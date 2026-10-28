$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Get-Content -LiteralPath (Join-Path $root 'nested-tray-drawer.wh.cpp') -Raw
$helper=[regex]::Match($source,'(?s)// BEGIN IDENTITY ACCESSOR\s*(.*?)// END IDENTITY ACCESSOR').Groups[1].Value
if(-not $helper){throw 'Missing actual identity decoder.'}
$header=Join-Path $root 'build/identity-accessor-actual.inc'
[IO.File]::WriteAllText($header,$helper,[Text.UTF8Encoding]::new($false))
$binary=Join-Path $root 'build/identity-accessor-test.exe'
& 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -static -target x86_64-w64-mingw32 -Wall -Wextra (Join-Path $PSScriptRoot 'IdentityAccessorTests.cpp') -o $binary
if($LASTEXITCODE -ne 0){throw 'Identity semantic test compilation failed.'}
& $binary
if($LASTEXITCODE -ne 0){throw 'Identity semantic test failed.'}
