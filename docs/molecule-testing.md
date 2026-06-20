# Molecule 测试指南

molecule 的完整测试生命周期、本脚手架的取舍，以及如何把生成的 role/collection 的测试做深。

## 完整生命周期 vs 脚手架接了什么

molecule `test` 序列可用的步骤（按顺序）：

```
dependency → create → prepare → converge → idempotence → side_effect → verify → cleanup → destroy
```

脚手架生成的 docker 场景默认接的是：

```
dependency → destroy → syntax → create → converge → idempotence → verify → destroy
```

（`syntax` 在 create 前做一次 playbook 语法检查；开头的 `destroy` 保证从干净状态开始。）未默认接入 `prepare` / `side_effect` / `cleanup`——它们偏场景化，按需自行添加（见下文 ①）。

## 一、脚手架已经替你生成的测试结构

生成的 role（及 collection 的 example role）不再是"空壳"，而是一个**最小但真实的闭环**，每一处都标了 `replace with…`，照着扩展即可。

### converge 有可观测、幂等的效果

`tasks/main.yml` 的占位任务用 `copy` 管理一个 marker 文件，路径来自 `defaults/main.yml` 的 `<role>_marker_path` 变量。这让 `idempotence` 有东西可测（重跑必须 `changed=0`），也让 `verify` 有真实状态可断言。换成你的真实任务时，保持幂等。

### verify 走"系统真相"，不是同义反复

`verify.yml` 不再是 `assert: that: [true]`，而是用 `stat` + `slurp` 从**外侧**读目标的真实状态再断言：

```yaml
- ansible.builtin.stat: { path: /etc/<ns>.<role>.applied }
  register: marker
- ansible.builtin.assert:
    that: [marker.stat.exists, marker.stat.mode == "0644"]
```

**关键原则**：verify 读系统的真相（文件内容、`systemctl is-active`、监听端口、二进制 `--version`），**不要**复跑 role 的模块再信它的 `changed/ok` 返回——那是循环论证。当模块只能"自报"、只有系统知道真相时（服务是否真在跑、端口是否真在听），就用 `command`：

```yaml
- ansible.builtin.command: systemctl is-active --quiet foo
  changed_when: false
```

`verify.yml` 里已附了这些模式的注释示例，取消注释改成你的即可。

### 输入校验：meta/argument_specs.yml

声明 role 参数（类型、是否必填、`choices`；**默认值放在 `defaults/main.yml`**，不在 spec 里重复——spec 的 `default` 只在变量未定义时才生效，而 `defaults/` 总会定义它，所以那是个永不触发的死默认）。应用 role 时 Ansible 会在跑 `tasks/main.yml` **之前**自动校验，把坏输入变成清晰的提前失败——molecule converge 日志里能看到 `Validating arguments against arg spec 'main'`。这是惯用的输入校验 / 负向测试入口（见下文 ③）。

### floor CI：在声明的最低 ansible-core 上测

role 在 `meta/main.yml` 声明了 `min_ansible_version`。生成的 CI 里有一个 `molecule-floor`（GitHub）/ `docker-floor`（Forgejo）作业：建一个钉死在该最低版本的 venv 跑完整 docker 序列，**证明 role 真能在它声称的下限上跑**，而不只是开发用的较新版本。为不拖慢每个 PR，它只在 push 到 main / 手动 dispatch 时跑。

> ⚠️ floor 的可测范围受测试工具链约束：floor venv 钉在 **Python 3.12**（ansible-core < 2.18 不支持仓库默认的 Python 3.13，而 3.12 兼容 2.16–2.19），且 docker 场景用 `community.docker` 5.x（`requires_ansible: '>=2.17.0'`）。因此**role 的 `min_ansible_version` 必须 ≥ 2.17**（`copier.yml` 的校验器现在会拦下更低的值；上限 ≤ 2.19，受 ansible-lint meta-runtime 规则约束）。低于 2.17 的 floor 无法用 docker 场景验证——把 floor 调高到可测版本，或单独给 floor 作业换更老的 `community.docker`。

### check mode：make check

`make check` = `molecule converge -- --check`（`--` 后的参数透传给 ansible-playbook），干跑预览将发生的变更。**仅当 role 是 check-mode 安全的**（每个任务都支持 check mode）才有意义。

## 二、需要你自己接的进阶模式

下面这些偏场景化，默认生成会让 starter 变臃肿，所以脚手架不生成、只讲清楚怎么接。（小节编号沿用文首那张缺口表的固定 ID 以便对照；这里按 ID 升序排列。）

### ① 升级 / 脏状态测试：side_effect / prepare / cleanup

写 `molecule/default/side_effect.yml` 制造漂移（改配置、停服务、装旧版本），并**在现有 `test_sequence` 里插入** `side_effect → converge`（放在 `idempotence` 之后、`verify` 之前），让 role 再收敛一次、验证它能从脏状态恢复。注意是**插入，不是整段替换**——生成的序列已经带了 `destroy` / `syntax`，照抄会把它们丢掉：

```yaml
provisioner:
  playbooks:
    side_effect: side_effect.yml
scenario:
  # 生成的序列：[dependency, destroy, syntax, create, converge, idempotence, verify, destroy]
  # 在 idempotence 之后插入 side_effect, converge ↓
  test_sequence: [dependency, destroy, syntax, create, converge, idempotence, side_effect, converge, verify, destroy]
```

