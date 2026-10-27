$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$helper = [regex]::Match($source, '(?s)// BEGIN CLEANUP STEP\s*(.*?)// END CLEANUP STEP').Groups[1].Value
if (-not $helper) { throw 'Missing actual cleanup helper.' }
$tests = @'
#include <windows.h>
#include <cassert>
#include <cstdio>
#include <stdexcept>
unsigned exceptions{};
void LogException(PCWSTR) noexcept { ++exceptions; }
'@ + "`n" + $helper + @'

int main() {
    // A failure at each restoration stage must not skip the remaining stages.
    for (unsigned failure = 0; failure < 12; ++failure) {
        unsigned visited{}, restored{};
        for (unsigned step = 0; step < 12; ++step) {
            auto ok = CleanupStep(L"fixture", [&] {
                ++visited;
                if (step == failure) throw std::runtime_error("injected");
                ++restored;
            });
            assert(ok == (step != failure));
        }
        assert(visited == 12 && restored == 11);
    }
    assert(exceptions == 12);
    puts("Actual cleanup helper: independent failures do not skip subsequent restoration.");
}
'@
$path = Join-Path $projectRoot 'build/cleanup-test.cpp'
[IO.File]::WriteAllText($path, $tests, [Text.UTF8Encoding]::new($false))
$binary = Join-Path $projectRoot 'build/cleanup-test.exe'
& 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -target x86_64-w64-mingw32 -static -Wall -Wextra $path -o $binary
if ($LASTEXITCODE -ne 0) { throw 'Cleanup test compilation failed.' }
& $binary
if ($LASTEXITCODE -ne 0) { throw 'Cleanup test failed.' }
