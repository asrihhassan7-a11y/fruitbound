-- Procedurally builds the 10 themed islands, bridges, gates, ocean and lighting at server start.
-- Everything is anchored and static. Decor is deterministic (seeded per zone).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Zones = require(Shared.Config.Zones)
local Trajectory = require(Shared.Trajectory)
local Util = require(Shared.Util)

local WorldBuilder = {}

local map: Folder
local folders: { [string]: Folder } = {}

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	local sphere = props.Sphere
	props.Sphere = nil
	for k, v in props do
		(p :: any)[k] = v
	end
	if sphere then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	p.Parent = parent
	return p
end

local function deco(props, parent)
	props.CanCollide = props.CanCollide == true
	props.CanQuery = false
	props.CanTouch = false
	return part(props, parent)
end

local function cyl(pos: Vector3, h: number, d: number, color: Color3, parent: Instance, mat: Enum.Material?)
	return deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or Enum.Material.SmoothPlastic, CanCollide = true }, parent)
end

local function ball(pos: Vector3, size: Vector3, color: Color3, parent: Instance, mat: Enum.Material?)
	return deco({ Sphere = true, Size = size, CFrame = CFrame.new(pos), Color = color, Material = mat or Enum.Material.SmoothPlastic }, parent)
end

-- Decor recipes ---------------------------------------------------------------
local R: Random
local function rcol(c: Color3, v: number): Color3
	local h, s, val = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(val + R:NextNumber(-v, v), 0, 1))
end

local recipes = {}
function recipes.tree(pos, z, parent, leaf)
	local h = R:NextNumber(8, 14)
	cyl(pos, h, R:NextNumber(1.4, 2), Color3.fromRGB(120, 85, 55), parent, Enum.Material.Wood)
	local c = leaf or rcol(z.ground, 0.12)
	for i = 1, 3 do
		local sz = R:NextNumber(6, 9)
		ball(pos + Vector3.new(R:NextNumber(-2, 2), h + i * 1.6 - 1, R:NextNumber(-2, 2)), Vector3.new(sz, sz * 0.85, sz), c, parent)
	end
end
function recipes.pine(pos, z, parent, snowy)
	local h = R:NextNumber(10, 16)
	cyl(pos, h * 0.4, 1.4, Color3.fromRGB(100, 70, 45), parent, Enum.Material.Wood)
	for i = 0, 3 do
		local w = (4 - i) * 2.4
		local c = snowy and (i % 2 == 0 and Color3.fromRGB(240, 250, 255) or Color3.fromRGB(60, 120, 90)) or rcol(Color3.fromRGB(40, 110, 60), 0.08)
		ball(pos + Vector3.new(0, h * 0.35 + i * 2.6, 0), Vector3.new(w, 3.4, w), c, parent)
	end
end
function recipes.rock(pos, z, parent)
	local s = R:NextNumber(3, 8)
	deco({ Sphere = true, Size = Vector3.new(s * 1.3, s * 0.8, s), CFrame = CFrame.new(pos + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(0, R:NextNumber(0, 6), 0), Color = rcol(z.edge, 0.1), Material = Enum.Material.Slate, CanCollide = true }, parent)
end
function recipes.flowers(pos, z, parent)
	local colors = { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 230, 90), Color3.fromRGB(150, 140, 255), Color3.fromRGB(255, 255, 255) }
	for _ = 1, 5 do
		local p = pos + Vector3.new(R:NextNumber(-4, 4), 0.6, R:NextNumber(-4, 4))
		cyl(p - Vector3.new(0, 0.6, 0), 1, 0.2, Color3.fromRGB(70, 160, 60), parent)
		ball(p + Vector3.new(0, 0.5, 0), Vector3.new(0.9, 0.6, 0.9), colors[R:NextInteger(1, #colors)], parent)
	end
end
function recipes.mushroom(pos, z, parent)
	local h = R:NextNumber(2, 5)
	cyl(pos, h, h * 0.35, Color3.fromRGB(245, 235, 215), parent)
	ball(pos + Vector3.new(0, h, 0), Vector3.new(h * 1.4, h * 0.7, h * 1.4), R:NextNumber() < 0.5 and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(200, 120, 255), parent)
end
function recipes.lava(pos, z, parent)
	local d = R:NextNumber(10, 20)
	deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, d, d), CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 100, 20), Material = Enum.Material.Neon }, parent)
