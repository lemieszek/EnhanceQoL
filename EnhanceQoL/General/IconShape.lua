local parentAddonName = "EnhanceQoL"
local addon = select(2, ...)

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.IconShape = addon.IconShape or {}
local IconShape = addon.IconShape

IconShape.DEFAULT = "DEFAULT"
IconShape.SQUARE = "SQUARE"
IconShape.ROUND = "ROUND"
IconShape.STAR = "STAR"
IconShape.HEXAGON = "HEXAGON"
IconShape.HEXAGON_MASK_TEXTURE = "Interface\\AddOns\\Blizzard_SharedTalentUI\\talents-hexagon-mask.png"
IconShape.ROUND_MASK_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
IconShape.STAR_MASK_TEXTURE = "Interface\\AddOns\\EnhanceQoL\\Assets\\StarShape.tga"
IconShape.DEFAULT_SWIPE_TEXTURE = "Interface\\Buttons\\WHITE8X8"

function IconShape.Normalize(value, fallback)
	local normalized = type(value) == "string" and strupper(value) or nil
	if normalized == IconShape.HEXAGON or normalized == "HEX" then return IconShape.HEXAGON end
	if normalized == IconShape.ROUND or normalized == "CIRCLE" then return IconShape.ROUND end
	if normalized == IconShape.SQUARE then return IconShape.SQUARE end
	if normalized == IconShape.STAR then return IconShape.STAR end
	if normalized == IconShape.DEFAULT or normalized == "NONE" then return IconShape.DEFAULT end
	local normalizedFallback = type(fallback) == "string" and strupper(fallback) or nil
	if normalizedFallback == IconShape.HEXAGON or normalizedFallback == "HEX" then return IconShape.HEXAGON end
	if normalizedFallback == IconShape.ROUND or normalizedFallback == "CIRCLE" then return IconShape.ROUND end
	if normalizedFallback == IconShape.SQUARE then return IconShape.SQUARE end
	if normalizedFallback == IconShape.STAR then return IconShape.STAR end
	return IconShape.DEFAULT
end

