-- luacheck: globals C_DamageMeter C_DeathRecap C_LFGInfo C_Spell C_StringUtil StaticPopupDialogs StaticPopup_Show YES CANCEL MenuUtil GameTooltip SecondsToClock DAMAGE_METER_COMBAT_NUMBER CLASS_ICON_TCOORDS UnitClass UnitExists UnitGUID IsInRaid UISpecialFrames GetCursorPosition GetTime ACTION_SWING ACTION_ENVIRONMENTAL_DAMAGE_DROWNING ACTION_ENVIRONMENTAL_DAMAGE_FALLING ACTION_ENVIRONMENTAL_DAMAGE_FIRE ACTION_ENVIRONMENTAL_DAMAGE_LAVA ACTION_ENVIRONMENTAL_DAMAGE_SLIME ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE DEATH_RECAP_TITLE
local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local LSM = LibStub("LibSharedMedia-3.0", true)
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType

local DamageMeter = {}
addon.DamageMeter = DamageMeter

local EDITMODE_ID_PREFIX = "EQOL_DamageMeter"
local MAX_WINDOWS = 5
local DEFAULT_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local DEFAULT_BORDER = "Interface\\Buttons\\WHITE8x8"
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local GLOBAL_FONT_KEY = "__EQOL_GLOBAL_FONT__"
local GLOBAL_STYLE_KEY = "__EQOL_GLOBAL_FONT_STYLE__"
local REMOVE_WINDOW_POPUP = "EQOL_DAMAGE_METER_REMOVE_WINDOW"
local COPY_WINDOW_POPUP = "EQOL_DAMAGE_METER_COPY_WINDOW"
local RESET_DATA_POPUP = "EQOL_DAMAGE_METER_RESET_DATA"
local CONTEXT_MENU_WIDTH = 376
local CONTEXT_MENU_PADDING = 8
local CONTEXT_MENU_BUTTON_HEIGHT = 30
local CONTEXT_MENU_BUTTON_GAP = 4
local getWindowCount
local PARTY_UNIT_TOKENS = { "player", "party1", "party2", "party3", "party4" }
local SESSION_TYPES = {
	current = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current,
	overall = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall,
}
-- Keep Blizzard's localized abbreviation breakpoints, with one extra floor so sub-1000 DPS values do not show long decimals.
local LOW_NUMBER_ABBREV_BREAKPOINT = { breakpoint = 1, abbreviation = "", significandDivisor = 1, fractionDivisor = 1, abbreviationIsGlobal = false }
local FALLBACK_SHORT_NUMBER_ABBREV_BREAKPOINTS = {
	{ breakpoint = 10000000000, abbreviation = "B", significandDivisor = 1000000000, fractionDivisor = 1, abbreviationIsGlobal = false },
	{ breakpoint = 1000000000, abbreviation = "B", significandDivisor = 1000000000, fractionDivisor = 10, abbreviationIsGlobal = false },
	{ breakpoint = 10000000, abbreviation = "M", significandDivisor = 1000000, fractionDivisor = 1, abbreviationIsGlobal = false },
	{ breakpoint = 1000000, abbreviation = "M", significandDivisor = 1000000, fractionDivisor = 10, abbreviationIsGlobal = false },
	{ breakpoint = 10000, abbreviation = "K", significandDivisor = 1000, fractionDivisor = 1, abbreviationIsGlobal = false },
	{ breakpoint = 1000, abbreviation = "K", significandDivisor = 1000, fractionDivisor = 10, abbreviationIsGlobal = false },
	LOW_NUMBER_ABBREV_BREAKPOINT,
}
local shortNumberAbbrevOptions
local SYNC_EXCLUDED_KEYS = {
	alwaysShowPlayer = true,
	sessionType = true,
	damageMeterType = true,
	visibility = true,
}
local DEFAULT_WINDOW = {
	alwaysShowPlayer = false,
	anchorToWindow = 0,
	windowAnchorPoint = "TOPLEFT",
	windowRelativePoint = "TOPRIGHT",
	windowOffsetX = 0,
	windowOffsetY = 0,
	sessionType = "current",
	damageMeterType = "DamageDone",
	quickTypes = { "DamageDone" },
	visibility = "always",
	maxRows = 8,
	visibleRows = 8,
	raidRowsEnabled = false,
	raidMaxRows = 8,
	raidVisibleRows = 8,
	width = 320,
	heightOffset = 0,
	headerPosition = "TOP",
	rowGrowth = "DOWN",
	rowSort = "TOP",
	rowHeight = 20,
	changeBarSize = false,
	barHeight = 20,
	barAnchor = "CENTER",
	barSpacing = 2,
	barBorderEnabled = false,
	barBorderTexture = "",
	barBorderColor = { r = 0, g = 0, b = 0, a = 0.9 },
	barBorderUseClassColor = false,
	barBorderSize = 1,
	barBorderInset = 0,
	changeIconSize = false,
	iconSizeOffset = 0,
	iconBorderEnabled = false,
	iconBorderTexture = "",
	iconBorderColor = { r = 0, g = 0, b = 0, a = 0.9 },
	iconBorderUseClassColor = false,
	iconBorderSize = 1,
	iconBorderInset = 0,
	showHeader = true,
	showHeaderSession = true,
	showHeaderType = true,
	showHeaderTime = true,
	showHeaderButtons = true,
	headerButtonSize = 16,
	headerFormat = "timeTypeDash",
	headerTimeFormat = "smart",
	showStatus = true,
	showNames = true,
	showRanks = true,
	prefixRankInName = false,
	rankGap = 2,
	rankFontFace = GLOBAL_FONT_KEY,
	rankFontOutline = GLOBAL_STYLE_KEY,
	rankFontSize = 11,
	showPercent = true,
	hideRealmNames = true,
	abbreviation = "short",
	valueFormat = "slash",
	nameAnchorH = "LEFT",
	nameAnchorV = "CENTER",
	nameOffsetX = 5,
	nameOffsetY = 0,
	valueAnchorH = "RIGHT",
	valueAnchorV = "CENTER",
	valueOffsetX = -5,
	valueOffsetY = 0,
	useClassColors = true,
	nameUseClassColors = false,
	nameColor = { r = 1, g = 1, b = 1, a = 1 },
	texture = "",
	backdropTexture = "",
	backdropColor = { r = 0.02, g = 0.025, b = 0.03, a = 0.78 },
	borderEnabled = true,
	borderTexture = "",
	borderColor = { r = 0.1, g = 0.12, b = 0.14, a = 0.95 },
	borderSize = 1,
	borderInset = 0,
	fontFace = GLOBAL_FONT_KEY,
	fontOutline = GLOBAL_STYLE_KEY,
	fontSize = 11,
	valueFontFace = GLOBAL_FONT_KEY,
	valueFontOutline = GLOBAL_STYLE_KEY,
	valueFontSize = 11,
	valueUseClassColors = false,
	valueColor = { r = 1, g = 1, b = 1, a = 1 },
	titleFontFace = GLOBAL_FONT_KEY,
	titleFontOutline = GLOBAL_STYLE_KEY,
	titleFontSize = 12,
	titleColor = { r = 1, g = 0.82, b = 0, a = 1 },
	statusFontFace = GLOBAL_FONT_KEY,
	statusFontOutline = GLOBAL_STYLE_KEY,
	statusFontSize = 11,
	tooltipEnabled = true,
	tooltipPreview = false,
	tooltipAnchor = "RIGHT",
	tooltipOffsetX = 8,
	tooltipOffsetY = 0,
	tooltipFontSize = 11,
	tooltipMaxLines = 12,
	tooltipShowTargets = true,
	tooltipWidth = 330,
	tooltipBackdropTexture = "",
	tooltipBorderTexture = "",
	tooltipBorderSize = 1,
	tooltipShowBars = true,
	tooltipBarTexture = "",
	tooltipBarColor = { r = 0.1, g = 0.42, b = 0.78, a = 0.5 },
	tooltipShowAmount = true,
	tooltipShowDPS = true,
	tooltipShowPercent = true,
	tooltipBackdropColor = { r = 0.02, g = 0.025, b = 0.03, a = 0.92 },
	tooltipBorderColor = { r = 0.1, g = 0.12, b = 0.14, a = 0.95 },
}
local PREVIEW_SESSION = {
	combatSources = {
		{ totalAmount = 100000, amountPerSecond = 10000, name = "Khadgar", classFilename = "MAGE", specIconID = 135932 },
		{ totalAmount = 83000, amountPerSecond = 8300, name = "Valeera", classFilename = "ROGUE", specIconID = 132320 },
		{ totalAmount = 71000, amountPerSecond = 7100, name = "Thrall", classFilename = "SHAMAN", specIconID = 136048 },
		{ totalAmount = 64000, amountPerSecond = 6400, name = "Liadrin", classFilename = "PALADIN", specIconID = 135920 },
		{ totalAmount = 51000, amountPerSecond = 5100, name = "Alleria", classFilename = "HUNTER", specIconID = 461115 },
		{ totalAmount = 42000, amountPerSecond = 4200, name = "Anduin", classFilename = "PRIEST", specIconID = 135940, isLocalPlayer = true },
	},
	maxAmount = 100000,
	totalAmount = 411000,
	durationSeconds = 10,
}
local PREVIEW_SOURCE_DETAILS = {
	combatSpells = {
		{ spellID = 188196, totalAmount = 344000, amountPerSecond = 14400, combatSpellDetails = { unitName = "Dutiful Groundskeeper", amount = 489000, specIconID = 236157 } },
		{ spellID = 117014, totalAmount = 148000, amountPerSecond = 6000, combatSpellDetails = { unitName = "Restless Steward", amount = 223000, specIconID = 236157 } },
		{ spellID = 51505, totalAmount = 91000, amountPerSecond = 3700, combatSpellDetails = { unitName = "Dutiful Groundskeeper", amount = 91000, specIconID = 236157 } },
		{ spellID = 188389, totalAmount = 58000, amountPerSecond = 2300, combatSpellDetails = { unitName = "Restless Steward", amount = 58000, specIconID = 236157 } },
		{ spellID = 45284, totalAmount = 49000, amountPerSecond = 2000, combatSpellDetails = { unitName = "Dutiful Groundskeeper", amount = 49000, specIconID = 236157 } },
	},
	maxAmount = 344000,
	totalAmount = 690000,
}

local function db()
	return addon.db or {}
end

local function clampNumber(value, minValue, maxValue, default)
	value = tonumber(value) or default
	if value < minValue then return minValue end
	if value > maxValue then return maxValue end
	return value
end

local copyValue
local normalizeWindowQuickTypes

local function copyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			target[key] = copyValue(value)
		end
	end
end

