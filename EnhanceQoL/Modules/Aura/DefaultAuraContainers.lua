-- luacheck: globals BackdropTemplate CreateFrame UIParent MinimapCluster InCombatLockdown RegisterAttributeDriver GameTooltip C_UnitAuras CooldownFrame_Set GetTime GetInventoryItemTexture GetInventoryItemID GetInventoryItemLink GetInventorySlotInfo GetWeaponEnchantInfo C_Item C_DurationUtil C_Timer
local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.DefaultAuraContainers = addon.DefaultAuraContainers or {}
addon.DefaultAuraContainers.functions = addon.DefaultAuraContainers.functions or {}
addon.DefaultAuraContainers.variables = addon.DefaultAuraContainers.variables or {}
local DAC = addon.DefaultAuraContainers

local L = LibStub("AceLocale-3.0"):GetLocale(parentAddonName)
local issecretvalue = _G.issecretvalue

local DEFAULT_AURA_INITIAL_CONFIG = [[
	local header = self:GetParent()
	self:SetWidth(header:GetAttribute("config-width"))
	self:SetHeight(header:GetAttribute("config-height"))
]]

local function isDefaultAuraIconSkinEnabled()
	return addon.db and (addon.db.skinnerDefaultBuffIconsEnabled == true or addon.db.skinnerDefaultDebuffIconsEnabled == true)
end

local DEFAULT_AURA_DB_PREFIX = "skinnerDefaultAura"
local DEFAULT_DEBUFF_AURA_DB_PREFIX = "skinnerDefaultDebuffAura"

local function normalizeDefaultAuraKind(kind)
	return kind == "debuff" and "debuff" or "buff"
end

local function getDefaultAuraSyncEnabled()
	return not addon.db or addon.db.skinnerDefaultAuraSyncBuffDebuff ~= false
end

local function getDefaultAuraDBPrefix(kind)
	kind = normalizeDefaultAuraKind(kind)
	if kind == "debuff" and not getDefaultAuraSyncEnabled() then return DEFAULT_DEBUFF_AURA_DB_PREFIX end
	return DEFAULT_AURA_DB_PREFIX
end

local function getDefaultAuraDBValue(kind, suffix)
	if not addon.db then return nil end
	local value = addon.db[getDefaultAuraDBPrefix(kind) .. suffix]
	if value == nil and normalizeDefaultAuraKind(kind) == "debuff" then value = addon.db[DEFAULT_AURA_DB_PREFIX .. suffix] end
	return value
end

local function setDefaultAuraDBValue(kind, suffix, value)
	if not addon.db then return end
	addon.db[getDefaultAuraDBPrefix(kind) .. suffix] = value
end

local DEFAULT_AURA_CONFIG_SUFFIXES = {
	"IconShape",
	"IconSize",
	"IconSpacing",
	"HorizontalSpacing",
	"VerticalSpacing",
	"IconsPerRow",
	"MaxRows",
	"SortMethod",
	"SortDirection",
	"IncludeWeapons",
	"IconZoom",
	"IconDarkMode",
	"IconDarkness",
	"IconDesaturate",
	"CooldownDrawSwipe",
	"BorderTexture",
	"BorderSize",
	"BorderOffset",
	"UseOriginalBorderColor",
	"BorderColor",
	"DurationEnabled",
	"DurationFontFace",
	"DurationFontOutline",
	"DurationFontSize",
	"DurationColor",
	"DurationAnchor",
	"DurationOffset",
	"DurationTextProfile",
	"CountEnabled",
	"CountFontFace",
	"CountFontOutline",
	"CountFontSize",
	"CountColor",
	"CountAnchor",
	"CountOffset",
}

local function copyValue(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for k, v in pairs(value) do copy[k] = copyValue(v) end
	return copy
end

local function copyDefaultAuraConfig(fromKind, toKind)
	if not addon.db then return end
	fromKind = normalizeDefaultAuraKind(fromKind)
	toKind = normalizeDefaultAuraKind(toKind)
	local targetPrefix = toKind == "debuff" and DEFAULT_DEBUFF_AURA_DB_PREFIX or DEFAULT_AURA_DB_PREFIX
	for _, suffix in ipairs(DEFAULT_AURA_CONFIG_SUFFIXES) do
		addon.db[targetPrefix .. suffix] = copyValue(getDefaultAuraDBValue(fromKind, suffix))
	end
end

local DEFAULT_AURA_BORDER_COLOR = { r = 0, g = 0, b = 0, a = 1 }
local DEFAULT_AURA_DURATION_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }
local DEFAULT_AURA_COUNT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local GLOBAL_FONT_KEY = "__EQOL_GLOBAL_FONT__"
local GLOBAL_STYLE_KEY = "__EQOL_GLOBAL_FONT_STYLE__"
local refreshDefaultAuraIconSkin

local function normalizeDefaultAuraDurationTextProfile(value)
	local durationText = addon.DurationText
	if durationText and durationText.GetProfileKey then return durationText:GetProfileKey(value or "MINIMAL") end
	return type(value) == "string" and value ~= "" and value or "MINIMAL"
end

local function normalizeAuraIconShape(value)
	if addon.IconShape and addon.IconShape.Normalize then return addon.IconShape.Normalize(value, "DEFAULT") end
	value = type(value) == "string" and strupper(value) or "DEFAULT"
	if value == "SQUARE" or value == "ROUND" or value == "HEXAGON" or value == "DIAMOND" then return value end
	if value == "ROUND_STAR" or value == "STAR" then return value end
	return "DEFAULT"
end

local function normalizeAuraIconZoom(value)
	if addon.IconShape and addon.IconShape.NormalizeIconZoom then return addon.IconShape.NormalizeIconZoom(value) end
	value = tonumber(value) or 0
	if value < 0 then value = 0 end
	if value > 35 then value = 35 end
	return math.floor(value + 0.5)
end

local function normalizeAuraIconDarkness(value)
	value = tonumber(value) or 35
	if value < 0 then value = 0 end
	if value > 100 then value = 100 end
	return math.floor(value + 0.5)
end

local function applyDefaultAuraIconDarkMode(button, kind)
	local icon = button and (button.Icon or button.icon)
	if not icon then return end
	if getDefaultAuraDBValue(kind, "IconDarkMode") == true then
		local darkness = normalizeAuraIconDarkness(getDefaultAuraDBValue(kind, "IconDarkness"))
		local value = 1 - (darkness / 100)
		if icon.SetDesaturated then icon:SetDesaturated(getDefaultAuraDBValue(kind, "IconDesaturate") == true) end
		if icon.SetVertexColor then icon:SetVertexColor(value, value, value, 1) end
	else
		if icon.SetDesaturated then icon:SetDesaturated(false) end
		if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
	end
end

local function normalizeAuraBorder(value, shape)
	if addon.IconShape and addon.IconShape.NormalizeBorder then
		return addon.IconShape.NormalizeBorder(value, addon.IconShape.BORDER and addon.IconShape.BORDER.NONE or "NONE", shape, {
			allowNone = true,
			emptyValue = addon.IconShape.BORDER and addon.IconShape.BORDER.NONE or "NONE",
		})
	end
	return value == "NONE" and "NONE" or "NONE"
end

local function getDefaultAuraBorderColor(kind)
	local col = getDefaultAuraDBValue(kind, "BorderColor")
	if type(col) ~= "table" then col = DEFAULT_AURA_BORDER_COLOR end
	return {
		col.r or DEFAULT_AURA_BORDER_COLOR.r,
		col.g or DEFAULT_AURA_BORDER_COLOR.g,
		col.b or DEFAULT_AURA_BORDER_COLOR.b,
		col.a ~= nil and col.a or DEFAULT_AURA_BORDER_COLOR.a,
	}
end

local function getDefaultAuraUseOriginalBorderColor(kind)
	return getDefaultAuraDBValue(kind, "UseOriginalBorderColor") == true
end

local function getDefaultAuraOriginalBorderColor(button)
	local border = button and (button.Border or button.border)
	if border and border.GetVertexColor then
		local r, g, b, a = border:GetVertexColor()
		if r and g and b then return { r, g, b, a ~= nil and a or 1 } end
	end
	return nil
end

local function resolveDefaultAuraBorderColor(button, kind)
	if getDefaultAuraUseOriginalBorderColor(kind) then
		return getDefaultAuraOriginalBorderColor(button) or getDefaultAuraBorderColor()
	end
	return getDefaultAuraBorderColor(kind)
end

local function normalizeAuraTextColor(value, fallback)
	fallback = fallback or DEFAULT_AURA_DURATION_COLOR
	if type(value) ~= "table" then value = fallback end
	return {
		r = tonumber(value.r or value[1]) or fallback.r or 1,
		g = tonumber(value.g or value[2]) or fallback.g or 1,
		b = tonumber(value.b or value[3]) or fallback.b or 1,
		a = value.a ~= nil and value.a or value[4] or fallback.a or 1,
	}
end

local function getGlobalFontKey()
	return addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or GLOBAL_FONT_KEY
end

local function getGlobalFontLabel()
	return addon.functions and addon.functions.GetGlobalFontConfigLabel and addon.functions.GetGlobalFontConfigLabel() or (L["useGlobalFontConfig"] or "Use global font config")
end

local function getGlobalStyleKey()
	return addon.functions and addon.functions.GetGlobalFontStyleConfigKey and addon.functions.GetGlobalFontStyleConfigKey() or GLOBAL_STYLE_KEY
end

local function getGlobalStyleLabel()
	return addon.functions and addon.functions.GetGlobalFontStyleConfigLabel and addon.functions.GetGlobalFontStyleConfigLabel() or (L["useGlobalFontStyleConfig"] or "Use global font styling")
end

local function normalizeAuraFontKey(value)
	if type(value) == "string" and value ~= "" then return value end
	return getGlobalFontKey()
end

local function normalizeAuraFontStyle(value)
	if addon.functions and addon.functions.NormalizeFontStyleChoice then return addon.functions.NormalizeFontStyleChoice(value, getGlobalStyleKey(), true) end
	if value == getGlobalStyleKey() then return value end
	if value == "NONE" or value == "OUTLINE" or value == "THICKOUTLINE" or value == "MONOCHROME" or value == "MONOCHROMEOUTLINE" then return value end
	return getGlobalStyleKey()
end

local function resolveAuraFont(key)
	key = normalizeAuraFontKey(key)
	if key == getGlobalFontKey() then key = addon.db and addon.db.globalFontFace or key end
	if addon.functions and addon.functions.ResolveLSMMedia then
		local resolved = addon.functions.ResolveLSMMedia("font", key, DEFAULT_FONT, true)
		if resolved then return resolved end
	end
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("font")
	if type(hash) == "table" and type(hash[key]) == "string" and hash[key] ~= "" then return hash[key] end
	return DEFAULT_FONT
