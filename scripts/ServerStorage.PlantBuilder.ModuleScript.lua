--> PlantBuilder (edit-time tool)
-- Builds harvestable plant models in code. Used to place plants in gardens.
--   PlantBuilder.build(style, bloomColor, leafColor) -> Model
--   styles: "Flower", "Veggie", "Mushroom"
-- Every plant has:
--   Hitbox (invisible, PrimaryPart, pivot sits 2.75 studs above the ground)
--   6 parts named "Bloom" with attribute Index 1..6 (what gets picked; their children hide with them)
--   parts named "Leaf" (bounce when harvested)
-- Tag the model "HarvestBush" and set attribute Garden to make it harvestable.

local PlantBuilder = {}

local SOIL = Color3.fromRGB(125, 85, 55)

local function tint(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function newPart(model, name, shape, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- 6 spots in a ring (+ centre-ish) around the plant, y = height
local function ring(radius, height, jitter)
	local spots = {}
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + (jitter or 0)
		table.insert(spots, Vector3.new(math.cos(a) * radius, height + ((i % 2 == 0) and 0.35 or 0), math.sin(a) * radius))
	end
	return spots
end

local function base(model, width)
	local hit = newPart(model, "Hitbox", Enum.PartType.Block, Vector3.new(6, 5.5, 6), CFrame.new(0, 2.75, 0), Color3.new(1, 1, 1))
	hit.Transparency = 1
	hit.CanQuery = true
	model.PrimaryPart = hit
	local soil = newPart(model, "Soil", Enum.PartType.Cylinder, Vector3.new(0.7, width, width), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), SOIL, Enum.Material.Sand)
	soil.CanCollide = true
	return hit
end

-- Flower bush: leafy clump with 6 flower heads (petals around a yellow heart)
local function flower(model, bloomColor, leafColor)
	base(model, 5)
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(3.6, 3.6, 3.6), CFrame.new(0, 1.9, 0), leafColor)
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(1.3, 1.5, 0.5), tint(leafColor, 0.9))
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(2.6, 2.6, 2.6), CFrame.new(-1.2, 1.4, -0.6), tint(leafColor, 1.1))
	for i, v in ipairs(ring(1.7, 2.9, 0.4)) do
		local outward = CFrame.lookAt(v, v * 2 + Vector3.new(0, 4, 0))
		local heart = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), outward, Color3.fromRGB(255, 225, 90))
		heart:SetAttribute("Index", i)
		for p = 1, 5 do
			local ang = (p / 5) * math.pi * 2
			local petal = newPart(model, "Petal", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), outward * CFrame.new(math.cos(ang) * 0.45, math.sin(ang) * 0.45, 0.05), tint(bloomColor, 0.95 + (p % 2) * 0.1))
			petal.Parent = heart
		end
	end
end

-- Veggie patch: 6 root veggies poking out of the soil with leafy tops
local function veggie(model, bloomColor, leafColor)
	base(model, 5.6)
	local leaf = newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.9, 0), leafColor)
	leaf.Transparency = 0
	for i, v in ipairs(ring(1.6, 0.75, 0)) do
		local root = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), CFrame.new(v), bloomColor)
		root:SetAttribute("Index", i)
		for l = 1, 3 do
			local ang = (l / 3) * math.pi * 2 + i
			local stalk = newPart(model, "Stalk", Enum.PartType.Block, Vector3.new(0.18, 1.5, 0.45),
				CFrame.new(v + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, ang, math.rad(18)), tint(leafColor, 0.9 + l * 0.05))
			stalk.Parent = root
		end
	end
end

-- Mushroom patch: 6 mushrooms of different heights with spotted caps
local function mushroom(model, bloomColor, leafColor)
	base(model, 5)
	local moss = newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 0.6, 0), leafColor)
	for i, v in ipairs(ring(1.5, 0, 0.3)) do
		local h = 1.2 + (i % 3) * 0.6
		local stem = newPart(model, "Bloom", Enum.PartType.Cylinder, Vector3.new(h, 0.55, 0.55), CFrame.new(v + Vector3.new(0, 0.5 + h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 235, 215))
		stem:SetAttribute("Index", i)
		local cap = newPart(model, "Cap", Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), CFrame.new(v + Vector3.new(0, 0.55 + h, 0)), bloomColor)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, 0.55, 1)
		mesh.Parent = cap
		cap.Parent = stem
		for s = 1, 3 do
			local ang = s * 2.1 + i
			local dot = newPart(model, "Spot", Enum.PartType.Ball, Vector3.new(0.28, 0.28, 0.28), CFrame.new(v + Vector3.new(math.cos(ang) * 0.4, 0.8 + h, math.sin(ang) * 0.4)), Color3.new(1, 1, 1))
			dot.Parent = stem
		end
	end
end

-- Berry bush: low round bush covered in small berries (strawberries, blueberries...)
local function berry(model, bloomColor, leafColor)
	base(model, 4.6)
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(3.2, 3.2, 3.2), CFrame.new(0, 1.2, 0), leafColor)
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(1.1, 1.0, -0.6), tint(leafColor, 0.9))
	newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(2.4, 2.4, 2.4), CFrame.new(-1.0, 1.0, 0.7), tint(leafColor, 1.1))
	for i, v in ipairs(ring(1.55, 1.5, 0.2)) do
		local b = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), CFrame.new(v + Vector3.new(0, (i % 3) * 0.25, 0)), bloomColor)
		b:SetAttribute("Index", i)
		local cap = newPart(model, "Cap", Enum.PartType.Block, Vector3.new(0.5, 0.15, 0.5), CFrame.new(b.Position + Vector3.new(0, 0.42, 0)), Color3.fromRGB(60, 160, 60))
		cap.Parent = b
	end
