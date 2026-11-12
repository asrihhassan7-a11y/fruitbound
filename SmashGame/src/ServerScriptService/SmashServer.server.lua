-- SmashServer (Script dans ServerScriptService)
-- Maps + vote, manches chronométrées, dégâts en %, recul, KO, vies, bots CPU.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("SmashConfig"))
local Maps = require(ReplicatedStorage:WaitForChild("SmashMaps"))
local Fighters = require(ReplicatedStorage:WaitForChild("SmashFighters"))
local O = Config.ARENA_ORIGIN

workspace.Gravity = Config.GRAVITY
Players.RespawnTime = 2

----------------------------------------------------------------------
-- Remotes + état partagé
----------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "SmashRemotes"
local actionRemote = Instance.new("RemoteEvent")
actionRemote.Name = "Action"
actionRemote.Parent = remotes
local knockRemote = Instance.new("RemoteEvent") -- serveur -> client : recul / reset / tremblement
knockRemote.Name = "Knock"
knockRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local state = Instance.new("Folder")
state.Name = "SmashState"
state:SetAttribute("Phase", "Waiting")
state:SetAttribute("Message", "")
state:SetAttribute("TimeLeft", 0)
state:SetAttribute("Map", 1)
state:SetAttribute("Mode", "FFA")          -- "FFA" (chacun pour soi) ou "Teams" (2 équipes)
state:SetAttribute("BotCount", Config.BOT_COUNT or 3)
state:SetAttribute("BotLevel", "Mix")      -- Mix, Facile, Moyen, Difficile, Expert
state:SetAttribute("Winner", "")
state:SetAttribute("Leaderboard", "")
local TEAM_COLORS = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(70, 140, 255) }
local TEAM_NAMES = { "ROUGE", "BLEUE" }
local function teamsMode() return state:GetAttribute("Mode") == "Teams" end
state.Parent = ReplicatedStorage

local function setMsg(m) state:SetAttribute("Message", m) end
local function phase() return state:GetAttribute("Phase") end
local function combat() local ph = phase() return ph == "Fight" or ph == "Training" end

----------------------------------------------------------------------
-- Groupes de collision : les combattants se traversent
----------------------------------------------------------------------
PhysicsService:RegisterCollisionGroup("Fighters")
PhysicsService:RegisterCollisionGroup("Platforms")
PhysicsService:RegisterCollisionGroup("Ghost") -- bots passant sous une plateforme
PhysicsService:CollisionGroupSetCollidable("Fighters", "Fighters", false)
PhysicsService:CollisionGroupSetCollidable("Ghost", "Fighters", false)
PhysicsService:CollisionGroupSetCollidable("Ghost", "Ghost", false)
PhysicsService:CollisionGroupSetCollidable("Ghost", "Platforms", false)
PhysicsService:RegisterCollisionGroup("Items")
PhysicsService:CollisionGroupSetCollidable("Items", "Fighters", false)
PhysicsService:CollisionGroupSetCollidable("Items", "Ghost", false)
PhysicsService:CollisionGroupSetCollidable("Items", "Items", false)

local function setGroup(model, group)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "SmashShield" then p.CollisionGroup = group end
	end
end

----------------------------------------------------------------------
-- Maps
----------------------------------------------------------------------
local arena, platformsFolder, solidsFolder
local startHazards -- défini plus bas (pièges)
local curMap = Maps[1]

