# CI builder images

Pre-baked toolchain images so CI jobs don't reinstall dependencies every run.
Built and pushed by [`../../.forgejo/workflows/build-image.yml`](../../.forgejo/workflows/build-image.yml).

| Image | Dockerfile | Used by | Contents |
|-------|-----------|---------|----------|
| `ansible-builder` | `Dockerfile` | Forgejo lint + docker molecule jobs | uv + Python 3.13 + docker **client** + git/make |
| `ansible-builder-vagrant` | `Dockerfile.vagrant` | only if the libvirt runner is containerized | the above + Vagrant + QEMU + libvirt + build deps |

By default the generated roles' vagrant CI job runs **host-mode** on a `[self-hosted, libvirt]`
runner (no container), so `ansible-builder-vagrant` is optional. See `../../docs/ci-overview.md`.

## Immutable tags

The Forgejo runner config uses `force_pull: false`, so a moving `:latest` tag would go
stale. `build-image.yml` tags every build `YYYYMMDD-<short-sha>` **and** `latest`. Pin
the immutable tag in your roles' `builder_registry` answer / workflow `container.image`.

## Required Forgejo settings

- `vars.REGISTRY` — registry host, e.g. `git.example.com`
- `secrets.REGISTRY_TOKEN` — token with `package:write`

## Build locally

```bash
docker build -f images/builder/Dockerfile        -t ansible-builder:dev         images/builder
docker build -f images/builder/Dockerfile.vagrant -t ansible-builder-vagrant:dev images/builder
```
