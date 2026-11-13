-- AuraServer : à mettre dans ServerScriptService (Script normal)
-- Touche E = activer son aura : explosion autour du joueur qui éjecte les joueurs proches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- ===== Liste des auras (ajoute-en autant que tu veux) =====
local AURAS = {
	Feu    = { couleur = Color3.fromRGB(255, 90, 20),  rayon = 14, force = 90,  degats = 10, cooldown = 2 },
	Glace  = { couleur = Color3.fromRGB(120, 220, 255), rayon = 18, force = 60,  degats = 5,  cooldown = 2, gel = 2 },
	Foudre = { couleur = Color3.fromRGB(255, 255, 80), rayon = 12, force = 140, degats = 15, cooldown = 3 },
}
local AURA_PAR_DEFAUT = "Feu"
-- ===========================================================

local remote = Instance.new("RemoteEvent")
remote.Name = "AuraActivate"
remote.Parent = ReplicatedStorage

local dernierUsage = {}

local function ajouterAuraVisuelle(character, aura)
	local root = character:WaitForChild("HumanoidRootPart")
	local old = root:FindFirstChild("AuraParticles")
	if old then old:Destroy() end
	local p = Instance.new("ParticleEmitter")
	p.Name = "AuraParticles"
	p.Color = ColorSequence.new(aura.couleur)
	p.LightEmission = 1
	p.Size = NumberSequence.new(1.2, 0)
	p.Transparency = NumberSequence.new(0.3, 1)
	p.Lifetime = NumberRange.new(0.6, 1)
	p.Rate = 40
	p.Speed = NumberRange.new(2, 4)
	p.SpreadAngle = Vector2.new(360, 360)
	p.Parent = root
	local light = Instance.new("PointLight")
	light.Name = "AuraLight"
	light.Color = aura.couleur
	light.Range = 10
	light.Parent = p
end

local function auraDuJoueur(player)
	return AURAS[player:GetAttribute("Aura")] or AURAS[AURA_PAR_DEFAUT]
end

Players.PlayerAdded:Connect(function(player)
	if not player:GetAttribute("Aura") then
		player:SetAttribute("Aura", AURA_PAR_DEFAUT)
	end
	player.CharacterAdded:Connect(function(char)
		ajouterAuraVisuelle(char, auraDuJoueur(player))
	end)
	player:GetAttributeChangedSignal("Aura"):Connect(function()
		if player.Character then ajouterAuraVisuelle(player.Character, auraDuJoueur(player)) end
	end)
end)

remote.OnServerEvent:Connect(function(player)
	local aura = auraDuJoueur(player)
	local now = os.clock()
	if dernierUsage[player] and now - dernierUsage[player] < aura.cooldown then return end
	dernierUsage[player] = now

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	-- Effet visuel : sphère qui grossit
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored, sphere.CanCollide, sphere.CanQuery = true, false, false
	sphere.Material = Enum.Material.Neon
	sphere.Color = aura.couleur
	sphere.Transparency = 0.5
	sphere.Size = Vector3.new(2, 2, 2)
	sphere.CFrame = root.CFrame
	sphere.Parent = workspace
	game:GetService("TweenService"):Create(sphere, TweenInfo.new(0.35),
		{ Size = Vector3.one * aura.rayon * 2, Transparency = 1 }):Play()
	Debris:AddItem(sphere, 0.4)

	-- Éjecter les joueurs dans le rayon
	for _, other in ipairs(Players:GetPlayers()) do
		local oc = other ~= player and other.Character
		local oroot = oc and oc:FindFirstChild("HumanoidRootPart")
		local ohum = oc and oc:FindFirstChildOfClass("Humanoid")
		if oroot and ohum and ohum.Health > 0 then
			local diff = oroot.Position - root.Position
			if diff.Magnitude <= aura.rayon then
				local dir = (Vector3.new(diff.X, 0, diff.Z).Unit + Vector3.new(0, 0.6, 0)).Unit
				if dir ~= dir then dir = Vector3.new(0, 1, 0) end -- même position
				ohum:TakeDamage(aura.degats)
				ohum.PlatformStand = true
				oroot.AssemblyLinearVelocity = dir * aura.force
				task.delay(aura.gel or 1, function()
					if ohum.Parent then ohum.PlatformStand = false end
				end)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p) dernierUsage[p] = nil end)