copyValue = function(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = copyValue(child)
	end
	return copy
end

local function applyWindowDefaults(target, index)
	local hadSessionType = target.sessionType ~= nil
	copyDefaults(target, DEFAULT_WINDOW)
	if index > 1 and not hadSessionType then
		target.sessionType = index % 2 == 0 and "overall" or "current"
	end
	normalizeWindowQuickTypes(target)
	return target
end

local function copyWindowConfig(source)
	local copy = {}
	source = type(source) == "table" and source or {}
	for key, defaultValue in pairs(DEFAULT_WINDOW) do
		if source[key] ~= nil then
			copy[key] = copyValue(source[key])
		else
			copy[key] = copyValue(defaultValue)
		end
	end
	return copy
end

local function copySyncedWindowConfig(source, target)
	source = type(source) == "table" and source or {}
	target = type(target) == "table" and target or {}
	copyDefaults(target, DEFAULT_WINDOW)
	for key, defaultValue in pairs(DEFAULT_WINDOW) do
		if not SYNC_EXCLUDED_KEYS[key] then
			if source[key] ~= nil then
				target[key] = copyValue(source[key])
			else
				target[key] = copyValue(defaultValue)
			end
		end
	end
	return target
end

local function getGlobalFontKey()
	return addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or GLOBAL_FONT_KEY
end

local function getGlobalFontLabel()
	return addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or (L["useGlobalFontConfig"] or "Use global font config")
end

local function getGlobalStyleKey()
	return addon.functions.GetGlobalFontStyleConfigKey and addon.functions.GetGlobalFontStyleConfigKey() or GLOBAL_STYLE_KEY
end

local function getGlobalStyleLabel()
	return addon.functions.GetGlobalFontStyleConfigLabel and addon.functions.GetGlobalFontStyleConfigLabel() or (L["useGlobalFontStyleConfig"] or "Use global font styling")
end

local function normalizeStyle(value)
	if addon.functions.NormalizeFontStyleChoice then
		return addon.functions.NormalizeFontStyleChoice(value, getGlobalStyleKey(), true)
	end
	if value == GLOBAL_STYLE_KEY then return value end
	if value == "NONE" or value == "OUTLINE" or value == "THICKOUTLINE" or value == "MONOCHROME" or value == "MONOCHROMEOUTLINE" then return value end
	return GLOBAL_STYLE_KEY
end

local function resolveStyle(value)
	if addon.functions.ResolveFontStyleChoice then
		return addon.functions.ResolveFontStyleChoice(value, "OUTLINE")
	end
	value = normalizeStyle(value)
	if value == GLOBAL_STYLE_KEY then
		local globalValue = db().globalFontStyle
		if type(globalValue) == "string" and globalValue ~= "" then return globalValue end
		return "OUTLINE"
	end
	if value == "NONE" then return "" end
	return value
end

local function resolveMedia(mediaType, key, fallback)
	if type(key) == "string" and key ~= "" then
		if addon.functions.ResolveLSMMedia then
			local resolved = addon.functions.ResolveLSMMedia(mediaType, key, fallback, true)
			if resolved then return resolved end
		end
		if LSM and LSM.Fetch then
			local resolved = LSM:Fetch(mediaType, key, true)
			if resolved then return resolved end
		end
	end
	return fallback
end

local function resolveFont(key)
	if key == GLOBAL_FONT_KEY then
		key = db().globalFontFace or getGlobalFontKey()
	end
	return resolveMedia("font", key, DEFAULT_FONT)
end

local function buildMediaOptions(mediaType, includeGlobal)
	local options = {}
	if includeGlobal and mediaType == "font" then
		options[#options + 1] = { value = getGlobalFontKey(), label = getGlobalFontLabel() }
	elseif mediaType == "statusbar" or mediaType == "border" then
		options[#options + 1] = { value = "", label = _G.DEFAULT or "Default" }
	end
	local names = addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames(mediaType) or {}
	for _, name in ipairs(names) do
		options[#options + 1] = { value = name, label = name }
	end
	return options
end

local function buildStyleOptions()
	if addon.functions.GetFontStyleOptionList then
		return addon.functions.GetFontStyleOptionList(true)
	end
	return {
		{ value = getGlobalStyleKey(), label = getGlobalStyleLabel() },
		{ value = "NONE", label = _G.NONE or "None" },
		{ value = "OUTLINE", label = L["Font outline"] or "Font outline" },
		{ value = "THICKOUTLINE", label = L["Thick outline"] or "Thick outline" },
		{ value = "MONOCHROME", label = "Monochrome" },
		{ value = "MONOCHROMEOUTLINE", label = "Monochrome Outline" },
	}
end

local function buildHorizontalAnchorOptions()
	return {
		{ value = "LEFT", label = _G.LEFT or "Left" },
		{ value = "CENTER", label = _G.CENTER or "Center" },
		{ value = "RIGHT", label = _G.RIGHT or "Right" },
	}
end

local function buildVerticalAnchorOptions()
	return {
		{ value = "TOP", label = _G.TOP or "Top" },
		{ value = "CENTER", label = _G.CENTER or "Center" },
		{ value = "BOTTOM", label = _G.BOTTOM or "Bottom" },
	}
end

local function buildTooltipAnchorOptions()
	return {
		{ value = "RIGHT", label = _G.RIGHT or "Right" },
		{ value = "LEFT", label = _G.LEFT or "Left" },
		{ value = "TOP", label = _G.TOP or "Top" },
		{ value = "BOTTOM", label = _G.BOTTOM or "Bottom" },
	}
end

local function buildHeaderPositionOptions()
	return {
		{ value = "TOP", label = _G.TOP or "Top" },
		{ value = "BOTTOM", label = _G.BOTTOM or "Bottom" },
	}
end

local function buildRowGrowthOptions()
	return {
		{ value = "DOWN", label = L["damageMeterRowsGrowDown"] or "Down" },
		{ value = "UP", label = L["damageMeterRowsGrowUp"] or "Up" },
	}
end

local function buildRowSortOptions()
	return {
		{ value = "TOP", label = L["damageMeterHighestBarTop"] or "Highest bar on top" },
		{ value = "BOTTOM", label = L["damageMeterHighestBarBottom"] or "Highest bar on bottom" },
	}
end

local DAMAGE_METER_TYPES = {
	{ key = "Absorbs", global = "DAMAGE_METER_TYPE_ABSORBS", enum = "Absorbs" },
	{ key = "AvoidableDamageTaken", global = "DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN", enum = "AvoidableDamageTaken" },
	{ key = "DamageDone", global = "DAMAGE_METER_TYPE_DAMAGE_DONE", enum = "DamageDone" },
	{ key = "DamageTaken", global = "DAMAGE_METER_TYPE_DAMAGE_TAKEN", enum = "DamageTaken" },
	{ key = "Deaths", global = "DAMAGE_METER_TYPE_DEATHS", enum = "Deaths" },
	{ key = "Dispels", global = "DAMAGE_METER_TYPE_DISPELS", enum = "Dispels" },
	{ key = "Dps", global = "DAMAGE_METER_TYPE_DPS", enum = "Dps" },
	{ key = "EnemyDamageTaken", global = "DAMAGE_METER_TYPE_ENEMY_DAMAGE_TAKEN", enum = "EnemyDamageTaken" },
	{ key = "HealingDone", global = "DAMAGE_METER_TYPE_HEALING_DONE", enum = "HealingDone" },
	{ key = "Hps", global = "DAMAGE_METER_TYPE_HPS", enum = "Hps" },
	{ key = "Interrupts", global = "DAMAGE_METER_TYPE_INTERRUPTS", enum = "Interrupts" },
}

local DAMAGE_METER_TYPE_ICONS = {
	Absorbs = "Interface\\Icons\\Spell_Holy_PowerWordShield",
	AvoidableDamageTaken = "Interface\\Icons\\Ability_Defend",
	DamageDone = "Interface\\Icons\\INV_Sword_04",
	DamageTaken = "Interface\\Icons\\Ability_Defend",
	Deaths = "Interface\\Icons\\Ability_Creature_Cursed_02",
	Dispels = "Interface\\Icons\\Spell_Holy_DispelMagic",
	Dps = "Interface\\Icons\\INV_Sword_04",
	EnemyDamageTaken = "Interface\\Icons\\Ability_DualWield",
	HealingDone = "Interface\\Icons\\Spell_Holy_HolyBolt",
	Hps = "Interface\\Icons\\Spell_Holy_HolyBolt",
	Interrupts = "Interface\\Icons\\Ability_Kick",
}

local function getDamageMeterTypeInfo(key)
	for _, info in ipairs(DAMAGE_METER_TYPES) do
		if info.key == key then return info end
	end
	return DAMAGE_METER_TYPES[3]
end

local function getDamageMeterTypeLabel(key)
	local info = getDamageMeterTypeInfo(key)
	return _G[info.global] or info.key
end

local function getDamageMeterTypeIcon(key)
	return DAMAGE_METER_TYPE_ICONS[getDamageMeterTypeInfo(key).key] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function normalizeDamageMeterTypeKey(key)
	local info = getDamageMeterTypeInfo(key)
	return info and info.key or DEFAULT_WINDOW.damageMeterType
end

local function getDamageMeterTypeValue(key)
	local info = getDamageMeterTypeInfo(key)
	return Enum and Enum.DamageMeterType and Enum.DamageMeterType[info.enum]
end

local function buildDamageMeterTypeOptions()
	local options = {}
	for _, info in ipairs(DAMAGE_METER_TYPES) do
		if Enum and Enum.DamageMeterType and Enum.DamageMeterType[info.enum] ~= nil then
			options[#options + 1] = { value = info.key, label = getDamageMeterTypeLabel(info.key) }
		end
	end
	table.sort(options, function(a, b) return a.label < b.label end)
	return options
end

local function isValidDamageMeterTypeKey(key)
	for _, info in ipairs(DAMAGE_METER_TYPES) do
		if info.key == key then return true end
	end
	return false
end

local function normalizeQuickDamageMeterTypes(types, fallback)
	local normalized = {}
	local seen = {}
	if type(types) == "table" then
		for _, value in ipairs(types) do
			local key = normalizeDamageMeterTypeKey(value)
			if isValidDamageMeterTypeKey(key) and not seen[key] then
				normalized[#normalized + 1] = key
				seen[key] = true
			end
		end
	end
	if #normalized == 0 and fallback then
		local key = normalizeDamageMeterTypeKey(fallback)
		if isValidDamageMeterTypeKey(key) then normalized[1] = key end
	end
	return normalized
end

normalizeWindowQuickTypes = function(config)
	config.quickTypes = normalizeQuickDamageMeterTypes(config.quickTypes, config.damageMeterType or DEFAULT_WINDOW.damageMeterType)
	return config.quickTypes
end

local function normalizeFramePoint(value)
	if value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT" or value == "LEFT" or value == "CENTER" or value == "RIGHT" or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT" then
		return value
	end
	return "TOPLEFT"
end

local function buildFramePointOptions()
	return {
		{ value = "TOPLEFT", label = "TOPLEFT" },
		{ value = "TOP", label = "TOP" },
		{ value = "TOPRIGHT", label = "TOPRIGHT" },
		{ value = "LEFT", label = "LEFT" },
		{ value = "CENTER", label = "CENTER" },
		{ value = "RIGHT", label = "RIGHT" },
		{ value = "BOTTOMLEFT", label = "BOTTOMLEFT" },
		{ value = "BOTTOM", label = "BOTTOM" },
		{ value = "BOTTOMRIGHT", label = "BOTTOMRIGHT" },
	}
end

local function buildWindowAnchorOptions(index)
	local options = {
		{ value = "0", label = _G.NONE or "None" },
	}
	for windowIndex = 1, math.min(index - 1, getWindowCount()) do
		options[#options + 1] = { value = tostring(windowIndex), label = string.format("%s %d", L["damageMeterTitle"] or "Damage Meter", windowIndex) }
	end
	return options
end

local function isSecret(value)
	return _G.issecretvalue and _G.issecretvalue(value)
end

local function safeText(value, fallback)
	if value == nil or isSecret(value) then return fallback end
	value = tostring(value)
	if value == "" then return fallback end
	return value
end

local function safeNumber(value)
	if value == nil or isSecret(value) then return nil end
	return tonumber(value)
end

local function formatFull(value)
	if isSecret(value) then
		if AbbreviateNumbers then return AbbreviateNumbers(value) end
		if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
		return ""
	end
	value = tonumber(value) or 0
	return BreakUpLargeNumbers and BreakUpLargeNumbers(math.floor(value + 0.5)) or tostring(math.floor(value + 0.5))
end

local function copyShortNumberAbbrevBreakpoints(data)
	if type(data) ~= "table" then return nil end
	local breakpoints = {}
	for _, breakpoint in ipairs(data) do
		if type(breakpoint) == "table" then
			breakpoints[#breakpoints + 1] = {
				breakpoint = breakpoint.breakpoint,
				abbreviation = breakpoint.abbreviation,
				significandDivisor = breakpoint.significandDivisor,
				fractionDivisor = breakpoint.fractionDivisor,
				abbreviationIsGlobal = breakpoint.abbreviationIsGlobal ~= false,
			}
		end
	end
	if #breakpoints == 0 then return nil end
	breakpoints[#breakpoints + 1] = LOW_NUMBER_ABBREV_BREAKPOINT
	return breakpoints
end

local function getShortNumberAbbrevOptions()
	if not shortNumberAbbrevOptions then
		local breakpoints = C_StringUtil and C_StringUtil.GetDefaultAbbreviationBreakpoints and copyShortNumberAbbrevBreakpoints(C_StringUtil.GetDefaultAbbreviationBreakpoints())
		shortNumberAbbrevOptions = { breakpointData = breakpoints or FALLBACK_SHORT_NUMBER_ABBREV_BREAKPOINTS }
	end
	return shortNumberAbbrevOptions
end

local function formatShort(value)
	if value == nil then return "0" end
	if AbbreviateNumbers then return AbbreviateNumbers(value, getShortNumberAbbrevOptions()) end
	if isSecret(value) then
		if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
		return ""
	end
	value = tonumber(value) or 0
	if AbbreviateLargeNumbers then return AbbreviateLargeNumbers(value) end
	if value >= 1000000000 then return string.format("%.1fb", value / 1000000000) end
	if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
	if value >= 1000 then return string.format("%.1fk", value / 1000) end
	return tostring(math.floor(value + 0.5))
end

local function formatNumber(value, mode)
	if mode == "none" then return formatFull(value) end
	return formatShort(value)
end

local function formatDuration(seconds, mode)
	seconds = safeNumber(seconds)
	if not seconds then return nil end
	seconds = math.floor(seconds + 0.5)
	if mode == "seconds" then
		return tostring(seconds) .. "s"
	end
	if mode == "clock" then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	if seconds >= 60 then
		return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
	end
	return tostring(seconds) .. "s"
end

local function formatHistoryDuration(seconds)
	seconds = safeNumber(seconds)
	if not seconds then return nil end
	seconds = math.floor(seconds + 0.5)
	if SecondsToClock then return SecondsToClock(seconds) end
	if seconds >= 60 then return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60) end
	return tostring(seconds) .. "s"
end

local function buildHeaderFormatOptions()
	return {
		{ value = "timeTypeDash", label = L["damageMeterHeaderFormatTimeTypeDash"] or "<combat time> - <type>" },
		{ value = "timeTypeSpace", label = L["damageMeterHeaderFormatTimeTypeSpace"] or "<combat time> <type>" },
		{ value = "typeTimeDash", label = L["damageMeterHeaderFormatTypeTimeDash"] or "<type> - <combat time>" },
		{ value = "typeTimeSpace", label = L["damageMeterHeaderFormatTypeTimeSpace"] or "<type> <combat time>" },
	}
end

local function buildHeaderTimeFormatOptions()
	return {
		{ value = "smart", label = L["damageMeterHeaderTimeFormatSmart"] or "1:05 after 60s" },
		{ value = "clock", label = L["damageMeterHeaderTimeFormatClock"] or "1:05" },
		{ value = "seconds", label = L["damageMeterHeaderTimeFormatSeconds"] or "65s" },
	}
end

local function normalizeHeaderFormat(value)
	if value == "timeTypeSpace" or value == "typeTimeDash" or value == "typeTimeSpace" then return value end
	return "timeTypeDash"
end

local function normalizeHeaderTimeFormat(value)
	if value == "clock" then return "clock" end
	return value == "seconds" and "seconds" or "smart"
end

local function formatSourceName(value, config)
	if value == nil then return L["Unknown"] or UNKNOWN or "Unknown" end
	if isSecret(value) then return value end
	local name = safeText(value, L["Unknown"] or UNKNOWN or "Unknown")
	if config.hideRealmNames ~= false then
		name = name:gsub("%-[^%-]+$", "")
	end
	return name
end

local function formatDisplayName(value, rowIndex, config)
	local name = formatSourceName(value, config)
	if isSecret(name) then return name end
	if config.showRanks ~= false and config.prefixRankInName == true then
		local gap = clampNumber(config.rankGap, 0, 24, DEFAULT_WINDOW.rankGap)
		local spaces = string.rep(" ", math.ceil(gap / 4))
		return string.format("%d.%s%s", rowIndex, spaces, name)
	end
	return name
end

local function isPerSecondMeterType(key)
	key = normalizeDamageMeterTypeKey(key)
	return key == "Dps" or key == "Hps"
end

local function isCountOnlyMeterType(key)
	key = normalizeDamageMeterTypeKey(key)
	return key == "Dispels" or key == "Interrupts"
end

local function getRowValueMode(damageMeterType)
	if damageMeterType == "Deaths" then return "death" end
	if damageMeterType == "Dispels" or damageMeterType == "Interrupts" then return "count" end
	if damageMeterType == "Dps" or damageMeterType == "Hps" then return "perSecond" end
	return "amountAndRate"
end

local function useRaidRows(config)
	return config.raidRowsEnabled == true and IsInRaid and IsInRaid() == true
end

local function getEffectiveMaxRows(config)
	if useRaidRows(config) then
		return clampNumber(config.raidMaxRows, 1, 30, DEFAULT_WINDOW.raidMaxRows)
	end
	return clampNumber(config.maxRows, 1, 30, DEFAULT_WINDOW.maxRows)
end

local function getEffectiveVisibleRows(config, maxRows)
	maxRows = maxRows or getEffectiveMaxRows(config)
	if useRaidRows(config) then
		return math.min(maxRows, clampNumber(config.raidVisibleRows, 1, 30, DEFAULT_WINDOW.raidVisibleRows))
	end
	return math.min(maxRows, clampNumber(config.visibleRows, 1, 30, DEFAULT_WINDOW.visibleRows))
end

local function formatDeathTimeText(source)
	local rawDeathTimeSeconds = source and source.deathTimeSeconds
	if isSecret(rawDeathTimeSeconds) then return tostring(rawDeathTimeSeconds) end
	local deathTimeSeconds = safeNumber(rawDeathTimeSeconds)
	if not deathTimeSeconds or deathTimeSeconds == -1 then return "" end
	return formatDuration(deathTimeSeconds, "clock") or ""
end

local function appendRowPercent(text, percent, showPercent)
	if showPercent and percent then
		return string.format("%s (%.1f%%)", text, percent)
	end
	return text
end

local function formatRowValueText(source, percent, valueMode, abbreviation, showPercent, useParentheses)
	if valueMode == "death" then
		return formatDeathTimeText(source)
	end
	if valueMode == "count" then
		return appendRowPercent(formatNumber(source.totalAmount, abbreviation), percent, showPercent)
	end
	if valueMode == "perSecond" then
		return appendRowPercent(formatNumber(source.amountPerSecond, abbreviation), percent, showPercent)
	end
	local amountText = formatNumber(source.totalAmount, abbreviation)
	local dpsText = formatNumber(source.amountPerSecond, abbreviation)
	local text = useParentheses and string.format("%s (%s)", amountText, dpsText) or string.format("%s / %s", amountText, dpsText)
	return appendRowPercent(text, percent, showPercent)
end

local function isInFollowerDungeon()
	if C_LFGInfo and C_LFGInfo.IsInLFGFollowerDungeon then
		if C_LFGInfo.IsInLFGFollowerDungeon() == true then return true end
	end
	local _, instanceType, difficultyID = GetInstanceInfo()
	return instanceType == "party" and difficultyID == 205
end

local function applyClassIcon(texture, classFilename)
	if type(classFilename) ~= "string" or classFilename == "" or not CLASS_ICON_TCOORDS or not CLASS_ICON_TCOORDS[classFilename] then return false end
	if texture._damageMeterIconKind == "class" and texture._damageMeterIconValue == classFilename then return true end
	texture._damageMeterIconKind = "class"
	texture._damageMeterIconValue = classFilename
	local coords = CLASS_ICON_TCOORDS[classFilename]
	texture:SetTexture(CLASS_ICON_TEXTURE)
	texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	return true
end

local function applySourceIcon(texture, source, inFollowerDungeon)
	if inFollowerDungeon and source.isLocalPlayer ~= true and applyClassIcon(texture, source.classFilename) then
		return
	end
	local specIconID = source.specIconID
	if specIconID and specIconID ~= 0 then
		if texture._damageMeterIconKind ~= "spec" or texture._damageMeterIconValue ~= specIconID then
			texture._damageMeterIconKind = "spec"
			texture._damageMeterIconValue = specIconID
			texture:SetTexture(specIconID)
			texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		return
	end
	if applyClassIcon(texture, source.classFilename) then return end
	if texture._damageMeterIconKind ~= "fallback" then
		texture._damageMeterIconKind = "fallback"
		texture._damageMeterIconValue = 136243
		texture:SetTexture(136243)
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
end

local function normalizeColor(value, fallback)
	fallback = fallback or DEFAULT_WINDOW.backdropColor
	if type(value) ~= "table" then value = fallback end
	return {
		r = clampNumber(value.r or value[1], 0, 1, fallback.r or fallback[1] or 0),
		g = clampNumber(value.g or value[2], 0, 1, fallback.g or fallback[2] or 0),
		b = clampNumber(value.b or value[3], 0, 1, fallback.b or fallback[3] or 0),
		a = clampNumber(value.a or value[4], 0, 1, fallback.a or fallback[4] or 1),
	}
end

local function colorComponents(value, fallback)
	fallback = fallback or DEFAULT_WINDOW.backdropColor
	if type(value) ~= "table" then value = fallback end
	return clampNumber(value.r or value[1], 0, 1, fallback.r or fallback[1] or 0),
		clampNumber(value.g or value[2], 0, 1, fallback.g or fallback[2] or 0),
		clampNumber(value.b or value[3], 0, 1, fallback.b or fallback[3] or 0),
		clampNumber(value.a or value[4], 0, 1, fallback.a or fallback[4] or 1)
end

local function getGlobalFontStateVersion()
	if addon.functions and addon.functions.GetGlobalFontStateVersion then return addon.functions.GetGlobalFontStateVersion() or 0 end
	return 0
end

local function setShownIfChanged(region, shown)
	shown = shown == true
	if region:IsShown() ~= shown then region:SetShown(shown) end
end

local function setTextColorIfChanged(fontString, r, g, b, a)
	a = a == nil and 1 or a
	if fontString._damageMeterTextColorR == r
		and fontString._damageMeterTextColorG == g
		and fontString._damageMeterTextColorB == b
		and fontString._damageMeterTextColorA == a then
		return
	end
	fontString._damageMeterTextColorR = r
	fontString._damageMeterTextColorG = g
	fontString._damageMeterTextColorB = b
	fontString._damageMeterTextColorA = a
	fontString:SetTextColor(r, g, b, a)
end

local function setPlainTextIfChanged(fontString, text)
	text = text or ""
	if fontString._damageMeterPlainText == text then return end
	fontString._damageMeterPlainText = text
	fontString:SetText(text)
end

local function getRowMetrics(config)
	local rowHeight = clampNumber(config.rowHeight, 10, 70, DEFAULT_WINDOW.rowHeight)
	local barHeight = config.changeBarSize == true and math.min(rowHeight, clampNumber(config.barHeight, 1, rowHeight, DEFAULT_WINDOW.barHeight)) or rowHeight
	local spacing = clampNumber(config.barSpacing, 0, 16, DEFAULT_WINDOW.barSpacing)
	return rowHeight, barHeight, spacing
end

local function getBarBorderOutset(config)
	if config.barBorderEnabled ~= true then return 0 end
	return clampNumber(config.barBorderInset, 0, 24, DEFAULT_WINDOW.barBorderInset)
end

local function getIconBorderOutset(config)
	if config.iconBorderEnabled ~= true then return 0 end
	return clampNumber(config.iconBorderInset, 0, 24, DEFAULT_WINDOW.iconBorderInset)
end

local function getEffectiveRowHeight(config)
	local rowHeight = getRowMetrics(config)
	return rowHeight + (math.max(getBarBorderOutset(config), getIconBorderOutset(config)) * 2)
end

local function getIconSize(config)
	local maxSize = math.max(8, getEffectiveRowHeight(config) - (getIconBorderOutset(config) * 2))
	if config.changeIconSize ~= true then return maxSize end
	local offset = clampNumber(config.iconSizeOffset, -60, 0, DEFAULT_WINDOW.iconSizeOffset)
	return clampNumber(maxSize + offset, 8, maxSize, maxSize)
end

local function getEffectiveRankWidth(config)
	if config.showRanks == false or config.prefixRankInName == true then return 0 end
	local rankFontSize = clampNumber(config.rankFontSize, 8, 24, DEFAULT_WINDOW.rankFontSize)
	local maxRows = getEffectiveMaxRows(config)
	local rankChars = #tostring(maxRows) + 1
	return math.min(60, math.ceil(rankChars * rankFontSize * 0.52) + 3)
end

local function getRowTextInsets(config)
	local rankWidth = getEffectiveRankWidth(config)
	local rankGap = clampNumber(config.rankGap, 0, 24, DEFAULT_WINDOW.rankGap)
	local iconSize = getIconSize(config)
	local leftInset = 4 + iconSize + 4
	if rankWidth > 0 then
		leftInset = leftInset + rankWidth + rankGap
	end
	return leftInset, 4, iconSize, rankWidth, rankGap
end

local function normalizeAnchorH(value)
	return (value == "CENTER" or value == "RIGHT") and value or "LEFT"
end

local function normalizeAnchorV(value)
	return (value == "TOP" or value == "BOTTOM") and value or "CENTER"
end

local function normalizeTooltipAnchor(value)
	if value == "LEFT" or value == "TOP" or value == "BOTTOM" then return value end
	return "RIGHT"
end

local function normalizeHeaderPosition(value)
	return value == "BOTTOM" and "BOTTOM" or "TOP"
end

local function normalizeRowGrowth(value)
	return value == "UP" and "UP" or "DOWN"
end

local function normalizeRowSort(value)
	return value == "BOTTOM" and "BOTTOM" or "TOP"
end

local function anchorPoint(horizontal, vertical)
	horizontal = normalizeAnchorH(horizontal)
	vertical = normalizeAnchorV(vertical)
	if vertical == "CENTER" then return horizontal end
	if horizontal == "CENTER" then return vertical end
	return vertical .. horizontal
end

local function justifyFromAnchor(horizontal)
	horizontal = normalizeAnchorH(horizontal)
	if horizontal == "RIGHT" then return "RIGHT" end
	if horizontal == "CENTER" then return "CENTER" end
	return "LEFT"
end

local function isDefaultTextLayout(config)
	return normalizeAnchorH(config.nameAnchorH) == "LEFT"
		and normalizeAnchorV(config.nameAnchorV) == "CENTER"
		and normalizeAnchorH(config.valueAnchorH) == "RIGHT"
		and normalizeAnchorV(config.valueAnchorV) == "CENTER"
		and clampNumber(config.nameOffsetX, -200, 200, DEFAULT_WINDOW.nameOffsetX) == DEFAULT_WINDOW.nameOffsetX
		and clampNumber(config.nameOffsetY, -200, 200, DEFAULT_WINDOW.nameOffsetY) == DEFAULT_WINDOW.nameOffsetY
		and clampNumber(config.valueOffsetX, -200, 200, DEFAULT_WINDOW.valueOffsetX) == DEFAULT_WINDOW.valueOffsetX
		and clampNumber(config.valueOffsetY, -200, 200, DEFAULT_WINDOW.valueOffsetY) == DEFAULT_WINDOW.valueOffsetY
end

local function getUpdateRate()
	return clampNumber(db().damageMeterUpdateRate, 0.1, 2, 0.1)
end

function getWindowCount()
	return clampNumber(db().damageMeterWindowCount, 1, MAX_WINDOWS, 1)
end

local function setWindowCount(value)
	db().damageMeterWindowCount = clampNumber(value, 1, MAX_WINDOWS, 1)
end

function DamageMeter:GetWindowsDB()
	local profile = db()
	if type(profile.damageMeterWindows) ~= "table" then profile.damageMeterWindows = {} end
	if self.normalizedWindowsDB == profile.damageMeterWindows then return profile.damageMeterWindows end
	for index = 1, MAX_WINDOWS do
		if type(profile.damageMeterWindows[index]) ~= "table" then profile.damageMeterWindows[index] = {} end
		applyWindowDefaults(profile.damageMeterWindows[index], index)
	end
	self.normalizedWindowsDB = profile.damageMeterWindows
	return profile.damageMeterWindows
end

function DamageMeter:GetConfig(index)
	return self:GetWindowsDB()[index]
end

function DamageMeter:GetWindowStyleVersion(index)
	self.windowStyleVersions = self.windowStyleVersions or {}
	return self.windowStyleVersions[index] or 0
end

function DamageMeter:InvalidateLiveEventWatch()
	self.liveEventWatchDirty = true
end

function DamageMeter:MarkWindowStyleDirty(index)
	self.windowStyleVersions = self.windowStyleVersions or {}
	if index then
		self.windowStyleVersions[index] = (self.windowStyleVersions[index] or 0) + 1
		return
	end
	for windowIndex = 1, MAX_WINDOWS do
		self.windowStyleVersions[windowIndex] = (self.windowStyleVersions[windowIndex] or 0) + 1
	end
end

function DamageMeter:GetTemporarySelection(index)
	self.temporarySelections = self.temporarySelections or {}
	if type(self.temporarySelections[index]) ~= "table" then self.temporarySelections[index] = {} end
	return self.temporarySelections[index]
end

function DamageMeter:GetEffectiveDamageMeterType(index)
	local temporary = self:GetTemporarySelection(index)
	return normalizeDamageMeterTypeKey(temporary.damageMeterType or self:GetConfig(index).damageMeterType)
end

function DamageMeter:GetQuickDamageMeterTypes(index)
	local config = self:GetConfig(index)
	if config.quickTypes == DEFAULT_WINDOW.quickTypes then
		config.quickTypes = copyValue(DEFAULT_WINDOW.quickTypes)
	end
	if type(config.quickTypes) ~= "table" or #config.quickTypes == 0 then return normalizeWindowQuickTypes(config) end
	return config.quickTypes
end

function DamageMeter:GetQuickDamageMeterTypeLabels(index, fallbackLabel)
	self.quickTypeLabelCache = self.quickTypeLabelCache or {}
	local quickTypes = self:GetQuickDamageMeterTypes(index)
	local cache = self.quickTypeLabelCache[index]
	if cache and cache.quickTypes == quickTypes and cache.fallbackLabel == fallbackLabel then return cache.text end
	local text
	for quickIndex, quickType in ipairs(quickTypes) do
		local label = getDamageMeterTypeLabel(quickType)
		text = text and (text .. " / " .. label) or label
	end
	if not text or text == "" then text = fallbackLabel or "" end
	self.quickTypeLabelCache[index] = {
		quickTypes = quickTypes,
		fallbackLabel = fallbackLabel,
		text = text,
	}
	return text
end

function DamageMeter:HasQuickDamageMeterType(index, damageMeterType)
	local key = normalizeDamageMeterTypeKey(damageMeterType)
	for _, quickType in ipairs(self:GetQuickDamageMeterTypes(index)) do
		if quickType == key then return true end
	end
	return false
end

function DamageMeter:AddQuickDamageMeterType(index, damageMeterType)
	local key = normalizeDamageMeterTypeKey(damageMeterType)
	local quickTypes = copyValue(self:GetQuickDamageMeterTypes(index))
	for _, quickType in ipairs(quickTypes) do
		if quickType == key then return end
	end
	quickTypes[#quickTypes + 1] = key
	self:SetConfigValue(index, "quickTypes", quickTypes)
end

function DamageMeter:RemoveQuickDamageMeterType(index, damageMeterType)
	local key = normalizeDamageMeterTypeKey(damageMeterType)
	local quickTypes = copyValue(self:GetQuickDamageMeterTypes(index))
	for quickIndex = #quickTypes, 1, -1 do
		if quickTypes[quickIndex] == key then
			table.remove(quickTypes, quickIndex)
		end
	end
	self:SetConfigValue(index, "quickTypes", quickTypes)
end

function DamageMeter:CycleQuickDamageMeterType(index, direction)
	local quickTypes = self:GetQuickDamageMeterTypes(index)
	if #quickTypes == 0 then return end
	local current = self:GetEffectiveDamageMeterType(index)
	local currentIndex = 1
	for quickIndex, quickType in ipairs(quickTypes) do
		if quickType == current then
			currentIndex = quickIndex
			break
		end
	end
	local nextIndex = currentIndex + (direction or 1)
	if nextIndex > #quickTypes then nextIndex = 1 end
	if nextIndex < 1 then nextIndex = #quickTypes end
	self:SetTemporaryDamageMeterType(index, quickTypes[nextIndex])
end

function DamageMeter:GetEffectiveSessionType(index)
	local temporary = self:GetTemporarySelection(index)
	if temporary.sessionID then return nil end
	return temporary.sessionType or self:GetConfig(index).sessionType
end

function DamageMeter:GetEffectiveSessionID(index)
	return self:GetTemporarySelection(index).sessionID
end

function DamageMeter:GetEffectiveSessionLabel(index)
	local temporary = self:GetTemporarySelection(index)
	if temporary.sessionID then
		local fallback = DAMAGE_METER_COMBAT_NUMBER and DAMAGE_METER_COMBAT_NUMBER:format(temporary.sessionID) or string.format("%s %d", L["damageMeterCombat"] or "Combat", temporary.sessionID)
		return safeText(temporary.sessionName, fallback)
	end
	local sessionType = self:GetEffectiveSessionType(index)
	return sessionType == "overall" and (L["damageMeterOverall"] or "Overall") or (L["damageMeterCurrent"] or "Current")
end

function DamageMeter:SetTemporaryDamageMeterType(index, damageMeterType)
	local temporary = self:GetTemporarySelection(index)
	temporary.damageMeterType = normalizeDamageMeterTypeKey(damageMeterType)
	self:InvalidateLiveEventWatch()
	self:ScheduleRefresh()
end

function DamageMeter:GetAvailableCombatSessions()
	if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return {} end
	local sessions = C_DamageMeter.GetAvailableCombatSessions()
	return type(sessions) == "table" and sessions or {}
end

function DamageMeter:SetTemporarySessionType(index, sessionType)
	local temporary = self:GetTemporarySelection(index)
	temporary.sessionID = nil
	temporary.sessionName = nil
	temporary.sessionDurationSeconds = nil
	temporary.sessionType = sessionType == "overall" and "overall" or "current"
	self:InvalidateLiveEventWatch()
	self:ScheduleRefresh()
end

function DamageMeter:SetTemporarySessionID(index, sessionID, sessionName, durationSeconds)
	sessionID = tonumber(sessionID)
	if not sessionID then return end
	local temporary = self:GetTemporarySelection(index)
	temporary.sessionType = nil
	temporary.sessionID = sessionID
	temporary.sessionName = sessionName
	temporary.sessionDurationSeconds = durationSeconds
	self:InvalidateLiveEventWatch()
	self:ScheduleRefresh()
end

function DamageMeter:ClearTemporarySelection(index)
	self.temporarySelections = self.temporarySelections or {}
	self.temporarySelections[index] = nil
	self:InvalidateLiveEventWatch()
	self:ScheduleRefresh()
end

function DamageMeter:IsEnabled()
	return db().damageMeterEnabled == true
end

function DamageMeter:IsWindowEnabled(index)
	return self:IsEnabled() and index <= getWindowCount()
end

function DamageMeter:IsAvailable()
	if not C_DamageMeter or not C_DamageMeter.IsDamageMeterAvailable then return false end
	return C_DamageMeter.IsDamageMeterAvailable() == true
end

function DamageMeter:IsInEditMode()
	return EditMode and EditMode.IsInEditMode and EditMode:IsInEditMode()
end

function DamageMeter:UsePreviewData()
	return self:IsInEditMode() and db().damageMeterEditModeSample ~= false
end

function DamageMeter:ShouldShow(index)
	if not self:IsWindowEnabled(index) then return false end
	if self:IsInEditMode() then return true end
	if not self:IsAvailable() then return false end
	local visibility = self:GetConfig(index).visibility
	if visibility == "combat" then return UnitAffectingCombat("player") == true end
	return true
end

function DamageMeter:BuildRefreshSharedState()
	local shared = self.refreshSharedState
	if not shared then
		shared = {}
		self.refreshSharedState = shared
	end
	local editMode = self:IsInEditMode()
	local preview = editMode and db().damageMeterEditModeSample ~= false
	local enabled = self:IsEnabled()
	local available = preview or (enabled and self:IsAvailable())
	shared.available = available
	shared.editMode = editMode
	shared.enabled = enabled
	shared.inFollowerDungeon = isInFollowerDungeon()
	shared.preview = preview
	shared.windowCount = getWindowCount()
	return shared
end

function DamageMeter:BuildWindowRefreshState(index, shared)
	shared = shared or self:BuildRefreshSharedState()
	self.refreshWindowStates = self.refreshWindowStates or {}
	local state = self.refreshWindowStates[index]
	if not state then
		state = {}
		self.refreshWindowStates[index] = state
	end
	local config = self:GetConfig(index)
	local temporary = self.temporarySelections and self.temporarySelections[index]
	local damageMeterType = normalizeDamageMeterTypeKey((temporary and temporary.damageMeterType) or config.damageMeterType)
	local damageMeterEnum = getDamageMeterTypeValue(damageMeterType)
	local sessionID = temporary and temporary.sessionID or nil
	local sessionType = sessionID and nil or ((temporary and temporary.sessionType) or config.sessionType)
	local sessionEnum = sessionType and (SESSION_TYPES[sessionType] or SESSION_TYPES.current) or nil
	local visible = shared.enabled == true and index <= shared.windowCount
	if visible and not shared.editMode then
		visible = shared.available == true
		if visible and config.visibility == "combat" then
			visible = UnitAffectingCombat("player") == true
		end
	end
	state.available = shared.available
	state.config = config
	state.damageMeterEnum = damageMeterEnum
	state.damageMeterType = damageMeterType
	state.editMode = shared.editMode
	state.index = index
	state.inFollowerDungeon = shared.inFollowerDungeon
	state.preview = shared.preview
	state.sessionEnum = sessionEnum
	state.sessionID = sessionID
	state.sessionType = sessionType
	state.temporary = temporary
	state.visible = visible
	return state
end

function DamageMeter:GetSessionForState(state, sessionCache)
	if state.preview then return PREVIEW_SESSION end
	if not state.available or state.damageMeterEnum == nil then return nil end
	if state.sessionID and C_DamageMeter.GetCombatSessionFromID then
		if sessionCache then
			sessionCache.byID = sessionCache.byID or {}
			local typeCache = sessionCache.byID[state.damageMeterEnum]
			if not typeCache then
				typeCache = {}
				sessionCache.byID[state.damageMeterEnum] = typeCache
			end
			local cached = typeCache[state.sessionID]
			if cached ~= nil then return cached ~= false and cached or nil end
			local session = C_DamageMeter.GetCombatSessionFromID(state.sessionID, state.damageMeterEnum)
			typeCache[state.sessionID] = session or false
			return session
		end
		return C_DamageMeter.GetCombatSessionFromID(state.sessionID, state.damageMeterEnum)
	end
	if not state.sessionEnum or not C_DamageMeter.GetCombatSessionFromType then return nil end
	if sessionCache then
		sessionCache.byType = sessionCache.byType or {}
		local typeCache = sessionCache.byType[state.damageMeterEnum]
		if not typeCache then
			typeCache = {}
			sessionCache.byType[state.damageMeterEnum] = typeCache
		end
		local cached = typeCache[state.sessionEnum]
		if cached ~= nil then return cached ~= false and cached or nil end
		local session = C_DamageMeter.GetCombatSessionFromType(state.sessionEnum, state.damageMeterEnum)
		typeCache[state.sessionEnum] = session or false
		return session
	end
	return C_DamageMeter.GetCombatSessionFromType(state.sessionEnum, state.damageMeterEnum)
end

function DamageMeter:GetSession(index)
	return self:GetSessionForState(self:BuildWindowRefreshState(index))
end

function DamageMeter:ClearRefreshSessionCache(cache)
	if not cache then return end
	if cache.byID then
		for damageMeterType, sessions in pairs(cache.byID) do
			if type(sessions) == "table" then
				for sessionID in pairs(sessions) do
					sessions[sessionID] = nil
				end
			else
				cache.byID[damageMeterType] = nil
			end
		end
	end
	if cache.byType then
		for damageMeterType, sessions in pairs(cache.byType) do
			if type(sessions) == "table" then
				for sessionType in pairs(sessions) do
					sessions[sessionType] = nil
				end
			else
				cache.byType[damageMeterType] = nil
			end
		end
	end
end

function DamageMeter:BuildLiveEventWatch()
	local typeWatch = self.liveEventTypeWatch
	if not typeWatch then
		typeWatch = {}
		self.liveEventTypeWatch = typeWatch
	else
		for key in pairs(typeWatch) do
			typeWatch[key] = nil
		end
	end
	local allSessionWatch = self.liveEventAllSessionWatch
	if not allSessionWatch then
		allSessionWatch = {}
		self.liveEventAllSessionWatch = allSessionWatch
	else
		for key in pairs(allSessionWatch) do
			allSessionWatch[key] = nil
		end
	end
	local sessionWatch = self.liveEventSessionWatch
	if not sessionWatch then
		sessionWatch = {}
		self.liveEventSessionWatch = sessionWatch
	else
		for key in pairs(sessionWatch) do
			sessionWatch[key] = nil
		end
	end
	if self:IsEnabled() then
		for index = 1, getWindowCount() do
			local damageMeterType = getDamageMeterTypeValue(self:GetEffectiveDamageMeterType(index))
			if damageMeterType ~= nil then
				typeWatch[damageMeterType] = true
				local sessionID = self:GetEffectiveSessionID(index)
				if sessionID then
					local sessions = sessionWatch[damageMeterType]
					if not sessions then
						sessions = {}
						sessionWatch[damageMeterType] = sessions
					end
					sessions[sessionID] = true
				else
					allSessionWatch[damageMeterType] = true
				end
			end
		end
	end
	self.liveEventWatchDirty = false
end

function DamageMeter:IsLiveEventRelevant(damageMeterType, sessionID)
	if damageMeterType == nil then return true end
	if self.liveEventWatchDirty or not self.liveEventTypeWatch then
		self:BuildLiveEventWatch()
	end
	if not self.liveEventTypeWatch[damageMeterType] then return false end
	if self.liveEventAllSessionWatch[damageMeterType] then return true end
	local sessions = self.liveEventSessionWatch[damageMeterType]
	return sessionID ~= nil and sessions and sessions[sessionID] == true
end

function DamageMeter:GetSessionDuration(index, session, state)
	state = state or self:BuildWindowRefreshState(index)
	if session then
		local duration = session.durationSeconds
		if duration and not isSecret(duration) then return safeNumber(duration) end
	end
	if state.preview then return PREVIEW_SESSION.durationSeconds end
	if state.sessionID then
		return safeNumber(state.temporary and state.temporary.sessionDurationSeconds)
	end
	if state.sessionEnum and C_DamageMeter and C_DamageMeter.GetSessionDurationSeconds then
		local duration = C_DamageMeter.GetSessionDurationSeconds(state.sessionEnum)
		if not isSecret(duration) then return safeNumber(duration) end
	end
	return nil
end

function DamageMeter:InvalidatePartyClassFallback()
	self.partyClassGeneration = (self.partyClassGeneration or 0) + 1
	self.partyClassCache = nil
end

function DamageMeter:MarkPartyClassFallbackCurrent()
	self.currentPartyClassGeneration = self.partyClassGeneration or 0
end

function DamageMeter:CanUsePartyClassFallback(index)
	if self:UsePreviewData() then return false end
	if self:GetEffectiveSessionID(index) then return false end
	if self:GetEffectiveSessionType(index) ~= "current" then return false end
	return (self.currentPartyClassGeneration or 0) == (self.partyClassGeneration or 0)
end

function DamageMeter:GetUniquePartyUnitTokenForClass(classFilename)
	if type(classFilename) ~= "string" or classFilename == "" then return nil end
	if IsInRaid and IsInRaid() then return nil end
	if not UnitExists or not UnitClass then return nil end
	self.partyClassCache = self.partyClassCache or {}
	for key in pairs(self.partyClassCache) do
		self.partyClassCache[key] = nil
	end
	for _, unitToken in ipairs(PARTY_UNIT_TOKENS) do
		if UnitExists(unitToken) then
			local _, unitClassFilename = UnitClass(unitToken)
			if type(unitClassFilename) == "string" and unitClassFilename ~= "" then
				local entry = self.partyClassCache[unitClassFilename]
				if entry then
					entry.duplicate = true
				else
					self.partyClassCache[unitClassFilename] = { token = unitToken, duplicate = false }
				end
			end
		end
	end
	local entry = self.partyClassCache[classFilename]
	if entry and not entry.duplicate and entry.token ~= "player" then return entry.token end
	return nil
end

function DamageMeter:GetUnitTokenGUID(unitToken)
	if not unitToken or not UnitGUID then return nil end
	local guid = UnitGUID(unitToken)
	if guid and not isSecret(guid) then return guid end
	return nil
end

function DamageMeter:HasSourceSpellDetails(details)
	return type(details) == "table" and type(details.combatSpells) == "table" and #details.combatSpells > 0
end

function DamageMeter:GetSourceDetails(index, source)
	if self:UsePreviewData() then return PREVIEW_SOURCE_DETAILS end
	if not source or not self:IsAvailable() then return nil end
	local damageMeterType = getDamageMeterTypeValue(self:GetEffectiveDamageMeterType(index))
	if damageMeterType == nil then return nil end
	local sessionID = self:GetEffectiveSessionID(index)
	local rawSourceGUID = source.sourceGUID
	local rawSourceCreatureID = source.sourceCreatureID
	local sourceGUID = not isSecret(rawSourceGUID) and rawSourceGUID or nil
	local sourceCreatureID = not isSecret(rawSourceCreatureID) and rawSourceCreatureID or nil
	local isLocalPlayer = source.isLocalPlayer == true
	local isRestrictedSource = isSecret(source.name) or isSecret(rawSourceGUID) or isSecret(rawSourceCreatureID)
	local partyUnitToken = isRestrictedSource and not isLocalPlayer and self:CanUsePartyClassFallback(index) and self:GetUniquePartyUnitTokenForClass(source.classFilename) or nil
	if sourceGUID == nil and sourceCreatureID == nil and not isLocalPlayer and not partyUnitToken then return nil end
	if sessionID and C_DamageMeter.GetCombatSessionSourceFromID then
		local emptyLocalDetails
		local details = C_DamageMeter.GetCombatSessionSourceFromID(sessionID, damageMeterType, sourceGUID, sourceCreatureID)
		if not isLocalPlayer or self:HasSourceSpellDetails(details) then return details end
		emptyLocalDetails = details
		if isLocalPlayer then
			local playerGUID = self:GetUnitTokenGUID("player")
			if playerGUID then
				details = C_DamageMeter.GetCombatSessionSourceFromID(sessionID, damageMeterType, playerGUID, nil)
				return details
			end
			details = C_DamageMeter.GetCombatSessionSourceFromID(sessionID, damageMeterType, nil, nil)
			if self:HasSourceSpellDetails(details) then return details end
		end
		local partyGUID = self:GetUnitTokenGUID(partyUnitToken)
		if partyGUID then
			details = C_DamageMeter.GetCombatSessionSourceFromID(sessionID, damageMeterType, partyGUID, nil)
			return details
		end
		if emptyLocalDetails then return emptyLocalDetails end
		return nil
	end
	local sessionType = SESSION_TYPES[self:GetEffectiveSessionType(index)] or SESSION_TYPES.current
	if sessionType and C_DamageMeter.GetCombatSessionSourceFromType then
		local emptyLocalDetails
		local details = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, damageMeterType, sourceGUID, sourceCreatureID)
		if not isLocalPlayer or self:HasSourceSpellDetails(details) then return details end
		emptyLocalDetails = details
		if isLocalPlayer then
			local playerGUID = self:GetUnitTokenGUID("player")
			if playerGUID then
				details = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, damageMeterType, playerGUID, nil)
				return details
			end
			details = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, damageMeterType, nil, nil)
			if self:HasSourceSpellDetails(details) then return details end
		end
		local partyGUID = self:GetUnitTokenGUID(partyUnitToken)
		if partyGUID then
			details = C_DamageMeter.GetCombatSessionSourceFromType(sessionType, damageMeterType, partyGUID, nil)
			return details
		end
		if emptyLocalDetails then return emptyLocalDetails end
	end
	return nil
end

local function getRaidClassColor(classFilename)
	if type(classFilename) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename] then
		return RAID_CLASS_COLORS[classFilename]
	end
end

local function getClassOrCustomColor(classFilename, customColor, defaultColor, useClassColor)
	local r, g, b, a = colorComponents(customColor, defaultColor)
	local classColor = useClassColor == true and getRaidClassColor(classFilename)
	if classColor then
		return classColor.r or 1, classColor.g or 1, classColor.b or 1, a
	end
	return r, g, b, a
end

function DamageMeter:GetClassColor(config, classFilename)
	if config.useClassColors ~= true then return 0.22, 0.56, 0.9 end
	local color = getRaidClassColor(classFilename)
	if color then
		return color.r or 1, color.g or 1, color.b or 1
	end
	return 0.55, 0.55, 0.55
end

function DamageMeter:GetNameColor(config, classFilename)
	return getClassOrCustomColor(classFilename, config.nameColor, DEFAULT_WINDOW.nameColor, config.nameUseClassColors)
end

function DamageMeter:GetValueColor(config, classFilename)
	return getClassOrCustomColor(classFilename, config.valueColor, DEFAULT_WINDOW.valueColor, config.valueUseClassColors)
end

function DamageMeter:GetRowColorState(frame, config, classFilename)
	local styleVersion = self:GetWindowStyleVersion(frame.index or 0)
	local cache = frame._damageMeterRowColorCache
	if not cache or cache.styleVersion ~= styleVersion then
		cache = { styleVersion = styleVersion, byClass = {} }
		frame._damageMeterRowColorCache = cache
	end
	local classKey = type(classFilename) == "string" and classFilename ~= "" and classFilename or false
	local entry = cache.byClass[classKey]
	if entry then return entry end
	local r, g, b = self:GetClassColor(config, classKey)
	local nr, ng, nb, na = self:GetNameColor(config, classKey)
	local vr, vg, vb, va = self:GetValueColor(config, classKey)
	entry = {
		r = r, g = g, b = b,
		nr = nr, ng = ng, nb = nb, na = na,
		vr = vr, vg = vg, vb = vb, va = va,
	}
	cache.byClass[classKey] = entry
	return entry
end

local function applyCachedFontString(fontString, fontFace, size, fontOutline, cachePrefix)
	local globalFontVersion = getGlobalFontStateVersion()
	cachePrefix = cachePrefix or "font"
	if fontString._damageMeterFontPrefix == cachePrefix
		and fontString._damageMeterFontFace == fontFace
		and fontString._damageMeterFontSize == size
		and fontString._damageMeterFontOutline == fontOutline
		and fontString._damageMeterFontGlobalVersion == globalFontVersion then
		return
	end
	fontString._damageMeterFontPrefix = cachePrefix
	fontString._damageMeterFontFace = fontFace
	fontString._damageMeterFontSize = size
	fontString._damageMeterFontOutline = fontOutline
	fontString._damageMeterFontGlobalVersion = globalFontVersion
	if addon.functions.ApplyFontString then
		addon.functions.ApplyFontString(fontString, fontFace, size, fontOutline, DEFAULT_FONT, "OUTLINE")
		return
	end
	local font = resolveFont(fontFace)
	local style = resolveStyle(fontOutline)
	fontString:SetFont(font, size, style)
end

function DamageMeter:ApplyFontString(fontString, config)
	applyCachedFontString(fontString, config.fontFace, clampNumber(config.fontSize, 8, 24, 11), config.fontOutline, "name")
end

function DamageMeter:ApplyRankFontString(fontString, config)
	applyCachedFontString(fontString, config.rankFontFace, clampNumber(config.rankFontSize, 8, 24, DEFAULT_WINDOW.rankFontSize), config.rankFontOutline, "rank")
end

function DamageMeter:ApplyValueFontString(fontString, config)
	applyCachedFontString(fontString, config.valueFontFace, clampNumber(config.valueFontSize, 8, 24, DEFAULT_WINDOW.valueFontSize), config.valueFontOutline, "value")
end

function DamageMeter:ApplyTitleFontString(fontString, config)
	applyCachedFontString(fontString, config.titleFontFace, clampNumber(config.titleFontSize, 8, 28, DEFAULT_WINDOW.titleFontSize), config.titleFontOutline, "title")
end

function DamageMeter:ApplyStatusFontString(fontString, config)
	applyCachedFontString(fontString, config.statusFontFace, clampNumber(config.statusFontSize, 8, 24, DEFAULT_WINDOW.statusFontSize), config.statusFontOutline, "status")
end

function DamageMeter:ApplyTooltipFontString(fontString, config)
	applyCachedFontString(fontString, config.fontFace, clampNumber(config.tooltipFontSize, 8, 24, DEFAULT_WINDOW.tooltipFontSize), config.fontOutline, "tooltip")
end

function DamageMeter:ApplyBarBorder(row, config, classFilename)
	local border = row.barBorder
	if not border or not border.SetBackdrop then return end
	local enabled = config.barBorderEnabled == true
	local classKey = enabled and config.barBorderUseClassColor == true and type(classFilename) == "string" and classFilename ~= "" and classFilename or false
	local styleVersion = self:GetWindowStyleVersion(row.windowIndex or 0)
	if border._damageMeterApplyVersion == styleVersion
		and border._damageMeterApplyEnabled == enabled
		and border._damageMeterApplyClassKey == classKey then
		setShownIfChanged(border, enabled)
		return
	end
	border._damageMeterApplyVersion = styleVersion
	border._damageMeterApplyEnabled = enabled
	border._damageMeterApplyClassKey = classKey
	if config.barBorderEnabled == true then
		local size = clampNumber(config.barBorderSize, 1, 32, DEFAULT_WINDOW.barBorderSize)
		local br, bg, bb, ba = getClassOrCustomColor(classKey, config.barBorderColor, DEFAULT_WINDOW.barBorderColor, config.barBorderUseClassColor)
		if border._damageMeterBackdropEnabled ~= true
			or border._damageMeterBackdropTexture ~= config.barBorderTexture
			or border._damageMeterBackdropSize ~= size then
			border._damageMeterBackdropEnabled = true
			border._damageMeterBackdropTexture = config.barBorderTexture
			border._damageMeterBackdropSize = size
			local borderTexture = resolveMedia("border", config.barBorderTexture, DEFAULT_BORDER)
			border:SetBackdrop({
				edgeFile = borderTexture,
				edgeSize = size,
			})
		end
		if border._damageMeterBorderColorR ~= br
			or border._damageMeterBorderColorG ~= bg
			or border._damageMeterBorderColorB ~= bb
			or border._damageMeterBorderColorA ~= ba then
			border._damageMeterBorderColorR = br
			border._damageMeterBorderColorG = bg
			border._damageMeterBorderColorB = bb
			border._damageMeterBorderColorA = ba
			border:SetBackdropBorderColor(br, bg, bb, ba)
		end
		setShownIfChanged(border, true)
	else
		if border._damageMeterBackdropEnabled ~= false then
			border._damageMeterBackdropEnabled = false
			border._damageMeterBackdropTexture = nil
			border._damageMeterBackdropSize = nil
			border._damageMeterBorderColorR = nil
			border._damageMeterBorderColorG = nil
			border._damageMeterBorderColorB = nil
			border._damageMeterBorderColorA = nil
			border:SetBackdrop(nil)
		end
		setShownIfChanged(border, false)
	end
end

function DamageMeter:ApplyIconBorder(row, config, classFilename)
	local border = row.iconBorder
	if not border or not border.SetBackdrop then return end
	local enabled = config.iconBorderEnabled == true
	local classKey = enabled and config.iconBorderUseClassColor == true and type(classFilename) == "string" and classFilename ~= "" and classFilename or false
	local styleVersion = self:GetWindowStyleVersion(row.windowIndex or 0)
	if border._damageMeterApplyVersion == styleVersion
		and border._damageMeterApplyEnabled == enabled
		and border._damageMeterApplyClassKey == classKey then
		setShownIfChanged(border, enabled)
		return
	end
	border._damageMeterApplyVersion = styleVersion
	border._damageMeterApplyEnabled = enabled
	border._damageMeterApplyClassKey = classKey
	if config.iconBorderEnabled == true then
		local size = clampNumber(config.iconBorderSize, 1, 32, DEFAULT_WINDOW.iconBorderSize)
		local br, bg, bb, ba = getClassOrCustomColor(classKey, config.iconBorderColor, DEFAULT_WINDOW.iconBorderColor, config.iconBorderUseClassColor)
		if border._damageMeterBackdropEnabled ~= true
			or border._damageMeterBackdropTexture ~= config.iconBorderTexture
			or border._damageMeterBackdropSize ~= size then
			border._damageMeterBackdropEnabled = true
			border._damageMeterBackdropTexture = config.iconBorderTexture
			border._damageMeterBackdropSize = size
			local borderTexture = resolveMedia("border", config.iconBorderTexture, DEFAULT_BORDER)
			border:SetBackdrop({
				edgeFile = borderTexture,
				edgeSize = size,
			})
		end
		if border._damageMeterBorderColorR ~= br
			or border._damageMeterBorderColorG ~= bg
			or border._damageMeterBorderColorB ~= bb
			or border._damageMeterBorderColorA ~= ba then
			border._damageMeterBorderColorR = br
			border._damageMeterBorderColorG = bg
			border._damageMeterBorderColorB = bb
			border._damageMeterBorderColorA = ba
			border:SetBackdropBorderColor(br, bg, bb, ba)
		end
		setShownIfChanged(border, true)
	else
		if border._damageMeterBackdropEnabled ~= false then
			border._damageMeterBackdropEnabled = false
			border._damageMeterBackdropTexture = nil
			border._damageMeterBackdropSize = nil
			border._damageMeterBorderColorR = nil
			border._damageMeterBorderColorG = nil
			border._damageMeterBorderColorB = nil
			border._damageMeterBorderColorA = nil
			border:SetBackdrop(nil)
		end
		setShownIfChanged(border, false)
	end
end

function DamageMeter:ApplyRowTextLayout(row, config)
	local rowMode = config.raidRowsEnabled == true and IsInRaid() and "raid" or "default"
	local styleVersion = self:GetWindowStyleVersion(row.windowIndex or 0)
	if row._damageMeterTextLayoutStyleVersion == styleVersion
		and row._damageMeterTextLayoutRowMode == rowMode then
		return
	end
	row._damageMeterTextLayoutStyleVersion = styleVersion
	row._damageMeterTextLayoutRowMode = rowMode

	local _, barHeight = getRowMetrics(config)
	local borderOutset = getBarBorderOutset(config)
	local leftInset, rightInset, iconSize, rankWidth, rankGap = getRowTextInsets(config)
	local showRankColumn = config.showRanks ~= false and rankWidth > 0
	row.rank:SetWidth(rankWidth)
	setShownIfChanged(row.rank, showRankColumn)
	row.iconFrame:SetSize(iconSize, iconSize)
	row.iconFrame:ClearAllPoints()
	if showRankColumn then
		row.iconFrame:SetPoint("LEFT", row.rank, "RIGHT", rankGap, 0)
	else
		row.iconFrame:SetPoint("LEFT", 4, 0)
	end
	row.iconBorder:ClearAllPoints()
	local iconBorderOffset = getIconBorderOutset(config)
	row.iconBorder:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", -iconBorderOffset, iconBorderOffset)
	row.iconBorder:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", iconBorderOffset, -iconBorderOffset)
	row.iconBorder:SetFrameLevel(row.iconFrame:GetFrameLevel() + 2)
	row.bar:ClearAllPoints()
	row.bar:SetPoint("LEFT", row.iconFrame, "RIGHT", 4, 0)
	row.bar:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.bar:SetHeight(barHeight)
	if normalizeAnchorV(config.barAnchor) == "TOP" then
		row.bar:SetPoint("TOP", row, "TOP", 0, -borderOutset)
	elseif normalizeAnchorV(config.barAnchor) == "BOTTOM" then
		row.bar:SetPoint("BOTTOM", row, "BOTTOM", 0, borderOutset)
	else
		row.bar:SetPoint("CENTER", row, "CENTER", 0, 0)
	end
	row.barBorder:ClearAllPoints()
	local borderOffset = clampNumber(config.barBorderInset, 0, 24, DEFAULT_WINDOW.barBorderInset)
	row.barBorder:SetPoint("TOPLEFT", row.bar, "TOPLEFT", -borderOffset, borderOffset)
	row.barBorder:SetPoint("BOTTOMRIGHT", row.bar, "BOTTOMRIGHT", borderOffset, -borderOffset)
	row.barBorder:SetFrameLevel(row.bar:GetFrameLevel() + 2)
	row.textArea:ClearAllPoints()
	row.textArea:SetPoint("TOPLEFT", row, "TOPLEFT", leftInset, 0)
	row.textArea:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -rightInset, 0)
	setShownIfChanged(row.name, config.showNames == true)
end

function DamageMeter:ApplyRowValueWidth(row, config, damageMeterType)
	damageMeterType = damageMeterType or config.damageMeterType
	local rowMode = config.raidRowsEnabled == true and IsInRaid() and "raid" or "default"
	local styleVersion = self:GetWindowStyleVersion(row.windowIndex or 0)
	if row._damageMeterValueLayoutStyleVersion == styleVersion
		and row._damageMeterValueLayoutRowMode == rowMode
		and row._damageMeterValueLayoutType == damageMeterType then
		return
	end
	row._damageMeterValueLayoutStyleVersion = styleVersion
	row._damageMeterValueLayoutRowMode = rowMode
	row._damageMeterValueLayoutType = damageMeterType

	local frameWidth = clampNumber(config.width, 220, 700, DEFAULT_WINDOW.width)
	local leftInset, rightInset = getRowTextInsets(config)
	local availableWidth = math.max(1, (frameWidth - 8) - leftInset - rightInset)
	local minNameWidth = config.showNames == false and 0 or 24
	local nameGap = config.showNames == false and 0 or 8
	local maxValueWidth = math.max(1, availableWidth - minNameWidth - nameGap)
	local valueFontSize = clampNumber(config.valueFontSize, 8, 24, DEFAULT_WINDOW.valueFontSize)
	local estimatedCharacters
	if isCountOnlyMeterType(damageMeterType) then
		estimatedCharacters = config.showPercent ~= false and 10 or 4
	elseif config.showPercent ~= false then
		estimatedCharacters = config.valueFormat == "parentheses" and 19 or 21
	else
		estimatedCharacters = config.valueFormat == "parentheses" and 13 or 15
	end
	local valueTargetWidth = math.ceil((valueFontSize * estimatedCharacters * 0.62) + 12)
	local minValueWidth = isCountOnlyMeterType(damageMeterType) and 42 or (config.valueFormat == "parentheses" and 76 or 86)
	local valueWidth = math.min(math.max(minValueWidth, valueTargetWidth), maxValueWidth)
	local nameWidth = math.max(minNameWidth, availableWidth - valueWidth - nameGap)
	row.value:SetWidth(valueWidth)
	row.name:SetWidth(nameWidth)

	row.value:ClearAllPoints()
	row.name:ClearAllPoints()
	if isDefaultTextLayout(config) then
		row.value:SetPoint("RIGHT", row.textArea, "RIGHT", DEFAULT_WINDOW.valueOffsetX, DEFAULT_WINDOW.valueOffsetY)
		row.value:SetJustifyH("RIGHT")
		row.name:SetPoint("LEFT", row.textArea, "LEFT", DEFAULT_WINDOW.nameOffsetX, DEFAULT_WINDOW.nameOffsetY)
		row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
		row.name:SetJustifyH("LEFT")
	else
		local valueH = normalizeAnchorH(config.valueAnchorH)
		local valueV = normalizeAnchorV(config.valueAnchorV)
		local nameH = normalizeAnchorH(config.nameAnchorH)
		local nameV = normalizeAnchorV(config.nameAnchorV)
		row.value:SetPoint(anchorPoint(valueH, valueV), row.textArea, anchorPoint(valueH, valueV), clampNumber(config.valueOffsetX, -200, 200, DEFAULT_WINDOW.valueOffsetX), clampNumber(config.valueOffsetY, -200, 200, DEFAULT_WINDOW.valueOffsetY))
		row.value:SetJustifyH(justifyFromAnchor(valueH))
		row.name:SetPoint(anchorPoint(nameH, nameV), row.textArea, anchorPoint(nameH, nameV), clampNumber(config.nameOffsetX, -200, 200, DEFAULT_WINDOW.nameOffsetX), clampNumber(config.nameOffsetY, -200, 200, DEFAULT_WINDOW.nameOffsetY))
		row.name:SetJustifyH(justifyFromAnchor(nameH))
	end
end

function DamageMeter:ApplyRankText(row, rowIndex, config)
	local rankWidth = getEffectiveRankWidth(config)
	if config.showRanks == false or config.prefixRankInName == true or rankWidth <= 0 then
		row.rank:SetText("")
		return
	end

	local text = rowIndex .. "."
	row.rank:SetText(text)
end

function DamageMeter:ShowTooltip(owner, text)
	if not GameTooltip or not text then return end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(text)
	GameTooltip:Show()
end

function DamageMeter:CreateContextMenuIconButton(frame, label, tooltipText, onClick)
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(18, 18)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(owner)
		button.bg:SetColorTexture(0.18, 0.18, 0.18, 0.95)
		self:ShowTooltip(owner, tooltipText)
	end)
	button:SetScript("OnLeave", function()
		button.bg:SetColorTexture(0.07, 0.07, 0.07, 0.85)
		if GameTooltip then GameTooltip:Hide() end
	end)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetColorTexture(0.07, 0.07, 0.07, 0.85)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetAllPoints()
	button.text:SetJustifyH("CENTER")
	button.text:SetText(label)
	return button
end

function DamageMeter:CreateHeaderButton(frame, label, atlas, tooltipText, onClick)
	local button = CreateFrame("Button", nil, frame)
	button:SetSize(16, 16)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(owner) self:ShowTooltip(owner, tooltipText) end)
	button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("CENTER")
	button.icon:SetSize(14, 14)
	local hasAtlas = atlas ~= nil
	if hasAtlas then
		button.icon:SetAtlas(atlas)
	end
	button.icon:SetShown(hasAtlas == true)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetAllPoints()
	button.text:SetJustifyH("CENTER")
	button.text:SetText(label)
	button.text:SetShown(hasAtlas ~= true)
	return button
end

function DamageMeter:ApplyHeaderButtons(frame, config, showHeaderButtons)
	local buttonSize = clampNumber(config.headerButtonSize, 10, 32, DEFAULT_WINDOW.headerButtonSize)
	local gap = math.max(2, math.floor(buttonSize / 4))
	local iconSize = math.max(8, buttonSize - 2)
	local signature = buttonSize .. ":" .. gap .. ":" .. iconSize .. ":" .. tostring(showHeaderButtons == true)
	if frame.headerButtons._damageMeterHeaderButtonsSignature ~= signature then
		frame.headerButtons._damageMeterHeaderButtonsSignature = signature
		frame.headerButtons:SetSize((buttonSize * 2) + gap, buttonSize)
		frame.resetButton:SetSize(buttonSize, buttonSize)
		frame.historyButton:SetSize(buttonSize, buttonSize)
		frame.resetButton.icon:SetSize(iconSize, iconSize)
		frame.historyButton.icon:SetSize(iconSize, iconSize)
		frame.resetButton:ClearAllPoints()
		frame.resetButton:SetPoint("RIGHT", frame.headerButtons, "RIGHT", 0, 0)
		frame.historyButton:ClearAllPoints()
		frame.historyButton:SetPoint("RIGHT", frame.resetButton, "LEFT", -gap, 0)
		setShownIfChanged(frame.headerButtons, showHeaderButtons)
		setShownIfChanged(frame.resetButton, showHeaderButtons)
		setShownIfChanged(frame.historyButton, showHeaderButtons)
	end
	return showHeaderButtons and ((buttonSize * 2) + gap + 12) or 8
end

function DamageMeter:EnsureContextMenu()
	if self.contextMenu then return self.contextMenu end
	local frame = CreateFrame("Frame", "EnhanceQoLDamageMeterContextMenu", UIParent, "BackdropTemplate")
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(80)
	frame:SetClampedToScreen(true)
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetWidth(CONTEXT_MENU_WIDTH)
	frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	frame:SetBackdropColor(0.015, 0.016, 0.018, 0.94)
	frame:SetBackdropBorderColor(0.16, 0.18, 0.2, 0.9)
	frame:Hide()
	frame.buttons = {}
	frame.clickCatcher = CreateFrame("Button", nil, UIParent)
	frame.clickCatcher:SetFrameStrata("DIALOG")
	frame.clickCatcher:SetFrameLevel(79)
	frame.clickCatcher:SetAllPoints(UIParent)
	frame.clickCatcher:EnableMouse(true)
	frame.clickCatcher:RegisterForClicks("AnyUp")
	frame.clickCatcher:SetScript("OnClick", function() self:HideContextMenu() end)
	frame.clickCatcher:Hide()
	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.title:SetJustifyH("LEFT")
	frame.title:SetWordWrap(false)
	frame.addLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.addLabel:SetJustifyH("CENTER")
	frame.addLabel:SetWordWrap(false)
	frame.modeHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.modeHint:SetJustifyH("RIGHT")
	frame.modeHint:SetWordWrap(false)
	frame.resetButton = self:CreateContextMenuIconButton(frame, "R", L["damageMeterResetData"] or "Reset data", function()
		self:HideContextMenu()
		self:PromptResetData()
	end)
	frame.historyButton = self:CreateContextMenuIconButton(frame, "H", L["damageMeterShowHistory"] or "Show history", function()
		local owner = frame.owner or frame
		local index = frame.index or 1
		self:HideContextMenu()
		self:OpenHistoryMenu(owner, index)
	end)
	frame.clearButton = self:CreateContextMenuIconButton(frame, "X", L["damageMeterResetTemporarySelection"] or "Reset temporary selection", function()
		local index = frame.index or 1
		self:HideContextMenu()
		self:ClearTemporarySelection(index)
	end)
	frame:SetScript("OnHide", function()
		if GameTooltip then GameTooltip:Hide() end
		if frame.clickCatcher then frame.clickCatcher:Hide() end
	end)
	if UISpecialFrames then
		UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
	end
	self.contextMenu = frame
	return frame
end

function DamageMeter:HideContextMenu()
	if self.contextMenu then
		if self.contextMenu.clickCatcher then self.contextMenu.clickCatcher:Hide() end
		self.contextMenu.owner = nil
		self.contextMenu.index = nil
		self.contextMenu:Hide()
	end
end

function DamageMeter:IsContextMenuOpenFor(index)
	local frame = self.contextMenu
	return frame and frame:IsShown() and (tonumber(index) or 1) == (tonumber(frame.index) or 1)
end

function DamageMeter:GetContextMenuButton(frame, buttonIndex)
	local button = frame.buttons[buttonIndex]
	if button then return button end
	button = CreateFrame("Button", nil, frame)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	button:SetHeight(CONTEXT_MENU_BUTTON_HEIGHT)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.bg:SetColorTexture(0.06, 0.065, 0.07, 0.92)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("LEFT", 9, 0)
	button.icon:SetSize(18, 18)
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
	button.text:SetPoint("RIGHT", -28, 0)
	button.text:SetJustifyH("LEFT")
	button.text:SetWordWrap(false)
	button.rightText = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	button.rightText:SetPoint("RIGHT", -8, 0)
	button.rightText:SetJustifyH("RIGHT")
	button.rightText:SetWordWrap(false)
	button.removeButton = CreateFrame("Button", nil, button)
	button.removeButton:SetSize(18, 18)
	button.removeButton:SetPoint("RIGHT", -3, 0)
	button.removeButton:SetFrameLevel(button:GetFrameLevel() + 3)
	button.removeButton:RegisterForClicks("AnyUp")
	button.removeButton.text = button.removeButton:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	button.removeButton.text:SetAllPoints()
	button.removeButton.text:SetJustifyH("CENTER")
	button.removeButton.text:SetText("X")
	button.removeButton.text:SetTextColor(0.55, 0.58, 0.6, 1)
	button.removeButton:SetScript("OnEnter", function(owner)
		owner.text:SetTextColor(1, 0.25, 0.25, 1)
	end)
	button.removeButton:SetScript("OnLeave", function(owner)
		owner.text:SetTextColor(0.55, 0.58, 0.6, 1)
	end)
	button:SetScript("OnEnter", function(owner)
		local selected = owner.selected == true
		owner.bg:SetColorTexture(selected and 0.03 or 0.12, selected and 0.24 or 0.13, selected and 0.21 or 0.15, 0.96)
	end)
	button:SetScript("OnLeave", function(owner)
		if owner.selected == true then
			owner.bg:SetColorTexture(0.02, 0.19, 0.17, 0.95)
		else
			owner.bg:SetColorTexture(0.06, 0.065, 0.07, 0.92)
		end
	end)
	frame.buttons[buttonIndex] = button
	return button
end

function DamageMeter:SetupContextMenuButton(button, label, icon, selected, rightText, onClick, disabled, onRemove)
	button.selected = selected == true
	button.disabled = disabled == true
	button:SetEnabled(disabled ~= true)
	button:SetAlpha(disabled and 0.45 or 1)
	button.bg:SetColorTexture(selected and 0.02 or 0.06, selected and 0.19 or 0.065, selected and 0.17 or 0.07, selected and 0.95 or 0.92)
	button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	button.text:SetText(label or "")
	button.rightText:SetText(rightText or "")
	button:SetScript("OnClick", onClick)
	button.removeButton:SetShown(type(onRemove) == "function")
	button.removeButton:SetScript("OnClick", onRemove)
	button:Show()
end

function DamageMeter:AnchorContextMenu(frame, owner)
	frame:ClearAllPoints()
	if GetCursorPosition and UIParent and UIParent.GetEffectiveScale then
		local scale = UIParent:GetEffectiveScale()
		local cursorX, cursorY = GetCursorPosition()
		if scale and scale > 0 and cursorX and cursorY then
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (cursorX / scale) + 6, (cursorY / scale) - 6)
			return
		end
	end
	frame:SetPoint("TOPLEFT", owner or UIParent, "BOTTOMLEFT", 0, -4)
