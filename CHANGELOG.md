# Changelog

All notable changes to this project are documented in this file.

## [1.2.0] - 2026-06-18

### Summary

本版本优化了脚手架自身和 Forgejo role 模板的 git-cliff 发布流程：发布说明现在分为人工维护的 `Summary`、人工维护的 `Upgrade Notes`，以及由 git-cliff 自动生成的 `Changes`。

这样每个版本既能保留面向用户的发布摘要和升级说明，也能继续从提交历史中自动生成可追溯的变更明细。`Changes` 现在也不再完全依赖约定式提交，非规范提交会进入 `Other Changes`，避免重要变更被静默漏掉。

### Upgrade Notes

已生成的 role 不会自动改变；需要在对应 role 中运行 `copier update --trust` 后，新的 Forgejo 发布流程才会进入该 role。

更新后的 Forgejo role 在发布每个 `v*` tag 前，都必须提交匹配的 `.release-notes/<tag>.md` 文件，并包含 `### Summary` 与 `### Upgrade Notes` 两个小节。缺少该文件或小节会让发布 workflow 失败，这是有意设计，用来避免发布时遗漏人工升级说明。

如果某个版本不需要迁移或配置调整，请在 `Upgrade Notes` 中明确写出 `No upgrade steps required.` 或等价说明。

### Changes

#### Documentation

- _scaffold_: Add general copier-update guide; fix the update command

- _release_: V1.2.0 notes


#### Features

- _release_: Support manual git-cliff release notes


## [1.1.0] - 2026-06-17

### Changes

#### Bug Fixes

- _scaffold_: Render collections: [] when galaxy_collections is empty

