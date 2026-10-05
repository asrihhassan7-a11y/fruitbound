--> FarmBuilder (server)
-- Builds everything that appears on a player's farm, in code.
--   FarmBuilder.build(upgradeInfo, plotCFrame, ownerUserId) -> Model
--   FarmBuilder.pad(upgradeInfo, plotCFrame, ownerUserId) -> Model (the purchase pad)
--   FarmBuilder.helper() -> Model (a garden gnome helper)
-- plotCFrame = centre of the plot base (its top, the ground, is GROUND = 0.5 above it), +Z = entrance side.
-- Harvestable plants are tagged "HarvestBush" with Owner / FoodRarity / Value attributes.

local CollectionService = game:GetService("CollectionService")
local PlantBuilder = require(script.Parent:WaitForChild("PlantBuilder"))

local FarmBuilder = {}
-- height of the plot ground above the plot base centre (the base part is 1 stud thick).
-- Was 1, which left every farm piece floating 0.5 studs above the ground. FarmingV2 uses the same value.
FarmBuilder.GROUND = 0.5

local FONT = Enum.Font.FredokaOne
local WOOD = Color3.fromRGB(190, 140, 90)
local WOOD_DARK = Color3.fromRGB(140, 95, 60)
local STONE = Color3.fromRGB(215, 205, 190)
local WHITE = Color3.fromRGB(250, 248, 240)
local GOLD = Color3.fromRGB(255, 205, 60)
local RAINBOW = {
	Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 225, 70), Color3.fromRGB(120, 220, 90),
	Color3.fromRGB(80, 200, 255), Color3.fromRGB(110, 120, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 120, 200),
}

---------------------------------------------------------------- helpers
local function P(parent, origin, name, size, localCf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = origin * localCf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function ball(parent, origin, name, d, pos, color, material)
	return P(parent, origin, name, Vector3.new(d, d, d), CFrame.new(pos), color, material, {Shape = Enum.PartType.Ball})
end

local function cyl(parent, origin, name, height, d, localCf, color, material, props)
	-- cylinder standing up (Roblox cylinders lie on X, so rotate)
	return P(parent, origin, name, Vector3.new(height, d, d), localCf * CFrame.Angles(0, 0, math.rad(90)), color, material, props or {Shape = Enum.PartType.Cylinder})
end

local function withShape(props)
	props = props or {}
	props.Shape = Enum.PartType.Cylinder
	return props
end

local function textSign(part, text, color, face)
	for _, f in ipairs(face and {face} or {Enum.NormalId.Front, Enum.NormalId.Back}) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = f
		-- sized per stud so the text always matches the board's shape (no squashed tiny text)
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 50
		sg.Parent = part
		sg.LightInfluence = 0.2
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(0.9, 0.72)
		l.Position = UDim2.fromScale(0.05, 0.14)
		l.BackgroundTransparency = 1
		l.Font = FONT
		l.TextScaled = true
		-- readable on wood: light text with a dark outline (the given colour tints the outline)
		l.TextColor3 = Color3.fromRGB(255, 248, 225)
		l.Text = text
		l.Parent = sg
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = (color or Color3.fromRGB(110, 170, 70)):Lerp(Color3.fromRGB(40, 25, 15), 0.7)
		st.LineJoinMode = Enum.LineJoinMode.Round
		st.Parent = l
	end
end

local function tuft(parent, origin, pos, color)
	-- small flower: 3 petals + centre
	ball(parent, origin, "Flower", 0.9, pos + Vector3.new(0, 0.5, 0), color)
	ball(parent, origin, "Flower", 0.45, pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 235, 110))
	P(parent, origin, "Stem", Vector3.new(0.15, 0.6, 0.15), CFrame.new(pos + Vector3.new(0, 0.2, 0)), Color3.fromRGB(80, 170, 70))
end

