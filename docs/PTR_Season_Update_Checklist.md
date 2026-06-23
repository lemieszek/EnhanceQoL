# PTR Season Update Checklist

Use this checklist when a new PTR build or new Mythic+ season changes dungeon pools, teleport spells, or Blizzard UI behavior that EnhanceQoL mirrors.

## Build and branch sanity

- Confirm which client is being checked: live, PTR, or PTR2.
- Record the exact build number from the client or local Blizzard UI source.
- If using local Blizzard UI source, sync the matching branch before comparing API or frame changes.
- Do not assume PTR2 changes apply to PTR unless the build/source confirms it.

## Mythic+ season dungeon IDs

- On the PTR client, list current season Challenge Map IDs.
- Preferred in-game command: `/eqol cid` when available.
- Fallback API snippet:

```lua
/dump C_ChallengeMode.GetMapTable()
```

- For every returned ID, verify the dungeon name with `C_ChallengeMode.GetMapUIInfo(challengeMapID)`.
- Update both label maps:
  - `EnhanceQoL/Modules/MythicPlus/Init.lua`: `challengeMapIDDefaults`
  - `EnhanceQoL/Modules/Tooltip/Init.lua`: `challengeMapIDDefaults`
- Keep short labels stable and recognizable, for example `RLP`, `KR`, `TOS`, `DON`.

## Dungeon teleport spells

- Search new PTR spells for `Path of the...` teleport spells.
- Ignore unrelated `Hero's Path`, DNT, quest, or non-dungeon entries unless verified in-game.
- For each season dungeon, collect:
  - spell ID
  - short label
  - Challenge Map ID
  - dungeon name
  - expansion section in `portalCompendium`
- Update:
  - `EnhanceQoL/Modules/MythicPlus/Init.lua`
  - table: `addon.MythicPlus.variables.portalCompendium`
- Add `cId = { [challengeMapID] = true }` for every season dungeon teleport. Talent Reminder and current-season teleport sections depend on this mapping.
- If one teleport covers multiple variants, keep all relevant cIDs in the same `cId` table.

## Portal location data

- For each new portal, collect:
  - `locID`
  - `x`
  - `y`
  - `zoneID` when known
  - `mapID` when the entry already needs a legacy or dungeon map reference
- Store coordinates with four digits after the decimal point, matching existing portal entries.
- If `zoneID` or `mapID` is uncertain, leave it out until verified instead of guessing.
- Verify the world map teleport panel still opens the correct map/zone for new entries.

## Talent Reminder impact

- Talent Reminder builds season dungeon data from `portalCompendium`.
- A new dungeon is usable there only when the portal entry has the correct `cId`.
- After changing season cIDs or labels:
  - Open Talent Reminder settings.
  - Confirm each current season dungeon appears once.
  - Confirm old-season dungeons are not shown as current season entries.
  - Check that existing saved loadout cleanup does not remove valid new-season assignments.

## Tooltip impact

- Tooltip dungeon labels use `EnhanceQoL/Modules/Tooltip/Init.lua`.
- After updating `challengeMapIDDefaults`, verify:
  - Mythic+ rating tooltip shows the new season dungeons.
  - Dungeon labels match the MythicPlus labels.
  - Old dungeons returning in a new season keep their existing label unless the user-facing abbreviation is wrong.

## Existing returning dungeons

- Before adding a new entry, search for the dungeon name, cID, and teleport spell ID.
- If the teleport already exists, only add missing season cIDs or label-map entries.
- Keep existing coordinates and map data unless PTR proves they changed.
- Example: Ruby Life Pools already existed and only needs to be confirmed against the new season cID.

## Consumables and potions

- Check new PTR consumables, especially potions, health potions, mana potions, fleeting variants, and combat potions.
- Also check buff food, hearty variants, and non-buff utility food.
- Useful Wowhead PTR filter:

```text
https://www.wowhead.com/ptr/items/consumables?filter=82;2;120100#0-3+19
```

- For health potions, update `EnhanceQoL/Modules/Food/Health.lua`.
  - Verify tooltip heal values in-game or on item pages.
  - Health potions are also ingested by Cooldown Panels for highest-rank grouping through `CooldownPanels:IngestHealthPotionRankGroups()`.
  - If PTR item level, quality tier, and heal amount disagree, prefer the verified heal amount for Health Macro ordering and note the PTR inconsistency.
