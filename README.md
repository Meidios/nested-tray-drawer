# Nested Tray Drawer

Add a second drawer to Windows 11's hidden notification-icons panel. Drag an
icon onto the added chevron to collect it, then click the chevron to open the
second drawer. Both drawers can remain visible together. Icons retain their
native templates, input handlers and app context menus. The footer is 40 DIP high.

![Nested Tray Drawer feature overview](https://raw.githubusercontent.com/Meidios/nested-tray-drawer/0d4ae2b9b09aba9a907541d0855e86a55a51e711/assets/feature-overview-0edbded10469.png)

*Concept illustration; example icons and panel styling are illustrative.*

## Experimental compatibility

Runtime validated on Windows 11 23H2 build 22631.5126 x64 with Windhawk 1.7.3,
Taskbar.View.dll 2125.4507.10.0 and taskbar.dll from that installation.
ARM64 builds and offline identity/symbol checks are also provided, using
ARM64 taskbar.dll 10.0.26100.9549, SystemTray.dll 2608.26001.100.0 and
Taskbar.View.dll 2125.26100.0.0. ARM64 UI behavior has not been tested on a
physical device and remains experimental. Windows 10, other Windows builds,
DPI/monitor combinations and interactions with other tray mods are unverified.

The mod discovers SystemTray.dll, older Taskbar.View.dll or ExplorerExtensions.dll
and resolves the required internal interfaces and methods from symbols. It no
longer requires a particular DLL version, timestamp, image size or vtable address.
This does not make every Windows build supported: the symbol names, root layout
and native identity ABI must still be compatible.

Persistent identity uses Wh_Disasm to follow a recognized interface-adjustment
thunk and the HWND/UID/GUID copy on x64 or ARM64. Both constructor-based and
inlined identity getters are recognized; the native owning-string return type
is never called across C++ ABIs. Unrecognized symbols, instructions, field layouts
or call targets are rejected rather than guessed. Some older ARM64 binaries
(such as the inspected taskbar.dll 10.0.22621.3810) lack the required Identity()
symbol. Do not bypass these checks to force compatibility.

## Use

1. Open the normal taskbar hidden-icons drawer.
2. Drag an icon onto the added chevron and release it. Repeat to collect more.
3. Click the added chevron to open or close the second drawer. Both drawers can
   remain open; an empty second drawer does not open.
4. Right-click the chevron and choose **Restore all collected icons** to return
   every collected icon and explicitly clear saved membership.

There is no right-click icon picker or individual drag-out command. Disabling
the mod using Windhawk's own toggle restores the native tray and preserves
the saved collection. There is no second enable setting.

## Saved collection

Records use Windhawk's public storage API, with a Windows-user SID suffix to
separate users in installed Windhawk. Membership uses an app GUID, or the owning
process's exact executable path and native UID. Missing apps keep their records;
ambiguous or inaccessible identities remain visible. Changed app identifiers can
require recollection. Records contain app identifiers/encoded paths, not secrets;
the encoding is not encryption. No records are transmitted.

An invalid record is kept intact and icons remain visible. The chevron's context
menu offers **Reset saved collection** for explicit recovery; a readable invalid
API record is backed up before resetting. Uninstalling removes Windhawk-owned
storage. Updates and Explorer restarts preserve the collection within the same mod ID.

## Known limits

- Custom app menus that do not expose foreground native menu state can dismiss
  both drawers after the bounded menu-start grace period.
- Complete Explorer restart, full mouse/keyboard and drag-cancel coverage,
  light/high-contrast appearance and live theme switching remain untested.
- Symbol discovery across module families is implemented; runtime compatibility
  on 24H2/25H2 is not established by the local build tests.

## Credits

Native overflow access is adapted from m417z's GPLv3
[Taskbar notification icon spacing](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/taskbar-notification-icon-spacing.wh.cpp).
Symbol-based interface resolution and vtable verification follow Ris Peng's GPLv3
[System Tray Folders](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/system-tray-folders.wh.cpp).
The Wh_Disasm instruction-scanning approach follows m417z's GPLv3
[Taskbar height and icon size](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/taskbar-icon-size.wh.cpp).
Nested Tray Drawer keeps a separate simultaneous flyout and drag-based membership;
it does not replace the first drawer with an in-grid folder view.
The single-file mod retains its GPL-3.0 declaration.

## Development-to-catalog switch

The official mod contains no development import/export code. A separate
[one-time transfer tool](docs/COLLECTION-TRANSFER.md) preserves a local copy's
collection through each ID's public API. It verifies exact readback, refuses
conflicting destination data, and restores the local configuration on failure.
Normal same-ID updates retain records without this tool.

## Source and review

Version 0.1.13 is experimental and is not yet in the official catalog.
Official submission: [windhawk-mods #6645](https://github.com/ramensoftware/windhawk-mods/pull/6645).
To try the local source, create a new mod in Windhawk and replace the starter
with [nested-tray-drawer.wh.cpp](nested-tray-drawer.wh.cpp), then compile it.
Development commands and evidence boundaries are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
and [docs/REVIEW.md](docs/REVIEW.md).
