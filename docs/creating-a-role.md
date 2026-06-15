# 创建与维护一个 role

## 生成

推荐用**远程 URL** 生成（也是 `copier update` 拉取的源，记下的 `_src_path` 可移植）：

```bash
uv sync                       # 一次性：装好 copier
copier copy https://git.utlas.de/eyebrowkang/ansible-development.git roles/<namespace>.<name>
```

> 仅做脚手架本地调试时可用 `uv run copier copy . <dest>`，但它把 `_src_path` 记成 `.`（不可移植）——
> 进了 role 目录后 `copier update` 会失效。正式 role 别用这种；要用本地源就给**绝对路径**。

copier 会询问（见仓库根的 [`copier.yml`](../copier.yml)）：

| 问题 | 说明 |
|------|------|
| `role_name` | 小写，作为 Galaxy role_name |
| `namespace` | Galaxy 命名空间 / 作者 |
| `min_ansible_version` | 写入 meta/main.yml |
| `galaxy_collections` | 依赖的 collection |
| `license` | meta 里记录的 SPDX id |
| `ci_platform` | github / forgejo / both |
| `include_vagrant` | 是否生成 vagrant 场景 |
| `needs_systemd` | docker 场景是否用 systemd 镜像 |
| `shell_templates` | role 是否渲染 shell 模板（`templates/**/*.sh.j2`）并需 shellcheck（生成 `tests/` + lint 步骤） |
| `release_automation` | （仅 `ci_platform` 含 github 时问）生成 GitHub release 自动化：release-please + 语义化 PR 标题检查 + Dependabot + Galaxy 导入 |
| `forgejo_release` | （仅 `ci_platform` 含 forgejo 时问，纯 forgejo 默认开）生成 Forgejo tag 驱动发布：push `v*` tag → git-cliff 出 CHANGELOG + 建 Forgejo release |
| `builder_registry` | Forgejo builder 镜像所在 registry |
| `builder_tag` | builder 镜像 tag —— 因 runner `force_pull:false`，应填 build-image.yml 产出的不可变 tag（如 `sha-ab12cd3`），别用 `latest`；默认是占位 `sha-REPLACE_ME`，记得替换 |

> **目录命名约定**：role 目录用 `<namespace>.<name>`（与 converge 里的 `role: namespace.role_name` 对应，molecule 把上级目录加入 `ANSIBLE_ROLES_PATH`）。

## 生成后：先 git init（必需）

```bash
cd roles/<namespace>.<name>
git init && git add -A && git commit -m "init from template"
uv sync
make test
```

`git init` **不是可选的**：脚手架的 `.gitignore` 把 `roles/*` 整个忽略，molecule/ansible-compat 走 git 收集 role 文件时会因此找不到 scenario，报 `'molecule/<scenario>/molecule.yml' glob failed`。让 role 成为**独立 git 仓库**后即正常——这也正是设计意图（每个 role 自带 git、可独立 CI），并且是 `copier update` 的前提。

## 拉取模板更新

模板改进后，把改动合并回已生成的 role：

```bash
cd roles/<namespace>.<name>
uv run copier update --trust       # 要求 role 是干净的 git 仓库
```

copier 依据 `.copier-answers.yml` 记录的答案与模板版本做三方合并；冲突会生成 `.rej`，手动解决即可。这正是选 copier 而非 cookiecutter 的核心价值——模板可持续回填。

> `kind` 默认 `role`，所以上面的命令不必显式带 `-d kind=role`。生成 collection 见 [creating-a-collection.md](creating-a-collection.md)。
>
> 脚手架自身采用 semver tag（`vX.Y.Z`）发布版本，`copier update` 默认更新到最新 tag；首个版本发布前（尚无 tag）可用 `copier update --vcs-ref=HEAD` 跟最新提交。

## release 自动化（仅 GitHub）

`release_automation`（默认开，仅在 `ci_platform` 含 github 时询问）生成一整套 GitHub release 自动化：

- `release-please-config.json` + `.release-please-manifest.json`——[release-please](https://github.com/googleapis/release-please) 按 conventional commits 自动开 release PR、打 tag、写 CHANGELOG。
- `.github/workflows/release.yml`——release-please + 发布后 `ansible-galaxy role import` 导入 Galaxy。
- `.github/workflows/pr-title.yml`——校验 PR 标题为 conventional commit（squash 合并用 PR 标题作 commit message，release-please 要解析它）。
- `.github/dependabot.yml`——每周更新 `github-actions` 与 `uv` 依赖。

需配置 secrets：`AUTOMATION_TOKEN`（细粒度 PAT，缺省回退 `GITHUB_TOKEN`）、`GALAXY_API_KEY`。

> Dependabot 只在 github.com 跑；forgejo-only 的 role 不问这个开关、也不生成这些文件。

## Forgejo tag 驱动发布（自托管）

`forgejo_release`（仅 `ci_platform` 含 forgejo 时询问；纯 forgejo 默认开，`both` 默认关以免与 release-please 重复）生成自托管 role 的经典 tag 流（不发 Galaxy）：

- `.forgejo/workflows/release.yml`——`on: push tags v*`，在 builder 镜像里下载 git-cliff → `git-cliff --latest` 出 release notes → 调 Forgejo API 建 release → `git-cliff` 重建 `CHANGELOG.md` 回写默认分支（`[skip ci]`）。
- `cliff.toml`——git-cliff 配置，分组与 release-please 的 sections 对齐（feat/fix/perf/refactor/docs/test，其余隐藏）。
- `CHANGELOG.md`——初始种子，首个 release 起由 git-cliff 重建。

发布只需打 tag（用 Forgejo 自动注入的 `GITHUB_TOKEN`，**无需额外 secret**）：

```bash
git tag v0.1.0 && git push origin v0.1.0
```

> tag 打在默认分支上（回写 `CHANGELOG.md` 那步会切到默认分支）。若默认分支受保护不许直接 push、或你想本地手动维护 `CHANGELOG.md`，删掉 release.yml 里「Sync CHANGELOG.md」那一步即可。`both` 平台若两个开关都开会同时有两套发布，通常只用其一。

## tasks/ 拆分约定（推荐，非强制）

role 复杂后，建议把 `tasks/main.yml` 按阶段拆分、用 `include_tasks` + `when` 串起来：

```yaml
# tasks/main.yml
- name: Validate
  ansible.builtin.include_tasks: validate.yml
- name: Install
  ansible.builtin.include_tasks: install.yml
  when: not (myrole_upgrade | bool)
- name: Configure
  ansible.builtin.include_tasks: configure.yml
- name: Service
  ansible.builtin.include_tasks: service.yml
```

约定（非强制——模板只给一个占位 `main.yml`，怎么拆由你定）：

- 阶段文件职责单一：`validate` / `install` / `configure` / `service` / `upgrade` …
- 对外变量用 `<role_name>_` 前缀（ansible-lint `var-naming` 的 production 要求）；内部计算的中间变量用 `_<role_name>_` 前缀。