end
function recipes.crystal(pos, z, parent, color)
	local c = color or z.accent
	for _ = 1, R:NextInteger(2, 4) do
		local h = R:NextNumber(4, 12)
		deco({ Size = Vector3.new(h * 0.25, h, h * 0.25), CFrame = CFrame.new(pos + Vector3.new(R:NextNumber(-2, 2), h * 0.4, R:NextNumber(-2, 2))) * CFrame.Angles(R:NextNumber(-0.4, 0.4), R:NextNumber(0, 3), R:NextNumber(-0.4, 0.4)), Color = rcol(c, 0.1), Material = Enum.Material.Neon, Transparency = 0.15 }, parent)
	end
end
function recipes.icespike(pos, z, parent)
	recipes.crystal(pos, z, parent, Color3.fromRGB(190, 230, 255))
end
function recipes.cloud(pos, z, parent)
	local base = pos + Vector3.new(0, R:NextNumber(4, 18), 0)
	for _ = 1, 4 do
		local s = R:NextNumber(5, 9)
		ball(base + Vector3.new(R:NextNumber(-5, 5), R:NextNumber(-1, 1), R:NextNumber(-3, 3)), Vector3.new(s * 1.4, s, s), Color3.new(1, 1, 1), parent)
	end
end
function recipes.pillar(pos, z, parent)
	local h = R:NextNumber(6, 16)
	cyl(pos, h, 3, Color3.fromRGB(235, 215, 170), parent, Enum.Material.Sandstone)
	deco({ Size = Vector3.new(4.4, 1, 4.4), CFrame = CFrame.new(pos + Vector3.new(0, h + 0.5, 0)), Color = Color3.fromRGB(220, 195, 140), Material = Enum.Material.Sandstone, CanCollide = true }, parent)
end
function recipes.obelisk(pos, z, parent)
	local h = R:NextNumber(8, 18)
	deco({ ClassName = "WedgePart", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, R:NextNumber(0, 6), 0), Color = Color3.fromRGB(25, 15, 40), CanCollide = true }, parent)
	ball(pos + Vector3.new(0, h + 1, 0), Vector3.new(1.4, 1.4, 1.4), z.accent, parent, Enum.Material.Neon)
end
function recipes.star(pos, z, parent)
	local s = R:NextNumber(0.6, 1.8)
	ball(pos + Vector3.new(0, R:NextNumber(6, 30), 0), Vector3.new(s, s, s), R:NextNumber() < 0.5 and z.accent or Color3.new(1, 1, 1), parent, Enum.Material.Neon)
end

local THEMES = {
	meadow = { "tree", "flowers", "rock" },
	forest = { "pine", "tree", "mushroom" },
	volcano = { "rock", "lava", "crystal" },
	frozen = { "snowpine", "icespike", "rock" },
	crystal = { "crystal", "rock", "mushroom" },
	sky = { "cloud", "tree", "flowers" },
	ancient = { "pillar", "rock", "palm" },
	shadow = { "obelisk", "crystal", "rock" },
	celestial = { "cloud", "star", "pillar" },
	cosmic = { "star", "crystal", "obelisk" },
}
recipes.snowpine = function(pos, z, parent)
	recipes.pine(pos, z, parent, true)
end
recipes.palm = function(pos, z, parent)
	recipes.tree(pos, z, parent, Color3.fromRGB(90, 170, 70))
end

local function label(parent: Instance, text: string, size: UDim2, offset: Vector3, maxDist: number?)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = size
	bb.StudsOffset = offset
	bb.MaxDistance = maxDist or 700
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
	return bb
end

