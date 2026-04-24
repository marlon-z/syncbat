Set-StrictMode -Version Latest

. "$PSScriptRoot\operations.ps1"

function Invoke-SafeMenuAction {
    param([Parameter(Mandatory = $true)] [scriptblock] $Action)

    try {
        & $Action
    }
    catch {
        Write-Host ""
        Write-Host "执行失败：" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "按 Enter 返回菜单"
}

function Show-ToolMenu {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $title = if ($Tool -eq 'codex') { 'Codex' } else { 'Claude' }

    while ($true) {
        Clear-Host
        Write-Host "$title" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. 初始化"
        Write-Host "2. 拉取"
        Write-Host "3. 推送"
        Write-Host "4. 查看状态"
        Write-Host "5. 重新绑定仓库"
        Write-Host "0. 返回"
        Write-Host ""

        $choice = Read-Host "请选择"
        switch ($choice) {
            '1' { Invoke-SafeMenuAction { Initialize-SyncTool -Tool $Tool } }
            '2' { Invoke-SafeMenuAction { Pull-SyncTool -Tool $Tool } }
            '3' { Invoke-SafeMenuAction { Push-SyncTool -Tool $Tool } }
            '4' { Invoke-SafeMenuAction { Write-RepoStatus -ToolConfig (Get-ToolConfig -Tool $Tool) } }
            '5' { Invoke-SafeMenuAction { Rebind-SyncTool -Tool $Tool } }
            '0' { return }
            default {
                Write-Host "无效选择。"
                Start-Sleep -Seconds 1
            }
        }
    }
}

function Start-SyncMenu {
    while ($true) {
        Clear-Host
        Write-Host "AI Sync Manager" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. 初始化"
        Write-Host "2. 拉取全部"
        Write-Host "3. 推送全部"
        Write-Host "4. 查看状态"
        Write-Host "5. 只操作 Codex"
        Write-Host "6. 只操作 Claude"
        Write-Host "7. 重新绑定仓库"
        Write-Host "0. 退出"
        Write-Host ""

        $choice = Read-Host "请选择"
        switch ($choice) {
            '1' { Invoke-SafeMenuAction { Initialize-AllSyncTools } }
            '2' { Invoke-SafeMenuAction { Pull-AllSyncTools } }
            '3' { Invoke-SafeMenuAction { Push-AllSyncTools } }
            '4' { Invoke-SafeMenuAction { Show-SyncStatus } }
            '5' { Show-ToolMenu -Tool 'codex' }
            '6' { Show-ToolMenu -Tool 'claude' }
            '7' {
                Invoke-SafeMenuAction {
                    Rebind-SyncTool -Tool 'codex'
                    Rebind-SyncTool -Tool 'claude'
                }
            }
            '0' { return }
            default {
                Write-Host "无效选择。"
                Start-Sleep -Seconds 1
            }
        }
    }
}