end

local function resolveAuraFontStyle(style)
	if addon.functions and addon.functions.ResolveFontStyleChoice then return addon.functions.ResolveFontStyleChoice(style, "OUTLINE") end
	style = normalizeAuraFontStyle(style)
	if style == getGlobalStyleKey() then style = addon.db and addon.db.globalFontStyle or "OUTLINE" end
	if style == "NONE" then return "" end
	return style
end

local function buildAuraFontOptions()
	local options = {
		{ value = getGlobalFontKey(), label = getGlobalFontLabel() },
	}
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("font") or {}
	for _, name in ipairs(names) do
		options[#options + 1] = { value = name, label = name }
	end
	return options
end

local function buildAuraFontStyleOptions()
	if addon.functions and addon.functions.GetFontStyleOptionList then return addon.functions.GetFontStyleOptionList(true) end
	return {
		{ value = getGlobalStyleKey(), label = getGlobalStyleLabel() },
		{ value = "NONE", label = _G.NONE or "None" },
		{ value = "OUTLINE", label = L["Font outline"] or "Font outline" },
		{ value = "THICKOUTLINE", label = L["Thick outline"] or "Thick outline" },
		{ value = "MONOCHROME", label = "Monochrome" },
		{ value = "MONOCHROMEOUTLINE", label = "Monochrome Outline" },
	}
end

local function getDefaultAuraBorderSize(value, kind)
	local size = tonumber(value)
	if size == nil then size = tonumber(getDefaultAuraDBValue(kind, "BorderSize")) end
	size = size or 1
	if size < 1 then size = 1 end
	if size > 24 then size = 24 end
	return size
end

local function getDefaultAuraBorderOffset(value, kind)
	local offset = tonumber(value)
	if offset == nil then offset = tonumber(getDefaultAuraDBValue(kind, "BorderOffset")) end
	offset = offset or 0
	if offset < -20 then offset = -20 end
	if offset > 100 then offset = 100 end
	return offset
end

local function getDefaultAuraIconSize(value, kind)
	local size = tonumber(value)
	if size == nil then size = tonumber(getDefaultAuraDBValue(kind, "IconSize")) end
	size = size or 32
	if size < 16 then size = 16 end
	if size > 80 then size = 80 end
	return size
end

local function getDefaultAuraIconSpacing(value, kind)
	local spacing = tonumber(value)
	if spacing == nil then spacing = tonumber(getDefaultAuraDBValue(kind, "IconSpacing")) end
	spacing = spacing or 4
	if spacing < 0 then spacing = 0 end
	if spacing > 24 then spacing = 24 end
	return spacing
end

local function getDefaultAuraHorizontalSpacing(value, kind)
	local spacing = tonumber(value)
	if spacing == nil then spacing = tonumber(getDefaultAuraDBValue(kind, "HorizontalSpacing")) end
	if spacing == nil then spacing = getDefaultAuraIconSpacing(nil, kind) end
	if spacing < 0 then spacing = 0 end
	if spacing > 100 then spacing = 100 end
	return spacing
end

local function getDefaultAuraVerticalSpacing(value, kind)
	local spacing = tonumber(value)
	if spacing == nil then spacing = tonumber(getDefaultAuraDBValue(kind, "VerticalSpacing")) end
	if spacing == nil then spacing = getDefaultAuraIconSpacing(nil, kind) + 12 end
	if spacing < 0 then spacing = 0 end
	if spacing > 100 then spacing = 100 end
	return spacing
end

local function getDefaultAuraDrawSwipe(kind)
	return getDefaultAuraDBValue(kind, "CooldownDrawSwipe") ~= false
end

local function getDefaultAuraDurationTextProfile(kind)
	return normalizeDefaultAuraDurationTextProfile(getDefaultAuraDBValue(kind, "DurationTextProfile"))
end

local function applyDefaultAuraDurationTextProfile(button)
	if not (button and button.Cooldown and addon.functions and addon.functions.ApplyDurationTextProfileToCooldownFrame) then return false end
	return addon.functions.ApplyDurationTextProfileToCooldownFrame(button.Cooldown, getDefaultAuraDurationTextProfile(button.eqolDefaultAuraKind), { preserveCooldownUnits = true })
end

local function getDefaultAuraIconsPerRow(value, kind)
	local perRow = tonumber(value)
	if perRow == nil then perRow = tonumber(getDefaultAuraDBValue(kind, "IconsPerRow")) end
	perRow = perRow or 8
	if perRow < 1 then perRow = 1 end
	if perRow > 32 then perRow = 32 end
	return perRow
end

local function getDefaultAuraMaxRows(value, kind)
	local rows = tonumber(value)
	if rows == nil then rows = tonumber(getDefaultAuraDBValue(kind, "MaxRows")) end
	rows = rows or 4
	if rows < 1 then rows = 1 end
	if rows > 10 then rows = 10 end
	return rows
end

local function normalizeDefaultAuraSortMethod(value)
	value = type(value) == "string" and strupper(value) or "TIME"
	if value == "INDEX" or value == "NAME" or value == "TIME" then return value end
	return "TIME"
end

local function normalizeDefaultAuraSortDirection(value)
	value = type(value) == "string" and value or "-"
	if value == "+" or value == "-" then return value end
	return "-"
end

local function getAuraTextSize(key, fallback)
	local size = tonumber(addon.db and addon.db[key]) or fallback
	if size < 6 then size = 6 end
	if size > 64 then size = 64 end
	return size
end

local function getAuraTextOffset(key, axis, fallback)
	local value = addon.db and addon.db[key]
	if type(value) == "table" then value = value[axis] end
	value = tonumber(value) or fallback or 0
	if value < -100 then value = -100 end
	if value > 100 then value = 100 end
	return value
end

local function normalizeAuraAnchorPoint(value, fallback)
	value = type(value) == "string" and strupper(value) or fallback
	if value == "TOPLEFT" or value == "TOP" or value == "TOPRIGHT" or value == "LEFT" or value == "CENTER" or value == "RIGHT" or value == "BOTTOMLEFT" or value == "BOTTOM" or value == "BOTTOMRIGHT" then return value end
	return fallback or "CENTER"
end

local function buildAuraAnchorOptions()
	return {
		{ value = "TOPLEFT", label = "Top left" },
		{ value = "TOP", label = "Top" },
		{ value = "TOPRIGHT", label = "Top right" },
		{ value = "LEFT", label = "Left" },
		{ value = "CENTER", label = "Center" },
		{ value = "RIGHT", label = "Right" },
		{ value = "BOTTOMLEFT", label = "Bottom left" },
		{ value = "BOTTOM", label = "Bottom" },
		{ value = "BOTTOMRIGHT", label = "Bottom right" },
	}
end

local function setAuraFontStringStyle(fontString, prefix, fallbackColor, kind)
	if not fontString then return end
	local fontKey = getDefaultAuraDBValue(kind, prefix .. "FontFace")
	local styleKey = getDefaultAuraDBValue(kind, prefix .. "FontOutline")
	local size = getAuraTextSize(nil, tonumber(getDefaultAuraDBValue(kind, prefix .. "FontSize")) or (prefix == "Duration" and 10 or 12))
	local color = normalizeAuraTextColor(getDefaultAuraDBValue(kind, prefix .. "Color"), fallbackColor)
	local font = resolveAuraFont(fontKey)
	local style = resolveAuraFontStyle(styleKey)
	if addon.functions and addon.functions.SetFontWithFallback then
		addon.functions.SetFontWithFallback(fontString, font, size, style, DEFAULT_FONT)
	else
		fontString:SetFont(font, size, style)
	end
	fontString:SetTextColor(color.r, color.g, color.b, color.a)
end

local function ensureDefaultAuraTextLayer(button)
	if not button then return nil end
	local layer = button.eqolDefaultAuraTextLayer
	if not layer then
		layer = CreateFrame("Frame", nil, button)
		button.eqolDefaultAuraTextLayer = layer
	end
	layer:ClearAllPoints()
	layer:SetAllPoints(button)
	layer:SetFrameLevel((button:GetFrameLevel() or 1) + 10)
	return layer
end

local function positionAuraFontString(fontString, owner, prefix, defaultPoint, defaultX, defaultY, kind)
	if not (fontString and owner) then return end
	local point = normalizeAuraAnchorPoint(getDefaultAuraDBValue(kind, prefix .. "Anchor"), defaultPoint)
	local offset = getDefaultAuraDBValue(kind, prefix .. "Offset")
	local x = getAuraTextOffset(nil, "x", type(offset) == "table" and offset.x or defaultX)
	local y = getAuraTextOffset(nil, "y", type(offset) == "table" and offset.y or defaultY)
	fontString:ClearAllPoints()
	fontString:SetPoint(point, owner, point, x, y)
	if fontString.SetDrawLayer then fontString:SetDrawLayer("OVERLAY", 7) end
end

local function applyDefaultAuraTextStyle(button)
	if not button then return end
	local kind = button.eqolDefaultAuraKind
	local textLayer = ensureDefaultAuraTextLayer(button)
	if textLayer then
		if button.Duration and button.Duration.SetParent then button.Duration:SetParent(textLayer) end
		if button.Count and button.Count.SetParent then button.Count:SetParent(textLayer) end
	end
	local durationEnabled = getDefaultAuraDBValue(kind, "DurationEnabled") ~= false
	applyDefaultAuraDurationTextProfile(button)
	if button.Cooldown and button.Cooldown.SetHideCountdownNumbers then button.Cooldown:SetHideCountdownNumbers(not durationEnabled) end
	local internalCooldownText = button.Cooldown and button.Cooldown.GetCountdownFontString and button.Cooldown:GetCountdownFontString()
	if internalCooldownText then
		if not durationEnabled then
			internalCooldownText:Hide()
		else
			setAuraFontStringStyle(internalCooldownText, "Duration", DEFAULT_AURA_DURATION_COLOR, kind)
			positionAuraFontString(internalCooldownText, button, "Duration", "BOTTOM", 0, -1, kind)
		end
	end

	setAuraFontStringStyle(button.Duration, "Duration", DEFAULT_AURA_DURATION_COLOR, kind)
	positionAuraFontString(button.Duration, button, "Duration", "BOTTOM", 0, -1, kind)
	button.Duration:Hide()

	setAuraFontStringStyle(button.Count, "Count", DEFAULT_AURA_COUNT_COLOR, kind)
	positionAuraFontString(button.Count, button, "Count", "TOPRIGHT", -1, -1, kind)
end

local function setDefaultAuraCooldownDuration(button, startTime, duration)
	if not (button and button.Cooldown and startTime and duration) then return false end
	if button.Cooldown.SetCooldownFromDurationObject and C_DurationUtil and C_DurationUtil.CreateDuration then
		local durationObject = button.eqolDefaultAuraDurationObject
		if not durationObject then
			durationObject = C_DurationUtil.CreateDuration()
			button.eqolDefaultAuraDurationObject = durationObject
		end
		durationObject:SetTimeFromStart(startTime, duration)
		button.Cooldown:SetCooldownFromDurationObject(durationObject)
		return true
	end
	CooldownFrame_Set(button.Cooldown, startTime, duration, true)
	return true
end

local function isNoAuraBorder(value)
	if addon.IconShape and addon.IconShape.IsNoBorder then return addon.IconShape.IsNoBorder(value) end
	return type(value) == "string" and strupper(value) == "NONE"
end

local function isBackdropAuraBorderCompatible(shape)
	if addon.IconShape and addon.IconShape.IsBackdropBorderCompatible then return addon.IconShape.IsBackdropBorderCompatible(shape) end
	shape = normalizeAuraIconShape(shape)
	return shape == "DEFAULT" or shape == "SQUARE"
end

local function resolveAuraBackdropBorder(borderKey)
	if not borderKey or borderKey == "" or isNoAuraBorder(borderKey) then return nil end
	if borderKey == "DEFAULT" then return "Interface\\Buttons\\WHITE8X8" end
	if addon.functions and addon.functions.GetLSMMediaHash then
		local media = addon.functions.GetLSMMediaHash("border")
		if type(media) == "table" and type(media[borderKey]) == "string" and media[borderKey] ~= "" then return media[borderKey] end
	end
	return borderKey
end

local function ensureDefaultAuraWatcher()
	if DAC.variables.defaultAuraWatcher then return DAC.variables.defaultAuraWatcher end
	local watcher = CreateFrame("Frame")
	watcher:SetScript("OnEvent", function()
		if DAC.variables.pendingDefaultAuraCombat then
			DAC.variables.pendingDefaultAuraCombat = nil
			if DAC.functions and DAC.functions.RefreshDefaultAuraIconSkin then DAC.functions.RefreshDefaultAuraIconSkin() end
		end
		if not DAC.variables.pendingDefaultAuraCombat then watcher:UnregisterEvent("PLAYER_REGEN_ENABLED") end
	end)
	DAC.variables.defaultAuraWatcher = watcher
	return watcher
end

local function applyDefaultAuraBackdropBorder(button, icon, borderKey, color, kind)
	if not (button and icon) then return false end
	local borderTexture = resolveAuraBackdropBorder(borderKey)
	if not borderTexture then return false end
	local size = getDefaultAuraBorderSize(nil, kind)
	local offset = getDefaultAuraBorderOffset(nil, kind)
	local border = button.eqolDefaultAuraBackdropBorder
	if not border then
		border = CreateFrame("Frame", nil, button, "BackdropTemplate")
		button.eqolDefaultAuraBackdropBorder = border
	end
	border:ClearAllPoints()
	border:SetPoint("TOPLEFT", icon, "TOPLEFT", -offset, offset)
	border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
	border:SetBackdrop({ edgeFile = borderTexture, edgeSize = size })
	border:SetBackdropBorderColor(color[1], color[2], color[3], color[4])
	border:SetFrameLevel((button:GetFrameLevel() or 1) + 4)
	border:Show()
	ensureDefaultAuraTextLayer(button)
	return true
end

local function applyDefaultAuraShapeBorder(button, icon, borderKey, shape, color, kind)
	if not (addon.IconShape and addon.IconShape.ApplyBorder and button and icon) then return false end
	local applied = addon.IconShape.ApplyBorder(button, borderKey, shape, {
		allowNone = true,
		emptyValue = addon.IconShape.BORDER and addon.IconShape.BORDER.NONE or "NONE",
		pointFrame = icon,
		borderSize = getDefaultAuraBorderSize(nil, kind),
		borderOffset = getDefaultAuraBorderOffset(nil, kind),
		color = color,
		texturesKey = "_eqolDefaultAuraShapeBorderTextures",
		drawLayer = "OVERLAY",
		subLevel = 6,
	})
	ensureDefaultAuraTextLayer(button)
	return applied
end

local function ensureDefaultAuraButtonVisuals(button)
	if not button or button.eqolDefaultAuraVisualsReady then return end
	button.eqolDefaultAuraVisualsReady = true
	button:SetScript("OnEnter", function(self)
		local targetSlot = self:GetAttribute("target-slot")
		if targetSlot then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
			GameTooltip:SetInventoryItem("player", targetSlot)
			return
		end
		local unit = self.eqolAuraUnit or "player"
		local auraInstanceID = self.eqolAuraInstanceID
		if not auraInstanceID then return end
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetUnitAuraByAuraInstanceID(unit, auraInstanceID)
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	button.Icon = button.Icon or button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints(button)
	if not button.Icon.GetTexture or not button.Icon:GetTexture() then button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end

	button.Cooldown = button.Cooldown or CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.Cooldown:SetAllPoints(button)
	button.Cooldown:SetDrawEdge(false)
	if button.Cooldown.SetDrawSwipe then button.Cooldown:SetDrawSwipe(getDefaultAuraDrawSwipe(button.eqolDefaultAuraKind)) end
	if button.Cooldown.SetHideCountdownNumbers then button.Cooldown:SetHideCountdownNumbers(false) end
	button.Cooldown:SetSwipeColor(0, 0, 0, 0.65)

	local textLayer = ensureDefaultAuraTextLayer(button) or button
	button.Count = button.Count or textLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)

	button.Duration = button.Duration or textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.Duration:SetPoint("TOP", button, "BOTTOM", 0, -1)
	button.Duration:SetTextColor(1, 0.82, 0)
	applyDefaultAuraTextStyle(button)
end

local function clearDefaultAuraCustomBorder(button)
	if not button then return end
	if button.eqolDefaultAuraBackdropBorder then button.eqolDefaultAuraBackdropBorder:Hide() end
	if addon.IconShape and addon.IconShape.HideBorderTextures then
		addon.IconShape.HideBorderTextures(button, { texturesKey = "_eqolDefaultAuraShapeBorderTextures" })
	end
end

local function applyDefaultAuraButtonStyle(button, force)
	if not button then return end
	ensureDefaultAuraButtonVisuals(button)
	local icon = button.Icon or button.icon
	if not icon then return end

	local kind = button.eqolDefaultAuraKind
	local size = getDefaultAuraIconSize(nil, kind)
	local shape = normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape"))
	local zoom = normalizeAuraIconZoom(getDefaultAuraDBValue(kind, "IconZoom"))
	local borderKey = normalizeAuraBorder(getDefaultAuraDBValue(kind, "BorderTexture"), shape)
	local color = resolveDefaultAuraBorderColor(button, kind)
	local hasCustomBorder = not isNoAuraBorder(borderKey)
	local styleKey = tostring(kind) .. ":" .. tostring(size) .. ":" .. tostring(shape) .. ":" .. tostring(zoom) .. ":" .. tostring(borderKey) .. ":" .. tostring(getDefaultAuraBorderSize(nil, kind)) .. ":" .. tostring(getDefaultAuraBorderOffset(nil, kind)) .. ":" .. tostring(getDefaultAuraDrawSwipe(kind)) .. ":" .. tostring(getDefaultAuraDurationTextProfile(kind)) .. ":" .. tostring(addon.DurationText and addon.DurationText.version or 0) .. ":" .. tostring(color.r) .. ":" .. tostring(color.g) .. ":" .. tostring(color.b) .. ":" .. tostring(color.a)
	if not force and button.eqolDefaultAuraStyleKey == styleKey then return end
	button.eqolDefaultAuraStyleKey = styleKey

	if force and not (InCombatLockdown and InCombatLockdown()) then button:SetSize(size, size) end
	button.Icon:SetAllPoints(button)
	button.Cooldown:SetAllPoints(button)
	if button.Cooldown.SetDrawSwipe then button.Cooldown:SetDrawSwipe(getDefaultAuraDrawSwipe(kind)) end
	if button.Cooldown.SetHideCountdownNumbers then button.Cooldown:SetHideCountdownNumbers(getDefaultAuraDBValue(kind, "DurationEnabled") == false) end
	applyDefaultAuraTextStyle(button)

	if addon.IconShape and addon.IconShape.ApplyFrameShape then
		addon.IconShape.ApplyFrameShape(button, shape, {
			textures = { icon },
			cooldown = button.Cooldown or button.cooldown,
			iconZoom = zoom,
			textureMaskKey = "_eqolDefaultAuraIconMask",
			textureTexCoordKey = "_eqolDefaultAuraIconTexCoord",
			maskKey = "_eqolDefaultAuraMask",
			refreshSwipe = function(owner)
				if addon.IconShape and addon.IconShape.ApplyCooldownSwipeVisual then
					addon.IconShape.ApplyCooldownSwipeVisual(owner and owner.Cooldown, owner, nil, nil, { customColor = false })
				end
			end,
		})
	elseif icon.SetTexCoord then
		icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end
	applyDefaultAuraIconDarkMode(button, kind)

	clearDefaultAuraCustomBorder(button)
	if hasCustomBorder then
		if isBackdropAuraBorderCompatible(shape) then
			applyDefaultAuraBackdropBorder(button, icon, borderKey, color, kind)
		else
			applyDefaultAuraShapeBorder(button, icon, borderKey, shape, color, kind)
		end
	end
end

local function resolveDefaultTempEnchantIcon(slot)
	local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
	if texture then return texture end
	local itemLink = GetInventoryItemLink and GetInventoryItemLink("player", slot)
	if itemLink and C_Item then
		if C_Item.GetItemIconByID then
			texture = C_Item.GetItemIconByID(itemLink)
			if texture then return texture end
		end
		if C_Item.GetItemInfoInstant then
			texture = select(5, C_Item.GetItemInfoInstant(itemLink))
			if texture then return texture end
		end
	end
	local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
	if itemID and C_Item then
		if C_Item.GetItemIconByID then
			texture = C_Item.GetItemIconByID(itemID)
			if texture then return texture end
		end
		if C_Item.GetItemInfoInstant then
			texture = select(5, C_Item.GetItemInfoInstant(itemID))
			if texture then return texture end
		end
	end
	return nil
end

local function updateDefaultTempEnchantButton(button, kind)
	if not button or not button:IsShown() then return end
	button.eqolDefaultAuraKind = normalizeDefaultAuraKind(kind)
	ensureDefaultAuraButtonVisuals(button)
	if not button.eqolDefaultAuraStyleKey then applyDefaultAuraButtonStyle(button, true) end

	local slot = button:GetAttribute("target-slot")
	if not slot then return end

	local mainSlot = GetInventorySlotInfo and GetInventorySlotInfo("MainHandSlot")
	local offSlot = GetInventorySlotInfo and GetInventorySlotInfo("SecondaryHandSlot")
	local hasEnchant, expirationMS, charges
	if slot == mainSlot then
		hasEnchant, expirationMS, charges = GetWeaponEnchantInfo()
	elseif slot == offSlot then
		hasEnchant, expirationMS, charges = select(5, GetWeaponEnchantInfo())
	else
		hasEnchant, expirationMS, charges = false, nil, nil
	end
	if issecretvalue and issecretvalue(expirationMS) then expirationMS = nil end
	if issecretvalue and issecretvalue(charges) then charges = nil end

	if not hasEnchant then
		button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		button.Count:Hide()
		button.Duration:Hide()
		button.Cooldown:Hide()
		button.eqolAuraInstanceID = nil
		return
	end

	local texture = resolveDefaultTempEnchantIcon(slot)
	button.Icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	button.eqolAuraUnit = "player"
	button.eqolAuraInstanceID = nil
	local chargeText = charges and charges > 0 and tostring(charges) or ""
	button.Count:SetText(chargeText)
	button.Count:SetShown(getDefaultAuraDBValue(kind, "CountEnabled") ~= false and chargeText ~= "")

	local timeLeft = (tonumber(expirationMS) or 0) / 1000
	if timeLeft > 0 then
		setDefaultAuraCooldownDuration(button, GetTime(), timeLeft)
		if addon.IconShape and addon.IconShape.ApplyCooldownSwipeVisual then addon.IconShape.ApplyCooldownSwipeVisual(button.Cooldown, button, nil, nil, { customColor = false }) end
		button.Cooldown:Show()
	else
		button.Cooldown:Hide()
		button.Duration:Hide()
	end

	if GameTooltip:IsOwned(button) then GameTooltip:SetInventoryItem("player", slot) end
end

local function updateDefaultAuraButton(button, unit, filter, kind)
	if not button or not button:IsShown() then return end
	button.eqolDefaultAuraKind = normalizeDefaultAuraKind(kind)
	if button:GetAttribute("target-slot") then
		updateDefaultTempEnchantButton(button, kind)
		return
	end
	ensureDefaultAuraButtonVisuals(button)
	if not button.eqolDefaultAuraStyleKey then applyDefaultAuraButtonStyle(button, true) end

	local index = button:GetAttribute("index") or button:GetID()
	local aura
	if index and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
		if ok then aura = data end
	end
	if not aura then
		button.Icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		button.Count:Hide()
		button.Duration:Hide()
		button.eqolAuraInstanceID = nil
		return
	end

	button.eqolAuraUnit = unit
	button.eqolAuraInstanceID = aura.auraInstanceID
	button.Icon:SetTexture(aura.icon)

	local countText = ""
	if C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID then
		countText = C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2) or ""
	end
	button.Count:SetText(countText)
	button.Count:SetShown(getDefaultAuraDBValue(kind, "CountEnabled") ~= false)

	local auraDuration
	if C_UnitAuras.GetAuraDuration and aura.auraInstanceID then
		local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
		if ok then auraDuration = durationObject end
	end
	if auraDuration and button.Cooldown.SetCooldownFromDurationObject then
		button.Duration:Hide()
		button.Cooldown:SetCooldownFromDurationObject(auraDuration)
		if addon.IconShape and addon.IconShape.ApplyCooldownSwipeVisual then addon.IconShape.ApplyCooldownSwipeVisual(button.Cooldown, button, nil, nil, { customColor = false }) end
		button.Cooldown:Show()
	else
		button.Cooldown:Hide()
		button.Duration:Hide()
	end

	if GameTooltip:IsOwned(button) and aura.auraInstanceID then GameTooltip:SetUnitAuraByAuraInstanceID(unit, aura.auraInstanceID) end
