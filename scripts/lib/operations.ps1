Set-StrictMode -Version Latest

. "$PSScriptRoot\config.ps1"
. "$PSScriptRoot\git-utils.ps1"
. "$PSScriptRoot\backup.ps1"

function Initialize-SyncTool {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $toolConfig = Get-ToolConfig -Tool $Tool
    Assert-GitInstalled

    Write-Host ""
    Write-Host "初始化 $($toolConfig.DisplayName)" -ForegroundColor Cyan
    Write-Host "路径：$($toolConfig.Path)"
    Write-Host "仓库：$($toolConfig.Repo)"

    if (-not (Test-Path -LiteralPath $toolConfig.Path)) {
        Write-Host "目录不存在，开始 clone 远程仓库。"
        Invoke-Git -Arguments @('clone', $toolConfig.Repo, $toolConfig.Path) | Out-Null
        Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
        Ensure-Branch -ToolConfig $toolConfig
        Write-RepoStatus -ToolConfig $toolConfig
        return
    }

    if (Test-GitRepository -Path $toolConfig.Path) {
        $origin = Get-GitOrigin -Path $toolConfig.Path
        if ([string]::IsNullOrWhiteSpace($origin)) {
            Write-Host "$($toolConfig.DisplayName) 已经是 Git 仓库，但没有 origin。" -ForegroundColor Yellow
            Write-Host "配置 origin：$($toolConfig.Repo)"
            Write-Host ""
            Write-Host "1. 取消"
            Write-Host "2. 现在绑定配置里的 origin"
            $choice = Read-Host "请选择"
            if ($choice -ne '2') {
                Write-Host "已取消。"
                return
            }

            $answer = Read-Host "输入 REBIND 确认绑定配置里的 origin"
            if ($answer -ne 'REBIND') {
                Write-Host "已取消。"
                return
            }

            $backupPath = New-ToolBackup -ToolConfig $toolConfig
            Write-Host "已创建备份：$backupPath"
            Invoke-Git -RepoPath $toolConfig.Path -Arguments @('remote', 'add', 'origin', $toolConfig.Repo) | Out-Null
            Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
            Ensure-Branch -ToolConfig $toolConfig
            Invoke-Git -RepoPath $toolConfig.Path -Arguments @('fetch', 'origin') -AllowFailure | Out-Null
            Write-RepoStatus -ToolConfig $toolConfig
            return
        }

        if (-not (Test-OriginMatches -Actual $origin -Expected $toolConfig.Repo)) {
            Write-Host "$($toolConfig.DisplayName) 已经绑定到另一个仓库。" -ForegroundColor Yellow
            Write-Host "当前 origin：$origin"
            Write-Host "配置 origin：$($toolConfig.Repo)"
            Write-Host ""
            Write-Host "1. 取消"
            Write-Host "2. 现在重新绑定到配置里的 origin"
            $choice = Read-Host "请选择"
            if ($choice -ne '2') {
                Write-Host "已取消。"
                return
            }

            Rebind-SyncTool -Tool $Tool
            return
        }

        Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
        Ensure-Branch -ToolConfig $toolConfig
        Invoke-Git -RepoPath $toolConfig.Path -Arguments @('fetch', 'origin') -AllowFailure | Out-Null
        Write-RepoStatus -ToolConfig $toolConfig
        return
    }

    Write-Host "$($toolConfig.DisplayName) 目录已存在，但还不是 Git 仓库。" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 取消"
    Write-Host "2. 使用当前本地文件作为源，并绑定配置里的远程仓库"
    Write-Host "3. 备份当前目录，然后把配置里的远程仓库 clone 到这里"
    $choice = Read-Host "请选择"
    if ($choice -eq '1' -or [string]::IsNullOrWhiteSpace($choice)) {
        Write-Host "已取消。"
        return
    }

    if ($choice -eq '3') {
        $answer = Read-Host "输入 REPLACE 确认移动当前目录到备份，并 clone 远程仓库"
        if ($answer -ne 'REPLACE') {
            Write-Host "已取消。"
            return
        }

        $backupPath = Move-ToolDirectoryToBackup -ToolConfig $toolConfig
        Write-Host "当前目录已移动到备份：$backupPath"
        Invoke-Git -Arguments @('clone', $toolConfig.Repo, $toolConfig.Path) | Out-Null
        Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
        Ensure-Branch -ToolConfig $toolConfig
        Write-RepoStatus -ToolConfig $toolConfig
        return
    }

    if ($choice -ne '2') {
        Write-Host "无效选择，已取消。"
        return
    }

    $answer = Read-Host "输入 YES 确认在当前目录初始化 Git"
    if ($answer -ne 'YES') {
        Write-Host "已取消。"
        return
    }

    $backupPath = New-ToolBackup -ToolConfig $toolConfig -FullDirectory
    Write-Host "已创建备份：$backupPath"

    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('init') | Out-Null
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('checkout', '-B', $toolConfig.Branch) | Out-Null
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('remote', 'add', 'origin', $toolConfig.Repo) | Out-Null
    Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('fetch', 'origin') -AllowFailure | Out-Null
    Write-RepoStatus -ToolConfig $toolConfig
}

