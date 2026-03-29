# deploy — Caddy + basic-http (minimal)

**Caddy** listens on **port 80** and proxies by path:

| Path | Container |
|------|-----------|
| **`/labs/`** … | `basic-http-labs` |
| **everything else** | `basic-http-main` |

No TLS, no auth — add those later. Image versions live in **`versions.manifest.json`**; **`docker compose up -d`** uses pinned **`image:`** tags (build them first).

Regenerate **`docker-compose.yml`** after editing the template or manifest:

```bash
python3 scripts/render-compose.py
```

## Build images (once per version bump)

From **agent-0** repo:

```bash
cd projects/docker-images && ./scripts/build-local.sh external/caddy
cd projects/docker-images && ./scripts/build-local.sh internal/basic-http
```

## Run

```bash
cd projects/deploy
docker compose up -d
```

On the machine where Docker runs, use **http://127.0.0.1/** and **http://127.0.0.1/labs/** (reliable IPv4). **`localhost`** can behave oddly in some browsers; **127.0.0.1** is fine to standardize on.

### `localhost` fails in the browser but `127.0.0.1` works

That usually means the browser is using **IPv6** for **`localhost`** (`::1`), while Docker (or the host) is only accepting **IPv4** on **`127.0.0.1`**. **`curl`** may pick IPv4; **Chrome/Safari/Firefox** often try **`::1` first**.

**Workaround:** use **`http://127.0.0.1/`** (forces IPv4). No stack change required.

**Optional:** in **`docker-compose.override.yml`**, add an IPv6 publish **only if** your Docker engine supports it and you do **not** get a “port already in use” error:

```yaml
services:
  caddy:
    ports:
      - "80:80"
      - "[::]:80:80"
```

If the second line errors, remove it and keep using **`127.0.0.1`**.

### “`/labs/` works on `localhost` but `/` doesn’t”

Often you actually started on **`http://127.0.0.1/`** and used the **“Try /labs/”** link. That link is **relative** (`href="/labs/"`), so the browser stays on **`127.0.0.1`** — the address bar never shows **`localhost`**. Root and labs both used **IPv4**; it only *felt* like “localhost” because the path says **`labs`**.

If you **literally** type **`http://localhost/labs/`** in the bar and **`http://localhost/`** fails, that’s odd (same name should behave the same for every path). Check the bar for **`https://`** vs **`http://`**, try a private window, and note any extension that treats “localhost” specially.

### “External” browser / another computer / your phone

**`localhost` and `127.0.0.1` always mean “this device,”** not your server. A browser on your laptop never reaches Docker on an Oracle VM (or another PC) via `http://localhost`.

Use a URL that points at the **host that runs `docker compose`**:

| Where Docker runs | What to type in the browser |
|-------------------|------------------------------|
| Same Mac as the browser | Prefer **`http://127.0.0.1/`** if **`http://localhost/`** fails (IPv6 vs IPv4; see above). |
| Another machine on your LAN | `http://<that-machine-LAN-IP>/` (e.g. `http://192.168.1.42/`) |
| Oracle Cloud VM | `http://<instance-public-IP>/` (security list must allow **TCP 80** to the internet or your IP) |

On the server you can check the listening address with **`ss -tlnp | grep ':80'`** or **`curl -sS http://127.0.0.1/`** from SSH — that only proves it works **on the VM**, not from your phone.

## “Connection refused”

Means nothing is accepting TCP on the port you used:

1. **`docker compose ps`** — all three services should be **Up**. If **caddy** is **Exited**, run **`docker compose logs caddy`**.
2. **Port 80 busy** (common on macOS with AirPlay, etc.) — use an override to map **`8080:80`** and open **http://localhost:8080/** (see **`docker-compose.override.example.yml`**).
3. **Wrong URL** — if you mapped **8080:80**, **http://localhost/** hits whatever else owns 80 on the host, not Caddy.

## Layout

- **`Caddyfile`** — routing only  
- **`docker-compose.template.yml`** + **`scripts/render-compose.py`** → **`docker-compose.yml`**  
- **`sites/main/`**, **`sites/labs/`** — static files served by **basic-http**  
- **`Caddyfile.https.example`** — reference when you add TLS  

## OCI / public VM

Open **TCP 80** in the security list / NSG. Use the instance **public IP** in the browser until DNS exists.
