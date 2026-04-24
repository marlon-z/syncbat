# AI 同步管理器设计文档

日期：2026-04-24

## 目标

做一个个人使用的 Windows PowerShell 同步管理器，用来让两台 Windows 电脑上的 Codex 和 Claude Code 状态保持一致。

日常使用流程是：

1. 离开当前电脑前，把当前 AI 工具状态推送到 GitHub。
2. 到另一台电脑后，先从 GitHub 拉取最新状态再开始工作。
3. Codex 和 Claude Code 分别使用独立的 GitHub 私有仓库。
4. 当前 `syncbat` 项目只放同步脚本和说明，不存放 Codex 或 Claude 的真实数据。

## 核心决策

Codex 和 Claude Code 的用户目录各自作为一个 Git 仓库管理：

```text
%USERPROFILE%\.codex   -> codex-sync GitHub 仓库
%USERPROFILE%\.claude  -> claude-sync GitHub 仓库
```

`syncbat` 仓库只保存：

```text
syncbat/
  README.md
  config.example.json
  config.json
  sync.ps1
  01-初始化.cmd
  02-拉取全部.cmd
  03-拉取Codex.cmd
  04-拉取Claude.cmd
  05-推送全部.cmd
  06-推送Codex.cmd
  07-推送Claude.cmd
  scripts/
```

`config.json` 是本机配置文件，不应该提交到 Git。

## 同步范围

### Codex

Codex 同步根目录：

```text
%USERPROFILE%\.codex
```

需要同步的文件和目录：

```text
config.toml
sessions/
skills/
```

明确不需要同步的示例：

```text
auth.json
cap_sid
installation_id
*.sqlite
*.sqlite-shm
*.sqlite-wal
cache/
log/
tmp/
.sandbox/
.sandbox-bin/
.sandbox-secrets/
generated_images/
models_cache.json
sandbox.log
state_*
logs_*
```

MCP 配置只通过 `config.toml` 同步。MCP 的登录状态、缓存、token、本地 secret 不同步。

建议在 `%USERPROFILE%\.codex` 里使用白名单 `.gitignore`：

```gitignore
*
!.gitignore
!config.toml
!sessions/
!sessions/**
!skills/
!skills/**
skills/**/dist/
skills/**/build/
skills/**/target/
skills/**/node_modules/
skills/**/.cache/
skills/**/__pycache__/
skills/**/*.exe
skills/**/*.dll
skills/**/*.zip
skills/**/*.7z
skills/**/*.tar
skills/**/*.gz
skills/**/*.bin
```

### Claude Code

Claude Code 同步根目录：

```text
%USERPROFILE%\.claude
```

需要同步的文件和目录：

```text
settings.json
history.jsonl
skills/
projects/
sessions/
```

明确不需要同步的示例：

```text
.credentials.json
cache/
debug/
downloads/
file-history/
ide/
paste-cache/
session-env/
shell-snapshots/
statsig/
telemetry/
todos/
backups/
```

建议在 `%USERPROFILE%\.claude` 里使用白名单 `.gitignore`：

```gitignore
*
!.gitignore
!settings.json
!history.jsonl
!skills/
!skills/**
!projects/
!projects/**
!sessions/
!sessions/**
skills/**/dist/
skills/**/build/
skills/**/target/
skills/**/node_modules/
skills/**/.cache/
skills/**/__pycache__/
skills/**/*.exe
skills/**/*.dll
skills/**/*.zip
skills/**/*.7z
skills/**/*.tar
skills/**/*.gz
skills/**/*.bin
```

## 配置文件

`config.example.json` 用来说明本机配置格式：

```json
{
  "backupRoot": "%USERPROFILE%\\.ai-sync-backups",
  "backupRetention": 3,
  "codex": {
    "path": "%USERPROFILE%\\.codex",
    "repo": "git@github.com:yourname/codex-sync.git",
    "branch": "main"
  },
  "claude": {
    "path": "%USERPROFILE%\\.claude",
    "repo": "git@github.com:yourname/claude-sync.git",
    "branch": "main"
  }
}
```