`prepare`（converge 前置条件，如预装依赖、铺测试数据）和 `cleanup`（destroy 前的外部清理，如删云资源）同理，分别配 `prepare.yml` / `cleanup.yml` 并插进序列。

### ② 变量矩阵 / feature flag 组合：多 scenario

每个 feature flag 组合建一个 scenario 目录，`converge` 设不同 vars：

```
molecule/
  default/        # 已生成
  minimal/        # converge 设 <role>_feature_x: false
  full/           # converge 设 <role>_feature_x: true
```

跑 `molecule test -s full`；CI 里用 `strategy.matrix` 遍历 scenario。

### ③ 负向测试：断言失败

`argument_specs.yml` 已给了输入校验的基础。要主动测"坏输入应失败"，建一个 negative scenario，converge 喂非法值并断言 role 失败：

```yaml
- name: Role must reject invalid input
  block:
    - ansible.builtin.include_role: { name: <ns>.<role> }
      vars: { <role>_marker_path: "" }   # 非法值
    - ansible.builtin.fail: { msg: "应当因非法输入失败，但没有" }
  rescue:
    - ansible.builtin.debug: { msg: "预期内的失败 — 通过" }
```

### ④ verify 深入：ansible verifier vs testinfra

脚手架用内建的 **ansible verifier**（`verify.yml`）——零额外依赖，且能用上你已熟悉的 ansible 模块。只要坚持"读系统真相"（`command` / `stat` / `service_facts`），它给的保证和 testinfra 是一样的。

若想从 Python 侧、以更"外部"的视角断言，可用 **testinfra**：

> ⚠️ molecule 各版本对内建 `verifier: name: testinfra` 的支持度不一。要么装 `pytest-testinfra` 用内建 verifier，要么直接 pytest 指向 molecule 的 inventory（环境变量 `MOLECULE_INVENTORY_FILE`）跑。不想引入就继续用 ansible verifier——照样能拿到系统真相级别的保证。

### ⑤ check mode（深入）

除了 `make check`，CI 里可加一个 check-mode 作业。注意：很多任务（`command` / `shell`、注册变量后续依赖等）默认不是 check-safe，需要 `check_mode:` / `changed_when:` 配合。把"是否 check-safe"当作 role 的一个显式目标来对待。

### ⑥ 多发行版：platforms 多镜像

`molecule.yml` 的 `platforms` 列多个镜像，molecule 为每个建实例并对全部跑 converge/verify：

```yaml
platforms:
  - { name: r-debian13, image: "geerlingguy/docker-debian13-ansible:latest", systemd: true }
  - { name: r-ubuntu2404, image: "geerlingguy/docker-ubuntu2404-ansible:latest", systemd: true }
```

CI 时长随发行版数量线性增长。

### ⑦ 多主机编排：多 instance + groups

`platforms` 配多台 + `groups`，converge 里用 `delegate_to` / `run_once` 编排（如先起 DB 再起 app）：

```yaml
platforms:
  - { name: db, image: "...", groups: [database] }
  - { name: app, image: "...", groups: [appserver] }
```

### ⑧ 多 ansible 版本（深入）

脚手架已下放了 floor 作业。要测更全的矩阵（floor + 当前 + 最新），用 CI 的 `strategy.matrix`，每个 matrix 项建对应 venv 跑 molecule（参考生成的 floor 作业写法）：

```yaml
strategy:
  matrix:
    ansible: ["2.19.0", "2.21"]   # floor + 当前
```

### ⑨ 从裸机 bootstrap

molecule 用**预装镜像 / 预装 box**（geerlingguy 镜像已带 python/systemd；vagrant box 已装好系统），所以它天然**测不了"从一台啥都没有的裸机开始"**那一段（最小化安装、首次联网、连 python 都没有时怎么打 bootstrap）。这没有 100% 解，诚实对待即可：

- 用 `prepare.yml` 把实例**回退**到更接近裸机的状态（卸掉非必要包、清缓存）来逼近，但仍非真正裸机。
- 真正的裸机引导（PXE、cloud-init、用 `raw` 模块装 python）要在镜像/VM 之外的层做，超出 molecule 范围；在 README 注明"假设目标已具备 X"即可。

## 速查

| 能力 | 状态 | 在哪 |
|---|---|---|
| 幂等的真实 converge 效果 | ✅ 已生成 | `tasks/main.yml`（marker） |
| verify 走系统真相 | ✅ 已生成 | `verify.yml` |
| 输入校验 | ✅ 已生成 | `meta/argument_specs.yml` |
| floor（最低 ansible-core） | ✅ 已生成 | CI 的 `*-floor` 作业 |
| check mode | ✅ 已生成 | `make check` |
| syntax 检查 | ✅ 已生成 | `test_sequence` |
| 升级/漂移（side_effect/prepare/cleanup） | 📖 本文 ① | 自行添加 |
| 变量矩阵（多 scenario） | 📖 本文 ② | 自行添加 |
| 负向测试（断言失败） | 📖 本文 ③ | 自行添加 |
| testinfra | 📖 本文 ④ | 可选 |
| check mode（CI 作业） | 📖 本文 ⑤ | 自行添加 |
| 多发行版 | 📖 本文 ⑥ | 自行添加 |
| 多主机编排 | 📖 本文 ⑦ | 自行添加 |
| 多 ansible 版本（全矩阵） | 📖 本文 ⑧ | 自行添加 |
| 裸机 bootstrap | 📖 本文 ⑨（无完美解） | 文档注明 |
