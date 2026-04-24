$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. "$PSScriptRoot\lib\operations.ps1"

Pull-SyncTool -Tool 'codex'


