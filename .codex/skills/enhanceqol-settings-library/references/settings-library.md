# EnhanceQoL Settings Library Reference

## Wrapper Surface

`EnhanceQoL/Settings/SettingsUI.lua` is the compatibility layer between feature settings files, Blizzard Settings, `LibEQOLSettingsMode-1.0`, and the modern config center (`LibEQOLConfig-1.0` / `LibEQOLConfigUI-1.0`).

Feature settings files should normally call `addon.functions.SettingsCreate*` wrappers:

- `SettingsCreateCategory(parent, treeName, sort, newTagID)`
- `SettingsCreateExpandableSection(cat, data)`
- `SettingsCreateHeadline(cat, text, extra)`
- `SettingsCreateText(cat, text, extra)`
- `SettingsCreateCheckbox(cat, data)`
- `SettingsCreateCheckboxes(cat, entries)`
- `SettingsCreateCheckboxDropdown(cat, data)`
- `SettingsCreateDropdown(cat, data)`
- `SettingsCreateScrollDropdown(cat, data)`
- `SettingsCreateMultiDropdown(cat, data)`
- `SettingsCreateSlider(cat, data)`
- `SettingsCreateInput(cat, data)`
- `SettingsCreateButton(cat, data)`
- `SettingsCreateColorPicker(cat, data)`
- `SettingsCreateColorOverrides(cat, data)`
- `SettingsCreateSoundDropdown(cat, data)`
- `SettingsCreateKeybind(cat, bindingIndex, parentSection)`
- `SettingsAttachNotify(setting, notify)`

The wrappers register both the legacy Blizzard Settings control and modern config metadata. They also store handles in `addon.SettingsLayout.elements[var]` where possible.

## Categories And Sections

Root categories are prepared in the normal settings bootstrapping files, e.g. `addon.SettingsLayout.rootECONOMY`, `rootGENERAL`, `rootSOCIAL`, `rootUI`, and similar category fields.

Use expandable sections for visible grouping:

```lua
local section = addon.functions.SettingsCreateExpandableSection(category, {
	name = L["someSectionKey"],
	newTagID = "SomeFeature",
	expanded = false,
	colorizeTitle = false,
})
```

Attach controls to the section with `parentSection = section`. For arrays of checkbox data, use the local recursive helper pattern:

```lua
local function applyParentSection(entries, section)
	for _, entry in ipairs(entries or {}) do
		entry.parentSection = section
		if entry.children then applyParentSection(entry.children, section) end
	end
end
```

`SettingsCreateExpandableSection` also registers a modern page. Passing `configPageID`, `description`, `icon`, `iconAtlas`, `mainToggleID`, `newTagID`, and `order` can influence the modern config page.

`SettingsCreateHeadline(cat, text, { parentSection = section })` starts a new modern config group within the section/page.

## Common Control Data Fields

Most wrappers accept these fields:

- `var`: config key and setting id without `EQOL_` prefix.
- `text`: label.
- `desc`: description or tooltip text.
- `default`: default value for the setting registration.
- `get`: value getter. Use when data is not plain `addon.db[var]`.
- `set` or `func`: setter/callback. Wrapper conventions vary, so check nearby examples.
- `parentSection`: expandable section handle.
- `parent` / `element`: parent control initializer/element for dependent controls.
- `parentCheck`: function returning whether the child is enabled/visible.
- `isEnabled`: additional enabled predicate.
- `searchtags`: search metadata.
- `newTagID`: new-feature badge id.
- `notify`: callback attached through `SettingsLib:AttachNotify`.

The global settings prefix is `EQOL_`. Use `Settings.NotifyUpdate("EQOL_" .. var)` when a dependent control must refresh its displayed value after another setting changes.

## Checkbox Pattern

For simple profile-backed booleans:

```lua
addon.functions.SettingsCreateCheckbox(category, {
	var = "featureEnabled",
	text = L["featureEnabled"],
	desc = L["featureEnabledDesc"],
	default = false,
	func = function(value)
		addon.db["featureEnabled"] = value and true or false
		if addon.Feature and addon.Feature.Refresh then addon.Feature.Refresh() end
	end,
	parentSection = section,
})
```

For children, either pass `children` to a checkbox or create controls separately with `element = parent.element` and a `parentCheck`.

## Slider Pattern

Sliders should define `min`, `max`, `step`, `default`, `get`, and `set` when nil or compatibility values are possible:

```lua
addon.functions.SettingsCreateSlider(category, {
	var = "featureScale",
	text = L["featureScale"],
	min = 0.5,
	max = 2,
	step = 0.05,
	default = 1,
	get = function() return tonumber(addon.db["featureScale"]) or 1 end,
	set = function(value)
		addon.db["featureScale"] = tonumber(value) or 1
		if addon.Feature and addon.Feature.Refresh then addon.Feature.Refresh() end
	end,
	parentSection = section,
})
```

The wrapper applies a numeric formatter by default in `SettingsCreateSlider`.

## Dropdown Patterns

Use `SettingsCreateDropdown` for normal option sets and `SettingsCreateScrollDropdown` for long or dynamic lists.

Static table options can be maps or ordered arrays. Use `order` for deterministic map order:

