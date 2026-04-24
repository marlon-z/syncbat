Set-StrictMode -Version Latest

function Get-ProjectRoot {
    return (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

function Test-HasProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Expand-SyncPath {
    param([Parameter(Mandatory = $true)] [string] $Path)

    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Get-SyncConfig {
    $root = Get-ProjectRoot
    $configPath = Join-Path $root 'config.json'

    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "找不到 config.json。请先复制 config.example.json 为 config.json，并填写两个 GitHub 仓库地址。"
    }

    $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json

    foreach ($tool in @('codex', 'claude')) {
        if (-not (Test-HasProperty $config $tool)) {
            throw "config.json 缺少 $tool 配置。"
        }

        $toolConfig = $config.$tool
        foreach ($field in @('path', 'repo', 'branch')) {
            if ((-not (Test-HasProperty $toolConfig $field)) -or [string]::IsNullOrWhiteSpace($toolConfig.$field)) {
                throw "config.json 的 $tool.$field 不能为空。"
            }
        }
    }

    if ((-not (Test-HasProperty $config 'backupRoot')) -or [string]::IsNullOrWhiteSpace($config.backupRoot)) {
        $config | Add-Member -MemberType NoteProperty -Name backupRoot -Value '%USERPROFILE%\.ai-sync-backups'
    }

    if ((-not (Test-HasProperty $config 'backupRetention')) -or $null -eq $config.backupRetention) {
        $config | Add-Member -MemberType NoteProperty -Name backupRetention -Value 3
    }

    return $config
}

function Get-ToolSpec {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    if ($Tool -eq 'codex') {
        return [pscustomobject]@{
            Name = 'codex'
            DisplayName = 'Codex'
            TrackPaths = @('config.toml', 'sessions', 'skills')
            GitIgnoreContent = @'
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
'@
        }
    }

    return [pscustomobject]@{
        Name = 'claude'
        DisplayName = 'Claude'
        TrackPaths = @('settings.json', 'skills', 'projects')
        GitIgnoreContent = @'
*
!.gitignore
!settings.json
!skills/
!skills/**
!projects/
!projects/**
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
'@
    }
}

function Get-ToolConfig {
    param([Parameter(Mandatory = $true)] [ValidateSet('codex', 'claude')] [string] $Tool)

    $config = Get-SyncConfig
    $spec = Get-ToolSpec -Tool $Tool
    $toolConfig = $config.$Tool

    return [pscustomobject]@{
        Name = $spec.Name
        DisplayName = $spec.DisplayName
        Path = Expand-SyncPath $toolConfig.path
        Repo = $toolConfig.repo
        Branch = $toolConfig.branch
        BackupRoot = Expand-SyncPath $config.backupRoot
        BackupRetention = [int]$config.backupRetention
        TrackPaths = $spec.TrackPaths
        GitIgnoreContent = $spec.GitIgnoreContent.TrimEnd() + [Environment]::NewLine
    }
}

function Get-AllToolConfigs {
    return @(
        Get-ToolConfig -Tool 'codex'
        Get-ToolConfig -Tool 'claude'
    )
}

