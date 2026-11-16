-- Builds an original low-poly dragon from parts. Used by clients only (wild dragons + companions),
-- so the server never replicates moving parts. Returns a rig the animator can pose cheaply.
local Config = script.Parent.Config
local Rarities = require(Config.Rarities)

local DragonBuilder = {}

local PARTICLE = {
	fire = { tex = "rbxasset://textures/particles/fire_main.dds", c0 = Color3.fromRGB(255, 200, 60), c1 = Color3.fromRGB(255, 60, 0), rate = 14, size = 0.9, speed = 2 },
	frost = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(230, 250, 255), c1 = Color3.fromRGB(120, 200, 255), rate = 8, size = 0.5, speed = 1 },
	sparkle = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(255, 255, 220), c1 = Color3.fromRGB(255, 220, 90), rate = 8, size = 0.5, speed = 1.5 },
	leaf = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(180, 255, 140), c1 = Color3.fromRGB(70, 190, 60), rate = 6, size = 0.45, speed = 1 },
	storm = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(255, 255, 140), c1 = Color3.fromRGB(120, 160, 255), rate = 12, size = 0.6, speed = 4 },
	sand = { tex = "rbxasset://textures/particles/smoke_main.dds", c0 = Color3.fromRGB(240, 210, 150), c1 = Color3.fromRGB(200, 160, 90), rate = 5, size = 1.2, speed = 1 },
	shadow = { tex = "rbxasset://textures/particles/smoke_main.dds", c0 = Color3.fromRGB(120, 40, 200), c1 = Color3.fromRGB(10, 0, 20), rate = 10, size = 1.4, speed = 1 },
	star = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(255, 255, 255), c1 = Color3.fromRGB(255, 230, 120), rate = 10, size = 0.6, speed = 1.5 },
	cosmic = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(255, 120, 240), c1 = Color3.fromRGB(80, 220, 255), rate = 14, size = 0.7, speed = 2 },
	rainbow = { tex = "rbxasset://textures/particles/sparkles_main.dds", c0 = Color3.fromRGB(255, 80, 80), c1 = Color3.fromRGB(80, 160, 255), rate = 20, size = 0.8, speed = 2.5 },
}