end

-- Fruit tree: trunk + leafy crown with 6 fruits hanging from it
local function tree(model, bloomColor, leafColor, opts)
	opts = opts or {}
	base(model, 4)
	local trunkColor = opts.trunk or Color3.fromRGB(140, 95, 60)
	newPart(model, "Trunk", Enum.PartType.Cylinder, Vector3.new(7, 1.4, 1.4), CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, math.rad(90)), trunkColor, Enum.Material.Wood)
	local crownMat = opts.crownMaterial or Enum.Material.SmoothPlastic
	local l1 = newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(6.5, 6.5, 6.5), CFrame.new(0, 8.6, 0), leafColor, crownMat)
	local l2 = newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(4.6, 4.6, 4.6), CFrame.new(2.3, 7.6, 0.8), tint(leafColor, 0.9), crownMat)
	local l3 = newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(4.6, 4.6, 4.6), CFrame.new(-2.2, 7.8, -0.9), tint(leafColor, 1.1), crownMat)
	if opts.crownTransparency then
		for _, l in ipairs({l1, l2, l3}) do l.Transparency = opts.crownTransparency end
	end
	for i, v in ipairs(ring(2.9, 6.9, 0.5)) do
		local f = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.2), CFrame.new(v), bloomColor, opts.fruitMaterial)
		f:SetAttribute("Index", i)
		local stem = newPart(model, "Stem", Enum.PartType.Block, Vector3.new(0.15, 0.5, 0.15), CFrame.new(v + Vector3.new(0, 0.7, 0)), Color3.fromRGB(90, 60, 30))
		stem.Parent = f
	end
end

-- Palm tree: tall trunk, drooping fronds, tropical fruits (coconuts, pineapples...)
local function palm(model, bloomColor, leafColor)
	base(model, 4)
	for s = 0, 4 do
		newPart(model, "Trunk", Enum.PartType.Cylinder, Vector3.new(2.2, 1.3 - s * 0.08, 1.3 - s * 0.08),
			CFrame.new(s * 0.18, 1.2 + s * 2, 0) * CFrame.Angles(0, 0, math.rad(90)), if s % 2 == 0 then Color3.fromRGB(170, 120, 75) else Color3.fromRGB(150, 105, 65), Enum.Material.Wood)
	end
	local top = Vector3.new(0.9, 10.6, 0)
	for f = 1, 7 do
		local a = (f / 7) * math.pi * 2
		local frond = newPart(model, "Leaf", Enum.PartType.Block, Vector3.new(5.5, 0.25, 1.4),
			CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(2.4, 0, 0) * CFrame.Angles(0, 0, math.rad(-22)), tint(leafColor, 0.9 + (f % 2) * 0.15))
	end
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		local v = top + Vector3.new(math.cos(a) * 0.9, -0.9 - (i % 2) * 0.4, math.sin(a) * 0.9)
		local f = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), CFrame.new(v), bloomColor)
		f:SetAttribute("Index", i)
	end
end

-- Melon patch: vines on the ground with 6 big melons
local function melon(model, bloomColor, leafColor)
	base(model, 6)
	for l = 1, 5 do
		local a = l * 1.3
		newPart(model, "Leaf", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(math.cos(a) * 1.2, 0.7, math.sin(a) * 1.2), tint(leafColor, 0.9 + (l % 2) * 0.15))
	end
	for i, v in ipairs(ring(2.0, 1.05, 0.3)) do
		local m = newPart(model, "Bloom", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), CFrame.new(v - Vector3.new(0, (i % 2) * 0.35, 0)), bloomColor)
		m:SetAttribute("Index", i)
		for s = 1, 3 do
			local stripe = newPart(model, "Stripe", Enum.PartType.Ball, Vector3.new(0.35, 0.35, 0.35), CFrame.new(m.Position + Vector3.new(math.cos(s * 2) * 0.62, 0.45, math.sin(s * 2) * 0.62)), tint(bloomColor, 0.65))
			stripe.Parent = m
		end
	end
end

local STYLES = {Flower = flower, Veggie = veggie, Mushroom = mushroom, Berry = berry, Tree = tree, Palm = palm, Melon = melon}

-- opts (optional, trees only): trunk, crownMaterial, crownTransparency, fruitMaterial
function PlantBuilder.build(style, bloomColor, leafColor, opts)
	local model = Instance.new("Model")
	model.Name = "Plant"
	;(STYLES[style] or flower)(model, bloomColor or Color3.fromRGB(255, 120, 170), leafColor or Color3.fromRGB(95, 200, 90), opts)
	model:SetAttribute("Fruits", 6)
	model:SetAttribute("Style", style)
	return model
end

-- Which style each garden uses (by garden id)
function PlantBuilder.styleFor(gardenId)
	local styles = {"Flower", "Veggie", "Mushroom"}
	return styles[(gardenId % 3) + 1]
end

return PlantBuilder
