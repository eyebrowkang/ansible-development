# CI 总览

## 两个平台

| | runner | docker 场景 | vagrant 场景 |
|---|---|---|---|
| **GitHub Actions**（开源） | 公共 `ubuntu-latest` | ✓ 用 setup-uv | ✗（无可靠 KVM） |
| **Forgejo Actions**（自托管） | 你的 runner（`forgejo_runner_label`，默认 `ubuntu-latest`） | ✓ 用 builder 镜像 | ✓ 容器化 `[self-hosted, kvm]` |

docker 轨是到处通用的主力；vagrant 轨落在你自托管、可控的 Forgejo。

> **driver 说明**：docker 场景用 molecule **内置 `default`（delegated）driver** + 自写 `create.yml`/`destroy.yml`（`community.docker`），不依赖 molecule-plugins，兼容 ansible-core 2.21。vagrant 场景用 `molecule-plugins[vagrant]`——实测兼容 ansible-core 2.21，并由脚手架自测的 `smoke-role-vagrant` job 持续把关，详见 [molecule-301-workaround.md](molecule-301-workaround.md)。

## DooD（你的 runner）

你的 Forgejo runner 配置是 `docker_host: automount` + `privileged: true`：每个 job 起一个 privileged 容器，并把宿主 docker socket 挂进去。于是：

- molecule 跑在 job 容器里，但通过 socket 命令**宿主 daemon** 创建被测实例——实例是 job 容器的**兄弟**，不是嵌套在里面。
- docker 场景因此**不需要** job 容器特权；systemd 实例所需的 `privileged` / cgroup 由 `molecule.yml` 的 platform 指定，由宿主 daemon 满足。
- ⚠️ actions cache（`actions/cache`、`setup-go` 的 `cache: true` 等）：runner 的 cache server 地址要能从 job 容器里访问到，否则恢复缓存会卡几分钟才超时（eyebrowkang.caddy 在 2026-10 撞上过）。修 runner 配置里 cache 的 `host`/网络之前，生成的 workflow 不要开缓存。
- ⚠️ automount + privileged = **零隔离**：这台 runner 相当于把宿主 root 暴露给 workflow。**只跑你可信的代码**；公开仓库 / fork PR 放到 GitHub 公共 runner（沙箱化）。

## builder 镜像

`images/builder/` 把工具链预烤进镜像，推到 Forgejo registry，CI 容器 job 直接拉，免去每次现装。

因为 runner 是 `force_pull: false`，**必须用不可变 tag**（`build-image.yml` 经 `type=sha` 产出的 `sha-<short>`），否则推了新 `:latest` 也不会被重新拉取。

- **推镜像**（`build-image.yml`）：registry 主机由 `GITHUB_SERVER_URL` 自动推导，无需配置；仅当实例的 actions token 不能写 package 时，才需配 `secrets.REGISTRY_TOKEN`（PAT，`package:write`）。
- **拉镜像**（生成的 role CI）：job 容器镜像地址来自生成时回答的 `builder_registry` / `builder_tag`（已烤进 workflow 文件）；故 `builder_tag` 要 pin `sha-<short>`，别用 `latest`。

> **不可变 = 锁产物**：Dockerfile 里 base 镜像（debian / docker-cli / uv）已按 `@sha256` digest 钉死、`uv python` 钉到具体 patch，所以同一 `sha-<short>` 重建产物可复现（tag 锁配方，digest 锁产物）。刷新 digest：`docker buildx imagetools inspect <image>`。
>
> 脚手架**自测 / 发布**（`test-template.yml`、`release.yml`）的镜像由各自的 `resolve-image` job 自动取最新 `builder/v*` tag —— 只有 registry 主机来自 `vars.BUILDER_REGISTRY`，发了新镜像无需手改变量（与 role pin 死版本不同，自测要跟最新工具链）。

## vagrant job：默认容器化

生成的 vagrant job 默认 `runs-on: [self-hosted, kvm]` 且**带 `container:`**——跑在 `ansible-builder-vagrant` 镜像里（vagrant 轨需 **builder 镜像 >= v1.2.0**）。容器内跑 libvirt/KVM 所需的几样东西都已**烤进镜像**:

- `dnsmasq-base` + `iptables` —— libvirt 起 NAT 网络要用;
- 放宽的 `/etc/libvirt/qemu.conf`（`cgroup_controllers=[]` / `namespaces=[]` / `security_driver=none` / `user`=`group`=`root`）—— 容器里做不了 per-VM cgroup / mount namespace / AppArmor 隔离;
- `tini` —— job 起 molecule 前用 `setsid tini -s -- libvirtd` 跑 libvirtd,靠 tini 的 **subreaper** 模式回收 libvirt daemonize 出去的 qemu 僵尸(否则 `vagrant destroy` 会一直卡——qemu 退出后没人 reap)。

⚠ **特权/设备只能来自 runner 配置,不能写在 job 里**:Forgejo 的 `container.options` 只认 `--volume`/`--tmpfs`/`--hostname`/`--memory`,**不认 `--privileged`/`--init`/`--device`**(之前 `--init` 没生效正是因此)。所以 `/dev/kvm` + 特权必须由那台 **privileged 的 `[self-hosted, kvm]` runner**(config 级)提供。契合「每个 job 都在 Docker 里、不污染宿主」的 runner 哲学。

⚠ **Forgejo 会忽略 `permissions`**（[与 GitHub Actions 的差异](https://forgejo.org/docs/latest/user/actions/github-actions/#known-list-of-differences)）：自动 token 的权限由 Forgejo 决定，写了也不生效，反而让人误以为权限受了限制。所以 `.forgejo/` 下的 workflow 都不写 `permissions`；`.github/` 下的照常写。

⚠ **molecule 实例名固定，同一 daemon 上的并发运行会互相删实例**：DooD 下所有 job 共用宿主的 Docker daemon。生成的 `molecule.yml` workflow 带 `concurrency: {group: molecule, cancel-in-progress: false}`，同一仓库的 molecule 运行排队执行（group 按仓库隔离，所以不需要带仓库名）。`concurrency` 不管同一次运行里的 job 之间的顺序，那要靠 `needs`（`docker-floor` 排在 `docker` 之后）。跨仓库靠实例名区分：role 的是 `<role_name>-debian13`，collection 示例场景的是 `<collection_name>-example-debian13`（下划线换成 `-`）。脚手架自测同理：`test-template.yml` 整体排队，`smoke-role-floor` 排在 `smoke-role` 之后。

> 脚手架自测的 `smoke-role-vagrant`（gate 到 main/dispatch）用同款配置端到端跑这条轨。

**备选 host-mode**：删掉该 job 的 `container:`（及起 libvirtd 的步骤），由 runner 主机自带 vagrant/libvirt/KVM——会在宿主留下 box/VM。
