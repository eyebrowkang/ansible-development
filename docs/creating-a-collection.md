# 创建与维护一个 collection

脚手架的 `kind` 开关决定生成 role 还是 collection（见仓库根 [`copier.yml`](../copier.yml)）。
collection 走 `kind=collection`，生成进 `collections/ansible_collections/<namespace>/<name>`。

## 生成

```bash
uv sync                       # 一次性：装好 copier
# 正式 collection 用远程 URL（_src_path 可移植，copier update 才干净）：
copier copy https://git.utlas.de/eyebrowkang/ansible-development.git \
  collections/ansible_collections/<namespace>/<name> -d kind=collection
# 仅脚手架本地调试用（会记下不可移植的 _src_path: .）：
uv run copier copy . collections/ansible_collections/<namespace>/<name> -d kind=collection
```

copier 会询问（collection 相关）：

| 问题 | 说明 |
|------|------|
| `collection_name` | 小写，galaxy.yml 的 `name` |
| `collection_description` | 一行描述 |
| `collection_dependencies` | galaxy.yml 的 `dependencies`（`name: version` 映射） |
| `collection_tags` | galaxy.yml tags——**必须含一个 Galaxy 命名 tag**（`tools`/`infrastructure`/`linux`…），否则 ansible-lint 的 `galaxy[tags]` 报错 |

外加共享问题：`namespace`、`author`、`license`、`min_ansible_version`、`ci_platform`、（forgejo 时）`builder_*`。

> **目录命名约定（强制）**：collection 必须放在 `…/ansible_collections/<namespace>/<collection_name>/`。
> `ansible-test sanity` 从路径（不是 galaxy.yml）推断 namespace/name；放错路径会直接报 "must be run from within a collection"。脚手架的 `collections/` 工作区天然满足这个布局。

## 生成后：先 git init（必需）

```bash
cd collections/ansible_collections/<namespace>/<name>
git init && git add -A && git commit -m "init from template"
uv sync
make lint        # yamllint + ansible-lint
make sanity      # ansible-test sanity（--venv，不需 docker）
make test        # molecule（example role）
```

`git init` 的原因同 role：脚手架 gitignore 了 `collections/*`，molecule 走 git 收集文件，不是独立 git 仓库会报 `glob failed`。

## 生成了什么

| 路径 | 作用 |
|------|------|
| `galaxy.yml` | collection 元数据（含 `repository`/`tags`——Galaxy/ansible-lint 要求，记得改成你的真实 URL） |
| `meta/runtime.yml` | `requires_ansible`（用完整 `X.Y.Z`） |
| `roles/example/` | 一个占位 role；按需复制成更多 role |
| `extensions/molecule/default/` | molecule 场景（collection 的场景放这里，不是顶层 `molecule/`） |
| `CHANGELOG.md` | ansible-lint `galaxy[no-changelog]` 要求 |
| `pyproject.toml` + `Makefile` | uv 工具链 + 本地 target |

## 两类测试

- **`make sanity`** = `ansible-test sanity --venv`。用 `--venv`（不是 `--docker`）：sanity 各测试在独立 venv 里跑，**不需 docker**，因此在 Forgejo DooD runner 上也不会踩 "兄弟容器 bind-mount 挂到宿主路径" 的坑。慢但全面，是 Galaxy 的标准门禁。
- **`make test`** = molecule 跑 `roles/example`。场景在 collection 根的 `extensions/molecule/`，`converge.yml` 用**短名** `roles: [example]`，靠 `molecule.yml` 里的 `ANSIBLE_ROLES_PATH=${MOLECULE_PROJECT_DIRECTORY}/roles` 解析——这样 molecule 的 create/destroy playbook 不会被 ansible-lint 当成 role 内容（否则 `var-naming[no-role-prefix]` 误报）。

## CI

- `.github/workflows/ci.yml`——public runner 上 lint + sanity + molecule（用 `path: ansible_collections/<ns>/<name>` checkout 满足 ansible-test 的布局要求）。
- `.forgejo/workflows/{lint,molecule}.yml`——builder 镜像跑 lint + sanity；`molecule.yml` 经 DooD 跑 example role。

## 拉取模板更新

```bash
cd collections/ansible_collections/<namespace>/<name>
uv run copier update --trust
```

## 后续（本轮未做）

- **collection release 自动化**（release-please 改 galaxy.yml 版本 + `ansible-galaxy collection publish` + antsibull-changelog）——role 模板已有 GitHub release bundle，collection 版可后续比照补上。
- **plugins**：当前模板是 roles-only（对齐你现有的 `bootstrap`）。要写模块/filter 时手动加 `plugins/`，并打开 `ansible-test units`。