end

function DamageMeter:RefreshContextMenu(owner, index, keepAnchor)
	local frame = self:EnsureContextMenu()
	index = tonumber(index) or 1
	frame.owner = owner or frame.owner
	frame.index = index

	local effectiveType = self:GetEffectiveDamageMeterType(index)
	local typeLabel = getDamageMeterTypeLabel(effectiveType)
	local durationText = formatDuration(self:GetSessionDuration(index, self:GetSession(index)), "clock")
	frame.title:SetText(durationText and string.format("%s (%s)", typeLabel, durationText) or typeLabel)

	local pad = CONTEXT_MENU_PADDING
	local y = -pad
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", pad, y)
	frame.title:SetPoint("TOPRIGHT", -84, y)
	frame.title:SetHeight(18)
	frame.clearButton:ClearAllPoints()
	frame.clearButton:SetPoint("TOPRIGHT", -pad, y + 1)
	frame.historyButton:ClearAllPoints()
	frame.historyButton:SetPoint("RIGHT", frame.clearButton, "LEFT", -4, 0)
	frame.resetButton:ClearAllPoints()
	frame.resetButton:SetPoint("RIGHT", frame.historyButton, "LEFT", -4, 0)
	y = y - 24

	local buttonIndex = 1
	frame.addLabel:SetText(L["damageMeterQuickSwitch"] or "Quick switch")
	frame.addLabel:ClearAllPoints()
	frame.addLabel:SetPoint("TOPLEFT", pad, y + 1)
	frame.addLabel:SetPoint("TOPRIGHT", -pad, y + 1)
	frame.addLabel:SetHeight(16)
	y = y - 20

	local quickTypes = self:GetQuickDamageMeterTypes(index)
	local quickSeen = {}
	for _, quickType in ipairs(quickTypes) do
		quickSeen[quickType] = true
		local button = self:GetContextMenuButton(frame, buttonIndex)
		self:SetupContextMenuButton(button, getDamageMeterTypeLabel(quickType), getDamageMeterTypeIcon(quickType), effectiveType == quickType, nil, function(_, mouseButton)
			if mouseButton == "RightButton" or mouseButton == "MiddleButton" then
				self:RemoveQuickDamageMeterType(index, quickType)
				self:RefreshContextMenu(owner, index, true)
				return
			end
			self:HideContextMenu()
			self:SetTemporaryDamageMeterType(index, quickType)
		end, false, function()
			self:RemoveQuickDamageMeterType(index, quickType)
			self:RefreshContextMenu(owner, index, true)
		end)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", pad, y)
		button:SetPoint("TOPRIGHT", -pad, y)
		buttonIndex = buttonIndex + 1
		y = y - CONTEXT_MENU_BUTTON_HEIGHT - CONTEXT_MENU_BUTTON_GAP
	end

	y = y - CONTEXT_MENU_BUTTON_GAP
	frame.modeHint:SetText(_G.ADD or "Add")
	frame.modeHint:ClearAllPoints()
	frame.modeHint:SetPoint("TOPLEFT", pad, y + 1)
	frame.modeHint:SetPoint("TOPRIGHT", -pad, y + 1)
	frame.modeHint:SetJustifyH("CENTER")
	frame.modeHint:SetHeight(16)
	y = y - 20

	local options = buildDamageMeterTypeOptions()
	local columns = 2
	local columnGap = CONTEXT_MENU_BUTTON_GAP
	local buttonWidth = (CONTEXT_MENU_WIDTH - (pad * 2) - columnGap) / columns
	local addIndex = 0
	for _, option in ipairs(options) do
		if not quickSeen[option.value] then
			addIndex = addIndex + 1
			local button = self:GetContextMenuButton(frame, buttonIndex)
			local optionValue = option.value
			self:SetupContextMenuButton(button, option.label, getDamageMeterTypeIcon(optionValue), false, nil, function()
				self:AddQuickDamageMeterType(index, optionValue)
				self:HideContextMenu()
				self:SetTemporaryDamageMeterType(index, optionValue)
			end)
			button:ClearAllPoints()
			local column = (addIndex - 1) % columns
			local row = math.floor((addIndex - 1) / columns)
			button:SetPoint("TOPLEFT", pad + (column * (buttonWidth + columnGap)), y - (row * (CONTEXT_MENU_BUTTON_HEIGHT + CONTEXT_MENU_BUTTON_GAP)))
			button:SetSize(buttonWidth, CONTEXT_MENU_BUTTON_HEIGHT)
			buttonIndex = buttonIndex + 1
		end
	end
	local rows = addIndex > 0 and math.ceil(addIndex / columns) or 0
	y = y - (rows * (CONTEXT_MENU_BUTTON_HEIGHT + CONTEXT_MENU_BUTTON_GAP))
	for unusedIndex = buttonIndex, #frame.buttons do
		frame.buttons[unusedIndex]:Hide()
	end

	frame:SetHeight(math.abs(y) + pad)
	if keepAnchor ~= true then
		self:AnchorContextMenu(frame, owner)
	end
	if frame.clickCatcher then frame.clickCatcher:Show() end
	frame:Show()
