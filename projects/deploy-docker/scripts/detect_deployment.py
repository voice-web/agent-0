#!/usr/bin/env python3
"""Guess which deployments/<bundle>/ matches running Docker Compose workloads.

1) List every *running* container that has Compose labels.
2) For each, compute which bundle(s) include that (compose_project, compose_service)
   pair (edge vs app lists in services.json).
3) If every workload maps to at least one bundle, intersect those sets; a single
   common bundle means that deployment is the one running (as a set).

Always prints discovery; exit 0 only when intersection is exactly one bundle.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
DEPLOYMENTS = ROOT / "deployments"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def docker_run(args: list[str]) -> tuple[int, str, str]:
    p = subprocess.run(["docker"] + args, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def load_bundles() -> list[dict[str, Any]]:
    bundles: list[dict[str, Any]] = []
    if not DEPLOYMENTS.is_dir():
        return bundles
    for d in sorted(DEPLOYMENTS.iterdir()):
        if not d.is_dir():
            continue
        dep = d / "deployment.json"
        svc = d / "services.json"
        if not dep.is_file() or not svc.is_file():
            continue
        dj = load_json(dep)
        sj = load_json(svc)
        bid = str(dj.get("deployment_id") or d.name)
        edge = sj.get("edge") or []
        app = sj.get("application") or []
        edge_services = {str(x["name"]) for x in edge if isinstance(x, dict) and x.get("name")}
        app_services = {str(x["name"]) for x in app if isinstance(x, dict) and x.get("name")}
        bundles.append(
            {
                "dirname": d.name,
                "deployment_id": bid,
                "network_name": str(sj.get("network_name") or ""),
                "edge_project": str(sj.get("edge_project") or ""),
                "app_project": str(sj.get("app_project") or ""),
                "edge_services": edge_services,
                "app_services": app_services,
            }
        )
    return bundles


def deployments_including(
    bundles: list[dict[str, Any]], compose_project: str, compose_service: str
) -> list[str]:
    """Bundle dirnames whose services.json declares this compose project+service."""
    hits: list[str] = []
    if not compose_project or not compose_service:
        return hits
    for b in bundles:
        ep, ap = b["edge_project"], b["app_project"]
        if ep == compose_project and compose_service in b["edge_services"]:
            hits.append(b["dirname"])
        elif ap == compose_project and compose_service in b["app_services"]:
            hits.append(b["dirname"])
    return hits


def running_compose_containers() -> list[tuple[str, str, str, str]]:
    """Running containers with Compose labels: name, project, service, image."""
    rc, out, _ = docker_run(
        [
            "ps",
            "--filter",
            "status=running",
            "--no-trunc",
            "--format",
            "{{.Names}}\t{{.Label \"com.docker.compose.project\"}}\t"
            '{{.Label "com.docker.compose.service"}}\t{{.Image}}',
        ]
    )
    if rc != 0:
        return []
    rows: list[tuple[str, str, str, str]] = []
    for line in out.splitlines():
        parts = line.split("\t", 3)
        if len(parts) < 4:
            continue
        name, proj, svc, image = parts[0], parts[1], parts[2], parts[3]
        if not proj.strip():
            continue
        if not svc.strip():
            svc = "?"
        rows.append((name, proj, svc, image))
    return sorted(rows, key=lambda x: (x[1], x[2], x[0]))


def list_wc_networks() -> list[str]:
    rc, out, _ = docker_run(["network", "ls", "--format", "{{.Name}}"])
    if rc != 0:
        return []
    return sorted(n for n in out.splitlines() if n.startswith("wc-"))


def main() -> None:
    print("==> Known deployment bundles (from deployments/*/services.json)")
    bundles = load_bundles()
    if not bundles:
        print("    (none — need deployment.json + services.json per bundle)")
        sys.exit(1)

    for b in bundles:
        en = ",".join(sorted(b["edge_services"]))
        an = ",".join(sorted(b["app_services"]))
        print(
            f"    {b['dirname']}: edge={b['edge_project']} [{en}] | "
            f"app={b['app_project']} [{an}] | net={b['network_name']}"
        )

    rc_docker, _, err_docker = docker_run(["version"])
    if rc_docker != 0:
        print("\n==> Docker not available", file=sys.stderr)
        print(err_docker.strip() or "docker version failed", file=sys.stderr)
        sys.exit(1)

    print("\n==> Running containers with Compose labels (compose project + service)")
    running = running_compose_containers()
    if not running:
        print("    (none)")
        sets_per_row: list[set[str]] = []
    else:
        sets_per_row = []
        for name, proj, svc, image in running:
            hits = deployments_including(bundles, proj, svc)
            hits_s = ", ".join(hits) if hits else "— none —"
            print(f"    {name}")
            print(f"        project={proj}  service={svc}  image={image}")
            print(f"        deployments: {hits_s}")
            sets_per_row.append(set(hits))

    print("\n==> Docker networks named wc-* (supplementary)")
    wc_nets = list_wc_networks()
    if wc_nets:
        for n in wc_nets:
            print(f"    {n}")
    else:
        print("    (none)")

    print()
    if not running:
        print(
            "==> No inference: no running containers with com.docker.compose.project.",
        )
        sys.exit(1)

    unmatched_idx = [i for i, s in enumerate(sets_per_row) if not s]
    if unmatched_idx:
        print(
            "==> Some Compose workloads do not match any bundle "
            f"({len(unmatched_idx)} of {len(running)}).",
        )
        for i in unmatched_idx:
            name, proj, svc, _ = running[i]
            print(f"    - {name} ({proj} / {svc})")

    nonempty = [s for s in sets_per_row if s]
    if not nonempty:
        print(
            "==> No inference: nothing running maps to a known deployment.",
        )
        sys.exit(1)

    overlap_all = set.intersection(*sets_per_row)
    overlap_known = set.intersection(*nonempty) if nonempty else set()

    if unmatched_idx:
        print(
            f"\n==> Intersection of deployments that include *every* running workload: "
            f"{sorted(overlap_all) if overlap_all else '(empty; impossible while orphans exist)'}",
        )
        print(
            f"==> Intersection ignoring unmatched workloads only: "
            f"{sorted(overlap_known) if overlap_known else '(empty)'}",
        )
        if len(overlap_known) == 1:
            only = next(iter(overlap_known))
            print(
                f"\n==> Provisional inference (matched containers only): {only}",
            )
        else:
            print(
                "\n==> No single deployment for the full machine state.",
            )
        sys.exit(1)

    assert not unmatched_idx
    if len(overlap_all) == 1:
        only = next(iter(overlap_all))
        print(
            "==> Inferred deployment: "
            f"{only} (every running Compose workload is included in this bundle’s project/service map).",
        )
        sys.exit(0)
    if len(overlap_all) == 0:
        print(
            "==> No single overlapping deployment: running stacks mix multiple bundles "
            "(or duplicate compose project names across bundles).",
        )
        print(f"    Pairwise candidate sets were: {[sorted(s) for s in sets_per_row]}")
        sys.exit(1)

    print(
        f"==> Ambiguous: multiple bundles overlap every workload: {sorted(overlap_all)}",
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
