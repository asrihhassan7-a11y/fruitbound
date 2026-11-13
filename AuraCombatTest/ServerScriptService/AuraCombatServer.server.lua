-- Script "AuraCombatServer" -> ServerScriptService
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Config = require(RS:WaitForChild("AuraConfig"))

local remote = Instance.new("RemoteEvent")
remote.Name = "AuraRemote"
remote.Parent = RS

local state = {} -- [player] = {charging, cooldowns}

local function getTier(aura)
	local t = Config.Tiers[1]
	for _, tier in ipairs(Config.Tiers) do
		if aura >= tier.Min then t = tier end
	end
	return t
end

local function getAura(plr) return plr:GetAttribute("Aura") or 0 end
local function setAura(plr, v) plr:SetAttribute("Aura", math.clamp(v, 0, Config.MaxAura)) end

local function onCooldown(plr, name, cd)
	local s = state[plr]; if not s then return true end
	local now = os.clock()
	if (s.cd[name] or 0) > now then return true end
	s.cd[name] = now + cd
	return false
end

local function getRoot(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then return hum, root end
end

local function damage(attacker, targetModel, amount)
	local hum = targetModel:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or targetModel == attacker.Character then return end
	local mult = getTier(getAura(attacker)).Mult
	hum:TakeDamage(amount * mult)
	remote:FireAllClients("Hit", targetModel, amount * mult)
end

-- Aura visuelle (ParticleEmitter + Highlight) sur le perso
local function buildAuraFx(char)
	local root = char:WaitForChild("HumanoidRootPart")
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "AuraFx"
	pe.Texture = "rbxasset://textures/particles/fire_main.dds"
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, 12, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	pe.LightEmission = 1
	pe.Rate = 0
	pe.Parent = root
	local hl = Instance.new("Highlight")
	hl.Name = "AuraHighlight"
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.Parent = char
end

Players.PlayerAdded:Connect(function(plr)
	state[plr] = { charging = false, cd = {} }
	setAura(plr, 0)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.MaxHealth = Config.MaxHealth
		hum.Health = Config.MaxHealth
		setAura(plr, 0)
		buildAuraFx(char)
	end)
end)
Players.PlayerRemoving:Connect(function(plr) state[plr] = nil end)

remote.OnServerEvent:Connect(function(plr, action, data)
	local s = state[plr]; if not s then return end
	local char = plr.Character
	local hum, root = getRoot(char)
	if not hum then return end

	if action == "Charge" then
		s.charging = data == true
		hum.WalkSpeed = s.charging and 4 or 16

	elseif action == "Punch" then
		local c = Config.Punch
		if onCooldown(plr, "Punch", c.Cooldown) then return end
		local origin = root.Position
		local look = root.CFrame.LookVector
		for _, model in ipairs(workspace:GetChildren()) do
			local h, r = getRoot(model)
			if h and model ~= char then
				local offset = r.Position - origin
				if offset.Magnitude <= c.Range and offset.Unit:Dot(look) > 0.3 then
					damage(plr, model, c.Damage)
					setAura(plr, getAura(plr) + c.AuraGain)
				end
			end
		end
		remote:FireAllClients("PunchFx", char)

	elseif action == "Blast" then
		local c = Config.Blast
		if typeof(data) ~= "Vector3" or getAura(plr) < c.Cost then return end
		if onCooldown(plr, "Blast", c.Cooldown) then return end
		setAura(plr, getAura(plr) - c.Cost)
		local dir = (data - root.Position)
		if dir.Magnitude < 0.1 then dir = root.CFrame.LookVector end
		dir = dir.Unit
		local color = getTier(getAura(plr) + c.Cost).Color

		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.one * c.Radius
		ball.Material = Enum.Material.Neon
		ball.Color = color
		ball.CanCollide, ball.Anchored, ball.CastShadow = false, true, false
		ball.CFrame = CFrame.new(root.Position + dir * 4)
		ball.Parent = workspace
		Debris:AddItem(ball, c.Lifetime)

		local params = OverlapParams.new()
		params.FilterDescendantsInstances = { char, ball }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local t, conn = 0, nil
		conn = RunService.Heartbeat:Connect(function(dt)
			t += dt
			if t > c.Lifetime or not ball.Parent then conn:Disconnect(); return end
			ball.CFrame += dir * c.Speed * dt
			for _, part in ipairs(workspace:GetPartsInPart(ball, params)) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model:FindFirstChildOfClass("Humanoid") then
					damage(plr, model, c.Damage)
					conn:Disconnect(); ball:Destroy(); return
				elseif part.Anchored and part.CanCollide then
					conn:Disconnect(); ball:Destroy(); return
				end
			end
		end)

	elseif action == "Burst" then
		local c = Config.Burst
		if getAura(plr) < c.Cost then return end
		if onCooldown(plr, "Burst", c.Cooldown) then return end
		local color = getTier(getAura(plr)).Color
		setAura(plr, getAura(plr) - c.Cost)
		for _, model in ipairs(workspace:GetChildren()) do
			local h, r = getRoot(model)
			if h and model ~= char and (r.Position - root.Position).Magnitude <= c.Radius then
				damage(plr, model, c.Damage)
				local push = (r.Position - root.Position)
				push = Vector3.new(push.X, 0, push.Z).Unit * c.Knockback + Vector3.new(0, 35, 0)
				r.AssemblyLinearVelocity = push
			end
		end
		remote:FireAllClients("BurstFx", root.Position, color, c.Radius)
	end
end)

-- Boucle : charge / regen + mise à jour des FX d'aura
RunService.Heartbeat:Connect(function(dt)
	for plr, s in pairs(state) do
		local char = plr.Character
		if char then
			local rate = s.charging and Config.ChargeRate or Config.RegenRate
			setAura(plr, getAura(plr) + rate * dt)
			local aura = getAura(plr)
			local tier = getTier(aura)
			local root = char:FindFirstChild("HumanoidRootPart")
			local pe = root and root:FindFirstChild("AuraFx")
			local hl = char:FindFirstChild("AuraHighlight")
			if pe then
				pe.Color = ColorSequence.new(tier.Color)
				pe.Rate = s.charging and 120 or (aura / Config.MaxAura) * 40
			end
			if hl then
				hl.OutlineColor = tier.Color
				hl.OutlineTransparency = 1 - (aura / Config.MaxAura) * 0.9
			end
		end
	end
end)

-- Mannequin d'entraînement pour tester
local function spawnDummy(pos)
	local dummy = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	dummy.Name = "AuraDummy"
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	hum.MaxHealth, hum.Health = 200, 200
	dummy:PivotTo(CFrame.new(pos))
	dummy.Parent = workspace
	hum.Died:Connect(function()
		task.wait(3)
		dummy:Destroy()
		spawnDummy(pos)
	end)
end
for i = 1, 3 do spawnDummy(Vector3.new(i * 10, 5, 20)) end
