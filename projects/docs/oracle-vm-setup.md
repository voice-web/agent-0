# Cloud VM setup (Oracle first pass)

Goal: repeatable baseline for a fresh cloud VM so we can deploy apps quickly and undo cleanly when needed. This version uses Oracle examples, but the structure is intended to stay cloud-agnostic.

## Scope for this pass

1. Decide / create OS accounts (`opc` only vs personal user + optional `vap`) **early** — right after first SSH — so a rollback + redo picks up the same model from the top.
2. Install `git` if missing.
3. Install Docker if missing, enable it as a service so it starts after reboot.
4. Pick stable paths for checkouts and runtime data (often repos + symlinks, not hand-made trees).
5. Install OCI tools for Oracle-specific operations.

**Deferred:** `mise` / `asdf` (or any version manager) until you need pinned CLI versions on the VM.

## Cloud-agnostic framing

Think of this as `cloud-vm-setup` with provider adapters:

- Core (provider neutral): git, docker service, data paths, repo checkout, app deploy/undo (optional: version managers, dedicated OS users).
- Provider-specific (Oracle): OCI CLI, OCI network/security list terms, region/AD behavior.

Keep core steps stable across providers (OCI/AWS/GCP/Azure) and isolate provider-specific commands in dedicated sections.

## Recommended standards

- OS assumption: Oracle Linux 8/9 (adapt package commands if Ubuntu/Debian).
- Version manager: **skip until needed** (no `mise` / `asdf` decision required for Docker + compose today).
- Checkout root: `/opt/vap-src` (git clones live here).
- Optional anchor for symlinks / bind mounts: `/opt/vap-data` (can stay empty until you link repos in).
- Content (sites, etc.) lives in **repos**; point deploy or compose at them with **symlinks** (or bind mounts) instead of creating a fixed `sites/...` tree on disk by hand.
- **Hostname for this pass:** use **`worldcliques.org`** in examples (SSH and HTTP). **DNS** must have an **`A`** record pointing at the instance’s public IPv4 (or fix DNS before these commands will work).

## Step-by-step setup

### 1) SSH and update system

```bash
ssh opc@worldcliques.org
sudo dnf -y update
```

First login is always as **`opc`** (Oracle default). Do **§ 2** next if you want **`ray`** / **`vap`** in place **before** git, Docker, and paths — makes a full **undo + redo** match this order.

### 2) Accounts: `opc`, a personal user, optional `vap`

**It is not too late** to add users later, but doing it **here** keeps the runbook top-down for a clean second pass after rollback.

| Approach | When it fits |
|----------|----------------|
| **Keep using `opc` only** | Solo bootstrap: SSH as `opc`, `sudo` when needed, `opc` in **`docker`** group (add in **§ 4**). Simple and valid for a first pass. |
| **Personal user (e.g. `ray`) + sudo** | Day-to-day SSH as yourself: add user, SSH key, **`wheel`** (Oracle Linux) for **`sudo`**. Keep **`opc`** enabled as break-glass unless you have a strong reason to lock it down later. |
| **Service user `vap` (no or limited login)** | Owns **`/opt/vap-data`** for clearer permissions and future non-root services. **Docker Engine still runs as root**; you usually run **`docker compose`** as **`opc`** or **`ray`** if they are in **`docker`**. Add **`vap`** to **`docker`** only if that user will run compose. |

Example (personal user with sudo — replace `ray` and the key line):

```bash
sudo useradd -m -G wheel ray
sudo mkdir -p ~ray/.ssh
sudo bash -c 'echo "ssh-ed25519 AAAA...your-key..." >> ~ray/.ssh/authorized_keys'
sudo chown -R ray:ray ~ray/.ssh
sudo chmod 700 ~ray/.ssh
sudo chmod 600 ~ray/.ssh/authorized_keys
# After Docker is installed (§ 4):
# sudo usermod -aG docker ray
```

**Connect from your Mac as `ray@worldcliques.org`**

1. **DNS** — `worldcliques.org` must resolve to the VM (same IP as in OCI). Check: `dig +short worldcliques.org` or `ping -c1 worldcliques.org` (ICMP may still fail; that is OK if SSH works).
2. **Key pair on the Mac** — the **public** key you pasted into **`~ray/.ssh/authorized_keys`** on the server must match a **private** key on your Mac (usually `~/.ssh/id_ed25519` or `id_rsa`). If you do not have one yet: `ssh-keygen -t ed25519 -C "ray@mac"` then put the **`.pub`** line on the server as shown above.
3. **SSH** — from Terminal:

   ```bash
   ssh ray@worldcliques.org
   ```

   If the key is not the default, specify it:

   ```bash
   ssh -i ~/.ssh/id_ed25519 ray@worldcliques.org
   ```

4. **Optional — `~/.ssh/config` on the Mac** (short name, always user `ray`):

   ```text
   Host worldcliques
     HostName worldcliques.org
     User ray
     IdentityFile ~/.ssh/id_ed25519
   ```

   Then: `ssh worldcliques`

