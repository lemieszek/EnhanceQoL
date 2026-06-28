local addonName, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local function applyParentSection(entries, section)
	for _, entry in ipairs(entries or {}) do
		entry.parentSection = section
		if entry.children then applyParentSection(entry.children, section) end
	end
end

local function NormalizeQuestAutomationModifier(value)
	if value == "SHIFT" or value == "CTRL" or value == "ALT" or value == "NONE" then return value end
	return nil
end

local cQuest = addon.SettingsLayout.rootGAMEPLAY
addon.SettingsLayout.questCategory = cQuest

local questingExpandable = addon.functions.SettingsCreateExpandableSection(cQuest, {
	name = L["QuestingAndCinematics"] or "Questing & Cinematics",
	newTagID = "Questing",
	iconKey = "questing",
	expanded = false,
	colorizeTitle = false,
	modernOnly = true,
})

local REMOVE_IGNORED_QUEST_NPC_DIALOG = addonName .. "QuestIgnoredNPCRemove"

local QUEST_TRACKER_QUEST_COUNT_COLOR = { r = 1, g = 210 / 255, b = 0 }
local questTrackerQuestCountFrame
local questTrackerQuestCountText
local questTrackerQuestCountWatcher
local questTrackerMainHeaderHiddenHooked
local questTrackerMainHeaderHiddenWatcher
local objectiveTrackerMinimizeWatcher
local objectiveTrackerMinimizeHooked
local objectiveTrackerCollapseHooked
local questTrackerTextStyleHooked = {}
local questTrackerTextStyleWatcher
local questTrackerTextStyleFontOrder = {}
local questTrackerTextStyleRefreshing
local questTrackerTextStyleState = {
	color = {},
	font = {},
	version = 0,
}
local QUEST_TRACKER_TEXT_STYLE_TRACKER_NAMES = {
	"QuestObjectiveTracker",
	"CampaignQuestObjectiveTracker",
}
local OBJECTIVE_TRACKER_MINIMIZE_ANCHORS = {
	TOPLEFT = { point = "TOPLEFT", x = 1, y = 0 },
	TOPRIGHT = { point = "TOPRIGHT", x = -1, y = 0 },
	BOTTOMLEFT = { point = "BOTTOMLEFT", x = 1, y = 0 },
	BOTTOMRIGHT = { point = "BOTTOMRIGHT", x = -1, y = 0 },
}
local QUEST_TRACKER_TEXT_STYLE_DEFAULTS = {
	moduleHeaderColor = { r = 1, g = 210 / 255, b = 0, a = 1 },
	moduleHeaderFontSize = 14,
	objectiveCompleteColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
	objectiveColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
	objectiveFontSize = 12,
	objectiveHoverColor = { r = 1, g = 1, b = 1, a = 1 },
	questTitleColor = { r = 1, g = 210 / 255, b = 0, a = 1 },
	questTitleFontSize = 12,
	questTitleHoverColor = { r = 1, g = 1, b = 1, a = 1 },
}
local QUEST_TRACKER_TEXT_STYLE_COLOR_DEFAULTS = {
	questTrackerTextStyleModuleHeaderColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.moduleHeaderColor,
	questTrackerTextStyleObjectiveCompleteColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.objectiveCompleteColor,
	questTrackerTextStyleObjectiveColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.objectiveColor,
	questTrackerTextStyleObjectiveHoverColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.objectiveHoverColor,
	questTrackerTextStyleQuestTitleColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.questTitleColor,
	questTrackerTextStyleQuestTitleHoverColor = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.questTitleHoverColor,
}
local QUEST_TRACKER_TEXT_STYLE_SIZE_DEFAULTS = {
	questTrackerTextStyleModuleHeaderFontSize = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.moduleHeaderFontSize,
	questTrackerTextStyleObjectiveFontSize = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.objectiveFontSize,
	questTrackerTextStyleQuestTitleFontSize = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.questTitleFontSize,
}

local function GetQuestTrackerDefaultFontFace()
	return addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT
end

local function GetQuestTrackerDefaultFontOutline()
	return addon.functions.GetGlobalFontStyleConfigKey and addon.functions.GetGlobalFontStyleConfigKey() or "OUTLINE"
end

local function InvalidateQuestTrackerTextStyleCache()
	questTrackerTextStyleState.version = questTrackerTextStyleState.version + 1
	wipe(questTrackerTextStyleState.color)
	wipe(questTrackerTextStyleState.font)
end

