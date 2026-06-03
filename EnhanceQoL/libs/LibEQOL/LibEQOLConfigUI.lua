local MODULE_MAJOR, MINOR = "LibEQOLConfigUI-1.0", 2
local LibStub = _G.LibStub
assert(LibStub, MODULE_MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MODULE_MAJOR, MINOR)
if not lib then
	return
end
lib.MINOR = MINOR

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local C_Texture = _G.C_Texture
local MenuUtil = _G.MenuUtil
local ColorPickerFrame = _G.ColorPickerFrame
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show

local WINDOW_WIDTH = 1080
local WINDOW_HEIGHT = 700
local SIDEBAR_WIDTH = 236
local CONTENT_WIDTH = 790
local PAGE_RIGHT_WIDTH = 248
local PAGE_RIGHT_WIDTH_MIN = 190
local PAGE_LEFT_WIDTH_MIN = 560
local PAGE_LEFT_WIDTH_IDEAL = 620
local PAGE_GAP = 16
local GRID_GAP = 12
local BOOLEAN_ROW_HEIGHT = 68
local STACKED_ROW_HEIGHT = 106
local COMPLEX_ROW_HEIGHT = 92
local ROW_INSET = 14
local FIELD_CONTROL_LEFT = 18
local FIELD_CONTROL_WIDTH_MIN = 260
local FIELD_CONTROL_WIDTH_MAX = 340

local FONT_TITLE = "GameFontNormalLarge"
local FONT_HERO = "GameFontNormalHuge2"
local FONT_HEADER = "GameFontNormal"
local FONT_TEXT = "GameFontHighlight"
local FONT_MUTED = "GameFontDisableSmall"

local DEFAULT_DASHBOARD_INTRO = "Welcome! EnhanceQoL improves your World of Warcraft experience "
	.. "with quality of life features and customization options."

local PANEL_BG = { 0.055, 0.049, 0.043, 0.94 }
local PANEL_BORDER = { 0.43, 0.34, 0.19, 0.74 }
local TOPBAR_BG = { 0.105, 0.095, 0.078, 0.97 }
local CONTENT_BG = { 0.035, 0.033, 0.031, 0.88 }
local CARD_BG = { 0.080, 0.073, 0.061, 0.92 }
local CARD_BG_HOVER = { 0.125, 0.101, 0.062, 0.98 }
local CARD_BORDER = { 0.46, 0.36, 0.20, 0.62 }
local CARD_BORDER_HOVER = { 0.94, 0.67, 0.25, 0.90 }
local DASHBOARD_CARD_BG = { 0.145, 0.145, 0.132, 0.96 }
local DASHBOARD_CARD_BG_HOVER = { 0.178, 0.170, 0.142, 0.99 }
local DASHBOARD_CARD_BORDER = { 0.43, 0.40, 0.32, 0.88 }
local DETAIL_SECTION_BG = { 0.065, 0.058, 0.047, 0.94 }
local ROW_BG = { 0.000, 0.000, 0.000, 0.00 }
local ROW_BORDER = { 0.000, 0.000, 0.000, 0.00 }
local ROW_HOVER_BG = { 0.120, 0.097, 0.055, 0.38 }
local ROW_HOVER_BORDER = { 0.76, 0.55, 0.22, 0.54 }
local ROW_SEPARATOR = { 0.50, 0.40, 0.24, 0.30 }
local SELECTED_BG = { 0.24, 0.17, 0.065, 0.96 }
local SIDEBAR_BG = { 0.030, 0.031, 0.030, 0.78 }
local MUTED = { 0.67, 0.64, 0.58 }
local WHITE = { 0.94, 0.91, 0.84 }
local GOLD = { 1.0, 0.82, 0.36 }
local TOPBAR_GOLD = { 1.0, 0.84, 0.36 }
local GREEN = { 0.36, 0.82, 0.36 }

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local ADDON_ICON = "Interface\\AddOns\\EnhanceQoL\\Icons\\Icon.tga"
local SETTINGS_COG_ICON = "Interface\\AddOns\\EnhanceQoL\\Assets\\NewSettings\\Cogwheel.tga"
local SETTINGS_EXPORT_IMPORT_ICON = "Interface\\AddOns\\EnhanceQoL\\Assets\\NewSettings\\ExportImport.tga"
local SETTINGS_QUESTION_ICON = "Interface\\AddOns\\EnhanceQoL\\Assets\\NewSettings\\Question.tga"
local SETTINGS_QUICK_REFERENCE_ICON = "Interface\\AddOns\\EnhanceQoL\\Assets\\NewSettings\\QuickReference.tga"
local SETTINGS_REVERT_ICON = "Interface\\AddOns\\EnhanceQoL\\Assets\\NewSettings\\Revert.tga"
local STATUS_ENABLED_ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local STATUS_PROFILE_ICON = "Interface\\Icons\\INV_Misc_GroupNeedMore"
local STATUS_VERSION_ATLAS = "worldquest-tracker-questmarker"
local STATUS_NEW_ATLAS = "collections-icon-favorites"
local ICON_TEXTURES = {
	actionbar = "Interface\\Icons\\INV_Sword_04",
	actiontracker = "Interface\\Icons\\Ability_Hunter_MarkedForDeath",
	advanced = "Interface\\Icons\\INV_Misc_Gear_01",
	bags = "Interface\\Icons\\INV_Misc_Bag_08",
	bars = "Interface\\Icons\\INV_Misc_Desecrated_PlateBelt",
	buff = "Interface\\Icons\\Spell_Holy_BlessingOfKings",
	castbar = "Interface\\Icons\\Spell_Nature_TimeStop",
	chat = "Interface\\Icons\\INV_Letter_15",
	combat = "Interface\\Icons\\Ability_Warrior_BattleShout",
	data = "Interface\\Icons\\INV_Misc_Note_05",
	diagnostics = "Interface\\Icons\\INV_Gizmo_02",
	cooldown = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	dashboard = SETTINGS_COG_ICON,
	economy = "Interface\\Icons\\INV_Misc_Coin_01",
	gameplay = "Interface\\Icons\\Ability_DualWield",
	general = "Interface\\Icons\\Trade_BlackSmithing",
	help = SETTINGS_QUICK_REFERENCE_ICON,
	interface = "Interface\\Icons\\INV_Misc_Monitor_01",
	map = "Interface\\Icons\\INV_Misc_Map_01",
	mover = "Interface\\Icons\\Ability_Hunter_MasterMarksman",
	nameplate = "Interface\\Icons\\INV_Misc_Tournaments_banner_Human",
	popups = "Interface\\Icons\\INV_Misc_Note_01",
	profiles = SETTINGS_EXPORT_IMPORT_ICON,
	reset = SETTINGS_REVERT_ICON,
	resource = "Interface\\Icons\\INV_Misc_Food_100",
	skinner = "Interface\\Icons\\INV_Misc_EngGizmos_17",
	social = "Interface\\Icons\\INV_Misc_GroupLooking",
	sound = "Interface\\Icons\\INV_Misc_Note_01",
	support = SETTINGS_QUESTION_ICON,
	tooltip = "Interface\\Icons\\INV_Misc_Note_03",
	unitframes = "Interface\\Icons\\INV_Misc_GroupLooking",
	vendor = "Interface\\Icons\\INV_Misc_Coin_02",
}

local CATEGORY_ICON_KEYS = {
	advanced = "advanced",
	dashboard = "dashboard",
	economy = "economy",
	gameplay = "gameplay",
	general = "general",
	interface = "interface",
	profiles = "profiles",
	social = "social",
	sound = "sound",
}

local CATEGORY_ICON_ATLASES = {
	gameplay = "icons_64x64_damage",
}

local PAGE_ICON_KEYS = {
	actiontracker = "actiontracker",
	actionbars = "actionbar",
	action = "actionbar",
	bags = "bags",
	buff = "buff",
	castbar = "castbar",
	castbars = "castbar",
	chat = "chat",
	combat = "combat",
	cooldown = "cooldown",
	cooldowns = "cooldown",
	data = "data",
	diagnostic = "diagnostics",
	loot = "bags",
	map = "map",
	minimap = "map",
	mover = "mover",
	nameplates = "nameplate",
	nameplate = "nameplate",
	popup = "popups",
	profile = "profiles",
	resource = "resource",
	skinner = "skinner",
	tooltips = "tooltip",
	tooltip = "tooltip",
	unitframes = "unitframes",
	unit = "unitframes",
	ui = "interface",
	vendor = "vendor",
	sell = "vendor",
}

local PAGE_DESCRIPTION_FALLBACKS = {
	actionbars = "Adjust action bar visibility, size, text and button behavior.",
	actiontracker = "Track important actions, cooldowns and combat state.",
	bars = "Customize resource bars, class bars and status displays.",
	castbars = "Configure cast bars, cooldown displays and timing helpers.",
	chat = "Improve chat history, whispers and message handling.",
	classbuff = "Track missing buffs and class-specific reminders.",
	combat = "Show important combat warnings and reminders.",
	cooldownpanels = "Manage cooldown panels, layout and visibility.",
	data = "Customize compact data and information panels.",
	death = "Customize death, resurrection and release helpers.",
	dungeons = "Configure dungeon, Mythic+ and teleport helpers.",
	groupfinder = "Improve group finder and group workflow helpers.",
	includelists = "Manage items that should always or never be handled.",
	loot = "Configure loot, item handling and inventory helpers.",
	map = "Configure map, minimap and navigation helpers.",
	minimap = "Configure map, minimap and navigation helpers.",
	mover = "Move and position supported UI elements.",
	nameplates = "Adjust nameplates, names and related display options.",
	popups = "Tweak dialogs, popups and small UI behaviors.",
	questing = "Automate quest handling and cinematic convenience options.",
	skinner = "Customize the appearance of supported Blizzard UI frames.",
	standaloneprivateaura = "Configure standalone private aura display.",
	tooltips = "Customize tooltip content, IDs, icons and extra information.",
	tooltip = "Customize tooltip content, IDs, icons and extra information.",
	unitframes = "Adjust player, target and party frame options.",
	vendor = "Add convenient vendor and merchant shortcuts.",
	autosell = "Automatically sell configured items and junk at vendors.",
}

local frames = lib.frames or {}
lib.frames = frames

local BASIC_FRAME_BORDER_REGIONS = {
	"TopBorder",
	"BottomBorder",
	"LeftBorder",
	"RightBorder",
	"TopLeftCorner",
	"TopRightCorner",
	"BotLeftCorner",
	"BotRightCorner",
	"InsetBorderTop",
	"InsetBorderBottom",
	"InsetBorderLeft",
	"InsetBorderRight",
	"InsetBorderTopLeft",
	"InsetBorderTopRight",
	"InsetBorderBottomLeft",
	"InsetBorderBottomRight",
}

local function setBasicFrameBorderAlpha(frame, alpha)
	for _, key in ipairs(BASIC_FRAME_BORDER_REGIONS) do
		local region = frame[key]
		if region and region.SetAlpha then
			region:SetAlpha(alpha)
		end
	end
end

local function applyBackdrop(frame, bg, border)
	if not frame.SetBackdrop then
		if frame.Bg and frame.Bg.SetColorTexture then
			frame.Bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
		end
		if frame.InsetBg and frame.InsetBg.SetColorTexture then
			frame.InsetBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
		end
		for _, key in ipairs(BASIC_FRAME_BORDER_REGIONS) do
			local region = frame[key]
			if region and region.SetVertexColor then
				region:SetVertexColor(border[1], border[2], border[3], border[4])
			end
		end
		return
	end
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
	frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function applyWindowBorder(frame)
	if not frame or frame.WindowBorder then
		return
	end
	local atlas = "AdventureMap-InsetMapBorder"
	if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then
		return
	end
	local border = frame:CreateTexture(nil, "BORDER", nil, 1)
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -22, 22)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 22, -22)
	local ok = border.SetAtlas and pcall(border.SetAtlas, border, atlas, false)
	if not ok then
		border:Hide()
		return
	end
	frame.WindowBorder = border
	setBasicFrameBorderAlpha(frame, 0)
