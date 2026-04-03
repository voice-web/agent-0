"""HTTP reconnaissance: site-agnostic info gathering and light misconfiguration checks."""

from __future__ import annotations

import json
import os
import re
import socket
import ssl
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


DEFAULT_INFO_PROBES = [
    "/",
    "/health",
    "/api/",
    "/robots.txt",
    "/sitemap.xml",
    "/.well-known/security.txt",
]

VULN_EXTRA_PROBES = [
    "/.git/HEAD",
    "/.env",
    "/backup.sql",
    "/server-status",
    "/phpinfo.php",
    "/actuator/health",
    "/actuator/env",
    "/admin",
    "/admin/",
    "/swagger-ui.html",
    "/v2/api-docs",
    "/graphql",
    "/trace",
    "/.DS_Store",
    "/config.json",
    "/package.json",
]


def validate_target_url(raw: str) -> tuple[str | None, str | None]:
    """Accept any http(s) URL with a host. No prior knowledge of the target required."""
    raw = (raw or "").strip()
    if not raw:
        return None, "empty URL"
    if len(raw) > 2048:
        return None, "URL too long"
    try:
        p = urllib.parse.urlsplit(raw)
    except ValueError:
        return None, "invalid URL"
    if p.scheme not in ("http", "https"):
        return None, "only http and https are allowed"
    if not p.netloc:
        return None, "missing host"
    if p.hostname is None:
        return None, "missing hostname"
    return raw, None


def _loopback_connection_hint(url: str, err_msg: str | None) -> str | None:
    """Inside Docker, 127.0.0.1 is the container, not the host — connection refused is common."""
    if not err_msg:
        return None
    low = err_msg.lower()
    if "refused" not in low and "errno 111" not in low:
        return None
    try:
        host = (urllib.parse.urlsplit(url).hostname or "").lower()
    except ValueError:
        return None
    if host not in ("127.0.0.1", "localhost", "::1"):
        return None
    return (
        "recon-lab runs in a container: 127.0.0.1 and localhost refer to THIS container, "
        "not your machine. Use http://host.docker.internal:8092/ for a port published on the host, "
        "or attach the app Docker network and use http://default-html:8080/ (service name + container port)."
    )


def _ssl_context_for_fetch() -> ssl.SSLContext | None:
    insecure = os.environ.get("RECON_TLS_INSECURE", "").strip() in ("1", "true", "yes")
    if insecure:
        return ssl._create_unverified_context()
    return None


def _fetch(
    url: str,
    timeout: float,
    ssl_ctx: ssl.SSLContext | None,
    method: str = "GET",
    extra_headers: dict[str, str] | None = None,
) -> tuple[int | None, dict[str, str], bytes, str | None]:
    hdrs = {"User-Agent": "recon-lab/0.3 (research)"}
    if extra_headers:
        hdrs.update(extra_headers)
    req = urllib.request.Request(url, method=method, headers=hdrs)
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ssl_ctx) as resp:
            code = resp.getcode()
            raw = resp.headers
            out = {k.lower(): v for k, v in raw.items()}
            if hasattr(raw, "get_all"):
                sc = raw.get_all("Set-Cookie")
                if sc:
                    out["set-cookie"] = "\n".join(sc)
            body = resp.read(200_000)
            return code, out, body, None
    except urllib.error.HTTPError as e:
        eh: dict[str, str] = {}
        if e.headers:
            eh = {k.lower(): v for k, v in e.headers.items()}
            if hasattr(e.headers, "get_all"):
                sc = e.headers.get_all("Set-Cookie")
                if sc:
                    eh["set-cookie"] = "\n".join(sc)
        body = e.read(50_000) if e.fp else b""
        return e.code, eh, body, None
    except urllib.error.URLError as e:
        return None, {}, b"", str(e.reason) if e.reason else str(e)


def _collect_set_cookie(headers: dict[str, str]) -> list[str]:
    raw = headers.get("set-cookie")
    if not raw:
        return []
    return [s.strip() for s in raw.split("\n") if s.strip()]


SECURITY_HEADERS = [
    "content-security-policy",
    "content-security-policy-report-only",
    "strict-transport-security",
    "x-content-type-options",
    "x-frame-options",
    "referrer-policy",
    "permissions-policy",
    "cross-origin-opener-policy",
    "cross-origin-resource-policy",
]

INTERESTING_HEADERS = [
    "server",
    "x-powered-by",
    "via",
    "x-aspnet-version",
    "x-aspnetmvc-version",
]