local function BuildQuestTrackerFontDropdown()
	local map = {
		[(addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT] = L["actionBarFontDefault"] or "Blizzard Font",
	}
	local globalKey = GetQuestTrackerDefaultFontFace()
	map[globalKey] = addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or (L["Global Font"] or "Global Font")
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM then
		local names = LSM:List("font") or {}
		local hash = LSM:HashTable("font") or {}
		for i = 1, #names do
			local name = names[i]
			local path = hash[name]
			if type(path) == "string" and path ~= "" then map[path] = tostring(name) end
		end
	end
	local list, order = addon.functions.prepareListForDropdown(map)
	wipe(questTrackerTextStyleFontOrder)
	if list[globalKey] then questTrackerTextStyleFontOrder[#questTrackerTextStyleFontOrder + 1] = globalKey end
	for _, key in ipairs(order) do
		if key ~= globalKey then questTrackerTextStyleFontOrder[#questTrackerTextStyleFontOrder + 1] = key end
	end
	return list
end

local function IsQuestTrackerTextStyleEnabled()
	return addon and addon.db and addon.db.questTrackerTextStyleEnabled == true
end

local function GetQuestTrackerTextStyleColor(key)
	local value = addon.db and addon.db[key]
	local fallback = QUEST_TRACKER_TEXT_STYLE_COLOR_DEFAULTS[key]
	if type(value) ~= "table" then value = fallback end
	return value or fallback
end

local function GetQuestTrackerTextStyleSize(key)
	local value = addon.db and tonumber(addon.db[key])
	local fallback = QUEST_TRACKER_TEXT_STYLE_SIZE_DEFAULTS[key] or 12
	if not value or value < 6 then value = fallback end
	return value
end

local function QuestTrackerTextStyleColorMatches(color, r, g, b)
	if type(color) ~= "table" or r == nil or g == nil or b == nil then return false end
	return math.abs((color.r or 0) - r) <= 0.002
		and math.abs((color.g or 0) - g) <= 0.002
		and math.abs((color.b or 0) - b) <= 0.002
end

local function UpdateQuestTrackerTextStyleCompleteFlag(fontString, r, g, b)
	if not fontString or fontString._eqolQuestTrackerTextRole ~= "objective" then return end
	local colors = _G.OBJECTIVE_TRACKER_COLOR
	if not colors then return end
	if QuestTrackerTextStyleColorMatches(colors.Complete, r, g, b) then
		fontString._eqolQuestTrackerCompleteObjective = true
	elseif QuestTrackerTextStyleColorMatches(colors.Normal, r, g, b)
		or QuestTrackerTextStyleColorMatches(colors.NormalHighlight, r, g, b)
		or QuestTrackerTextStyleColorMatches(colors.Failed, r, g, b)
		or QuestTrackerTextStyleColorMatches(colors.FailedHighlight, r, g, b) then
		fontString._eqolQuestTrackerCompleteObjective = nil
	end
end

local function ApplyQuestTrackerTextStyleColor(fontString)
	if not (fontString and fontString.SetTextColor) or fontString._eqolQuestTrackerApplyingColor then return end
	if not IsQuestTrackerTextStyleEnabled() then return end
	local role = fontString._eqolQuestTrackerTextRole
	if not role then return end
	local block = fontString._eqolQuestTrackerBlock
	local highlighted = block and block.isHighlighted
	local colorKey
	if role == "moduleHeader" then
		colorKey = "questTrackerTextStyleModuleHeaderColor"
	elseif role == "title" then
		colorKey = highlighted and "questTrackerTextStyleQuestTitleHoverColor" or "questTrackerTextStyleQuestTitleColor"
	elseif fontString._eqolQuestTrackerCompleteObjective then
		colorKey = "questTrackerTextStyleObjectiveCompleteColor"
	else
		colorKey = highlighted and "questTrackerTextStyleObjectiveHoverColor" or "questTrackerTextStyleObjectiveColor"
	end
	local color = questTrackerTextStyleState.color[colorKey]
	if not color then
		color = GetQuestTrackerTextStyleColor(colorKey)
		questTrackerTextStyleState.color[colorKey] = color
	end
	local r, g, b, a = color.r or 1, color.g or 1, color.b or 1, color.a or 1
	if
		fontString._eqolQuestTrackerColorKey == colorKey
		and fontString._eqolQuestTrackerColorR == r
		and fontString._eqolQuestTrackerColorG == g
		and fontString._eqolQuestTrackerColorB == b
		and fontString._eqolQuestTrackerColorA == a
	then
		return
	end
	fontString._eqolQuestTrackerApplyingColor = true
	fontString:SetTextColor(r, g, b, a)
	fontString._eqolQuestTrackerApplyingColor = nil
	fontString._eqolQuestTrackerColorKey = colorKey
	fontString._eqolQuestTrackerColorR = r
	fontString._eqolQuestTrackerColorG = g
	fontString._eqolQuestTrackerColorB = b
	fontString._eqolQuestTrackerColorA = a
end

local function HookQuestTrackerTextStyleColor(fontString)
	if not (fontString and fontString.SetTextColor) or fontString._eqolQuestTrackerColorHooked or not hooksecurefunc then return end
	fontString._eqolQuestTrackerColorHooked = true
	hooksecurefunc(fontString, "SetTextColor", function(text, r, g, b)
		if text and not text._eqolQuestTrackerApplyingColor then UpdateQuestTrackerTextStyleCompleteFlag(text, r, g, b) end
		ApplyQuestTrackerTextStyleColor(text)
	end)
end

local function IsQuestTrackerTextStyleCompleteLine(line)
	if not line then return false end
	local completeStyle = _G.OBJECTIVE_TRACKER_COLOR and _G.OBJECTIVE_TRACKER_COLOR.Complete
	if completeStyle and line.Text and line.Text.colorStyle == completeStyle then return true end
	return _G.ObjectiveTrackerAnimLineState
		and (line.state == _G.ObjectiveTrackerAnimLineState.Completed or line.state == _G.ObjectiveTrackerAnimLineState.Completing)
end

local function GetQuestTrackerTextStyleFontConfig(role)
	local globalFontStateVersion = addon.functions and addon.functions.GetGlobalFontStateVersion and addon.functions.GetGlobalFontStateVersion() or 0
	local db = addon.db or {}
	local sizeKey = role == "moduleHeader" and "questTrackerTextStyleModuleHeaderFontSize"
		or role == "title" and "questTrackerTextStyleQuestTitleFontSize"
		or "questTrackerTextStyleObjectiveFontSize"
	local fontFace = db.questTrackerTextStyleFontFace or GetQuestTrackerDefaultFontFace()
	local fontOutline = db.questTrackerTextStyleFontOutline or GetQuestTrackerDefaultFontOutline()
	local size = GetQuestTrackerTextStyleSize(sizeKey)
	local cacheKey = role
	local cached = questTrackerTextStyleState.font[cacheKey]
	if
		cached
		and cached.version == questTrackerTextStyleState.version
		and cached.globalFontStateVersion == globalFontStateVersion
		and cached.fontFace == fontFace
		and cached.fontOutline == fontOutline
		and cached.size == size
	then
		return cached
	end

	local defaultFont = (addon.variables and addon.variables.defaultFont) or STANDARD_TEXT_FONT
	local fallbackFace = addon.functions.ResolveFontFace and addon.functions.ResolveFontFace(defaultFont, defaultFont) or defaultFont
	local resolvedFace = addon.functions.ResolveFontFace and addon.functions.ResolveFontFace(fontFace, fallbackFace) or fontFace
	local styleChoice, flags, shadowAlpha, shadowX, shadowY
	if addon.functions.ResolveFontStyle then
		styleChoice, flags, shadowAlpha, shadowX, shadowY = addon.functions.ResolveFontStyle(fontOutline, "OUTLINE")
	else
		styleChoice, flags, shadowAlpha, shadowX, shadowY = fontOutline, fontOutline, 0, 0, 0
	end
	cached = {
		fallbackFace = fallbackFace,
		flags = flags,
		fontFace = fontFace,
		globalFontStateVersion = globalFontStateVersion,
		key = table.concat({
			tostring(resolvedFace or ""),
			tostring(fallbackFace or ""),
			tostring(size or ""),
			tostring(flags or ""),
			tostring(shadowAlpha or 0),
			tostring(shadowX or 0),
			tostring(shadowY or 0),
		}, "\001"),
		resolvedFace = resolvedFace,
		shadowAlpha = shadowAlpha or 0,
		shadowX = shadowX or 0,
		shadowY = shadowY or 0,
		size = size,
		styleChoice = styleChoice,
		fontOutline = fontOutline,
		version = questTrackerTextStyleState.version,
	}
	questTrackerTextStyleState.font[cacheKey] = cached
	return cached
end

local function ApplyQuestTrackerTextStyleFont(fontString, role)
	if not (fontString and fontString.SetFont) then return end
	local cfg = GetQuestTrackerTextStyleFontConfig(role)
	if fontString._eqolQuestTrackerFontKey == cfg.key then return end
	local ok, applied = pcall(fontString.SetFont, fontString, cfg.resolvedFace, cfg.size, cfg.flags)
	if (not ok or applied == false) and cfg.fallbackFace and cfg.fallbackFace ~= cfg.resolvedFace then
		pcall(fontString.SetFont, fontString, cfg.fallbackFace, cfg.size, cfg.flags)
	end
	if fontString.SetShadowColor and fontString.SetShadowOffset then
		if cfg.shadowAlpha and cfg.shadowAlpha > 0 then
			fontString:SetShadowColor(0, 0, 0, cfg.shadowAlpha)
			fontString:SetShadowOffset(cfg.shadowX or 1, cfg.shadowY or -1)
		else
			fontString:SetShadowColor(0, 0, 0, 0)
			fontString:SetShadowOffset(0, 0)
		end
	end
	fontString._eqolQuestTrackerFontKey = cfg.key
end

local function ApplyQuestTrackerTextStyleFontString(fontString, role, block, line)
	if not fontString then return false end
	local completeObjective = role == "objective" and IsQuestTrackerTextStyleCompleteLine(line) or nil
	local highlighted = block and block.isHighlighted or nil
	fontString._eqolQuestTrackerTextRole = role
	fontString._eqolQuestTrackerBlock = block
	fontString._eqolQuestTrackerCompleteObjective = completeObjective
	HookQuestTrackerTextStyleColor(fontString)
	if not IsQuestTrackerTextStyleEnabled() then
		return false
	end
	if
		fontString._eqolQuestTrackerAppliedVersion == questTrackerTextStyleState.version
		and fontString._eqolQuestTrackerAppliedRole == role
		and fontString._eqolQuestTrackerAppliedBlock == block
		and fontString._eqolQuestTrackerAppliedHighlighted == highlighted
		and fontString._eqolQuestTrackerAppliedCompleteObjective == completeObjective
	then
		return false
	end

	ApplyQuestTrackerTextStyleFont(fontString, role)
	if fontString.SetWordWrap and role ~= "moduleHeader" and fontString._eqolQuestTrackerWordWrap ~= true then
		fontString:SetWordWrap(true)
		fontString._eqolQuestTrackerWordWrap = true
	end
	ApplyQuestTrackerTextStyleColor(fontString)
	fontString._eqolQuestTrackerAppliedVersion = questTrackerTextStyleState.version
	fontString._eqolQuestTrackerAppliedRole = role
	fontString._eqolQuestTrackerAppliedBlock = block
	fontString._eqolQuestTrackerAppliedHighlighted = highlighted
	fontString._eqolQuestTrackerAppliedCompleteObjective = completeObjective
	return true
end

local function UpdateQuestTrackerFontStringHeight(fontString, padding)
	if not (fontString and fontString.GetStringHeight and fontString.SetHeight) then return end
	local height = math.max(1, (fontString:GetStringHeight() or 0) + (padding or 0))
	if fontString._eqolQuestTrackerHeight ~= height then
		fontString:SetHeight(height)
		fontString._eqolQuestTrackerHeight = height
	end
end

local function HandleQuestTrackerTextStyleLine(block, line)
	if not line then return end
	local textChanged = false
	local dashChanged = false
	local textValue = line.Text and line.Text.GetText and line.Text:GetText() or nil
	if line.Text then textChanged = ApplyQuestTrackerTextStyleFontString(line.Text, "objective", block, line) end
	if line.Dash then dashChanged = ApplyQuestTrackerTextStyleFontString(line.Dash, "objective", block, line) end
	if line.SetHeight and line.Text and line.Text.GetHeight then
		if not (textChanged or dashChanged or line._eqolQuestTrackerTextValue ~= textValue or line._eqolQuestTrackerHeight == nil) then return end
		local height = math.max(1, line.Text:GetHeight() or 1)
		if line._eqolQuestTrackerHeight ~= height then
			line:SetHeight(height)
			line._eqolQuestTrackerHeight = height
		end
		line._eqolQuestTrackerTextValue = textValue
	end
end

local function HandleQuestTrackerTextStyleBlock(block)
	if not block then return end
	if block.HeaderText then
		local headerTextValue = block.HeaderText.GetText and block.HeaderText:GetText() or nil
		local headerChanged = ApplyQuestTrackerTextStyleFontString(block.HeaderText, "title", block)
		if block.HeaderText.SetWordWrap and block.HeaderText._eqolQuestTrackerWordWrap ~= true then
			block.HeaderText:SetWordWrap(true)
			block.HeaderText._eqolQuestTrackerWordWrap = true
			headerChanged = true
		end
		if headerChanged or block.HeaderText._eqolQuestTrackerTextValue ~= headerTextValue or block.HeaderText._eqolQuestTrackerHeight == nil then
			UpdateQuestTrackerFontStringHeight(block.HeaderText, 2)
			block.HeaderText._eqolQuestTrackerTextValue = headerTextValue
		end
	end
	if block.ForEachUsedLine then block:ForEachUsedLine(function(line) HandleQuestTrackerTextStyleLine(block, line) end) end
	if block.AddObjective and not block._eqolQuestTrackerAddObjectiveHooked and hooksecurefunc then
		block._eqolQuestTrackerAddObjectiveHooked = true
		hooksecurefunc(block, "AddObjective", function(hookedBlock)
			HandleQuestTrackerTextStyleLine(hookedBlock, hookedBlock and hookedBlock.lastRegion)
		end)
	end
end

local function IsQuestTrackerTextStyleTracker(tracker)
	for _, name in ipairs(QUEST_TRACKER_TEXT_STYLE_TRACKER_NAMES) do
		if tracker == _G[name] then return true end
	end
	return false
end

local function HandleQuestTrackerTextStyleModule(tracker)
	if not IsQuestTrackerTextStyleTracker(tracker) then return end
	local headerText = tracker and tracker.Header and tracker.Header.Text
	if headerText then
		ApplyQuestTrackerTextStyleFontString(headerText, "moduleHeader", nil)
		UpdateQuestTrackerFontStringHeight(headerText, 2)
	end
end

local function ApplyQuestTrackerQuestCountStyle()
	if not questTrackerQuestCountText then return end
	if IsQuestTrackerTextStyleEnabled() then
		ApplyQuestTrackerTextStyleFontString(questTrackerQuestCountText, "moduleHeader", nil)
		return
	end

	local header = _G.QuestObjectiveTracker and _G.QuestObjectiveTracker.Header
	local referenceFont = header and header.Text and header.Text:GetFontObject()
	if referenceFont then
		questTrackerQuestCountText:SetFontObject(referenceFont)
	else
		questTrackerQuestCountText:SetFont(addon.variables.defaultFont or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
	end
	questTrackerQuestCountText._eqolQuestTrackerFontKey = nil
	questTrackerQuestCountText._eqolQuestTrackerColorKey = nil
	questTrackerQuestCountText:SetTextColor(QUEST_TRACKER_QUEST_COUNT_COLOR.r, QUEST_TRACKER_QUEST_COUNT_COLOR.g, QUEST_TRACKER_QUEST_COUNT_COLOR.b)
end

local function EnsureQuestTrackerTextStyleHooks()
	if not IsQuestTrackerTextStyleEnabled() then return end
	if not hooksecurefunc then return end
	for _, name in ipairs(QUEST_TRACKER_TEXT_STYLE_TRACKER_NAMES) do
		local tracker = _G[name]
		if not questTrackerTextStyleHooked[name] and tracker and type(tracker.Update) == "function" and type(tracker.AddBlock) == "function" then
			questTrackerTextStyleHooked[name] = true
			hooksecurefunc(tracker, "Update", function(hookedTracker) HandleQuestTrackerTextStyleModule(hookedTracker) end)
			hooksecurefunc(tracker, "AddBlock", function(_, block) HandleQuestTrackerTextStyleBlock(block) end)
		end
	end
end

local function RefreshQuestTrackerTextStyle(skipLayoutUpdate)
	if not IsQuestTrackerTextStyleEnabled() then return end
	EnsureQuestTrackerTextStyleHooks()
	for _, name in ipairs(QUEST_TRACKER_TEXT_STYLE_TRACKER_NAMES) do
		local tracker = _G[name]
		if tracker and tracker.EnumerateActiveBlocks then tracker:EnumerateActiveBlocks(function(block) HandleQuestTrackerTextStyleBlock(block) end) end
		HandleQuestTrackerTextStyleModule(tracker)
	end
	ApplyQuestTrackerQuestCountStyle()
	if not skipLayoutUpdate and not questTrackerTextStyleRefreshing and _G.ObjectiveTrackerManager and _G.ObjectiveTrackerManager.UpdateAll then
		questTrackerTextStyleRefreshing = true
		_G.ObjectiveTrackerManager:UpdateAll()
		questTrackerTextStyleRefreshing = nil
	end
end
addon.functions.RefreshQuestTrackerTextStyle = RefreshQuestTrackerTextStyle

local function EnsureQuestTrackerTextStyleWatcher()
	if questTrackerTextStyleWatcher or not IsQuestTrackerTextStyleEnabled() then return end
	questTrackerTextStyleWatcher = CreateFrame("Frame")
	questTrackerTextStyleWatcher:RegisterEvent("ADDON_LOADED")
	questTrackerTextStyleWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	questTrackerTextStyleWatcher:SetScript("OnEvent", function(_, event, name)
		if not IsQuestTrackerTextStyleEnabled() then return end
		if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
		RunNextFrame(function() RefreshQuestTrackerTextStyle(true) end)
	end)
end

local function ActivateQuestTrackerTextStyle()
	if not IsQuestTrackerTextStyleEnabled() then return end
	EnsureQuestTrackerTextStyleWatcher()
	RefreshQuestTrackerTextStyle()
end

local function MarkQuestTrackerTextStyleReloadRequired()
	addon.variables.requireReload = true
	if addon.functions and addon.functions.checkReloadFrame then addon.functions.checkReloadFrame() end
end

local function IsQuestTrackerMainHeaderHidden()
	return addon and addon.db and addon.db.questTrackerHideMainHeader == true
end

local function ApplyQuestTrackerMainHeaderHidden()
	if not IsQuestTrackerMainHeaderHidden() then return end
	local header = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header
	if not header then return end
	if header.Background and header.Background.Hide then header.Background:Hide() end
	if header.Text and header.Text.Hide then header.Text:Hide() end
end

local function EnsureQuestTrackerMainHeaderHiddenHooks()
	if questTrackerMainHeaderHiddenHooked or not IsQuestTrackerMainHeaderHidden() or not hooksecurefunc then return end
	local header = _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.Header
	if not header then return end
	questTrackerMainHeaderHiddenHooked = true
	if header.Background and header.Background.Show then hooksecurefunc(header.Background, "Show", ApplyQuestTrackerMainHeaderHidden) end
	if header.Text and header.Text.Show then hooksecurefunc(header.Text, "Show", ApplyQuestTrackerMainHeaderHidden) end
end

local function EnsureQuestTrackerMainHeaderHiddenWatcher()
	if questTrackerMainHeaderHiddenWatcher or not IsQuestTrackerMainHeaderHidden() then return end
	questTrackerMainHeaderHiddenWatcher = CreateFrame("Frame")
	questTrackerMainHeaderHiddenWatcher:RegisterEvent("ADDON_LOADED")
	questTrackerMainHeaderHiddenWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	questTrackerMainHeaderHiddenWatcher:SetScript("OnEvent", function(_, event, name)
		if not IsQuestTrackerMainHeaderHidden() then return end
		if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
		RunNextFrame(function()
			EnsureQuestTrackerMainHeaderHiddenHooks()
			ApplyQuestTrackerMainHeaderHidden()
		end)
	end)
end

local function ActivateQuestTrackerMainHeaderHidden()
	if not IsQuestTrackerMainHeaderHidden() then return end
	EnsureQuestTrackerMainHeaderHiddenWatcher()
	EnsureQuestTrackerMainHeaderHiddenHooks()
	ApplyQuestTrackerMainHeaderHidden()
end

local function GetQuestTrackerQuestCountText()
	if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return "" end
	local numEntries = C_QuestLog.GetNumQuestLogEntries()
	local visibleQuests = 0
	if numEntries and numEntries > 0 then
		for i = 1, numEntries do
			local info = C_QuestLog.GetInfo(i)
			if info and not info.isHidden and info.questID and info.questID > 0 then visibleQuests = visibleQuests + 1 end
		end
	end
	local maxQuests = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()
	if not maxQuests or maxQuests <= 0 then
		if visibleQuests <= 0 then return "" end
		return tostring(visibleQuests)
	end
	return string.format("%d/%d", visibleQuests, maxQuests)
end

local function PositionQuestTrackerQuestCount()
	if not questTrackerQuestCountFrame or not addon or not addon.db then return end
	local header = _G.QuestObjectiveTracker and _G.QuestObjectiveTracker.Header
	if not header then return end
	questTrackerQuestCountFrame:ClearAllPoints()
	local x = addon.db.questTrackerQuestCountOffsetX or 0
	local y = addon.db.questTrackerQuestCountOffsetY or 0
	questTrackerQuestCountFrame:SetPoint("CENTER", header, "CENTER", x, y)
end

local function EnsureQuestTrackerQuestCountFrame()
	local header = _G.QuestObjectiveTracker and _G.QuestObjectiveTracker.Header
	if not header then return nil end
	if not questTrackerQuestCountFrame then
		questTrackerQuestCountFrame = CreateFrame("Frame", nil, header)
		questTrackerQuestCountFrame:SetSize(1, 1)
	end
	questTrackerQuestCountFrame:SetParent(header)
	if not questTrackerQuestCountText then
		questTrackerQuestCountText = questTrackerQuestCountFrame:CreateFontString(nil, "OVERLAY")
		questTrackerQuestCountText:SetPoint("TOPLEFT")
		questTrackerQuestCountText:SetJustifyH("LEFT")
		questTrackerQuestCountText:SetJustifyV("TOP")
	end
	ApplyQuestTrackerQuestCountStyle()
	return questTrackerQuestCountFrame
end

local function UpdateQuestTrackerQuestCountPosition()
	if not addon or not addon.db then return end
	if not questTrackerQuestCountFrame or not questTrackerQuestCountFrame:IsShown() then
		if addon.db.questTrackerShowQuestCount then addon.functions.UpdateQuestTrackerQuestCount() end
		return
	end
	PositionQuestTrackerQuestCount()
end
addon.functions.UpdateQuestTrackerQuestCountPosition = UpdateQuestTrackerQuestCountPosition

local function UpdateQuestTrackerQuestCount()
	if not addon or not addon.db or not addon.db.questTrackerShowQuestCount then
		if questTrackerQuestCountFrame then questTrackerQuestCountFrame:Hide() end
		return
	end
	local header = _G.QuestObjectiveTracker and _G.QuestObjectiveTracker.Header
	if not header then
		if questTrackerQuestCountFrame then questTrackerQuestCountFrame:Hide() end
		return
	end
	local container = EnsureQuestTrackerQuestCountFrame()
	if not container or not questTrackerQuestCountText then return end
	PositionQuestTrackerQuestCount()
	local textValue = GetQuestTrackerQuestCountText()
	if textValue == "" then
		questTrackerQuestCountFrame:Hide()
		return
	end
	questTrackerQuestCountText:SetText(textValue)
	questTrackerQuestCountFrame:SetSize(math.max(1, questTrackerQuestCountText:GetStringWidth()), math.max(1, questTrackerQuestCountText:GetStringHeight()))
	questTrackerQuestCountFrame:Show()
	questTrackerQuestCountText:Show()
end
addon.functions.UpdateQuestTrackerQuestCount = UpdateQuestTrackerQuestCount

local function EnsureQuestTrackerQuestCountWatcher()
	if questTrackerQuestCountWatcher then return end
	questTrackerQuestCountWatcher = CreateFrame("Frame")
	local events = { "PLAYER_ENTERING_WORLD", "QUEST_ACCEPTED", "QUEST_REMOVED" }
	for _, evt in ipairs(events) do
		questTrackerQuestCountWatcher:RegisterEvent(evt)
	end
	questTrackerQuestCountWatcher:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			C_Timer.After(0.5, UpdateQuestTrackerQuestCount)
		else
			UpdateQuestTrackerQuestCount()
		end
	end)
end

local function ApplyObjectiveTrackerMinimizeStyle()
	if not addon or not addon.db then return end
	local tracker = _G.ObjectiveTrackerFrame
	local header = tracker and tracker.Header
	if not header then return end
	local bg = header.Background
	local text = header.Text
	local minimizeButton = header.MinimizeButton
	if bg and bg._eqolAlpha == nil and bg.GetAlpha then bg._eqolAlpha = bg:GetAlpha() end
	if text and text._eqolAlpha == nil and text.GetAlpha then text._eqolAlpha = text:GetAlpha() end
	local collapsed = tracker.IsCollapsed and tracker:IsCollapsed()
	local hideHeader = addon.db.questTrackerMinimizeButtonOnly == true and collapsed
	if bg and bg.SetAlpha then bg:SetAlpha(hideHeader and 0 or (bg._eqolAlpha or 1)) end
	if text and text.SetAlpha then text:SetAlpha(hideHeader and 0 or (text._eqolAlpha or 1)) end

	if minimizeButton and minimizeButton.GetPoint then
		if not minimizeButton._eqolDefaultPoint then
			local point = { minimizeButton:GetPoint() }
			if point[1] then minimizeButton._eqolDefaultPoint = point end
		end
		if hideHeader then
			local anchorKey = addon.db.questTrackerMinimizeButtonAnchor or "TOPRIGHT"
			local anchor = OBJECTIVE_TRACKER_MINIMIZE_ANCHORS[anchorKey] or OBJECTIVE_TRACKER_MINIMIZE_ANCHORS.TOPRIGHT
			if anchor then
				minimizeButton:ClearAllPoints()
				minimizeButton:SetPoint(anchor.point, tracker, anchor.point, anchor.x, anchor.y)
				minimizeButton._eqolAnchorApplied = true
			end
		elseif minimizeButton._eqolAnchorApplied and minimizeButton._eqolDefaultPoint then
			local point = minimizeButton._eqolDefaultPoint
			minimizeButton:ClearAllPoints()
			minimizeButton:SetPoint(point[1], point[2], point[3], point[4], point[5])
			minimizeButton._eqolAnchorApplied = nil
		end
	end
end
addon.functions.UpdateObjectiveTrackerMinimizeStyle = ApplyObjectiveTrackerMinimizeStyle

local function ApplyQuestTrackerCollapsedState()
	if not addon or not addon.db or not addon.db.questTrackerRememberState then return end
	local tracker = _G.ObjectiveTrackerFrame
	if not tracker or not tracker.IsCollapsed or not tracker.SetCollapsed then return end
	local saved = addon.db.questTrackerCollapsed
	if saved == nil then
		addon.db.questTrackerCollapsed = tracker:IsCollapsed() and true or false
		return
	end
	if tracker:IsCollapsed() ~= saved then tracker:SetCollapsed(saved) end
end

local function CaptureQuestTrackerCollapsedState()
	if not addon or not addon.db or not addon.db.questTrackerRememberState then return end
	local tracker = _G.ObjectiveTrackerFrame
	if not tracker or not tracker.IsCollapsed then return end
	addon.db.questTrackerCollapsed = tracker:IsCollapsed() and true or false
end

local function EnsureObjectiveTrackerCollapseHook()
	if objectiveTrackerCollapseHooked then return end
	local tracker = _G.ObjectiveTrackerFrame
	if not tracker or not hooksecurefunc then return end
	objectiveTrackerCollapseHooked = true
	hooksecurefunc(tracker, "SetCollapsed", function(_, collapsed)
		if addon and addon.db and addon.db.questTrackerRememberState then addon.db.questTrackerCollapsed = collapsed and true or false end
	end)
end

local function EnsureObjectiveTrackerMinimizeHook()
	local tracker = _G.ObjectiveTrackerFrame
	if not tracker then return end
	EnsureObjectiveTrackerCollapseHook()
	local header = tracker.Header
	if not header then return end
	if not objectiveTrackerMinimizeHooked then
		objectiveTrackerMinimizeHooked = true
		if hooksecurefunc then hooksecurefunc(header, "SetCollapsed", function() ApplyObjectiveTrackerMinimizeStyle() end) end
	end
	ApplyQuestTrackerCollapsedState()
	ApplyObjectiveTrackerMinimizeStyle()
end

local function EnsureObjectiveTrackerMinimizeWatcher()
	if objectiveTrackerMinimizeWatcher then return end
	objectiveTrackerMinimizeWatcher = CreateFrame("Frame")
	objectiveTrackerMinimizeWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	objectiveTrackerMinimizeWatcher:RegisterEvent("ADDON_LOADED")
	objectiveTrackerMinimizeWatcher:SetScript("OnEvent", function(_, event, name)
		if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
		RunNextFrame(EnsureObjectiveTrackerMinimizeHook)
	end)
end

local function ShowRemoveIgnoredQuestNPCDialog(selectionKey)
	if not selectionKey or selectionKey == "" then return end
	if not addon.db or not addon.db["ignoredQuestNPC"] then return end

	local npcID = tonumber(selectionKey) or selectionKey
	local npcName = addon.db["ignoredQuestNPC"][npcID]
	if not npcName then
		local asString = tostring(selectionKey)
		if addon.db["ignoredQuestNPC"][asString] then
			npcID = asString
			npcName = addon.db["ignoredQuestNPC"][asString]
		end
	end
	if not npcName then return end

	StaticPopupDialogs[REMOVE_IGNORED_QUEST_NPC_DIALOG] = StaticPopupDialogs[REMOVE_IGNORED_QUEST_NPC_DIALOG]
		or {
			text = L["ignoredQuestNPCRemoveConfirm"],
			button1 = ACCEPT,
			button2 = CANCEL,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}

	StaticPopupDialogs[REMOVE_IGNORED_QUEST_NPC_DIALOG].OnAccept = function(_, data)
		if not data or data == "" or not addon.db or not addon.db["ignoredQuestNPC"] then return end
		if addon.db["ignoredQuestNPC"][data] then addon.db["ignoredQuestNPC"][data] = nil end
		local numericID = tonumber(data)
		if numericID and addon.db["ignoredQuestNPC"][numericID] then addon.db["ignoredQuestNPC"][numericID] = nil end
		local stringKey = tostring(data)
		if addon.db["ignoredQuestNPC"][stringKey] then addon.db["ignoredQuestNPC"][stringKey] = nil end
	end

	StaticPopup_Show(REMOVE_IGNORED_QUEST_NPC_DIALOG, npcName or tostring(npcID), nil, npcID)
end

local questingData = {
	{
		var = "autoChooseQuest",
		text = L["autoChooseQuest"],
		desc = L["autoChooseQuestDesc"],
		richNote = {
			blocks = {
				{ text = "|cff99e599" .. L["ignoreNPCTipp"] .. "|r" },
			},
		},
		func = function(key) addon.db["autoChooseQuest"] = key end,
		default = false,
		children = {
			{
				var = "autoChooseQuestModifier",
				text = L["questAutomationModifier"] or "Quest automation modifier",
				desc = L["questAutomationModifierDesc"],
				listFunc = function()
					return {
						NONE = NONE,
						SHIFT = SHIFT_KEY_TEXT,
						CTRL = CTRL_KEY_TEXT,
						ALT = ALT_KEY_TEXT,
					}
				end,
				get = function() return addon.db and addon.db.autoChooseQuestModifier or "NONE" end,
				set = function(key)
					if not key or key == "" then key = "NONE" end
					addon.db["autoChooseQuestModifier"] = key
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["autoChooseQuest"]
						and addon.SettingsLayout.elements["autoChooseQuest"].setting
						and addon.SettingsLayout.elements["autoChooseQuest"].setting:GetValue() == true
				end,
				parent = true,
				sType = "dropdown",
			},
			{
				var = "ignoreDailyQuests",
				text = L["ignoreDailyQuests"]:format(QUESTS_LABEL),
				desc = L["ignoreDailyQuestsDesc"],
				func = function(key) addon.db["ignoreDailyQuests"] = key end,
				default = false,
				sType = "checkbox",
				parentCheck = function()
					return addon.SettingsLayout.elements["autoChooseQuest"]
						and addon.SettingsLayout.elements["autoChooseQuest"].setting
						and addon.SettingsLayout.elements["autoChooseQuest"].setting:GetValue() == true
				end,
				parent = true,
			},
			{
				var = "ignoreWarbandCompleted",
				text = L["ignoreWarbandCompleted"]:format(ACCOUNT_COMPLETED_QUEST_LABEL, QUESTS_LABEL),
				desc = L["ignoreWarbandCompletedDesc"],
				func = function(key) addon.db["ignoreWarbandCompleted"] = key end,
				default = false,
				sType = "checkbox",
				parentCheck = function()
					return addon.SettingsLayout.elements["autoChooseQuest"]
						and addon.SettingsLayout.elements["autoChooseQuest"].setting
						and addon.SettingsLayout.elements["autoChooseQuest"].setting:GetValue() == true
				end,
				parent = true,
			},
			{
				var = "ignoreTrivialQuests",
				text = L["ignoreTrivialQuests"]:format(QUESTS_LABEL),
				desc = L["ignoreTrivialQuestsDesc"],
				func = function(key) addon.db["ignoreTrivialQuests"] = key end,
				default = false,
				sType = "checkbox",
				parentCheck = function()
					return addon.SettingsLayout.elements["autoChooseQuest"]
						and addon.SettingsLayout.elements["autoChooseQuest"].setting
						and addon.SettingsLayout.elements["autoChooseQuest"].setting:GetValue() == true
				end,
				parent = true,
			},
			{
				listFunc = function()
					local tList = { [""] = "" }
					for id, name in pairs(addon.db["ignoredQuestNPC"] or {}) do
						tList[id] = name
					end
					return tList
				end,
				text = REMOVE,
				get = function() return "" end,
				set = function(key)
					if not key or key == "" then return end
					ShowRemoveIgnoredQuestNPCDialog(key)
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["autoChooseQuest"]
						and addon.SettingsLayout.elements["autoChooseQuest"].setting
						and addon.SettingsLayout.elements["autoChooseQuest"].setting:GetValue() == true
				end,
				parent = true,
				var = "ignoredQuestNPC",
				type = Settings.VarType.Number,
				sType = "dropdown",
			},
		},
	},
	{
		var = "questWowheadLink",
		text = L["questWowheadLink"],
		desc = L["questWowheadLinkDesc"],
		func = function(key) addon.db["questWowheadLink"] = key end,
		default = false,
	},
}

local cinematicData = {
	{
		var = "autoCancelCinematic",
		text = L["autoCancelCinematic"],
		desc = L["autoCancelCinematicDesc"],
		func = function(value)
			addon.db["autoCancelCinematic"] = value and true or false
			if value then
				addon.db["quickSkipCinematic"] = false
				local quickSetting = addon.SettingsLayout.elements and addon.SettingsLayout.elements["quickSkipCinematic"]
				if quickSetting and quickSetting.setting then quickSetting.setting:SetValue(false) end
			end
		end,
		default = false,
	},
	{
		var = "quickSkipCinematic",
		text = L["quickSkipCinematic"],
		desc = L["quickSkipCinematicDesc"],
		func = function(value)
			addon.db["quickSkipCinematic"] = value and true or false
			if value then
				addon.db["autoCancelCinematic"] = false
				local autoSetting = addon.SettingsLayout.elements and addon.SettingsLayout.elements["autoCancelCinematic"]
				if autoSetting and autoSetting.setting then autoSetting.setting:SetValue(false) end
			end
		end,
		default = false,
	},
}

local function IsQuestTrackerTextStyleSettingEnabled()
	local element = addon.SettingsLayout.elements and addon.SettingsLayout.elements["questTrackerTextStyleEnabled"]
	return element and element.setting and element.setting:GetValue() == true
end

local function SetQuestTrackerTextStyleDBValue(key, value)
	if not addon.db then return end
	local fallback = QUEST_TRACKER_TEXT_STYLE_SIZE_DEFAULTS[key]
	if fallback == nil then
		if key == "questTrackerTextStyleFontFace" then
			fallback = GetQuestTrackerDefaultFontFace()
		elseif key == "questTrackerTextStyleFontOutline" then
			fallback = GetQuestTrackerDefaultFontOutline()
		end
	end
	if value == fallback then
		addon.db[key] = nil
	else
		addon.db[key] = value
	end
	InvalidateQuestTrackerTextStyleCache()
	RefreshQuestTrackerTextStyle()
end

local function GetQuestTrackerTextStyleDBValue(key, fallback)
	if not addon.db then return fallback end
	local value = addon.db[key]
	if value == nil then return fallback end
	return value
end

local function ColorsMatch(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	return (a.r or 0) == (b.r or 0) and (a.g or 0) == (b.g or 0) and (a.b or 0) == (b.b or 0) and (a.a or 1) == (b.a or 1)
end

local function BuildQuestTrackerTextColorPicker(key, label)
	return {
		var = key,
		text = label,
		entries = { { key = key, label = label } },
		getColor = function()
			local color = GetQuestTrackerTextStyleColor(key)
			return color.r, color.g, color.b, color.a or 1
		end,
		setColor = function(_, r, g, b, a)
			if not addon.db then return end
			local value = { r = r, g = g, b = b, a = a }
			local fallback = QUEST_TRACKER_TEXT_STYLE_COLOR_DEFAULTS[key]
			if ColorsMatch(value, fallback) then
				addon.db[key] = nil
			else
				addon.db[key] = value
			end
			InvalidateQuestTrackerTextStyleCache()
			RefreshQuestTrackerTextStyle()
		end,
		getDefaultColor = function()
			local color = QUEST_TRACKER_TEXT_STYLE_COLOR_DEFAULTS[key]
			return color.r, color.g, color.b, color.a or 1
		end,
		parentCheck = IsQuestTrackerTextStyleSettingEnabled,
		parent = true,
		sType = "colorpicker",
	}
end

local trackerData = {
	{
		var = "questTrackerShowQuestCount",
		text = L["questTrackerShowQuestCount"],
		desc = L["questTrackerShowQuestCount_desc"],
		func = function(key)
			addon.db["questTrackerShowQuestCount"] = key
			addon.functions.UpdateQuestTrackerQuestCount()
		end,
		default = false,
		children = {
			{
				var = "questTrackerQuestCountOffsetX",
				text = L["Horizontal offset"],
				desc = L["questTrackerQuestCountOffsetXDesc"],
				parentCheck = function()
					return addon.SettingsLayout.elements["questTrackerShowQuestCount"]
						and addon.SettingsLayout.elements["questTrackerShowQuestCount"].setting
						and addon.SettingsLayout.elements["questTrackerShowQuestCount"].setting:GetValue() == true
				end,
				get = function() return addon.db and addon.db.questTrackerQuestCountOffsetX or 0 end,
				set = function(value)
					addon.db["questTrackerQuestCountOffsetX"] = value
					addon.functions.UpdateQuestTrackerQuestCountPosition()
				end,
				min = -200,
				max = 200,
				step = 1,
				parent = true,
				default = 0,
				sType = "slider",
			},
			{
				var = "questTrackerQuestCountOffsetY",
				text = L["Vertical offset"],
				desc = L["questTrackerQuestCountOffsetYDesc"],
				parentCheck = function()
					return addon.SettingsLayout.elements["questTrackerShowQuestCount"]
						and addon.SettingsLayout.elements["questTrackerShowQuestCount"].setting
						and addon.SettingsLayout.elements["questTrackerShowQuestCount"].setting:GetValue() == true
				end,
				get = function() return addon.db and addon.db.questTrackerQuestCountOffsetY or 0 end,
				set = function(value)
					addon.db["questTrackerQuestCountOffsetY"] = value
					addon.functions.UpdateQuestTrackerQuestCountPosition()
				end,
				min = -200,
				max = 200,
				step = 1,
				parent = true,
				default = 0,
				sType = "slider",
			},
		},
	},
	{
		var = "questTrackerHideMainHeader",
		text = L["questTrackerHideMainHeader"],
		desc = L["questTrackerHideMainHeader_desc"],
		storage = false,
		func = function(value)
			local enabled = value and true or false
			local wasEnabled = addon.db and addon.db.questTrackerHideMainHeader == true
			addon.db["questTrackerHideMainHeader"] = enabled and true or nil
			if enabled then
				ActivateQuestTrackerMainHeaderHidden()
			elseif wasEnabled then
				MarkQuestTrackerTextStyleReloadRequired()
			end
		end,
		default = false,
	},
	{
		var = "questTrackerTextStyleEnabled",
		text = L["questTrackerTextStyleEnabled"],
		desc = L["questTrackerTextStyleEnabled_desc"],
		storage = false,
		func = function(value)
			local enabled = value and true or false
			local wasEnabled = addon.db and addon.db.questTrackerTextStyleEnabled == true
			addon.db["questTrackerTextStyleEnabled"] = enabled and true or nil
			if enabled then
				InvalidateQuestTrackerTextStyleCache()
				ActivateQuestTrackerTextStyle()
			elseif wasEnabled then
				MarkQuestTrackerTextStyleReloadRequired()
			end
		end,
		default = false,
		children = {
			{
				var = "questTrackerTextStyleFontFace",
				text = L["questTrackerTextStyleFontFace"],
				listFunc = BuildQuestTrackerFontDropdown,
				order = questTrackerTextStyleFontOrder,
				get = function() return GetQuestTrackerTextStyleDBValue("questTrackerTextStyleFontFace", GetQuestTrackerDefaultFontFace()) end,
				set = function(key)
					if not key or key == "" then return end
					SetQuestTrackerTextStyleDBValue("questTrackerTextStyleFontFace", key)
				end,
				parentCheck = IsQuestTrackerTextStyleSettingEnabled,
				parent = true,
				sType = "dropdown",
			},
			{
				var = "questTrackerTextStyleFontOutline",
				text = L["questTrackerTextStyleFontOutline"],
				listFunc = function()
					if addon.functions.GetFontStyleOptions then return addon.functions.GetFontStyleOptions(true) end
					return {
						NONE = _G.NONE or "None",
						OUTLINE = "Outline",
						THICKOUTLINE = "Thick Outline",
					}, { "NONE", "OUTLINE", "THICKOUTLINE" }
				end,
				get = function() return GetQuestTrackerTextStyleDBValue("questTrackerTextStyleFontOutline", GetQuestTrackerDefaultFontOutline()) end,
				set = function(key)
					if not key or key == "" then return end
					SetQuestTrackerTextStyleDBValue("questTrackerTextStyleFontOutline", key)
				end,
				parentCheck = IsQuestTrackerTextStyleSettingEnabled,
				parent = true,
				sType = "dropdown",
			},
			{
				var = "questTrackerTextStyleModuleHeaderFontSize",
				text = L["questTrackerTextStyleModuleHeaderFontSize"],
				get = function() return GetQuestTrackerTextStyleSize("questTrackerTextStyleModuleHeaderFontSize") end,
				set = function(value) SetQuestTrackerTextStyleDBValue("questTrackerTextStyleModuleHeaderFontSize", value) end,
				min = 8,
				max = 32,
				step = 1,
				parentCheck = IsQuestTrackerTextStyleSettingEnabled,
				parent = true,
				default = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.moduleHeaderFontSize,
				sType = "slider",
			},
			BuildQuestTrackerTextColorPicker("questTrackerTextStyleModuleHeaderColor", L["questTrackerTextStyleModuleHeaderColor"]),
			{
				var = "questTrackerTextStyleQuestTitleFontSize",
				text = L["questTrackerTextStyleQuestTitleFontSize"],
				get = function() return GetQuestTrackerTextStyleSize("questTrackerTextStyleQuestTitleFontSize") end,
				set = function(value) SetQuestTrackerTextStyleDBValue("questTrackerTextStyleQuestTitleFontSize", value) end,
				min = 8,
				max = 32,
				step = 1,
				parentCheck = IsQuestTrackerTextStyleSettingEnabled,
				parent = true,
				default = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.questTitleFontSize,
				sType = "slider",
			},
			BuildQuestTrackerTextColorPicker("questTrackerTextStyleQuestTitleColor", L["questTrackerTextStyleQuestTitleColor"]),
			BuildQuestTrackerTextColorPicker("questTrackerTextStyleQuestTitleHoverColor", L["questTrackerTextStyleQuestTitleHoverColor"]),
			{
				var = "questTrackerTextStyleObjectiveFontSize",
				text = L["questTrackerTextStyleObjectiveFontSize"],
				get = function() return GetQuestTrackerTextStyleSize("questTrackerTextStyleObjectiveFontSize") end,
				set = function(value) SetQuestTrackerTextStyleDBValue("questTrackerTextStyleObjectiveFontSize", value) end,
				min = 8,
				max = 32,
				step = 1,
				parentCheck = IsQuestTrackerTextStyleSettingEnabled,
				parent = true,
				default = QUEST_TRACKER_TEXT_STYLE_DEFAULTS.objectiveFontSize,
				sType = "slider",
			},
			BuildQuestTrackerTextColorPicker("questTrackerTextStyleObjectiveColor", L["questTrackerTextStyleObjectiveColor"]),
			BuildQuestTrackerTextColorPicker("questTrackerTextStyleObjectiveHoverColor", L["questTrackerTextStyleObjectiveHoverColor"]),
		},
	},
	{
		var = "questTrackerMinimizeButtonOnly",
		text = L["questTrackerMinimizeButtonOnly"],
		desc = L["questTrackerMinimizeButtonOnly_desc"],
		func = function(value)
			addon.db["questTrackerMinimizeButtonOnly"] = value and true or false
			ApplyObjectiveTrackerMinimizeStyle()
		end,
		default = false,
		children = {
			{
				var = "questTrackerMinimizeButtonAnchor",
				text = L["questTrackerMinimizeButtonAnchor"] or "Minimized '+' anchor",
				desc = L["questTrackerMinimizeButtonAnchor_desc"],
				listFunc = function()
					return {
						TOPLEFT = L["Top Left"] or "Top Left",
						TOPRIGHT = L["Top Right"] or "Top Right",
						BOTTOMLEFT = L["Bottom Left"] or "Bottom Left",
						BOTTOMRIGHT = L["Bottom Right"] or "Bottom Right",
					}
				end,
				get = function() return addon.db and addon.db.questTrackerMinimizeButtonAnchor or "TOPRIGHT" end,
				set = function(key)
					if not key or key == "" then return end
					addon.db["questTrackerMinimizeButtonAnchor"] = key
					ApplyObjectiveTrackerMinimizeStyle()
				end,
				parentCheck = function()
					return addon.SettingsLayout.elements["questTrackerMinimizeButtonOnly"]
						and addon.SettingsLayout.elements["questTrackerMinimizeButtonOnly"].setting
						and addon.SettingsLayout.elements["questTrackerMinimizeButtonOnly"].setting:GetValue() == true
				end,
				parent = true,
				sType = "dropdown",
			},
		},
	},
	{
		var = "questTrackerRememberState",
		text = L["questTrackerRememberState"],
		desc = L["questTrackerRememberState_desc"],
		func = function(value)
			addon.db["questTrackerRememberState"] = value and true or false
			if value then
				CaptureQuestTrackerCollapsedState()
				EnsureObjectiveTrackerCollapseHook()
			end
		end,
		default = false,
	},
}

addon.functions.SettingsCreateHeadline(cQuest, L["Questing"], { parentSection = questingExpandable })
applyParentSection(questingData, questingExpandable)
addon.functions.SettingsCreateCheckboxes(cQuest, questingData)

addon.functions.SettingsCreateHeadline(cQuest, L["Cinematics"], { parentSection = questingExpandable })
applyParentSection(cinematicData, questingExpandable)
addon.functions.SettingsCreateCheckboxes(cQuest, cinematicData)

addon.functions.SettingsCreateHeadline(cQuest, L["questTrackerOptions"], { parentSection = questingExpandable })
applyParentSection(trackerData, questingExpandable)
addon.functions.SettingsCreateCheckboxes(cQuest, trackerData)

----- REGION END

function addon.functions.initQuest()
	if addon.db then
		if addon.db.autoChooseQuest == nil then
			if addon.db.autoAcceptQuest == true or addon.db.autoTurnInQuest == true or addon.db.autoGossip == true then addon.db.autoChooseQuest = true end
		end
		if addon.db.autoChooseQuestModifier == nil then
			local modifiers = {}
			if addon.db.autoAcceptQuest == true then table.insert(modifiers, NormalizeQuestAutomationModifier(addon.db.autoAcceptQuestModifier) or "NONE") end
			if addon.db.autoTurnInQuest == true then table.insert(modifiers, NormalizeQuestAutomationModifier(addon.db.autoTurnInQuestModifier) or "NONE") end
			if addon.db.autoGossip == true then table.insert(modifiers, NormalizeQuestAutomationModifier(addon.db.autoGossipModifier) or "NONE") end
			if #modifiers == 0 then
				local fallbackModifiers = {
					NormalizeQuestAutomationModifier(addon.db.autoAcceptQuestModifier),
					NormalizeQuestAutomationModifier(addon.db.autoTurnInQuestModifier),
					NormalizeQuestAutomationModifier(addon.db.autoGossipModifier),
				}
				for _, modifier in ipairs(fallbackModifiers) do
					if modifier then
						addon.db.autoChooseQuestModifier = modifier
						break
					end
				end
			end
			if addon.db.autoChooseQuestModifier == nil then
				local selectedModifier = "NONE"
				for _, modifier in ipairs(modifiers) do
					if modifier ~= "NONE" then
						if selectedModifier == "NONE" or selectedModifier == modifier then
							selectedModifier = modifier
						else
							selectedModifier = "SHIFT"
							break
						end
					end
				end
				addon.db.autoChooseQuestModifier = selectedModifier
			end
		end
		if addon.db.ignoreDailyQuests == nil then
			addon.db.ignoreDailyQuests = (type(addon.db.questAutomationFiltersAccept) == "table" and addon.db.questAutomationFiltersAccept.daily == true)
				or (type(addon.db.questAutomationFiltersTurnIn) == "table" and addon.db.questAutomationFiltersTurnIn.daily == true)
				or false
		end
		if addon.db.ignoreTrivialQuests == nil then
			addon.db.ignoreTrivialQuests = (type(addon.db.questAutomationFiltersAccept) == "table" and addon.db.questAutomationFiltersAccept.trivial == true)
				or (type(addon.db.questAutomationFiltersTurnIn) == "table" and addon.db.questAutomationFiltersTurnIn.trivial == true)
				or false
		end
		if addon.db.ignoreWarbandCompleted == nil then
			addon.db.ignoreWarbandCompleted = (type(addon.db.questAutomationFiltersAccept) == "table" and addon.db.questAutomationFiltersAccept.warband == true)
				or (type(addon.db.questAutomationFiltersTurnIn) == "table" and addon.db.questAutomationFiltersTurnIn.warband == true)
				or false
		end
	end

	addon.functions.InitDBValue("autoChooseQuest", false)
	addon.functions.InitDBValue("autoChooseQuestModifier", "NONE")
	addon.functions.InitDBValue("ignoreTrivialQuests", false)
	addon.functions.InitDBValue("ignoreDailyQuests", false)
	addon.functions.InitDBValue("ignoreWarbandCompleted", false)
	addon.functions.InitDBValue("questTrackerShowQuestCount", false)
	addon.functions.InitDBValue("questTrackerQuestCountOffsetX", 0)
	addon.functions.InitDBValue("questTrackerQuestCountOffsetY", 0)
	addon.functions.InitDBValue("questTrackerMinimizeButtonOnly", false)
	addon.functions.InitDBValue("questTrackerMinimizeButtonAnchor", "TOPRIGHT")
	addon.functions.InitDBValue("questTrackerRememberState", false)
	addon.functions.InitDBValue("questWowheadLink", false)
	addon.functions.InitDBValue("ignoredQuestNPC", {})
	addon.functions.InitDBValue("autogossipID", {})
	if addon.db then addon.db.testOwner = nil end

	EnsureObjectiveTrackerMinimizeWatcher()
	EnsureObjectiveTrackerMinimizeHook()
	ActivateQuestTrackerMainHeaderHidden()
	ActivateQuestTrackerTextStyle()

	local function EQOL_GetQuestIDFromMenu(owner, ctx)
		if ctx and (ctx.questID or ctx.questId) then return ctx.questID or ctx.questId end

		if owner then
			if owner.questID then return owner.questID end
			if owner.GetQuestID then
				local ok, id = pcall(owner.GetQuestID, owner)
				if ok and id then return id end
			end
			if owner.questLogIndex and C_QuestLog and C_QuestLog.GetInfo then
				local info = C_QuestLog.GetInfo(owner.questLogIndex)
				if info and info.questID then return info.questID end
			end
		end
		return nil
	end

	local function EQOL_ShowCopyURL(url)
		if not StaticPopupDialogs["ENHANCEQOL_COPY_URL"] then
			StaticPopupDialogs["ENHANCEQOL_COPY_URL"] = {
					text = L["copyUrlPopupText"],
				button1 = OKAY,
				hasEditBox = true,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
				OnShow = function(self, data)
					local eb = self.editBox or self.GetEditBox and self:GetEditBox()
					eb:SetAutoFocus(true)
					eb:SetText(data or "")
					eb:HighlightText()
					eb:SetCursorPosition(0)
				end,
				OnAccept = function(self) end,
				EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			}
		end
		StaticPopup_Show("ENHANCEQOL_COPY_URL", nil, nil, url)
	end

	local function EQOL_AddQuestWowheadEntry(owner, root, ctx)
		if not addon.db["questWowheadLink"] then return end
		local qid
		if owner.GetName and owner:GetName() == "ObjectiveTrackerFrame" then
			local mFocus = GetMouseFoci()
			if mFocus and mFocus[1] and mFocus[1].GetParent then
				local pInfo = mFocus[1]:GetParent()
				if pInfo.poiQuestID then
					qid = pInfo.poiQuestID
				else
					return
				end
			end
		else
			qid = EQOL_GetQuestIDFromMenu(owner, ctx)
		end
		if not qid then return end
		root:CreateDivider()
		local btn = root:CreateButton(L["CopyWowheadURL"], function() EQOL_ShowCopyURL(("https://www.wowhead.com/quest=%d"):format(qid)) end)
		btn:AddInitializer(function()
			btn:SetTooltip(function(tt)
				GameTooltip_SetTitle(tt, L["wowhead"])
				GameTooltip_AddNormalLine(tt, ("quest=%d"):format(qid))
			end)
		end)
	end

	-- Register for Blizzard's menu tags (provided by /etrace):
	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", EQOL_AddQuestWowheadEntry)
		Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", EQOL_AddQuestWowheadEntry)
	end

	if Menu and Menu.ModifyMenu then
		local function GetNPCIDFromGUID(guid)
			if type(guid) == "nil" then return end
			if type(guid) ~= "nil" and issecretvalue(guid) then return nil end
			if guid then
				local type, _, _, _, _, npcID = strsplit("-", guid)
				if type == "Creature" or type == "Vehicle" then return tonumber(npcID) end
			end
			return nil
		end

		local function AddIgnoreAutoQuest(owner, root, ctx)
			if not addon.db["autoChooseQuest"] then return end
			if addon.functions.isRestrictedContent() then return end

			if not UnitExists("target") or UnitPlayerControlled("target") then return end
			local guid = UnitGUID("target")
			if issecretvalue(guid) then return end
			local npcID = GetNPCIDFromGUID(guid)
			if not npcID then return end
			if issecretvalue and issecretvalue(npcID) then return end
			local name = UnitName("target")
			if not name or (issecretvalue and issecretvalue(name)) then return end

			root:CreateDivider()
			root:CreateTitle(addonName)
			if addon.db["ignoredQuestNPC"][npcID] then
				root:CreateButton(L["SettingsQuestHeaderIgnoredNPCRemove"], function(id) addon.db["ignoredQuestNPC"][npcID] = nil end, npcID)
			else
				root:CreateButton(L["SettingsQuestHeaderIgnoredNPCAdd"], function(id) addon.db["ignoredQuestNPC"][npcID] = name end, npcID)
			end
		end

		Menu.ModifyMenu("MENU_UNIT_TARGET", AddIgnoreAutoQuest)
	end

	EnsureQuestTrackerQuestCountWatcher()
	UpdateQuestTrackerQuestCount()
end

local eventHandlers = {}

local function registerEvents(frame)
	for event in pairs(eventHandlers) do
		frame:RegisterEvent(event)
	end
end

local function eventHandler(self, event, ...)
	if eventHandlers[event] then eventHandlers[event](...) end
end

local frameLoad = CreateFrame("Frame")

registerEvents(frameLoad)
frameLoad:SetScript("OnEvent", eventHandler)