end

local function forEachDefaultAuraHeaderChild(header, func, ...)
	if not (header and func) then return end
	local index = 1
	local child = header:GetAttribute("child" .. index)
	while child do
		func(child, ...)
		index = index + 1
		child = header:GetAttribute("child" .. index)
	end
	index = 1
	child = header:GetAttribute("tempEnchant" .. index)
	while child do
		func(child, ...)
		index = index + 1
		child = header:GetAttribute("tempEnchant" .. index)
	end
end

local function applyDefaultAuraHeaderButtonStyles(header, force)
	if not header then return end
	local filter = header:GetAttribute("filter") or "HELPFUL"
	local kind = header.eqolDefaultAuraKind or (filter == "HARMFUL" and "debuff" or "buff")
	forEachDefaultAuraHeaderChild(header, function(child)
		child.eqolDefaultAuraKind = kind
		applyDefaultAuraButtonStyle(child, force)
	end)
end

local function updateDefaultAuraHeaderButtons(header)
	if not header then return end
	local unit = header:GetAttribute("unit") or "player"
	local filter = header:GetAttribute("filter") or "HELPFUL"
	local kind = header.eqolDefaultAuraKind or (filter == "HARMFUL" and "debuff" or "buff")
	forEachDefaultAuraHeaderChild(header, updateDefaultAuraButton, unit, filter, kind)
