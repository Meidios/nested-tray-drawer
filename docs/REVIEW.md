# Review and verification

Experimental version 0.1.13, reviewed on 2026-10-27. This is development evidence,
not official Windhawk approval. The submission is
[windhawk-mods #6645](https://github.com/ramensoftware/windhawk-mods/pull/6645).

## Fourth review: decoder hardening in 0.1.13

The review of 403deec4 found no blockers and accepted both maintainer requests,
including the ARM64 implementation. A functionality note nevertheless exposed a
real conservative-decoding gap: an ignored instruction could change a second,
implicit or write-back register while retaining a stale tracked alias. New
regression fixtures reproduced an accepted but incorrect offset in 0.1.12.

The fallback now rejects unmodelled instructions outright. Non-stack write-back,
pair loads, xchg, mul and string operations are rejected; known SP-relative save
stores remain supported. STP saves registers rather than overwriting both inputs,
so rejecting every STP would break the inspected ARM64 prologues. Assigning an
identity alias to SP is rejected, and pointer-authentication instructions explicitly
invalidate LR tracking. The new negative cases and real ARM64/x64 API probes pass.
The 0.1.13 x64 build also reloaded in the original four Explorer processes;
public-API exports immediately before and after the update matched all sixteen
records exactly. No Explorer restart was performed. This is a decoder protection
change; drawer interaction and collection format are unchanged. ARM64 physical UI acceptance is still not claimed.

## Maintainer feedback and 0.1.12

- Removed the duplicate enabled setting, its atomic state, every conditional and
  Wh_ModSettingsChanged. Windhawk's own toggle controls the mod and the existing
  unload path restores the tray.
- Replaced x64 byte signatures with bounded Wh_Disasm semantic decoding, following
  the existing taskbar-icon-size instruction-scanning approach. Both x64 and
  ARM64 validate the interface adjustment and the HWND/UID/GUID prefix, including
  inlined ARM64 getters. No native owning-string result crosses a C++ ABI.
- Four local/catalog x64/ARM64 builds passed; PE machine, four lifecycle exports
  and every required native symbol were checked. The semantic tests cover both
  architectures and reject incorrect fields, call targets, pointer truncation,
  clobbers, malformed numbers, lengths and bounded-scan failures.
- Real ARM64 images and matching public PDBs were inspected without executing the
  images. The actual ARM64 getter decodes correctly with Windhawk's formatter.
  A separate owned test process exercised the real x64 Wh_Disasm API successfully.
  Reproducible sample identities and limitations are in [ARM64.md](ARM64.md).
- The x64 0.1.12 build reloaded in the original four Explorer processes. Independent
  public-API transfers immediately before/after the update matched all sixteen
  records exactly and erased disposable test copies. The installed source matched
  the maintained source. No Explorer restart was performed.

## Historical first AI review: changes and boundaries

- Removed permanent DLL pinning. Synchronized initial UI publication with unload,
  tracked active UI callbacks, and moved teardown to posted owner-thread work.
  Event revocation precedes independently guarded native restoration and visual
  removal. Menu command callbacks are revoked explicitly. Cross-thread cleanup
  reads atomic state rather than the UI-owned unique pointer.
- Reused the tray-spacing module-discovery approach and System Tray Folders'
  symbol-resolved interface/vtable verification, retaining GPL attribution.
  Removed exact DLL versions, PE timestamp/size, fixed internal IIDs, vtable RVA
  and private +64/+152 field reads.
- Persistent identity still depends on a verified x64 native ABI. Public UDK
  icon interfaces expose presentation/input but no persistent identifier. The
  Identity() return type contains an MSVC-owned string and cannot be called as
  a MinGW struct. Its symbol-resolved accessor, interface adjustment and identity
  copy ABI are recognized before positions are derived. Unknown instruction
  forms are rejected. This is not universal Windows support or ARM64 support.
- Replaced the canonical custom registry store with Windhawk's public storage
  API and per-user SID names. No Windhawk private HKLM namespace is read by the
  mod. The second review removed all development migration from both variants.
  Explicit-empty records persist and invalid records have an explicit reset path.
- Retained simultaneous drawers, native icon views, the 40-DIP footer, direct
  drag collection, existing record keys and the original menu-hold policy.
  Kept instance/concurrency guards because public storage does not itself prevent
  duplicate XAML attachment or serialize a multi-process read/modify/write.

## Second AI review

- Window-class ownership now follows only the ATOM successfully registered by
  this DLL. Unknown existing classes are rejected and never unregistered.
  The actual helper passed Win32 foreign-class collision, failed-window/thread
  reuse, cleanup and re-registration tests in an independent process.
- Removed the HKCU importer, development-only flag and unload exporter entirely
  from the single-file mod. Existing API keys and record format are unchanged.
- Added a separate personal-repository API transfer helper and hidden owned host.
  Synthetic tests use actual Windows DPAPI and exercise exact readback, retries,
  source preservation, failed writes, tampering and destination conflicts.
- A real transfer copied the latest sixteen records through the source ID's API
  and a disposable ID's API; exact text and SHA256 matched. Disposable contents
  were erased and the original local configuration/enabled state restored.
  No records were seeded into the real catalog ID ahead of the actual switch.
  The original four Explorer processes were preserved.

## Checks completed

- Both local-ID and catalog-ID C++ builds; callback/context exports; all required
  symbols against the matching local PDB dumps.
- Actual cleanup helper: exceptions injected at each of twelve restoration
  positions do not skip subsequent cleanup operations. This is a helper-level
  test, not proof of every possible disconnected-XAML failure.
- Actual accessor against the local DLL mapped as data; eight mutated instruction
  or return-ABI cases are rejected. No inspected system DLL is executed by this
  offline test.
- Actual record, partition, drop and menu policy regression checks.
- Actual API storage code with simulated namespaces: initialization, same-ID
  persistence, separate IDs/users, explicit clear, corrupt-data preservation and
  recovery, marked missing values, and failed writes.
- Initial 0.1.10 installation into the same four Explorer processes: all sixteen
  real records migrated to Windhawk storage and compared byte-for-byte with the
  pre-update value. Native identity and overflow symbols resolved successfully.

The prior 0.1.10 final build also completed a disable/replacement/re-enable cycle: the old
DLL unloaded, the final source hash matched the installed source, and all sixteen
records and the local-to-catalog handoff matched exactly. The same four Explorer
processes loaded the new DLL. No Explorer restart was performed.

For 0.1.10, the user confirmed that the saved icons restored automatically, both drawers
remain visible together, and the inner icons' app context menus work. Runtime
logs independently show real 40x40 native icon views with matching models and
the outer window visible, plus recognized native menu hold and release.
For 0.1.11, local official validation had one expected amd64 manual-confirmation
warning and zero unexpected warnings.

The 0.1.11 final source was installed and reloaded in the same four Explorer
processes. Independent public-API transfers immediately before and after the
update matched all sixteen records exactly. Both temporary test copies were
cleared and the final local configuration restored. The old DLL unloaded; the
installed source hash matched the maintained source. This does not substitute
for a complete Explorer restart test. The user then confirmed on 0.1.11 that
saved icons restored automatically, both drawers remain visible together, and
the inner icons' app context menus still work.

## Remaining coverage and review

Only Windows 11 23H2 22631.5126 x64 / Windhawk 1.7.3 has runtime evidence.
24H2/25H2, ARM64, full input/drag-cancel, DPI/multiple-monitor and light/high-contrast
coverage remain unverified. Some custom menus do not expose recognized foreground
menu state. The 0.1.12 architecture metadata change follows an actual ARM64 implementation,
not just a warning suppression. ARM64 remains limited to static/compile evidence.

The first submission head 0c16f58e passed the 1.6.1, 1.7.3 and 2.0.0-alpha.7 build
jobs. The updated head must run its own CI and AI review before human review.

## Publication boundary

Publish only the maintained source, license, documentation and build/test scripts.
Do not include build outputs, production storage values, icon identities, app
paths, private backups, PDB dumps, screenshots or raw runtime logs.
