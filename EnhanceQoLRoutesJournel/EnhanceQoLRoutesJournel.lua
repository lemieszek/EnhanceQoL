local parentAddonName = "EnhanceQoL"
local addonName = ...

local addon = _G[parentAddonName]
if not addon then error(parentAddonName .. " is not loaded") end

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local AceComm = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

local Routes = {}
addon.RoutesJournel = Routes

local PRESET_COMM_PREFIX = "MDTPreset"
local MINIMAP_BUTTON_NAME = "EnhanceQoLRoutesJournel"
local EXPORT_LEVEL = 5
local configForDeflate = {
	[1] = { level = 1 },
	[2] = { level = 2 },
	[3] = { level = 3 },
	[4] = { level = 4 },
	[5] = { level = 5 },
	[6] = { level = 6 },
	[7] = { level = 7 },
	[8] = { level = 8 },
	[9] = { level = 9 },
}

local byteToB64 = {
	[0] = "a",
	"b",
	"c",
	"d",
	"e",
	"f",
	"g",
	"h",
	"i",
	"j",
	"k",
	"l",
	"m",
	"n",
	"o",
	"p",
	"q",
	"r",
	"s",
	"t",
	"u",
	"v",
	"w",
	"x",
	"y",
	"z",
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"(",
	")",
}

local dungeonNames = {
	[2] = "Cathedral of Eternal Night",
	[3] = "Court of Stars",
	[4] = "Darkheart Thicket",
	[5] = "Eye of Azshara",
	[6] = "Halls of Valor",
	[7] = "Maw of Souls",
	[8] = "Neltharion's Lair",
	[9] = "Return to Karazhan Lower",
	[10] = "Return to Karazhan Upper",
	[11] = "Seat of the Triumvirate",
	[12] = "The Arcway",
	[13] = "Vault of the Wardens",
	[15] = "Atal'Dazar",
	[16] = "Freehold",
	[17] = "King's Rest",
	[18] = "Shrine of the Storm",
	[19] = "Siege of Boralus",
	[20] = "Temple of Sethraliss",
	[22] = "The Underrot",
	[23] = "Tol Dagor",
	[24] = "Waycrest Manor",
	[25] = "Mechagon - Junkyard",
	[29] = "De Other Side",
	[30] = "Halls of Atonement",
	[31] = "Mists of Tirna Scithe",
	[32] = "Plaguefall",
	[33] = "Sanguine Depths",
	[34] = "Spires of Ascension",
	[35] = "The Necrotic Wake",
	[37] = "Tazavesh: Streets of Wonder",
	[38] = "Tazavesh: So'leah's Gambit",
	[40] = "Grimrail Depot",
	[41] = "Iron Docks",
	[42] = "Ruby Life Pools",
	[43] = "The Nokhud Offensive",
	[44] = "The Azure Vault",
	[45] = "Algethar Academy",
	[46] = "Shadowmoon Burial Grounds",
	[47] = "Temple of the Jade Serpent",
	[48] = "Brackenhide Hollow",
	[49] = "Halls of Infusion",
	[50] = "Neltharus",
	[51] = "Uldaman",
	[77] = "The Vortex Pinnacle",
	[100] = "DOTI: Galakrond's Fall",
	[101] = "DOTI: Murozond's Rise",
	[102] = "Waycrest Manor",
	[103] = "Black Rook Hold",
	[104] = "The Everbloom",
	[105] = "Throne of Tides",
	[110] = "The Stonevault",
	[111] = "The Dawnbreaker",
	[112] = "Grim Batol",
	[113] = "Ara-Kara",
	[114] = "City of Threads",
	[115] = "Priory of the Sacred Flame",
	[116] = "Cinderbrew Meadery",
	[117] = "Darkflame Cleft",
	[118] = "The Rookery",
	[119] = "Operation: Floodgate",
	[120] = "The MOTHERLODE!!",
	[121] = "Theater of Pain",
	[122] = "Mechagon - Workshop",
	[123] = "Eco-Dome Al'dani",
	[130] = "Gate of the Setting Sun",
	[131] = "Mogu'shan Palace",
	[132] = "Scarlet Halls",
	[133] = "Scarlet Monastery",
	[134] = "Scholomance",
	[135] = "Shado-Pan Monastery",
	[136] = "Siege of Niuzao Temple",
	[137] = "Stormstout Brewery",
	[138] = "Temple of the Jade Serpent",
	[150] = "Pit of Saron",
	[151] = "Skyreach",
	[152] = "Windrunner Spire",
	[153] = "Magisters Terrace",
	[154] = "Maisara Caverns",
	[155] = "Nexus Point Xenas",
	[160] = "Murder Row",
}

local challengeMapIDs = {
	[11] = 239,
	[45] = 402,
	[130] = 962,
	[131] = 994,
	[132] = 1001,
	[133] = 1004,
	[134] = 1007,
	[135] = 959,
	[136] = 1011,
	[137] = 961,
	[138] = 960,
	[150] = 556,
	[151] = 161,
	[152] = 557,
	[153] = 558,
	[154] = 560,
	[155] = 559,
	[160] = 12345,
}

local challengeMapToDungeonIdx = {}
for dungeonIdx, challengeMapID in pairs(challengeMapIDs) do
	challengeMapToDungeonIdx[challengeMapID] = dungeonIdx
end

local routeOptionDefs = {
	{ key = "invisShroud", labelKey = "routesJournelOptionInvisShroud", fallback = "Invis/Shroud" },
	{ key = "warlock", labelKey = "routesJournelOptionWarlock", fallback = "Warlock" },
	{ key = "sleepwalk", labelKey = "routesJournelOptionSleepwalk", fallback = "Sleepwalk" },
}

local getDungeonDisplayName