end

local function updateDefaultAuraHeaderTempEnchantButtons(header)
	if not header then return end
	local kind = header.eqolDefaultAuraKind or "buff"
	local index = 1
	local child = header:GetAttribute("tempEnchant" .. index)
	while child do
		updateDefaultTempEnchantButton(child, kind)
		index = index + 1
		child = header:GetAttribute("tempEnchant" .. index)
	end
end

local function scheduleDefaultTempEnchantUpdate()
	DAC.variables.defaultTempEnchantUpdateToken = (DAC.variables.defaultTempEnchantUpdateToken or 0) + 1
	local token = DAC.variables.defaultTempEnchantUpdateToken
	C_Timer.After(0.5, function()
		if token ~= DAC.variables.defaultTempEnchantUpdateToken then return end
		updateDefaultAuraHeaderTempEnchantButtons(DAC.variables.defaultBuffHeader)
	end)
end

local function ensureDefaultTempEnchantWatcher()
	if DAC.variables.defaultTempEnchantWatcher then return DAC.variables.defaultTempEnchantWatcher end
	local watcher = CreateFrame("Frame")
	watcher:SetScript("OnEvent", scheduleDefaultTempEnchantUpdate)
	watcher:RegisterEvent("WEAPON_ENCHANT_CHANGED")
	DAC.variables.defaultTempEnchantWatcher = watcher
	return watcher
end

local function configureDefaultAuraHeader(header, filter, kind)
	kind = normalizeDefaultAuraKind(kind)
	header.eqolDefaultAuraKind = kind
	local size = getDefaultAuraIconSize(nil, kind)
	local horizontalSpacing = getDefaultAuraHorizontalSpacing(nil, kind)
	local verticalSpacing = getDefaultAuraVerticalSpacing(nil, kind)
	local perRow = getDefaultAuraIconsPerRow(nil, kind)
	local maxRows = getDefaultAuraMaxRows(nil, kind)
	header:SetAttribute("unit", "player")
	header:SetAttribute("filter", filter)
	header:SetAttribute("template", "SecureAuraButtonTemplate")
	header:SetAttribute("weaponTemplate", filter == "HELPFUL" and "SecureAuraButtonTemplate" or nil)
	header:SetAttribute("config-width", size)
	header:SetAttribute("config-height", size)
	header:SetAttribute("initialConfigFunction", DEFAULT_AURA_INITIAL_CONFIG)
	header:SetAttribute("sortMethod", normalizeDefaultAuraSortMethod(getDefaultAuraDBValue(kind, "SortMethod")))
	header:SetAttribute("sortDirection", normalizeDefaultAuraSortDirection(getDefaultAuraDBValue(kind, "SortDirection")))
	header:SetAttribute("wrapAfter", perRow)
	header:SetAttribute("maxWraps", maxRows)
	header:SetAttribute("point", "TOPRIGHT")
	header:SetAttribute("xOffset", -(size + horizontalSpacing))
	header:SetAttribute("yOffset", 0)
	header:SetAttribute("wrapXOffset", 0)
	header:SetAttribute("wrapYOffset", -(size + verticalSpacing))
	header:SetAttribute("minWidth", perRow * size + (perRow - 1) * horizontalSpacing)
	header:SetAttribute("minHeight", maxRows * size + (maxRows - 1) * verticalSpacing)
	if filter == "HELPFUL" then
		header:SetAttribute("includeWeapons", getDefaultAuraDBValue(kind, "IncludeWeapons") == true and 1 or 0)
	end
	header:SetSize(perRow * size + (perRow - 1) * horizontalSpacing, maxRows * size + (maxRows - 1) * verticalSpacing)
	if filter == "HELPFUL" then ensureDefaultTempEnchantWatcher() end
	applyDefaultAuraHeaderButtonStyles(header, true)
	updateDefaultAuraHeaderButtons(header)
end

local function createDefaultAuraHeader(kind, filter)
	local name = kind == "buff" and "EnhanceQoLCustomBuffFrame" or "EnhanceQoLCustomDebuffFrame"
	local header = _G[name] or CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
	header:SetClampedToScreen(true)
	header:UnregisterEvent("UNIT_AURA")
	header:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
	if filter == "HELPFUL" then header:RegisterEvent("WEAPON_ENCHANT_CHANGED") end
	if RegisterAttributeDriver then RegisterAttributeDriver(header, "unit", "[vehicleui] vehicle; player") end
	if not header.eqolDefaultAuraHooksInstalled then
		header.eqolDefaultAuraHooksInstalled = true
		header:HookScript("OnEvent", updateDefaultAuraHeaderButtons)
		header:HookScript("OnShow", updateDefaultAuraHeaderButtons)
	end
	configureDefaultAuraHeader(header, filter, kind)
	return header
end

local function ensureDefaultAuraAnchor(kind)
	local isBuff = kind == "buff"
	local key = isBuff and "defaultBuffAnchor" or "defaultDebuffAnchor"
	local name = isBuff and "EnhanceQoLCustomBuffFrameAnchor" or "EnhanceQoLCustomDebuffFrameAnchor"
	local anchor = DAC.variables[key] or _G[name] or CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	DAC.variables[key] = anchor
	anchor:SetSize(getDefaultAuraIconsPerRow(nil, kind) * getDefaultAuraIconSize(nil, kind) + (getDefaultAuraIconsPerRow(nil, kind) - 1) * getDefaultAuraHorizontalSpacing(nil, kind), getDefaultAuraMaxRows(nil, kind) * getDefaultAuraIconSize(nil, kind) + (getDefaultAuraMaxRows(nil, kind) - 1) * getDefaultAuraVerticalSpacing(nil, kind))
	anchor:SetFrameStrata("MEDIUM")
	anchor:SetFrameLevel(50)
	if anchor.SetClampedToScreen then anchor:SetClampedToScreen(true) end
	if anchor.SetClampRectInsets then anchor:SetClampRectInsets(0, 0, 0, 0) end
	anchor:SetMovable(true)
	anchor:EnableMouse(false)
	return anchor
