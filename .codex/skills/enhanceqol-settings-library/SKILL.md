---
name: enhanceqol-settings-library
description: "Use when Codex needs to add, change, migrate, or review EnhanceQoL settings menu code that uses the new LibEQOL settings stack: SettingsCreate* wrappers, LibEQOLSettingsMode, LibEQOLConfig, LibEQOLConfigUI, expandable sections, modern config pages, EditMode settings, MultiDropdowns, SavedVariables-backed controls, settings locale text, new-setting badges, or settings runtime refresh behavior."
---

# EnhanceQoL Settings Library

Use the repo's settings wrappers as the default interface. Do not call Blizzard `Settings.*`, `LibEQOLSettingsMode-*`, `LibEQOLConfig-*`, or `LibEQOLConfigUI-*` directly from feature modules unless the existing code in the same area already does so for a necessary reason.

## First Steps

1. Read `EnhanceQoL/Settings/SettingsUI.lua` for the wrapper contract and current fields forwarded to the modern config app.
2. Read the closest existing settings file for the target area before editing. Good references:
   - `EnhanceQoL/Settings/VendorEconomy.lua` for shared root-category settings, private DB access, dynamic dropdowns, and parent sections.
   - `EnhanceQoL/Modules/Vendor/Settings_Vendor.lua` for module settings, nested controls, runtime refresh callbacks, item-list dropdowns, and MultiDropdown usage.
   - `EnhanceQoL/Settings/UIOptions.lua` for dense UI controls, color pickers, MultiDropdowns, and action bar/nameplate settings patterns.
   - `EnhanceQoL/Modules/Aura/Settings_UF.lua` and `EnhanceQoL/Modules/Aura/UF_GroupFrames.lua` for EditMode and MultiDropdown behavior.
3. For detailed field rules and examples, read `references/settings-library.md`.

## Implementation Rules

- Create controls through `addon.functions.SettingsCreateCheckbox`, `SettingsCreateCheckboxes`, `SettingsCreateDropdown`, `SettingsCreateScrollDropdown`, `SettingsCreateMultiDropdown`, `SettingsCreateSlider`, `SettingsCreateInput`, `SettingsCreateButton`, `SettingsCreateColorPicker`, `SettingsCreateColorOverrides`, `SettingsCreateSoundDropdown`, `SettingsCreateHeadline`, `SettingsCreateText`, and `SettingsCreateExpandableSection`.
- Put controls into an expandable section with `parentSection = expandable`; for arrays, use a local `applyParentSection(entries, expandable)` helper and recurse into `children`.
- Store normal profile-backed values in `addon.db`. Use explicit `get`/`set` when using private DB, nested tables, computed values, per-character data, or compatibility fallbacks.
- Add defaults/backfills for new SavedVariables and add new-feature badges to `EnhanceQoL/NewSettingsTable.lua` when the setting should be marked as new.
- Use the central `EnhanceQoL` AceLocale namespace for user-facing labels/descriptions, and update every supported locale file in the same change.
- Prefer Blizzard globals such as `_G.NONE`, `ADD`, `REMOVE`, `DEFAULT`, `FONT_SIZE`, or `BANK` when the game already provides stable text.
- Keep callbacks focused: write config, update runtime state/previews, notify dependent settings if needed. Do not rebuild the open settings dialog from a control callback.

## MultiDropdown Rules

- Prefer `options`/`list` plus `isSelectedFunc` and `setSelectedFunc` for per-option state, or `getSelection`/`setSelection` for table-map state.
- `setSelectedFunc(value, selected)` must update the underlying store and affected runtime frames only.
- Do not call settings rebuild paths or standalone settings `UpdateSettings()` from a MultiDropdown selection callback.
- Use `menuHeight` for large option lists and `order` when deterministic ordering matters.
- Preserve boolean-map selection shape: selected keys should map to `true`; deselected keys should be removed or set to nil unless existing code uses another shape.

## Review Checklist

Before finishing a settings-library task:

- Verify every new user-facing string exists in all supported `EnhanceQoL/Locales/*.lua` files, key sets match, and keys remain alphabetically sorted.
- Verify no `EnhanceQoL/Modules/*/Locales` directory was created.
- Verify new config keys have defaults/backfills or defensively handle nil.
- Verify parent/child enablement uses `parent`, `element`, and `parentCheck` consistently.
- Verify dynamic dropdowns clear or notify dependent selections when their source data changes.
- Verify `Settings.NotifyUpdate("EQOL_" .. var)` or `entry.setting:GetVariable()` is used only for dependent control refresh, not for dialog rebuilds.
- Verify code still works when optional libs or modules are not loaded, following local guard patterns.
