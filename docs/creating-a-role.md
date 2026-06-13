# 创建与维护一个 role

## 生成

```bash
uv sync                       # 一次性：装好 copier
uv run copier copy templates/role roles/<namespace>.<name>
```

copier 会询问（见 [`../templates/role/copier.yml`](../templates/role/copier.yml)）：

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
| `builder_registry` | Forgejo builder 镜像所在 registry |
| `builder_tag` | builder 镜像 tag —— 因 runner `force_pull:false`，应填 build-image.yml 产出的不可变 tag（如 `20250613-ab12cd3`），别用 `latest` |

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
