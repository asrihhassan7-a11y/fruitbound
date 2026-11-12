-- SmashClient (LocalScript dans StarterPlayer > StarterPlayerScripts)
-- Caméra de côté fixe, déplacement 2D, double saut, contrôles d'attaque, HUD des %.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("SmashConfig"))
local remotes = ReplicatedStorage:WaitForChild("SmashRemotes")
local actionRemote = remotes:WaitForChild("Action")
local knockRemote = remotes:WaitForChild("Knock")
local state = ReplicatedStorage:WaitForChild("SmashState")
local Fighters = require(ReplicatedStorage:WaitForChild("SmashFighters"))
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local O = Config.ARENA_ORIGIN

-- Désactive les contrôles Roblox par défaut (on gère nous-mêmes en 2D)
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
controls:Disable()

----------------------------------------------------------------------
-- État local
----------------------------------------------------------------------
local held = {}
local function maxAirJumps()
	local me = state:FindFirstChild("P" .. player.UserId)
	return (me and me:GetAttribute("AirJumps")) or Config.AIR_JUMPS
end
local airJumps = Config.AIR_JUMPS

-- sons locaux
local function sfx(name, pitch, volume)
	local id = Fighters.Sounds[name]
	if not id or id == "" then return end
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.PlaybackSpeed = pitch or 1
	snd.Volume = volume or 0.6
	snd.Parent = SoundService
	snd.PlayOnRemove = false
	snd:Play()
	snd.Ended:Connect(function() snd:Destroy() end)
	task.delay(5, function() if snd.Parent then snd:Destroy() end end)
end
local facing = 1
local stunUntil = 0
local smashStart = nil
local shielding = false
local shake = 0
local recoveryReady = true
local koLock = false -- pendant l'animation de KO, le serveur contrôle le perso
local fx = {}        -- fonctions d'effets d'écran (définies plus bas avec le HUD)

local function getChar()
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if root and hum then return char, root, hum end
end

local function dirInput()
	if held.Up then return "Up" end
	if held.Down then return "Down" end
	return "Side"
end

local function moveAxis()
	local x = 0
	if held.Left then x -= 1 end
	if held.Right then x += 1 end
	if x == 0 and held.Stick then x = held.Stick end
	return x
end

----------------------------------------------------------------------
-- Entrées
----------------------------------------------------------------------
local KEYS = {
	[Enum.KeyCode.A] = "Left", [Enum.KeyCode.Left] = "Left", [Enum.KeyCode.Q] = "Left",
	[Enum.KeyCode.D] = "Right", [Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.W] = "Up", [Enum.KeyCode.Up] = "Up", [Enum.KeyCode.Z] = "Up",
	[Enum.KeyCode.S] = "Down", [Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.Space] = "Jump", [Enum.KeyCode.ButtonA] = "Jump",
	[Enum.KeyCode.J] = "Attack", [Enum.KeyCode.ButtonX] = "Attack",
	[Enum.KeyCode.K] = "Smash", [Enum.KeyCode.ButtonY] = "Smash",
	[Enum.KeyCode.L] = "Special", [Enum.KeyCode.E] = "Special", [Enum.KeyCode.ButtonB] = "Special",
	[Enum.KeyCode.LeftShift] = "Shield", [Enum.KeyCode.ButtonR2] = "Shield", [Enum.KeyCode.ButtonL2] = "Shield",
}

local function jump()
	local _, root, hum = getChar()
	if not root or os.clock() < stunUntil or shielding then return end
	if hum.FloorMaterial ~= Enum.Material.Air then
		hum.Jump = true
		sfx("Jump", 1, 0.4)
	elseif airJumps > 0 then
		airJumps -= 1
		root.AssemblyLinearVelocity = Vector3.new(moveAxis() * hum.WalkSpeed, Config.AIR_JUMP_VELOCITY, 0)
		sfx("Jump", 1.25, 0.4)
	end
end

local function press(action)
	-- compte à rebours : aucune action possible
	if state:GetAttribute("Phase") == "Countdown" then
		if action == "Smash" then smashStart = nil end
		return
	end
	if fx.onPress and fx.onPress(action) then return end
	if action == "Jump" then
		jump()
	elseif action == "Attack" then
		actionRemote:FireServer("Attack", dirInput(), facing)
	elseif action == "Smash" then
		smashStart = os.clock()
	elseif action == "Special" then
		local _, root, hum = getChar()
		if dirInput() == "Up" and root then
			-- super saut de récupération (une fois par passage en l'air)
			if hum.FloorMaterial == Enum.Material.Air and recoveryReady and os.clock() >= stunUntil
				and (state:GetAttribute("Phase") == "Fight" or state:GetAttribute("Phase") == "Training") then
				recoveryReady = false
				root.AssemblyLinearVelocity = Vector3.new(moveAxis() * 25, Config.RECOVERY_VELOCITY, 0)
				actionRemote:FireServer("Special", "Up", facing)
			end
			return
		end
		actionRemote:FireServer("Special", dirInput(), facing)
	elseif action == "Shield" then
		shielding = true
		actionRemote:FireServer("ShieldOn")
	end
end

local function release(action)
	if state:GetAttribute("Phase") == "Countdown" then return end
	if action == "Smash" and smashStart then
		local charge = math.min(os.clock() - smashStart, Config.SMASH_CHARGE_MAX)
		smashStart = nil
		actionRemote:FireServer("Smash", dirInput(), facing, charge)
		sfx("Smash", 1 - charge * 0.3, 0.7)
	elseif action == "Shield" then
		shielding = false
		actionRemote:FireServer("ShieldOff")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local action = KEYS[input.KeyCode]
	if input.UserInputType == Enum.UserInputType.MouseButton1 then action = "Attack" end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then action = "Smash" end
	if not action then return end
	held[action] = true
	press(action)
end)

UserInputService.InputEnded:Connect(function(input)
	local action = KEYS[input.KeyCode]
	if input.UserInputType == Enum.UserInputType.MouseButton2 then action = "Smash" end
	if not action then return end
	held[action] = false
	release(action)
end)

UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		local p = input.Position
		held.Stick = math.abs(p.X) > 0.3 and math.sign(p.X) or nil
		held.Up = p.Y > 0.6 or nil
		held.Down = p.Y < -0.6 or nil
	end
end)

----------------------------------------------------------------------
-- Messages du serveur
----------------------------------------------------------------------
knockRemote.OnClientEvent:Connect(function(kind, a, b, c)
	local _, root, hum = getChar()
	if kind == "Shake" then
		shake = math.max(shake, a)
		return
	elseif kind == "KO" then
		if fx.ko then fx.ko(a, b, c) end
		return
	elseif kind == "Eliminated" then
		if fx.eliminated then fx.eliminated() end
		return
	elseif kind == "NextRound" then
		if fx.toast then fx.toast("Tu rejoindras la prochaine manche !") end
		return
	elseif kind == "Freeze" then
		if fx.freeze then fx.freeze(a) end
		return
	elseif kind == "DmgNum" then
		if fx.dmgNum then fx.dmgNum(a, b, c) end
		return
	elseif kind == "Dash" then
		local _, r = getChar()
		if r and not r.Anchored then
			r.AssemblyLinearVelocity = Vector3.new(a * 110, 4, 0)
			task.delay(0.24, function()
				local v = r.AssemblyLinearVelocity
				r.AssemblyLinearVelocity = Vector3.new(v.X * 0.25, v.Y, 0)
			end)
		end
		return
	elseif kind == "Dive" then
		local _, r = getChar()
		if r and not r.Anchored then r.AssemblyLinearVelocity = Vector3.new(0, -130, 0) end
		return
	elseif kind == "Pose" then
		if fx.pose then fx.pose(a, b) end
		return
	elseif kind == "Pickup" then
		sfx("Pickup", 1.5, 0.7)
		if fx.toast then fx.toast(a) end
		return
	elseif kind == "KOStart" then
		if fx.clearLocal and root then fx.clearLocal(root) end
		koLock = true
		held = {}
		smashStart = nil
		return
	end
	if not root then return end
	if fx.clearLocal then fx.clearLocal(root) end
	if kind == "Knock" then
		stunUntil = os.clock() + b
		hum.PlatformStand = true
		root.AssemblyLinearVelocity = a
		airJumps = maxAirJumps()
		recoveryReady = true
	elseif kind == "Reset" then
		koLock = false
		stunUntil = 0
		hum.PlatformStand = false
		root.AssemblyLinearVelocity = Vector3.zero
		airJumps = maxAirJumps()
	end
end)

----------------------------------------------------------------------
-- Plateformes traversables (localement, pour son propre perso)
----------------------------------------------------------------------

local function updatePlatforms(root)
	local feet = root.Position.Y - 3
	local vy = root.AssemblyLinearVelocity.Y
	local arena = workspace:FindFirstChild("SmashArena")
	local platforms = arena and arena:FindFirstChild("Platforms")
	if not platforms then return end
	for _, p in ipairs(platforms:GetChildren()) do
		local top = p.Position.Y + p.Size.Y / 2
		local solid = feet >= top - 0.6
		-- maintenir Bas pour tomber à travers
		if held.Down and feet >= top - 1 and feet < top + 1.5 and os.clock() - (held.DownTime or 0) > 0.15 then
			solid = false
		end
		if vy > 1 then solid = false end
		p.CanCollide = solid
	end
end

----------------------------------------------------------------------
-- Boucle de déplacement 2D
----------------------------------------------------------------------
local lastDown = false
RunService.Stepped:Connect(function()
	local _, root, hum = getChar()
	if not root or koLock or root.Anchored then return end

	if held.Down and not lastDown then held.DownTime = os.clock() end
	lastDown = held.Down

	-- verrouiller sur le plan Z
	local pos = root.Position
	if math.abs(pos.Z - O.Z) > 0.01 then
		root.CFrame += Vector3.new(0, 0, O.Z - pos.Z)
	end
	local v = root.AssemblyLinearVelocity
	if v.Z ~= 0 then root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, 0) end

	updatePlatforms(root)

	local now = os.clock()
	if now < stunUntil then
		-- en hitstun : on vole, orientation figée
		hum:Move(Vector3.zero)
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(facing > 0 and -90 or 90), 0)
		root.AssemblyAngularVelocity = Vector3.zero
		return
	elseif hum.PlatformStand then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end

	if hum.FloorMaterial ~= Enum.Material.Air then
		airJumps = maxAirJumps()
		recoveryReady = true
	end

	local x = moveAxis()
	if shielding or state:GetAttribute("Phase") == "Countdown" then x = 0 end
	if x ~= 0 then facing = x end
	hum:Move(Vector3.new(x, 0, 0), false)

	-- chute rapide
	if held.Down and hum.FloorMaterial == Enum.Material.Air and v.Y < 10 then
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, -Config.FAST_FALL_SPEED), 0)
	end
end)

----------------------------------------------------------------------
-- Caméra de côté
----------------------------------------------------------------------
camera.CameraType = Enum.CameraType.Scriptable
local camFocus = O + Vector3.new(0, 10, 0)
local camDist = Config.CAMERA_FIXED_DIST

