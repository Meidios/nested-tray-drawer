$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$policy = [regex]::Match($source, '(?s)// BEGIN CHEVRON DROP POLICY\s*(.*?)// END CHEVRON DROP POLICY')
if (-not $policy.Success) { throw 'Cannot locate the actual chevron drop policy.' }
$testBody = @'
#include <cassert>
#include <cstdio>
#include <limits>
int main() {
    assert(AcceptChevronDrop(true, true, true, 20, 16, 40, 32));
    assert(AcceptChevronDrop(true, true, true, 0, 0, 40, 32));
    assert(!AcceptChevronDrop(false, true, true, 20, 16, 40, 32)); // External/inner/stale source.
    assert(!AcceptChevronDrop(true, false, true, 20, 16, 40, 32)); // Another pointer.
    assert(!AcceptChevronDrop(true, true, false, 20, 16, 40, 32)); // Hidden/disabled/closing.
    assert(!AcceptChevronDrop(true, true, true, -1, 16, 40, 32));
    assert(!AcceptChevronDrop(true, true, true, 40, 16, 40, 32));
    assert(!AcceptChevronDrop(true, true, true, 20, -1, 40, 32));
    assert(!AcceptChevronDrop(true, true, true, 20, 32, 40, 32));
    assert(!AcceptChevronDrop(true, true, true, 0, 0, 0, 32));
    assert(!AcceptChevronDrop(true, true, true, 0, 0, 40, 0));
    assert(!AcceptChevronDrop(true, true, true, std::numeric_limits<double>::quiet_NaN(), 0, 40, 32));
    assert(!AcceptChevronDrop(true, true, true, 0, 0, std::numeric_limits<double>::infinity(), 32));
    std::puts("Chevron drop policy tests passed: owned source, pointer identity, availability, boundaries, invalid geometry.");
}
'@
$testSource = "#include <cmath>`n" + $policy.Groups[1].Value + "`n" + $testBody
$testPath = Join-Path $projectRoot 'build\chevron-drop-test.cpp'
$testBinary = Join-Path $projectRoot 'build\chevron-drop-test.exe'
[IO.File]::WriteAllText($testPath, $testSource, [Text.UTF8Encoding]::new($false))
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' '-target' 'x86_64-w64-mingw32' '-std=c++23' '-O0' '-static' '-Wall' '-Wextra' $testPath '-o' $testBinary
if ($LASTEXITCODE -ne 0) { throw 'Drop policy test compilation failed.' }
& $testBinary
if ($LASTEXITCODE -ne 0) { throw "Drop policy tests failed: $LASTEXITCODE" }