脚本需要支持展开 Windows 环境变量，例如 `%USERPROFILE%`。

## 脚本入口

主入口有两类：

1. 交互式入口：适合查看菜单、手动选择操作。
2. 双击入口：适合日常直接执行固定动作。

交互式入口：

```powershell
.\sync.ps1
```

交互式菜单：

```text
AI Sync Manager

1. First-time setup / 初始化
2. Pull all / 拉取 Codex + Claude
3. Push all / 推送 Codex + Claude
4. Status / 查看状态
5. Codex only / 只操作 Codex
6. Claude only / 只操作 Claude
7. Rebind remote / 重新绑定仓库
0. Exit / 退出
```

Codex 子菜单：

```text
Codex

1. Setup / 初始化
2. Pull / 拉取
3. Push / 推送
4. Status / 查看状态
5. Rebind remote / 重新绑定仓库
0. Back / 返回
```

Claude 子菜单和 Codex 子菜单保持一致。

## 双击执行脚本

为了方便日常使用，根目录提供 7 个可以双击执行的 `.cmd` 文件：

```text
01-初始化.cmd       # 初始化 Codex + Claude
02-拉取全部.cmd     # 拉取 Codex + Claude
03-拉取Codex.cmd    # 只拉取 Codex
04-拉取Claude.cmd   # 只拉取 Claude
05-推送全部.cmd     # 推送 Codex + Claude
06-推送Codex.cmd    # 只推送 Codex
07-推送Claude.cmd   # 只推送 Claude
```

这 7 个 `.cmd` 只作为启动器，不直接写复杂逻辑。它们负责调用对应的 PowerShell 脚本，并在执行结束后暂停窗口，方便用户看到成功、失败或冲突提示。

示例行为：

```text
01-初始化.cmd      -> powershell -ExecutionPolicy Bypass -File .\scripts\setup-all.ps1
02-拉取全部.cmd    -> powershell -ExecutionPolicy Bypass -File .\scripts\pull-all.ps1
03-拉取Codex.cmd   -> powershell -ExecutionPolicy Bypass -File .\scripts\pull-codex.ps1
04-拉取Claude.cmd  -> powershell -ExecutionPolicy Bypass -File .\scripts\pull-claude.ps1
05-推送全部.cmd    -> powershell -ExecutionPolicy Bypass -File .\scripts\push-all.ps1
06-推送Codex.cmd   -> powershell -ExecutionPolicy Bypass -File .\scripts\push-codex.ps1
07-推送Claude.cmd  -> powershell -ExecutionPolicy Bypass -File .\scripts\push-claude.ps1
```

使用 `.cmd` 而不是让用户直接双击 `.ps1`，是为了减少 Windows PowerShell 执行策略和文件关联带来的问题。

熟悉之后，也可以直接调用底层脚本：

```text
scripts/
  setup-all.ps1
  setup-codex.ps1
  setup-claude.ps1
  pull-codex.ps1
  pull-claude.ps1
  push-codex.ps1
  push-claude.ps1
  pull-all.ps1
  push-all.ps1
  status.ps1
  rebind-codex.ps1
  rebind-claude.ps1
```

共享逻辑放在：

```text
scripts/lib/
  config.ps1
  git-utils.ps1
  backup.ps1
  menu.ps1
```

## 初始化行为

初始化必须保守。脚本需要先判断目标目录状态，不能静默做破坏性操作。

### 目标目录不存在

行为：

1. 直接把配置里的仓库 clone 到目标路径。
2. 写入或检查白名单 `.gitignore`。
3. 获取分支状态。
4. 显示最终状态。

示例：

```text
git clone <repo> %USERPROFILE%\.codex
```

### 目标目录存在，但不是 Git 仓库

行为：

1. 显示当前目录存在，但还不是 Git 仓库。
2. 在初始化窗口里给用户选择：

