$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Get-Content -LiteralPath (Join-Path $root 'nested-tray-drawer.wh.cpp') -Raw
function Actual([string]$name) {
    $m=[regex]::Match($source,'(?s)// BEGIN '+[regex]::Escape($name)+'\s*(.*?)// END '+[regex]::Escape($name))
    if(-not $m.Success){throw "Missing actual block: $name"}; $m.Groups[1].Value
}
$storage=Actual 'COLLECTION STORAGE'
$init=Actual 'STORAGE INITIALIZATION'
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
int wmain(){
 SetErrorMode(SEM_FAILCRITICALERRORS|SEM_NOGPFAULTERRORBOX);
 const std::wstring a=L"g:{01234567-89ab-cdef-0123-456789abcdef}",b=L"g:{11234567-89ab-cdef-0123-456789abcdef}";
 User(L"fixture-a");std::vector<std::wstring> keys;
 assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 assert(WriteCollection({a,b})&&InitializeCollectionStorage()&&ReadCollection(keys)&&keys.size()==2);
 scope=L"catalog";assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 scope=L"local";assert(ReadCollection(keys)&&keys.size()==2);
 assert(WriteCollection({})&&InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 auto snapshot=strings;failWrites=true;assert(!WriteCollection({a})&&strings==snapshot);failWrites=false;
 strings[scoped(g_collectionStorageKey.c_str())]=L"damaged";
 assert(InitializeCollectionStorage()&&!ReadCollection(keys)&&!WriteCollection({a}));
 assert(strings[scoped(g_collectionStorageKey.c_str())]==L"damaged");
 assert(WriteCollection({})&&ReadCollection(keys)&&keys.empty());
 assert(strings[scoped((g_collectionStorageKey+L".invalid-backup").c_str())]==L"damaged");
 strings.erase(scoped(g_collectionStorageKey.c_str()));
 assert(ReadWindhawkCollection().state==RecordState::Error&&InitializeCollectionStorage()&&!ReadCollection(keys));
 User(L"fixture-b");assert(InitializeCollectionStorage()&&ReadCollection(keys)&&keys.empty());
 failWrites=true;User(L"fixture-c");assert(!InitializeCollectionStorage());failWrites=false;
 puts("Actual API storage passed: initialization, same-ID persistence, separate IDs/users, explicit empty, corruption preservation/recovery and write failure.");
}
'@
$generated=$head+"`n"+(Actual 'COLLECTION RECORD')+"`n"+$storage+"`n"+$init+"`n"+$tests
$path=Join-Path $root 'build/windhawk-storage-test.cpp'
[IO.File]::WriteAllText($path,$generated,[Text.UTF8Encoding]::new($false))
foreach($variant in @('local@nested-tray-drawer','nested-tray-drawer')){
 $binary=Join-Path $root 'build/windhawk-storage-test.exe'
 & 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -target x86_64-w64-mingw32 -static -municode -Wall -Wextra ('-DWH_MOD_ID=L"'+$variant+'"') $path -o $binary
 if($LASTEXITCODE -ne 0){throw 'Storage test compilation failed.'}
 & $binary
 if($LASTEXITCODE -ne 0){throw "Storage test failed: $variant"}
}