end

local function setBackdropColor(frame, color)
	frame:SetBackdropColor(color[1], color[2], color[3], color[4])
end

local function setBackdropBorderColor(frame, color)
	if frame and frame.SetBackdropBorderColor then
		frame:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local function setFrameBackdrop(frame, bg, border)
	setBackdropColor(frame, bg)
	setBackdropBorderColor(frame, border)
end

local function setTextColor(fontString, color)
	if fontString and color then
		fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local function applyHoverState(frame, normalBg, hoverBg, normalBorder, hoverBorder)
	frame:SetScript("OnEnter", function(self)
		setFrameBackdrop(self, hoverBg or CARD_BG_HOVER, hoverBorder or CARD_BORDER_HOVER)
	end)
	frame:SetScript("OnLeave", function(self)
		setFrameBackdrop(self, normalBg or CARD_BG, normalBorder or CARD_BORDER)
	end)
end

local getControlType

local function styleInlineSettingRow(row)
	applyBackdrop(row, ROW_BG, ROW_BORDER)
	row:EnableMouse(true)
	row:SetScript("OnEnter", function(self)
		setFrameBackdrop(self, ROW_HOVER_BG, ROW_HOVER_BORDER)
	end)
	row:SetScript("OnLeave", function(self)
		setFrameBackdrop(self, ROW_BG, ROW_BORDER)
	end)
	row.Separator = row:CreateTexture(nil, "BACKGROUND")
	row.Separator:SetColorTexture(ROW_SEPARATOR[1], ROW_SEPARATOR[2], ROW_SEPARATOR[3], ROW_SEPARATOR[4])
	row.Separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", ROW_INSET, 0)
	row.Separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -ROW_INSET, 0)
	row.Separator:SetHeight(1)
end

local function getControlLayoutType(control)
	local controlType = getControlType(control)
	if controlType == "toggle" or controlType == "checkbox" then
		return "boolean"
	end
	if controlType == "slider" or controlType == "dropdown" or controlType == "sounddropdown"
		or controlType == "input" or controlType == "colorpicker" then
		return "stacked"
	end
	return "complex"
end

local function getSettingRowHeight(control)
	local layoutType = getControlLayoutType(control)
	if layoutType == "boolean" then
		return BOOLEAN_ROW_HEIGHT
	end
	if layoutType == "stacked" then
		return STACKED_ROW_HEIGHT
	end
	return COMPLEX_ROW_HEIGHT
end

local function getFieldControlWidth(rowWidth)
	return math.max(FIELD_CONTROL_WIDTH_MIN, math.min(FIELD_CONTROL_WIDTH_MAX, (tonumber(rowWidth) or 0) - 36))
end

local function getAddonIcon(app)
	return app and app.opts and app.opts.icon or SETTINGS_COG_ICON
end

local function normalizeIconLookupText(text)
	text = tostring(text or ""):lower()
	return text:gsub("[^%w]+", "")
end

local function getKeywordIconKey(text)
	text = tostring(text or ""):lower()
	for keyword, iconKey in pairs(PAGE_ICON_KEYS) do
		if text:find(keyword, 1, true) then
			return iconKey
		end
	end
	return nil
end

local function resolveCategoryIcon(category)
	if category and category.icon then
		return category.icon
	end
	if category and category.iconAtlas then
		return category.iconAtlas, true
	end
	if category and CATEGORY_ICON_ATLASES[category.id] then
		return CATEGORY_ICON_ATLASES[category.id], true
	end
	local iconKey = category and CATEGORY_ICON_KEYS[category.id]
	return ICON_TEXTURES[iconKey or "advanced"] or FALLBACK_ICON
end

local function resolveProfilePageIcon(page)
	if not page or page.category ~= "profiles" then
		return nil
	end

	local lookup = normalizeIconLookupText((page.id or "") .. " " .. (page.title or "") .. " " .. (page.newTagID or ""))
	if lookup:find("damagemeter", 1, true) then
		return "icons_64x64_damage", true
	end
	if lookup:find("healerbuffplacement", 1, true)
		or lookup:find("profileshbp", 1, true)
		or lookup:find("hbp", 1, true) then
		return "UI-LFG-RoleIcon-Healer", true
	end
	if lookup:find("settings", 1, true) then
		return "GM-icon-settings-pressed", true
	end
	if lookup:find("addon", 1, true) then
		return ADDON_ICON
	end

	return nil
end

local function resolvePageIcon(page)
	if page and page.icon then
		return page.icon
	end
	if page and page.iconAtlas then
		return page.iconAtlas, true
	end
	local profileIcon, isProfileAtlas = resolveProfilePageIcon(page)
	if profileIcon then
		return profileIcon, isProfileAtlas
	end
	local iconKey = getKeywordIconKey((page and page.id or "") .. " " .. (page and page.title or ""))
	return ICON_TEXTURES[iconKey or "advanced"] or FALLBACK_ICON
end

local function createIcon(parent, source, size, isAtlas)
	local icon = parent:CreateTexture(nil, "OVERLAY")
	icon:SetSize(size or 24, size or 24)
	if isAtlas and source and icon.SetAtlas then
		local hasAtlas = type(source) == "string"
			and (not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(source))
		local ok = hasAtlas and pcall(icon.SetAtlas, icon, source, false)
		if ok then
			return icon
		end
		source = FALLBACK_ICON
	end
	icon:SetTexture(source or FALLBACK_ICON)
	return icon
end

local function createIconPlate(parent, source, size, isAtlas)
	local plate = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	plate:SetSize(size or 42, size or 42)
	applyBackdrop(plate, { 0.015, 0.015, 0.018, 0.80 }, { 0.55, 0.42, 0.18, 0.75 })
	plate.Icon = createIcon(plate, source, (size or 42) - 12, isAtlas)
	plate.Icon:SetPoint("CENTER")
	return plate
end

local function clearFrameList(list)
	for _, frame in ipairs(list) do
		frame:Hide()
		frame:SetParent(nil)
	end
	for i = #list, 1, -1 do
		list[i] = nil
	end
end

