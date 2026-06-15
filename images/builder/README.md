# CI builder images

Pre-baked toolchain images so CI jobs don't reinstall dependencies every run.
Built and pushed by [`../../.forgejo/workflows/build-image.yml`](../../.forgejo/workflows/build-image.yml).

| Image | Dockerfile | Used by | Contents |
|-------|-----------|---------|----------|
| `ansible-builder` | `Dockerfile` | Forgejo lint + docker molecule jobs | uv + Python 3.13 + docker client + git + make + node + jq + shellcheck |
| `ansible-builder-vagrant` | `Dockerfile.vagrant` | every role's (containerized) vagrant job + scaffold `smoke-role-vagrant` | the above + Vagrant + QEMU + libvirt + build deps |

`node` is included because `actions/checkout` (and other JS actions) need it in the job container.
The generated roles' vagrant CI job now runs **containerized** (`--privileged`) in
`ansible-builder-vagrant` by default, so this image is **required** for the vagrant track — not
optional. Host-mode is the alternative. See `../../docs/ci-overview.md`.

## Tags

`build-image.yml` computes tags with `docker/metadata-action`, then builds + pushes with plain
`docker build` / `docker push` — **not** `docker/build-push-action`/buildx, whose OCI manifest this
Forgejo registry rejects. Each push to `main` tags:

- `latest` (moving)
- `main` (the branch)
- `sha-<short>` — **immutable**; pin this in your roles' `builder_tag`, since the runner uses
  `force_pull: false` and a moving `:latest` would go stale. The Dockerfiles pin their base
  images by `@sha256` digest (+ a fixed `uv python` patch), so the same `sha-<short>` rebuilds
  reproducibly — the tag locks the recipe, the digests lock the product.

The registry host is derived from the instance URL (`GITHUB_SERVER_URL`), not hardcoded; images push
to `<host>/<owner>/ansible-builder[-vagrant]`.

## Forgejo settings

- The workflow sets `permissions: packages: write`.
- `secrets.REGISTRY_TOKEN` — **optional**; only needed if the instance's actions token
  (`GITHUB_TOKEN`) can't write packages. Use a PAT with `package:write`.

## Build locally

```bash
docker build -f images/builder/Dockerfile         -t ansible-builder:dev         images/builder
docker build -f images/builder/Dockerfile.vagrant -t ansible-builder-vagrant:dev images/builder
```