local function getCurrentSeasonDungeons()
	local dungeons = {}
	if not C_ChallengeMode or not C_ChallengeMode.GetMapTable then return dungeons end
	for _, challengeMapID in ipairs(C_ChallengeMode.GetMapTable() or {}) do
		local dungeonIdx = challengeMapToDungeonIdx[challengeMapID]
		if dungeonIdx then dungeons[#dungeons + 1] = dungeonIdx end
	end
	table.sort(dungeons, function(left, right)
		local leftName = (getDungeonDisplayName(left) or ""):lower()
		local rightName = (getDungeonDisplayName(right) or ""):lower()
		if leftName == rightName then return left < right end
		return leftName < rightName
	end)
	return dungeons
end

local function getCurrentDungeonIdx()
	if C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
		local activeChallengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
		if activeChallengeMapID and challengeMapToDungeonIdx[activeChallengeMapID] then return challengeMapToDungeonIdx[activeChallengeMapID] end
	end

	if C_Map and C_Map.GetBestMapForUnit and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
		local currentMapID = C_Map.GetBestMapForUnit("player")
		if currentMapID then
			for dungeonIdx, challengeMapID in pairs(challengeMapIDs) do
				local _, _, _, _, _, mapID = C_ChallengeMode.GetMapUIInfo(challengeMapID)
				if mapID == currentMapID then return dungeonIdx end
			end
		end
	end

	return nil
end

local function trim(value)
	if type(value) ~= "string" then return "" end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyTable(value, seen)
	if type(value) ~= "table" then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local out = {}
	seen[value] = out
	for k, v in pairs(value) do
		out[copyTable(k, seen)] = copyTable(v, seen)
	end
	return out
end

local function tableToString(inTable, forChat)
	local serialized = Serializer:Serialize(inTable)
	local compressed = LibDeflate:CompressDeflate(serialized, configForDeflate[EXPORT_LEVEL])
	if forChat then return "!" .. LibDeflate:EncodeForPrint(compressed) end
	return "!" .. LibDeflate:EncodeForWoWAddonChannel(compressed)
end

local function stringToTable(inString, fromChat)
	local encoded, usesDeflate = trim(inString):gsub("^%!", "")
	if usesDeflate ~= 1 then return nil, L["routesJournelLegacyUnsupported"] or "Legacy MDT strings are not supported." end

	local decoded
	if fromChat then
		decoded = LibDeflate:DecodeForPrint(encoded)
	else
		decoded = LibDeflate:DecodeForWoWAddonChannel(encoded)
	end
	if not decoded then return nil, L["routesJournelDecodeError"] or "Could not decode MDT string." end

	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then return nil, L["routesJournelDecompressError"] or "Could not decompress MDT string." end

	local success, deserialized = Serializer:Deserialize(decompressed)
	if not success then return nil, L["routesJournelDeserializeError"] or "Could not read MDT data." end
	return deserialized
end

local function validatePreset(preset)
	if type(preset) ~= "table" then return false end
	if type(preset.text) ~= "string" or preset.text == "" then return false end
	if type(preset.value) ~= "table" then return false end
	if not preset.value.currentDungeonIdx then return false end
	if not preset.value.currentPull then return false end
	if not preset.value.currentSublevel then return false end
	if type(preset.value.pulls) ~= "table" then return false end
	return true
end

local function presetHasPullData(preset)
	if not validatePreset(preset) then return false end
	for _, pull in pairs(preset.value.pulls) do
		if type(pull) == "table" then
			for _, clones in pairs(pull) do
				if type(clones) == "table" then
					if next(clones) ~= nil then return true end
				elseif clones ~= nil then
					return true
				end
			end
		end
	end
	return false
end

local function getRoutes()
	addon.db = addon.db or {}
	addon.db.routesJournel = addon.db.routesJournel or {}
	return addon.db.routesJournel
end

local function getOptionsDB()
	addon.db = addon.db or {}
	addon.db.routesJournelOptions = addon.db.routesJournelOptions or {}
	if addon.db.routesJournelOptions.hideMinimapButton == nil then addon.db.routesJournelOptions.hideMinimapButton = false end
	addon.db.routesJournelMinimap = addon.db.routesJournelMinimap or {}
	addon.db.routesJournelMinimap.hide = addon.db.routesJournelOptions.hideMinimapButton
	return addon.db.routesJournelOptions
end

local function getRoutePreset(route)
	return route and route.preset
end

local function getRouteOptions(route)
	if not route then return {} end
	route.options = route.options or {}
	return route.options
end

local function getOptionLabel(option)
	return L[option.labelKey] or option.fallback
end

local function getRouteOptionText(route)
	local options = getRouteOptions(route)
	local labels = {}
	for _, option in ipairs(routeOptionDefs) do
		if options[option.key] then labels[#labels + 1] = getOptionLabel(option) end
	end
	return table.concat(labels, ", ")
end

local function getRouteDungeonIdx(route)
	local preset = getRoutePreset(route)
	return preset and preset.value and preset.value.currentDungeonIdx
end

local function getRouteDungeonName(route)
	return dungeonNames[getRouteDungeonIdx(route)] or (L["routesJournelUnknownDungeon"] or "Unknown MDT dungeon index.")
end

local function appendCanonicalValue(value, out, seen)
	local valueType = type(value)
	if valueType == "table" then
		seen = seen or {}
		if seen[value] then
			out[#out + 1] = "*cycle*"
			return
		end
		seen[value] = true
		local keys = {}
		for key in pairs(value) do
			keys[#keys + 1] = key
		end
		table.sort(keys, function(left, right)
			local leftType, rightType = type(left), type(right)
			if leftType ~= rightType then return leftType < rightType end
			return tostring(left) < tostring(right)
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			appendCanonicalValue(key, out, seen)
			out[#out + 1] = "="
			appendCanonicalValue(value[key], out, seen)
			out[#out + 1] = ";"
		end
		out[#out + 1] = "}"
		seen[value] = nil
	else
		out[#out + 1] = valueType
		out[#out + 1] = ":"
		out[#out + 1] = tostring(value)
	end
end

local function getPresetPullSignature(preset)
	if not validatePreset(preset) then return nil end
	local out = { "dungeon:", tostring(preset.value.currentDungeonIdx), ";pulls:" }
	appendCanonicalValue(preset.value.pulls, out)
	return table.concat(out)
end

local function findDuplicateRoute(preset)
	local signature = getPresetPullSignature(preset)
	if not signature then return nil end
	for index, route in ipairs(getRoutes()) do
		local routeSignature = route.pullSignature or getPresetPullSignature(getRoutePreset(route))
		if routeSignature == signature then return index, route end
	end
	return nil
end

getDungeonDisplayName = function(dungeonIdx)
	local challengeMapID = challengeMapIDs[dungeonIdx]
	if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and challengeMapID then
		local name = C_ChallengeMode.GetMapUIInfo(challengeMapID)
		if name then return name end
	end
	return dungeonNames[dungeonIdx] or tostring(dungeonIdx)
end

local function getDungeonArt(dungeonIdx)
	local challengeMapID = challengeMapIDs[dungeonIdx]
	if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and challengeMapID then
		local _, _, _, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(challengeMapID)
		if texture and texture ~= 0 then return texture end
		if backgroundTexture and backgroundTexture ~= 0 then return backgroundTexture end
	end
	return nil
end

local function getRouteSearchText(route)
	local preset = getRoutePreset(route)
	return table.concat({ route and route.name or "", route and route.comment or "", preset and preset.text or "", getRouteDungeonName(route), getRouteOptionText(route) }, " "):lower()
end

local function routeMatchesSearch(route, needle)
	if not needle or needle == "" then return true end
	return getRouteSearchText(route):find(needle, 1, true) ~= nil
end

local function routeMatchesOptionFilters(frame, route)
	if not frame or not frame.optionFilters then return true end
	local options = getRouteOptions(route)
	for _, option in ipairs(routeOptionDefs) do
		local filter = frame.optionFilters[option.key]
		if options[option.key] and filter and not filter:GetChecked() then return false end
	end
	return true
end

local function getRouteCounts()
	local counts = {}
	for _, route in ipairs(getRoutes()) do
		local dungeonIdx = getRouteDungeonIdx(route)
		counts[dungeonIdx] = (counts[dungeonIdx] or 0) + 1
	end
	return counts
end

local function getRouteCountForDungeon(dungeonIdx)
	if not dungeonIdx then return 0 end
	return getRouteCounts()[dungeonIdx] or 0
end

local function getSelectedRoute(frame)
	local index = frame and frame.selectedIndex
	local route = index and getRoutes()[index]
	return index, route
end

local function printMessage(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff98EnhanceQoL:|r " .. message)
end

local function getDistribution()
	return (UnitInRaid("player") and "RAID") or (IsInGroup() and "PARTY") or nil
end

local function sendMDTChatLink(args, bytesSent, bytesToSend)
	if bytesSent ~= bytesToSend then return end
	local distribution, dungeon, presetName = args[1], args[2], args[3]
	local name, realm = UnitFullName("player")
	if name then
		name = UnitFullName(name) or name
	end
	realm = realm or GetRealmName()
	C_ChatInfo.SendChatMessage("[MDT_v2: " .. name .. "+" .. realm .. " - " .. dungeon .. ": " .. presetName .. "]", distribution)
end

local function ensureUniqueId(preset)
	if preset.uid then return end
	local chars = {}
	for i = 1, 11 do
		chars[i] = byteToB64[math.random(0, 63)]
	end
	preset.uid = table.concat(chars)
end

local refreshRows
local refreshHome
local setStatus
local addPresetRoute

local function addRoute(name, importString, options)
	local preset, errorMessage = stringToTable(importString, true)
	if not preset then return false, errorMessage end
	if not validatePreset(preset) then return false, L["routesJournelInvalidPreset"] or "Invalid MDT route string." end

	return addPresetRoute(name, preset, options)
end

addPresetRoute = function(name, preset, options)
	name = trim(name)
	if name == "" then name = preset.text end
	if findDuplicateRoute(preset) then return false, L["routesJournelDuplicate"] or "This route is already saved." end
	preset.text = name
	ensureUniqueId(preset)

	local routes = getRoutes()
	routes[#routes + 1] = {
		name = name,
		comment = "",
		options = copyTable(options or {}),
		preset = preset,
		importString = tableToString(preset, true),
		pullSignature = getPresetPullSignature(preset),
	}
	return true
end

local function getMDT()
	return _G.MDT
end

local function getMDTDB()
	return _G.MythicDungeonToolsDB and _G.MythicDungeonToolsDB.global
end

local function getMDTDungeonFilter(frame)
	return frame and frame.activeDungeonIdx or getCurrentDungeonIdx()
end

local function getMDTPresetsForDungeon(dungeonIdx)
	local db = getMDTDB()
	local presets = db and dungeonIdx and db.presets and db.presets[dungeonIdx]
	local out = {}
	if type(presets) ~= "table" then return out end
	for presetIndex, preset in pairs(presets) do
		if presetHasPullData(preset) then
			out[#out + 1] = {
				index = presetIndex,
				preset = preset,
				duplicate = findDuplicateRoute(preset) ~= nil,
			}
		end
	end
	table.sort(out, function(left, right)
		local leftText = left.preset and left.preset.text or ""
		local rightText = right.preset and right.preset.text or ""
		leftText, rightText = leftText:lower(), rightText:lower()
		if leftText ~= rightText then return leftText < rightText end
		return (left.index or 0) < (right.index or 0)
	end)
	return out
end

local function finishMDTImport(frame, imported, skipped)
	refreshRows(frame)
	refreshHome(frame)
	if imported > 0 then
		setStatus(frame, string.format(L["routesJournelImportedFromMDTCount"] or "Imported %d MDT routes. Skipped %d duplicates.", imported, skipped), 0.2, 1, 0.2)
	elseif skipped > 0 then
		setStatus(frame, L["routesJournelDuplicate"] or "This route is already saved.", 1, 0.82, 0)
	else
		setStatus(frame, L["routesJournelMDTNoRoute"] or "MDT has no importable current route.", 1, 0.25, 0.25)
	end
end

local function importMDTPreset(frame, preset)
	if findDuplicateRoute(preset) then
		finishMDTImport(frame, 0, 1)
		return false
	end
	local ok, message = addPresetRoute(preset.text, copyTable(preset), {})
	if not ok then
		setStatus(frame, message or (L["routesJournelInvalidPreset"] or "Invalid MDT route string."), 1, 0.25, 0.25)
		return false
	end
	finishMDTImport(frame, 1, 0)
	return true
end

local function importMDTPresets(frame, entries)
	local imported, skipped = 0, 0
	for _, entry in ipairs(entries or {}) do
		local preset = entry.preset
		if findDuplicateRoute(preset) then
			skipped = skipped + 1
		else
			local ok = addPresetRoute(preset.text, copyTable(preset), {})
			if ok then
				imported = imported + 1
			else
				skipped = skipped + 1
			end
		end
	end
	finishMDTImport(frame, imported, skipped)
	return imported > 0
end

local function showMDTImportMenu(owner, frame)
	local dungeonIdx = getMDTDungeonFilter(frame)
	local entries = getMDTPresetsForDungeon(dungeonIdx)
	if #entries == 0 then
		setStatus(frame, L["routesJournelMDTNoRoutesForDungeon"] or "MDT has no importable routes for this dungeon.", 1, 0.25, 0.25)
		return
	end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			rootDescription:CreateButton(string.format(L["routesJournelImportAllFromMDT"] or "Import all (%d)", #entries), function()
				importMDTPresets(frame, entries)
			end)
			for _, entry in ipairs(entries) do
				rootDescription:CreateButton(entry.preset.text, function()
					importMDTPreset(frame, entry.preset)
				end)
			end
		end)
		return
	end
	importMDTPresets(frame, entries)
end

local function openRouteInMDT(frame, route)
	local mdt = getMDT()
	local preset = route and route.preset
	if not mdt or type(mdt.ImportPreset) ~= "function" then
		setStatus(frame, L["routesJournelMDTNotLoaded"] or "Mythic Dungeon Tools is not loaded.", 1, 0.25, 0.25)
		return false
	end
	if not validatePreset(preset) then
		setStatus(frame, L["routesJournelInvalidStoredRoute"] or "This saved route is invalid.", 1, 0.25, 0.25)
		return false
	end
	if type(mdt.ShowInterface) == "function" then mdt:ShowInterface(true) end
	mdt:ImportPreset(copyTable(preset))
	setStatus(frame, L["routesJournelOpenedInMDT"] or "Opened route in MDT.", 0.2, 1, 0.2)
	return true
end

local function refreshMinimapButton()
	getOptionsDB()
	if addon.db.routesJournelMinimap then addon.db.routesJournelMinimap.hide = addon.db.routesJournelOptions.hideMinimapButton end
	if not LDBIcon or not LDBIcon.Show or not LDBIcon.Hide then return end
	if addon.db.routesJournelOptions.hideMinimapButton then
		LDBIcon:Hide(MINIMAP_BUTTON_NAME)
	else
		LDBIcon:Show(MINIMAP_BUTTON_NAME)
	end
end

local function setMinimapButtonShown(shown)
	getOptionsDB()
	addon.db.routesJournelOptions.hideMinimapButton = not shown
	refreshMinimapButton()
end

local function initMinimapButton()
	if Routes.minimapInitialized then return end
	getOptionsDB()
	local broker = LDB:NewDataObject(MINIMAP_BUTTON_NAME, {
		type = "launcher",
		text = L["routesJournelTitle"] or "Routes Journel",
		icon = "Interface\\AddOns\\EnhanceQoL\\Icons\\Dungeon.tga",
		OnClick = function(_, button)
			if button == "RightButton" and Routes.frame and Routes.frame.gearButton then
				Routes.frame.gearButton:Click()
			else
				Routes:Toggle()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(L["routesJournelTitle"] or "Routes Journel")
			tooltip:AddLine(L["routesJournelMinimapTooltip"] or "Left-click to open routes. Right-click for options.", 1, 1, 1)
		end,
	})
	LDBIcon:Register(MINIMAP_BUTTON_NAME, broker, addon.db.routesJournelMinimap)
	Routes.minimapInitialized = true
	refreshMinimapButton()
end

local function showOptionsMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			rootDescription:CreateCheckbox(L["routesJournelShowMinimapButton"] or "Show Minimap Button", function()
				return not getOptionsDB().hideMinimapButton
			end, function()
				setMinimapButtonShown(getOptionsDB().hideMinimapButton)
			end)
		end)
		return
	end

	setMinimapButtonShown(getOptionsDB().hideMinimapButton)
end

local function deleteRoute(index)
	local routes = getRoutes()
	if routes[index] then table.remove(routes, index) end
end

local function confirmDeleteRoute(frame, index)
	if not index then return end
	StaticPopupDialogs.ENHANCEQOL_ROUTES_JOURNEL_DELETE = StaticPopupDialogs.ENHANCEQOL_ROUTES_JOURNEL_DELETE or {
		text = L["routesJournelDeleteConfirm"] or "Delete this route?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if not data or not data.frame or not data.index then return end
			deleteRoute(data.index)
			data.frame.selectedIndex = nil
			refreshRows(data.frame)
			setStatus(data.frame, L["routesJournelDeleted"] or "Route deleted.", 1, 0.82, 0)
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs.ENHANCEQOL_ROUTES_JOURNEL_DELETE.text = L["routesJournelDeleteConfirm"] or "Delete this route?"
	StaticPopup_Show("ENHANCEQOL_ROUTES_JOURNEL_DELETE", nil, nil, { frame = frame, index = index })
end

local function shareRoute(index)
	if InCombatLockdown and InCombatLockdown() then
		printMessage(L["routesJournelCombatBlocked"] or "Cannot share routes while in combat.")
		return false
	end

	local distribution = getDistribution()
	if not distribution then
		printMessage(L["routesJournelNoGroup"] or "You are not in a party or raid.")
		return false
	end

	local route = getRoutes()[index]
	local preset = route and route.preset
	if not validatePreset(preset) then
		printMessage(L["routesJournelInvalidStoredRoute"] or "This saved route is invalid.")
		return false
	end

	preset = copyTable(preset)
	preset.text = route.name or preset.text
	ensureUniqueId(preset)

	local dungeon = dungeonNames[preset.value.currentDungeonIdx]
	if not dungeon then
		printMessage(L["routesJournelUnknownDungeon"] or "Unknown MDT dungeon index.")
		return false
	end

	local export = tableToString(preset, false)
	AceComm:SendCommMessage(PRESET_COMM_PREFIX, export, distribution, nil, "BULK", sendMDTChatLink, { distribution, dungeon, preset.text })
	return true
end

local function createButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 90, 22)
	button:SetText(text)
	return button
end

local function createIconButton(parent, texture)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(22, 22)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints(button)
	button.icon:SetTexture(texture)
	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints(button)
	button.highlight:SetColorTexture(1, 1, 1, 0.14)
	return button
end

local function createPanel(parent)
	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel.bg = panel:CreateTexture(nil, "BACKGROUND")
	panel.bg:SetAllPoints(panel)
	panel.bg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
	panel.bg:SetAlpha(0.85)
	panel:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	panel:SetBackdropBorderColor(0.75, 0.65, 0.4, 0.85)
	return panel
end

local function createLabel(parent, text, template)
	local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
	label:SetText(text or "")
	label:SetJustifyH("LEFT")
	return label
end

local function createSearchBox(parent)
	local box = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
	box:SetAutoFocus(false)
	box:SetHeight(22)
	return box
end

local function createCheckButton(parent, text)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check.Text:SetText(text)
	return check
end

local function collectOptionChecks(checks, uncheckedAsFalse)
	local options = {}
	if not checks then return options end
	for _, option in ipairs(routeOptionDefs) do
		if checks[option.key] and checks[option.key]:GetChecked() then
			options[option.key] = true
		elseif uncheckedAsFalse then
			options[option.key] = false
		end
	end
	return options
end

local function setOptionChecks(checks, options, defaultValue)
	if not checks then return end
	options = options or {}
	for _, option in ipairs(routeOptionDefs) do
		if checks[option.key] then checks[option.key]:SetChecked(options[option.key] ~= nil and options[option.key] or defaultValue) end
	end
end

setStatus = function(frame, text, r, g, b)
	frame.status:SetText(text or "")
	frame.status:SetTextColor(r or 1, g or 0.82, b or 0)
end

local function setButtonEnabled(button, enabled)
	if not button then return end
	if enabled then
		button:Enable()
	else
		button:Disable()
	end
end

local function updateMDTImportButton(frame)
	if not frame or not frame.importFromMDT then return end
	local hasPresets = #getMDTPresetsForDungeon(getMDTDungeonFilter(frame)) > 0
	frame.importFromMDT:SetShown(hasPresets)
end

local function setImportShown(frame, shown)
	if not frame or not frame.importPanel then return end
	local hasRoute = frame.selectedIndex ~= nil and getRoutes()[frame.selectedIndex] ~= nil
	if shown then setOptionChecks(frame.importOptions, nil, false) end
	frame.importPanel:SetShown(shown)
	frame.detailsContent:SetShown(not shown and hasRoute)
	frame.detailsEmpty:SetShown(not shown and not hasRoute)
	setButtonEnabled(frame.share, not shown and hasRoute)
	setButtonEnabled(frame.openInMDT, not shown and hasRoute)
	setButtonEnabled(frame.delete, not shown and hasRoute)
	setButtonEnabled(frame.saveDetails, not shown and hasRoute)
end

local function setSelectedRoute(frame, index)
	frame.selectedIndex = index
	if frame.rows then
		for _, row in ipairs(frame.rows) do
			if row.bg then row.bg:SetColorTexture(0.1, 0.6, 0.6, row.index == index and 0.35 or 0) end
		end
	end

	local _, route = getSelectedRoute(frame)
	local preset = getRoutePreset(route)
	local hasRoute = route ~= nil
	local importShown = frame.importPanel and frame.importPanel:IsShown()
	frame.detailsEmpty:SetShown(not importShown and not hasRoute)
	frame.detailsContent:SetShown(not importShown and hasRoute)
	setButtonEnabled(frame.share, not importShown and hasRoute)
	setButtonEnabled(frame.openInMDT, not importShown and hasRoute)
	setButtonEnabled(frame.delete, not importShown and hasRoute)
	setButtonEnabled(frame.saveDetails, not importShown and hasRoute)
	if not hasRoute then return end

	frame.detailTitle:SetText(route.name or preset.text or (L["routesJournelUnnamed"] or "Unnamed route"))
	frame.detailDungeon:SetText(getRouteDungeonName(route))
	frame.detailPulls:SetText(string.format(L["routesJournelPullCount"] or "%d pulls", type(preset.value.pulls) == "table" and #preset.value.pulls or 0))
	frame.detailName:SetText(route.name or preset.text or "")
	frame.detailComment:SetText(route.comment or "")
	setOptionChecks(frame.detailOptions, getRouteOptions(route), false)
end

local function saveSelectedDetails(frame)
	local _, route = getSelectedRoute(frame)
	if not route then return false end
	local name = trim(frame.detailName:GetText())
	if name == "" then name = route.name or (getRoutePreset(route) and getRoutePreset(route).text) or (L["routesJournelUnnamed"] or "Unnamed route") end
	route.name = name
	route.comment = trim(frame.detailComment:GetText())
	route.options = collectOptionChecks(frame.detailOptions)
	if route.preset then
		route.preset.text = name
		route.importString = tableToString(route.preset, true)
	end
	return true
end

local function getActiveDungeonFilter(frame)
	return frame and frame.activeDungeonIdx
end

local function setActiveDungeonFilter(frame, dungeonIdx)
	frame.activeDungeonIdx = dungeonIdx
	frame.selectedIndex = nil
	refreshRows(frame)
end

local refreshCategories
local rebuildHomeTiles
local showJournal

refreshRows = function(frame)
	if not frame.rows then frame.rows = {} end
	for _, row in ipairs(frame.rows) do
		row:Hide()
	end

	local routes = getRoutes()
	local dungeonFilter = getActiveDungeonFilter(frame)
	local needle = frame.search and trim(frame.search:GetText()):lower() or ""
	local previous
	local shown = 0
	for index, route in ipairs(routes) do
		if (not dungeonFilter or getRouteDungeonIdx(route) == dungeonFilter) and routeMatchesSearch(route, needle) and routeMatchesOptionFilters(frame, route) then
			shown = shown + 1
			local row = frame.rows[shown]
			if not row then
				row = CreateFrame("Button", nil, frame.listContent)
				row:SetSize(1, 34)
				row:RegisterForClicks("LeftButtonUp")
				row.bg = row:CreateTexture(nil, "BACKGROUND")
				row.bg:SetAllPoints(row)
				row.bg:SetColorTexture(0.1, 0.6, 0.6, 0)
				row.hl = row:CreateTexture(nil, "HIGHLIGHT")
				row.hl:SetAllPoints(row)
				row.hl:SetColorTexture(1, 1, 1, 0.08)

				row.name = createLabel(row, nil, "GameFontNormal")
				row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
				row.name:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				row.name:SetJustifyH("LEFT")

				row.meta = createLabel(row, nil, "GameFontDisableSmall")
				row.meta:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
				row.meta:SetPoint("RIGHT", row, "RIGHT", -8, 0)

				frame.rows[shown] = row
			end

			row.index = index
			row.name:SetText(route.name or (L["routesJournelUnnamed"] or "Unnamed route"))
			local optionText = getRouteOptionText(route)
			row.meta:SetText(optionText ~= "" and (getRouteDungeonName(route) .. " - " .. optionText) or getRouteDungeonName(route))
			row:SetScript("OnClick", function()
				setSelectedRoute(frame, index)
			end)

			row:ClearAllPoints()
			if previous then
				row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -3)
				row:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -3)
			else
				row:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", 0, 0)
				row:SetPoint("TOPRIGHT", frame.listContent, "TOPRIGHT", 0, 0)
			end
			row:Show()
			row.bg:SetColorTexture(0.1, 0.6, 0.6, frame.selectedIndex == index and 0.35 or 0)
			previous = row
		end
	end

	frame.empty:SetShown(shown == 0)
	frame.listContent:SetHeight(math.max(1, shown * 37))
	if frame.selectedIndex and (not routes[frame.selectedIndex] or (dungeonFilter and getRouteDungeonIdx(routes[frame.selectedIndex]) ~= dungeonFilter) or not routeMatchesSearch(routes[frame.selectedIndex], needle) or not routeMatchesOptionFilters(frame, routes[frame.selectedIndex])) then
		setSelectedRoute(frame, nil)
	elseif not frame.selectedIndex and shown > 0 then
		for index, route in ipairs(routes) do
			if (not dungeonFilter or getRouteDungeonIdx(route) == dungeonFilter) and routeMatchesSearch(route, needle) and routeMatchesOptionFilters(frame, route) then
				setSelectedRoute(frame, index)
				break
			end
		end
	else
		setSelectedRoute(frame, frame.selectedIndex)
	end
	if refreshCategories then refreshCategories(frame) end
	updateMDTImportButton(frame)
end

refreshCategories = function(frame)
	if not frame.categoryRows then frame.categoryRows = {} end
	for _, row in ipairs(frame.categoryRows) do
		row:Hide()
	end

	local counts = getRouteCounts()
	local rowIndex = 0
	local function acquireRow()
		rowIndex = rowIndex + 1
		local row = frame.categoryRows[rowIndex]
		if not row then
			row = CreateFrame("Button", nil, frame.categoryContent)
			row:SetHeight(24)
			row:RegisterForClicks("LeftButtonUp")
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints(row)
			row.bg:SetColorTexture(0, 0, 0, 0)
			row.hl = row:CreateTexture(nil, "HIGHLIGHT")
			row.hl:SetAllPoints(row)
			row.hl:SetColorTexture(1, 1, 1, 0.08)
			row.text = createLabel(row, nil, "GameFontNormalSmall")
			row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
			row.count = createLabel(row, nil, "GameFontDisableSmall")
			row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
			frame.categoryRows[rowIndex] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", frame.categoryContent, "TOPLEFT", 0, -((rowIndex - 1) * 26))
		row:SetPoint("TOPRIGHT", frame.categoryContent, "TOPRIGHT", 0, -((rowIndex - 1) * 26))
		row:Show()
		return row
	end

	local total = #getRoutes()
	local allRow = acquireRow()
	allRow.text:SetText(ALL or "All")
	allRow.count:SetText(tostring(total))
	allRow.bg:SetColorTexture(0.1, 0.6, 0.6, frame.activeDungeonIdx == nil and 0.35 or 0)
	allRow:SetScript("OnClick", function() setActiveDungeonFilter(frame, nil) end)

	local header = acquireRow()
	header.text:SetText(L["routesJournelSeasonOverview"] or "Season Overview")
	header.text:SetTextColor(1, 0.9, 0.6, 1)
	header.count:SetText("")
	header.bg:SetColorTexture(0, 0, 0, 0.28)
	header:SetScript("OnClick", nil)
	for _, dungeonIdx in ipairs(getCurrentSeasonDungeons()) do
		local count = counts[dungeonIdx] or 0
		local row = acquireRow()
		row.text:SetText("  " .. getDungeonDisplayName(dungeonIdx))
		row.text:SetTextColor(count > 0 and 1 or 0.55, count > 0 and 1 or 0.55, count > 0 and 1 or 0.55, 1)
		row.count:SetText(tostring(count))
		row.bg:SetColorTexture(0.1, 0.6, 0.6, frame.activeDungeonIdx == dungeonIdx and 0.35 or 0)
		row:SetScript("OnClick", function() setActiveDungeonFilter(frame, dungeonIdx) end)
	end
	frame.categoryContent:SetHeight(math.max(1, rowIndex * 26))
end

refreshHome = function(frame)
	if not frame or not frame.homeTiles then return end
	local counts = getRouteCounts()
	for _, tile in ipairs(frame.homeTiles) do
		local count = counts[tile.dungeonIdx] or 0
		tile.count:SetText((L["routesJournelSavedRoutes"] or "Saved routes") .. ": " .. count)
	end
end

rebuildHomeTiles = function(frame)
	if not frame or not frame.home then return end
	frame.homeTiles = frame.homeTiles or {}
	for _, tile in ipairs(frame.homeTiles) do
		tile:Hide()
	end

	local previousTile
	for index, dungeonIdx in ipairs(getCurrentSeasonDungeons()) do
		local tile = frame.homeTiles[index]
		if not tile then
			tile = CreateFrame("Button", nil, frame.home, "BackdropTemplate")
			tile:SetSize(205, 178)
			tile:RegisterForClicks("LeftButtonUp")
			tile:SetBackdrop({
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				edgeSize = 12,
				insets = { left = 2, right = 2, top = 2, bottom = 2 },
			})
			tile:SetBackdropBorderColor(0.75, 0.65, 0.4, 0.85)

			tile.art = tile:CreateTexture(nil, "BACKGROUND")
			tile.art:SetAllPoints(tile)
			tile.art:SetTexCoord(0.02, 0.98, 0.02, 0.98)

			tile.shade = tile:CreateTexture(nil, "BORDER")
			tile.shade:SetAllPoints(tile)
			tile.shade:SetColorTexture(0, 0, 0, 0.18)

			tile.textShade = tile:CreateTexture(nil, "ARTWORK")
			tile.textShade:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 0)
			tile.textShade:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 0, 0)
			tile.textShade:SetHeight(56)
			tile.textShade:SetColorTexture(0, 0, 0, 0.42)

			tile.hl = tile:CreateTexture(nil, "HIGHLIGHT")
			tile.hl:SetAllPoints(tile)
			tile.hl:SetColorTexture(1, 1, 1, 0.12)

			tile.name = createLabel(tile, nil, "GameFontHighlightLarge")
			tile.name:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 12, 28)
			tile.name:SetPoint("RIGHT", tile, "RIGHT", -12, 0)
			tile.name:SetJustifyH("LEFT")

			tile.count = createLabel(tile, "", "GameFontNormalSmall")
			tile.count:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -3)
			tile.count:SetPoint("RIGHT", tile, "RIGHT", -12, 0)
			frame.homeTiles[index] = tile
		end

		tile.dungeonIdx = dungeonIdx
		tile.name:SetText(getDungeonDisplayName(dungeonIdx))
		tile.art:SetTexture(getDungeonArt(dungeonIdx) or "Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
		tile:SetScript("OnClick", function()
			showJournal(frame, dungeonIdx)
		end)
		tile:ClearAllPoints()
		if index == 1 then
			tile:SetPoint("TOPLEFT", frame.homeSubtitle, "BOTTOMLEFT", 0, -14)
		elseif index == 5 then
			tile:SetPoint("TOPLEFT", frame.homeTiles[1], "BOTTOMLEFT", 0, -14)
		else
			tile:SetPoint("LEFT", previousTile, "RIGHT", 12, 0)
		end
		tile:Show()
		previousTile = tile
	end
	refreshHome(frame)
end

local function setJournalShown(frame, shown)
	frame.home:SetShown(not shown)
	frame.left:SetShown(shown)
	frame.middle:SetShown(shown)
	frame.right:SetShown(shown)
	frame.homeButton:SetShown(shown)
end

showJournal = function(frame, dungeonIdx)
	setJournalShown(frame, true)
	setActiveDungeonFilter(frame, dungeonIdx)
end

local function showHome(frame)
	frame.activeDungeonIdx = nil
	frame.selectedIndex = nil
	setJournalShown(frame, false)
	setSelectedRoute(frame, nil)
	rebuildHomeTiles(frame)
	setStatus(frame, "")
end

local function createFrame()
	local frame = CreateFrame("Frame", "EnhanceQoLRoutesJournelFrame", UIParent, "BackdropTemplate")
	frame:SetSize(920, 560)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})

	frame.title = createLabel(frame, L["routesJournelTitle"] or "Routes Journel", "GameFontHighlightLarge")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -18)

	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

	frame.homeButton = createButton(frame, L["routesJournelSeasonOverview"] or "Season Overview", 128)
	frame.homeButton:SetPoint("RIGHT", frame.close, "LEFT", -8, 1)
	frame.homeButton:SetScript("OnClick", function()
		showHome(frame)
	end)

	frame.home = CreateFrame("Frame", nil, frame)
	frame.home:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
	frame.home:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)

	frame.homeBg = frame.home:CreateTexture(nil, "BACKGROUND")
	frame.homeBg:SetAllPoints(frame.home)
	frame.homeBg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
	frame.homeBg:SetAlpha(0.7)

	frame.homeTitle = createLabel(frame.home, L["routesJournelSeasonOverview"] or "Season Overview", "GameFontHighlightHuge")
	frame.homeTitle:SetPoint("TOPLEFT", frame.home, "TOPLEFT", 12, -8)

	frame.homeSubtitle = createLabel(frame.home, L["routesJournelDungeons"] or "Dungeons", "GameFontNormal")
	frame.homeSubtitle:SetPoint("TOPLEFT", frame.homeTitle, "BOTTOMLEFT", 1, -4)

	frame.homeTiles = {}

	frame.left = createPanel(frame)
	frame.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -48)
	frame.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
	frame.left:SetWidth(230)

	frame.middle = createPanel(frame)
	frame.middle:SetPoint("TOPLEFT", frame.left, "TOPRIGHT", 12, 0)
	frame.middle:SetPoint("BOTTOMLEFT", frame.left, "BOTTOMRIGHT", 12, 0)
	frame.middle:SetWidth(330)

	frame.right = createPanel(frame)
	frame.right:SetPoint("TOPLEFT", frame.middle, "TOPRIGHT", 12, 0)
	frame.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)

	local categoryTitle = createLabel(frame.left, L["routesJournelDungeons"] or "Dungeons", "GameFontNormal")
	categoryTitle:SetPoint("TOPLEFT", frame.left, "TOPLEFT", 12, -12)

	frame.categoryScroll = CreateFrame("ScrollFrame", nil, frame.left, "UIPanelScrollFrameTemplate")
	frame.categoryScroll:SetPoint("TOPLEFT", categoryTitle, "BOTTOMLEFT", 0, -8)
	frame.categoryScroll:SetPoint("BOTTOMRIGHT", frame.left, "BOTTOMRIGHT", -26, 12)
	frame.categoryContent = CreateFrame("Frame", nil, frame.categoryScroll)
	frame.categoryContent:SetSize(1, 1)
	frame.categoryScroll:SetScrollChild(frame.categoryContent)
	frame.categoryScroll:SetScript("OnSizeChanged", function(self) frame.categoryContent:SetWidth(self:GetWidth() or 1) end)

	frame.search = createSearchBox(frame.middle)
	frame.search:SetPoint("TOPLEFT", frame.middle, "TOPLEFT", 12, -12)
	frame.search:SetPoint("TOPRIGHT", frame.middle, "TOPRIGHT", -42, -12)
	frame.search:SetScript("OnTextChanged", function()
		refreshRows(frame)
	end)

	frame.gearButton = createIconButton(frame.middle, "Interface\\Buttons\\UI-OptionsButton")
	frame.gearButton:SetPoint("LEFT", frame.search, "RIGHT", 8, 0)
	frame.gearButton:SetScript("OnClick", function(self)
		showOptionsMenu(self)
	end)

	frame.filterLabel = createLabel(frame.middle, L["routesJournelFilters"] or "Filters", "GameFontNormalSmall")
	frame.filterLabel:SetPoint("TOPLEFT", frame.search, "BOTTOMLEFT", 0, -7)

	frame.optionFilters = {}
	local previousFilter
	for index, option in ipairs(routeOptionDefs) do
		local check = createCheckButton(frame.middle, getOptionLabel(option))
		check:SetChecked(true)
		check:SetScript("OnClick", function()
			refreshRows(frame)
		end)
		if index == 1 then
			check:SetPoint("TOPLEFT", frame.filterLabel, "BOTTOMLEFT", -4, -1)
		else
			check:SetPoint("LEFT", previousFilter.Text, "RIGHT", 18, 0)
		end
		frame.optionFilters[option.key] = check
		previousFilter = check
	end

	frame.add = createButton(frame.middle, L["routesJournelNew"] or "New Route", 100)
	frame.add:SetPoint("TOPLEFT", frame.optionFilters[routeOptionDefs[1].key], "BOTTOMLEFT", 4, -7)
	frame.add:SetScript("OnClick", function()
		setImportShown(frame, not frame.importPanel:IsShown())
	end)

	frame.importFromMDT = createButton(frame.middle, L["routesJournelImportFromMDT"] or "Import from MDT", 128)
	frame.importFromMDT:SetPoint("LEFT", frame.add, "RIGHT", 8, 0)
	frame.importFromMDT:SetScript("OnClick", function(self)
		showMDTImportMenu(self, frame)
	end)

	frame.listScroll = CreateFrame("ScrollFrame", nil, frame.middle, "UIPanelScrollFrameTemplate")
	frame.listScroll:SetPoint("TOPLEFT", frame.add, "BOTTOMLEFT", 0, -10)
	frame.listScroll:SetPoint("BOTTOMRIGHT", frame.middle, "BOTTOMRIGHT", -26, 12)
	frame.listContent = CreateFrame("Frame", nil, frame.listScroll)
	frame.listContent:SetSize(1, 1)
	frame.listScroll:SetScrollChild(frame.listContent)
	frame.listScroll:SetScript("OnSizeChanged", function(self) frame.listContent:SetWidth(self:GetWidth() or 1) end)

	frame.empty = createLabel(frame.listContent, L["routesJournelEmpty"] or "No saved routes.", "GameFontDisable")
	frame.empty:SetPoint("TOPLEFT", frame.listContent, "TOPLEFT", 8, -8)

	frame.importPanel = createPanel(frame.right)
	frame.importPanel:SetPoint("TOPLEFT", frame.right, "TOPLEFT", 12, -12)
	frame.importPanel:SetPoint("TOPRIGHT", frame.right, "TOPRIGHT", -12, -12)
	frame.importPanel:SetHeight(220)
	frame.importPanel:Hide()

	local importTitle = createLabel(frame.importPanel, L["routesJournelNew"] or "New Route", "GameFontNormal")
	importTitle:SetPoint("TOPLEFT", frame.importPanel, "TOPLEFT", 10, -8)
	frame.nameBox = CreateFrame("EditBox", nil, frame.importPanel, "InputBoxTemplate")
	frame.nameBox:SetSize(200, 22)
	frame.nameBox:SetPoint("TOPLEFT", importTitle, "BOTTOMLEFT", 2, -6)
	frame.nameBox:SetAutoFocus(false)
	frame.nameBox:SetText("")

	local importOptionsLabel = createLabel(frame.importPanel, L["routesJournelOptionalRequirements"] or "Optional requirements", "GameFontNormalSmall")
	importOptionsLabel:SetPoint("TOPLEFT", frame.nameBox, "BOTTOMLEFT", -2, -8)
	frame.importOptions = {}
	local previousImportOption
	for index, option in ipairs(routeOptionDefs) do
		local check = createCheckButton(frame.importPanel, getOptionLabel(option))
		if index == 1 then
			check:SetPoint("TOPLEFT", importOptionsLabel, "BOTTOMLEFT", -4, -1)
		else
			check:SetPoint("LEFT", previousImportOption.Text, "RIGHT", 18, 0)
		end
		frame.importOptions[option.key] = check
		previousImportOption = check
	end

	frame.stringScroll = CreateFrame("ScrollFrame", nil, frame.importPanel, "UIPanelScrollFrameTemplate")
	frame.stringScroll:SetPoint("TOPLEFT", frame.importOptions[routeOptionDefs[1].key], "BOTTOMLEFT", 4, -6)
	frame.stringScroll:SetPoint("BOTTOMRIGHT", frame.importPanel, "BOTTOMRIGHT", -28, 34)
	frame.stringBox = CreateFrame("EditBox", nil, frame.stringScroll)
	frame.stringBox:SetMultiLine(true)
	frame.stringBox:SetAutoFocus(false)
	frame.stringBox:SetFontObject(ChatFontNormal)
	frame.stringBox:SetSize(1, 80)
	frame.stringBox:SetTextInsets(4, 4, 4, 4)
	frame.stringScroll:SetScrollChild(frame.stringBox)
	frame.stringScroll:SetScript("OnSizeChanged", function(self) frame.stringBox:SetWidth(self:GetWidth() or 1) end)

	local saveImport = createButton(frame.importPanel, L["routesJournelSave"] or "Save Route", 110)
	saveImport:SetPoint("BOTTOMLEFT", frame.importPanel, "BOTTOMLEFT", 10, 8)
	saveImport:SetScript("OnClick", function()
		local ok, message = addRoute(frame.nameBox:GetText(), frame.stringBox:GetText(), collectOptionChecks(frame.importOptions))
		if ok then
			frame.nameBox:SetText("")
			frame.stringBox:SetText("")
			setOptionChecks(frame.importOptions, nil, false)
			setImportShown(frame, false)
			refreshRows(frame)
			refreshHome(frame)
			setStatus(frame, L["routesJournelSaved"] or "Route saved.", 0.2, 1, 0.2)
		else
			setStatus(frame, message or (L["routesJournelInvalidPreset"] or "Invalid MDT route string."), 1, 0.25, 0.25)
		end
	end)

	local cancelImport = createButton(frame.importPanel, CANCEL or "Cancel", 82)
	cancelImport:SetPoint("LEFT", saveImport, "RIGHT", 8, 0)
	cancelImport:SetScript("OnClick", function()
		frame.nameBox:SetText("")
		frame.stringBox:SetText("")
		setOptionChecks(frame.importOptions, nil, false)
		setImportShown(frame, false)
		setStatus(frame, "")
	end)

	frame.detailsContent = CreateFrame("Frame", nil, frame.right)
	frame.detailsContent:SetPoint("TOPLEFT", frame.right, "TOPLEFT", 14, -14)
	frame.detailsContent:SetPoint("BOTTOMRIGHT", frame.right, "BOTTOMRIGHT", -14, 84)

	frame.detailsEmpty = createLabel(frame.right, L["routesJournelSelectRoute"] or "Select a route.", "GameFontDisable")
	frame.detailsEmpty:SetPoint("CENTER", frame.right, "CENTER")

	frame.detailTitle = createLabel(frame.detailsContent, "", "GameFontHighlightLarge")
	frame.detailTitle:SetPoint("TOPLEFT", frame.detailsContent, "TOPLEFT", 0, 0)
	frame.detailTitle:SetPoint("RIGHT", frame.detailsContent, "RIGHT", 0, 0)

	frame.detailDungeon = createLabel(frame.detailsContent, "", "GameFontNormal")
	frame.detailDungeon:SetPoint("TOPLEFT", frame.detailTitle, "BOTTOMLEFT", 0, -8)

	frame.detailPulls = createLabel(frame.detailsContent, "", "GameFontDisableSmall")
	frame.detailPulls:SetPoint("LEFT", frame.detailDungeon, "RIGHT", 12, 0)

	local nameLabel = createLabel(frame.detailsContent, L["routesJournelNameLabel"] or "Route name", "GameFontNormalSmall")
	nameLabel:SetPoint("TOPLEFT", frame.detailDungeon, "BOTTOMLEFT", 0, -18)
	frame.detailName = CreateFrame("EditBox", nil, frame.detailsContent, "InputBoxTemplate")
	frame.detailName:SetSize(250, 22)
	frame.detailName:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 2, -4)
	frame.detailName:SetAutoFocus(false)

	local detailOptionsLabel = createLabel(frame.detailsContent, L["routesJournelOptionalRequirements"] or "Optional requirements", "GameFontNormalSmall")
	detailOptionsLabel:SetPoint("TOPLEFT", frame.detailName, "BOTTOMLEFT", -2, -14)
	frame.detailOptions = {}
	local previousDetailOption
	for index, option in ipairs(routeOptionDefs) do
		local check = createCheckButton(frame.detailsContent, getOptionLabel(option))
		if index == 1 then
			check:SetPoint("TOPLEFT", detailOptionsLabel, "BOTTOMLEFT", -4, -1)
		else
			check:SetPoint("LEFT", previousDetailOption.Text, "RIGHT", 18, 0)
		end
		frame.detailOptions[option.key] = check
		previousDetailOption = check
	end

	local commentLabel = createLabel(frame.detailsContent, L["routesJournelCommentLabel"] or "Comment", "GameFontNormalSmall")
	commentLabel:SetPoint("TOPLEFT", frame.detailOptions[routeOptionDefs[1].key], "BOTTOMLEFT", 4, -8)
	frame.commentScroll = CreateFrame("ScrollFrame", nil, frame.detailsContent, "UIPanelScrollFrameTemplate")
	frame.commentScroll:SetPoint("TOPLEFT", commentLabel, "BOTTOMLEFT", 0, -5)
	frame.commentScroll:SetPoint("RIGHT", frame.detailsContent, "RIGHT", -26, 0)
	frame.commentScroll:SetPoint("BOTTOM", frame.detailsContent, "BOTTOM", 0, 6)
	frame.commentScroll:EnableMouse(true)
	frame.detailComment = CreateFrame("EditBox", nil, frame.commentScroll)
	frame.detailComment:SetMultiLine(true)
	frame.detailComment:SetAutoFocus(false)
	frame.detailComment:EnableMouse(true)
	frame.detailComment:SetFontObject(ChatFontNormal)
	frame.detailComment:SetSize(1, 1)
	frame.detailComment:SetTextInsets(4, 4, 4, 4)
	frame.commentScroll:SetScrollChild(frame.detailComment)
	frame.commentScroll:SetScript("OnSizeChanged", function(self)
		frame.detailComment:SetSize(self:GetWidth() or 1, self:GetHeight() or 1)
	end)
	frame.commentScroll:SetScript("OnMouseDown", function()
		frame.detailComment:SetFocus()
	end)
	frame.detailComment:SetScript("OnMouseDown", function(self)
		self:SetFocus()
	end)

	frame.status = createLabel(frame.right, "", "GameFontHighlightSmall")
	frame.status:SetPoint("BOTTOMLEFT", frame.right, "BOTTOMLEFT", 14, 60)
	frame.status:SetPoint("RIGHT", frame.right, "RIGHT", -14, 0)

	frame.saveDetails = createButton(frame.right, SAVE or "Save", 82)
	frame.saveDetails:SetPoint("BOTTOMLEFT", frame.right, "BOTTOMLEFT", 14, 32)
	frame.saveDetails:SetScript("OnClick", function()
		if saveSelectedDetails(frame) then
			refreshRows(frame)
			setStatus(frame, L["routesJournelSaved"] or "Route saved.", 0.2, 1, 0.2)
		end
	end)

	frame.share = createButton(frame.right, L["routesJournelShare"] or "Share", 82)
	frame.share:SetPoint("LEFT", frame.saveDetails, "RIGHT", 8, 0)
	frame.share:SetScript("OnClick", function()
		saveSelectedDetails(frame)
		local index = frame.selectedIndex
		if index and shareRoute(index) then setStatus(frame, L["routesJournelShared"] or "Route shared.", 0.2, 1, 0.2) end
	end)

	frame.openInMDT = createButton(frame.right, _G.OPEN or "Open", 72)
	frame.openInMDT:SetPoint("BOTTOMLEFT", frame.right, "BOTTOMLEFT", 14, 8)
	frame.openInMDT:SetScript("OnClick", function()
		local _, route = getSelectedRoute(frame)
		openRouteInMDT(frame, route)
	end)

	frame.delete = createButton(frame.right, DELETE or "Delete", 72)
	frame.delete:SetPoint("LEFT", frame.openInMDT, "RIGHT", 8, 0)
	frame.delete:SetScript("OnClick", function()
		confirmDeleteRoute(frame, frame.selectedIndex)
	end)

	frame:Hide()
	return frame
end

function Routes:Open()
	if not self.frame then self.frame = createFrame() end
	local dungeonIdx = getCurrentDungeonIdx()
	if dungeonIdx then
		showJournal(self.frame, dungeonIdx)
	else
		showHome(self.frame)
	end
	self.frame:Show()
end

function Routes:Toggle()
	if self.frame and self.frame:IsShown() then
		self.frame:Hide()
	else
		self:Open()
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "ADDON_LOADED" then
		if loadedAddon ~= addonName then return end
		getRoutes()
		getOptionsDB()
		initMinimapButton()
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PRESET_COMM_PREFIX) end
		SLASH_ENHANCEQOLROUTESJOURNEL1 = "/routesjournel"
		SLASH_ENHANCEQOLROUTESJOURNEL2 = "/eqolroutes"
		SlashCmdList["ENHANCEQOLROUTESJOURNEL"] = function()
			Routes:Toggle()
		end
		eventFrame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
		eventFrame:UnregisterEvent("ADDON_LOADED")
	elseif event == "CHALLENGE_MODE_MAPS_UPDATE" and Routes.frame then
		rebuildHomeTiles(Routes.frame)
		refreshRows(Routes.frame)
	end
end)