end

function DamageMeter:BuildSessionMenu(index, rootDescription)
	local effectiveSessionID = self:GetEffectiveSessionID(index)
	for _, availableCombatSession in ipairs(self:GetAvailableCombatSessions()) do
		local sessionID = safeNumber(availableCombatSession.sessionID)
		if sessionID then
			local sessionName = safeText(availableCombatSession.name, nil)
			if not sessionName then
				sessionName = DAMAGE_METER_COMBAT_NUMBER and DAMAGE_METER_COMBAT_NUMBER:format(sessionID) or string.format("%s %d", L["damageMeterCombat"] or "Combat", sessionID)
			end
			local durationText = formatHistoryDuration(availableCombatSession.durationSeconds)
			local label = durationText and string.format("%s [%s]", sessionName, durationText) or sessionName
			rootDescription:CreateRadio(label, function(value) return effectiveSessionID == value.sessionID end, function(value) self:SetTemporarySessionID(index, value.sessionID, value.name, value.durationSeconds) end, {
				sessionID = sessionID,
				name = sessionName,
				durationSeconds = safeNumber(availableCombatSession.durationSeconds),
			})
		end
	end

	rootDescription:CreateDivider()
	rootDescription:CreateRadio(L["damageMeterCurrent"] or "Current", function() return not self:GetEffectiveSessionID(index) and self:GetEffectiveSessionType(index) == "current" end, function() self:SetTemporarySessionType(index, "current") end)
	rootDescription:CreateRadio(L["damageMeterOverall"] or "Overall", function() return not self:GetEffectiveSessionID(index) and self:GetEffectiveSessionType(index) == "overall" end, function() self:SetTemporarySessionType(index, "overall") end)
end

function DamageMeter:OpenContextMenu(owner, index)
	if self:IsContextMenuOpenFor(index) then return end
	self:RefreshContextMenu(owner, index)
end

function DamageMeter:OpenHistoryMenu(owner, index)
	if not MenuUtil or not MenuUtil.CreateContextMenu then return end
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_DAMAGE_METER_HISTORY")
		self:BuildSessionMenu(index, rootDescription)
	end)
end

function DamageMeter:EnsureSourceTooltip()
	if self.sourceTooltip then return self.sourceTooltip end
	local frame = CreateFrame("Frame", "EnhanceQoLDamageMeterSourceTooltip", UIParent, "BackdropTemplate")
	frame:SetFrameStrata("TOOLTIP")
	frame:SetFrameLevel(20)
	frame:Hide()
	frame.lines = {}
	self.sourceTooltip = frame
	return frame
end

function DamageMeter:GetTooltipLine(frame, lineIndex)
	local line = frame.lines[lineIndex]
	if line then return line end
	line = CreateFrame("Frame", nil, frame)
	line:SetHeight(18)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetSize(14, 14)
	line.icon:SetPoint("LEFT", 6, 0)
	line.barBG = line:CreateTexture(nil, "BACKGROUND")
	line.bar = line:CreateTexture(nil, "BORDER")
	line.bar:SetPoint("TOPLEFT", line.icon, "TOPRIGHT", 4, 0)
	line.bar:SetPoint("BOTTOMLEFT", line.icon, "BOTTOMRIGHT", 4, 0)
	line.name = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.name:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
	line.name:SetJustifyH("LEFT")
	line.name:SetWordWrap(false)
	line.amount = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.amount:SetJustifyH("RIGHT")
	line.amount:SetWordWrap(false)
	line.dps = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.dps:SetJustifyH("RIGHT")
	line.dps:SetWordWrap(false)
	line.percent = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.percent:SetJustifyH("RIGHT")
	line.percent:SetWordWrap(false)
	frame.lines[lineIndex] = line
	return line
end

function DamageMeter:AnchorSourceTooltip(frame, owner, config)
	frame:ClearAllPoints()
	local anchor = normalizeTooltipAnchor(config.tooltipAnchor)
	local offsetX = clampNumber(config.tooltipOffsetX, -300, 300, DEFAULT_WINDOW.tooltipOffsetX)
	local offsetY = clampNumber(config.tooltipOffsetY, -300, 300, DEFAULT_WINDOW.tooltipOffsetY)
	if anchor == "LEFT" then
		frame:SetPoint("RIGHT", owner, "LEFT", -offsetX, offsetY)
	elseif anchor == "TOP" then
		frame:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", offsetX, offsetY)
	elseif anchor == "BOTTOM" then
		frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", offsetX, -offsetY)
	else
		frame:SetPoint("LEFT", owner, "RIGHT", offsetX, offsetY)
	end
end

