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