function IconShape.GetOptions(localeTable, opts)
	opts = opts or {}
	local excluded = opts.exclude or {}
	local options = {
		{ value = IconShape.DEFAULT, label = (localeTable and localeTable["settingsIconShapeDefault"]) or _G.DEFAULT or "Default" },
		{ value = IconShape.SQUARE, label = (localeTable and localeTable["settingsIconShapeSquare"]) or "Square" },
		{ value = IconShape.ROUND, label = (localeTable and localeTable["settingsIconShapeRound"]) or "Round" },
		{ value = IconShape.STAR, label = (localeTable and localeTable["settingsIconShapeStar"]) or "Star" },
		{ value = IconShape.HEXAGON, label = (localeTable and localeTable["settingsIconShapeHexagon"]) or "Hexagon" },
	}
	if not next(excluded) then return options end

	local filtered = {}
	for _, option in ipairs(options) do
		if not excluded[option.value] then filtered[#filtered + 1] = option end
	end
	return filtered
end

function IconShape.GetMaskTexture(shape)
	shape = IconShape.Normalize(shape)
	if shape == IconShape.SQUARE then return IconShape.DEFAULT_SWIPE_TEXTURE end
	if shape == IconShape.ROUND then return IconShape.ROUND_MASK_TEXTURE end
	if shape == IconShape.STAR then return IconShape.STAR_MASK_TEXTURE end
	if shape == IconShape.HEXAGON then return IconShape.HEXAGON_MASK_TEXTURE end
	return nil
end

function IconShape.ApplyTextureMask(texture, mask, key)
	if not (texture and mask and texture.AddMaskTexture) then return false end
	key = key or "_eqolIconShapeMask"
	if texture[key] == mask then return true end
	if texture[key] and texture.RemoveMaskTexture then pcall(texture.RemoveMaskTexture, texture, texture[key]) end
	local ok = pcall(texture.AddMaskTexture, texture, mask)
	texture[key] = ok and mask or nil
	return ok == true
end

function IconShape.ClearTextureMask(texture, key)
	if not texture then return end
	key = key or "_eqolIconShapeMask"
	if texture[key] and texture.RemoveMaskTexture then pcall(texture.RemoveMaskTexture, texture, texture[key]) end
	texture[key] = nil
end

function IconShape.EnsureMask(frame, shape, key)
	if not (frame and frame.CreateMaskTexture) then return nil end
	shape = IconShape.Normalize(shape)
	local maskTexture = IconShape.GetMaskTexture(shape)
	if not maskTexture then return nil end
	key = key or "_eqolIconShapeMask"
	local mask = frame[key]
	if not mask then
		mask = frame:CreateMaskTexture(nil, "BACKGROUND")
		frame[key] = mask
	end
	mask:SetTexture(maskTexture)
	mask:ClearAllPoints()
	mask:SetAllPoints(frame)
	return mask
end

function IconShape.ApplyCooldownRegionMask(cooldown, mask, key)
	if not (cooldown and cooldown.GetRegions and cooldown.GetNumRegions) then return end
	for index = 1, cooldown:GetNumRegions() do
		local region = select(index, cooldown:GetRegions())
		if region then
			if mask then
				IconShape.ApplyTextureMask(region, mask, key)
			else
				IconShape.ClearTextureMask(region, key)
			end
		end
	end
end

function IconShape.GetCooldownSwipeTexture(shape, blizzardSwipeTexture)
	shape = IconShape.Normalize(shape)
	if shape == IconShape.HEXAGON then return IconShape.HEXAGON_MASK_TEXTURE end
	if shape == IconShape.ROUND then return IconShape.ROUND_MASK_TEXTURE end
	if shape == IconShape.STAR then return IconShape.STAR_MASK_TEXTURE end
	if shape == IconShape.SQUARE then return IconShape.DEFAULT_SWIPE_TEXTURE end
	if type(blizzardSwipeTexture) == "string" and blizzardSwipeTexture ~= "" then return blizzardSwipeTexture end
	return IconShape.DEFAULT_SWIPE_TEXTURE
end

function IconShape.ApplyCooldownSwipeVisual(cooldown, owner, colorFunc, data, opts)
	if not cooldown then return end
	opts = opts or {}
	local r, g, b, a = 1, 1, 1, 1
	if colorFunc then r, g, b, a = colorFunc(data) end
	local needsCustomSwipeColor = opts.customColor == true
	local swipeTexture = IconShape.GetCooldownSwipeTexture(owner and owner._eqolIconShape, opts.blizzardSwipeTexture)
	local shapeSwipe = owner and owner._eqolIconShape and owner._eqolIconShape ~= IconShape.DEFAULT
	local customSwipeTexture = swipeTexture ~= IconShape.DEFAULT_SWIPE_TEXTURE
	local textureR, textureG, textureB, textureA = r, g, b, a
	if shapeSwipe and not needsCustomSwipeColor then
		textureR, textureG, textureB, textureA = 0, 0, 0, 0.8
	end
	if cooldown.SetSwipeTexture and (shapeSwipe or customSwipeTexture or needsCustomSwipeColor or (owner and owner._eqolSwipeTexturePath ~= nil)) then
		if
			not owner
			or owner._eqolSwipeTexturePath ~= swipeTexture
			or owner._eqolSwipeTextureR ~= textureR
			or owner._eqolSwipeTextureG ~= textureG
			or owner._eqolSwipeTextureB ~= textureB
			or owner._eqolSwipeTextureA ~= textureA
		then
			local ok = pcall(cooldown.SetSwipeTexture, cooldown, swipeTexture, textureR, textureG, textureB, textureA)
			if ok and owner then
				owner._eqolSwipeTexturePath = swipeTexture
				owner._eqolSwipeTextureR, owner._eqolSwipeTextureG, owner._eqolSwipeTextureB, owner._eqolSwipeTextureA = textureR, textureG, textureB, textureA
			end
		end
	end
	if needsCustomSwipeColor and cooldown.SetSwipeColor then
		if not owner or owner._eqolSwipeColorR ~= r or owner._eqolSwipeColorG ~= g or owner._eqolSwipeColorB ~= b or owner._eqolSwipeColorA ~= a then
			cooldown:SetSwipeColor(r, g, b, a)
			if owner then owner._eqolSwipeColorR, owner._eqolSwipeColorG, owner._eqolSwipeColorB, owner._eqolSwipeColorA = r, g, b, a end
		end
	elseif not needsCustomSwipeColor then
		if cooldown.SetSwipeColor and owner and owner._eqolSwipeColorR ~= nil then cooldown:SetSwipeColor(0, 0, 0, 0.8) end
		if owner then owner._eqolSwipeColorR, owner._eqolSwipeColorG, owner._eqolSwipeColorB, owner._eqolSwipeColorA = nil, nil, nil, nil end
	end
end

function IconShape.ResetCooldownSwipeVisual(cooldown, owner)
	if not cooldown then return end
	if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, IconShape.DEFAULT_SWIPE_TEXTURE, 0, 0, 0, 0.8) end
	if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.8) end
	if owner then
		owner._eqolSwipeTexturePath = nil
		owner._eqolSwipeTextureR, owner._eqolSwipeTextureG, owner._eqolSwipeTextureB, owner._eqolSwipeTextureA = nil, nil, nil, nil
		owner._eqolSwipeColorR, owner._eqolSwipeColorG, owner._eqolSwipeColorB, owner._eqolSwipeColorA = nil, nil, nil, nil
	end
end

function IconShape.ApplyFrameShape(frame, shape, opts)
	if not frame then return end
	opts = opts or {}
	shape = IconShape.Normalize(shape)
	if shape == IconShape.DEFAULT then
		frame._eqolIconShape = IconShape.DEFAULT
		for _, texture in ipairs(opts.textures or {}) do
			IconShape.ClearTextureMask(texture, opts.textureMaskKey)
		end
		IconShape.ApplyCooldownRegionMask(opts.cooldown, nil, opts.textureMaskKey)
		frame._eqolGlowShape = nil
		IconShape.ResetCooldownSwipeVisual(opts.cooldown, frame)
		if opts.refreshSwipe then opts.refreshSwipe(frame) end
		return
	end

	local mask = IconShape.EnsureMask(frame, shape, opts.maskKey)
	frame._eqolIconShape = shape
	frame._eqolGlowShape = shape
	for _, texture in ipairs(opts.textures or {}) do
		IconShape.ApplyTextureMask(texture, mask, opts.textureMaskKey)
	end
	IconShape.ApplyCooldownRegionMask(opts.cooldown, mask, opts.textureMaskKey)
	if opts.refreshSwipe then opts.refreshSwipe(frame) end
end