5. **First connection** — accept the host key prompt if the fingerprint looks right.

Example (service user + data dir — safe before **§ 7** because it creates the dir):

```bash
sudo useradd -r -s /sbin/nologin vap || true
sudo mkdir -p /opt/vap-data
sudo chown -R vap:vap /opt/vap-data
```

Then in **§ 7**, create **`/opt/vap-src`** and set ownership to whoever runs **`git`** / **`docker compose`** (`opc`, `ray`, or a shared group).

### 3) Install git (if needed)

```bash
command -v git || sudo dnf -y install git
git --version
```

### 4) Install Docker Engine + Compose (Oracle Linux)

**Why `dnf install docker docker-compose-plugin` often fails:** Oracle Linux default repos usually **do not** ship the **`docker-compose-plugin`** RPM, and the name **`docker`** may not be the upstream Docker Engine you expect. For the **agent-0** deploy stack, install **Docker CE** from Docker’s repo (same stack our docs use: `docker` + `docker compose`).

**4a) See major version (pick the matching repo in 4b):**

```bash
cat /etc/oracle-release
```

**4b) Add Docker CE repo and install** (try **one** path that matches your major version).

Oracle Linux **9** (typical for newer shapes):

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Oracle Linux **8**:

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

If **`docker-ce.repo`** fails (wrong `$releasever` / GPG), use the **CentOS** repo for the same major as your OL (example for **9**):

```bash
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

**4c) Enable and start the service:**

```bash
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

Optional (run **Docker** without **`sudo`** — repeat for each human user that runs **`docker compose`**, e.g. **`opc`** and **`ray`**):

```bash
sudo usermod -aG docker opc
# sudo usermod -aG docker ray
newgrp docker
```

Verify:

```bash
docker --version
docker compose version
docker ps
```

**Alternative (Oracle-default stack):** **Podman** + **`podman compose`** or **`podman-docker`** — different CLI and compose path; only choose this if you intentionally standardize on Podman. Our **`deploy-vap`** flow today assumes **Docker Engine + `docker compose`**.

### 5) (Optional) Version managers — skip until needed

**No need to install `mise` or `asdf` on the VM** until you want pinned versions of languages/CLIs there. Install one later; the choice does not block Docker or deploy.

### 6) Install OCI tools (Oracle-specific)

Install OCI CLI if this VM will be managed with Oracle tooling:

```bash
command -v oci || {
  curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh -o /tmp/oci_install.sh
  bash /tmp/oci_install.sh --accept-all-defaults
}
```

Verify:

```bash
oci --version
```

If you prefer version-managed OCI CLI on a dev machine, see `mysa/docs/OCI_CLI.md` (asdf-based); the VM can stay with the installer above until you care.

### 7) Persistent paths (repos + symlinks — no hand-built layout)

Create only the **parent directories** you will use for clones and optional symlink targets:

```bash
sudo mkdir -p /opt/vap-data /opt/vap-src
sudo chown -R opc:opc /opt/vap-data /opt/vap-src
# If you use user `ray` for deploy:   sudo chown -R ray:ray /opt/vap-src
# If `vap` owns only data:            sudo chown -R vap:vap /opt/vap-data
```

**Do not** create `sites/main`, `sites/labs`, etc. here unless you want empty placeholders. Plan is:

1. **Clone** each repo under `/opt/vap-src/…` (for example `…/agent-0`, `…/my-sites`).
2. **Symlink** from whatever path **docker compose** or **Caddy/basic-http** expects into the repo directory that actually holds the files.

Example (adjust repo names and paths to match your layout):

```bash
# After cloning agent-0 and a sites repo:
ln -sfn /opt/vap-src/my-sites/main  /opt/vap-src/agent-0/projects/deploy/sites/main
ln -sfn /opt/vap-src/my-sites/labs  /opt/vap-src/agent-0/projects/deploy/sites/labs
```

You can instead symlink **into** `/opt/vap-data/...` and point compose at those paths if you prefer a stable “data” root separate from the app repo.

**Note:** Removing `/opt/vap-src` in the undo section deletes checkouts and symlinks under it; it does **not** delete a remote repo—only local files.

### 8) Network checks

OCI security list / NSG should allow:

- TCP 22 from your IP/VPN
- TCP 80 from expected clients
- TCP 443 from expected clients (required once TLS / HTTPS is live)

### 9) (Optional) TLS with Let's Encrypt (ACME)

Use this when you want **browser-trusted HTTPS** on the VM for the **`deploy-docker` `oci-vm`** stack (Caddy on **:80** and **:443**). Caddy requests and renews **Let's Encrypt** certificates automatically; you do **not** need Certbot on the host unless you deliberately run TLS outside Caddy.

#### When this applies

- You have deployed (or will deploy) **`projects/deploy-docker`** with environment **`oci-vm`** so Caddy serves **`api.worldcliques.org`**, **`auth.worldcliques.org`**, and explicit HTML names (default **`worldcliques.org`**; add `www` or others via **`routing.html_hosts`** in **`deployments/vm-host-oci/config.json`** — see `projects/deploy-docker/DEPLOY_LOCAL.md`).
- You want **public** certificates instead of lab-only **`tls internal`** (`WC_CADDY_TLS=internal`).

