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

local WINDOW_WIDTH = 980
local WINDOW_HEIGHT = 660
local SIDEBAR_WIDTH = 220
local CONTENT_WIDTH = 690
local GRID_GAP = 10

local FONT_TITLE = "GameFontNormalLarge"
local FONT_HEADER = "GameFontNormal"
local FONT_TEXT = "GameFontHighlight"
local FONT_MUTED = "GameFontDisableSmall"

local PANEL_BG = { 0.025, 0.025, 0.03, 0.92 }
local PANEL_BORDER = { 0.35, 0.30, 0.20, 0.70 }
local CARD_BG = { 0.045, 0.045, 0.055, 0.88 }
local CARD_BG_HOVER = { 0.075, 0.065, 0.045, 0.94 }
local CARD_BORDER = { 0.42, 0.36, 0.23, 0.55 }
local SELECTED_BG = { 0.18, 0.13, 0.045, 0.94 }
local MUTED = { 0.62, 0.62, 0.58 }
local WHITE = { 0.92, 0.90, 0.84 }
local GOLD = { 1.0, 0.82, 0.36 }
local GREEN = { 0.36, 0.82, 0.36 }
local WARNING = { 1.0, 0.55, 0.18 }

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local ICON_TEXTURES = {
	actionbar = "Interface\\Icons\\INV_Sword_04",
	advanced = "Interface\\Icons\\INV_Misc_Gear_01",
	bags = "Interface\\Icons\\INV_Misc_Bag_08",
	chat = "Interface\\Icons\\INV_Letter_15",
	combat = "Interface\\Icons\\Ability_Warrior_BattleShout",
	cooldown = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	dashboard = "Interface\\Icons\\INV_Misc_Gear_01",
	economy = "Interface\\Icons\\INV_Misc_Coin_01",
	gameplay = "Interface\\Icons\\Ability_DualWield",
	general = "Interface\\Icons\\Trade_BlackSmithing",
	help = "Interface\\Icons\\INV_Misc_Book_09",
	interface = "Interface\\Icons\\INV_Misc_Monitor_01",
	map = "Interface\\Icons\\INV_Misc_Map_01",
	nameplate = "Interface\\Icons\\INV_Misc_Tournaments_banner_Human",
	profiles = "Interface\\Icons\\INV_Misc_GroupNeedMore",
	reset = "Interface\\Icons\\Ability_Rogue_FeignDeath",
	resource = "Interface\\Icons\\INV_Misc_Food_100",
	social = "Interface\\Icons\\INV_Misc_GroupLooking",
	sound = "Interface\\Icons\\INV_Misc_Note_01",
	support = "Interface\\Icons\\INV_Misc_QuestionMark",
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

local PAGE_ICON_KEYS = {
	actionbars = "actionbar",
	bags = "bags",
	chat = "chat",
	cooldown = "cooldown",
	cooldowns = "cooldown",
	map = "map",
	nameplates = "nameplate",
	resource = "resource",
	tooltips = "tooltip",
	tooltip = "tooltip",
	unitframes = "unitframes",
	unit = "unitframes",
	vendor = "vendor",
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

local function setBackdropColor(frame, color)
	frame:SetBackdropColor(color[1], color[2], color[3], color[4])
end

local function setTextColor(fontString, color)
	if fontString and color then
		fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	end
end

local function getAddonIcon(app)
	return app and app.opts and app.opts.icon or FALLBACK_ICON
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
	local iconKey = category and CATEGORY_ICON_KEYS[category.id]
	return ICON_TEXTURES[iconKey or "advanced"] or FALLBACK_ICON
end

local function resolvePageIcon(page)
	if page and page.icon then
		return page.icon
	end
	if page and page.iconAtlas then
		return page.iconAtlas, true
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

local function getCategoryStats(app, categoryID)
	local pages = app:GetPages(categoryID)
	local controls = 0
	local enabled = 0
	for _, page in ipairs(pages) do
		for _, control in ipairs(page.controls or {}) do
			controls = controls + 1
			if (control.type == "toggle" or control.type == "checkbox") and app:GetControlValue(control) == true then
				enabled = enabled + 1
			end
		end
	end
	return #pages, controls, enabled
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
	button:SetScript("OnEnter", function(self) setBackdropColor(self, CARD_BG_HOVER) end)
	button:SetScript("OnLeave", function(self)
		if self.selected then
			setBackdropColor(self, SELECTED_BG)
		else
			setBackdropColor(self, { 0.07, 0.065, 0.055, 0.92 })
		end
	end)
	return button
end

local function refreshControlRow(app, control, row)
	local enabled = app:IsControlEnabled(control)
	row:SetAlpha(enabled and 1 or 0.48)
	if row.check then
		row.check:SetEnabled(enabled)
		row.check:SetChecked(app:GetControlValue(control) == true)
	end
	if row.value then
		local value = app:GetControlValue(control)
		if type(value) == "boolean" then
			row.value.Text:SetText(value and (_G.ENABLED or "Enabled") or (_G.DISABLED or "Disabled"))
		elseif value ~= nil then
			row.value.Text:SetText(tostring(value))
		else
			row.value.Text:SetText("")
		end
	end
end

local function setScrollHeight(state)
	local height = math.max(1, math.abs(state.y) + 24)
	state.content:SetHeight(height)
end

local function clearContent(state)
	clearFrameList(state.contentFrames)
	state.y = -2
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
	card:SetScript("OnEnter", function(self) setBackdropColor(self, CARD_BG_HOVER) end)
	card:SetScript("OnLeave", function(self) setBackdropColor(self, CARD_BG) end)
	return card, width
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

local function addDashboardCard(row, index, title, description, iconSource, onClick)
	local card = createGridCard({ contentWidth = row.contentWidth or CONTENT_WIDTH }, row, index, 2, 84)
	if onClick then
		card:SetScript("OnMouseUp", onClick)
	end
	local icon = createIconPlate(card, iconSource, 42, false)
	icon:SetPoint("LEFT", card, "LEFT", 14, 0)

	local titleText = createText(card, FONT_HEADER, title or "", WHITE)
	titleText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -4)
	titleText:SetPoint("RIGHT", card, "RIGHT", -14, 0)
	titleText:SetHeight(20)

	local desc = createText(card, FONT_MUTED, description or "", MUTED)
	desc:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
	desc:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -14, 12)
	return card