RunService:BindToRenderStep("SmashCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera.CameraType = Enum.CameraType.Scriptable
	local targetFocus, targetDist = O + Vector3.new(0, 12, 0), Config.CAMERA_FIXED_DIST

	local winnerIds = state:GetAttribute("Winner") or ""
	if state:GetAttribute("Phase") == "End" and winnerIds ~= "" then
		-- écran de victoire : zoom sur le(s) gagnant(s)
		local sum, n = Vector3.zero, 0
		for id in string.gmatch(winnerIds, "[^,]+") do
			local info = state:FindFirstChild(id)
			local ref = info and info:FindFirstChild("Character")
			local r = ref and ref.Value and ref.Value:FindFirstChild("HumanoidRootPart")
			if r then sum += r.Position n += 1 end
		end
		if n > 0 then
			targetFocus = sum / n + Vector3.new(0, 1, 0)
			targetDist = n > 1 and 22 or 13
		end
	elseif Config.CAMERA_FOLLOW then
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		local n = 0
		for _, info in ipairs(state:GetChildren()) do
			local ref = info:FindFirstChild("Character")
			local m = ref and ref.Value
			local r = m and m:FindFirstChild("HumanoidRootPart")
			if r and (info:GetAttribute("Stocks") or 0) > 0 and not r.Anchored and math.abs(r.Position.X - O.X) < (state:GetAttribute("BlastX") or 95) + 10
				and math.abs(r.Position.Z - O.Z) < 50 then
				local p = r.Position
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
				n += 1
			end
		end
		if n > 0 then
			local range = state:GetAttribute("CamRangeX") or 35
			local cx = math.clamp((minX + maxX) / 2, O.X - range, O.X + range)
			local cy = math.clamp((minY + maxY) / 2 + 3, O.Y, O.Y + 45)
			targetFocus = Vector3.new(cx, cy, O.Z)
			local spread = math.max(maxX - minX, (maxY - minY) * 1.6)
			targetDist = math.clamp(spread * 0.7 + 14, Config.CAMERA_MIN_DIST, Config.CAMERA_MAX_DIST)
		end
	end

	local a = 1 - math.exp(-4 * dt)
	camFocus = camFocus:Lerp(targetFocus, a)
	camDist += (targetDist - camDist) * a

	local offset = Vector3.zero
	if shake > 0 then
		offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * 2
		shake = math.max(0, shake - dt * 4)
	end
	local camPos = camFocus + Vector3.new(0, camDist * 0.12, camDist) + offset
	camera.FieldOfView = 50
	camera.CFrame = CFrame.lookAt(camPos, camFocus + offset)
end)

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SmashHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.new(1, -32, 0, 110)
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 14)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

local message = Instance.new("TextLabel")
message.BackgroundTransparency = 1
message.AnchorPoint = Vector2.new(0.5, 0.5)
message.Position = UDim2.new(0.5, 0, 0.3, 0)
message.Size = UDim2.new(0.8, 0, 0, 100)
message.Font = Enum.Font.FredokaOne
message.TextScaled = true
message.TextColor3 = Color3.new(1, 1, 1)
message.TextStrokeTransparency = 0
message.Parent = gui

local help = Instance.new("TextLabel")
help.BackgroundTransparency = 0.4
help.BackgroundColor3 = Color3.new(0, 0, 0)
help.Position = UDim2.new(0, 12, 0, 50)
help.Size = UDim2.new(0, 260, 0, 136)
help.Font = Enum.Font.Gotham
help.TextSize = 13
help.TextColor3 = Color3.new(1, 1, 1)
help.TextXAlignment = Enum.TextXAlignment.Left
help.TextYAlignment = Enum.TextYAlignment.Top
help.Text = "  A/D ou Q/D : bouger\n  Espace : saut (x2 en l'air)\n  J / clic gauche : attaque\n  K / clic droit (maintenir) : smash\n  E ou L : projectile\n  Haut + E en l'air : super saut\n  W/Z ou S + attaque : direction\n  S en l'air : chute rapide / traverser\n  Shift : bouclier"
help.Parent = gui
Instance.new("UICorner", help).CornerRadius = UDim.new(0, 8)

local cards = {}
local TS = game:GetService("TweenService")
local function makeCard(info)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 190, 1, 0)
	card.BackgroundTransparency = 1
	card.Parent = bar

	-- contenu (décalé quand on tremble)
	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, 0, 1, 0)
	body.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	body.BackgroundTransparency = 0.2
	body.Parent = card
	Instance.new("UICorner", body).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", body)
	stroke.Thickness = 3
	local grad = Instance.new("UIGradient", body)
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new(0, 0.3)

	-- portrait
	local portrait = Instance.new("Frame")
	portrait.Position = UDim2.new(0, 8, 0, 8)
	portrait.Size = UDim2.fromOffset(52, 52)
	portrait.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
	portrait.Parent = body
	Instance.new("UICorner", portrait).CornerRadius = UDim.new(1, 0)
	local pStroke = Instance.new("UIStroke", portrait)
	pStroke.Thickness = 2
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(1, 0, 1, 0)
	img.Parent = portrait
	Instance.new("UICorner", img).CornerRadius = UDim.new(1, 0)
	local initial = Instance.new("TextLabel")
	initial.BackgroundTransparency = 1
	initial.Size = UDim2.new(1, 0, 1, 0)
	initial.Font = Enum.Font.FredokaOne
	initial.TextScaled = true
	initial.TextColor3 = Color3.new(1, 1, 1)
	initial.Parent = portrait
	local uid = tonumber(string.match(info.Name, "^P(%d+)$"))
	if uid then
		img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=150&h=150"
	end

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 66, 0, 6)
	name.Size = UDim2.new(1, -72, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = body

	local pct = Instance.new("TextLabel")
	pct.BackgroundTransparency = 1
	pct.Position = UDim2.new(0, 64, 0, 22)
	pct.Size = UDim2.new(1, -70, 0, 50)
	pct.Font = Enum.Font.FredokaOne
	pct.TextScaled = true
	pct.TextXAlignment = Enum.TextXAlignment.Left
	pct.TextStrokeTransparency = 0
	pct.Parent = body

	-- icônes de vies
	local lives = Instance.new("Frame")
	lives.BackgroundTransparency = 1
	lives.Position = UDim2.new(0, 10, 0, 76)
	lives.Size = UDim2.new(1, -20, 0, 18)
	lives.Parent = body
	local livesLayout = Instance.new("UIListLayout", lives)
	livesLayout.FillDirection = Enum.FillDirection.Horizontal
	livesLayout.Padding = UDim.new(0, 5)
	livesLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local shieldBar = Instance.new("Frame")
	shieldBar.BorderSizePixel = 0
	shieldBar.Position = UDim2.new(0, 10, 1, -7)
	shieldBar.Size = UDim2.new(1, -20, 0, 3)
	shieldBar.Parent = body

	local lastDmg = info:GetAttribute("Damage") or 0
	local lastStocks = -1
	local flashUntil = 0

	local function pctColor(dmg)
		local t = math.clamp(dmg / 150, 0, 1)
		return Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 60), math.min(t * 2, 1)):Lerp(Color3.fromRGB(200, 20, 20), math.max(t * 2 - 1, 0))
	end

	local function rebuildLives(st, c)
		for _, ch in ipairs(lives:GetChildren()) do
			if ch:IsA("GuiObject") then ch:Destroy() end
		end
		if st >= 50 then
			local inf = Instance.new("TextLabel")
			inf.BackgroundTransparency = 1
			inf.Size = UDim2.fromOffset(30, 18)
			inf.Font = Enum.Font.FredokaOne
			inf.TextScaled = true
			inf.TextColor3 = c
			inf.Text = "∞"
			inf.Parent = lives
			return
		end
		if st <= 0 then
			local out = Instance.new("TextLabel")
			out.BackgroundTransparency = 1
			out.Size = UDim2.fromOffset(100, 18)
			out.Font = Enum.Font.GothamBold
			out.TextScaled = true
			out.TextXAlignment = Enum.TextXAlignment.Left
			out.TextColor3 = Color3.fromRGB(255, 90, 90)
			out.Text = "ÉLIMINÉ"
			out.Parent = lives
			return
		end
		for _ = 1, st do
			local icon = Instance.new("Frame")
			icon.Size = UDim2.fromOffset(16, 16)
			icon.BackgroundColor3 = c
			icon.Parent = lives
			Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
			local is = Instance.new("UIStroke", icon)
			is.Color = Color3.new(1, 1, 1)
			is.Thickness = 1.5
			local shine = Instance.new("Frame")
			shine.BackgroundColor3 = Color3.new(1, 1, 1)
			shine.BackgroundTransparency = 0.4
			shine.Position = UDim2.fromOffset(3, 3)
			shine.Size = UDim2.fromOffset(5, 5)
			shine.Parent = icon
			Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)
		end
	end

	local function shakeCard(strength)
		task.spawn(function()
			for i = 1, 6 do
				local k = (7 - i) / 6
				body.Position = UDim2.fromOffset((math.random() - 0.5) * 2 * strength * k, (math.random() - 0.5) * 2 * strength * k)
				task.wait(0.03)
			end
			body.Position = UDim2.new(0, 0, 0, 0)
		end)
	end

	local function refresh()
		local c = info:GetAttribute("Color") or Color3.new(1, 1, 1)
		local dmg = info:GetAttribute("Damage") or 0
		local st = info:GetAttribute("Stocks") or 0
		card.LayoutOrder = info:GetAttribute("Slot") or 0
		local team = info:GetAttribute("Team") or 0
		if state:GetAttribute("Mode") == "Teams" and team > 0 then
			c = team == 1 and Color3.fromRGB(255, 70, 70) or Color3.fromRGB(70, 140, 255)
		end
		stroke.Color = c
		pStroke.Color = c
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1):Lerp(c, 0.5))
		if not uid then
			portrait.BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.3)
			local nm = info:GetAttribute("CharName") or info:GetAttribute("DisplayName") or "?"
			initial.Text = string.upper(string.sub(nm, 1, 1))
		end
		name.Text = info:GetAttribute("DisplayName") or info.Name
		pct.Text = dmg .. "%"

		-- touché : le % tremble et devient rouge
		if dmg > lastDmg then
			local gained = dmg - lastDmg
			shakeCard(math.clamp(gained * 0.8, 4, 14))
			flashUntil = os.clock() + 0.35
			pct.TextColor3 = Color3.fromRGB(255, 40, 40)
			pct.Size = UDim2.new(1, -60, 0, 58)
			TS:Create(pct, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(1, -70, 0, 50) }):Play()
			task.delay(0.36, function()
				if os.clock() >= flashUntil then
					TS:Create(pct, TweenInfo.new(0.2), { TextColor3 = pctColor(info:GetAttribute("Damage") or 0) }):Play()
				end
			end)
		elseif os.clock() >= flashUntil then
			pct.TextColor3 = pctColor(dmg)
		end
		lastDmg = dmg

		if st ~= lastStocks then
			rebuildLives(st, c)
			lastStocks = st
		end
		shieldBar.BackgroundColor3 = c
		shieldBar.Size = UDim2.new((info:GetAttribute("Shield") or 1), -20, 0, 3)
		body.BackgroundTransparency = st > 0 and 0.2 or 0.65
		-- cacher ceux qui sont sur le menu
		card.Visible = not info:GetAttribute("InMenu")
			and (info:GetAttribute("InRound") or (state:GetAttribute("Phase") ~= "Fight" and state:GetAttribute("Phase") ~= "Training"))
	end
	info.AttributeChanged:Connect(refresh)
	refresh()
	cards[info] = card
