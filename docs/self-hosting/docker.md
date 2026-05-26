# Deploy with Docker / Podman

The easiest way to self-host Vinaros in a production environment.

> [!IMPORTANT]
> **Required Headers for Office File Conversion**
>
> LibreOffice-based tools (Word, Excel, PowerPoint conversion) require these HTTP headers for `SharedArrayBuffer` support:
>
> - `Cross-Origin-Opener-Policy: same-origin`
> - `Cross-Origin-Embedder-Policy: require-corp`
>
> The page must also be served from a secure context. `http://localhost` works for local testing, but `http://192.168.x.x` or other LAN IPs usually do not qualify, so Office conversion over plain HTTP will fail even if the headers are present.
>
> The official container images include these headers. If using a reverse proxy (Traefik, Caddy, etc.), ensure these headers are preserved or added, and use HTTPS for non-loopback access.

> [!TIP]
> **Podman Users:** All `docker` commands work with Podman by replacing `docker` with `podman` and `docker-compose` with `podman-compose`.

## Quick Start

```bash
# Docker
docker run -d \
  --name vinaros \
  -p 3000:8080 \
  --restart unless-stopped \
  ghcr.io/alam00000/vinaros:latest

# Podman
podman run -d \
  --name vinaros \
  -p 3000:8080 \
  ghcr.io/alam00000/vinaros:latest
```

## Docker Compose / Podman Compose

Create `docker-compose.yml`:

```yaml
services:
  vinaros:
    image: ghcr.io/alam00000/vinaros:latest
    container_name: vinaros
    ports:
      - '3000:8080'
    restart: unless-stopped
    healthcheck:
      test: ['CMD', 'wget', '--spider', '-q', 'http://localhost:8080']
      interval: 30s
      timeout: 10s
      retries: 3
```

Run:

```bash
# Docker Compose
docker compose up -d

# Podman Compose
podman-compose up -d
```

## Build Your Own Image

```dockerfile
# Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
```

Build and run:

```bash
docker build -t vinaros:custom .
docker run -d -p 3000:8080 vinaros:custom
```

## Environment Variables

| Variable                             | Description                                 | Default                                                        |
| ------------------------------------ | ------------------------------------------- | -------------------------------------------------------------- |
| `SIMPLE_MODE`                        | Build without LibreOffice tools             | `false`                                                        |
| `BASE_URL`                           | Deploy to subdirectory                      | `/`                                                            |
| `VITE_WASM_PYMUPDF_URL`              | PyMuPDF WASM module URL                     | `https://cdn.jsdelivr.net/npm/@vinaros/pymupdf-wasm@0.11.16/` |
| `VITE_WASM_GS_URL`                   | Ghostscript WASM module URL                 | `https://cdn.jsdelivr.net/npm/@vinaros/gs-wasm/assets/`       |
| `VITE_WASM_CPDF_URL`                 | CoherentPDF WASM module URL                 | `https://cdn.jsdelivr.net/npm/coherentpdf/dist/`               |
| `VITE_TESSERACT_WORKER_URL`          | OCR worker script URL                       | _(empty; use Tesseract.js default CDN)_                        |
| `VITE_TESSERACT_CORE_URL`            | OCR core runtime directory                  | _(empty; use Tesseract.js default CDN)_                        |
| `VITE_TESSERACT_LANG_URL`            | OCR traineddata directory                   | _(empty; use Tesseract.js default CDN)_                        |
| `VITE_TESSERACT_AVAILABLE_LANGUAGES` | Comma-separated OCR languages exposed in UI | _(empty; show full catalog)_                                   |
| `VITE_OCR_FONT_BASE_URL`             | OCR text-layer font directory               | _(empty; use remote Noto font URLs)_                           |
| `VITE_DEFAULT_LANGUAGE`              | Default UI language                         | `en`                                                           |
| `VITE_BRAND_NAME`                    | Custom brand name                           | `Vinaros`                                                     |
| `VITE_BRAND_LOGO`                    | Logo path relative to `public/`             | `images/favicon-no-bg.svg`                                     |
| `VITE_FOOTER_TEXT`                   | Custom footer/copyright text                | `© 2026 Vinaros. All rights reserved.`                        |

