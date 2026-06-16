# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **meta-repo / scaffold** for developing Ansible **roles and collections** — not a role/collection or distributable package itself (`pyproject.toml` has `package = false`, no dependencies). It holds:

- `templates/role/` — a **copier** template for a self-contained Ansible role (`kind=role`)
- `templates/collection/` — copier template for a roles-only Ansible collection (`kind=collection`)
- `images/builder/` — CI builder images (pre-baked toolchain pushed to a Forgejo registry)
- `docs/` — workflow docs (in Chinese; so is `README.md`)

`copier.yml`'s `kind` question drives `_subdirectory: templates/{{ kind }}/template`, so one entry point generates either. The dependency contract lives in each **generated artifact**, not here: each gets its own `pyproject.toml` + `uv.lock`. `roles/` and `collections/` are thin workspace dirs whose contents are gitignored — each artifact you generate there becomes its own independent git repo.

Tooling is **uv** throughout (it replaced an older conda scaffold, archived at git tag `archive/conda-scaffold-v0`).

## Commands

### Working on the scaffold itself
```bash
uv sync                                        # install scaffold tooling (copier)
uv run copier copy . roles/<ns>.<name>                               # generate a role (kind defaults to role)
uv run copier copy . collections/ansible_collections/<ns>/<name> -d kind=collection   # generate a collection
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

Two template subtrees — `templates/role/template/` and `templates/collection/template/` — selected by `_subdirectory: templates/{{ kind }}/template`. Editing them requires copier's conventions:

- **`.jinja` suffix is stripped on render** (`_templates_suffix`). Files *with* it are templated (`Makefile.jinja` → `Makefile`); files *without* are copied verbatim (`create.yml`, `destroy.yml`, `.ansible-lint`, and the static GitHub-Actions files whose `${{ }}` must survive copier).
- **Conditional paths** are Jinja in the *path name* — both directories (`{% if include_vagrant %}vagrant{% endif %}/`, `{% if ci_platform in ['forgejo','both'] %}.forgejo{% endif %}/`) and individual files (the role release bundle: `{% if release_automation %}release-please-config.json{% endif %}`). A path that renders empty is skipped. Don't rename these casually.
- **Questions** (`copier.yml`): `kind` first, then shared (namespace, license, `ci_platform`, …), then role-only / collection-only ones gated `when: "{{ kind == 'role' }}"` etc. A `when`-skipped question still gets its computed default in the render context, so `{% if release_automation %}` is safe even on a forgejo role.
- `.copier-answers.yml` records answers + template version; `copier update` three-way-merges from it — the backfill ability that's the whole reason for copier over cookiecutter.

## Two-track molecule testing

Generated roles ship two scenarios with a deliberate split:

- **`molecule/default` (docker)** — fast; runs everywhere (local, GitHub, Forgejo). It uses molecule's **built-in `default` (delegated) driver plus hand-written `create.yml`/`destroy.yml`** driving `community.docker`. This intentionally avoids `molecule-plugins[docker]`, whose `create.yml` crashes on ansible-core 2.21 (the data-tagging change in 2.19+). Don't "simplify" it back to the plugin.
- **`molecule/vagrant`** — real VMs (kernel modules, reboot, real networking). Uses `molecule-plugins[vagrant]` (no native alternative exists).

**molecule-plugins#301 (vagrant):** the `vagrant` module isn't on Ansible's default search path, so a bare `molecule test -s vagrant` fails to resolve it. The role's `Makefile` `test-vm` target works around this by computing the package paths at runtime and exporting `ANSIBLE_LIBRARY` / `ANSIBLE_FILTER_PLUGINS`. Always run the vagrant track via `make test-vm`. See `docs/molecule-301-workaround.md`.

## Collections (`templates/collection/template/`)

Roles-only collections (matching the user's `bootstrap` collection). Key differences from roles:

- **Generate into `collections/ansible_collections/<ns>/<name>/`** — `ansible-test` derives namespace/name from the path, not `galaxy.yml`; a wrong path fails sanity outright. CI checks out under that path (`actions/checkout` `path:`).
- **`make sanity` = `ansible-test sanity --venv`** (not `--docker`): `--docker` bind-mounts into a sibling container, which under the Forgejo DooD runner misses the checked-out collection. `--venv` needs no docker.
- **molecule lives at `extensions/molecule/`** (molecule's collection location), not inside `roles/example/` — else its `create.yml` vars trip ansible-lint's `var-naming[no-role-prefix]`. The example role resolves by short name via `ANSIBLE_ROLES_PATH=${MOLECULE_PROJECT_DIRECTORY}/roles` set in `molecule.yml`.
- production `ansible-lint` requires `galaxy.yml` to carry `repository` + a Galaxy namespace tag, a `CHANGELOG.md`, and `requires_ansible` as full `X.Y.Z` — the template ships all three.

See `docs/creating-a-collection.md`.

## CI architecture

Roles get CI for two platforms (chosen by the `ci_platform` answer):

- **GitHub Actions** (`.github/workflows/ci.yml`) — public `ubuntu-latest`, docker scenario only (no reliable KVM), uses `setup-uv`.
- **Forgejo Actions** (`.forgejo/workflows/{lint,molecule}.yml`) — self-hosted; runs lint + docker in a **builder-image container job**, and the vagrant scenario **containerized** (`ansible-builder-vagrant`, libvirtd started in-job under a `tini -s` subreaper) on a **privileged** `[self-hosted, kvm]` runner. Host-mode is the documented alternative.

**Forgejo Actions ≈ GitHub Actions, with caveats we've hit** (see `docs/ci-overview.md`): `container.options` only honors `--volume`/`--tmpfs`/`--hostname`/`--memory` — `--privileged`/`--init`/`--device` are **silently ignored**, so set privilege/devices in the **runner config**, not the job (that's why the vagrant track reaps qemu via an in-job `tini -s` subreaper instead of `--init`, and gets `/dev/kvm` from the privileged runner). `uses:` resolves relative actions via `DEFAULT_ACTIONS_URL`. The `github.*` context and `GITHUB_*` env are aliases of `forgejo.*`/`FORGEJO_*`; `github.event.repository.default_branch` / `pull_request.base.sha` may be absent (workflows fall back). Don't combine `push` `tags` with `paths`/`branches` — use a separate workflow (that's why builder image releases live in `release-image.yml`, not `build-image.yml`).

**Builder images** (`images/builder/`): `ansible-builder` is lean (only the docker *client* — under the runner's DooD setup the host docker socket is automounted, so molecule creates instances on the host daemon as siblings); `ansible-builder-vagrant` adds the full QEMU/libvirt/Vagrant stack and is now **required** (the role vagrant job runs in it by default). Base images (debian/docker-cli/uv) are pinned by `@sha256` digest + a fixed `uv python` patch, so a given `sha-<short>` rebuilds reproducibly (tag locks the recipe, digests lock the product); refresh with `docker buildx imagetools inspect <img>`. Two hard constraints when touching `build-image.yml`:

- **Push with plain `docker build`/`docker push`, not buildx.** buildx emits an OCI manifest that this Forgejo registry rejects (`failed to push ... unknown`); plain docker emits a schema2 manifest it accepts.
- **Pin immutable tags** (`type=sha`, e.g. `sha-ab12cd3`) in roles' `builder_tag`, never `latest` — the Forgejo runner uses `force_pull: false`, so a re-pushed `:latest` is never re-pulled.

The self-hosted Forgejo runner is `automount` + `privileged` = **zero isolation** (host root is exposed to the workflow). Only run trusted code on it; public/fork PRs belong on the sandboxed GitHub runners. See `docs/ci-overview.md`.

**Role release automation** — two platform-specific tracks, each its own copier toggle:
- `release_automation` (GitHub-gated): generates `release-please` config+manifest+`release.yml` (Galaxy role import), `pr-title.yml` (conventional-commit PR titles), and `dependabot.yml` (`github-actions` + `uv`). Static files with conditional Jinja names; needs `AUTOMATION_TOKEN` + `GALAXY_API_KEY` secrets. Dependabot only runs on github.com, so the toggle is only offered when `ci_platform` includes github.
- `forgejo_release` (Forgejo-gated; default on for pure-forgejo, off for `both` to avoid double-release): generates `.forgejo/workflows/release.yml` (on `v*` tag: download git-cliff → release notes → create release via the Forgejo API → regenerate + push `CHANGELOG.md`), `cliff.toml`, and a seed `CHANGELOG.md`. `release.yml` is a `.jinja` with the steps wrapped in `{% raw %}` so the Actions `${{ }}` survive copier while the builder `image:` line stays templated. Uses the auto-injected `GITHUB_TOKEN`; no extra secret.

**Scaffold self-test** (`.forgejo/workflows/test-template.yml`): the scaffold's own CI generates a role + a collection across the answer matrix and lints them (`lint-role` matrix + `lint-collection`, on push/PR), exercises `copier update` (`update-role`: generate at the PR base → update to HEAD → assert no `.rej` → re-lint, on push/PR), plus gated smokes on main/dispatch: `smoke-role` (docker molecule), `smoke-role-vagrant` (containerized vagrant), `smoke-collection` (sanity + molecule). The builder image is resolved by a `resolve-image` job from the latest `builder/v*` tag (`git ls-remote ... | sort -V | tail -1`); only the host comes from `vars.BUILDER_REGISTRY`, so releasing a new image needs no variable bump. This is the regression net for template edits — extend it when you add template features.

**Releases** — two independent tag tracks. The scaffold's own version: `release.yml` on a `v*` SemVer tag → git-cliff builds a Forgejo release + `CHANGELOG.md`; these `v*` tags are what `copier update` targets as versions (non-`v` tags like `archive/*` are ignored — `cliff.toml`'s `tag_pattern` is anchored `^v[0-9]`). The builder image: `release-image.yml` on a `builder/v*` tag → image `vX.Y.Z` (immutable) + `sha-<short>`, on its own cadence; `build-image.yml` still emits moving `latest`/`sha` on main pushes for dev.

## The git-init gotcha

A freshly generated role **or collection** must be `git init`'d before molecule will work. The scaffold's `.gitignore` ignores all of `roles/*` and `collections/*`; molecule/ansible-compat collects files via git, so until the artifact is its *own* git repo it can't discover its scenarios and fails with `'molecule/<scenario>/molecule.yml' glob failed`. This is also a precondition for `copier update`. `copier.yml`'s `_message_after_copy` reminds the user of this after generation.
