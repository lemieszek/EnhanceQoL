# CDM Aura Performance Checkpoint

Date: 2026-06-22
Branch: `dev/cdm-aura-o1-rebind`
Checkpoint commit: `b2fbe580 Optimize CDM aura refresh paths`
Local checkpoint tag: `checkpoint-cdm-aura-gated-perf`
Squashed 11.4 commit: `82d64541 Optimize cooldown panel runtime performance`

## Purpose

This note documents the CDM_AURA performance changes made before release so the exact scope is easy to audit or roll back if aura-related issues appear later.

## Changed File

- `EnhanceQoL/Modules/Aura/CooldownPanels_CDMAuras.lua`

## What Changed

### Targeted CooldownID rebind

CDM aura entries now maintain an index from cooldown ID to entry keys:

- `runtime.entryKeysByCooldownID`
- `registerStateCooldownIndex`
- `unregisterStateCooldownIndex`

The Blizzard Cooldown Viewer `SetCooldownID` and `ClearCooldownID` hooks now only react to `BuffIconCooldownViewer` frames and refresh affected entries/panels instead of scheduling broad tracked-panel rescans.

Main functions added:

- `cdm.GetCooldownViewerFrameName`
- `cdm.IsBuffIconViewerFrame`
- `cdm.UpdateScanForBuffIconRebind`
- `CDMAuras:RefreshEntriesForCooldownRebind`

### Secret value guard

The old comparison path used `pcall(areValuesEqual, ...)` to survive Blizzard secret values. This caused Perfy stack reconstruction warnings because the guarded comparison can intentionally throw inside `pcall`.

The comparison now checks `isSecretValue(...)` before comparing:

- no direct Lua comparison is attempted on secret values
- the Perfy `bad stack` / `missing stack information` issue disappeared in later traces

### OnDataChanged gate

The CDM_AURA listener for `CooldownViewerSettings.OnDataChanged` now only schedules a rescan when all of these are true:

- there are active tracked CDM aura panels
- Blizzard `CooldownViewerSettings` is currently shown
- at least one panel is synced to `BUFF_ICON`

This prevents regular aura/runtime changes from triggering CDM_AURA rescans when the Blizzard CDM settings panel is not open.

## Performance Evidence

Perfy traces were analyzed in separate temp folders.

Relevant folders:

- Baseline: `/tmp/perfy-cdm-aura-baseline-current`
- No aura entries: `/tmp/perfy-cdm-aura-no-aura/analyzer`
- Aura before OnDataChanged gate: `/tmp/perfy-cdm-aura-with-aura-2/analyzer`
- Aura after OnDataChanged gate: `/tmp/perfy-cdm-aura-gated-ondatachanged/analyzer`

### Aura before gate -> Aura after gate

Both traces were about 15 seconds.

```text
Total CPU/sec:    103067.4 -> 84050.7  (-18.5%)
Total MEM/sec:   1887236.8 -> 1871308.9 (-0.8%)

CDM_AURA CPU/sec: 14745.0 -> 10888.7 (-26.2%)
CDM_AURA MEM/sec: 346564.3 -> 311791.5 (-10.0%)
```

CDM_AURA bucket changes:

```text
BuildRuntimeData CPU/sec:          12416.9 -> 9145.5 (-26.3%)
ScanTrackedBuffs CPU/sec:           3201.3 -> 2303.5 (-28.0%)
Frame mutation/rebind CPU/sec:      2427.0 -> 1728.8 (-28.8%)
Runtime scan lookup CPU/sec:        7016.6 -> 5001.0 (-28.7%)
CooldownViewer API/cache CPU/sec:   1172.1 -> 838.3  (-28.5%)
Panel rescan scheduling CPU/sec:       1.0 -> 0.0    (-100%)
```

### No aura -> Aura after gate

The post-gate aura run was close to the no-aura run in total cost:

```text
No Aura CPU/sec:    81290.3
Aura gated CPU/sec: 84050.7
Delta:              +3.4%

No Aura MEM/sec:    1777594.8
Aura gated MEM/sec: 1871308.9
Delta:              +5.3%
```

## Remaining Hot Path

The main remaining CDM_AURA cost is not the event scheduling path. It is the normal runtime refresh path:

```text
CooldownPanels:RefreshPanel
CooldownPanels:UpdateRuntimeIcons
CDMAuras:BuildRuntimeData
CDMAuras:ScanTrackedBuffs
```

If future optimization is needed, investigate reducing repeated scan/lookup work inside `BuildRuntimeData`, especially:

- `resolveRuntimeEntryScanInfo`
- `findRuntimeScanInfoBySpellID`
- `getCooldownViewerInfo`
- `ScanTrackedBuffs`

## Rollback Notes

To return to this known-good checkpoint:

```bash
git checkout checkpoint-cdm-aura-gated-perf
```

To inspect the exact change:

```bash
git show b2fbe580
```

If this is later squashed into another branch, keep this document updated with the final commit hash.
