# PTR 12.1 AuraContainer migration notes

Source checked: local `wow-ui-source` `origin/ptr`, commit `d93edffb6`, build `12.1.0.68301`.
Comparison context: this document includes both the first 12.1 AuraContainer drop and the 2026-06-24 PTR update from build `12.1.0.68209` to `12.1.0.68301`.

This is an investigation note for the announced PTR3 aura restriction work. The PTR2 source still allows existing addon-owned aura rendering paths, but Blizzard's new `Blizzard_AuraContainer` code is already the compatibility target for future aura display work.

## What is concretely forbidden now

The concrete aura frame found with explicit forbidden aspects is Blizzard's new intrinsic `AuraButton`:

- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.xml`
- XML wraps the template in `<ScopedModifier useForbiddenObjectTable="true">`.
- `AuraButton` has these forbidden aspects:
  - `UntrustedScriptExecution`
  - `UntrustedLayoutScriptExecution`
  - `ScriptedInput`
  - `AlwaysPropagateInput`
  - `QueryFocus`

The current PTR source does not show legacy `BuffFrame`, `CompactUnitFrame`, `TargetFrame`, or `SecureAuraButtonTemplate` being explicitly converted to forbidden aura objects yet. That likely matches the PTR2 state: the new container exists, but the hard lock is expected in PTR3.

Other non-aura objects using `SetForbidden()` in the same PTR source are internal delegates or unrelated protected surfaces, for example:

- `Blizzard_Game/Shared/EventRouting.lua`: `internalEventFrame`
- `Blizzard_Menu/Menu.lua`: `MenuAttributeDelegate`
- `Blizzard_Settings_Shared/Blizzard_SettingsInbound.lua`: `AttributeDelegate`
- `Blizzard_StaticPopup/StaticPopup.lua`: `StaticPopupAttributeDelegate`
- `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`: `FramePositionDelegate`
- `Blizzard_UIPanels_Game/Mainline/TradeFrame.lua`: `TradePlayerInputMoneyFrame`

These are useful as signal that Blizzard is expanding object-level restrictions, but they are not the AuraContainer migration target.

## New forbidden-aspect API surface

`ForbiddenAspectConstantsDocumentation.lua` expanded from only two aspects to a larger mask-based model:

- `SetToDefaults`
- `ScriptBindings`
- `UntrustedScriptExecution`
- `UntrustedLayoutScriptExecution`
- `EventRegistrations`
- `AlwaysPropagateInput`
- `ScriptedInput`
- `QueryFocus`
- `Shown`

It also adds inheritance categories:

- `Enum.ForbiddenAspectInheritance.Parent`
- `Enum.ForbiddenAspectInheritance.Layout`

The important implementation detail is that forbidden aspects can propagate through parentage and anchoring. This is why AuraContainer validates custom subregions by checking both parent inheritance and layout inheritance.

APIs that now explicitly check these aspects include:

- `Show`, `Hide`, `SetShown` check `ForbiddenAspect.Shown`.
- `RegisterEvent`, `RegisterUnitEvent`, `RegisterEventCallback`, `UnregisterEvent`, `UnregisterAllEvents`, `IsEventRegistered` check `ForbiddenAspect.EventRegistrations`.
- `SetScript` and `HookScript` check `ForbiddenAspect.ScriptBindings`.
- `Click` and some EditBox input APIs check `ForbiddenAspect.ScriptedInput`.
- `IsMouseMotionFocus` checks `ForbiddenAspect.QueryFocus`.
- `SetParent` and several texture/statusbar setters now require allowed inheritance of forbidden parent aspects.

For addon code, the risk is not normal addon-owned frames. The risk is attaching, reparenting, anchoring, hooking, showing, hiding, or registering events on Blizzard-provided forbidden aura objects or their protected child regions.

## New AuraContainer files

PTR has a new addon:

- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.toc`
- `Blizzard_AuraContainer.lua`
- `Blizzard_AuraContainer.xml`
- `Blizzard_AuraButton.lua`
- `Blizzard_AuraButton.xml`
- `Blizzard_CustomAuraContainer.lua`
- `Blizzard_CustomAuraContainer.xml`
- `Blizzard_CustomAuraButton.lua`
- `Blizzard_CustomAuraButton.xml`
- `Blizzard_AuraContainerInbound.lua`
- `Blizzard_AuraContainerShared.lua`
- family-specific `Blizzard_AuraButtonTooltip.xml`