local function loadMap(index)
	curMap = Maps[index] or Maps[1]
	if arena then arena:Destroy() end
	arena = Instance.new("Model")
	arena.Name = "SmashArena"
	solidsFolder = Instance.new("Folder")
	solidsFolder.Name = "Solids"
	solidsFolder.Parent = arena
	platformsFolder = Instance.new("Folder")
	platformsFolder.Name = "Platforms"
	platformsFolder.Parent = arena
	local decoFolder = Instance.new("Folder")
	decoFolder.Name = "Deco"
	decoFolder.Parent = arena

	for _, d in ipairs(curMap.parts) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = d.size
		p.Position = O + d.pos
		p.Color = d.color
		p.Material = d.material or Enum.Material.SmoothPlastic
		if d.move then
			p:SetAttribute("MoveBase", p.Position)
			p:SetAttribute("MoveOffset", d.move.offset)
			p:SetAttribute("MovePeriod", d.move.period)
			p:AddTag("SmashMoving")
		end
		if d.kind == "platform" then
			p.Name = "Platform"
			p.CollisionGroup = "Platforms"
			p.Parent = platformsFolder
		elseif d.kind == "solid" then
			p.Name = "Stage"
			p.Parent = solidsFolder
		else
			p.Name = "Deco"
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = decoFolder
		end
	end

	-- détails de la scène : bords lumineux + blocs en façade
	local accent = curMap.icon or Color3.new(1, 1, 1)
	local function deco(size, cf, color, material, transparency)
		local d = Instance.new("Part")
		d.Name = "Detail"
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.CastShadow = false
		d.Size = size
		d.CFrame = cf
		d.Color = color
		d.Material = material
		d.Transparency = transparency or 0
		d.Parent = decoFolder
		return d
	end
	for _, p in ipairs(solidsFolder:GetChildren()) do
		local top = p.Position.Y + p.Size.Y / 2
		local front = p.Position.Z + p.Size.Z / 2
		-- liseré lumineux sur le bord avant et les côtés
		deco(Vector3.new(p.Size.X + 0.2, 0.35, 0.35), CFrame.new(p.Position.X, top - 0.1, front + 0.05), accent, Enum.Material.Neon)
		deco(Vector3.new(0.35, p.Size.Y, 0.35), CFrame.new(p.Position.X - p.Size.X / 2, p.Position.Y, front + 0.05), accent, Enum.Material.Neon)
		deco(Vector3.new(0.35, p.Size.Y, 0.35), CFrame.new(p.Position.X + p.Size.X / 2, p.Position.Y, front + 0.05), accent, Enum.Material.Neon)
		-- motif de dalles en façade
		local n = math.floor(p.Size.X / 6)
		for i = 0, n - 1 do
			local x = p.Position.X - p.Size.X / 2 + 3 + i * (p.Size.X - 6) / math.max(n - 1, 1)
			local shade = (i % 2 == 0) and 0.12 or 0.22
			deco(Vector3.new(4.6, p.Size.Y * 0.55, 0.2), CFrame.new(x, p.Position.Y - p.Size.Y * 0.1, front + 0.1),
				p.Color:Lerp(Color3.new(0, 0, 0), shade), p.Material)
		end
		-- petite lueur sur le dessus
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Top
		glow.Color = accent
		glow.Brightness = 0.6
		glow.Range = 8
		glow.Parent = p
	end
	for _, p in ipairs(platformsFolder:GetChildren()) do
		local front = p.Position.Z + p.Size.Z / 2
		p.Color = p.Color:Lerp(accent, 0.25)
		if p:HasTag("SmashMoving") then
			-- plateforme mobile : le liseré est soudé dessus pour bouger avec elle
			local trim = Instance.new("Part")
			trim.Name = "Detail"
			trim.Anchored = false
			trim.Massless = true
			trim.CanCollide = false
			trim.CanQuery = false
			trim.CanTouch = false
			trim.Material = Enum.Material.Neon
			trim.Color = accent
			trim.Size = Vector3.new(p.Size.X - 1, 0.3, p.Size.Z - 1)
			trim.CFrame = p.CFrame * CFrame.new(0, -p.Size.Y / 2 - 0.15, 0)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = trim, p
			w.Parent = trim
			trim.Parent = p
			continue
		end
		-- dessous lumineux de la couleur de la map
		deco(Vector3.new(p.Size.X - 1, 0.3, p.Size.Z - 1), CFrame.new(p.Position - Vector3.new(0, p.Size.Y / 2 + 0.15, 0)), accent, Enum.Material.Neon, 0.2)
		deco(Vector3.new(p.Size.X + 0.2, 0.3, 0.3), CFrame.new(p.Position.X, p.Position.Y + p.Size.Y / 2 - 0.1, front + 0.05), Color3.new(1, 1, 1), Enum.Material.Neon)
	end

	-- fond pour la vue de côté
	local back = Instance.new("Part")
	back.Name = "Backdrop"
	back.Anchored = true
	back.CanCollide = false
	back.CanQuery = false
	back.Size = Vector3.new(500, 260, 2)
	back.Position = O + Vector3.new(0, 20, -90)
	back.Color = curMap.theme.backdrop
	back.Material = Enum.Material.SmoothPlastic
	back.Parent = decoFolder

	arena.Parent = workspace

	-- effets de lumière (bloom, couleurs, atmosphère)
	local function effect(class, name)
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	local bloom = effect("BloomEffect", "SmashBloom")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 0.85
	local cc = effect("ColorCorrectionEffect", "SmashColor")
	cc.Contrast = 0.15
	cc.Saturation = 0.25
	cc.Brightness = 0.03
	cc.TintColor = Color3.new(1, 1, 1):Lerp(curMap.theme.fog, 0.12)
	local rays = effect("SunRaysEffect", "SmashRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.25
	atmo.Offset = 0.1
	atmo.Color = curMap.theme.fog
	atmo.Decay = curMap.theme.backdrop
	atmo.Glare = 0.2
	atmo.Haze = 1.5
	atmo.Parent = Lighting
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6

	Lighting.ClockTime = curMap.theme.clock
	Lighting.Ambient = curMap.theme.ambient
	Lighting.OutdoorAmbient = curMap.theme.ambient
	Lighting.FogColor = curMap.theme.fog
	Lighting.FogStart = 150
	Lighting.FogEnd = 600

	if startHazards then startHazards() end
	state:SetAttribute("Map", index)
	state:SetAttribute("MapName", curMap.name)
	state:SetAttribute("BlastX", curMap.blast.x)
	state:SetAttribute("BlastTop", curMap.blast.top)
	state:SetAttribute("BlastBottom", curMap.blast.bottom)
	state:SetAttribute("CamRangeX", curMap.camRangeX or 35)
end

local function spawnPos(i)
	local s = curMap.spawns
	return O + s[((i - 1) % #s) + 1]
end
local function respawnPos() return O + curMap.respawn end
local PARK_POS = O + Vector3.new(0, 400, 300) -- là où vont les éliminés

----------------------------------------------------------------------
-- Combattants
----------------------------------------------------------------------
local fighters = {}          -- id -> fighter
local fighterByModel = {}    -- model -> fighter
local COLORS = {
	Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 150, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(220, 110, 255), Color3.fromRGB(255, 150, 60), Color3.fromRGB(80, 230, 230), Color3.fromRGB(240, 240, 240),
}

local function freeSlot()
	local used = {}
	for _, f in pairs(fighters) do used[f.slot] = true end
	local i = 1
	while used[i] do i += 1 end
	return i
end

local function newFighter(id, name, player)
	local f = {
		id = id, name = name, player = player, slot = freeSlot(),
		damage = 0, stocks = 0, model = nil, kos = 0,
		cooldownUntil = 0, stunUntil = 0, invincibleUntil = 0,
		shielding = false, shieldHp = Config.SHIELD_MAX, shieldPart = nil,
		char = Fighters.Characters[1], hammerUntil = 0, bootsUntil = 0,
	}
	local info = Instance.new("Folder")
	info.Name = id
	info:SetAttribute("DisplayName", name)
	info:SetAttribute("Damage", 0)
	info:SetAttribute("Stocks", 0)
	info:SetAttribute("Color", COLORS[((f.slot - 1) % #COLORS) + 1])
	info:SetAttribute("Slot", f.slot)
	info:SetAttribute("IsBot", player == nil)
	info:SetAttribute("CharId", f.char.id)
	info:SetAttribute("AirJumps", f.char.airJumps)
	local charRef = Instance.new("ObjectValue")
	charRef.Name = "Character"
	charRef.Parent = info
	info.Parent = state
	f.info = info
	f.charRef = charRef
	fighters[id] = f
	return f
end

local function removeFighter(f)
	fighters[f.id] = nil
	if f.model then fighterByModel[f.model] = nil end
	f.info:Destroy()
end

local function sync(f)
	f.info:SetAttribute("Damage", math.floor(f.damage))
	f.info:SetAttribute("Stocks", f.stocks)
	f.info:SetAttribute("KOs", f.kos)
end

local function rootOf(f)
	return f.model and f.model.Parent and f.model:FindFirstChild("HumanoidRootPart")
end
local function humOf(f)
	return f.model and f.model:FindFirstChildOfClass("Humanoid")
end
local function alive(f)
	return f.stocks > 0 and not f.koing and rootOf(f) ~= nil
end

local function setMenu(f, on)
	f.inMenu = on
	f.info:SetAttribute("InMenu", on)
end
local joinTraining
local function setTraining(f, on)
	f.training = on
	f.info:SetAttribute("Training", on)
end
local function setInRound(f, on)
	f.inRound = on
	f.info:SetAttribute("InRound", on)
end

local function setShield(f, on)
	if on == f.shielding then return end
	f.shielding = on
	if f.shieldPart then f.shieldPart:Destroy() f.shieldPart = nil end
	local root = rootOf(f)
	if on and root then
		local s = Instance.new("Part")
		s.Name = "SmashShield"
		s.Shape = Enum.PartType.Ball
		s.Size = Vector3.new(7, 7, 7)
		s.Material = Enum.Material.ForceField
		s.Color = f.info:GetAttribute("Color")
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.Massless = true
		s.CFrame = root.CFrame
		local w = Instance.new("WeldConstraint")
		w.Part0 = s
		w.Part1 = root
		w.Parent = s
		s.Parent = f.model
		f.shieldPart = s
	end
end

local function giveInvincibility(f, t)
	f.invincibleUntil = os.clock() + t
	if f.model then
		local old = f.model:FindFirstChildOfClass("ForceField")
		if old then old:Destroy() end
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = f.model
		Debris:AddItem(ff, t)
	end
end

-- Les bots doivent rester simulés par le serveur. Ancrer puis désancrer une pièce
-- remet la propriété réseau en automatique (souvent donnée au joueur proche),
-- et le recul appliqué par le serveur n'a alors plus d'effet.
local function serverOwn(f)
	if f.player then return end
	local root = f.model and f.model:FindFirstChild("HumanoidRootPart")
	if root and not root.Anchored and root:IsDescendantOf(workspace) then
		pcall(function()
			if root:GetNetworkOwner() ~= nil or root:GetNetworkOwnershipAuto() then root:SetNetworkOwner(nil) end
		end)
	end
end

local function placeAt(f, pos, anchored)
	local root = rootOf(f)
	if not root then return end
	root.Anchored = false
	f.frozen = false
	f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(pos.X > O.X and -90 or 90), 0))
	root.AssemblyLinearVelocity = Vector3.zero
	f.stunUntil = 0
	if f.player then
		knockRemote:FireClient(f.player, "Reset")
	else
		local hum = humOf(f)
		if hum then hum.PlatformStand = false end
	end
	if anchored then root.Anchored = true else serverOwn(f) end
end

local function park(f)
	setShield(f, false)
	placeAt(f, PARK_POS + Vector3.new(f.slot * 10, 0, 0), true)
end

local function setChar(f, id)
	f.char = Fighters.get(id)
	f.info:SetAttribute("CharId", f.char.id)
	f.info:SetAttribute("CharName", f.char.name)
	f.info:SetAttribute("AirJumps", f.char.airJumps)
end

local function applyStats(f)
	local hum = humOf(f)
	if not hum then return end
	local speed = f.char.speed
	if os.clock() < f.bootsUntil then speed *= 1.4 end
	hum.WalkSpeed = speed
	hum.JumpPower = f.char.jump
end

local function applyScale(f)
	local model = f.model
	if model and model.Parent then
		pcall(function()
			if math.abs(model:GetScale() - f.char.scale) > 0.01 then model:ScaleTo(f.char.scale) end
		end)
	end
end

local function setupCharacter(f, model)
	f.model = model
	fighterByModel[model] = f
	f.charRef.Value = model
	local hum = model:WaitForChild("Humanoid")
	hum.UseJumpPower = true
	hum.JumpPower = Config.JUMP_POWER
	hum.WalkSpeed = Config.WALK_SPEED
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	model:WaitForChild("HumanoidRootPart")
	if not model:IsDescendantOf(workspace) then model.AncestryChanged:Wait() end
	task.wait(0.1) -- laisser Roblox placer le perso avant de le téléporter
	applyScale(f)
	applyStats(f)
	-- contour de la couleur du combattant
	local outline = model:FindFirstChild("SmashOutline") or Instance.new("Highlight")
	outline.Name = "SmashOutline"
	outline.FillTransparency = 1
	outline.OutlineColor = (teamsMode() and f.team) and TEAM_COLORS[f.team] or f.info:GetAttribute("Color")
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	setGroup(model, "Fighters")
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Name ~= "SmashShield" then d.CollisionGroup = "Fighters" end
	end)
	f.shielding = false
	f.shieldPart = nil
	f.koing = false
	local fighting = phase() == "Fight" or phase() == "Countdown" or phase() == "Training"
	if f.inMenu or (fighting and not (f.inRound and f.stocks > 0)) then
		park(f) -- menu ou spectateur
	elseif phase() == "Countdown" then
		placeAt(f, spawnPos(f.slot), true)
	elseif fighting then
		placeAt(f, respawnPos())
		giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
	else
		placeAt(f, spawnPos(f.slot))
	end
end

----------------------------------------------------------------------
-- Effets
----------------------------------------------------------------------
local function flash(cf, size, color, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.45
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace
	Debris:AddItem(p, life or 0.12)
	return p
end

local function hitSound(parent, big)
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/swordslash.wav"
	s.Volume = big and 1 or 0.5
	s.PlaybackSpeed = big and 0.7 or 1.2
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 2)
end

----------------------------------------------------------------------
-- Dégâts + recul
----------------------------------------------------------------------
local freeze, impactBurst, smokeTrail, dashAttack, quakeAttack

local function applyKnockback(target, vel, hitstun)
	local root = rootOf(target)
	if not root then return end
	target.stunUntil = os.clock() + hitstun
	if hitstun > 0.3 and target.model then knockRemote:FireAllClients("Pose", target.model, "Hurt") end
	if target.player then
		knockRemote:FireClient(target.player, "Knock", vel, hitstun)
	else
		local hum = humOf(target)
		if root.Anchored and not target.koing then root.Anchored = false end -- encore figé par le hitstop
		serverOwn(target)
		if hum then hum.PlatformStand = true end
		root.AssemblyLinearVelocity = vel
	end
end

-- figer un combattant (hitstop)
function freeze(f, duration)
	local root = rootOf(f)
	if not root then return end
	if f.player then
		knockRemote:FireClient(f.player, "Freeze", duration)
	elseif not root.Anchored then
		root.Anchored = true
		f.frozen = true
		task.delay(duration, function()
			if f.frozen and root.Parent and not f.koing then
				root.Anchored = false
				serverOwn(f)
			end
			f.frozen = false
		end)
	end
end

-- gerbe d'étincelles à l'impact
function impactBurst(pos, color, big)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 0.8), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, big and 1.6 or 1), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.2, 0.45)
	e.Speed = NumberRange.new(big and 35 or 20, big and 60 or 35)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Rate = 0
	e.Parent = p
	e:Emit(big and 30 or 12)
	-- anneau de choc
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.new(1, 1, 1)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
	ring.Parent = workspace
	game:GetService("TweenService"):Create(ring, TweenInfo.new(0.2), {
		Size = Vector3.new(0.3, big and 14 or 8, big and 14 or 8), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.25)
	Debris:AddItem(p, 1)
end

-- traînée de fumée derrière un combattant éjecté fort
function smokeTrail(f, duration, power)
	local root = rootOf(f)
	if not root then return end
	local old = root:FindFirstChild("SmashSmoke")
	if old then old:Destroy() end
	local e = Instance.new("ParticleEmitter")
	e.Name = "SmashSmoke"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230), Color3.fromRGB(120, 120, 120))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(0, 1)
	e.Rate = math.clamp(power * 0.6, 30, 90)
	e.LockedToPart = false
	e.Parent = root
	if power > 100 then
		local fire = Instance.new("ParticleEmitter")
		fire.Name = "SmashSmokeFire"
		fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 20))
		fire.LightEmission = 1
		fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		fire.Lifetime = NumberRange.new(0.2, 0.4)
		fire.Rate = 60
		fire.Speed = NumberRange.new(0, 2)
		fire.Parent = root
		Debris:AddItem(fire, duration)
	end
	Debris:AddItem(e, duration)