end

for _, info in ipairs(state:GetChildren()) do makeCard(info) end
state.ChildAdded:Connect(makeCard)
state.ChildRemoved:Connect(function(info)
	if cards[info] then cards[info]:Destroy() cards[info] = nil end
end)

local function refreshMsg() message.Text = state:GetAttribute("Message") or "" end
state:GetAttributeChangedSignal("Message"):Connect(refreshMsg)
refreshMsg()

-- indicateur de charge du smash
RunService.RenderStepped:Connect(function()
	if smashStart then
		local c = math.min(os.clock() - smashStart, Config.SMASH_CHARGE_MAX) / Config.SMASH_CHARGE_MAX
		local char = player.Character
		if char then
			local h = char:FindFirstChild("SmashCharge") or Instance.new("Highlight")
			h.Name = "SmashCharge"
			h.FillColor = Color3.fromRGB(255, 220, 60)
			h.FillTransparency = 1 - c * 0.7
			h.OutlineTransparency = 1
			h.Parent = char
		end
	else
		local char = player.Character
		local h = char and char:FindFirstChild("SmashCharge")
		if h then h:Destroy() end
	end
end)

----------------------------------------------------------------------
-- Chrono, nom de la map, résultats
----------------------------------------------------------------------
local Maps = require(ReplicatedStorage:WaitForChild("SmashMaps"))

local timer = Instance.new("TextLabel")
timer.BackgroundColor3 = Color3.new(0, 0, 0)
timer.BackgroundTransparency = 0.4
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.new(0.5, 0, 0, 44)
timer.Size = UDim2.new(0, 220, 0, 44)
timer.Font = Enum.Font.FredokaOne
timer.TextScaled = true
timer.TextColor3 = Color3.new(1, 1, 1)
timer.Parent = gui
Instance.new("UICorner", timer).CornerRadius = UDim.new(0, 10)

local resultsLabel = Instance.new("TextLabel")
resultsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
resultsLabel.BackgroundTransparency = 0.3
resultsLabel.AnchorPoint = Vector2.new(0.5, 0)
resultsLabel.Position = UDim2.new(0.5, 0, 0.42, 0)
resultsLabel.Size = UDim2.new(0, 420, 0, 170)
resultsLabel.Font = Enum.Font.GothamBold
resultsLabel.TextSize = 20
resultsLabel.TextColor3 = Color3.new(1, 1, 1)
resultsLabel.Visible = false
resultsLabel.Parent = gui
Instance.new("UICorner", resultsLabel).CornerRadius = UDim.new(0, 12)

local function fmtTime(t)
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local function refreshTop()
	local ph = state:GetAttribute("Phase")
	local t = state:GetAttribute("TimeLeft") or 0
	local mapName = state:GetAttribute("MapName") or ""
	if ph == "Fight" or ph == "Countdown" then
		timer.Visible = true
		timer.Text = (Config.ROUND_TIME > 0 and fmtTime(t) .. "  •  " or "") .. mapName
		timer.TextColor3 = (ph == "Fight" and t <= 10 and Config.ROUND_TIME > 0) and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
	elseif ph == "Vote" then
		timer.Visible = true
		timer.Text = "Vote : " .. t .. "s"
		timer.TextColor3 = Color3.new(1, 1, 1)
	else
		timer.Visible = false
	end
	local res = state:GetAttribute("Results") or ""
	resultsLabel.Visible = res ~= ""
	resultsLabel.Text = res
end
state.AttributeChanged:Connect(refreshTop)
refreshTop()

----------------------------------------------------------------------
-- Écran de sélection de map (vote)
----------------------------------------------------------------------
local voteFrame = Instance.new("Frame")
voteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
voteFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
voteFrame.Size = UDim2.new(0.9, 0, 0, 290)
voteFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
voteFrame.BackgroundTransparency = 0.15
voteFrame.Visible = false
voteFrame.Parent = gui
Instance.new("UICorner", voteFrame).CornerRadius = UDim.new(0, 14)
voteFrame.Size = UDim2.new(0.9, 0, 0, 350)
local sizeLimit = Instance.new("UISizeConstraint", voteFrame)
sizeLimit.MaxSize = Vector2.new(1000, 350)

local voteTitle = Instance.new("TextLabel")
voteTitle.BackgroundTransparency = 1
voteTitle.Size = UDim2.new(1, 0, 0, 44)
voteTitle.Position = UDim2.new(0, 0, 0, 8)
voteTitle.Font = Enum.Font.FredokaOne
voteTitle.TextScaled = true
voteTitle.TextColor3 = Color3.new(1, 1, 1)
voteTitle.Text = "CHOISIS LA MAP"
voteTitle.Parent = voteFrame

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.new(0, 12, 0, 60)
list.Size = UDim2.new(1, -24, 1, -132)
list.ScrollingDirection = Enum.ScrollingDirection.X
list.AutomaticCanvasSize = Enum.AutomaticSize.X
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.ScrollBarThickness = 6
list.Parent = voteFrame
local listLayout = Instance.new("UIListLayout", list)
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local myVote = nil
local voteButtons = {}