def analyze_headers(headers: dict[str, str]) -> dict[str, Any]:
    lower = {k.lower(): v for k, v in headers.items()}
    sec = {h: lower.get(h) for h in SECURITY_HEADERS}
    leak = {h: lower.get(h) for h in INTERESTING_HEADERS if lower.get(h)}
    return {
        "security_headers": sec,
        "informational_headers": leak,
    }


def analyze_html(body: bytes) -> dict[str, Any]:
    try:
        text = body.decode("utf-8", errors="replace")
    except Exception:
        text = ""
    title_m = re.search(r"<title[^>]*>([^<]{0,200})", text, re.I)
    scripts = re.findall(
        r'<script[^>]+src=["\']([^"\']+)["\']',
        text,
        re.I,
    )
    links = re.findall(
        r'<link[^>]+href=["\']([^"\']+)["\']',
        text,
        re.I,
    )
    metas = re.findall(
        r'<meta[^>]+name=["\']generator["\'][^>]+content=["\']([^"\']+)["\']',
        text,
        re.I,
    )
    http_urls = len(re.findall(r"http://[^\s\"'<>]+", text))
    return {
        "title": title_m.group(1).strip() if title_m else None,
        "external_script_count": len(scripts),
        "script_sources_sample": scripts[:12],
        "link_hrefs_sample": links[:12],
        "meta_generator": metas[0] if metas else None,
        "insecure_http_urls_in_markup_estimate": http_urls,
    }


def request_origin(url: str) -> str:
    p = urllib.parse.urlsplit(url)
    return f"{p.scheme}://{p.netloc}/"


def join_url(base: str, path: str) -> str:
    base = base.rstrip("/") + "/"
    path = path if path.startswith("/") else f"/{path}"
    return urllib.parse.urljoin(base, path.lstrip("/"))


def _issue_severity_rank(sev: str | None) -> int:
    return {"high": 0, "medium": 1, "low": 2, "info": 3}.get((sev or "info").lower(), 4)