end

local function addSettingRow(state, control, pathText)
	local app = state.app
	local row = createContentFrame(state, 66)
	applyBackdrop(row, CARD_BG, CARD_BORDER)

	local iconKey = getKeywordIconKey((control.id or "") .. " " .. (control.label or "")) or "advanced"
	local rowIcon = createIcon(row, ICON_TEXTURES[iconKey], 18, false)
	rowIcon:SetPoint("TOPLEFT", row, "TOPLEFT", 14, -14)

	local title = createText(row, FONT_TEXT, control.label or control.id, WHITE)
	title:SetPoint("TOPLEFT", rowIcon, "TOPRIGHT", 9, 3)
	title:SetPoint("RIGHT", row, "RIGHT", -150, 0)
	title:SetHeight(20)

	local descText = control.description or pathText or getControlPath(app, control)
	local desc = createText(row, FONT_MUTED, descText or "", MUTED)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
	desc:SetPoint("RIGHT", row, "RIGHT", -150, 0)
	desc:SetHeight(28)

	if control.type == "toggle" or control.type == "checkbox" then
		local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		check:SetPoint("RIGHT", row, "RIGHT", -16, 0)
		check:SetSize(28, 28)
		check:SetScript("OnClick", function(self)
			if not app:IsControlEnabled(control) then
				self:SetChecked(app:GetControlValue(control) == true)
				return
			end
			app:SetControlValue(control, self:GetChecked() == true)
			refreshControlRow(app, control, row)
		end)
		row.check = check
	elseif control.type == "button" then
		local button = makeFlatButton(row, control.buttonText or (_G.OKAY or "OK"), 112, 26)
		button:SetPoint("RIGHT", row, "RIGHT", -14, 0)
		button:SetScript("OnClick", function()
			if type(control.onClick) == "function" then
				control.onClick()
			elseif type(control.setValue) == "function" then
				control.setValue()
			end
		end)
	else
		local value = createText(row, FONT_MUTED, "", MUTED, "RIGHT")
		value:SetPoint("RIGHT", row, "RIGHT", -16, 0)
		value:SetSize(130, 24)
		row.value = value
	end

	refreshControlRow(app, control, row)
	state.y = state.y - 8
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