local function trackFrame(list, frame)
	list[#list + 1] = frame
	return frame
end

local function createText(parent, template, text, color, justify)
	local textFrame = CreateFrame("Frame", nil, parent)
	textFrame.Text = textFrame:CreateFontString(nil, "OVERLAY", template or FONT_TEXT)
	textFrame.Text:SetAllPoints(textFrame)
	textFrame.Text:SetJustifyH(justify or "LEFT")
	textFrame.Text:SetJustifyV("TOP")
	textFrame.Text:SetWordWrap(true)
	textFrame.Text:SetText(text or "")
	setTextColor(textFrame.Text, color)
	return textFrame
end

local function createContentFrame(state, height)
	local frame = trackFrame(state.contentFrames, CreateFrame("Frame", nil, state.content, "BackdropTemplate"))
	frame:SetPoint("TOPLEFT", state.content, "TOPLEFT", 0, state.y)
	frame:SetPoint("TOPRIGHT", state.content, "TOPRIGHT", 0, state.y)
	frame:SetHeight(height)
	state.y = state.y - height
	return frame
end

local function createSidebarFrame(state, height)
	local frame = trackFrame(state.sidebarFrames, CreateFrame("Button", nil, state.frame.Sidebar, "BackdropTemplate"))
	frame:SetPoint("TOPLEFT", state.frame.Sidebar, "TOPLEFT", 0, state.sidebarY)
	frame:SetPoint("TOPRIGHT", state.frame.Sidebar, "TOPRIGHT", 0, state.sidebarY)
	frame:SetHeight(height)
	state.sidebarY = state.sidebarY - height
	return frame
end

local function getLocale(app)
	return app and app.opts and app.opts.locale or {}
end

local function getSettingCountText(app, count)
	local L = getLocale(app)
	local label = count == 1 and (L["configCenterSetting"] or "setting") or (L["configCenterSettings"] or "settings")
	return tostring(count) .. " " .. label
end

local function getAppTitle(app)
	return (app and app.opts and app.opts.title) or (app and app.id) or "Settings"
end

local function getPagePath(app, page)
	local category = page and app.categoriesByID[page.category or ""]
	if category and page then
		return (category.title or category.id) .. " > " .. (page.title or page.id)
	end
	return page and (page.title or page.id) or ""
end

local function getControlPath(app, control)
	return getPagePath(app, app:GetPage(control.pageID))
end

local function normalizePageLookupText(page)
	return tostring((page and page.id or "") .. " " .. (page and page.title or "")):lower():gsub("[^%w]+", "")
end

local function getPageDescription(app, page)
	if page and page.description and page.description ~= "" then
		return page.description
	end
	local lookup = normalizePageLookupText(page)
	for keyword, description in pairs(PAGE_DESCRIPTION_FALLBACKS) do
		if lookup:find(keyword, 1, true) then
			return description
		end
	end
	if page then
		return getSettingCountText(app, #(page.controls or {}))
	end
	return ""
end

function getControlType(control)
	local controlType = tostring(control and (control.type or control.sType) or "text"):lower()
	if controlType == "checkbox" then
		return "toggle"
	elseif controlType == "scrolldropdown" then
		return "dropdown"
	end
	return controlType
end

local function getControlTypeLabel(app, control)
	local L = getLocale(app)
	local controlType = getControlType(control)
	if controlType == "toggle" then
		return _G.ENABLE or "Toggle"
	elseif controlType == "slider" then
		return L["configCenterControlSlider"] or "Slider"
	elseif controlType == "dropdown" or controlType == "sounddropdown" then
		return L["configCenterControlDropdown"] or "Dropdown"
	elseif controlType == "input" then
		return _G.EDIT or "Input"
	elseif controlType == "button" then
		return _G.ACTION or "Action"
	elseif controlType == "colorpicker" then
		return _G.COLOR or "Color"
	end
	return _G.SETTINGS or "Settings"
end

local function callFormatter(formatter, value, control)
	if type(formatter) ~= "function" then
		return nil
	end
	local ok, text = pcall(formatter, value, control)
	if ok and text ~= nil then
		return tostring(text)
	end
	ok, text = pcall(formatter, value)
	if ok and text ~= nil then
		return tostring(text)
	end
	return nil
end

local function formatControlValue(control, value)
	local text = callFormatter(control.valueFormatter or control.formatter, value, control)
	if not text then
		if type(value) == "number" then
			text = string.format("%.2f", value):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
		elseif type(value) == "boolean" then
			text = value and (_G.ENABLED or "Enabled") or (_G.DISABLED or "Disabled")
		elseif value ~= nil then
			text = tostring(value)
		else
			text = ""
		end
	end
	if control.suffix and text ~= "" then
		text = text .. tostring(control.suffix)
	end
	return text
end

local function getOptionLabel(option, key)
	if type(option) == "table" then
		return option.text or option.label or option.name or option.title or option[2] or option.value or option.key or key
	end
	return option
end

local function getOptionValue(option, key)
	if type(option) == "table" then
		local value = option.value
		if value == nil then value = option.key end
		if value == nil then value = option[1] end
		if value ~= nil then return value end
	end
	return key
end

local function getControlOptions(control)
	local list = control.values or control.options or control.list
	local optionfunc = control.optionfunc or control.listFunc
	if type(optionfunc) == "function" then
		local ok, result = pcall(optionfunc)
		if ok and type(result) == "table" then
			list = result
		end
	end
	local options = {}
	local order = type(control.orderList) == "table" and control.orderList
		or type(control.order) == "table" and control.order
	local seen
	if type(list) ~= "table" then
		return options
	end
	if order then
		seen = {}
		for _, key in ipairs(order) do
			if key ~= "_order" and list[key] ~= nil then
				local option = list[key]
				options[#options + 1] = {
					value = getOptionValue(option, key),
					label = tostring(getOptionLabel(option, key) or key),
				}
				seen[key] = true
			end
		end
	end
	for key, option in pairs(list) do
		if key ~= "_order" and (not seen or not seen[key]) then
			options[#options + 1] = {
				value = getOptionValue(option, key),
				label = tostring(getOptionLabel(option, key) or key),
			}
		end
	end
	if not order then
		table.sort(options, function(a, b)
			return tostring(a.label) < tostring(b.label)
		end)
	end
	return options
end

local function getDropdownValueText(control, value)
	for _, option in ipairs(getControlOptions(control)) do
		if tostring(option.value) == tostring(value) then
			return option.label
		end
	end
	return formatControlValue(control, value)
end

local function openLegacySettingsForControl(app, control)
	if app.opts and type(app.opts.openLegacySettings) == "function" then
		app.opts.openLegacySettings(control)
	end
end

local function makeFlatButton(parent, text, width, height, iconSource, iconIsAtlas)
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(width or 120, height or 26)
	applyBackdrop(button, { 0.07, 0.065, 0.055, 0.92 }, CARD_BORDER)
	local leftInset = 10
	if iconSource then
		button.Icon = createIcon(button, iconSource, math.min((height or 26) - 8, 18), iconIsAtlas)
		button.Icon:SetPoint("LEFT", button, "LEFT", 8, 0)
		leftInset = 30
	end
	button.Text = button:CreateFontString(nil, "OVERLAY", FONT_TEXT)
	button.Text:SetPoint("LEFT", button, "LEFT", leftInset, 0)
	button.Text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
	button.Text:SetJustifyH("CENTER")
	button.Text:SetText(text or "")
	setTextColor(button.Text, WHITE)
	button:SetScript("OnEnter", function(self) setFrameBackdrop(self, CARD_BG_HOVER, CARD_BORDER_HOVER) end)
	button:SetScript("OnLeave", function(self)
		if self.selected then
			setFrameBackdrop(self, SELECTED_BG, CARD_BORDER_HOVER)
		else
			setFrameBackdrop(self, { 0.07, 0.065, 0.055, 0.92 }, CARD_BORDER)
		end
	end)
	return button
end

local function refreshControlRow(app, control, row)
	local enabled = app:IsControlEnabled(control)
	row:SetAlpha(enabled and 1 or 0.48)
	if row.check then
		if row.check.SetEnabled then
			row.check:SetEnabled(enabled)
		elseif enabled and row.check.Enable then
			row.check:Enable()
		elseif row.check.Disable then
			row.check:Disable()
		end
		if row.check.SetChecked then
			row.check:SetChecked(app:GetControlValue(control) == true)
		end
	end
	if row.slider then
		local value = tonumber(app:GetControlValue(control)) or tonumber(control.default) or tonumber(control.min) or 0
		if row.slider.SetEnabled then
			row.slider:SetEnabled(enabled)
		elseif enabled and row.slider.Enable then
			row.slider:Enable()
		elseif row.slider.Disable then
			row.slider:Disable()
		end
		row.slider.updating = true
		row.slider:SetValue(value)
		row.slider.updating = false
	end
	if row.editBox then
		local editEnabled = enabled and not control.readOnly
		if row.editBox.SetEnabled then
			row.editBox:SetEnabled(editEnabled)
		elseif editEnabled and row.editBox.Enable then
			row.editBox:Enable()
		elseif row.editBox.Disable then
			row.editBox:Disable()
		end
		row.editBox:SetText(formatControlValue(control, app:GetControlValue(control)))
	end
	if row.value then
		local value = app:GetControlValue(control)
		if getControlType(control) == "dropdown" or getControlType(control) == "sounddropdown" then
			row.value.Text:SetText(getDropdownValueText(control, value))
		else
			row.value.Text:SetText(formatControlValue(control, value))
		end
	end
	if row.swatch and type(control.getColor) == "function" then
		local key = control.key or control.id
		local ok, r, g, b, a = pcall(control.getColor, key)
		if ok then
			row.swatch.Texture:SetColorTexture(r or 1, g or 1, b or 1, a or 1)
			if row.hexText then
				row.hexText.Text:SetText(
					string.format(
						"#%02X%02X%02X",
						math.floor(((r or 1) * 255) + 0.5),
						math.floor(((g or 1) * 255) + 0.5),
						math.floor(((b or 1) * 255) + 0.5)
					)
				)
			end
		end
	end
end

local updateScrollFrameVisibility

local function setScrollHeight(state)
	local height = math.max(1, math.abs(state.y) + 24)
	state.content:SetHeight(height)
	updateScrollFrameVisibility(state.frame.Scroll)
end

local function updateContentMetrics(state)
	local shellWidth = state.frame.ContentShell and state.frame.ContentShell:GetWidth() or 0
	local fallbackWidth = CONTENT_WIDTH
	local usableShellWidth = math.max(1, math.floor((shellWidth > 0 and shellWidth or fallbackWidth) - 26))
	local useSidePanel = state.view == "page"
	local pageRightWidth = 0
	if useSidePanel then
		local idealRightWidth = usableShellWidth - PAGE_LEFT_WIDTH_IDEAL - PAGE_GAP - 14
		pageRightWidth = math.min(PAGE_RIGHT_WIDTH, math.max(PAGE_RIGHT_WIDTH_MIN, idealRightWidth))
		if usableShellWidth - pageRightWidth - PAGE_GAP - 14 < PAGE_LEFT_WIDTH_MIN then
			pageRightWidth = usableShellWidth - PAGE_LEFT_WIDTH_MIN - PAGE_GAP - 14
		end
		pageRightWidth = math.max(PAGE_RIGHT_WIDTH_MIN, math.floor(pageRightWidth))
	end
	state.sidePanelMode = useSidePanel and "right" or nil
	state.pageRightWidth = pageRightWidth
	state.pageGap = useSidePanel and PAGE_GAP or 0
	if state.frame.Scroll and state.frame.ContentShell then
		state.frame.Scroll:ClearAllPoints()
		state.frame.Scroll:SetPoint("TOPLEFT", state.frame.ContentShell, "TOPLEFT", 12, -12)
		if state.view == "page" and useSidePanel then
			state.frame.Scroll:SetPoint(
				"BOTTOMRIGHT",
				state.frame.ContentShell,
				"BOTTOMRIGHT",
				-(pageRightWidth + PAGE_GAP + 14),
				12
			)
		else
			state.frame.Scroll:SetPoint("BOTTOMRIGHT", state.frame.ContentShell, "BOTTOMRIGHT", -14, 12)
		end
	end
	local width
	if state.view == "page" and useSidePanel then
		width = usableShellWidth - pageRightWidth - PAGE_GAP - 14
	else
		width = usableShellWidth
	end
	local minimumWidth = state.view == "page" and PAGE_LEFT_WIDTH_MIN or 640
	width = math.max(minimumWidth, math.floor(width))
	state.contentWidth = width
	state.pageLeftWidth = width
	state.content:SetWidth(width)
end

local function skinScrollFrame(scrollFrame)
	if not scrollFrame then return end
	local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar") or ""]
	local up = scrollFrame.ScrollBar and scrollFrame.ScrollBar.ScrollUpButton or scrollFrame.ScrollUpButton
	local down = scrollFrame.ScrollBar and scrollFrame.ScrollBar.ScrollDownButton or scrollFrame.ScrollDownButton
	local buttons = {}
	if scrollBar then
		up = up or scrollBar.ScrollUpButton or scrollBar.Back
		down = down or scrollBar.ScrollDownButton or scrollBar.Forward
		if scrollBar.SetAlpha then scrollBar:SetAlpha(0.55) end
	end
	buttons[1] = up
	buttons[2] = down
	if scrollBar then
		buttons[3] = scrollBar.Back
		buttons[4] = scrollBar.Forward
		buttons[5] = scrollBar.ScrollUpButton
		buttons[6] = scrollBar.ScrollDownButton
	end
	for _, button in ipairs(buttons) do
		if button and button.Hide then
			button:Hide()
			if button.SetAlpha then button:SetAlpha(0) end
			if button.EnableMouse then button:EnableMouse(false) end
			if button.HookScript then
				button:HookScript("OnShow", function(self) self:Hide() end)
			end
		end
	end
end

updateScrollFrameVisibility = function(scrollFrame)
	if not scrollFrame then return end
	local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and (scrollFrame:GetName() .. "ScrollBar") or ""]
	if not scrollBar or not scrollBar.SetShown then return end
	local range = scrollFrame.GetVerticalScrollRange and scrollFrame:GetVerticalScrollRange() or 0
	scrollBar:SetShown(range and range > 1)
end

local function clearContent(state)
	clearFrameList(state.contentFrames)
	state.y = -2
end

local function clearFixedContent(state)
	clearFrameList(state.fixedFrames)
end

local function clearSidebar(state)
	clearFrameList(state.sidebarFrames)
	state.sidebarY = -6
end

local function addSectionTitle(state, title, subtitle)
	local height = subtitle and 58 or 34
	local frame = createContentFrame(state, height)
	local titleText = createText(frame, FONT_TITLE, title or "", GOLD)
	titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	titleText:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	titleText:SetHeight(24)
	if subtitle and subtitle ~= "" then
		local subText = createText(frame, FONT_MUTED, subtitle, MUTED)
		subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
		subText:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
		subText:SetHeight(24)
	end
	state.y = state.y - 8
	return frame
end

local function addInfoCard(state, title, lines, height)
	local card = createContentFrame(state, height or 96)
	applyBackdrop(card, CARD_BG, CARD_BORDER)

	local titleText = createText(card, FONT_HEADER, title or "", GOLD)
	titleText:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
	titleText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	titleText:SetHeight(20)

	local body = createText(card, FONT_MUTED, table.concat(lines or {}, "\n"), MUTED)
	body:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -8)
	body:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
	state.y = state.y - 12
	return card
end

local function createGridRow(state, height)
	local row = createContentFrame(state, height)
	row.contentWidth = state.contentWidth or CONTENT_WIDTH
	row:SetWidth(row.contentWidth)
	state.y = state.y - GRID_GAP
	return row
end

local function createGridCard(state, row, index, columns, height)
	local width = math.floor(((state.contentWidth or CONTENT_WIDTH) - ((columns - 1) * GRID_GAP)) / columns)
	local card = CreateFrame("Button", nil, row, "BackdropTemplate")
	card:SetSize(width, height)
	card:SetPoint("TOPLEFT", row, "TOPLEFT", (index - 1) * (width + GRID_GAP), 0)
	applyBackdrop(card, CARD_BG, CARD_BORDER)
	card:EnableMouse(true)
	applyHoverState(card)
	return card, width
end

local function createPageLeftFrame(state, height)
	local frame = trackFrame(state.contentFrames, CreateFrame("Frame", nil, state.content, "BackdropTemplate"))
	frame:SetPoint("TOPLEFT", state.content, "TOPLEFT", 0, state.y)
	frame:SetSize(state.pageLeftWidth or 420, height)
	state.y = state.y - height
	return frame
end

local function addStatusChip(parent, text, color, width)
	local chip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	chip:SetSize(width or 86, 20)
	applyBackdrop(chip, { 0.02, 0.05, 0.025, 0.86 }, { color[1], color[2], color[3], 0.45 })
	chip.Text = chip:CreateFontString(nil, "OVERLAY", FONT_MUTED)
	chip.Text:SetAllPoints(chip)
	chip.Text:SetJustifyH("CENTER")
	chip.Text:SetText(text or "")
	setTextColor(chip.Text, color)
	return chip
end

local function getDashboardIconSize(iconSource)
	if iconSource == SETTINGS_QUICK_REFERENCE_ICON then
		return 48, 50
	elseif iconSource == SETTINGS_EXPORT_IMPORT_ICON then
		return 48, 54
	elseif iconSource == SETTINGS_REVERT_ICON then
		return 48, 56
	end
	return 48, 48
end

local function createDashboardIcon(parent, iconSource)
	local icon = parent:CreateTexture(nil, "OVERLAY")
	local width, height = getDashboardIconSize(iconSource)
	icon:SetSize(width, height)
	icon:SetTexture(iconSource or FALLBACK_ICON)
	return icon
end

local function applyDashboardCardBackground(card, bgColor)
	if card.SetBackdrop then
		card:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			tile = true,
			tileSize = 16,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		card:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
	end
