--> CropModelUtility
-- Builds a small cute physical model for a backpack item (crops, mutated crops, future props).
--   CropModelUtility.build(itemName) -> Model (PrimaryPart "Handle" = where the hand grips it, item grows up +Y)
-- Expandable:
--   1) put a custom Model in ReplicatedStorage.Assets.Models.Crops named after the item -> used as is
--   2) or add the item to STYLES (+ COLORS) below to pick one of the procedural shapes
-- Mutations ("Wet Carrot") tint the item and add their particles / glow. Rare items sparkle.

local _L = _G._L

local CropModelUtility = {}

local rgb = Color3.fromRGB

local STYLES = {
	Clover = "clover", ["Mint Leaf"] = "leaf", Carrot = "carrot", ["Sunflower Seed"] = "seed",
	["Glow Mushroom"] = "mushroom", ["Honey Blossom"] = "flower", ["Aloe Leaf"] = "leaf",
	["Dragon Lily"] = "flower", ["Star Petal"] = "star", ["Moon Flower"] = "flower",
	["Golden Sprout"] = "sprout", ["Crystal Bloom"] = "crystal", ["Spirit Blossom"] = "flower",
	["Celestial Lotus"] = "lotus", ["Phoenix Feather Plant"] = "feather", ["World Tree Leaf"] = "leaf",
	["Cosmic Fern"] = "leaf", ["Eternal Seed"] = "seed", ["Genesis Seed"] = "seed",
	["Chaos Bloom"] = "flower", ["Divine Lotus"] = "lotus",
}

-- main colour, accent colour, glowing?
local COLORS = {
	Clover = {rgb(90, 200, 90), rgb(60, 150, 60)},
	["Mint Leaf"] = {rgb(130, 230, 170), rgb(70, 170, 110)},
	Carrot = {rgb(255, 140, 40), rgb(90, 190, 80)},
	["Sunflower Seed"] = {rgb(90, 70, 50), rgb(235, 225, 200)},
	["Glow Mushroom"] = {rgb(90, 200, 255), rgb(245, 240, 225), true},
	["Honey Blossom"] = {rgb(255, 200, 70), rgb(255, 140, 40)},
	["Aloe Leaf"] = {rgb(110, 190, 120), rgb(200, 240, 200)},
	["Dragon Lily"] = {rgb(255, 80, 50), rgb(255, 210, 60)},
	["Star Petal"] = {rgb(255, 230, 90), rgb(255, 255, 200), true},
	["Moon Flower"] = {rgb(190, 200, 255), rgb(255, 255, 230), true},
	["Golden Sprout"] = {rgb(255, 205, 60), rgb(120, 220, 90)},
	["Crystal Bloom"] = {rgb(120, 230, 255), rgb(220, 250, 255), true},
	["Spirit Blossom"] = {rgb(200, 150, 255), rgb(255, 255, 255), true},
	["Celestial Lotus"] = {rgb(255, 170, 220), rgb(255, 240, 150), true},
	["Phoenix Feather Plant"] = {rgb(255, 100, 40), rgb(255, 220, 70), true},
	["World Tree Leaf"] = {rgb(80, 220, 120), rgb(255, 230, 120), true},
	["Cosmic Fern"] = {rgb(120, 80, 255), rgb(90, 220, 255), true},
	["Eternal Seed"] = {rgb(255, 245, 180), rgb(140, 255, 200), true},
	["Genesis Seed"] = {rgb(60, 50, 90), rgb(180, 120, 255), true},
	["Chaos Bloom"] = {rgb(60, 20, 70), rgb(255, 60, 120), true},
	["Divine Lotus"] = {rgb(255, 255, 255), rgb(255, 225, 110), true},
}

local RARITY_SPARKLE = {
	Epic = rgb(190, 90, 255), Legendary = rgb(255, 200, 60), Mythical = rgb(255, 80, 120),
	Huge = rgb(80, 255, 170), Secret = rgb(170, 120, 255), Divine = rgb(255, 250, 220),
}

local HEIGHT = 2.1 -- studs, nice readable size in a hand

