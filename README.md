# Ansible development

个人的Ansible开发环境配置，用于ansible role和ansible collection的开发工作

## 依赖

### 主机依赖

适用于 Arch Linux

- qemu-full
- vagrant
- libvirt
- virt-manager
- dnsmasq
- nftables/iptabls-nft
- miniforge/miniconda3

### Vagrant 依赖

```shell
vagrant plugin install vagrant-libvirt
```

### Python 依赖

[environment.yml](./environment.yml)

## 环境配置

### 1. 创建 conda 环境

```shell
conda env create -f environment.yml
```

### 2. 配置激活脚本

```shell
conda activate ansible-dev
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
mkdir -p $CONDA_PREFIX/etc/conda/deactivate.d
ln -s $(pwd)/set_env.sh $CONDA_PREFIX/etc/conda/activate.d/set_env.sh
ln -s $(pwd)/unset_env.sh $CONDA_PREFIX/etc/conda/deactivate.d/unset_env.sh
```

### 3. 重新激活 conda 环境

```shell
conda deactivate
conda activate ansible-dev
```

## Thanks

- <https://github.com/ansible-community/molecule-plugins/issues/301#issuecomment-3518609714>
