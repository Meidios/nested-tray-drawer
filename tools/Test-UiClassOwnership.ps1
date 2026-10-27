$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $root 'nested-tray-drawer.wh.cpp') -Raw
$match = [regex]::Match($source, '(?s)// BEGIN UI CLASS OWNERSHIP\s*(.*?)// END UI CLASS OWNERSHIP')
if (-not $match.Success) { throw 'Actual UI class ownership code not found.' }
$test = @'
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#define CHECK(condition) do { if(!(condition)) { std::fprintf(stderr,"UI class test failed: %d, Win32=%lu\n",__LINE__,GetLastError()); ExitProcess(1); } } while(false)
constexpr WCHAR kUiClass[]=L"Windhawk_NestedTrayDrawer_ClassOwnershipFixture";
HMODULE g_selfModule=GetModuleHandleW(nullptr);
unsigned foreignCalls{};
LRESULT CALLBACK UiWindowProc(HWND window,UINT message,WPARAM w,LPARAM l) { return DefWindowProcW(window,message,w,l); }
LRESULT CALLBACK ForeignProc(HWND window,UINT message,WPARAM w,LPARAM l) { ++foreignCalls; return DefWindowProcW(window,message,w,l); }
template<typename... T> void Wh_Log(PCWSTR,T...) {}
'@ + "`n" + $match.Groups[1].Value + @'

HWND Window() { return CreateWindowExW(0,kUiClass,L"",0,0,0,0,0,HWND_MESSAGE,nullptr,g_selfModule,nullptr); }
DWORD WINAPI ThreadFixture(void*) {
 CHECK(EnsureUiClassRegistered());
 auto window=Window(); CHECK(window); CHECK(DestroyWindow(window));
 return 0;
}
int main() {
 // Only this fixture process is touched; no Explorer classes or UI input.
 WNDCLASSW foreign{}; foreign.lpfnWndProc=ForeignProc; foreign.hInstance=g_selfModule; foreign.lpszClassName=kUiClass;
 CHECK(RegisterClassW(&foreign));
 CHECK(!EnsureUiClassRegistered() && !g_uiClassAtom);
 CHECK(UnregisterOwnedUiClass()); // Does not delete a class owned by another copy.
 WNDCLASSW info{}; CHECK(GetClassInfoW(g_selfModule,kUiClass,&info)); CHECK(info.lpfnWndProc==ForeignProc);
 CHECK(foreignCalls==0); CHECK(UnregisterClassW(kUiClass,g_selfModule));
 auto thread=CreateThread(nullptr,0,ThreadFixture,nullptr,0,nullptr); CHECK(thread);
 CHECK(WaitForSingleObject(thread,5000)==WAIT_OBJECT_0); CHECK(CloseHandle(thread));
 auto atom=g_uiClassAtom; CHECK(atom);
 CHECK(!CreateWindowExW(0,kUiClass,L"",WS_CHILD,0,0,0,0,reinterpret_cast<HWND>(-9999),nullptr,g_selfModule,nullptr));
 CHECK(EnsureUiClassRegistered() && g_uiClassAtom==atom); // Retry after failed window creation / departed owner thread.
 auto window=Window(); CHECK(window);
 CHECK(GetClassInfoW(g_selfModule,kUiClass,&info) && info.lpfnWndProc==UiWindowProc);
 CHECK(DestroyWindow(window)); CHECK(UnregisterOwnedUiClass() && !g_uiClassAtom);
 CHECK(!GetClassInfoW(g_selfModule,kUiClass,&info));
 CHECK(EnsureUiClassRegistered()); CHECK(UnregisterOwnedUiClass());
 std::puts("Actual UI class ownership passed: foreign registration rejected and retained, own class reused after thread/window failure, owned class cleanup and re-registration.");
}
'@
$path = Join-Path $root 'build/ui-class-ownership-test.cpp'
$binary = Join-Path $root 'build/ui-class-ownership-test.exe'
[IO.File]::WriteAllText($path,$test,[Text.UTF8Encoding]::new($false))
& 'C:/Program Files/Windhawk/Compiler/bin/clang++.exe' -std=c++23 -target x86_64-w64-mingw32 -DUNICODE -D_UNICODE -static -Wall -Wextra $path -luser32 -o $binary
if ($LASTEXITCODE -ne 0) { throw 'UI class ownership fixture did not compile.' }
& $binary
if ($LASTEXITCODE -ne 0) { throw 'UI class ownership fixture failed.' }
