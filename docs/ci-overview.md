# CI 总览

## 两个平台

| | runner | docker 场景 | vagrant 场景 |
|---|---|---|---|
| **GitHub Actions**（开源） | 公共 `ubuntu-latest` | ✓ 用 setup-uv | ✗（无可靠 KVM） |
| **Forgejo Actions**（自托管） | 你的 runner | ✓ 用 builder 镜像 | ✓ `[self-hosted, libvirt]` |

docker 轨是到处通用的主力；vagrant 轨落在你自托管、可控的 Forgejo。

> **driver 说明**：docker 场景用 molecule **内置 `default`（delegated）driver** + 自写 `create.yml`/`destroy.yml`（`community.docker`），不依赖 molecule-plugins，兼容 ansible-core 2.21。vagrant 场景用 `molecule-plugins[vagrant]`——其与 2.21 的兼容性尚未实测，详见 [molecule-301-workaround.md](molecule-301-workaround.md)。

## DooD（你的 runner）

你的 Forgejo runner 配置是 `docker_host: automount` + `privileged: true`：每个 job 起一个 privileged 容器，并把宿主 docker socket 挂进去。于是：

- molecule 跑在 job 容器里，但通过 socket 命令**宿主 daemon** 创建被测实例——实例是 job 容器的**兄弟**，不是嵌套在里面。
- docker 场景因此**不需要** job 容器特权；systemd 实例所需的 `privileged` / cgroup 由 `molecule.yml` 的 platform 指定，由宿主 daemon 满足。
- ⚠️ automount + privileged = **零隔离**：这台 runner 相当于把宿主 root 暴露给 workflow。**只跑你可信的代码**；公开仓库 / fork PR 放到 GitHub 公共 runner（沙箱化）。

## builder 镜像

`images/builder/` 把工具链预烤进镜像，推到 Forgejo registry，CI 容器 job 直接拉，免去每次现装。

因为 runner 是 `force_pull: false`，**必须用不可变 tag**（`YYYYMMDD-<sha>`），否则推了新 `:latest` 也不会被重新拉取。

需要在 Forgejo 配置：`vars.REGISTRY`（registry 主机）、`secrets.REGISTRY_TOKEN`（`package:write`）。

## vagrant job：host-mode vs 容器化

生成的 vagrant job 默认 `runs-on: [self-hosted, libvirt]` 且**不带 `container:`**（host-mode，沿用 restic 的可用做法——runner 主机自带 vagrant/libvirt/KVM）。

如果你的 libvirt runner 也是容器化的（像主 runner 那样跑在容器里），把该 job 改成带 `container:` 用 `ansible-builder-vagrant` 镜像 + `options: --privileged`（privileged 暴露 `/dev/kvm`）。
