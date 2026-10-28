param(
    [string]$WindhawkPath = 'C:\Program Files\Windhawk',
    [ValidateSet('Local','Catalog')][string]$Variant = 'Local',
    [string]$SourcePath = '',
    [ValidateSet('amd64','arm64')][string]$Architecture = 'amd64'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $SourcePath) { $SourcePath = Join-Path $projectRoot 'nested-tray-drawer.wh.cpp' }
$source = (Resolve-Path -LiteralPath $SourcePath).Path
$modId = if ($Variant -eq 'Local') { 'local@nested-tray-drawer' } else { 'nested-tray-drawer' }
$outputName = if ($Variant -eq 'Local') { 'nested-tray-drawer.dll' } else { 'nested-tray-drawer-catalog.dll' }
if ($Architecture -eq 'arm64') { $outputName = $outputName.Replace('.dll','-arm64.dll') }
$sourceText = Get-Content -LiteralPath $source -Raw
$versionMatch = [regex]::Match($sourceText, '(?m)^// @version\s+([0-9]+\.[0-9]+\.[0-9]+)\s*$')
if (-not $versionMatch.Success) { throw 'A valid mod version is required.' }
$modVersion = $versionMatch.Groups[1].Value
$buildDir = Join-Path $projectRoot 'build'
$compiler = Join-Path $WindhawkPath 'Compiler\bin\clang++.exe'
$engineArchitecture = if ($Architecture -eq 'arm64') { 'arm64' } else { '64' }
$target = if ($Architecture -eq 'arm64') { 'aarch64-w64-mingw32' } else { 'x86_64-w64-mingw32' }
$engineLibrary = Join-Path $WindhawkPath ('Engine\1.7.3\'+$engineArchitecture+'\windhawk.lib')
if (-not (Test-Path -LiteralPath $compiler) -or -not (Test-Path -LiteralPath $engineLibrary)) {
    throw "Windhawk 1.7.3 compiler/engine library not found for $Architecture at the specified path."
}
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
$identityHeader = Join-Path $buildDir ($modId+'-'+$Architecture+'-identity.h')
[IO.File]::WriteAllText($identityHeader,('#define WH_MOD_ID L"'+$modId+'"'+"`n"+'#define WH_MOD_VERSION L"'+$modVersion+'"'+"`n"),[Text.UTF8Encoding]::new($false))
$compilerArgs = @(
    '-std=c++23', '-O2', '-shared', '-target', $target,
    '-DUNICODE', '-D_UNICODE', '-DWINVER=0x0A00', '-D_WIN32_WINNT=0x0A00',
    '-D_WIN32_IE=0x0A00', '-DNTDDI_VERSION=0x0A000008',
    '-D__USE_MINGW_ANSI_STDIO=0', '-DWH_MOD',
    '-include', $identityHeader, '-include', 'windhawk_api.h', '-Wall', '-Wextra',
    '-Wno-pragma-pack', '-Wno-pragma-system-header-outside-header',
    $source, $engineLibrary, '-Wl,--export-all-symbols',
    '-lole32', '-loleaut32', '-lruntimeobject', '-lversion', '-ladvapi32',
    '-o', (Join-Path $buildDir $outputName)
)
& $compiler @compilerArgs
if ($LASTEXITCODE -ne 0) { throw "Mod compilation failed with exit code $LASTEXITCODE." }
Get-Item -LiteralPath (Join-Path $buildDir $outputName) | Select-Object FullName,Length
