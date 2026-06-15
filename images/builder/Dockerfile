# syntax=docker/dockerfile:1
# Lean CI toolchain for the docker molecule scenario (Forgejo container jobs).
# Under DooD the runner automounts the host docker socket, so only the docker
# CLIENT is needed here. Tag immutably — see .forgejo/workflows/build-image.yml.
# Bases + uv are digest-pinned so a given sha-<short> rebuilds reproducibly (tag locks
# the recipe; digests lock the product). Refresh: docker buildx imagetools inspect <img>.
FROM debian:13-slim@sha256:4e401d95de7083948053197a9c3913343cd06b706bf15eb6a0c3ccd26f436a0e

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        make \
        nodejs \
        openssh-client \
        shellcheck \
    && rm -rf /var/lib/apt/lists/*

# docker client only (talks to the host daemon via the automounted socket)
COPY --from=docker:29-cli@sha256:cdfd70216347d3cbc202a64752101dd76d11f87396749c33641eb487e2e9effc /usr/local/bin/docker /usr/local/bin/docker

# uv (pinned) provides Python and installs each role's deps from its uv.lock
COPY --from=ghcr.io/astral-sh/uv:0.11@sha256:ff07b86af50d4d9391d9daf4ff89ce427bc544f9aae87057e69a1cc0aa369946 /uv /uvx /usr/local/bin/
ENV UV_LINK_MODE=copy
RUN uv python install 3.13.14

LABEL org.opencontainers.image.title="ansible-builder"
