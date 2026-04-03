#!/usr/bin/env python3
"""
Compile a deployment bundle under deployments/<id>/ → .generated/<id>/

Outputs:
  Caddyfile
  edge/docker-compose.yml  (network + caddy + keycloak)
  app/docker-compose.yml   (workloads, external network)
  resolved.json
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

try:
    import jsonschema

    _HAS_JSONSCHEMA = True
except ImportError:
    _HAS_JSONSCHEMA = False


ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "schemas"
DEPLOYMENTS = ROOT / "deployments"
GENERATED = ROOT / ".generated"

DEFAULT_GLOBE_ASSETS = os.environ.get(
    "GLOBE_LANDING_ASSETS",
    "/Users/ray.jimenez/worldcliques/git/vap/projects/globe-landing/site/assets",
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_schema(instance: dict, schema_name: str) -> None:
    if not _HAS_JSONSCHEMA:
        return
    schema_path = SCHEMA_DIR / schema_name
    if not schema_path.is_file():
        return
    schema = load_json(schema_path)
    jsonschema.validate(instance=instance, schema=schema)


def service_enabled(config: dict, flag: str, default: bool = True) -> bool:
    o = (config.get("service_overrides") or {}).get(flag, {})
    return bool(o.get("enabled", default))


def sanitize(s: str) -> str:
    s = s.lower().replace(".", "-")
    return re.sub(r"[^a-z0-9_-]+", "-", s).strip("-") or "deploy"


def emit_local_path_caddy(config: dict, path: Path) -> None:
    globe = service_enabled(config, "globe-landing", False)
    lines = [
        ":80 {",
        "\tencode zstd gzip",
        "",
        "\thandle_path /api/* {",
        "\t\treverse_proxy default-api-json:8080",
        "\t}",
        "\thandle_path /api {",
        "\t\treverse_proxy default-api-json:8080",
        "\t}",
		"\t@auth path /auth*",
		"\thandle @auth {",
		"\t\treverse_proxy keycloak:8080 {",
		"\t\t\t# Keycloak may emit HSTS; browsers then upgrade to https://127.0.0.1, which has no listener.",
		"\t\t\theader_down -Strict-Transport-Security",
		"\t\t}",
		"\t}",
    ]
    if globe:
        lines += [
            "\thandle_path /ui/* {",
            "\t\treverse_proxy globe-landing:8080",
            "\t}",
            "\thandle_path /ui {",
            "\t\treverse_proxy globe-landing:8080",
            "\t}",
        ]
    else:
        lines += [
            "\t@ui path /ui*",
            "\thandle @ui {",
            '\t\trespond "ui disabled" 404',
            "\t}",
        ]
    lines += [
        "\thandle {",
        "\t\treverse_proxy default-html:8080",
        "\t}",
        "}",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def emit_vm_host_caddy(routing: dict, config: dict, path: Path) -> None:
    tls_line = "\n\ttls internal" if os.environ.get("WC_CADDY_TLS", "auto") == "internal" else ""
    email = os.environ.get("WC_CADDY_ACME_EMAIL", "").strip()
    global_block = f"{{\n\temail {email}\n}}\n\n" if email else ""

    ro = config.get("routing") or {}
    html_hosts = ro.get("html_hosts") or routing.get("html_hosts") or ["worldcliques.org"]
    html_hosts_str = ", ".join(html_hosts)

    globe = service_enabled(config, "globe-landing", False)
    login_block = ""
    if globe:
        login_block = """
	@login_no_slash path /login
	redir @login_no_slash /login/ 308
	handle /login/* {
		uri strip_prefix /login
		reverse_proxy globe-landing:8080
	}
	handle /login/ {
		uri strip_prefix /login
		reverse_proxy globe-landing:8080
	}
"""

    body = f"""api.worldcliques.org {{{tls_line}
	encode zstd gzip
	reverse_proxy default-api-json:8080
}}

auth.worldcliques.org {{{tls_line}
	encode zstd gzip
	reverse_proxy keycloak:8080
}}

{html_hosts_str} {{{tls_line}
	encode zstd gzip
{login_block}\thandle {{
		reverse_proxy default-html:8080
	}}
}}
"""
    path.write_text(global_block + body, encoding="utf-8")


def resolve_volume_line(spec: str, caddyfile_abs: Path, deployment_id: str) -> str:
    if spec == "caddyfile_bind":
        return f"{caddyfile_abs}:/etc/caddy/Caddyfile:ro"
    if spec == "caddy_data":
        return "caddy_data:/data"
    if spec == "caddy_config":
        return "caddy_config:/config"
    if spec == "globe_assets_bind":
        ga = os.environ.get("GLOBE_LANDING_ASSETS", DEFAULT_GLOBE_ASSETS)
        return f"{ga}:/srv/www/assets:ro"
    raise ValueError(f"unknown volumes_spec: {spec}")


def service_yaml(
    name: str,
    svc: dict,
    deployment_id: str,
    role: str,
    caddyfile_abs: Path | None,
) -> list[str]:
    lines = [f"  {name}:", f'    image: "{svc["image"]}"']
    if svc.get("command"):
        cmd = svc["command"]
        if isinstance(cmd, list):
            lines.append("    command:")
            for c in cmd:
                lines.append(f"      - {json.dumps(str(c))}")
        else:
            lines.append(f"    command: {json.dumps(str(cmd))}")
    if svc.get("env_file"):
        lines.append("    env_file:")
        for ef in svc["env_file"]:
            lines.append(f"      - {json.dumps(ef)}")
    env = svc.get("environment") or {}
    if env:
        lines.append("    environment:")
        for k, v in env.items():
            lines.append(f"      {k}: {json.dumps(str(v))}")
    ports = svc.get("ports") or []
    if ports:
        lines.append("    ports:")
        for p in ports:
            lines.append(f'      - "{p}"')
    vol_specs = svc.get("volumes_spec") or []
    if vol_specs:
        lines.append("    volumes:")
        for sp in vol_specs:
            lines.append(f"      - {json.dumps(resolve_volume_line(sp, caddyfile_abs, deployment_id))}")
    dep = svc.get("depends_on") or []
    if dep:
        lines.append("    depends_on:")
        for d in dep:
            lines.append(f"      - {d}")
    lines.append("    labels:")
    lines.append(f'      worldcliques.deployment: "{deployment_id}"')
    lbl_role = svc.get("label_role") or role
    lines.append(f'      worldcliques.role: "{lbl_role}"')
    lines.append('      worldcliques.service: "' + name + '"')
    lines.append("    networks:")
    lines.append("      - wc-net")
    if svc.get("restart"):
        lines.append(f"    restart: {svc['restart']}")
    return lines


def write_edge_compose(
    out: Path,
    services_manifest: dict,
    network_name: str,
    deployment_id: str,
    caddyfile_abs: Path,
) -> None:
    lines = ["services:"]
    for svc in services_manifest["edge"]:
        lines.extend(
            service_yaml(
                svc["name"],
                svc,
                deployment_id,
                "edge",
                caddyfile_abs,
            )
        )
    lines.append("")
    lines.append("networks:")
    lines.append("  wc-net:")
    lines.append(f"    name: {json.dumps(network_name)}")
    lines.append("    driver: bridge")
    lines.append("")
    lines.append("volumes:")
    lines.append("  caddy_data:")
    lines.append("  caddy_config:")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_app_compose(
    out: Path,
    services_manifest: dict,
    network_name: str,
    deployment_id: str,
    config: dict,
) -> list[str]:
    """Write app compose; return service names. If none enabled, do not write the file."""
    selected: list[dict] = []
    for svc in services_manifest["application"]:
        opt = svc.get("optional")
        flag = svc.get("config_flag") or svc["name"]
        if opt and not service_enabled(config, flag, default=True):
            continue
        selected.append(svc)
    if not selected:
        return []
    lines = ["services:"]
    for svc in selected:
        lines.extend(
            service_yaml(
                svc["name"],
                svc,
                deployment_id,
                "application",
                None,
            )
        )
    lines.append("")
    lines.append("networks:")
    lines.append("  wc-net:")
    lines.append("    external: true")
    lines.append(f"    name: {json.dumps(network_name)}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return [s["name"] for s in selected]


def _keycloak_env(services_manifest: dict) -> dict:
    for svc in services_manifest["edge"]:
        if svc["name"] == "keycloak":
            return svc.get("environment") or {}
    return {}


def _caddy_svc(services_manifest: dict) -> dict | None:
    for svc in services_manifest["edge"]:
        if svc["name"] == "caddy":
            return svc
    return None


def _first_published_port(port_spec: str) -> int | None:
    """First host port from a compose port string (e.g. 80:80, 8080:80, [::]:80:80)."""
    parts = str(port_spec).split(":")
    if not parts:
        return None
    if parts[0].isdigit():
        return int(parts[0])
    # ip:published:target
    if len(parts) >= 3 and parts[1].isdigit():
        return int(parts[1])
    return None


def build_test_routes(
    mode: str,
    routing: dict,
    config: dict,
    services_manifest: dict,
) -> list[dict]:
    """Human-facing URLs matching the generated Caddyfile (for docs and up.sh)."""
    kc = _keycloak_env(services_manifest)
    rel_raw = (kc.get("KC_HTTP_RELATIVE_PATH") or "/auth").strip()
    rel = rel_raw if rel_raw.startswith("/") else f"/{rel_raw}"
    rel = rel.rstrip("/") or "/auth"
    globe = service_enabled(config, "globe-landing", False)
    routes: list[dict[str, object]] = []

    if mode == "local_path":
        caddy = _caddy_svc(services_manifest) or {}
        port_list = caddy.get("ports") or ["80:80"]
        pub = _first_published_port(port_list[0]) if port_list else 80
        if pub is None:
            pub = 80
        host = str(kc.get("KC_HOSTNAME") or "127.0.0.1")

        def loc(path: str) -> str:
            p = path if path.startswith("/") else f"/{path}"
            if p != "/" and not p.endswith("/"):
                p = f"{p}/"
            netloc = host if pub == 80 else f"{host}:{pub}"
            return f"http://{netloc}{p}"

        routes.append({"label": "API (default-api-json)", "urls": [loc("/api")]})
        routes.append({"label": "Keycloak", "urls": [loc(f"{rel}/")]})
        if globe:
            routes.append({"label": "Globe UI", "urls": [loc("/ui")]})
        routes.append({"label": "Default HTML", "urls": [loc("/")]})

    elif mode == "vm_host":
        ro = config.get("routing") or {}
        html_hosts = list(
            ro.get("html_hosts") or routing.get("html_hosts") or ["worldcliques.org"]
        )
        auth_path = f"{rel}/"

        def host_urls(site: str, path: str) -> list[str]:
            p = path if path.startswith("/") else f"/{path}"
            if p != "/" and not p.endswith("/"):
                p = f"{p}/"
            return [f"https://{site}{p}", f"http://{site}{p}"]

        routes.append(
            {
                "label": "API (default-api-json)",
                "urls": host_urls("api.worldcliques.org", "/"),
            }
        )
        routes.append(
            {
                "label": "Keycloak",
                "urls": host_urls("auth.worldcliques.org", auth_path),
            }
        )
        for h in html_hosts:
            routes.append(
                {"label": f"Default HTML ({h})", "urls": host_urls(h, "/")}
            )
            if globe:
                routes.append(
                    {"label": f"Globe /login ({h})", "urls": host_urls(h, "/login/")}
                )

    return routes


def expected_images(services_manifest: dict, config: dict) -> list[str]:
    imgs = []
    for svc in services_manifest["edge"]:
        imgs.append(svc["image"])
    for svc in services_manifest["application"]:
        opt = svc.get("optional")
        flag = svc.get("config_flag") or svc["name"]
        if opt and not service_enabled(config, flag, default=True):
            continue
        imgs.append(svc["image"])
    return imgs


def compile_deployment(deployment_dir: Path) -> Path:
    dep_meta = load_json(deployment_dir / "deployment.json")
    validate_schema(dep_meta, "deployment.schema.json")

    deployment_id = dep_meta["deployment_id"]
    routing = load_json(deployment_dir / dep_meta["routing"])
    validate_schema(routing, "routing.schema.json")
    services_manifest = load_json(deployment_dir / dep_meta["services"])
    validate_schema(services_manifest, "services.schema.json")
    config = load_json(deployment_dir / dep_meta["config"])
    validate_schema(config, "config.schema.json")

    out_dir = GENERATED / sanitize(deployment_id)
    out_dir.mkdir(parents=True, exist_ok=True)
    caddy_path = out_dir / "Caddyfile"

    mode = routing.get("mode")
    if mode == "local_path":
        emit_local_path_caddy(config, caddy_path)
    elif mode == "vm_host":
        ro = config.get("routing") or {}
        html_hosts = list(ro.get("html_hosts") or routing.get("html_hosts") or [])
        reserved = {"api.worldcliques.org", "auth.worldcliques.org"}
        bad = [h for h in html_hosts if h in reserved]
        if bad:
            sys.stderr.write(
                f"routing conflict: html_hosts must not include {bad} "
                "(those hosts are reserved for api/auth)\n"
            )
            sys.exit(2)
        emit_vm_host_caddy(routing, config, caddy_path)
    else:
        sys.stderr.write(f"unsupported routing mode: {mode}\n")
        sys.exit(2)

    caddy_abs = caddy_path.resolve()
    write_edge_compose(
        out_dir / "edge" / "docker-compose.yml",
        services_manifest,
        services_manifest["network_name"],
        deployment_id,
        caddy_abs,
    )
    app_compose_path = out_dir / "app" / "docker-compose.yml"
    app_service_names = write_app_compose(
        app_compose_path,
        services_manifest,
        services_manifest["network_name"],
        deployment_id,
        config,
    )
    app_compose_resolved: str | None
    if not app_service_names:
        if app_compose_path.is_file():
            app_compose_path.unlink()
        no_svc = out_dir / "app" / ".no_application_services"
        no_svc.parent.mkdir(parents=True, exist_ok=True)
        no_svc.write_text(
            "All optional application services are disabled in config.\n",
            encoding="utf-8",
        )
        app_compose_resolved = None
    else:
        app_path = app_compose_path.resolve()
        if (out_dir / "app" / ".no_application_services").is_file():
            (out_dir / "app" / ".no_application_services").unlink()
        app_compose_resolved = str(app_path)

    paths_obj = {
        "root": str(out_dir.resolve()),
        "caddyfile": str(caddy_abs),
        "edge_compose": str((out_dir / "edge" / "docker-compose.yml").resolve()),
        "app_compose": app_compose_resolved,
    }

    resolved = {
        "schema_version": "1.0",
        "deployment_id": deployment_id,
        "generated_at": __import__("datetime")
        .datetime.now(__import__("datetime").timezone.utc)
        .isoformat()
        .replace("+00:00", "Z"),
        "paths": paths_obj,
        "network_name": services_manifest["network_name"],
        "compose_projects": {
            "edge": services_manifest["edge_project"],
            "application": services_manifest["app_project"],
        },
        "routing": routing,
        "config": config,
        "expected_images": expected_images(services_manifest, config),
        "application_service_names": app_service_names,
        "test_routes": build_test_routes(mode, routing, config, services_manifest),
    }
    (out_dir / "resolved.json").write_text(
        json.dumps(resolved, indent=2) + "\n", encoding="utf-8"
    )
    return out_dir


def main() -> None:
    if len(sys.argv) != 2:
        sys.stderr.write(
            f"Usage: {sys.argv[0]} <deployment_id | path-to-deployment-dir>\n"
        )
        sys.exit(2)
    arg = sys.argv[1]
    if Path(arg).is_dir():
        d = Path(arg).resolve()
    else:
        d = (DEPLOYMENTS / arg).resolve()
    if not (d / "deployment.json").is_file():
        sys.stderr.write(f"not a deployment directory: {d}\n")
        sys.exit(2)
    out = compile_deployment(d)
    print(out)


if __name__ == "__main__":
    main()
