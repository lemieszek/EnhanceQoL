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
	DurationText:SetProfileValue(DurationText:GetEditProfileKey(), key, value)
	invalidate()
end

local function getDurationTextValue(key)
	DurationText:InitDB()
	return DurationText:GetProfileValue(DurationText:GetEditProfileKey(), key)
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
local formatStyleOptions, formatStyleOrder = optionList({
	{ value = "NUMERIC", text = L["durationTextFormatStyleNumeric"] },
	{ value = "UNITS", text = L["durationTextFormatStyleUnits"] },
})

local function getProfileDropdownData()
	DurationText:InitDB()
	return DurationText:GetProfileDropdownData()
end

local function getDeleteProfileDropdownData()
	DurationText:InitDB()
	local list, order = {}, {}
	for _, option in ipairs(DurationText:GetProfileOptions()) do
		if not DurationText:IsProfileProtected(option.value) then
			list[option.value] = option.label
			order[#order + 1] = option.value
		end
	end
	return list, order
end

local function notifyDurationTextSettings()
	if not (Settings and Settings.NotifyUpdate) then return end
	Settings.NotifyUpdate("EQOL_durationTextEditProfile")
	Settings.NotifyUpdate("EQOL_durationTextProfileCopy")
	Settings.NotifyUpdate("EQOL_durationTextProfileDelete")
	Settings.NotifyUpdate("EQOL_durationText")
end

local function refreshConfigCenterDurationTextSettings(rebuild)
	local frame = addon.ConfigCenterFrame
	local state = frame and frame._LibSettingsDesignerState
	if not (frame and frame.IsShown and frame:IsShown() and state) then return end
	if rebuild and state.RenderContent then
		state:RenderContent()
		return
	end
	local designer = addon.LibSettingsDesigner and addon.LibSettingsDesigner.UI
	if designer and designer.RefreshVisibleRows then designer.RefreshVisibleRows(state) end
end

local function refreshDurationTextSettings(rebuild)
	invalidate()
	if DurationText and DurationText.RefreshConsumers then DurationText:RefreshConsumers() end
	notifyDurationTextSettings()
	refreshConfigCenterDurationTextSettings(rebuild)
	local timer = _G.C_Timer
	if timer and timer.After then
		timer.After(0, function()
			notifyDurationTextSettings()
			refreshConfigCenterDurationTextSettings(rebuild)
		end)
	end
end

local function printDurationTextProfileError(reason)
	local text = reason == "EXISTS" and (L["durationTextProfileErrorExists"] or "A duration text profile with that name already exists.")
		or reason == "INVALID_NAME" and (L["durationTextProfileErrorInvalidName"] or "Enter a profile name.")
		or reason == "LAST_PROFILE" and (L["durationTextProfileErrorLastProfile"] or "The last duration text profile cannot be deleted.")
		or reason == "PROTECTED_PROFILE" and (L["durationTextProfileErrorProtected"] or "Built-in duration text profiles cannot be deleted.")
		or (L["durationTextProfileErrorGeneric"] or "Duration text profile action failed.")
	print("|cff00ff98Enhance QoL|r: " .. text)
end

local function formatUsageSummary(usages)
	if type(usages) ~= "table" or (usages.count or 0) <= 0 then return L["durationTextProfileDeleteNoUsage"] or "It is not currently used by any configured module." end
	local lines = {
		(L["durationTextProfileDeleteUsageHeader"] or "Used by %d setting(s):"):format(usages.count or 0),
	}
	local order = usages.order
	local byLabel = usages.byLabel
	if type(order) == "table" and type(byLabel) == "table" then
		for i = 1, #order do
			local label = order[i]
			local count = tonumber(byLabel[label]) or 0
			local text = L[label] or label
			lines[#lines + 1] = count > 1 and ("- " .. tostring(text) .. " (" .. count .. ")") or ("- " .. tostring(text))
		end
	else
		for i = 1, #usages do
			lines[#lines + 1] = "- " .. tostring(usages[i])
		end
	end
	return table.concat(lines, "\n")
end

local function showCreateProfileDialog(sourceProfileKey)
	StaticPopupDialogs["EQOL_DURATION_TEXT_PROFILE_CREATE"] = StaticPopupDialogs["EQOL_DURATION_TEXT_PROFILE_CREATE"]
		or {
			text = L["durationTextProfileCreatePrompt"] or "Enter a name for the new duration text profile.",
			hasEditBox = true,
			button1 = OKAY,
			button2 = CANCEL,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
			OnShow = function(self)
				local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
				if editBox then
					editBox:SetText("")
					editBox:SetFocus()
					editBox:HighlightText()
				end
			end,
			EditBoxOnEnterPressed = function(editBox)
				local parent = editBox:GetParent()
				if parent and parent.button1 then parent.button1:Click() end
			end,
			OnAccept = function(self)
				local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
				local ok, result = DurationText:CreateProfile(editBox and editBox:GetText() or "", self.data)
				if not ok then
					printDurationTextProfileError(result)
					return
				end
				DurationText:SetEditProfileKey(result)
				refreshDurationTextSettings(true)
			end,
		}
	StaticPopup_Show("EQOL_DURATION_TEXT_PROFILE_CREATE", nil, nil, sourceProfileKey)
end

local function showDeleteProfileDialog(profileKey)
	DurationText:InitDB()
	profileKey = DurationText:GetProfileKey(profileKey)
	local replacementKey = DurationText:GetReplacementProfileKey(profileKey)
	if not replacementKey then
		printDurationTextProfileError("LAST_PROFILE")
		return
	end
	local usage = DurationText:GetProfileUsage(profileKey)
	local profileLabel = DurationText:GetProfileLabel(profileKey)
	local replacementLabel = DurationText:GetProfileLabel(replacementKey)
	StaticPopupDialogs["EQOL_DURATION_TEXT_PROFILE_DELETE"] = StaticPopupDialogs["EQOL_DURATION_TEXT_PROFILE_DELETE"]
		or {
			text = "",
			button1 = DELETE,
			button2 = CANCEL,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
			OnAccept = function(self)
				local data = self.data
				local ok, reason = DurationText:DeleteProfile(data and data.profileKey, data and data.replacementKey)
				if not ok then
					printDurationTextProfileError(reason)
					return
				end
				refreshDurationTextSettings(true)
			end,
		}
	StaticPopupDialogs["EQOL_DURATION_TEXT_PROFILE_DELETE"].text = (L["durationTextProfileDeleteConfirm"] or 'Delete duration text profile "%s"? References will be moved to "%s".'):format(profileLabel, replacementLabel)
		.. "\n\n"
		.. formatUsageSummary(usage)
	StaticPopup_Show("EQOL_DURATION_TEXT_PROFILE_DELETE", nil, nil, { profileKey = profileKey, replacementKey = replacementKey })
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

addon.functions.SettingsCreateHeadline(category, L["durationTextProfile"], { parentSection = expandable, order = 10 })

addon.functions.SettingsCreateDropdown(category, {
	var = "durationTextEditProfile",
	text = L["durationTextProfile"],
	desc = L["durationTextProfileDesc"],
	listFunc = getProfileDropdownData,
	order = 10,
	default = DurationText.defaultProfileKey,
	storage = false,
	get = function() return DurationText:GetEditProfileKey() end,
	func = function(value)
		DurationText:SetEditProfileKey(value)
		refreshDurationTextSettings()
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateButton(category, {
	var = "durationTextProfileCreate",
	text = L["durationTextProfileCreate"],
	desc = L["durationTextProfileCreateDesc"],
	buttonText = ADD,
	order = 11,
	func = function() showCreateProfileDialog(nil) end,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationTextProfileCopy",
	text = L["durationTextProfileCopy"],
	desc = L["durationTextProfileCopyDesc"],
	listFunc = getProfileDropdownData,
	order = 12,
	default = "",
	storage = false,
	get = function() return "" end,
	func = function(value)
		if value and value ~= "" then showCreateProfileDialog(value) end
	end,
	parentSection = expandable,
})

addon.functions.SettingsCreateDropdown(category, {
	var = "durationTextProfileDelete",
	text = L["durationTextProfileDelete"],
	desc = L["durationTextProfileDeleteDesc"],
	listFunc = getDeleteProfileDropdownData,
	order = 13,
	default = "",
	storage = false,
	get = function() return "" end,
	func = function(value)
		if value and value ~= "" then showDeleteProfileDialog(value) end
	end,
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
	subvar = "formatStyle",
	text = L["durationTextFormatStyle"],
	desc = L["durationTextFormatStyleDesc"],
	list = formatStyleOptions,
	listOrder = formatStyleOrder,
	order = 45,
	default = DurationText.defaults.formatStyle,
	get = function() return getDurationTextValue("formatStyle") end,
	func = function(value) setDurationTextValue("formatStyle", value) end,
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
		DurationText:ResetProfile(DurationText:GetEditProfileKey())
		refreshDurationTextSettings()
	end,
	parentSection = expandable,
})