WASM module URLs are pre-configured with CDN defaults — all advanced features work out of the box. Override these for air-gapped or self-hosted deployments.

For OCR, leave the `VITE_TESSERACT_*` variables empty to use the default online assets, or set all three together for self-hosted/offline OCR. Partial OCR overrides are rejected because the worker, core runtime, and traineddata directory must match. For fully offline searchable PDF output, also set `VITE_OCR_FONT_BASE_URL` so the OCR text-layer fonts are loaded from your internal server instead of the public Noto font URLs.

`VITE_DEFAULT_LANGUAGE` sets the UI language for first-time visitors. Supported values: `en`, `ar`, `be`, `fr`, `de`, `es`, `zh`, `zh-TW`, `vi`, `tr`, `id`, `it`, `pt`, `nl`, `da`. Users can still switch languages — this only changes the default.

Example:

```bash
# Build with French as the default language
docker build --build-arg VITE_DEFAULT_LANGUAGE=fr -t vinaros .
docker run -d -p 3000:8080 vinaros
```

### Custom Branding

Replace the default Vinaros logo, name, and footer text with your own. Place your logo file in the `public/` folder (or use an existing image), then pass the branding variables at build time:

```bash
docker build \
  --build-arg VITE_BRAND_NAME="AcmePDF" \
  --build-arg VITE_BRAND_LOGO="images/acme-logo.svg" \
  --build-arg VITE_FOOTER_TEXT="© 2026 Acme Corp. Internal use only." \
  -t acmepdf .
```

Branding works in both full mode and Simple Mode, and can be combined with all other build-time options.

### Custom WASM URLs (Air-Gapped / Self-Hosted)

> [!IMPORTANT]
> WASM URLs are baked into the JavaScript at **build time**. The WASM files are downloaded by the **user's browser** at runtime — Docker does not download them during the build. For air-gapped networks, you must host the WASM files on an internal server that browsers can reach.

**Full air-gapped workflow:**

```bash
# 1. On a machine WITH internet — download WASM packages
bash scripts/prepare-airgap.sh --list-ocr-languages
bash scripts/prepare-airgap.sh --search-ocr-language german

# 2. Download WASM/OCR packages
npm pack @vinaros/pymupdf-wasm@0.11.14
npm pack @vinaros/gs-wasm
npm pack coherentpdf
npm pack tesseract.js@7.0.0
npm pack tesseract.js-core@7.0.0
mkdir -p tesseract-langdata
curl -fsSL https://cdn.jsdelivr.net/npm/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz -o tesseract-langdata/eng.traineddata.gz
mkdir -p ocr-fonts
curl -fsSL https://raw.githack.com/googlefonts/noto-fonts/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf -o ocr-fonts/NotoSans-Regular.ttf

# 3. Build the image with your internal server URLs
docker build \
  --build-arg VITE_WASM_PYMUPDF_URL=https://internal-server.example.com/wasm/pymupdf/ \
  --build-arg VITE_WASM_GS_URL=https://internal-server.example.com/wasm/gs/ \
  --build-arg VITE_WASM_CPDF_URL=https://internal-server.example.com/wasm/cpdf/ \
  --build-arg VITE_TESSERACT_WORKER_URL=https://internal-server.example.com/wasm/ocr/worker.min.js \
  --build-arg VITE_TESSERACT_CORE_URL=https://internal-server.example.com/wasm/ocr/core \
  --build-arg VITE_TESSERACT_LANG_URL=https://internal-server.example.com/wasm/ocr/lang-data \
  --build-arg VITE_TESSERACT_AVAILABLE_LANGUAGES=eng,deu \
  --build-arg VITE_OCR_FONT_BASE_URL=https://internal-server.example.com/wasm/ocr/fonts \
  -t vinaros .

# 4. Export the image
docker save vinaros -o vinaros.tar

# 5. Transfer vinaros.tar + the .tgz packages + tesseract-langdata/ + ocr-fonts/ into the air-gapped network

# 6. Inside the air-gapped network — load and run
docker load -i vinaros.tar

# Extract WASM packages to your internal web server
mkdir -p /var/www/wasm/pymupdf /var/www/wasm/gs /var/www/wasm/cpdf /var/www/wasm/ocr/core /var/www/wasm/ocr/lang-data /var/www/wasm/ocr/fonts
tar xzf vinaros-pymupdf-wasm-0.11.14.tgz -C /var/www/wasm/pymupdf --strip-components=1
tar xzf vinaros-gs-wasm-*.tgz -C /var/www/wasm/gs --strip-components=1
tar xzf coherentpdf-*.tgz -C /var/www/wasm/cpdf --strip-components=1
TEMP_TESS=$(mktemp -d)
tar xzf tesseract.js-7.0.0.tgz -C "$TEMP_TESS"
cp "$TEMP_TESS/package/dist/worker.min.js" /var/www/wasm/ocr/worker.min.js
rm -rf "$TEMP_TESS"
tar xzf tesseract.js-core-7.0.0.tgz -C /var/www/wasm/ocr/core --strip-components=1
cp ./tesseract-langdata/*.traineddata.gz /var/www/wasm/ocr/lang-data/
cp ./ocr-fonts/* /var/www/wasm/ocr/fonts/

# Run Vinaros
docker run -d -p 3000:8080 --restart unless-stopped vinaros
```