end

local function createDashboardCardBorder(card)
	if card.BorderTop then return end
	card.BorderTop = card:CreateTexture(nil, "OVERLAY", nil, 1)
	card.BorderTop:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	card.BorderTop:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
	card.BorderTop:SetHeight(1)

	card.BorderBottom = card:CreateTexture(nil, "OVERLAY", nil, 1)
	card.BorderBottom:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
	card.BorderBottom:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
	card.BorderBottom:SetHeight(1)

	card.BorderLeft = card:CreateTexture(nil, "OVERLAY", nil, 1)
	card.BorderLeft:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	card.BorderLeft:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
	card.BorderLeft:SetWidth(1)

	card.BorderRight = card:CreateTexture(nil, "OVERLAY", nil, 1)
	card.BorderRight:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
	card.BorderRight:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
	card.BorderRight:SetWidth(1)
end

local function setDashboardCardBorder(card, borderColor)
	createDashboardCardBorder(card)
	card.BorderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	card.BorderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	card.BorderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
	card.BorderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function styleRaisedTile(tile)
	applyDashboardCardBackground(tile, DASHBOARD_CARD_BG)
	setDashboardCardBorder(tile, DASHBOARD_CARD_BORDER)
	tile:EnableMouse(true)
	tile:SetScript("OnEnter", function(self)
		applyDashboardCardBackground(self, DASHBOARD_CARD_BG_HOVER)
		setDashboardCardBorder(self, CARD_BORDER_HOVER)
	end)
	tile:SetScript("OnLeave", function(self)
		applyDashboardCardBackground(self, DASHBOARD_CARD_BG)
		setDashboardCardBorder(self, DASHBOARD_CARD_BORDER)
	end)
end

local function addDashboardCard(row, index, title, description, iconSource, onClick)
	local card = createGridCard({ contentWidth = row.contentWidth or CONTENT_WIDTH }, row, index, 2, 108)
	styleRaisedTile(card)
	if onClick then
		card:SetScript("OnMouseUp", onClick)
	end
	local icon = createDashboardIcon(card, iconSource)
	icon:SetPoint("LEFT", card, "LEFT", 24, 0)

	local titleText = createText(card, FONT_TITLE, title or "", WHITE)
	titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 18, -6)
	titleText:SetPoint("RIGHT", card, "RIGHT", -18, 0)
	titleText:SetHeight(24)

	local desc = createText(card, FONT_TEXT, description or "", MUTED)
	desc:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -7)
	desc:SetPoint("RIGHT", card, "RIGHT", -18, 0)
	desc:SetHeight(42)
	desc.Text:SetWordWrap(true)
	return card
end

local function addDashboardHero(state, title, subtitle)
	local hero = createContentFrame(state, 138)

	local titleText = createText(hero, FONT_HERO, title or "", WHITE)
	titleText:SetPoint("TOPLEFT", hero, "TOPLEFT", 4, -10)
	titleText:SetPoint("RIGHT", hero, "RIGHT", -146, 0)
	titleText:SetHeight(42)

	local subText = createText(hero, FONT_TEXT, subtitle or "", MUTED)
	subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -9)
	subText:SetPoint("RIGHT", hero, "RIGHT", -166, 0)
	subText:SetHeight(48)

	local icon = createDashboardIcon(hero, SETTINGS_COG_ICON)
	icon:SetSize(92, 92)
	icon:SetPoint("RIGHT", hero, "RIGHT", -36, -4)
	state.y = state.y - 8
	return hero
end

local function getOptionalNumber(app, key)
	local value = app.opts and app.opts[key]
	value = type(value) == "function" and value() or value
	value = tonumber(value)
	return value
end

local function splitVersionBadge(version)
	version = tostring(version or "")
	local base, suffix = version:match("^(.-)%-beta([%w%.%-]*)$")
	if base and base ~= "" then
		local number = tostring(suffix or ""):match("^(%d+)")
		return base, number and ("Beta " .. number) or "Beta"
	end
	base, suffix = version:match("^(.-)%-alpha([%w%.%-]*)$")
	if base and base ~= "" then
		local number = tostring(suffix or ""):match("^(%d+)")
		return base, number and ("Alpha " .. number) or "Alpha"
	end
	return version, nil
end

local function addDashboardStatusTile(parent, index, iconSource, iconAtlas, title, value, badge)
	local width = math.floor((parent.tileWidth or 160))
	local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	tile:SetSize(width, 72)
	tile:SetPoint("TOPLEFT", parent, "TOPLEFT", 14 + ((index - 1) * (width + GRID_GAP)), -44)
	styleRaisedTile(tile)

	local icon = tile:CreateTexture(nil, "OVERLAY")
	icon:SetSize(32, 32)
	icon:SetPoint("LEFT", tile, "LEFT", 14, -1)
	if iconAtlas and icon.SetAtlas then
		local hasAtlas = not C_Texture or not C_Texture.GetAtlasInfo or C_Texture.GetAtlasInfo(iconAtlas)
		local ok = hasAtlas and pcall(icon.SetAtlas, icon, iconAtlas, false)
		if not ok then
			icon:SetTexture(iconSource or FALLBACK_ICON)
		end
	else
		icon:SetTexture(iconSource or FALLBACK_ICON)
	end

	local titleText = createText(tile, FONT_MUTED, title or "", GOLD)
	titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 4)
	titleText:SetPoint("RIGHT", tile, "RIGHT", badge and -60 or -10, 0)
	titleText:SetHeight(28)
	titleText.Text:SetWordWrap(true)

	if badge and badge ~= "" then
		local badgeFrame = addStatusChip(tile, badge, GOLD, 54)
		badgeFrame:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -8, -11)
	end

	local valueText = createText(tile, FONT_TITLE, tostring(value or ""), WHITE)
	valueText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -27)
	valueText:SetPoint("RIGHT", tile, "RIGHT", -10, 0)
	valueText:SetHeight(26)
	return tile
end