local function buildBand(i: number)
	local z = Zones.List[i]
	local z0, z1 = Zones.band(i)
	local zmid = (z0 + z1) / 2
	R = Random.new(i * 7919)
	local zf = Instance.new("Folder")
	zf.Name = "Zone" .. i
	local ground = part({ Name = "Band" .. i, Size = Vector3.new(Zones.FIELD_W, 4, Zones.BAND), CFrame = CFrame.new(0, -2 + (i - 1) * 0.02, zmid), Color = z.ground, Material = (z.decor == "frozen") and Enum.Material.Snow or (z.decor == "ancient" and Enum.Material.Sand or Enum.Material.Grass) }, folders.Ground)
	ground:SetAttribute("Zone", i)
	-- band border stripe
	deco({ Size = Vector3.new(Zones.FIELD_W, 0.3, 1.2), CFrame = CFrame.new(0, 0.1, z0 + 0.6), Color = z.accent, Material = Enum.Material.Neon, Transparency = 0.3 }, zf)
	-- side scenery outside the field + a few props inside the band
	local kinds = THEMES[z.decor]
	for _, side in { -1, 1 } do
		for k = 1, 4 do
			local x = side * (Zones.FIELD_W / 2 + R:NextNumber(8, 40))
			recipes[kinds[(k % #kinds) + 1]](Vector3.new(x, 0, R:NextNumber(z0 + 4, z1 - 4)), z, zf)
		end
	end
	for _ = 1, 5 do
		recipes[kinds[R:NextInteger(1, #kinds)]](Vector3.new(R:NextNumber(-Zones.FIELD_W / 2 + 10, Zones.FIELD_W / 2 - 10), 0, R:NextNumber(z0 + 4, z1 - 4)), z, zf)
	end
	-- side cliffs so the field reads as a valley
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(60, 16 + i * 2, Zones.BAND), CFrame = CFrame.new(side * (Zones.FIELD_W / 2 + 70), 4 + i, zmid), Color = z.edge, Material = Enum.Material.Slate }, zf)
	end
	-- floating zone name
	-- zone name label at the near edge of the band (clients slide it in front of their own plot)
	local anchor = deco({ Name = "Sign" .. i, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, 3.5, z0 + 3), Transparency = 1 }, folders.Signs)
	anchor:SetAttribute("Zone", i)
	label(anchor, z.icon .. " " .. z.name .. "  x" .. z.mult, UDim2.fromScale(46, 5), Vector3.zero)
	zf.Parent = folders.Decor
end

local function buildPlot(i: number)
	local c = Zones.plotCenter(i)
	local f = Instance.new("Folder")
	f.Name = "Plot" .. i
	f:SetAttribute("Index", i)
	local W, D = Zones.PLOT_W, Zones.PLOT_D
	-- ground + curb
	deco({ Name = "Ground", Size = Vector3.new(W - 2, 2, D), CFrame = CFrame.new(c.X, -1, c.Z), Color = (i % 2 == 0) and Color3.fromRGB(120, 205, 95) or Color3.fromRGB(110, 195, 88), Material = Enum.Material.Grass, CanCollide = true }, f)
	deco({ Size = Vector3.new(W, 1.2, 1.2), CFrame = CFrame.new(c.X, 0.6, -D), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks, CanCollide = true }, f)
	for _, sx in { -1, 1 } do
		deco({ Size = Vector3.new(1.2, 1.2, D), CFrame = CFrame.new(c.X + sx * (W / 2 - 0.6), 0.6, c.Z), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks, CanCollide = true }, f)
	end
	-- throwing deck at the front
	deco({ Name = "Deck", Size = Vector3.new(W - 6, 1, 12), CFrame = CFrame.new(c.X, 0.5, -7), Color = Color3.fromRGB(196, 150, 95), Material = Enum.Material.WoodPlanks, CanCollide = true }, f)
	-- picket fence along the front
	for x = -W / 2 + 2, W / 2 - 2, 4 do
		deco({ Size = Vector3.new(0.8, 3.2, 0.8), CFrame = CFrame.new(c.X + x, 1.6, -0.6), Color = Color3.new(1, 1, 1), CanCollide = true }, f)
	end
	deco({ Size = Vector3.new(W - 2, 0.5, 0.5), CFrame = CFrame.new(c.X, 2.4, -0.6), Color = Color3.new(1, 1, 1) }, f)
	-- farm pen fence (separates deck from the dragon farm)
	deco({ Size = Vector3.new(W - 6, 1.6, 0.6), CFrame = CFrame.new(c.X, 0.8, -13.5), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.Wood }, f)
	-- invisible walls keep players on their own plot
	local function wall(size: Vector3, cf: CFrame)
		local w = part({ Name = "Wall", Size = size, CFrame = cf, Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false }, f)
		return w
	end
	wall(Vector3.new(W, 60, 1), CFrame.new(c.X, 30, 0.5))
	wall(Vector3.new(W, 60, 1), CFrame.new(c.X, 30, -D - 0.5))
	wall(Vector3.new(1, 60, D), CFrame.new(c.X - W / 2, 30, c.Z))
	wall(Vector3.new(1, 60, D), CFrame.new(c.X + W / 2, 30, c.Z))
	-- owner sign at the back
	local sign = deco({ Name = "Sign", Size = Vector3.new(18, 6, 1), CFrame = CFrame.new(c.X, 7, -D + 1), Color = Color3.fromRGB(255, 205, 40), CanCollide = true }, f)
	for _, sx in { -7, 7 } do
		deco({ Size = Vector3.new(1, 5, 1), CFrame = CFrame.new(c.X + sx, 2, -D + 1), Color = Color3.fromRGB(120, 85, 55) }, f)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Owner"
	sg.Face = Enum.NormalId.Back
	sg.PixelsPerStud = 25
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = "Empty Farm"
	t.Parent = sg
	sg.Parent = sign
	f.Parent = folders.Plots
	return f
end

function WorldBuilder.plotFolder(i: number): Folder?
	return folders.Plots and folders.Plots:FindFirstChild("Plot" .. i) :: Folder?
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild(Trajectory.MAP_NAME)
	if old then
		old:Destroy()
	end
	map = Instance.new("Folder")
	map.Name = Trajectory.MAP_NAME
	for _, n in { "Ground", "Water", "Decor", "Plots", "Signs" } do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = map
		folders[n] = f
	end
	local fieldEnd = select(2, Zones.band(#Zones.List))
	part({ Name = "Ocean", Size = Vector3.new(2000, 1, 1400), CFrame = CFrame.new(0, -14, fieldEnd / 2 - 100), Color = Color3.fromRGB(70, 170, 235), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false }, folders.Water)
	-- grass strip between fences and zone 1 (no dragons there)
	part({ Name = "Lawn", Size = Vector3.new(Zones.FIELD_W, 4, Zones.FIELD_START), CFrame = CFrame.new(0, -2, Zones.FIELD_START / 2), Color = Color3.fromRGB(100, 185, 80), Material = Enum.Material.Grass }, folders.Ground)
	-- cliff under everything
	deco({ Size = Vector3.new(Zones.FIELD_W + 12, 24, fieldEnd + Zones.PLOT_D + 12), CFrame = CFrame.new(0, -16, (fieldEnd - Zones.PLOT_D) / 2), Color = Color3.fromRGB(120, 95, 70), Material = Enum.Material.Slate }, folders.Decor)
	map.Parent = workspace
	for i = 1, #Zones.List do
		buildBand(i)
		task.wait()
	end
	for i = 1, Zones.PLOTS do
		buildPlot(i)
	end
	-- far landmarks behind the last zone
	R = Random.new(42)
	local back = fieldEnd + 60
	for k = 0, 5 do
		cyl(Vector3.new(-120, k * 14, back), 14, 110 - k * 18, k < 5 and Color3.fromRGB(70, 45, 40) or Color3.fromRGB(255, 90, 20), folders.Decor, k < 5 and Enum.Material.Slate or Enum.Material.Neon)
	end
	for k = 0, 4 do
		cyl(Vector3.new(140, k * 16, back + 20), 16, 100 - k * 20, k < 3 and Color3.fromRGB(150, 180, 210) or Color3.fromRGB(250, 252, 255), folders.Decor, Enum.Material.Snow)
	end
	ball(Vector3.new(0, 150, back + 160), Vector3.new(120, 120, 120), Color3.fromRGB(140, 80, 230), folders.Decor, Enum.Material.Neon)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TFFD_Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(Zones.plotCenter(1) + Vector3.new(0, 0.5, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Parent = map

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.6
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 165)
	Lighting.Ambient = Color3.fromRGB(80, 80, 95)
	Lighting.GlobalShadows = true
	local function ensure(class: string, name: string)
		local e = Lighting:FindFirstChild(name) or Instance.new(class)
		e.Name = name
		e.Parent = Lighting
		return e
	end
	local atm = ensure("Atmosphere", "TFFD_Atmosphere") :: Atmosphere
	atm.Density = 0.22
	atm.Haze = 1
	atm.Color = Color3.fromRGB(190, 230, 255)
	atm.Decay = Color3.fromRGB(120, 150, 200)
	local bloom = ensure("BloomEffect", "TFFD_Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4
	local cc = ensure("ColorCorrectionEffect", "TFFD_Color") :: ColorCorrectionEffect
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	ensure("SunRaysEffect", "TFFD_SunRays")
	return map
end

return WorldBuilder
