-- SmashServer (Script dans ServerScriptService)
-- Arène, dégâts en %, recul, zones de KO, vies, bots CPU, déroulement des manches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("SmashConfig"))
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
local knockRemote = Instance.new("RemoteEvent") -- serveur -> client : recul / respawn / tremblement
knockRemote.Name = "Knock"
knockRemote.Parent = remotes
remotes.Parent = ReplicatedStorage

local state = Instance.new("Folder")
state.Name = "SmashState"
state:SetAttribute("Phase", "Waiting")
state:SetAttribute("Message", "")
state.Parent = ReplicatedStorage

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
		if p:IsA("BasePart") then p.CollisionGroup = group end
	end
end

----------------------------------------------------------------------
-- Arène
----------------------------------------------------------------------
local arena = Instance.new("Model")
arena.Name = "SmashArena"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = arena
	return p
end

local stageTop = O.Y + Config.STAGE_SIZE.Y / 2
part({ Name = "MainStage", Size = Config.STAGE_SIZE, Position = O, Color = Color3.fromRGB(70, 75, 95), Material = Enum.Material.Slate })
part({ Name = "StageTrim", Size = Vector3.new(Config.STAGE_SIZE.X + 0.4, 0.6, Config.STAGE_SIZE.Z + 0.4),
	Position = Vector3.new(O.X, stageTop - 0.2, O.Z), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon })
part({ Name = "Underside", Size = Vector3.new(40, 10, 12), Position = O - Vector3.new(0, 8, 0), Color = Color3.fromRGB(50, 50, 65), Material = Enum.Material.Slate })

local platformsFolder = Instance.new("Folder")
platformsFolder.Name = "Platforms"
platformsFolder.Parent = arena
local function platform(x, y, w)
	local p = part({ Name = "Platform", Size = Vector3.new(w, 1, 10), Position = Vector3.new(O.X + x, stageTop + y, O.Z),
		Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.SmoothPlastic, CollisionGroup = "Platforms" })
	p.Parent = platformsFolder
	return p
end
platform(-17, 12, 16)
platform(17, 12, 16)
platform(0, 23, 14)

-- Décor de fond (mur loin derrière, pour la vue de côté)
part({ Name = "Backdrop", Size = Vector3.new(400, 220, 2), Position = O + Vector3.new(0, 30, -70),
	Color = Color3.fromRGB(25, 30, 55), Material = Enum.Material.SmoothPlastic, CanCollide = false })

arena.Parent = workspace