The XML templates are intrinsic:

- `AuraContainer`
- `AuraButton`
- `CustomAuraContainerTemplate`
- `CustomAuraButtonTemplate`

The custom templates expose public inbound mixins while keeping private behavior in local mixins.

## Temporary PTR2 usage snapshot of the new AuraButton

This section is intentionally temporary. Blizzard has announced that the actual aura restriction/migration step is expected with PTR3. In build `12.1.0.68301`, repo-wide source search only tells us what PTR2 currently wires up, not what Blizzard intends the final 12.1 aura architecture to be.

PTR2 source search shows the new intrinsic `AuraButton` is only used inside `Blizzard_AuraContainer` itself:

- `Blizzard_CustomAuraButton.xml` defines `CustomAuraButtonTemplate` as `<AuraButton ...>`.
- `Blizzard_CustomAuraContainer.lua` creates children with `CreateFrame("AuraButton", nil, self, templateName)`.

No current PTR2 source evidence shows `BuffIconCooldownViewer`, `BuffBarCooldownViewer`, `BuffFrame`, `TargetFrame`, `PartyMemberFrame`, or `CompactUnitFrame` using the new intrinsic `AuraButton` type yet.

Important naming collision: older Blizzard code also has names such as `AuraButtonMixin`, `AuraButtonTemplate`, and `AuraContainerTemplate` in `Blizzard_BuffFrame`. These are not the new `Blizzard_AuraContainer` intrinsic objects:

- `Blizzard_BuffFrame/BuffFrameTemplates.xml` defines old `<Button name="AuraButtonTemplate" ... mixin="AuraButtonMixin">`.
- `Blizzard_BuffFrame/BuffFrame.lua` creates those with `CreateFrame("BUTTON", nil, self.AuraContainer, "AuraButtonTemplate")`.
- This path still manually sets tooltip, duration, debuff border, and symbol.

Unit-frame aura displays also still use their older local templates/data paths in this PTR2 source:

- `Blizzard_UnitFrame/Mainline/TargetFrame.xml` uses `TargetBuffFrameTemplate` and `TargetDebuffFrameTemplate`.
- `Blizzard_UnitFrame/Shared/CompactUnitFrame.xml` defines `CompactUnitFrameTemplate`; aura code is still normal unit-frame logic plus private-aura behavior, not `Blizzard_AuraContainer`.

Cooldown Manager also does not use the new intrinsic `AuraButton` in this PTR2 source:

- `Blizzard_CooldownViewer/CooldownViewer.xml` defines `CooldownViewerBuffIconItemTemplate` and `CooldownViewerBuffBarItemTemplate` as normal `<Frame>` templates.
- `BuffIconCooldownViewer` uses `CooldownViewerBuffIconItemTemplate`.
- `BuffBarCooldownViewer` uses `CooldownViewerBuffBarItemTemplate`.
- CDM tracks aura instances through `CooldownViewerItemDataMixin:SetAuraInstanceInfo(auraInfo, unit)`, stores `auraInstanceID`, and registers item frames in `CooldownViewerMixin.auraInstanceIDToItemFramesMap`.
- CDM tooltips still call `tooltip:SetUnitAuraByAuraInstanceID(auraUnit, auraInstanceID, "INCLUDE_NAME_PLATE_ONLY")`.

Temporary interpretation: `AuraButton` is not just "the unit-frame aura button" in current PTR2. It is a new generic intrinsic button type supplied by `Blizzard_AuraContainer`. Blizzard has not yet migrated BuffFrame, UnitFrame aura displays, or Cooldown Manager tracked buff frames onto it in the visible PTR2 source, but this should not be treated as a stable final design. Re-check this section when PTR3 lands; that is the build where Blizzard may actually switch those systems internally or enforce the new path for addons.

## AuraContainer behavior

`AuraContainerPrivateMixin` handles:

- `UNIT_AURA` registration for the configured unit.
- `SetEnabled(enabled)`.
- `SetUnit(unitToken)`.
- `UpdateAllAuras()`.
- full updates on show/hide, enabled changes, and unit changes.

`CustomAuraContainerPrivateMixin` handles:

- full parses with `C_UnitAuras.GetUnitAuras(unit, filterString)`;
- delta updates from `unitAuraUpdateInfo.addedAuras`;
- delta refreshes from `updatedAuraInstanceIDs` via `C_UnitAuras.GetAuraDataByAuraInstanceID`;
- removals from `removedAuraInstanceIDs`;
- aura ordering through `TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, true)`;
- sequential assignment to registered aura frames via `auraFrame:SetAuraInstance(unit, auraData, isFullUpdate)`.

Public container methods:

- `AddAuraFilter(filterString, options)`
- `ClearAuraFilters()`
- `AddAuraFrame(auraFrame)`
- `AddAuraFramesFromTable(auraFrames)`
- `AddAuraFramesFromTemplate(templateName, count)`
- `RemoveAuraFrame(auraFrame)`
- `RemoveAllAuraFrames()`
- `GetAuraFrame(index)`
- `GetAuraFrameCount()`

`AddAuraFilter` options currently include:

- `maxFrameCount`
- `roundUpFrameIndex`

## AuraButton behavior

`AuraButtonPrivateMixin` owns:

- `SetAuraContainer(auraContainer)`
- `ClearAuraContainer()`
- `SetAuraInstance(unitToken, auraData, isFullUpdate)`
- `ClearAuraInstance()`
- `GetAuraInstance()`
- `ShowTooltip()`
- `HideTooltip()`
- `UpdateTooltip()`

Tooltip handling is now native to AuraButton:

- `OnEnter` calls `ShowTooltip()`.
- `OnLeave` calls `HideTooltip()`.
- `OnUpdate` calls `UpdateTooltip()`.
- tooltip uses `AuraButtonTooltip`, which inherits private-aura tooltip support.
- tooltip adds the aura button's inheritable layout forbidden aspects before ownership/population.

Custom AuraButtons display data through `CustomAuraButtonPrivateMixin:ApplyAuraInstance(unitToken, auraData)`.

Built-in display pieces:

- stack/application count
- dispel border
- dispel symbol
- cooldown duration
- text duration
- duration bar
- icon
- spell name
- visibility

Public button methods:

- `SetApplicationCount(fontString, options)`
- `SetAuraBorder(texture, options)`
- `SetAuraSymbol(fontString, options)`
- `SetDurationCooldown(cooldownFrame)`
- `SetDurationText(fontString, options)`
- `SetDurationBar(statusBar, options)`
- `SetIcon(texture)`
- `SetSpellName(fontString)`
- matching `Get*` and `Clear*` methods for each display piece

## New border and symbol support

PTR2 adds `AuraButtonBorderStyle`:

- `AuraButtonBorderStyle.Atlas = 0`
- `AuraButtonBorderStyle.Color = 1`

`SetAuraBorder(texture, options)` defaults:

- `showIcon = true`
- `showWhenHarmful = true`
- `showWhenHelpful = false`
- `style = AuraButtonBorderStyle.Atlas`

The border uses:

- `AuraUtil.SetAuraBorderAtlas(texture, dispelType, showIcon)` for atlas style;
- `AuraUtil.SetAuraBorderColor(texture, dispelType)` for color style.

`SetAuraSymbol(fontString, options)` defaults:

- `showWhenHarmful = true`
- `showWhenHelpful = false`
- `style = AuraButtonBorderStyle.Color`

The symbol uses `AuraUtil.SetAuraSymbol(fontString, dispelType)`.

Important validation rule: all display regions passed into `SetAuraBorder`, `SetAuraSymbol`, `SetIcon`, `SetDurationText`, `SetDurationBar`, `SetDurationCooldown`, `SetApplicationCount`, or `SetSpellName` must:

- not already be forbidden themselves;
- have inherited all required parent forbidden aspects from the AuraButton;
- have inherited all required layout forbidden aspects from the AuraButton.

Practically, these regions must be children of, or otherwise correctly parented to, the AuraButton and anchored in a way that inherits the button's layout restrictions. Free-floating external regions will error.

## Duration support

Custom AuraButton does not use numeric `duration` / `expirationTime` directly for rendering. It calls:

- `C_UnitAuras.GetAuraDuration(unitToken, auraInstanceID)`

The returned duration object is then used for:

- `Cooldown:SetCooldownFromDurationObject(durationObject, clearIfZero)`
- `DurationTextBinding:SetDuration(durationObject)`
- `StatusBar:SetTimerDuration(durationObject, interpolation, direction)`