end

local function hit(attacker, target, data, facing, mult, fromPos)
	if target == attacker or not alive(target) then return end
	if teamsMode() and attacker.team and attacker.team == target.team then return end -- pas de tir ami
	if os.clock() < target.invincibleUntil then return end
	local troot = rootOf(target)

	if target.shielding then
		target.shieldHp -= data.dmg * mult * 1.5
		local push = math.sign(troot.Position.X - fromPos.X)
		if push == 0 then push = facing end
		applyKnockback(target, Vector3.new(push * 12, 0, 0), 0.05)
		flash(troot.CFrame, Vector3.new(8, 8, 8), Color3.new(1, 1, 1), 0.08)
		return
	end

	local atkMult = attacker.char.power * (os.clock() < attacker.hammerUntil and 1.6 or 1)
	target.damage = math.min(999, target.damage + data.dmg * mult * atkMult)
	sync(target)
	target.lastHitBy = attacker
	target.lastHitTime = os.clock()

	local dir = facing
	if data.bothSides then
		dir = math.sign(troot.Position.X - fromPos.X)
		if dir == 0 then dir = facing end
	end
	local power = (data.base + target.damage * data.growth) * mult * target.char.weight
	if os.clock() < attacker.hammerUntil then power *= 1.25 end
	local a = math.rad(data.angle)
	local vel = Vector3.new(math.cos(a) * dir, math.sin(a), 0) * power
	local hitstun = math.clamp(power * Config.HITSTUN_FACTOR, 0.15, Config.HITSTUN_MAX)

	-- arrêt sur image (hitstop) : les deux combattants se figent un instant
	local stop = math.clamp(0.04 + power * 0.0009, 0.05, 0.15)
	target.stunUntil = os.clock() + stop + hitstun
	freeze(attacker, stop)
	freeze(target, stop)
	task.delay(stop, function()
		if alive(target) and target.model then
			applyKnockback(target, vel, hitstun)
			if power > 55 then smokeTrail(target, hitstun + 0.3, power) end
		end
	end)

	local big = power > 70
	local hitPos = troot.Position
	flash(troot.CFrame, Vector3.new(3, 3, 3) * (big and 2 or 1), Color3.fromRGB(255, 240, 150), 0.1)
	impactBurst(hitPos, attacker.info:GetAttribute("Color"), big)
	hitSound(troot, big)
	knockRemote:FireAllClients("DmgNum", hitPos, math.floor(data.dmg * mult * atkMult + 0.5), big)
	if big then knockRemote:FireAllClients("Shake", math.clamp(power / 100, 0.3, 1.5)) end
end

local function charactersList(except)
	local list = {}
	for _, f in pairs(fighters) do
		if f ~= except and f.model then table.insert(list, f.model) end
	end
	return list
end

local function hitboxAt(attacker, data, facing, mult, already)
	local root = rootOf(attacker)
	if not root then return end
	local center = root.Position + Vector3.new(data.offset.X * facing, data.offset.Y, 0)
	local cf = CFrame.new(center)
	flash(cf, data.size, attacker.info:GetAttribute("Color"), 0.1)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = charactersList(attacker)
	local done = already or {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(cf, data.size, params)) do
		local model = p:FindFirstAncestorOfClass("Model")
		local target = model and fighterByModel[model]
		if target and not done[target] then
			done[target] = true
			hit(attacker, target, data, facing, mult, root.Position)
		end
	end
end

local function fireProjectile(attacker, facing, big)
	local root = rootOf(attacker)
	if not root then return end
	local base = Config.ATTACKS.Special
	local data = table.clone(base)
	data.speed = attacker.char.projSpeed
	data.dmg = base.dmg * attacker.char.projPower
	data.base = base.base * attacker.char.projPower
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = big and Vector3.new(3.2, 3.2, 3.2) or Vector3.new(2.2, 2.2, 2.2)
	ball.Material = big and Enum.Material.ForceField or Enum.Material.Neon
	ball.Color = big and attacker.char.color or attacker.info:GetAttribute("Color")
	if big then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = attacker.char.color
		sp.Parent = ball
	end
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Position = root.Position + Vector3.new(facing * 3, 0.5, 0)
	ball.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = ball.Color
	light.Range = 10
	light.Parent = ball

	local t0 = os.clock()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = charactersList(attacker)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ball.Parent then conn:Disconnect() return end
		ball.Position += Vector3.new(facing * data.speed * dt, 0, 0)
		for _, p in ipairs(workspace:GetPartBoundsInRadius(ball.Position, 1.6, params)) do
			local model = p:FindFirstAncestorOfClass("Model")
			local target = model and fighterByModel[model]
			if target and target ~= attacker and alive(target) then
				hit(attacker, target, data, facing, 1, ball.Position)
				conn:Disconnect()
				ball:Destroy()
				return
			end
		end
		if os.clock() - t0 > data.lifetime then
			conn:Disconnect()
			ball:Destroy()
		end
	end)
end

----------------------------------------------------------------------
-- Attaques spéciales propres à chaque personnage
----------------------------------------------------------------------
local DASH_DATA = { dmg = 9, base = 26, growth = 0.55, angle = 30, offset = Vector2.new(1.5, 0), size = Vector3.new(6, 5, 6) }
local QUAKE_DATA = { dmg = 12, base = 30, growth = 0.8, angle = 62, offset = Vector2.new(0, -1.5), size = Vector3.new(20, 4, 6), bothSides = true }

function dashAttack(f, facing)
	local root = rootOf(f)
	if not root then return end
	knockRemote:FireAllClients("Pose", f.model, "Dash")
	if f.player then
		knockRemote:FireClient(f.player, "Dash", facing)
	else
		root.AssemblyLinearVelocity = Vector3.new(facing * 110, 4, 0)
	end
	-- traînée lumineuse
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(f.char.color)
	trail.LightEmission = 1
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	trail.Lifetime = NumberRange.new(0.25, 0.4)
	trail.Rate = 120
	trail.Speed = NumberRange.new(0, 1)
	trail.Parent = root
	Debris:AddItem(trail, 0.3)
	local already = {}
	task.spawn(function()
		for _ = 1, 6 do
			if not f.model or f.koing then break end
			hitboxAt(f, DASH_DATA, facing, 1, already)
			task.wait(0.04)
		end
		if not f.player and rootOf(f) then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X * 0.25, v.Y, 0)
		end
	end)
end

local function shockwave(f)
	local root = rootOf(f)
	if not root then return end
	knockRemote:FireAllClients("Pose", f.model, "Quake")
	hitboxAt(f, QUAKE_DATA, 1, 1)
	knockRemote:FireAllClients("Shake", 1)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = f.char.color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.4, 3, 3)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.3), { Size = Vector3.new(0.4, 24, 24), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.35)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 140, 120))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.5, 0.8)
	dust.Speed = NumberRange.new(15, 25)
	dust.SpreadAngle = Vector2.new(10, 80)
	dust.Rate = 0
	dust.Parent = ring
	dust:Emit(25)
end

function quakeAttack(f, airborne)
	local root, hum = rootOf(f), humOf(f)
	if not root then return end
	if not airborne then
		task.delay(0.15, function() shockwave(f) end)
		knockRemote:FireAllClients("Pose", f.model, "Quake")
		return
	end
	-- en l'air : plongée vers le sol puis séisme à l'atterrissage
	if f.player then
		knockRemote:FireClient(f.player, "Dive")
	else
		root.AssemblyLinearVelocity = Vector3.new(0, -130, 0)
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1 do
			task.wait(0.03)
			if not f.model or f.koing or not hum.Parent then return end
			if hum.FloorMaterial ~= Enum.Material.Air then break end
		end
		if os.clock() - t0 < 1 then shockwave(f) end
	end)
end

