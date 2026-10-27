// SPDX-License-Identifier: GPL-3.0
// Owned, hidden host for the one-time Windhawk API helper; no desktop automation.
#include <windows.h>
#include <shellapi.h>
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    int argc{};
    auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv || argc != 4) {
        if (argv)
            LocalFree(argv);
        return 2;
    }
    int result = 3;
    for (unsigned i = 0; i < 450; ++i) {
        if (GetFileAttributesW(argv[3]) != INVALID_FILE_ATTRIBUTES) {
            result = 0;
            break;
        }
        Sleep(100);
    }
    LocalFree(argv);
    return result;
}
