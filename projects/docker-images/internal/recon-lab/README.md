# recon-lab

Site-agnostic **http/https** scanner: **Scan Info** (headers, HTML hints, light path probes) and **Scan Vulnerability** (TLS summary, security headers, CORS probe, TRACE, cookie flags, common sensitive paths). Not a CVE/exploit tool—heuristic misconfiguration checks only.

Build:

```bash
./scripts/build-local.sh internal/recon-lab
```

Use with deploy-docker bundle **`local-tools-127`**. Optional: **`attach_networks`** to reach other compose services by name; **`host.docker.internal`** for host ports.

Env:

- **`RECON_TLS_INSECURE=1`** — skip TLS certificate verification (self-signed / lab).
