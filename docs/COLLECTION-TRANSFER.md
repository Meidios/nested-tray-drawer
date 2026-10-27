# Local-to-catalog collection transfer

This one-time tool belongs to the personal source repository. It is not embedded
in the official single-file mod. The mod itself uses only its own Windhawk public
storage API, with the existing `CollectionV2.<Windows-user SID>` keys and `NTD1`
format. Updating a mod with the same ID needs no transfer.

## Requirements

- Windows x64, Windhawk 1.7.3 installed at its default location, and its compiler.
- A working local mod named `local@nested-tray-drawer`, version 0.1.10 or later,
  already using Windhawk API storage. Earlier legacy-only versions must first be
  upgraded to 0.1.10 and their restored collection checked.
- Elevated PowerShell running as the same Windows user as Explorer. Do not use
  another administrator account. Close the Windhawk mod editor during transfer.
- Keep the old local mod installed. Do not enable both copies simultaneously.

## Validate without switching

From an elevated PowerShell in this repository:

```powershell
.\tools\Move-CollectionToCatalog.ps1 -Mode Validate
```

The script briefly pauses the local mod and temporarily replaces its loader
configuration with an API helper. It does not edit the installed source. An owned,
hidden test process lets the helper read that ID's collection through the public
API. The script then imports into a fresh disposable ID, verifies exact text and
SHA256 equality, erases the disposable values' contents, and restores the local
configuration and previous enabled state. Explorer is not restarted.

The API has no value-delete function. Disposable validation values are therefore
overwritten with an empty string and a zero marker after verification, removing
their record contents. The temporary mod configuration is removed separately.

## Prepare the actual switch

Only do this when ready to install the catalog version immediately:

```powershell
.\tools\Move-CollectionToCatalog.ps1 -Mode PrepareCatalog
```

This mode requires that the catalog ID `nested-tray-drawer` is not installed yet.
It writes through that ID's public API, then removes only its temporary loader
configuration. It leaves API storage in place for normal catalog installation.
On success the original local configuration is restored but kept disabled. Install
the catalog mod without uninstalling the local copy, confirm automatic restoration,
and only then consider removing the local copy. Do not resume organizing in the
local copy between preparing the handoff and enabling the catalog copy.

No catalog storage is seeded by the default validation mode. This avoids saving
an outdated snapshot while the local mod is still in daily use.

## Data protection and failures

- The source collection is read only. Its original storage remains available.
- Handoff files use Windows DPAPI encryption for the current user. Existing files
  are never overwritten. Decryption is verified before attempting an import.
- A missing destination can be initialized. An identical destination is accepted
  without rewriting it. Any different destination, including an explicitly empty
  collection, is refused. Corrupt or unreadable initialized data is also refused.
- API writes are read back and compared exactly. Failed writes, corruption or
  conflicting records stop the transfer; the source configuration is restored.
- `build/collection-transfer/<run ID>/` contains a private encrypted backup,
  configuration recovery snapshot, and counts/hashes/status only. These files are
  ignored by Git and must not be published. Do not upload raw collection data.
- Do not close the elevated transfer process mid-run. If the OS or PowerShell
  terminates before its `finally` recovery, keep the catalog copy disabled and
  restore the local configuration from that run's `original-configuration.xml`;
  the record itself was not removed. Configuration recovery does not require
  clearing or recreating the collection. Ask for assistance with that recovery
  rather than deleting either mod's stored values.

The tool has no dependency on Windhawk's private storage layout. It uses the
installed loader's configuration temporarily, public APIs for each mod ID's data,
and Windows cryptography. It never reads credentials or restarts Explorer.