-- Exécute une action (utilisé par les joueurs ET les bots)
local function doAction(f, kind, dir, facing, charge)
	if not combat() then return end
	local root, hum = rootOf(f), humOf(f)
	if not root or not hum or f.stocks <= 0 then return end
	local now = os.clock()

	if kind == "ShieldOn" then
		if now >= f.stunUntil and f.shieldHp > 10 and hum.FloorMaterial ~= Enum.Material.Air then
			setShield(f, true)
			knockRemote:FireAllClients("Pose", f.model, "Shield")
		end
		return
	elseif kind == "ShieldOff" then
		setShield(f, false)
		knockRemote:FireAllClients("Pose", f.model, "ShieldEnd")
		return
	end

	if f.shielding or now < f.cooldownUntil or now < f.stunUntil then return end
	facing = (facing == -1) and -1 or 1
	local airborne = hum.FloorMaterial == Enum.Material.Air

	local name
	if kind == "Attack" then
		if dir == "Up" then name = "JabUp"
		elseif dir == "Down" then name = airborne and "AirDown" or "JabDown"
		else name = "JabSide" end
	elseif kind == "Smash" then
		if dir == "Up" then name = "SmashUp"
		elseif dir == "Down" then name = "SmashDown"
		else name = "SmashSide" end
	elseif kind == "Special" then
		if dir == "Up" then
			name = "SpecialUp" -- le super saut lui-même est appliqué par le client / le bot
		else
			f.cooldownUntil = now + f.char.specialCooldown
			local sp = f.char.special
			if sp == "dash" then
				dashAttack(f, facing)
			elseif sp == "quake" then
				quakeAttack(f, airborne)
			else
				knockRemote:FireAllClients("Pose", f.model, "Special")
				fireProjectile(f, facing, sp == "orb")
			end
			return
		end
	else
		return
	end

	local data = Config.ATTACKS[name]
	local mult = 1
	if kind == "Smash" then
		charge = math.clamp(tonumber(charge) or 0, 0, Config.SMASH_CHARGE_MAX)
		mult = 1 + (charge / Config.SMASH_CHARGE_MAX) * Config.SMASH_CHARGE_BONUS
	end
	f.cooldownUntil = now + data.cooldown
	knockRemote:FireAllClients("Pose", f.model, name)
	-- les bots proches peuvent réagir (bouclier / esquive)
	for _, o in pairs(fighters) do
		if o ~= f and o.isBot and o.ai and (o.ai.dodge or 0) > 0 and alive(o) then
			local orr, ohum = rootOf(o), humOf(o)
			local d = orr.Position - root.Position
			if d.Magnitude < 9 and math.sign(d.X) == facing and os.clock() >= o.stunUntil and math.random() < o.ai.dodge then
				if ohum.FloorMaterial ~= Enum.Material.Air and o.shieldHp > 30 and math.random() < 0.6 then
					setShield(o, true)
					knockRemote:FireAllClients("Pose", o.model, "Shield")
					task.delay(0.4, function()
						setShield(o, false)
						knockRemote:FireAllClients("Pose", o.model, "ShieldEnd")
					end)
				else
					-- esquive : petit bond en arrière + invincibilité courte
					orr.AssemblyLinearVelocity = Vector3.new(facing * 30, 35, 0)
					o.invincibleUntil = math.max(o.invincibleUntil, os.clock() + 0.3)
				end
			end
		end
	end
	if data.startup then
		task.delay(data.startup, function()
			if f.model and os.clock() >= f.stunUntil then hitboxAt(f, data, facing, mult) end
		end)
	else
		hitboxAt(f, data, facing, mult)
	end
end

----------------------------------------------------------------------
-- Vote de map
----------------------------------------------------------------------
local votes = {} -- player -> index (0 = aléatoire)
local modeVotes = {} -- player -> "FFA" / "Teams"

local function refreshVotes()
	for i = 0, #Maps do state:SetAttribute("Vote" .. i, 0) end
	for _, idx in pairs(votes) do
		state:SetAttribute("Vote" .. idx, (state:GetAttribute("Vote" .. idx) or 0) + 1)
	end
	local ffa, teams = 0, 0
	for _, m in pairs(modeVotes) do
		if m == "Teams" then teams += 1 else ffa += 1 end
	end
	state:SetAttribute("VoteFFA", ffa)
	state:SetAttribute("VoteTeams", teams)
end

actionRemote.OnServerEvent:Connect(function(player, kind, dir, facing, charge)
	if kind == "Pick" then
		local f = fighters["P" .. player.UserId]
		if f and f.inMenu and typeof(dir) == "string" then setChar(f, dir) end
		return
	end
	if kind == "Training" then
		local f = fighters["P" .. player.UserId]
		local ph = phase()
		if f and f.inMenu and (ph == "Waiting" or ph == "Training") then
			setMenu(f, false)
			setTraining(f, true)
			applyScale(f)
			applyStats(f)
			if ph == "Training" then joinTraining(f) end
		end
		return
	end
	if kind == "LeaveTraining" then
		local f = fighters["P" .. player.UserId]
		if f and f.training then
			setTraining(f, false)
			setInRound(f, false)
			setMenu(f, true)
			park(f)
		end
		return
	end
	if kind == "BagDamage" then
		local f = fighters["P" .. player.UserId]
		local bag = fighters["BAG"]
		if f and f.training and bag and typeof(dir) == "number" then
			bag.damage = math.clamp(math.floor(dir), 0, 999)
			sync(bag)
		end
		return
	end
	if kind == "Play" then
		local f = fighters["P" .. player.UserId]
		if f and f.inMenu then
			setMenu(f, false)
			f.info:SetAttribute("Eliminated", false)
			applyScale(f)
			applyStats(f)
			local ph = phase()
			if ph == "Fight" or ph == "Countdown" then
				knockRemote:FireClient(player, "NextRound") -- spectateur jusqu'à la prochaine manche
			else
				placeAt(f, spawnPos(f.slot))
			end
		end
		return
	end
	if kind == "VoteMode" then
		if phase() == "Vote" and (dir == "FFA" or dir == "Teams") then
			modeVotes[player] = dir
			refreshVotes()
		end
		return
	end
	if kind == "BotSettings" then
		local ph = phase()
		if ph == "Waiting" or ph == "Vote" or ph == "End" or ph == "Training" then
			local n = tonumber(dir)
			if n then state:SetAttribute("BotCount", math.clamp(math.floor(n), 0, 5)) end
			local lvl = facing
			if lvl == "Mix" or lvl == "Facile" or lvl == "Moyen" or lvl == "Difficile" or lvl == "Expert" then
				state:SetAttribute("BotLevel", lvl)
			end
		end
		return
	end
	if kind == "Vote" then
		local idx = tonumber(dir)
		if phase() == "Vote" and idx and idx >= 0 and idx <= #Maps and idx % 1 == 0 then
			votes[player] = idx
			refreshVotes()
		end
		return
	end
	local f = fighters["P" .. player.UserId]
	if f and typeof(kind) == "string" and f.inRound and not f.inMenu then
		doAction(f, kind, dir, facing, charge)
	end
end)

