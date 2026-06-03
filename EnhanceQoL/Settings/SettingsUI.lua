-- SettingsUI.lua (LibEQOLSettingsMode-basiert)
local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local SettingsLib = LibStub("LibEQOLSettingsMode-1.0")
local ConfigLib = LibStub("LibEQOLConfig-1.0", true)
local ConfigUILib = LibStub("LibEQOLConfigUI-1.0", true)

-- Optional: Prefix für Settings-Variablen
local prefix = "EQOL_"

-- Optional: New-Badge-Resolver (Kategorie-ID oder Variablenname)
-- Ersetze addon.variables.NewVersionTableEQOL nach Bedarf
SettingsLib:SetNewTagResolverForPrefix(prefix, function(idOrVar) return addon.variables and addon.variables.NewVersionTableEQOL and addon.variables.NewVersionTableEQOL[idOrVar] end)

addon.SettingsLayout = addon.SettingsLayout or {}
addon.functions = addon.functions or {}
addon.ConfigCurrentGroupByPageID = addon.ConfigCurrentGroupByPageID or {}
addon.ConfigGroupTitleByPageID = addon.ConfigGroupTitleByPageID or {}
addon.ConfigGroupOrderByPageID = addon.ConfigGroupOrderByPageID or {}
addon.ConfigControlOrder = addon.ConfigControlOrder or 0

local rootCategoryMap = {
	UI = "interface",
	GENERAL = "general",
	GAMEPLAY = "gameplay",
	SOCIAL = "social",
	ECONOMY = "economy",
	SOUND = "sound",
	PROFILES = "profiles",
}

local function ensureConfigApp()
	if addon.ConfigApp or not ConfigLib then return addon.ConfigApp end

	local app = ConfigLib:RegisterAddOn(addonName, {
		title = "Enhance QoL",
		icon = "Interface\\AddOns\\EnhanceQoL\\Icons\\Icon.tga",
		addonFolder = addonName,
		assetRoot = "Interface\\AddOns\\EnhanceQoL\\libs\\LibSettingsDesigner\\Assets\\",
		db = function() return addon.db end,
		profile = function() return addon.db end,
		locale = L,
		version = function()
			return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
		end,
		newCount = function()
			local count = 0
			for _, value in pairs(addon.variables and addon.variables.NewVersionTableEQOL or {}) do
				if value then count = count + 1 end
			end
			return count
		end,
		isNewTag = function(tagID)
			local newTags = addon.variables and addon.variables.NewVersionTableEQOL
			if not tagID or type(newTags) ~= "table" then return false end
			local key = tostring(tagID)
			return newTags[key] == true or newTags[prefix .. "_" .. key] == true
		end,
		profileCount = function()
			local count = 0
			if EnhanceQoLDB and type(EnhanceQoLDB.profiles) == "table" then
				for profileName in pairs(EnhanceQoLDB.profiles) do
					if type(profileName) == "string" and profileName ~= "" then count = count + 1 end
				end
			end
			return count
		end,
		openLegacySettings = function()
			if Settings and Settings.OpenToCategory and addon.SettingsLayout and addon.SettingsLayout.rootCategory then
				Settings.OpenToCategory(addon.SettingsLayout.rootCategory:GetID())
			end
		end,
	})

	app:RegisterCategory({ id = "interface", title = _G["INTERFACE_LABEL"] or "Interface", order = 100, iconAtlas = "hud-microbutton-character-up" })
	app:RegisterCategory({ id = "general", title = _G["GENERAL"] or "General", order = 200, iconAtlas = "communities-icon-chat" })
	app:RegisterCategory({ id = "gameplay", title = _G["SETTING_GROUP_GAMEPLAY"] or "Gameplay", order = 300, iconAtlas = "bags-button-autosort-up" })
	app:RegisterCategory({ id = "social", title = _G["SOCIAL_LABEL"] or L["configCenterChatSocial"] or "Chat & Social", order = 400, iconAtlas = "socialqueuing-icon-group" })
	app:RegisterCategory({ id = "economy", title = L["Economy"] or "Economy", order = 500, iconAtlas = "auctionhouse-icon-favorite" })
	app:RegisterCategory({ id = "sound", title = _G["SOUND"] or "Sound", order = 600, iconAtlas = "poi-door-arrow-down" })
	app:RegisterCategory({ id = "profiles", title = L["Profiles"] or "Profiles", order = 700, iconAtlas = "services-icon-warning" })
	app:SetDefaultPage("dashboard")

	addon.ConfigApp = app
	return app
