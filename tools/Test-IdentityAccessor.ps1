$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'nested-tray-drawer.wh.cpp') -Raw
$helper = [regex]::Match($source, '(?s)// BEGIN IDENTITY ACCESSOR\s*(.*?)// END IDENTITY ACCESSOR').Groups[1].Value
if (-not $helper) { throw 'Missing actual identity accessor.' }
$symbols = Get-Content -LiteralPath (Join-Path $projectRoot 'research/taskbar-symbols.txt')
function SymbolRva([string]$Text) {
    $found = @($symbols | Where-Object { $_.Contains($Text) })
    if ($found.Count -ne 1) { throw "Missing or ambiguous fixture symbol: $Text" }
    return '0x' + ($found[0] -split ' ',2)[0]
}
$query = SymbolRva 'produce_base<struct winrt::WindowsUdk::UI::Shell::implementation::NotificationAreaIcon2,struct winrt::WindowsUdk::UI::Shell::INotificationAreaIcon,void>::QueryInterface('
$getter = SymbolRva 'NotificationAreaIcon2::Identity(void)const'
$copy = SymbolRva 'NotificationAreaIconIdentity::NotificationAreaIconIdentity(struct NotificationAreaIconIdentity const &'
$tests = @'
#include <windows.h>
#include <cassert>
#include <cstdint>
#include <cstddef>
#include <cstring>
#include <cstdio>
#include <vector>
#include <fstream>
'@ + "`n" + $helper + "`nconstexpr size_t queryRva=$query, getterRva=$getter, copyRva=$copy;`n" + @'
int main() {
    // Map as data, not as an executable module. RVAs come from matching local PDBs.
    std::ifstream file("C:/Windows/System32/taskbar.dll", std::ios::binary);
    std::vector<BYTE> bytes((std::istreambuf_iterator<char>(file)), {});
    assert(!bytes.empty());
    auto dos = reinterpret_cast<const IMAGE_DOS_HEADER*>(bytes.data());
    auto pe = reinterpret_cast<const IMAGE_NT_HEADERS64*>(bytes.data()+dos->e_lfanew);
    std::vector<BYTE> image(pe->OptionalHeader.SizeOfImage);
    auto sections = IMAGE_FIRST_SECTION(pe);
    for (unsigned i=0;i<pe->FileHeader.NumberOfSections;++i)
        memcpy(image.data()+sections[i].VirtualAddress, bytes.data()+sections[i].PointerToRawData, sections[i].SizeOfRawData);
    ptrdiff_t adjustment{}; size_t offset{};
    auto decode = [&] { return DecodeIdentityAccessor(image.data()+queryRva, image.data()+getterRva,
        image.data()+copyRva, adjustment, offset); };
    assert(decode());
    assert(adjustment == -16 && offset == 72); // Fixture values, never runtime constants.
    for (auto rva : {queryRva, queryRva+4, getterRva, getterRva+13, getterRva+17,
                    getterRva+21, copyRva, copyRva+17}) {
        image[rva] ^= 1;
        assert(!decode());
        image[rva] ^= 1;
        assert(decode());
    }
    puts("Actual accessor: matching local binary accepted; incompatible code and return ABI rejected.");
}
'@
$path = Join-Path $projectRoot 'build/identity-accessor-test.cpp'
$binary = Join-Path $projectRoot 'build/identity-accessor-test.exe'
[IO.File]::WriteAllText($path, $tests, [Text.UTF8Encoding]::new($false))
& 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -target x86_64-w64-mingw32 -static -Wall -Wextra $path -o $binary
if ($LASTEXITCODE -ne 0) { throw 'Accessor test compilation failed.' }
& $binary
if ($LASTEXITCODE -ne 0) { throw 'Accessor test failed.' }
