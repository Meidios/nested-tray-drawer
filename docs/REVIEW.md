# Review and verification

Reviewed on 2026-10-27 for experimental version 0.1.9. This is a local source
review and verification record, not official Windhawk approval or a zero-defect
guarantee. The support matrix in the README remains intentionally narrow.

## Findings addressed

- Removed the background HighContrastChanged subscription so an in-flight
  off-thread delegate cannot outlive mod unload. Color refresh now uses existing
  UI-thread drawer-load/theme handlers; their exceptions are contained.
- Moved owning-thread checks ahead of drawer-state reads in native hook entry
  points, keeping non-UI hook calls away from UI-owned state.

The accepted footer dimensions, native icon templates, saved-record format,
matching, partitioning and drop/menu policies were retained.

## Checks performed

- Local-ID and catalog-ID C++ builds, five lifecycle callback exports, engine
  context export and nine native hook symbols against the matching local PDB.
- Record round trips, Unicode, bounds, malformed/duplicate keys and membership
  matching, including absent/reappearing identities.
- Cross-process local/catalog migration, destination precedence, explicit-empty
  tombstones, stale-backup prevention, corruption handling and instance guards
  in isolated registry fixtures.
- Repeated icon additions, partition bounds, owned drop sources, pointer and
  geometry boundaries, and scoped menu-hold lifetime/owner changes.
- Official validation functions executed locally with one expected `amd64`
  manual-review warning and no unexpected warnings.

For the initial official submission commit `0c16f58e`,
[PR #6645](https://github.com/ramensoftware/windhawk-mods/pull/6645) passed the
Windhawk 1.6.1, 1.7.3 and 2.0.0-alpha.7 build jobs. The source-validation job
fails on the same `amd64` manual-confirmation warning; this remains unresolved
by a human reviewer. The author requested the official AI review. These build
results do not broaden the inspected runtime support matrix.

Earlier live verification on the inspected configuration covered native icons,
multiple collection, drag-to-collect, simultaneous drawers, recognized app menus,
mod reload restoration, icon disappearance/reappearance and compact dark-theme
footer appearance. Native cleanup and restoration were observed during reloads.
The review's lifecycle-only changes do not add new compatibility coverage.

## Remaining coverage

A complete desktop Explorer restart, full keyboard/activation/drag-cancel
matrix, DPI/monitor variants, light/high-contrast appearance, live theme switching,
portable legacy import and universal custom-menu support remain unverified.
Other Windows builds require their own native-layout inspection and runtime evidence.

## Publication contents

Only source, GPL license, documentation and build/policy-test scripts are
included. Production registry values, icon identifiers, local application paths,
DLLs, PDB dumps, desktop screenshots and debug logs are excluded.
