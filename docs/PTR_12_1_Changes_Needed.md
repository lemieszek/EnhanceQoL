# PTR 12.1 Changes Needed

Track EnhanceQoL changes that need follow-up before or when WoW 12.1 ships. Remove obsolete features only after verifying the behavior on the release client.

## TODO: Midnight Season 2 Altar of Fangs portal position

- PTR status: Altar of Fangs exists as a season dungeon and has a portal spell, but the dungeon location is not fully available on PTR yet.
- EnhanceQoL entry: `EnhanceQoL/Modules/MythicPlus/Init.lua`, spell `1286812`, label `AOF`, cID `588`.
- Current data:
  - `zoneID = 2588` is set for name resolution.
  - `locID`, `x`, and `y` are intentionally missing.
- Follow-up action:
  - Once Altar of Fangs exists correctly on PTR, collect `locID/x/y`.
  - Add the map-pin data with four decimal places.
  - Clear `EnhanceQoL.db.teleportNameCache` and verify the portal list still resolves the localized name.

## TODO: Auction House filter persistence

- PTR note: Auction House filters now persist across sessions.
- EnhanceQoL feature: `persistAuctionHouseFilter`
- Current code:
  - `EnhanceQoL/EnhanceQoL.lua` initializes the DB key and stores/restores `AuctionHouseFrame.SearchBar.FilterButton` state on `AUCTION_HOUSE_SHOW` / `AUCTION_HOUSE_CLOSED`.
  - `EnhanceQoL/Settings/VendorEconomy.lua` exposes the setting.
  - Locale key: `persistAuctionHouseFilter`.
- Removal reason: Blizzard provides native persistence in 12.1, so the session-only addon workaround should no longer be needed.
- Keep separate: `alwaysUserCurExpAuctionHouse` still enforces the Current Expansion filter and is not made redundant by generic persistence.
- Release action:
  - Verify Blizzard persists the same filters EnhanceQoL currently preserves.
  - Remove the DB default, show/close hook logic, setting entry, profile handling if present, and locale key.
  - Add SavedVariables cleanup for `persistAuctionHouseFilter` so old profiles do not keep a dead option.

## TODO: Group Finder reset button position

- PTR note: In Group Finder, the refresh button no longer overlaps with the filter reset button.
- EnhanceQoL feature: `groupfinderMoveResetButton`
- Current code:
  - `EnhanceQoL/Settings/CombatDungeon.lua` moves `LFGListFrame.SearchPanel.FilterButton.ResetButton`.
  - Locale key: `groupfinderMoveResetButton`.
- Removal reason: Blizzard fixes the original overlap in 12.1, so the manual reposition workaround should no longer be needed.
- Release action:
  - Verify the refresh/reset button overlap is fixed with the default Blizzard layout.
  - Remove `toggleLFGFilterPosition`, saved original point state, setting entry, DB key initialization if present, profile handling if present, and locale key.
  - Add SavedVariables cleanup for `groupfinderMoveResetButton` so old profiles do not keep a dead option.

## TODO: Investigate Roleset System for visibility features

- PTR note: Blizzard added a Roleset System. Frames can be tagged as part of a roleset, and `C_RolesetSystem.ApplyRolesetFilters` controls which rolesets are currently active.
- Why this matters: Frames in inactive rolesets should stay hidden regardless of their normal shown state, which may affect visibility logic that relies on `Show`, `Hide`, `IsShown`, hooks, or Blizzard frame state.
- EnhanceQoL areas to review:
  - Visibility-related features and frame hiding/showing helpers.
  - Movers or skins that assume a Blizzard frame can be shown after calling `Show()`.
  - Any settings that force Blizzard frames visible or hidden depending on UI mode.
- Follow-up action:
  - Verify the API and usage once 12.1 PTR UI source/docs are locally available.
  - Inspect `Blizzard_UIModeManager.lua` examples mentioned in the PTR notes.
  - Decide whether Roleset behavior needs compatibility guards or can be useful for our own visibility features.

## TODO: Support native unit-frame ping icons

- PTR source: `origin/ptr`, build `12.1.0.68209`.
- PTR note: Blizzard added native UI ping icon frames to unit frames. This is separate from the older world ping pin system.
- New Blizzard pieces:
  - `Interface/AddOns/Blizzard_PingUI/Blizzard_PingUI.xml`: `UnitPingIconFrameTemplate` with `UnitPingIconFrameMixin`, `IconFrame`, `BackgroundMarker`, and `Icon`.
  - `Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.xml`: compact unit frames now include `<Frame parentKey="pingIconFrame" inherits="UnitPingIconFrameTemplate">`.
  - `Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua`: `DefaultCompactUnitFrameSetup` assigns `frame.pingIconFrame:SetGUIDMatch(...)` against `UnitGUID(frame.unit)`.
  - `Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml`: target frames now include `parentKey="PingIconFrame"` anchored near the portrait.
- Live status: Retail/live build `12.0.7.68235` does not contain `UnitPingIconFrameTemplate`, `pingIconFrame`, or target-frame `PingIconFrame`.
- Why this matters: EnhanceQoL unit-frame work that repositions, scales, hides, skins, or mirrors Blizzard unit-frame children needs to preserve or intentionally integrate the native ping icon on 12.1+ clients.
- EnhanceQoL areas to review:
  - Unit frame and group-frame modules that touch compact party, compact raid, target, boss, target-of-target, or pet frame children.
  - Any aura, health-bar, texture, strata, scale, mover, or frame-cleanup logic that assumes a fixed compact-unit-frame child set.
  - Any code that hides unknown Blizzard children or reanchors center/overlay elements around `centerStatusIcon`, `readyCheckIcon`, role icons, or health bars.
- Follow-up action:
  - Gate integration by feature detection, for example `frame.pingIconFrame` or `UnitPingIconFrameTemplate`, so live clients keep the old path.
  - Verify whether EnhanceQoL layouts need explicit size, position, alpha, strata, or visibility handling for `pingIconFrame` and `PingIconFrame`.
  - Test compact party, raid, target, and boss frames with an actual PTR UI ping and Frame Stack open.
  - Document whether the addon should expose any setting for native ping icons or only preserve Blizzard behavior.
