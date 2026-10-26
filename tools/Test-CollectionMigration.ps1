$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
function Get-ActualBlock([string]$Label) {
    $match = [regex]::Match($source, '(?s)// BEGIN ' + [regex]::Escape($Label) + '\s*(.*?)// END ' + [regex]::Escape($Label))
    if (-not $match.Success) { throw "Missing actual source block: $Label" }
    return $match.Groups[1].Value
}
$body = @'
#include <cassert>
#include <cstdio>
const std::wstring a = L"NTD1\ng:{01234567-89ab-cdef-0123-456789abcdef}\n";
const std::wstring b = L"NTD1\ng:{11234567-89ab-cdef-0123-456789abcdef}\n";
const StoredCollection missing{};
const StoredCollection error{RecordState::Error, {}};
const StoredCollection legacyA{RecordState::Present, a};
const StoredCollection legacyB{RecordState::Present, b};

void RawValue(std::wstring const& path, DWORD type, void const* bytes, DWORD length) {
    HKEY key{};
    assert(RegCreateKeyExW(HKEY_CURRENT_USER, path.c_str(), 0, nullptr, 0,
                           KEY_SET_VALUE | KEY_WOW64_64KEY, nullptr, &key, nullptr) == ERROR_SUCCESS);
    assert(RegSetValueExW(key, kCollectionValue, 0, type,
                           static_cast<const BYTE*>(bytes), length) == ERROR_SUCCESS);
    RegCloseKey(key);
}

int wmain(int argc, wchar_t** argv) {
    assert(std::wstring(kLegacyLocalStoragePath).find(L"local@nested-tray-drawer") != std::wstring::npos);
    if (argc != 3) return 2;
    std::wstring root = argv[1], action = argv[2];
    const std::wstring prefix = L"Software\\Meidios\\Windhawk\\NestedTrayDrawer.Tests\\";
    if (!root.starts_with(prefix) || root.size() != prefix.size() + 32) return 3;
    MigrationChoice choice{};
    if (action == L"local") {
        assert(BootstrapCollectionAt(HKEY_CURRENT_USER, root.c_str(), legacyA, missing, choice));
        assert(choice == MigrationChoice::ImportOwn);
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, root.c_str()).text == a);
    } else if (action == L"catalog") {
        assert(BootstrapCollectionAt(HKEY_CURRENT_USER, root.c_str(), missing, legacyB, choice));
        assert(choice == MigrationChoice::KeepDestination);
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, root.c_str()).text == a);
    } else if (action == L"clear") {
        assert(SaveRegistryCollection(HKEY_CURRENT_USER, root.c_str(), L"NTD1\n"));
    } else if (action == L"return-local") {
        assert(BootstrapCollectionAt(HKEY_CURRENT_USER, root.c_str(), legacyA, legacyB, choice));
        assert(choice == MigrationChoice::KeepDestination);
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, root.c_str()).text == L"NTD1\n");
    } else if (action == L"policies") {
        assert(ChooseCollectionMigration(missing, legacyA, legacyB) == MigrationChoice::ImportOwn);
        assert(ChooseCollectionMigration(missing, missing, legacyB) == MigrationChoice::ImportLocal);
        assert(ChooseCollectionMigration(missing, missing, missing) == MigrationChoice::CreateEmpty);
        assert(ChooseCollectionMigration(legacyB, legacyA, error) == MigrationChoice::KeepDestination);
        assert(ChooseCollectionMigration(error, legacyA, legacyB) == MigrationChoice::Refuse);
        assert(ChooseCollectionMigration(missing, error, legacyB) == MigrationChoice::Refuse);
        assert(ChooseCollectionMigration(missing, missing, error) == MigrationChoice::Refuse);
        auto path = root + L"\\import-local";
        assert(BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), missing, legacyB, choice));
        assert(choice == MigrationChoice::ImportLocal);
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).text == b);
        path = root + L"\\empty";
        assert(BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), missing, missing, choice));
        assert(choice == MigrationChoice::CreateEmpty);
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).text == L"NTD1\n");
        path = root + L"\\bad-source";
        assert(!BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), error, legacyB, choice));
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).state == RecordState::Missing);
        path = root + L"\\invalid-schema";
        const wchar_t invalid[] = L"NTD2\n";
        RawValue(path, REG_SZ, invalid, sizeof(invalid));
        assert(!BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), legacyA, missing, choice));
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).state == RecordState::Error);
        path = root + L"\\binary";
        RawValue(path, REG_BINARY, invalid, sizeof(invalid));
        assert(!BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), legacyA, missing, choice));
        path = root + L"\\oversized";
        std::wstring huge(kMaxCollectionChars + 2, L'x');
        RawValue(path, REG_SZ, huge.c_str(), static_cast<DWORD>((huge.size() + 1) * sizeof(wchar_t)));
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).state == RecordState::Error);
        assert(!BootstrapCollectionAt(HKEY_CURRENT_USER, path.c_str(), legacyA, missing, choice));
        path = root + L"\\unterminated";
        RawValue(path, REG_SZ, invalid, sizeof(invalid) - sizeof(wchar_t));
        assert(ReadRegistryCollection(HKEY_CURRENT_USER, path.c_str()).state == RecordState::Error);
        assert(!SaveRegistryCollection(reinterpret_cast<HKEY>(0x1234), root.c_str(), a));
        assert(!SaveRegistryCollection(HKEY_CURRENT_USER, root.c_str(), L"garbage"));
        auto first = AcquireDrawerInstance(GetCurrentProcessId());
        assert(first && !AcquireDrawerInstance(GetCurrentProcessId()));
        CloseHandle(first);
        auto next = AcquireDrawerInstance(GetCurrentProcessId());
        assert(next);
        CloseHandle(next);
        assert(legacyA.text == a && legacyB.text == b);
    } else return 4;
    std::printf("Migration test passed: %ls (%ls).\n", argv[2], WH_MOD_ID);
}
'@
$generated = "#include <windows.h>`n#include <algorithm>`n#include <string>`n#include <vector>`n#include <cstdint>`n" +
    "constexpr wchar_t kCollectionValue[] = L`"CollectedIconsV1`";`n" +
    (Get-ActualBlock 'COLLECTION RECORD') + "`n" + (Get-ActualBlock 'COLLECTION STORAGE') + "`n" +
    (Get-ActualBlock 'INSTANCE GUARD') + "`n" + $body