local function pickMap()
	local best, list = -1, {}
	for i = 1, #Maps do
		local n = state:GetAttribute("Vote" .. i) or 0
		if n > best then best, list = n, { i } elseif n == best then table.insert(list, i) end
	end
	local random = state:GetAttribute("Vote0") or 0
	if best <= 0 or random > best then return math.random(1, #Maps) end
	return list[math.random(1, #list)]
end

----------------------------------------------------------------------
-- KO
----------------------------------------------------------------------
-- petite plateforme de réapparition qui disparaît
local function revivalPlatform(f)
	local p = Instance.new("Part")
	p.Name = "RevivalPlatform"
	p.Anchored = true
	p.Size = Vector3.new(8, 0.6, 8)
	p.Material = Enum.Material.Neon
	p.Color = f.info:GetAttribute("Color")
	p.Transparency = 0.3
	p.CFrame = CFrame.new(respawnPos() - Vector3.new(0, 3.3, 0))
	p.Parent = workspace
	Debris:AddItem(p, Config.RESPAWN_INVINCIBILITY)
end

local function respawnAfterKO(f)
	revivalPlatform(f)
	placeAt(f, respawnPos())
	giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
end

local function eliminated(f)
	park(f)
	f.info:SetAttribute("Eliminated", true)
	if f.player then
		knockRemote:FireClient(f.player, "Eliminated")
		-- retour au menu après un petit moment
		task.delay(2.5, function()
			if fighters[f.id] == f and f.stocks <= 0 then setMenu(f, true) end
		end)
	end
end

-- Animation de KO : le perso tourne, s'envole et disparaît, puis explosion / étoile
local function koAnimation(f, model, root)
	local b = curMap.blast
	local p = root.Position
	local cp = Vector3.new(math.clamp(p.X, O.X - b.x + 6, O.X + b.x - 6), math.clamp(p.Y, O.Y - b.bottom + 6, O.Y + b.top - 6), O.Z)
	local starKO = p.Y > O.Y + b.top - 1 -- sorti par le haut : KO "étoile" vers le fond de l'écran
	local dir = Vector3.new(cp.X - O.X, cp.Y - O.Y, 0)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(0, 1, 0)
	local color = f.info:GetAttribute("Color")

	f.koing = true
	setShield(f, false)
	if f.player then knockRemote:FireClient(f.player, "KOStart") end
	knockRemote:FireAllClients("KO", cp, color, f.name)
	root.Anchored = true

	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if (d:IsA("BasePart") and d ~= root) or d:IsA("Decal") then parts[d] = d.Transparency end
	end

	-- traînée de couleur derrière le perso
	local trailFx = Instance.new("Part")
	trailFx.Anchored = true
	trailFx.CanCollide = false
	trailFx.CanQuery = false
	trailFx.Material = Enum.Material.Neon
	trailFx.Color = color

	local startPos = starKO and Vector3.new(cp.X, O.Y + b.top - 12, O.Z) or (cp - dir * 6)
	local DURATION = 1.0
	local t0 = os.clock()
	while true do
		local a = math.min((os.clock() - t0) / DURATION, 1)
		if not model.Parent or f.model ~= model then break end
		local cf
		if starKO then
			-- part loin derrière, en tournoyant, et rapetisse à l'écran
			cf = CFrame.new(startPos + Vector3.new(0, a * 15, -a * 140)) * CFrame.Angles(a * 6, a * 25, a * 4)
		else
			-- éjecté hors de l'écran en vrille
			cf = CFrame.new(startPos + dir * (a * a * 30)) * CFrame.Angles(a * 18, a * 12, a * 9)
		end
		model:PivotTo(cf)
		for d, t in pairs(parts) do d.Transparency = t + (1 - t) * math.max(0, a - 0.4) / 0.6 end
		if not starKO then
			trailFx.Size = Vector3.new(1.2, 1.2, (cf.Position - startPos).Magnitude + 1)
			trailFx.CFrame = CFrame.lookAt((cf.Position + startPos) / 2, cf.Position)
			trailFx.Transparency = 0.2 + a * 0.8
			trailFx.Parent = workspace
		end
		if a >= 1 then break end
		RunService.Heartbeat:Wait()
	end
	trailFx:Destroy()

	-- effet final
	local endPos = model.Parent and model:GetPivot().Position or cp
	if starKO then
		local star = flash(CFrame.new(endPos), Vector3.new(2, 2, 2), Color3.fromRGB(255, 255, 200), 0.35)
		star.Shape = Enum.PartType.Ball
		local sparkle = Instance.new("Sparkles")
		sparkle.SparkleColor = color
		sparkle.Parent = star
	else
		local e = Instance.new("Explosion")
		e.Position = cp
		e.BlastPressure = 0
		e.DestroyJointRadiusPercent = 0
		e.BlastRadius = 14
		e.Parent = workspace
		flash(CFrame.lookAt(cp, O) * CFrame.new(0, 0, -25), Vector3.new(3, 3, 50), color, 0.5)
		flash(CFrame.new(cp), Vector3.new(10, 10, 10), Color3.new(1, 1, 1), 0.15).Shape = Enum.PartType.Ball
	end
	knockRemote:FireAllClients("Shake", 1.2)

	for d, t in pairs(parts) do
		if d.Parent then d.Transparency = t end
	end
	f.koing = false
	return f.model == model
end

local function ko(f, noAnim)
	if f.stocks <= 0 or f.koing then return end
	-- crédit du KO au dernier attaquant (si touché récemment)
	if f.lastHitBy and fighters[f.lastHitBy.id] and os.clock() - (f.lastHitTime or 0) < 8 then
		f.lastHitBy.kos += 1
		sync(f.lastHitBy)
	end
	f.lastHitBy = nil
	f.stocks -= 1
	f.damage = 0
	f.shieldHp = Config.SHIELD_MAX
	setShield(f, false)
	sync(f)

	local model, root = f.model, rootOf(f)
	task.spawn(function()
		local stillSame = true
		if root and not noAnim then
			stillSame = koAnimation(f, model, root)
		end
		if not stillSame then return end -- nouveau perso entre-temps
		if f.stocks > 0 then
			if combat() then
				park(f)
				task.wait(0.6)
				if fighters[f.id] == f and combat() and f.model == model then respawnAfterKO(f) end
			end
		else
			eliminated(f)
		end
	end)
end

----------------------------------------------------------------------
-- Joueurs
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Statistiques sauvegardées (DataStore) + classement
-- Dans Studio : Paramètres du jeu > Sécurité > "Enable Studio Access to API Services"
----------------------------------------------------------------------
local statsStore, winsBoard
pcall(function()
	statsStore = DataStoreService:GetDataStore("SmashStats_v1")
	winsBoard = DataStoreService:GetOrderedDataStore("SmashWins_v1")
end)
local playerStats = {} -- player -> { wins, kos, matches }

local function loadStats(player)
	local data = { wins = 0, kos = 0, matches = 0 }
	if statsStore then
		local ok, saved = pcall(function() return statsStore:GetAsync("u" .. player.UserId) end)
		if ok and type(saved) == "table" then
			data.wins = tonumber(saved.wins) or 0
			data.kos = tonumber(saved.kos) or 0
			data.matches = tonumber(saved.matches) or 0
		end
	end
	playerStats[player] = data
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, pair in ipairs({ { "Victoires", "wins" }, { "KO", "kos" }, { "Matchs", "matches" } }) do
		local v = Instance.new("IntValue")
		v.Name = pair[1]
		v.Value = data[pair[2]]
		v.Parent = ls
	end
	ls.Parent = player
end

local function refreshLeaderstats(player)
	local data = playerStats[player]
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then return end
	ls.Victoires.Value = data.wins
	ls.KO.Value = data.kos
	ls.Matchs.Value = data.matches
end

local function saveStats(player)
	local data = playerStats[player]
	if not data then return end
	if statsStore then
		pcall(function() statsStore:SetAsync("u" .. player.UserId, data) end)
	end
	if winsBoard then
		pcall(function() winsBoard:SetAsync(tostring(player.UserId), data.wins) end)
	end
end

local nameCache = {}
local function refreshLeaderboard()
	if not winsBoard then
		state:SetAttribute("Leaderboard", "(Active l'accès aux API dans Studio pour le classement)")
		return
	end
	local ok, pages = pcall(function() return winsBoard:GetSortedAsync(false, 10) end)
	if not ok then return end
	local lines = {}
	for i, entry in ipairs(pages:GetCurrentPage()) do
		local uid = tonumber(entry.key)
		local name = uid and nameCache[uid]
		if uid and not name then
			local okName, n = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
			name = okName and n or ("#" .. uid)
			nameCache[uid] = name
		end
		table.insert(lines, string.format("%d. %s — %d victoire%s", i, name or "?", entry.value, entry.value > 1 and "s" or ""))
	end
	state:SetAttribute("Leaderboard", #lines > 0 and table.concat(lines, "\n") or "Aucune victoire pour l'instant !")
end
task.spawn(function()
	while true do
		refreshLeaderboard()
		task.wait(60)
	end
end)

local function onPlayer(player)
	task.spawn(loadStats, player)
	local f = newFighter("P" .. player.UserId, player.DisplayName, player)
	setMenu(f, true) -- commence sur le menu
	setInRound(f, false)
	local function onChar(char)
		task.spawn(function()
			setupCharacter(f, char)
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				-- reset volontaire = perte d'une vie
				if combat() and f.inRound then ko(f, true) end
			end)
		end)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then onChar(player.Character) end
end

loadMap(1)
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	votes[player] = nil
	modeVotes[player] = nil
	task.spawn(saveStats, player)
	task.delay(5, function() playerStats[player] = nil end)
	local f = fighters["P" .. player.UserId]
	if f then removeFighter(f) end
	if phase() == "Vote" then refreshVotes() end
end)

----------------------------------------------------------------------
-- Bots CPU
----------------------------------------------------------------------
local bots = {}

local function playAnims(f)
	local hum = humOf(f)
	local animate = f.model:FindFirstChild("Animate")
	if not hum or not animate then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local function load(folder)
		local fo = animate:FindFirstChild(folder)
		local a = fo and fo:FindFirstChildOfClass("Animation")
		if a then
			local ok, track = pcall(function() return animator:LoadAnimation(a) end)
			if ok then return track end
		end
	end
	local idle, run, fall = load("idle"), load("run"), load("fall")
	animate:Destroy()
	local current
	f.animStep = function()
		local want
		if hum.FloorMaterial == Enum.Material.Air then want = fall
		elseif math.abs(hum.MoveDirection.X) > 0.1 then want = run
		else want = idle end
		if want ~= current then
			if current then current:Stop(0.15) end
			if want then want:Play(0.15) end
			current = want
		end
	end
end

local function spawnBot(i, def)
	local id = def.id or ("CPU" .. i)
	if fighters[id] then return fighters[id] end
	local f = newFighter(id, def.name, nil)
	setChar(f, def.bag and "Brawler" or Fighters.Characters[math.random(1, #Fighters.Characters)].id)
	f.info:SetAttribute("DisplayName", def.bag and def.name or (def.name .. " (" .. f.char.name .. ")"))
	f.isBot = true
	f.ai = def
	if def.bag then
		setInRound(f, true)
		f.stocks = 99
		sync(f)
	end
	f.airJumps = f.char.airJumps
	f.recovery = true
	f.nextThink = 0
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local c = def.bag and Color3.fromRGB(190, 160, 90) or f.char.color
		desc.HeadColor, desc.TorsoColor = c, c
		desc.LeftArmColor, desc.RightArmColor = c, c
		desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(40, 40, 40), Color3.fromRGB(40, 40, 40)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn("[Smash] Impossible de créer le bot :", model)
		removeFighter(f)
		return
	end
	model.Name = def.name
	model.Parent = workspace
	model.HumanoidRootPart:SetNetworkOwner(nil)
	bots[id] = f
	task.spawn(function()
		setupCharacter(f, model)
		playAnims(f)
	end)
	return f
end

local function despawnBot(f)
	bots[f.id] = nil
	if f.model then f.model:Destroy() end
	removeFighter(f)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function groundBelow(pos, depth)
	rayParams.FilterDescendantsInstances = { solidsFolder, platformsFolder }
	return workspace:Raycast(pos, Vector3.new(0, -(depth or 80), 0), rayParams)
end

local function nearestStageX(x)
	local bestX, bestD = O.X, math.huge
	for _, p in ipairs(solidsFolder:GetChildren()) do
		local half = p.Size.X / 2 - 3
		local cx = math.clamp(x, p.Position.X - half, p.Position.X + half)
		local d = math.abs(cx - x)
		if d < bestD then bestD, bestX = d, cx end
	end
	return bestX
end

local function botJump(f, root, hum, vx)
	if hum.FloorMaterial ~= Enum.Material.Air then
		hum.Jump = true
		return true
	elseif f.airJumps > 0 then
		f.airJumps -= 1
		root.AssemblyLinearVelocity = Vector3.new(vx or root.AssemblyLinearVelocity.X, Config.AIR_JUMP_VELOCITY, 0)
		return true
	end
	return false
end

local function botThink(f)
	local root, hum = rootOf(f), humOf(f)
	if not root or not hum or root.Anchored then return end
	serverOwn(f)
	if f.animStep then f.animStep() end
	local now = os.clock()
	local pos = root.Position
	local ai = f.ai

	-- garder sur le plan 2D
	if math.abs(pos.Z - O.Z) > 0.05 then
		root.CFrame += Vector3.new(0, 0, O.Z - pos.Z)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
	end

	-- traverser les plateformes par en dessous
	local underPlatform = false
	for _, p in ipairs(platformsFolder:GetChildren()) do
		if math.abs(pos.X - p.Position.X) < p.Size.X / 2 + 2 and pos.Y - 2.5 < p.Position.Y + 0.5 and pos.Y > p.Position.Y - 14 then
			underPlatform = true
		end
	end
	local g = underPlatform and "Ghost" or "Fighters"
	if f.group ~= g then f.group = g setGroup(f.model, g) end

	if now < f.stunUntil then
		hum:Move(Vector3.zero)
		return
	end
	if hum.PlatformStand then hum.PlatformStand = false end
	if hum.FloorMaterial ~= Enum.Material.Air then
		f.airJumps = f.char.airJumps
		f.recovery = true
	end
	if not combat() then hum:Move(Vector3.zero) return end
	if ai.bag then hum:Move(Vector3.zero) return end -- le sac de frappe ne fait rien

	local vel = root.AssemblyLinearVelocity

	-- accroche au bord de la scène
	if ai.ledge and vel.Y < 5 and now >= (f.ledgeCooldown or 0) then
		for _, p in ipairs(solidsFolder:GetChildren()) do
			local top = p.Position.Y + p.Size.Y / 2
			for _, side in ipairs({ -1, 1 }) do
				local edgeX = p.Position.X + side * p.Size.X / 2
				local outside = (pos.X - edgeX) * side > -0.5
				if outside and math.abs(pos.X - edgeX) < 3.5 and pos.Y < top + 1 and pos.Y > top - 7 then
					f.ledgeCooldown = now + 1
					root.Anchored = true
					root.CFrame = CFrame.new(edgeX + side * 1.2, top - 2.2, O.Z) * CFrame.Angles(0, math.rad(side > 0 and 90 or -90), 0)
					knockRemote:FireAllClients("Pose", f.model, "Ledge")
					task.delay(0.35 + ai.think, function()
						if f.model and root.Parent and not f.koing then
							root.Anchored = false
							serverOwn(f)
							root.CFrame = CFrame.new(edgeX - side * 2.5, top + 3.2, O.Z)
							root.AssemblyLinearVelocity = Vector3.zero
							knockRemote:FireAllClients("Pose", f.model, "ShieldEnd")
						end
					end)
					return
				end
			end
		end
	end

	-- récupération : plus de sol en dessous -> revenir vers la scène
	if not groundBelow(pos + Vector3.new(0, 1, 0), 120) then
		local tx = nearestStageX(pos.X)
		local d = math.sign(tx - pos.X)
		hum:Move(Vector3.new(d, 0, 0))
		if vel.Y < 0 and (pos.Y < O.Y + 6 or (ai.dodge or 0) > 0.3) then
			if not botJump(f, root, hum, d * Config.WALK_SPEED) and f.recovery and pos.Y < O.Y - 2 then
				f.recovery = false
				root.AssemblyLinearVelocity = Vector3.new(d * 28, Config.RECOVERY_VELOCITY, 0)
				doAction(f, "Special", "Up", d)
			end
		end
		return
	end

	-- cible la plus proche
	local target, best = nil, math.huge
	for _, o in pairs(fighters) do
		if o ~= f and alive(o) and not rootOf(o).Anchored and not (teamsMode() and o.team and o.team == f.team) then
			local d = (rootOf(o).Position - pos).Magnitude
			if d < best then best, target = d, o end
		end
	end
	if not target then hum:Move(Vector3.zero) return end
	local tp = rootOf(target).Position
	local dx, dy = tp.X - pos.X, tp.Y - pos.Y
	local facing = dx >= 0 and 1 or -1

	if now < f.nextThink then return end
	f.nextThink = now + ai.think * (0.7 + math.random() * 0.6)

	-- ne pas suivre une cible qui tombe hors de la scène
	local targetOffStage = not groundBelow(tp + Vector3.new(0, 1, 0), 120)
	local move = 0
	if math.abs(dx) > 4 then move = facing end
	if targetOffStage and math.abs(dx) < 14 then move = 0 end

	-- vide devant ? sauter par-dessus (îles) ou s'arrêter
	if move ~= 0 and not groundBelow(pos + Vector3.new(move * 6, 1, 0), 30) then
		if not targetOffStage and groundBelow(Vector3.new(tp.X, pos.Y + 5, O.Z), 60) and hum.FloorMaterial ~= Enum.Material.Air then
			hum.Jump = true
		elseif hum.FloorMaterial ~= Enum.Material.Air then
			move = 0
		end
	end
	hum:Move(Vector3.new(move, 0, 0))
	if move == 0 then
		root.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(facing > 0 and -90 or 90), 0)
	end

	-- monter vers la cible
	if dy > 6 and math.random() < 0.35 and vel.Y < 5 then botJump(f, root, hum) end
	-- saut aléatoire pour être moins prévisible
	if math.random() < 0.03 then botJump(f, root, hum) end

	-- bouclier (bots doués) si la cible est collée et qu'on est blessé
	if ai.aggro > 0.8 and math.abs(dx) < 6 and math.random() < 0.08 and f.shieldHp > 50 then
		doAction(f, "ShieldOn")
		task.delay(0.4, function() if f.model then doAction(f, "ShieldOff") end end)
		return
	end

	if target.shielding and math.random() < 0.5 then return end
	if math.random() > ai.aggro then return end

	local aimOk = math.random() < ai.aim
	if math.abs(dx) < 6 and math.abs(dy) < 4 then
		local smashChance = ai.smash + ((ai.finisher and target.damage > 90) and 0.4 or 0)
		if math.random() < smashChance then
			doAction(f, "Smash", "Side", aimOk and facing or -facing, math.random() * Config.SMASH_CHARGE_MAX)
		elseif dy < -1 and math.random() < 0.3 then
			doAction(f, "Smash", "Down", facing, 0.3)
		else
			doAction(f, "Attack", "Side", aimOk and facing or -facing)
		end
	elseif math.abs(dx) < 4 and dy > 3 and dy < 10 then
		doAction(f, math.random() < ai.smash and "Smash" or "Attack", "Up", facing, 0.4)
	elseif math.abs(dx) < 3 and dy < -3 and hum.FloorMaterial == Enum.Material.Air then
		doAction(f, "Attack", "Down", facing)
	elseif math.abs(dx) > 12 and math.abs(dy) < 3 and math.random() < ai.special * 2 then
		doAction(f, "Special", "Side", facing)
	end
end

----------------------------------------------------------------------
-- Boucle principale
----------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	for _, f in pairs(fighters) do
		local root = rootOf(f)
		-- bouclier
		if f.shielding then
			f.shieldHp -= Config.SHIELD_DRAIN * dt
			if f.shieldPart then
				local s = 3 + 4 * math.max(f.shieldHp, 0) / Config.SHIELD_MAX
				f.shieldPart.Size = Vector3.new(s, s, s)
			end
			if f.shieldHp <= 0 then
				setShield(f, false)
				f.shieldHp = Config.SHIELD_MAX * 0.4
				applyKnockback(f, Vector3.new(0, 50, 0), Config.SHIELD_BREAK_STUN)
			end
		else
			f.shieldHp = math.min(Config.SHIELD_MAX, f.shieldHp + Config.SHIELD_REGEN * dt)
		end
		f.info:SetAttribute("Shield", math.floor(f.shieldHp) / Config.SHIELD_MAX)

		-- zones de KO
		if root and not root.Anchored then
			local p, b = root.Position, curMap.blast
			local out = math.abs(p.X - O.X) > b.x or p.Y > O.Y + b.top or p.Y < O.Y - b.bottom
			if out then
				if combat() and f.stocks > 0 then ko(f) else placeAt(f, respawnPos()) end
			end
		end
	end
	for _, b in pairs(bots) do botThink(b) end
end)

----------------------------------------------------------------------
-- Objets
----------------------------------------------------------------------
local itemsFolder = Instance.new("Folder")
itemsFolder.Name = "SmashItems"
itemsFolder.Parent = workspace

local function clearItems()
	itemsFolder:ClearAllChildren()
end

local function pickItemDef()
	local total = 0
	for _, it in ipairs(Fighters.Items) do total += it.weight end
	local r = math.random() * total
	for _, it in ipairs(Fighters.Items) do
		r -= it.weight
		if r <= 0 then return it end
	end
	return Fighters.Items[1]
end

local function buildItemModel(def)
	local m = Instance.new("Model")
	m.Name = def.id
	local main = Instance.new("Part")
	main.Name = "Main"
	main.Size = Vector3.new(2.4, 2.4, 2.4)
	main.Color = def.color
	main.Material = Enum.Material.Neon
	main.CanTouch = false
	main.CollisionGroup = "Items"
	if def.id == "Bomb" then
		main.Shape = Enum.PartType.Ball
		main.Material = Enum.Material.SmoothPlastic
		local fuse = Instance.new("Part")
		fuse.Size = Vector3.new(0.4, 0.8, 0.4)
		fuse.Color = Color3.fromRGB(255, 120, 40)
		fuse.Material = Enum.Material.Neon
		fuse.CanCollide = false
		fuse.Massless = true
		fuse.CollisionGroup = "Items"
		fuse.CFrame = main.CFrame * CFrame.new(0, 1.4, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = main, fuse
		w.Parent = fuse
		fuse.Parent = m
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = fuse
	elseif def.id == "Heal" then
		main.Shape = Enum.PartType.Ball
	end
	main.Parent = m
	m.PrimaryPart = main

	local light = Instance.new("PointLight")
	light.Color = def.color
	light.Range = 8
	light.Parent = main

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 110, 0, 26)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = main
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 1, 0)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = def.id == "Bomb" and Color3.fromRGB(255, 90, 60) or def.color
	t.TextStrokeTransparency = 0
	t.Text = def.name
	t.Parent = bb
	return m
end

local function spawnItem()
	local surfaces = {}
	for _, p in ipairs(solidsFolder:GetChildren()) do table.insert(surfaces, p) end
	for _, p in ipairs(platformsFolder:GetChildren()) do table.insert(surfaces, p) end
	if #surfaces == 0 then return end
	local surf = surfaces[math.random(1, #surfaces)]
	local x = surf.Position.X + (math.random() - 0.5) * math.max(surf.Size.X - 4, 0)
	local def = pickItemDef()
	local m = buildItemModel(def)
	m:SetAttribute("Spawned", os.clock())
	m:PivotTo(CFrame.new(x, O.Y + 40, O.Z))
	m.Parent = itemsFolder
	-- plan 2D pour l'objet
	local main = m.PrimaryPart
	local att = Instance.new("Attachment", main)
	local plane = Instance.new("AlignPosition")
	plane.Mode = Enum.PositionAlignmentMode.OneAttachment
	plane.Attachment0 = att
	plane.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	plane.MaxAxesForce = Vector3.new(0, 0, 1e6)
	plane.Position = Vector3.new(0, 0, O.Z)
	plane.Responsiveness = 200
	plane.Parent = main
	main:SetNetworkOwner(nil)
end

local function explodeBomb(def, pos)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.BlastRadius = def.radius
	e.Parent = workspace
	knockRemote:FireAllClients("Shake", 1.3)
	for _, f in pairs(fighters) do
		local r = rootOf(f)
		if r and alive(f) and f.inRound and os.clock() >= f.invincibleUntil and (r.Position - pos).Magnitude <= def.radius then
			if f.shielding then
				f.shieldHp -= def.dmg * 2
			else
				f.damage = math.min(999, f.damage + def.dmg)
				sync(f)
				local dir = math.sign(r.Position.X - pos.X)
				if dir == 0 then dir = 1 end
				local a = math.rad(def.angle)
				local power = (def.base + f.damage * def.growth) * f.char.weight
				applyKnockback(f, Vector3.new(math.cos(a) * dir, math.sin(a), 0) * power,
					math.clamp(power * Config.HITSTUN_FACTOR, 0.2, Config.HITSTUN_MAX))
			end
		end
	end
end

local function giveHammerVisual(f, duration)
	if not f.model then return end
	local hand = f.model:FindFirstChild("RightHand") or f.model:FindFirstChild("Right Arm")
	if not hand then return end
	local old = f.model:FindFirstChild("SmashHammer")
	if old then old:Destroy() end
	local hammer = Instance.new("Model")
	hammer.Name = "SmashHammer"
	local handle = Instance.new("Part")
	handle.Size = Vector3.new(0.4, 3, 0.4)
	handle.Color = Color3.fromRGB(120, 80, 40)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = hand.CFrame * CFrame.new(0, -1.2, 0)
	handle.Parent = hammer
	local head = Instance.new("Part")
	head.Size = Vector3.new(1.6, 1.2, 1.2)
	head.Color = Color3.fromRGB(255, 170, 40)
	head.Material = Enum.Material.Metal
	head.CanCollide = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, -1.6, 0)
	head.Parent = hammer
	for _, part in ipairs({ handle, head }) do
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = part, hand
		w.Parent = part
	end
	hammer.Parent = f.model
	Debris:AddItem(hammer, duration)
end

local function pickup(f, item)
	local def
	for _, d in ipairs(Fighters.Items) do
		if d.id == item.Name then def = d end
	end
	if not def then return end
	local pos = item:GetPivot().Position
	item:Destroy()
	if def.id == "Bomb" then
		explodeBomb(def, pos)
		return
	end
	if f.player then knockRemote:FireClient(f.player, "Pickup", def.name .. " : " .. def.desc) end
	if def.id == "Heal" then
		f.damage = math.max(0, f.damage - 35)
		sync(f)
		flash(CFrame.new(pos), Vector3.new(6, 6, 6), def.color, 0.25).Shape = Enum.PartType.Ball
	elseif def.id == "Hammer" then
		f.hammerUntil = os.clock() + def.duration
		giveHammerVisual(f, def.duration)
	elseif def.id == "Boots" then
		f.bootsUntil = os.clock() + def.duration
		applyStats(f)
		task.delay(def.duration + 0.05, function() applyStats(f) end)
		local r = rootOf(f)
		if r then
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = def.color
			sp.Parent = r
			Debris:AddItem(sp, def.duration)
		end
	end
end

local nextItemAt = math.huge
RunService.Heartbeat:Connect(function()
	if not combat() then return end
	local now = os.clock()
	if now >= nextItemAt then
		nextItemAt = now + Fighters.ITEM_INTERVAL * (0.7 + math.random() * 0.6)
		spawnItem()
	end
	for _, item in ipairs(itemsFolder:GetChildren()) do
		local main = item.PrimaryPart
		if not main then
			item:Destroy()
		else
			local pos = main.Position
			local age = now - (item:GetAttribute("Spawned") or now)
			if age > Fighters.ITEM_LIFETIME or pos.Y < O.Y - curMap.blast.bottom then
				if item.Name == "Bomb" and age > Fighters.ITEM_LIFETIME then
					explodeBomb(Fighters.Items[4], pos)
				end
				item:Destroy()
			else
				for _, f in pairs(fighters) do
					local r = rootOf(f)
					if r and alive(f) and f.inRound and (r.Position - pos).Magnitude < 4 then
						pickup(f, item)
						break
					end
				end
			end
		end
	end
end)

----------------------------------------------------------------------
-- Manches
----------------------------------------------------------------------
-- joueurs qui ont appuyé sur JOUER
local function humanCount()
	local n = 0
	for _, f in pairs(fighters) do
		if f.player and not f.inMenu and not f.training then n += 1 end
	end
	return n
end

local function trainingCount()
	local n = 0
	for _, f in pairs(fighters) do
		if f.player and f.training then n += 1 end
	end
	return n
end

local function botDefFor(i)
	local level = state:GetAttribute("BotLevel") or "Mix"
	if level == "Mix" then
		return Config.BOTS[((i - 1) % #Config.BOTS) + 1], false
	end
	for _, d in ipairs(Config.BOTS) do
		if d.name == "CPU " .. level then return d, true end
	end
	return Config.BOTS[1], false
end

local function setupBots()
	if fighters["BAG"] then despawnBot(fighters["BAG"]) end
	-- on recrée les bots à chaque manche (nouveau perso au hasard, réglages à jour)
	for _, b in pairs(bots) do despawnBot(b) end
	local want = Config.FILL_WITH_BOTS or humanCount() < 2
	if not want then return end
	local count = state:GetAttribute("BotCount") or 3
	for i = 1, count do
		local def, numbered = botDefFor(i)
		def = table.clone(def)
		if numbered then def.name = def.name .. " " .. i end
		spawnBot(i, def)
	end
	task.wait(0.4)
end

local function assignTeams()
	local list = {}
	for _, f in pairs(fighters) do
		if f.inRound then table.insert(list, f) end
	end
	-- humains d'abord (répartis), puis les bots
	table.sort(list, function(a, b)
		if (a.player ~= nil) ~= (b.player ~= nil) then return a.player ~= nil end
		return a.slot < b.slot
	end)
	for i, f in ipairs(list) do
		f.team = teamsMode() and (((i - 1) % 2) + 1) or nil
		f.info:SetAttribute("Team", f.team or 0)
		local outline = f.model and f.model:FindFirstChild("SmashOutline")
		if outline then
			outline.OutlineColor = f.team and TEAM_COLORS[f.team] or f.info:GetAttribute("Color")
		end
	end
end

local function startRound()
	for _, f in pairs(fighters) do
		f.info:SetAttribute("Eliminated", false)
		if f.player and (f.inMenu or f.training) then
			setInRound(f, false)
			f.stocks = 0
			sync(f)
			continue
		end
		setInRound(f, true)
		f.koing = false
		f.hammerUntil = 0
		f.bootsUntil = 0
		applyStats(f)
		if f.model and f.model:FindFirstChild("SmashHammer") then f.model.SmashHammer:Destroy() end
		f.stocks = Config.STOCKS
		f.damage = 0
		f.kos = 0
		f.shieldHp = Config.SHIELD_MAX
		f.lastHitBy = nil
		setShield(f, false)
		sync(f)
		placeAt(f, spawnPos(f.slot), true) -- figé pendant le compte à rebours
		giveInvincibility(f, 1)
	end
	assignTeams()
end

-- libère tout le monde au "GO !"
local function releaseAll()
	for _, f in pairs(fighters) do
		local r = rootOf(f)
		if r and f.inRound and f.stocks > 0 and not f.koing then
			r.Anchored = false
			serverOwn(f)
			if f.player then knockRemote:FireClient(f.player, "Reset") end
		end
	end
end

local function results()
	local list = {}
	for _, f in pairs(fighters) do
		if f.inRound then table.insert(list, f) end
	end
	table.sort(list, function(a, b)
		if a.stocks ~= b.stocks then return a.stocks > b.stocks end
		if a.damage ~= b.damage then return a.damage < b.damage end
		return a.kos > b.kos
	end)
	return list
end

----------------------------------------------------------------------
-- Plateformes mobiles (même formule sur le serveur et les clients)
----------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
RunService.Heartbeat:Connect(function()
	local t = workspace:GetServerTimeNow()
	for _, p in ipairs(CollectionService:GetTagged("SmashMoving")) do
		local base, offset, period = p:GetAttribute("MoveBase"), p:GetAttribute("MoveOffset"), p:GetAttribute("MovePeriod")
		if base and offset and period then
			local w = 2 * math.pi / period
			p.CFrame = CFrame.new(base + offset * math.sin(t * w))
			p.AssemblyLinearVelocity = offset * w * math.cos(t * w)
		end
	end
end)

----------------------------------------------------------------------
-- Pièges (geysers de lave, stalactites)
----------------------------------------------------------------------
local hazardToken = nil

local function envHit(pos, radiusBox, dmg, base, growth, angleDeg, fixedDir)
	for _, f in pairs(fighters) do
		local r = rootOf(f)
		if r and alive(f) and f.inRound and os.clock() >= f.invincibleUntil then
			local d = r.Position - pos
			if math.abs(d.X) <= radiusBox.X / 2 and math.abs(d.Y) <= radiusBox.Y / 2 then
				if f.shielding then
					f.shieldHp -= dmg * 2
				else
					f.damage = math.min(999, f.damage + dmg)
					sync(f)
					local dir = fixedDir or math.sign(d.X)
					if dir == 0 then dir = 1 end
					local a = math.rad(angleDeg)
					local power = (base + f.damage * growth) * f.char.weight
					applyKnockback(f, Vector3.new(math.cos(a) * dir, math.sin(a), 0) * power,
						math.clamp(power * Config.HITSTUN_FACTOR, 0.2, Config.HITSTUN_MAX))
					knockRemote:FireAllClients("DmgNum", r.Position, dmg, power > 70)
				end
			end
		end
	end
end

local function hazardPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in pairs(props) do p[k] = v end
	p.Parent = arena
	return p
end

local function geyser(h)
	local x = O.X + h.x
	local top = O.Y
	-- avertissement : le sol bouillonne
	local warn = hazardPart({ Size = Vector3.new(7, 0.3, 8), Position = Vector3.new(x, top + 0.2, O.Z),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 30), Transparency = 0.4 })
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(255, 160, 40))
	bubbles.LightEmission = 1
	bubbles.Size = NumberSequence.new(0.6)
	bubbles.Lifetime = NumberRange.new(0.3, 0.6)
	bubbles.Speed = NumberRange.new(4, 10)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Rate = 40
	bubbles.Parent = warn
	for _ = 1, 6 do
		warn.Transparency = warn.Transparency == 0.4 and 0.1 or 0.4
		task.wait(0.2)
	end
	warn:Destroy()
	if not combat() then return end
	-- éruption
	local pillar = hazardPart({ Size = Vector3.new(6, 2, 6), Position = Vector3.new(x, top + 1, O.Z),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 90, 20), Transparency = 0.15 })
	TweenService:Create(pillar, TweenInfo.new(0.15), { Size = Vector3.new(6, 34, 6), Position = Vector3.new(x, top + 17, O.Z) }):Play()
	knockRemote:FireAllClients("Shake", 0.6)
	for _ = 1, 4 do
		envHit(Vector3.new(x, top + 17, O.Z), Vector3.new(7, 34, 0), 12, 45, 0.6, 88)
		task.wait(0.15)
	end
	TweenService:Create(pillar, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(2, 34, 2) }):Play()
	Debris:AddItem(pillar, 0.35)
end

local function icicle(h)
	local x = O.X + math.random(h.minX, h.maxX)
	local top = O.Y
	local shadow = hazardPart({ Size = Vector3.new(4, 0.3, 4), Position = Vector3.new(x, top + 0.2, O.Z),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 60, 60), Transparency = 0.5 })
	local ice = hazardPart({ Size = Vector3.new(2.5, 6, 2.5), Position = Vector3.new(x, top + 60, O.Z),
		Material = Enum.Material.Ice, Color = Color3.fromRGB(200, 240, 255) })
	task.wait(1)
	shadow:Destroy()
	if not combat() then ice:Destroy() return end
	TweenService:Create(ice, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = Vector3.new(x, top + 3, O.Z) }):Play()
	task.wait(0.45)
	envHit(Vector3.new(x, top + 4, O.Z), Vector3.new(6, 8, 0), 10, 30, 0.55, 70)
	local shards = Instance.new("ParticleEmitter")
	shards.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	shards.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	shards.Lifetime = NumberRange.new(0.3, 0.6)
	shards.Speed = NumberRange.new(15, 30)
	shards.SpreadAngle = Vector2.new(70, 70)
	shards.EmissionDirection = Enum.NormalId.Top
	shards.Acceleration = Vector3.new(0, -60, 0)
	shards.Rate = 0
	shards.Parent = ice
	shards:Emit(20)
	ice.Transparency = 1
	Debris:AddItem(ice, 0.7)
