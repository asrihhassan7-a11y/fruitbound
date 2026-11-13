-- Script "AuraCombatServer" -> ServerScriptService
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Config = require(RS:WaitForChild("AuraConfig"))

local remote = Instance.new("RemoteEvent")
remote.Name = "AuraRemote"
remote.Parent = RS

local AurasByName = {}
for _, a in ipairs(Config.Auras) do AurasByName[a.Name] = a end

-- ===== Arène flottante =====
local arena = Instance.new("Part")
arena.Name = "Arena"
arena.Shape = Enum.PartType.Cylinder
arena.Size = Vector3.new(4, 120, 120)
arena.CFrame = CFrame.new(0, 50, 0) * CFrame.Angles(0, 0, math.rad(90))
arena.Anchored = true
arena.Material = Enum.Material.Grass
arena.Color = Color3.fromRGB(80, 170, 80)
arena.Parent = workspace
-- Lobby (zone sûre) au-dessus
local lobby = Instance.new("Part")
lobby.Name = "Lobby"
lobby.Size = Vector3.new(40, 2, 40)
lobby.Position = Vector3.new(0, 120, 0)
lobby.Anchored = true
lobby.Material = Enum.Material.SmoothPlastic
lobby.Color = Color3.fromRGB(60, 60, 80)
lobby.Parent = workspace
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Size = Vector3.new(8, 1, 8)
spawnLoc.Position = Vector3.new(0, 121.5, 0)
spawnLoc.Anchored = true
spawnLoc.Neutral = true
spawnLoc.Duration = 0
spawnLoc.Parent = workspace
-- Portail : toucher pour sauter dans l'arène
local portal = Instance.new("Part")
portal.Name = "Portal"
portal.Size = Vector3.new(8, 10, 1)
portal.Position = Vector3.new(0, 126, -18)
portal.Anchored, portal.CanCollide = true, false
portal.Material = Enum.Material.Neon
portal.Color = Color3.fromRGB(150, 80, 255)
portal.Transparency = 0.3
portal.Parent = workspace

-- ===== État joueurs =====
local state = {} -- [plr] = {aura, nextHit, nextAbility, inArena, lastHitter, lastHitTime, powerMult}

local function root(char) return char and char:FindFirstChild("HumanoidRootPart") end
local function aliveHum(char)
	local h = char and char:FindFirstChildOfClass("Humanoid")
	return h and h.Health > 0 and h or nil
end

local function applyAuraFx(plr)
	local s, char = state[plr], plr.Character
	local r = root(char); if not (s and r) then return end
	local a = AurasByName[s.aura]
	local pe = r:FindFirstChild("AuraFx") or Instance.new("ParticleEmitter")
	pe.Name = "AuraFx"
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(2, 5)
	pe.Acceleration = Vector3.new(0, 10, 0)
	pe.LightEmission = 1
	pe.Rate = 35
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(a.Color)
	pe.Parent = r
	local hl = char:FindFirstChild("AuraHighlight") or Instance.new("Highlight")
	hl.Name = "AuraHighlight"
	hl.FillTransparency = 0.85
	hl.FillColor = a.Color
	hl.OutlineColor = a.Color
	hl.Parent = char
end

-- Ragdoll simple + éjection
local function fling(victimChar, velocity)
	local hum, r = aliveHum(victimChar), root(victimChar)
	if not (hum and r) then return end
	hum.PlatformStand = true
	r.AssemblyLinearVelocity = velocity
	r.AssemblyAngularVelocity = Vector3.new(math.random(-10, 10), math.random(-10, 10), math.random(-10, 10))
	task.delay(Config.RagdollTime, function()
		if hum.Parent then hum.PlatformStand = false end
	end)
end

local function tagHit(attacker, victimPlr)
	if victimPlr and state[victimPlr] then
		state[victimPlr].lastHitter = attacker
		state[victimPlr].lastHitTime = os.clock()
	end
end

local function nearestTarget(plr, maxDist, needFront)
	local myRoot = root(plr.Character); if not myRoot then return end
	local best, bestD
	for _, other in ipairs(Players:GetPlayers()) do
		local os_ = state[other]
		local r = root(other.Character)
		if other ~= plr and os_ and os_.inArena and r and aliveHum(other.Character) then
			local off = r.Position - myRoot.Position
			local d = off.Magnitude
			if d <= maxDist and (not needFront or off.Unit:Dot(myRoot.CFrame.LookVector) > 0.2) and (not bestD or d < bestD) then
				best, bestD = other, d
			end
		end
	end
	return best
end

local Abilities = {}
function Abilities.Dash(plr, a)
	local r = root(plr.Character)
	r.AssemblyLinearVelocity = r.CFrame.LookVector * 110 + Vector3.new(0, 15, 0)
