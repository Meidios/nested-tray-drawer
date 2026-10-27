# Development

The maintained mod is the single file `nested-tray-drawer.wh.cpp`. Its metadata,
settings and embedded README can be used directly in Windhawk. Support guards
must remain in place until another configuration is independently inspected.

## Toolchain

- Windows x64 with Windhawk 1.7.3 installed at its default location.
- Windhawk's bundled Clang 20, C++23 and C++/WinRT headers.
- PowerShell for the scripts below. `Build.ps1` accepts `-WindhawkPath` for a
  non-default installation; the standalone test scripts use the default path.

## Build

Run from the repository root:

```powershell
.\tools\Build.ps1 -Variant Local
.\tools\Check-Build.ps1
.\tools\Build.ps1 -Variant Catalog
.\tools\Check-Build.ps1 -DllPath build\nested-tray-drawer-catalog.dll
```

The variants compile with `local@nested-tray-drawer` and `nested-tray-drawer`
respectively. Artifacts go to the ignored `build/` directory. Each ID has its own
Windhawk API store, keyed by Windows-user SID. Neither variant contains custom
registry migration or local-build export logic. Use the separate
[one-time transfer tool](COLLECTION-TRANSFER.md) immediately before a local-to-catalog
switch. Do not load both simultaneously.

`Check-Build.ps1` verifies AMD64 callback/context exports. Native hook checks
also run if a matching `research/taskbar-view-symbols.txt` PDB dump is supplied.
That research dump is not included here. A successful build alone does not validate
the native ABI or make another Windows build supported.

## Regression checks

After building, run:

```powershell
.\tools\Test-CollectionRecord.ps1
.\tools\Test-CollectionMigration.ps1
.\tools\Test-TrayPartition.ps1
.\tools\Test-ChevronDrop.ps1
.\tools\Test-MenuHold.ps1
.\tools\Test-Cleanup.ps1
.\tools\Test-IdentityAccessor.ps1
.\tools\Test-UiClassOwnership.ps1
.\tools\Test-CollectionTransfer.ps1
```

These extract the actual policy/storage blocks from the maintained source.
The API storage test uses simulated namespaces to exercise the actual storage
code. The transfer test uses synthetic records and actual Windows DPAPI encryption;
it refuses existing empty/conflicting/corrupt destination values, checks exact
readback and failed writes, and never touches the production collection. DPAPI
tests need an ordinary user context outside a restricted registry/crypto sandbox. The accessor test requires matching local taskbar PDB text in `research/`
and reads the corresponding DLL only as data. It does not execute that DLL.

## Lifecycle constraints

All drawer models and XAML controls belong to Explorer's captured UI thread.
Normal unload removes handlers, restores native item binding and removes owned
controls before the DLL is unloaded. First attachment and unload are synchronized;
posted cleanup waits for active UI callbacks to leave, revokes event handlers,
and attempts each native restore operation independently. The private endpoint's
destruction also cleans the drawer. There is no permanent DLL pin. Do not replace
UI-thread cleanup with a global XAML destructor. Window-class registration keeps
only this DLL instance's successful ATOM. An existing unknown class is rejected;
only the owned ATOM can be unregistered. The isolated class test covers foreign
class collisions, retry/reuse after thread termination and registration cleanup.

Only the existing UI-thread Loaded/ActualThemeChanged handlers refresh footer
colors. No background AccessibilitySettings event delegate is registered.
High-contrast state is sampled when the footer loads or the UI theme changes.
Hook entry points verify thread ownership before reading drawer state.

## Contributing

Document the exact inspected build, native symbols/layout evidence and real UI
results for compatibility changes. Preserve storage destination precedence and
explicit-empty tombstones. Never include personal collection records, app paths
or raw desktop logs in a change. The official-catalog submission is tracked in
[windhawk-mods #6645](https://github.com/ramensoftware/windhawk-mods/pull/6645).