```lua
local order = { "LEFT", "CENTER", "RIGHT" }
local options = {
	LEFT = "LEFT",
	CENTER = "CENTER",
	RIGHT = "RIGHT",
}
addon.functions.SettingsCreateDropdown(category, {
	var = "featureAnchor",
	text = L["featureAnchor"],
	list = options,
	order = order,
	default = "CENTER",
	get = function() return addon.db["featureAnchor"] or "CENTER" end,
	set = function(_, value) addon.db["featureAnchor"] = value end,
	parentSection = section,
})
```

Dynamic lists should use `listFunc` or `optionfunc`, rebuild local order tables with `wipe(orderTable)`, and include a safe empty option such as `[""] = _G.NONE`.

When changing a source setting that affects another dropdown or slider, notify the dependent control:

```lua
local entry = addon.SettingsLayout and addon.SettingsLayout.elements and addon.SettingsLayout.elements["dependentVar"]
local variable = entry and entry.setting and entry.setting.GetVariable and entry.setting:GetVariable()
if variable and Settings and Settings.NotifyUpdate then Settings.NotifyUpdate(variable) end
```

## MultiDropdown Patterns

`SettingsCreateMultiDropdown` supports two main selection models.

Use per-option state for existing stores or derived state:

```lua
addon.functions.SettingsCreateMultiDropdown(category, {
	var = "featureSelectedFlags",
	text = L["featureSelectedFlags"],
	options = options,
	order = order,
	menuHeight = 240,
	isSelectedFunc = function(value)
		local store = addon.db["featureSelectedFlags"]
		return store and store[value] == true
	end,
	setSelectedFunc = function(value, selected)
		addon.db["featureSelectedFlags"] = addon.db["featureSelectedFlags"] or {}
		addon.db["featureSelectedFlags"][value] = selected or nil
		if addon.Feature and addon.Feature.Refresh then addon.Feature.Refresh() end
	end,
	parentSection = section,
})
```

Use table-map selection for simple map storage:

```lua
addon.functions.SettingsCreateMultiDropdown(category, {
	var = "featureSelectedFlags",
	text = L["featureSelectedFlags"],
	options = options,
	getSelection = function()
		return addon.db["featureSelectedFlags"] or {}
	end,
	setSelection = function(map)
		addon.db["featureSelectedFlags"] = type(map) == "table" and map or {}
		if addon.Feature and addon.Feature.Refresh then addon.Feature.Refresh() end
	end,
	parentSection = section,
})
```

Important rules:

- Selection maps are boolean maps: `selection[value] == true`.
- Remove or nil deselected values unless existing code intentionally stores false.
- `setSelectedFunc` and `setSelection` must not rebuild an open settings dialog.
- For EditMode `SettingType.MultiDropdown`, follow `EnhanceQoL/Modules/Aura/UF_GroupFrames.lua`: `values`, `isSelected`, and `setSelected` update config/runtime state only.
- Use `hideSummary = false` only when the summary is useful; the wrapper hides summaries by default.

## Color, Input, Button, And Sound Controls

`SettingsCreateInput` supports `numeric`, `formatter`, `maxChars`, `inputWidth`, `readOnly`, `selectAllOnFocus`, `placeholder`, `justifyH`, `min`, `max`, `clampToRange`, `height`, `multiline`, and `multilineHeight`.

`SettingsCreateColorPicker` stores `{ r, g, b, a }` under `addon.db[var]` or `addon.db[var][subvar]`. Provide `default`, `callback`, `colorizeLabel`, and `hasOpacity` when needed.

`SettingsCreateColorOverrides` handles multi-row color panels. Provide `entries`, `getColor`, `setColor`, and `getDefaultColor`.

`SettingsCreateButton` uses `text`/`label` and `func`. Add a stable `var` for modern config registration and search if the button is not uniquely identified by text.

`SettingsCreateSoundDropdown` supports `soundResolver`, `previewSoundFunc`, `playbackChannel`, `getPlaybackChannel`, `placeholderText`, `previewTooltip`, `menuHeight`, `frameWidth`, and `frameHeight`.

## SavedVariables And Defaults

When adding a new setting:

1. Add or confirm the default in the repo's default DB definition.
2. Add migration/backfill if old profiles can contain incompatible values.
3. Make getters defensive when data can be nil, nested, per-character, or private.
4. Preserve existing key names unless a migration is implemented.
5. If the setting should show a "new" marker, add the `EQOL_...` key or relevant tag id to `EnhanceQoL/NewSettingsTable.lua`.

Private or per-character data should use explicit `get`/`set`, as seen in `EnhanceQoL/Settings/VendorEconomy.lua`.

## Locale Requirements

All labels, descriptions, section titles, placeholders, and custom button text are user-facing text.

Use:

```lua
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL")
```

or `GetLocale(addonName)` when `addonName` is `EnhanceQoL`. Do not create module-specific locale namespaces.

Update every supported core locale file in `EnhanceQoL/Locales/<locale>.lua` in the same change. Keep key sets equal and keys alphabetically sorted. Do not add `EnhanceQoL/Modules/*/Locales`.

Prefer Blizzard globals for established game terms.

## Final Validation Commands

Use the repo's existing checks when available. At minimum, inspect:

```bash
rg -n 'AceLocale-3.0.*EnhanceQoL_' EnhanceQoL
find EnhanceQoL/Modules -path '*/Locales' -type d
```

For locale work, verify all `EnhanceQoL/Locales/*.lua` files have matching keys and sorted key order. Use existing project scripts if present; otherwise perform a focused parser/check before finishing.
