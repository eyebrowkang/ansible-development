# Changelog

All notable changes to this project are documented in this file.

## [1.3.3] - 2026-06-21

### Summary

修复 v1.3.0 / v1.3.1 引入的 floor 作业的一个并发 bug（**仅影响 Forgejo 托管的 role**）。

在共享的 Forgejo runner 上（DooD = 单个宿主 docker 守护进程），生成的 `docker` 与 `docker-floor` 两个作业**并发**运行，且都用**同名** molecule 实例（且 `recreate: true`）。于是两个作业互相把对方的容器 recreate / 删掉，导致 floor 作业（连带主作业）**稳定失败**（`OCI runtime exec failed: error executing setns process` / `container is not running` / `UNREACHABLE`）。

本版本给 Forgejo 的 `docker-floor` 加 `needs: docker`，让它在主 `docker` 作业（其实例已经 destroy）之后**串行**跑——共享守护进程上不再有并发同名实例。

GitHub 托管的 role **不受影响**（每个作业跑独立 VM + 独立 docker 守护进程，从不共享实例），故 GitHub 的 `molecule-floor` 保持不变。

### Upgrade Notes

已生成的 **Forgejo** role 运行 `copier update --trust` 即引入本修复（floor 作业的增量改动，正常会干净并入）。

- **GitHub role 无需为本版本更新**：它们的 floor 作业本就不受此 bug 影响。
- 若某 Forgejo role **自定义了主 molecule 作业的名字**（不是模板默认的 `docker`，例如改成了 `molecule` 矩阵），更新后需把 `docker-floor` 的 `needs:` 改成对应的作业名。
- 无需其他配置调整。

### Changes

#### Bug Fixes

- _templates_: Serialize the Forgejo docker-floor job after docker (needs:)


#### Documentation

- _release_: V1.3.3 notes


## [1.3.2] - 2026-06-20

### Summary

修复 v1.3.0 / v1.3.1 测试脚手架的几处小问题（不改变已生成 role 的运行行为）：

- `copier.yml` 的 `min_ansible_version` 校验器现在强制下限/上限：**role 须 ≥ 2.17**（docker floor 测试栈用 `community.docker` 5.x，要求 ansible-core ≥ 2.17，且 floor venv 跑 Python 3.12），**两者 ≤ 2.19**（ansible-lint meta-runtime 规则上限）。此前只验 X.Y.Z 格式，填 2.16 能过校验却会生成一个必然失败的 floor 作业——文档定了约束、校验器没拦。
- 示例 `meta/argument_specs.yml` 去掉了那个"死默认"——默认值归 `defaults/main.yml`，spec 只声明类型 / 必填，避免两处同一字面量悄悄 drift（spec 的 `default` 只在变量未定义时才生效，而 `defaults/` 总会定义它）。
- `docs/molecule-testing.md` 第二节按固定 ID 升序整理（原来是 ①②⑥⑦③⑤⑧④⑨），并把 side_effect 示例改成"在现有 `test_sequence` 里**插入** `side_effect → converge`"，而非整段替换（以免丢掉已有的 `destroy` / `syntax`）。

### Upgrade Notes

已生成的 role / collection 运行 `copier update --trust` 即引入本次改动；都是增量，正常会干净并入。

- **已落地的 role（如 garage、litedump）无需为本版本重更**：它们的 floor 已 ≥ 2.17、`argument_specs` 是各自的真实内容，本次改的是模板示例与生成期校验。
- 若某 role 的声明 floor < 2.17，下次 `copier update` 时校验器会**拦下**——把 floor 提到 ≥ 2.17（见 `docs/molecule-testing.md`）。
- 无需其他配置调整。

### Changes

#### Bug Fixes

- _copier_: Enforce min_ansible_version bounds (role >= 2.17, both <= 2.19)

- _templates_: Drop the dead default from the example argument_specs


#### Documentation

- _molecule_: Order section 2 by ID; side_effect inserts, not replaces

- _release_: V1.3.2 notes


## [1.3.1] - 2026-06-20

### Summary

修复 v1.3.0 引入的 floor 作业的一个缺陷。

floor 作业（`molecule-floor` / `docker-floor`）此前用 `uv venv .venv-floor` 建虚拟环境，继承了仓库默认的 Python 3.13。但 ansible-core 低于 2.18 的版本不支持 Python 3.13，导致**声明 `min_ansible_version` < 2.18 的 role 会在 floor 作业里因环境不兼容而假失败**（与 role 代码无关）。脚手架默认 floor 是 2.19，所以一直没暴露，直到有 role 把 floor 调低才触发。

