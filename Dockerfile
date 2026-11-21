# Headless Arman VPN: the Linux core (SOCKS5 and HTTP proxy, and the web
# panel). The version baked into the binary is app/pubspec.yaml, the same
# "major.minor.patch" a release tag vX.Y.Z must name.

ARG GO_VERSION=1.27.2
# build compiles the core from these sources. prebuilt takes a core built
# outside, from docker-prebuilt/linux-<arch>/arman-vpn-core: the release
# workflow does that when it builds with its optional build profile, the
# same core the Linux release packages carry.
ARG CORE=build

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-bookworm AS build

ARG GO_VERSION
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG VERSION=

WORKDIR /src
COPY core/go.mod core/go.sum core/
WORKDIR /src/core
RUN set -eu \
    && goversion="$(awk '/^go / { print $2; exit }' go.mod)" \
    && if [ "$goversion" != "$GO_VERSION" ]; then \
         echo "Dockerfile GO_VERSION is ${GO_VERSION} but core/go.mod says ${goversion}" >&2; \
         exit 1; \
       fi \
    && go mod download

COPY core/ /src/core/
COPY app/pubspec.yaml /src/app/pubspec.yaml

RUN set -eu \
    && version="$VERSION" \
    && if [ -z "$version" ]; then \
         version="$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' /src/app/pubspec.yaml)"; \
       fi \
    && test -n "$version" \
    && goarch="${TARGETARCH:-$(go env GOARCH)}" \
    && goarm="" \
    && if [ "$goarch" = "arm" ]; then \
         case "$TARGETVARIANT" in \
           v6) goarm=6 ;; \
           *) goarm=7 ;; \
         esac; \
       fi \
    && export CGO_ENABLED=0 GOOS="${TARGETOS:-linux}" GOARCH="$goarch" \
    && if [ -n "$goarm" ]; then export GOARM="$goarm"; fi \
    && flags="-s -w -X github.com/armanlife/arman-vpn-client/core/internal/version.Current=${version}" \
    && go build -trimpath -ldflags "$flags" -o /out/arman-vpn-core ./cmd/arman-vpn-core

FROM scratch AS prebuilt
ARG TARGETARCH
COPY docker-prebuilt/linux-${TARGETARCH}/arman-vpn-core /out/arman-vpn-core

FROM ${CORE} AS core

FROM debian:bookworm-slim

ARG VERSION=0.0.0
ARG SOURCE=https://github.com/armanlife/arman-vpn-client

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/arman-vpn

COPY --from=core /out/arman-vpn-core /usr/local/bin/arman-vpn-core
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint
COPY LICENSE /usr/local/share/arman-vpn/LICENSE
RUN chmod 755 /usr/local/bin/arman-vpn-core /usr/local/bin/docker-entrypoint

VOLUME ["/var/lib/arman-vpn"]
EXPOSE 10820/tcp 10810/tcp 10810/udp

LABEL org.opencontainers.image.title="Arman VPN" \
      org.opencontainers.image.description="Headless Arman VPN core: a SOCKS5 and HTTP proxy and the web panel" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.source="${SOURCE}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.documentation="${SOURCE}/blob/main/docs/DOCKER.md"

ENV TZ=UTC
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
