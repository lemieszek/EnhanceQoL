local addonName, addon = ...
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local category = addon.SettingsLayout.rootUI
local DurationText = addon.DurationText
if not (category and DurationText) then return end

local function invalidate()
	if DurationText and DurationText.Invalidate then DurationText:Invalidate() end
end

local function setDurationTextValue(key, value)
	DurationText:InitDB()
	addon.db.durationText[key] = value
	if key ~= "preset" then addon.db.durationText.preset = "CUSTOM" end
	invalidate()
end

local function getDurationTextValue(key)
	DurationText:InitDB()
	return addon.db.durationText[key]
end

local function optionList(entries)
	local options, order = {}, {}
	for i = 1, #entries do
		local entry = entries[i]
		options[entry.value] = entry.text
		order[#order + 1] = entry.value
	end
	return options, order
end

local presetOptions, presetOrder = optionList({
	{ value = "CUSTOM", text = L["durationTextPresetCustom"] },
	{ value = "COMPACT", text = L["durationTextPresetCompact"] },
	{ value = "PRECISE", text = L["durationTextPresetPrecise"] },
	{ value = "MINIMAL", text = L["durationTextPresetMinimal"] },
})
local intervalOptions, intervalOrder = optionList({
	{ value = "SECONDS", text = L["durationTextIntervalSeconds"] },
	{ value = "MINUTES", text = L["durationTextIntervalMinutes"] },
	{ value = "HOURS", text = L["durationTextIntervalHours"] },
	{ value = "DAYS", text = L["durationTextIntervalDays"] },
})
local abbreviationOptions, abbreviationOrder = optionList({
	{ value = "NONE", text = L["durationTextAbbreviationNone"] },
	{ value = "TRUNCATE", text = L["durationTextAbbreviationTruncate"] },
	{ value = "ONE_LETTER", text = L["durationTextAbbreviationOneLetter"] },
})
local whitespaceOptions, whitespaceOrder = optionList({
	{ value = "PRESERVE", text = L["durationTextWhitespacePreserve"] },
	{ value = "STRIP", text = L["durationTextWhitespaceStrip"] },
	{ value = "STRIP_IGNORE_LOCALE", text = L["durationTextWhitespaceStripIgnoreLocale"] },
})

local presets = {
	COMPACT = {
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
		stripIntervalWhitespace = "PRESERVE",
		zeroDurationText = "",
	},
	MINIMAL = {
		abbreviation = "ONE_LETTER",
		approximationSeconds = 0,
		bindingUpdateInterval = 0.2,
		canRoundUpIntervals = true,
		canRoundUpLastUnit = false,
		convertToLower = true,
		desiredUnitCount = 1,
		expiredText = "",
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
		maxInterval = "DAYS",
		millisecondsThreshold = 10,
		minInterval = "SECONDS",
		stripIntervalWhitespace = "PRESERVE",
		zeroDurationText = "",
	},
}

local function applyPreset(value)
	DurationText:InitDB()
	addon.db.durationText.preset = value
	local preset = presets[value]
	if preset then
		for key, presetValue in pairs(preset) do
			addon.db.durationText[key] = presetValue
		end
	end
	invalidate()
end

local expandable = addon.functions.SettingsCreateExpandableSection(category, {
	name = L["durationTextTitle"],
	description = L["configCenterPageCardDescDurationText"],
	expanded = false,
	colorizeTitle = false,
	newTagID = "DurationText",
	configPageKey = "DurationText",
	iconKey = "castbar",
	modernCategory = "suites",
	modernOnly = true,
})
addon.SettingsLayout.durationTextSection = expandable

addon.functions.SettingsCreateHeadline(category, L["durationTextPreset"], { parentSection = expandable, order = 10 })

addon.functions.SettingsCreateDropdown(category, {
	var = "durationText",
	subvar = "preset",
	text = L["durationTextPreset"],
	desc = L["durationTextPresetDesc"],
	list = presetOptions,
	listOrder = presetOrder,
	order = 10,
	default = DurationText.defaults.preset,
	get = function() return getDurationTextValue("preset") end,
	func = applyPreset,
	parentSection = expandable,
})

addon.functions.SettingsCreateText(category, L["durationTextIntro"], { parentSection = expandable, order = 20 })

addon.functions.SettingsCreateHeadline(category, L["durationTextFormattingHeader"], { parentSection = expandable, order = 20 })

addon.functions.SettingsCreateSlider(category, {
	var = "durationText",
	subvar = "millisecondsThreshold",
	text = L["durationTextMillisecondsThreshold"],
	desc = L["durationTextMillisecondsThresholdDesc"],
	min = 0,
	max = 60,
	step = 0.5,
	default = DurationText.defaults.millisecondsThreshold,
	get = function() return getDurationTextValue("millisecondsThreshold") end,
	func = function(value) setDurationTextValue("millisecondsThreshold", value) end,
	order = 20,
	parentSection = expandable,
})

addon.functions.SettingsCreateSlider(category, {
	var = "durationText",
	subvar = "approximationSeconds",
	text = L["durationTextApproximationSeconds"],
	desc = L["durationTextApproximationSecondsDesc"],
	min = 0,
	max = 3600,
	step = 1,
	default = DurationText.defaults.approximationSeconds,
	get = function() return getDurationTextValue("approximationSeconds") end,
	func = function(value) setDurationTextValue("approximationSeconds", value) end,
	order = 30,
	parentSection = expandable,
})

addon.functions.SettingsCreateSlider(category, {
	var = "durationText",
	subvar = "bindingUpdateInterval",
	text = L["durationTextBindingUpdateInterval"],
	desc = L["durationTextBindingUpdateIntervalDesc"],
	min = 0,
	max = 1,
	step = 0.01,
	default = DurationText.defaults.bindingUpdateInterval,
	get = function() return getDurationTextValue("bindingUpdateInterval") end,
	func = function(value) setDurationTextValue("bindingUpdateInterval", value) end,
	order = 40,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationText",
	subvar = "abbreviation",
	text = L["durationTextAbbreviation"],
	desc = L["durationTextAbbreviationDesc"],
	list = abbreviationOptions,
	listOrder = abbreviationOrder,
	order = 50,
	default = DurationText.defaults.abbreviation,
	get = function() return getDurationTextValue("abbreviation") end,
	func = function(value) setDurationTextValue("abbreviation", value) end,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationText",
	subvar = "minInterval",
	text = L["durationTextMinInterval"],
	desc = L["durationTextMinIntervalDesc"],
	list = intervalOptions,
	listOrder = intervalOrder,
	order = 60,
	default = DurationText.defaults.minInterval,
	get = function() return getDurationTextValue("minInterval") end,
	func = function(value) setDurationTextValue("minInterval", value) end,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationText",
	subvar = "maxInterval",
	text = L["durationTextMaxInterval"],
	desc = L["durationTextMaxIntervalDesc"],
	list = intervalOptions,
	listOrder = intervalOrder,
	order = 70,
	default = DurationText.defaults.maxInterval,
	get = function() return getDurationTextValue("maxInterval") end,
	func = function(value) setDurationTextValue("maxInterval", value) end,
	parentSection = expandable,
})

addon.functions.SettingsCreateSlider(category, {
	var = "durationText",
	subvar = "desiredUnitCount",
	text = L["durationTextDesiredUnitCount"],
	desc = L["durationTextDesiredUnitCountDesc"],
	min = 1,
	max = 2,
	step = 1,
	default = DurationText.defaults.desiredUnitCount,
	get = function() return getDurationTextValue("desiredUnitCount") end,
	func = function(value) setDurationTextValue("desiredUnitCount", value) end,
	order = 80,
	parentSection = expandable,
})

addon.functions.SettingsCreateHeadline(category, L["durationTextBehaviorHeader"], { parentSection = expandable, order = 30 })

addon.functions.SettingsCreateCheckboxes(category, {
	{
		var = "durationText",
		subvar = "canRoundUpIntervals",
		text = L["durationTextCanRoundUpIntervals"],
		desc = L["durationTextCanRoundUpIntervalsDesc"],
		default = DurationText.defaults.canRoundUpIntervals,
		get = function() return getDurationTextValue("canRoundUpIntervals") end,
		func = function(value) setDurationTextValue("canRoundUpIntervals", value == true) end,
		order = 90,
		parentSection = expandable,
	},
	{
		var = "durationText",
		subvar = "canRoundUpLastUnit",
		text = L["durationTextCanRoundUpLastUnit"],
		desc = L["durationTextCanRoundUpLastUnitDesc"],
		default = DurationText.defaults.canRoundUpLastUnit,
		get = function() return getDurationTextValue("canRoundUpLastUnit") end,
		func = function(value) setDurationTextValue("canRoundUpLastUnit", value == true) end,
		order = 100,
		parentSection = expandable,
	},
	{
		var = "durationText",
		subvar = "convertToLower",
		text = L["durationTextConvertToLower"],
		desc = L["durationTextConvertToLowerDesc"],
		default = DurationText.defaults.convertToLower,
		get = function() return getDurationTextValue("convertToLower") end,
		func = function(value) setDurationTextValue("convertToLower", value == true) end,
		order = 110,
		parentSection = expandable,
	},
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationText",
	subvar = "stripIntervalWhitespace",
	text = L["durationTextStripIntervalWhitespace"],
	desc = L["durationTextStripIntervalWhitespaceDesc"],
	list = whitespaceOptions,
	listOrder = whitespaceOrder,
	order = 120,
	default = DurationText.defaults.stripIntervalWhitespace,
	get = function() return getDurationTextValue("stripIntervalWhitespace") end,
	func = function(value) setDurationTextValue("stripIntervalWhitespace", value) end,
	parentSection = expandable,
})

addon.functions.SettingsCreateHeadline(category, L["durationTextFallbackTextHeader"], { parentSection = expandable, order = 40 })

addon.functions.SettingsCreateInput(category, {
	var = "durationText",
	subvar = "zeroDurationText",
	text = L["durationTextZeroDurationText"],
	desc = L["durationTextZeroDurationTextDesc"],
	default = DurationText.defaults.zeroDurationText,
	get = function() return getDurationTextValue("zeroDurationText") end,
	func = function(value) setDurationTextValue("zeroDurationText", value or "") end,
	order = 130,
	parentSection = expandable,
})

addon.functions.SettingsCreateInput(category, {
	var = "durationText",
	subvar = "expiredText",
	text = L["durationTextExpiredText"],
	desc = L["durationTextExpiredTextDesc"],
	default = DurationText.defaults.expiredText,
	get = function() return getDurationTextValue("expiredText") end,
	func = function(value) setDurationTextValue("expiredText", value or "") end,
	order = 140,
	parentSection = expandable,
})

addon.functions.SettingsCreateButton(category, {
	id = "durationTextResetDefaults",
	text = L["durationTextResetDefaults"],
	desc = L["durationTextResetDefaultsDesc"],
	buttonText = RESET_TO_DEFAULT,
	order = 150,
	func = function()
		DurationText:InitDB()
		for key, value in pairs(DurationText.defaults) do
			addon.db.durationText[key] = value
		end
		invalidate()
	end,
	parentSection = expandable,
})
