# molecule-plugins 与 ansible-core 2.21（vagrant 场景）

## 背景：docker 为什么不用 molecule-plugins

molecule-plugins（最新 25.8.12，2025-08）已明显落后 molecule/ansible-core。实测其 **docker driver 的 `create.yml` 在 ansible-core 2.21 上运行时崩溃**（`object of type 'dict' has no attribute 'invocation'`，ansible-core 2.19+ 的 data-tagging 改动所致）。

因此本模板的 **docker 场景改用 molecule 内置的 `default`（delegated）driver + 自写的 `create.yml`/`destroy.yml`（`community.docker`）**，完全不依赖 molecule-plugins，兼容 ansible-core 2.21（已在本地 colima 上端到端验证通过）。

## vagrant 场景：已验证可用于 ansible-core 2.21 ✅

vagrant **只能**用 `molecule-plugins[vagrant]`（没有 ansible-native 替代）。曾担心它和 docker driver 一样在 2.21 上崩，但**已在 Arch Linux + libvirt 上实测 `make test-vm` 全流程通过**（`1 scenario (1 successful)`）——vagrant 插件没有 docker 插件那个 data-tagging 问题。此外脚手架自测的 `smoke-role-vagrant` job（容器化、gate 到 main/dispatch）在 CI 里持续跑这条轨。

万一未来某个 ansible-core 版本打破它，应急方案：把该 role 的 `ansible-core` 临时 pin 到兼容版本，或等 molecule-plugins 更新。docker 场景不受影响（已 ansible-native）。

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
