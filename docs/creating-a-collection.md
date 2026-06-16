# 创建与维护一个 collection

脚手架的 `kind` 开关决定生成 role 还是 collection（见仓库根 [`copier.yml`](../copier.yml)）。
collection 走 `kind=collection`，生成进 `collections/ansible_collections/<namespace>/<name>`。

## 生成

```bash
uv sync                       # 一次性：装好 copier
# 正式 collection 用远程 URL（_src_path 可移植，copier update 才干净）：
copier copy https://git.utlas.de/eyebrowkang/ansible-development.git \
  collections/ansible_collections/<namespace>/<name> -d kind=collection
# 仅脚手架本地调试用（_src_path: . 不可移植；--vcs-ref=HEAD 才生成当前提交，否则 copier 默认用最新 tag）：
uv run copier copy --vcs-ref=HEAD . collections/ansible_collections/<namespace>/<name> -d kind=collection
```

copier 会询问（collection 相关）：

| 问题 | 说明 |
|------|------|
| `collection_name` | 小写，galaxy.yml 的 `name` |
| `collection_description` | 一行描述 |
| `collection_dependencies` | galaxy.yml 的 `dependencies`（`name: version` 映射） |
| `collection_tags` | galaxy.yml tags——**必须含一个 Galaxy 命名 tag**（`tools`/`infrastructure`/`linux`…），否则 ansible-lint 的 `galaxy[tags]` 报错 |
| `include_plugins` | 是否脚手架示例插件（一个 filter + 一个 module，共享 `module_utils`）+ 单测，并打开 `ansible-test units`（默认关；关时 collection 保持 roles-only） |

外加共享问题：`namespace`、`author`、`license`、`min_ansible_version`、`ci_platform`、`include_docker`、`include_vagrant`、（forgejo 时）`builder_*`。

> **molecule 场景开关（`include_docker` / `include_vagrant`）**：与 role 共享。`include_docker`（默认开）生成 `extensions/molecule/default/`（docker，example role）；`include_vagrant`（collection 默认**关**）生成 `extensions/molecule/vagrant/`（vagrant+libvirt，靠短名解析 example role）。两者至少开一个，否则 copier 校验报错。

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
| `extensions/molecule/default/` | docker molecule 场景（`include_docker` 时；collection 的场景放这里，不是顶层 `molecule/`） |
| `extensions/molecule/vagrant/` | vagrant+libvirt 场景（`include_vagrant` 时；与 standalone role 的 vagrant 场景对齐，靠短名解析 example role） |
| `CHANGELOG.md` | ansible-lint `galaxy[no-changelog]` 要求 |
| `pyproject.toml` + `Makefile` | uv 工具链 + 本地 target |
| `renovate.json`（+ forgejo `renovate.yml`） | Renovate 依赖更新（`dependency_updates` 时，默认开；uv + Actions，与 role 同一套配置——见 [creating-a-role.md](creating-a-role.md) 的「依赖更新自动化（Renovate）」一节） |
| `plugins/`（`include_plugins` 时） | 示例 filter（`filter/to_upper.py`）+ module（`modules/example_fact.py`）+ 共享 `module_utils/greeting.py`。module 带 GPLv3 头（ansible 约定，`validate-modules` 强制，与 collection 自身 license 无关），author 写成 `name (@handle)` 以过 doc 校验 |
| `tests/unit/`（`include_plugins` 时） | filter 与 module_utils 的单测，`ansible-test units` 跑；`galaxy.yml` 的 `build_ignore` 同时从 `tests` 收窄到 `tests/output`，让单测 + sanity ignore 进 Galaxy artifact |

## 两类测试

- **`make sanity`** = `ansible-test sanity --venv`。用 `--venv`（不是 `--docker`）：sanity 各测试在独立 venv 里跑，**不需 docker**，因此在 Forgejo DooD runner 上也不会踩 "兄弟容器 bind-mount 挂到宿主路径" 的坑。慢但全面，是 Galaxy 的标准门禁。
- **`make test`** = molecule 跑 `roles/example`（docker 场景，`include_docker` 时）。场景在 collection 根的 `extensions/molecule/`，`converge.yml` 用**短名** `roles: [example]`，靠 `molecule.yml` 里的 `ANSIBLE_ROLES_PATH=${MOLECULE_PROJECT_DIRECTORY}/roles` 解析——这样 molecule 的 create/destroy playbook 不会被 ansible-lint 当成 role 内容（否则 `var-naming[no-role-prefix]` 误报）。
- **`make test-vm`** = molecule 跑 vagrant 场景（`include_vagrant` 时；需 `uv sync --group vagrant` + libvirt/KVM）。同 standalone role 走 molecule-plugins#301 的 `ANSIBLE_LIBRARY`/`ANSIBLE_FILTER_PLUGINS` 变通，见 [molecule-301-workaround.md](molecule-301-workaround.md)。
- **`make units`** = `ansible-test units --venv`（仅 `include_plugins` 时生成）。跑 `tests/unit/` 下 filter 与 module_utils 的单测，无需 docker。CI 里 forgejo `lint.yml` / github `ci.yml` 都有对应 `units` job，脚手架自测的 `smoke-collection-plugins` 还会连 sanity 一起跑。

## CI

- `.github/workflows/ci.yml`——public runner 上 lint + sanity + molecule（用 `path: ansible_collections/<ns>/<name>` checkout 满足 ansible-test 的布局要求）。
- `.forgejo/workflows/{lint,molecule}.yml`——builder 镜像跑 lint + sanity；`molecule.yml` 经 DooD 跑 example role。

## 拉取模板更新

```bash
cd collections/ansible_collections/<namespace>/<name>
uv run copier update --trust
```

## 插件（plugins）

`include_plugins`（默认关）脚手架一组可直接替换的示例插件 + 单测，并把 `ansible-test units` 接进 CI：

- `plugins/filter/to_upper.py`——示例 filter；`plugins/modules/example_fact.py`——示例 module；二者的逻辑都收在 `plugins/module_utils/greeting.py`（共享 helper，便于单测）。
- `tests/unit/plugins/`——`filter` 与 `module_utils` 的单测，导入用全限定路径 `ansible_collections.<ns>.<name>.plugins.…`，`ansible-test units --venv` 跑（`make units`）。
- module 的两个 ansible 约定坑：**GPLv3 头**（`validate-modules` 强制，所有 ansible module 都要，跟 collection 自身 license 无关），**author 写成 `name (@handle)`**（否则 `ansible-doc`/`validate-modules` 报 author 格式错）——模板都已处理，示例插件能直接过 `make sanity` + `make units`，无需任何 `tests/sanity/ignore-*.txt`。
- 打开后 `galaxy.yml` 的 `build_ignore` 从 `tests` 收窄到 `tests/output`：单测 + 将来你加的 sanity ignore 文件会进 Galaxy artifact，只排除 `ansible-test` 的生成输出。

## 后续（本轮未做）

- **collection release 自动化**（bump galaxy.yml 版本 + `ansible-galaxy collection publish` + antsibull-changelog）——role 模板已有 GitHub/Forgejo release bundle，collection 版可后续比照补上。