This matches Blizzard's secret-value direction. Migration code should prefer Blizzard duration objects and avoid deriving numeric values from secret aura state where possible.

## EnhanceQoL areas that need migration work

### Highest priority: `EnhanceQoL/Modules/Aura/DefaultAuraContainers.lua`

Current state:

- Builds replacement default buff/debuff containers with `SecureAuraHeaderTemplate`.
- Uses `SecureAuraButtonTemplate`.
- Manually styles button visuals, cooldowns, count text, icon shape, tooltip, and borders.
- Hooks/updates aura buttons from aura data and `UNIT_AURA`.

PTR3 risk:

- This is the closest match to the future restricted surface. If Blizzard prevents custom aura headers/buttons from reading or displaying normal auras directly, this path will need to become a wrapper around `CustomAuraContainerTemplate` and `CustomAuraButtonTemplate`.

Required adaptation direction:

- Add a 12.1+ / feature-detected container backend using `CreateFrame("AuraContainer", ..., "CustomAuraContainerTemplate")` or the correct PTR3 final template path.
- Add filters with `AddAuraFilter("HELPFUL", ...)` and `AddAuraFilter("HARMFUL", ...)`.
- Create AuraButtons through `AddAuraFramesFromTemplate(...)` or add explicitly created `AuraButton` children.
- Move icon/count/duration/border regions inside each AuraButton, then register them through `SetIcon`, `SetApplicationCount`, `SetDurationCooldown` or `SetDurationText`, and `SetAuraBorder`.
- Preserve EnhanceQoL positioning, growth, sizing, shape, opacity, and profile settings outside the restricted aura assignment path.
- Avoid direct `GameTooltip:SetUnitAuraByAuraInstanceID` on custom buttons if AuraButton tooltip handling is available.

### High priority: `EnhanceQoL/Modules/Aura/UF_GroupFrames.lua`

Current state:

- Builds custom group-frame aura containers and aura buttons for buffs, debuffs, externals, healer buffs, private auras, and filtering.
- Uses `C_UnitAuras` data and `auraInstanceID` heavily.
- Has custom border textures, icon shape, duration text profiles, stack text, filter selection, sorting, and private aura settings.

PTR3 risk:

- Any normal buff/debuff/external aura rendering that depends on direct addon-owned aura buttons may need to move behind AuraContainer assignment.
- Private aura anchors are a separate Blizzard-supported path and should remain separate unless Blizzard changes that API.

Required adaptation direction:

- Split data/model code from visual AuraButton registration.
- Define one AuraContainer-backed rendering adapter for normal helpful/harmful aura lists.
- Keep healer-buff placement and custom sorting as policy around container filters/frame order, not as direct C_UnitAuras rendering if PTR3 blocks it.
- Verify whether `AddAuraFilter` supports all needed filter strings and whether extra custom filtering must happen before display or by using separate containers.
- Rebuild border/count/duration rendering as AuraButton child regions registered with the new inbound methods.

### High priority: `EnhanceQoL/Modules/Aura/UF.lua`

Current state:

- Custom unit-frame aura-related rendering and frame ownership exists around player, target, focus, boss, pet, and target-of-target surfaces.
- Already uses rolesets for 12.1+ unit frame visibility.

PTR3 risk:

- Any normal aura display that is not Blizzard-owned or AuraContainer-backed may break once aura display restrictions are enabled.

Required adaptation direction:

- Inventory every custom normal aura strip on player/target/focus/boss frames.
- Move aura display creation behind the same adapter used by `UF_GroupFrames`.
- Keep non-aura unit-frame styling, cast bars, health/power, portrait, ping receiver, and rolesets separate.

### Medium/high priority: `EnhanceQoL/Modules/Aura/CooldownPanels_CDMAuras.lua`

Current state:

- Integrates tracked auras from Blizzard Cooldown Manager.
- Reads frame aura data and `auraInstanceID`, caches `C_UnitAuras.GetAuraDataByAuraInstanceID`, and uses `C_UnitAuras.GetAuraDuration`.

PTR3 risk:

- If Blizzard's CDM aura frames become forbidden, direct reads from frame fields or external manipulation of their children may fail.
- The current use of `GetAuraDuration` is aligned with the new model.

Required adaptation direction:

