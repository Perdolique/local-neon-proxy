# syntax=docker/dockerfile:1.7
# hadolint global ignore=DL3008

ARG NEON_RELEASE_TAG=release-proxy-8853

FROM rust:bookworm AS rust-builder
ARG NEON_RELEASE_TAG

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
  apt-get update -qq \
  && apt-get install -qq --no-install-recommends -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-confdef \
  build-essential \
  git \
  libssl-dev \
  pkg-config \
  && apt-get clean -qq && rm -rf /var/lib/apt/lists/*

# get and build the proxy
RUN git clone --depth=1 --filter=blob:none --branch "$NEON_RELEASE_TAG" https://github.com/neondatabase/neon.git
WORKDIR /neon
RUN --mount=type=cache,target=/usr/local/cargo/git \
  --mount=type=cache,target=/usr/local/cargo/registry \
  cargo build --locked --release --bin proxy --features "testing"


FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN \
  apt-get update -qq \
  && apt-get install -qq --no-install-recommends -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-confdef \
  apt-transport-https \
  ca-certificates \
  curl \
  debian-archive-keyring \
  debian-keyring \
  gnupg \
  openssl \
  postgresql-client \
  tini \
  && curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
  && curl -fsSL 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' -o /etc/apt/sources.list.d/caddy-stable.list \
  && apt-get update -qq \
  && apt-get install -qq --no-install-recommends -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-confdef \
  caddy \
  && useradd --create-home --home-dir /home/app --shell /usr/sbin/nologin app \
  && mkdir -p /app /home/app/.config/caddy /home/app/.local/share/caddy \
  && chown -R app:app /app /home/app \
  && apt-get clean -qq && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=rust-builder --chown=app:app --chmod=755 /neon/target/release/proxy /app/neon-proxy
COPY --chown=app:app Caddyfile /app/Caddyfile
COPY --chown=app:app --chmod=755 start.sh /app/start.sh

ENV HOME=/home/app
USER app

EXPOSE 4444
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD bash -ec 'exec 3<>/dev/tcp/127.0.0.1/4444 && exec 4<>/dev/tcp/127.0.0.1/4445'
ENTRYPOINT ["/usr/bin/tini", "--", "./start.sh"]