local function newPart(className: string, size: Vector3, color: Color3, material: Enum.Material?, sphere: boolean?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if sphere then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	return p
end

-- opts: { scale: number?, nameTag: boolean?, lowGfx: boolean? }
function DragonBuilder.build(def, opts)
	opts = opts or {}
	local rarity = Rarities.Info[def.rarity]
	local s = (opts.scale or 1) * rarity.scale
	local model = Instance.new("Model")
	model.Name = def.name
	local entries = {}
	local belly = def.body:Lerp(Color3.new(1, 1, 1), 0.45)
	local fancy = rarity.rank >= 4
	local skinMat = (def.fx == "frost" or def.fx == "cosmic") and fancy and Enum.Material.Glass or Enum.Material.SmoothPlastic

	local function add(group: string, part: BasePart, cf: CFrame, name: string)
		part.Name = name
		part.Parent = model
		local scaled = CFrame.new(cf.Position * s) * cf.Rotation
		part.Size *= s
		table.insert(entries, { part = part, group = group, offset = scaled })
		return part
	end
	local V = Vector3.new
	local CF = CFrame.new

	-- body
	local body = add("body", newPart("Part", V(3.2, 2.8, 4.4), def.body, skinMat, true), CF(0, 2.5, 0), "Body")
	body.CastShadow = true
	add("body", newPart("Part", V(2.5, 2.2, 3.4), belly, nil, true), CF(0, 2.15, -0.5), "Belly")
	add("body", newPart("Part", V(1.5, 2.3, 1.5), def.body, skinMat, true), CF(0, 3.5, -2.0) * CFrame.Angles(math.rad(-35), 0, 0), "Neck")
	for _, x in { -1.15, 1.15 } do
		for _, z in { -1.2, 1.3 } do
			add("body", newPart("Part", V(1, 1.9, 1.1), def.body, nil, true), CF(x, 0.95, z), "Leg")
		end
	end
	for i, z in { -0.9, 0.3, 1.4 } do
		add("body", newPart("WedgePart", V(0.3, 0.8 - i * 0.1, 0.9), def.accent), CF(0, 4.0 - i * 0.08, z), "Spike")
	end
	-- head
	local head = add("head", newPart("Part", V(2.4, 2.1, 2.5), def.body, skinMat, true), CF(0, 4.7, -2.8), "Head")
	add("head", newPart("Part", V(1.7, 1.2, 1.8), belly, nil, true), CF(0, 4.35, -3.9), "Snout")
	local eyeMat = rarity.rank >= 3 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	for _, x in { -0.62, 0.62 } do
		add("head", newPart("Part", V(0.75, 0.75, 0.75), Color3.new(1, 1, 1), nil, true), CF(x, 5.05, -3.55), "Eye")
		add("head", newPart("Part", V(0.4, 0.45, 0.4), def.eye, eyeMat, true), CF(x * 1.06, 5.07, -3.88), "Pupil")
		add("head", newPart("Part", V(0.18, 0.18, 0.18), Color3.fromRGB(30, 20, 20), nil, true), CF(x * 0.45, 4.6, -4.78), "Nostril")
		add("head", newPart("WedgePart", V(0.3, 1.1 + (fancy and 0.4 or 0), 0.7), def.accent), CF(x, 5.95, -2.35) * CFrame.Angles(math.rad(25), 0, 0), "Horn")
	end
	-- wings
	local wingSize = V(0.15, 3.6, 2.8) * (def.move == "fly" and 1.25 or 1)
	add("wingL", newPart("WedgePart", wingSize, def.accent), CFrame.fromMatrix(V(-3.0, 3.9, 0.3), V(0, -1, 0), V(-1, 0, 0)), "WingL")
	add("wingR", newPart("WedgePart", wingSize, def.accent), CFrame.fromMatrix(V(3.0, 3.9, 0.3), V(0, 1, 0), V(1, 0, 0)), "WingR")
	-- tail
	add("tail", newPart("Part", V(1.4, 1.2, 2.4), def.body, skinMat, true), CF(0, 2.3, 3.0), "Tail")
	add("tail", newPart("Part", V(0.9, 0.8, 2.2), def.body, skinMat, true), CF(0, 2.1, 4.7), "Tail2")
	add("tail", newPart("WedgePart", V(0.25, 1.1, 1.3), def.accent), CF(0, 2.35, 6.0), "TailTip")

	model.PrimaryPart = body

	-- rarity / element effects
	if not opts.lowGfx and def.fx and PARTICLE[def.fx] then
		local cfg = PARTICLE[def.fx]
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = cfg.tex
		pe.Color = ColorSequence.new(cfg.c0, cfg.c1)
		pe.Rate = cfg.rate * (fancy and 1.5 or 1)
		pe.Lifetime = NumberRange.new(0.8, 1.6)
		pe.Speed = NumberRange.new(cfg.speed * 0.5, cfg.speed)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg.size * s), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new(0.2, 1)
		pe.LightEmission = 0.6
		pe.Parent = body
	end
	if rarity.rank >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.rainbow and Color3.new(1, 1, 1) or def.accent
		light.Range = 10 * s
		light.Brightness = 1.6
		light.Parent = body
	end

	if opts.nameTag then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Tag"
		bb.Size = UDim2.fromOffset(180, 46)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * s, 0)
		bb.MaxDistance = rarity.rank >= 5 and 220 or 90
		bb.LightInfluence = 0
		bb.AlwaysOnTop = false
		bb.Adornee = head
		local nameL = Instance.new("TextLabel")
		nameL.BackgroundTransparency = 1
		nameL.Size = UDim2.new(1, 0, 0.55, 0)
		nameL.Font = Enum.Font.FredokaOne
		nameL.TextScaled = true
		nameL.TextColor3 = Color3.new(1, 1, 1)
		nameL.TextStrokeTransparency = 0.3
		nameL.Text = def.name
		nameL.Parent = bb
		local rar = nameL:Clone()
		rar.Name = "Rarity"
		rar.Position = UDim2.fromScale(0, 0.55)
		rar.Size = UDim2.new(1, 0, 0.45, 0)
		rar.Text = def.rarity
		rar.TextColor3 = rarity.color
		rar.Parent = bb
		bb.Parent = head
	end

	return {
		model = model,
		entries = entries,
		head = head,
		body = body,
		scale = s,
		def = def,
		height = 4.7 * s,
		pivots = {
			head = CFrame.new(Vector3.new(0, 3.9, -2.3) * s),
			wingL = CFrame.new(Vector3.new(-1.3, 3.9, 0.3) * s),
			wingR = CFrame.new(Vector3.new(1.3, 3.9, 0.3) * s),
			tail = CFrame.new(Vector3.new(0, 2.4, 1.9) * s),
		},
	}
end

-- Poses every part of a rig. root = ground CFrame; anim = { head: CFrame, wingL: CFrame, wingR: CFrame, tail: CFrame }
local partsBuf, cfBuf = {}, {}
function DragonBuilder.pose(rig, root: CFrame, anim)
	table.clear(partsBuf)
	table.clear(cfBuf)
	local groupCF = {}
	for g, pivot in rig.pivots do
		local a = anim[g]
		groupCF[g] = a and (root * pivot * a * pivot:Inverse()) or root
	end
	for i, e in rig.entries do
		partsBuf[i] = e.part
		cfBuf[i] = (groupCF[e.group] or root) * e.offset
	end
	workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged)
end

return DragonBuilder
