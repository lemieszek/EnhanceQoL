local MODULE_MAJOR, MINOR = "LibEQOLConfig-1.0", 1
local LibStub = _G.LibStub
assert(LibStub, MODULE_MAJOR .. " requires LibStub")

local lib = LibStub:NewLibrary(MODULE_MAJOR, MINOR)
if not lib then
	return
end
lib.MINOR = MINOR

local apps = lib.apps or {}
lib.apps = apps

local function wipeTable(tbl)
	if not tbl then
		return {}
	end
	for key in pairs(tbl) do
		tbl[key] = nil
	end
	return tbl
end

local function copyTable(source, target)
	target = target or {}
	if type(source) ~= "table" then
		return target
	end
	for key, value in pairs(source) do
		target[key] = value
	end
	return target
end

local function normalizeID(text)
	text = tostring(text or ""):lower()
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("[^%w]+", ".")
	text = text:gsub("^%.+", ""):gsub("%.+$", "")
	text = text:gsub("%.+", ".")
	if text == "" then
		text = "settings"
	end
	return text
end

local function normalizeSearchText(text)
	text = tostring(text or ""):lower()
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("[^%w]+", " ")
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

local function valuesEqual(a, b, depth)
	depth = (depth or 0) + 1
	if depth > 5 then
		return a == b
	end
	if a == b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return false
	end
	for key, value in pairs(a) do
		if not valuesEqual(value, b[key], depth) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function resolveControlDefault(control)
	if not control then
		return nil, false
	end
	if control.default ~= nil then
		if type(control.default) == "function" then
			local ok, value = pcall(control.default)
			if ok then
				return value, true
			end
			return nil, false
		end
		return control.default, true
	end
	if type(control.dbDefault) == "function" then
		local ok, value, hasDefault = pcall(control.dbDefault, control)
		if ok and (hasDefault == true or value ~= nil) then
			return value, true
		end
	elseif control.dbDefault ~= nil then
		return control.dbDefault, true
	end
	if control.setting then
		local methods = { "GetDefaultValue", "GetDefault" }
		for _, method in ipairs(methods) do
			if type(control.setting[method]) == "function" then
				local ok, value = pcall(control.setting[method], control.setting)
				if ok then
					return value, true
				end
			end
		end
	end
	return nil, false
end

local function getCategoryKey(category)
	if not category then
		return nil
	end
	if type(category) == "table" then
		if category.GetID then
			local ok, id = pcall(category.GetID, category)
			if ok and id ~= nil then
				return "id:" .. tostring(id)
			end
		end
		if category.GetName then
			local ok, name = pcall(category.GetName, category)
			if ok and name ~= nil then
				return "name:" .. tostring(name)
			end
		end
	end
	return tostring(category)
end