def build_info_issues(
    primary: dict[str, Any],
    probes: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Surface likely problems from an info scan without duplicating the full JSON tree."""
    issues: list[dict[str, Any]] = []
    st = primary.get("status")
    if isinstance(st, int):
        if st >= 500:
            issues.append(
                {
                    "severity": "medium",
                    "title": "Primary URL returns a server error",
                    "detail": f"HTTP status {st}.",
                }
            )
        elif 400 <= st < 500:
            issues.append(
                {
                    "severity": "info",
                    "title": "Primary URL returns a client error",
                    "detail": f"HTTP status {st}.",
                }
            )
    ha = primary.get("header_analysis") or {}
    inf = ha.get("informational_headers") or {}
    for k, v in sorted(inf.items()):
        issues.append(
            {
                "severity": "info",
                "title": f"Fingerprint header present: {k}",
                "detail": str(v)[:400],
            }
        )
    sec = ha.get("security_headers") or {}
    for name in SECURITY_HEADERS:
        if sec.get(name) is None:
            issues.append(
                {
                    "severity": "low",
                    "title": f"Missing security header on primary response: {name}",
                    "detail": "No value observed; consider hardening at the edge or application.",
                }
            )
    html = primary.get("html") or {}
    mixed = int(html.get("insecure_http_urls_in_markup_estimate") or 0)
    if mixed > 0:
        issues.append(
            {
                "severity": "low",
                "title": "Possible mixed content in HTML",
                "detail": f"~{mixed} http:// URL reference(s) in the markup sample.",
            }
        )
    ext = int(html.get("external_script_count") or 0)
    if ext > 0:
        samples = html.get("script_sources_sample") or []
        snip = ", ".join(str(s) for s in samples[:5])
        issues.append(
            {
                "severity": "info",
                "title": f"{ext} external script reference(s) in HTML",
                "detail": snip if snip else "Review third-party script origins.",
            }
        )
    for p in probes:
        if p.get("error"):
            continue
        path = p.get("path")
        ps = p.get("status")
        if path == "/health" and ps == 500:
            issues.append(
                {
                    "severity": "medium",
                    "title": "/health returned HTTP 500",
                    "detail": "Health endpoints should not fail during passive recon.",
                }
            )
    return issues


def consolidate_vuln_issues(
    findings: list[dict[str, Any]],
    tls_report: dict[str, Any],
    sensitive_hits: list[dict[str, Any]],
    cookie_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Merge structured vuln fields into one list for UI highlights (includes findings)."""
    issues: list[dict[str, Any]] = [dict(f) for f in findings]
    tls_err = (tls_report or {}).get("error")
    if tls_err:
        issues.append(
            {
                "id": "tls-handshake-error",
                "severity": "medium",
                "title": "TLS handshake or certificate problem",
                "detail": str(tls_err)[:500],
            }
        )
    for hit in sensitive_hits or []:
        st = hit.get("status")
        path = hit.get("path") or "?"
        if st == 200:
            issues.append(
                {
                    "id": f"sensitive-200-{path}",
                    "severity": "high",
                    "title": f"Sensitive path returned 200: {path}",
                    "detail": (
                        f"Content-Type: {hit.get('content_type')!r}; "
                        f"body sample: {(hit.get('body_snippet') or '')[:160]}"
                    ),
                }
            )
        elif st in (301, 302, 307, 308, 401, 403):
            issues.append(
                {
                    "id": f"sensitive-{st}-{path}",
                    "severity": "low",
                    "title": f"Sensitive path {path} returned HTTP {st}",
                    "detail": "Resource may exist; confirm exposure and redirects are intended.",
                }
            )
    for row in cookie_rows or []:
        missing = row.get("missing_flags") or []
        if not missing:
            continue
        name = str(row.get("cookie_name_hint") or "cookie")
        sev = "medium" if ("Secure" in missing or "HttpOnly" in missing) else "low"
        preview = str(row.get("preview") or "")[:140]
        issues.append(
            {
                "id": f"cookie-flags-{name[:48]}",
                "severity": sev,
                "title": f"Set-Cookie may be missing flags ({name})",
                "detail": f"Missing: {', '.join(missing)}. {preview}",
            }
        )
    return issues


def run_info_scan(
    target: str,
    timeout: float = 12.0,
    extra_probes: list[str] | None = None,
) -> dict[str, Any]:
    ok_url, err = validate_target_url(target)
    if not ok_url:
        return {
            "ok": False,
            "error": err,
            "issues": [
                {
                    "severity": "high",
                    "title": "Invalid or disallowed target URL",
                    "detail": err or "empty URL",
                }
            ],
        }

    ssl_ctx = _ssl_context_for_fetch()
    origin = request_origin(ok_url)

    status, hdrs, body, fetch_err = _fetch(ok_url, timeout, ssl_ctx)
    if fetch_err:
        out: dict[str, Any] = {
            "ok": False,
            "error": fetch_err,
            "target": ok_url,
            "issues": [
                {
                    "severity": "high",
                    "title": "Primary request failed",
                    "detail": str(fetch_err)[:500],
                }
            ],
        }
        hint = _loopback_connection_hint(ok_url, fetch_err)
        if hint:
            out["hint"] = hint
        return out

    header_report = analyze_headers(hdrs)
    content_type = hdrs.get("content-type", "")
    html_bits: dict[str, Any] | None = None
    if "html" in content_type.lower():
        html_bits = analyze_html(body)

    probes = list(DEFAULT_INFO_PROBES)
    if extra_probes:
        probes.extend(extra_probes)
    seen: set[str] = set()
    ordered = [p for p in probes if not (p in seen or seen.add(p))]

    probe_results: list[dict[str, Any]] = []
    for path in ordered:
        u = join_url(origin, path)
        st, h, _b, fe = _fetch(u, min(timeout, 8.0), ssl_ctx)
        probe_results.append(
            {
                "path": path,
                "url": u,
                "status": st,
                "error": fe,
                "content_type": h.get("content-type") if h else None,
            }
        )

    payload: dict[str, Any] = {
        "ok": True,
        "scan_type": "info",
        "target": ok_url,
        "primary": {
            "status": status,
            "content_type": content_type,
            "header_analysis": header_report,
            "body_preview": body[:4000].decode("utf-8", errors="replace"),
            "html": html_bits,
        },
        "probes": probe_results,
        "notes": [
            "No target-specific logic: same probes and parsers for every URL.",
            "Use Scan Vulnerability for TLS, CORS, cookies, TRACE, and extra paths.",
        ],
    }
    info_issues = build_info_issues(payload["primary"], probe_results)
    info_issues.sort(
        key=lambda x: (_issue_severity_rank(str(x.get("severity"))), str(x.get("title", "")))
    )
    payload["issues"] = info_issues
    return payload


def _tls_overview(parsed: urllib.parse.SplitResult, timeout: float) -> dict[str, Any]:
    if parsed.scheme != "https":
        return {"skipped": True, "reason": "not https"}
    host = parsed.hostname
    if not host:
        return {"error": "no host"}
    port = parsed.port or 443
    insecure = os.environ.get("RECON_TLS_INSECURE", "").strip() in ("1", "true", "yes")
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    if insecure:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    else:
        ctx.verify_mode = ssl.CERT_REQUIRED
        ctx.load_default_certs()
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                cert = ssock.getpeercert()
                cipher = ssock.cipher()
                ver = ssock.version()
    except Exception as e:
        return {"error": str(e), "host": host, "port": port}

    def _flatten(tuples: list) -> list[tuple[str, str]]:
        out: list[tuple[str, str]] = []
        for item in tuples or []:
            if isinstance(item, tuple):
                for k, v in item:
                    out.append((str(k), str(v)))
        return out

    sub = dict(_flatten(cert.get("subject", []))) if cert else {}
    iss = dict(_flatten(cert.get("issuer", []))) if cert else {}
    san = []
    if cert:
        for t in cert.get("subjectAltName", []) or []:
            if len(t) >= 2:
                san.append(f"{t[0]}:{t[1]}")

    return {
        "skipped": False,
        "host": host,
        "port": port,
        "tls_version": ver,
        "cipher": {"name": cipher[0], "bits": cipher[2]} if cipher else None,
        "subject": sub,
        "issuer": iss,
        "not_before": cert.get("notBefore") if cert else None,
        "not_after": cert.get("notAfter") if cert else None,
        "san_count": len(san),
        "san_sample": san[:8],
        "certificate_obtained": bool(cert),
    }


def _cookie_flag_findings(cookies: list[str]) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for c in cookies:
        lower = c.lower()
        name = c.split("=", 1)[0].strip() if "=" in c else c[:40]
        missing = []
        if "httponly" not in lower:
            missing.append("HttpOnly")
        if "secure" not in lower:
            missing.append("Secure")
        if "samesite" not in lower:
            missing.append("SameSite")
        findings.append(
            {
                "cookie_name_hint": name[:80],
                "missing_flags": missing,
                "preview": c[:200],
            }
        )
    return findings


def _missing_header_findings(h: dict[str, str]) -> list[dict[str, Any]]:
    low = {k.lower(): v for k, v in h.items()}
    findings = []
    for name in SECURITY_HEADERS:
        if not low.get(name):
            findings.append(
                {
                    "id": f"missing-{name.replace('_', '-')}",
                    "severity": "low",
                    "title": f"Missing {name}",
                    "detail": "Consider adding this header to reduce browser-level risk.",
                }
            )
    return findings


def run_vuln_scan(target: str, timeout: float = 15.0) -> dict[str, Any]:
    """Light misconfiguration / exposure checks. Not a full CVE scanner."""
    ok_url, err = validate_target_url(target)
    if not ok_url:
        return {
            "ok": False,
            "error": err,
            "issues": [
                {
                    "severity": "high",
                    "title": "Invalid or disallowed target URL",
                    "detail": err or "empty URL",
                }
            ],
        }

    ssl_ctx = _ssl_context_for_fetch()
    parsed = urllib.parse.urlsplit(ok_url)
    origin = request_origin(ok_url)

    findings: list[dict[str, Any]] = []

    tls_report = _tls_overview(parsed, min(timeout, 10.0))

    status, hdrs, body, fetch_err = _fetch(ok_url, timeout, ssl_ctx)
    if fetch_err:
        out: dict[str, Any] = {
            "ok": False,
            "error": fetch_err,
            "target": ok_url,
            "tls": tls_report,
            "issues": [
                {
                    "severity": "high",
                    "title": "Primary request failed",
                    "detail": str(fetch_err)[:500],
                }
            ],
        }
        hint = _loopback_connection_hint(ok_url, fetch_err)
        if hint:
            out["hint"] = hint
        return out

    lowh = {k.lower(): v for k, v in hdrs.items()}

    for name in ("server", "x-powered-by", "x-aspnet-version"):
        if lowh.get(name):
            findings.append(
                {
                    "id": f"header-disclosure-{name}",
                    "severity": "info",
                    "title": f"{name} present",
                    "detail": lowh[name][:200],
                }
            )

    findings.extend(_missing_header_findings(hdrs))

    cookies = _collect_set_cookie(lowh)
    if cookies:
        findings.append(
            {
                "id": "set-cookie-present",
                "severity": "info",
                "title": f"{len(cookies)} Set-Cookie header(s)",
                "detail": "Review flags below.",
            }
        )

    cookie_flags = _cookie_flag_findings(cookies)

    cors_origin = "https://recon-lab-cors-probe.invalid"
    _st, ch, _b, _fe = _fetch(
        ok_url,
        min(timeout, 8.0),
        ssl_ctx,
        extra_headers={"Origin": cors_origin},
    )
    acao = (ch or {}).get("access-control-allow-origin", "")
    acac = (ch or {}).get("access-control-allow-credentials", "")
    cors_reflects = acao == cors_origin or acao == "*"
    if cors_reflects:
        findings.append(
            {
                "id": "cors-permissive",
                "severity": "medium" if acao == cors_origin else "info",
                "title": "CORS may allow cross-origin access",
                "detail": f"Access-Control-Allow-Origin: {acao!r}; credentials header: {acac!r}",
            }
        )

    trace_status: int | None = None
    trace_err: str | None = None
    trace_body_snip = ""
    try:
        ts, th, tb, te = _fetch(ok_url, min(timeout, 6.0), ssl_ctx, method="TRACE")
        trace_status = ts
        trace_err = te
        if tb:
            trace_body_snip = tb[:200].decode("utf-8", errors="replace")
    except Exception as e:
        trace_err = str(e)

    if trace_status == 200 and trace_body_snip:
        findings.append(
            {
                "id": "trace-enabled",
                "severity": "low",
                "title": "TRACE returned 200 with body",
                "detail": "Some proxies disable TRACE; a response may indicate it is enabled.",
            }
        )

    opts_allow = None
    os_, oh, _ob, oe = _fetch(ok_url, min(timeout, 6.0), ssl_ctx, method="OPTIONS")
    if not oe and oh:
        opts_allow = oh.get("allow") or oh.get("access-control-allow-methods")

    ct = lowh.get("content-type", "")
    mixed = None
    if parsed.scheme == "https" and "html" in ct.lower():
        est = analyze_html(body).get("insecure_http_urls_in_markup_estimate", 0)
        mixed = est
        if est and est > 0:
            findings.append(
                {
                    "id": "mixed-content-hints",
                    "severity": "low",
                    "title": "Possible mixed content (http:// URLs in HTML)",
                    "detail": f"~{est} http:// references in markup sample",
                }
            )

    probe_hits: list[dict[str, Any]] = []
    for path in VULN_EXTRA_PROBES:
        u = join_url(origin, path)
        st, h, b, fe = _fetch(u, min(timeout, 5.0), ssl_ctx)
        interesting = st in (200, 301, 302, 401, 403) and not fe
        if interesting:
            probe_hits.append(
                {
                    "path": path,
                    "url": u,
                    "status": st,
                    "content_type": (h or {}).get("content-type"),
                    "body_snippet": (b[:120].decode("utf-8", errors="replace") if b else ""),
                }
            )

    all_issues = consolidate_vuln_issues(findings, tls_report, probe_hits, cookie_flags)
    all_issues.sort(
        key=lambda x: (_issue_severity_rank(str(x.get("severity"))), str(x.get("title", "")))
    )

    return {
        "ok": True,
        "scan_type": "vulnerability",
        "target": ok_url,
        "summary": {
            "finding_count": len(findings),
            "primary_status": status,
            "content_type": ct,
        },
        "findings": findings,
        "issues": all_issues,
        "tls": tls_report,
        "http": {
            "trace": {
                "status": trace_status,
                "error": trace_err,
                "body_preview": trace_body_snip[:120],
            },
            "options_allow": opts_allow,
            "cors_probe": {
                "sent_origin": cors_origin,
                "access_control_allow_origin": acao or None,
                "access_control_allow_credentials": acac or None,
                "reflects_arbitrary_origin": cors_reflects,
            },
            "cookie_analysis": cookie_flags,
        },
        "sensitive_path_hits": probe_hits,
        "disclaimer": [
            "Heuristic checks only; false positives/negatives are expected.",
            "Does not exploit RCE/SQLi or run a CVE database.",
            "Only test targets you are permitted to assess.",
        ],
    }


def scan_json(target: str) -> str:
    return json.dumps(run_info_scan(target), indent=2) + "\n"