- Treat Blizzard CDM frames as read-only and feature-detect forbidden status before touching frame internals.
- Prefer public CDM APIs and auraInstanceID values only when exposed safely.
- Avoid mutating or reparenting CDM aura children.

### Medium priority: `EnhanceQoL/Submodules/ClassBuffReminder.lua`

Current state:

- Scans aura state with `C_UnitAuras.GetAuraSlots`, `GetAuraDataBySlot`, `GetAuraDataByAuraInstanceID`, and `UNIT_AURA`.
- Displays its own reminder icons, not necessarily actual unit aura containers.

PTR3 risk:

- Lower if Blizzard only restricts aura display containers and not aura query APIs.
- Higher if PTR3 also restricts addon aura scanning for non-player units or secret fields.

Required adaptation direction:

- Keep this as data/logic until PTR3 confirms query restrictions.
- Do not migrate reminder icons to AuraContainer unless Blizzard restricts the underlying aura queries or the UI is meant to represent actual unit aura buttons.

### Private auras

Current EnhanceQoL private aura code uses Blizzard private aura anchors in `UF_Helper.lua`.

Keep this separate from normal AuraContainer migration. The new `AuraButtonTooltip` supports private aura tooltip behavior, but private aura anchoring remains its own API path through `C_UnitAuras.AddPrivateAuraAnchor`.

## Migration design proposal

Add a small internal adapter instead of rewriting each module directly:

- `addon.AuraContainerCompat` or similar module table.
- Feature detection:
  - `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` succeeds.
  - `CreateFrame("AuraButton", nil, container, "CustomAuraButtonTemplate")` succeeds.
  - created buttons expose `SetIcon`, `SetDurationCooldown`, `SetApplicationCount`, `SetAuraBorder`.
- Backend selection:
  - current live/PTR2 backend remains existing code;
  - 12.1+/PTR3 backend uses Blizzard AuraContainer when the templates and methods exist.
- Module-facing contract:
  - create container for unit/filter/kind;
  - configure max count and frame rounding;
  - provide a button setup callback to attach EnhanceQoL visuals;
  - provide a layout callback for size, growth, spacing, shape, and strata.

Keep migration boundaries clear:

- AuraContainer owns aura assignment, deltas, duration objects, tooltip, and visibility.
- EnhanceQoL owns layout, style configuration, icon shape, optional border appearance, duration text profile selection, and settings UI.
- Addon code should not call `Show`, `Hide`, `SetScript`, `HookScript`, `RegisterEvent`, or `SetParent` on Blizzard forbidden aura buttons except through documented public inbound methods.

## Open questions for PTR3

- Will existing `SecureAuraHeaderTemplate` / `SecureAuraButtonTemplate` stop working for normal addon aura displays?
- Will `C_UnitAuras.GetAuraSlots`, `GetUnitAuras`, and `GetAuraDataByAuraInstanceID` remain fully usable for addon logic?
- Will addons be allowed to add custom filters beyond Blizzard filter strings, or must custom filtering happen by using multiple containers/max counts?
- Can AuraContainer ordering be customized beyond `AuraUtil.DefaultAuraCompare`?
- Can addon code safely create non-forbidden child regions for forbidden AuraButtons if parented/anchored correctly, or must all children be created from XML/templates?
- Can custom icon shapes and masks be applied to AuraButton icon textures without violating forbidden layout inheritance?
- How should weapon enchants and default buff weapon slots map to the new container?
- Does `AuraButtonTooltip` fully replace addon-owned tooltip customization for normal and private auras?

## PTR3 test checklist

- Log in with all EnhanceQoL aura modules enabled and capture first errors around `ForbiddenAspect`, `IsForbidden`, `SetShown`, `RegisterEvent`, `SetParent`, `SetScript`, and `HookScript`.
- Test default buff/debuff replacement containers.
- Test player/target/focus/boss aura displays.
- Test group/raid custom aura displays, including buffs, debuffs, externals, healer buffs, and ignored aura filters.
- Test private aura anchors separately.
- Test CDM tracked aura panels and verify whether Blizzard CDM aura frames can still be read without mutating them.
- Test tooltip behavior on AuraContainer-backed buttons.
- Test custom borders, dispel symbols, stack text, duration cooldown, duration text, and duration bars.
- Test icon shape/mask/zoom/desaturation/darkness settings on AuraButton child regions.
- Run `luacheck --no-color -q .` after code changes.
