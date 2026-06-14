# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **meta-repo / scaffold** for developing Ansible roles — not a role or distributable package itself (`pyproject.toml` has `package = false`, no dependencies). It holds three things only:

- `templates/role/` — a **copier** template that generates self-contained Ansible roles
- `images/builder/` — CI builder images (pre-baked toolchain pushed to a Forgejo registry)
- `docs/` — workflow docs (in Chinese; so is `README.md`)

The dependency contract lives in each **generated role**, not here: every role gets its own `pyproject.toml` + `uv.lock`. `roles/` and `collections/` are thin workspace dirs whose contents are gitignored — each role you generate there is meant to become its own independent git repo.

Tooling is **uv** throughout (it replaced an older conda scaffold, archived at git tag `archive/conda-scaffold-v0`).

## Commands

### Working on the scaffold itself
```bash
uv sync                                        # install scaffold tooling (copier, pre-commit)
uv run copier copy . roles/<namespace>.<name>  # generate a role from the local template
```
There is no test suite for the scaffold. To test template changes, generate a role and run its molecule scenarios (below). Builder images are built by CI (`.forgejo/workflows/build-image.yml`) on push to `images/builder/**`, not locally.

### The generated-role workflow (run inside `roles/<namespace>.<name>/`)
```bash
git init && git add -A && git commit -m "init"   # REQUIRED before molecule — see gotcha below
uv sync                  # dev toolchain;  uv sync --group vagrant  to add the VM track
make test                # docker scenario  (= uv run molecule test)
make test-vm             # vagrant scenario — use this, NOT `molecule test -s vagrant` (see #301)
make lint                # yamllint + ansible-lint
make converge / destroy  # iterate on the docker instance
uv run copier update --trust   # pull template improvements back into an existing role
```
Molecule has no "single test" — drive individual steps with `molecule converge` / `molecule verify` / `molecule idempotence` instead of the full `test` sequence.

## copier templating

The template root is `templates/role/template/` (`_subdirectory` in `copier.yml`). Editing it requires knowing copier's conventions:

- **`.jinja` suffix is stripped on render** (`_templates_suffix`). Files *with* it are templated (`Makefile.jinja` → `Makefile`); files *without* it are copied verbatim (e.g. `create.yml`, `destroy.yml`, `.ansible-lint`, `defaults/main.yml`).
- **Conditional directories** are encoded in the *directory name* via Jinja, e.g. `{% if include_vagrant %}vagrant{% endif %}/`, `{% if ci_platform in ['forgejo','both'] %}.forgejo{% endif %}/`, `{% if shell_templates %}tests{% endif %}/`. When the condition is false the dir renders to an empty name and is skipped. Don't rename these casually.
- All template questions live in `copier.yml`. `.copier-answers.yml` (in each role) records the answers + template version; `copier update` uses it for a three-way merge — this backfill ability is the whole reason copier is used over cookiecutter.

## Two-track molecule testing

Generated roles ship two scenarios with a deliberate split:

- **`molecule/default` (docker)** — fast; runs everywhere (local, GitHub, Forgejo). It uses molecule's **built-in `default` (delegated) driver plus hand-written `create.yml`/`destroy.yml`** driving `community.docker`. This intentionally avoids `molecule-plugins[docker]`, whose `create.yml` crashes on ansible-core 2.21 (the data-tagging change in 2.19+). Don't "simplify" it back to the plugin.
- **`molecule/vagrant`** — real VMs (kernel modules, reboot, real networking). Uses `molecule-plugins[vagrant]` (no native alternative exists).

**molecule-plugins#301 (vagrant):** the `vagrant` module isn't on Ansible's default search path, so a bare `molecule test -s vagrant` fails to resolve it. The role's `Makefile` `test-vm` target works around this by computing the package paths at runtime and exporting `ANSIBLE_LIBRARY` / `ANSIBLE_FILTER_PLUGINS`. Always run the vagrant track via `make test-vm`. See `docs/molecule-301-workaround.md`.

## CI architecture

Roles get CI for two platforms (chosen by the `ci_platform` answer):

- **GitHub Actions** (`.github/workflows/ci.yml`) — public `ubuntu-latest`, docker scenario only (no reliable KVM), uses `setup-uv`.
- **Forgejo Actions** (`.forgejo/workflows/{lint,molecule}.yml`) — self-hosted; runs lint + docker in a **builder-image container job**, and the vagrant scenario on a `[self-hosted, libvirt]` host-mode runner.

**Builder images** (`images/builder/`): `ansible-builder` is lean (only the docker *client* — under the runner's DooD setup the host docker socket is automounted, so molecule creates instances on the host daemon as siblings); `ansible-builder-vagrant` adds the full QEMU/libvirt/Vagrant stack. Two hard constraints when touching `build-image.yml`:

- **Push with plain `docker build`/`docker push`, not buildx.** buildx emits an OCI manifest that this Forgejo registry rejects (`failed to push ... unknown`); plain docker emits a schema2 manifest it accepts.
- **Pin immutable tags** (`type=sha`, e.g. `sha-ab12cd3`) in roles' `builder_tag`, never `latest` — the Forgejo runner uses `force_pull: false`, so a re-pushed `:latest` is never re-pulled.

The self-hosted Forgejo runner is `automount` + `privileged` = **zero isolation** (host root is exposed to the workflow). Only run trusted code on it; public/fork PRs belong on the sandboxed GitHub runners. See `docs/ci-overview.md`.

## The git-init gotcha

A freshly generated role **must be `git init`'d before molecule will work**. The scaffold's `.gitignore` ignores all of `roles/*` and `collections/*`; molecule/ansible-compat collects role files via git, so until the role is its *own* git repo it can't discover its scenarios and fails with `'molecule/<scenario>/molecule.yml' glob failed`. This is also a precondition for `copier update`. `copier.yml`'s `_message_after_copy` reminds the user of this after generation.