```text
1. Cancel
2. Use current local files as the source and bind the configured remote
3. Back up current directory, then clone the configured remote into this path
```

选择 2 时：

1. 先把当前目标目录备份到：

```text
%USERPROFILE%\.ai-sync-backups\<tool>\<timestamp>\
```

2. 要求输入 `YES` 二次确认。
3. 用户确认后，在现有目录里执行 `git init`。
4. 切换或创建配置里的分支。
5. 绑定配置里的 `origin`。
6. 写入或检查白名单 `.gitignore`。
7. fetch 远程状态，并显示当前状态。

这个流程适合当前机器已经有 Codex 或 Claude 数据，但还没有 Git 仓库的场景。脚本不会删除现有目录，也不会自动用远程内容覆盖本地内容。

选择 3 时：

1. 要求输入 `REPLACE` 二次确认。
2. 把当前目标目录整体移动到备份目录。
3. 从配置里的远程仓库 clone 到目标路径。
4. 写入或检查白名单 `.gitignore`。
5. 显示当前状态。

这个流程适合新电脑上已有旧数据，但用户希望直接以 GitHub 仓库内容为准的场景。

### 目标目录存在，并且是 Git 仓库，origin 正确

行为：

1. 检查 `origin` 是否和 `config.json` 一致。
2. 写入或检查 `.gitignore`。
3. fetch 远程状态。
4. 显示本地分支是 clean、ahead、behind 还是 diverged。

### 目标目录存在，并且是 Git 仓库，但 origin 不一致

行为：

1. 停止自动初始化流程。
2. 打印当前 `origin`。
3. 打印配置里的 `origin`。
4. 在初始化窗口里给用户选择：

```text
1. Cancel
2. Rebind to configured origin now
```

5. 如果用户选择取消，则不做任何修改。
6. 如果用户选择重新绑定，则继续要求输入 `REBIND` 进行二次确认。
7. 确认后备份当前同步范围，执行 `git remote set-url origin <configured repo>`，然后 fetch 新远程。

初始化脚本不能静默执行 `git remote set-url`，必须由用户在初始化界面里主动选择并确认。

### 目标目录存在，并且是 Git 仓库，但没有 origin

行为：

1. 停止自动初始化流程。
2. 说明当前仓库没有 `origin`。
3. 在初始化窗口里给用户选择：

```text
1. Cancel
2. Bind configured origin now
```

4. 如果用户选择取消，则不做任何修改。
5. 如果用户选择绑定，则继续要求输入 `REBIND` 进行二次确认。
6. 确认后备份当前同步范围，执行 `git remote add origin <configured repo>`，然后 fetch 新远程。

## 拉取行为

拉取脚本：

```text
pull-codex.ps1
pull-claude.ps1
pull-all.ps1
```

每次拉取前，脚本必须：

1. 检查配置路径是否存在。
2. 检查目标路径是否是 Git 仓库。
3. 检查 `origin` 是否和配置里的仓库一致。
4. 只备份本工具允许同步的范围。
5. 执行 `git pull --rebase`。

Codex 备份范围：

```text
config.toml
sessions/
skills/
```

Claude 备份范围：

```text
settings.json
history.jsonl
skills/
projects/
sessions/
```

如果 Git 出现冲突，脚本停止并打印简短的冲突处理提示，不自动解决冲突。

## 推送行为

推送脚本：

```text
push-codex.ps1
push-claude.ps1
push-all.ps1
```

每次推送时，脚本必须：

1. 检查配置路径是否存在。
2. 检查目标路径是否是 Git 仓库。
3. 检查 `origin` 是否和配置里的仓库一致。
4. 写入或检查白名单 `.gitignore`。
5. 只 add 允许同步的文件和目录。
6. 如果没有 staged changes，打印 `No changes` 并退出。
7. 使用带时间戳的 commit message。
8. push 到配置的分支。

Codex add 范围：

```text
git add .gitignore config.toml sessions skills
```

Claude add 范围：

```text
git add .gitignore settings.json history.jsonl skills projects sessions
```

