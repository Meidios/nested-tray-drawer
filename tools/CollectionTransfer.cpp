// SPDX-License-Identifier: GPL-3.0
// Personal-repository migration helper. Never included in the catalog mod.
#include <windows.h>
#include <sddl.h>
#include <shellapi.h>
#include <wincrypt.h>
#include <bcrypt.h>
#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>
#include <cstdio>
#include <stdexcept>
#include "../build/collection-transfer-storage.inc"

struct TransferResult {
    bool success{};
    const char* status{"unexpected-error"};
    size_t entries{};
    std::string sha256;
    TransferResult() = default;
    TransferResult(bool ok, const char* message, size_t count = 0, std::string hash = {})
        : success(ok), status(message), entries(count), sha256(std::move(hash)) {}
};

std::string RecordHash(std::wstring const& text) {
    BYTE hash[32]{};
    BCRYPT_ALG_HANDLE algorithm{};
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) < 0)
        throw std::runtime_error("Hash provider failed");
    BCRYPT_HASH_HANDLE handle{};
    auto status = BCryptCreateHash(algorithm, &handle, nullptr, 0, nullptr, 0, 0);
    if (status >= 0)
        status = BCryptHashData(handle, reinterpret_cast<PUCHAR>(const_cast<wchar_t*>(text.data())),
                                static_cast<ULONG>(text.size() * sizeof(wchar_t)), 0);
    if (status >= 0)
        status = BCryptFinishHash(handle, hash, sizeof(hash), 0);
    if (handle)
        BCryptDestroyHash(handle);
    BCryptCloseAlgorithmProvider(algorithm, 0);
    if (status < 0)
        throw std::runtime_error("Hash failed");
    std::string result;
    for (auto byte : hash) {
        result += "0123456789abcdef"[byte >> 4];
        result += "0123456789abcdef"[byte & 15];
    }
    return result;
}

bool WriteNewFile(PCWSTR path, const void* data, DWORD size) {
    HANDLE file =
        CreateFileW(path, GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        return false;
    DWORD written{};
    bool ok =
        WriteFile(file, data, size, &written, nullptr) && written == size && FlushFileBuffers(file);
    CloseHandle(file);
    return ok;
}

bool ProtectRecord(PCWSTR path, std::wstring const& text) {
    DATA_BLOB plain{static_cast<DWORD>(text.size() * sizeof(wchar_t)),
                    reinterpret_cast<BYTE*>(const_cast<wchar_t*>(text.data()))};
    DATA_BLOB encrypted{};
    if (!CryptProtectData(&plain, L"Nested Tray Drawer collection transfer", nullptr, nullptr,
                          nullptr, CRYPTPROTECT_UI_FORBIDDEN, &encrypted))
        return false;
    bool ok = WriteNewFile(path, encrypted.pbData, encrypted.cbData);
    LocalFree(encrypted.pbData);
    return ok;
}

bool UnprotectRecord(PCWSTR path, std::wstring& text) {
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE)
        return false;
    LARGE_INTEGER size{};
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 1 || size.QuadPart > 1048576) {
        CloseHandle(file);
        return false;
    }
    std::vector<BYTE> buffer(static_cast<size_t>(size.QuadPart));
    DWORD read{};
    bool ok = ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &read, nullptr) &&
              read == buffer.size();
    CloseHandle(file);
    if (!ok)
        return false;
    DATA_BLOB encrypted{read, buffer.data()}, plain{};
    if (!CryptUnprotectData(&encrypted, nullptr, nullptr, nullptr, nullptr,
                            CRYPTPROTECT_UI_FORBIDDEN, &plain))
        return false;
    ok = plain.cbData % sizeof(wchar_t) == 0 &&
         plain.cbData <= kMaxCollectionChars * sizeof(wchar_t);
    if (ok)
        text.assign(reinterpret_cast<wchar_t*>(plain.pbData), plain.cbData / sizeof(wchar_t));
    SecureZeroMemory(plain.pbData, plain.cbData);
    LocalFree(plain.pbData);
    return ok && text.find(L'\0') == std::wstring::npos && ValidStoredCollection(text);
}