local function addCategoryCard(state, category, row, index, columns)
	local app = state.app
	local pageCount, controlCount, enabledCount = getCategoryStats(app, category.id)
	local card = row and createGridCard(state, row, index, columns or 2, 86) or createContentFrame(state, 84)
	applyBackdrop(card, CARD_BG, CARD_BORDER)
	card:EnableMouse(true)
	card:SetScript("OnEnter", function(self) setBackdropColor(self, CARD_BG_HOVER) end)
	card:SetScript("OnLeave", function(self) setBackdropColor(self, CARD_BG) end)
	card:SetScript("OnMouseUp", function()
		state:SetCategory(category.id)
	end)

	local iconSource, iconIsAtlas = resolveCategoryIcon(category)
	local icon = createIconPlate(card, iconSource, 42, iconIsAtlas)
	icon:SetPoint("LEFT", card, "LEFT", 14, 0)

	local title = createText(card, FONT_HEADER, category.title or category.id, WHITE)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -3)
	title:SetPoint("RIGHT", card, "RIGHT", -88, 0)
	title:SetHeight(22)

	local settingsLabel = getLocale(app)["configCenterAllSettings"] or "All settings"
	local categoryDetails = settingsLabel .. ": " .. ("%d / %d"):format(pageCount, controlCount)
	local details = createText(card, FONT_MUTED, categoryDetails, MUTED)
	details:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	details:SetPoint("RIGHT", card, "RIGHT", -88, 0)
	details:SetHeight(22)

	local enabled = createText(card, FONT_MUTED, tostring(enabledCount), GOLD, "RIGHT")
	enabled:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	enabled:SetSize(110, 24)
	if not row then
		state.y = state.y - 10
	end
end

local function addPageCard(state, page, row, index, columns)
	local app = state.app
	local controlCount = #(page.controls or {})
	local card = row and createGridCard(state, row, index, columns or 2, 90) or createContentFrame(state, 88)
	applyBackdrop(card, CARD_BG, CARD_BORDER)
	card:EnableMouse(true)
	card:SetScript("OnEnter", function(self) setBackdropColor(self, CARD_BG_HOVER) end)
	card:SetScript("OnLeave", function(self) setBackdropColor(self, CARD_BG) end)
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

	local desc = page.description
	if not desc or desc == "" then
		desc = (getLocale(app)["configCenterAllSettings"] or "All settings") .. ": " .. tostring(controlCount)
	end
	local descText = createText(card, FONT_MUTED, desc, MUTED)
	descText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	descText:SetPoint("RIGHT", card, "RIGHT", -42, 0)
	descText:SetHeight(36)

	local open = createText(card, FONT_TITLE, ">", GOLD, "RIGHT")
	open:SetPoint("RIGHT", card, "RIGHT", -16, 0)
	open:SetSize(18, 22)
	if not row then
		state.y = state.y - 10
	end
end