end

local function attachDefaultAuraHeaderToAnchor(header, anchor)
	if not (header and anchor) then return end
	if header:GetParent() ~= anchor then header:SetParent(anchor) end
	header:ClearAllPoints()
	header:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
	header:SetFrameStrata(anchor:GetFrameStrata())
	header:SetFrameLevel((anchor:GetFrameLevel() or 1) + 1)
end

local SAMPLE_AURA_ICONS = {
	"Interface\\Icons\\Spell_Holy_WordFortitude",
	"Interface\\Icons\\Spell_Nature_Rejuvenation",
	"Interface\\Icons\\Spell_Holy_Renew",
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	"Interface\\Icons\\Spell_Fire_FlameShock",
	"Interface\\Icons\\Spell_Nature_Regeneration",
	"Interface\\Icons\\Spell_Holy_PrayerOfMendingtga",
	"Interface\\Icons\\Spell_Nature_ResistNature",
	"Interface\\Icons\\Spell_Holy_SealOfSalvation",
	"Interface\\Icons\\Spell_Magic_GreaterBlessingOfKings",
	"Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
	"Interface\\Icons\\Spell_Shadow_CurseOfTounges",
	"Interface\\Icons\\Spell_Shadow_AbominationExplosion",
	"Interface\\Icons\\Spell_Frost_ChainsOfIce",
	"Interface\\Icons\\Spell_Nature_StrangleVines",
	"Interface\\Icons\\Ability_Creature_Cursed_02",
	"Interface\\Icons\\Spell_Shadow_Possession",
	"Interface\\Icons\\Spell_Shadow_PlagueCloud",
	"Interface\\Icons\\Spell_Fire_Incinerate",
	"Interface\\Icons\\Spell_Nature_CorrosiveBreath",
}

local function hideDefaultAuraSamples(kind)
	kind = normalizeDefaultAuraKind(kind)
	local anchor = DAC.variables[kind == "debuff" and "defaultDebuffAnchor" or "defaultBuffAnchor"]
	local samples = anchor and anchor.eqolDefaultAuraSamples
	if samples then
		for i = 1, #samples do samples[i]:Hide() end
	end
	local header = DAC.variables[kind == "debuff" and "defaultDebuffHeader" or "defaultBuffHeader"]
	local enabled = addon.db and ((kind == "debuff" and addon.db.skinnerDefaultDebuffIconsEnabled == true) or (kind == "buff" and addon.db.skinnerDefaultBuffIconsEnabled == true))
	if header and enabled then header:Show() end
end

