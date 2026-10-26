$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$block = [regex]::Match($source, '(?s)// BEGIN COLLECTION RECORD\s*(.*?)// END COLLECTION RECORD')
if (-not $block.Success) { throw 'Cannot locate the actual collection record code.' }
$tests = @'
#include <cassert>
#include <cstdio>
int main() {
    std::vector<std::wstring> saved, loaded;
    std::wstring text;
    const std::wstring guid = L"g:{01234567-89ab-cdef-0123-456789abcdef}";
    auto path = PathCollectionKey(L"c:\\apps\\tray.exe", 42);
    auto unicode = PathCollectionKey(L"d:\\音频\\tool.exe", 0xffffffffu);
    assert(ValidCollectionKey(guid) && ValidCollectionKey(path) && ValidCollectionKey(unicode));
    assert(PathCollectionKey(L"", 0).empty());
    assert(PathCollectionKey(std::wstring(4097, L'a'), 0).empty());
    assert(!ValidCollectionKey(L"g:{00000000-0000-0000-0000-000000000000}"));
    assert(!ValidCollectionKey(L"p:4294967296:0061"));
    assert(!ValidCollectionKey(L"p:01:0061"));
    assert(!ValidCollectionKey(L"p:1:00zz"));
    assert(!ValidCollectionKey(L"p:1:061"));
    assert(SerializeCollectionRecord({guid,path,unicode}, text));
    assert(ParseCollectionRecord(text, loaded));
    assert((loaded == std::vector<std::wstring>{guid,path,unicode}));
    assert(!SerializeCollectionRecord({guid,guid}, text));
    assert(!SerializeCollectionRecord({L"unknown:key"}, text));
    assert(!ParseCollectionRecord(L"NTD2\n", loaded));
    assert(!ParseCollectionRecord(L"NTD1\n\n", loaded));
    assert(!ParseCollectionRecord(L"NTD1\n" + guid, loaded));
    assert(!ParseCollectionRecord(L"NTD1\n" + guid + L"\n" + guid + L"\n", loaded));
    assert(!ParseCollectionRecord(std::wstring(kMaxCollectionChars + 1, L'x'), loaded));
    assert(ParseCollectionRecord(L"", loaded) && loaded.empty());
    assert(SerializeCollectionRecord({}, text) && text == L"NTD1\n");
    assert(ParseCollectionRecord(text, loaded) && loaded.empty()); // Explicit restore.
    saved = {guid,path};
    assert((MatchCollectionKeys({path,L"",guid}, saved) == std::vector<size_t>{0,2}));
    assert((MatchCollectionKeys({path}, saved) == std::vector<size_t>{0}));
    assert(saved.size() == 2); // Missing apps do not delete persistent membership.
    assert(MatchCollectionKeys({guid,guid,L""}, saved).empty()); // Ambiguous: fail open.
    assert((MatchCollectionKeys({guid,unicode,path}, saved) == std::vector<size_t>{0,2}));
    assert(MatchCollectionKeys({}, saved).empty());
    assert(MatchCollectionKeys({guid}, {}).empty());
    std::vector<std::wstring> maximum;
    for (unsigned i = 0; i < 512; ++i) maximum.push_back(PathCollectionKey(L"c:\\a.exe", i));
    assert(SerializeCollectionRecord(maximum, text) && ParseCollectionRecord(text, loaded));
    assert(loaded == maximum);
    maximum.push_back(PathCollectionKey(L"c:\\a.exe", 512));
    assert(!SerializeCollectionRecord(maximum, text));
    std::puts("Collection record tests passed: round trip, Unicode, limits, corruption, duplicates, absent/reappearing apps, restore.");
}
'@
$generated = "#include <algorithm>`n#include <string>`n#include <vector>`n#include <cstdint>`n" + $block.Groups[1].Value + "`n" + $tests
$testSource = Join-Path $projectRoot 'build\collection-record-test.cpp'
$testBinary = Join-Path $projectRoot 'build\collection-record-test.exe'
[IO.File]::WriteAllText($testSource, $generated, [Text.UTF8Encoding]::new($false))
& 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe' '-target' 'x86_64-w64-mingw32' '-std=c++23' '-O0' '-static' '-Wall' '-Wextra' $testSource '-o' $testBinary
if ($LASTEXITCODE -ne 0) { throw 'Collection record tests did not compile.' }
& $testBinary
if ($LASTEXITCODE -ne 0) { throw "Collection record tests failed: $LASTEXITCODE" }
