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

-- ============================================================
-- SEED CROPS: ONE plant per crop (FarmingV2). Every planted Seed is its own single plant that
-- looks different at each growth stage, instead of a patch of 6 identical plants.
--   PlantBuilder.buildCrop(seed, stage) -> Model
--   stage: "Stage1" (sprout) | "Stage2" | "Stage3" | "Mature" | "Harvested" (regrowing)
-- Same conventions as build(): PrimaryPart "Hitbox" (bottom on the ground, tap target),
-- ONE "Bloom" part with Index 1 (the crop that gets picked; its children hide with it), "Leaf" parts.
-- The model is built at scale 1; FarmingV2 scales the whole model for size rolls / overgrowth.
-- ============================================================

local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles

-- Block part with a sphere mesh = smooth ellipsoid of any proportions (scales with Model:ScaleTo)
local function ellipsoid(model, name, size, cf, color, material)
	local p = newPart(model, name, Enum.PartType.Block, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- vertical cylinder from y0 to y0 + height, centred on (x, z), optionally tilted
local function stem(model, name, height, width, at, color, tilt)
	local cf = CF(at) * (tilt or CFrame.identity) * CF(0, height / 2, 0) * ANG(0, 0, math.rad(90))
	return newPart(model, name, Enum.PartType.Cylinder, V(height, width, width), cf, color)
end

-- small soil mound every crop sits in
local function mound(model, width)
	return ellipsoid(model, "Soil", V(width, 0.5, width), CF(0, 0.15, 0), SOIL, Enum.Material.Sand)
end

local function parentTo(parts, parent)
	for _, p in ipairs(parts) do
		p.Parent = parent
	end
end

local CROP_SHAPES = {}

-- Clover: a low tuft of trefoil leaves; the picked crop is the lucky FOUR-leaf clover in the middle
function CROP_SHAPES.Clover(model, seed, fruit)
	mound(model, 2.6)
	local stalk = tint(seed.leaf, 0.85)
	for i = 1, 5 do
		local a = i * math.pi * 2 / 5 + 0.3
		local tilt = ANG(0, a, math.rad(28))
		local top = CF(0, 0.2, 0) * tilt * CF(0, 1.3, 0)
		stem(model, "Stalk", 1.3, 0.12, V(0, 0.2, 0), stalk, tilt)
		for l = 1, 3 do
			local la = l * math.pi * 2 / 3
			ellipsoid(model, "Leaf", V(0.62, 0.1, 0.5), CF(top.Position) * ANG(0, la + a, 0) * CF(0.3, 0, 0) * ANG(0, 0, math.rad(-10)), tint(seed.leaf, 0.95 + (l % 2) * 0.1))
		end
	end
	if fruit > 0 then
		local h = 1.9
		stem(model, "Stalk", h, 0.14, V(0, 0.2, 0), stalk)
		local heart = ellipsoid(model, "Bloom", V(0.3, 0.3, 0.3) * fruit, CF(0, 0.2 + h, 0), tint(seed.fruit, 0.8))
		heart:SetAttribute("Index", 1)
		local leaves = {}
		for l = 1, 4 do
			local la = l * math.pi / 2
			table.insert(leaves, ellipsoid(model, "Petal", V(0.9, 0.14, 0.72) * fruit, CF(0, 0.2 + h, 0) * ANG(0, la, 0) * CF(0.42 * fruit, 0, 0) * ANG(0, 0, math.rad(-12)), seed.fruit))
		end
		parentTo(leaves, heart)
	end
end

-- Mint: one upright square stem with pairs of leaves; the picked crop is the fresh top cluster
function CROP_SHAPES.Leaf(model, seed, fruit)
	mound(model, 2.2)
	local h = 3.2
	newPart(model, "Stalk", Enum.PartType.Block, V(0.2, h, 0.2), CF(0, h / 2, 0), tint(seed.leaf, 0.8))
	for node = 1, 4 do
		local y = 0.5 + (node - 1) * 0.75
		local turn = if node % 2 == 0 then math.pi / 2 else 0
		local size = 1.15 - node * 0.12
		for side = -1, 1, 2 do
			ellipsoid(model, "Leaf", V(size, 0.1, size * 0.6), CF(0, y, 0) * ANG(0, turn, 0) * CF(side * size * 0.5, 0, 0) * ANG(0, 0, math.rad(side * -18)), tint(seed.leaf, 0.9 + node * 0.05))
		end
	end
	if fruit > 0 then
		local top = ellipsoid(model, "Bloom", V(0.55, 0.7, 0.55) * fruit, CF(0, h + 0.2, 0), seed.fruit)
		top:SetAttribute("Index", 1)
		local leaves = {}
		for l = 1, 4 do
			local a = l * math.pi / 2 + math.pi / 4
			table.insert(leaves, ellipsoid(model, "Petal", V(0.8, 0.1, 0.45) * fruit, CF(0, h + 0.1, 0) * ANG(0, a, 0) * CF(0.38 * fruit, 0, 0) * ANG(0, 0, math.rad(30)), tint(seed.fruit, 1.05)))
		end
		parentTo(leaves, top)
	end
end

-- Carrot: ONE big carrot with its shoulder out of the soil and a feathery fan of leaves
function CROP_SHAPES.Veggie(model, seed, fruit)
	mound(model, 2.4)
	-- the carrot sits in the mound (bottom at the ground), its leaves grow from its top
	local length = 2.2 * fruit
	local leafBase = 0.4 + length * 0.8
	for i = 1, 6 do
		local a = i * math.pi * 2 / 6
		local tilt = ANG(0, a, math.rad(16 + (i % 2) * 10))
		local len = 2.2 + (i % 3) * 0.35
		stem(model, "Stalk", len, 0.12, V(0, leafBase, 0), tint(seed.leaf, 0.85), tilt)
		for f = 1, 3 do
			local at = CF(0, leafBase, 0) * tilt * CF(0, len * (0.45 + f * 0.17), 0)
			ellipsoid(model, "Leaf", V(0.55, 0.42, 0.55) * (1.1 - f * 0.15), at, tint(seed.leaf, 0.9 + f * 0.06))
		end
	end
	if fruit > 0 then
		local centre = length / 2 + 0.05
		local root = ellipsoid(model, "Bloom", V(1.15 * fruit, length, 1.15 * fruit), CF(0, centre, 0), seed.fruit)
		root:SetAttribute("Index", 1)
		local rings = {}
		for r = 1, 3 do
			local dy = (0.75 - r * 0.35) * fruit
			local width = 1.18 * fruit * math.sqrt(math.max(1 - (dy / (length / 2)) ^ 2, 0.05))
			table.insert(rings, newPart(model, "Stripe", Enum.PartType.Cylinder, V(0.06, width, width), CF(0, centre + dy, 0) * ANG(0, 0, math.rad(90)), tint(seed.fruit, 0.82)))
		end
		parentTo(rings, root)
	end
end

-- Sunflower: ONE tall sunflower, big leaves on the stem, a heavy head facing the sky
function CROP_SHAPES.Flower(model, seed, fruit)
	mound(model, 2.2)
	local h = 5.2
	stem(model, "Stalk", h, 0.38, V(0, 0.2, 0), tint(seed.leaf, 0.85))
	for i = 1, 4 do
		local y = 1 + i * 0.8
		local a = i * 2.2
		ellipsoid(model, "Leaf", V(1.9 - i * 0.2, 0.12, 1.05 - i * 0.1), CF(0, y, 0) * ANG(0, a, 0) * CF(0.95 - i * 0.08, 0, 0) * ANG(0, 0, math.rad(-20)), tint(seed.leaf, 0.9 + (i % 2) * 0.12))
	end
	local head = CF(0, h + 0.3, 0) * ANG(math.rad(-55), 0, 0) -- local Z = the way the flower faces
	if fruit > 0 then
		local heart = newPart(model, "Bloom", Enum.PartType.Cylinder, V(0.4, 1.8, 1.8) * fruit, head * ANG(0, math.rad(90), 0), Color3.fromRGB(110, 70, 40))
		heart:SetAttribute("Index", 1)
		local petals = {}
		for p = 1, 14 do
			local a = p * math.pi * 2 / 14
			table.insert(petals, ellipsoid(model, "Petal", V(0.55, 1.15, 0.12) * fruit, head * ANG(0, 0, a) * CF(0, 1.3 * fruit, -0.05), tint(seed.fruit, 0.92 + (p % 2) * 0.12)))
		end
		parentTo(petals, heart)
	else
		-- closed green bud before it blooms
		ellipsoid(model, "Leaf", V(0.8, 0.9, 0.8), head, tint(seed.leaf, 1.1))
	end
end

-- Glow Mushroom: ONE big mushroom; the picked crop is its glowing spotted cap
function CROP_SHAPES.Mushroom(model, seed, fruit)
	mound(model, 2.4)
	ellipsoid(model, "Leaf", V(1.4, 0.5, 1.4), CF(0, 0.35, 0), tint(seed.leaf, 0.9)) -- moss around the foot
	local h = 2.6
	stem(model, "Stalk", h, 0.9, V(0, 0.2, 0), Color3.fromRGB(245, 235, 215))
	ellipsoid(model, "Stalk", V(1.2, 0.7, 1.2), CF(0, 0.55, 0), Color3.fromRGB(240, 228, 205))
	if fruit > 0 then
		local cap = ellipsoid(model, "Bloom", V(3.2, 1.6, 3.2) * fruit, CF(0, h + 0.2, 0), seed.fruit)
		cap:SetAttribute("Index", 1)
		local extras = {ellipsoid(model, "Gills", V(2.6, 0.35, 2.6) * fruit, CF(0, h - 0.25 * fruit, 0), Color3.fromRGB(250, 240, 220))}
		for s = 1, 7 do
			local a = s * 2.4
			local r = (if s == 7 then 0 else 0.95) * fruit
			table.insert(extras, ellipsoid(model, "Spot", V(0.45, 0.2, 0.45) * fruit, CF(math.cos(a) * r, h + 0.2 + 0.72 * fruit - (if s == 7 then 0 else 0.15 * fruit), math.sin(a) * r), Color3.new(1, 1, 1), Enum.Material.Neon))
		end
		parentTo(extras, cap)
	else
		ellipsoid(model, "Leaf", V(1.3, 0.8, 1.3), CF(0, h + 0.1, 0), tint(seed.fruit, 0.75)) -- closed young cap
	end
end

-- Stage 1 of every crop: a little sprout with two seed leaves
local function sprout(model, seed)
	mound(model, 1.8)
	stem(model, "Stalk", 0.8, 0.12, V(0, 0.2, 0), tint(seed.leaf, 0.85))
	for side = -1, 1, 2 do
		ellipsoid(model, "Leaf", V(0.6, 0.1, 0.38), CF(side * 0.28, 1.0, 0) * ANG(0, 0, math.rad(side * -25)), seed.leaf)
	end
end

-- how tall the plant is (g) and how big its crop is (fruit, 0 = not there yet) at each stage
local CROP_STAGE_LOOK = {
	Stage2 = {g = 0.55, fruit = 0},
	Stage3 = {g = 0.8, fruit = 0.55},
	Mature = {g = 1, fruit = 1},
	Harvested = {g = 0.85, fruit = 0},
}

-- bakes a uniform scale (around the ground centre) into the parts, so the model stays at scale 1
local function bakeScale(model, g)
	if g == 1 then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Size *= g
			d.CFrame = CF(d.Position * g) * d.CFrame.Rotation
		end
	end
end

function PlantBuilder.buildCrop(seed, stage)
	local model = Instance.new("Model")
	model.Name = "Plant"
	local look = CROP_STAGE_LOOK[stage]
	local shape = CROP_SHAPES[seed.style]
	if seed.id == "apple_tree" then
		-- regrowable tree (not plantable yet): the classic fruit tree, without fruit while regrowing
		tree(model, seed.fruit, seed.leaf)
		model.PrimaryPart:Destroy()
		if not look or look.fruit <= 0 then
			for _, d in ipairs(model:GetChildren()) do
				if d.Name == "Bloom" then
					d:Destroy()
				end
			end
		end
		bakeScale(model, if look then look.g else 0.3)
	elseif stage == "Stage1" or not look or not shape then
		if shape then
			sprout(model, seed)
		else
			flower(model, seed.fruit, seed.leaf) -- unknown style: old flower bush
			model.PrimaryPart:Destroy()
		end
	else
		shape(model, seed, look.fruit)
		bakeScale(model, look.g)
	end
	-- number the pickable parts (one per plant; the old fallback bushes have several)
	local index = 0
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" then
			index += 1
			d:SetAttribute("Index", index)
		end
	end
	-- invisible tap target around the whole plant, bottom on the ground (FarmingV2.placeCrop)
	local bboxCF, bboxSize = model:GetBoundingBox()
	local width = math.max(bboxSize.X, bboxSize.Z, 3)
	local height = math.max(bboxCF.Position.Y + bboxSize.Y / 2, 1.5)
	local hit = newPart(model, "Hitbox", Enum.PartType.Block, V(width, height, width), CF(0, height / 2, 0), Color3.new(1, 1, 1))
	hit.Transparency = 1
	hit.CanQuery = true
	model.PrimaryPart = hit
	model:SetAttribute("Fruits", 1)
	model:SetAttribute("Style", seed.style)
	return model
end

-- Which style each garden uses (by garden id)
function PlantBuilder.styleFor(gardenId)
	local styles = {"Flower", "Veggie", "Mushroom"}
	return styles[(gardenId % 3) + 1]
end

return PlantBuilder
