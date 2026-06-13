# Ansible development

个人的 Ansible 开发工具箱（meta-repo）：用 **copier 模板**生成自包含的 Ansible role，用 **uv** 管理工具链，用 **molecule** 双轨测试（Docker + Vagrant/libvirt），并为 **GitHub Actions** 与自托管 **Forgejo Actions** 提供开箱即用的 CI。

> 旧的 conda 版脚手架已归档在 git tag `archive/conda-scaffold-v0`。

## 这个仓库是什么

它本身**不持有依赖**——依赖契约下沉到每个生成的 role（各自的 `pyproject.toml` + `uv.lock`）。本仓库只持有：

| 路径 | 作用 |
|------|------|
| `templates/role/` | copier role 模板（生成新 role） |
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

# 2. 生成一个新 role
uv run copier copy . roles/eyebrowkang.myrole       # 或远程：copier copy gh:eyebrowkang/ansible-development roles/...
# 按提示回答 role_name / namespace / CI 平台 / 是否含 vagrant 场景 ...

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
- **vagrant（`molecule/vagrant`）**：真实 VM；覆盖内核模块、真实网络、reboot、systemd 深层。本地 + 自托管 Forgejo `[self-hosted, libvirt]`。

## CI

生成的 role 自带：

- `.github/workflows/ci.yml`——公共 runner 上跑 lint + docker 场景；
- `.forgejo/workflows/{lint,molecule}.yml`——用 builder 镜像跑 lint + docker，`[self-hosted, libvirt]` 跑 vagrant。

细节见 [docs/ci-overview.md](docs/ci-overview.md)。

## 进一步阅读

- [docs/creating-a-role.md](docs/creating-a-role.md)——copier copy / update 流程
- [docs/ci-overview.md](docs/ci-overview.md)——GitHub vs Forgejo、DooD、builder 镜像
- [docs/molecule-301-workaround.md](docs/molecule-301-workaround.md)——vagrant 场景的 #301 绕坑

## Thanks

- <https://github.com/ansible-community/molecule-plugins/issues/301>
