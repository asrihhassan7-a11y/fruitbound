-- SmashServer (Script dans ServerScriptService)
-- Maps + vote, manches chronométrées, dégâts en %, recul, KO, vies, bots CPU.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("SmashConfig"))
local Maps = require(ReplicatedStorage:WaitForChild("SmashMaps"))
local O = Config.ARENA_ORIGIN

workspace.Gravity = Config.GRAVITY

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
state.Parent = ReplicatedStorage

local function setMsg(m) state:SetAttribute("Message", m) end
local function phase() return state:GetAttribute("Phase") end

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

local function setGroup(model, group)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "SmashShield" then p.CollisionGroup = group end
	end
end

----------------------------------------------------------------------
-- Maps
----------------------------------------------------------------------
local arena, platformsFolder, solidsFolder
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

	Lighting.ClockTime = curMap.theme.clock
	Lighting.Ambient = curMap.theme.ambient
	Lighting.OutdoorAmbient = curMap.theme.ambient
	Lighting.FogColor = curMap.theme.fog
	Lighting.FogStart = 150
	Lighting.FogEnd = 600

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
	}
	local info = Instance.new("Folder")
	info.Name = id
	info:SetAttribute("DisplayName", name)
	info:SetAttribute("Damage", 0)
	info:SetAttribute("Stocks", 0)
	info:SetAttribute("Color", COLORS[((f.slot - 1) % #COLORS) + 1])
	info:SetAttribute("Slot", f.slot)
	info:SetAttribute("IsBot", player == nil)
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
	return f.stocks > 0 and rootOf(f) ~= nil
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

local function placeAt(f, pos, anchored)
	local root = rootOf(f)
	if not root then return end
	root.Anchored = false
	f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(pos.X > O.X and -90 or 90), 0))
	root.AssemblyLinearVelocity = Vector3.zero
	f.stunUntil = 0
	if f.player then
		knockRemote:FireClient(f.player, "Reset")
	else
		local hum = humOf(f)
		if hum then hum.PlatformStand = false end
	end
	if anchored then root.Anchored = true end
end

local function park(f)
	setShield(f, false)
	placeAt(f, PARK_POS + Vector3.new(f.slot * 10, 0, 0), true)
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
	setGroup(model, "Fighters")
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Name ~= "SmashShield" then d.CollisionGroup = "Fighters" end
	end)
	f.shielding = false
	f.shieldPart = nil
	if phase() == "Fight" and f.stocks > 0 then
		placeAt(f, respawnPos())
		giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
	elseif phase() == "Fight" then
		park(f) -- arrivé en cours de manche : spectateur
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
local function applyKnockback(target, vel, hitstun)
	local root = rootOf(target)
	if not root then return end
	target.stunUntil = os.clock() + hitstun
	if target.player then
		knockRemote:FireClient(target.player, "Knock", vel, hitstun)
	else
		local hum = humOf(target)
		if hum then hum.PlatformStand = true end
		root.AssemblyLinearVelocity = vel
	end
end

local function hit(attacker, target, data, facing, mult, fromPos)
	if target == attacker or not alive(target) then return end
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

	target.damage = math.min(999, target.damage + data.dmg * mult)
	sync(target)
	target.lastHitBy = attacker
	target.lastHitTime = os.clock()

	local dir = facing
	if data.bothSides then
		dir = math.sign(troot.Position.X - fromPos.X)
		if dir == 0 then dir = facing end
	end
	local power = (data.base + target.damage * data.growth) * mult
	local a = math.rad(data.angle)
	local vel = Vector3.new(math.cos(a) * dir, math.sin(a), 0) * power
	local hitstun = math.clamp(power * Config.HITSTUN_FACTOR, 0.15, Config.HITSTUN_MAX)
	applyKnockback(target, vel, hitstun)

	local big = power > 70
	flash(troot.CFrame, Vector3.new(3, 3, 3) * (big and 2 or 1), Color3.fromRGB(255, 240, 150), 0.1)
	hitSound(troot, big)
	if big then knockRemote:FireAllClients("Shake", math.clamp(power / 100, 0.3, 1.5)) end
end

