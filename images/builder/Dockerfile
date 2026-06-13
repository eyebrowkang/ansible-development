# syntax=docker/dockerfile:1
# Lean CI toolchain for the docker molecule scenario (Forgejo container jobs).
# Under DooD the runner automounts the host docker socket, so only the docker
# CLIENT is needed here. Tag immutably — see .forgejo/workflows/build-image.yml.
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        make \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# docker client only (talks to the host daemon via the automounted socket)
COPY --from=docker:cli /usr/local/bin/docker /usr/local/bin/docker

# uv (pinned) provides Python and installs each role's deps from its uv.lock
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /uvx /usr/local/bin/
ENV UV_LINK_MODE=copy
RUN uv python install 3.13

LABEL org.opencontainers.image.title="ansible-builder"