end
function Abilities.Freeze(plr, a)
	local r = root(plr.Character)
	for _, other in ipairs(Players:GetPlayers()) do
		local orr = root(other.Character)
		if other ~= plr and orr and state[other].inArena and (orr.Position - r.Position).Magnitude < 18 then
			orr.Anchored = true
			task.delay(2, function() if orr.Parent then orr.Anchored = false end end)
			tagHit(plr, other)
		end
	end
end
function Abilities.Speed(plr, a)
	local hum = aliveHum(plr.Character)
	hum.WalkSpeed = 32
	task.delay(4, function() if hum.Parent then hum.WalkSpeed = 16 end end)
end
function Abilities.Gust(plr, a)
	local r = root(plr.Character)
	for _, other in ipairs(Players:GetPlayers()) do
		local orr = root(other.Character)
		if other ~= plr and orr and state[other].inArena then
			local off = orr.Position - r.Position
			if off.Magnitude < 20 then
				local flat = Vector3.new(off.X, 0, off.Z)
				if flat.Magnitude < 0.1 then flat = Vector3.new(1, 0, 0) end
				fling(other.Character, flat.Unit * 70 + Vector3.new(0, 40, 0))
				tagHit(plr, other)
			end
		end
	end
end
function Abilities.Teleport(plr, a)
	local target = nearestTarget(plr, 60, false)
	if not target then return false end
	local tr = root(target.Character)
	root(plr.Character).CFrame = tr.CFrame * CFrame.new(0, 0, 4)
end

Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
	local kills = Instance.new("IntValue"); kills.Name = "Éjections"; kills.Parent = ls
	state[plr] = { aura = "Normale", nextHit = 0, nextAbility = 0, inArena = false }
	plr:SetAttribute("Aura", "Normale")
	plr.CharacterAdded:Connect(function(char)
		local s = state[plr]
		s.inArena, s.lastHitter = false, nil
		plr:SetAttribute("InArena", false)
		char:WaitForChild("HumanoidRootPart")
		applyAuraFx(plr)
		char:WaitForChild("Humanoid").Died:Connect(function()
			local killer = s.lastHitter
			if killer and killer.Parent and os.clock() - (s.lastHitTime or 0) < 10 then
				killer.leaderstats["Éjections"].Value += 1
				remote:FireAllClients("Feed", killer.Name, plr.Name, s.aura)
			end
		end)
	end)
end)
Players.PlayerRemoving:Connect(function(plr) state[plr] = nil end)

portal.Touched:Connect(function(hit)
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	local s = plr and state[plr]
	if s and not s.inArena then
		s.inArena = true
		plr:SetAttribute("InArena", true)
		local ang = math.random() * math.pi * 2
		root(plr.Character).CFrame = CFrame.new(math.cos(ang) * 30, 56, math.sin(ang) * 30)
	end
end)

remote.OnServerEvent:Connect(function(plr, action, data)
	local s = state[plr]; if not s then return end
	local char = plr.Character
	if not aliveHum(char) then return end
	local a = AurasByName[s.aura]

	if action == "Equip" then
		if not s.inArena and type(data) == "string" and AurasByName[data] then
			s.aura = data
			plr:SetAttribute("Aura", data)
			applyAuraFx(plr)
		end

	elseif action == "Hit" then
		if not s.inArena or os.clock() < s.nextHit then return end
		s.nextHit = os.clock() + a.Cooldown
		remote:FireAllClients("Swing", char, a.Color)
		local target = nearestTarget(plr, Config.HitRange, true)
		if target then
			local myR, tr = root(char), root(target.Character)
			local dir = Vector3.new(tr.Position.X - myR.Position.X, 0, tr.Position.Z - myR.Position.Z).Unit
			fling(target.Character, dir * a.Power + Vector3.new(0, a.Power * 0.5, 0))
			tagHit(plr, target)
			remote:FireAllClients("Impact", tr.Position, a.Color)
		end

	elseif action == "Ability" then
		if not s.inArena or a.Ability == "None" or os.clock() < s.nextAbility then return end
		local fn = Abilities[a.Ability]
		if fn and fn(plr, a) ~= false then
			s.nextAbility = os.clock() + a.AbilityCd
			remote:FireClient(plr, "AbilityCd", a.AbilityCd)
			remote:FireAllClients("Impact", root(char).Position, a.Color)
		end
	end
end)

-- Chute dans le vide = éliminé
RunService.Heartbeat:Connect(function()
	for plr in pairs(state) do
		local r, h = root(plr.Character), aliveHum(plr.Character)
		if r and h and r.Position.Y < Config.VoidY then h.Health = 0 end
	end
end)