local function addTooltipSectionGap(rows)
	rows[#rows + 1] = { spacer = true, heightMultiplier = 0.7 }
end

local function resolveCombatSpellDisplay(spell)
	if not spell then return L["Unknown"] or UNKNOWN or "Unknown", 136243 end
	local spellID = spell.spellID
	local spellName
	local spellIcon
	if spellID and C_Spell then
		if C_Spell.GetSpellInfo then
			local spellInfo = C_Spell.GetSpellInfo(spellID)
			if type(spellInfo) == "table" then
				spellName = spellInfo.name
				spellIcon = spellInfo.iconID
			end
		end
		if not spellName and C_Spell.GetSpellName then
			spellName = C_Spell.GetSpellName(spellID)
		end
		if not spellIcon and C_Spell.GetSpellTexture then
			spellIcon = C_Spell.GetSpellTexture(spellID)
		end
	end
	if not spellName then
		local creatureName = spell.creatureName
		if creatureName and isSecret(creatureName) then
			spellName = creatureName
		elseif creatureName and tostring(creatureName) ~= "" then
			spellName = tostring(creatureName)
		else
			spellName = L["Unknown"] or UNKNOWN or "Unknown"
		end
	end
	return spellName, spellIcon or 136243
end

local function getTooltipColumnVisibility(config, damageMeterType)
	local showAmount = config.tooltipShowAmount ~= false
	local showDPS = config.tooltipShowDPS ~= false
	local showPercent = config.tooltipShowPercent ~= false
	if damageMeterType == "Deaths" or damageMeterType == "Dispels" or damageMeterType == "Interrupts" then
		showDPS = false
	end
	if damageMeterType == "Dps" or damageMeterType == "Hps" then
		showAmount = false
	end
	return showAmount, showDPS, showPercent
end

local function resolveDeathRecapEventDisplay(eventData)
	if type(eventData) ~= "table" then return L["Unknown"] or UNKNOWN or "Unknown", 136243 end
	local eventType = eventData.event
	local spellID = eventData.spellId
	local spellName = eventData.spellName
	local icon
	if eventType == "SWING_DAMAGE" then
		spellID = 88163
		spellName = ACTION_SWING or spellName
	elseif eventType == "ENVIRONMENTAL_DAMAGE" then
		local environmentalType = type(eventData.environmentalType) == "string" and string.upper(eventData.environmentalType) or ""
		spellName = _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. environmentalType] or spellName or eventType
		if environmentalType == "DROWNING" then
			icon = "Interface\\Icons\\spell_shadow_demonbreath"
		elseif environmentalType == "FALLING" then
			icon = "Interface\\Icons\\ability_rogue_quickrecovery"
		elseif environmentalType == "FIRE" or environmentalType == "LAVA" then
			icon = "Interface\\Icons\\spell_fire_fire"
		elseif environmentalType == "SLIME" then
			icon = "Interface\\Icons\\inv_misc_slime_01"
		elseif environmentalType == "FATIGUE" then
			icon = "Interface\\Icons\\ability_creature_cursed_05"
		else
			icon = "Interface\\Icons\\ability_creature_cursed_05"
		end
	end
	if spellID and C_Spell and C_Spell.GetSpellTexture then
		local texture = C_Spell.GetSpellTexture(spellID)
		if texture then icon = texture end
	end
	return spellName or eventType or (L["Unknown"] or UNKNOWN or "Unknown"), icon or 136243
end

