local addonName, addon = ...

addon.DurationText = addon.DurationText or {}
addon.functions = addon.functions or {}

local DurationText = addon.DurationText
local EMPTY_TABLE = {}
local DEFAULT_PROFILE_KEY = "MINIMAL"

DurationText.defaults = {
	abbreviation = "ONE_LETTER",
	approximationSeconds = 0,
	bindingUpdateInterval = 0.1,
	canRoundUpIntervals = true,
	canRoundUpLastUnit = false,
	convertToLower = false,
	desiredUnitCount = 1,
	expiredText = "",
	formatStyle = "NUMERIC",
	maxInterval = "DAYS",
	millisecondsThreshold = 10,
	minInterval = "SECONDS",
	stripIntervalWhitespace = "PRESERVE",
	zeroDurationText = "",
}
DurationText.defaultProfileKey = DEFAULT_PROFILE_KEY
DurationText.profileOrder = { DEFAULT_PROFILE_KEY, "PRECISE" }
DurationText.protectedProfileKeys = {
	MINIMAL = true,
	PRECISE = true,
}
DurationText.profileDefaults = {
	MINIMAL = {
		abbreviation = "ONE_LETTER",
		approximationSeconds = 0,
		bindingUpdateInterval = 0.2,
		canRoundUpIntervals = true,
		canRoundUpLastUnit = false,
		convertToLower = true,
		desiredUnitCount = 1,
		expiredText = "",
		formatStyle = "NUMERIC",
		maxInterval = "DAYS",
		millisecondsThreshold = 0,
		minInterval = "SECONDS",
		stripIntervalWhitespace = "STRIP",
		zeroDurationText = "",
	},
	PRECISE = {
		abbreviation = "NONE",
		approximationSeconds = 0,
		bindingUpdateInterval = 0.05,
		canRoundUpIntervals = false,
		canRoundUpLastUnit = false,
		convertToLower = false,
		desiredUnitCount = 2,
		expiredText = "",
		formatStyle = "UNITS",
		maxInterval = "DAYS",
		millisecondsThreshold = 10,
		minInterval = "SECONDS",
		stripIntervalWhitespace = "PRESERVE",
		zeroDurationText = "",
	},
}

local INTERVAL_FALLBACK = {
	SECONDS = 0,
	MINUTES = 1,
	HOURS = 2,
	DAYS = 3,
}
local ABBREVIATION_FALLBACK = {
	NONE = 0,
	TRUNCATE = 1,
	ONE_LETTER = 2,
}
local WHITESPACE_FALLBACK = {
	PRESERVE = 0,
	STRIP = 1,
	STRIP_IGNORE_LOCALE = 2,
}
local ROUNDING_FALLBACK = {
	DOWN = 2,
	NEAREST = 0,
	UP = 1,
}
local DURATION_TEXT_BINDING_PROPERTIES = {
	ElapsedDuration = 2,
	ElapsedPercent = 3,
	EndTime = 6,
	RemainingDuration = 0,
	RemainingPercent = 1,
	StartTime = 5,
	TotalDuration = 4,
}
local DURATION_TEXT_BINDING_PROPERTY_ALIASES = {
	ELAPSED = "ElapsedDuration",
	ELAPSEDDURATION = "ElapsedDuration",
	ELAPSEDPERCENT = "ElapsedPercent",
	END = "EndTime",
	ENDTIME = "EndTime",
	PERCENT = "RemainingPercent",
	REMAINING = "RemainingDuration",
	REMAININGDURATION = "RemainingDuration",
	REMAININGPERCENT = "RemainingPercent",
	START = "StartTime",
	STARTTIME = "StartTime",
	TOTAL = "TotalDuration",
	TOTALDURATION = "TotalDuration",
}

local function copyDefaultTable(source)
	local target = {}
	for key, value in pairs(source or EMPTY_TABLE) do
		target[key] = value
	end
	return target
end

local function trimProfileName(name)
	if type(name) ~= "string" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil end
	return name
end

local function isConfigKey(key)
	return DurationText.defaults[key] ~= nil
end