本版本把 floor venv 钉到 **Python 3.12**（兼容 2.16–2.19 全部 floor），并在生成的 GitHub / Forgejo floor 作业和脚手架自测的 `smoke-role-floor` 中同步修复。

### Upgrade Notes

已生成的 role 运行 `copier update --trust` 即引入本修复（floor 作业的增量改动，正常会干净并入）。

- **声明的 `min_ansible_version` 须 ≥ 2.17**：docker 测试栈用 `community.docker` 5.x（`requires_ansible: '>=2.17.0'`），低于此的 floor 无法用 docker 场景验证。请把 floor 调到可测版本，或单独给 floor 作业换更老的 `community.docker`。详见 `docs/molecule-testing.md`。
- 无需其他配置调整。

### Changes

#### Bug Fixes

- _templates_: Pin the floor-test venv to Python 3.12


#### Documentation

- _release_: V1.3.1 notes


## [1.3.0] - 2026-06-20

### Summary

本版本聚焦**生成产物的测试深度**与**模板去重**两块。

测试深度：生成的 role 与 collection 示例 role 不再是"占位骨架"。`verify.yml` 改为从外侧读系统真相（`stat` / `slurp` / `assert`，并附 `command` / `service_facts` 注释示例）而非 `assert: that: [true]`；占位 `tasks/main.yml` 改为管理一个幂等 marker 文件，让 `idempotence` 与 `verify` 有真实状态可断言；新增 `meta/argument_specs.yml` 做输入校验（负向测试入口）；CI 新增 floor 作业，在 role 声明的最低 `min_ansible_version` 上跑 docker 场景；并补上 `make check`（check mode 干跑）与 docker 场景的 `syntax` 步骤。配套新增中文指南 `docs/molecule-testing.md`，讲清完整生命周期、已生成项如何扩展，以及刻意留给文档的进阶模式（side_effect / prepare / cleanup、多场景、多发行版、多主机、负向场景、全 ansible 版本矩阵、testinfra、裸机 bootstrap 限制）。

模板去重：role 与 collection 两套模板中逐字节相同的文件（`.ansible-lint`、`.pre-commit-config.yaml`、`.python-version`、`.copier-answers.yml.jinja`、`renovate.json`，以及 molecule 的 `create.yml` / `destroy.yml`）统一收敛到 `templates/_shared/`，两边用相对软链接引用，并设 `_preserve_symlinks: false` 让 copier 在渲染时跟随软链写出真实文件（生成的产物里不残留任何软链）。机制与"将来如何拆分"记录在 `templates/_shared/README.md`。同时修复 collection 示例 molecule 场景仍停留在 `geerlingguy/docker-debian12-ansible` 的问题，对齐到 role 使用的 `debian13`。

### Upgrade Notes

已生成的 role / collection 不会自动改变；需在对应仓库运行 `copier update --trust` 才会引入本版本内容。

- **去重对已生成产物零影响**：共享文件字节不变。role 端 `copier update` 无任何变更；collection 端仅有 molecule 镜像 `debian12 → debian13` 这一处预期变更。两者均无 `.rej` 冲突。
- **测试深度会改写占位文件**：本版本改写了 `tasks/main.yml`、`verify.yml`、`defaults/main.yml` 并新增 `meta/argument_specs.yml`。若你**尚未改动这些占位文件**，`copier update` 会干净地引入新结构。若你**已把它们替换成真实内容**，三方合并可能在这些文件上产生 `.rej` 冲突——这是预期行为：审阅后保留你自己的实现即可（新的 marker / verify 仅作示例模式）。
- 其余改动（`Makefile` 的 `check` 目标、`test_sequence` 的 `syntax` 步骤、CI 的 floor 作业）均为增量，正常情况下会干净并入。
- 无需额外配置调整。

### Changes

#### Bug Fixes

- _collection_: Pin example molecule image to debian13


#### Documentation

- _molecule_: Add testing guide; note generated test scaffolding

- _release_: V1.3.0 notes


#### Features

- _templates_: Real molecule scenario for generated roles

- _templates_: Validate role inputs via meta/argument_specs.yml

- _templates_: Run generated role CI on its declared ansible-core floor


#### Refactoring

- _templates_: De-duplicate shared files into _shared/ via symlinks


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


