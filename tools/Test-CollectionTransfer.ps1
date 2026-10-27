$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'Build-CollectionTransfer.ps1') | Out-Null
$test=@'
#include <windows.h>
#include <map>
#include <string>
#include <algorithm>
#include <cstdio>
#include <cstdlib>
std::map<std::wstring,std::wstring> strings;
std::map<std::wstring,int> integers;
bool failWrites{};
size_t Wh_GetStringValue(PCWSTR key,PWSTR output,size_t capacity){
 auto it=strings.find(key);if(it==strings.end()||it->second.size()+1>capacity)return 0;
 std::copy(it->second.begin(),it->second.end(),output);output[it->second.size()]=0;return it->second.size();
}
BOOL Wh_SetStringValue(PCWSTR key,PCWSTR value){if(failWrites)return FALSE;strings[key]=value;return TRUE;}
int Wh_GetIntValue(PCWSTR key,int fallback){auto it=integers.find(key);return it==integers.end()?fallback:it->second;}
BOOL Wh_SetIntValue(PCWSTR key,int value){if(failWrites)return FALSE;integers[key]=value;return TRUE;}
#define TRANSFER_TEST
#include "../tools/CollectionTransfer.cpp"
#define CHECK(condition) do{if(!(condition)){std::fprintf(stderr,"Failed line %d\n",__LINE__);return 1;}}while(false)
int wmain(int argc,wchar_t** argv){
 if(argc!=2)return 2;
 CHECK(InitializeStorageNames());
 const std::wstring record=L"NTD1\ng:{01234567-89ab-cdef-0123-456789abcdef}\n";
 CHECK(SaveWindhawkCollection(record));
 auto originalStrings=strings;auto originalIntegers=integers;
 auto exported=ExportCollection(argv[1]);CHECK(exported.success&&exported.entries==1);
 CHECK(!ExportCollection(argv[1]).success); // Existing encrypted backup is never replaced.
 strings.clear();integers.clear();
 auto imported=ImportCollection(argv[1]);CHECK(imported.success&&imported.sha256==exported.sha256);
 CHECK(ReadWindhawkCollection().text==record&&ImportCollection(argv[1]).success);
 CHECK(SaveWindhawkCollection(L"NTD1\n"));
 CHECK(!ImportCollection(argv[1]).success&&ReadWindhawkCollection().text==L"NTD1\n");
 strings[g_collectionStorageKey]=L"damaged";
 CHECK(!ImportCollection(argv[1]).success&&strings[g_collectionStorageKey]==L"damaged");
 strings.clear();integers.clear();integers[g_collectionReadyKey]=1;
 CHECK(!ImportCollection(argv[1]).success&&strings.empty());
 integers.clear();failWrites=true;CHECK(!ImportCollection(argv[1]).success&&strings.empty());failWrites=false;
 CHECK(ImportCollection(argv[1]).success);
 strings=originalStrings;integers=originalIntegers;
 CHECK(ReadWindhawkCollection().text==record);
 HANDLE file=CreateFileW(argv[1],GENERIC_WRITE,0,nullptr,OPEN_EXISTING,0,nullptr);
 CHECK(file!=INVALID_HANDLE_VALUE);BYTE bad=0;DWORD written{};CHECK(WriteFile(file,&bad,1,&written,nullptr));CloseHandle(file);
 auto before=strings;CHECK(!ImportCollection(argv[1]).success&&strings==before);
 puts("Transfer passed: real DPAPI round-trip, exact readback/hash, retry, empty/conflicting/corrupt destination, missing marked value, write failure, tampered handoff, source preservation.");
}
'@
$path=Join-Path $root 'build/collection-transfer-test.cpp'
[IO.File]::WriteAllText($path,$test,[Text.UTF8Encoding]::new($false))
$exe=Join-Path $root 'build/collection-transfer-test.exe'
& 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -static -target x86_64-w64-mingw32 -municode -DUNICODE -D_UNICODE -Wall -Wextra $path -ladvapi32 -lcrypt32 -lbcrypt -lshell32 -o $exe
if($LASTEXITCODE -ne 0){throw 'Transfer test compilation failed.'}
$handoff=Join-Path $root ('build/transfer-fixture-'+[guid]::NewGuid().ToString('N')+'.dpapi')
try { & $exe $handoff; if($LASTEXITCODE -ne 0){throw 'Transfer test failed.'} }
finally { if(Test-Path -LiteralPath $handoff){Remove-Item -LiteralPath $handoff} }
