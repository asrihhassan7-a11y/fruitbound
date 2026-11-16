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
	meadow = { { "tree", 14 }, { "flowers", 18 }, { "rock", 6 } },
	forest = { { "pine", 18 }, { "tree", 10 }, { "mushroom", 10 } },
	volcano = { { "rock", 18 }, { "lava", 7 }, { "crystal", 4 } },
	frozen = { { "snowpine", 16 }, { "icespike", 10 }, { "rock", 5 } },
	crystal = { { "crystal", 22 }, { "rock", 8 }, { "mushroom", 4 } },
	sky = { { "cloud", 18 }, { "tree", 6 }, { "flowers", 10 } },
	ancient = { { "pillar", 16 }, { "rock", 10 }, { "palm", 6 } },
	shadow = { { "obelisk", 16 }, { "crystal", 8 }, { "rock", 6 } },
	celestial = { { "cloud", 10 }, { "star", 22 }, { "pillar", 6 } },
	cosmic = { { "star", 30 }, { "crystal", 12 }, { "obelisk", 6 } },
}
recipes.snowpine = function(pos, z, parent)
	recipes.pine(pos, z, parent, true)
end
recipes.palm = function(pos, z, parent)
	recipes.tree(pos, z, parent, Color3.fromRGB(90, 170, 70))
end

local function decorPosition(center: Vector3): Vector3?
	local half = Zones.SIZE / 2 - 6
	for _ = 1, 12 do
		local x, zz = R:NextNumber(-half, half), R:NextNumber(-half, half)
		local d = math.sqrt(x * x + zz * zz)
		local onPath = math.abs(zz) < 18 and math.abs(x) > 60
		if d > Zones.SPAWN_RADIUS + 8 and not onPath then
			return center + Vector3.new(x, 0, zz)
		end
	end
	return nil
end

local function landmark(i: number, z, center: Vector3, parent: Instance)
	local back = center + Vector3.new(0, 0, -Zones.SIZE / 2 + 22)
	if z.decor == "volcano" then
		for k = 0, 5 do
			cyl(back + Vector3.new(0, k * 8, 0), 8, 60 - k * 9, k < 5 and Color3.fromRGB(70, 45, 40) or Color3.fromRGB(255, 90, 20), parent, k < 5 and Enum.Material.Slate or Enum.Material.Neon)
		end
	elseif z.decor == "frozen" then
		for k = 0, 4 do
			cyl(back + Vector3.new(-30, k * 9, 0), 9, 50 - k * 10, k < 3 and Color3.fromRGB(150, 180, 210) or Color3.fromRGB(250, 252, 255), parent, Enum.Material.Snow)
		end
	elseif z.decor == "ancient" then
		for k = 0, 6 do
			deco({ Size = Vector3.new(56 - k * 8, 6, 56 - k * 8), CFrame = CFrame.new(back + Vector3.new(30, 3 + k * 6, 0)), Color = Color3.fromRGB(225, 195, 130), Material = Enum.Material.Sandstone, CanCollide = true }, parent)
		end
	elseif z.decor == "cosmic" or z.decor == "celestial" then
		ball(back + Vector3.new(40, 70, -30), Vector3.new(50, 50, 50), z.decor == "cosmic" and Color3.fromRGB(120, 60, 220) or Color3.fromRGB(255, 220, 120), parent, Enum.Material.Neon)
	elseif z.decor == "crystal" then
		for _ = 1, 4 do
			recipes.crystal(back + Vector3.new(R:NextNumber(-40, 40), 0, R:NextNumber(-8, 8)), z, parent)
		end
	end
	-- welcome arch
	local entrance = center + Vector3.new(-Zones.SIZE / 2 + 6, 0, 0)
	for _, side in { -15, 15 } do
		cyl(entrance + Vector3.new(0, 0, side), 16, 3, z.edge, parent)
		ball(entrance + Vector3.new(0, 17, side), Vector3.new(4, 4, 4), z.accent, parent, Enum.Material.Neon)
	end
	local beam = deco({ Size = Vector3.new(3, 2.5, 34), CFrame = CFrame.new(entrance + Vector3.new(0, 16, 0)), Color = z.edge, CanCollide = true }, parent)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Left
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = z.icon .. " " .. z.name
	t.Parent = sg
	sg.Parent = beam
end