local SPAWN_POINTS = {
	Vector3.new(-20, 4, 0), Vector3.new(20, 4, 0), Vector3.new(-8, 4, 0), Vector3.new(8, 4, 0),
	Vector3.new(-26, 4, 0), Vector3.new(26, 4, 0), Vector3.new(0, 30, 0), Vector3.new(0, 4, 0),
}
local function spawnPos(i)
	local p = SPAWN_POINTS[((i - 1) % #SPAWN_POINTS) + 1]
	return Vector3.new(O.X + p.X, stageTop + p.Y, O.Z)
end
local RESPAWN_POS = Vector3.new(O.X, stageTop + 30, O.Z)

----------------------------------------------------------------------
-- Combattants
----------------------------------------------------------------------
local fighters = {}          -- id -> fighter
local fighterByModel = {}    -- model -> fighter
local nextSlot = 0
local COLORS = {
	Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 150, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(220, 110, 255), Color3.fromRGB(255, 150, 60), Color3.fromRGB(80, 230, 230), Color3.fromRGB(240, 240, 240),
}

local function newFighter(id, name, player)
	nextSlot += 1
	local f = {
		id = id, name = name, player = player, slot = nextSlot,
		damage = 0, stocks = Config.STOCKS, model = nil,
		cooldownUntil = 0, stunUntil = 0, invincibleUntil = 0,
		shielding = false, shieldHp = Config.SHIELD_MAX, shieldPart = nil,
	}
	local info = Instance.new("Folder")
	info.Name = id
	info:SetAttribute("DisplayName", name)
	info:SetAttribute("Damage", 0)
	info:SetAttribute("Stocks", f.stocks)
	info:SetAttribute("Color", COLORS[((f.slot - 1) % #COLORS) + 1])
	info:SetAttribute("Slot", f.slot)
	local charRef = Instance.new("ObjectValue")
	charRef.Name = "Character"
	charRef.Parent = info
	info.Parent = state
	f.info = info
	f.charRef = charRef
	fighters[id] = f
	return f
end

local function sync(f)
	f.info:SetAttribute("Damage", math.floor(f.damage))
	f.info:SetAttribute("Stocks", f.stocks)
end

local function rootOf(f)
	return f.model and f.model:FindFirstChild("HumanoidRootPart")
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
		s.Shape = Enum.PartType.Ball
		s.Size = Vector3.new(7, 7, 7)
		s.Material = Enum.Material.ForceField
		s.Color = f.info:GetAttribute("Color")
		s.CanCollide = false
		s.CanQuery = false
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
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = f.model
		Debris:AddItem(ff, t)
	end
end

local function placeAt(f, pos)
	local root = rootOf(f)
	if not root then return end
	f.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(pos.X > O.X and -90 or 90), 0))
	root.AssemblyLinearVelocity = Vector3.zero
	if f.player then
		knockRemote:FireClient(f.player, "Reset")
	else
		local hum = humOf(f)
		if hum then hum.PlatformStand = false end
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
	setGroup(model, "Fighters")
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d ~= f.shieldPart then d.CollisionGroup = "Fighters" end
	end)
	f.shielding = false
	f.shieldPart = nil
	placeAt(f, spawnPos(f.slot))
	giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
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
	if state:GetAttribute("Phase") ~= "Fight" then return end
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
		f.cooldownUntil = now + Config.ATTACKS.Special.cooldown
		fireProjectile(f, facing)
		return
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

actionRemote.OnServerEvent:Connect(function(player, kind, dir, facing, charge)
	local f = fighters["P" .. player.UserId]
	if f and typeof(kind) == "string" then
		doAction(f, kind, dir, facing, charge)
	end
end)

----------------------------------------------------------------------
-- KO
----------------------------------------------------------------------
local function ko(f)
	if f.stocks <= 0 then return end
	local root = rootOf(f)
	if root then
		local p = root.Position
		local cp = Vector3.new(math.clamp(p.X, O.X - Config.BLAST_X, O.X + Config.BLAST_X),
			math.clamp(p.Y, O.Y - Config.BLAST_BOTTOM, O.Y + Config.BLAST_TOP), O.Z)
		local e = Instance.new("Explosion")
		e.Position = cp
		e.BlastPressure = 0
		e.DestroyJointRadiusPercent = 0
		e.BlastRadius = 12
		e.Parent = workspace
		flash(CFrame.lookAt(cp, Vector3.new(O.X, O.Y, O.Z)) * CFrame.new(0, 0, -20), Vector3.new(1.5, 1.5, 40), f.info:GetAttribute("Color"), 0.4)
	end
	knockRemote:FireAllClients("Shake", 1.2)
	f.stocks -= 1
	f.damage = 0
	f.shieldHp = Config.SHIELD_MAX
	setShield(f, false)
	sync(f)
	if f.stocks > 0 then
		placeAt(f, RESPAWN_POS)
		giveInvincibility(f, Config.RESPAWN_INVINCIBILITY)
	else
		-- éliminé : on le met hors de vue
		placeAt(f, Vector3.new(O.X, O.Y + 300, O.Z + 200))
		if root then root.Anchored = true end
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
			if state:GetAttribute("Phase") == "Fight" and f.stocks <= 0 then
				local r = rootOf(f)
				placeAt(f, Vector3.new(O.X, O.Y + 300, O.Z + 200))
				if r then r.Anchored = true end
			end
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				-- reset volontaire = perte d'une vie
				if state:GetAttribute("Phase") == "Fight" then ko(f) end
			end)
		end)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then onChar(player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
Players.PlayerRemoving:Connect(function(player)
	local f = fighters["P" .. player.UserId]
	if f then
		fighters[f.id] = nil
		if f.model then fighterByModel[f.model] = nil end
		f.info:Destroy()
	end
end)

----------------------------------------------------------------------
-- Bots CPU
----------------------------------------------------------------------
local bots = {}

local function playAnims(f)
	local hum = humOf(f)
	local animate = f.model:FindFirstChild("Animate")
	if not hum or not animate then return end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
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

local function spawnBot(i)
	local id = "CPU" .. i
	local f = fighters[id] or newFighter(id, "CPU " .. i, nil)
	f.isBot = true
	f.airJumps = Config.AIR_JUMPS
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
		return
	end
	model.Name = f.name
	model.Parent = workspace
	model.HumanoidRootPart:SetNetworkOwner(nil)
	setupCharacter(f, model)
	playAnims(f)
	bots[id] = f
end

local function botThink(f, dt)
	local root, hum = rootOf(f), humOf(f)
	if not root or not hum or f.stocks <= 0 then return end
	if f.animStep then f.animStep() end
	local now = os.clock()
	local pos = root.Position

	-- garder sur le plan 2D
	if math.abs(pos.Z - O.Z) > 0.05 then
		root.CFrame += Vector3.new(0, 0, O.Z - pos.Z)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0)
	end

	-- traverser les plateformes par en dessous
	local underPlatform = false
	for _, p in ipairs(platformsFolder:GetChildren()) do
		if math.abs(pos.X - p.Position.X) < p.Size.X / 2 + 2 and pos.Y - 2.5 < p.Position.Y + 0.5 and pos.Y > p.Position.Y - 12 then
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
	if hum.FloorMaterial ~= Enum.Material.Air then f.airJumps = Config.AIR_JUMPS end
	if state:GetAttribute("Phase") ~= "Fight" then hum:Move(Vector3.zero) return end

	-- récupération : revenir vers la scène
	local edge = Config.STAGE_SIZE.X / 2
	local offStage = math.abs(pos.X - O.X) > edge - 1 or pos.Y < stageTop - 1
	if offStage then
		local d = math.sign(O.X - pos.X)
		hum:Move(Vector3.new(d, 0, 0))
		local vy = root.AssemblyLinearVelocity.Y
		if vy < 0 and pos.Y < stageTop + 4 then
			if f.airJumps > 0 then
				f.airJumps -= 1
				root.AssemblyLinearVelocity = Vector3.new(d * Config.WALK_SPEED, Config.AIR_JUMP_VELOCITY * 1.1, 0)
			elseif pos.Y < stageTop - 4 and math.abs(pos.X - O.X) < edge + 8 then
				-- petit coup de pouce de récup
				root.AssemblyLinearVelocity = Vector3.new(d * 30, 70, 0)
				f.airJumps = -1
			end
		end
		return
	end

	-- trouver la cible la plus proche
	local target, best = nil, math.huge
	for _, o in pairs(fighters) do
		if o ~= f and alive(o) then
			local r = rootOf(o)
			local d = (r.Position - pos).Magnitude
			if d < best then best, target = d, o end
		end
	end
	if not target then hum:Move(Vector3.zero) return end
	local tp = rootOf(target).Position
	local dx, dy = tp.X - pos.X, tp.Y - pos.Y
	local facing = dx >= 0 and 1 or -1

	if now < f.nextThink then return end
	f.nextThink = now + 0.12

	if math.abs(dx) > 4 then
		hum:Move(Vector3.new(facing, 0, 0))
	else
		hum:Move(Vector3.zero)
		root.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(facing > 0 and -90 or 90), 0) -- se tourner vers la cible
	end

	if dy > 6 and math.random() < 0.3 then
		if hum.FloorMaterial ~= Enum.Material.Air then hum.Jump = true
		elseif f.airJumps > 0 and root.AssemblyLinearVelocity.Y < 5 then
			f.airJumps -= 1
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Config.AIR_JUMP_VELOCITY, 0)
		end
	end

	if target.shielding and math.random() < 0.3 then return end
	if math.abs(dx) < 6 and math.abs(dy) < 4 then
		if math.random() < 0.25 then doAction(f, "Smash", "Side", facing, math.random() * 0.6)
		else doAction(f, "Attack", "Side", facing) end
	elseif math.abs(dx) < 4 and dy > 3 and dy < 9 then
		doAction(f, math.random() < 0.4 and "Smash" or "Attack", "Up", facing, 0.3)
	elseif math.abs(dx) < 3 and dy < -3 and hum.FloorMaterial == Enum.Material.Air then
		doAction(f, "Attack", "Down", facing)
	elseif math.abs(dx) > 14 and math.abs(dy) < 3 and math.random() < 0.15 then
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
		f.info:SetAttribute("Shield", f.shieldHp / Config.SHIELD_MAX)

		-- zones de KO
		if root and f.stocks > 0 and not root.Anchored and state:GetAttribute("Phase") == "Fight" then
			local p = root.Position
			if math.abs(p.X - O.X) > Config.BLAST_X or p.Y > O.Y + Config.BLAST_TOP or p.Y < O.Y - Config.BLAST_BOTTOM then
				ko(f)
			end
		elseif root and state:GetAttribute("Phase") ~= "Fight" and root.Position.Y < O.Y - Config.BLAST_BOTTOM then
			placeAt(f, RESPAWN_POS)
		end
	end
	for _, b in pairs(bots) do botThink(b, dt) end