---------->
local function part(model, handle, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = opts.name or "Piece"
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Transparency = opts.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	if opts.shape == "ball" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	elseif opts.shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	elseif opts.shape == "wedge" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Wedge
		m.Parent = p
	end
	p.Parent = model
	return p
end

local V, C, A = Vector3.new, CFrame.new, CFrame.Angles

local SHAPES = {}

SHAPES.carrot = function(m, h, c1, c2)
	part(m, h, V(0.7, 1.3, 0.7), C(0, 0.55, 0), c1, {shape = "ball", name = "Body"})
	part(m, h, V(0.35, 0.5, 0.35), C(0, 0.05, 0), c1, {shape = "ball"})
	for i = 1, 3 do
		local a = i * math.pi * 2 / 3
		part(m, h, V(0.14, 0.75, 0.3), C(0, 1.4, 0) * A(0, a, math.rad(18)) * C(0, 0.1, 0), c2, {shape = "ball"})
	end
end

SHAPES.clover = function(m, h, c1, c2)
	part(m, h, V(0.9, 0.12, 0.12), C(0, 0.45, 0) * A(0, 0, math.rad(90)), c2, {shape = "cyl"})
	for i = 1, 4 do
		local a = i * math.pi / 2
		part(m, h, V(0.62, 0.12, 0.62), C(0, 1.0, 0) * A(0, a, 0) * C(0.3, 0, 0) * A(0, 0, math.rad(-12)), c1, {shape = "ball", name = "Body"})
	end
end

SHAPES.leaf = function(m, h, c1, c2)
	part(m, h, V(0.5, 0.1, 0.1), C(0, 0.25, 0) * A(0, 0, math.rad(90)), c2, {shape = "cyl"})
	part(m, h, V(0.8, 1.35, 0.14), C(0, 1.0, 0), c1, {shape = "ball", name = "Body"})
	part(m, h, V(0.06, 1.2, 0.16), C(0, 1.0, 0), c2)
end

SHAPES.seed = function(m, h, c1, c2)
	part(m, h, V(0.8, 1.2, 0.55), C(0, 0.6, 0), c1, {shape = "ball", name = "Body"})
	part(m, h, V(0.4, 0.8, 0.58), C(0.12, 0.65, 0), c2, {shape = "ball"})
end

SHAPES.mushroom = function(m, h, c1, c2)
	part(m, h, V(0.8, 0.45, 0.45), C(0, 0.4, 0) * A(0, 0, math.rad(90)), c2, {shape = "cyl"})
	part(m, h, V(1.3, 0.8, 1.3), C(0, 0.95, 0), c1, {shape = "ball", name = "Body"})
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		part(m, h, V(0.2, 0.2, 0.2), C(math.cos(a) * 0.4, 1.2, math.sin(a) * 0.4), c2, {shape = "ball"})
	end
end

SHAPES.flower = function(m, h, c1, c2)
	part(m, h, V(0.9, 0.12, 0.12), C(0, 0.45, 0) * A(0, 0, math.rad(90)), rgb(90, 180, 80), {shape = "cyl"})
	part(m, h, V(0.4, 0.1, 0.25), C(0.2, 0.5, 0) * A(0, 0, math.rad(25)), rgb(90, 180, 80), {shape = "ball"})
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5
		part(m, h, V(0.6, 0.14, 0.4), C(0, 1.1, 0) * A(0, a, 0) * C(0.33, 0, 0) * A(0, 0, math.rad(20)), c1, {shape = "ball", name = "Body"})
	end
	part(m, h, V(0.36, 0.3, 0.36), C(0, 1.15, 0), c2, {shape = "ball"})
end

SHAPES.lotus = function(m, h, c1, c2)
	for i = 1, 8 do
		local a = i * math.pi / 4
		local tilt = if i % 2 == 0 then 55 else 35
		part(m, h, V(0.3, 0.8, 0.14), C(0, 0.55, 0) * A(0, a, 0) * C(0.22, 0, 0) * A(0, 0, math.rad(-tilt)) * C(0, 0.3, 0), c1, {shape = "ball", name = "Body"})
	end
	part(m, h, V(0.4, 0.3, 0.4), C(0, 0.7, 0), c2, {shape = "ball"})
	part(m, h, V(1.1, 0.12, 1.1), C(0, 0.35, 0), rgb(80, 180, 110), {shape = "ball"})
end

SHAPES.star = function(m, h, c1, c2)
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5
		part(m, h, V(0.3, 0.75, 0.16), C(0, 0.9, 0) * A(0, 0, a) * C(0, 0.35, 0), c1, {shape = "ball", name = "Body"})
	end
	part(m, h, V(0.45, 0.45, 0.25), C(0, 0.9, 0), c2, {shape = "ball"})
end

SHAPES.sprout = function(m, h, c1, c2)
	part(m, h, V(0.8, 0.9, 0.8), C(0, 0.45, 0), c1, {shape = "ball", name = "Body"})
	part(m, h, V(0.4, 0.1, 0.1), C(0, 1.0, 0) * A(0, 0, math.rad(90)), c2, {shape = "cyl"})
	part(m, h, V(0.55, 0.12, 0.35), C(-0.25, 1.25, 0) * A(0, 0, math.rad(25)), c2, {shape = "ball"})
	part(m, h, V(0.55, 0.12, 0.35), C(0.25, 1.25, 0) * A(0, 0, math.rad(-25)), c2, {shape = "ball"})
end

SHAPES.crystal = function(m, h, c1, c2)
	part(m, h, V(0.55, 0.55, 0.55), C(0, 0.75, 0) * A(math.rad(45), 0, math.rad(45)), c1, {material = Enum.Material.Glass, transparency = 0.15, name = "Body"})
	part(m, h, V(0.35, 0.35, 0.35), C(0.35, 0.45, 0.1) * A(math.rad(30), math.rad(20), math.rad(45)), c2, {material = Enum.Material.Glass, transparency = 0.15})
	part(m, h, V(0.3, 0.3, 0.3), C(-0.3, 0.4, -0.1) * A(math.rad(15), math.rad(40), math.rad(45)), c1, {material = Enum.Material.Glass, transparency = 0.15})
	part(m, h, V(0.3, 0.3, 0.3), C(0, 1.35, 0) * A(math.rad(45), 0, math.rad(45)), c2, {material = Enum.Material.Neon})
end

SHAPES.feather = function(m, h, c1, c2)
	part(m, h, V(1.2, 0.08, 0.08), C(0, 0.75, 0) * A(0, 0, math.rad(90)), c2, {shape = "cyl"})
	part(m, h, V(0.6, 1.4, 0.1), C(0, 0.95, 0) * A(0, 0, math.rad(-8)), c1, {shape = "ball", name = "Body"})
	part(m, h, V(0.35, 0.8, 0.12), C(0.02, 1.25, 0) * A(0, 0, math.rad(-8)), c2, {shape = "ball"})
end

-- keyword fallback so new items still get a sensible look
local function guessStyle(name)
	local n = string.lower(name)
	for key, style in pairs({mushroom = "mushroom", carrot = "carrot", seed = "seed", lotus = "lotus", leaf = "leaf", fern = "leaf", clover = "clover", feather = "feather", crystal = "crystal", star = "star", sprout = "sprout"}) do
		if string.find(n, key, 1, true) then
			return style
		end
	end
	return "flower"
end

function CropModelUtility.getStyle(baseName)
	return STYLES[baseName] or guessStyle(baseName)
end

-- returns Model, info {base, mutation, rarity}
function CropModelUtility.build(itemName)
	local MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
	local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	local baseName, mutation = MutationUtility.split(itemName)
	local rarity = BackpackUtility.getRarity(itemName)

	local model = Instance.new("Model")
	model.Name = "HeldItem"
	local handle = part(model, nil, V(0.3, 0.3, 0.3), C(0, 0, 0), rgb(255, 255, 255), {name = "Handle", transparency = 1})
	model.PrimaryPart = handle

	local folder = _L.Assets:FindFirstChild("Models") and _L.Assets.Models:FindFirstChild("Crops")
	local custom = folder and folder:FindFirstChild(baseName)
	if custom then
		local copy = custom:Clone()
		local cf, size
		if copy:IsA("Model") then
			cf, size = copy:GetBoundingBox()
		else
			cf, size = copy.CFrame, copy.Size
		end
		local pieces = if copy:IsA("BasePart") then {copy} else {}
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(pieces, d)
			end
		end
		local offset = C(0, size.Y / 2, 0) * cf:Inverse()
		for _, p in ipairs(pieces) do
			p.CFrame = offset * p.CFrame
			for _, j in ipairs(p:GetChildren()) do
				if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
					j:Destroy()
				end
			end
		end
		copy.Parent = model
	else
		local colors = COLORS[baseName] or {rgb(255, 150, 190), rgb(255, 230, 120)}
		local c1, c2 = colors[1], colors[2]
		if mutation and mutation.effect ~= "rainbow" then
			c1 = c1:Lerp(mutation.color, 0.22)
		end
		SHAPES[CropModelUtility.getStyle(baseName)](model, handle, c1, c2)
		if colors[3] then
			for _, p in ipairs(model:GetChildren()) do
				if p.Name == "Body" then
					p.Material = Enum.Material.Neon
					p.Transparency = 0.1
				end
			end
		end
	end

	-- normalise size
	local _, size = model:GetBoundingBox()
	pcall(function()
		model:ScaleTo(HEIGHT / math.max(size.Y, 0.2))
	end)

	-- rigid welds (made after scaling so the offsets are final, works in or out of workspace)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if d ~= handle then
				local w = Instance.new("Weld")
				w.Part0 = handle
				w.Part1 = d
				w.C0 = handle.CFrame:ToObjectSpace(d.CFrame)
				w.Parent = d
			end
		end
	end

	-- effects
	local att = Instance.new("Attachment")
	att.Name = "FX"
	att.Position = V(0, HEIGHT * 0.6, 0)
	att.Parent = handle
	local sparkleColor = RARITY_SPARKLE[rarity]
	if mutation then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "MutationFX"
		pe.LightEmission = 0.7
		pe.Rate = 8
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(0.6, 1.6)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0)})
		pe.Color = ColorSequence.new(mutation.color)
		if mutation.effect == "rainbow" then
			pe.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(255, 90, 90)), ColorSequenceKeypoint.new(0.33, rgb(255, 230, 80)),
				ColorSequenceKeypoint.new(0.66, rgb(90, 200, 255)), ColorSequenceKeypoint.new(1, rgb(200, 110, 255)),
			})
		elseif mutation.effect == "drops" then
			pe.Acceleration = V(0, -6, 0)
		elseif mutation.effect == "sparks" then
			pe.Speed = NumberRange.new(3, 5)
			pe.Lifetime = NumberRange.new(0.2, 0.35)
			pe.Rate = 14
		end
		pe.Parent = att
		local light = Instance.new("PointLight")
		light.Color = mutation.color
		light.Brightness = 0.8
		light.Range = 6
		light.Parent = handle
	end
	if sparkleColor then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "RarityFX"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.LightEmission = 1
		pe.Rate = 4
		pe.Lifetime = NumberRange.new(0.5, 0.9)
		pe.Speed = NumberRange.new(0.3, 0.8)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
		pe.Color = ColorSequence.new(sparkleColor)
		pe.Parent = att
	end

	-- show-off name tag for rare / mutated items
	if mutation or sparkleColor then
		local tagColor = if mutation then mutation.color else sparkleColor
		local bb = Instance.new("BillboardGui")
		bb.Name = "ItemTag"
		bb.Size = UDim2.fromOffset(150, 26)
		bb.StudsOffsetWorldSpace = V(0, HEIGHT + 0.9, 0)
		bb.MaxDistance = 60
		bb.LightInfluence = 0
		bb.Parent = handle
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundColor3 = rgb(255, 248, 228)
		l.BackgroundTransparency = 0.1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = rgb(95, 65, 40)
		l.Text = "✨ " .. itemName
		l.Parent = bb
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = l
		local s = Instance.new("UIStroke")
		s.Color = tagColor
		s.Thickness = 2.5
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 3)
		pad.PaddingBottom = UDim.new(0, 3)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = l
	end

	model:SetAttribute("ItemName", itemName)
	return model, {base = baseName, mutation = mutation, rarity = rarity}
end

return CropModelUtility