-- harvestable plant owned by this player
local function plant(parent, origin, info, ownerId, pos, colorOverride)
	local spec = info.plant
	local opts
	if spec.crystal then
		opts = {crownMaterial = Enum.Material.Glass, crownTransparency = 0.25, fruitMaterial = Enum.Material.Neon, trunk = Color3.fromRGB(200, 220, 255)}
	end
	local color = colorOverride or spec.fruit
	local m = PlantBuilder.build(spec.style, color, spec.leaf, opts)
	m:PivotTo(origin * CFrame.new(pos + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	m:SetAttribute("Garden", 0)
	m:SetAttribute("Owner", ownerId)
	m:SetAttribute("FoodRarity", info.rarity or "Common")
	m:SetAttribute("Value", info.value or 1)
	m.Parent = parent
	CollectionService:AddTag(m, "HarvestBush")
	return m
end

-- plants in a grid inside a cell
local function grid(parent, origin, info, ownerId, count, width, depth)
	local cols = if count >= 8 then 4 elseif count >= 6 then 3 else 2
	local rows = math.ceil(count / cols)
	local n = 0
	for r = 1, rows do
		for c = 1, cols do
			n += 1
			if n > count then break end
			local x = (c - (cols + 1) / 2) * (width / cols)
			local z = (r - (rows + 1) / 2) * (depth / rows)
			local color = if info.plant.fruit == "rainbow" then RAINBOW[(n - 1) % #RAINBOW + 1] else nil
			plant(parent, origin, info, ownerId, Vector3.new(x, 0, z), color)
		end
	end
end

-- plantable soil: tagged so the client Seed preview recognises it (the server validates by FarmUpgrades.soil)
local function markSoil(part, ownerId, upgradeId)
	part:SetAttribute("Owner", ownerId)
	part:SetAttribute("UpgradeId", upgradeId)
	CollectionService:AddTag(part, "FarmSoil")
	return part
end

local function soilBed(parent, origin, w, d)
	local soil = P(parent, origin, "Soil", Vector3.new(w, 0.4, d), CFrame.new(0, 0.2, 0), Color3.fromRGB(135, 95, 60), Enum.Material.Ground)
	for _, s in ipairs({{0, d / 2, w, 0.6}, {0, -d / 2, w, 0.6}, {w / 2, 0, 0.6, d}, {-w / 2, 0, 0.6, d}}) do
		P(parent, origin, "Edge", Vector3.new(s[3], 0.8, s[4]), CFrame.new(s[1], 0.4, s[2]), WOOD, Enum.Material.Wood)
	end
	return soil
end

---------------------------------------------------------------- builders per kind
local BUILD = {}

-- Land plots are EMPTY soil: players plant their own Seeds anywhere on it (FarmingV2)
BUILD.starter = function(m, o, info, ownerId)
	markSoil(soilBed(m, o, info.soil.X, info.soil.Z), ownerId, info.id)
	local crate = P(m, o, "Crate", Vector3.new(3, 2.4, 3), CFrame.new(12, 1.2, 4), WOOD, Enum.Material.WoodPlanks)
	for i = 1, 3 do
		ball(m, o, "Veg", 0.9, Vector3.new(11.4 + i * 0.4, 2.6, 3.4 + (i % 2) * 0.8), Color3.fromRGB(255, 140, 50))
	end
end

BUILD.field = function(m, o, info, ownerId)
	markSoil(soilBed(m, o, info.soil.X, info.soil.Z), ownerId, info.id)
	local post = P(m, o, "SignPost", Vector3.new(0.6, 4, 0.6), CFrame.new(-15, 2, 12), WOOD_DARK, Enum.Material.Wood)
	local board = P(m, o, "Sign", Vector3.new(7, 2, 0.4), CFrame.new(-15, 4.4, 12), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	textSign(board, info.icon .. " " .. info.name, Color3.fromRGB(120, 170, 70))
end

BUILD.orchard = function(m, o, info, ownerId)
	P(m, o, "Lawn", Vector3.new(34, 0.3, 24), CFrame.new(0, 0.15, 0), Color3.fromRGB(110, 200, 90), Enum.Material.Grass)
	markSoil(soilBed(m, o, info.soil.X, info.soil.Z), ownerId, info.id)
	-- flower tufts around the soil bed (on the lawn, outside the planting area)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		tuft(m, o, Vector3.new(math.cos(a) * 16, 0, math.sin(a) * 11.5), RAINBOW[(i % #RAINBOW) + 1])
	end
	local board = P(m, o, "Sign", Vector3.new(7, 2, 0.4), CFrame.new(-15, 4.4, 12), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	P(m, o, "SignPost", Vector3.new(0.6, 4, 0.6), CFrame.new(-15, 2, 12), WOOD_DARK, Enum.Material.Wood)
	textSign(board, info.icon .. " " .. info.name, Color3.fromRGB(120, 170, 70))
end

local function hut(m, o, roofColor)
	P(m, o, "Floor", Vector3.new(10, 0.4, 9), CFrame.new(0, 0.2, 0), WOOD_DARK, Enum.Material.WoodPlanks)
	for _, w in ipairs({{0, -4.3, 10, 0.5}, {4.8, 0, 0.5, 9}, {-4.8, 0, 0.5, 9}}) do
		P(m, o, "Wall", Vector3.new(w[3], 6, w[4]), CFrame.new(w[1], 3.2, w[2]), Color3.fromRGB(235, 205, 150), Enum.Material.WoodPlanks, {CanCollide = true})
	end
	P(m, o, "FrontL", Vector3.new(3, 6, 0.5), CFrame.new(-3.5, 3.2, 4.3), Color3.fromRGB(235, 205, 150), Enum.Material.WoodPlanks, {CanCollide = true})
	P(m, o, "FrontR", Vector3.new(3, 6, 0.5), CFrame.new(3.5, 3.2, 4.3), Color3.fromRGB(235, 205, 150), Enum.Material.WoodPlanks, {CanCollide = true})
	P(m, o, "FrontTop", Vector3.new(4, 1.5, 0.5), CFrame.new(0, 5.45, 4.3), Color3.fromRGB(235, 205, 150), Enum.Material.WoodPlanks)
	local roofL = Instance.new("WedgePart")
	roofL.Name = "Roof" roofL.Anchored = true roofL.Size = Vector3.new(11, 3.5, 5.6) roofL.Color = roofColor roofL.Material = Enum.Material.SmoothPlastic
	roofL.CFrame = o * CFrame.new(0, 7.95, -2.4) * CFrame.Angles(0, math.pi, 0)
	roofL.Parent = m
	local roofR = roofL:Clone()
	roofR.CFrame = o * CFrame.new(0, 7.95, 2.4)
	roofR.Parent = m
	ball(m, o, "Window", 1.6, Vector3.new(4.9, 4, 0), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
end

BUILD.helper_hut = function(m, o, info, ownerId)
	-- V1.1 cleanup: the small hut building was removed; the helpers' storage crate and the
	-- collect pad stay (they are the gameplay part of this upgrade)
	-- storage crate + collect pad
	local storage = Instance.new("Model")
	storage.Name = "Storage"
	local crate = P(storage, o, "Crate", Vector3.new(5, 4, 5), CFrame.new(-10, 2, 1), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	for i = 1, 5 do
		ball(storage, o, "Coin", 1.2, Vector3.new(-11.5 + i * 0.6, 4.3, 0.2 + (i % 2) * 1.2), GOLD, Enum.Material.Foil)
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StorageGui"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 90
	gui.Parent = crate
	local l = Instance.new("TextLabel")
	l.Name = "Amount"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = GOLD
	l.Text = "💰 0"
	l.Parent = gui
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Color = Color3.fromRGB(70, 50, 40) st.Parent = l
	local pad = P(storage, o, "CollectPad", Vector3.new(0.4, 6, 6), CFrame.new(-10, 0.25, 6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 215, 70), Enum.Material.Neon, withShape({CanTouch = true}))
	storage.PrimaryPart = crate
	storage.Parent = m
	local padGui = Instance.new("BillboardGui")
	padGui.Size = UDim2.fromOffset(160, 40)
	padGui.StudsOffset = Vector3.new(0, 1.5, 0)
	padGui.MaxDistance = 60
	padGui.Parent = pad
	local pl = l:Clone() pl.Name = "Text" pl.Text = "Step here to collect!" pl.TextColor3 = Color3.new(1, 1, 1) pl.Parent = padGui
end

BUILD.helper = function(m, o, info, ownerId)
	if info.id == "helper_3" then
		-- scarecrow
		P(m, o, "Pole", Vector3.new(0.6, 8, 0.6), CFrame.new(0, 4, 0), WOOD_DARK, Enum.Material.Wood)
		P(m, o, "Arms", Vector3.new(6, 0.5, 0.5), CFrame.new(0, 5.5, 0), WOOD_DARK, Enum.Material.Wood)
		P(m, o, "Shirt", Vector3.new(3, 3, 1.2), CFrame.new(0, 5, 0), Color3.fromRGB(90, 140, 220), Enum.Material.Fabric)
		ball(m, o, "Head", 2, Vector3.new(0, 7.6, 0), Color3.fromRGB(245, 215, 140), Enum.Material.Fabric)
		cyl(m, o, "HatBrim", 0.3, 3.2, CFrame.new(0, 8.6, 0), Color3.fromRGB(200, 160, 80), Enum.Material.Fabric, {Shape = Enum.PartType.Cylinder})
		cyl(m, o, "HatTop", 1.2, 1.8, CFrame.new(0, 9.3, 0), Color3.fromRGB(200, 160, 80), Enum.Material.Fabric, {Shape = Enum.PartType.Cylinder})
	else
		-- wheelbarrow full of fruit
		P(m, o, "Tub", Vector3.new(4, 1.6, 2.6), CFrame.new(0, 1.8, 0), Color3.fromRGB(90, 160, 220))
		cyl(m, o, "Wheel", 0.5, 1.6, CFrame.new(2.4, 0.8, 0) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(60, 60, 60), nil, {Shape = Enum.PartType.Cylinder})
		P(m, o, "Handle", Vector3.new(3, 0.3, 0.3), CFrame.new(-3, 1.6, 0.9), WOOD_DARK, Enum.Material.Wood)
		P(m, o, "Handle", Vector3.new(3, 0.3, 0.3), CFrame.new(-3, 1.6, -0.9), WOOD_DARK, Enum.Material.Wood)
		for i = 1, 6 do
			ball(m, o, "Fruit", 1, Vector3.new(-1.2 + (i % 3) * 1.1, 2.8, -0.5 + math.floor(i / 4) * 1), RAINBOW[i])
		end
	end
end

BUILD.path = function(m, o, info, ownerId)
	local tileColor = Color3.fromRGB(235, 220, 185)
	for _, x in ipairs({-21, 21}) do
		P(m, o, "Path", Vector3.new(5, 0.3, 124), CFrame.new(x, 0.15, -1), tileColor, Enum.Material.Cobblestone)
	end
	for _, z in ipairs({27, -3, -33}) do
		P(m, o, "Path", Vector3.new(124, 0.3, 5), CFrame.new(0, 0.16, z), tileColor, Enum.Material.Cobblestone)
	end
	P(m, o, "Path", Vector3.new(8, 0.3, 14), CFrame.new(0, 0.16, 63), tileColor, Enum.Material.Cobblestone)
	local n = 0
	for _, x in ipairs({-24, -18, 18, 24}) do
		for z = -58, 58, 8 do
			n += 1
			tuft(m, o, Vector3.new(x, 0, z), RAINBOW[(n % #RAINBOW) + 1])
		end
	end
end

BUILD.sprinklers = function(m, o, info, ownerId)
	-- V1.1 cleanup: the blue sprinkler props are no longer built. The upgrade and its
	-- +40% growth effect (FarmUpgrades effect.growth) are unchanged.
	if true then
		return
	end
	for _, x in ipairs({-21, 21}) do
		for _, z in ipairs({42, 12, -18, -48}) do
			cyl(m, o, "Pipe", 3, 0.5, CFrame.new(x, 1.5, z), Color3.fromRGB(120, 130, 140), Enum.Material.Metal, {Shape = Enum.PartType.Cylinder})
			local head = ball(m, o, "Head", 1, Vector3.new(x, 3.2, z), Color3.fromRGB(90, 170, 230), Enum.Material.Metal)
			local a = Instance.new("Attachment") a.Parent = head
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
			e.Size = NumberSequence.new(0.35)
			e.Lifetime = NumberRange.new(0.8, 1.1)
			e.Speed = NumberRange.new(9, 12)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Acceleration = Vector3.new(0, -30, 0)
			e.Rate = 30
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = a
		end
	end
end

BUILD.market = function(m, o, info, ownerId)
	for _, x in ipairs({-5, 5}) do
		P(m, o, "Post", Vector3.new(0.6, 7, 0.6), CFrame.new(x, 3.5, -2), WOOD_DARK, Enum.Material.Wood)
		P(m, o, "Post", Vector3.new(0.6, 7, 0.6), CFrame.new(x, 3.5, 2), WOOD_DARK, Enum.Material.Wood)
	end
	P(m, o, "Counter", Vector3.new(11, 2.6, 4), CFrame.new(0, 1.3, 1), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	for i = 0, 5 do
		P(m, o, "Awning", Vector3.new(11 / 6, 0.4, 6), CFrame.new(-5.5 + 11 / 12 + i * 11 / 6, 7.2, 0) * CFrame.Angles(math.rad(-12), 0, 0), if i % 2 == 0 then Color3.fromRGB(235, 70, 80) else WHITE)
	end
	for c = 1, 3 do
		local x = -3.6 + (c - 1) * 3.6
		P(m, o, "Box", Vector3.new(3, 1, 2.6), CFrame.new(x, 3.1, 1), WOOD_DARK, Enum.Material.WoodPlanks)
		for f = 1, 4 do
			ball(m, o, "Fruit", 0.9, Vector3.new(x - 0.8 + (f % 2) * 1.4, 3.9, 0.5 + math.floor(f / 3) * 0.9), RAINBOW[c * 2])
		end
	end
	local board = P(m, o, "Sign", Vector3.new(8, 1.8, 0.4), CFrame.new(0, 8.6, 2.8), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	textSign(board, "🍎 FRUIT MARKET 🍌", Color3.fromRGB(230, 90, 80))
end

BUILD.pond = function(m, o, info, ownerId)
	cyl(m, o, "Water", 0.5, 26, CFrame.new(0, 0.3, 0), Color3.fromRGB(90, 190, 240), Enum.Material.Glass, {Shape = Enum.PartType.Cylinder, Transparency = 0.15})
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2
		ball(m, o, "Rock", 2 + (i % 3) * 0.5, Vector3.new(math.cos(a) * 13.3, 0.4, math.sin(a) * 13.3), Color3.fromRGB(170 + (i % 3) * 15, 160, 150), Enum.Material.Slate)
	end
	for i = 1, 7 do
		local a = i * 0.9
		local r = 4 + (i % 3) * 2.6
		cyl(m, o, "LilyPad", 0.15, 2.6, CFrame.new(math.cos(a) * r, 0.62, math.sin(a) * r), Color3.fromRGB(90, 190, 80), nil, {Shape = Enum.PartType.Cylinder})
		if i % 2 == 1 then
			for p = 1, 5 do
				local pa = p / 5 * math.pi * 2
				ball(m, o, "Lotus", 0.6, Vector3.new(math.cos(a) * r + math.cos(pa) * 0.35, 0.95, math.sin(a) * r + math.sin(pa) * 0.35), Color3.fromRGB(255, 160, 210))
			end
			ball(m, o, "Lotus", 0.4, Vector3.new(math.cos(a) * r, 1.15, math.sin(a) * r), Color3.fromRGB(255, 230, 110))
		end
	end
end

BUILD.barn = function(m, o, info, ownerId)
	-- V1.1 cleanup: the red barn and blue silo are no longer built. The upgrade and its storage /
	-- helper-speed effects (FarmUpgrades) are unchanged.
	if true then
		return
	end
	local red = Color3.fromRGB(200, 60, 55)
	P(m, o, "Body", Vector3.new(22, 12, 16), CFrame.new(-2, 6, 0), red, Enum.Material.WoodPlanks, {CanCollide = true})
	local roof = Instance.new("WedgePart")
	roof.Name = "Roof" roof.Anchored = true roof.Size = Vector3.new(23, 6, 8.6) roof.Color = Color3.fromRGB(120, 60, 50)
	roof.CFrame = o * CFrame.new(-2, 15, -4.3) * CFrame.Angles(0, math.pi, 0) roof.Parent = m
	local roof2 = roof:Clone() roof2.CFrame = o * CFrame.new(-2, 15, 4.3) roof2.Parent = m
	P(m, o, "Door", Vector3.new(8, 8, 0.4), CFrame.new(-2, 4, 8.1), WHITE, Enum.Material.WoodPlanks)
	P(m, o, "DoorX", Vector3.new(10.5, 0.7, 0.3), CFrame.new(-2, 4, 8.35) * CFrame.Angles(0, 0, math.rad(45)), red)
	P(m, o, "DoorX", Vector3.new(10.5, 0.7, 0.3), CFrame.new(-2, 4, 8.35) * CFrame.Angles(0, 0, math.rad(-45)), red)
	P(m, o, "Loft", Vector3.new(3, 3, 0.4), CFrame.new(-2, 13, 8.1), WHITE, Enum.Material.WoodPlanks)
	-- silo
	cyl(m, o, "Silo", 16, 6, CFrame.new(12, 8, -2), Color3.fromRGB(210, 215, 225), Enum.Material.Metal, {Shape = Enum.PartType.Cylinder, CanCollide = true})
	ball(m, o, "SiloTop", 6, Vector3.new(12, 16, -2), Color3.fromRGB(120, 180, 230), Enum.Material.Metal)
	-- hay bales
	for i = 1, 3 do
		cyl(m, o, "Hay", 2.2, 2.4, CFrame.new(-10 + i * 3, 1.2, 11) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(235, 200, 90), Enum.Material.Fabric, {Shape = Enum.PartType.Cylinder})
	end
end

BUILD.windmill = function(m, o, info, ownerId)
	for s = 0, 3 do
		cyl(m, o, "Tower", 4, 6 - s * 0.9, CFrame.new(0, 2 + s * 4, 0), if s % 2 == 0 then WHITE else Color3.fromRGB(240, 235, 225), Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Cylinder, CanCollide = s == 0})
	end
	for s = 0, 2 do
		cyl(m, o, "Roof", 1.2, 3.8 - s * 1.2, CFrame.new(0, 16.6 + s * 1.2, 0), Color3.fromRGB(220, 80, 70), nil, {Shape = Enum.PartType.Cylinder})
	end
	P(m, o, "Door", Vector3.new(2.2, 3.4, 0.3), CFrame.new(0, 1.7, 2.9), WOOD_DARK, Enum.Material.Wood)
	local blades = Instance.new("Model")
	blades.Name = "Blades"
	local hub = P(blades, o, "Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 13.5, 3.2), WOOD_DARK, Enum.Material.Wood, {Shape = Enum.PartType.Ball})
	for b = 0, 3 do
		P(blades, o, "Blade", Vector3.new(1.6, 9, 0.2), CFrame.new(0, 13.5, 3.5) * CFrame.Angles(0, 0, b * math.pi / 2) * CFrame.new(0, 4.8, 0), Color3.fromRGB(245, 240, 230), Enum.Material.Fabric)
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("SpinAxis", "Z")
	CollectionService:AddTag(blades, "FarmSpin")
	blades.Parent = m
end

BUILD.greenhouse = function(m, o, info, ownerId)
	local w, d, h = 30, 20, 10
	markSoil(P(m, o, "Floor", Vector3.new(w, 0.4, d), CFrame.new(0, 0.2, 0), Color3.fromRGB(135, 95, 60), Enum.Material.Ground), ownerId, info.id)
	local glass = Color3.fromRGB(200, 240, 255)
	P(m, o, "Glass", Vector3.new(w, h, 0.3), CFrame.new(0, h / 2, -d / 2), glass, Enum.Material.Glass, {Transparency = 0.55})
	P(m, o, "Glass", Vector3.new(0.3, h, d), CFrame.new(w / 2, h / 2, 0), glass, Enum.Material.Glass, {Transparency = 0.55})
	P(m, o, "Glass", Vector3.new(0.3, h, d), CFrame.new(-w / 2, h / 2, 0), glass, Enum.Material.Glass, {Transparency = 0.55})
	P(m, o, "GlassL", Vector3.new(11, h, 0.3), CFrame.new(-9.5, h / 2, d / 2), glass, Enum.Material.Glass, {Transparency = 0.55})
	P(m, o, "GlassR", Vector3.new(11, h, 0.3), CFrame.new(9.5, h / 2, d / 2), glass, Enum.Material.Glass, {Transparency = 0.55})
	P(m, o, "Roof", Vector3.new(w, 0.3, d), CFrame.new(0, h, 0), glass, Enum.Material.Glass, {Transparency = 0.5})
	for _, x in ipairs({-w / 2, -w / 4, 0, w / 4, w / 2}) do
		P(m, o, "Frame", Vector3.new(0.4, h, 0.4), CFrame.new(x, h / 2, d / 2), WHITE)
		P(m, o, "Frame", Vector3.new(0.4, h, 0.4), CFrame.new(x, h / 2, -d / 2), WHITE)
		P(m, o, "Frame", Vector3.new(0.4, 0.4, d), CFrame.new(x, h, 0), WHITE)
	end
end

BUILD.fountain = function(m, o, info, ownerId)
	cyl(m, o, "Pool", 1.6, 18, CFrame.new(0, 0.8, 0), STONE, Enum.Material.Marble, {Shape = Enum.PartType.Cylinder, CanCollide = true})
	cyl(m, o, "Water", 0.3, 16, CFrame.new(0, 1.65, 0), Color3.fromRGB(110, 210, 255), Enum.Material.Glass, {Shape = Enum.PartType.Cylinder, Transparency = 0.1})
	cyl(m, o, "GoldRim", 0.4, 18.6, CFrame.new(0, 1.7, 0), GOLD, Enum.Material.Foil, {Shape = Enum.PartType.Cylinder, Transparency = 0})
	cyl(m, o, "Pillar", 6, 2, CFrame.new(0, 4.6, 0), GOLD, Enum.Material.Foil, {Shape = Enum.PartType.Cylinder})
	cyl(m, o, "Bowl", 1, 7, CFrame.new(0, 7.8, 0), GOLD, Enum.Material.Foil, {Shape = Enum.PartType.Cylinder})
	local top = ball(m, o, "Top", 2.4, Vector3.new(0, 9.4, 0), Color3.fromRGB(150, 230, 255), Enum.Material.Neon)
	local a = Instance.new("Attachment") a.Parent = top
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255), Color3.fromRGB(255, 240, 150))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.45, 0.1)
	e.Lifetime = NumberRange.new(1, 1.4)
	e.Speed = NumberRange.new(10, 14)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Rate = 40
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = a
	local light = Instance.new("PointLight") light.Color = GOLD light.Range = 18 light.Brightness = 1.5 light.Parent = top
end

BUILD.gate = function(m, o, info, ownerId)
	for _, x in ipairs({-11, 11}) do
		cyl(m, o, "Pillar", 14, 2.6, CFrame.new(x, 7, 0), WHITE, Enum.Material.Marble, {Shape = Enum.PartType.Cylinder, CanCollide = true})
		ball(m, o, "PillarTop", 3.2, Vector3.new(x, 14.6, 0), GOLD, Enum.Material.Foil)
		for f = 1, 8 do
			ball(m, o, "Garland", 1, Vector3.new(x + math.cos(f) * 1.4, f * 1.6, math.sin(f) * 1.4), RAINBOW[f])
		end
	end
	local beam = P(m, o, "Arch", Vector3.new(26, 3, 2), CFrame.new(0, 15.5, 0), GOLD, Enum.Material.Foil)
	local banner = P(m, o, "Banner", Vector3.new(20, 3.4, 0.3), CFrame.new(0, 12.4, 0), Color3.fromRGB(196, 146, 94))
	textSign(banner, "✨ FRUITBOUND PARADISE ✨", Color3.fromRGB(255, 150, 60))
	local a = Instance.new("Attachment") a.Parent = beam
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, RAINBOW[1]), ColorSequenceKeypoint.new(0.5, RAINBOW[4]), ColorSequenceKeypoint.new(1, RAINBOW[7])})
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.4, 0)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 25
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Parent = a
end

---------------------------------------------------------------- upgrades: functional pieces only (V1.1)
-- Upgrades build ONLY what gameplay needs: planting soil, the farm paths, and the helpers'
-- storage crate + collect pad. Everything decorative is left to the owner's Decor Bench.
-- (The BUILD.* builders above are kept: the Decor system reuses some of them, e.g. the
-- wheelbarrow and scarecrow decorations.)
local UPGRADE_BUILD = {}

local function plotSoil(m, o, info, ownerId)
	markSoil(soilBed(m, o, info.soil.X, info.soil.Z), ownerId, info.id)
end
UPGRADE_BUILD.starter = plotSoil
UPGRADE_BUILD.field = plotSoil
UPGRADE_BUILD.orchard = plotSoil
UPGRADE_BUILD.greenhouse = plotSoil

UPGRADE_BUILD.path = function(m, o, info, ownerId)
	local tileColor = Color3.fromRGB(235, 220, 185)
	for _, x in ipairs({-21, 21}) do
		P(m, o, "Path", Vector3.new(5, 0.3, 124), CFrame.new(x, 0.15, -1), tileColor, Enum.Material.Cobblestone)
	end
	for _, z in ipairs({27, -3, -33}) do
		P(m, o, "Path", Vector3.new(124, 0.3, 5), CFrame.new(0, 0.16, z), tileColor, Enum.Material.Cobblestone)
	end
	P(m, o, "Path", Vector3.new(8, 0.3, 14), CFrame.new(0, 0.16, 63), tileColor, Enum.Material.Cobblestone)
end

-- helpers' storage crate (shows the stored Coins) + the collect pad, where the hut used to stand
UPGRADE_BUILD.helper_hut = function(m, o, info, ownerId)
	local storage = Instance.new("Model")
	storage.Name = "Storage"
	local crate = P(storage, o, "Crate", Vector3.new(5, 4, 5), CFrame.new(0, 2, -2), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	for i = 1, 5 do
		ball(storage, o, "Coin", 1.2, Vector3.new(-1.5 + i * 0.6, 4.3, -2.8 + (i % 2) * 1.2), GOLD, Enum.Material.Foil)
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "StorageGui"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 90
	gui.Parent = crate
	local l = Instance.new("TextLabel")
	l.Name = "Amount"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = GOLD
	l.Text = "💰 0"
	l.Parent = gui
	local st = Instance.new("UIStroke") st.Thickness = 3 st.Color = Color3.fromRGB(70, 50, 40) st.Parent = l
	local pad = P(storage, o, "CollectPad", Vector3.new(0.4, 6, 6), CFrame.new(0, 0.25, 4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 215, 70), Enum.Material.Neon, withShape({CanTouch = true}))
	storage.PrimaryPart = crate
	storage.Parent = m
	local padGui = Instance.new("BillboardGui")
	padGui.Size = UDim2.fromOffset(160, 40)
	padGui.StudsOffset = Vector3.new(0, 1.5, 0)
	padGui.MaxDistance = 60
	padGui.Parent = pad
	local pl = l:Clone() pl.Name = "Text" pl.Text = "Step here to collect!" pl.TextColor3 = Color3.new(1, 1, 1) pl.Parent = padGui
end
-- helper, sprinklers, market, pond, barn, windmill, fountain, gate: effects only (no default decor)

---------------------------------------------------------------- decorations (placed by the player)
local DECOR = {}

DECOR.fence = function(m, o)
	for _, x in ipairs({-3.6, 0, 3.6}) do
		P(m, o, "Post", Vector3.new(0.7, 3.2, 0.7), CFrame.new(x, 1.6, 0), WOOD_DARK, Enum.Material.Wood, {CanCollide = true})
	end
	P(m, o, "Rail", Vector3.new(8, 0.4, 0.3), CFrame.new(0, 2.4, 0), WOOD, Enum.Material.Wood)
	P(m, o, "Rail", Vector3.new(8, 0.4, 0.3), CFrame.new(0, 1.3, 0), WOOD, Enum.Material.Wood)
end

DECOR.flower_pot = function(m, o)
	cyl(m, o, "Pot", 1.6, 2.4, CFrame.new(0, 0.8, 0), Color3.fromRGB(205, 110, 70), Enum.Material.Slate, {Shape = Enum.PartType.Cylinder, CanCollide = true})
	cyl(m, o, "Soil", 0.2, 2.1, CFrame.new(0, 1.62, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Ground, {Shape = Enum.PartType.Cylinder})
	local colors = {RAINBOW[1], RAINBOW[3], RAINBOW[8], RAINBOW[6]}
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		tuft(m, o, Vector3.new(math.cos(a) * 0.55, 1.6, math.sin(a) * 0.55), colors[i])
	end
end

DECOR.hay_bale = function(m, o)
	P(m, o, "Hay", Vector3.new(3.6, 2.2, 2.6), CFrame.new(0, 1.1, 0), Color3.fromRGB(235, 200, 90), Enum.Material.Fabric, {CanCollide = true})
	for _, x in ipairs({-0.9, 0.9}) do
		P(m, o, "Twine", Vector3.new(0.2, 2.26, 2.66), CFrame.new(x, 1.1, 0), Color3.fromRGB(170, 120, 60), Enum.Material.Fabric)
	end
end

DECOR.lantern = function(m, o)
	P(m, o, "Post", Vector3.new(0.5, 6, 0.5), CFrame.new(0, 3, 0), WOOD_DARK, Enum.Material.Wood, {CanCollide = true})
	P(m, o, "Arm", Vector3.new(1.6, 0.3, 0.3), CFrame.new(0.6, 5.8, 0), WOOD_DARK, Enum.Material.Wood)
	local lamp = P(m, o, "Lamp", Vector3.new(0.9, 1.1, 0.9), CFrame.new(1.2, 5.1, 0), Color3.fromRGB(255, 220, 140), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = lamp
	lamp:SetAttribute("NightLight", true)
end

DECOR.crate = function(m, o)
	P(m, o, "Crate", Vector3.new(2.8, 1.8, 2.8), CFrame.new(0, 0.9, 0), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	for i = 1, 5 do
		ball(m, o, "Veg", 0.9, Vector3.new(-0.8 + (i % 3) * 0.8, 1.95, -0.5 + math.floor(i / 3) * 0.9), if i % 2 == 0 then Color3.fromRGB(255, 140, 50) else Color3.fromRGB(120, 200, 80))
	end
end

DECOR.bench = function(m, o)
	P(m, o, "Seat", Vector3.new(5.6, 0.4, 1.8), CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	P(m, o, "Back", Vector3.new(5.6, 1.6, 0.35), CFrame.new(0, 2.5, 0.8), WOOD, Enum.Material.WoodPlanks)
	for _, x in ipairs({-2.4, 2.4}) do
		P(m, o, "Leg", Vector3.new(0.4, 1.5, 1.6), CFrame.new(x, 0.75, 0), WOOD_DARK, Enum.Material.Wood)
	end
end

DECOR.wheelbarrow = function(m, o)
	BUILD.helper(m, o, {id = "decor"}, nil)
end

DECOR.scarecrow = function(m, o)
	BUILD.helper(m, o, {id = "helper_3"}, nil)
end

DECOR.bird_bath = function(m, o)
	cyl(m, o, "Base", 0.5, 2.6, CFrame.new(0, 0.25, 0), STONE, Enum.Material.Marble, {Shape = Enum.PartType.Cylinder, CanCollide = true})
	cyl(m, o, "Pillar", 2.4, 0.9, CFrame.new(0, 1.7, 0), STONE, Enum.Material.Marble, {Shape = Enum.PartType.Cylinder})
	cyl(m, o, "Bowl", 0.6, 3.6, CFrame.new(0, 3.1, 0), STONE, Enum.Material.Marble, {Shape = Enum.PartType.Cylinder})
	cyl(m, o, "Water", 0.1, 3, CFrame.new(0, 3.42, 0), Color3.fromRGB(110, 200, 235), Enum.Material.Glass, {Shape = Enum.PartType.Cylinder, Transparency = 0.2})
	ball(m, o, "Bird", 0.7, Vector3.new(1.3, 3.75, 0), Color3.fromRGB(110, 170, 240))
	ball(m, o, "Beak", 0.25, Vector3.new(1.3, 3.8, -0.4), Color3.fromRGB(255, 190, 60))
end

-- Fruit Pen: a fenced meadow where the owner's resting (unequipped) fruits wander around.
-- Tagged "FruitPen"; the walk area is the part named "Meadow" (the client animates the fruits).
DECOR.fruit_pen = function(m, o)
	local w, d = 17, 13
	local meadow = P(m, o, "Meadow", Vector3.new(w - 0.6, 0.3, d - 0.6), CFrame.new(0, 0.15, 0), Color3.fromRGB(120, 205, 90), Enum.Material.Grass)
	meadow.CanQuery = false
	for _, s in ipairs({{0, d / 2, w, 0.3}, {0, -d / 2, w, 0.3}, {w / 2, 0, 0.3, d}, {-w / 2, 0, 0.3, d}}) do
		for _, y in ipairs({1.2, 2.2}) do
			P(m, o, "Rail", Vector3.new(s[3], 0.35, s[4]), CFrame.new(s[1], y, s[2]), Color3.fromRGB(245, 240, 230), Enum.Material.Wood, {CanCollide = true})
		end
	end
	for _, c in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}, {0, 1}, {0, -1}}) do
		P(m, o, "Post", Vector3.new(0.7, 2.9, 0.7), CFrame.new(c[1] * w / 2, 1.45, c[2] * d / 2), WHITE, Enum.Material.Wood, {CanCollide = true})
	end
	P(m, o, "Trough", Vector3.new(4, 1, 1.6), CFrame.new(-w / 2 + 3, 0.8, -d / 2 + 1.6), WOOD, Enum.Material.WoodPlanks)
	P(m, o, "TroughWater", Vector3.new(3.4, 0.2, 1.1), CFrame.new(-w / 2 + 3, 1.25, -d / 2 + 1.6), Color3.fromRGB(110, 200, 235), Enum.Material.Glass, {Transparency = 0.2})
	P(m, o, "Hay", Vector3.new(2.4, 1.6, 1.8), CFrame.new(w / 2 - 2.2, 0.95, d / 2 - 1.8), Color3.fromRGB(235, 200, 90), Enum.Material.Fabric)
	local board = P(m, o, "Sign", Vector3.new(5, 1.4, 0.25), CFrame.new(0, 3.3, d / 2 + 0.2), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	textSign(board, "🐾 Fruit Pen", Color3.fromRGB(230, 120, 150))
	P(m, o, "SignPost", Vector3.new(0.4, 3, 0.4), CFrame.new(0, 1.5, d / 2 + 0.2), WOOD_DARK, Enum.Material.Wood)
	CollectionService:AddTag(m, "FruitPen")
end

local function cropDecor(m, o, item, ownerId)
	local c = item.crop
	local info = {plant = {style = c.style, fruit = c.fruit, leaf = c.leaf}, rarity = c.rarity, value = c.value}
	if c.style == "Tree" then
		P(m, o, "Lawn", Vector3.new(7, 0.2, 7), CFrame.new(0, 0.1, 0), Color3.fromRGB(110, 200, 90), Enum.Material.Grass)
		plant(m, o, info, ownerId, Vector3.new(0, 0, 0))
	else
		soilBed(m, o, item.size.X - 0.6, item.size.Z - 0.6)
		for i = 1, c.count do
			plant(m, o, info, ownerId, Vector3.new((i - (c.count + 1) / 2) * 3.8, 0, 0))
		end
	end
end

-- item = FarmDecor entry, cf = where it stands (on the ground), rotation already included
function FarmBuilder.decor(item, cf, ownerId)
	local m = Instance.new("Model")
	m.Name = "Decor_" .. item.id
	if item.crop then
		cropDecor(m, cf, item, ownerId)
	elseif DECOR[item.id] then
		DECOR[item.id](m, cf)
	end
	-- invisible hit box so the whole piece can be clicked in "pick up" mode
	local hit = P(m, cf, "HitBox", Vector3.new(item.size.X, item.height or 3, item.size.Z), CFrame.new(0, (item.height or 3) / 2, 0), Color3.new(1, 1, 1), nil, {Transparency = 1, CanQuery = true})
	m.PrimaryPart = hit
	return m
end

-- the Decorate bench at the farm entrance (prompt opens the decoration menu on the client)
function FarmBuilder.workbench(cf)
	local m = Instance.new("Model")
	m.Name = "DecorBench"
	local top = P(m, cf, "Top", Vector3.new(5, 0.5, 2.6), CFrame.new(0, 2.6, 0), WOOD, Enum.Material.WoodPlanks, {CanCollide = true})
	for _, x in ipairs({-2.1, 2.1}) do
		for _, z in ipairs({-1, 1}) do
			P(m, cf, "Leg", Vector3.new(0.5, 2.4, 0.5), CFrame.new(x, 1.2, z), WOOD_DARK, Enum.Material.Wood)
		end
	end
	cyl(m, cf, "Pot", 1, 1.4, CFrame.new(-1.4, 3.35, 0), Color3.fromRGB(205, 110, 70), Enum.Material.Slate, {Shape = Enum.PartType.Cylinder})
	tuft(m, cf, Vector3.new(-1.4, 3.6, 0), RAINBOW[8])
	P(m, cf, "Hammer", Vector3.new(1.6, 0.25, 0.25), CFrame.new(1, 2.95, 0.3) * CFrame.Angles(0, 0.4, 0), WOOD_DARK, Enum.Material.Wood)
	P(m, cf, "HammerHead", Vector3.new(0.35, 0.35, 0.8), CFrame.new(1.7, 2.95, 0.6) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(120, 125, 135), Enum.Material.Metal)
	local post = P(m, cf, "SignPost", Vector3.new(0.5, 5.5, 0.5), CFrame.new(3, 2.75, -1), WOOD_DARK, Enum.Material.Wood)
	local board = P(m, cf, "Sign", Vector3.new(5, 1.6, 0.3), CFrame.new(3, 5.4, -0.8), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	textSign(board, "🌷 DECORATE", Color3.fromRGB(120, 170, 70))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DecoratePrompt"
	prompt.ActionText = "Decorate Farm"
	prompt.ObjectText = "Decor Bench"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	m.PrimaryPart = top
	return m
end

-- footprint (x, z size) an upgrade will use on the plot, for placement checks
-- (V1.1: only upgrades that still build something block owner decorations)
local KIND_FOOTPRINT = {
	starter = Vector3.new(22, 0, 16), field = Vector3.new(36, 0, 24), orchard = Vector3.new(26, 0, 16),
	greenhouse = Vector3.new(30, 0, 20), helper_hut = Vector3.new(7, 0, 14),
}
function FarmBuilder.footprint(info)
	return KIND_FOOTPRINT[info.kind]
end

-- "coming soon" marker for an upgrade that is not bought yet: corner stakes + a little sign
function FarmBuilder.plan(info, plotCFrame, costText)
	local model = Instance.new("Model")
	model.Name = "Plan_" .. info.id
	local o = plotCFrame * CFrame.new(info.at + Vector3.new(0, FarmBuilder.GROUND, 0))
	local fp = KIND_FOOTPRINT[info.kind] or Vector3.new(10, 0, 10)
	for _, c in ipairs({{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
		P(model, o, "Stake", Vector3.new(0.35, 1.4, 0.35), CFrame.new(c[1] * fp.X / 2, 0.7, c[2] * fp.Z / 2), WOOD_DARK, Enum.Material.Wood)
		P(model, o, "Flag", Vector3.new(0.6, 0.35, 0.05), CFrame.new(c[1] * fp.X / 2 + 0.3, 1.25, c[2] * fp.Z / 2), Color3.fromRGB(255, 205, 80), Enum.Material.Fabric)
	end
	P(model, o, "SignPost", Vector3.new(0.4, 2.6, 0.4), CFrame.new(0, 1.3, 0), WOOD_DARK, Enum.Material.Wood)
	local board = P(model, o, "Sign", Vector3.new(6, 1.5, 0.25), CFrame.new(0, 2.8, 0), Color3.fromRGB(196, 146, 94), Enum.Material.Wood)
	textSign(board, "🔒 " .. info.icon .. " " .. info.name .. "  •  " .. (costText or ""), Color3.fromRGB(150, 150, 150))
	return model
end

---------------------------------------------------------------- public
function FarmBuilder.build(info, plotCFrame, ownerId)
	local model = Instance.new("Model")
	model.Name = info.id
	model:SetAttribute("UpgradeId", info.id)
	local origin = plotCFrame * CFrame.new(info.at + Vector3.new(0, FarmBuilder.GROUND, 0))
	local builder = UPGRADE_BUILD[info.kind]
	if builder then
		builder(model, origin, info, ownerId)
	end
	return model
end

-- Purchase pad: glowing circle + floating price, plus a faint outline of what will be built
local FOOTPRINT = {field = Vector3.new(34, 0, 22), orchard = Vector3.new(34, 0, 24), greenhouse = Vector3.new(30, 0, 20), }

function FarmBuilder.pad(info, plotCFrame, ownerId, costText)
	local model = Instance.new("Model")
	model.Name = "Pad_" .. info.id
	local origin = plotCFrame * CFrame.new(info.at + Vector3.new(0, FarmBuilder.GROUND, 0))
	local pad = P(model, origin, "Pad", Vector3.new(0.4, 9, 9), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 230, 100), Enum.Material.Neon, withShape({CanTouch = true, Transparency = 0.15}))
	pad:SetAttribute("UpgradeId", info.id)
	pad:SetAttribute("Cost", info.cost)
	pad:SetAttribute("Owner", ownerId)
	CollectionService:AddTag(pad, "FarmPad")
	local ring = P(model, origin, "Ring", Vector3.new(0.3, 10.5, 10.5), CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), Enum.Material.Neon, withShape({Transparency = 0.3}))
	local fp = FOOTPRINT[info.kind]
	if fp then
		local outline = Color3.fromRGB(150, 240, 130)
		for _, s in ipairs({{0, fp.Z / 2, fp.X, 0.5}, {0, -fp.Z / 2, fp.X, 0.5}, {fp.X / 2, 0, 0.5, fp.Z}, {-fp.X / 2, 0, 0.5, fp.Z}}) do
			P(model, origin, "Outline", Vector3.new(s[3], 0.15, s[4]), CFrame.new(s[1], 0.1, s[2]), outline, Enum.Material.Neon, {Transparency = 0.45})
		end
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PadGui"
	-- sized in studs so it shrinks with distance (never covers the HUD)
	gui.Size = UDim2.fromScale(7.5, 3)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = pad
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
	frame.Parent = gui
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 16) c.Parent = frame
	local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(70, 50, 40) s.Parent = frame
	local nameL = Instance.new("TextLabel")
	nameL.Name = "UpgradeName"
	nameL.Size = UDim2.fromScale(0.92, 0.5)
	nameL.Position = UDim2.fromScale(0.04, 0.05)
	nameL.BackgroundTransparency = 1
	nameL.Font = FONT
	nameL.TextScaled = true
	nameL.TextColor3 = Color3.fromRGB(80, 55, 35)
	nameL.Text = info.icon .. " " .. info.name
	nameL.Parent = frame
	local price = nameL:Clone()
	price.Name = "Price"
	price.Position = UDim2.fromScale(0.04, 0.52)
	price.Size = UDim2.fromScale(0.92, 0.42)
	price.TextColor3 = Color3.fromRGB(255, 200, 60)
	price.Text = "💰 " .. (costText or tostring(info.cost))
	price.Parent = frame
	local ps = Instance.new("UIStroke")
	ps.Thickness = 2
	ps.Color = Color3.fromRGB(120, 70, 20)
	ps.Parent = price
	return model
end

-- A cute garden gnome that helps harvest
function FarmBuilder.helper()
	local m = Instance.new("Model")
	m.Name = "Helper"
	local o = CFrame.new()
	local root = P(m, o, "Root", Vector3.new(1.5, 3.4, 1.5), CFrame.new(0, 1.7, 0), Color3.new(1, 1, 1), nil, {Transparency = 1})
	m.PrimaryPart = root
	ball(m, o, "Body", 1.9, Vector3.new(0, 1.1, 0), Color3.fromRGB(80, 150, 230))
	ball(m, o, "Belt", 1.95, Vector3.new(0, 0.95, 0), Color3.fromRGB(110, 70, 40)).Size = Vector3.new(1.95, 1.95, 1.95)
	ball(m, o, "Head", 1.4, Vector3.new(0, 2.3, 0), Color3.fromRGB(255, 215, 180))
	ball(m, o, "Beard", 1.1, Vector3.new(0, 1.95, -0.45), WHITE)
	ball(m, o, "Nose", 0.45, Vector3.new(0, 2.3, -0.7), Color3.fromRGB(255, 160, 150))
	ball(m, o, "Eye", 0.2, Vector3.new(0.28, 2.55, -0.62), Color3.fromRGB(30, 30, 30))
	ball(m, o, "Eye", 0.2, Vector3.new(-0.28, 2.55, -0.62), Color3.fromRGB(30, 30, 30))
	for s = 0, 3 do
		cyl(m, o, "Hat", 0.5, 1.5 - s * 0.35, CFrame.new(0, 2.95 + s * 0.45, 0), Color3.fromRGB(230, 60, 70), nil, {Shape = Enum.PartType.Cylinder})
	end
	ball(m, o, "Basket", 0.9, Vector3.new(0.9, 1.2, -0.3), WOOD)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	CollectionService:AddTag(m, "FarmHelper")
	return m
end

return FarmBuilder