- _scaffold_: Destroy recorded molecule instances (#10)


#### Features

- _scaffold_: Add reusable setup-repo.sh repo-governance helper


#### Refactoring

- _scaffold_: Drop the per-repo Forgejo Renovate workflow


## [1.0.0] - 2026-06-17

### Changes

#### Bug Fixes

- _scaffold_: Address code-review findings (#1-#8)

- _collection_: Lean changelog dep-group + keep lint green after release

- _collection_: Harden release version parse, Forgejo release id, and renovate token


#### Features

- _scaffold_: Make docker/vagrant molecule scenarios optional for both kinds

- _scaffold_: Add Renovate dependency automation, replacing Dependabot

- _collection_: Scaffold example plugins + ansible-test units (include_plugins)

- _collection_: Add antsibull-changelog release automation (Galaxy + Forgejo)


#### Performance

- _scaffold_: Validate the static renovate.json once, not per variant


#### Refactoring

- _scaffold_: Flatten the conditional molecule job separator


#### Tests

- _scaffold_: Add adversarial free-text self-test variants

- _scaffold_: Smoke-test the declared min ansible-core floor (R6)


## [0.3.0] - 2026-06-16

### Changes

#### Bug Fixes

- _role_: JSON-escape free-text fields into TOML/YAML

- _role_: Gate vagrant Makefile targets on include_vagrant

- _role_: Make lint install Galaxy collections first

- _scaffold_: Enforce Galaxy name pattern for role/namespace/collection

- _scaffold_: Default min_ansible_version to the tested 2.21.0

- _scaffold_: Cap min_ansible_version default at ansible-lint-accepted 2.19.0

- _scaffold_: Generate from HEAD in self-test and local-debug copies

- _collection_: JSON-escape free-text fields into TOML/YAML

- _collection_: Make lint install Galaxy collections first

- _collection_: Pin molecule dependency versions

- _collection_: Exclude dev/test artifacts from the built tarball


#### CI

- _scaffold_: Run docker molecule smoke on PRs


#### Documentation

- _collection_: Fix Makefile sanity help text


#### Features

- _role_: Allow pinning Galaxy collection versions


#### Tests

- _scaffold_: Add update-collection self-test job


## [0.2.0] - 2026-06-16

### Changes

#### Bug Fixes

- _ci_: Runner label [self-hosted, libvirt] -> [self-hosted, kvm]

- _images_: Install dnsmasq-base + iptables explicitly in the vagrant builder

- _vagrant_: Relax libvirt container isolation + route destroy through the #301 workaround

- _vagrant_: Add --init to reap the qemu zombie on teardown (+ job timeout)

- _vagrant_: Reap qemu via a tini subreaper for libvirtd (container.options --init is ignored)

- _vagrant_: Drop ineffective container.options --privileged (Forgejo ignores it)


#### Build

- _images_: Upgrade builder bases to debian 13 + docker 29

- _molecule_: Upgrade default docker test images to debian 13

- _meta_: Declare Debian trixie (13) platform support

- _molecule_: Switch vagrant box to debian/trixie64 (debian 13)

- _images_: Bake tini + container-libvirt qemu.conf into the vagrant image


#### CI

- Auto-resolve the latest builder/v* image tag (drop hardcoded BUILDER_TAG)


#### Documentation

- Finalize vagrant CI + builder-image docs; record one-tag-per-commit convention


#### Features

- _roles_: Update vagrant box default cpus and memory to 1c1g


#### Refactoring

- _vagrant_: Rely on the image's baked tini + qemu.conf (drop runtime setup)


## [0.1.0] - 2026-06-15

### Changes

#### Bug Fixes

- Fix README syntax error


#### Build

- Build with docker/* actions (cleaner, multi-arch, auto-registry)

- Simplify image pushes for the Forgejo registry

- Push with plain docker (schema2), not buildx


#### CI

- Self-test the copier template (lint matrix + molecule smoke)


#### Documentation

- Add CLAUDE.md guidance for Claude Code

- Collection guide, tasks-split convention, release automation

- Fix builder-image build mechanism, tag format, copier source URL

- Reconcile docs with the Phase 2 mechanism changes


#### Features

- _roles_: Containerize vagrant CI + Forgejo tag-release; pin builder images

- Tag-driven releases for the scaffold and versioned builder images


#### Other Changes

- Init

- Update environment.yml

- Update conda dependencies

- Rebuild/uv copier meta repo (#1)

* Replace conda scaffold with uv workspace

Drop environment.yml and the conda activate/deactivate hooks; manage the scaffold's own tooling (copier, pre-commit) with uv via pyproject.toml + uv.lock. Per-role dependency contracts now live in each generated role.

* Add copier role template

Generates self-contained roles: uv dependency groups (dev/vagrant), docker + vagrant molecule scenarios, GitHub + Forgejo CI, Makefile, lint config. The docker scenario uses molecule's built-in delegated driver + community.docker (ansible-core 2.21 compatible), avoiding the broken molecule-plugins[docker].

* Add CI builder images and Forgejo build pipeline

Lean docker-track image + fat vagrant-track image, pushed to the Forgejo registry with immutable tags (force_pull:false safe).

* Rewrite README and add workflow docs

Document the uv/copier/molecule workflow, CI on GitHub vs Forgejo (DooD), and the molecule-plugins/ansible-core 2.21 caveats.

* Harden role-generation UX after Arch verification

- copier _message_after_copy + README/docs make the required 'git init' explicit: the scaffold gitignores roles/*, so molecule can't discover a generated role's scenarios until it is its own git repo (otherwise: 'glob failed').
- Docs: confirm the vagrant scenario works on ansible-core 2.21 (verified via 'make test-vm' on Arch + libvirt).

- Fix molecule collection install + pin builder image tag (#2)

* Fix molecule collection install for generated roles

Molecule resolves dependency.options.requirements-file relative to the role root (CWD), so the docker scenario's community.docker (declared in molecule/default/requirements.yml) was never installed in a fresh CI job, and create.yml's community.docker.docker_container failed. Use molecule's default scenario-collections file instead: a per-scenario collections.yml (auto-detected at the scenario-absolute path), drop the requirements-file override, and keep a roles-only requirements.yml to silence the 'missing roles requirements file' warning. Verified end-to-end with an empty ANSIBLE_COLLECTIONS_PATH.

* Let generated roles pin an immutable builder image tag

The Forgejo runner uses force_pull:false, so a hardcoded :latest goes stale once build-image.yml pushes a new immutable tag, and users could not set the tag without editing generated YAML. Add a builder_tag copier question (default latest; help nudges the immutable YYYYMMDD-<sha> tag) and reference {{ builder_registry }}/ansible-builder:{{ builder_tag }} in the Forgejo lint/molecule workflows.

- Shellcheck support + remotely addressable for copier update (#3)

- Fix Forgejo CI: provide Node.js for actions/checkout

actions/checkout@v4 is a JS action and needs 'node' in the job container.

- build-image.yml ran in 'docker:cli' (Alpine, no node) -> 'exec: node: not found'. Run it in node:20-bookworm (node + git for checkout) and install the docker CLI in a step.
- The builder images (ansible-builder[-vagrant]) had no node either, so roles' lint/molecule jobs that use them would fail checkout the same way -> add nodejs.

Verified locally: the built ansible-builder image has node v18 + git + docker + uv + shellcheck; node:20-bookworm has node v20 + git.

- Install vagrant-libvirt from Debian (no gem build)

- Template ci: install Galaxy collections before ansible-lint

Generated roles' lint job ran ansible-lint without installing collections, so syntax-check couldn't resolve community.docker (molecule create/destroy) or the role's collections. Add an 'ansible-galaxy collection install -r molecule/default/collections.yml' step to the github + forgejo lint jobs.

- Pin test images, drop unused deps, drop top-level requirements.yml

- Add kind=role|collection switch via dynamic _subdirectory

- Role template: pre-commit, .yamllint.yml rename, GitHub release automation

- .pre-commit-config.yaml (uv-local yamllint/ansible-lint hooks + generic mirror)
- rename .yamllint -> .yamllint.yml (matches the reference roles + pre-commit -c)
- release_automation bundle (static files, conditional names, github-gated):
  release-please config+manifest, release.yml (Galaxy import), pr-title.yml,
  dependabot.yml (github-actions + uv)

- Collection template: roles-only scaffold + sanity/molecule CI

galaxy.yml/meta/runtime.yml/example role/CHANGELOG + uv toolchain. Tests:
ansible-test sanity --venv (dodges DooD bind-mount) and molecule on the example
role from extensions/molecule (ANSIBLE_ROLES_PATH short-name resolution). CI uses
the ansible_collections/<ns>/<name> checkout-path trick.


#### Tests

- Cover collections + role release toggle