local function makeVoteButton(idx, name, desc, color)
	local b = Instance.new("TextButton")
	b.LayoutOrder = idx == 0 and 999 or idx
	b.Size = UDim2.new(0, 170, 1, -10)
	b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	b.AutoButtonColor = true
	b.Text = ""
	b.Parent = list
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", b)
	stroke.Thickness = 2
	stroke.Color = color
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local swatch = Instance.new("Frame")
	swatch.BorderSizePixel = 0
	swatch.BackgroundColor3 = color
	swatch.Position = UDim2.new(0, 10, 0, 10)
	swatch.Size = UDim2.new(1, -20, 0, 70)
	swatch.Parent = b
	Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 8)
	local grad = Instance.new("UIGradient", swatch)
	grad.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.6))
	grad.Rotation = 90

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 86)
	title.Size = UDim2.new(1, -20, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = name
	title.Parent = b

	local d = Instance.new("TextLabel")
	d.BackgroundTransparency = 1
	d.Position = UDim2.new(0, 10, 0, 112)
	d.Size = UDim2.new(1, -20, 0, 40)
	d.Font = Enum.Font.Gotham
	d.TextSize = 13
	d.TextWrapped = true
	d.TextColor3 = Color3.fromRGB(200, 200, 210)
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.Text = desc
	d.Parent = b

	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.AnchorPoint = Vector2.new(0, 1)
	count.Position = UDim2.new(0, 10, 1, -8)
	count.Size = UDim2.new(1, -20, 0, 26)
	count.Font = Enum.Font.FredokaOne
	count.TextScaled = true
	count.TextColor3 = color
	count.Text = "0 vote"
	count.Parent = b

	b.MouseButton1Click:Connect(function()
		myVote = idx
		actionRemote:FireServer("Vote", idx)
		for i, vb in pairs(voteButtons) do
			vb.stroke.Thickness = (i == myVote) and 5 or 2
			vb.button.BackgroundColor3 = (i == myVote) and Color3.fromRGB(60, 60, 85) or Color3.fromRGB(35, 35, 50)
		end
	end)
	voteButtons[idx] = { button = b, stroke = stroke, count = count }
end

for i, m in ipairs(Maps) do makeVoteButton(i, m.name, m.desc, m.icon) end
makeVoteButton(0, "Aléatoire", "Laisse le hasard choisir", Color3.fromRGB(200, 200, 200))

local function refreshVote()
	local isVote = state:GetAttribute("Phase") == "Vote"
	if isVote and not voteFrame.Visible then
		myVote = nil
		for _, vb in pairs(voteButtons) do
			vb.stroke.Thickness = 2
			vb.button.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
		end
	end
	local me = state:FindFirstChild("P" .. player.UserId)
	local inMenu = me and me:GetAttribute("InMenu")
	voteFrame.Visible = isVote and not inMenu
	help.Visible = not isVote and not inMenu
	for i, vb in pairs(voteButtons) do
		local n = state:GetAttribute("Vote" .. i) or 0
		vb.count.Text = n .. (n > 1 and " votes" or " vote")
	end
end
state.AttributeChanged:Connect(refreshVote)
refreshVote()

-- choix du mode : chacun pour soi / équipes
local modeRow = Instance.new("Frame")
modeRow.BackgroundTransparency = 1
modeRow.AnchorPoint = Vector2.new(0.5, 1)
modeRow.Position = UDim2.new(0.5, 0, 1, -10)
modeRow.Size = UDim2.new(1, -24, 0, 48)
modeRow.Parent = voteFrame
local modeLayout = Instance.new("UIListLayout", modeRow)
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
modeLayout.Padding = UDim.new(0, 12)
local modeButtons = {}
local myMode = nil
for _, m in ipairs({ { "FFA", "Chacun pour soi", Color3.fromRGB(230, 200, 60) }, { "Teams", "Équipes (Rouge vs Bleu)", Color3.fromRGB(90, 140, 255) } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 280, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = modeRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke", b)
	st.Color = m[3]
	st.Thickness = 2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding", b)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
	b.MouseButton1Click:Connect(function()
		myMode = m[1]
		actionRemote:FireServer("VoteMode", m[1])
		for id, mb in pairs(modeButtons) do mb.stroke.Thickness = id == myMode and 5 or 2 end
	end)
	modeButtons[m[1]] = { button = b, stroke = st, label = m[2] }
end
local function refreshModeVotes()
	if state:GetAttribute("Phase") ~= "Vote" then
		myMode = nil
		for _, mb in pairs(modeButtons) do mb.stroke.Thickness = 2 end
	end
	modeButtons.FFA.button.Text = modeButtons.FFA.label .. "  (" .. (state:GetAttribute("VoteFFA") or 0) .. ")"
	modeButtons.Teams.button.Text = modeButtons.Teams.label .. "  (" .. (state:GetAttribute("VoteTeams") or 0) .. ")"
end
state.AttributeChanged:Connect(refreshModeVotes)
refreshModeVotes()

----------------------------------------------------------------------
-- Effets de KO à l'écran
----------------------------------------------------------------------
local whiteFlash = Instance.new("Frame")
whiteFlash.Size = UDim2.new(1, 0, 1, 0)
whiteFlash.BackgroundColor3 = Color3.new(1, 1, 1)
whiteFlash.BackgroundTransparency = 1
whiteFlash.BorderSizePixel = 0
whiteFlash.ZIndex = 5
whiteFlash.Parent = gui

local koText = Instance.new("TextLabel")
koText.BackgroundTransparency = 1
koText.AnchorPoint = Vector2.new(0.5, 0.5)
koText.Position = UDim2.new(0.5, 0, 0.45, 0)
koText.Size = UDim2.new(0, 500, 0, 160)
koText.Font = Enum.Font.FredokaOne
koText.TextScaled = true
koText.TextStrokeTransparency = 0
koText.TextTransparency = 1
koText.TextStrokeColor3 = Color3.new(0, 0, 0)
koText.ZIndex = 6
koText.Parent = gui

local TweenService = game:GetService("TweenService")

fx.ko = function(pos, color, name)
	shake = math.max(shake, 1.5)
	sfx("KO", 0.8, 0.8)
	whiteFlash.BackgroundTransparency = 0.35
	TweenService:Create(whiteFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	koText.Text = "KO !\n" .. tostring(name)
	koText.TextColor3 = color or Color3.new(1, 1, 1)
	koText.TextTransparency = 0
	koText.TextStrokeTransparency = 0
	koText.Size = UDim2.new(0, 700, 0, 220)
	TweenService:Create(koText, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(0, 500, 0, 160) }):Play()
	task.delay(0.9, function()
		TweenService:Create(koText, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

local toast = Instance.new("TextLabel")
toast.BackgroundColor3 = Color3.new(0, 0, 0)
toast.BackgroundTransparency = 0.3
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 100)
toast.Size = UDim2.new(0, 420, 0, 40)
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
toast.ZIndex = 7
toast.Parent = gui
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
fx.toast = function(text)
	toast.Text = text
	toast.Visible = true
	task.delay(3, function() if toast.Text == text then toast.Visible = false end end)
end

fx.eliminated = function()
	koText.Text = "ÉLIMINÉ !"
	koText.TextColor3 = Color3.fromRGB(255, 70, 70)
	koText.TextTransparency = 0
	koText.TextStrokeTransparency = 0
	task.delay(2.2, function()
		TweenService:Create(koText, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

----------------------------------------------------------------------
-- Menu de départ
----------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local menu = Instance.new("Frame")
menu.Size = UDim2.new(1, 0, 1, 0)
menu.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
menu.BackgroundTransparency = 0.35
menu.BorderSizePixel = 0
menu.ZIndex = 20
menu.Visible = false
menu.Parent = gui

local menuTitle = Instance.new("TextLabel")
menuTitle.BackgroundTransparency = 1
menuTitle.AnchorPoint = Vector2.new(0.5, 0)
menuTitle.Position = UDim2.new(0.5, 0, 0.12, 0)
menuTitle.Size = UDim2.new(0.8, 0, 0, 110)
menuTitle.Font = Enum.Font.FredokaOne
menuTitle.TextScaled = true
menuTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
menuTitle.TextStrokeTransparency = 0
menuTitle.Text = "SMASH ARENA"
menuTitle.ZIndex = 21
menuTitle.Parent = menu
local titleGrad = Instance.new("UIGradient", menuTitle)
titleGrad.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 120, 40))
titleGrad.Rotation = 90

local menuSub = Instance.new("TextLabel")
menuSub.BackgroundTransparency = 1
menuSub.AnchorPoint = Vector2.new(0.5, 0)
menuSub.Position = UDim2.new(0.5, 0, 0.12, 115)
menuSub.Size = UDim2.new(0.8, 0, 0, 30)
menuSub.Font = Enum.Font.GothamBold
menuSub.TextScaled = true
menuSub.TextColor3 = Color3.fromRGB(220, 220, 235)
menuSub.Text = "Éjecte tes adversaires hors de l'écran !"
menuSub.ZIndex = 21
menuSub.Parent = menu

local playButton = Instance.new("TextButton")
playButton.AnchorPoint = Vector2.new(0.5, 0.5)
playButton.Position = UDim2.new(0.5, 0, 0.62, 0)
playButton.Size = UDim2.new(0, 280, 0, 80)
playButton.BackgroundColor3 = Color3.fromRGB(80, 200, 110)
playButton.Font = Enum.Font.FredokaOne
playButton.TextScaled = true
playButton.TextColor3 = Color3.new(1, 1, 1)
playButton.Text = "JOUER"
playButton.ZIndex = 22
playButton.Parent = menu
Instance.new("UICorner", playButton).CornerRadius = UDim.new(0, 16)
local playStroke = Instance.new("UIStroke", playButton)
playStroke.Thickness = 4
playStroke.Color = Color3.fromRGB(30, 110, 50)
playStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local playPad = Instance.new("UIPadding", playButton)
playPad.PaddingTop = UDim.new(0, 12)
playPad.PaddingBottom = UDim.new(0, 12)

local menuInfo = Instance.new("TextLabel")
menuInfo.BackgroundTransparency = 1
menuInfo.AnchorPoint = Vector2.new(0.5, 0)
menuInfo.Position = UDim2.new(0.5, 0, 0.62, 150)
menuInfo.Size = UDim2.new(0.9, 0, 0, 70)
menuInfo.Font = Enum.Font.Gotham
menuInfo.TextSize = 16
menuInfo.TextColor3 = Color3.fromRGB(200, 200, 215)
menuInfo.Text = "3 vies par manche • Vote pour la map • Affronte les bots CPU\n\nQ/D bouger • Espace sauter • J attaque • K smash • E projectile • Shift bouclier"
menuInfo.TextWrapped = true
menuInfo.ZIndex = 21
menuInfo.Parent = menu

local lastResult = Instance.new("TextLabel")
lastResult.BackgroundTransparency = 1
lastResult.AnchorPoint = Vector2.new(0.5, 1)
lastResult.Position = UDim2.new(0.5, 0, 0.12, 180)
lastResult.Size = UDim2.new(0.8, 0, 0, 30)
lastResult.Font = Enum.Font.GothamBold
lastResult.TextScaled = true
lastResult.TextColor3 = Color3.fromRGB(255, 110, 110)
lastResult.Text = ""
lastResult.ZIndex = 21
lastResult.Parent = menu

-- petit effet de pulsation sur le bouton
task.spawn(function()
	while true do
		if menu.Visible then
			TweenService:Create(playButton, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 300, 0, 86) }):Play()
			task.wait(0.6)
			TweenService:Create(playButton, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Size = UDim2.new(0, 280, 0, 80) }):Play()
			task.wait(0.6)
		else
			task.wait(0.3)
		end
	end
end)

playButton.MouseButton1Click:Connect(function()
	actionRemote:FireServer("Play")
end)

local wasPlaying = false
local function refreshMenu()
	local me = state:FindFirstChild("P" .. player.UserId)
	local inMenu = me == nil or me:GetAttribute("InMenu") == true
	if inMenu and wasPlaying then
		lastResult.Text = "Tu as perdu tes 3 vies ! Réessaie ?"
	end
	wasPlaying = not inMenu
	menu.Visible = inMenu
	TweenService:Create(blur, TweenInfo.new(0.4), { Size = inMenu and 16 or 0 }):Play()
	refreshVote()
end

local function hookMe(me)
	me.AttributeChanged:Connect(refreshMenu)
	refreshMenu()
end
local meInfo = state:FindFirstChild("P" .. player.UserId)
if meInfo then hookMe(meInfo) end
state.ChildAdded:Connect(function(c)
	if c.Name == "P" .. player.UserId then hookMe(c) end
end)
refreshMenu()

----------------------------------------------------------------------
-- Sélection du personnage (dans le menu)
----------------------------------------------------------------------
local pickRow = Instance.new("Frame")
pickRow.BackgroundTransparency = 1
pickRow.AnchorPoint = Vector2.new(0.5, 0.5)
pickRow.Position = UDim2.new(0.5, 0, 0.44, 0)
pickRow.Size = UDim2.new(0.95, 0, 0, 170)
pickRow.ZIndex = 21
pickRow.Parent = menu
local pickLayout = Instance.new("UIListLayout", pickRow)
pickLayout.FillDirection = Enum.FillDirection.Horizontal
pickLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
pickLayout.VerticalAlignment = Enum.VerticalAlignment.Center
pickLayout.Padding = UDim.new(0, 12)

local pickCards = {}
local myPick = "Brawler"
local function statBar(parent, y, label, value, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.new(0, 8, 0, y)
	l.Size = UDim2.new(0, 50, 0, 12)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = Color3.fromRGB(200, 200, 210)
	l.Text = label
	l.ZIndex = 23
	l.Parent = parent
	local bg = Instance.new("Frame")
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	bg.Position = UDim2.new(0, 60, 0, y + 3)
	bg.Size = UDim2.new(1, -70, 0, 6)
	bg.ZIndex = 23
	bg.Parent = parent
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color
	fill.Size = UDim2.new(math.clamp(value, 0.05, 1), 0, 1, 0)
	fill.ZIndex = 24
	fill.Parent = bg
end

local function selectPick(id)
	myPick = id
	actionRemote:FireServer("Pick", id)
	for cid, card in pairs(pickCards) do
		card.stroke.Thickness = (cid == id) and 5 or 2
		card.button.BackgroundColor3 = (cid == id) and Color3.fromRGB(60, 60, 85) or Color3.fromRGB(30, 30, 45)
	end
end

for i, c in ipairs(Fighters.Characters) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(0, 160, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	b.Text = ""
	b.ZIndex = 22
	b.Parent = pickRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", b)
	stroke.Color = c.color
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local swatch = Instance.new("Frame")
	swatch.BorderSizePixel = 0
	swatch.BackgroundColor3 = c.color
	swatch.AnchorPoint = Vector2.new(0.5, 0)
	swatch.Position = UDim2.new(0.5, 0, 0, 10)
	swatch.Size = UDim2.fromOffset(34 * c.scale, 34 * c.scale)
	swatch.ZIndex = 23
	swatch.Parent = b
	Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)

	local n = Instance.new("TextLabel")
	n.BackgroundTransparency = 1
	n.Position = UDim2.new(0, 6, 0, 52)
	n.Size = UDim2.new(1, -12, 0, 22)
	n.Font = Enum.Font.FredokaOne
	n.TextScaled = true
	n.TextColor3 = Color3.new(1, 1, 1)
	n.Text = c.name
	n.ZIndex = 23
	n.Parent = b

	local d = Instance.new("TextLabel")
	d.BackgroundTransparency = 1
	d.Position = UDim2.new(0, 6, 0, 75)
	d.Size = UDim2.new(1, -12, 0, 30)
	d.Font = Enum.Font.Gotham
	d.TextSize = 11
	d.TextWrapped = true
	d.TextColor3 = Color3.fromRGB(200, 200, 210)
	d.Text = c.desc
	d.ZIndex = 23
	d.Parent = b

	statBar(b, 108, "Vitesse", (c.speed - 15) / 22, c.color)
	statBar(b, 124, "Force", (c.power - 0.6) / 0.8, c.color)
	statBar(b, 140, "Poids", (1.4 - c.weight) / 0.7, c.color)

	b.MouseButton1Click:Connect(function() selectPick(c.id) end)
	pickCards[c.id] = { button = b, stroke = stroke }
end
selectPick(myPick)

----------------------------------------------------------------------
-- Animations d'attaque (poses procédurales sur les articulations)
----------------------------------------------------------------------
local JOINTS = {
	RightArm = { "RightShoulder", "Right Shoulder", 1 },
	LeftArm = { "LeftShoulder", "Left Shoulder", -1 },
	RightLeg = { "RightHip", "Right Hip", 1 },
	LeftLeg = { "LeftHip", "Left Hip", -1 },
	Waist = { "Waist", nil, 0 },
	RightElbow = { "RightElbow", nil, 0, 1 },
	LeftElbow = { "LeftElbow", nil, 0, 1 },
	RightKnee = { "RightKnee", nil, 0, -1 },
	LeftKnee = { "LeftKnee", nil, 0, -1 },
}
local baseC0 = setmetatable({}, { __mode = "k" })
local poseToken = setmetatable({}, { __mode = "k" })

local function findMotor(model, name)
	if not name then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then return d end
	end
end

local function jointOffset(jointKey, motor, deg)
	local r = math.rad(deg)
	local info = JOINTS[jointKey]
	if jointKey == "Waist" then return CFrame.Angles(0, r, 0) end
	if motor.Name == info[1] then
		return CFrame.Angles(r * (info[4] or 1), 0, 0) -- R15
	end
	return CFrame.Angles(0, 0, r * info[3]) -- R6
end

local function applyPose(model, pose, time)
	local tweens = {}
	for key, deg in pairs(pose) do
		local info = JOINTS[key]
		local motor = info and (findMotor(model, info[1]) or findMotor(model, info[2]))
		if motor then
			baseC0[motor] = baseC0[motor] or motor.C0
			local t = TweenService:Create(motor, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = baseC0[motor] * jointOffset(key, motor, deg) })
			t:Play()
			table.insert(tweens, t)
		end
	end
	return tweens
end

local function resetPose(model, time)
	for motor, c0 in pairs(baseC0) do
		if motor.Parent and motor:IsDescendantOf(model) then
			TweenService:Create(motor, TweenInfo.new(time, Enum.EasingStyle.Quad), { C0 = c0 }):Play()
		end
	end
end

fx.pose = function(model, name)
	if typeof(model) ~= "Instance" or not model.Parent then return end
	if name == "ShieldEnd" then
		poseToken[model] = {}
		resetPose(model, 0.15)
		return
	end
	local def = Fighters.Poses[name]
	if not def then return end
	local token = {}
	poseToken[model] = token
	local atk = Config.ATTACKS[name]
	local startup = atk and atk.startup or 0
	task.spawn(function()
		if def.windup and startup > 0 then
			applyPose(model, def.windup, startup * 0.8)
			task.wait(startup)
			if poseToken[model] ~= token then return end
		end
		applyPose(model, def.strike, 0.06)
		if def.hold then return end
		task.wait(0.18)
		if poseToken[model] ~= token then return end
		resetPose(model, 0.18)
	end)
end

-- bip du compte à rebours
state:GetAttributeChangedSignal("Message"):Connect(function()
	local m = state:GetAttribute("Message")
	if m == "3" or m == "2" or m == "1" then sfx("Beep", 1, 0.6)
	elseif m == "GO !" then sfx("Beep", 1.5, 0.8) end
end)

----------------------------------------------------------------------
-- Musique
----------------------------------------------------------------------
local Maps = require(ReplicatedStorage:WaitForChild("SmashMaps"))
local music = Instance.new("Sound")
music.Name = "SmashMusic"
music.Looped = true
music.Volume = Fighters.MusicVolume
music.Parent = SoundService

local function refreshMusic()
	local me = state:FindFirstChild("P" .. player.UserId)
	local inMenu = me == nil or me:GetAttribute("InMenu") == true
	local id
	if inMenu then
		id = Fighters.MenuMusic
	else
		local map = Maps[state:GetAttribute("Map") or 1]
		id = (map and map.music) or Fighters.FightMusic
	end
	id = id or ""
	if music.SoundId ~= id then
		music:Stop()
		music.SoundId = id
		if id ~= "" then music:Play() end
	end
end
state.AttributeChanged:Connect(refreshMusic)
state.ChildAdded:Connect(function(c)
	if c.Name == "P" .. player.UserId then c.AttributeChanged:Connect(refreshMusic) end
end)
do
	local me = state:FindFirstChild("P" .. player.UserId)
	if me then me.AttributeChanged:Connect(refreshMusic) end
end
refreshMusic()

----------------------------------------------------------------------
-- Contrôles mobiles (boutons tactiles)
----------------------------------------------------------------------
if UserInputService.TouchEnabled then
	help.Visible = false
	local touchGui = Instance.new("Frame")
	touchGui.BackgroundTransparency = 1
	touchGui.Size = UDim2.new(1, 0, 1, 0)
	touchGui.ZIndex = 10
	touchGui.Parent = gui

	local function touchButton(label, action, pos, size, color)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = pos
		b.Size = UDim2.fromOffset(size, size)
		b.BackgroundColor3 = color or Color3.fromRGB(40, 40, 55)
		b.BackgroundTransparency = 0.35
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = label
		b.AutoButtonColor = false
		b.ZIndex = 11
		b.Parent = touchGui
		Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
		local pad = Instance.new("UIPadding", b)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.22, 0), UDim.new(0.22, 0)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.15, 0), UDim.new(0.15, 0)
		b.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				held[action] = true
				b.BackgroundTransparency = 0.05
				press(action)
			end
		end)
		b.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				held[action] = false
				b.BackgroundTransparency = 0.35
				release(action)
			end
		end)
		return b
	end

	-- croix directionnelle (gauche)
	touchButton("◀", "Left", UDim2.new(0, 70, 1, -150), 70)
	touchButton("▶", "Right", UDim2.new(0, 210, 1, -150), 70)
	touchButton("▲", "Up", UDim2.new(0, 140, 1, -220), 64)
	touchButton("▼", "Down", UDim2.new(0, 140, 1, -80), 64)
	-- actions (droite)
	touchButton("Saut", "Jump", UDim2.new(1, -80, 1, -90), 90, Color3.fromRGB(70, 160, 90))
	touchButton("Coup", "Attack", UDim2.new(1, -180, 1, -130), 80, Color3.fromRGB(200, 70, 70))
	touchButton("Smash", "Smash", UDim2.new(1, -110, 1, -200), 76, Color3.fromRGB(220, 140, 40))
	touchButton("Tir", "Special", UDim2.new(1, -220, 1, -230), 70, Color3.fromRGB(140, 90, 220))
	touchButton("Bouclier", "Shield", UDim2.new(1, -270, 1, -90), 70, Color3.fromRGB(60, 140, 200))

	-- la barre des % remonte un peu au-dessus des boutons
	bar.Position = UDim2.new(0.5, 0, 1, -270)
	bar.Size = UDim2.new(1, -32, 0, 90)

	-- masquer les boutons dans le menu
	local function refreshTouch()
		local me = state:FindFirstChild("P" .. player.UserId)
		touchGui.Visible = not (me == nil or me:GetAttribute("InMenu"))
	end
	state.ChildAdded:Connect(function(c)
		if c.Name == "P" .. player.UserId then c.AttributeChanged:Connect(refreshTouch) end
	end)
	local me = state:FindFirstChild("P" .. player.UserId)
	if me then me.AttributeChanged:Connect(refreshTouch) end
	refreshTouch()
