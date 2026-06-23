local _, addon = ...

local EnhancedWaypoint = {}
addon.EnhancedWaypoint = EnhancedWaypoint

local C_AreaPoiInfo = _G.C_AreaPoiInfo
local C_Map = _G.C_Map
local C_Navigation = _G.C_Navigation
local C_VignetteInfo = _G.C_VignetteInfo

local state = {
	activeAtlas = nil,
	applyScaleQueued = false,
	fontPrepared = false,
	frame = nil,
	highlight = nil,
	label = nil,
}

local EVENT_NAMES = {
	"SUPER_TRACKING_CHANGED",
	"SUPER_TRACKING_PATH_UPDATED",
	"USER_WAYPOINT_UPDATED",
	"NAVIGATION_FRAME_CREATED",
}

local DEFAULT_LABEL_COLOR = { r = 1, g = 210 / 255, b = 0 }
local DISTANCE_TEXT_SIZE = 13
local LABEL_OFFSET_Y = -22
local GLOW_OFFSET_Y = 82
local GLOW_WIDTH = 300
local GLOW_HEIGHT = 32
local TARGET_ICON_SIZE = 35

local AVAILABLE_QUEST_ATLAS = {
	[Enum.QuestClassification.Campaign] = "Quest-Campaign-Available",
	[Enum.QuestClassification.Important] = "quest-important-available",
	[Enum.QuestClassification.Legendary] = "quest-legendary-available",
	[Enum.QuestClassification.Meta] = "quest-wrapper-available",
	[Enum.QuestClassification.Recurring] = "quest-recurring-available",
}

local ACTIVE_QUEST_ATLAS = {
	[Enum.QuestClassification.Campaign] = "UI-QuestPoiCampaign-QuestNumber",
	[Enum.QuestClassification.Important] = "UI-QuestPoiImportant-QuestNumber-SuperTracked",
	[Enum.QuestClassification.Legendary] = "UI-QuestPoiLegendary-QuestNumber-SuperTracked",
	[Enum.QuestClassification.Meta] = "UI-QuestPoiWrapper-QuestNumber-SuperTracked",
	[Enum.QuestClassification.Recurring] = "UI-QuestPoiRecurring-QuestNumber-SuperTracked",
}

local TURN_IN_QUEST_ATLAS = {
	[Enum.QuestClassification.Campaign] = "Quest-Campaign-TurnIn",
	[Enum.QuestClassification.Important] = "quest-important-turnin",
	[Enum.QuestClassification.Legendary] = "quest-legendary-turnin",
	[Enum.QuestClassification.Meta] = "quest-wrapper-turnin",
	[Enum.QuestClassification.Recurring] = "quest-recurring-turnin",
}

local NAVIGATION_ALPHA = {
	[Enum.NavigationState.Invalid] = 0,
	[Enum.NavigationState.Occluded] = 0.6,
	[Enum.NavigationState.InRange] = 1,
	[Enum.NavigationState.Disabled] = 0,
}

local function clampScale(value)
	value = tonumber(value) or 1
	if value < 0.6 then return 0.6 end
	if value > 2 then return 2 end
	return value
end

local function callLater(delay, callback)
	if C_Timer and C_Timer.After then
		C_Timer.After(delay, callback)
	else
		callback()
	end
end

local function getQuestData(questID)
	if not questID or questID == 0 then return nil end
	return {
		classification = C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification and C_QuestInfoSystem.GetQuestClassification(questID) or nil,
		complete = C_QuestLog and C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(questID) or false,
	}
end

local function getAreaPOIInfo(poiID)
	if not poiID or not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIInfo then return nil end
	local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, nil, poiID)
	if ok then return info end
	return nil
end

local function getVignetteInfo(vignetteGUID)
	if not vignetteGUID or not C_VignetteInfo or not C_VignetteInfo.GetVignetteInfo then return nil end
	local ok, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
	if ok then return info end
	return nil
end

local function getSuperTrackedQuestID(pinType, poiType, poiID)
	local questID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	if questID and questID ~= 0 then return questID end
	if
		pinType == Enum.SuperTrackingType.MapPin
		and poiType == Enum.SuperTrackingMapPinType.QuestOffer
		and type(poiID) == "number"
	then
		return poiID
	end
	return nil