local function charactersList(except)
	local list = {}
	for _, f in pairs(fighters) do
		if f ~= except and f.model then table.insert(list, f.model) end
	end
	return list
end

local function hitboxAt(attacker, data, facing, mult)
	local root = rootOf(attacker)
	if not root then return end
	local center = root.Position + Vector3.new(data.offset.X * facing, data.offset.Y, 0)
	local cf = CFrame.new(center)
	flash(cf, data.size, attacker.info:GetAttribute("Color"), 0.1)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = charactersList(attacker)
	local done = {}
	for _, p in ipairs(workspace:GetPartBoundsInBox(cf, data.size, params)) do
		local model = p:FindFirstAncestorOfClass("Model")
		local target = model and fighterByModel[model]
		if target and not done[target] then
			done[target] = true
			hit(attacker, target, data, facing, mult, root.Position)
		end
	end
end

local function fireProjectile(attacker, facing)
	local root = rootOf(attacker)
	if not root then return end
	local data = Config.ATTACKS.Special
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(2.2, 2.2, 2.2)
	ball.Material = Enum.Material.Neon
	ball.Color = attacker.info:GetAttribute("Color")
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

-- Exécute une action (utilisé par les joueurs ET les bots)
local function doAction(f, kind, dir, facing, charge)
	if phase() ~= "Fight" then return end
	local root, hum = rootOf(f), humOf(f)
	if not root or not hum or f.stocks <= 0 then return end
	local now = os.clock()

	if kind == "ShieldOn" then
		if now >= f.stunUntil and f.shieldHp > 10 and hum.FloorMaterial ~= Enum.Material.Air then setShield(f, true) end
		return
	elseif kind == "ShieldOff" then
		setShield(f, false)
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
			f.cooldownUntil = now + Config.ATTACKS.Special.cooldown
			fireProjectile(f, facing)
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

local function refreshVotes()
	for i = 0, #Maps do state:SetAttribute("Vote" .. i, 0) end
	for _, idx in pairs(votes) do
		state:SetAttribute("Vote" .. idx, (state:GetAttribute("Vote" .. idx) or 0) + 1)
	end
end