end)

----------------------------------------------------------------------
-- Manches
----------------------------------------------------------------------
local function setMsg(m) state:SetAttribute("Message", m) end

local function resetAll()
	for _, f in pairs(fighters) do
		f.stocks = Config.STOCKS
		f.damage = 0
		f.shieldHp = Config.SHIELD_MAX
		f.stunUntil = 0
		setShield(f, false)
		sync(f)
		local r = rootOf(f)
		if r then r.Anchored = false end
		placeAt(f, spawnPos(f.slot))
		giveInvincibility(f, 1)
	end
end

task.spawn(function()
	for i = 1, Config.CPU_BOTS do spawnBot(i) end
	while true do
		state:SetAttribute("Phase", "Waiting")
		setMsg("En attente de joueurs...")
		while #Players:GetPlayers() == 0 do task.wait(1) end

		resetAll()
		state:SetAttribute("Phase", "Countdown")
		for i = 3, 1, -1 do setMsg(tostring(i)) task.wait(1) end
		state:SetAttribute("Phase", "Fight")
		setMsg("GO !")
		task.delay(1, function() if state:GetAttribute("Message") == "GO !" then setMsg("") end end)

		local winner
		while true do
			task.wait(0.25)
			local alivers, total = {}, 0
			for _, f in pairs(fighters) do
				total += 1
				if f.stocks > 0 then table.insert(alivers, f) end
			end
			if total >= 2 and #alivers <= 1 then winner = alivers[1] break end
			if #Players:GetPlayers() == 0 then break end
		end

		state:SetAttribute("Phase", "End")
		setMsg(winner and ("🏆 " .. winner.name .. " GAGNE !") or "Partie terminée")
		task.wait(5)
	end
end)