local function createProfileStore(defaults)
	local store = {
		activeProfile = DEFAULT_PROFILE_KEY,
		editProfile = DEFAULT_PROFILE_KEY,
		profileNames = {},
		profileOrder = {},
		profiles = {},
	}
	for _, key in ipairs(DurationText.profileOrder) do
		local profileDefaults = defaults and defaults[key] or nil
		store.profiles[key] = copyDefaultTable(profileDefaults)
		store.profileOrder[#store.profileOrder + 1] = key
	end
	return store
end

local function normalizeProfileConfig(profile, defaults)
	if type(profile) ~= "table" then profile = {} end
	defaults = defaults or DurationText.defaults
	for key, value in pairs(defaults) do
		if profile[key] == nil then profile[key] = value end
	end
	for key, value in pairs(DurationText.defaults) do
		if profile[key] == nil then profile[key] = value end
	end
	for key in pairs(profile) do
		if not isConfigKey(key) then profile[key] = nil end
	end
	return profile
end

local function normalizeProfileKey(key)
	if type(key) ~= "string" then return nil end
	key = key:gsub("^%s+", ""):gsub("%s+$", ""):upper()
	if key == "" then return nil end
	return key
end

local function profileKeyFromName(name)
	name = trimProfileName(name)
	if not name then return nil end
	return name:upper()
end

local function hasOrderKey(order, key)
	if type(order) ~= "table" then return false end
	for i = 1, #order do
		if order[i] == key then return true end
	end
	return false
end

local function removeOrderKey(order, key)
	if type(order) ~= "table" then return end
	for i = #order, 1, -1 do
		if order[i] == key then table.remove(order, i) end
	end
end

local function appendOrderedKey(order, key)
	if type(order) ~= "table" then return end
	if key and not hasOrderKey(order, key) then order[#order + 1] = key end
end

local function getFirstProfileKey(db, excludedKey)
	if type(db) ~= "table" or type(db.profiles) ~= "table" then return nil end
	for _, key in ipairs(db.profileOrder or EMPTY_TABLE) do
		if key ~= excludedKey and type(db.profiles[key]) == "table" then return key end
	end
	for key, profile in pairs(db.profiles) do
		if key ~= excludedKey and type(profile) == "table" then return key end
	end
	return nil
end

local function profileMatches(value, profileKey)
	return normalizeProfileKey(value) == profileKey
end

local function getUsageLabel(path, key)
	path = tostring(path or "")
	key = tostring(key or "")
	if path:find("^cooldownPanels%.panels%.[^%.]+%.entries%.") then return "durationTextUsageCooldownPanelEntries" end
	if path:find("^cooldownPanels%.panels%.") and key == "durationTextProfile" then return "durationTextUsageCooldownPanelDefaults" end
	if path:find("^cooldownPanels%.panels%.") and key == "barDurationTextProfile" then return "durationTextUsageCooldownPanelDefaults" end
	if path:find("^personalResourceBarSettings") then return "durationTextUsageResourceBarsPersonal" end
	if path:find("^globalResourceBarSettings") then return "durationTextUsageResourceBarsGlobal" end
	if path:find("^sharedResourceBarSettings") then return "durationTextUsageResourceBarsShared" end
	if key == "barDurationTextProfile" then return "durationTextUsageCooldownPanels" end
	if key == "durationTextProfile" then return "durationTextUsageResourceBars" end
	return path ~= "" and path or key
end

local function addUsage(usages, label)
	usages.count = (usages.count or 0) + 1
	usages.byLabel = usages.byLabel or {}
	usages.order = usages.order or {}
	if not usages.byLabel[label] then usages.order[#usages.order + 1] = label end
	usages.byLabel[label] = (usages.byLabel[label] or 0) + 1
end

local function scanDurationTextProfileFields(root, profileKey, replacementKey, usages)
	if type(root) ~= "table" then return 0 end
	local changed = 0
	local seen = {}
	local function walk(tbl, path)
		if type(tbl) ~= "table" or seen[tbl] then return end
		seen[tbl] = true
		for key, value in pairs(tbl) do
			if tbl == root and key == "durationText" then
				-- The profile definitions themselves are not consumer references.
			elseif (key == "barDurationTextProfile" or key == "durationTextProfile") and profileMatches(value, profileKey) then
				addUsage(usages, getUsageLabel(path, key))
				if replacementKey then
					tbl[key] = replacementKey
					changed = changed + 1
				end
			elseif type(value) == "table" then
				local childPath = path ~= "" and (path .. "." .. tostring(key)) or tostring(key)
				walk(value, childPath)
			end
		end
	end
	walk(root, "")
	return changed
end

local function normalizeKey(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("[_%-%s]", ""):upper()
	if value == "ONELETTER" then return "ONE_LETTER" end
	if value == "STRIPIGNORELOCALE" then return "STRIP_IGNORE_LOCALE" end
	return value
end

local function getEnumValue(enumTable, key, fallback)
	if type(key) == "number" then return key end
	key = normalizeKey(key)
	if not key then return nil end
	if enumTable then
		local enumKey = key:gsub("_(%a)", function(letter) return letter end):lower()
		enumKey = enumKey:gsub("^%l", string.upper)
		enumKey = enumKey:gsub("(%l)(%u)", "%1%2")
		if key == "ONE_LETTER" then enumKey = "OneLetter" end
		if key == "STRIP_IGNORE_LOCALE" then enumKey = "StripIgnoreLocale" end
		if key == "SECONDS" then enumKey = "Seconds" end
		if key == "MINUTES" then enumKey = "Minutes" end
		if key == "HOURS" then enumKey = "Hours" end
		if key == "DAYS" then enumKey = "Days" end
		if key == "TRUNCATE" then enumKey = "Truncate" end
		if key == "PRESERVE" then enumKey = "Preserve" end
		if key == "STRIP" then enumKey = "Strip" end
		if key == "NONE" then enumKey = "None" end
		if enumTable[enumKey] ~= nil then return enumTable[enumKey] end
	end
	return fallback and fallback[key] or nil
end

local function getSecondsFormatterAPI()
	local stringUtil = _G.C_StringUtil
	if stringUtil and stringUtil.CreateSecondsFormatter then return stringUtil end
	return nil
end

local function getNumericRuleFormatterAPI()
	local stringUtil = _G.C_StringUtil
	if stringUtil and stringUtil.CreateNumericRuleFormatter then return stringUtil end
	return nil
end

local function getDurationTextBindingAPI()
	local durationUtil = _G.C_DurationUtil
	if durationUtil and durationUtil.CreateDurationTextBinding then return durationUtil end
	return nil
end

local function getDurationTextBindingStore(owner, create)
	if type(owner) ~= "table" then return nil end
	local store = owner._eqolDurationTextBindings
	if not store and create then
		store = {}
		owner._eqolDurationTextBindings = store
	end
	return store
end

local function setDurationTextBindingEnabled(binding, enabled)
	if not binding then return false end
	if binding.SetEnabled then
		binding:SetEnabled(enabled == true)
	elseif enabled == true and binding.Enable then
		binding:Enable()
	elseif binding.Disable then
		binding:Disable()
	end
	return true
end

local function releaseDurationTextBinding(binding, clearText)
	if not binding then return false end
	local fontString = binding.GetFontString and binding:GetFontString() or nil
	if binding.Disable then binding:Disable() end
	if binding.SetToDefaults then binding:SetToDefaults() end
	if clearText and fontString and fontString.SetText then fontString:SetText("") end
	return true
end

function DurationText:InitDB()
	addon.db = addon.db or {}
	addon.dbDefaults = addon.dbDefaults or {}
	addon.dbDefaults.durationText = createProfileStore(self.profileDefaults)
	if type(addon.db.durationText) ~= "table" or type(addon.db.durationText.profiles) ~= "table" then addon.db.durationText = createProfileStore(self.profileDefaults) end

	local db = addon.db.durationText
	if type(db.profileNames) ~= "table" then db.profileNames = {} end
	if type(db.profileOrder) ~= "table" then db.profileOrder = {} end
	db.activeProfile = normalizeProfileKey(db.activeProfile) or DEFAULT_PROFILE_KEY
	db.editProfile = normalizeProfileKey(db.editProfile) or db.activeProfile
	for _, key in ipairs(self.profileOrder) do
		if type(db.profiles[key]) ~= "table" then db.profiles[key] = copyDefaultTable(self.profileDefaults[key] or self.defaults) end
		appendOrderedKey(db.profileOrder, key)
	end
	for key, profile in pairs(db.profiles) do
		local normalizedKey = normalizeProfileKey(key)
		if normalizedKey and normalizedKey ~= key then
			db.profiles[normalizedKey] = normalizeProfileConfig(db.profiles[normalizedKey] or profile, self.profileDefaults[normalizedKey])
			if db.profileNames[key] and not db.profileNames[normalizedKey] then db.profileNames[normalizedKey] = db.profileNames[key] end
			db.profileNames[key] = nil
			removeOrderKey(db.profileOrder, key)
			appendOrderedKey(db.profileOrder, normalizedKey)
			db.profiles[key] = nil
		elseif not normalizedKey then
			db.profiles[key] = nil
		else
			db.profiles[key] = normalizeProfileConfig(profile, self.profileDefaults[key])
			appendOrderedKey(db.profileOrder, key)
		end
	end
	for key in pairs(db.profileNames) do
		if not db.profiles[key] then db.profileNames[key] = nil end
	end
	for i = #db.profileOrder, 1, -1 do
		if not db.profiles[db.profileOrder[i]] then table.remove(db.profileOrder, i) end
	end
	if not getFirstProfileKey(db) then
		db.profiles[DEFAULT_PROFILE_KEY] = copyDefaultTable(self.profileDefaults[DEFAULT_PROFILE_KEY] or self.defaults)
		appendOrderedKey(db.profileOrder, DEFAULT_PROFILE_KEY)
	end
	if not db.profiles[db.activeProfile] then db.activeProfile = DEFAULT_PROFILE_KEY end
	if not db.profiles[db.activeProfile] then db.activeProfile = getFirstProfileKey(db) end
	if not db.profiles[db.editProfile] then db.editProfile = db.activeProfile or getFirstProfileKey(db) end
end

function DurationText:Invalidate()
	self.formatterCache = {}
	self.version = (self.version or 0) + 1
end

function DurationText:GetProfileKey(profileKey)
	self:InitDB()
	profileKey = normalizeProfileKey(profileKey) or addon.db.durationText.activeProfile or DEFAULT_PROFILE_KEY
	if not addon.db.durationText.profiles[profileKey] then
		profileKey = addon.db.durationText.profiles[DEFAULT_PROFILE_KEY] and DEFAULT_PROFILE_KEY or getFirstProfileKey(addon.db.durationText)
	end
	return profileKey
end

function DurationText:GetProfileConfig(profileKey)
	self:InitDB()
	local key = self:GetProfileKey(profileKey)
	return addon.db.durationText.profiles[key], key
end

function DurationText:GetGlobalConfig()
	return self:GetProfileConfig()
end

function DurationText:GetEffectiveConfig(scopeConfig)
	if type(scopeConfig) == "string" then return self:GetProfileConfig(scopeConfig) end
	local globalConfig = self:GetProfileConfig(type(scopeConfig) == "table" and scopeConfig.profileKey or nil)
	if type(scopeConfig) ~= "table" or scopeConfig.useGlobal ~= false then return globalConfig end
	local effective = {}
	for key, value in pairs(globalConfig) do
		effective[key] = value
	end
	for key, value in pairs(scopeConfig) do
		if key ~= "useGlobal" and key ~= "profileKey" and value ~= nil then effective[key] = value end
	end
	return effective
end

function DurationText:GetProfileLabel(profileKey)
	profileKey = normalizeProfileKey(profileKey) or DEFAULT_PROFILE_KEY
	local db = addon.db and addon.db.durationText or nil
	if db and db.profileNames and db.profileNames[profileKey] then return db.profileNames[profileKey] end
	local L = LibStub and LibStub("AceLocale-3.0"):GetLocale(addonName, true) or nil
	if profileKey == "MINIMAL" then return L and L["durationTextProfileMinimal"] or "Minimal" end
	if profileKey == "PRECISE" then return L and L["durationTextProfilePrecise"] or "Precise" end
	return profileKey
end

function DurationText:GetProfileOptions()
	self:InitDB()
	local options = {}
	for _, key in ipairs(addon.db.durationText.profileOrder or EMPTY_TABLE) do
		if addon.db.durationText.profiles[key] then options[#options + 1] = { value = key, label = self:GetProfileLabel(key) } end
	end
	return options
end

function DurationText:GetProfileDropdownData()
	self:InitDB()
	local list, order = {}, {}
	for _, option in ipairs(self:GetProfileOptions()) do
		list[option.value] = option.label
		order[#order + 1] = option.value
	end
	return list, order
end

function DurationText:IsProfileProtected(profileKey)
	profileKey = normalizeProfileKey(profileKey)
	return profileKey and self.protectedProfileKeys and self.protectedProfileKeys[profileKey] == true or false
end

function DurationText:GetEditProfileKey()
	self:InitDB()
	return self:GetProfileKey(addon.db.durationText.editProfile)
end

function DurationText:SetEditProfileKey(profileKey)
	self:InitDB()
	profileKey = self:GetProfileKey(profileKey)
	addon.db.durationText.editProfile = profileKey
	self:Invalidate()
end

function DurationText:GetProfileValue(profileKey, key)
	local profile = self:GetProfileConfig(profileKey)
	return profile and profile[key] or nil
end

function DurationText:SetProfileValue(profileKey, key, value)
	if not isConfigKey(key) then return end
	local profile = self:GetProfileConfig(profileKey)
	if not profile then return end
	profile[key] = value
	self:Invalidate()
end

function DurationText:ResetProfile(profileKey)
	self:InitDB()
	profileKey = self:GetProfileKey(profileKey)
	addon.db.durationText.profiles[profileKey] = copyDefaultTable(self.profileDefaults[profileKey] or self.defaults)
	self:Invalidate()
end

function DurationText:GetCreateProfileKey(name)
	return profileKeyFromName(name)
end

function DurationText:CreateProfile(name, sourceProfileKey)
	self:InitDB()
	name = trimProfileName(name)
	local profileKey = profileKeyFromName(name)
	if not profileKey then return false, "INVALID_NAME" end
	if addon.db.durationText.profiles[profileKey] then return false, "EXISTS", profileKey end
	local source = sourceProfileKey and self:GetProfileConfig(sourceProfileKey) or nil
	addon.db.durationText.profiles[profileKey] = copyDefaultTable(source or self.defaults)
	addon.db.durationText.profileNames[profileKey] = name
	appendOrderedKey(addon.db.durationText.profileOrder, profileKey)
	addon.db.durationText.editProfile = profileKey
	self:Invalidate()
	return true, profileKey
end

function DurationText:CopyProfile(sourceProfileKey, name)
	return self:CreateProfile(name, sourceProfileKey)
end

function DurationText:GetReplacementProfileKey(profileKey)
	self:InitDB()
	profileKey = self:GetProfileKey(profileKey)
	return getFirstProfileKey(addon.db.durationText, profileKey)
end

function DurationText:GetProfileUsage(profileKey)
	self:InitDB()
	profileKey = self:GetProfileKey(profileKey)
	local usages = { count = 0 }
	scanDurationTextProfileFields(addon.db, profileKey, nil, usages)
	return usages
end

function DurationText:RefreshConsumers()
	local aura = addon.Aura
	local cooldownPanels = aura and aura.CooldownPanels or nil
	if cooldownPanels and cooldownPanels.RefreshAllPanels then cooldownPanels:RefreshAllPanels(true) end
	local resourceBars = aura and aura.ResourceBars or nil
	if resourceBars and resourceBars.QueueRefresh then resourceBars.QueueRefresh(nil, { force = true, structural = true }) elseif resourceBars and resourceBars.Refresh then resourceBars.Refresh() end
end

function DurationText:DeleteProfile(profileKey, replacementKey)
	self:InitDB()
	profileKey = self:GetProfileKey(profileKey)
	if self:IsProfileProtected(profileKey) then return false, "PROTECTED_PROFILE" end
	replacementKey = self:GetProfileKey(replacementKey or self:GetReplacementProfileKey(profileKey))
	if profileKey == replacementKey then replacementKey = self:GetReplacementProfileKey(profileKey) end
	if not replacementKey then return false, "LAST_PROFILE" end
	local usages = self:GetProfileUsage(profileKey)
	local changed = scanDurationTextProfileFields(addon.db, profileKey, replacementKey, { count = 0 })
	addon.db.durationText.profiles[profileKey] = nil
	addon.db.durationText.profileNames[profileKey] = nil
	removeOrderKey(addon.db.durationText.profileOrder, profileKey)
	if addon.db.durationText.activeProfile == profileKey then addon.db.durationText.activeProfile = replacementKey end
	if addon.db.durationText.editProfile == profileKey then addon.db.durationText.editProfile = replacementKey end
	self:Invalidate()
	self:RefreshConsumers()
	return true, replacementKey, usages, changed
end

function DurationText:GetIntervalValue(key)
	return getEnumValue(_G.Enum and _G.Enum.SecondsFormatterInterval, key, INTERVAL_FALLBACK)
end

function DurationText:GetAbbreviationValue(key)
	return getEnumValue(_G.Enum and _G.Enum.SecondsFormatterAbbreviation, key, ABBREVIATION_FALLBACK)
end

function DurationText:GetWhitespaceValue(key)
	return getEnumValue(_G.Enum and _G.Enum.SecondsFormatterIntervalWhitespace, key, WHITESPACE_FALLBACK)
end

function DurationText:GetRoundingValue(key)
	return getEnumValue(_G.Enum and _G.Enum.NumericRuleFormatRounding, key, ROUNDING_FALLBACK)
end

function DurationText:GetCacheKey(config)
	config = config or self:GetGlobalConfig()
	return table.concat({
		tostring(config.abbreviation),
		tostring(config.approximationSeconds),
		tostring(config.canRoundUpIntervals),
		tostring(config.canRoundUpLastUnit),
		tostring(config.convertToLower),
		tostring(config.desiredUnitCount),
		tostring(config.formatStyle),
		tostring(config.maxInterval),
		tostring(config.millisecondsThreshold),
		tostring(config.minInterval),
		tostring(config.stripIntervalWhitespace),
	}, "|")
end

function DurationText:CreateSecondsFormatter(config)
	local api = getSecondsFormatterAPI()
	if not api then return nil end
	config = config or self:GetGlobalConfig()
	local formatter = api.CreateSecondsFormatter()
	if formatter.Reset then formatter:Reset() end
	if formatter.SetDefaultAbbreviation then formatter:SetDefaultAbbreviation(self:GetAbbreviationValue(config.abbreviation) or self:GetAbbreviationValue(self.defaults.abbreviation)) end
	if formatter.SetMillisecondsThreshold then formatter:SetMillisecondsThreshold(tonumber(config.millisecondsThreshold) or self.defaults.millisecondsThreshold) end
	if formatter.SetApproximationSeconds then formatter:SetApproximationSeconds(tonumber(config.approximationSeconds) or self.defaults.approximationSeconds) end
	if formatter.SetDesiredUnitCount then formatter:SetDesiredUnitCount(tonumber(config.desiredUnitCount) or self.defaults.desiredUnitCount) end
	if formatter.SetMinInterval then formatter:SetMinInterval(self:GetIntervalValue(config.minInterval) or self:GetIntervalValue(self.defaults.minInterval)) end
	if formatter.SetMaxInterval then formatter:SetMaxInterval(self:GetIntervalValue(config.maxInterval) or self:GetIntervalValue(self.defaults.maxInterval)) end
	if formatter.SetCanRoundUpIntervals then formatter:SetCanRoundUpIntervals(config.canRoundUpIntervals == true) end
	if formatter.SetCanRoundUpLastUnit then formatter:SetCanRoundUpLastUnit(config.canRoundUpLastUnit == true) end
	if formatter.SetConvertToLower then formatter:SetConvertToLower(config.convertToLower == true) end
	if formatter.SetStripIntervalWhitespace then formatter:SetStripIntervalWhitespace(self:GetWhitespaceValue(config.stripIntervalWhitespace) or self:GetWhitespaceValue(self.defaults.stripIntervalWhitespace)) end
	return formatter
end

function DurationText:CreateNumericFormatter(config)
	local api = getNumericRuleFormatterAPI()
	if not api then return nil end
	config = config or self:GetGlobalConfig()
	local formatter = api.CreateNumericRuleFormatter()
	if formatter.ClearBreakpoints then formatter:ClearBreakpoints() end
	local decimalThreshold = tonumber(config.millisecondsThreshold) or self.defaults.millisecondsThreshold
	local nearest = self:GetRoundingValue("NEAREST") or 0
	local up = self:GetRoundingValue("UP") or nearest
	local down = self:GetRoundingValue("DOWN") or nearest
	local rounding = config.canRoundUpIntervals == true and up or down
	local breakpoints = {}
	if decimalThreshold and decimalThreshold > 0 then
		breakpoints[#breakpoints + 1] = {
			threshold = 0,
			step = 0.1,
			format = "%.1f",
			rounding = rounding,
		}
	end
	breakpoints[#breakpoints + 1] = {
		threshold = decimalThreshold and decimalThreshold > 0 and decimalThreshold or 0,
		step = 1,
		format = "%.0f",
		rounding = rounding,
	}
	if formatter.SetBreakpoints then
		formatter:SetBreakpoints(breakpoints)
	elseif formatter.AddBreakpoint then
		for i = 1, #breakpoints do
			formatter:AddBreakpoint(breakpoints[i])
		end
	end
	return formatter
end

function DurationText:GetSecondsFormatter(config)
	config = config or self:GetGlobalConfig()
	local cacheKey = self:GetCacheKey(config)
	self.formatterCache = self.formatterCache or {}
	if not self.formatterCache[cacheKey] then
		if config.formatStyle == "UNITS" then
			self.formatterCache[cacheKey] = self:CreateSecondsFormatter(config)
		else
			self.formatterCache[cacheKey] = self:CreateNumericFormatter(config) or self:CreateSecondsFormatter(config)
		end
	end
	return self.formatterCache[cacheKey]
end

function DurationText:GetCooldownFrameFormatter(config)
	config = config or self:GetGlobalConfig()
	local cacheKey = "cooldown|" .. self:GetCacheKey(config)
	self.formatterCache = self.formatterCache or {}
	if not self.formatterCache[cacheKey] then
		self.formatterCache[cacheKey] = self:CreateNumericFormatter(config)
	end
	return self.formatterCache[cacheKey]
end

function DurationText:FormatSeconds(seconds, config, abbreviation)
	config = self:GetEffectiveConfig(config)
	local formatter = self:GetSecondsFormatter(config)
	if formatter and formatter.Format then return formatter:Format(seconds, abbreviation) end
	if formatter and formatter.FormatNumber then return formatter:FormatNumber(seconds or 0) end
	return tostring(seconds or "")
end

function DurationText:IsDurationTextBindingSupported()
	return getDurationTextBindingAPI() ~= nil
end

function DurationText:GetDurationTextBindingProperty(property)
	if type(property) == "number" then return property end
	if type(property) ~= "string" then return nil end
	local normalized = property:gsub("[_%-%s]", ""):upper()
	local key = DURATION_TEXT_BINDING_PROPERTY_ALIASES[normalized] or property
	local enum = _G.Enum and _G.Enum.DurationTextBindingProperty or nil
	if enum and enum[key] ~= nil then return enum[key] end
	return DURATION_TEXT_BINDING_PROPERTIES[key]
end

function DurationText:CreateFormatComponent(property, formatter)
	local resolvedProperty = self:GetDurationTextBindingProperty(property)
	if resolvedProperty == nil or formatter == nil then return nil end
	return {
		property = resolvedProperty,
		formatter = formatter,
	}
end

function DurationText:CreateRemainingDurationComponent(config)
	config = self:GetEffectiveConfig(config)
	local formatter = self:GetSecondsFormatter(config)
	return self:CreateFormatComponent("RemainingDuration", formatter)
end

function DurationText:CreateTotalDurationComponent(config)
	config = self:GetEffectiveConfig(config)
	local formatter = self:GetSecondsFormatter(config)
	return self:CreateFormatComponent("TotalDuration", formatter)
end

function DurationText:GetBinding(owner, key)
	local store = getDurationTextBindingStore(owner, false)
	return store and store[key or "default"] or nil
end

function DurationText:EnsureBinding(owner, key)
	local durationUtil = getDurationTextBindingAPI()
	if not durationUtil then return nil, false end
	local store = getDurationTextBindingStore(owner, true)
	if not store then return nil, false end
	key = key or "default"
	local binding = store[key]
	if not binding then
		binding = durationUtil.CreateDurationTextBinding()
		store[key] = binding
	end
	return binding, true
end

function DurationText:ReleaseBinding(owner, key, clearText)
	local store = getDurationTextBindingStore(owner, false)
	if not store then return false end
	key = key or "default"
	local binding = store[key]
	store[key] = nil
	return releaseDurationTextBinding(binding, clearText)
end

function DurationText:ReleaseBindings(owner, clearText)
	local store = getDurationTextBindingStore(owner, false)
	if not store then return false end
	for key, binding in pairs(store) do
		releaseDurationTextBinding(binding, clearText)
		store[key] = nil
	end
	return true
end

function DurationText:SetBindingEnabled(owner, key, enabled)
	return setDurationTextBindingEnabled(self:GetBinding(owner, key), enabled == true)
end

function DurationText:UpdateBinding(owner, key)
	local binding = self:GetBinding(owner, key)
	if binding and binding.UpdateFontString then
		binding:UpdateFontString()
		return true
	end
	return false
end

function DurationText:GetBindingState(owner, key)
	local binding = self:GetBinding(owner, key)
	if not binding then return nil end
	return {
		canFormatText = binding.CanFormatText and binding:CanFormatText() or false,
		canUpdateFontString = binding.CanUpdateFontString and binding:CanUpdateFontString() or false,
		duration = binding.GetDuration and binding:GetDuration() or nil,
		enabled = binding.IsEnabled and binding:IsEnabled() or false,
		expiredText = binding.GetExpiredText and binding:GetExpiredText() or nil,
		fontString = binding.GetFontString and binding:GetFontString() or nil,
		hasSecretValues = binding.HasSecretValues and binding:HasSecretValues() or false,
		timeModifier = binding.GetTimeModifier and binding:GetTimeModifier() or nil,
		updateInterval = binding.GetUpdateInterval and binding:GetUpdateInterval() or nil,
		zeroDurationText = binding.GetZeroDurationText and binding:GetZeroDurationText() or nil,
	}
end

function DurationText:ConfigureBinding(owner, key, fontString, durationObject, options)
	options = options or EMPTY_TABLE
	if not (fontString and durationObject) then
		if options.releaseOnMissing ~= false then self:ReleaseBinding(owner, key, options.clearText == true) end
		return nil, false
	end

	local config = self:GetEffectiveConfig(options.config or options.profileKey)
	local formatter = options.formatter or self:GetSecondsFormatter(config)
	local binding = self:EnsureBinding(owner, key)
	if not binding then return nil, false end
	if options.reset == true and binding.SetToDefaults then binding:SetToDefaults() end
	if binding.SetFontString then binding:SetFontString(fontString) end
	if binding.SetDuration then binding:SetDuration(durationObject) end
	if binding.SetTimeModifier then binding:SetTimeModifier(options.timeModifier or (_G.Enum and _G.Enum.DurationTimeModifier and _G.Enum.DurationTimeModifier.RealTime or 0)) end
	if binding.SetUpdateInterval then binding:SetUpdateInterval(options.updateInterval or tonumber(config.bindingUpdateInterval) or self.defaults.bindingUpdateInterval) end
	if binding.SetZeroDurationText then binding:SetZeroDurationText(options.zeroDurationText ~= nil and options.zeroDurationText or config.zeroDurationText) end
	if binding.SetExpiredText then binding:SetExpiredText(options.expiredText ~= nil and options.expiredText or config.expiredText) end
	if options.textFormat ~= nil and options.components ~= nil and binding.SetTextFormat then
		binding:SetTextFormat(options.textFormat, options.components)
	elseif formatter and binding.SetFormatter then
		binding:SetFormatter(formatter)
	end

	setDurationTextBindingEnabled(binding, options.enabled ~= false)
	if options.updateNow ~= false and binding.UpdateFontString then binding:UpdateFontString() end
	return binding, true
end

function DurationText:BindFontString(fontString, durationObject, options)
	options = options or EMPTY_TABLE
	local owner = options.owner or fontString
	return self:ConfigureBinding(owner, options.key or "default", fontString, durationObject, options)
end

function DurationText:ApplyToCooldownFrame(cooldownFrame, config)
	if not cooldownFrame then return false end
	config = self:GetEffectiveConfig(config)
	local formatter = self:GetCooldownFrameFormatter(config)
	if formatter and cooldownFrame.SetCountdownFormatter then cooldownFrame:SetCountdownFormatter(formatter) end
	if cooldownFrame.SetCountdownMillisecondsThreshold then cooldownFrame:SetCountdownMillisecondsThreshold(tonumber(config.millisecondsThreshold) or self.defaults.millisecondsThreshold) end
	if cooldownFrame.SetCountdownAbbrevThreshold then cooldownFrame:SetCountdownAbbrevThreshold(tonumber(config.approximationSeconds) or self.defaults.approximationSeconds) end
	return formatter ~= nil
end

function DurationText:ApplyProfileToCooldownFrame(cooldownFrame, profileKey)
	local _, resolvedProfileKey = self:GetProfileConfig(profileKey)
	return self:ApplyToCooldownFrame(cooldownFrame, resolvedProfileKey)
end

function addon.functions.IsDurationTextBindingSupported() return DurationText:IsDurationTextBindingSupported() end
function addon.functions.GetDurationTextBindingProperty(property) return DurationText:GetDurationTextBindingProperty(property) end
function addon.functions.GetDurationTextProfileDropdownData() return DurationText:GetProfileDropdownData() end
function addon.functions.GetDurationTextProfileOptions() return DurationText:GetProfileOptions() end
function addon.functions.GetDurationTextProfileValue(profileKey, key) return DurationText:GetProfileValue(profileKey, key) end
function addon.functions.SetDurationTextProfileValue(profileKey, key, value) return DurationText:SetProfileValue(profileKey, key, value) end
function addon.functions.ResetDurationTextProfile(profileKey) return DurationText:ResetProfile(profileKey) end
function addon.functions.CreateDurationTextProfile(name, sourceProfileKey) return DurationText:CreateProfile(name, sourceProfileKey) end
function addon.functions.CopyDurationTextProfile(sourceProfileKey, name) return DurationText:CopyProfile(sourceProfileKey, name) end
function addon.functions.DeleteDurationTextProfile(profileKey, replacementKey) return DurationText:DeleteProfile(profileKey, replacementKey) end
function addon.functions.GetDurationTextProfileUsage(profileKey) return DurationText:GetProfileUsage(profileKey) end
function addon.functions.CreateDurationTextBindingFormatComponent(property, formatter) return DurationText:CreateFormatComponent(property, formatter) end
function addon.functions.CreateRemainingDurationTextComponent(config) return DurationText:CreateRemainingDurationComponent(config) end
function addon.functions.CreateTotalDurationTextComponent(config) return DurationText:CreateTotalDurationComponent(config) end
function addon.functions.GetDurationTextBinding(owner, key) return DurationText:GetBinding(owner, key) end
function addon.functions.EnsureDurationTextBinding(owner, key) return DurationText:EnsureBinding(owner, key) end
function addon.functions.ReleaseDurationTextBinding(owner, key, clearText) return DurationText:ReleaseBinding(owner, key, clearText) end
function addon.functions.ReleaseDurationTextBindings(owner, clearText) return DurationText:ReleaseBindings(owner, clearText) end
function addon.functions.SetDurationTextBindingEnabled(owner, key, enabled) return DurationText:SetBindingEnabled(owner, key, enabled) end
function addon.functions.UpdateDurationTextBinding(owner, key) return DurationText:UpdateBinding(owner, key) end
function addon.functions.GetDurationTextBindingState(owner, key) return DurationText:GetBindingState(owner, key) end
function addon.functions.ConfigureDurationTextBinding(owner, key, fontString, durationObject, options) return DurationText:ConfigureBinding(owner, key, fontString, durationObject, options) end
function addon.functions.BindDurationText(fontString, durationObject, options) return DurationText:BindFontString(fontString, durationObject, options) end
function addon.functions.ApplyDurationTextProfileToCooldownFrame(cooldownFrame, profileKey) return DurationText:ApplyProfileToCooldownFrame(cooldownFrame, profileKey) end
