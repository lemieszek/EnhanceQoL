## Locales

- `EnhanceQoL` uses one central AceLocale namespace: `EnhanceQoL`.
- Core locale files live only in `EnhanceQoL/Locales/<locale>.lua`.
- Do not add or recreate module locale files under `EnhanceQoL/Modules/*/Locales`.
- `EnhanceQoLSharedMedia` is a separate addon and keeps its own locale files in `EnhanceQoLSharedMedia/Locales/<locale>.lua`.
- CurseForge is not the source of truth for translations anymore. Locale changes are maintained locally in git.

### Supported Locales

- `enUS`
- `deDE`
- `esES`
- `esMX`
- `frFR`
- `itIT`
- `koKR`
- `ptBR`
- `ruRU`
- `zhCN`
- `zhTW`

### Required Workflow

- Every user-facing text change must update all supported locale files in the same change.
- Do not leave new, renamed, or rewritten strings in English only.
- Do not postpone locale propagation to a later follow-up commit or PR.
- A locale change is incomplete until the key set matches across every supported locale file.
- When adding a key, add it to every locale file.
- When renaming a key, rename it in every locale file.
- When removing a key, remove it from every locale file.
- Keep the locale files alphabetically sorted by key so diffs stay reviewable.
- Keep the same key names across all locales. Only the translated values should differ.

### Implementation Rules

- In core addon Lua files, use the unified locale table from `LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL")` or `GetLocale(addonName)` when `addonName` is `EnhanceQoL`.
- Do not use old module-specific locale namespaces such as `EnhanceQoL_Aura`, `EnhanceQoL_MythicPlus`, `EnhanceQoL_Mover`, `EnhanceQoL_Vendor`, or similar.
- Do not introduce redundant locale aliases like `LMain`, `LCore`, `LVendor`, or `LMP` when they all point to the same `EnhanceQoL` locale table.
- Prefer Blizzard globals such as `_G.NONE` or `_G.STATUS_TEXT_BOTH` when the game already provides the text, instead of creating duplicate locale keys for them.

### Validation

- Before finishing locale work, verify that every `EnhanceQoL/Locales/*.lua` file has the same keys.
- Before finishing locale work, verify that key order is still alphabetically sorted.
- Before finishing locale work, verify that no module locale folders were reintroduced under `EnhanceQoL/Modules`.

## Release and Beta Packaging

- Releases use `BigWigsMods/packager@v2` through `.github/workflows/release.yml`.
- BigWigs supports beta release types for tags such as `10.10.0-beta1`, but it does not support `@beta@` as a native content gate.
- Do not use raw BigWigs-style `@beta@` markers for project gating.
- EnhanceQoL uses its own pre-packager gate script: `scripts/prepare_packager_gates.sh`.
- Use `eqol-beta` markers for content that should exist only in beta packages:
  - TOC/TXT/Markdown: `#@eqol-beta@` through matching `#@end-eqol-beta@`.
  - Markdown also supports `<!--@eqol-beta@-->` through `<!--@end-eqol-beta@-->`; prefer this HTML-comment form in `CHANGELOG.md`.
  - Lua: `--@eqol-beta@` through `--@end-eqol-beta@`.
  - XML: `<!--@eqol-beta@-->` through `<!--@end-eqol-beta@-->`.
- Use `non-eqol-beta` markers only for content that should exist in non-beta packages.
- For TOC, Markdown, and TXT files, non-matching gated blocks are removed by the script.
- For Lua and XML files, non-matching gated blocks are commented out by the script to keep line numbers more stable for bug reports.
- If the user asks to make or update a beta changelog, keep the beta section in `CHANGELOG.md` wrapped in `<!--@eqol-beta@-->` and `<!--@end-eqol-beta@-->`.
- If the user asks to prepare a release changelog while a beta changelog should remain available, keep the beta-gated section separate and place the release section below it, outside the beta gate.
- Do not merge beta-only changelog entries into a release section unless the user explicitly says those beta items are shipping in that release.
- Alpha changelog entries may be technical and specific because they document early prerelease iteration.
- Beta changelog entries should be less technical than alpha entries because beta builds are installed by users. Keep beta notes user-facing while still specific enough for testers.
- When preparing the final release changelog for the same version, consolidate all alpha and beta entries into a small number of user-facing summary bullets. Do not copy verbose prerelease details directly into the release section.
- In a final release changelog, omit fixes for bugs that only existed in alpha or beta builds of that same version. Those fixes are implementation churn for a newly shipped feature, not user-facing release notes.
- For final release changelogs, prefer concise feature/result wording over implementation details, internal issue context, stack traces, or intermediate prerelease regressions.
- Use changelog sections consistently: `Added` for new user-facing functionality, `Changed` for behavior/default/slot/order changes, and `Fixed` for bugs in already-shipped behavior.
- Before creating or pushing any release, beta, or alpha tag at the user's request, run project Luacheck when Lua code changed and only tag after it passes or after explicitly reporting remaining failures to the user.
- After changing packaging gates, verify `scripts/prepare_packager_gates.sh` with at least `bash -n`, and make sure the release workflow still runs Luacheck after the gate step.

## Secret Values

- When handling Blizzard secret values, do not do Lua arithmetic, comparisons, `tonumber`, `min`, `max`, sorting, modulo, or similar numeric operations on the secret value.
- Pass secret values through to Blizzard APIs that can consume them directly, such as status bar setters, instead of converting or deriving values in Lua.

## Large Lua Files and Local Limits

- Lua chunks have a hard limit of 200 local variables. In large addon files, avoid adding new top-level locals casually.
- Prefer a single module table such as `local UF = {}`, `local RB = {}`, or `local M = {}` for grouped functions, constants, and runtime state when a file is large or already near the local limit.
- Store related values as table fields, such as `UF.constants`, `UF.state`, or `UF.helpers`, instead of many independent top-level locals.
- Use local upvalues only for genuinely hot paths, imported APIs, or small scoped helpers where the benefit is clear.
- Before adding several new locals to a large file, check whether the file already has local-limit warnings or history, and prefer table fields if in doubt.
- Do not refactor an existing large file only to reduce locals unless required for the task. Keep changes scoped.

## EditMode MultiDropdowns

- `SettingType.MultiDropdown` callbacks must not rebuild or refresh the open EditMode settings dialog while the dropdown menu is open.
- In `setSelected` handlers, update the underlying config and any affected preview/runtime frames only. Avoid calls that recreate the dialog or pooled settings rows, such as direct `UpdateSettings()` calls or helper paths that rebuild the standalone settings UI.
- Let the EditMode settings library handle its own deferred refresh after selection changes. Rebuilding the dialog from inside a dropdown selection can corrupt the dropdown button text, causing the clicked checkbox label to appear as the dropdown's selected value.
- For concrete patterns, follow the `SettingType.MultiDropdown` entries in `EnhanceQoL/Modules/Aura/UF_GroupFrames.lua`: use `values`, `isSelected`, and `setSelected`, and keep UI rebuilds outside the selection callback.
