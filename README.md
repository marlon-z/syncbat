# syncbat

个人使用的 Windows AI 工具同步脚本，用 GitHub 私有仓库同步两台电脑上的 Codex 和 Claude Code 数据。

## 同步内容

Codex：

```text
%USERPROFILE%\.codex\config.toml
%USERPROFILE%\.codex\sessions\
%USERPROFILE%\.codex\skills\
```

Claude Code：

```text
%USERPROFILE%\.claude\settings.json
%USERPROFILE%\.claude\skills\
%USERPROFILE%\.claude\projects\
```

认证、token、缓存、日志、SQLite 状态库不会同步。

`skills/` 里的构建产物也不会同步，例如：

```text
skills/**/dist/
skills/**/build/
skills/**/target/
skills/**/node_modules/
skills/**/*.exe
skills/**/*.dll
skills/**/*.zip
```

这些文件通常可以重新安装或重新构建，不适合放进 GitHub。

## 第一次使用

1. 创建两个 GitHub 私有仓库，例如：

```text
codex-sync
claude-sync
```

2. 复制配置模板：

```powershell
Copy-Item .\config.example.json .\config.json
```

3. 修改 `config.json`，填入两个仓库地址。

4. 双击：

```text
01-初始化.cmd
```

如果当前电脑已经有 `%USERPROFILE%\.codex` 或 `%USERPROFILE%\.claude`，但还不是 Git 仓库，初始化会先备份，再询问是否在现有目录中创建 Git 仓库并绑定远程。

## 日常使用

开始工作前，双击：

```text
02-拉取全部.cmd
```

结束工作后，双击：

```text
05-推送全部.cmd
```

也可以只操作其中一个：

```text
03-拉取Codex.cmd
04-拉取Claude.cmd
06-推送Codex.cmd
07-推送Claude.cmd
```

## 交互式菜单

也可以运行：

```powershell
.\sync.ps1
```

菜单里可以选择初始化、拉取、推送、查看状态、重新绑定仓库等操作。

## 备份

拉取、初始化现有目录、重新绑定仓库前会自动备份到：

```text
%USERPROFILE%\.ai-sync-backups
```

默认只保留最近 3 份备份，可以在 `config.json` 里调整：

```json
"backupRetention": 3
```