#### Prerequisites

| Requirement | Why |
|-------------|-----|
| **DNS** | Every hostname Caddy advertises must have an **`A`** (and optionally **`AAAA`**) record pointing at this instance's **public** IP (or a stable load balancer that forwards **:80** / **:443** to Caddy). |
| **Reachability** | The internet (or Let's Encrypt's validation servers) must reach this host on **TCP 80** for **HTTP-01** validation. **443** must be reachable for HTTPS clients after issuance. |
| **No `tls internal` for prod** | Before running `./scripts/up.sh oci-vm infra …`, **do not** set `WC_CADDY_TLS=internal` if you want Let's Encrypt; that mode uses Caddy's internal CA instead. |
| **Contact email (recommended)** | Set `WC_CADDY_ACME_EMAIL` so the generated Caddyfile includes an ACME account email (expiry notices, account recovery). |

#### Steps (happy path — HTTP-01, one cert per name)

1. **Create DNS records** for every name you will use, for example:
   - `worldcliques.org` (apex)
   - `api.worldcliques.org`
   - `auth.worldcliques.org`
   - Any concrete subdomain you will actually open in a browser (e.g. `www.worldcliques.org`).  
   **`/etc/hosts` on your laptop is not enough** for Let's Encrypt; public DNS must resolve to this server.

2. **Confirm propagation** (from your laptop or any resolver):

   ```bash
   dig +short worldcliques.org A
   dig +short www.worldcliques.org A
   dig +short api.worldcliques.org A
   dig +short auth.worldcliques.org A
   ```

3. **Open OCI ingress** (security list / NSG) for **0.0.0.0/0** or your CDN/origin path on **TCP 80** and **TCP 443** (aligned with **§ 8**).

4. **Optional — set ACME email** before bringing up infra (so `scripts/up.sh` can embed it in the generated Caddyfile):

   ```bash
   export WC_CADDY_ACME_EMAIL='you@yourdomain.com'
   ```

5. **Start the stack** from `projects/deploy-docker` so Caddy loads the **generated** `Caddyfile` (not the lab `tls internal` variant):

   ```bash
   ./scripts/up.sh oci-vm infra application
   ```

6. **First issuance** happens when Caddy starts and negotiates ACME. If something fails, inspect Caddy logs:

   ```bash
   docker logs <caddy-container-name> 2>&1 | tail -100
   ```

   Common failures: DNS not pointing here yet, **:80** blocked, or a corporate/WAF rule blocking Let's Encrypt.

7. **Renewals** are handled by Caddy using the same **Docker volume** (`caddy_data` in the compose file). Do not delete that volume casually if you care about rate limits and continuity.

#### Wildcard `*.worldcliques.org` (optional, not in default Caddyfile)

The reference **`oci-vm`** Caddyfile uses **only explicit hostnames** (default apex + `www`) so HTTP-01 and DNS stay simple. If you later add a **`*.worldcliques.org`** site block, Let's Encrypt **wildcard** certificates require **DNS-01** validation, not HTTP-01 on **:80** alone—see [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https) and DNS modules for your DNS host.

#### Lab / staging without public DNS

If names do not resolve publicly, use **`WC_CADDY_TLS=internal`** and trust Caddy's local CA (or stay on HTTP-only testing). That path is documented in `projects/deploy-docker/DEPLOY_LOCAL.md`; it is **not** Let's Encrypt.

#### If you do not use Caddy

If TLS terminates elsewhere (load balancer, Ingress, Cloudflare “full strict” with origin certs), adjust that layer’s docs instead; this section assumes **Caddy** is the ACME client as in **`infra-oci-vm.yml`**.

## Undo / rollback (first pass)

Use this to return to a cleaner VM.

```bash
# stop and disable docker
sudo systemctl disable --now docker || true

# remove Docker CE packages (adjust list if you installed differently)
sudo dnf -y remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true

# remove docker state (destructive)
sudo rm -rf /var/lib/docker

# remove project paths (destructive)
sudo rm -rf /opt/vap-src /opt/vap-data
```

If you only want to undo app deploy but keep Docker installed, use the undo section in `deploy-vap.md`.

## Open decisions for tomorrow

- Confirm canonical checkout path, symlink conventions, and **which OS user** owns **`/opt/vap-src`** vs **`/opt/vap-data`** (`opc` only vs `ray` + optional `vap`).
- Decide script names and location for bootstrap/undo.
- Decide whether to rename this file to `cloud-vm-setup.md` now or keep Oracle naming with cloud-neutral content.

## Tomorrow discussion checklist

- [ ] Git install and verification flow finalized.
- [ ] Docker service enable/start path reboot-tested.
- [ ] Account model agreed (`opc` only vs personal user + optional `vap`).
- [ ] Persistent data paths and ownership finalized.
- [ ] Bootstrap and undo scripts agreed.