- For mana potions, check `EnhanceQoL/Modules/Food/Drinks.lua`.
- For damage or combat potions used in Cooldown Panels, update:
  - `EnhanceQoL/Modules/Aura/CooldownPanels.lua`: `CooldownPanels.itemHighestRankByID`
  - `EnhanceQoL/Modules/Aura/CooldownPanels_AutoDurations.lua`: `CooldownPanels.autoCooldownDurationByItemID`
- In rank groups, list highest rank first, then fallback ranks. Keep comments explicit, for example `rank2 -> rank1`, so the priority order is clear.
- Check fleeting variants separately; they may share the same effect duration but use separate item IDs and stack limits.
- For buff food, update `EnhanceQoL/Modules/Food/BuffFoods.lua`.
  - Classify each item by tooltip stat, not only item name.
  - Do not add feast/banquet variants to the Buff Food Macro unless there is a deliberate feature decision to support placing feasts from the macro.
  - Keep Hearty variants above normal variants when both provide the same stat value because Hearty food persists through death.
  - Keep weaker PTR/event foods below stronger expansion foods by using lower `sortRank` values.

## Trinkets and auto durations

- Scan new PTR trinkets for Cooldown Panels auto-duration candidates.
- Use the existing Wowhead helper with the PTR trinket list and PTR tooltip environment:

```bash
python3 scripts/refresh_auto_duration_candidates_from_wowhead.py --discover --discover-url 'https://www.wowhead.com/ptr/items/armor/trinkets?filter=82;2;120100' --data-env 2 --output-json /tmp/eqol_ptr_trinket_auto_duration.json --output-markdown /tmp/eqol_ptr_trinket_auto_duration.md --output-lua /tmp/eqol_ptr_trinket_auto_duration.lua
```

- Review accepted and rejected rows before copying anything into runtime data.
- Add accepted fixed on-use durations to `EnhanceQoL/Modules/Aura/CooldownPanels_AutoDurations.lua`.
- Do not add rejected stack-based, charge-based, absorb-limited, target-only, damage-only, summon, or conditional trinkets unless manually verified and deliberately supported.
- Separately review `EnhanceQoL/Modules/Aura/CooldownPanels_ActiveProcTriggers.lua`.
  - The Wowhead auto-duration script does not currently generate ActiveProcTriggers.
  - ActiveProcTrigger entries need verified combat log or aura trigger spell IDs from the PTR client, not just item IDs or item-use spell IDs.
  - Candidate patterns include stack-building trinkets, delayed proc windows, post-use proc windows, or trinkets whose visible active duration starts from a separate effect spell.
  - For the 12.1 PTR trinket scan, manually verify candidates such as `Hex Lord's Dooming Idol`, `Voracious Heart of Ula'tek`, `Tattered Amani War Banner`, `Spirit Ward`, `First Mate's Shellward`, and similar rejected duration rows before adding runtime entries.

## Blizzard UI behavior changes

- Read PTR notes for features that make EnhanceQoL workarounds redundant.
- Track removals in a dedicated PTR cleanup doc before deleting code.
- For each candidate removal, record:
  - Blizzard PTR note
  - EnhanceQoL setting or feature name
  - code locations
  - removal reason
  - SavedVariables cleanup needed
  - release-client verification step
- Do not remove workaround code based only on PTR notes; verify on the release client before final cleanup.

## API and compatibility checks

- Check for removed or renamed globals and frame APIs on PTR.
- Prefer central compatibility helpers when multiple modules call the same changed API.
- Gate PTR-only logic by API availability or interface version when live clients still need the old path.
- Avoid changing valid non-secret UnitAura use unless PTR proves the call breaks or returns secrets in that context.

## Validation before staging

- Run syntax checks on changed Lua files:

```bash
luac -p EnhanceQoL/Modules/MythicPlus/Init.lua EnhanceQoL/Modules/Tooltip/Init.lua
```

- Run whitespace checks:

```bash
git diff --check -- EnhanceQoL/Modules/MythicPlus/Init.lua EnhanceQoL/Modules/Tooltip/Init.lua
```

- If broader Lua files changed, run the relevant `luac -p` checks for those files too.
- Before a beta or release tag with Lua changes, run project Luacheck.

## Release notes and cleanup

- Add a beta changelog entry when PTR compatibility or new-season support ships to testers.
- If Blizzard makes an EnhanceQoL feature obsolete, add DB cleanup to the release task list.
- Keep PTR-only investigation notes separate from user-facing release notes.
- For final release notes, summarize the outcome, not the intermediate PTR churn.