local function addSearchBlob(parts, value)
	if value == nil or value == false then
		return
	end
	if type(value) == "table" then
		for _, entry in ipairs(value) do
			addSearchBlob(parts, entry)
		end
		return
	end
	parts[#parts + 1] = normalizeSearchText(value)
end

local AppMixin = {}

local LEGACY_CONTROL_METADATA_FIELDS = {
	"buttonText",
	"callback",
	"clampToRange",
	"colorizeLabel",
	"customDefaultText",
	"customText",
	"dropdownDefault",
	"dropdownDesc",
	"dropdownFormatter",
	"dropdownGet",
	"dropdownKey",
	"dropdownList",
	"dropdownListFunc",
	"dropdownName",
	"dropdownOptionfunc",
	"dropdownOptions",
	"dropdownOrder",
	"dropdownSet",
	"dropdownSetting",
	"dropdownSuffix",
	"dropdownText",
	"dropdownValueFormatter",
	"dropdownValues",
	"entries",
	"formatter",
	"frameHeight",
	"frameWidth",
	"generator",
	"getColor",
	"getDefaultColor",
	"getPlaybackChannel",
	"getSelection",
	"groupID",
	"groupTitle",
	"hasOpacity",
	"height",
	"hideSummary",
	"inputWidth",
	"isMainToggle",
	"isSelected",
	"isSelectedFunc",
	"justifyH",
	"list",
	"listFunc",
	"max",
	"maxChars",
	"menuHeight",
	"min",
	"modernGroup",
	"multiline",
	"multilineHeight",
	"newTagID",
	"numeric",
	"onClick",
	"optionfunc",
	"options",
	"placeholder",
	"placeholderText",
	"playbackChannel",
	"previewSoundFunc",
	"previewTooltip",
	"readOnly",
	"orderList",
	"rowHeight",
	"setColor",
	"setSelected",
	"setSelectedFunc",
	"setSelection",
	"selectionSource",
	"soundResolver",
	"step",
	"subvar",
	"suffix",
	"summary",
	"tooltip",
	"uiRole",
	"valueFormatter",
	"values",
}

local function sortByOrderAndTitle(a, b)
	local ao = tonumber(a.order) or 1000
	local bo = tonumber(b.order) or 1000
	if ao ~= bo then
		return ao < bo
	end
	return tostring(a.title or a.id) < tostring(b.title or b.id)
end

local function rebuildSearchBlob(app, control)
	local parts = {}
	local page = app.pagesByID[control.pageID or ""]
	local group = page and page.groupsByID and page.groupsByID[control.groupID or ""]
	local category = page and app.categoriesByID[page.category or ""]
	addSearchBlob(parts, control.label or control.title or control.text or control.id)
	addSearchBlob(parts, control.description or control.desc)
	addSearchBlob(parts, control.key or control.settingKey)
	addSearchBlob(parts, control.keywords or control.searchtags)
	addSearchBlob(parts, page and page.title)
	addSearchBlob(parts, group and group.title)
	addSearchBlob(parts, category and category.title)
	control.searchBlob = table.concat(parts, " ")
end

function AppMixin:RegisterCategory(data)
	if type(data) ~= "table" or not data.id then
		return nil
	end
	local category = self.categoriesByID[data.id]
	if category then
		copyTable(data, category)
	else
		category = copyTable(data, {})
		self.categoriesByID[category.id] = category
		self.categories[#self.categories + 1] = category
	end
	table.sort(self.categories, sortByOrderAndTitle)
	return category
end

function AppMixin:RegisterPage(data)
	if type(data) ~= "table" or not data.id then
		return nil
	end
	local page = self.pagesByID[data.id]
	if page then
		copyTable(data, page)
	else
		page = copyTable(data, {})
		page.groups = page.groups or {}
		page.groupsByID = page.groupsByID or {}
		page.controls = page.controls or {}
		self.pagesByID[page.id] = page
		self.pages[#self.pages + 1] = page
	end
	if page.category and not self.categoriesByID[page.category] then
		self:RegisterCategory({ id = page.category, title = page.category, order = 1000 })
	end
	table.sort(self.pages, sortByOrderAndTitle)
	return page
end

function AppMixin:RegisterGroup(pageID, data)
	local page = self.pagesByID[pageID]
	if not page or type(data) ~= "table" then
		return nil
	end
	local id = data.id or normalizeID(data.title or data.name or "group")
	local group = page.groupsByID[id]
	if group then
		copyTable(data, group)
	else
		group = copyTable(data, { id = id, pageID = pageID })
		page.groupsByID[id] = group
		page.groups[#page.groups + 1] = group
	end
	table.sort(page.groups, sortByOrderAndTitle)
	return group
end

function AppMixin:RegisterControl(pageID, data)
	local page = self.pagesByID[pageID]
	if not page or type(data) ~= "table" then
		return nil
	end
	local id = data.id or data.key or data.var
	if not id or id == "" then
		id = pageID .. "." .. tostring(#self.controls + 1)
	end
	local control = self.controlsByID[id]
	if control then
		copyTable(data, control)
	else
		control = copyTable(data, { id = id })
		self.controlsByID[id] = control
		self.controls[#self.controls + 1] = control
		page.controls[#page.controls + 1] = control
	end
	control.pageID = pageID
	if control.groupID then
		self:RegisterGroup(pageID, { id = control.groupID, title = control.groupTitle or control.groupID })
	end
	rebuildSearchBlob(self, control)
	table.sort(page.controls, sortByOrderAndTitle)
	return control
end

function AppMixin:RegisterLegacyCategory(category, data)
	local key = getCategoryKey(category)
	if not key then
		return nil
	end
	data = data or {}
	local categoryID = data.categoryID or data.modernCategory or normalizeID(data.title or data.name or key)
	self.legacyCategories[key] = categoryID
	if data.title and not self.categoriesByID[categoryID] then
		self:RegisterCategory({
			id = categoryID,
			title = data.title,
			iconAtlas = data.iconAtlas,
			order = data.order,
		})
	end
	return categoryID
end

function AppMixin:RegisterLegacySection(section, data)
	if not section then
		return nil
	end
	data = data or {}
	local categoryID = data.categoryID
	if not categoryID then
		categoryID = self.legacyCategories[getCategoryKey(data.category)] or "advanced"
	end
	local pageID = data.pageID or (categoryID .. "." .. normalizeID(data.title or data.name or "settings"))
	local page = self:RegisterPage({
		id = pageID,
		category = categoryID,
		title = data.title or data.name or pageID,
		description = data.description,
		iconAtlas = data.iconAtlas,
		icon = data.icon,
		mainToggleID = data.mainToggleID,
		newTagID = data.newTagID,
		order = data.order or 500,
		legacy = true,
	})
	self.legacySections[section] = pageID
	return page and page.id
end

function AppMixin:RegisterLegacyControl(data)
	if type(data) ~= "table" then
		return nil
	end
	local pageID = data.pageID
	if not pageID and data.parentSection then
		pageID = self.legacySections[data.parentSection]
	end
	if not pageID and data.legacyCategory then
		local categoryID = self.legacyCategories[getCategoryKey(data.legacyCategory)] or "advanced"
		pageID = categoryID .. ".settings"
		self:RegisterPage({
			id = pageID,
			category = categoryID,
			title = data.legacyCategoryTitle or "Settings",
			order = 900,
			legacy = true,
		})
	end
	if not pageID then
		pageID = self.defaultPageID or "dashboard"
	end
	if not self.pagesByID[pageID] then
		self:RegisterPage({
			id = pageID,
			category = "advanced",
			title = pageID,
			order = 900,
			legacy = true,
		})
	end

	local control = {
		id = data.id or data.key or data.var,
		type = data.type or data.sType,
		label = data.label or data.text or data.name or data.key or data.var,
		description = data.description or data.desc,
		key = data.key or data.var,
		default = data.default,
		dbDefault = data.dbDefault,
		keywords = data.keywords or data.searchtags,
		level = data.level or "basic",
		order = data.order,
		setting = data.setting,
		getValue = data.getValue or data.get,
		setValue = data.setValue or data.set,
		parentCheck = data.parentCheck,
		isEnabled = data.isEnabled,
		legacy = true,
	}
	for _, field in ipairs(LEGACY_CONTROL_METADATA_FIELDS) do
		if data[field] ~= nil then
			control[field] = data[field]
		end
	end
	if control.modernGroup and not control.groupID then
		control.groupID = control.modernGroup
	end
	if not control.id or control.id == "" then
		control.id = pageID .. "." .. tostring(#self.controls + 1)
	end
	return self:RegisterControl(pageID, control)
end

function AppMixin:GetCategories()
	table.sort(self.categories, sortByOrderAndTitle)
	return self.categories
end

function AppMixin:GetPages(categoryID)
	local pages = wipeTable(self._tmpPages)
	for _, page in ipairs(self.pages) do
		if not categoryID or page.category == categoryID then
			pages[#pages + 1] = page
		end
	end
	table.sort(pages, sortByOrderAndTitle)
	return pages
end

function AppMixin:GetPage(pageID)
	return self.pagesByID[pageID]
end

function AppMixin:GetDefaultPageID()
	return self.defaultPageID or (self.pages[1] and self.pages[1].id)
end

function AppMixin:SetDefaultPage(pageID)
	self.defaultPageID = pageID
end

function AppMixin:GetControlValue(control)
	if control.setting and control.setting.GetValue then
		local ok, value = pcall(control.setting.GetValue, control.setting)
		if ok then
			return value
		end
	end
	if type(control.getSelection) == "function" then
		local ok, value = pcall(control.getSelection, control)
		if ok then
			return value
		end
		ok, value = pcall(control.getSelection)
		if ok then
			return value
		end
	end
	if type(control.getValue) == "function" then
		local ok, value = pcall(control.getValue)
		if ok then
			return value
		end
	end
	local db = self.opts and self.opts.db and self.opts.db()
	if type(db) == "table" and control.key ~= nil then
		return db[control.key]
	end
	return control.default
end

local function getEffectiveControlValue(app, control, default, hasDefault)
	local value = app:GetControlValue(control)
	if value == nil and hasDefault then
		return default
	end
	return value
end

function AppMixin:SetControlValue(control, value)
	if control.setting and control.setting.SetValue then
		local ok = pcall(control.setting.SetValue, control.setting, value)
		if ok then
			return true
		end
	end
	if type(control.setSelection) == "function" then
		local ok = pcall(control.setSelection, value, control)
		if ok then
			return true
		end
		ok = pcall(control.setSelection, value)
		if ok then
			return true
		end
	end
	if type(control.setValue) == "function" then
		local ok = pcall(control.setValue, value)
		if ok then
			return true
		end
		ok = pcall(control.setValue, nil, value)
		return ok == true
	end
	local db = self.opts and self.opts.db and self.opts.db()
	if type(db) == "table" and control.key ~= nil then
		db[control.key] = value
		return true
	end
	return false
end

function AppMixin:IsControlEnabled(control)
	local _ = self
	if type(control.isEnabled) == "function" then
		local ok, enabled = pcall(control.isEnabled)
		if ok and enabled == false then
			return false
		end
	end
	if type(control.parentCheck) == "function" then
		local ok, enabled = pcall(control.parentCheck)
		if ok and enabled == false then
			return false
		end
	end
	return true
end

function AppMixin:GetSearchResults(query, limit)
	query = normalizeSearchText(query)
	local results = wipeTable(self._tmpSearch)
	if query == "" then
		return results
	end
	local terms = {}
	for term in query:gmatch("%S+") do
		terms[#terms + 1] = term
	end
	for _, control in ipairs(self.controls) do
		local blob = control.searchBlob or ""
		local matched = true
		for _, term in ipairs(terms) do
			if not blob:find(term, 1, true) then
				matched = false
				break
			end
		end
		if matched then
			results[#results + 1] = control
			if limit and #results >= limit then
				break
			end
		end
	end
	return results
end

function AppMixin:IsControlCustomized(control)
	local default, hasDefault = resolveControlDefault(control)
	if not hasDefault then
		return false
	end
	local value = getEffectiveControlValue(self, control, default, hasDefault)
	return not valuesEqual(value, default)
end

function AppMixin:GetStats()
	local customized = 0
	local booleanTrue = 0
	local controlsWithDefaults = 0
	for _, control in ipairs(self.controls) do
		local default, hasDefault = resolveControlDefault(control)
		if hasDefault then
			controlsWithDefaults = controlsWithDefaults + 1
			if self:IsControlCustomized(control) then
				customized = customized + 1
			end
		end
		if control.type == "toggle" or control.type == "checkbox" then
			if getEffectiveControlValue(self, control, default, hasDefault) == true then
				booleanTrue = booleanTrue + 1
			end
		end
	end
	return {
		categories = #self.categories,
		pages = #self.pages,
		controls = #self.controls,
		customized = customized,
		customizable = controlsWithDefaults,
		booleanTrue = booleanTrue,
		enabled = customized,
	}
end

function lib:RegisterAddOn(id, opts)
	local _ = self
	assert(id, "addon id required")
	local app = apps[id]
	if app then
		app.opts = opts or app.opts or {}
		return app
	end
	app = {
		id = id,
		opts = opts or {},
		categories = {},
		categoriesByID = {},
		pages = {},
		pagesByID = {},
		controls = {},
		controlsByID = {},
		legacyCategories = {},
		legacySections = {},
		_tmpPages = {},
		_tmpSearch = {},
	}
	for key, value in pairs(AppMixin) do
		app[key] = value
	end
	apps[id] = app
	return app
end

function lib:GetAddOn(id)
	local _ = self
	return apps[id]
end

function lib:NormalizeID(text)
	local _ = self
	return normalizeID(text)
end
