# Ansible role template (copier)

Generate a new role into the workspace:

```bash
copier copy https://git.utlas.de/eyebrowkang/ansible-development.git roles/<namespace>.<name>
# local scaffold-dev testing only (records a non-portable _src_path: .):
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
- `molecule/default` — **Docker** scenario (fast; runs on GitHub & Forgejo) *(optional, `include_docker`)*
- `molecule/vagrant` — **Vagrant+libvirt** scenario (VM-only needs; local + self-hosted Forgejo) *(optional, `include_vagrant`; ≥1 scenario required)*
- `.github/workflows` and/or `.forgejo/workflows` — CI (+ optional GitHub release automation: release-please / Galaxy import)
- `.release-notes/`, `cliff.toml`, `scripts/render-git-cliff-notes.sh` — optional Forgejo release notes: manual Summary/Upgrade Notes + git-cliff Changes
- `renovate.json` — **Renovate** dependency updates (`dependency_updates`, replaces Dependabot; read by an external Renovate — GitHub App / self-hosted Forgejo bot)
- `Makefile` — `make test` / `make test-vm` / `make lint`
- `.pre-commit-config.yaml` (enable with `uvx pre-commit install`), `.yamllint.yml`, `.ansible-lint`, `meta/main.yml`

> This repo also generates **collections** (`-d kind=collection`) — see [`../../docs/creating-a-collection.md`](../../docs/creating-a-collection.md).

See [`../../docs/creating-a-role.md`](../../docs/creating-a-role.md) for the full workflow.