end

local function resolveLegacyPageID(app, cbData, category)
	if not app then return nil end
	if cbData and cbData.pageID then return cbData.pageID end
	if cbData and cbData.parentSection and app.legacySections then return app.legacySections[cbData.parentSection] end
	if category and app.legacyCategories then
		local key
		if type(category) == "table" and category.GetID then
			local ok, id = pcall(category.GetID, category)
			if ok and id ~= nil then key = "id:" .. tostring(id) end
		end
		if not key and type(category) == "table" and category.GetName then
			local ok, name = pcall(category.GetName, category)
			if ok and name ~= nil then key = "name:" .. tostring(name) end
		end
		key = key or tostring(category)
		local categoryID = app.legacyCategories[key]
		if categoryID then return categoryID .. ".settings" end
	end
	return nil
end

local function getDefaultGroupID(app, pageID)
	if not app or not pageID then return nil end
	local groupID = "settings"
	if not app:GetPage(pageID).groupsByID[groupID] then
		app:RegisterGroup(pageID, {
			id = groupID,
			title = _G.SETTINGS or "Settings",
			order = 100000,
		})
	end
	return groupID, _G.SETTINGS or "Settings"
end

local function getLegacyControlGroup(app, category, cbData)
	local pageID = resolveLegacyPageID(app, cbData, category)
	if not pageID or not app:GetPage(pageID) then return nil, nil, pageID end
	if cbData.groupID or cbData.modernGroup then
		local groupID = cbData.groupID or cbData.modernGroup
		local groupTitle = cbData.groupTitle or cbData.groupName or groupID
		app:RegisterGroup(pageID, {
			id = groupID,
			title = groupTitle,
			order = cbData.groupOrder,
		})
		return groupID, groupTitle, pageID
	end
	local groupID = addon.ConfigCurrentGroupByPageID[pageID]
	if groupID then return groupID, addon.ConfigGroupTitleByPageID[pageID], pageID end
	local groupTitle
	groupID, groupTitle = getDefaultGroupID(app, pageID)
	return groupID, groupTitle, pageID
end

function addon.functions.OpenConfigCenter(pageID)
	local app = ensureConfigApp()
	if ConfigUILib and app then
		ConfigUILib:Open(app, pageID)
		return
	end
	if Settings and Settings.OpenToCategory and addon.SettingsLayout and addon.SettingsLayout.rootCategory then
		Settings.OpenToCategory(addon.SettingsLayout.rootCategory:GetID())
	end
end

local function registerLegacyCategory(category, title, newTagID)
	local app = ensureConfigApp()
	if not app then return end
	local categoryID = rootCategoryMap[newTagID] or ConfigLib:NormalizeID(title or newTagID or "advanced")
	app:RegisterLegacyCategory(category, {
		categoryID = categoryID,
		title = title,
		order = categoryID == "advanced" and 800 or nil,
	})
end

