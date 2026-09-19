[CmdletBinding()]
param(
    [string]$DeviceId,
    [switch]$InstallOnly,
    [switch]$SkipBuild,
    [switch]$Clean
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$flutterCommand = (Get-Command flutter -ErrorAction Stop).Source

function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    $preferenceBefore = $ErrorActionPreference
    try {
        # PowerShell 5.1 treats redirected native stderr warnings as errors.
        # Use the process exit code to decide whether the command failed.
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments | Out-Host
        $nativeExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $preferenceBefore }
    if ($nativeExit -ne 0) { throw "$Executable failed (exit $nativeExit)." }
}

Push-Location -LiteralPath $projectRoot
try {
    $adb = (Get-Command adb -ErrorAction Stop).Source
    $connected = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^(\S+)\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    if (-not $DeviceId) {
        if ($connected.Count -ne 1) { throw 'Connect one authorized phone, or specify -DeviceId SERIAL. Check adb devices.' }
        $DeviceId = $connected[0]
    }
    if ($DeviceId -notin $connected) { throw 'The selected device is not connected and authorized for USB debugging.' }
    $abi = ((& $adb -s $DeviceId shell getprop ro.product.cpu.abilist) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $abi -notmatch 'arm64-v8a') { throw "This project builds ARM64 only. Reported ABIs: $abi" }
    $sdk = ((& $adb -s $DeviceId shell getprop ro.build.version.sdk) -join '').Trim()
    if ([int]$sdk -lt 26) { throw 'Lyrio requires Android 8.0 / API 26 or newer.' }
    Write-Host "Lyrio / $DeviceId / $abi / Android API $sdk" -ForegroundColor Cyan
    if ($Clean) { Invoke-Checked $flutterCommand @('clean') }
    if (-not $SkipBuild) {
        Invoke-Checked $flutterCommand @('pub', 'get')
        Invoke-Checked $flutterCommand @('build', 'apk', '--debug', '--target-platform', 'android-arm64')
    }
    $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk)) { throw 'No debug APK exists. Run again without -SkipBuild.' }
    if ($InstallOnly) {
        Invoke-Checked $adb @('-s', $DeviceId, 'install', '-r', $apk)
        Invoke-Checked $adb @('-s', $DeviceId, 'shell', 'am', 'start', '-n', 'com.mbn.lyrio/.MainActivity')
    } else {
        Write-Host 'Debug keys: r = hot reload; d = detach and keep running; q = quit.' -ForegroundColor Green
        Invoke-Checked $flutterCommand @('run', '--debug', '-d', $DeviceId, '--use-application-binary', $apk)
    }
    Write-Host 'First run: grant access from Home, then enable Floating lyrics. See docs/PHONE_TEST.md.' -ForegroundColor Green
} finally { Pop-Location }
