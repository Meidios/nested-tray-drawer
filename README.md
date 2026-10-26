# Nested Tray Drawer

An experimental [Windhawk](https://windhawk.net/) mod that adds a second drawer
inside Windows' hidden notification-icons panel. Drag rarely used icons onto
the added chevron to collect them, while keeping your everyday icons nearby.

![Nested Tray Drawer feature overview](https://raw.githubusercontent.com/Meidios/nested-tray-drawer/0d4ae2b9b09aba9a907541d0855e86a55a51e711/assets/feature-overview-0edbded10469.png)

*Concept illustration; panel styling and example icons are illustrative.*

**Version 0.1.9 is experimental and is not in the official Windhawk catalog.**
Support is restricted to the inspected configuration below.

## Features

- Collect multiple icons by dragging them from the first drawer onto the added
  chevron. Earlier collected icons stay collected.
- Open both drawers together and retain original app icons, native input
  handlers and recognized native context menus.
- Save collection membership automatically. Reloading the mod retains it;
  temporarily absent icons are collected again when they return.
- Share the same per-user record between local and catalog installation IDs,
  with one-time migration from this mod's older storage.
- Use a compact 40 DIP footer with a subtle divider and an inset rounded button.

## Supported configuration

| Component | Inspected configuration |
| --- | --- |
| Windows | Windows 11 23H2, build 22631.5126, x64 |
| Windhawk | 1.7.3 |
| Taskbar.View.dll | 2125.4507.10.0 |
| taskbar.dll | PE timestamp `10195DD3`, image size `3B6000`, inspected identity interface |

Other builds, including other 23H2 updates, are not claimed as supported.
Windows 10, ARM64, 24H2 and 25H2 are unvalidated. Native version and identity
guards are intentional; do not remove them to force support on another build.

## Install and use

1. Open [nested-tray-drawer.wh.cpp](nested-tray-drawer.wh.cpp) and copy its contents.
2. In Windhawk, choose **Create a New Mod**, replace the starter source with
   this file, then compile and enable it. Disable an existing copy first.
3. Open Windows' normal hidden-icons drawer. Drag an icon onto the added
   chevron and release it. Repeat to collect more icons.
4. Click the added chevron to open or close the second drawer. An empty second
   drawer does not open.
5. To return all collected icons, right-click the added chevron and choose
   **Restore all collected icons**. This explicitly clears saved membership.

There is no right-click icon picker or supported individual drag-out gesture.
Disabling the mod restores Windows' normal tray presentation and keeps records.
The detailed README embedded in the source is the authoritative support statement.

## Saved records and switching copies

Version 0.1.8 and later use
`HKEY_CURRENT_USER\Software\Meidios\Windhawk\NestedTrayDrawer`, value
`CollectedIconsV1`, independently of Windhawk's `local@` prefix.

Update an older local copy to 0.1.8 or later before switching installation
source. Disable it before enabling another copy; confirm restoration before
uninstalling the disabled copy. A future catalog copy will use the same record.
Portable users must update their local copy first. Versions without saved
records, 0.1.6 and earlier, cannot be recovered by stored-record migration.

An existing destination record always wins, including an explicitly cleared
collection. Old backups are preserved and are not synchronized. Missing apps
retain membership. Apps that change their GUID, executable path or UID may
require collection again; ambiguous identities remain visible.

Records contain app identifiers or encoded paths and UIDs. Encoding is not
encryption. The mod does not transmit records. Uninstalling leaves the shared
record in place; use the restore-all command first if you want to clear it.

## Known limitations

- Some custom or non-foreground app menus are not recognized and may dismiss
  both drawers. Native menu retention is not universal.
- Mod reload and icon disappearance/reappearance restoration were verified.
  A full desktop Explorer restart remains untested.
- Full left-click/double-click/keyboard, drag-cancel, multi-monitor, DPI and
  coexistence testing with other taskbar mods is incomplete.
- The compact footer was accepted in the inspected dark-theme configuration.
  Light/high-contrast appearance and live theme switching remain untested.
  Reopen the drawer after changing high-contrast settings to refresh its colors.

## Development and validation

See [development instructions](docs/DEVELOPMENT.md) for local builds and tests,
and [review notes](docs/REVIEW.md) for checked behavior and remaining coverage.
No compiled DLLs, user records or desktop logs are distributed in this repository.

For issues, provide Windows build, both taskbar module versions, Windhawk version
and reproduction steps. Remove private app paths and identifiers from logs.

## License and credits

Code is licensed under [GPL-3.0](LICENSE). Native overflow access is adapted
from m417z's GPLv3
[Taskbar notification icon spacing](https://github.com/ramensoftware/windhawk-mods/blob/main/mods/taskbar-notification-icon-spacing.wh.cpp).
Authored by [MEI / Meidios](https://github.com/Meidios), with ChatGPT/Codex assistance.
