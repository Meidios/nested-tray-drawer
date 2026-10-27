param([string]$ModId='local@ntd-transfer-test-build', [string]$WindhawkPath='C:\Program Files\Windhawk')
$ErrorActionPreference='Stop'
if ($ModId -notmatch '^(local@nested-tray-drawer|nested-tray-drawer|local@ntd-transfer-test-[a-z0-9-]+)$') { throw 'Unexpected transfer mod ID.' }
$root=Split-Path -Parent $PSScriptRoot
$build=Join-Path $root 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$source=Get-Content -LiteralPath (Join-Path $root 'nested-tray-drawer.wh.cpp') -Raw
$blocks=foreach($name in @('COLLECTION RECORD','COLLECTION STORAGE','STORAGE NAMES')) {
    $match=[regex]::Match($source,'(?s)// BEGIN '+$name+'\s*(.*?)// END '+$name)
    if(-not $match.Success){throw "Missing actual block: $name"};$match.Groups[1].Value
}
[IO.File]::WriteAllText((Join-Path $build 'collection-transfer-storage.inc'),($blocks -join "`n"),[Text.UTF8Encoding]::new($false))
$compiler=Join-Path $WindhawkPath 'Compiler/bin/clang++.exe'
$library=Join-Path $WindhawkPath 'Engine/1.7.3/64/windhawk.lib'
$dll=Join-Path $build ($ModId+'-transfer.dll')
$identity=Join-Path $build ($ModId+'-transfer-identity.h')
[IO.File]::WriteAllText($identity,('#define WH_MOD_ID L"'+$ModId+'"'+"`n"+'#define WH_MOD_VERSION L"0.0.1"'+"`n"),[Text.UTF8Encoding]::new($false))
$common=@('-std=c++23','-O2','-target','x86_64-w64-mingw32','-DUNICODE','-D_UNICODE','-Wall','-Wextra')
& $compiler @common -shared -DWH_MOD -include $identity -include windhawk_api.h (Join-Path $PSScriptRoot 'CollectionTransfer.cpp') $library '-Wl,--export-all-symbols' -ladvapi32 -lcrypt32 -lbcrypt -lshell32 -o $dll
if($LASTEXITCODE -ne 0){throw 'Transfer DLL build failed.'}
$hostPath=Join-Path $build 'ntd-collection-transfer-host.exe'
& $compiler @common -static -municode -mwindows (Join-Path $PSScriptRoot 'CollectionTransferHost.cpp') -lshell32 -o $hostPath
if($LASTEXITCODE -ne 0){throw 'Transfer host build failed.'}
[pscustomobject]@{Dll=$dll;Host=$hostPath;ModId=$ModId}