local function addDashboardStatusPanel(state, stats)
	local app = state.app
	local L = getLocale(app)
	local tiles = {
		{
			icon = STATUS_ENABLED_ICON,
			title = L["configCenterEnabledFeatures"] or "Enabled features",
			value = tostring(stats.enabled) .. " / " .. tostring(stats.controls),
		},
	}

	local profileCount = getOptionalNumber(app, "profileCount")
	if profileCount then
		tiles[#tiles + 1] = {
			icon = STATUS_PROFILE_ICON,
			title = L["Profiles"] or "Profiles",
			value = tostring(profileCount),
		}
	end

	local version = app.opts and app.opts.version
	version = type(version) == "function" and version() or version
	if version then
		local versionValue, versionBadge = splitVersionBadge(version)
		tiles[#tiles + 1] = {
			atlas = STATUS_VERSION_ATLAS,
			title = L["configCenterVersion"] or "Version",
			value = versionValue,
			badge = versionBadge,
		}
	end

	local newCount = getOptionalNumber(app, "newCount")
	if newCount and newCount > 0 then
		tiles[#tiles + 1] = {
			atlas = STATUS_NEW_ATLAS,
			title = L["configCenterNewInVersion"] or "New in this Version",
			value = tostring(newCount),
		}
	end

	local panel = createContentFrame(state, 130)
	applyBackdrop(panel, { 0.070, 0.068, 0.060, 0.90 }, DASHBOARD_CARD_BORDER)
	local title = createText(panel, FONT_TITLE, L["configCenterAddOnStatus"] or (_G.STATUS or "Status"), GOLD)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -13)
	title:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	title:SetHeight(24)

	local contentWidth = state.contentWidth or CONTENT_WIDTH
	panel.tileWidth = math.floor((contentWidth - 28 - ((#tiles - 1) * GRID_GAP)) / math.max(#tiles, 1))
	for index, tile in ipairs(tiles) do
		addDashboardStatusTile(panel, index, tile.icon, tile.atlas, tile.title, tile.value, tile.badge)
	end
	state.y = state.y - 12
	return panel
end

local function addConfigureFallback(row, app, control, text, opts)
	opts = opts or {}
	local L = getLocale(app)
	local button = makeFlatButton(
		row,
		text or L["configCenterConfigure"] or "Configure",
		opts.width or 138,
		26,
		ICON_TEXTURES.advanced
	)
	if opts.point then
		button:SetPoint(opts.point[1], opts.point[2], opts.point[3], opts.point[4], opts.point[5])
	else
		button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	end
	setFrameBackdrop(button, { 0.100, 0.087, 0.064, 0.95 }, { 0.50, 0.39, 0.20, 0.78 })
	button:SetScript("OnClick", function()
		openLegacySettingsForControl(app, control)
	end)
	return button
end

local function commitInputValue(app, control, editBox, row)
	local value = editBox:GetText() or ""
	if control.numeric then
		value = tonumber(value)
		if value == nil then
			value = tonumber(control.default) or 0
		end
		if control.clampToRange then
			if control.min and value < control.min then value = control.min end
			if control.max and value > control.max then value = control.max end
		end
	end
	app:SetControlValue(control, value)
	refreshControlRow(app, control, row)
end

local function addSliderWidget(row, app, control, opts)
	opts = opts or {}
	local valueText = opts.valueText
	if not valueText then
		valueText = createText(row, FONT_TEXT, "", GOLD, "RIGHT")
		valueText:SetPoint("RIGHT", row, "RIGHT", -14, 10)
		valueText:SetSize(62, 18)
	end
	row.value = valueText
	local sliderWidth = opts.width or 220
	local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
	if opts.point then
		slider:SetPoint(opts.point[1], opts.point[2], opts.point[3], opts.point[4], opts.point[5])
	else
		slider:SetPoint("RIGHT", valueText, "LEFT", -12, -7)
	end
	slider:SetSize(sliderWidth, 18)
	local minValue = tonumber(control.min) or 0
	local maxValue = tonumber(control.max) or 1
	slider:SetMinMaxValues(minValue, maxValue)
	slider:SetValueStep(tonumber(control.step) or 1)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	if slider.Low then slider.Low:Hide() end
	if slider.High then slider.High:Hide() end
	if slider.Text then slider.Text:Hide() end
	if slider.Left then slider.Left:Hide() end
	if slider.Middle then slider.Middle:Hide() end
	if slider.Right then slider.Right:Hide() end
	slider.Track = CreateFrame("Frame", nil, row, "BackdropTemplate")
	slider.Track:SetSize(sliderWidth, 6)
	slider.Track:SetPoint("CENTER", slider, "CENTER", 0, 0)
	applyBackdrop(slider.Track, { 0.025, 0.024, 0.022, 0.95 }, { 0.28, 0.24, 0.17, 0.75 })
	slider.Fill = slider.Track:CreateTexture(nil, "OVERLAY")
	slider.Fill:SetPoint("LEFT", slider.Track, "LEFT", 1, 0)
	slider.Fill:SetHeight(4)
	slider.Fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.68)
	if slider.Thumb then
		slider.Thumb:SetVertexColor(1.0, 0.84, 0.46, 1)
	end
	local function updateFill(value)
		local span = maxValue - minValue
		local percent = span ~= 0 and ((tonumber(value) or minValue) - minValue) / span or 0
		percent = math.max(0, math.min(1, percent))
		slider.Fill:SetWidth(math.max(1, (sliderWidth - 2) * percent))
	end
	slider:SetScript("OnValueChanged", function(self, value)
		updateFill(value)
		if self.updating then
			valueText.Text:SetText(formatControlValue(control, value))
			return
		end
		local step = tonumber(control.step) or 1
		if step > 0 then
			value = math.floor((value / step) + 0.5) * step
		end
		valueText.Text:SetText(formatControlValue(control, value))
		app:SetControlValue(control, value)
	end)
	row.slider = slider
	return slider
end

local function addDropdownWidget(row, app, control, opts)
	opts = opts or {}
	local options = getControlOptions(control)
	if #options == 0 or not MenuUtil or not MenuUtil.CreateContextMenu then
		addConfigureFallback(row, app, control, nil, opts.configure)
		return
	end
	local button = makeFlatButton(row, "", opts.width or 220, 26)
	if opts.point then
		button:SetPoint(opts.point[1], opts.point[2], opts.point[3], opts.point[4], opts.point[5])
	else
		button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	end
	row.value = createText(button, FONT_TEXT, "", WHITE, "LEFT")
	row.value:SetPoint("LEFT", button, "LEFT", 10, 0)
	row.value:SetPoint("RIGHT", button, "RIGHT", -22, 0)
	row.value:SetHeight(18)
	local arrow = createText(button, FONT_TEXT, "v", GOLD, "RIGHT")
	arrow:SetPoint("RIGHT", button, "RIGHT", -8, 1)
	arrow:SetSize(14, 18)
	button:SetScript("OnClick", function(owner)
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			for _, option in ipairs(getControlOptions(control)) do
				rootDescription:CreateButton(option.label, function()
					app:SetControlValue(control, option.value)
					refreshControlRow(app, control, row)
				end)
			end
		end)
	end)
	return button
end

local function addInputWidget(row, app, control, opts)
	opts = opts or {}
	local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	editBox:SetSize(opts.width or math.min(tonumber(control.inputWidth) or 178, 220), control.multiline and 48 or 26)
	if opts.point then
		editBox:SetPoint(opts.point[1], opts.point[2], opts.point[3], opts.point[4], opts.point[5])
	else
		editBox:SetPoint("RIGHT", row, "RIGHT", -14, 0)
	end
	editBox:SetAutoFocus(false)
	editBox:SetNumeric(control.numeric == true)
	if control.maxChars then editBox:SetMaxLetters(control.maxChars) end
	if control.readOnly then editBox:SetEnabled(false) end
	editBox:SetScript("OnEnterPressed", function(self)
		commitInputValue(app, control, self, row)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		commitInputValue(app, control, self, row)
	end)
	row.editBox = editBox
	return editBox
end

local function addToggleWidget(row, app, control)
	local switch = CreateFrame("Button", nil, row, "BackdropTemplate")
	switch:SetSize(48, 24)
	switch:SetPoint("RIGHT", row, "RIGHT", -16, 0)
	applyBackdrop(switch, { 0.050, 0.046, 0.038, 0.95 }, CARD_BORDER)

	switch.Knob = CreateFrame("Frame", nil, switch, "BackdropTemplate")
	switch.Knob:SetSize(18, 18)
	applyBackdrop(switch.Knob, { 0.62, 0.58, 0.49, 1.00 }, { 0.92, 0.82, 0.58, 0.80 })

	function switch:SetChecked(checked)
		self.checked = checked == true
		self.Knob:ClearAllPoints()
		if self.checked then
			setFrameBackdrop(self, { 0.105, 0.205, 0.095, 0.96 }, { GREEN[1], GREEN[2], GREEN[3], 0.70 })
			setFrameBackdrop(self.Knob, { 0.78, 0.92, 0.66, 1.00 }, { GREEN[1], GREEN[2], GREEN[3], 0.85 })
			self.Knob:SetPoint("RIGHT", self, "RIGHT", -3, 0)
		else
			setFrameBackdrop(self, { 0.050, 0.046, 0.038, 0.95 }, CARD_BORDER)
			setFrameBackdrop(self.Knob, { 0.62, 0.58, 0.49, 1.00 }, { 0.92, 0.82, 0.58, 0.80 })
			self.Knob:SetPoint("LEFT", self, "LEFT", 3, 0)
		end
	end

	function switch:GetChecked()
		return self.checked == true
	end

	switch:SetScript("OnEnter", function(self)
		setBackdropBorderColor(self, CARD_BORDER_HOVER)
	end)
	switch:SetScript("OnLeave", function(self)
		self:SetChecked(self.checked)
	end)
	switch:SetScript("OnClick", function(self)
		if not app:IsControlEnabled(control) then
			self:SetChecked(app:GetControlValue(control) == true)
			return
		end
		app:SetControlValue(control, not self:GetChecked())
		refreshControlRow(app, control, row)
	end)

	row.check = switch
	return switch
end

local function addColorWidget(row, app, control, opts)
	opts = opts or {}
	if type(control.getColor) ~= "function" or type(control.setColor) ~= "function" or not ColorPickerFrame then
		addConfigureFallback(row, app, control, nil, opts.configure)
		return
	end
	local currentLabel = createText(row, FONT_MUTED, opts.currentText or (_G.CURRENT or "Current") .. ":", MUTED)
	if opts.point then
		currentLabel:SetPoint(opts.point[1], opts.point[2], opts.point[3], opts.point[4], opts.point[5])
	else
		currentLabel:SetPoint("LEFT", row, "LEFT", FIELD_CONTROL_LEFT, -29)
	end
	currentLabel:SetSize(58, 20)

	local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
	swatch:SetSize(34, 24)
	swatch:SetPoint("LEFT", currentLabel, "RIGHT", 8, 0)
	applyBackdrop(swatch, { 0.02, 0.02, 0.02, 0.92 }, CARD_BORDER)
	swatch.Texture = swatch:CreateTexture(nil, "OVERLAY")
	swatch.Texture:SetPoint("TOPLEFT", swatch, "TOPLEFT", 4, -4)
	swatch.Texture:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -4, 4)
	row.swatch = swatch
	row.hexText = createText(row, FONT_TEXT, "", GOLD)
	row.hexText:SetPoint("LEFT", swatch, "RIGHT", 10, 1)
	row.hexText:SetSize(80, 20)

	local button = makeFlatButton(row, _G.CHANGE or "Change", 92, 26)
	button:SetPoint("LEFT", row.hexText, "RIGHT", 10, 0)
	local function openPicker()
		local key = control.key or control.id
		local ok, r, g, b, a = pcall(control.getColor, key)
		if not ok then
			r, g, b, a = 1, 1, 1, 1
		end
		r, g, b, a = r or 1, g or 1, b or 1, a or 1
		local function applyColor()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or a
			control.setColor(key, nr, ng, nb, na)
			refreshControlRow(app, control, row)
		end
		if ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow({
				r = r,
				g = g,
				b = b,
				opacity = a,
				hasOpacity = control.hasOpacity,
				swatchFunc = applyColor,
				opacityFunc = applyColor,
				cancelFunc = function(previous)
					if previous then control.setColor(key, previous.r, previous.g, previous.b, previous.opacity) end
					refreshControlRow(app, control, row)
				end,
			})
		else
			ColorPickerFrame.func = applyColor
			ColorPickerFrame.opacityFunc = applyColor
			ColorPickerFrame.hasOpacity = control.hasOpacity
			ColorPickerFrame.opacity = a
			ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = a }
			ColorPickerFrame.cancelFunc = function(previous)
				if previous then control.setColor(key, previous.r, previous.g, previous.b, previous.opacity) end
				refreshControlRow(app, control, row)
			end
			ColorPickerFrame:SetColorRGB(r, g, b)
			ColorPickerFrame:Show()
		end
	end
	button:SetScript("OnClick", openPicker)
	swatch:SetScript("OnClick", openPicker)
	return button
end

local function addSettingRow(state, control, pathText, parent, yOffset, width)
	local app = state.app
	local controlType = getControlType(control)
	local layoutType = getControlLayoutType(control)
	local rowHeight = getSettingRowHeight(control)
	local rowWidth = width or parent and (parent:GetWidth() - 24) or state.pageLeftWidth or state.contentWidth or 620
	local row
	if parent then
		row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset or -42)
		row:SetSize(rowWidth, rowHeight)
	else
		row = createContentFrame(state, rowHeight)
		rowWidth = row:GetWidth() > 0 and row:GetWidth() or rowWidth
	end
	styleInlineSettingRow(row)

	local textLeft = 16
	if control.icon or control.iconAtlas then
		local rowIcon = createIcon(row, control.icon or control.iconAtlas, 18, control.iconAtlas ~= nil)
		rowIcon:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -14)
		textLeft = 42
	end

	local title = createText(row, FONT_TEXT, control.label or control.id, WHITE)
	title:SetPoint("TOPLEFT", row, "TOPLEFT", textLeft, -12)
	title:SetHeight(20)

	local descText = control.description or pathText or getControlPath(app, control)
	local desc = createText(row, FONT_MUTED, descText or "", MUTED)
	desc.Text:SetWordWrap(true)

	if layoutType == "boolean" then
		title:SetPoint("RIGHT", row, "RIGHT", -88, 0)
		desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
		desc:SetPoint("RIGHT", row, "RIGHT", -88, 0)
		desc:SetHeight(30)
		addToggleWidget(row, app, control)
	elseif layoutType == "stacked" then
		local valueWidth = controlType == "slider" and 96 or 0
		if valueWidth > 0 then
			title:SetPoint("RIGHT", row, "RIGHT", -(valueWidth + 18), 0)
		else
			title:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		end
		desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
		desc:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		desc:SetHeight(32)

		local controlWidth = getFieldControlWidth(rowWidth)
		local controlPoint = { "BOTTOMLEFT", row, "BOTTOMLEFT", FIELD_CONTROL_LEFT, 15 }
		if controlType == "slider" then
			local valueText = createText(row, FONT_TEXT, "", GOLD, "RIGHT")
			valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -18, -12)
			valueText:SetSize(valueWidth, 20)
			addSliderWidget(row, app, control, {
				point = controlPoint,
				width = controlWidth,
				valueText = valueText,
			})
		elseif controlType == "dropdown" or controlType == "sounddropdown" then
			addDropdownWidget(row, app, control, {
				point = controlPoint,
				width = controlWidth,
				configure = {
					point = controlPoint,
					width = 150,
				},
			})
		elseif controlType == "input" then
			addInputWidget(row, app, control, {
				point = controlPoint,
				width = controlWidth,
			})
		elseif controlType == "colorpicker" then
			addColorWidget(row, app, control, {
				point = controlPoint,
				configure = {
					point = controlPoint,
					width = 150,
				},
			})
		end
	elseif controlType == "button" then
		title:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
		desc:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		desc:SetHeight(36)
		local button = makeFlatButton(row, control.buttonText or (_G.OKAY or "OK"), 112, 26)
		button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -14, 14)
		button:SetScript("OnClick", function()
			if type(control.onClick) == "function" then
				control.onClick()
			elseif type(control.setValue) == "function" then
				control.setValue()
			end
		end)
	else
		title:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
		desc:SetPoint("RIGHT", row, "RIGHT", -18, 0)
		desc:SetHeight(36)
		addConfigureFallback(row, app, control, nil, {
			point = { "BOTTOMRIGHT", row, "BOTTOMRIGHT", -14, 14 },
			width = 150,
		})
		local badge = addStatusChip(row, control.level == "advanced" and "Advanced" or "Legacy", MUTED, 74)
		badge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", textLeft, 15)
	end

	refreshControlRow(app, control, row)
	if not parent then
		state.y = state.y - 10
	end
	return row
end

local function openLegacySettings(app)
	if app.opts and type(app.opts.openLegacySettings) == "function" then
		app.opts.openLegacySettings()
	end
end

local function resetCurrentPage(state)
	if state.view ~= "page" or not state.selectedPageID then
		return
	end
	local page = state.app:GetPage(state.selectedPageID)
	if not page then
		return
	end
	for _, control in ipairs(page.controls or {}) do
		if control.default ~= nil then
			state.app:SetControlValue(control, control.default)
		end
	end
	state:RenderContent()
end