end

function startHazards()
	local token = {}
	hazardToken = token
	for _, h in ipairs(curMap.hazards or {}) do
		task.spawn(function()
			task.wait((h.offset or 0) + h.interval)
			while hazardToken == token do
				if combat() then
					if h.type == "geyser" then geyser(h) elseif h.type == "icicle" then icicle(h) end
				end
				task.wait(h.interval)
			end
		end)
	end
end

----------------------------------------------------------------------
-- Mode entraînement : sac de frappe, vies infinies, % du sac réglable
----------------------------------------------------------------------
function joinTraining(f)
	setInRound(f, true)
	f.stocks = 99
	f.damage = 0
	f.koing = false
	sync(f)
	placeAt(f, spawnPos(1))
	giveInvincibility(f, 1)
end

local function runTraining()
	state:SetAttribute("Phase", "Training")
	setMsg("ENTRAÎNEMENT")
	task.delay(1.5, function() if state:GetAttribute("Message") == "ENTRAÎNEMENT" then setMsg("") end end)
	clearItems()
	for id, b in pairs(bots) do despawnBot(b) end
	for _, f in pairs(fighters) do
		if f.player and f.training then joinTraining(f) end
	end
	local bag = spawnBot(0, { id = "BAG", name = Config.TRAINING_BAG_NAME, bag = true, think = 1, aggro = 0, smash = 0, special = 0, aim = 1 })
	task.wait(0.5)
	if bag then
		setInRound(bag, true)
		bag.stocks = 99
		sync(bag)
		placeAt(bag, spawnPos(2))
	end
	nextItemAt = os.clock() + Fighters.ITEM_INTERVAL
	while trainingCount() > 0 and humanCount() == 0 do
		for _, f in pairs(fighters) do
			if f.inRound and f.stocks < 50 then
				f.stocks = 99
				sync(f)
			end
		end
		task.wait(0.3)
	end
	-- fin : quelqu'un a lancé une vraie partie -> les joueurs en entraînement la rejoignent
	clearItems()
	if fighters["BAG"] then despawnBot(fighters["BAG"]) end
	for _, f in pairs(fighters) do
		if f.player and f.training then
			setTraining(f, false)
			setInRound(f, false)
		end
	end
