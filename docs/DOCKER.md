# Arman VPN in Docker

The image is the Linux core: a SOCKS5 and HTTP proxy, and the web panel. It runs `arman-vpn-core -plain`. Debian is the image's system. The desktop app is not included.

A release tag `vX.Y.Z` (the same tag as the GitHub release, the version in `app/pubspec.yaml`) publishes the image. The workflow is [`.github/workflows/docker.yml`](../.github/workflows/docker.yml). Tags are `X.Y.Z`, `vX.Y.Z`, `X.Y`, `X`, and `latest`, for `linux/amd64` and `linux/arm64`. The image name is `ghcr.io/<owner>/<repository>`. The examples use `ghcr.io/armanlife/arman-vpn-client`.

## Run

```bash
docker run -d --name arman-vpn --restart unless-stopped \
  -p 10820:10820 \
  -p 127.0.0.1:10810:10810 -p 127.0.0.1:10810:10810/udp \
  -v arman-vpn:/var/lib/arman-vpn \
  ghcr.io/armanlife/arman-vpn-client:latest

docker logs arman-vpn
```

The first start runs `-setup-server` and prints a panel login and a proxy login. Later starts keep them.

- **Panel:** `http://<host>:10820/app/`
- **Proxy:** SOCKS5 or HTTP on `127.0.0.1:10810` of the machine running Docker

The panel is published on every interface. The proxy is published on localhost only.

## Data

The volume is `/var/lib/arman-vpn`, passed as `-data-dir`. It holds `config.json`, `accounts/`, and the logs. Replacing the image keeps the volume.

A systemd install keeps the same files in `/opt/arman-vpn/user-data`. Copy that directory into the volume. The container path stays `/var/lib/arman-vpn`.

## If Mozilla is blocked

The container goes to Mozilla directly. Where that is refused, the panel's
"If Mozilla is blocked" settings apply here as they do anywhere else, and
they are kept in `config.json` in the volume under `network`:

- `api_relay` - a relay of your own that carries the Guardian requests, with
  `api_relay_ech` for its name to be hidden from the network.
- `hello_split` - TLS fragmentation, for a network that filters by server
  name. `auto` tries the methods in turn.
- `upstream_proxy` - a SOCKS5 proxy the connection to Mozilla goes through.

The container has no desktop app to set these from, so set them in the panel
or edit `config.json` in the volume and restart the container.

## Build

```bash
docker build -t arman-vpn .
```

`GO_VERSION` in the Dockerfile is the `go` line of `core/go.mod`. The build stops when they differ.

```bash
docker run --rm --entrypoint arman-vpn-core arman-vpn -version
```
