Set-StrictMode -Version Latest

function Invoke-Git {
    param(
        [string] $RepoPath,
        [Parameter(Mandatory = $true)] [string[]] $Arguments,
        [switch] $AllowFailure
    )

    $allArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($RepoPath)) {
        $allArgs += @('-C', $RepoPath)
    }
    $allArgs += $Arguments

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git @allArgs 2>&1 | ForEach-Object { $_.ToString() }
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $message = ($output -join [Environment]::NewLine)
        if ([string]::IsNullOrWhiteSpace($message)) {
            $message = "git $($Arguments -join ' ') failed with exit code $exitCode"
        }
        throw $message
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Assert-GitInstalled {
    $result = Invoke-Git -Arguments @('--version') -AllowFailure
    if ($result.ExitCode -ne 0) {
        throw "找不到 Git。请先安装 Git for Windows，并确认 git 命令可用。"
    }
}

function Test-GitRepository {
    param([Parameter(Mandatory = $true)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $result = Invoke-Git -RepoPath $Path -Arguments @('rev-parse', '--is-inside-work-tree') -AllowFailure
    return ($result.ExitCode -eq 0 -and ($result.Output -join '').Trim() -eq 'true')
}

function Get-GitOrigin {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $result = Invoke-Git -RepoPath $Path -Arguments @('remote', 'get-url', 'origin') -AllowFailure
    if ($result.ExitCode -ne 0) {
        return $null
    }

    return ($result.Output -join [Environment]::NewLine).Trim()
}

function Test-OriginMatches {
    param(
        [Parameter(Mandatory = $true)] [string] $Actual,
        [Parameter(Mandatory = $true)] [string] $Expected
    )

    return $Actual.Trim().TrimEnd('/') -eq $Expected.Trim().TrimEnd('/')
}

function Assert-RepoReady {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    if (-not (Test-Path -LiteralPath $ToolConfig.Path)) {
        throw "$($ToolConfig.DisplayName) 目录不存在：$($ToolConfig.Path)"
    }

    if (-not (Test-GitRepository -Path $ToolConfig.Path)) {
        throw "$($ToolConfig.DisplayName) 目录还不是 Git 仓库：$($ToolConfig.Path)。请先运行初始化。"
    }

    $origin = Get-GitOrigin -Path $ToolConfig.Path
    if ([string]::IsNullOrWhiteSpace($origin)) {
        throw "$($ToolConfig.DisplayName) 仓库没有 origin。请先重新绑定远程仓库。"
    }

    if (-not (Test-OriginMatches -Actual $origin -Expected $ToolConfig.Repo)) {
        throw "$($ToolConfig.DisplayName) origin 和 config.json 不一致。当前：$origin；配置：$($ToolConfig.Repo)"
    }
}

function Ensure-WhitelistGitIgnore {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    $gitIgnorePath = Join-Path $ToolConfig.Path '.gitignore'
    $expected = $ToolConfig.GitIgnoreContent

    if ((Test-Path -LiteralPath $gitIgnorePath)) {
        $current = Get-Content -Raw -LiteralPath $gitIgnorePath
        if ($current -eq $expected) {
            return
        }
    }

    Set-Content -LiteralPath $gitIgnorePath -Value $expected -Encoding UTF8
}

function Get-CurrentBranch {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $result = Invoke-Git -RepoPath $Path -Arguments @('branch', '--show-current') -AllowFailure
    return ($result.Output -join '').Trim()
}

function Ensure-Branch {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    $branch = Get-CurrentBranch -Path $ToolConfig.Path
    if ([string]::IsNullOrWhiteSpace($branch)) {
        Invoke-Git -RepoPath $ToolConfig.Path -Arguments @('checkout', '-B', $ToolConfig.Branch) | Out-Null
        return
    }

    if ($branch -ne $ToolConfig.Branch) {
        Write-Host "$($ToolConfig.DisplayName) 当前分支是 $branch，配置分支是 $($ToolConfig.Branch)。" -ForegroundColor Yellow
    }
}

function Get-WorkingTreeLines {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $result = Invoke-Git -RepoPath $Path -Arguments @('status', '--porcelain') -AllowFailure
    return @($result.Output)
}

function Get-AheadBehindText {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    Invoke-Git -RepoPath $ToolConfig.Path -Arguments @('fetch', 'origin') -AllowFailure | Out-Null

    $remoteRef = "origin/$($ToolConfig.Branch)"
    $remoteCheck = Invoke-Git -RepoPath $ToolConfig.Path -Arguments @('rev-parse', '--verify', '--quiet', $remoteRef) -AllowFailure
    if ($remoteCheck.ExitCode -ne 0) {
        return "远程分支不存在或尚未 fetch：$remoteRef"
    }

    $branch = Get-CurrentBranch -Path $ToolConfig.Path
    if ([string]::IsNullOrWhiteSpace($branch)) {
        $branch = $ToolConfig.Branch
    }

    $result = Invoke-Git -RepoPath $ToolConfig.Path -Arguments @('rev-list', '--left-right', '--count', "$branch...$remoteRef") -AllowFailure
    if ($result.ExitCode -ne 0) {
        return "无法计算 ahead/behind"
    }

    $parts = (($result.Output -join ' ').Trim() -split '\s+')
    if ($parts.Count -lt 2) {
        return "无法计算 ahead/behind"
    }

    return "领先 $($parts[0])，落后 $($parts[1])"
}

function Add-TrackedPaths {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    $paths = @('.gitignore')
    foreach ($relative in $ToolConfig.TrackPaths) {
        $full = Join-Path $ToolConfig.Path $relative
        if (Test-Path -LiteralPath $full) {
            $paths += $relative
        }
    }

    Invoke-Git -RepoPath $ToolConfig.Path -Arguments (@('add', '--') + $paths) | Out-Null
}

function Test-StagedChanges {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $result = Invoke-Git -RepoPath $Path -Arguments @('diff', '--cached', '--quiet') -AllowFailure
    return $result.ExitCode -ne 0
}

function Write-RepoStatus {
    param([Parameter(Mandatory = $true)] $ToolConfig)

    Write-Host ""
    Write-Host "$($ToolConfig.DisplayName):" -ForegroundColor Cyan
    Write-Host "  路径：$($ToolConfig.Path)"
    Write-Host "  路径存在：$(if (Test-Path -LiteralPath $ToolConfig.Path) { '是' } else { '否' })"

    if (-not (Test-Path -LiteralPath $ToolConfig.Path)) {
        return
    }

    $isRepo = Test-GitRepository -Path $ToolConfig.Path
    Write-Host "  Git 仓库：$(if ($isRepo) { '是' } else { '否' })"
    if (-not $isRepo) {
        return
    }

    $origin = Get-GitOrigin -Path $ToolConfig.Path
    Write-Host "  当前 origin：$origin"
    Write-Host "  配置 origin：$($ToolConfig.Repo)"
    Write-Host "  origin 匹配：$(if ($origin -and (Test-OriginMatches -Actual $origin -Expected $ToolConfig.Repo)) { '是' } else { '否' })"
    Write-Host "  当前分支：$(Get-CurrentBranch -Path $ToolConfig.Path)"

    $dirty = Get-WorkingTreeLines -Path $ToolConfig.Path
    Write-Host "  工作区状态：$(if ($dirty.Count -eq 0) { '干净' } else { '有变更' })"
    Write-Host "  领先/落后：$(Get-AheadBehindText -ToolConfig $ToolConfig)"

    if ($dirty.Count -gt 0) {
        Write-Host "  变更列表："
        foreach ($line in ($dirty | Select-Object -First 30)) {
            Write-Host "    $line"
        }
        if ($dirty.Count -gt 30) {
            Write-Host "    ... 还有 $($dirty.Count - 30) 条"
        }
    }
}