local function confirmResetCurrentPage(state)
	if state.view ~= "page" or not state.selectedPageID then
		return
	end
	local page = state.app:GetPage(state.selectedPageID)
	if not page then
		return
	end
	local L = getLocale(state.app)
	if not StaticPopupDialogs or not StaticPopup_Show then
		resetCurrentPage(state)
		return
	end
	StaticPopupDialogs.EQOL_CONFIG_CENTER_RESET_DEFAULTS = StaticPopupDialogs.EQOL_CONFIG_CENTER_RESET_DEFAULTS or {
		button1 = _G.OKAY or "OK",
		button2 = _G.CANCEL or "Cancel",
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(_, data)
			if data and data.state then
				resetCurrentPage(data.state)
			end
		end,
	}
	local dialog = StaticPopupDialogs.EQOL_CONFIG_CENTER_RESET_DEFAULTS
	dialog.text = (L["configCenterConfirmDefaultsTitle"] or "Reset this page to default values?")
		.. "\n\n"
		.. (L["configCenterConfirmDefaultsDesc"] or "This will restore all settings on %s to their defaults."):format(
			page.title or page.id
		)
	StaticPopup_Show("EQOL_CONFIG_CENTER_RESET_DEFAULTS", nil, nil, { state = state })
end

local function addPageCard(state, page, row, index, columns)
	local controlCount = #(page.controls or {})
	local card = row and createGridCard(state, row, index, columns or 2, 104) or createContentFrame(state, 104)
	styleRaisedTile(card)
	card:SetScript("OnMouseUp", function()
		state:SetPage(page.id)
	end)

	local iconSource, iconIsAtlas = resolvePageIcon(page)
	local icon = createIconPlate(card, iconSource, 42, iconIsAtlas)
	icon:SetPoint("LEFT", card, "LEFT", 14, 0)

	local title = createText(card, FONT_HEADER, page.title or page.id, WHITE)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -3)
	title:SetPoint("RIGHT", card, "RIGHT", -42, 0)
	title:SetHeight(22)

	local desc = getPageDescription(state.app, page)
	local descText = createText(card, FONT_MUTED, desc, MUTED)
	descText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
	descText:SetPoint("RIGHT", card, "RIGHT", -42, 0)
	descText:SetHeight(26)
	descText.Text:SetWordWrap(true)

	local metaText = getSettingCountText(state.app, controlCount)
	local meta = createText(card, FONT_MUTED, metaText, GOLD)
	meta:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -62)
	meta:SetPoint("RIGHT", card, "RIGHT", -42, 0)
	meta:SetHeight(16)

	local open = createText(card, FONT_TITLE, ">", GOLD, "RIGHT")
	open:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	open:SetSize(18, 22)
	if not row then
		state.y = state.y - 10
	end
end

local function collectEnabledPages(app, limit)
	local result = {}
	local seen = {}
	for _, control in ipairs(app.controls or {}) do
		if getControlType(control) == "toggle" and app:GetControlValue(control) == true and not seen[control.pageID] then
			local page = app:GetPage(control.pageID)
			if page then
				result[#result + 1] = page
				seen[control.pageID] = true
				if limit and #result >= limit then break end
			end
		end
	end
	return result
end

local function isNewTagActive(app, tagID)
	local resolver = app and app.opts and app.opts.isNewTag
	if type(resolver) ~= "function" or not tagID then
		return false
	end
	local ok, result = pcall(resolver, tagID)
	return ok and result == true
end

local function collectNewEntries(app, limit)
	local result = {}
	local seen = {}
	for _, page in ipairs(app.pages or {}) do
		if page.newTagID and isNewTagActive(app, page.newTagID) and not seen[page.id] then
			result[#result + 1] = {
				title = page.title or page.id,
				pageID = page.id,
			}
			seen[page.id] = true
			if limit and #result >= limit then return result end
		end
	end
	for _, control in ipairs(app.controls or {}) do
		if control.newTagID and isNewTagActive(app, control.newTagID) and not seen[control.id] then
			result[#result + 1] = {
				title = control.label or control.id,
				pageID = control.pageID,
			}
			seen[control.id] = true
			if limit and #result >= limit then return result end
		end
	end
	return result
end

local function addDashboardNewPanel(state, parent, entries, width)
	local app = state.app
	local L = getLocale(app)
	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	panel:SetSize(width, 250)
	applyBackdrop(panel, CARD_BG, CARD_BORDER)

	local title = createText(panel, FONT_HEADER, L["configCenterNewInVersion"] or "New in this Version", GOLD)
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12)
	title:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	title:SetHeight(20)

	for index, entry in ipairs(entries) do
		local row = CreateFrame("Button", nil, panel)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -46 - ((index - 1) * 38))
		row:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
		row:SetHeight(26)
		row:SetScript("OnClick", function()
			if entry.pageID then state:SetPage(entry.pageID) end
		end)

		local icon = row:CreateTexture(nil, "OVERLAY")
		icon:SetSize(15, 15)
		icon:SetPoint("LEFT", row, "LEFT", 0, 0)
		if icon.SetAtlas then
			local ok = pcall(icon.SetAtlas, icon, STATUS_NEW_ATLAS, false)
			if not ok then icon:SetTexture("Interface\\Common\\ReputationStar") end
		else
			icon:SetTexture("Interface\\Common\\ReputationStar")
		end

		local label = createText(row, FONT_TEXT, entry.title or "", WHITE)
		label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
		label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		label:SetHeight(22)
	end
	return panel
end

local function renderDashboard(state)
	local app = state.app
	local L = getLocale(app)
	local stats = app:GetStats()
	addDashboardHero(
		state,
		L["configCenterTitle"] or (getAppTitle(app) .. " Settings"),
		L["configCenterIntro"] or DEFAULT_DASHBOARD_INTRO
	)

	local quickRow = createGridRow(state, 108)
	addDashboardCard(
		quickRow,
		1,
		L["configCenterQuickReference"] or (_G.HELP_LABEL or _G.HELP or "Help"),
		L["configCenterQuickReferenceDesc"] or "Useful links, slash commands and information.",
		ICON_TEXTURES.help
	)
	addDashboardCard(
		quickRow,
		2,
		L["configCenterSupportFeedback"] or "Support & Feedback",
		L["configCenterSupportFeedbackDesc"] or "Report bugs, request features or get help.",
		ICON_TEXTURES.support,
		function()
			openLegacySettings(app)
		end
	)

	local quickRow2 = createGridRow(state, 108)
	addDashboardCard(
		quickRow2,
		1,
		L["configCenterImportExport"] or "Import / Export",
		L["configCenterImportExportDesc"] or "Import or export your settings and profiles.",
		ICON_TEXTURES.profiles
	)
	addDashboardCard(
		quickRow2,
		2,
		L["configCenterResetDefaults"] or "Reset & Defaults",
		L["configCenterResetDefaultsDesc"] or "Reset settings or restore default values.",
		ICON_TEXTURES.reset
	)

	addDashboardStatusPanel(state, stats)

	local enabledPages = collectEnabledPages(app, 5)
	local newEntries = collectNewEntries(app, 3)
	local panelRow = createContentFrame(state, 250)
	local panelWidth = state.contentWidth or CONTENT_WIDTH
	local hasNewPanel = #newEntries > 0
	local newPanelWidth = hasNewPanel and math.floor((panelWidth - GRID_GAP) * 0.48) or 0
	local enabledWidth = hasNewPanel and (panelWidth - newPanelWidth - GRID_GAP) or panelWidth
	if hasNewPanel then
		addDashboardNewPanel(state, panelRow, newEntries, newPanelWidth)
	end
	local enabledPanel = CreateFrame("Frame", nil, panelRow, "BackdropTemplate")
	if hasNewPanel then
		enabledPanel:SetPoint("TOPRIGHT", panelRow, "TOPRIGHT", 0, 0)
	else
		enabledPanel:SetPoint("TOPLEFT", panelRow, "TOPLEFT", 0, 0)
	end
	enabledPanel:SetSize(enabledWidth, 250)
	applyBackdrop(enabledPanel, CARD_BG, CARD_BORDER)
	local enabledTitle = createText(
		enabledPanel,
		FONT_HEADER,
		L["configCenterRecentlyEnabled"] or "Recently Enabled Features",
		GOLD
	)
	enabledTitle:SetPoint("TOPLEFT", enabledPanel, "TOPLEFT", 14, -12)
	enabledTitle:SetPoint("RIGHT", enabledPanel, "RIGHT", -14, 0)
	enabledTitle:SetHeight(20)
	if #enabledPages == 0 then
		local emptyText = createText(enabledPanel, FONT_MUTED, L["configCenterNoResults"] or "No settings found.", MUTED)
		emptyText:SetPoint("TOPLEFT", enabledTitle, "BOTTOMLEFT", 0, -12)
		emptyText:SetPoint("BOTTOMRIGHT", enabledPanel, "BOTTOMRIGHT", -14, 14)
	else
		for index, page in ipairs(enabledPages) do
			local mini = CreateFrame("Button", nil, enabledPanel, "BackdropTemplate")
			mini:SetPoint("TOPLEFT", enabledPanel, "TOPLEFT", 14, -38 - ((index - 1) * 39))
			mini:SetPoint("RIGHT", enabledPanel, "RIGHT", -14, 0)
			mini:SetHeight(34)
			applyBackdrop(mini, { 0.058, 0.052, 0.044, 0.90 }, CARD_BORDER)
			applyHoverState(mini, { 0.058, 0.052, 0.044, 0.90 }, CARD_BG_HOVER, CARD_BORDER, CARD_BORDER_HOVER)
			mini:SetScript("OnClick", function() state:SetPage(page.id) end)
			local iconSource, iconIsAtlas = resolvePageIcon(page)
			local icon = createIcon(mini, iconSource, 20, iconIsAtlas)
			icon:SetPoint("LEFT", mini, "LEFT", 9, 0)
			local label = createText(mini, FONT_TEXT, page.title or page.id, WHITE)
			label:SetPoint("LEFT", icon, "RIGHT", 9, 0)
			label:SetPoint("RIGHT", mini, "RIGHT", -96, 0)
			label:SetHeight(18)
			local badge = addStatusChip(mini, _G.ENABLED or "Enabled", GREEN, 76)
			badge:SetPoint("RIGHT", mini, "RIGHT", -8, 0)
		end
	end
	state.y = state.y - 14
end

local function renderCategoryOverview(state, categoryID)
	local app = state.app
	local category = app.categoriesByID[categoryID]
	if not category then
		renderDashboard(state)
		return
	end
	addSectionTitle(state, category.title or category.id, category.description)
	local pages = app:GetPages(categoryID)
	if #pages == 0 then
		addInfoCard(state, app.opts.title or app.id, { getLocale(app)["configCenterNoResults"] or "No settings found." }, 72)
		return
	end
	for index = 1, #pages, 2 do
		local row = createGridRow(state, 104)
		addPageCard(state, pages[index], row, 1, 2)
		if pages[index + 1] then
			addPageCard(state, pages[index + 1], row, 2, 2)
		end
	end
end