local function registerLegacyControl(category, cbData, controlType, setting)
	local app = ensureConfigApp()
	if not app or type(cbData) ~= "table" then return end
	local key = cbData.var or cbData.key
	local id = cbData.id or key or cbData.text or cbData.label or cbData.name
	if not id then return end
	addon.ConfigControlOrder = (addon.ConfigControlOrder or 0) + 1
	local groupID, groupTitle, pageID = getLegacyControlGroup(app, category, cbData)
	app:RegisterLegacyControl({
		legacyCategory = category,
		parentSection = cbData.parentSection,
		pageID = pageID,
		id = id,
		key = key,
		type = controlType,
		label = cbData.text or cbData.label or cbData.name,
		description = cbData.desc,
		default = cbData.default,
		dbDefault = key and function()
			local defaults = addon.dbDefaults
			if type(defaults) == "table" and defaults[key] ~= nil then
				return defaults[key], true
			end
			return nil, false
		end or nil,
		keywords = cbData.searchtags,
		level = cbData.level,
		order = type(cbData.order) == "number" and cbData.order or addon.ConfigControlOrder,
		newTagID = cbData.newTagID,
		groupID = groupID,
		groupTitle = groupTitle,
		setting = setting,
		getValue = cbData.get,
		setValue = cbData.func or cbData.set,
		parentCheck = cbData.parentCheck,
		isEnabled = cbData.isEnabled,
		isMainToggle = cbData.isMainToggle,
		uiRole = cbData.uiRole,
		min = cbData.min,
		max = cbData.max,
		step = cbData.step,
		formatter = cbData.formatter,
		suffix = cbData.suffix,
		valueFormatter = cbData.valueFormatter,
		values = cbData.values,
		options = cbData.options,
		list = cbData.list,
		optionfunc = cbData.optionfunc,
		listFunc = cbData.listFunc,
		orderList = type(cbData.order) == "table" and cbData.order or nil,
		customText = cbData.customText,
		customDefaultText = cbData.customDefaultText,
		menuHeight = cbData.menuHeight or cbData.height,
		dropdownDefault = cbData.dropdownDefault,
		dropdownDesc = cbData.dropdownDesc,
		dropdownFormatter = cbData.dropdownFormatter,
		dropdownGet = cbData.dropdownGet,
		dropdownKey = cbData.dropdownKey or cbData.dropdownVar,
		dropdownList = cbData.dropdownList,
		dropdownListFunc = cbData.dropdownListFunc,
		dropdownName = cbData.dropdownName,
		dropdownOptionfunc = cbData.dropdownOptionfunc,
		dropdownOptions = cbData.dropdownOptions,
		dropdownOrder = cbData.dropdownOrder,
		dropdownSet = cbData.dropdownSet,
		dropdownSetting = cbData.dropdownSetting,
		dropdownSuffix = cbData.dropdownSuffix,
		dropdownText = cbData.dropdownText,
		dropdownValueFormatter = cbData.dropdownValueFormatter,
		dropdownValues = cbData.dropdownValues,
		generator = cbData.generator,
		numeric = cbData.numeric,
		placeholder = cbData.placeholder,
		placeholderText = cbData.placeholderText,
		maxChars = cbData.maxChars,
		readOnly = cbData.readOnly,
		multiline = cbData.multiline,
		multilineHeight = cbData.multilineHeight,
		inputWidth = cbData.inputWidth,
		clampToRange = cbData.clampToRange,
		height = cbData.height,
		buttonText = cbData.buttonText or cbData.buttonLabel or cbData.label,
		onClick = cbData.onClick or cbData.func,
		entries = cbData.entries,
		getColor = cbData.getColor,
		setColor = cbData.setColor,
		getDefaultColor = cbData.getDefaultColor,
		hasOpacity = cbData.hasOpacity,
		colorizeLabel = cbData.colorizeLabel,
		isSelectedFunc = cbData.isSelectedFunc,
		setSelectedFunc = cbData.setSelectedFunc,
		getSelection = cbData.getSelection,
		setSelection = cbData.setSelection,
		selectionSource = cbData.selectionSource,
		summary = cbData.summary,
		soundResolver = cbData.soundResolver,
		previewSoundFunc = cbData.previewSoundFunc,
		playbackChannel = cbData.playbackChannel,
		getPlaybackChannel = cbData.getPlaybackChannel,
	})
end

local function getCVarOptionData(cvarKey) return addon.variables and addon.variables.cvarOptions and addon.variables.cvarOptions[cvarKey] end

function addon.functions.GetCVarOptionState(cvarKey)
	local optionData = getCVarOptionData(cvarKey)
	if not optionData or not C_CVar or not C_CVar.GetCVar then return false end
	local ok, value = pcall(C_CVar.GetCVar, cvarKey)
	if not ok then return false end
	return tostring(value) == tostring(optionData.trueValue)
end

function addon.functions.SetCVarOptionState(cvarKey, enabled)
	local optionData = getCVarOptionData(cvarKey)
	if not optionData then return end
	local newValue = enabled and optionData.trueValue or optionData.falseValue
	if newValue == nil then return end
	if optionData.persistent then
		addon.db = addon.db or {}
		addon.db.cvarOverrides = addon.db.cvarOverrides or {}
		addon.db.cvarOverrides[cvarKey] = tostring(newValue)
	end
	if addon.functions.setCVarValue then addon.functions.setCVarValue(cvarKey, newValue) end
end

---------------------------------------------------------
-- Kategorien
---------------------------------------------------------
function addon.functions.SettingsCreateCategory(parent, treeName, sort, newTagID)
	if nil == parent then parent = addon.SettingsLayout.rootCategory end
	local cat, layout = SettingsLib:CreateCategory(parent, treeName, sort, newTagID, prefix)
	addon.SettingsLayout.knownCategoryID = addon.SettingsLayout.knownCategoryID or {}
	addon.SettingsLayout.knownCategoryID[cat:GetID()] = true
	registerLegacyCategory(cat, treeName, newTagID)
	return cat, layout
