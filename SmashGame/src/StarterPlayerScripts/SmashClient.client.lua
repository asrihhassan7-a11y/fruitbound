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
local airJumps = Config.AIR_JUMPS
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
	elseif airJumps > 0 then
		airJumps -= 1
		root.AssemblyLinearVelocity = Vector3.new(moveAxis() * Config.WALK_SPEED, Config.AIR_JUMP_VELOCITY, 0)
	end
end

local function press(action)
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
				and state:GetAttribute("Phase") == "Fight" then
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
	if action == "Smash" and smashStart then
		local charge = math.min(os.clock() - smashStart, Config.SMASH_CHARGE_MAX)
		smashStart = nil
		actionRemote:FireServer("Smash", dirInput(), facing, charge)
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
	elseif kind == "KOStart" then
		koLock = true
		held = {}
		smashStart = nil
		return
	end
	if not root then return end
	if kind == "Knock" then
		stunUntil = os.clock() + b
		hum.PlatformStand = true
		root.AssemblyLinearVelocity = a
		airJumps = Config.AIR_JUMPS
		recoveryReady = true
	elseif kind == "Reset" then
		koLock = false
		stunUntil = 0
		hum.PlatformStand = false
		root.AssemblyLinearVelocity = Vector3.zero
		airJumps = Config.AIR_JUMPS
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
		airJumps = Config.AIR_JUMPS
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

	if Config.CAMERA_FOLLOW then
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
			targetDist = math.clamp(spread * 0.8 + 18, Config.CAMERA_MIN_DIST, Config.CAMERA_MAX_DIST)
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
local function makeCard(info)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 150, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	card.BackgroundTransparency = 0.25
	card.Parent = bar
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", card)
	stroke.Thickness = 3

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -10, 0, 22)
	name.Position = UDim2.new(0, 5, 0, 4)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Parent = card

	local pct = Instance.new("TextLabel")
	pct.BackgroundTransparency = 1
	pct.Size = UDim2.new(1, -10, 0, 52)
	pct.Position = UDim2.new(0, 5, 0, 26)
	pct.Font = Enum.Font.FredokaOne
	pct.TextScaled = true
	pct.TextStrokeTransparency = 0
	pct.Parent = card

	local stocks = Instance.new("TextLabel")
	stocks.BackgroundTransparency = 1
	stocks.Size = UDim2.new(1, -10, 0, 20)
	stocks.Position = UDim2.new(0, 5, 0, 80)
	stocks.Font = Enum.Font.GothamBold
	stocks.TextScaled = true
	stocks.Parent = card

	local shieldBar = Instance.new("Frame")
	shieldBar.BorderSizePixel = 0
	shieldBar.Position = UDim2.new(0, 8, 1, -6)
	shieldBar.Size = UDim2.new(1, -16, 0, 3)
	shieldBar.Parent = card

	local function refresh()
		local c = info:GetAttribute("Color") or Color3.new(1, 1, 1)
		local dmg = info:GetAttribute("Damage") or 0
		local st = info:GetAttribute("Stocks") or 0
		card.LayoutOrder = info:GetAttribute("Slot") or 0
		stroke.Color = c
		name.Text = info:GetAttribute("DisplayName") or info.Name
		pct.Text = dmg .. "%"
		local t = math.clamp(dmg / 150, 0, 1)
		pct.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 60), math.min(t * 2, 1)):Lerp(Color3.fromRGB(200, 20, 20), math.max(t * 2 - 1, 0))
		stocks.Text = st > 0 and string.rep("● ", st) or "ÉLIMINÉ"
		stocks.TextColor3 = c
		shieldBar.BackgroundColor3 = c
		shieldBar.Size = UDim2.new((info:GetAttribute("Shield") or 1), -16, 0, 3)
		card.BackgroundTransparency = st > 0 and 0.25 or 0.7
		-- cacher ceux qui sont sur le menu
		card.Visible = not info:GetAttribute("InMenu")
			and (info:GetAttribute("InRound") or state:GetAttribute("Phase") ~= "Fight")
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
local sizeLimit = Instance.new("UISizeConstraint", voteFrame)
sizeLimit.MaxSize = Vector2.new(1000, 290)

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
list.Size = UDim2.new(1, -24, 1, -72)
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
playButton.Position = UDim2.new(0.5, 0, 0.55, 0)
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
menuInfo.Position = UDim2.new(0.5, 0, 0.55, 60)
menuInfo.Size = UDim2.new(0.9, 0, 0, 120)
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
lastResult.Position = UDim2.new(0.5, 0, 0.55, -50)
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
