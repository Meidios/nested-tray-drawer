$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$partition = [regex]::Match($source, '(?s)// BEGIN TRAY PARTITION\s*(.*?)// END TRAY PARTITION')
if (-not $partition.Success) { throw 'Cannot locate the actual tray partition code.' }
$testBody = @'
#include <cassert>
#include <cstdio>
int main() {
    std::vector<int> all{1,2,3,4}, outer, inner;
    assert(PartitionTrayModels(all, std::vector<int>{}, outer, inner));
    assert(outer == all && inner.empty());
    assert(PartitionTrayModels(all, std::vector<int>{2}, outer, inner));
    assert((outer == std::vector<int>{1,3,4}) && (inner == std::vector<int>{2}));
    assert(PartitionTrayModels(all, std::vector<int>{2,4}, outer, inner));
    assert((outer == std::vector<int>{1,3}) && (inner == std::vector<int>{2,4}));
    assert(PartitionTrayModels(all, std::vector<int>{4,2,1,3}, outer, inner));
    assert(outer.empty() && inner == all); // Stable native order, all collected.
    assert(!PartitionTrayModels(all, std::vector<int>{2,2}, outer, inner));
    assert(!PartitionTrayModels(all, std::vector<int>{5}, outer, inner));
    assert(!PartitionTrayModels(std::vector<int>{1,2,2}, std::vector<int>{2}, outer, inner));
    assert(!PartitionTrayModels(std::vector<int>{}, std::vector<int>{}, outer, inner));
    assert(!PartitionTrayModels(std::vector<int>(513), std::vector<int>{}, outer, inner));
    assert(PartitionTrayModels(all, std::vector<int>{}, outer, inner)); // Restore all.
    assert(outer == all && inner.empty());
    std::puts("Tray partition tests passed: repeated additions, all, restore, stale/duplicate identity, bounds.");
}
'@
$testSource = "#include <algorithm>`n#include <vector>`n" + $partition.Groups[1].Value + "`n" + $testBody
$testPath = Join-Path $projectRoot 'build\tray-partition-test.cpp'
$testBinary = Join-Path $projectRoot 'build\tray-partition-test.exe'
[IO.File]::WriteAllText($testPath, $testSource, [Text.UTF8Encoding]::new($false))
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' '-target' 'x86_64-w64-mingw32' '-std=c++23' '-O0' '-static' '-Wall' '-Wextra' $testPath '-o' $testBinary
if ($LASTEXITCODE -ne 0) { throw 'Partition test compilation failed.' }
& $testBinary
if ($LASTEXITCODE -ne 0) { throw "Partition tests failed: $LASTEXITCODE" }