end

function addon.functions.SettingsCreateKeybind(cat, bindingIndex, parentSection) SettingsLib:CreateKeybind(cat, { bindingIndex = bindingIndex, parentSection = parentSection }) end

---------------------------------------------------------
-- Checkbox
---------------------------------------------------------
function addon.functions.SettingsCreateCheckbox(cat, cbData)
	local element, setting = SettingsLib:CreateCheckbox(cat, {
		key = cbData.var,
		name = cbData.text,
		default = cbData.default or false,
		get = cbData.get or function() return addon.db[cbData.var] end,
		set = cbData.func or cbData.set or function(_, v) addon.db[cbData.var] = v end,
		desc = cbData.desc,
		searchtags = cbData.searchtags,
		isEnabled = cbData.isEnabled,
		parent = cbData.element,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { setting = setting, element = element }
	registerLegacyControl(cat, cbData, "toggle", setting)

	if cbData.notify then SettingsLib:AttachNotify(setting, cbData.notify) end
	-- Children (rekursiv)
	if cbData.children then
		for _, v in pairs(cbData.children) do
			v.element = v.element or element
			v.parentCheck = v.parentCheck or cbData.parentCheck
			local sType = v.sType or v.type
			if sType == "dropdown" then
				addon.functions.SettingsCreateDropdown(cat, v)
			elseif sType == "scrolldropdown" then
				addon.functions.SettingsCreateScrollDropdown(cat, v)
			elseif sType == "checkbox" then
				addon.functions.SettingsCreateCheckbox(cat, v)
			elseif sType == "multidropdown" then
				addon.functions.SettingsCreateMultiDropdown(cat, v)
			elseif sType == "slider" then
				addon.functions.SettingsCreateSlider(cat, v)
			elseif sType == "hint" then
				addon.functions.SettingsCreateText(cat, v.text, { parentSection = v.parentSection })
			elseif sType == "colorpicker" then
				addon.functions.SettingsCreateColorPicker(cat, v)
			elseif sType == "button" then
				addon.functions.SettingsCreateButton(cat, v)
			elseif sType == "sounddropdown" then
				addon.functions.SettingsCreateSoundDropdown(cat, v)
			end
		end
	end

	return addon.SettingsLayout.elements[cbData.var]
end

function addon.functions.SettingsCreateCheckboxes(cat, data)
	local rData = {}
	for _, cbData in ipairs(data) do
		rData[cbData.var] = addon.functions.SettingsCreateCheckbox(cat, cbData)
	end
	return rData
end

---------------------------------------------------------
-- Checkbox + Dropdown
---------------------------------------------------------
function addon.functions.SettingsCreateCheckboxDropdown(cat, cbData)
	local dropdownKey = cbData.dropdownVar or cbData.dropdownKey
	local initializer, checkboxSetting, dropdownSetting = SettingsLib:CreateCheckboxDropdown(cat, {
		key = cbData.var,
		name = cbData.text,
		default = cbData.default or false,
		get = cbData.get or function() return addon.db[cbData.var] end,
		set = cbData.func or cbData.set or function(v) addon.db[cbData.var] = v end,
		desc = cbData.desc,
		dropdownKey = dropdownKey,
		dropdownName = cbData.dropdownText or cbData.dropdownName,
		dropdownDefault = cbData.dropdownDefault,
		dropdownValues = cbData.dropdownList or cbData.dropdownValues or cbData.list or cbData.values,
		dropdownOrder = cbData.dropdownOrder or cbData.order,
		dropdownGet = cbData.dropdownGet or function() return addon.db[dropdownKey] end,
		dropdownSet = cbData.dropdownSet or function(v) addon.db[dropdownKey] = v end,
		dropdownDesc = cbData.dropdownDesc,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = {
		initializer = initializer,
		setting = checkboxSetting,
		dropdownSetting = dropdownSetting,
	}
	if dropdownKey then
		addon.SettingsLayout.elements[dropdownKey] = {
			initializer = initializer,
			setting = dropdownSetting,
			checkboxSetting = checkboxSetting,
		}
	end
	local modernData = {}
	for key, value in pairs(cbData) do
		modernData[key] = value
	end
	modernData.dropdownKey = dropdownKey
	modernData.dropdownSetting = dropdownSetting
	modernData.dropdownValues = cbData.dropdownList or cbData.dropdownValues or cbData.list or cbData.values
	modernData.dropdownOptions = modernData.dropdownValues
	modernData.dropdownOrder = cbData.dropdownOrder or cbData.order
	modernData.dropdownOptionfunc = cbData.dropdownOptionfunc
		or cbData.dropdownListFunc
		or cbData.listFunc
		or cbData.optionfunc
	modernData.dropdownName = cbData.dropdownText or cbData.dropdownName
	modernData.dropdownDesc = cbData.dropdownDesc
	modernData.dropdownGet = cbData.dropdownGet or function() return addon.db[dropdownKey] end
	modernData.dropdownSet = cbData.dropdownSet or function(v) addon.db[dropdownKey] = v end
	registerLegacyControl(cat, modernData, "checkboxdropdown", checkboxSetting)
	return addon.SettingsLayout.elements[cbData.var]
end

---------------------------------------------------------
-- Slider
---------------------------------------------------------
function addon.functions.SettingsCreateSlider(cat, cbData)
	local element, setting = SettingsLib:CreateSlider(cat, {
		key = cbData.var,
		name = cbData.text,
		default = cbData.default,
		min = cbData.min,
		max = cbData.max,
		step = cbData.step,
		get = cbData.get or function() return addon.db[cbData.var] or cbData.default end,
		set = cbData.set or function(_, v) addon.db[cbData.var] = v end,
		desc = cbData.desc,
		formatter = function(value)
			local s = string.format("%.2f", value)
			s = s:gsub("(%..-)0+$", "%1")
			s = s:gsub("%.$", "")
			return s
		end,
		parent = cbData.element,
		parentCheck = cbData.parentCheck,
		searchtags = cbData.searchtags,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { setting = setting, element = element }
	registerLegacyControl(cat, cbData, "slider", setting)
	return addon.SettingsLayout.elements[cbData.var]
end

---------------------------------------------------------
-- Input
---------------------------------------------------------
function addon.functions.SettingsCreateInput(cat, cbData)
	local element, setting = SettingsLib:CreateInput(cat, {
		key = cbData.var,
		name = cbData.text,
		default = cbData.default,
		get = cbData.get or function() return addon.db[cbData.var] or cbData.default end,
		set = cbData.set or function(v) addon.db[cbData.var] = v end,
		desc = cbData.desc,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
		numeric = cbData.numeric,
		formatter = cbData.formatter,
		maxChars = cbData.maxChars,
		inputWidth = cbData.inputWidth,
		readOnly = cbData.readOnly,
		selectAllOnFocus = cbData.selectAllOnFocus,
		placeholder = cbData.placeholder,
		justifyH = cbData.justifyH,
		min = cbData.min,
		max = cbData.max,
		clampToRange = cbData.clampToRange,
		height = cbData.height,
		multiline = cbData.multiline,
		multilineHeight = cbData.multilineHeight,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { setting = setting, element = element }
	if cbData.notify then SettingsLib:AttachNotify(setting, cbData.notify) end
	registerLegacyControl(cat, cbData, "input", setting)
	return addon.SettingsLayout.elements[cbData.var]
end

---------------------------------------------------------
-- Dropdown
---------------------------------------------------------
function addon.functions.SettingsCreateDropdown(cat, cbData)
	local element, setting = SettingsLib:CreateDropdown(cat, {
		key = cbData.var,
		name = cbData.text,
		default = cbData.default,
		values = cbData.list or cbData.values,
		optionfunc = cbData.listFunc or cbData.optionfunc,
		order = cbData.order,
		get = cbData.get or function() return addon.db[cbData.var] end,
		set = cbData.set or function(_, v) addon.db[cbData.var] = v end,
		desc = cbData.desc,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { setting = setting, element = element }
	if cbData.notify then SettingsLib:AttachNotify(setting, cbData.notify) end
	registerLegacyControl(cat, cbData, "dropdown", setting)
	return addon.SettingsLayout.elements[cbData.var]
end

---------------------------------------------------------
-- Scroll Dropdown
---------------------------------------------------------
function addon.functions.SettingsCreateScrollDropdown(cat, cbData)
	if not SettingsLib.CreateScrollDropdown then return addon.functions.SettingsCreateDropdown(cat, cbData) end

	local key = cbData.var or cbData.key
	local initializer, setting = SettingsLib:CreateScrollDropdown(cat, {
		key = key,
		name = cbData.text,
		default = cbData.default,
		values = cbData.options or cbData.list or cbData.values,
		optionfunc = cbData.optionfunc or cbData.listFunc,
		generator = cbData.generator,
		order = cbData.order,
		height = cbData.height or cbData.menuHeight or 200,
		customText = cbData.customText,
		customDefaultText = cbData.customDefaultText,
		callback = cbData.callback,
		get = cbData.get or function() return addon.db[key] end,
		set = cbData.set or function(_, v) addon.db[key] = v end,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[key] = { initializer = initializer, setting = setting }
	if cbData.notify then SettingsLib:AttachNotify(setting, cbData.notify) end
	registerLegacyControl(cat, cbData, "dropdown", setting)
	return initializer
end

function addon.functions.SettingsAttachNotify(setting, notify)
	if notify and setting then SettingsLib:AttachNotify(setting, notify) end
end

---------------------------------------------------------
-- MultiDropdown
---------------------------------------------------------
function addon.functions.SettingsCreateMultiDropdown(cat, cbData)
	addon.db = addon.db or {}
	local explicitStorageDB = type(cbData.db) == "table" and cbData.db or nil
	local storageDisabled = cbData.storage == false

	-- Resolve addon.db lazily so profile-backed settings do not capture the pre-init placeholder table.
	local function resolveStorageDB()
		if explicitStorageDB then return explicitStorageDB end
		addon.db = addon.db or {}
		return addon.db
	end

	local function ensureRootContainer()
		local storageDB = resolveStorageDB()
		if type(storageDB[cbData.var]) ~= "table" then storageDB[cbData.var] = {} end
		return storageDB
	end

	local function getSelection()
		local storageDB = ensureRootContainer()
		local container = storageDB[cbData.var]
		if cbData.subvar then
			if type(container[cbData.subvar]) ~= "table" then container[cbData.subvar] = {} end
			container = container[cbData.subvar]
		end
		return container
	end

	local function setSelection(map)
		local storageDB = ensureRootContainer()
		if type(map) ~= "table" then map = {} end
		if cbData.subvar then
			storageDB[cbData.var][cbData.subvar] = map
		else
			storageDB[cbData.var] = map
		end
		if cbData.callback then cbData.callback(map) end
	end

	local function iterateOptionValues(func)
		local values = nil
		if cbData.optionfunc or cbData.listFunc then
			local ok, result = pcall(cbData.optionfunc or cbData.listFunc)
			if ok then values = result end
		end
		values = values or cbData.options or cbData.list
		if type(values) ~= "table" then return end

		for key, option in pairs(values) do
			local value = key
			if type(option) == "table" then value = option.value or option.key or option[1] or key end
			if value ~= nil then func(value) end
		end
	end

	local function getSelectionFromSelected()
		local selection = {}
		if type(cbData.isSelectedFunc) ~= "function" then return selection end
		iterateOptionValues(function(value)
			local ok, selected = pcall(cbData.isSelectedFunc, value)
			if ok and selected == true then selection[value] = true end
		end)
		return selection
	end

	local function setSelectionFromSelected(map)
		if type(cbData.setSelectedFunc) ~= "function" then return end
		if type(map) ~= "table" then map = {} end
		local seen = {}
		iterateOptionValues(function(value)
			seen[value] = true
			cbData.setSelectedFunc(value, map[value] == true)
		end)
		for value, selected in pairs(map) do
			if selected == true and not seen[value] then cbData.setSelectedFunc(value, true) end
		end
		if cbData.callback then cbData.callback(map) end
	end

	local initializer = SettingsLib:CreateMultiDropdown(cat, {
		key = cbData.var,
		db = explicitStorageDB or (not storageDisabled and addon.db) or nil,
		name = cbData.text,
		values = cbData.options or cbData.list,
		optionfunc = cbData.optionfunc or cbData.listFunc,
		desc = cbData.desc,
		tooltip = cbData.tooltip,
		height = cbData.menuHeight or 200,
		order = cbData.order,
		customText = cbData.customText,
		customDefaultText = cbData.customDefaultText,
		isSelected = cbData.isSelectedFunc,
		setSelected = cbData.setSelectedFunc,
		getSelection = cbData.getSelection or cbData.get or (storageDisabled and getSelectionFromSelected or getSelection),
		setSelection = cbData.setSelection or cbData.set or (storageDisabled and setSelectionFromSelected or setSelection),
		summary = cbData.summary,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		notify = cbData.notify,
		parentSection = cbData.parentSection,
		isEnabled = cbData.isEnabled,
		prefix = prefix,
		hideSummary = cbData.hideSummary == nil and true or cbData.hideSummary,
	})

	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { initializer = initializer }
	local modernData = {}
	for key, value in pairs(cbData) do
		modernData[key] = value
	end
	local hasExplicitSelectionGetter = type(cbData.getSelection) == "function" or type(cbData.get) == "function"
	local hasPerOptionSelection = type(cbData.isSelectedFunc) == "function"
	if hasExplicitSelectionGetter then
		modernData.getSelection = cbData.getSelection or cbData.get
	elseif hasPerOptionSelection then
		modernData.getSelection = getSelectionFromSelected
		modernData.selectionSource = "perOption"
	else
		modernData.getSelection = storageDisabled and getSelectionFromSelected or getSelection
	end
	if cbData.setSelection or cbData.set then
		modernData.setSelection = cbData.setSelection or cbData.set
	elseif type(cbData.setSelectedFunc) == "function" then
		modernData.setSelection = setSelectionFromSelected
	else
		modernData.setSelection = storageDisabled and setSelectionFromSelected or setSelection
	end
	modernData.values = cbData.options or cbData.list
	modernData.optionfunc = cbData.optionfunc or cbData.listFunc
	modernData.menuHeight = cbData.menuHeight or 200
	registerLegacyControl(cat, modernData, "multidropdown", nil)
	return initializer
end

---------------------------------------------------------
-- Sound Dropdown
---------------------------------------------------------
function addon.functions.SettingsCreateSoundDropdown(cat, cbData)
	local initializer, setting = SettingsLib:CreateSoundDropdown(cat, {
		key = cbData.var,
		name = cbData.text,
		values = cbData.options or cbData.list,
		optionfunc = cbData.optionfunc or cbData.listFunc,
		order = cbData.order,
		default = cbData.default,
		get = cbData.get or function() return addon.db[cbData.var] end,
		set = cbData.set or function(_, v) addon.db[cbData.var] = v end,
		callback = cbData.callback,
		soundResolver = cbData.soundResolver,
		previewSoundFunc = cbData.previewSoundFunc,
		playbackChannel = cbData.playbackChannel,
		getPlaybackChannel = cbData.getPlaybackChannel,
		placeholderText = cbData.placeholderText,
		previewTooltip = cbData.previewTooltip,
		height = cbData.menuHeight,
		frameWidth = cbData.frameWidth,
		frameHeight = cbData.frameHeight,
		parent = cbData.element,
		parentCheck = cbData.parentCheck,
		searchtags = cbData.searchtags,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { initializer = initializer, setting = setting }
	if cbData.notify then SettingsLib:AttachNotify(setting, cbData.notify) end
	registerLegacyControl(cat, cbData, "sounddropdown", setting)

	return initializer
end

---------------------------------------------------------
-- Color Overrides Panel
---------------------------------------------------------
function addon.functions.SettingsCreateColorOverrides(cat, cbData)
	local initializer = SettingsLib:CreateColorOverrides(cat, {
		key = cbData.var or cbData.key,
		headerText = cbData.text or cbData.name,
		entries = cbData.entries,
		getColor = cbData.getColor,
		setColor = cbData.setColor,
		getDefaultColor = cbData.getDefaultColor,
		colorizeLabel = cbData.colorizeLabel or cbData.colorizeText,
		rowHeight = cbData.rowHeight,
		basePadding = cbData.basePadding,
		minHeight = cbData.minHeight,
		height = cbData.height,
		spacing = cbData.spacing,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		searchtags = cbData.searchtags,
		notify = cbData.notify,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var or cbData.key or "ColorOverrides"] = { initializer = initializer }
	registerLegacyControl(cat, cbData, "coloroverrides", nil)
	return initializer
end

-- Text / Header / Button / Notify
---------------------------------------------------------
function addon.functions.SettingsCreateHeadline(cat, text, extra)
	local header = SettingsLib:CreateHeader(cat, text, extra)
	local app = ensureConfigApp()
	if app and extra and extra.parentSection then
		local pageID = app.legacySections and app.legacySections[extra.parentSection]
		if pageID and app:GetPage(pageID) then
			addon.ConfigGroupOrderByPageID[pageID] = (addon.ConfigGroupOrderByPageID[pageID] or 0) + 10
			local groupID = extra.groupID or extra.modernGroup or ConfigLib:NormalizeID(text or "settings")
			app:RegisterGroup(pageID, {
				id = groupID,
				title = text,
				order = extra.order or addon.ConfigGroupOrderByPageID[pageID],
			})
			addon.ConfigCurrentGroupByPageID[pageID] = groupID
			addon.ConfigGroupTitleByPageID[pageID] = text
		end
	end
	return header
end

function addon.functions.SettingsCreateText(cat, text, extra) return SettingsLib:CreateText(cat, text, extra) end

function addon.functions.SettingsCreateButton(cat, cbData)
	local btn = SettingsLib:CreateButton(cat, {
		label = cbData.label,
		text = cbData.text,
		func = cbData.func,
		desc = cbData.desc,
		searchtags = cbData.searchtags,
		parent = cbData.element or cbData.parent,
		parentCheck = cbData.parentCheck,
		parentSection = cbData.parentSection,
		prefix = prefix,
	})
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var or cbData.text] = { element = btn }
	registerLegacyControl(cat, cbData, "button", nil)
	return btn
end

function addon.functions.SettingsCreateColorPicker(cat, cbData)
	local entries = { { key = cbData.var, label = cbData.text, tooltip = cbData.tooltip } }
	local function getColor(_)
		local db = addon.db[cbData.var]
		if cbData.subvar and db then db = db[cbData.subvar] end
		local default = type(cbData.default) == "function" and cbData.default() or cbData.default
		local col = db or default or { r = 0, g = 0, b = 0, a = 1 }
		return col.r or 0, col.g or 0, col.b or 0, col.a or 1
	end
	local function setColor(_, r, g, b, a)
		addon.db[cbData.var] = addon.db[cbData.var] or {}
		if cbData.subvar then
			addon.db[cbData.var][cbData.subvar] = { r = r, g = g, b = b, a = a }
		else
			addon.db[cbData.var] = { r = r, g = g, b = b, a = a }
		end
		if cbData.callback then cbData.callback(r, g, b, a) end
	end
	local function getDefaultColor()
		local default = type(cbData.default) == "function" and cbData.default() or cbData.default
		return default and default.r or 1, default and default.g or 1, default and default.b or 1, default and default.a or 1
	end
	local initializer = SettingsLib:CreateColorOverrides(cat, {
		key = cbData.var, -- eindeutiger Key
		headerText = cbData.text, -- Überschrift (optional)
		entries = entries,
		getColor = getColor,
		setColor = setColor,
		getDefaultColor = getDefaultColor,
		parent = cbData.element,
		parentCheck = cbData.parentCheck,
		searchtags = cbData.searchtags,
		notify = cbData.notify,
		parentSection = cbData.parentSection,
		prefix = prefix,
		colorizeLabel = cbData.colorizeLabel,
		hasOpacity = cbData.hasOpacity,
	})

	addon.SettingsLayout = addon.SettingsLayout or {}
	addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
	addon.SettingsLayout.elements[cbData.var] = { initializer = initializer }
	cbData.entries = entries
	cbData.getColor = getColor
	cbData.setColor = setColor
	cbData.getDefaultColor = getDefaultColor
	registerLegacyControl(cat, cbData, "colorpicker", nil)
	return initializer
end

function addon.functions.SettingsCreateExpandableSection(cat, cbData)
	local section = SettingsLib:CreateExpandableSection(cat, {
		name = cbData.name,
		expanded = cbData.expanded,
		searchtags = cbData.searchtags,
		colorizeTitle = cbData.colorizeTitle,
		titleColor = cbData.titleColor,
		extent = cbData.extent,
		newTagID = cbData.newTagID,
		prefix = prefix,
	})
	if cbData.var then
		addon.SettingsLayout = addon.SettingsLayout or {}
		addon.SettingsLayout.elements = addon.SettingsLayout.elements or {}
		addon.SettingsLayout.elements[cbData.var] = { initializer = section }
	end
	local app = ensureConfigApp()
	if app then
		local pageID = app:RegisterLegacySection(section, {
			category = cat,
			title = cbData.name,
			pageID = cbData.configPageID,
			order = cbData.order,
			description = cbData.description or cbData.desc,
			icon = cbData.icon,
			iconAtlas = cbData.iconAtlas,
			mainToggleID = cbData.mainToggleID,
			newTagID = cbData.newTagID,
		})
		if pageID then
			addon.ConfigCurrentGroupByPageID[pageID] = nil
			addon.ConfigGroupTitleByPageID[pageID] = nil
			addon.ConfigGroupOrderByPageID[pageID] = 0
		end
	end
	return section
end

local cat, layout = SettingsLib:CreateRootCategory(addonName, false)

addon.SettingsLayout.rootCategory = cat
addon.SettingsLayout.rootLayout = layout

ensureConfigApp()
