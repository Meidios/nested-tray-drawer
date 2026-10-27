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
respectively. Artifacts go to the ignored `build/` directory. Both variants share
the per-user collection store. Do not load both simultaneously.

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
```

These extract the actual policy/storage blocks from the maintained source.
Migration tests use isolated, unique registry fixtures under
`Software\Meidios\Windhawk\NestedTrayDrawer.Tests` and remove only their own
fixture. They do not clear or rewrite the production collection store.

## Lifecycle constraints

All drawer models and XAML controls belong to Explorer's captured UI thread.
Normal unload removes handlers, restores native item binding and removes owned
controls before the DLL is unloaded. A failed cleanup retains inert code and its
instance guard until Explorer exits. Do not replace UI-thread cleanup with a
global XAML destructor.

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
