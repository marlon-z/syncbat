Set-StrictMode -Version Latest

function New-ToolBackup {
    param(
        [Parameter(Mandatory = $true)] $ToolConfig,
        [switch] $FullDirectory
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $toolBackupRoot = Join-Path $ToolConfig.BackupRoot $ToolConfig.Name
    $backupPath = Join-Path $toolBackupRoot $timestamp

    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

    if ($FullDirectory) {
        $dest = Join-Path $backupPath 'full'
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Get-ChildItem -LiteralPath $ToolConfig.Path -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
        }
    }
    else {
        foreach ($relative in $ToolConfig.TrackPaths) {
            $source = Join-Path $ToolConfig.Path $relative
            if (Test-Path -LiteralPath $source) {
                Copy-Item -LiteralPath $source -Destination $backupPath -Recurse -Force
            }
        }
    }

    if (Test-Path -LiteralPath $ToolConfig.Path) {
        $origin = $null
        if (Get-Command Get-GitOrigin -ErrorAction SilentlyContinue) {
            $origin = Get-GitOrigin -Path $ToolConfig.Path
        }
        if ($origin) {
            Set-Content -LiteralPath (Join-Path $backupPath 'remote.txt') -Value $origin -Encoding UTF8
        }
    }

    Remove-OldBackups -ToolConfig $ToolConfig
    return $backupPath
}

function Move-ToolDirectoryToBackup {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    if (-not (Test-Path -LiteralPath $ToolConfig.Path)) {
        throw "无法移动不存在的目录到备份：$($ToolConfig.Path)"
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $toolBackupRoot = Join-Path $ToolConfig.BackupRoot $ToolConfig.Name
    $backupPath = Join-Path $toolBackupRoot $timestamp
    $destination = Join-Path $backupPath 'full'

    New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

    $sourceResolved = (Resolve-Path -LiteralPath $ToolConfig.Path).Path
    $backupRootResolved = (Resolve-Path -LiteralPath $toolBackupRoot).Path
    $destinationParent = (Resolve-Path -LiteralPath $backupPath).Path

    if (-not $destinationParent.StartsWith($backupRootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw "备份移动目标路径异常，已停止：$destinationParent"
    }

    Move-Item -LiteralPath $sourceResolved -Destination $destination -Force
    Remove-OldBackups -ToolConfig $ToolConfig
    return $backupPath
}

function Remove-OldBackups {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    $toolBackupRoot = Join-Path $ToolConfig.BackupRoot $ToolConfig.Name
    if (-not (Test-Path -LiteralPath $toolBackupRoot)) {
        return
    }

    $retention = [Math]::Max(1, [int]$ToolConfig.BackupRetention)
    $rootResolved = (Resolve-Path -LiteralPath $toolBackupRoot).Path
    $oldBackups = Get-ChildItem -LiteralPath $toolBackupRoot -Directory |
        Sort-Object Name -Descending |
        Select-Object -Skip $retention

    foreach ($backup in $oldBackups) {
        $backupResolved = (Resolve-Path -LiteralPath $backup.FullName).Path
        if (-not $backupResolved.StartsWith($rootResolved, [StringComparison]::OrdinalIgnoreCase)) {
            throw "备份清理路径异常，已停止：$backupResolved"
        }

        Remove-Item -LiteralPath $backupResolved -Recurse -Force
    }
}

