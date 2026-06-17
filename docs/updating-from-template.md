# 用 copier update 拉取模板更新

生成出来的 role / collection 都是 **copier 管理的 artifact**（带 `.copier-answers.yml`）。脚手架发新版（打了新的 `vX.Y.Z` tag）后，用 `copier update` 把模板改进**三方合并**回填进已有 artifact。下面这套流程 role 和 collection 通用。

## 前提

- artifact 是**独立 git 仓库**（生成后已 `git init`），且工作树**干净**——`copier update` 拒绝在有未提交改动时跑（`.venv/`、`.ansible/` 等被 gitignore 的不算）。
- `.copier-answers.yml` 里 `_src_path` 指向脚手架的**远程地址**（update 的 clone 源），`_commit` 记录当前模板版本。

## 步骤

```bash
cd <artifact 目录>            # roles/<ns>.<name> 或 collections/ansible_collections/<ns>/<name>
git switch main && git pull   # main 干净且最新
git switch -c chore/copier-update-vX.Y.Z   # 建议开分支走 PR 流程

uvx copier update --trust --defaults
```

- **为什么 `uvx` 而不是 `uv run`**：copier **不在 artifact 的依赖里**，在 artifact 目录跑 `uv run copier` 会找不到。`uvx copier`（= `uv tool run copier`）临时拉起 copier；也可 `uv tool install copier` 一次后直接 `copier update`。
- **`--defaults`**：用 `.copier-answers.yml` 记录的答案、不再交互提问（想逐项确认或改答案就去掉它，回车保留旧值）。
- **`--trust`**：模板带 `_message_after_copy` 等，加上以免被拦。
- copier 默认更新到**最新的 `vX.Y.Z` tag**（非 `v` 开头的 tag 忽略）。脚手架首版发布前、尚无 tag 时，用 `--vcs-ref=HEAD` 跟最新提交。

然后查冲突、验证、提交：

```bash
find . -name '*.rej'          # 期望无输出；有冲突就手动解决这些 .rej 再删掉
git diff                      # review；确认 .copier-answers.yml 的 _commit 升到了新版本
uv sync && make lint          # collection 再加 make sanity；都要绿
make test                     # docker molecule（可选，保险）

git add -A && git commit -m "chore: copier update to template vX.Y.Z"
git push -u origin <branch>
# 开 PR：GitHub 用 gh，Forgejo 用 fj。chore: 不触发发版。
```

## 会改动什么

- diff 取决于**自 `_commit` 记录的版本以来模板改了哪些文件**——这是模板可持续回填、选 copier 而非 cookiecutter 的核心价值。
- 你定制过的文件（业务逻辑、被你改过的 `meta` / CI 等）走三方合并：模板没动的地方**保留你的改动**；只有“模板动了、你也动了同一处”才出 `.rej`。
- 同版本（`_commit` 已是最新 tag）跑就是干净 **no-op**。
- 某个改进若你之前已**手动对齐**过（手改正好和新模板一致），那次 update 的 diff 会很小甚至为空——正常。

## 注意点

- **别手改 `.copier-answers.yml`**（除非有意改 `_src_path` / `_commit`）——它由 copier 维护。
- **网络**：update 会 clone `_src_path`（远程脚手架仓库）；慢或失败就重试。
- 脚手架自测（`.forgejo/workflows/test-template.yml` 的 `update-role` / `update-collection`）正是跑这套：在 PR base 生成 → update 到 HEAD → 断言无 `.rej` → 重新 lint。