Commit message 格式：

```text
sync codex 2026-04-24 10:35:00
sync claude 2026-04-24 10:35:00
```

## 重新绑定远程仓库

重新绑定远程仓库是高风险动作，必须显式触发。

菜单入口：

```text
7. Rebind remote / 重新绑定仓库
```

直接脚本：

```text
rebind-codex.ps1
rebind-claude.ps1
```

执行前必须显示：

```text
Current origin:
<current>

Configured origin:
<configured>

This will:
1. Back up current sync files
2. Save current Git remote information
3. Change origin to the configured repository
4. Fetch the new remote
5. Not reset, overwrite, or auto-merge files
```

要求用户输入明确确认：

```text
Type REBIND to continue:
```

确认后执行：

```text
git remote set-url origin <configured repo>
git fetch origin
```

脚本不能自动执行 `git reset --hard`。

## 状态检查

`status.ps1` 需要报告 Codex 和 Claude 两边的状态：

```text
Codex:
  Path exists: yes/no
  Git repo: yes/no
  Origin: ...
  Config origin: ...
  Branch: ...
  Remote branch: ...
  Working tree: clean/dirty
  Ahead/behind: ...

Claude:
  ...
```

状态检查只能读信息，不能修改任何文件或 Git 状态。

## 备份策略

备份根目录：

```text
%USERPROFILE%\.ai-sync-backups
```

备份目录结构：

```text
%USERPROFILE%\.ai-sync-backups\
  codex\
    20260424-103500\
      config.toml
      sessions/
      skills/
      remote.txt
  claude\
    20260424-103500\
      settings.json
      history.jsonl
      skills/
      projects/
      sessions/
      remote.txt
```

拉取和 rebind 会自动创建备份。初始化时，如果已有非 Git 目录需要被替换，也必须先创建备份。

推送不需要备份，因为推送不会覆盖本地状态。

备份只保留最近 3 份。每次创建新备份后，脚本会按时间清理旧备份，避免长期占用太多磁盘空间。保留数量由 `config.json` 里的 `backupRetention` 控制，默认值为 `3`。

## 冲突和安全规则

脚本必须遵守这些规则：

1. 不静默覆盖已有的非 Git AI 目录。
2. 不静默修改 Git remote。
3. 不同步凭据、认证文件、缓存、日志、SQLite 状态库、sandbox 状态或 telemetry。
4. 不自动执行 `git reset --hard`。
5. 遇到 Git 冲突就停止，并打印冲突文件。
6. 初始化替换目录和 rebind 操作必须要求用户确认。
7. Codex 和 Claude 必须保持两个独立仓库。

## 日常使用流程

在当前电脑结束工作时：

```powershell
.\sync.ps1
# 选择 3. Push all
```

或者直接运行：

```powershell
.\scripts\push-all.ps1
```

到另一台电脑准备开始工作时：

```powershell
.\sync.ps1
# 选择 2. Pull all
```

或者直接运行：

```powershell
.\scripts\pull-all.ps1
```

## 新电脑初始化流程

在新的 Windows 电脑上：

1. clone 当前 `syncbat` 项目。
2. 复制 `config.example.json` 为 `config.json`。
3. 在 `config.json` 里填写 Codex 和 Claude 的 GitHub 私有仓库地址。
4. 运行：

```powershell
.\sync.ps1
# 选择 1. First-time setup
```

5. 检查脚本输出的状态。

## 实现备注

PowerShell 实现时，共享逻辑应该放在 `scripts/lib/`，保证直接脚本和交互式菜单使用同一套行为。

第一版不做压缩。Codex 和 Claude 的同步目录直接由 Git 管理，并通过白名单 `.gitignore` 限制同步范围。如果后续 session 文件数量导致 Git 性能明显变差，再考虑加压缩包方案。

第一版默认按 GitHub 私有仓库和 SSH remote 设计。HTTPS remote 也应该可用，因为脚本只比较 `config.json` 里的 remote 字符串，不强制要求 SSH 格式。