local function renderDashboard(state)
	local app = state.app
	local L = getLocale(app)
	local stats = app:GetStats()
	addSectionTitle(state, L["configCenterDashboard"] or "Dashboard", getAppTitle(app))

	local quickRow = createGridRow(state, 84)
	local legacyLabel = L["configCenterLegacyBlizzard"] or "Legacy Blizzard Settings"
	addDashboardCard(
		quickRow,
		1,
		_G.HELP_LABEL or _G.HELP or "Help",
		L["configCenterAllSettings"] or "All settings",
		ICON_TEXTURES.help
	)
	addDashboardCard(
		quickRow,
		2,
		L["configCenterQuickActions"] or "Quick actions",
		legacyLabel,
		ICON_TEXTURES.support,
		function()
			openLegacySettings(app)
		end
	)

	local status = createContentFrame(state, 76)
	applyBackdrop(status, CARD_BG, CARD_BORDER)
	local statusTitle = createText(status, FONT_HEADER, _G.STATUS or "Status", GOLD)
	statusTitle:SetPoint("TOPLEFT", status, "TOPLEFT", 14, -11)
	statusTitle:SetSize(220, 20)

	local allSettingsLabel = (L["configCenterAllSettings"] or "All settings") .. ": " .. tostring(stats.controls)
	local allSettings = addStatusChip(status, allSettingsLabel, GOLD, 170)
	allSettings:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", 14, 13)
	local enabledLabel = (L["configCenterEnabledFeatures"] or "Enabled features") .. ": " .. tostring(stats.enabled)
	local enabled = addStatusChip(status, enabledLabel, GREEN, 190)
	enabled:SetPoint("LEFT", allSettings, "RIGHT", 10, 0)
	local pages = addStatusChip(status, (_G.CATEGORY or "Category") .. ": " .. tostring(stats.pages), WARNING, 138)
	pages:SetPoint("LEFT", enabled, "RIGHT", 10, 0)
	state.y = state.y - 12

	addSectionTitle(state, _G.CATEGORY or "Category", nil)
	local categories = app:GetCategories()
	for index = 1, #categories, 2 do
		local row = createGridRow(state, 86)
		addCategoryCard(state, categories[index], row, 1, 2)
		if categories[index + 1] then
			addCategoryCard(state, categories[index + 1], row, 2, 2)
		end
	end
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
		local row = createGridRow(state, 90)
		addPageCard(state, pages[index], row, 1, 2)
		if pages[index + 1] then
			addPageCard(state, pages[index + 1], row, 2, 2)
		end
	end
end

