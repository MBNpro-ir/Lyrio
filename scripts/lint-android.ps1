[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Push-Location -LiteralPath $root
try {
    # Flutter on Windows writes unescaped drive colons in this generated file.
    # Normalize them before invoking Android Lint; never commit machine paths.
    $file = (Resolve-Path -LiteralPath 'android\local.properties').Path
    $text = Get-Content -LiteralPath $file -Raw -Encoding UTF8
    $text = [regex]::Replace($text, '(?m)^((?:sdk\.dir|flutter\.sdk)=)([A-Za-z]):', '$1$2\:')
    [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding($false)))
    $javaHomeBefore = $env:JAVA_HOME
    if (-not $env:JAVA_HOME) {
        $bundledJdk = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
        if (Test-Path -LiteralPath $bundledJdk) { $env:JAVA_HOME = $bundledJdk }
    }
    try {
        $ErrorActionPreference = 'Continue'
        & .\android\gradlew.bat -p android :app:lintDebug -Ptarget-platform=android-arm64 --console=plain
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0) { throw 'Android Lint failed.' }
    } finally { $env:JAVA_HOME = $javaHomeBefore }
} finally { Pop-Location }