actionRemote.OnServerEvent:Connect(function(player, kind, dir, facing, charge)
	if kind == "Vote" then
		local idx = tonumber(dir)
		if phase() == "Vote" and idx and idx >= 0 and idx <= #Maps and idx % 1 == 0 then
			votes[player] = idx
			refreshVotes()
		end
		return
	end
	local f = fighters["P" .. player.UserId]
	if f and typeof(kind) == "string" then
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
local function ko(f)
	if f.stocks <= 0 then return end
	local root = rootOf(f)
	if root then
		local b = curMap.blast
		local p = root.Position
		local cp = Vector3.new(math.clamp(p.X, O.X - b.x, O.X + b.x), math.clamp(p.Y, O.Y - b.bottom, O.Y + b.top), O.Z)
		local e = Instance.new("Explosion")
		e.Position = cp
		e.BlastPressure = 0
		e.DestroyJointRadiusPercent = 0
		e.BlastRadius = 12
		e.Parent = workspace
		flash(CFrame.lookAt(cp, O) * CFrame.new(0, 0, -20), Vector3.new(1.5, 1.5, 40), f.info:GetAttribute("Color"), 0.4)
	end
	knockRemote:FireAllClients("Shake", 1.2)
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
	if f.stocks > 0 then
		placeAt(f, respawnPos())
		giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
	else
		park(f)
	end
end

----------------------------------------------------------------------
-- Joueurs
----------------------------------------------------------------------
local function onPlayer(player)
	local f = newFighter("P" .. player.UserId, player.DisplayName, player)
	local function onChar(char)
		task.spawn(function()
			setupCharacter(f, char)
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				-- reset volontaire = perte d'une vie
				if phase() == "Fight" then ko(f) end
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
	local id = "CPU" .. i
	if fighters[id] then return fighters[id] end
	local f = newFighter(id, def.name, nil)
	f.isBot = true
	f.ai = def
	f.airJumps = Config.AIR_JUMPS
	f.recovery = true
	f.nextThink = 0
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		local c = f.info:GetAttribute("Color")
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
		f.airJumps = Config.AIR_JUMPS
		f.recovery = true
	end
	if phase() ~= "Fight" then hum:Move(Vector3.zero) return end

	local vel = root.AssemblyLinearVelocity

	-- récupération : plus de sol en dessous -> revenir vers la scène
	if not groundBelow(pos + Vector3.new(0, 1, 0), 120) then
		local tx = nearestStageX(pos.X)
		local d = math.sign(tx - pos.X)
		hum:Move(Vector3.new(d, 0, 0))
		if vel.Y < 0 and pos.Y < O.Y + 6 then
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
		if o ~= f and alive(o) and not rootOf(o).Anchored then
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
		if math.random() < ai.smash then
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
				if phase() == "Fight" and f.stocks > 0 then ko(f) else placeAt(f, respawnPos()) end
			end
		end
	end
	for _, b in pairs(bots) do botThink(b) end
end)

----------------------------------------------------------------------
-- Manches
----------------------------------------------------------------------
local function humanCount() return #Players:GetPlayers() end

local function setupBots()
	local want = Config.FILL_WITH_BOTS or humanCount() < 2
	for i, def in ipairs(Config.BOTS) do
		local id = "CPU" .. i
		if want and not fighters[id] then
			spawnBot(i, def)
		elseif not want and fighters[id] then
			despawnBot(fighters[id])
		end
	end
end

local function startRound()
	for _, f in pairs(fighters) do
		f.stocks = Config.STOCKS
		f.damage = 0
		f.kos = 0
		f.shieldHp = Config.SHIELD_MAX
		f.lastHitBy = nil
		setShield(f, false)
		sync(f)
		placeAt(f, spawnPos(f.slot))
		giveInvincibility(f, 1)
	end
end

local function results()
	local list = {}
	for _, f in pairs(fighters) do table.insert(list, f) end
	table.sort(list, function(a, b)
		if a.stocks ~= b.stocks then return a.stocks > b.stocks end
		if a.damage ~= b.damage then return a.damage < b.damage end
		return a.kos > b.kos
	end)
	return list
end

task.spawn(function()
	while true do
		-- 1) attendre un joueur
		state:SetAttribute("Phase", "Waiting")
		setMsg("En attente de joueurs...")
		while humanCount() == 0 do task.wait(1) end

		-- 2) vote de la map
		votes = {}
		refreshVotes()
		state:SetAttribute("Phase", "Vote")
		setMsg("")
		for t = Config.VOTE_TIME, 1, -1 do
			state:SetAttribute("TimeLeft", t)
			task.wait(1)
		end
		local idx = pickMap()
		loadMap(idx)
		setupBots()
		task.wait(0.3)

		-- 3) compte à rebours
		startRound()
		state:SetAttribute("Phase", "Countdown")
		state:SetAttribute("TimeLeft", Config.ROUND_TIME)
		setMsg(curMap.name)
		task.wait(1.2)
		for i = 3, 1, -1 do setMsg(tostring(i)) task.wait(0.8) end
		state:SetAttribute("Phase", "Fight")
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
			local alivers, total = 0, 0
			for _, f in pairs(fighters) do
				total += 1
				if f.stocks > 0 then alivers += 1 end
			end
			if total >= 2 and alivers <= 1 then break end
			if humanCount() == 0 then break end
		end

		-- 5) résultats
		state:SetAttribute("Phase", "End")
		local ranking = results()
		local lines = { timeUp and "TEMPS ÉCOULÉ !" or "FIN DU MATCH !" }
		for i, f in ipairs(ranking) do
			if i > 4 then break end
			table.insert(lines, string.format("%d. %s  (%d vie%s, %d KO)", i, f.name, f.stocks, f.stocks > 1 and "s" or "", f.kos))
		end
		state:SetAttribute("Results", table.concat(lines, "\n"))
		setMsg(ranking[1] and ("🏆 " .. ranking[1].name .. " GAGNE !") or "Partie terminée")
		task.wait(Config.INTERMISSION)
		state:SetAttribute("Results", "")
	end
end)
