# Never Secret SpellMisc MasterMind

This tracks Wago `SpellMisc` changes for `Attributes_15` never-secret flags.

## Codex Automation

- Automation: `~/.codex/automations/eqol-never-secret-spellmisc/automation.toml`
- Schedule: every Wednesday
- Script: `scripts/check_never_secret_spells.py`
- Baseline: `docs/data/wago_spellmisc_never_secret_baseline.json`
- Source: `https://wago.tools/db2/spellmisc/csv`

The Codex automation runs locally in the EnhanceQoL workspace, downloads the
latest Wago SpellMisc CSV, extracts unique `SpellID` values where
`Attributes_15` contains these bits, and diffs them against the checked-in
baseline:

| Key | Bit | Meaning |
| --- | --- | --- |
| `aura_never_secret` | `0x04000000` | Aura never secret |
| `cd_never_secret` | `0x80000000` | Cooldown never secret |

When SpellIDs are added or removed, the script exits non-zero and writes a
Markdown report. The automation should then review the report, look up new IDs,
and summarize recommended addon changes. It should not update the baseline or
commit changes unless explicitly requested.

## Review Flow

1. Open the local report `/tmp/eqol_never_secret_spellmisc_report.md`.
2. Look up added SpellIDs on Wowhead or Wago.
3. For Aura never secret:
   - Add user-facing ignore candidates to `EnhanceQoL/Modules/Aura/UF_GlobalAuraIgnore.lua`.
   - Add healer-placement relevant spells to `EnhanceQoL/Modules/Aura/UF_GroupFrames_HealerBuffs.lua`.
   - Skip DNT/internal test spells unless they need explicit blacklist coverage.
4. For CD never secret:
   - Check whether Cooldown Panels, cooldown auras, or cooldown visibility lists need an update.
5. After addon data is updated and reviewed, regenerate the baseline:

```bash
python3 scripts/check_never_secret_spells.py --write-baseline
```

Use `--csv /path/to/spellmisc.csv` when reviewing a manually downloaded
SpellMisc file.
