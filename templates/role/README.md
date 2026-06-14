# Ansible role template (copier)

Generate a new role into the workspace:

```bash
copier copy gh:eyebrowkang/ansible-development roles/<namespace>.<name>
# or from a local checkout of this repo:
uv run copier copy . roles/<namespace>.<name>
```

You'll be asked for `role_name`, `namespace`, CI platform, whether to include the
vagrant scenario, etc. (see [`copier.yml`](../../copier.yml) at the repo root).

Update an existing role when this template improves:

```bash
cd roles/<namespace>.<name>
uvx copier update --trust
```

## What a generated role gets

- `pyproject.toml` — uv-managed dev toolchain (`dev` group) + optional `vagrant` group
- `molecule/default` — **Docker** scenario (fast; runs on GitHub & Forgejo)
- `molecule/vagrant` — **Vagrant+libvirt** scenario (VM-only needs; local + self-hosted Forgejo) *(optional)*
- `.github/workflows` and/or `.forgejo/workflows` — CI (+ optional GitHub release automation: release-please / Dependabot / Galaxy import)
- `Makefile` — `make test` / `make test-vm` / `make lint`
- `.pre-commit-config.yaml` (enable with `uvx pre-commit install`), `.yamllint.yml`, `.ansible-lint`, `meta/main.yml`

> This repo also generates **collections** (`-d kind=collection`) — see [`../../docs/creating-a-collection.md`](../../docs/creating-a-collection.md).

See [`../../docs/creating-a-role.md`](../../docs/creating-a-role.md) for the full workflow.