end

task.spawn(function()
	while true do
		-- 1) attendre un joueur (ou faire de l'entraînement)
		state:SetAttribute("Phase", "Waiting")
		setMsg("En attente de joueurs...")
		while humanCount() == 0 do
			if trainingCount() > 0 then
				runTraining()
				state:SetAttribute("Phase", "Waiting")
				setMsg("En attente de joueurs...")
			end
			task.wait(0.5)
		end

		-- 2) vote de la map
		votes = {}
		modeVotes = {}
		refreshVotes()
		state:SetAttribute("Phase", "Vote")
		setMsg("")
		for t = Config.VOTE_TIME, 1, -1 do
			state:SetAttribute("TimeLeft", t)
			task.wait(1)
		end
		local idx = pickMap()
		local ffaVotes, teamVotes = state:GetAttribute("VoteFFA") or 0, state:GetAttribute("VoteTeams") or 0
		state:SetAttribute("Mode", teamVotes > ffaVotes and "Teams" or "FFA")
		clearItems()
		loadMap(idx)
		setupBots()
		task.wait(0.3)

		-- 3) compte à rebours
		startRound()
		state:SetAttribute("Phase", "Countdown")
		state:SetAttribute("TimeLeft", Config.ROUND_TIME)
		setMsg(curMap.name .. (teamsMode() and "\nÉQUIPES" or ""))
		task.wait(1.2)
		for i = 3, 1, -1 do setMsg(tostring(i)) task.wait(0.8) end
		releaseAll()
		state:SetAttribute("Phase", "Fight")
		nextItemAt = os.clock() + Fighters.ITEM_INTERVAL
		setMsg("GO !")
		task.delay(1, function() if state:GetAttribute("Message") == "GO !" then setMsg("") end end)

		-- 4) combat
		local endTime = os.clock() + Config.ROUND_TIME
		local timeUp = false
		while true do
			task.wait(0.2)
			if Config.ROUND_TIME > 0 then
				local left = math.max(0, math.ceil(endTime - os.clock()))
				state:SetAttribute("TimeLeft", left)
				if left <= 0 then timeUp = true break end
			end
			local alivers, total, humansLeft = 0, 0, 0
			for _, f in pairs(fighters) do
				if f.inRound then
					total += 1
					if f.stocks > 0 then
						alivers += 1
						if f.player then humansLeft += 1 end
					end
				end
			end
			if teamsMode() then
				local teamsAlive = {}
				for _, f in pairs(fighters) do
					if f.inRound and f.stocks > 0 and f.team then teamsAlive[f.team] = true end
				end
				local n = 0
				for _ in pairs(teamsAlive) do n += 1 end
				if total >= 2 and n <= 1 then task.wait(1.2) break end
			elseif total >= 2 and alivers <= 1 then task.wait(1.2) break end -- laisser finir l'anim de KO
			if humansLeft == 0 then task.wait(1.2) break end -- plus aucun joueur humain en vie
		end

		-- 5) résultats
		state:SetAttribute("Phase", "End")
		clearItems()
		local ranking = results()
		local lines = { timeUp and "TEMPS ÉCOULÉ !" or "FIN DU MATCH !" }
		for i, f in ipairs(ranking) do
			if i > 4 then break end
			table.insert(lines, string.format("%d. %s  (%d vie%s, %d KO)", i, f.name, f.stocks, f.stocks > 1 and "s" or "", f.kos))
		end
		-- vainqueur(s)
		local winners = {}
		local winnerText = "Partie terminée"
		if ranking[1] then
			if teamsMode() and ranking[1].team then
				local wt = ranking[1].team
				for _, f in ipairs(ranking) do
					if f.team == wt then table.insert(winners, f) end
				end
				winnerText = "🏆 ÉQUIPE " .. TEAM_NAMES[wt] .. " GAGNE !"
			else
				winners = { ranking[1] }
				winnerText = "🏆 " .. ranking[1].name .. " GAGNE !"
			end
		end
		local ids = {}
		for _, w in ipairs(winners) do
			table.insert(ids, w.id)
			if w.model then knockRemote:FireAllClients("Pose", w.model, "Victory") end
		end
		setMsg(winnerText)
		state:SetAttribute("Results", table.concat(lines, "\n"))
		state:SetAttribute("Winner", table.concat(ids, ","))

		-- statistiques
		local isWinner = {}
		for _, w in ipairs(winners) do isWinner[w] = true end
		for _, f in pairs(fighters) do
			if f.player and f.inRound and playerStats[f.player] then
				local data = playerStats[f.player]
				data.matches += 1
				data.kos += f.kos
				if isWinner[f] then data.wins += 1 end
				refreshLeaderstats(f.player)
				task.spawn(saveStats, f.player)
			end
		end
		task.delay(3, refreshLeaderboard)

		task.wait(Config.INTERMISSION)
		for _, w in ipairs(winners) do
			if w.model then knockRemote:FireAllClients("Pose", w.model, "ShieldEnd") end
		end
		state:SetAttribute("Winner", "")
		state:SetAttribute("Results", "")
	end
end)
