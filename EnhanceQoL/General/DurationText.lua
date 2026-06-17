local addonName, addon = ...

addon.DurationText = addon.DurationText or {}
addon.functions = addon.functions or {}

local DurationText = addon.DurationText
local EMPTY_TABLE = {}

DurationText.defaults = {
	abbreviation = "ONE_LETTER",
	approximationSeconds = 0,
	bindingUpdateInterval = 0.1,
	canRoundUpIntervals = true,
	canRoundUpLastUnit = false,
	convertToLower = false,
	desiredUnitCount = 1,
	expiredText = "",
	maxInterval = "DAYS",
	millisecondsThreshold = 10,
	minInterval = "SECONDS",
	preset = "CUSTOM",
	stripIntervalWhitespace = "PRESERVE",
	zeroDurationText = "",
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
	if type(addon.dbDefaults.durationText) ~= "table" then addon.dbDefaults.durationText = copyDefaultTable(self.defaults) end
	if type(addon.db.durationText) ~= "table" then addon.db.durationText = copyDefaultTable(self.defaults) end
	for key, value in pairs(self.defaults) do
		if addon.db.durationText[key] == nil then addon.db.durationText[key] = value end
		if addon.dbDefaults.durationText[key] == nil then addon.dbDefaults.durationText[key] = value end
	end
end

function DurationText:Invalidate()
	self.formatterCache = nil
	self.cacheKey = nil
	self.version = (self.version or 0) + 1
end

function DurationText:GetGlobalConfig()
	self:InitDB()
	return addon.db.durationText
end

function DurationText:GetEffectiveConfig(scopeConfig)
	local globalConfig = self:GetGlobalConfig()
	if type(scopeConfig) ~= "table" or scopeConfig.useGlobal ~= false then return globalConfig end
	local effective = {}
	for key, value in pairs(globalConfig) do
		effective[key] = value
	end
	for key, value in pairs(scopeConfig) do
		if key ~= "useGlobal" and value ~= nil then effective[key] = value end
	end
	return effective
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

function DurationText:GetCacheKey(config)
	config = config or self:GetGlobalConfig()
	return table.concat({
		tostring(config.abbreviation),
		tostring(config.approximationSeconds),
		tostring(config.canRoundUpIntervals),
		tostring(config.canRoundUpLastUnit),
		tostring(config.convertToLower),
		tostring(config.desiredUnitCount),
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

function DurationText:GetSecondsFormatter(config)
	config = config or self:GetGlobalConfig()
	local cacheKey = self:GetCacheKey(config)
	if not self.formatterCache or self.cacheKey ~= cacheKey then
		self.formatterCache = self:CreateSecondsFormatter(config)
		self.cacheKey = cacheKey
	end
	return self.formatterCache
end

function DurationText:FormatSeconds(seconds, config, abbreviation)
	local formatter = self:GetSecondsFormatter(config)
	if formatter and formatter.Format then return formatter:Format(seconds, abbreviation) end
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
	local formatter = self:GetSecondsFormatter(config)
	return self:CreateFormatComponent("RemainingDuration", formatter)
end

function DurationText:CreateTotalDurationComponent(config)
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

	local config = self:GetEffectiveConfig(options.config)
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
	local formatter = self:GetSecondsFormatter(config)
	if formatter and cooldownFrame.SetCountdownFormatter then cooldownFrame:SetCountdownFormatter(formatter) end
	if cooldownFrame.SetCountdownMillisecondsThreshold then cooldownFrame:SetCountdownMillisecondsThreshold(tonumber(config.millisecondsThreshold) or self.defaults.millisecondsThreshold) end
	if cooldownFrame.SetCountdownAbbrevThreshold then cooldownFrame:SetCountdownAbbrevThreshold(tonumber(config.approximationSeconds) or self.defaults.approximationSeconds) end
	return formatter ~= nil
end

function addon.functions.IsDurationTextBindingSupported() return DurationText:IsDurationTextBindingSupported() end
function addon.functions.GetDurationTextBindingProperty(property) return DurationText:GetDurationTextBindingProperty(property) end
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