Use the codes printed by `bash scripts/prepare-airgap.sh --list-ocr-languages`, or search by name with `bash scripts/prepare-airgap.sh --search-ocr-language <term>`, for `--ocr-languages`. When you build with a restricted OCR subset, pass the same codes to `VITE_TESSERACT_AVAILABLE_LANGUAGES` so the app only shows bundled languages. For full offline OCR output, also host the bundled `ocr-fonts/` directory and point `VITE_OCR_FONT_BASE_URL` at it.

Set a variable to empty string to disable that module (users must configure manually via Advanced Settings).

## Custom User ID (PUID/PGID)

For environments that require running as a specific non-root user (NAS devices, Kubernetes with security contexts, organizational policies), Vinaros provides a separate Dockerfile with LSIO-style PUID/PGID support.

### Build and Run

```bash
# Build the non-root image
docker build -f Dockerfile.nonroot -t vinaros-nonroot .

# Run with custom UID/GID
docker run -d \
  --name vinaros \
  -p 3000:8080 \
  -e PUID=1000 \
  -e PGID=1000 \
  --restart unless-stopped \
  vinaros-nonroot
```

### Environment Variables

| Variable       | Description           | Default |
| -------------- | --------------------- | ------- |
| `PUID`         | User ID to run as     | `1000`  |
| `PGID`         | Group ID to run as    | `1000`  |
| `DISABLE_IPV6` | Disable IPv6 listener | `false` |

### Docker Compose

```yaml
services:
  vinaros:
    build:
      context: .
      dockerfile: Dockerfile.nonroot
    container_name: vinaros
    ports:
      - '3000:8080'
    environment:
      - PUID=1000
      - PGID=1000
    restart: unless-stopped
```

### How It Works

The container starts as root, creates a user with the specified PUID/PGID, adjusts ownership on all writable directories, then drops privileges using `su-exec`. The nginx process runs entirely as your specified user.

> [!NOTE]
> The standard `Dockerfile` uses `nginx-unprivileged` (UID 101) and is recommended for most deployments. Use `Dockerfile.nonroot` only when you need a specific UID/GID.

> [!WARNING]
> PUID/PGID cannot be `0` (root). The entrypoint validates inputs and will exit with an error for invalid values.

## With Traefik (Reverse Proxy)

