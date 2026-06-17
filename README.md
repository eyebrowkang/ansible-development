# Ansible development

个人的 Ansible 开发工具箱（meta-repo）：用 **copier 模板**生成自包含的 Ansible **role 或 collection**（`kind` 开关），用 **uv** 管理工具链，用 **molecule** 双轨测试（Docker + Vagrant/libvirt），并为 **GitHub Actions** 与自托管 **Forgejo Actions** 提供开箱即用的 CI、**Renovate** 依赖更新，以及可选的 release 自动化（GitHub release-please / Forgejo git-cliff；collection 走 antsibull-changelog）。

> 旧的 conda 版脚手架已归档在 git tag `archive/conda-scaffold-v0`。

## 这个仓库是什么

它本身**不持有依赖**——依赖契约下沉到每个生成的 role（各自的 `pyproject.toml` + `uv.lock`）。本仓库只持有：

| 路径 | 作用 |
|------|------|
| `templates/role/` | copier role 模板（`kind=role`） |
| `templates/collection/` | copier collection 模板（`kind=collection`） |
| `images/builder/` | CI builder 镜像（预烤工具链，推 Forgejo registry） |
| `docs/` | 工作流文档 |
| `roles/` `collections/` | 薄工作区（内容被 gitignore，各自是独立 git 仓库） |

## 主机依赖

- [uv](https://docs.astral.sh/uv/)（取代 conda/miniforge）
- Docker（docker 测试轨）
- `make`
- VM 测试轨（Arch Linux）：`qemu-full`、`vagrant`、`libvirt`、`virt-manager`、`dnsmasq`、`nftables`，以及 `vagrant plugin install vagrant-libvirt`

## 快速开始

```bash
# 1. 装好脚手架自己的工具（copier 等）
uv sync

# 2. 生成一个新 role（collection 见 docs/creating-a-collection.md）
#    正式 role 用远程 URL（_src_path 可移植，copier update 才干净）：
uv run copier copy https://git.utlas.de/eyebrowkang/ansible-development.git roles/eyebrowkang.myrole
#    （仅脚手架本地调试可用 `uv run copier copy --vcs-ref=HEAD . <dest>`：--vcs-ref=HEAD 用当前提交而非最新 tag；会记下不可移植的 _src_path: .）
# 按提示回答 kind=role / role_name / namespace / CI 平台 / 是否含 vagrant / 是否要 release 自动化 ...

# 3. 进入 role；先 git init（必需！roles/ 被脚手架 gitignore，
#    role 不是独立 git 仓库的话 molecule 找不到 scenario，报 "glob failed"）
cd roles/eyebrowkang.myrole
git init && git add -A && git commit -m "init from template"
uv sync
make test        # docker 场景（快）
make test-vm     # vagrant/libvirt 场景（需 KVM）
make lint
```

## 测试双轨

- **docker（`molecule/default`）**：快、轻；本地、GitHub 公共 runner、Forgejo 都能跑。覆盖 80%——装包、模板、配置、幂等。
- **vagrant（`molecule/vagrant`）**：真实 VM；覆盖内核模块、真实网络、reboot、systemd 深层。本地 + 自托管 Forgejo `[self-hosted, kvm]`（CI 里默认容器化跑）。

## CI

生成的 role 自带：

- `.github/workflows/ci.yml`——公共 runner 上跑 lint + docker 场景；
- `.forgejo/workflows/{lint,molecule}.yml`——用 builder 镜像跑 lint + docker；vagrant 在 `[self-hosted, kvm]` 上**容器化**（`ansible-builder-vagrant` + `--privileged`）跑。
- **依赖更新**（`dependency_updates`，默认开）：生成一个平台无关的 `renovate.json`，由仓库外的 Renovate 读取——GitHub 用托管 Renovate App，Forgejo 用自托管的集中 renovate-bot（取代旧的 Dependabot）。
- **发布**（可选）：role 在 GitHub 走 release-please（`release_automation`）、Forgejo 走 git-cliff（`forgejo_release`）；collection 走 antsibull-changelog（`collection_release` 发 Galaxy / `collection_forgejo_release` 建 Forgejo release）。

> docker / vagrant 两轨均可选（`include_docker` / `include_vagrant`，至少开一个）。细节见 [docs/ci-overview.md](docs/ci-overview.md)。

## 发布（维护者）

脚手架与 builder 镜像各自独立用 tag 发布。

**脚手架版本**（`copier update` 的目标）——合并到 main 后打 SemVer tag：

```bash
git tag -a v0.1.0 -m "v0.1.0" && git push origin v0.1.0
```

`.forgejo/workflows/release.yml` 用 git-cliff 生成 release notes、建 Forgejo release、回写 `CHANGELOG.md`。非 `v` 开头的 tag（如旧的 `archive/*`）被忽略。

**builder 镜像版本**（role `builder_tag` 的 pin 目标，独立 cadence）——改了 `images/builder/` 后打 `builder/v*` tag：

```bash
git tag builder/v1.0.0 && git push origin builder/v1.0.0
```

`.forgejo/workflows/release-image.yml` 构建并推送 `vX.Y.Z`（不可变）+ `sha-<short>`；日常 main push 仍由 `build-image.yml` 出 `latest`/`sha`（dev 用）。两套 tag 互不触发。

> **约定：一个 commit 只打一个版本 tag。** 把 `builder/v*` 和脚手架 `v*` 打到同一个 commit 会让 `git describe` 选错，copier 会把 role 的 `_commit` 记成那个 builder tag（probe 就踩过，记成了 `builder/v1.0.0`）。所以镜像改动与脚手架改动**分成不同 commit**；依赖新镜像特性的脚手架版本，要在对应 `builder/v*` 发布**之后**再发（如 `v0.2.0` 的 vagrant 轨需要 `builder/v1.2.0`）。

## 进一步阅读

- [docs/creating-a-role.md](docs/creating-a-role.md)——copier copy / update 流程、GitHub release-please 与 Forgejo tag 发布、tasks/ 拆分约定
- [docs/creating-a-collection.md](docs/creating-a-collection.md)——生成 collection、sanity + molecule 测试
- [docs/ci-overview.md](docs/ci-overview.md)——GitHub vs Forgejo、DooD、builder 镜像
- [docs/molecule-301-workaround.md](docs/molecule-301-workaround.md)——vagrant 场景的 #301 绕坑

## Thanks

- <https://github.com/ansible-community/molecule-plugins/issues/301>