end

----------------------------------------------------------------------
-- Fond animé (local, propre à chaque map)
----------------------------------------------------------------------
local bgFolder
local bgMovers = {}

local function bgPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = bgFolder
	return p
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do e[k] = v end
	e.Parent = parent
	return e
end

local function addMover(part, kind, data)
	data.part = part
	data.kind = kind
	data.base = part.CFrame
	data.t = math.random() * 100
	table.insert(bgMovers, data)
end

local function buildBackground()
	if bgFolder then bgFolder:Destroy() end
	bgMovers = {}
	bgFolder = Instance.new("Folder")
	bgFolder.Name = "LocalBackground"
	bgFolder.Parent = workspace

	local map = Maps[state:GetAttribute("Map") or 1]
	if not map then return end
	local accent = map.icon or Color3.new(1, 1, 1)
	local style = map.bg or "clouds"
	local rng = Random.new(42)

	-- anneaux lumineux qui tournent derrière la scène (toutes les maps)
	for i = 1, 2 do
		local ring = bgPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, 70 + i * 30, 70 + i * 30),
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.85,
			CFrame = CFrame.new(O + Vector3.new(0, 15, -80 - i * 2)) * CFrame.Angles(0, math.rad(90), 0),
		})
		addMover(ring, "spin", { speed = (i == 1 and 0.15 or -0.1) })
	end

	if style == "clouds" or style == "sunset" then
		local cloudColor = style == "sunset" and Color3.fromRGB(255, 190, 160) or Color3.fromRGB(255, 255, 255)
		for i = 1, 14 do
			local base = O + Vector3.new(rng:NextNumber(-160, 160), rng:NextNumber(-40, 60), rng:NextNumber(-80, -40))
			local scale = rng:NextNumber(0.7, 1.6)
			for j = 1, 3 do
				local puff = bgPart({
					Shape = Enum.PartType.Ball,
					Size = Vector3.new(14, 14, 14) * scale * (j == 2 and 1.3 or 1),
					Color = cloudColor,
					Transparency = 0.35,
					CFrame = CFrame.new(base + Vector3.new((j - 2) * 9 * scale, (j == 2 and 3 or 0), 0)),
				})
				addMover(puff, "drift", { speed = 2 + (i % 3) })
			end
		end
		if style == "sunset" then
			local sun = bgPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(60, 60, 60),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 200, 120),
				CFrame = CFrame.new(O + Vector3.new(30, -5, -86)),
			})
			addMover(sun, "pulse", { amount = 0.05 })
			-- oiseaux / feuilles
			emitter(bgPart({ Size = Vector3.new(200, 1, 1), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 30, -30)) }), {
				Color = ColorSequence.new(Color3.fromRGB(90, 160, 70)),
				Size = NumberSequence.new(0.6),
				Rate = 4, Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(3, 6),
				SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(2, -1, 0),
				RotSpeed = NumberRange.new(-90, 90), LightEmission = 0.2,
			})
		end
	elseif style == "stars" then
		for i = 1, 90 do
			local star = bgPart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.5, 1.6),
				Material = Enum.Material.Neon,
				Color = (i % 4 == 0) and accent or Color3.new(1, 1, 1),
				CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-200, 200), rng:NextNumber(-60, 110), rng:NextNumber(-88, -60))),
			})
			addMover(star, "twinkle", { speed = rng:NextNumber(1, 4) })
		end
		-- planète
		local planet = bgPart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(50, 50, 50),
			Material = Enum.Material.Neon,
			Color = accent:Lerp(Color3.new(0, 0, 0), 0.4),
			CFrame = CFrame.new(O + Vector3.new(-70, 55, -85)),
		})
		addMover(planet, "bob", { amount = 2, speed = 0.3 })
		-- étoiles filantes
		emitter(bgPart({ Size = Vector3.new(250, 1, 1), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 90, -70)) }), {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
			Rate = 0.8, Lifetime = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(60, 80),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 0),
			LightEmission = 1, Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	elseif style == "lava" then
		-- volcans au loin
		for i = -1, 1 do
			local volcano = bgPart({
				Shape = Enum.PartType.Block,
				Size = Vector3.new(70, 70, 70),
				Color = Color3.fromRGB(45, 30, 30),
				Material = Enum.Material.Basalt,
				CFrame = CFrame.new(O + Vector3.new(i * 110, -30, -85)) * CFrame.Angles(0, 0, math.rad(45)),
			})
			local glow = bgPart({
				Size = Vector3.new(12, 3, 12),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 110, 30),
				CFrame = CFrame.new(O + Vector3.new(i * 110, 19, -85)),
			})
			addMover(glow, "pulse", { amount = 0.15 })
			emitter(glow, {
				Color = ColorSequence.new(Color3.fromRGB(80, 70, 70)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
				Rate = 3, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(6, 10),
				EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(3, 0, 0),
			})
			local _ = volcano
		end
		-- braises qui montent
		emitter(bgPart({ Size = Vector3.new(220, 1, 40), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, -34, -20)) }), {
			Color = ColorSequence.new(Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 60, 20)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Rate = 40, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(6, 14),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
			LightEmission = 1, Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
	elseif style == "city" then
		-- skyline lointaine
		for i = 1, 22 do
			local h = rng:NextNumber(40, 120)
			bgPart({
				Size = Vector3.new(rng:NextNumber(10, 20), h, 4),
				Color = Color3.fromRGB(15, 12, 30),
				CFrame = CFrame.new(O + Vector3.new(-220 + i * 20, -60 + h / 2, -84)),
			})
			if i % 2 == 0 then
				local sign = bgPart({
					Size = Vector3.new(6, 2, 0.4),
					Material = Enum.Material.Neon,
					Color = (i % 4 == 0) and Color3.fromRGB(255, 60, 180) or Color3.fromRGB(60, 220, 255),
					CFrame = CFrame.new(O + Vector3.new(-220 + i * 20, -60 + h - 8, -81.5)),
				})
				addMover(sign, "twinkle", { speed = rng:NextNumber(0.5, 2) })
			end
		end
		-- voitures volantes
		for i = 1, 6 do
			local car = bgPart({
				Size = Vector3.new(3, 1, 1.5),
				Material = Enum.Material.Neon,
				Color = (i % 2 == 0) and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 240, 200),
				CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-180, 180), 25 + i * 9, -55 - i * 3)),
			})
			addMover(car, "drift", { speed = (i % 2 == 0 and 1 or -1) * rng:NextNumber(15, 30) })
		end
		-- pluie
		emitter(bgPart({ Size = Vector3.new(220, 1, 60), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 70, -10)) }), {
			Color = ColorSequence.new(Color3.fromRGB(150, 170, 255)),
			Size = NumberSequence.new(0.12), Transparency = NumberSequence.new(0.4),
			Rate = 200, Lifetime = NumberRange.new(1.2, 1.6), Speed = NumberRange.new(80, 100),
			EmissionDirection = Enum.NormalId.Bottom, LightEmission = 0.3,
		})
		-- lune
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(30, 30, 30), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(230, 220, 255), CFrame = CFrame.new(O + Vector3.new(60, 70, -88)) })
	elseif style == "forest" then
		for i = 1, 16 do
			local x = -200 + i * 25 + rng:NextNumber(-6, 6)
			local h = rng:NextNumber(60, 110)
			bgPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 5, 5), Color = Color3.fromRGB(35, 25, 20),
				CFrame = CFrame.new(O + Vector3.new(x, -40 + h / 2, -80)) * CFrame.Angles(0, 0, math.rad(90)) })
			bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(30, 30, 30) * rng:NextNumber(0.8, 1.3),
				Color = Color3.fromRGB(20, 55, 40), CFrame = CFrame.new(O + Vector3.new(x, -40 + h, -80)) })
		end
		-- lucioles
		emitter(bgPart({ Size = Vector3.new(160, 40, 50), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 10, -20)) }), {
			Color = ColorSequence.new(Color3.fromRGB(200, 255, 120)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 0) }),
			Rate = 25, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.5, 2),
			SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
		})
		-- rayons de lune
		for i = 1, 3 do
			local ray = bgPart({ Size = Vector3.new(8, 160, 0.4), Material = Enum.Material.Neon,
				Color = Color3.fromRGB(180, 255, 220), Transparency = 0.85,
				CFrame = CFrame.new(O + Vector3.new(-60 + i * 40, 30, -60)) * CFrame.Angles(0, 0, math.rad(20)) })
			addMover(ray, "pulse", { amount = 0.06 })
		end
	elseif style == "beach" then
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(40, 40, 40), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 240, 170), CFrame = CFrame.new(O + Vector3.new(-60, 60, -88)) })
		-- vagues
		for i = 1, 5 do
			local wave = bgPart({ Size = Vector3.new(400, 0.6, 3), Material = Enum.Material.Neon,
				Color = Color3.fromRGB(220, 245, 255), Transparency = 0.5,
				CFrame = CFrame.new(O + Vector3.new(0, -17.3, -10 - i * 14)) })
			addMover(wave, "wave", { amount = 1.2, speed = 0.6 + i * 0.1 })
		end
		-- îlots au loin
		for i = 1, 3 do
			bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(50, 20, 50), Color = Color3.fromRGB(80, 160, 90),
				Material = Enum.Material.Grass, CFrame = CFrame.new(O + Vector3.new(-120 + i * 90, -20, -80)) })
		end
		-- nuages
		for i = 1, 8 do
			local base = O + Vector3.new(rng:NextNumber(-160, 160), rng:NextNumber(40, 80), rng:NextNumber(-85, -60))
			for j = 1, 3 do
				local puff = bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12) * (j == 2 and 1.3 or 1),
					Color = Color3.new(1, 1, 1), Transparency = 0.25,
					CFrame = CFrame.new(base + Vector3.new((j - 2) * 9, (j == 2) and 3 or 0, 0)) })
				addMover(puff, "drift", { speed = 3 })
			end
		end
		-- mouettes
		emitter(bgPart({ Size = Vector3.new(200, 1, 1), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 50, -50)) }), {
			Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.8),
			Rate = 1, Lifetime = NumberRange.new(15, 20), Speed = NumberRange.new(5, 8),
			EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(10, 10),
		})
	elseif style == "spooky" then
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(45, 45, 45), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 250, 220), CFrame = CFrame.new(O + Vector3.new(40, 60, -88)) })
		-- collines
		for i = 1, 5 do
			bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(80, 50, 30), Color = Color3.fromRGB(20, 12, 30),
				CFrame = CFrame.new(O + Vector3.new(-200 + i * 80, -45, -82)) })
		end
		-- chauves-souris
		for i = 1, 10 do
			local bat = bgPart({ Size = Vector3.new(2.5, 0.5, 0.5), Color = Color3.fromRGB(10, 5, 15),
				CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-150, 150), rng:NextNumber(20, 70), rng:NextNumber(-70, -40))) })
			addMover(bat, "drift", { speed = rng:NextNumber(8, 16) * (i % 2 == 0 and 1 or -1) })
		end
		-- fantômes
		for i = 1, 4 do
			local ghost = bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Material = Enum.Material.Neon,
				Color = Color3.fromRGB(200, 220, 255), Transparency = 0.6,
				CFrame = CFrame.new(O + Vector3.new(-90 + i * 45, rng:NextNumber(10, 40), -45)) })
			addMover(ghost, "wave", { amount = 4, speed = 0.3 + i * 0.1 })
		end
		emitter(bgPart({ Size = Vector3.new(200, 1, 60), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, -25, -20)) }), {
			Color = ColorSequence.new(Color3.fromRGB(120, 90, 160)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) }),
			Rate = 6, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(1, 3),
			EmissionDirection = Enum.NormalId.Top,
		})
	elseif style == "space" then
		for i = 1, 120 do
			local star = bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.4, 1.3),
				Material = Enum.Material.Neon, Color = Color3.new(1, 1, 1),
				CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-220, 220), rng:NextNumber(-80, 120), rng:NextNumber(-88, -60))) })
			addMover(star, "twinkle", { speed = rng:NextNumber(0.5, 3) })
		end
		-- la Terre
		local earth = bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(120, 120, 120), Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(50, 110, 210), CFrame = CFrame.new(O + Vector3.new(-40, -95, -88)) })
		addMover(earth, "spin", { speed = 0.02 })
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(126, 126, 126), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(120, 200, 255), Transparency = 0.85, CFrame = CFrame.new(O + Vector3.new(-40, -95, -89)) })
		for i = 1, 6 do
			bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(30, 8, 30) * rng:NextNumber(0.6, 1.2),
				Color = Color3.fromRGB(70, 160, 80), Material = Enum.Material.Grass,
				CFrame = CFrame.new(O + Vector3.new(-40 + rng:NextNumber(-45, 45), -95 + rng:NextNumber(10, 55), -30)) })
		end
		-- astéroïdes
		for i = 1, 8 do
			local rock = bgPart({ Size = Vector3.new(4, 3, 3) * rng:NextNumber(0.5, 1.5), Material = Enum.Material.Rock,
				Color = Color3.fromRGB(110, 100, 95),
				CFrame = CFrame.new(O + Vector3.new(rng:NextNumber(-180, 180), rng:NextNumber(30, 90), rng:NextNumber(-70, -45))) })
			addMover(rock, "drift", { speed = rng:NextNumber(4, 10) })
		end
	elseif style == "sakura" then
		-- mont enneigé
		bgPart({ Shape = Enum.PartType.Block, Size = Vector3.new(120, 120, 4), Color = Color3.fromRGB(150, 130, 170),
			CFrame = CFrame.new(O + Vector3.new(40, -40, -86)) * CFrame.Angles(0, 0, math.rad(45)) })
		bgPart({ Shape = Enum.PartType.Block, Size = Vector3.new(36, 36, 4.2), Color = Color3.fromRGB(255, 255, 255),
			CFrame = CFrame.new(O + Vector3.new(40, 30, -85.8)) * CFrame.Angles(0, 0, math.rad(45)) })
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(35, 35, 35), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 120, 100), CFrame = CFrame.new(O + Vector3.new(-50, 40, -88)) })
		-- pétales qui tombent
		emitter(bgPart({ Size = Vector3.new(200, 1, 60), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 60, -10)) }), {
			Color = ColorSequence.new(Color3.fromRGB(255, 180, 210), Color3.fromRGB(255, 220, 235)),
			Size = NumberSequence.new(0.5), Rate = 35, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(3, 6),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(3, -0.5, 0), RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360),
			LightEmission = 0.2,
		})
		for i = 1, 6 do
			local cloud = bgPart({ Size = Vector3.new(40, 2, 6), Color = Color3.fromRGB(255, 230, 240), Transparency = 0.4,
				CFrame = CFrame.new(O + Vector3.new(-150 + i * 50, rng:NextNumber(20, 60), -75)) })
			addMover(cloud, "drift", { speed = 2 })
		end
	elseif style == "desert" then
		bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(50, 50, 50), Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 230, 150), CFrame = CFrame.new(O + Vector3.new(70, 65, -88)) })
		-- dunes
		for i = 1, 6 do
			bgPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(100, 40, 30), Color = Color3.fromRGB(235, 195, 130),
				Material = Enum.Material.Sand, CFrame = CFrame.new(O + Vector3.new(-250 + i * 85, -48, -84)) })
		end
		-- tempête de sable
		emitter(bgPart({ Size = Vector3.new(1, 60, 60), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(-120, 10, -15)) }), {
			Color = ColorSequence.new(Color3.fromRGB(230, 200, 150)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }),
			Rate = 25, Lifetime = NumberRange.new(5, 7), Speed = NumberRange.new(40, 60),
			EmissionDirection = Enum.NormalId.Right, SpreadAngle = Vector2.new(5, 10),
		})
		-- vautours
		for i = 1, 3 do
			local bird = bgPart({ Size = Vector3.new(3, 0.4, 0.6), Color = Color3.fromRGB(50, 35, 30),
				CFrame = CFrame.new(O + Vector3.new(-40 + i * 30, 60 + i * 5, -60)) })
			addMover(bird, "wave", { amount = 6, speed = 0.25 })
		end
	elseif style == "snow" then
		for i = 1, 8 do
			local peak = bgPart({
				Size = Vector3.new(50, 50, 50) * rng:NextNumber(0.8, 1.4),
				Color = Color3.fromRGB(220, 235, 250),
				Material = Enum.Material.Glacier,
				CFrame = CFrame.new(O + Vector3.new(-180 + i * 45, -45, -86)) * CFrame.Angles(0, 0, math.rad(45)),
			})
			local _ = peak
		end
		-- neige qui tombe
		emitter(bgPart({ Size = Vector3.new(220, 1, 60), Transparency = 1, CFrame = CFrame.new(O + Vector3.new(0, 70, -10)) }), {
			Color = ColorSequence.new(Color3.new(1, 1, 1)),
			Size = NumberSequence.new(0.35),
			Rate = 80, Lifetime = NumberRange.new(8, 10), Speed = NumberRange.new(6, 9),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15),
			Acceleration = Vector3.new(2, 0, 0), LightEmission = 0.5,
		})
		-- aurore boréale
		for i = 1, 3 do
			local aurora = bgPart({
				Size = Vector3.new(160, 14, 0.5),
				Material = Enum.Material.Neon,
				Color = (i == 2) and Color3.fromRGB(120, 255, 200) or Color3.fromRGB(90, 200, 255),
				Transparency = 0.7,
				CFrame = CFrame.new(O + Vector3.new(0, 70 + i * 10, -84)) * CFrame.Angles(0, 0, math.rad(i * 4 - 8)),
			})
			addMover(aurora, "wave", { amount = 5, speed = 0.4 + i * 0.1 })
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	for _, m in ipairs(bgMovers) do
		local p = m.part
		if p.Parent then
			m.t += dt
			if m.kind == "spin" then
				p.CFrame = m.base * CFrame.Angles(m.t * m.speed, 0, 0)
			elseif m.kind == "drift" then
				local x = (m.base.Position.X - O.X + m.t * m.speed + 180) % 360 - 180
				p.CFrame = CFrame.new(O.X + x, m.base.Position.Y, m.base.Position.Z)
			elseif m.kind == "twinkle" then
				p.Transparency = 0.5 + 0.5 * math.sin(m.t * m.speed)
			elseif m.kind == "pulse" then
				p.Transparency = m.amount + m.amount * math.sin(m.t * 2)
			elseif m.kind == "bob" then
				p.CFrame = m.base + Vector3.new(0, math.sin(m.t * m.speed) * m.amount, 0)
			elseif m.kind == "wave" then
				p.CFrame = m.base * CFrame.new(math.sin(m.t * m.speed) * m.amount * 3, math.sin(m.t * m.speed * 1.3) * m.amount, 0)
			end
		end
	end
