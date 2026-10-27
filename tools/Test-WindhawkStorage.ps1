$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Get-Content -LiteralPath (Join-Path $root 'nested-tray-drawer.wh.cpp') -Raw
function Actual([string]$name) {
    $m=[regex]::Match($source,'(?s)// BEGIN '+[regex]::Escape($name)+'\s*(.*?)// END '+[regex]::Escape($name))
    if(-not $m.Success){throw "Missing actual block: $name"}; $m.Groups[1].Value
}
$storage=Actual 'COLLECTION STORAGE'
$storage=[regex]::Replace($storage,'constexpr WCHAR kUserCollectionPath\[\] = [^;]+;','const wchar_t* kUserCollectionPath;')
$init=[regex]::Match($source,'(?s)(bool InitializeCollectionStorage\(\).*?)(?=void ExportDevelopmentHandoff)').Groups[1].Value
$export=[regex]::Match($source,'(?s)(void ExportDevelopmentHandoff\(\).*?)(?=// Symbol-based)').Groups[1].Value
if(-not $init -or -not $export){throw 'Storage lifecycle not found.'}
$head=@'
#include <windows.h>
#include <algorithm>
#include <string>
#include <string_view>
#include <vector>
#include <cstdint>
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <map>
#undef assert
#define assert(condition) do { if(!(condition)){ std::fprintf(stderr,"Test failed at line %d\n",__LINE__); ExitProcess(1); } } while(false)
constexpr wchar_t kCollectionValue[]=L"CollectedIconsV1";
std::wstring scope=L"local";
std::map<std::wstring,std::wstring> strings;
std::map<std::wstring,int> integers;
bool failWrites{};
std::wstring scoped(PCWSTR name){return scope+L":"+name;}
size_t Wh_GetStringValue(PCWSTR name,PWSTR output,size_t capacity){
 auto it=strings.find(scoped(name)); if(it==strings.end()||it->second.size()+1>capacity)return 0;
 std::copy(it->second.begin(),it->second.end(),output);output[it->second.size()]=0;return it->second.size();
}
BOOL Wh_SetStringValue(PCWSTR name,PCWSTR value){if(failWrites)return FALSE;strings[scoped(name)]=value;return TRUE;}
int Wh_GetIntValue(PCWSTR name,int fallback){auto it=integers.find(scoped(name));return it==integers.end()?fallback:it->second;}
BOOL Wh_SetIntValue(PCWSTR name,int value){if(failWrites)return FALSE;integers[scoped(name)]=value;return TRUE;}
struct CollectionLock{bool acquired=true;};
template<typename... T> void Wh_Log(PCWSTR,T...){}
'@
$tests=@'
void User(PCWSTR sid){g_collectionStorageKey=std::wstring(L"CollectionV2.")+sid;g_collectionReadyKey=g_collectionStorageKey+L".ready";}
void Seed(std::wstring const& text){
 HKEY key{}; assert(RegCreateKeyExW(HKEY_CURRENT_USER,kUserCollectionPath,0,nullptr,0,KEY_SET_VALUE,nullptr,&key,nullptr)==0);
 assert(RegSetValueExW(key,kCollectionValue,0,REG_SZ,reinterpret_cast<const BYTE*>(text.c_str()),DWORD((text.size()+1)*sizeof(wchar_t)))==0);RegCloseKey(key);
}
int wmain(int argc,wchar_t** argv){
 SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX);
 if(argc!=2)return 2;
 std::wstring path=argv[1];if(!path.starts_with(L"Software\\Meidios\\Windhawk\\NestedTrayDrawer.Tests\\"))return 3;
 kUserCollectionPath=path.c_str();
 const std::wstring a=L"g:{01234567-89ab-cdef-0123-456789abcdef}",b=L"g:{11234567-89ab-cdef-0123-456789abcdef}";
 const std::wstring record=L"NTD1\n"+a+L"\n";Seed(record);User(L"fixture-a");
 std::vector<std::wstring> keys;
 assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys==std::vector<std::wstring>{a});
 assert(WriteCollection({a,b})&&InitializeCollectionStorage()&&ReadCollection(keys)&&keys.size()==2);
 ExportDevelopmentHandoff();
 if constexpr(kDevelopmentBuild){
  assert(ReadLegacyCollection().text==L"NTD1\n"+a+L"\n"+b+L"\n");
  scope=L"catalog";assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys.size()==2);
 }else{assert(ReadLegacyCollection().text==record);}
 assert(WriteCollection({})&&InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 auto snapshot=strings;failWrites=true;assert(!WriteCollection({a})&&strings==snapshot);failWrites=false;
 strings[scoped(g_collectionStorageKey.c_str())]=L"damaged";
 assert(InitializeCollectionStorage()&&!ReadCollection(keys)&&!WriteCollection({a}));
 assert(strings[scoped(g_collectionStorageKey.c_str())]==L"damaged");
 assert(WriteCollection({})&&ReadCollection(keys)&&keys.empty());
 assert(strings[scoped((g_collectionStorageKey+L".invalid-backup").c_str())]==L"damaged");
 strings.erase(scoped(g_collectionStorageKey.c_str()));
 assert(ReadWindhawkCollection().state==RecordState::Error&&InitializeCollectionStorage()&&!ReadCollection(keys));
 Seed(L"NTD1\n");User(L"fixture-b");assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 Seed(L"damaged legacy");User(L"fixture-c");assert(InitializeCollectionStorage()&&!ReadCollection(keys));
 assert(ReadLegacyCollection().text==L"damaged legacy");
 puts("Actual storage passed: import, local/catalog handoff, precedence, clear, user isolation, corruption recovery and write failure.");
}
'@
$generated=$head+"`n"+(Actual 'COLLECTION RECORD')+"`n"+$storage+"`n"+$init+"`n"+$export+"`n"+$tests
$path=Join-Path $root 'build/windhawk-storage-test.cpp'
[IO.File]::WriteAllText($path,$generated,[Text.UTF8Encoding]::new($false))
foreach($variant in @('local@nested-tray-drawer','nested-tray-drawer')){
 $fixture='Software\Meidios\Windhawk\NestedTrayDrawer.Tests\'+[guid]::NewGuid().ToString('N')
 $binary=Join-Path $root 'build/windhawk-storage-test.exe'
 & 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -target x86_64-w64-mingw32 -static -municode -Wall -Wextra ('-DWH_MOD_ID=L"'+$variant+'"') $path -ladvapi32 -o $binary
 if($LASTEXITCODE -ne 0){throw 'Storage test compilation failed.'}
 try{& $binary $fixture;if($LASTEXITCODE -ne 0){throw "Storage test failed: $variant"}}
 finally{
  $target='HKCU:\'+$fixture
  if(-not $target.StartsWith('HKCU:\Software\Meidios\Windhawk\NestedTrayDrawer.Tests\')){throw 'Invalid fixture cleanup target.'}
  if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse}
 }
}