local function renderPage(state, pageID)
	local app = state.app
	local L = getLocale(app)
	local page = app:GetPage(pageID)
	if not page then
		renderDashboard(state)
		return
	end
	local category = app.categoriesByID[page.category or ""]
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
	local desc = createText(header, FONT_MUTED, page.description or "", MUTED)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetPoint("RIGHT", header, "RIGHT", -190, 0)
	desc:SetHeight(36)
	local statusLabel = category and (category.title or category.id) or (_G.SETTINGS or "Settings")
	local status = addStatusChip(header, statusLabel, GOLD, 150)
	status:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -7)
	state.y = state.y - 8

	local mainToggle
	for _, control in ipairs(page.controls or {}) do
		if not mainToggle and (control.type == "toggle" or control.type == "checkbox") then
			mainToggle = control
		end
	end
	if mainToggle then
		addSettingRow(state, mainToggle, getPagePath(app, page))
	end

	local infoRow = createGridRow(state, 82)
	local about = createGridCard(state, infoRow, 1, 2, 82)
	local aboutTitle = createText(about, FONT_HEADER, page.title or page.id, GOLD)
	aboutTitle:SetPoint("TOPLEFT", about, "TOPLEFT", 14, -12)
	aboutTitle:SetPoint("RIGHT", about, "RIGHT", -14, 0)
	aboutTitle:SetHeight(20)
	local aboutDescription = (page.description ~= "" and page.description) or getPagePath(app, page)
	local aboutText = createText(about, FONT_MUTED, aboutDescription, MUTED)
	aboutText:SetPoint("TOPLEFT", aboutTitle, "BOTTOMLEFT", 0, -7)
	aboutText:SetPoint("BOTTOMRIGHT", about, "BOTTOMRIGHT", -14, 12)
	local related = createGridCard(state, infoRow, 2, 2, 82)
	local relatedTitle = createText(related, FONT_HEADER, L["configCenterAllSettings"] or "All settings", GOLD)
	relatedTitle:SetPoint("TOPLEFT", related, "TOPLEFT", 14, -12)
	relatedTitle:SetPoint("RIGHT", related, "RIGHT", -14, 0)
	relatedTitle:SetHeight(20)
	local relatedDescription = tostring(#(page.controls or {})) .. " / " .. getPagePath(app, page)
	local relatedText = createText(related, FONT_MUTED, relatedDescription, MUTED)
	relatedText:SetPoint("TOPLEFT", relatedTitle, "BOTTOMLEFT", 0, -7)
	relatedText:SetPoint("BOTTOMRIGHT", related, "BOTTOMRIGHT", -14, 12)

	local section = createContentFrame(state, 28)
	local sectionTitle = createText(section, FONT_HEADER, _G.SETTINGS or "Settings", GOLD)
	sectionTitle:SetAllPoints(section)

	for _, control in ipairs(page.controls or {}) do
		if control ~= mainToggle then
			addSettingRow(state, control, getPagePath(app, page))
		end
	end

	local footer = createContentFrame(state, 42)
	local reset = makeFlatButton(footer, _G.RESET or "Reset", 118, 28, ICON_TEXTURES.reset)
	reset:SetPoint("RIGHT", footer, "RIGHT", -130, 0)
	reset:SetScript("OnClick", function() resetCurrentPage(state) end)
	local apply = makeFlatButton(footer, _G.APPLY or "Apply", 118, 28)
	apply:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
	apply:SetScript("OnClick", function() state:RenderContent() end)
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
		local row = addSettingRow(state, control, getControlPath(app, control))
		if row.check then
			local openButton = makeFlatButton(row, _G.OPEN or "Open", 66, 24)
			openButton:SetPoint("RIGHT", row, "RIGHT", -56, 0)
			openButton:SetScript("OnClick", function()
				state:SetPage(control.pageID)
			end)
		end
	end
end

local StateMixin = {}

function StateMixin:RenderContent()
	clearContent(self)
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
		setBackdropColor(row, selected and SELECTED_BG or PANEL_BG)
		setTextColor(row.Text, selected and GOLD or WHITE)
	end
end

function StateMixin:RenderSidebar()
	clearSidebar(self)
	self.sidebarRows = {}
	local frame = self.frame
	local L = getLocale(self.app)

	local dashboard = createSidebarFrame(self, 42)
	applyBackdrop(dashboard, PANEL_BG, { 0, 0, 0, 0 })
	dashboard.Icon = createIcon(dashboard, ICON_TEXTURES.dashboard, 20, false)
	dashboard.Icon:SetPoint("LEFT", dashboard, "LEFT", 12, 0)
	dashboard.Text = dashboard:CreateFontString(nil, "OVERLAY", FONT_TEXT)
	dashboard.Text:SetPoint("LEFT", dashboard.Icon, "RIGHT", 10, 0)
	dashboard.Text:SetPoint("RIGHT", dashboard, "RIGHT", -12, 0)
	dashboard.Text:SetJustifyH("LEFT")
	dashboard.Text:SetText(L["configCenterDashboard"] or "Dashboard")
	dashboard.view = "dashboard"
	dashboard:SetScript("OnEnter", function(row) if not row.selected then setBackdropColor(row, CARD_BG_HOVER) end end)
	dashboard:SetScript("OnLeave", function(row) setBackdropColor(row, row.selected and SELECTED_BG or PANEL_BG) end)
	dashboard:SetScript("OnClick", function()
		frame.SearchBox:SetText("")
		self:SetDashboard()
	end)
	self.sidebarRows.dashboard = dashboard

	for _, category in ipairs(self.app:GetCategories()) do
		local row = createSidebarFrame(self, 42)
		applyBackdrop(row, PANEL_BG, { 0, 0, 0, 0 })
		local iconSource, iconIsAtlas = resolveCategoryIcon(category)
		row.Icon = createIcon(row, iconSource, 20, iconIsAtlas)
		row.Icon:SetPoint("LEFT", row, "LEFT", 12, 0)
		row.Text = row:CreateFontString(nil, "OVERLAY", FONT_TEXT)
		row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 10, 0)
		row.Text:SetPoint("RIGHT", row, "RIGHT", -12, 0)
		row.Text:SetJustifyH("LEFT")
		row.Text:SetText(category.title or category.id)
		row.categoryID = category.id
		row:SetScript("OnEnter", function(sidebarRow)
			if not sidebarRow.selected then setBackdropColor(sidebarRow, CARD_BG_HOVER) end
		end)
		row:SetScript("OnLeave", function(sidebarRow)
			setBackdropColor(sidebarRow, sidebarRow.selected and SELECTED_BG or PANEL_BG)
		end)
		row:SetScript("OnClick", function()
			frame.SearchBox:SetText("")
			self:SetCategory(category.id)
		end)
		self.sidebarRows[category.id] = row
	end
	frame.Sidebar:SetHeight(math.max(1, math.abs(self.sidebarY) + 8))
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
		sidebarFrames = {},
		sidebarRows = {},
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
	frame:Hide()

	frame.HeaderIcon = createIconPlate(frame, getAddonIcon(app), 34, false)
	frame.HeaderIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -11)

	frame.Title = frame:CreateFontString(nil, "OVERLAY", FONT_TITLE)
	frame.Title:SetPoint("LEFT", frame.HeaderIcon, "RIGHT", 10, 0)
	frame.Title:SetPoint("RIGHT", frame, "RIGHT", -410, 0)
	frame.Title:SetJustifyH("LEFT")
	frame.Title:SetText(L["configCenterTitle"] or (getAppTitle(app) .. " Settings"))
	setTextColor(frame.Title, GOLD)

	frame.ResetButton = makeFlatButton(frame, _G.DEFAULTS or _G.RESET or "Defaults", 104, 28)
	frame.ResetButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -86, -28)

	frame.SearchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.SearchBox:SetSize(260, 28)
	frame.SearchBox:SetPoint("TOPRIGHT", frame.ResetButton, "TOPLEFT", -10, 0)
	frame.SearchBox:SetAutoFocus(false)
	frame.SearchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	frame.SearchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

	frame.SidebarShell = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.SidebarShell:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -64)
	frame.SidebarShell:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 16)
	frame.SidebarShell:SetWidth(SIDEBAR_WIDTH)
	applyBackdrop(frame.SidebarShell, { 0.018, 0.018, 0.022, 0.86 }, PANEL_BORDER)

	frame.SidebarScroll = CreateFrame("ScrollFrame", nil, frame.SidebarShell, "UIPanelScrollFrameTemplate")
	frame.SidebarScroll:SetPoint("TOPLEFT", frame.SidebarShell, "TOPLEFT", 8, -8)
	frame.SidebarScroll:SetPoint("BOTTOMRIGHT", frame.SidebarShell, "BOTTOMRIGHT", -28, 54)

	frame.Sidebar = CreateFrame("Frame", nil, frame.SidebarScroll)
	frame.Sidebar:SetWidth(180)
	frame.Sidebar:SetHeight(1)
	frame.Sidebar:SetPoint("TOPLEFT", frame.SidebarScroll, "TOPLEFT", 0, 0)
	frame.SidebarScroll:SetScrollChild(frame.Sidebar)

	local legacyLabel = L["configCenterLegacyBlizzard"] or "Legacy Blizzard Settings"
	frame.LegacyButton = makeFlatButton(frame.SidebarShell, legacyLabel, 184, 30, ICON_TEXTURES.advanced)
	frame.LegacyButton:SetPoint("BOTTOMLEFT", frame.SidebarShell, "BOTTOMLEFT", 8, 11)
	frame.LegacyButton:SetScript("OnClick", function() openLegacySettings(app) end)

	frame.Scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	frame.Scroll:SetPoint("TOPLEFT", frame.SidebarShell, "TOPRIGHT", 18, 0)
	frame.Scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 18)

	frame.Content = CreateFrame("Frame", nil, frame.Scroll)
	frame.Content:SetWidth(CONTENT_WIDTH)
	frame.Content:SetHeight(1)
	frame.Content:SetPoint("TOPLEFT", frame.Scroll, "TOPLEFT", 0, 0)
	frame.Scroll:SetScrollChild(frame.Content)

	local state = initializeState(frame, app)
	frame._LibEQOLConfigState = state

	frame.SearchBox:SetScript("OnTextChanged", function()
		state:RenderContent()
	end)
	frame.ResetButton:SetScript("OnClick", function()
		resetCurrentPage(state)
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