end

local function pickQuestAtlas(questData, activeQuest)
	if not questData then return nil end
	if questData.complete then
		return TURN_IN_QUEST_ATLAS[questData.classification] or "QuestTurnin"
	end
	if activeQuest then return ACTIVE_QUEST_ATLAS[questData.classification] or "UI-QuestPoi-QuestNumber-Pressed-SuperTracked" end
	return AVAILABLE_QUEST_ATLAS[questData.classification] or "QuestNormal"
end

local function resolveTrackedAtlas()
	if not C_SuperTrack or not C_SuperTrack.GetHighestPrioritySuperTrackingType then return "Navigation-Tracked-Icon" end

	local trackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType()
	if trackingType == Enum.SuperTrackingType.UserWaypoint then return "Waypoint-MapPin-Minimap-Tracked" end

	if trackingType == Enum.SuperTrackingType.Vignette then
		local vignetteGUID = C_SuperTrack.GetSuperTrackedVignette and C_SuperTrack.GetSuperTrackedVignette()
		local vignetteInfo = getVignetteInfo(vignetteGUID)
		return vignetteInfo and vignetteInfo.atlasName or "VignetteKill"
	end

	local poiType, poiID
	if C_SuperTrack.GetSuperTrackedMapPin then poiType, poiID = C_SuperTrack.GetSuperTrackedMapPin() end
	local questID = getSuperTrackedQuestID(trackingType, poiType, poiID)
	local questData = getQuestData(questID)
	if trackingType == Enum.SuperTrackingType.Quest then return pickQuestAtlas(questData, true) or "Navigation-Tracked-Icon" end

	if trackingType == Enum.SuperTrackingType.MapPin then
		if poiType == Enum.SuperTrackingMapPinType.QuestOffer then return pickQuestAtlas(questData, false) end
		if poiType == Enum.SuperTrackingMapPinType.TaxiNode then return "TaxiNode_Neutral" end
		local poiInfo = getAreaPOIInfo(poiID)
		if poiInfo and poiInfo.atlasName then return poiInfo.atlasName end
	end

	return "Navigation-Tracked-Icon"
end

local function getLabel(frame)
	if state.label then return state.label end

	local label = frame:CreateFontString(nil, "OVERLAY", "Game12Font_o1")
	label:SetTextColor(DEFAULT_LABEL_COLOR.r, DEFAULT_LABEL_COLOR.g, DEFAULT_LABEL_COLOR.b)
	label:SetPoint("TOP", frame.Icon, "BOTTOM", 0, LABEL_OFFSET_Y)
	state.label = label
	return label
end

local function getHighlight(frame)
	if state.highlight then return state.highlight end

	local highlight = CreateFrame("Frame", nil, frame)
	highlight:SetSize(1, 1)
	highlight:SetPoint("CENTER")
	highlight:SetFrameStrata("BACKGROUND")
	highlight:SetFrameLevel(math.max((frame:GetFrameLevel() or 1) - 1, 0))

	highlight.texture = highlight:CreateTexture(nil, "BACKGROUND")
	highlight.texture:SetAtlas("OBJFX_LineGlow")
	highlight.texture:SetPoint("TOP", frame.Icon, "TOP", 0, GLOW_OFFSET_Y)
	highlight.texture:SetSize(GLOW_WIDTH, GLOW_HEIGHT)
	highlight.texture:SetRotation(math.pi / 2)

	state.highlight = highlight
	return highlight
end

local function updateAlphaBehavior(frame)
	if frame.__eqolEnhancedWaypointAlphaHooked then return end
	frame.__eqolEnhancedWaypointAlphaHooked = true
	frame.__eqolOriginalGetTargetAlphaBaseValue = frame.GetTargetAlphaBaseValue
	frame.GetTargetAlphaBaseValue = function(self)
		if not C_SuperTrack or not C_SuperTrack.IsSuperTrackingAnything or not C_SuperTrack.IsSuperTrackingAnything() then return 0 end
		local navState = C_Navigation and C_Navigation.GetTargetState and C_Navigation.GetTargetState()
		local alpha = NAVIGATION_ALPHA[navState]
		if navState == Enum.NavigationState.Invalid and C_Navigation and C_Navigation.HasValidScreenPosition and not C_Navigation.HasValidScreenPosition() then alpha = 1 end
		if alpha and alpha > 0 and self.isClamped then return 1 end
		return alpha
	end