local function refreshDefaultAuraSamples(kind)
	kind = normalizeDefaultAuraKind(kind)
	local anchor = DAC.variables[kind == "debuff" and "defaultDebuffAnchor" or "defaultBuffAnchor"]
	if not (anchor and anchor.eqolDefaultAuraSamplesEnabled) then return end
	local header = DAC.variables[kind == "debuff" and "defaultDebuffHeader" or "defaultBuffHeader"]
	if header then header:Hide() end
	local samples = anchor.eqolDefaultAuraSamples
	if not samples then
		samples = {}
		anchor.eqolDefaultAuraSamples = samples
	end

	local size = getDefaultAuraIconSize(nil, kind)
	local horizontalSpacing = getDefaultAuraHorizontalSpacing(nil, kind)
	local perRow = getDefaultAuraIconsPerRow(nil, kind)
	local verticalSpacing = getDefaultAuraVerticalSpacing(nil, kind)
	local maxRows = getDefaultAuraMaxRows(nil, kind)
	local count = perRow * maxRows
	for i = 1, count do
		local sample = samples[i]
		if not sample then
			sample = CreateFrame("Frame", nil, anchor)
			sample.Icon = sample:CreateTexture(nil, "ARTWORK")
			sample.Icon:SetAllPoints(sample)
			sample.Cooldown = CreateFrame("Cooldown", nil, sample, "CooldownFrameTemplate")
			sample.Cooldown:SetAllPoints(sample)
			sample.Count = sample:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
			sample.Duration = sample:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			samples[i] = sample
		end
		sample.eqolDefaultAuraKind = kind
		sample.Icon:SetTexture(SAMPLE_AURA_ICONS[((i - 1) % #SAMPLE_AURA_ICONS) + 1] or "Interface\\Icons\\INV_Misc_QuestionMark")
		local showCount = getDefaultAuraDBValue(kind, "CountEnabled") ~= false and (i == 1 or i == 6 or i == 13)
		sample.Count:SetText(showCount and tostring((i % 4) + 2) or "")
		sample.Count:SetShown(showCount)
		setDefaultAuraCooldownDuration(sample, GetTime() - i, 30 + i * 8)
		sample:ClearAllPoints()
		sample:SetSize(size, size)
		local column = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		if column == 0 then
			sample:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -row * (size + verticalSpacing))
		else
			sample:SetPoint("RIGHT", samples[i - 1], "LEFT", -horizontalSpacing, 0)
		end
		applyDefaultAuraButtonStyle(sample)
		sample:Show()
	end
	for i = count + 1, #samples do samples[i]:Hide() end
end

local function toggleDefaultAuraSamples(kind)
	kind = normalizeDefaultAuraKind(kind)
	local anchor = DAC.variables[kind == "debuff" and "defaultDebuffAnchor" or "defaultBuffAnchor"]
	if not anchor then return end
	anchor.eqolDefaultAuraSamplesEnabled = not anchor.eqolDefaultAuraSamplesEnabled
	if anchor.eqolDefaultAuraSamplesEnabled then
		refreshDefaultAuraSamples(kind)
	else
		hideDefaultAuraSamples(kind)
	end
end

local function hideBlizzardAuraFrame(frame)
	if not (frame and frame.Hide) then return end
	frame.eqolDefaultAuraHiddenByDefaultAuraContainers = true
	frame:Hide()
end

local function markDefaultAuraReloadRequired()
	addon.variables = addon.variables or {}
	addon.variables.requireReload = true
	if addon.functions and addon.functions.checkReloadFrame then addon.functions.checkReloadFrame() end
end

local function applyDefaultAuraEditModeSetting(kind, field, value)
	kind = normalizeDefaultAuraKind(kind)
	if field == "shape" then
		local shape = normalizeAuraIconShape(value)
		setDefaultAuraDBValue(kind, "IconShape", shape)
		setDefaultAuraDBValue(kind, "BorderTexture", normalizeAuraBorder(getDefaultAuraDBValue(kind, "BorderTexture"), shape))
	elseif field == "zoom" then
		setDefaultAuraDBValue(kind, "IconZoom", normalizeAuraIconZoom(value))
	elseif field == "iconDarkMode" then
		setDefaultAuraDBValue(kind, "IconDarkMode", value == true)
	elseif field == "iconDarkness" then
		setDefaultAuraDBValue(kind, "IconDarkness", normalizeAuraIconDarkness(value))
	elseif field == "iconDesaturate" then
		setDefaultAuraDBValue(kind, "IconDesaturate", value == true)
	elseif field == "size" then
		setDefaultAuraDBValue(kind, "IconSize", getDefaultAuraIconSize(value, kind))
	elseif field == "horizontalSpacing" then
		setDefaultAuraDBValue(kind, "HorizontalSpacing", getDefaultAuraHorizontalSpacing(value, kind))
	elseif field == "verticalSpacing" then
		setDefaultAuraDBValue(kind, "VerticalSpacing", getDefaultAuraVerticalSpacing(value, kind))
	elseif field == "drawSwipe" then
		setDefaultAuraDBValue(kind, "CooldownDrawSwipe", value == true)
	elseif field == "perRow" then
		setDefaultAuraDBValue(kind, "IconsPerRow", getDefaultAuraIconsPerRow(value, kind))
	elseif field == "maxRows" then
		setDefaultAuraDBValue(kind, "MaxRows", getDefaultAuraMaxRows(value, kind))
	elseif field == "sortMethod" then
		setDefaultAuraDBValue(kind, "SortMethod", normalizeDefaultAuraSortMethod(value))
	elseif field == "sortDirection" then
		setDefaultAuraDBValue(kind, "SortDirection", normalizeDefaultAuraSortDirection(value))
	elseif field == "includeWeapons" then
		setDefaultAuraDBValue(kind, "IncludeWeapons", value == true)
	elseif field == "border" then
		local shape = normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape"))
		setDefaultAuraDBValue(kind, "BorderTexture", normalizeAuraBorder(value, shape))
	elseif field == "borderSize" then
		setDefaultAuraDBValue(kind, "BorderSize", getDefaultAuraBorderSize(value, kind))
	elseif field == "borderOffset" then
		setDefaultAuraDBValue(kind, "BorderOffset", getDefaultAuraBorderOffset(value, kind))
	elseif field == "useOriginalBorderColor" then
		setDefaultAuraDBValue(kind, "UseOriginalBorderColor", value == true)
	elseif field == "borderColor" then
		setDefaultAuraDBValue(kind, "BorderColor", value)
	elseif field == "durationEnabled" then
		setDefaultAuraDBValue(kind, "DurationEnabled", value == true)
	elseif field == "durationFont" then
		setDefaultAuraDBValue(kind, "DurationFontFace", normalizeAuraFontKey(value))
	elseif field == "durationOutline" then
		setDefaultAuraDBValue(kind, "DurationFontOutline", normalizeAuraFontStyle(value))
	elseif field == "durationSize" then
		setDefaultAuraDBValue(kind, "DurationFontSize", getAuraTextSize(nil, tonumber(value) or 10))
	elseif field == "durationColor" then
		setDefaultAuraDBValue(kind, "DurationColor", normalizeAuraTextColor(value, DEFAULT_AURA_DURATION_COLOR))
	elseif field == "durationAnchor" then
		setDefaultAuraDBValue(kind, "DurationAnchor", normalizeAuraAnchorPoint(value, "BOTTOM"))
	elseif field == "durationOffsetX" then
		local offset = copyValue(getDefaultAuraDBValue(kind, "DurationOffset"))
		if type(offset) ~= "table" then offset = {} end
		offset.x = getAuraTextOffset(nil, nil, tonumber(value) or 0)
		setDefaultAuraDBValue(kind, "DurationOffset", offset)
	elseif field == "durationOffsetY" then
		local offset = copyValue(getDefaultAuraDBValue(kind, "DurationOffset"))
		if type(offset) ~= "table" then offset = {} end
		offset.y = getAuraTextOffset(nil, nil, tonumber(value) or -1)
		setDefaultAuraDBValue(kind, "DurationOffset", offset)
	elseif field == "durationTextProfile" then
		setDefaultAuraDBValue(kind, "DurationTextProfile", normalizeDefaultAuraDurationTextProfile(value))
	elseif field == "countEnabled" then
		setDefaultAuraDBValue(kind, "CountEnabled", value == true)
	elseif field == "countFont" then
		setDefaultAuraDBValue(kind, "CountFontFace", normalizeAuraFontKey(value))
	elseif field == "countOutline" then
		setDefaultAuraDBValue(kind, "CountFontOutline", normalizeAuraFontStyle(value))
	elseif field == "countSize" then
		setDefaultAuraDBValue(kind, "CountFontSize", getAuraTextSize(nil, tonumber(value) or 12))
	elseif field == "countColor" then
		setDefaultAuraDBValue(kind, "CountColor", normalizeAuraTextColor(value, DEFAULT_AURA_COUNT_COLOR))
	elseif field == "countAnchor" then
		setDefaultAuraDBValue(kind, "CountAnchor", normalizeAuraAnchorPoint(value, "TOPRIGHT"))
	elseif field == "countOffsetX" then
		local offset = copyValue(getDefaultAuraDBValue(kind, "CountOffset"))
		if type(offset) ~= "table" then offset = {} end
		offset.x = getAuraTextOffset(nil, nil, tonumber(value) or -1)
		setDefaultAuraDBValue(kind, "CountOffset", offset)
	elseif field == "countOffsetY" then
		local offset = copyValue(getDefaultAuraDBValue(kind, "CountOffset"))
		if type(offset) ~= "table" then offset = {} end
		offset.y = getAuraTextOffset(nil, nil, tonumber(value) or -1)
		setDefaultAuraDBValue(kind, "CountOffset", offset)
	elseif field == "sync" then
		addon.db["skinnerDefaultAuraSyncBuffDebuff"] = value == true
	end
	refreshDefaultAuraIconSkin()
end

local function createDefaultAuraEditModeSettings(kind)
	kind = normalizeDefaultAuraKind(kind)
	local EditMode = addon.EditMode
	local SettingType = (EditMode and EditMode.lib and EditMode.lib.SettingType) or (addon.EditModeLib and addon.EditModeLib.SettingType)
	if not SettingType then return nil end

	local function dropdown(name, getValue, setValue, buildOptions, height, enabled, parentId)
		local function refreshSettings()
			local internal = addon.EditModeLib and addon.EditModeLib.internal
			if internal and internal.RequestRefreshSettings then internal:RequestRefreshSettings() end
		end
		return {
			name = name,
			kind = SettingType.Dropdown,
			parentId = parentId,
			height = height or 180,
			get = function() return getValue() end,
			set = function(_, value)
				setValue(value)
				refreshSettings()
			end,
			generator = function(_, root)
				for _, option in ipairs(buildOptions()) do
					root:CreateRadio(option.label, function() return getValue() == option.value end, function()
						setValue(option.value)
						refreshSettings()
					end)
				end
			end,
			isEnabled = enabled,
		}
	end

	local function slider(name, getValue, setValue, minValue, maxValue, step, enabled, parentId)
		return {
			name = name,
			kind = SettingType.Slider,
			parentId = parentId,
			minValue = minValue,
			maxValue = maxValue,
			valueStep = step or 1,
			allowInput = true,
			get = function() return getValue() end,
			set = function(_, value) setValue(value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			isEnabled = enabled,
		}
	end
	local function checkbox(name, getValue, setValue, enabled, parentId)
		return {
			name = name,
			kind = SettingType.Checkbox,
			parentId = parentId,
			get = function() return getValue() end,
			set = function(_, value) setValue(value) end,
			isEnabled = enabled,
		}
	end
	local function color(name, getValue, setValue, enabled, parentId)
		return {
			name = name,
			kind = SettingType.Color,
			parentId = parentId,
			hasOpacity = true,
			get = function() return getValue() end,
			set = function(_, value) setValue(value) end,
			isEnabled = enabled,
		}
	end

	local function shapeOptions()
		return addon.IconShape and addon.IconShape.GetOptions and addon.IconShape.GetOptions(L) or {
			{ value = "DEFAULT", label = _G.DEFAULT or "Default" },
			{ value = "SQUARE", label = "Square" },
			{ value = "ROUND", label = "Round" },
			{ value = "HEXAGON", label = "Hexagon" },
			{ value = "DIAMOND", label = "Diamond" },
		}
	end
	local function borderOptions()
		local shape = normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape"))
		return addon.IconShape and addon.IconShape.GetBorderOptions and addon.IconShape.GetBorderOptions(L, shape, {
			includeDefault = true,
			defaultValue = "DEFAULT",
			defaultLabel = _G.DEFAULT or "Default",
			includeNone = true,
			noneLabel = _G.NONE or "None",
			sort = false,
		}) or {
			{ value = "NONE", label = _G.NONE or "None" },
			{ value = "DEFAULT", label = _G.DEFAULT or "Default" },
		}
	end
	local function borderEnabled()
		local shape = normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape"))
		local borderKey = normalizeAuraBorder(getDefaultAuraDBValue(kind, "BorderTexture"), shape)
		return not isNoAuraBorder(borderKey)
	end
	local function borderColorEnabled()
		return borderEnabled() and not getDefaultAuraUseOriginalBorderColor(kind)
	end
	local function durationEnabled() return getDefaultAuraDBValue(kind, "DurationEnabled") ~= false end
	local function countEnabled() return getDefaultAuraDBValue(kind, "CountEnabled") ~= false end
	local function iconDarkModeEnabled() return getDefaultAuraDBValue(kind, "IconDarkMode") == true end
	local function anchorOptions() return buildAuraAnchorOptions() end
	local function sortMethodOptions()
		return {
			{ value = "TIME", label = L["Time"] or "Time" },
			{ value = "INDEX", label = L["Index"] or "Index" },
			{ value = "NAME", label = _G.NAME or "Name" },
		}
	end
	local function sortDirectionOptions()
		return {
			{ value = "-", label = L["Descending"] or "Descending" },
			{ value = "+", label = L["Ascending"] or "Ascending" },
		}
	end

	local layoutSectionId = "default-aura-containers-layout"
	local borderSectionId = "default-aura-containers-border"
	local durationSectionId = "default-aura-containers-duration"
	local stackSectionId = "default-aura-containers-stacks"

	return {
		{ name = L["Layout"] or "Layout", kind = SettingType.Collapsible, id = layoutSectionId, defaultCollapsed = false },
		checkbox(L["Sync buff and debuff settings"] or "Sync buff and debuff settings", getDefaultAuraSyncEnabled, function(value) applyDefaultAuraEditModeSetting(kind, "sync", value) end, nil, layoutSectionId),
		dropdown(L["settingsIconShapeLabel"] or "Icon shape", function() return normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape")) end, function(value) applyDefaultAuraEditModeSetting(kind, "shape", value) end, shapeOptions, 180, nil, layoutSectionId),
		slider(L["Icon zoom"] or "Icon zoom", function() return normalizeAuraIconZoom(getDefaultAuraDBValue(kind, "IconZoom")) end, function(value) applyDefaultAuraEditModeSetting(kind, "zoom", value) end, 0, 35, 1, nil, layoutSectionId),
		checkbox(L["Icon dark mode"] or "Icon dark mode", function() return getDefaultAuraDBValue(kind, "IconDarkMode") == true end, function(value) applyDefaultAuraEditModeSetting(kind, "iconDarkMode", value) end, nil, layoutSectionId),
		slider(L["Icon darkness"] or "Icon darkness", function() return normalizeAuraIconDarkness(getDefaultAuraDBValue(kind, "IconDarkness")) end, function(value) applyDefaultAuraEditModeSetting(kind, "iconDarkness", value) end, 0, 100, 1, iconDarkModeEnabled, layoutSectionId),
		checkbox(L["Desaturate icon"] or "Desaturate icon", function() return getDefaultAuraDBValue(kind, "IconDesaturate") == true end, function(value) applyDefaultAuraEditModeSetting(kind, "iconDesaturate", value) end, iconDarkModeEnabled, layoutSectionId),
		slider(L["Icon size"] or "Icon size", function() return getDefaultAuraIconSize(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "size", value) end, 16, 80, 1, nil, layoutSectionId),
		slider(L["Horizontal spacing"] or "Horizontal spacing", function() return getDefaultAuraHorizontalSpacing(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "horizontalSpacing", value) end, 0, 100, 1, nil, layoutSectionId),
		slider(L["Vertical spacing"] or "Vertical spacing", function() return getDefaultAuraVerticalSpacing(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "verticalSpacing", value) end, 0, 100, 1, nil, layoutSectionId),
		checkbox(L["Draw cooldown swipe"] or "Draw cooldown swipe", function() return getDefaultAuraDrawSwipe(kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "drawSwipe", value) end, nil, layoutSectionId),
		slider(L["Aura per row"] or "Auras per row", function() return getDefaultAuraIconsPerRow(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "perRow", value) end, 1, 32, 1, nil, layoutSectionId),
		slider(L["Max rows"] or "Max rows", function() return getDefaultAuraMaxRows(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "maxRows", value) end, 1, 10, 1, nil, layoutSectionId),
		dropdown(L["Sort method"] or "Sort method", function() return normalizeDefaultAuraSortMethod(getDefaultAuraDBValue(kind, "SortMethod")) end, function(value) applyDefaultAuraEditModeSetting(kind, "sortMethod", value) end, sortMethodOptions, 120, nil, layoutSectionId),
		dropdown(L["Sort direction"] or "Sort direction", function() return normalizeDefaultAuraSortDirection(getDefaultAuraDBValue(kind, "SortDirection")) end, function(value) applyDefaultAuraEditModeSetting(kind, "sortDirection", value) end, sortDirectionOptions, 100, nil, layoutSectionId),
		checkbox(L["Include weapon enchants"] or "Include weapon enchants", function() return getDefaultAuraDBValue(kind, "IncludeWeapons") == true end, function(value) applyDefaultAuraEditModeSetting(kind, "includeWeapons", value) end, function() return kind == "buff" end, layoutSectionId),
		{ name = L["Border"] or "Border", kind = SettingType.Collapsible, id = borderSectionId, defaultCollapsed = true },
		dropdown(L["Aura border texture"] or "Aura border texture", function()
			local shape = normalizeAuraIconShape(getDefaultAuraDBValue(kind, "IconShape"))
			return normalizeAuraBorder(getDefaultAuraDBValue(kind, "BorderTexture"), shape)
		end, function(value) applyDefaultAuraEditModeSetting(kind, "border", value) end, borderOptions, 220, nil, borderSectionId),
		slider(L["Border Size"] or "Border Size", function() return getDefaultAuraBorderSize(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "borderSize", value) end, 1, 24, 1, borderEnabled, borderSectionId),
		slider(L["Border offset"] or "Border offset", function() return getDefaultAuraBorderOffset(nil, kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "borderOffset", value) end, -20, 100, 1, borderEnabled, borderSectionId),
		checkbox(L["Use original border color"] or "Use original border color", function() return getDefaultAuraUseOriginalBorderColor(kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "useOriginalBorderColor", value) end, borderEnabled, borderSectionId),
		{
			name = L["Border color"] or "Border color",
			kind = SettingType.Color,
			parentId = borderSectionId,
			hasOpacity = true,
			get = function()
				local color = getDefaultAuraDBValue(kind, "BorderColor") or DEFAULT_AURA_BORDER_COLOR
				return {
					r = color.r or DEFAULT_AURA_BORDER_COLOR.r,
					g = color.g or DEFAULT_AURA_BORDER_COLOR.g,
					b = color.b or DEFAULT_AURA_BORDER_COLOR.b,
					a = color.a ~= nil and color.a or DEFAULT_AURA_BORDER_COLOR.a,
				}
			end,
			set = function(_, value) applyDefaultAuraEditModeSetting(kind, "borderColor", value) end,
			isEnabled = borderColorEnabled,
		},
		{ name = L["Cooldown text"] or "Cooldown text", kind = SettingType.Collapsible, id = durationSectionId, defaultCollapsed = true },
		checkbox(L["Show cooldown text"] or "Show cooldown text", durationEnabled, function(value) applyDefaultAuraEditModeSetting(kind, "durationEnabled", value) end, nil, durationSectionId),
		dropdown(L["durationTextProfile"] or "Duration text profile", function() return getDefaultAuraDurationTextProfile(kind) end, function(value) applyDefaultAuraEditModeSetting(kind, "durationTextProfile", value) end, function()
			return addon.DurationText and addon.DurationText.GetProfileOptions and addon.DurationText:GetProfileOptions() or {}
		end, 180, durationEnabled, durationSectionId),
		dropdown(L["Font"] or "Font", function() return normalizeAuraFontKey(getDefaultAuraDBValue(kind, "DurationFontFace")) end, function(value) applyDefaultAuraEditModeSetting(kind, "durationFont", value) end, buildAuraFontOptions, 220, durationEnabled, durationSectionId),
		dropdown(L["Font outline"] or "Font outline", function() return normalizeAuraFontStyle(getDefaultAuraDBValue(kind, "DurationFontOutline")) end, function(value) applyDefaultAuraEditModeSetting(kind, "durationOutline", value) end, buildAuraFontStyleOptions, 220, durationEnabled, durationSectionId),
		slider(_G.FONT_SIZE or "Font size", function() return getAuraTextSize(nil, tonumber(getDefaultAuraDBValue(kind, "DurationFontSize")) or 10) end, function(value) applyDefaultAuraEditModeSetting(kind, "durationSize", value) end, 6, 64, 1, durationEnabled, durationSectionId),
		color(_G.COLOR or "Color", function() return normalizeAuraTextColor(getDefaultAuraDBValue(kind, "DurationColor"), DEFAULT_AURA_DURATION_COLOR) end, function(value) applyDefaultAuraEditModeSetting(kind, "durationColor", value) end, durationEnabled, durationSectionId),
		dropdown(L["Anchor point"] or "Anchor point", function() return normalizeAuraAnchorPoint(getDefaultAuraDBValue(kind, "DurationAnchor"), "BOTTOM") end, function(value) applyDefaultAuraEditModeSetting(kind, "durationAnchor", value) end, anchorOptions, 180, durationEnabled, durationSectionId),
		slider(L["X Offset"] or "X Offset", function()
			local offset = getDefaultAuraDBValue(kind, "DurationOffset")
			return getAuraTextOffset(nil, "x", type(offset) == "table" and offset.x or 0)
		end, function(value) applyDefaultAuraEditModeSetting(kind, "durationOffsetX", value) end, -100, 100, 1, durationEnabled, durationSectionId),
		slider(L["Y Offset"] or "Y Offset", function()
			local offset = getDefaultAuraDBValue(kind, "DurationOffset")
			return getAuraTextOffset(nil, "y", type(offset) == "table" and offset.y or -1)
		end, function(value) applyDefaultAuraEditModeSetting(kind, "durationOffsetY", value) end, -100, 100, 1, durationEnabled, durationSectionId),
		{ name = L["Stacks"] or "Stacks", kind = SettingType.Collapsible, id = stackSectionId, defaultCollapsed = true },
		checkbox(L["Show stacks"] or "Show stacks", countEnabled, function(value) applyDefaultAuraEditModeSetting(kind, "countEnabled", value) end, nil, stackSectionId),
		dropdown(L["Font"] or "Font", function() return normalizeAuraFontKey(getDefaultAuraDBValue(kind, "CountFontFace")) end, function(value) applyDefaultAuraEditModeSetting(kind, "countFont", value) end, buildAuraFontOptions, 220, countEnabled, stackSectionId),
		dropdown(L["Font outline"] or "Font outline", function() return normalizeAuraFontStyle(getDefaultAuraDBValue(kind, "CountFontOutline")) end, function(value) applyDefaultAuraEditModeSetting(kind, "countOutline", value) end, buildAuraFontStyleOptions, 220, countEnabled, stackSectionId),
		slider(_G.FONT_SIZE or "Font size", function() return getAuraTextSize(nil, tonumber(getDefaultAuraDBValue(kind, "CountFontSize")) or 12) end, function(value) applyDefaultAuraEditModeSetting(kind, "countSize", value) end, 6, 64, 1, countEnabled, stackSectionId),
		color(_G.COLOR or "Color", function() return normalizeAuraTextColor(getDefaultAuraDBValue(kind, "CountColor"), DEFAULT_AURA_COUNT_COLOR) end, function(value) applyDefaultAuraEditModeSetting(kind, "countColor", value) end, countEnabled, stackSectionId),
		dropdown(L["Anchor point"] or "Anchor point", function() return normalizeAuraAnchorPoint(getDefaultAuraDBValue(kind, "CountAnchor"), "TOPRIGHT") end, function(value) applyDefaultAuraEditModeSetting(kind, "countAnchor", value) end, anchorOptions, 180, countEnabled, stackSectionId),
		slider(L["X Offset"] or "X Offset", function()
			local offset = getDefaultAuraDBValue(kind, "CountOffset")
			return getAuraTextOffset(nil, "x", type(offset) == "table" and offset.x or -1)
		end, function(value) applyDefaultAuraEditModeSetting(kind, "countOffsetX", value) end, -100, 100, 1, countEnabled, stackSectionId),
		slider(L["Y Offset"] or "Y Offset", function()
			local offset = getDefaultAuraDBValue(kind, "CountOffset")
			return getAuraTextOffset(nil, "y", type(offset) == "table" and offset.y or 1)
		end, function(value) applyDefaultAuraEditModeSetting(kind, "countOffsetY", value) end, -100, 100, 1, countEnabled, stackSectionId),
	}
end

local function registerDefaultAuraHeaderEditMode(kind, header, anchor)
	if not (header and anchor) then return false end
	local EditMode = addon.EditMode
	if not (EditMode and EditMode.RegisterFrame and EditMode:IsAvailable()) then return false end

	local isBuff = kind == "buff"
	local id = isBuff and "DefaultAuraBuffContainer" or "DefaultAuraDebuffContainer"
	local flag = isBuff and "defaultBuffHeaderEditModeRegistered" or "defaultDebuffHeaderEditModeRegistered"
	if DAC.variables[flag] then
		attachDefaultAuraHeaderToAnchor(header, anchor)
		return true
	end

	attachDefaultAuraHeaderToAnchor(header, anchor)

	EditMode:RegisterFrame(id, {
		frame = anchor,
		title = isBuff and (L["Buff Frame"] or "Buff Frame") or (L["Debuff Frame"] or "Debuff Frame"),
		layoutDefaults = isBuff and { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -260, y = -120 } or { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -260, y = -220 },
		showOutsideEditMode = true,
		isEnabled = function()
			return addon.db and ((isBuff and addon.db.skinnerDefaultBuffIconsEnabled == true) or (not isBuff and addon.db.skinnerDefaultDebuffIconsEnabled == true))
		end,
		onApply = function()
			attachDefaultAuraHeaderToAnchor(header, anchor)
			updateDefaultAuraHeaderButtons(header)
		end,
		onPositionChanged = function()
			attachDefaultAuraHeaderToAnchor(header, anchor)
			updateDefaultAuraHeaderButtons(header)
		end,
		settings = createDefaultAuraEditModeSettings(kind),
		settingsMaxHeight = 700,
		collapseExclusive = true,
		showReset = false,
		showSettingsReset = false,
	})

	if EditMode.RegisterButtons then
		local otherKind = isBuff and "debuff" or "buff"
		EditMode:RegisterButtons(id, {
			{
				text = L["Toggle sample auras"] or "Toggle sample auras",
				layout = "compact",
				click = function() toggleDefaultAuraSamples(kind) end,
			},
			{
				text = isBuff and (L["Copy settings to debuffs"] or "Copy settings to debuffs") or (L["Copy settings to buffs"] or "Copy settings to buffs"),
				layout = "compact",
				click = function()
					copyDefaultAuraConfig(kind, otherKind)
					refreshDefaultAuraIconSkin()
				end,
			},
		})
	end

	DAC.variables[flag] = true
	attachDefaultAuraHeaderToAnchor(header, anchor)
	return true
end

local function updateBlizzardAuraFrameVisibility()
	if addon.db and addon.db.skinnerDefaultBuffIconsEnabled == true then hideBlizzardAuraFrame(_G.BuffFrame) end
	if addon.db and addon.db.skinnerDefaultDebuffIconsEnabled == true then hideBlizzardAuraFrame(_G.DebuffFrame) end
end

local function ensureDefaultAuraContainerHooks()
	if DAC.variables.defaultAuraContainerHooksInstalled then return end
	DAC.variables.defaultAuraContainerHooksInstalled = true
	if _G.BuffFrame and _G.BuffFrame.HookScript then _G.BuffFrame:HookScript("OnShow", updateBlizzardAuraFrameVisibility) end
	if _G.DebuffFrame and _G.DebuffFrame.HookScript then _G.DebuffFrame:HookScript("OnShow", updateBlizzardAuraFrameVisibility) end
end

function DAC.functions.RefreshDefaultAuraIconSkin()
	if InCombatLockdown and InCombatLockdown() then
		DAC.variables.pendingDefaultAuraCombat = true
		local watcher = ensureDefaultAuraWatcher()
		watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	if not isDefaultAuraIconSkinEnabled() then
		if DAC.variables.defaultBuffHeader then DAC.variables.defaultBuffHeader:Hide() end
		if DAC.variables.defaultDebuffHeader then DAC.variables.defaultDebuffHeader:Hide() end
		return
	end

	ensureDefaultAuraContainerHooks()

	if addon.db and addon.db.skinnerDefaultBuffIconsEnabled == true then
		local header = DAC.variables.defaultBuffHeader or createDefaultAuraHeader("buff", "HELPFUL")
		local anchor = ensureDefaultAuraAnchor("buff")
		DAC.variables.defaultBuffHeader = header
		configureDefaultAuraHeader(header, "HELPFUL", "buff")
		if not registerDefaultAuraHeaderEditMode("buff", header, anchor) then
			anchor:ClearAllPoints()
			anchor:SetPoint("TOPRIGHT", MinimapCluster or UIParent, "TOPLEFT", -8, -8)
			attachDefaultAuraHeaderToAnchor(header, anchor)
		end
		refreshDefaultAuraSamples("buff")
		anchor:Show()
		header:SetShown(not anchor.eqolDefaultAuraSamplesEnabled)
	else
		if DAC.variables.defaultBuffAnchor then DAC.variables.defaultBuffAnchor:Hide() end
		if DAC.variables.defaultBuffHeader then DAC.variables.defaultBuffHeader:Hide() end
	end

	if addon.db and addon.db.skinnerDefaultDebuffIconsEnabled == true then
		local header = DAC.variables.defaultDebuffHeader or createDefaultAuraHeader("debuff", "HARMFUL")
		local anchor = ensureDefaultAuraAnchor("debuff")
		DAC.variables.defaultDebuffHeader = header
		configureDefaultAuraHeader(header, "HARMFUL", "debuff")
		if not registerDefaultAuraHeaderEditMode("debuff", header, anchor) then
			anchor:ClearAllPoints()
			anchor:SetPoint("TOPRIGHT", DAC.variables.defaultBuffAnchor or MinimapCluster or UIParent, "BOTTOMRIGHT", 0, -20)
			attachDefaultAuraHeaderToAnchor(header, anchor)
		end
		refreshDefaultAuraSamples("debuff")
		anchor:Show()
		header:SetShown(not anchor.eqolDefaultAuraSamplesEnabled)
	else
		if DAC.variables.defaultDebuffAnchor then DAC.variables.defaultDebuffAnchor:Hide() end
		if DAC.variables.defaultDebuffHeader then DAC.variables.defaultDebuffHeader:Hide() end
	end

	updateBlizzardAuraFrameVisibility()
end

refreshDefaultAuraIconSkin = function()
	if DAC.functions.RefreshDefaultAuraIconSkin then DAC.functions.RefreshDefaultAuraIconSkin() end
end

local function migrateDefaultAuraTextAnchor(prefix)
	if not addon.db then return end
	local durationAnchorKey = prefix .. "DurationAnchor"
	local durationRelativeKey = prefix .. "DurationRelativePoint"
	local countAnchorKey = prefix .. "CountAnchor"
	local countOffsetKey = prefix .. "CountOffset"
	if addon.db[durationAnchorKey] == "TOP" and addon.db[durationRelativeKey] == "BOTTOM" then
		addon.db[durationAnchorKey] = "BOTTOM"
	end
	local countOffset = addon.db[countOffsetKey]
	if addon.db[countAnchorKey] == "BOTTOMRIGHT" and type(countOffset) == "table" and (tonumber(countOffset.x) or -1) == -1 and (tonumber(countOffset.y) or 1) == 1 then
		addon.db[countAnchorKey] = "TOPRIGHT"
		addon.db[countOffsetKey] = { x = -1, y = -1 }
	end
	addon.db[durationRelativeKey] = nil
	addon.db[prefix .. "CountRelativePoint"] = nil
end

function DAC.functions.InitDB()
	if not (addon.functions and addon.functions.InitDBValue) then return end
	local init = addon.functions.InitDBValue
	init("skinnerDefaultBuffIconsEnabled", false)
	init("skinnerDefaultDebuffIconsEnabled", false)
	init("skinnerDefaultAuraSyncBuffDebuff", true)
	init("skinnerDefaultAuraIconShape", "DEFAULT")
	init("skinnerDefaultAuraIconSize", 32)
	init("skinnerDefaultAuraIconSpacing", 4)
	init("skinnerDefaultAuraHorizontalSpacing", getDefaultAuraIconSpacing())
	init("skinnerDefaultAuraVerticalSpacing", getDefaultAuraIconSpacing() + 12)
	init("skinnerDefaultAuraIconsPerRow", 8)
	init("skinnerDefaultAuraMaxRows", 4)
	init("skinnerDefaultAuraSortMethod", "TIME")
	init("skinnerDefaultAuraSortDirection", "-")
	init("skinnerDefaultAuraIncludeWeapons", true)
	init("skinnerDefaultAuraIconZoom", 0)
	init("skinnerDefaultAuraIconDarkMode", false)
	init("skinnerDefaultAuraIconDarkness", 35)
	init("skinnerDefaultAuraIconDesaturate", true)
	init("skinnerDefaultAuraCooldownDrawSwipe", true)
	init("skinnerDefaultAuraBorderTexture", addon.IconShape and addon.IconShape.BORDER and addon.IconShape.BORDER.NONE or "NONE")
	init("skinnerDefaultAuraBorderSize", 1)
	init("skinnerDefaultAuraBorderOffset", 0)
	init("skinnerDefaultAuraUseOriginalBorderColor", false)
	init("skinnerDefaultAuraBorderColor", {
		r = DEFAULT_AURA_BORDER_COLOR.r,
		g = DEFAULT_AURA_BORDER_COLOR.g,
		b = DEFAULT_AURA_BORDER_COLOR.b,
		a = DEFAULT_AURA_BORDER_COLOR.a,
	})
	init("skinnerDefaultAuraDurationEnabled", true)
	init("skinnerDefaultAuraDurationFontFace", getGlobalFontKey())
	init("skinnerDefaultAuraDurationFontOutline", getGlobalStyleKey())
	init("skinnerDefaultAuraDurationFontSize", 10)
	init("skinnerDefaultAuraDurationColor", {
		r = DEFAULT_AURA_DURATION_COLOR.r,
		g = DEFAULT_AURA_DURATION_COLOR.g,
		b = DEFAULT_AURA_DURATION_COLOR.b,
		a = DEFAULT_AURA_DURATION_COLOR.a,
	})
	init("skinnerDefaultAuraDurationAnchor", "BOTTOM")
	init("skinnerDefaultAuraDurationOffset", { x = 0, y = -1 })
	init("skinnerDefaultAuraDurationTextProfile", "MINIMAL")
	init("skinnerDefaultAuraCountEnabled", true)
	init("skinnerDefaultAuraCountFontFace", getGlobalFontKey())
	init("skinnerDefaultAuraCountFontOutline", getGlobalStyleKey())
	init("skinnerDefaultAuraCountFontSize", 12)
	init("skinnerDefaultAuraCountColor", {
		r = DEFAULT_AURA_COUNT_COLOR.r,
		g = DEFAULT_AURA_COUNT_COLOR.g,
		b = DEFAULT_AURA_COUNT_COLOR.b,
		a = DEFAULT_AURA_COUNT_COLOR.a,
	})
	init("skinnerDefaultAuraCountAnchor", "TOPRIGHT")
	init("skinnerDefaultAuraCountOffset", { x = -1, y = -1 })
	migrateDefaultAuraTextAnchor(DEFAULT_AURA_DB_PREFIX)
	migrateDefaultAuraTextAnchor(DEFAULT_DEBUFF_AURA_DB_PREFIX)
	if isDefaultAuraIconSkinEnabled() then refreshDefaultAuraIconSkin() end
end

local function ensureDefaultAuraContainersSuiteSection(category)
	local expandable = addon.SettingsLayout and addon.SettingsLayout.suitesDefaultAuraContainersSection
	if expandable then return expandable end
	if not (addon.functions and addon.functions.SettingsCreateExpandableSection) then return nil end
	expandable = addon.functions.SettingsCreateExpandableSection(category, {
		name = L["skinnerDefaultAuraIconsSection"],
		configPageKey = "DefaultAuraContainers",
		description = L["skinnerDefaultAuraIconsSectionDesc"],
		iconKey = "buff",
		modernCategory = "suites",
		modernOnly = true,
		expanded = false,
		colorizeTitle = false,
	})
	addon.SettingsLayout.suitesDefaultAuraContainersSection = expandable
	return expandable
end

function DAC.functions.InitSettings()
	if DAC.variables.settingsBuilt then return end
	if not addon.SettingsLayout or not addon.SettingsLayout.rootUI then return end
	if not addon.functions or not addon.functions.SettingsCreateExpandableSection then return end

	local category = addon.SettingsLayout.rootUI
	local expandable = ensureDefaultAuraContainersSuiteSection(category)
	if not expandable then return end
	DAC.variables.settingsBuilt = true

	addon.functions.SettingsCreateHeadline(category, L["skinnerDefaultAuraIconsSection"], { parentSection = expandable })

	addon.functions.SettingsCreateCheckbox(category, {
		var = "skinnerDefaultBuffIconsEnabled",
		text = L["skinnerDefaultBuffIconsEnabled"],
		default = false,
		func = function(value)
			local wasEnabled = addon.db["skinnerDefaultBuffIconsEnabled"] == true
			addon.db["skinnerDefaultBuffIconsEnabled"] = value == true
			if wasEnabled and value ~= true then markDefaultAuraReloadRequired() end
			refreshDefaultAuraIconSkin()
		end,
		parentSection = expandable,
	})

	addon.functions.SettingsCreateCheckbox(category, {
		var = "skinnerDefaultDebuffIconsEnabled",
		text = L["skinnerDefaultDebuffIconsEnabled"],
		default = false,
		func = function(value)
			local wasEnabled = addon.db["skinnerDefaultDebuffIconsEnabled"] == true
			addon.db["skinnerDefaultDebuffIconsEnabled"] = value == true
			if wasEnabled and value ~= true then markDefaultAuraReloadRequired() end
			refreshDefaultAuraIconSkin()
		end,
		parentSection = expandable,
	})

	if isDefaultAuraIconSkinEnabled() then refreshDefaultAuraIconSkin() end
end
