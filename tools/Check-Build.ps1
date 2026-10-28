param([string]$DllPath = '', [string]$SourcePath = '',
      [ValidateSet('amd64','arm64')][string]$Architecture = 'amd64',
      [string[]]$SymbolPaths = @())
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Get-PeExports([string]$ImagePath) {
    $imageBytes = [IO.File]::ReadAllBytes($ImagePath)
    $peOffset = [BitConverter]::ToInt32($imageBytes, 0x3c)
    $machine = [BitConverter]::ToUInt16($imageBytes, $peOffset + 4)
    $expectedMachine = if ($Architecture -eq 'arm64') { 0xaa64 } else { 0x8664 }
    if ($machine -ne $expectedMachine) { throw "Expected a $Architecture image: $ImagePath" }
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
foreach ($callback in @('Wh_ModInit','Wh_ModAfterInit','Wh_ModBeforeUninit','Wh_ModUninit')) {
    $matchingExports = @($exports | Where-Object { $_ -match ('^_Z\d+' + [regex]::Escape($callback) + 'v$') })
    if ($matchingExports.Count -ne 1) { throw "Missing or ambiguous C++ callback export: $callback" }
    "Verified callback export: $($matchingExports[0])"
}
if ($exports -notcontains 'InternalWhModPtr') { throw 'The engine mod-context export is missing.' }
if ($exports | Where-Object { $_ -match '^_Z\d+Wh_ModSettingsChanged' }) { throw 'The removed settings callback is still exported.' }
if (-not $SymbolPaths -and $Architecture -eq 'amd64') {
    $SymbolPaths = @('research/taskbar-view-symbols.txt','research/taskbar-symbols.txt') |
        ForEach-Object { Join-Path $projectRoot $_ } | Where-Object { Test-Path -LiteralPath $_ }
}
if ($SymbolPaths) {
    $symbols = ($SymbolPaths | ForEach-Object { (Get-Content -LiteralPath $_ -Raw) -replace ' __ptr64','' }) -join "`n"
    $source = Get-Content -LiteralPath $SourcePath -Raw
    foreach ($hook in [regex]::Matches($source, 'LR"\(((?:public:|private:|protected:|struct guid::|const winrt::)[^\r\n]+)\)"')) {
        if (-not $symbols.Contains($hook.Groups[1].Value.TrimEnd())) { throw "Native hook not in matching PDB: $($hook.Groups[1].Value)" }
        "Verified native hook: $($hook.Groups[1].Value)"
    }
}
Get-FileHash -LiteralPath $dllPath -Algorithm SHA256 | Select-Object Path,Hash
