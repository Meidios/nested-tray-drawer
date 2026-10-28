# Identity decoding and ARM64 evidence

Since version 0.1.12, the mod replaces fixed x64 byte patterns with Windhawk's public
`Wh_Disasm` API. The scan follows the approach used in m417z's
[Taskbar height and icon size](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/taskbar-icon-size.wh.cpp).
It is bounded and fails closed; it does not execute an arbitrary instruction stream.

The required interfaces, vtables and functions are still resolved from symbols.
The decoder checks the conditional QueryInterface adjustment and tracks pointer
aliases and constant additions in a small supported instruction set. It then
requires source-to-destination copies of HWND (8 bytes), UID (4 bytes) and GUID
(16 bytes) at consistent offsets. A getter can copy the fields inline or call
the exact symbol-resolved constructor after that constructor's prefix is verified.
From 0.1.13, unmodelled operations are rejected outright, including pair loads,
implicit-register instructions and non-stack write-back addressing. Recognized
SP-relative save stores remain supported; identity aliases cannot be assigned
to SP. Pointer authentication explicitly invalidates LR tracking. Unrecognized branches,
32-bit pointer truncation, mismatched fields and call targets, malformed numbers,
invalid instruction lengths and scan limits all reject the accessor.

The native owning-string result is never constructed, returned or destroyed by
this mod. The verified prefix is read with ReadProcessMemory, as in earlier
versions; persistent collection keys and storage format remain unchanged.

## Actual binary checks

ARM64 binaries were obtained using [Winbindex ARM64](https://winbindex.m417z.com/?arch=arm64)
and downloaded from Microsoft's public symbol server. SHA256 was compared with
the index. Each matching public PDB was selected using the DLL's embedded CodeView
GUID and age; the target DLLs were mapped only as data and were never executed.

| ARM64 binary | SHA256 | Result |
| --- | --- | --- |
| taskbar.dll 10.0.26100.9549 | `a8bd211035ab1978cacd97f79bd167741e7bf7d8a2393a2dcc918200b9fbccf8` | All required identity symbols match; actual adjustment thunk and inlined getter decode to -16 / 80. |
| SystemTray.dll 2608.26001.100.0 | `d1dc1edfea99a1b2d3d4c418a289074da98c03398a7a30e64a83da9111e66712` | All 18 required tray symbol strings match. |
| Taskbar.View.dll 2125.26100.0.0 | `ca1c6990a3f0ee25f78e9a3f3624316b902edc9459dffdb03c74d9d784872f0a` | All 18 required tray symbol strings match. |
| taskbar.dll 10.0.22621.3810 | `02ec91c63d874c86b4ac1996ef5186417fa8b877a7f9430d0a82b09ecbe6e092` | Required Identity() symbol absent; this sample is not supported. |

The actual decoder was tested against the ARM64 image using the same Binary Ninja
ARM64 disassembler/formatter vendored in Windhawk (Windhawk source revision
`7413a57a3f964a6e0e11f491f388da103d947a5d`). The x64 image was separately mapped
as data in an owned test process; a temporary diagnostic mod called the real
Windhawk `Wh_Disasm` API and decoded its adjustment/offset as -16 / 72. The probe
did not hook Explorer, read collection records or execute the inspected taskbar DLL.

The numbers above are fixture expectations, never hardcoded production offsets.
PDB decoration display differences such as `__ptr64` were normalized for the
offline symbol comparison, consistent with the undecorated signatures used by mods.

## Limits

`@architecture x86-64` selects native x64 or ARM64 for explorer.exe. Both targets
are cross-built with Windhawk's bundled compiler and matching engine import
libraries. Compilation and these offline checks are evidence of an implementation,
not a physical ARM64 runtime or UI test. An ARM64 device remains necessary to
validate both drawers, native app input/menus, drag collection and unload behavior.
No ARM64 runtime acceptance is claimed. Compatibility with every older ARM64
Windows build is not claimed, and unknown layouts remain rejected.