end)

state:GetAttributeChangedSignal("Map"):Connect(buildBackground)
buildBackground()

----------------------------------------------------------------------
-- Arrêt sur image local (hitstop) + accroche au bord
----------------------------------------------------------------------
local frozenToken = nil
local hanging = nil
local ledgeCooldown = 0

fx.clearLocal = function(root)
	if (frozenToken or hanging) and root then root.Anchored = false end
	frozenToken = nil
	hanging = nil
end

fx.freeze = function(duration)
	local _, root = getChar()
	if not root or koLock then return end
	local token = {}
	frozenToken = token
	local vel = root.AssemblyLinearVelocity
	root.Anchored = true
	task.delay(duration, function()
		if frozenToken == token then
			frozenToken = nil
			if not hanging and not koLock then
				root.Anchored = false
				root.AssemblyLinearVelocity = vel
			end
		end
	end)
end

local function ledgeRot(dirX)
	return CFrame.Angles(0, math.rad(dirX > 0 and -90 or 90), 0)
end

local function releaseLedge(climb, jumpUp)
	local char, root = getChar()
	if not hanging or not root then hanging = nil return end
	local h = hanging
	hanging = nil
	ledgeCooldown = os.clock() + 0.6
	root.Anchored = false
	if climb then
		root.CFrame = CFrame.new(h.edgeX - h.side * 2.5, h.top + 3.2, O.Z) * ledgeRot(-h.side)
		root.AssemblyLinearVelocity = jumpUp and Vector3.new(0, Config.AIR_JUMP_VELOCITY, 0) or Vector3.zero
	else
		root.AssemblyLinearVelocity = Vector3.new(h.side * 5, -5, 0)
	end
	if char and fx.pose then fx.pose(char, "ShieldEnd") end