function DamageMeter:BuildDeathRecapRows(source, config)
	local rows = {}
	if not C_DeathRecap or not C_DeathRecap.GetRecapEvents or not source then return rows end
	local recapID = source.deathRecapID
	if not recapID or recapID == 0 then return rows end
	local events = C_DeathRecap.GetRecapEvents(recapID)
	if type(events) ~= "table" or #events == 0 then return rows end
	local maxHealth
	if C_DeathRecap.GetRecapMaxHealth then
		maxHealth = C_DeathRecap.GetRecapMaxHealth(recapID)
	end
	maxHealth = safeNumber(maxHealth)
	local showAmount, _, showPercent = getTooltipColumnVisibility(config, "Deaths")
	rows[#rows + 1] = { header = true, name = DEATH_RECAP_TITLE or getDamageMeterTypeLabel("Deaths"), icon = getDamageMeterTypeIcon("Deaths"), amount = showAmount and (L["damageMeterTooltipAmount"] or "Amount"), percent = showPercent and "%" }
	local deathTimestamp = 0
	local maxAmount = 0
	for _, eventData in ipairs(events) do
		local timestamp = safeNumber(eventData.timestamp)
		if timestamp and timestamp > deathTimestamp then deathTimestamp = timestamp end
		local amount = safeNumber(eventData.amount)
		if amount and amount > maxAmount then maxAmount = amount end
	end
	for eventIndex = #events, 1, -1 do
		local eventData = events[eventIndex]
		local spellName, spellIcon = resolveDeathRecapEventDisplay(eventData)
		local timestamp = safeNumber(eventData.timestamp)
		local seconds = timestamp and math.max(0, deathTimestamp - timestamp) or 0
		local amount = safeNumber(eventData.amount)
		local overkill = safeNumber(eventData.overkill)
		local amountText = amount and ("-" .. formatNumber(amount, config.abbreviation)) or nil
		if amountText and overkill and overkill > 0 then
			amountText = string.format("%s (%s %s)", amountText, formatNumber(overkill, config.abbreviation), _G.OVERKILL or "overkill")
		end
		local percent = amount and maxHealth and maxHealth > 0 and (amount / maxHealth * 100) or nil
		rows[#rows + 1] = {
			name = string.format("-%.1fs %s", seconds, spellName),
			icon = spellIcon,
			amount = showAmount and amountText,
			percent = showPercent and percent and string.format("%.0f%%", percent),
			sortAmount = amount or 0,
			barValue = amount,
			barMax = maxAmount,
		}
	end
	return rows
end

function DamageMeter:BuildTooltipRows(details, config, damageMeterType)
	local rows = {}
	if not details or type(details.combatSpells) ~= "table" then return rows end
	local showAmount, showDPS, showPercent = getTooltipColumnVisibility(config, damageMeterType)
	local showTargets = config.tooltipShowTargets ~= false
	local spellLimit = clampNumber(config.tooltipMaxLines, 4, 30, DEFAULT_WINDOW.tooltipMaxLines)
	local totalAmount = safeNumber(details.totalAmount)
	local showSpellSection = damageMeterType ~= "EnemyDamageTaken"

	if showSpellSection then
		rows[#rows + 1] = { header = true, name = L["damageMeterTooltipSpellName"] or "Spell Name", icon = "Interface\\WORLDSTATEFRAME\\CombatSwords", amount = showAmount and (L["damageMeterTooltipAmount"] or "Amount"), dps = showDPS and (L["damageMeterTooltipDPS"] or "DPS"), percent = showPercent and "%" }
	end
	local targetMap = {}
	local spellMaxAmount = 0
	local spellMaxScanRows = 0
	for _, spell in ipairs(details.combatSpells) do
		if spellMaxScanRows >= spellLimit then break end
		local amount = safeNumber(spell.totalAmount)
		if amount and amount > spellMaxAmount then spellMaxAmount = amount end
		spellMaxScanRows = spellMaxScanRows + 1
	end
	local spellRows = 0
	for _, spell in ipairs(details.combatSpells) do
		local spellName, spellIcon = resolveCombatSpellDisplay(spell)
		local amount = spell.totalAmount
		local dps = spell.amountPerSecond
		local percent = totalAmount and totalAmount > 0 and safeNumber(amount) and (safeNumber(amount) / totalAmount * 100) or nil
		if showSpellSection and spellRows < spellLimit then
			rows[#rows + 1] = { name = spellName, icon = spellIcon, amount = showAmount and formatNumber(amount, config.abbreviation), dps = showDPS and formatNumber(dps, config.abbreviation), percent = showPercent and percent and string.format("%.1f%%", percent), sortAmount = safeNumber(amount) or 0, barValue = safeNumber(amount), barMax = spellMaxAmount }
			spellRows = spellRows + 1
		end

		local target = spell.combatSpellDetails
		if showTargets and type(target) == "table" then
			local targetName = safeText(target.unitName, nil)
			if targetName then
				local entry = targetMap[targetName]
				if not entry then
					entry = { name = targetName, icon = target.specIconID ~= 0 and target.specIconID or 136243, amount = 0, dps = 0 }
					targetMap[targetName] = entry
				end
				local targetAmount = damageMeterType == "EnemyDamageTaken" and safeNumber(spell.totalAmount) or safeNumber(target.amount)
				entry.amount = entry.amount + (targetAmount or 0)
				entry.dps = entry.dps + (safeNumber(spell.amountPerSecond) or 0)
			end
		end
	end

	if not showTargets then return rows end
	local targets = {}
	for _, target in pairs(targetMap) do targets[#targets + 1] = target end
	table.sort(targets, function(a, b) return (a.amount or 0) > (b.amount or 0) end)
	if #targets > 0 then
		if showSpellSection then addTooltipSectionGap(rows) end
		rows[#rows + 1] = { header = true, name = L["damageMeterTooltipTargets"] or "Targets", icon = "Interface\\MINIMAP\\TRACKING\\Target", amount = showAmount and (L["damageMeterTooltipAmount"] or "Amount"), dps = showDPS and (L["damageMeterTooltipDPS"] or "DPS"), percent = showPercent and "%" }
		local targetTotal = 0
		local targetMaxAmount = 0
		for _, target in ipairs(targets) do
			targetTotal = targetTotal + (target.amount or 0)
			if target.amount and target.amount > targetMaxAmount then targetMaxAmount = target.amount end
		end
		for _, target in ipairs(targets) do
			local percent = targetTotal > 0 and (target.amount / targetTotal * 100) or nil
			rows[#rows + 1] = { name = target.name, icon = target.icon, amount = showAmount and formatNumber(target.amount, config.abbreviation), dps = showDPS and formatNumber(target.dps, config.abbreviation), percent = showPercent and percent and string.format("%.1f%%", percent), sortAmount = target.amount or 0, barValue = target.amount, barMax = targetMaxAmount }
		end
	end
	return rows
end

function DamageMeter:ShowSourceTooltip(owner, index, source)
	local config = self:GetConfig(index)
	if config.tooltipEnabled ~= true then return end
	local frame = self:EnsureSourceTooltip()
	local damageMeterType = self:GetEffectiveDamageMeterType(index)
	local rows = damageMeterType == "Deaths" and self:BuildDeathRecapRows(source, config) or nil
	if not rows or #rows == 0 then
		local details = self:GetSourceDetails(index, source)
		rows = self:BuildTooltipRows(details, config, damageMeterType)
	end
	if #rows == 0 then
		rows[1] = { name = L["damageMeterTooltipNoData"] or "No details available", icon = 136243 }
	end
	local width = clampNumber(config.tooltipWidth, 220, 600, DEFAULT_WINDOW.tooltipWidth)
	local tooltipFontSize = clampNumber(config.tooltipFontSize, 8, 24, DEFAULT_WINDOW.tooltipFontSize)
	local lineHeight = tooltipFontSize + 7
	local showAmount, showDPS, showPercent = getTooltipColumnVisibility(config, damageMeterType)
	local percentWidth = showPercent and math.max(56, tooltipFontSize * 4.8) or 0
	local dpsWidth = showDPS and math.max(58, tooltipFontSize * 4.8) or 0
	local amountWidth = showAmount and (damageMeterType == "Deaths" and 150 or math.max(76, tooltipFontSize * 6.2)) or 0
	local rightPadding = 10
	local barStartX = 24
	local minNameWidth = math.max(150, tooltipFontSize * 13)
	local requiredWidth = barStartX + minNameWidth + amountWidth + dpsWidth + percentWidth + rightPadding + 8
	width = math.min(600, math.max(width, requiredWidth))
	local percentRight = -rightPadding
	local dpsRight = percentRight - percentWidth
	local amountRight = dpsRight - dpsWidth
	local nameRight = amountRight - amountWidth - 8
	local showBars = config.tooltipShowBars == true and damageMeterType ~= "Deaths"
	local barTexture = resolveMedia("statusbar", config.tooltipBarTexture, DEFAULT_TEXTURE)
	local barColor = normalizeColor(config.tooltipBarColor, DEFAULT_WINDOW.tooltipBarColor)
	local shown = #rows
	local tooltipHeight = 10
	for rowIndex = 1, shown do
		local multiplier = rows[rowIndex].heightMultiplier or 1
		tooltipHeight = tooltipHeight + (lineHeight * multiplier)
	end

	local backdropTexture = resolveMedia("statusbar", config.tooltipBackdropTexture, "Interface\\Buttons\\WHITE8x8")
	local borderTexture = resolveMedia("border", config.tooltipBorderTexture, DEFAULT_BORDER)
	local borderSize = clampNumber(config.tooltipBorderSize, 1, 32, DEFAULT_WINDOW.tooltipBorderSize)
	frame:SetBackdrop({ bgFile = backdropTexture, edgeFile = borderTexture, edgeSize = borderSize })
	local bg = normalizeColor(config.tooltipBackdropColor, DEFAULT_WINDOW.tooltipBackdropColor)
	local border = normalizeColor(config.tooltipBorderColor, DEFAULT_WINDOW.tooltipBorderColor)
	frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
	frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
	frame:SetSize(width, tooltipHeight)
	self:AnchorSourceTooltip(frame, owner, config)

	local yOffset = 5
	for lineIndex = 1, shown do
		local line = self:GetTooltipLine(frame, lineIndex)
		local data = rows[lineIndex]
		if data then
			local currentLineHeight = lineHeight * (data.heightMultiplier or 1)
			line:SetPoint("TOPLEFT", 0, -yOffset)
			line:SetPoint("TOPRIGHT", 0, -yOffset)
			line:SetHeight(currentLineHeight)
			self:ApplyTooltipFontString(line.name, config)
			self:ApplyTooltipFontString(line.amount, config)
			self:ApplyTooltipFontString(line.dps, config)
			self:ApplyTooltipFontString(line.percent, config)
			line.name:ClearAllPoints()
			line.amount:ClearAllPoints()
			line.dps:ClearAllPoints()
			line.percent:ClearAllPoints()
			line.barBG:ClearAllPoints()
			line.bar:ClearAllPoints()
			line.name:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
			line.name:SetPoint("RIGHT", line, "RIGHT", nameRight, 0)
			line.icon:SetShown(not data.spacer)
			if not data.spacer then line.icon:SetTexture(data.icon or 136243) end
			if showBars and not data.header and not data.spacer and data.barValue and data.barMax and data.barMax > 0 then
				local availableBarWidth = math.max(1, width - rightPadding - barStartX)
				local barWidth = math.max(1, availableBarWidth * math.min(1, data.barValue / data.barMax))
				local barHeight = math.max(1, currentLineHeight - 3)
				line.barBG:SetTexture(barTexture)
				line.barBG:SetVertexColor(0, 0, 0, math.min(0.45, (barColor.a or 1) * 0.6))
				line.barBG:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
				line.barBG:SetSize(availableBarWidth, barHeight)
				line.barBG:Show()
				line.bar:SetTexture(barTexture)
				line.bar:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a)
				line.bar:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
				line.bar:SetSize(barWidth, barHeight)
				line.bar:Show()
			else
				line.barBG:Hide()
				line.bar:Hide()
			end
			line.name:SetText(data.spacer and "" or data.name or "")
			line.amount:SetPoint("RIGHT", line, "RIGHT", amountRight, 0)
			line.dps:SetPoint("RIGHT", line, "RIGHT", dpsRight, 0)
			line.percent:SetPoint("RIGHT", line, "RIGHT", percentRight, 0)
			line.amount:SetWidth(amountWidth)
			line.dps:SetWidth(dpsWidth)
			line.percent:SetWidth(percentWidth)
			line.amount:SetText(data.amount or "")
			line.dps:SetText(data.dps or "")
			line.percent:SetText(data.percent or "")
			if data.header then
				line.name:SetTextColor(1, 0.82, 0, 1)
				line.amount:SetTextColor(1, 0.82, 0, 1)
				line.dps:SetTextColor(1, 0.82, 0, 1)
				line.percent:SetTextColor(1, 0.82, 0, 1)
			else
				line.name:SetTextColor(1, 1, 1, 1)
				line.amount:SetTextColor(1, 1, 1, 1)
				line.dps:SetTextColor(1, 1, 1, 1)
				line.percent:SetTextColor(1, 1, 1, 1)
			end
			line:Show()
			yOffset = yOffset + currentLineHeight
		elseif line then
			line:Hide()
		end
	end
	for lineIndex = shown + 1, #frame.lines do
		frame.lines[lineIndex]:Hide()
	end
	frame:Show()
end

function DamageMeter:HideSourceTooltip()
	if self.previewTooltipOwner then return end
	if self.sourceTooltip then self.sourceTooltip:Hide() end
end

function DamageMeter:UpdatePreviewTooltip(index)
	local config = self:GetConfig(index)
	if self.previewTooltipIndex == index and (config.tooltipPreview ~= true or not self:IsInEditMode()) and self.sourceTooltip then
		self.sourceTooltip:Hide()
		self.previewTooltipIndex = nil
	end
	local frame = self.windows and self.windows[index]
	if not frame or config.tooltipPreview ~= true or not self:IsInEditMode() then return end
	local row = frame.rows and frame.rows[1]
	if row then
		self.previewTooltipOwner = row
		self.previewTooltipIndex = index
		self:ShowSourceTooltip(row, index, PREVIEW_SESSION.combatSources[1])
		self.previewTooltipOwner = nil
	end
end

function DamageMeter:CreateRow(window, index)
	local config = self:GetConfig(window.index)
	local _, _, spacing = getRowMetrics(config)
	local effectiveRowHeight = getEffectiveRowHeight(config)
	local texture = resolveMedia("statusbar", config.texture, DEFAULT_TEXTURE)
	local row = CreateFrame("Button", nil, window.rowsContainer)
	row.windowIndex = window.index
	row:RegisterForClicks("AnyUp")
	row:SetScript("OnClick", function(owner, button)
		if button == "RightButton" then
			DamageMeter:OpenContextMenu(owner, window.index)
		end
	end)
	row:SetScript("OnEnter", function(owner)
		DamageMeter:ShowSourceTooltip(owner, window.index, owner.sourceData)
	end)
	row:SetScript("OnLeave", function()
		DamageMeter:HideSourceTooltip()
	end)
	row:SetHeight(effectiveRowHeight)
	row:ClearAllPoints()
	if normalizeRowGrowth(config.rowGrowth) == "UP" then
		if index > 1 and window.rows[index - 1] then
			row:SetPoint("BOTTOMLEFT", window.rows[index - 1], "TOPLEFT", 0, spacing)
			row:SetPoint("BOTTOMRIGHT", window.rows[index - 1], "TOPRIGHT", 0, spacing)
		else
			row:SetPoint("BOTTOMLEFT", window.rowsContainer, "BOTTOMLEFT")
			row:SetPoint("BOTTOMRIGHT", window.rowsContainer, "BOTTOMRIGHT")
		end
	else
		if index > 1 and window.rows[index - 1] then
			row:SetPoint("TOPLEFT", window.rows[index - 1], "BOTTOMLEFT", 0, -spacing)
			row:SetPoint("TOPRIGHT", window.rows[index - 1], "BOTTOMRIGHT", 0, -spacing)
		else
			row:SetPoint("TOPLEFT", window.rowsContainer, "TOPLEFT")
			row:SetPoint("TOPRIGHT", window.rowsContainer, "TOPRIGHT")
		end
	end

	row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.rank:SetPoint("LEFT", 4, 0)
	row.rank:SetWidth(24)
	row.rank:SetJustifyH("LEFT")

	row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
	row.iconFrame:EnableMouse(false)

	row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
	row.icon:SetAllPoints()
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.iconBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
	row.iconBorder:EnableMouse(false)

	row.bar = CreateFrame("StatusBar", nil, row, "BackdropTemplate")
	row.bar:SetMinMaxValues(0, 1)
	row.bar:SetValue(0)
	row.bar:SetStatusBarTexture(texture)

	row.background = row.bar:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.background:SetColorTexture(0, 0, 0, 0.45)

	row.barBorder = CreateFrame("Frame", nil, row, "BackdropTemplate")
	row.barBorder:EnableMouse(false)

	row.textArea = CreateFrame("Frame", nil, row)

	row.name = row.textArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.value = row.textArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetJustifyH("RIGHT")
	row.value:SetWordWrap(false)

	self:ApplyRankFontString(row.rank, config)
	self:ApplyFontString(row.name, config)
	self:ApplyValueFontString(row.value, config)
	self:ApplyRowTextLayout(row, config)
	self:ApplyIconBorder(row, config)
	self:ApplyBarBorder(row, config)

	window.rows[index] = row
	return row
end

function DamageMeter:EnsureWindow(index)
	self.windows = self.windows or {}
	local window = self.windows[index]
	if window then return window end

	local frame = CreateFrame("Frame", "EnhanceQoLDamageMeterFrame" .. index, UIParent, "BackdropTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:SetScript("OnMouseUp", function(owner, button)
		if button == "RightButton" then
			DamageMeter:OpenContextMenu(owner, index)
		end
	end)
	frame:Hide()
	frame.index = index

	local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header:SetPoint("TOPLEFT", 8, -7)
	header:SetPoint("TOPRIGHT", -8, -7)
	header:SetJustifyH("LEFT")
	frame.header = header

	local headerButtons = CreateFrame("Frame", nil, frame)
	headerButtons:SetSize(36, 16)
	frame.headerButtons = headerButtons
	local resetButton = self:CreateHeaderButton(frame, "R", "GM-raidMarker-reset", L["damageMeterResetData"] or "Reset data", function() DamageMeter:PromptResetData() end)
	resetButton:SetPoint("RIGHT", headerButtons, "RIGHT", 0, 0)
	frame.resetButton = resetButton
	local historyButton = self:CreateHeaderButton(frame, "H", "questlog-questtypeicon-clockyellow", L["damageMeterShowHistory"] or "Show history", function(owner) DamageMeter:OpenHistoryMenu(owner, index) end)
	historyButton:SetPoint("RIGHT", resetButton, "LEFT", -4, 0)
	frame.historyButton = historyButton

	local rowsViewport = CreateFrame("ScrollFrame", nil, frame)
	rowsViewport:SetPoint("TOPLEFT", 4, -28)
	rowsViewport:SetPoint("BOTTOMRIGHT", -4, 22)
	rowsViewport:EnableMouseWheel(true)
	rowsViewport:SetScript("OnMouseWheel", function(_, delta)
		local config = DamageMeter:GetConfig(index)
		local _, _, spacing = getRowMetrics(config)
		local effectiveRowHeight = getEffectiveRowHeight(config)
		local maxRows = getEffectiveMaxRows(config)
		local visibleRows = getEffectiveVisibleRows(config, maxRows)
		local contentRows = math.min(maxRows, frame.contentRows or maxRows)
		local maxScroll = math.max(0, (contentRows - visibleRows) * (effectiveRowHeight + spacing))
		local nextScroll = (rowsViewport:GetVerticalScroll() or 0) - (delta * (effectiveRowHeight + spacing))
		rowsViewport:SetVerticalScroll(clampNumber(nextScroll, 0, maxScroll, 0))
	end)
	frame.rowsViewport = rowsViewport

	local rowsContainer = CreateFrame("Frame", nil, rowsViewport)
	rowsViewport:SetScrollChild(rowsContainer)
	frame.rowsContainer = rowsContainer

	local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	empty:SetPoint("CENTER", rowsViewport, "CENTER", 0, 0)
	empty:SetText(L["damageMeterNoData"] or "No damage data")
	frame.empty = empty

	local status = CreateFrame("Button", nil, frame)
	status:RegisterForClicks("AnyUp")
	status:SetPoint("BOTTOMLEFT", 4, 4)
	status:SetPoint("BOTTOMRIGHT", -4, 4)
	status:SetHeight(16)
	status:SetScript("OnClick", function(owner, button)
		if button == "RightButton" then
			DamageMeter:OpenContextMenu(owner, index)
			return
		end
		if button == "MiddleButton" then
			local config = DamageMeter:GetConfig(index)
			config.sessionType = config.sessionType == "overall" and "current" or "overall"
			DamageMeter:ScheduleRefresh()
			return
		end
		DamageMeter:CycleQuickDamageMeterType(index, 1)
	end)
	status:SetScript("OnMouseWheel", function(_, delta)
		DamageMeter:CycleQuickDamageMeterType(index, delta and delta < 0 and -1 or 1)
	end)
	status:EnableMouseWheel(true)
	status.text = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	status.text:SetAllPoints()
	status.text:SetJustifyH("CENTER")
	status.text:SetTextColor(0.8, 0.82, 0.86)
	frame.status = status

	frame.rows = {}
	self.windows[index] = frame
	return frame
end

function DamageMeter:ApplyWindowAnchor(index)
	if index <= 1 then return end
	local frame = self.windows and self.windows[index]
	if not frame then return end
	local config = self:GetConfig(index)
	local targetIndex = clampNumber(config.anchorToWindow, 0, index - 1, 0)
	if targetIndex <= 0 then
		if frame._damageMeterAnchored then
			local id = EDITMODE_ID_PREFIX .. index
			local point = EditMode and EditMode.GetValue and EditMode:GetValue(id, "point") or "CENTER"
			local relativePoint = EditMode and EditMode.GetValue and EditMode:GetValue(id, "relativePoint") or point
			local x = EditMode and EditMode.GetValue and EditMode:GetValue(id, "x") or 300
			local y = EditMode and EditMode.GetValue and EditMode:GetValue(id, "y") or (-120 - ((index - 1) * 30))
			frame:ClearAllPoints()
			frame:SetPoint(point or "CENTER", UIParent, relativePoint or point or "CENTER", x or 0, y or 0)
			frame._damageMeterAnchored = false
		end
		return
	end
	local target = self:EnsureWindow(targetIndex)
	if not target then return end
	frame:ClearAllPoints()
	frame:SetPoint(
		normalizeFramePoint(config.windowAnchorPoint),
		target,
		normalizeFramePoint(config.windowRelativePoint),
		clampNumber(config.windowOffsetX, -1000, 1000, DEFAULT_WINDOW.windowOffsetX),
		clampNumber(config.windowOffsetY, -1000, 1000, DEFAULT_WINDOW.windowOffsetY)
	)
	frame._damageMeterAnchored = true
end

function DamageMeter:ApplyWindowStyle(index, contentRows)
	local frame = self:EnsureWindow(index)
	local config = self:GetConfig(index)
	local rowMode = config.raidRowsEnabled == true and IsInRaid() and "raid" or "default"
	local styleVersion = self:GetWindowStyleVersion(index)
	local rowCount = #frame.rows
	local globalFontVersion = getGlobalFontStateVersion()
	if frame._damageMeterWindowStyleVersion == styleVersion
		and frame._damageMeterWindowStyleContentRows == contentRows
		and frame._damageMeterWindowStyleRowCount == rowCount
		and frame._damageMeterWindowStyleRowMode == rowMode
		and frame._damageMeterWindowStyleGlobalFontVersion == globalFontVersion then
		return
	end
	frame._damageMeterWindowStyleVersion = styleVersion
	frame._damageMeterWindowStyleContentRows = contentRows
	frame._damageMeterWindowStyleRowCount = rowCount
	frame._damageMeterWindowStyleRowMode = rowMode
	frame._damageMeterWindowStyleGlobalFontVersion = globalFontVersion

	local width = clampNumber(config.width, 220, 700, DEFAULT_WINDOW.width)
	local showHeader = config.showHeader == true
	local showHeaderButtons = showHeader and config.showHeaderButtons ~= false
	local showStatus = config.showStatus ~= false
	local headerPosition = normalizeHeaderPosition(config.headerPosition)
	local rowsGrowUp = normalizeRowGrowth(config.rowGrowth) == "UP"
	local _, _, spacing = getRowMetrics(config)
	local effectiveRowHeight = getEffectiveRowHeight(config)
	local maxRows = getEffectiveMaxRows(config)
	local visibleRows = getEffectiveVisibleRows(config, maxRows)
	contentRows = math.min(maxRows, clampNumber(contentRows, 0, maxRows, maxRows))
	local viewportHeight = (visibleRows * effectiveRowHeight) + math.max(0, visibleRows - 1) * spacing
	local titleFontSize = clampNumber(config.titleFontSize, 8, 28, DEFAULT_WINDOW.titleFontSize)
	local statusFontSize = clampNumber(config.statusFontSize, 8, 24, DEFAULT_WINDOW.statusFontSize)
	local headerHeight = showHeader and math.max(24, titleFontSize + 12) or 0
	local statusHeight = showStatus and math.max(16, statusFontSize + 6) or 0
	local topInset = headerPosition == "TOP" and (headerHeight > 0 and headerHeight or 4) or 4
	local bottomInset = 4 + (showStatus and (statusHeight + 2) or 0) + (headerPosition == "BOTTOM" and headerHeight or 0)
	local heightOffset = clampNumber(config.heightOffset, 0, 300, DEFAULT_WINDOW.heightOffset)
	local topOffset = math.floor(heightOffset / 2)
	local bottomOffset = heightOffset - topOffset
	local height = math.max(60, viewportHeight + topInset + bottomInset + heightOffset)
	local contentHeight = contentRows > 0 and ((contentRows * effectiveRowHeight) + math.max(0, contentRows - 1) * spacing) or 1
	local backdropR, backdropG, backdropB, backdropA = colorComponents(config.backdropColor, DEFAULT_WINDOW.backdropColor)
	local borderR, borderG, borderB, borderA = colorComponents(config.borderColor, DEFAULT_WINDOW.borderColor)
	local titleR, titleG, titleB, titleA = colorComponents(config.titleColor, DEFAULT_WINDOW.titleColor)
	frame.contentRows = contentRows

	local texture = resolveMedia("statusbar", config.texture, DEFAULT_TEXTURE)
	local backdropTexture = resolveMedia("statusbar", config.backdropTexture, "Interface\\Buttons\\WHITE8x8")
	frame:SetSize(width, height)
	self:ApplyWindowAnchor(index)
	local headerButtonTextInset = self:ApplyHeaderButtons(frame, config, showHeaderButtons)
	setShownIfChanged(frame.header, showHeader)
	setShownIfChanged(frame.status, showStatus)
	frame.header:ClearAllPoints()
	frame.headerButtons:ClearAllPoints()
	frame.status:ClearAllPoints()
	if headerPosition == "BOTTOM" then
		frame.header:SetPoint("BOTTOMLEFT", 8, 7 + bottomOffset)
		frame.header:SetPoint("BOTTOMRIGHT", -headerButtonTextInset, 7 + bottomOffset)
		frame.headerButtons:SetPoint("BOTTOMRIGHT", -8, 7 + bottomOffset)
		frame.status:SetPoint("BOTTOMLEFT", 4, 4 + bottomOffset + headerHeight)
		frame.status:SetPoint("BOTTOMRIGHT", -4, 4 + bottomOffset + headerHeight)
	else
		frame.header:SetPoint("TOPLEFT", 8, -(7 + topOffset))
		frame.header:SetPoint("TOPRIGHT", -headerButtonTextInset, -(7 + topOffset))
		frame.headerButtons:SetPoint("TOPRIGHT", -8, -(7 + topOffset))
		frame.status:SetPoint("BOTTOMLEFT", 4, 4 + bottomOffset)
		frame.status:SetPoint("BOTTOMRIGHT", -4, 4 + bottomOffset)
	end

	local borderTexture = resolveMedia("border", config.borderTexture, DEFAULT_BORDER)
	if config.borderEnabled == true then
		local size = clampNumber(config.borderSize, 1, 32, DEFAULT_WINDOW.borderSize)
		local inset = clampNumber(config.borderInset, 0, 24, DEFAULT_WINDOW.borderInset)
		frame:SetBackdrop({
			bgFile = backdropTexture,
			edgeFile = borderTexture,
			edgeSize = size,
			insets = { left = inset, right = inset, top = inset, bottom = inset },
		})
		frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
	else
		frame:SetBackdrop({ bgFile = backdropTexture })
	end
	frame:SetBackdropColor(backdropR, backdropG, backdropB, backdropA)

	frame.status:SetHeight(math.max(1, statusHeight))

	frame.rowsViewport:ClearAllPoints()
	frame.rowsViewport:SetPoint("TOPLEFT", 4, -(topInset + topOffset))
	frame.rowsViewport:SetPoint("TOPRIGHT", -4, -(topInset + topOffset))
	frame.rowsViewport:SetHeight(viewportHeight)
	frame.rowsContainer:SetSize(math.max(1, width - 8), math.max(1, contentHeight))
	local maxScroll = math.max(0, contentHeight - viewportHeight)
	if (frame.rowsViewport:GetVerticalScroll() or 0) > maxScroll then
		frame.rowsViewport:SetVerticalScroll(maxScroll)
	end

	self:ApplyTitleFontString(frame.header, config)
	setTextColorIfChanged(frame.header, titleR, titleG, titleB, titleA)
	self:ApplyFontString(frame.empty, config)
	self:ApplyStatusFontString(frame.status.text, config)

	local previous
	for rowIndex, row in ipairs(frame.rows) do
		row:SetHeight(effectiveRowHeight)
		row:ClearAllPoints()
		if rowsGrowUp then
			if previous then
				row:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, spacing)
				row:SetPoint("BOTTOMRIGHT", previous, "TOPRIGHT", 0, spacing)
			else
				row:SetPoint("BOTTOMLEFT", frame.rowsContainer, "BOTTOMLEFT")
				row:SetPoint("BOTTOMRIGHT", frame.rowsContainer, "BOTTOMRIGHT")
			end
		else
			if previous then
				row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
				row:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -spacing)
			else
				row:SetPoint("TOPLEFT", frame.rowsContainer, "TOPLEFT")
				row:SetPoint("TOPRIGHT", frame.rowsContainer, "TOPRIGHT")
			end
		end
		if row.bar._damageMeterTexture ~= texture then
			row.bar._damageMeterTexture = texture
			row.bar:SetStatusBarTexture(texture)
		end
		self:ApplyRankFontString(row.rank, config)
		self:ApplyFontString(row.name, config)
		self:ApplyValueFontString(row.value, config)
		self:ApplyRowTextLayout(row, config)
		self:ApplyRowValueWidth(row, config)
		previous = row
	end
end

function DamageMeter:UpdateHeader(index, session, state)
	state = state or self:BuildWindowRefreshState(index)
	local frame = self:EnsureWindow(index)
	local config = state.config
	local showHeader = config.showHeader == true
	local showStatus = config.showStatus ~= false
	if not showHeader and not showStatus then return end
	local sessionLabel
	if state.sessionID then
		local fallback = DAMAGE_METER_COMBAT_NUMBER and DAMAGE_METER_COMBAT_NUMBER:format(state.sessionID) or string.format("%s %d", L["damageMeterCombat"] or "Combat", state.sessionID)
		sessionLabel = safeText(state.temporary and state.temporary.sessionName, fallback)
	else
		sessionLabel = state.sessionType == "overall" and (L["damageMeterOverall"] or "Overall") or (L["damageMeterCurrent"] or "Current")
	end
	local typeLabel = getDamageMeterTypeLabel(state.damageMeterType)
	local durationText
	local durationBucket = false
	local headerTimeFormat = normalizeHeaderTimeFormat(config.headerTimeFormat)
	if showHeader and config.showHeaderTime ~= false then
		local duration = self:GetSessionDuration(index, session, state)
		if duration then
			durationBucket = math.floor(duration + 0.5)
			durationText = formatDuration(duration, headerTimeFormat)
		end
	end
	local formatMode = normalizeHeaderFormat(config.headerFormat)
	local quickTypeLabels = showStatus and self:GetQuickDamageMeterTypeLabels(index, typeLabel) or nil
	local styleVersion = self:GetWindowStyleVersion(index)
	if frame._damageMeterHeaderStyleVersion == styleVersion
		and frame._damageMeterHeaderShowHeader == showHeader
		and frame._damageMeterHeaderShowStatus == showStatus
		and frame._damageMeterHeaderShowSession == (config.showHeaderSession ~= false)
		and frame._damageMeterHeaderShowType == (config.showHeaderType ~= false)
		and frame._damageMeterHeaderShowTime == (config.showHeaderTime ~= false)
		and frame._damageMeterHeaderFormat == formatMode
		and frame._damageMeterHeaderTimeFormat == headerTimeFormat
		and frame._damageMeterHeaderDurationBucket == durationBucket
		and frame._damageMeterHeaderSessionLabel == sessionLabel
		and frame._damageMeterHeaderTypeLabel == typeLabel
		and frame._damageMeterHeaderQuickTypeLabels == quickTypeLabels then
		return
	end
	frame._damageMeterHeaderStyleVersion = styleVersion
	frame._damageMeterHeaderShowHeader = showHeader
	frame._damageMeterHeaderShowStatus = showStatus
	frame._damageMeterHeaderShowSession = config.showHeaderSession ~= false
	frame._damageMeterHeaderShowType = config.showHeaderType ~= false
	frame._damageMeterHeaderShowTime = config.showHeaderTime ~= false
	frame._damageMeterHeaderFormat = formatMode
	frame._damageMeterHeaderTimeFormat = headerTimeFormat
	frame._damageMeterHeaderDurationBucket = durationBucket
	frame._damageMeterHeaderSessionLabel = sessionLabel
	frame._damageMeterHeaderTypeLabel = typeLabel
	frame._damageMeterHeaderQuickTypeLabels = quickTypeLabels

	local separator = (formatMode == "timeTypeSpace" or formatMode == "typeTimeSpace") and " " or " - "
	local headerText = ""
	if showHeader then
		if durationText and (formatMode == "timeTypeDash" or formatMode == "timeTypeSpace") then headerText = durationText end
		if config.showHeaderType ~= false and typeLabel then
			headerText = headerText ~= "" and (headerText .. separator .. typeLabel) or typeLabel
		end
		if durationText and (formatMode == "typeTimeDash" or formatMode == "typeTimeSpace") then
			headerText = headerText ~= "" and (headerText .. separator .. durationText) or durationText
		end
		if config.showHeaderSession ~= false and sessionLabel then
			if headerText ~= "" then
				headerText = sessionLabel .. " - " .. headerText
			else
				headerText = sessionLabel
			end
		end
		setPlainTextIfChanged(frame.header, headerText)
	end
	if showStatus then
		setPlainTextIfChanged(frame.status.text, string.format("%s: %s  |  %s", L["damageMeterQuickSwitch"] or "Quick switch", sessionLabel, quickTypeLabels))
	end
end

function DamageMeter:RefreshWindow(index, shared, sessionCache)
	local state = self:BuildWindowRefreshState(index, shared)
	local frame = self:EnsureWindow(index)
	if not state.visible then
		frame:Hide()
		return
	end

	local config = state.config
	local session = self:GetSessionForState(state, sessionCache)
	local sources = session and type(session.combatSources) == "table" and session.combatSources or {}
	local maxRows = getEffectiveMaxRows(config)
	local damageMeterType = state.damageMeterType
	local orderedSources = sources
	if damageMeterType == "Deaths" and type(sources) == "table" and #sources > 1 then
		orderedSources = {}
		local hasComparableDeathTime = false
		for _, source in ipairs(sources) do
			if safeNumber(source and source.deathTimeSeconds) then
				hasComparableDeathTime = true
				break
			end
		end
		if hasComparableDeathTime then
			for sourceIndex, source in ipairs(sources) do
				orderedSources[sourceIndex] = source
			end
			table.sort(orderedSources, function(left, right)
				local leftTime = safeNumber(left and left.deathTimeSeconds) or math.huge
				local rightTime = safeNumber(right and right.deathTimeSeconds) or math.huge
				return leftTime < rightTime
			end)
		else
			for sourceIndex = 1, #sources do
				orderedSources[sourceIndex] = sources[#sources - sourceIndex + 1]
			end
		end
	end
	local rowsGrowUp = normalizeRowGrowth(config.rowGrowth) == "UP"
	local highestBottom = damageMeterType ~= "Deaths" and normalizeRowSort(config.rowSort) == "BOTTOM"
	local visibleRows = getEffectiveVisibleRows(config, maxRows)
	local contentRows = math.min(maxRows, #orderedSources)
	local displayIndices
	local playerSourceIndex
	if config.alwaysShowPlayer == true then
		for sourceIndex, source in ipairs(orderedSources) do
			if source and source.isLocalPlayer == true then
				playerSourceIndex = sourceIndex
				break
			end
		end
	end
	local playerVisibleLimit = highestBottom and math.max(1, contentRows - visibleRows + 1) or math.min(contentRows, visibleRows)
	local forcePlayer = playerSourceIndex and contentRows > 0 and ((highestBottom and playerSourceIndex < playerVisibleLimit) or (not highestBottom and playerSourceIndex > playerVisibleLimit))
	if forcePlayer then
		displayIndices = frame._damageMeterDisplayIndices
		if not displayIndices then
			displayIndices = {}
			frame._damageMeterDisplayIndices = displayIndices
		end
		for displayIndex = #displayIndices, 1, -1 do
			displayIndices[displayIndex] = nil
		end
		local usedSourceIndices = frame._damageMeterUsedSourceIndices
		if not usedSourceIndices then
			usedSourceIndices = {}
			frame._damageMeterUsedSourceIndices = usedSourceIndices
		end
		for sourceIndex in pairs(usedSourceIndices) do
			usedSourceIndices[sourceIndex] = nil
		end
		usedSourceIndices[playerSourceIndex] = true
		local playerSlot = playerVisibleLimit
		for sourceIndex = 1, playerSlot - 1 do
			displayIndices[#displayIndices + 1] = sourceIndex
		end
		displayIndices[#displayIndices + 1] = playerSourceIndex
		for sourceIndex = playerSlot, #orderedSources do
			if #displayIndices >= contentRows then break end
			if not usedSourceIndices[sourceIndex] then
				displayIndices[#displayIndices + 1] = sourceIndex
			end
		end
	end

	self:ApplyWindowStyle(index, contentRows)
	self:UpdateHeader(index, session, state)

	local totalAmount = safeNumber(session and session.totalAmount)
	local shown = 0
	local inFollowerDungeon = state.inFollowerDungeon
	local valueMode = getRowValueMode(damageMeterType)
	local valueAbbreviation = config.abbreviation
	local valueShowPercent = config.showPercent ~= false
	local valueUseParentheses = config.valueFormat == "parentheses"

	for rowIndex = 1, maxRows do
		local visualTopIndex = rowsGrowUp and (contentRows - rowIndex + 1) or rowIndex
		local entryIndex = highestBottom and (contentRows - visualTopIndex + 1) or visualTopIndex
		local sourceIndex
		if entryIndex >= 1 and entryIndex <= contentRows then
			if displayIndices then
				sourceIndex = displayIndices[entryIndex]
			else
				sourceIndex = entryIndex
			end
		end
		local source = sourceIndex and orderedSources[sourceIndex] or nil
		local row = frame.rows[rowIndex] or self:CreateRow(frame, rowIndex)
		if source then
			local rawMaxAmount, rawAmount
			if damageMeterType == "Deaths" then
				rawMaxAmount = 1
				rawAmount = 1
			else
				rawMaxAmount = session and session.maxAmount
				rawAmount = source.totalAmount
				if rawMaxAmount == nil then rawMaxAmount = 1 end
				if rawAmount == nil then rawAmount = 0 end
			end
			local amount = safeNumber(source.totalAmount)
			local percent = totalAmount and totalAmount > 0 and amount and (amount / totalAmount * 100) or nil
			local colors = self:GetRowColorState(frame, config, source.classFilename)
			local valueText = formatRowValueText(source, percent, valueMode, valueAbbreviation, valueShowPercent, valueUseParentheses)

			self:ApplyRankText(row, sourceIndex, config)
			row.sourceData = source
			self:ApplyIconBorder(row, config, source.classFilename)
			self:ApplyBarBorder(row, config, source.classFilename)
			applySourceIcon(row.icon, source, inFollowerDungeon)
			row.name:SetText(formatDisplayName(source.name, sourceIndex, config))
			setTextColorIfChanged(row.name, colors.nr, colors.ng, colors.nb, colors.na)
			row.value:SetText(valueText)
			setTextColorIfChanged(row.value, colors.vr, colors.vg, colors.vb, colors.va)
			self:ApplyRowValueWidth(row, config, damageMeterType)
			row.bar:SetStatusBarColor(colors.r, colors.g, colors.b, 0.85)
			row.bar:SetMinMaxValues(0, rawMaxAmount)
			row.bar:SetValue(rawAmount)
			row:Show()
			shown = shown + 1
		else
			row.sourceData = nil
			row:Hide()
		end
	end

	for rowIndex = maxRows + 1, #frame.rows do
		frame.rows[rowIndex]:Hide()
	end

	frame.empty:SetShown(shown == 0)
	frame:SetShown(true)
	self:UpdatePreviewTooltip(index)
end

function DamageMeter:Refresh()
	local shared = self:BuildRefreshSharedState()
	local sessionCache = self.refreshSessionCache
	if not sessionCache then
		sessionCache = {}
		self.refreshSessionCache = sessionCache
	end
	self:ClearRefreshSessionCache(sessionCache)
	for index = 1, MAX_WINDOWS do
		self:RefreshWindow(index, shared, sessionCache)
	end
	self:ClearRefreshSessionCache(sessionCache)
end

function DamageMeter:ScheduleRefresh()
	if GetTime then
		self.lastLiveRefreshTime = GetTime()
	end
	self:Refresh()
end

function DamageMeter:RefreshFromLiveEvent(damageMeterType, sessionID)
	if not self:IsLiveEventRelevant(damageMeterType, sessionID) then return end
	local now = GetTime and GetTime() or 0
	local last = self.lastLiveRefreshTime or 0
	if now - last < getUpdateRate() then return end
	self.lastLiveRefreshTime = now
	self:Refresh()
end

function DamageMeter:RegisterLiveEvents()
	local frame = self.eventFrame
	if not frame or self.liveEventsRegistered then return end
	frame:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	frame:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	frame:RegisterEvent("DAMAGE_METER_RESET")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.liveEventsRegistered = true
end

function DamageMeter:UnregisterLiveEvents()
	local frame = self.eventFrame
	if not frame or not self.liveEventsRegistered then return end
	frame:UnregisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
	frame:UnregisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
	frame:UnregisterEvent("DAMAGE_METER_RESET")
	frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
	frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
	frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self.liveEventsRegistered = false
end

function DamageMeter:UpdateEventState()
	self:InvalidateLiveEventWatch()
	if self:IsEnabled() and self:IsAvailable() then
		self:RegisterLiveEvents()
	else
		self:UnregisterLiveEvents()
	end
	self:ScheduleRefresh()
end

function DamageMeter:ApplySyncedConfig(sourceIndex)
	if db().damageMeterSyncSettings ~= true then return end
	local windows = self:GetWindowsDB()
	local source = copyWindowConfig(windows[sourceIndex])
	for index = 1, MAX_WINDOWS do
		if index ~= sourceIndex then
			windows[index] = copySyncedWindowConfig(source, windows[index])
		end
	end
	self:MarkWindowStyleDirty()
	self:Refresh()
end

function DamageMeter:CopySettings(sourceIndex, targetIndex)
	sourceIndex = tonumber(sourceIndex)
	targetIndex = tonumber(targetIndex)
	if not sourceIndex or not targetIndex or sourceIndex == targetIndex then return end
	local count = getWindowCount()
	if sourceIndex < 1 or sourceIndex > count or targetIndex < 1 or targetIndex > count then return end
	local windows = self:GetWindowsDB()
	windows[targetIndex] = copyWindowConfig(windows[sourceIndex])
	self:InvalidateLiveEventWatch()
	self:MarkWindowStyleDirty(targetIndex)
	if db().damageMeterSyncSettings == true then
		self:ApplySyncedConfig(targetIndex)
	else
		self:RefreshWindow(targetIndex)
	end
end

function DamageMeter:AddWindow(sourceIndex)
	local count = getWindowCount()
	if count >= MAX_WINDOWS then return end
	local newIndex = count + 1
	setWindowCount(newIndex)
	self:GetWindowsDB()
	self:InvalidateLiveEventWatch()
	self:MarkWindowStyleDirty(newIndex)
	if db().damageMeterSyncSettings == true then
		self:CopySettings(sourceIndex or 1, newIndex)
	end
	self:UpdateEventState()
	self:Refresh()
	return newIndex
end

function DamageMeter:CloseEditModeDialogForWindow(index)
	local frame = self.windows and self.windows[index]
	local lib = EditMode and EditMode.lib
	local dialog = lib and lib.internal and lib.internal.dialog
	if not (frame and dialog and dialog.IsShown and dialog:IsShown()) then return end
	local contextFrame = dialog.context and dialog.context.frame
	local selectionFrame = dialog.selection and dialog.selection.parent
	if contextFrame == frame or selectionFrame == frame then
		dialog:Hide()
	end
end

function DamageMeter:RemoveWindow(index)
	index = tonumber(index)
	local count = getWindowCount()
	if not index or index <= 1 or index > count then return end
	self:HideContextMenu()
	self:CloseEditModeDialogForWindow(index)
	local windows = self:GetWindowsDB()
	for windowIndex = index, count - 1 do
		windows[windowIndex] = copyWindowConfig(windows[windowIndex + 1])
	end
	windows[count] = copyWindowConfig(DEFAULT_WINDOW)
	setWindowCount(count - 1)
	for windowIndex = count, MAX_WINDOWS do
		local frame = self.windows and self.windows[windowIndex]
		if frame then frame:Hide() end
	end
	self:InvalidateLiveEventWatch()
	self:Refresh()
end

function DamageMeter:EnsureStaticPopups()
	if not StaticPopupDialogs then return end
	StaticPopupDialogs[REMOVE_WINDOW_POPUP] = StaticPopupDialogs[REMOVE_WINDOW_POPUP] or {
		text = L["damageMeterRemoveWindowConfirm"] or "Remove Damage Meter window %s?",
		button1 = YES or "Yes",
		button2 = CANCEL or "Cancel",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[REMOVE_WINDOW_POPUP].OnAccept = function(_, data) DamageMeter:RemoveWindow(data) end

	StaticPopupDialogs[COPY_WINDOW_POPUP] = StaticPopupDialogs[COPY_WINDOW_POPUP] or {
		text = L["damageMeterCopyWindowConfirm"] or "Copy settings from Damage Meter %s to Damage Meter %s?",
		button1 = YES or "Yes",
		button2 = CANCEL or "Cancel",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[COPY_WINDOW_POPUP].OnAccept = function(_, data)
		if type(data) == "table" then DamageMeter:CopySettings(data.source, data.target) end
	end

	StaticPopupDialogs[RESET_DATA_POPUP] = StaticPopupDialogs[RESET_DATA_POPUP] or {
		text = L["damageMeterResetDataConfirm"] or "Reset all Damage Meter data?",
		button1 = YES or "Yes",
		button2 = CANCEL or "Cancel",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[RESET_DATA_POPUP].OnAccept = function() DamageMeter:ResetData() end
end

function DamageMeter:PromptRemoveWindow(index)
	self:EnsureStaticPopups()
	if StaticPopup_Show then
		StaticPopup_Show(REMOVE_WINDOW_POPUP, tostring(index), nil, index)
	else
		self:RemoveWindow(index)
	end
end

function DamageMeter:PromptCopySettings(sourceIndex, targetIndex)
	if sourceIndex == targetIndex then return end
	self:EnsureStaticPopups()
	if StaticPopup_Show then
		StaticPopup_Show(COPY_WINDOW_POPUP, tostring(sourceIndex), tostring(targetIndex), { source = sourceIndex, target = targetIndex })
	else
		self:CopySettings(sourceIndex, targetIndex)
	end
end

function DamageMeter:ResetData()
	if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
		C_DamageMeter.ResetAllCombatSessions()
	end
	self.temporarySelections = {}
	self:InvalidateLiveEventWatch()
	self:ScheduleRefresh()
end

function DamageMeter:PromptResetData()
	self:EnsureStaticPopups()
	if StaticPopup_Show then
		StaticPopup_Show(RESET_DATA_POPUP)
	else
		self:ResetData()
	end
end

local function buildWindowCopyOptions(targetIndex)
	local options = {}
	local count = getWindowCount()
	for index = 1, count do
		if index ~= targetIndex then
			options[#options + 1] = { value = tostring(index), label = string.format("%s %d", L["damageMeterTitle"] or "Damage Meter", index) }
		end
	end
	if #options == 0 then options[#options + 1] = { value = "", label = _G.NONE or "None" } end
	return options
end

local function dropdownSetting(name, getter, setter, options, parentId, height, isEnabled, isShown)
	return {
		name = name,
		kind = SettingType.Dropdown,
		parentId = parentId,
		height = height or 160,
		isEnabled = isEnabled,
		isShown = isShown,
		get = getter,
		set = function(_, value) setter(value) end,
		generator = function(_, root)
			local optionList = type(options) == "function" and options() or options
			for _, option in ipairs(optionList) do
				root:CreateRadio(option.label, function() return getter() == option.value end, function() setter(option.value) end)
			end
		end,
	}
end

local function sliderSetting(name, getter, setter, minValue, maxValue, step, parentId, isEnabled, isShown)
	return {
		name = name,
		kind = SettingType.Slider,
		parentId = parentId,
		isEnabled = isEnabled,
		isShown = isShown,
		minValue = minValue,
		maxValue = maxValue,
		valueStep = step or 1,
		allowInput = true,
		get = getter,
		set = function(_, value) setter(value) end,
	}
end

local function checkboxSetting(name, getter, setter, parentId, isEnabled, tooltip)
	return {
		name = name,
		kind = SettingType.Checkbox,
		parentId = parentId,
		isEnabled = isEnabled,
		tooltip = tooltip,
		get = getter,
		set = function(_, value) setter(value == true) end,
	}
end

local function colorSetting(name, getter, setter, default, parentId, isEnabled)
	return {
		name = name,
		kind = SettingType.Color,
		parentId = parentId,
		isEnabled = isEnabled,
		default = default,
		hasOpacity = true,
		get = getter,
		set = function(_, value) setter(value) end,
	}
end

local function dividerSetting(parentId, isEnabled, isShown)
	return {
		name = "",
		kind = SettingType.Divider,
		parentId = parentId,
		isEnabled = isEnabled,
		isShown = isShown,
	}
end

local function requestEditModeSettingsRefresh()
	if addon.EditModeLib and addon.EditModeLib.internal and addon.EditModeLib.internal.RequestRefreshSettings then
		addon.EditModeLib.internal:RequestRefreshSettings()
	end
end

function DamageMeter:SetConfigValue(index, key, value)
	local config = self:GetConfig(index)
	if key == "quickTypes" then
		config.quickTypes = normalizeQuickDamageMeterTypes(value, config.damageMeterType or DEFAULT_WINDOW.damageMeterType)
		if self.quickTypeLabelCache then self.quickTypeLabelCache[index] = nil end
	else
		config[key] = copyValue(value)
	end
	if key == "damageMeterType" or key == "sessionType" then
		self:InvalidateLiveEventWatch()
	end
	self:MarkWindowStyleDirty(index)
	if key == "tooltipPreview" and value ~= true and self.sourceTooltip then
		self.sourceTooltip:Hide()
		if self.previewTooltipIndex == index then self.previewTooltipIndex = nil end
	end
	if key == "tooltipEnabled" and value ~= true and self.sourceTooltip then
		self.sourceTooltip:Hide()
		if self.previewTooltipIndex == index then self.previewTooltipIndex = nil end
	end
	if key == "rowHeight" or key == "barHeight" or key == "changeBarSize" then
		local rowHeight = clampNumber(config.rowHeight, 10, 70, DEFAULT_WINDOW.rowHeight)
		config.barHeight = clampNumber(config.barHeight, 1, rowHeight, DEFAULT_WINDOW.barHeight)
	end
	if db().damageMeterSyncSettings == true and not SYNC_EXCLUDED_KEYS[key] then
		local windows = self:GetWindowsDB()
		for windowIndex = 1, MAX_WINDOWS do
			if windowIndex ~= index then
				windows[windowIndex][key] = copyValue(config[key])
				self:MarkWindowStyleDirty(windowIndex)
				if key == "rowHeight" or key == "barHeight" or key == "changeBarSize" then
					local rowHeight = clampNumber(windows[windowIndex].rowHeight, 10, 70, DEFAULT_WINDOW.rowHeight)
					windows[windowIndex].barHeight = clampNumber(windows[windowIndex].barHeight, 1, rowHeight, DEFAULT_WINDOW.barHeight)
				end
			end
		end
		self:Refresh()
	else
		self:RefreshWindow(index)
	end
end

function DamageMeter:BuildWindowSettings(index)
	local function cfg() return self:GetConfig(index) end
	local function headerEnabled() return cfg().showHeader == true end
	local function headerTimeEnabled() return cfg().showHeader == true and cfg().showHeaderTime ~= false end
	local function statusEnabled() return cfg().showStatus ~= false end
	local function namesEnabled() return cfg().showNames == true end
	local function fixedNameColorEnabled() return cfg().showNames == true and cfg().nameUseClassColors ~= true end
	local function tooltipEnabled() return cfg().tooltipEnabled == true end
	local function customBarSizeEnabled() return cfg().changeBarSize == true end
	local function barBorderEnabled() return cfg().barBorderEnabled == true end
	local function fixedBarBorderColorEnabled() return cfg().barBorderEnabled == true and cfg().barBorderUseClassColor ~= true end
	local function customIconSizeEnabled() return cfg().changeIconSize == true end
	local function iconBorderEnabled() return cfg().iconBorderEnabled == true end
	local function fixedIconBorderColorEnabled() return cfg().iconBorderEnabled == true and cfg().iconBorderUseClassColor ~= true end
	local function fixedValueColorEnabled() return cfg().valueUseClassColors ~= true end
	local function rankingEnabled() return cfg().showRanks ~= false end
	local function rankColumnEnabled() return cfg().showRanks ~= false and cfg().prefixRankInName ~= true end
	local function windowAnchorVisible() return index > 1 end
	local function windowAnchorEnabled() return index > 1 and clampNumber(cfg().anchorToWindow, 0, index - 1, 0) > 0 end
	local function raidRowsEnabled() return cfg().raidRowsEnabled == true end
	local behaviorId = "damageMeterBehavior" .. index
	local layoutId = "damageMeterLayout" .. index
	local headerId = "damageMeterHeader" .. index
	local statusId = "damageMeterStatus" .. index
	local barId = "damageMeterBar" .. index
	local iconId = "damageMeterIcon" .. index
	local namesId = "damageMeterNames" .. index
	local valuesId = "damageMeterValues" .. index
	local tooltipId = "damageMeterTooltip" .. index
	local rankingId = "damageMeterRanking" .. index
	local mediaId = "damageMeterMedia" .. index
	local borderId = "damageMeterBorder" .. index
	local settingsId = "damageMeterSettings" .. index
	local settings = {
		{ name = L["damageMeterSettings"] or "Settings", kind = SettingType.Collapsible, id = settingsId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterSyncSettings"] or "Sync settings", function() return db().damageMeterSyncSettings == true end, function(value)
			db().damageMeterSyncSettings = value == true
			if value == true then
				self:ApplySyncedConfig(index)
			else
				self:Refresh()
			end
		end, settingsId, nil, L["damageMeterSyncSettingsDesc"] or "When enabled, every Damage Meter window uses the same settings. Changes made in any window are applied to all windows."),
		dropdownSetting(L["damageMeterCopySettingsFrom"] or "Copy settings from", function() return "" end, function(value)
			local sourceIndex = tonumber(value)
			if sourceIndex then self:PromptCopySettings(sourceIndex, index) end
		end, function() return buildWindowCopyOptions(index) end, settingsId, 160, function() return getWindowCount() > 1 and db().damageMeterSyncSettings ~= true end),
		{ name = L["Behavior"] or "Behavior", kind = SettingType.Collapsible, id = behaviorId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterAlwaysShowPlayer"] or "Always show player", function() return cfg().alwaysShowPlayer == true end, function(value) self:SetConfigValue(index, "alwaysShowPlayer", value) end, behaviorId),
		dropdownSetting(L["damageMeterSession"] or "Session", function() return cfg().sessionType end, function(value) self:SetConfigValue(index, "sessionType", value == "overall" and "overall" or "current") end, {
			{ value = "current", label = L["damageMeterCurrent"] or "Current" },
			{ value = "overall", label = L["damageMeterOverall"] or "Overall" },
		}, behaviorId, 110),
		dropdownSetting(_G.TYPE or "Type", function() return normalizeDamageMeterTypeKey(cfg().damageMeterType) end, function(value) self:SetConfigValue(index, "damageMeterType", normalizeDamageMeterTypeKey(value)) end, buildDamageMeterTypeOptions, behaviorId, 180),
		dropdownSetting(L["damageMeterVisibility"] or "Show when", function() return cfg().visibility == "combat" and "combat" or "always" end, function(value) self:SetConfigValue(index, "visibility", value == "combat" and "combat" or "always") end, {
			{ value = "always", label = L["Always show"] or "Always show" },
			{ value = "combat", label = L["Always in combat"] or "Always in combat" },
		}, behaviorId, 120),
		{ name = L["Layout"] or "Layout", kind = SettingType.Collapsible, id = layoutId, defaultCollapsed = false },
		sliderSetting(L["damageMeterMaxRows"] or "Max rows", function() return cfg().maxRows end, function(value) self:SetConfigValue(index, "maxRows", clampNumber(value, 1, 30, DEFAULT_WINDOW.maxRows)) end, 1, 30, 1, layoutId),
		sliderSetting(L["damageMeterVisibleRows"] or "Visible rows", function() return cfg().visibleRows end, function(value) self:SetConfigValue(index, "visibleRows", clampNumber(value, 1, 30, DEFAULT_WINDOW.visibleRows)) end, 1, 30, 1, layoutId),
		dividerSetting(layoutId),
		checkboxSetting(L["damageMeterDifferentRaidRows"] or "Different settings in raid", function() return cfg().raidRowsEnabled == true end, function(value) self:SetConfigValue(index, "raidRowsEnabled", value) end, layoutId),
		sliderSetting(L["damageMeterRaidMaxRows"] or "Raid max rows", function() return cfg().raidMaxRows end, function(value) self:SetConfigValue(index, "raidMaxRows", clampNumber(value, 1, 30, DEFAULT_WINDOW.raidMaxRows)) end, 1, 30, 1, layoutId, raidRowsEnabled),
		sliderSetting(L["damageMeterRaidVisibleRows"] or "Raid visible rows", function() return cfg().raidVisibleRows end, function(value) self:SetConfigValue(index, "raidVisibleRows", clampNumber(value, 1, 30, DEFAULT_WINDOW.raidVisibleRows)) end, 1, 30, 1, layoutId, raidRowsEnabled),
		dividerSetting(layoutId),
		sliderSetting(L["Width"] or "Width", function() return cfg().width end, function(value) self:SetConfigValue(index, "width", clampNumber(value, 220, 700, DEFAULT_WINDOW.width)) end, 220, 700, 10, layoutId),
		sliderSetting(L["damageMeterHeightOffset"] or "Height offset", function() return cfg().heightOffset end, function(value) self:SetConfigValue(index, "heightOffset", clampNumber(value, 0, 300, DEFAULT_WINDOW.heightOffset)) end, 0, 300, 1, layoutId),
		dividerSetting(layoutId),
		dropdownSetting(L["damageMeterHeaderPosition"] or "Header position", function() return normalizeHeaderPosition(cfg().headerPosition) end, function(value) self:SetConfigValue(index, "headerPosition", normalizeHeaderPosition(value)) end, buildHeaderPositionOptions(), layoutId, 120),
		dropdownSetting(L["damageMeterRowGrowth"] or "Rows grow", function() return normalizeRowGrowth(cfg().rowGrowth) end, function(value) self:SetConfigValue(index, "rowGrowth", normalizeRowGrowth(value)) end, buildRowGrowthOptions(), layoutId, 120),
		dropdownSetting(L["damageMeterRowSort"] or "Row order", function() return normalizeRowSort(cfg().rowSort) end, function(value) self:SetConfigValue(index, "rowSort", normalizeRowSort(value)) end, buildRowSortOptions(), layoutId, 160),
		dividerSetting(layoutId, nil, windowAnchorVisible),
		dropdownSetting(L["damageMeterAnchorToWindow"] or "Anchor to window", function() return tostring(clampNumber(cfg().anchorToWindow, 0, index - 1, 0)) end, function(value)
			self:SetConfigValue(index, "anchorToWindow", clampNumber(value, 0, index - 1, 0))
			requestEditModeSettingsRefresh()
		end, function() return buildWindowAnchorOptions(index) end, layoutId, 140, nil, windowAnchorVisible),
		dropdownSetting(L["damageMeterWindowAnchorPoint"] or "Anchor point", function() return normalizeFramePoint(cfg().windowAnchorPoint) end, function(value) self:SetConfigValue(index, "windowAnchorPoint", normalizeFramePoint(value)) end, buildFramePointOptions(), layoutId, 180, windowAnchorEnabled, windowAnchorVisible),
		dropdownSetting(L["damageMeterWindowRelativePoint"] or "Relative point", function() return normalizeFramePoint(cfg().windowRelativePoint) end, function(value) self:SetConfigValue(index, "windowRelativePoint", normalizeFramePoint(value)) end, buildFramePointOptions(), layoutId, 180, windowAnchorEnabled, windowAnchorVisible),
		sliderSetting(L["damageMeterWindowOffsetX"] or "Window X offset", function() return cfg().windowOffsetX end, function(value) self:SetConfigValue(index, "windowOffsetX", clampNumber(value, -1000, 1000, DEFAULT_WINDOW.windowOffsetX)) end, -1000, 1000, 1, layoutId, windowAnchorEnabled, windowAnchorVisible),
		sliderSetting(L["damageMeterWindowOffsetY"] or "Window Y offset", function() return cfg().windowOffsetY end, function(value) self:SetConfigValue(index, "windowOffsetY", clampNumber(value, -1000, 1000, DEFAULT_WINDOW.windowOffsetY)) end, -1000, 1000, 1, layoutId, windowAnchorEnabled, windowAnchorVisible),
		{ name = L["Header"] or "Header", kind = SettingType.Collapsible, id = headerId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterShowHeader"] or "Show header", function() return cfg().showHeader == true end, function(value) self:SetConfigValue(index, "showHeader", value) end, headerId),
		checkboxSetting(L["damageMeterShowHeaderSession"] or "Show session", function() return cfg().showHeaderSession ~= false end, function(value) self:SetConfigValue(index, "showHeaderSession", value) end, headerId, headerEnabled),
		checkboxSetting(L["damageMeterShowHeaderType"] or "Show type", function() return cfg().showHeaderType ~= false end, function(value) self:SetConfigValue(index, "showHeaderType", value) end, headerId, headerEnabled),
		checkboxSetting(L["damageMeterShowHeaderTime"] or "Show combat time", function() return cfg().showHeaderTime ~= false end, function(value) self:SetConfigValue(index, "showHeaderTime", value) end, headerId, headerEnabled),
		checkboxSetting(L["damageMeterShowHeaderButtons"] or "Show header buttons", function() return cfg().showHeaderButtons ~= false end, function(value) self:SetConfigValue(index, "showHeaderButtons", value) end, headerId, headerEnabled),
		sliderSetting(L["damageMeterHeaderButtonSize"] or "Header button size", function() return cfg().headerButtonSize end, function(value) self:SetConfigValue(index, "headerButtonSize", clampNumber(value, 10, 32, DEFAULT_WINDOW.headerButtonSize)) end, 10, 32, 1, headerId, function() return cfg().showHeader == true and cfg().showHeaderButtons ~= false end),
		dropdownSetting(L["damageMeterHeaderFormat"] or "Header format", function() return normalizeHeaderFormat(cfg().headerFormat) end, function(value) self:SetConfigValue(index, "headerFormat", normalizeHeaderFormat(value)) end, buildHeaderFormatOptions(), headerId, 150, headerTimeEnabled),
		dropdownSetting(L["damageMeterHeaderTimeFormat"] or "Time format", function() return normalizeHeaderTimeFormat(cfg().headerTimeFormat) end, function(value) self:SetConfigValue(index, "headerTimeFormat", normalizeHeaderTimeFormat(value)) end, buildHeaderTimeFormatOptions(), headerId, 120, headerTimeEnabled),
		dividerSetting(headerId),
		dropdownSetting(L["damageMeterTitleFont"] or "Title font", function() return cfg().titleFontFace end, function(value) self:SetConfigValue(index, "titleFontFace", value) end, buildMediaOptions("font", true), headerId, 260, headerEnabled),
		dropdownSetting(L["damageMeterTitleFontOutline"] or "Title font outline", function() return cfg().titleFontOutline end, function(value) self:SetConfigValue(index, "titleFontOutline", normalizeStyle(value)) end, buildStyleOptions(), headerId, 180, headerEnabled),
		sliderSetting(L["damageMeterTitleFontSize"] or "Title font size", function() return cfg().titleFontSize end, function(value) self:SetConfigValue(index, "titleFontSize", clampNumber(value, 8, 28, DEFAULT_WINDOW.titleFontSize)) end, 8, 28, 1, headerId, headerEnabled),
		colorSetting(L["damageMeterHeaderColor"] or "Header color", function() return normalizeColor(cfg().titleColor, DEFAULT_WINDOW.titleColor) end, function(value) self:SetConfigValue(index, "titleColor", normalizeColor(value, DEFAULT_WINDOW.titleColor)) end, DEFAULT_WINDOW.titleColor, headerId, headerEnabled),
		{ name = L["Status"] or "Status", kind = SettingType.Collapsible, id = statusId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterShowStatus"] or "Show status line", function() return cfg().showStatus ~= false end, function(value) self:SetConfigValue(index, "showStatus", value) end, statusId),
		dropdownSetting(L["damageMeterStatusFont"] or "Status font", function() return cfg().statusFontFace end, function(value) self:SetConfigValue(index, "statusFontFace", value) end, buildMediaOptions("font", true), statusId, 260, statusEnabled),
		dropdownSetting(L["damageMeterStatusFontOutline"] or "Status font outline", function() return cfg().statusFontOutline end, function(value) self:SetConfigValue(index, "statusFontOutline", normalizeStyle(value)) end, buildStyleOptions(), statusId, 180, statusEnabled),
		sliderSetting(L["damageMeterStatusFontSize"] or "Status font size", function() return cfg().statusFontSize end, function(value) self:SetConfigValue(index, "statusFontSize", clampNumber(value, 8, 24, DEFAULT_WINDOW.statusFontSize)) end, 8, 24, 1, statusId, statusEnabled),
		{ name = L["Bar"] or "Bar", kind = SettingType.Collapsible, id = barId, defaultCollapsed = true },
		sliderSetting(L["damageMeterRowHeight"] or "Row height", function() return cfg().rowHeight end, function(value) self:SetConfigValue(index, "rowHeight", clampNumber(value, 10, 70, DEFAULT_WINDOW.rowHeight)) end, 10, 70, 1, barId),
		dividerSetting(barId),
		checkboxSetting(L["damageMeterChangeBarSize"] or "Change bar size", function() return cfg().changeBarSize == true end, function(value) self:SetConfigValue(index, "changeBarSize", value) end, barId),
		sliderSetting(L["damageMeterBarHeight"] or "Bar height", function() return math.min(clampNumber(cfg().barHeight, 1, 70, DEFAULT_WINDOW.barHeight), clampNumber(cfg().rowHeight, 10, 70, DEFAULT_WINDOW.rowHeight)) end, function(value) self:SetConfigValue(index, "barHeight", clampNumber(value, 1, clampNumber(cfg().rowHeight, 10, 70, DEFAULT_WINDOW.rowHeight), DEFAULT_WINDOW.barHeight)) end, 1, 70, 1, barId, customBarSizeEnabled),
		dropdownSetting(L["damageMeterBarAnchor"] or "Bar anchor", function() return normalizeAnchorV(cfg().barAnchor) end, function(value) self:SetConfigValue(index, "barAnchor", normalizeAnchorV(value)) end, buildVerticalAnchorOptions(), barId, 120, customBarSizeEnabled),
		dividerSetting(barId),
		sliderSetting(L["damageMeterBarSpacing"] or "Bar spacing", function() return cfg().barSpacing end, function(value) self:SetConfigValue(index, "barSpacing", clampNumber(value, 0, 16, DEFAULT_WINDOW.barSpacing)) end, 0, 16, 1, barId),
		dividerSetting(barId),
		checkboxSetting(L["damageMeterBarBorder"] or "Bar border", function() return cfg().barBorderEnabled == true end, function(value) self:SetConfigValue(index, "barBorderEnabled", value) end, barId),
		dropdownSetting(L["damageMeterBarBorderTexture"] or "Bar border texture", function() return cfg().barBorderTexture end, function(value) self:SetConfigValue(index, "barBorderTexture", value) end, buildMediaOptions("border", false), barId, 260, barBorderEnabled),
		checkboxSetting(L["damageMeterUseClassColor"] or "Use class color", function() return cfg().barBorderUseClassColor == true end, function(value)
			self:SetConfigValue(index, "barBorderUseClassColor", value)
			requestEditModeSettingsRefresh()
		end, barId, barBorderEnabled),
		colorSetting(L["damageMeterBarBorderColor"] or "Bar border color", function() return normalizeColor(cfg().barBorderColor, DEFAULT_WINDOW.barBorderColor) end, function(value) self:SetConfigValue(index, "barBorderColor", normalizeColor(value, DEFAULT_WINDOW.barBorderColor)) end, DEFAULT_WINDOW.barBorderColor, barId, fixedBarBorderColorEnabled),
		sliderSetting(L["damageMeterBarBorderSize"] or "Bar border size", function() return cfg().barBorderSize end, function(value) self:SetConfigValue(index, "barBorderSize", clampNumber(value, 1, 32, DEFAULT_WINDOW.barBorderSize)) end, 1, 32, 1, barId, barBorderEnabled),
		sliderSetting(L["damageMeterBarBorderOffset"] or "Bar border offset", function() return cfg().barBorderInset end, function(value) self:SetConfigValue(index, "barBorderInset", clampNumber(value, 0, 24, DEFAULT_WINDOW.barBorderInset)) end, 0, 24, 1, barId, barBorderEnabled),
		{ name = L["damageMeterIcon"] or "Icon", kind = SettingType.Collapsible, id = iconId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterChangeIconSize"] or "Change icon size", function() return cfg().changeIconSize == true end, function(value)
			self:SetConfigValue(index, "changeIconSize", value)
			requestEditModeSettingsRefresh()
		end, iconId),
		sliderSetting(L["damageMeterIconSizeOffset"] or "Icon size offset", function() return cfg().iconSizeOffset end, function(value) self:SetConfigValue(index, "iconSizeOffset", clampNumber(value, -60, 0, DEFAULT_WINDOW.iconSizeOffset)) end, -60, 0, 1, iconId, customIconSizeEnabled),
		dividerSetting(iconId),
		checkboxSetting(L["damageMeterIconBorder"] or "Icon border", function() return cfg().iconBorderEnabled == true end, function(value)
			self:SetConfigValue(index, "iconBorderEnabled", value)
			requestEditModeSettingsRefresh()
		end, iconId),
		dropdownSetting(L["damageMeterIconBorderTexture"] or "Icon border texture", function() return cfg().iconBorderTexture end, function(value) self:SetConfigValue(index, "iconBorderTexture", value) end, buildMediaOptions("border", false), iconId, 260, iconBorderEnabled),
		checkboxSetting(L["damageMeterUseClassColor"] or "Use class color", function() return cfg().iconBorderUseClassColor == true end, function(value)
			self:SetConfigValue(index, "iconBorderUseClassColor", value)
			requestEditModeSettingsRefresh()
		end, iconId, iconBorderEnabled),
		colorSetting(L["damageMeterIconBorderColor"] or "Icon border color", function() return normalizeColor(cfg().iconBorderColor, DEFAULT_WINDOW.iconBorderColor) end, function(value) self:SetConfigValue(index, "iconBorderColor", normalizeColor(value, DEFAULT_WINDOW.iconBorderColor)) end, DEFAULT_WINDOW.iconBorderColor, iconId, fixedIconBorderColorEnabled),
		sliderSetting(L["damageMeterIconBorderSize"] or "Icon border size", function() return cfg().iconBorderSize end, function(value) self:SetConfigValue(index, "iconBorderSize", clampNumber(value, 1, 32, DEFAULT_WINDOW.iconBorderSize)) end, 1, 32, 1, iconId, iconBorderEnabled),
		sliderSetting(L["damageMeterIconBorderOffset"] or "Icon border offset", function() return cfg().iconBorderInset end, function(value) self:SetConfigValue(index, "iconBorderInset", clampNumber(value, 0, 24, DEFAULT_WINDOW.iconBorderInset)) end, 0, 24, 1, iconId, iconBorderEnabled),
		{ name = L["damageMeterNames"] or "Names", kind = SettingType.Collapsible, id = namesId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterShowNames"] or "Show names", function() return cfg().showNames == true end, function(value) self:SetConfigValue(index, "showNames", value) end, namesId),
		checkboxSetting(L["damageMeterHideRealmNames"] or "Hide realm names", function() return cfg().hideRealmNames ~= false end, function(value) self:SetConfigValue(index, "hideRealmNames", value) end, namesId, namesEnabled),
		checkboxSetting(L["damageMeterNameUseClassColor"] or "Use class color for names", function() return cfg().nameUseClassColors == true end, function(value) self:SetConfigValue(index, "nameUseClassColors", value) end, namesId, namesEnabled),
		colorSetting(L["damageMeterNameColor"] or "Name color", function() return normalizeColor(cfg().nameColor, DEFAULT_WINDOW.nameColor) end, function(value) self:SetConfigValue(index, "nameColor", normalizeColor(value, DEFAULT_WINDOW.nameColor)) end, DEFAULT_WINDOW.nameColor, namesId, fixedNameColorEnabled),
		dividerSetting(namesId),
		dropdownSetting(L["damageMeterNameFont"] or "Name font", function() return cfg().fontFace end, function(value) self:SetConfigValue(index, "fontFace", value) end, buildMediaOptions("font", true), namesId, 260, namesEnabled),
		dropdownSetting(L["damageMeterNameFontOutline"] or "Name font outline", function() return cfg().fontOutline end, function(value) self:SetConfigValue(index, "fontOutline", normalizeStyle(value)) end, buildStyleOptions(), namesId, 180, namesEnabled),
		sliderSetting(L["damageMeterNameFontSize"] or "Name font size", function() return cfg().fontSize end, function(value) self:SetConfigValue(index, "fontSize", clampNumber(value, 8, 24, DEFAULT_WINDOW.fontSize)) end, 8, 24, 1, namesId, namesEnabled),
		dividerSetting(namesId),
		dropdownSetting(L["damageMeterNameAnchorH"] or "Name horizontal anchor", function() return normalizeAnchorH(cfg().nameAnchorH) end, function(value) self:SetConfigValue(index, "nameAnchorH", normalizeAnchorH(value)) end, buildHorizontalAnchorOptions(), namesId, 120, namesEnabled),
		dropdownSetting(L["damageMeterNameAnchorV"] or "Name vertical anchor", function() return normalizeAnchorV(cfg().nameAnchorV) end, function(value) self:SetConfigValue(index, "nameAnchorV", normalizeAnchorV(value)) end, buildVerticalAnchorOptions(), namesId, 120, namesEnabled),
		sliderSetting(L["damageMeterNameOffsetX"] or "Name X offset", function() return cfg().nameOffsetX end, function(value) self:SetConfigValue(index, "nameOffsetX", clampNumber(value, -200, 200, DEFAULT_WINDOW.nameOffsetX)) end, -200, 200, 1, namesId, namesEnabled),
		sliderSetting(L["damageMeterNameOffsetY"] or "Name Y offset", function() return cfg().nameOffsetY end, function(value) self:SetConfigValue(index, "nameOffsetY", clampNumber(value, -200, 200, DEFAULT_WINDOW.nameOffsetY)) end, -200, 200, 1, namesId, namesEnabled),
		{ name = L["damageMeterValues"] or "Values", kind = SettingType.Collapsible, id = valuesId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterShowPercent"] or "Show percent", function() return cfg().showPercent ~= false end, function(value) self:SetConfigValue(index, "showPercent", value) end, valuesId),
		dividerSetting(valuesId),
		checkboxSetting(L["damageMeterUseClassColor"] or "Use class color", function() return cfg().valueUseClassColors == true end, function(value)
			self:SetConfigValue(index, "valueUseClassColors", value)
			requestEditModeSettingsRefresh()
		end, valuesId),
		colorSetting(L["damageMeterValueColor"] or "Value color", function() return normalizeColor(cfg().valueColor, DEFAULT_WINDOW.valueColor) end, function(value) self:SetConfigValue(index, "valueColor", normalizeColor(value, DEFAULT_WINDOW.valueColor)) end, DEFAULT_WINDOW.valueColor, valuesId, fixedValueColorEnabled),
		dividerSetting(valuesId),
		dropdownSetting(L["damageMeterValueFont"] or "Value font", function() return cfg().valueFontFace end, function(value) self:SetConfigValue(index, "valueFontFace", value) end, buildMediaOptions("font", true), valuesId, 260),
		dropdownSetting(L["damageMeterValueFontOutline"] or "Value font outline", function() return cfg().valueFontOutline end, function(value) self:SetConfigValue(index, "valueFontOutline", normalizeStyle(value)) end, buildStyleOptions(), valuesId, 180),
		sliderSetting(L["damageMeterValueFontSize"] or "Value font size", function() return cfg().valueFontSize end, function(value) self:SetConfigValue(index, "valueFontSize", clampNumber(value, 8, 24, DEFAULT_WINDOW.valueFontSize)) end, 8, 24, 1, valuesId),
		dividerSetting(valuesId),
		dropdownSetting(L["damageMeterValueAnchorH"] or "Value horizontal anchor", function() return normalizeAnchorH(cfg().valueAnchorH) end, function(value) self:SetConfigValue(index, "valueAnchorH", normalizeAnchorH(value)) end, buildHorizontalAnchorOptions(), valuesId, 120),
		dropdownSetting(L["damageMeterValueAnchorV"] or "Value vertical anchor", function() return normalizeAnchorV(cfg().valueAnchorV) end, function(value) self:SetConfigValue(index, "valueAnchorV", normalizeAnchorV(value)) end, buildVerticalAnchorOptions(), valuesId, 120),
		sliderSetting(L["damageMeterValueOffsetX"] or "Value X offset", function() return cfg().valueOffsetX end, function(value) self:SetConfigValue(index, "valueOffsetX", clampNumber(value, -200, 200, DEFAULT_WINDOW.valueOffsetX)) end, -200, 200, 1, valuesId),
		sliderSetting(L["damageMeterValueOffsetY"] or "Value Y offset", function() return cfg().valueOffsetY end, function(value) self:SetConfigValue(index, "valueOffsetY", clampNumber(value, -200, 200, DEFAULT_WINDOW.valueOffsetY)) end, -200, 200, 1, valuesId),
		dividerSetting(valuesId),
		dropdownSetting(L["damageMeterAbbreviation"] or "Number format", function() return cfg().abbreviation end, function(value) self:SetConfigValue(index, "abbreviation", value == "none" and "none" or "short") end, {
			{ value = "short", label = L["damageMeterAbbreviationShort"] or "Abbreviated" },
			{ value = "none", label = L["damageMeterAbbreviationFull"] or "Full numbers" },
		}, valuesId, 100),
		dropdownSetting(L["damageMeterValueFormat"] or "Value format", function() return cfg().valueFormat end, function(value) self:SetConfigValue(index, "valueFormat", value == "parentheses" and "parentheses" or "slash") end, {
			{ value = "slash", label = L["damageMeterValueFormatSlash"] or "<total> / <DPS>" },
			{ value = "parentheses", label = L["damageMeterValueFormatParentheses"] or "<total> (<DPS>)" },
		}, valuesId, 110),
		{ name = L["damageMeterTooltip"] or "Tooltip", kind = SettingType.Collapsible, id = tooltipId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterTooltipEnabled"] or "Show row tooltip", function() return cfg().tooltipEnabled == true end, function(value) self:SetConfigValue(index, "tooltipEnabled", value) end, tooltipId),
		checkboxSetting(L["damageMeterTooltipPreview"] or "Preview tooltip", function() return cfg().tooltipPreview == true end, function(value) self:SetConfigValue(index, "tooltipPreview", value) end, tooltipId, tooltipEnabled),
		dividerSetting(tooltipId),
		checkboxSetting(L["damageMeterTooltipShowAmount"] or "Show amount column", function() return cfg().tooltipShowAmount ~= false end, function(value) self:SetConfigValue(index, "tooltipShowAmount", value) end, tooltipId, tooltipEnabled),
		checkboxSetting(L["damageMeterTooltipShowBars"] or "Show bars", function() return cfg().tooltipShowBars == true end, function(value) self:SetConfigValue(index, "tooltipShowBars", value) end, tooltipId, tooltipEnabled),
		checkboxSetting(L["damageMeterTooltipShowDPS"] or "Show DPS column", function() return cfg().tooltipShowDPS ~= false end, function(value) self:SetConfigValue(index, "tooltipShowDPS", value) end, tooltipId, tooltipEnabled),
		checkboxSetting(L["damageMeterTooltipShowPercent"] or "Show percent column", function() return cfg().tooltipShowPercent ~= false end, function(value) self:SetConfigValue(index, "tooltipShowPercent", value) end, tooltipId, tooltipEnabled),
		checkboxSetting(L["damageMeterTooltipShowTargets"] or "Show targets", function() return cfg().tooltipShowTargets ~= false end, function(value) self:SetConfigValue(index, "tooltipShowTargets", value) end, tooltipId, tooltipEnabled),
		dividerSetting(tooltipId),
		dropdownSetting(L["damageMeterTooltipAnchor"] or "Tooltip anchor", function() return normalizeTooltipAnchor(cfg().tooltipAnchor) end, function(value) self:SetConfigValue(index, "tooltipAnchor", normalizeTooltipAnchor(value)) end, buildTooltipAnchorOptions(), tooltipId, 120, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipOffsetX"] or "Tooltip X offset", function() return cfg().tooltipOffsetX end, function(value) self:SetConfigValue(index, "tooltipOffsetX", clampNumber(value, -300, 300, DEFAULT_WINDOW.tooltipOffsetX)) end, -300, 300, 1, tooltipId, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipOffsetY"] or "Tooltip Y offset", function() return cfg().tooltipOffsetY end, function(value) self:SetConfigValue(index, "tooltipOffsetY", clampNumber(value, -300, 300, DEFAULT_WINDOW.tooltipOffsetY)) end, -300, 300, 1, tooltipId, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipWidth"] or "Tooltip width", function() return cfg().tooltipWidth end, function(value) self:SetConfigValue(index, "tooltipWidth", clampNumber(value, 220, 600, DEFAULT_WINDOW.tooltipWidth)) end, 220, 600, 10, tooltipId, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipMaxLines"] or "Tooltip max lines", function() return cfg().tooltipMaxLines end, function(value) self:SetConfigValue(index, "tooltipMaxLines", clampNumber(value, 4, 30, DEFAULT_WINDOW.tooltipMaxLines)) end, 4, 30, 1, tooltipId, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipFontSize"] or "Tooltip font size", function() return cfg().tooltipFontSize end, function(value) self:SetConfigValue(index, "tooltipFontSize", clampNumber(value, 8, 24, DEFAULT_WINDOW.tooltipFontSize)) end, 8, 24, 1, tooltipId, tooltipEnabled),
		dividerSetting(tooltipId),
		dropdownSetting(L["damageMeterTooltipBarTexture"] or "Tooltip bar texture", function() return cfg().tooltipBarTexture end, function(value) self:SetConfigValue(index, "tooltipBarTexture", value) end, buildMediaOptions("statusbar", false), tooltipId, 260, tooltipEnabled),
		colorSetting(L["damageMeterTooltipBarColor"] or "Tooltip bar color", function() return normalizeColor(cfg().tooltipBarColor, DEFAULT_WINDOW.tooltipBarColor) end, function(value) self:SetConfigValue(index, "tooltipBarColor", normalizeColor(value, DEFAULT_WINDOW.tooltipBarColor)) end, DEFAULT_WINDOW.tooltipBarColor, tooltipId, tooltipEnabled),
		dropdownSetting(L["damageMeterTooltipBackgroundTexture"] or "Tooltip background texture", function() return cfg().tooltipBackdropTexture end, function(value) self:SetConfigValue(index, "tooltipBackdropTexture", value) end, buildMediaOptions("statusbar", false), tooltipId, 260, tooltipEnabled),
		colorSetting(L["damageMeterTooltipBackgroundColor"] or "Tooltip background color", function() return normalizeColor(cfg().tooltipBackdropColor, DEFAULT_WINDOW.tooltipBackdropColor) end, function(value) self:SetConfigValue(index, "tooltipBackdropColor", normalizeColor(value, DEFAULT_WINDOW.tooltipBackdropColor)) end, DEFAULT_WINDOW.tooltipBackdropColor, tooltipId, tooltipEnabled),
		dropdownSetting(L["damageMeterTooltipBorderTexture"] or "Tooltip border texture", function() return cfg().tooltipBorderTexture end, function(value) self:SetConfigValue(index, "tooltipBorderTexture", value) end, buildMediaOptions("border", false), tooltipId, 260, tooltipEnabled),
		colorSetting(L["damageMeterTooltipBorderColor"] or "Tooltip border color", function() return normalizeColor(cfg().tooltipBorderColor, DEFAULT_WINDOW.tooltipBorderColor) end, function(value) self:SetConfigValue(index, "tooltipBorderColor", normalizeColor(value, DEFAULT_WINDOW.tooltipBorderColor)) end, DEFAULT_WINDOW.tooltipBorderColor, tooltipId, tooltipEnabled),
		sliderSetting(L["damageMeterTooltipBorderSize"] or "Tooltip border size", function() return cfg().tooltipBorderSize end, function(value) self:SetConfigValue(index, "tooltipBorderSize", clampNumber(value, 1, 32, DEFAULT_WINDOW.tooltipBorderSize)) end, 1, 32, 1, tooltipId, tooltipEnabled),
		{ name = L["Ranking"] or "Ranking", kind = SettingType.Collapsible, id = rankingId, defaultCollapsed = true },
		checkboxSetting(L["damageMeterShowRanks"] or "Show ranks", function() return cfg().showRanks ~= false end, function(value) self:SetConfigValue(index, "showRanks", value) end, rankingId),
		checkboxSetting(L["damageMeterPrefixRankInName"] or "Prefix rank in name", function() return cfg().prefixRankInName == true end, function(value) self:SetConfigValue(index, "prefixRankInName", value) end, rankingId, rankingEnabled),
		dropdownSetting(L["damageMeterRankFont"] or "Rank font", function() return cfg().rankFontFace end, function(value) self:SetConfigValue(index, "rankFontFace", value) end, buildMediaOptions("font", true), rankingId, 260, rankColumnEnabled),
		dropdownSetting(L["damageMeterRankFontOutline"] or "Rank font outline", function() return cfg().rankFontOutline end, function(value) self:SetConfigValue(index, "rankFontOutline", normalizeStyle(value)) end, buildStyleOptions(), rankingId, 180, rankColumnEnabled),
		sliderSetting(L["damageMeterRankFontSize"] or "Rank font size", function() return cfg().rankFontSize end, function(value) self:SetConfigValue(index, "rankFontSize", clampNumber(value, 8, 24, DEFAULT_WINDOW.rankFontSize)) end, 8, 24, 1, rankingId, rankColumnEnabled),
		sliderSetting(L["damageMeterRankGap"] or "Rank gap", function() return cfg().rankGap end, function(value) self:SetConfigValue(index, "rankGap", clampNumber(value, 0, 24, DEFAULT_WINDOW.rankGap)) end, 0, 24, 1, rankingId, rankingEnabled),
		{ name = L["Media"] or "Media", kind = SettingType.Collapsible, id = mediaId, defaultCollapsed = true },
		dropdownSetting(L["Texture"] or "Texture", function() return cfg().texture end, function(value) self:SetConfigValue(index, "texture", value) end, buildMediaOptions("statusbar", false), mediaId, 260),
		dropdownSetting(L["Backdrop texture"] or "Backdrop texture", function() return cfg().backdropTexture end, function(value) self:SetConfigValue(index, "backdropTexture", value) end, buildMediaOptions("statusbar", false), mediaId, 260),
		colorSetting(L["Background color"] or "Background color", function() return normalizeColor(cfg().backdropColor, DEFAULT_WINDOW.backdropColor) end, function(value) self:SetConfigValue(index, "backdropColor", normalizeColor(value, DEFAULT_WINDOW.backdropColor)) end, DEFAULT_WINDOW.backdropColor, mediaId),
		checkboxSetting(L["damageMeterUseClassColors"] or "Use class colors", function() return cfg().useClassColors == true end, function(value) self:SetConfigValue(index, "useClassColors", value) end, mediaId),
		{ name = L["Border"] or "Border", kind = SettingType.Collapsible, id = borderId, defaultCollapsed = true },
		checkboxSetting(L["Use border"] or "Use border", function() return cfg().borderEnabled == true end, function(value) self:SetConfigValue(index, "borderEnabled", value) end, borderId),
		dropdownSetting(L["Border texture"] or "Border texture", function() return cfg().borderTexture end, function(value) self:SetConfigValue(index, "borderTexture", value) end, buildMediaOptions("border", false), borderId, 260),
		colorSetting(L["Border color"] or "Border color", function() return normalizeColor(cfg().borderColor, DEFAULT_WINDOW.borderColor) end, function(value) self:SetConfigValue(index, "borderColor", normalizeColor(value, DEFAULT_WINDOW.borderColor)) end, DEFAULT_WINDOW.borderColor, borderId),
		sliderSetting(L["Border size"] or "Border size", function() return cfg().borderSize end, function(value) self:SetConfigValue(index, "borderSize", clampNumber(value, 1, 32, DEFAULT_WINDOW.borderSize)) end, 1, 32, 1, borderId),
		sliderSetting(L["Border offset"] or "Border offset", function() return cfg().borderInset end, function(value) self:SetConfigValue(index, "borderInset", clampNumber(value, 0, 24, DEFAULT_WINDOW.borderInset)) end, 0, 24, 1, borderId),
	}
	return settings
end

function DamageMeter:BuildWindowButtons(index)
	local buttons = {
		{
			text = L["damageMeterAddWindow"] or "Add new window",
			click = function() DamageMeter:AddWindow(index) end,
		},
	}
	if index > 1 then
		buttons[#buttons + 1] = {
			text = L["damageMeterRemoveWindow"] or "Remove window",
			click = function() DamageMeter:PromptRemoveWindow(index) end,
		}
	end
	return buttons
end

function DamageMeter:RegisterEditMode()
	if self.editModeRegistered or not (EditMode and EditMode.RegisterFrame and SettingType) then return end
	for index = 1, MAX_WINDOWS do
		EditMode:RegisterFrame(EDITMODE_ID_PREFIX .. index, {
			frame = self:EnsureWindow(index),
			title = string.format("%s %d", L["damageMeterTitle"] or "Damage Meter", index),
			layoutDefaults = { point = "CENTER", relativePoint = "CENTER", x = 300, y = -120 - ((index - 1) * 30) },
			onApply = function() DamageMeter:RefreshWindow(index) end,
			onEnter = function() DamageMeter:RefreshWindow(index) end,
			onExit = function() C_Timer.After(0, function() DamageMeter:RefreshWindow(index) end) end,
			isEnabled = function() return DamageMeter:ShouldShow(index) end,
			settings = self:BuildWindowSettings(index),
			buttons = self:BuildWindowButtons(index),
			showOutsideEditMode = true,
			showReset = false,
			showSettingsReset = false,
			enableOverlayToggle = true,
			collapseExclusive = true,
			settingsMaxHeight = 520,
		})
	end
	self.editModeRegistered = true
end

function DamageMeter:Init()
	if self.initialized then return end
	self.initialized = true
	self:GetWindowsDB()
	for index = 1, MAX_WINDOWS do
		self:EnsureWindow(index)
	end
	self:RegisterEditMode()
	self.eventFrame = CreateFrame("Frame")
	self.partyClassGeneration = 0
	self.currentPartyClassGeneration = 0
	self.eventFrame:SetScript("OnEvent", function(_, event, damageMeterType, sessionID)
		if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
			self:InvalidatePartyClassFallback()
		elseif event == "PLAYER_REGEN_DISABLED" then
			self:MarkPartyClassFallbackCurrent()
		elseif event == "DAMAGE_METER_RESET" then
			self:InvalidatePartyClassFallback()
			self:MarkPartyClassFallbackCurrent()
		end
		if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
			self:RefreshFromLiveEvent(damageMeterType, sessionID)
		elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
			self:RefreshFromLiveEvent()
		else
			self:ScheduleRefresh()
		end
	end)
	self:UpdateEventState()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	DamageMeter:Init()
end)