```yaml
services:
  traefik:
    image: traefik:v2.10
    command:
      - '--providers.docker=true'
      - '--entrypoints.web.address=:80'
      - '--entrypoints.websecure.address=:443'
      - '--certificatesresolvers.letsencrypt.acme.email=you@example.com'
      - '--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json'
      - '--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web'
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

  vinaros:
    image: ghcr.io/alam00000/vinaros:latest
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.vinaros.rule=Host(`pdf.example.com`)'
      - 'traefik.http.routers.vinaros.entrypoints=websecure'
      - 'traefik.http.routers.vinaros.tls.certresolver=letsencrypt'
      - 'traefik.http.services.vinaros.loadbalancer.server.port=8080'
      # Required headers for SharedArrayBuffer (LibreOffice WASM)
      - 'traefik.http.routers.vinaros.middlewares=vinaros-headers'
      - 'traefik.http.middlewares.vinaros-headers.headers.customresponseheaders.Cross-Origin-Opener-Policy=same-origin'
      - 'traefik.http.middlewares.vinaros-headers.headers.customresponseheaders.Cross-Origin-Embedder-Policy=require-corp'
    restart: unless-stopped
```

## With Caddy (Reverse Proxy)

```yaml
services:
  caddy:
    image: caddy:2
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data

  vinaros:
    image: ghcr.io/alam00000/vinaros:latest
    restart: unless-stopped

volumes:
  caddy_data:
```

Caddyfile:

```
pdf.example.com {
    reverse_proxy vinaros:8080
    header Cross-Origin-Opener-Policy "same-origin"
    header Cross-Origin-Embedder-Policy "require-corp"
}
```

## Resource Limits

```yaml
services:
  vinaros:
    image: ghcr.io/alam00000/vinaros:latest
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
```

## Podman Quadlet (Systemd Integration)

[Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) allows you to run Podman containers as systemd services. This is ideal for production deployments on Linux systems.

### Basic Quadlet Setup

Create a container unit file at `~/.config/containers/systemd/vinaros.container` (user) or `/etc/containers/systemd/vinaros.container` (system):

```ini
[Unit]
Description=Vinaros - Privacy-first PDF toolkit
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/alam00000/vinaros:latest
ContainerName=vinaros
PublishPort=3000:8080
AutoUpdate=registry

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

### Enable and Start

```bash
# Reload systemd to detect new unit
systemctl --user daemon-reload

# Start the service
systemctl --user start vinaros

# Enable on boot
systemctl --user enable vinaros

# Check status
systemctl --user status vinaros

# View logs
journalctl --user -u vinaros -f
```

> [!TIP]
> For system-wide deployment, use `systemctl` without `--user` flag and place the file in `/etc/containers/systemd/`.

### Simple Mode Quadlet

For Simple Mode deployment, create `vinaros-simple.container`:

```ini
[Unit]
Description=Vinaros Simple Mode - Clean PDF toolkit
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/alam00000/vinaros-simple:latest
ContainerName=vinaros-simple
PublishPort=3000:8080
AutoUpdate=registry

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

### Quadlet with Health Check

```ini
[Unit]
Description=Vinaros with health monitoring
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/alam00000/vinaros:latest
ContainerName=vinaros
PublishPort=3000:8080
AutoUpdate=registry
HealthCmd=wget --spider -q http://localhost:8080 || exit 1
HealthInterval=30s
HealthTimeout=10s
HealthRetries=3

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

### Auto-Update with Quadlet

Podman can automatically update containers when new images are available:

```bash
# Enable auto-update timer
systemctl --user enable --now podman-auto-update.timer

# Check for updates manually
podman auto-update

# Dry run (check without updating)
podman auto-update --dry-run
```

### Quadlet Network Configuration

For custom network configuration, create a network file `vinaros.network`:

```ini
[Network]
Subnet=10.89.0.0/24
Gateway=10.89.0.1
```

Then reference it in your container file:

```ini
[Container]
Image=ghcr.io/alam00000/vinaros:latest
ContainerName=vinaros
PublishPort=3000:8080
Network=vinaros.network
```

## Updating

```bash
# Pull latest image
docker compose pull

# Recreate container
docker compose up -d
```
