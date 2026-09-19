[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$localFlutter = Join-Path $root '.tooling\flutter\bin\flutter.bat'
$flutterCommand = if (Test-Path -LiteralPath $localFlutter) { $localFlutter } else { (Get-Command flutter -ErrorAction Stop).Source }
Push-Location -LiteralPath $root
try {
    foreach ($arguments in @(
        @('pub', 'get'),
        @('analyze'),
        @('test', '--reporter', 'expanded'),
        @('build', 'apk', '--debug', '--target-platform', 'android-arm64')
    )) {
        $ErrorActionPreference = 'Continue'
        & $flutterCommand @arguments
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw "Flutter verification failed: $($arguments -join ' ')" }
    }
    & (Join-Path $PSScriptRoot 'lint-android.ps1')
} finally { Pop-Location }