local function buildZone(i: number)
	local z = Zones.List[i]
	local center = Zones.center(i)
	R = Random.new(i * 7919)
	local zf = Instance.new("Folder")
	zf.Name = "Zone" .. i
	-- ground
	local top = part({ Name = "Island" .. i, Size = Vector3.new(Zones.SIZE, 4, Zones.SIZE), CFrame = CFrame.new(center - Vector3.new(0, 2, 0)), Color = z.ground, Material = (z.decor == "frozen") and Enum.Material.Snow or Enum.Material.Grass }, folders.Ground)
	top:SetAttribute("Zone", i)
	if z.decor ~= "meadow" and z.decor ~= "forest" and z.decor ~= "frozen" then
		top.Material = (z.decor == "ancient") and Enum.Material.Sand or Enum.Material.SmoothPlastic
	end
	deco({ Size = Vector3.new(Zones.SIZE + 6, 26, Zones.SIZE + 6), CFrame = CFrame.new(center - Vector3.new(0, 17, 0)), Color = z.edge, Material = Enum.Material.Slate }, zf)
	-- path
	deco({ Size = Vector3.new(Zones.SIZE, 0.2, 22), CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)), Color = z.ground:Lerp(Color3.fromRGB(230, 210, 160), 0.45), Material = Enum.Material.SmoothPlastic }, zf)
	-- decor
	for _, entry in THEMES[z.decor] do
		for _ = 1, entry[2] do
			local p = decorPosition(center)
			if p then
				recipes[entry[1]](p, z, zf)
			end
		end
	end
	landmark(i, z, center, zf)
	zf.Parent = folders.Decor

	-- bridge from previous island + gate
	if i > 1 then
		local prev = Zones.center(i - 1)
		local x0, x1 = prev.X + Zones.SIZE / 2, center.X - Zones.SIZE / 2
		part({ Name = "Bridge" .. i, Size = Vector3.new(x1 - x0, 2, 26), CFrame = CFrame.new((x0 + x1) / 2, -1, 0), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks }, folders.Ground)
		for _, side in { -13, 13 } do
			deco({ Size = Vector3.new(x1 - x0, 1, 1), CFrame = CFrame.new((x0 + x1) / 2, 3, side), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood }, folders.Decor)
		end
		local gate = part({ Name = "Gate" .. i, Size = Vector3.new(2, 30, 30), CFrame = CFrame.new(x1 - 1, 15, 0), Color = z.accent, Material = Enum.Material.ForceField, Transparency = 0.2, CanCollide = true, CanQuery = false }, folders.Gates)
		gate:SetAttribute("Zone", i)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Unlock (" .. Util.fmt(z.cost) .. " coins)"
		prompt.ObjectText = z.icon .. " " .. z.name
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = gate
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(260, 90)
		bb.StudsOffset = Vector3.new(0, 19, 0)
		bb.MaxDistance = 160
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.2
		t.Text = "🔒 " .. z.name .. "\n🪙 " .. Util.fmt(z.cost)
		t.Parent = bb
		bb.Parent = gate
	end
end

function WorldBuilder.spawnCFrame(i: number): CFrame
	local c = Zones.center(i)
	return CFrame.lookAt(c + Vector3.new(-Zones.SIZE / 2 + 18, 4, 0), c + Vector3.new(0, 4, 0))
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild(Trajectory.MAP_NAME)
	if old then
		old:Destroy()
	end
	map = Instance.new("Folder")
	map.Name = Trajectory.MAP_NAME
	for _, n in { "Ground", "Water", "Decor", "Gates" } do
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = map
		folders[n] = f
	end
	-- ocean (parts are capped at 2048 studs per axis)
	local total = (#Zones.List - 1) * Zones.SPACING + 900
	local segments = math.ceil(total / 2000)
	for k = 0, segments - 1 do
		part({ Name = "Ocean", Size = Vector3.new(2000, 1, 1400), CFrame = CFrame.new(-450 + 1000 + k * 2000, -14, 0), Color = Color3.fromRGB(70, 170, 235), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false }, folders.Water)
	end
	map.Parent = workspace
	for i = 1, #Zones.List do
		buildZone(i)
		task.wait()
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TFFD_Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = WorldBuilder.spawnCFrame(1) - Vector3.new(0, 3.5, 0)
	spawn.Color = Zones.List[1].accent
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = map

	-- lighting
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
	atm.Density = 0.28
	atm.Haze = 1.2
	atm.Color = Zones.List[1].fog
	atm.Decay = Color3.fromRGB(120, 150, 200)
	local bloom = ensure("BloomEffect", "TFFD_Bloom") :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.4
	ensure("ColorCorrectionEffect", "TFFD_Color")
	local cc = Lighting:FindFirstChild("TFFD_Color") :: ColorCorrectionEffect
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	ensure("SunRaysEffect", "TFFD_SunRays")
	return map
end

return WorldBuilder