local function collectPageGroups(app, page, mainToggle)
	local groups = {}
	local groupsByID = {}
	for _, group in ipairs(page.groups or {}) do
		local entry = {
			id = group.id,
			title = group.title or group.id,
			order = group.order,
			controls = {},
			collapsed = group.collapsed,
		}
		groups[#groups + 1] = entry
		groupsByID[group.id] = entry
	end
	for _, control in ipairs(page.controls or {}) do
		if control ~= mainToggle then
			local groupID = control.groupID or "settings"
			local entry = groupsByID[groupID]
			if not entry then
				entry = {
					id = groupID,
					title = control.groupTitle or (_G.SETTINGS or "Settings"),
					order = 100000,
					controls = {},
				}
				groups[#groups + 1] = entry
				groupsByID[groupID] = entry
			end
			entry.controls[#entry.controls + 1] = control
		end
	end
	for index = #groups, 1, -1 do
		if #groups[index].controls == 0 then
			table.remove(groups, index)
		end
	end
	table.sort(groups, function(a, b)
		local ao = tonumber(a.order) or 1000
		local bo = tonumber(b.order) or 1000
		if ao ~= bo then return ao < bo end
		return tostring(a.title) < tostring(b.title)
	end)
	local _ = app
	return groups
end

local function addPageSidePanel(state, page, category)
	local L = getLocale(state.app)
	local panel = trackFrame(state.fixedFrames, CreateFrame("Frame", nil, state.frame.ContentShell, "BackdropTemplate"))
	panel:SetPoint("TOPRIGHT", state.frame.ContentShell, "TOPRIGHT", -14, -12)
	panel:SetSize(state.pageRightWidth or PAGE_RIGHT_WIDTH, 248)
	applyBackdrop(panel, CARD_BG, CARD_BORDER)

	local aboutTitle = createText(panel, FONT_HEADER, L["configCenterAbout"] or "About", GOLD)
	aboutTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
	aboutTitle:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	aboutTitle:SetHeight(20)

	local aboutText = createText(panel, FONT_MUTED, getPageDescription(state.app, page), MUTED)
	aboutText:SetPoint("TOPLEFT", aboutTitle, "BOTTOMLEFT", 0, -8)
	aboutText:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	aboutText:SetHeight(58)

	local divider = panel:CreateTexture(nil, "OVERLAY")
	divider:SetColorTexture(CARD_BORDER[1], CARD_BORDER[2], CARD_BORDER[3], 0.55)
	divider:SetPoint("TOPLEFT", aboutText, "BOTTOMLEFT", 0, -10)
	divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -104)
	divider:SetHeight(1)

	local relatedTitle = createText(panel, FONT_HEADER, L["configCenterRelated"] or "Related", GOLD)
	relatedTitle:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -12)
	relatedTitle:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	relatedTitle:SetHeight(20)
	local relatedLines = {
		category and (category.title or category.id) or "",
		getSettingCountText(state.app, #(page.controls or {})),
	}
	local relatedText = createText(panel, FONT_MUTED, table.concat(relatedLines, "\n"), MUTED)
	relatedText:SetPoint("TOPLEFT", relatedTitle, "BOTTOMLEFT", 0, -8)
	relatedText:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
	relatedText:SetHeight(48)
	return panel
end

local function addGroupSection(state, group, pagePath)
	local collapsed = state.collapsedGroups and state.collapsedGroups[group.id] == true
	local controlsHeight = 0
	if not collapsed then
		for _, control in ipairs(group.controls) do
			controlsHeight = controlsHeight + getSettingRowHeight(control)
		end
	end
	local rowGap = collapsed and 0 or math.max(#group.controls - 1, 0) * 2
	local height = 46 + controlsHeight + rowGap + 14
	local section = createPageLeftFrame(state, height)
	applyBackdrop(section, DETAIL_SECTION_BG, CARD_BORDER)

	local header = CreateFrame("Button", nil, section, "BackdropTemplate")
	header:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
	header:SetHeight(40)
	applyBackdrop(header, { 0.078, 0.068, 0.050, 0.96 }, { 0, 0, 0, 0 })
	header.Text = header:CreateFontString(nil, "OVERLAY", FONT_HEADER)
	header.Text:SetPoint("LEFT", header, "LEFT", 14, 0)
	header.Text:SetPoint("RIGHT", header, "RIGHT", -34, 0)
	header.Text:SetJustifyH("LEFT")
	header.Text:SetText(group.title or group.id)
	setTextColor(header.Text, WHITE)
	header.Chevron = header:CreateFontString(nil, "OVERLAY", FONT_TEXT)
	header.Chevron:SetPoint("RIGHT", header, "RIGHT", -14, 0)
	header.Chevron:SetText(collapsed and ">" or "v")
	setTextColor(header.Chevron, GOLD)
	header:SetScript("OnClick", function()
		state.collapsedGroups[group.id] = not collapsed
		state:RenderContent()
	end)

	if not collapsed then
		local y = -46
		for _, control in ipairs(group.controls) do
			local rowHeight = getSettingRowHeight(control)
			addSettingRow(state, control, pagePath, section, y, (state.pageLeftWidth or 420) - 24)
			y = y - rowHeight - 2
		end
	end
	state.y = state.y - 12
	return section
end

local function renderPage(state, pageID)
	local app = state.app
	local page = app:GetPage(pageID)
	if not page then
		renderDashboard(state)
		return
	end
	local category = app.categoriesByID[page.category or ""]
	local pagePath = getPagePath(app, page)
	local breadcrumb = createText(createContentFrame(state, 22), FONT_MUTED, getPagePath(app, page), MUTED)
	breadcrumb:SetAllPoints(breadcrumb:GetParent())
	state.y = state.y - 4

	local header = createContentFrame(state, 78)
	local iconSource, iconIsAtlas = resolvePageIcon(page)
	local icon = createIconPlate(header, iconSource, 54, iconIsAtlas)
	icon:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -4)
	local title = createText(header, FONT_TITLE, page.title or page.id, WHITE)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 16, -1)
	title:SetPoint("RIGHT", header, "RIGHT", -190, 0)
	title:SetHeight(25)
	local desc = createText(header, FONT_MUTED, getPageDescription(app, page), MUTED)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetPoint("RIGHT", header, "RIGHT", -190, 0)
	desc:SetHeight(36)
	local statusLabel = category and (category.title or category.id) or (_G.SETTINGS or "Settings")
	local status = addStatusChip(header, statusLabel, GOLD, 150)
	status:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -7)
	if category then
		status:EnableMouse(true)
		status:SetScript("OnMouseUp", function()
			state:SetCategory(category.id)
		end)
	end
	state.y = state.y - 8

	local groupsStartY = state.y
	if state.sidePanelMode == "right" then
		addPageSidePanel(state, page, category)
	end
	local groups = collectPageGroups(app, page, nil)
	if #groups == 0 then
		local empty = createPageLeftFrame(state, 72)
		applyBackdrop(empty, CARD_BG, CARD_BORDER)
		local emptyLabel = getLocale(app)["configCenterNoResults"] or "No settings found."
		local emptyText = createText(empty, FONT_MUTED, emptyLabel, MUTED)
		emptyText:SetPoint("TOPLEFT", empty, "TOPLEFT", 14, -14)
		emptyText:SetPoint("BOTTOMRIGHT", empty, "BOTTOMRIGHT", -14, 14)
	else
		for _, group in ipairs(groups) do
			addGroupSection(state, group, pagePath)
		end
	end
	if state.sidePanelMode == "right" then
		state.y = math.min(state.y, groupsStartY - 230)
	end
end

local function renderSearch(state, query)
	local app = state.app
	local L = getLocale(app)
	local results = app:GetSearchResults(query, 80)
	addSectionTitle(state, (L["configCenterSearchPlaceholder"] or "Search settings") .. ": " .. query)
	if #results == 0 then
		addInfoCard(state, L["configCenterNoResults"] or "No settings found.", {}, 64)
		return
	end
	for _, control in ipairs(results) do
		local page = app:GetPage(control.pageID)
		local card = createContentFrame(state, 78)
		applyBackdrop(card, CARD_BG, CARD_BORDER)
		card:EnableMouse(true)
		applyHoverState(card)
		card:SetScript("OnMouseUp", function()
			state:SetPage(control.pageID)
		end)

		local iconSource, iconIsAtlas = resolvePageIcon(page)
		local icon = createIconPlate(card, iconSource, 38, iconIsAtlas)
		icon:SetPoint("LEFT", card, "LEFT", 14, 0)

		local title = createText(card, FONT_HEADER, control.label or control.id, WHITE)
		title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -5)
		title:SetPoint("RIGHT", card, "RIGHT", -190, 0)
		title:SetHeight(20)

		local descText = control.description or getPageDescription(app, page)
		local desc = createText(card, FONT_MUTED, descText, MUTED)
		desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
		desc:SetPoint("RIGHT", card, "RIGHT", -190, 0)
		desc:SetHeight(22)

		local path = createText(card, FONT_MUTED, getControlPath(app, control), GOLD)
		path:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -4)
		path:SetPoint("RIGHT", card, "RIGHT", -190, 0)
		path:SetHeight(16)

		local badge = addStatusChip(card, getControlTypeLabel(app, control), GOLD, 86)
		badge:SetPoint("RIGHT", card, "RIGHT", -92, 8)
		local openButton = makeFlatButton(card, _G.OPEN or "Open", 74, 24)
		openButton:SetPoint("RIGHT", card, "RIGHT", -14, -12)
		openButton:SetScript("OnClick", function()
			state:SetPage(control.pageID)
		end)
		state.y = state.y - 8
	end
end

local StateMixin = {}

function StateMixin:RenderContent()
	updateContentMetrics(self)
	clearContent(self)
	clearFixedContent(self)
	local query = self.frame.SearchBox:GetText() or ""
	if query ~= "" then
		renderSearch(self, query)
	elseif self.view == "category" then
		renderCategoryOverview(self, self.selectedCategoryID)
	elseif self.view == "page" then
		renderPage(self, self.selectedPageID)
	else
		renderDashboard(self)
	end
	setScrollHeight(self)
	self:RefreshSidebarSelection()
end

function StateMixin:RefreshSidebarSelection()
	for _, row in pairs(self.sidebarRows or {}) do
		local selected = false
		if row.view == "dashboard" then
			selected = self.view == "dashboard"
		elseif row.categoryID then
			selected = self.selectedCategoryID == row.categoryID and self.view ~= "dashboard"
		end
		row.selected = selected
		setFrameBackdrop(row, selected and SELECTED_BG or SIDEBAR_BG, selected and CARD_BORDER_HOVER or { 0, 0, 0, 0 })
		setTextColor(row.Text, selected and GOLD or WHITE)
		if row.Accent then row.Accent:SetShown(selected) end
	end
end

function StateMixin:RenderSidebar()
	clearSidebar(self)
	self.sidebarRows = {}
	local frame = self.frame
	local L = getLocale(self.app)

	local dashboard = createSidebarFrame(self, 44)
	applyBackdrop(dashboard, SIDEBAR_BG, { 0, 0, 0, 0 })
	dashboard.Accent = dashboard:CreateTexture(nil, "OVERLAY")
	dashboard.Accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
	dashboard.Accent:SetPoint("TOPLEFT", dashboard, "TOPLEFT", 0, -6)
	dashboard.Accent:SetPoint("BOTTOMLEFT", dashboard, "BOTTOMLEFT", 0, 6)
	dashboard.Accent:SetWidth(2)
	dashboard.Icon = createIcon(dashboard, ICON_TEXTURES.dashboard, 22, false)
	dashboard.Icon:SetPoint("LEFT", dashboard, "LEFT", 12, 0)
	dashboard.Text = dashboard:CreateFontString(nil, "OVERLAY", FONT_TEXT)
	dashboard.Text:SetPoint("LEFT", dashboard.Icon, "RIGHT", 10, 0)
	dashboard.Text:SetPoint("RIGHT", dashboard, "RIGHT", -12, 0)
	dashboard.Text:SetJustifyH("LEFT")
	dashboard.Text:SetText(L["configCenterDashboard"] or "Dashboard")
	dashboard.view = "dashboard"
	dashboard:SetScript("OnEnter", function(row)
		if not row.selected then setFrameBackdrop(row, CARD_BG_HOVER, CARD_BORDER) end
	end)
	dashboard:SetScript("OnLeave", function(row)
		setFrameBackdrop(
			row,
			row.selected and SELECTED_BG or SIDEBAR_BG,
			row.selected and CARD_BORDER_HOVER or { 0, 0, 0, 0 }
		)
	end)
	dashboard:SetScript("OnClick", function()
		frame.SearchBox:SetText("")
		self:SetDashboard()
	end)
	self.sidebarRows.dashboard = dashboard

	for _, category in ipairs(self.app:GetCategories()) do
		local row = createSidebarFrame(self, 44)
		applyBackdrop(row, SIDEBAR_BG, { 0, 0, 0, 0 })
		row.Accent = row:CreateTexture(nil, "OVERLAY")
		row.Accent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)
		row.Accent:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -6)
		row.Accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 6)
		row.Accent:SetWidth(2)
		local iconSource, iconIsAtlas = resolveCategoryIcon(category)
		row.Icon = createIcon(row, iconSource, 22, iconIsAtlas)
		row.Icon:SetPoint("LEFT", row, "LEFT", 12, 0)
		row.Text = row:CreateFontString(nil, "OVERLAY", FONT_TEXT)
		row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 10, 0)
		row.Text:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetText(category.title or category.id)
		row.categoryID = category.id
		row:SetScript("OnEnter", function(sidebarRow)
			if not sidebarRow.selected then setFrameBackdrop(sidebarRow, CARD_BG_HOVER, CARD_BORDER) end
		end)
		row:SetScript("OnLeave", function(sidebarRow)
			setFrameBackdrop(
				sidebarRow,
				sidebarRow.selected and SELECTED_BG or SIDEBAR_BG,
				sidebarRow.selected and CARD_BORDER_HOVER or { 0, 0, 0, 0 }
			)
		end)
		row:SetScript("OnClick", function()
			frame.SearchBox:SetText("")
			self:SetCategory(category.id)
		end)
		self.sidebarRows[category.id] = row
	end
	frame.Sidebar:SetHeight(math.max(1, math.abs(self.sidebarY) + 8))
	updateScrollFrameVisibility(frame.SidebarScroll)
	self:RefreshSidebarSelection()