$testSource = Join-Path $projectRoot 'build\collection-migration-test.cpp'
[IO.File]::WriteAllText($testSource, $generated, [Text.UTF8Encoding]::new($false))
$compiler = 'C:\Program Files\Windhawk\Compiler\bin\clang++.exe'
foreach ($variant in @('local','catalog')) {
    $id = if ($variant -eq 'local') { 'local@nested-tray-drawer' } else { 'nested-tray-drawer' }
    $executable = Join-Path $projectRoot ('build\migration-' + $variant + '-test.exe')
    & $compiler '-target' 'x86_64-w64-mingw32' '-std=c++23' '-O0' '-static' '-municode' '-DUNICODE' '-D_UNICODE' '-Wall' '-Wextra' ('-DWH_MOD_ID=L"' + $id + '"') $testSource '-ladvapi32' '-o' $executable
    if ($LASTEXITCODE -ne 0) { throw "Migration test build failed: $variant" }
}
$testSuffix = [guid]::NewGuid().ToString('N')
$relative = 'Software\Meidios\Windhawk\NestedTrayDrawer.Tests\' + $testSuffix
$registryPath = 'HKCU:\' + $relative
try {
    foreach ($step in @(@('local','local'),@('catalog','catalog'),@('catalog','clear'),@('local','return-local'),@('catalog','policies'))) {
        & (Join-Path $projectRoot ('build\migration-' + $step[0] + '-test.exe')) $relative $step[1]
        if ($LASTEXITCODE -ne 0) { throw ('Migration test failed: ' + $step[1] + ', exit=' + $LASTEXITCODE) }
    }
} finally {
    if (Test-Path -LiteralPath $registryPath) {
        $resolved = (Get-Item -LiteralPath $registryPath).Name
        if ($resolved -notmatch ('^HKEY_CURRENT_USER\\Software\\Meidios\\Windhawk\\NestedTrayDrawer\.Tests\\' + $testSuffix + '$')) {
            throw 'Unexpected test registry path; cleanup refused.'
        }
        Remove-Item -LiteralPath $registryPath -Recurse
    }
}
'Migration tests used isolated registry fixtures only; production collection was not modified.'
