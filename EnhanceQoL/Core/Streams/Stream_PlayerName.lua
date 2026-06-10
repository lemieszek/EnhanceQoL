-- luacheck: globals EnhanceQoL UnitFullName UnitName UnitClass GetRealmName NORMAL_FONT_COLOR CUSTOM_CLASS_COLORS RAID_CLASS_COLORS
local addonName, addon = ...
local L = addon.L

local db
local stream

local function getOptionsHint()
	if addon.DataPanel and addon.DataPanel.GetOptionsHintText then
		local text = addon.DataPanel.GetOptionsHintText()
		if text ~= nil then return text end
		return nil
	end
	return L["Right-Click for options"]
end

local function ensureDB()
	addon.db.datapanel = addon.db.datapanel or {}
	addon.db.datapanel.playername = addon.db.datapanel.playername or {}
	db = addon.db.datapanel.playername
	db.fontSize = db.fontSize or 14
	if db.showRealm == nil then db.showRealm = false end
	if db.useClassColor == nil then db.useClassColor = true end
	if db.useTextColor == nil then db.useTextColor = false end
	if not db.textColor then
		local r, g, b = 1, 0.82, 0
		if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.GetRGB then
			r, g, b = NORMAL_FONT_COLOR:GetRGB()
		end
		db.textColor = { r = r, g = g, b = b }
	end
end

local function openSettings()
	if addon.functions and addon.functions.OpenConfigCenter then
		addon.functions.OpenConfigCenter("interface.datapanel", "DataPanel_playername_fontSize")
	end
end

local function getPlayerName()
	local name, realm
	if UnitFullName then name, realm = UnitFullName("player") end
	if not name or name == "" then name = UnitName and UnitName("player") end
	if not name or name == "" then return "" end
	if db and db.showRealm then
		if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
		if realm and realm ~= "" then return name .. "-" .. realm end
	end
	return name
end

local function getClassColor()
	local classToken = UnitClass and select(2, UnitClass("player"))
	local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	return classToken and colors and colors[classToken]
end

local function colorize(text)
	if not text or text == "" then return "" end
	local color
	if db and db.useTextColor then
		color = db.textColor
	elseif db and db.useClassColor then
		color = getClassColor()
	end
	if not color then return text end
	local r = math.floor((color.r or 1) * 255 + 0.5)
	local g = math.floor((color.g or 1) * 255 + 0.5)
	local b = math.floor((color.b or 1) * 255 + 0.5)
	return ("|cff%02x%02x%02x%s|r"):format(r, g, b, text)
end

local function updatePlayerName(s)
	s = s or stream
	if not s then return end
	ensureDB()
	s.snapshot.text = colorize(getPlayerName())
	s.snapshot.fontSize = db.fontSize or 14
	s.snapshot.tooltip = getOptionsHint()
	s.snapshot.skipPanelClassColor = true
end

local provider = {
	id = "playername",
	version = 1,
	title = (PLAYER or "Player") .. " " .. (NAME or "Name"),
	update = updatePlayerName,
	events = {
		PLAYER_LOGIN = function(s) addon.DataHub:RequestUpdate(s) end,
		PLAYER_ENTERING_WORLD = function(s) addon.DataHub:RequestUpdate(s) end,
	},
	OnClick = function(_, btn)
		if btn == "RightButton" then openSettings() end
	end,
}

stream = EnhanceQoL.DataHub.RegisterStream(provider)

return provider
