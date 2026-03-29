# Colima on Mac

Colima runs containers on macOS (and Linux) with **no GUI**—CLI only. It provides a lightweight VM and the `docker` (or `kubectl`) CLI so you can run Docker images without Docker Desktop.

---

## 1. Install (Mac)

**Prerequisites:** Homebrew.

```bash
brew install colima docker
```

That installs both Colima and the Docker CLI. No asdf plugin exists for Colima; Homebrew is the standard way.

---

## 2. Use Colima

| Command | Description |
|--------|-------------|
| `colima start` | Start the Colima VM and Docker context. Do this once per session (or after reboot). |
| `colima stop` | Stop the VM. |
| `colima status` | Show whether Colima is running. |
| `colima delete` | Remove the VM and its data (images, containers, volumes). |

After `colima start`, use `docker` as usual:

```bash
docker run hello-world
docker images
docker ps
```

---

## 3. Create a Docker image

You build an image from a **Dockerfile** in a directory.

**Example Dockerfile** (e.g. in your project root):

```dockerfile
FROM alpine:3.19
RUN apk add --no-cache curl
CMD ["curl", "--version"]
```

**Build and tag the image:**

```bash
# From the directory that contains the Dockerfile
docker build -t my-image:latest .

# Or with a specific Dockerfile path
docker build -t my-image:1.0 -f path/to/Dockerfile .
```

- `-t my-image:latest` names the image and (optionally) a tag.
- `.` is the build context (current directory); the Dockerfile is usually named `Dockerfile` in that directory.

The new image appears in `docker images` as `my-image` with tag `latest`.

---

## 4. Run a local image

Once an image exists locally (built or pulled), run it with `docker run`:

```bash
# By name and tag
docker run --rm my-image:latest

# By image ID (from docker images)
docker run --rm <image_id>

# Interactive shell
docker run -it my-image:latest sh

# Map port and run in background
docker run -d -p 3000:8080 --name my-container my-image:latest
```

- `--rm` removes the container when it exits.
- `-it` gives you an interactive TTY (e.g. shell).
- `-d` runs in the background; `-p 3000:8080` maps host port 3000 to container port 8080.

You do **not** need the internet to run an image that is already on your machine.

---

## 5. Offline use: images are local

**Once an image is downloaded (e.g. `docker pull`) or built (`docker build`), you can run it with no network.** Colima/Docker use the copy on your machine.

**Where are local images stored?**

- With Colima, images live **inside the Colima Linux VM** (on a virtual disk Colima manages), not in a plain folder on your Mac.
- You don’t need to browse that disk directly. Use the CLI:
  - **List images:** `docker images`
  - **Inspect:** `docker image inspect <name-or-id>`
- Colima’s data (including images and volumes) is under Colima’s own storage; exact path depends on the Colima version and can be inspected with `colima status` or the Colima docs. The important point: **they are stored locally**, and after `colima start` you can run them offline.

**Summary:** Pull or build once (with internet if needed). After that, `colima start` and `docker run <your-image>` work without being connected to the internet.

---

## 6. Disk space: the Colima VM can run out

Images, containers, and volumes all live inside the Colima VM on a **fixed-size virtual disk**. If you pull or build a lot, you can run out of space.

**See what’s using space**

```bash
docker system df
```

Shows space used by images, containers, and volumes. You can also run `colima status`; some setups report VM disk usage there.

**Free space**

| Command | What it does |
|--------|----------------|
| `docker image prune` | Remove dangling (untagged) images. |
| `docker image prune -a` | Remove all images not used by a container. |
| `docker container prune` | Remove stopped containers. |
| `docker volume prune` | Remove unused volumes. |
| `docker system prune -a` | Remove all unused images, containers, networks. Add `--volumes` to include volumes (only if you don’t need that data). |

**Give the VM more disk**

The VM disk size is set when Colima creates the VM. To use a larger disk (e.g. 60 GB):

```bash
colima stop
colima delete
colima start --disk 60
```

Then re-pull or re-build the images you need (or restore from backup). There is no in-place resize; you recreate the VM with a new size.