// BEGIN TRANSFER POLICY
TransferResult ExportCollection(PCWSTR path) {
    auto source = ReadWindhawkCollection();
    if (source.state != RecordState::Present)
        return {false, "source-missing-or-invalid"};
    std::vector<std::wstring> keys;
    if (!ParseCollectionRecord(source.text, keys))
        return {false, "invalid-source"};
    if (!ProtectRecord(path, source.text))
        return {false, "encrypted-export-failed"};
    std::wstring confirmed;
    if (!UnprotectRecord(path, confirmed) || confirmed != source.text)
        return {false, "export-verification-failed"};
    return {true, "export-verified", keys.size(), RecordHash(confirmed)};
}

TransferResult ImportCollection(PCWSTR path) {
    std::wstring text;
    if (!UnprotectRecord(path, text))
        return {false, "invalid-encrypted-handoff"};
    auto destination = ReadWindhawkCollection();
    if (destination.state == RecordState::Error)
        return {false, "destination-invalid"};
    if (destination.state == RecordState::Present && destination.text != text)
        return {false, "destination-conflict"};
    bool existed = destination.state == RecordState::Present;
    if (!existed && !SaveWindhawkCollection(text))
        return {false, "write-failed"};
    auto confirmed = ReadWindhawkCollection();
    if (confirmed.state != RecordState::Present || confirmed.text != text)
        return {false, "import-verification-failed"};
    std::vector<std::wstring> keys;
    if (!ParseCollectionRecord(confirmed.text, keys))
        return {false, "invalid-readback"};
    return {true, existed ? "already-identical" : "import-verified", keys.size(),
            RecordHash(confirmed.text)};
}
// END TRANSFER POLICY

#ifndef TRANSFER_TEST
BOOL Wh_ModInit() {
    int argc{};
    auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv || argc != 4) {
        if (argv)
            LocalFree(argv);
        return FALSE;
    }
    TransferResult result;
    try {
        if (!InitializeStorageNames())
            result.status = "user-identity-failed";
        else if (std::wstring(argv[1]) == L"export")
            result = ExportCollection(argv[2]);
        else if (std::wstring(argv[1]) == L"import")
            result = ImportCollection(argv[2]);
        // Only disposable validation IDs may erase their own test copy. Public API
        // has no delete operation, so erase the value's contents and reset marker.
        else if (std::wstring(argv[1]) == L"clear-test" &&
                 std::wstring(WH_MOD_ID).starts_with(L"local@ntd-transfer-test-")) {
            bool ok = Wh_SetStringValue(g_collectionStorageKey.c_str(), L"") &&
                      Wh_SetIntValue(g_collectionReadyKey.c_str(), 0) &&
                      ReadWindhawkCollection().state == RecordState::Missing;
            result = {ok, ok ? "test-copy-cleared" : "test-cleanup-failed"};
        }
    } catch (...) {
        result = {false, "exception"};
    }
    std::string json = std::string("{\"success\":") + (result.success ? "true" : "false") +
                       ",\"status\":\"" + result.status +
                       "\",\"entries\":" + std::to_string(result.entries) + ",\"sha256\":\"" +
                       result.sha256 + "\"}";
    auto temporary = std::wstring(argv[3]) + L".tmp";
    if (WriteNewFile(temporary.c_str(), json.data(), static_cast<DWORD>(json.size())))
        MoveFileExW(temporary.c_str(), argv[3], MOVEFILE_WRITE_THROUGH);
    LocalFree(argv);
    return TRUE;
}
void Wh_ModAfterInit() {}
void Wh_ModBeforeUninit() {}
void Wh_ModUninit() {}
#endif