end

function StateMixin:SetDashboard()
	self.view = "dashboard"
	self.selectedPageID = nil
	self:RenderContent()
end

function StateMixin:SetCategory(categoryID)
	self.view = "category"
	self.selectedCategoryID = categoryID
	self.selectedPageID = nil
	self:RenderContent()
end

function StateMixin:SetPage(pageID)
	local page = self.app:GetPage(pageID)
	self.view = "page"
	self.selectedPageID = pageID
	if page then
		self.selectedCategoryID = page.category
	end
	self.frame.SearchBox:SetText("")
	self:RenderContent()
end

local function initializeState(frame, app)
	local state = {
		app = app,
		frame = frame,
		content = frame.Content,
		contentFrames = {},
		fixedFrames = {},
		sidebarFrames = {},
		sidebarRows = {},
		collapsedGroups = {},
		contentWidth = CONTENT_WIDTH,
		view = "dashboard",
		selectedCategoryID = nil,
		selectedPageID = nil,
		y = -2,
		sidebarY = -6,
	}
	for key, value in pairs(StateMixin) do
		state[key] = value
	end
	return state
end

local function createFrame(app)
	local L = getLocale(app)
	local name = (app.id or "EQOL") .. "ConfigCenterFrame"
	local frame = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	applyBackdrop(frame, PANEL_BG, PANEL_BORDER)
	applyWindowBorder(frame)
	frame:Hide()

	frame.TopBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.TopBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
	frame.TopBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
	frame.TopBar:SetHeight(54)
	applyBackdrop(frame.TopBar, TOPBAR_BG, { 0.52, 0.39, 0.19, 0.52 })

	frame.TopBarAccent = frame.TopBar:CreateTexture(nil, "OVERLAY")
	frame.TopBarAccent:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.38)
	frame.TopBarAccent:SetPoint("BOTTOMLEFT", frame.TopBar, "BOTTOMLEFT", 10, 0)
	frame.TopBarAccent:SetPoint("BOTTOMRIGHT", frame.TopBar, "BOTTOMRIGHT", -10, 0)
	frame.TopBarAccent:SetHeight(1)

	frame.HeaderIcon = createIcon(frame.TopBar, getAddonIcon(app), 32, false)
	frame.HeaderIcon:SetPoint("LEFT", frame.TopBar, "LEFT", 12, 0)

	frame.Title = frame.TopBar:CreateFontString(nil, "OVERLAY", FONT_TITLE)
	frame.Title:SetPoint("LEFT", frame.HeaderIcon, "RIGHT", 10, 0)
	frame.Title:SetPoint("RIGHT", frame.TopBar, "RIGHT", -470, 0)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetText(L["configCenterTitle"] or (getAppTitle(app) .. " Settings"))
	frame.Title:SetShadowColor(0, 0, 0, 0.95)
	frame.Title:SetShadowOffset(1, -1)
	setTextColor(frame.Title, TOPBAR_GOLD)

	frame.ResetButton = makeFlatButton(frame.TopBar, _G.DEFAULTS or _G.RESET or "Defaults", 104, 28)
	frame.ResetButton:SetPoint("RIGHT", frame.TopBar, "RIGHT", -46, 0)
	setFrameBackdrop(frame.ResetButton, { 0.120, 0.105, 0.075, 0.95 }, { 0.55, 0.42, 0.18, 0.82 })
	setTextColor(frame.ResetButton.Text, TOPBAR_GOLD)
	frame.ResetButton:SetScript("OnEnter", function(self)
		setFrameBackdrop(self, { 0.165, 0.135, 0.080, 0.98 }, CARD_BORDER_HOVER)
	end)
	frame.ResetButton:SetScript("OnLeave", function(self)
		setFrameBackdrop(self, { 0.120, 0.105, 0.075, 0.95 }, { 0.55, 0.42, 0.18, 0.82 })
	end)

	frame.SearchShell = CreateFrame("Frame", nil, frame.TopBar, "BackdropTemplate")
	frame.SearchShell:SetSize(286, 28)
	frame.SearchShell:SetPoint("RIGHT", frame.ResetButton, "LEFT", -12, 0)
	applyBackdrop(frame.SearchShell, { 0.035, 0.034, 0.032, 0.95 }, { 0.30, 0.28, 0.22, 0.90 })

	frame.SearchIcon = frame.SearchShell:CreateTexture(nil, "OVERLAY")
	frame.SearchIcon:SetSize(15, 15)
	frame.SearchIcon:SetPoint("LEFT", frame.SearchShell, "LEFT", 10, 0)
	if frame.SearchIcon.SetAtlas then
		local ok = pcall(frame.SearchIcon.SetAtlas, frame.SearchIcon, "common-search-magnifyingglass", false)
		if not ok then
			frame.SearchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		end
	else
		frame.SearchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	end
	frame.SearchIcon:SetAlpha(0.72)

	frame.SearchBox = CreateFrame("EditBox", nil, frame.SearchShell, "InputBoxTemplate")
	frame.SearchBox:SetSize(286, 28)
	frame.SearchBox:SetPoint("CENTER", frame.SearchShell, "CENTER", 0, 0)
	frame.SearchBox:SetAutoFocus(false)
	if frame.SearchBox.SetTextInsets then
		frame.SearchBox:SetTextInsets(34, 28, 0, 0)
	end
	for _, regionKey in ipairs({ "Left", "Middle", "Right", "LeftTex", "MiddleTex", "RightTex" }) do
		local region = frame.SearchBox[regionKey]
		if region and region.SetAlpha then
			region:SetAlpha(0)
		end
	end
	frame.SearchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	frame.SearchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

	frame.SearchPlaceholder = frame.SearchShell:CreateFontString(nil, "OVERLAY", FONT_MUTED)
	frame.SearchPlaceholder:SetPoint("LEFT", frame.SearchBox, "LEFT", 34, 1)
	frame.SearchPlaceholder:SetPoint("RIGHT", frame.SearchBox, "RIGHT", -30, 1)
	frame.SearchPlaceholder:SetJustifyH("LEFT")
	frame.SearchPlaceholder:SetText((L["configCenterSearchPlaceholder"] or "Search settings") .. "...")
	setTextColor(frame.SearchPlaceholder, { 0.62, 0.60, 0.56, 0.92 })

	frame.SearchClearButton = makeFlatButton(frame.SearchShell, "x", 24, 22)
	frame.SearchClearButton:SetPoint("RIGHT", frame.SearchBox, "RIGHT", -4, 0)
	frame.SearchClearButton:SetScript("OnClick", function()
		frame.SearchBox:SetText("")
		frame.SearchBox:ClearFocus()
	end)
	frame.SearchClearButton:Hide()

	frame.SidebarShell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.SidebarShell:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -72)
	frame.SidebarShell:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
	frame.SidebarShell:SetWidth(SIDEBAR_WIDTH)
	applyBackdrop(frame.SidebarShell, SIDEBAR_BG, PANEL_BORDER)

	frame.SidebarScroll = CreateFrame("ScrollFrame", nil, frame.SidebarShell, "UIPanelScrollFrameTemplate")
	frame.SidebarScroll:SetPoint("TOPLEFT", frame.SidebarShell, "TOPLEFT", 8, -8)
	frame.SidebarScroll:SetPoint("BOTTOMRIGHT", frame.SidebarShell, "BOTTOMRIGHT", -28, 54)
	skinScrollFrame(frame.SidebarScroll)

	frame.Sidebar = CreateFrame("Frame", nil, frame.SidebarScroll)
	frame.Sidebar:SetWidth(SIDEBAR_WIDTH - 44)
	frame.Sidebar:SetHeight(1)
	frame.Sidebar:SetPoint("TOPLEFT", frame.SidebarScroll, "TOPLEFT", 0, 0)
	frame.SidebarScroll:SetScrollChild(frame.Sidebar)

	local legacyLabel = L["configCenterLegacyBlizzard"] or "Legacy Blizzard Settings"
	frame.LegacyButton = makeFlatButton(frame.SidebarShell, legacyLabel, 184, 30, ICON_TEXTURES.advanced)
	frame.LegacyButton:SetPoint("BOTTOMLEFT", frame.SidebarShell, "BOTTOMLEFT", 8, 11)
	frame.LegacyButton:SetScript("OnClick", function() openLegacySettings(app) end)

	frame.ContentShell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.ContentShell:SetPoint("TOPLEFT", frame.SidebarShell, "TOPRIGHT", 18, 0)
	frame.ContentShell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 18)
	applyBackdrop(frame.ContentShell, CONTENT_BG, { 0.24, 0.20, 0.14, 0.54 })

	frame.Scroll = CreateFrame("ScrollFrame", nil, frame.ContentShell, "UIPanelScrollFrameTemplate")
	frame.Scroll:SetPoint("TOPLEFT", frame.ContentShell, "TOPLEFT", 12, -12)
	frame.Scroll:SetPoint("BOTTOMRIGHT", frame.ContentShell, "BOTTOMRIGHT", -14, 12)
	skinScrollFrame(frame.Scroll)

	frame.Content = CreateFrame("Frame", nil, frame.Scroll)
	frame.Content:SetWidth(CONTENT_WIDTH)
	frame.Content:SetHeight(1)
	frame.Content:SetPoint("TOPLEFT", frame.Scroll, "TOPLEFT", 0, 0)
	frame.Scroll:SetScrollChild(frame.Content)

	local state = initializeState(frame, app)
	frame._LibEQOLConfigState = state
	updateContentMetrics(state)

	frame.SearchBox:SetScript("OnTextChanged", function()
		if frame.SearchPlaceholder then
			frame.SearchPlaceholder:SetShown(frame.SearchBox:GetText() == "")
		end
		if frame.SearchClearButton then
			frame.SearchClearButton:SetShown(frame.SearchBox:GetText() ~= "")
		end
		state:RenderContent()
	end)
	frame.ResetButton:SetScript("OnClick", function()
		confirmResetCurrentPage(state)
	end)
	frame:SetScript("OnSizeChanged", function()
		if frame:IsShown() then
			state:RenderContent()
		end
	end)

	state:RenderSidebar()
	state:RenderContent()
	return frame
end

function lib:Open(appOrID, pageID)
	local _ = self
	local app = type(appOrID) == "table" and appOrID or LibStub("LibEQOLConfig-1.0"):GetAddOn(appOrID)
	if not app then
		return nil
	end
	local frame = frames[app.id]
	if not frame then
		frame = createFrame(app)
		frames[app.id] = frame
	else
		frame._LibEQOLConfigState:RenderSidebar()
	end
	local state = frame._LibEQOLConfigState
	if pageID and pageID ~= "dashboard" then
		state:SetPage(pageID)
	elseif not pageID then
		state:RenderContent()
	else
		state:SetDashboard()
	end
	frame:Show()
	return frame
end

function lib:Toggle(appOrID, pageID)
	local app = type(appOrID) == "table" and appOrID or LibStub("LibEQOLConfig-1.0"):GetAddOn(appOrID)
	if not app then
		return nil
	end
	local frame = frames[app.id]
	if frame and frame:IsShown() then
		frame:Hide()
		return frame
	end
	return self:Open(app, pageID)
end