end

function EnhancedWaypoint:QueueScaleApply()
	if state.applyScaleQueued then return end
	state.applyScaleQueued = true
	callLater(0.04, function()
		state.applyScaleQueued = false
		EnhancedWaypoint:ApplyScale()
	end)
end

function EnhancedWaypoint:ApplyScale()
	if not self.enabled then return end
	local frame = _G.SuperTrackedFrame
	if not (frame and frame.Arrow and frame.Icon and frame.DistanceText) then return end

	local scale = clampScale(addon.db and addon.db.enhancedWaypointScale)
	frame.Arrow:SetScale(scale)
	frame.Icon:SetScale(1.2 * scale)
	if state.activeAtlas and state.activeAtlas ~= "Navigation-Tracked-Icon" and frame.Icon:GetWidth() > 0 then
		frame.Icon:SetScale(1.2 * scale * (TARGET_ICON_SIZE / frame.Icon:GetWidth()))
	end
	frame.DistanceText:SetScale(scale)
	if not state.fontPrepared then
		local fontFile = frame.DistanceText:GetFont()
		if fontFile then frame.DistanceText:SetFont(fontFile, DISTANCE_TEXT_SIZE, "OUTLINE") end
		state.fontPrepared = true
	end

	if state.label then state.label:SetScale(scale) end
end

function EnhancedWaypoint:Update()
	if not self.enabled then return end
	local frame = _G.SuperTrackedFrame
	if not (frame and frame.Icon and frame.DistanceText and C_SuperTrack and C_SuperTrack.IsSuperTrackingAnything) then return end

	self:ApplyScale()

	local isTracking = C_SuperTrack.IsSuperTrackingAnything()
	local label = getLabel(frame)
	local name = C_SuperTrack.GetSuperTrackedItemName and C_SuperTrack.GetSuperTrackedItemName()
	label:SetText(isTracking and name or "")
	label:SetScale(clampScale(addon.db and addon.db.enhancedWaypointScale))
	label:SetShown(isTracking)

	local highlight = getHighlight(frame)
	highlight:SetShown(isTracking and addon.db and addon.db.enhancedWaypointGlow ~= false)

	if not isTracking then return end

	local atlas = resolveTrackedAtlas()
	if atlas then
		frame.Icon:SetAtlas(atlas, true)
		state.activeAtlas = atlas
		self:ApplyScale()
	end
end

function EnhancedWaypoint:TryAttach()
	local frame = _G.SuperTrackedFrame
	if not (frame and frame.Icon and frame.UpdateIcon) then return false end
	if not frame.__eqolEnhancedWaypointHooked then
		frame.__eqolEnhancedWaypointHooked = true
		hooksecurefunc(frame, "UpdateIcon", function() EnhancedWaypoint:Update() end)
	end
	updateAlphaBehavior(frame)
	self:Update()
	callLater(1, function() EnhancedWaypoint:Update() end)
	return true
end

function EnhancedWaypoint:SetEnabled(enabled)
	enabled = enabled == true
	if enabled == self.enabled then return end
	self.enabled = enabled
	if not enabled then return end

	if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("showInGameNavigation", "1") end
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame:SetScript("OnEvent", function(_, event, addonLoadedName)
			if event == "ADDON_LOADED" and addonLoadedName ~= "Blizzard_QuestNavigation" then return end
			if event == "USER_WAYPOINT_UPDATED" and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				callLater(0, function()
					if EnhancedWaypoint.enabled and C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
					EnhancedWaypoint:Update()
				end)
			else
				EnhancedWaypoint:TryAttach()
			end
			callLater(1, function() EnhancedWaypoint:Update() end)
		end)
	end

	self.eventFrame:RegisterEvent("ADDON_LOADED")
	self.eventFrame:RegisterEvent("PLAYER_LOGIN")
	for i = 1, #EVENT_NAMES do
		self.eventFrame:RegisterEvent(EVENT_NAMES[i])
	end
	self:TryAttach()
end
