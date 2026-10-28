// SPDX-License-Identifier: GPL-3.0
// Semantic fixtures based on inspected x64 and ARM64 identity implementations.
#include <windows.h>
#include <algorithm>
#include <array>
#include <charconv>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <vector>
#include <map>
#include <cstdio>
#include <cstdlib>

struct WH_DISASM_RESULT {
    size_t length;
    char text[96];
};
std::map<uintptr_t, std::string> instructions;
size_t instructionLength = 4;
BOOL Wh_Disasm(void* address, WH_DISASM_RESULT* result) {
    auto found = instructions.find(reinterpret_cast<uintptr_t>(address));
    if (found == instructions.end() || found->second.size() >= sizeof(result->text))
        return FALSE;
    result->length = instructionLength;
    std::strcpy(result->text, found->second.c_str());
    return TRUE;
}
#include "../build/identity-accessor-actual.inc"

#define CHECK(x)                                                              \
    do {                                                                      \
        if (!(x)) {                                                           \
            std::fprintf(stderr, "Identity test failed line %d\n", __LINE__); \
            return 1;                                                         \
        }                                                                     \
    } while (false)
using Code = std::vector<std::string>;
Code xQuery = {"lea rax, [rcx-0x10]", "neg rcx", "sbb rcx, rcx", "and rcx, rax", "jmp 0x4000"};
Code xGetter = {"push rbx",     "sub rsp, 0x30", "mov rbx, rdx", "lea rdx, [rcx+0x48]",
                "mov rcx, rbx", "call 0x3000",   "ret"};
Code xCopy = {"push rbx",
              "sub rsp, 0x20",
              "mov rax, qword ptr [rdx]",
              "mov rbx, rcx",
              "mov qword ptr [rcx], rax",
              "mov eax, dword ptr [rdx+0x8]",
              "mov dword ptr [rcx+0x8], eax",
              "movups xmm0, xmmword ptr [rdx+0xc]",
              "add rdx, 0x20",
              "movdqu xmmword ptr [rcx+0xc], xmm0",
              "ret"};
Code aQuery = {"sub\tx8, x0, #0x10", "cmp\tx0, #0", "csel\tx0, xzr, x8, eq", "b\t0x4000"};
Code aGetter = {"pacibsp",
                "stp x19, x20, [sp, #-0x20]!",
                "mov x29, sp",
                "ldr x8, [x0, #0x50]",
                "mov x19, x1",
                "str x1, [sp, #0x10]",
                "add x22, x0, #0x70",
                "str x8, [x19]",
                "ldr w8, [x0, #0x58]",
                "str w8, [x19, #0x8]",
                "ldur q16, [x0, #0x5c]",
                "stur q16, [x19, #0xc]",
                "ret"};
Code aCopy = {"pacibsp",
              "ldr x8, [x1]",
              "mov x19, x0",
              "str x8, [x19]",
              "ldr w8, [x1, #0x8]",
              "str w8, [x19, #0x8]",
              "ldur q16, [x1, #0xc]",
              "stur q16, [x19, #0xc]",
              "ret"};
void Fixture(Code const& query, Code const& getter, Code const& copy) {
    instructions.clear();
    instructionLength = 4;
    for (auto pair :
         {std::pair<uintptr_t, Code const*>{0x1000, &query}, {0x2000, &getter}, {0x3000, &copy}})
        for (size_t i = 0; i < pair.second->size(); ++i)
            instructions[pair.first + i * 4] = (*pair.second)[i];
}
bool Decode(IdentityMachine machine, ptrdiff_t& adjustment, size_t& offset) {
    return DecodeIdentityAccessor(reinterpret_cast<BYTE*>(0x1000), reinterpret_cast<BYTE*>(0x2000),
                                  reinterpret_cast<BYTE*>(0x3000), adjustment, offset, machine);
}
int main() {
    ptrdiff_t adjustment{};
    size_t offset{};
    Fixture(xQuery, xGetter, xCopy);
    CHECK(Decode(IdentityMachine::X64, adjustment, offset) && adjustment == -16 && offset == 72);
    for (auto const& mutation :
         Code{"mov eax, dword ptr [rdx+0x9]", "mov rax, qword ptr [rdx+0x8]"}) {
        auto copy = xCopy;
        copy[5] = mutation;
        Fixture(xQuery, xGetter, copy);
        CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    }
    auto getter = xGetter;
    getter[5] = "call 0x3010";
    Fixture(xQuery, getter, xCopy);
    CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    getter = xGetter;
    getter[3] = "lea rdx, [rcx+0x49]";
    Fixture(xQuery, getter, xCopy);
    CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    auto query = xQuery;
    query[0] = "lea rcx, [rcx-0x10]";
    query[3] = "and rcx, rcx";
    Fixture(query, xGetter, xCopy);
    CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    // Register allocation, displacement width and whitespace do not bind the decoder to opcodes.
    query = xQuery;
    query[0] = "LEA R10, [RCX - 0x110]";
    query[3] = "AND RCX, R10";
    getter = xGetter;
    getter[2] = "MOV R8, RDX";
    getter[3] = "LEA RDX, [RCX + 0x108]";
    getter[4] = "MOV RCX, R8";
    Fixture(query, getter, xCopy);
    CHECK(Decode(IdentityMachine::X64, adjustment, offset) && adjustment == -272 && offset == 264);
    Fixture(aQuery, aGetter, aCopy);
    CHECK(Decode(IdentityMachine::Arm64, adjustment, offset) && adjustment == -16 && offset == 80);
    // Inlined getters prove their own three fields without requiring a constructor call.
    Fixture(aQuery, aGetter, Code{"ret"});
    CHECK(Decode(IdentityMachine::Arm64, adjustment, offset) && offset == 80);
    for (auto index : {3u, 8u, 10u}) {
        getter = aGetter;
        getter[index] = "ldr x8, [x0, #0x60]";
        Fixture(aQuery, getter, aCopy);
        CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    }
    getter = aGetter;
    getter.insert(getter.begin() + 7, "mov x8, xzr");
    Fixture(aQuery, getter, aCopy);
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    getter = aGetter;
    getter[4] = "mov w19, w1";
    Fixture(aQuery, getter, aCopy);
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    getter = xGetter;
    getter[2] = "mov ebx, edx";
    Fixture(xQuery, getter, xCopy);
    CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    query = aQuery;
    query[2] = "csel x0, xzr, x8, ne";
    Fixture(query, aGetter, aCopy);
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    getter = {"pacibsp", "mov x19, x0", "mov x0, x1", "add x1, x19, #0x50", "bl 0x3000"};
    Fixture(aQuery, getter, aCopy);
    CHECK(Decode(IdentityMachine::Arm64, adjustment, offset) && offset == 80);
    getter = aGetter;
    getter[3] = "ldr x8, [x0, #0x7fffffffffffffff]";
    Fixture(aQuery, getter, aCopy);
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    Fixture(aQuery, aGetter, aCopy);
    instructionLength = 0;
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    instructionLength = 8;
    CHECK(!Decode(IdentityMachine::Arm64, adjustment, offset));
    Fixture(xQuery, xGetter, xCopy);
    instructionLength = 16;
    CHECK(!Decode(IdentityMachine::X64, adjustment, offset));
    puts(
        "Identity semantics passed: x64/ARM64, inline/constructor copies, changed registers/encodings, field layout, call target, clobbers, bounds and disassembly failures.");
}
