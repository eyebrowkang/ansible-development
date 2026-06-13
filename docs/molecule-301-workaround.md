# molecule-plugins 与 ansible-core 2.21（vagrant 场景）

## 背景：docker 为什么不用 molecule-plugins

molecule-plugins（最新 25.8.12，2025-08）已明显落后 molecule/ansible-core。实测其 **docker driver 的 `create.yml` 在 ansible-core 2.21 上运行时崩溃**（`object of type 'dict' has no attribute 'invocation'`，ansible-core 2.19+ 的 data-tagging 改动所致）。

因此本模板的 **docker 场景改用 molecule 内置的 `default`（delegated）driver + 自写的 `create.yml`/`destroy.yml`（`community.docker`）**，完全不依赖 molecule-plugins，兼容 ansible-core 2.21（已在本地 colima 上端到端验证通过）。

## vagrant 场景的同类风险 ⚠️

vagrant **只能**用 `molecule-plugins[vagrant]`（没有 ansible-native 替代）。它很可能存在与 docker driver 同样的 ansible-core 2.21 不兼容（data-tagging）。**截至目前尚未在 2.21 上实测过 vagrant 场景**。

请在你的 Linux + libvirt 机器上用 `make test-vm` 验证。若同样报 `invocation`/data-tagging 类错误，临时方案二选一：

- 在该 role 的 `pyproject.toml` 把 `ansible-core` 暂时 pin 到 `>=2.18,<2.19`（plugin 兼容的最后一个大版本）；
- 或等 molecule-plugins 发布兼容 2.21 的新版后解除 pin。

docker 场景不受影响（已 ansible-native）。

## molecule-plugins#301（vagrant 模块路径）

[molecule-plugins#301](https://github.com/ansible-community/molecule-plugins/issues/301)（截至 2026-06 仍未修复）：用 vagrant driver 时，molecule 生成的 playbook 调用 `vagrant` 模块，但该模块路径不在 Ansible 默认搜索路径上，报 `couldn't resolve module/action 'vagrant'`。

解法在 role 的 `Makefile` 的 `test-vm` 目标里——运行时从已安装的包计算路径（不硬编码 python 小版本）并导出：

```make
test-vm:
	ANSIBLE_LIBRARY="$(uv run python -c '...molecule_plugins.vagrant... + /modules')" \
	ANSIBLE_FILTER_PLUGINS="$(uv run python -c '...molecule... + /provisioner/ansible/plugins/filter')" \
	uv run molecule test -s vagrant
```

所以**用 `make test-vm` 跑 vagrant**，别直接 `molecule test -s vagrant`。CI 的 vagrant job 也调 `make test-vm`。#301 修复后，删掉这两行 export 并 `copier update` 推给所有 role 即可。