function Initialize-AllSyncTools {
    Initialize-SyncTool -Tool 'codex'
    Initialize-SyncTool -Tool 'claude'
}

function Pull-SyncTool {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $toolConfig = Get-ToolConfig -Tool $Tool
    Assert-GitInstalled
    Assert-RepoReady -ToolConfig $toolConfig

    Write-Host ""
    Write-Host "拉取 $($toolConfig.DisplayName)" -ForegroundColor Cyan
    $backupPath = New-ToolBackup -ToolConfig $toolConfig
    Write-Host "拉取前备份：$backupPath"

    Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('pull', '--no-rebase', 'origin', $toolConfig.Branch) | Out-Null
    Write-Host "$($toolConfig.DisplayName) 拉取完成。"
}

function Pull-AllSyncTools {
    Pull-SyncTool -Tool 'codex'
    Pull-SyncTool -Tool 'claude'
}

function Push-SyncTool {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $toolConfig = Get-ToolConfig -Tool $Tool
    Assert-GitInstalled
    Assert-RepoReady -ToolConfig $toolConfig

    Write-Host ""
    Write-Host "推送 $($toolConfig.DisplayName)" -ForegroundColor Cyan
    Ensure-WhitelistGitIgnore -ToolConfig $toolConfig
    Ensure-Branch -ToolConfig $toolConfig
    Add-TrackedPaths -ToolConfig $toolConfig

    if (-not (Test-StagedChanges -Path $toolConfig.Path)) {
        Write-Host "没有变化。"
        return
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('commit', '-m', "sync $($toolConfig.Name) $timestamp") | Out-Null
    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('push', '-u', 'origin', $toolConfig.Branch) | Out-Null
    Write-Host "$($toolConfig.DisplayName) 推送完成。"
}

function Push-AllSyncTools {
    Push-SyncTool -Tool 'codex'
    Push-SyncTool -Tool 'claude'
}

function Show-SyncStatus {
    Assert-GitInstalled
    foreach ($toolConfig in Get-AllToolConfigs) {
        Write-RepoStatus -ToolConfig $toolConfig
    }
}

function Rebind-SyncTool {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $toolConfig = Get-ToolConfig -Tool $Tool
    Assert-GitInstalled

    if (-not (Test-Path -LiteralPath $toolConfig.Path)) {
        throw "$($toolConfig.DisplayName) 目录不存在：$($toolConfig.Path)"
    }
    if (-not (Test-GitRepository -Path $toolConfig.Path)) {
        throw "$($toolConfig.DisplayName) 目录不是 Git 仓库：$($toolConfig.Path)"
    }

    $currentOrigin = Get-GitOrigin -Path $toolConfig.Path
    Write-Host ""
    Write-Host "重新绑定 $($toolConfig.DisplayName)" -ForegroundColor Yellow
    Write-Host "当前 origin："
    Write-Host "$currentOrigin"
    Write-Host ""
    Write-Host "配置 origin："
    Write-Host "$($toolConfig.Repo)"
    Write-Host ""
    Write-Host "将会执行："
    Write-Host "1. 备份当前同步文件"
    Write-Host "2. 保存当前 Git remote 信息"
    Write-Host "3. 修改 origin 为配置仓库"
    Write-Host "4. fetch 新远程"
    Write-Host "5. 不 reset、不覆盖、不自动合并文件"

    $answer = Read-Host "输入 REBIND 继续"
    if ($answer -ne 'REBIND') {
        Write-Host "已取消。"
        return
    }

    $backupPath = New-ToolBackup -ToolConfig $toolConfig
    Write-Host "已创建备份：$backupPath"

    if ([string]::IsNullOrWhiteSpace($currentOrigin)) {
        Invoke-Git -RepoPath $toolConfig.Path -Arguments @('remote', 'add', 'origin', $toolConfig.Repo) | Out-Null
    }
    else {
        Invoke-Git -RepoPath $toolConfig.Path -Arguments @('remote', 'set-url', 'origin', $toolConfig.Repo) | Out-Null
    }

    Invoke-Git -RepoPath $toolConfig.Path -Arguments @('fetch', 'origin') -AllowFailure | Out-Null
    Write-RepoStatus -ToolConfig $toolConfig
}