end

fx.onPress = function(action)
	if not hanging then return false end
	local toward = -hanging.side
	if action == "Jump" then
		releaseLedge(true, true)
	elseif action == "Up" or action == "Attack" or (action == "Right" and toward == 1) or (action == "Left" and toward == -1) then
		releaseLedge(true, false)
	elseif action == "Down" or (action == "Right" and toward == -1) or (action == "Left" and toward == 1) then
		releaseLedge(false)
	end
	return true
end

RunService.Stepped:Connect(function()
	local char, root, hum = getChar()
	if not root or koLock then return end
	if hanging then
		if os.clock() - hanging.t0 > 3 then releaseLedge(false) end -- lâche après 3 s
		return
	end
	if root.Anchored or os.clock() < stunUntil or os.clock() < ledgeCooldown then return end
	if hum.FloorMaterial ~= Enum.Material.Air or root.AssemblyLinearVelocity.Y > 2 then return end
	local arena = workspace:FindFirstChild("SmashArena")
	local solids = arena and arena:FindFirstChild("Solids")
	if not solids then return end
	local pos = root.Position
	for _, p in ipairs(solids:GetChildren()) do
		local top = p.Position.Y + p.Size.Y / 2
		for _, side in ipairs({ -1, 1 }) do
			local edgeX = p.Position.X + side * p.Size.X / 2
			local outside = (pos.X - edgeX) * side > -0.5
			if outside and math.abs(pos.X - edgeX) < 3 and pos.Y < top + 1 and pos.Y > top - 6 then
				hanging = { edgeX = edgeX, top = top, side = side, t0 = os.clock() }
				facing = -side
				airJumps = maxAirJumps()
				recoveryReady = true
				root.Anchored = true
				root.CFrame = CFrame.new(edgeX + side * 1.2, top - 2.2, O.Z) * ledgeRot(-side)
				if fx.pose then fx.pose(char, "Ledge") end
				if fx.toast then fx.toast("Accroché ! Saut / Haut = remonter • Bas = lâcher") end
				return
			end
		end
	end
end)

----------------------------------------------------------------------
-- Chiffres de dégâts flottants
----------------------------------------------------------------------
fx.dmgNum = function(pos, amount, big)
	if typeof(pos) ~= "Vector3" then return end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = pos + Vector3.new((math.random() - 0.5) * 2, 3, 2)
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(big and 120 or 80, big and 60 or 40)
	bb.AlwaysOnTop = true
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 1, 0)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = tostring(amount) .. "%"
	t.TextColor3 = big and Color3.fromRGB(255, 80, 60) or Color3.fromRGB(255, 240, 120)
	t.TextStrokeTransparency = 0
	t.Parent = bb
	TS:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TS:Create(t, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.3),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	game:GetService("Debris"):AddItem(anchor, 0.9)
end

----------------------------------------------------------------------
-- Alerte danger : bords rouges qui clignotent au-dessus de 100 %
----------------------------------------------------------------------
local danger = Instance.new("Frame")
danger.BackgroundTransparency = 1
danger.Size = UDim2.new(1, 0, 1, 0)
danger.ZIndex = 4
danger.Visible = false
danger.Parent = gui
local function edge(pos, size, rotation)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(255, 20, 20)
	f.Position = pos
	f.Size = size
	f.ZIndex = 4
	f.Parent = danger
	local g = Instance.new("UIGradient", f)
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(0.1, 1)
	return f
end
edge(UDim2.new(0, 0, 0, 0), UDim2.new(0, 90, 1, 0), 0)      -- gauche
edge(UDim2.new(1, -90, 0, 0), UDim2.new(0, 90, 1, 0), 180)  -- droite
edge(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 70), 90)     -- haut
edge(UDim2.new(0, 0, 1, -70), UDim2.new(1, 0, 0, 70), -90)  -- bas

RunService.RenderStepped:Connect(function()
	local me = state:FindFirstChild("P" .. player.UserId)
	local dmg = me and me:GetAttribute("Damage") or 0
	local on = me ~= nil and dmg >= 100 and me:GetAttribute("InRound") and (me:GetAttribute("Stocks") or 0) > 0
		and not me:GetAttribute("InMenu")
	danger.Visible = on and true or false
	if on then
		local speed = 3 + math.clamp((dmg - 100) / 50, 0, 3)
		local a = 0.5 + 0.5 * math.sin(os.clock() * speed * math.pi)
		for _, f in ipairs(danger:GetChildren()) do
			f.BackgroundTransparency = 0.15 + a * 0.6
		end
	end
end)

