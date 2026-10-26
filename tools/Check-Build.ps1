param([string]$DllPath = '', [string]$SourcePath = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Get-PeExports([string]$ImagePath) {
    $imageBytes = [IO.File]::ReadAllBytes($ImagePath)
    $peOffset = [BitConverter]::ToInt32($imageBytes, 0x3c)
    $machine = [BitConverter]::ToUInt16($imageBytes, $peOffset + 4)
    if ($machine -ne 0x8664) { throw "Expected an AMD64 image: $ImagePath" }
    $sectionCount = [BitConverter]::ToUInt16($imageBytes, $peOffset + 6)
    $optionalSize = [BitConverter]::ToUInt16($imageBytes, $peOffset + 20)
    $optionalOffset = $peOffset + 24
    $sectionBase = $optionalOffset + $optionalSize
    function Resolve-ImageRva([uint32]$Address) {
        for ($index = 0; $index -lt $sectionCount; $index++) {
            $offset = $sectionBase + $index * 40
            $virtualAddress = [BitConverter]::ToUInt32($imageBytes, $offset + 12)
            $extent = [Math]::Max([BitConverter]::ToUInt32($imageBytes, $offset + 8), [BitConverter]::ToUInt32($imageBytes, $offset + 16))
            if ($Address -ge $virtualAddress -and $Address -lt $virtualAddress + $extent) {
                return [BitConverter]::ToUInt32($imageBytes, $offset + 20) + $Address - $virtualAddress
            }
        }
        throw "Unmapped RVA: $Address"
    }
    $exportOffset = Resolve-ImageRva ([BitConverter]::ToUInt32($imageBytes, $optionalOffset + 112))
    $nameCount = [BitConverter]::ToUInt32($imageBytes, $exportOffset + 24)
    $nameTable = Resolve-ImageRva ([BitConverter]::ToUInt32($imageBytes, $exportOffset + 32))
    for ($index = 0; $index -lt $nameCount; $index++) {
        $nameOffset = Resolve-ImageRva ([BitConverter]::ToUInt32($imageBytes, $nameTable + $index * 4))
        $end = $nameOffset
        while ($imageBytes[$end] -ne 0) { $end++ }
        [Text.Encoding]::ASCII.GetString($imageBytes, $nameOffset, $end - $nameOffset)
    }
}
if (-not $DllPath) { $DllPath = Join-Path $projectRoot 'build\nested-tray-drawer.dll' }
if (-not $SourcePath) { $SourcePath = Join-Path $projectRoot 'nested-tray-drawer.wh.cpp' }
$dllPath = $DllPath
$exports = @(Get-PeExports $dllPath)
foreach ($callback in @('Wh_ModInit','Wh_ModAfterInit','Wh_ModBeforeUninit','Wh_ModUninit','Wh_ModSettingsChanged')) {
    $matchingExports = @($exports | Where-Object { $_ -match ('^_Z\d+' + [regex]::Escape($callback) + 'v$') })
    if ($matchingExports.Count -ne 1) { throw "Missing or ambiguous C++ callback export: $callback" }
    "Verified callback export: $($matchingExports[0])"
}
if ($exports -notcontains 'InternalWhModPtr') { throw 'The engine mod-context export is missing.' }
$symbolsPath = Join-Path $projectRoot 'research\taskbar-view-symbols.txt'
if (Test-Path -LiteralPath $symbolsPath) {
    $symbols = (Get-Content -LiteralPath $symbolsPath -Raw) -replace ' __ptr64',''
    $source = Get-Content -LiteralPath $SourcePath -Raw
    foreach ($hook in [regex]::Matches($source, 'LR"\(([^\r\n]+)\)"')) {
        if (-not $symbols.Contains($hook.Groups[1].Value)) { throw "Native hook not in matching PDB: $($hook.Groups[1].Value)" }
        "Verified native hook: $($hook.Groups[1].Value)"
    }
}
Get-FileHash -LiteralPath $dllPath -Algorithm SHA256 | Select-Object Path,Hash