----------------------------------------------------------------------
-- Mode entraînement : bouton du menu + panneau de réglage du sac
----------------------------------------------------------------------
local trainButton = Instance.new("TextButton")
trainButton.AnchorPoint = Vector2.new(0.5, 0.5)
trainButton.Position = UDim2.new(0.5, 0, 0.62, 68)
trainButton.Size = UDim2.new(0, 280, 0, 46)
trainButton.BackgroundColor3 = Color3.fromRGB(70, 110, 200)
trainButton.Font = Enum.Font.FredokaOne
trainButton.TextScaled = true
trainButton.TextColor3 = Color3.new(1, 1, 1)
trainButton.Text = "ENTRAÎNEMENT"
trainButton.ZIndex = 22
trainButton.Parent = menu
Instance.new("UICorner", trainButton).CornerRadius = UDim.new(0, 12)
local tPad = Instance.new("UIPadding", trainButton)
tPad.PaddingTop, tPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
trainButton.MouseButton1Click:Connect(function()
	local ph = state:GetAttribute("Phase")
	if ph == "Waiting" or ph == "Training" then
		actionRemote:FireServer("Training")
	elseif fx.toast then
		fx.toast("Un match est en cours : l'entraînement sera dispo après.")
	end
end)
local function refreshTrainButton()
	local ph = state:GetAttribute("Phase")
	local ok = ph == "Waiting" or ph == "Training"
	trainButton.BackgroundColor3 = ok and Color3.fromRGB(70, 110, 200) or Color3.fromRGB(70, 70, 90)
	trainButton.Text = ok and "ENTRAÎNEMENT" or "ENTRAÎNEMENT (match en cours)"
end
state:GetAttributeChangedSignal("Phase"):Connect(refreshTrainButton)
refreshTrainButton()

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 100)
panel.Size = UDim2.fromOffset(220, 210)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BackgroundTransparency = 0.2
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", panel).Color = Color3.fromRGB(70, 110, 200)

local pTitle = Instance.new("TextLabel")
pTitle.BackgroundTransparency = 1
pTitle.Position = UDim2.new(0, 10, 0, 6)
pTitle.Size = UDim2.new(1, -20, 0, 24)
pTitle.Font = Enum.Font.FredokaOne
pTitle.TextScaled = true
pTitle.TextColor3 = Color3.new(1, 1, 1)
pTitle.Text = "ENTRAÎNEMENT"
pTitle.Parent = panel

local bagLabel = Instance.new("TextLabel")
bagLabel.BackgroundTransparency = 1
bagLabel.Position = UDim2.new(0, 10, 0, 34)
bagLabel.Size = UDim2.new(1, -20, 0, 26)
bagLabel.Font = Enum.Font.GothamBold
bagLabel.TextScaled = true
bagLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
bagLabel.Text = "Sac : 0%"
bagLabel.Parent = panel

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.new(0, 10, 0, 66)
grid.Size = UDim2.new(1, -20, 0, 90)
grid.Parent = panel
local gl = Instance.new("UIGridLayout", grid)
gl.CellSize = UDim2.new(0.33, -4, 0, 40)
gl.CellPadding = UDim2.fromOffset(6, 6)
gl.SortOrder = Enum.SortOrder.LayoutOrder

local function bagDamage()
	local bag = state:FindFirstChild("BAG")
	return bag and bag:GetAttribute("Damage") or 0
end
local function smallButton(parent, text, order, color, onClick)
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", b)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	b.MouseButton1Click:Connect(onClick)
	return b
end
local blue = Color3.fromRGB(50, 70, 130)
smallButton(grid, "-10%", 1, blue, function() actionRemote:FireServer("BagDamage", math.max(0, bagDamage() - 10)) end)
smallButton(grid, "+10%", 2, blue, function() actionRemote:FireServer("BagDamage", bagDamage() + 10) end)
smallButton(grid, "0%", 3, blue, function() actionRemote:FireServer("BagDamage", 0) end)
smallButton(grid, "50%", 4, blue, function() actionRemote:FireServer("BagDamage", 50) end)
smallButton(grid, "100%", 5, blue, function() actionRemote:FireServer("BagDamage", 100) end)
smallButton(grid, "150%", 6, blue, function() actionRemote:FireServer("BagDamage", 150) end)

local quit = smallButton(panel, "Quitter", 0, Color3.fromRGB(180, 60, 60), function()
	actionRemote:FireServer("LeaveTraining")
end)
quit.Position = UDim2.new(0, 10, 1, -46)
quit.Size = UDim2.new(1, -20, 0, 36)

RunService.Heartbeat:Connect(function()
	local me = state:FindFirstChild("P" .. player.UserId)
	panel.Visible = me ~= nil and me:GetAttribute("Training") == true
	if panel.Visible then bagLabel.Text = "Sac : " .. bagDamage() .. "%" end
end)

----------------------------------------------------------------------
-- Plateformes mobiles : même mouvement que le serveur, calculé localement (fluide)
----------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
RunService.Stepped:Connect(function()
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
-- Écran de victoire : bannière + confettis
----------------------------------------------------------------------
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.new(-0.6, 0, 0.2, 0)
banner.Size = UDim2.new(1.2, 0, 0, 110)
banner.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
banner.BorderSizePixel = 0
banner.Rotation = -4
banner.Visible = false
banner.ZIndex = 8
banner.Parent = gui
local bannerGrad = Instance.new("UIGradient", banner)
bannerGrad.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 120, 30))
local bannerText = Instance.new("TextLabel")
bannerText.BackgroundTransparency = 1
bannerText.Size = UDim2.new(1, 0, 1, 0)
bannerText.Font = Enum.Font.FredokaOne
bannerText.TextScaled = true
bannerText.TextColor3 = Color3.new(1, 1, 1)
bannerText.TextStrokeTransparency = 0
bannerText.ZIndex = 9
bannerText.Parent = banner
local bPad = Instance.new("UIPadding", bannerText)
bPad.PaddingTop, bPad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)

local confettiParts = {}
local function clearConfetti()
	for _, p in ipairs(confettiParts) do p:Destroy() end
	confettiParts = {}
end

local function showVictory()
	local ids = state:GetAttribute("Winner") or ""
	if ids == "" then
		banner.Visible = false
		clearConfetti()
		return
	end
	bannerText.Text = state:GetAttribute("Message") or "VICTOIRE !"
	banner.Visible = true
	banner.Position = UDim2.new(-0.6, 0, 0.2, 0)
	TS:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0.2, 0) }):Play()
	sfx("Beep", 0.7, 0.8)
	task.delay(0.15, function() sfx("Beep", 1.0, 0.8) end)
	task.delay(0.3, function() sfx("Beep", 1.4, 0.9) end)
	-- confettis au-dessus des gagnants
	for id in string.gmatch(ids, "[^,]+") do
		local info = state:FindFirstChild(id)
		local ref = info and info:FindFirstChild("Character")
		local r = ref and ref.Value and ref.Value:FindFirstChild("HumanoidRootPart")
		if r then
			local src = Instance.new("Part")
			src.Anchored = true
			src.CanCollide = false
			src.CanQuery = false
			src.Transparency = 1
			src.Size = Vector3.new(12, 1, 4)
			src.Position = r.Position + Vector3.new(0, 12, 0)
			src.Parent = workspace
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 150, 255)),
			})
			e.Size = NumberSequence.new(0.35)
			e.Lifetime = NumberRange.new(2, 3)
			e.Speed = NumberRange.new(2, 6)
			e.SpreadAngle = Vector2.new(60, 60)
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Acceleration = Vector3.new(0, -12, 0)
			e.RotSpeed = NumberRange.new(-200, 200)
			e.Rotation = NumberRange.new(0, 360)
			e.Rate = 60
			e.LightEmission = 0.3
			e.Parent = src
			table.insert(confettiParts, src)
		end
	end
end
state:GetAttributeChangedSignal("Winner"):Connect(function()
	clearConfetti()
	showVictory()
end)

----------------------------------------------------------------------
-- Menu : réglage des bots + classement
----------------------------------------------------------------------
local LEVELS = { "Mix", "Facile", "Moyen", "Difficile", "Expert" }
local botRow = Instance.new("Frame")
botRow.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
botRow.BackgroundTransparency = 0.2
botRow.AnchorPoint = Vector2.new(0.5, 0)
botRow.Position = UDim2.new(0.5, 0, 0.62, 100)
botRow.Size = UDim2.fromOffset(420, 44)
botRow.ZIndex = 22
botRow.Parent = menu
Instance.new("UICorner", botRow).CornerRadius = UDim.new(0, 10)
local botLayout = Instance.new("UIListLayout", botRow)
botLayout.FillDirection = Enum.FillDirection.Horizontal
botLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
botLayout.VerticalAlignment = Enum.VerticalAlignment.Center
botLayout.Padding = UDim.new(0, 6)
botLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function rowLabel(text, width, order)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(width, 30)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	l.LayoutOrder = order
	l.ZIndex = 23
	l.Parent = botRow
	return l
end
local function rowButton(text, width, order, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(width, 32)
	b.BackgroundColor3 = Color3.fromRGB(60, 70, 120)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = order
	b.ZIndex = 23
	b.Parent = botRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", b)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	b.MouseButton1Click:Connect(onClick)
	return b
end
local function sendBots(count, level)
	actionRemote:FireServer("BotSettings", count, level)
end
rowLabel("Bots :", 60, 1)
rowButton("-", 32, 2, function() sendBots((state:GetAttribute("BotCount") or 3) - 1, state:GetAttribute("BotLevel")) end)
local countLabel = rowLabel("3", 30, 3)
rowButton("+", 32, 4, function() sendBots((state:GetAttribute("BotCount") or 3) + 1, state:GetAttribute("BotLevel")) end)
rowLabel("Niveau :", 70, 5)
local levelButton = rowButton("Mix", 130, 6, function()
	local cur = state:GetAttribute("BotLevel") or "Mix"
	local idx = table.find(LEVELS, cur) or 1
	sendBots(state:GetAttribute("BotCount") or 3, LEVELS[(idx % #LEVELS) + 1])
end)
local function refreshBotRow()
	countLabel.Text = tostring(state:GetAttribute("BotCount") or 3)
	levelButton.Text = state:GetAttribute("BotLevel") or "Mix"
end
state:GetAttributeChangedSignal("BotCount"):Connect(refreshBotRow)
state:GetAttributeChangedSignal("BotLevel"):Connect(refreshBotRow)
refreshBotRow()

local board = Instance.new("TextLabel")
board.AnchorPoint = Vector2.new(0, 0.5)
board.Position = UDim2.new(0, 20, 0.5, 0)
board.Size = UDim2.fromOffset(260, 260)
board.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
board.BackgroundTransparency = 0.2
board.Font = Enum.Font.Gotham
board.TextSize = 15
board.TextColor3 = Color3.new(1, 1, 1)
board.TextXAlignment = Enum.TextXAlignment.Left
board.TextYAlignment = Enum.TextYAlignment.Top
board.TextWrapped = true
board.ZIndex = 22
board.Parent = menu
Instance.new("UICorner", board).CornerRadius = UDim.new(0, 12)
local boardPad = Instance.new("UIPadding", board)
boardPad.PaddingLeft, boardPad.PaddingTop, boardPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 10), UDim.new(0, 12)
local function refreshBoard()
	local lb = state:GetAttribute("Leaderboard") or ""
	board.Text = "🏆 MEILLEURS JOUEURS\n\n" .. (lb ~= "" and lb or "Chargement...")
end
state:GetAttributeChangedSignal("Leaderboard"):Connect(refreshBoard)
refreshBoard()
