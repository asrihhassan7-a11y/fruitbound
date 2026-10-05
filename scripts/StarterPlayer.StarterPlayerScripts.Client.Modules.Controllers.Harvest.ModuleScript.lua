local readyNotify
--> Harvest (client)
-- Shows YOUR plants: each harvest picks one "Bloom" (flower / veggie / mushroom), then they regrow with a little pop.
-- Also shows the food you got when a plant is fully harvested.

local _L = _G._L

local Network
local Audio

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

---------->
local Harvest = {
	-- [player] = {position = Vector3, t = os.clock()} : the plant each player is harvesting right now
	_targets = {},
}

-- How long fruits/pets stay at the plant after the last harvest click
local STAY_TIME = 1.5

-- Position of the plant a player is harvesting (nil if they stopped)
function Harvest.getTarget(player)
	local t = Harvest._targets[player]
	if t and os.clock() - t.t <= STAY_TIME then
		return t.position
	end
	return nil
end

-- Where helper number `index` (of `count`) should stand around the plant
function Harvest.getRingCFrame(plantPosition, index, count, size, raycastParams)
	count = math.max(count, 1)
	local angle = (index / count) * math.pi * 2
	local radius = 3.6 + math.max(size.X, size.Z) * 0.5 + math.max(0, count - 4) * 0.35
	local flat = plantPosition + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

	local y = plantPosition.Y - 2.75 + size.Y / 2
	local hit = workspace:Raycast(flat + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), raycastParams)
	if hit then
		y = hit.Position.Y + size.Y / 2
	end

	local pos = Vector3.new(flat.X, y, flat.Z)
	return CFrame.lookAt(pos, Vector3.new(plantPosition.X, y, plantPosition.Z))
end

local FOOD_EMOJI = {
	Common = "🍀", Rare = "🍄", Epic = "🌸", Legendary = "🌻",
	Mythical = "🌺", Huge = "🌿", Secret = "🌀", Divine = "✨",
}

local function findBush(bushId)
	for _, model in ipairs(CollectionService:GetTagged("HarvestBush")) do
		if model:GetAttribute("BushId") == bushId then
			return model
		end
	end
	return nil
end

local function setFruitVisible(fruit, visible, animate)
	local full = fruit:GetAttribute("FullSize")
	if not full then
		full = fruit.Size
		fruit:SetAttribute("FullSize", full)
	end
	local parts = {fruit}
	for _, d in ipairs(fruit:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if visible then
		for _, p in ipairs(parts) do
			p.LocalTransparencyModifier = 0
		end
		if animate then
			fruit.Size = full * 0.1
			TweenService:Create(fruit, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = full}):Play()
		else
			fruit.Size = full
		end
	else
		for _, p in ipairs(parts) do
			p.LocalTransparencyModifier = 1
		end
	end
end

-- Show the first `left` fruits (by Index), hide the rest
local function applyFruitCount(model, left, animate)
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" and d:IsA("BasePart") then
			local index = d:GetAttribute("Index") or 1
			local shouldShow = index <= left
			local isShown = d.LocalTransparencyModifier < 0.5
			if shouldShow ~= isShown then
				setFruitVisible(d, shouldShow, animate)
			end
		end
	end
end

local function bounce(model)
	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end
	for _, d in ipairs(model:GetChildren()) do
		if (d.Name == "Leaf" or d.Name == "Soil") and d:IsA("BasePart") then
			local full = d:GetAttribute("FullSize") or d.Size
			d:SetAttribute("FullSize", full)
			d.Size = full * 1.12
			TweenService:Create(d, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = full}):Play()
		end
	end
end

-- PICK ANIMATION: a copy of the picked bloom hops off the plant, arcs through the air,
-- spins and shrinks into your character, then pops into a little sparkle.
local RunService = game:GetService("RunService")
local POP_TIME = 0.22 -- the bloom jumps out of the plant
local FLY_TIME = 0.6 -- then flies into you (a bit longer when the plant is far, e.g. Auto Collect)

local function sparkle(position, color)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 0.2
	ball.Size = Vector3.one * 0.6
	ball.Position = position
	ball.Parent = workspace
	TweenService:Create(ball, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.one * 2.6, Transparency = 1}):Play()
	task.delay(0.3, function()
		ball:Destroy()
	end)
end

-- SOUND: soft pop when picked, collect "blip" when it reaches you; pitch rises on quick streaks
local streak, lastCollect = 0, 0
local function sfx(name, props)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name, props)
	end
end
local function collectSound()
	local now = os.clock()
	streak = if now - lastCollect < 1.2 then math.min(streak + 1, 8) else 0
	lastCollect = now
	sfx("Harvest_Collect", {speed = 1 + streak * 0.05 + (math.random() - 0.5) * 0.04})
end

local function flyBloom(bloom)
	local character = _L.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not bloom:IsDescendantOf(workspace) then
		return
	end

	local holder = Instance.new("Model")
	holder.Name = "PickedBloom"
	local copy = bloom:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local parts = {copy}
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.LocalTransparencyModifier = 0
	end
	copy.Size = bloom:GetAttribute("FullSize") or bloom.Size
	copy.Parent = holder
	holder.PrimaryPart = copy
	holder.Parent = workspace

	local color = copy.Color

	-- colored trail so you can follow it flying to you
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = copy
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = copy
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.FaceCamera = true
	trail.Parent = copy

	local start = copy.Position
	local popped = start + Vector3.new(0, 2.5, 0)
	local startCF = copy.CFrame - copy.Position
	local distance = (start - root.Position).Magnitude
	local flyTime = FLY_TIME + math.min(distance, 30) * 0.012
	local elapsed = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if not root.Parent then
			connection:Disconnect()
			holder:Destroy()
			return
		end

		-- 1) POP: jumps out of the plant and grows a little
		if elapsed < POP_TIME then
			local t = elapsed / POP_TIME
			local e = 1 - (1 - t) * (1 - t)
			holder:PivotTo(CFrame.new(start:Lerp(popped, e)) * startCF * CFrame.Angles(0, t * math.pi, 0))
			pcall(holder.ScaleTo, holder, 1 + e * 0.4)
			return
		end

		-- 2) FLY: arcs through the air into the player, spinning and shrinking
		local t = math.clamp((elapsed - POP_TIME) / flyTime, 0, 1)
		if t >= 1 then
			connection:Disconnect()
			sparkle(root.Position + Vector3.new(0, 1, 0), color)
			collectSound()
			holder:Destroy()
			return
		end
		local target = root.Position + Vector3.new(0, 1, 0)
		local mid = (popped + target) / 2 + Vector3.new(0, 3 + (popped - target).Magnitude * 0.25, 0)
		local e = t * t -- speeds up as it gets closer
		local a = popped:Lerp(mid, e)
		local b = mid:Lerp(target, e)
		local pos = a:Lerp(b, e)
		local spin = CFrame.Angles(0, math.pi + t * math.pi * 4, t * math.pi)
		holder:PivotTo(CFrame.new(pos) * startCF * spin)
		pcall(holder.ScaleTo, holder, math.max(1.4 - t * 1.1, 0.25))
	end)
end

-- GROWING: after a plant is emptied its blooms come back as tiny see-through sprouts
-- that slowly swell while a timer counts down. When the timer ends they pop to full size.
local function setGrowing(model, growTime)
	local endAt = os.clock() + growTime
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" and d:IsA("BasePart") then
			local full = d:GetAttribute("FullSize") or d.Size
			d:SetAttribute("FullSize", full)
			d.LocalTransparencyModifier = 0.45
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("BasePart") then
					c.LocalTransparencyModifier = 1
				end
			end
			d.Size = full * 0.15
			TweenService:Create(d, TweenInfo.new(growTime, Enum.EasingStyle.Linear), {Size = full * 0.7}):Play()
		end
	end

	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end
	if os.clock() - (Harvest._lastWater or 0) > 0.6 then
		Harvest._lastWater = os.clock()
		sfx("Water")
	end
	local old = hitbox:FindFirstChild("GrowTimer")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "GrowTimer"
	gui.Size = UDim2.fromOffset(110, 34)
	gui.StudsOffset = Vector3.new(0, 3.5, 0)
	gui.MaxDistance = 80
	gui.AlwaysOnTop = true
	gui.Adornee = hitbox
	gui.Parent = hitbox
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(40, 90, 45)
	label.BackgroundTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = gui
	Instance.new("UICorner", label).CornerRadius = UDim.new(1, 0)
	local pad = Instance.new("UIPadding", label)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 45, 20)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label

	task.spawn(function()
		while gui.Parent do
			local left = math.max(0, endAt - os.clock())
			label.Text = "🌱 " .. math.ceil(left) .. "s"
			if left <= 0 then
				break
			end
			task.wait(0.2)
		end
		if gui.Parent then
			label.Text = "✨ Ready!"
			label.BackgroundColor3 = Color3.fromRGB(230, 170, 30)
			task.wait(1)
			gui:Destroy()
		end
	end)
end

local function setReady(model)
	for _, d in ipairs(model:GetChildren()) do
		if d.Name == "Bloom" and d:IsA("BasePart") then
			local full = d:GetAttribute("FullSize") or d.Size
			d.LocalTransparencyModifier = 0
			for _, c in ipairs(d:GetDescendants()) do
				if c:IsA("BasePart") then
					c.LocalTransparencyModifier = 0
				end
			end
			TweenService:Create(d, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = full}):Play()
		end
	end
	bounce(model)
end

local function foodPopup(model, foodName)
	local hitbox = model.PrimaryPart
	if not hitbox then
		return
	end
	local Plants = _L.Get {"Common", "Modules", "Databases", "Plants"}
	local rarity = "Common"
	for _, p in ipairs(Plants) do
		if p.name == foodName then
			rarity = p.rarity
		end
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = hitbox
	gui.Parent = _L.PlayerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = "+1 " .. (FOOD_EMOJI[rarity] or "🍀") .. " " .. foodName
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(45, 30, 80)
	stroke.Parent = label

	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffset = Vector3.new(0, 8, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(stroke, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
	task.delay(1.5, function()
		gui:Destroy()
	end)

	sfx("Harvest_Pick")
	local MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
	local _, mutation = MutationUtility.split(foodName)
	if mutation then
		sfx(if (mutation.tier or 1) >= 4 then "Mutation_Rare" else "Mutation", {volume = 0.3})
	end
end

function Harvest._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
end

-- AUTO COLLECT: toggle button (right side of the screen) + a soft ring on the ground
-- showing how far it reaches. The server does the collecting (Player controller, every 0.5s).
local AUTO_RANGE = 30

-- Shared layout for the right-side HUD stack (also used by Backpack + Items).
-- Everything hangs from one anchor line; on touch screens it sits higher so the
-- jump button never covers it. Sizes are scaled down on small screens.
local UserInputService = game:GetService("UserInputService")
Harvest.HUD = {
	MARGIN = 16,
	WIDTH = 158,
	TOGGLE_H = 34,
	BACKPACK_H = 38,
	COLLECT_Y = -46, -- above the backpack indicator
	HARVEST_Y = -86,
	HOLD_Y = -128,
	_items = {},
}
function Harvest.HUD.anchorY()
	return if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 0.7 else 0.8
end
function Harvest.HUD.scale()
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / 1100, vp.Y / 700), 0.62, 1)
end
-- keep an element in the stack: position is recomputed when the screen size changes
function Harvest.HUD.track(gui, offsetY)
	table.insert(Harvest.HUD._items, {gui = gui, y = offsetY})
	Harvest.HUD.apply()
end
function Harvest.HUD.apply()
	local k = Harvest.HUD.scale()
	for _, item in ipairs(Harvest.HUD._items) do
		if item.gui.Parent then
			local sc = item.gui:FindFirstChild("HudScale") or Instance.new("UIScale")
			sc.Name = "HudScale"
			sc.Scale = k
			sc.Parent = item.gui
			item.gui.Position = UDim2.new(1, -Harvest.HUD.MARGIN, Harvest.HUD.anchorY(), item.y * k)
		end
	end
end
task.defer(function()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(Harvest.HUD.apply)
	end
end)

function Harvest._buildAutoCollect()
	local Data = _L.Get {"Client", "Library", "Classes", "Data"}
	local data = Data.Await()

	local gui = Instance.new("ScreenGui")
	gui.Name = "AutoCollect"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = _L.PlayerGui

	-- Right-side Auto Collect control and its range ring.
	local HUD = Harvest.HUD
	local CREAM, BROWN = Color3.fromRGB(255, 248, 230), Color3.fromRGB(90, 60, 30)
	local ON_BG, ON_DARK = Color3.fromRGB(110, 200, 80), Color3.fromRGB(45, 110, 35)
	local function makeToggle(name, icon, label, offsetY)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = ""
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -HUD.MARGIN, HUD.anchorY(), offsetY)
		b.Size = UDim2.fromOffset(HUD.WIDTH, HUD.TOGGLE_H)
		b.BackgroundColor3 = CREAM
		b.Parent = gui
		Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
		local s = Instance.new("UIStroke")
		s.Thickness = 2.5
		s.Color = BROWN
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = b
		local t = Instance.new("TextLabel")
		t.Name = "Label"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(12, 7)
		t.Size = UDim2.new(1, -62, 1, -14)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = BROWN
		t.Text = icon .. " " .. label
		t.Parent = b
		local dot = Instance.new("TextLabel")
		dot.Name = "State"
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(1, -6, 0.5, 0)
		dot.Size = UDim2.fromOffset(42, HUD.TOGGLE_H - 12)
		dot.Font = Enum.Font.FredokaOne
		dot.TextScaled = true
		dot.TextColor3 = Color3.new(1, 1, 1)
		dot.Parent = b
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		local dp = Instance.new("UIPadding", dot)
		dp.PaddingTop = UDim.new(0, 3)
		dp.PaddingBottom = UDim.new(0, 3)
		local function visual(on)
			b.BackgroundColor3 = if on then Color3.fromRGB(225, 250, 205) else CREAM
			s.Color = if on then ON_DARK else BROWN
			dot.Text = if on then "ON" else "OFF"
			dot.BackgroundColor3 = if on then ON_BG else Color3.fromRGB(190, 175, 150)
		end
		HUD.track(b, offsetY)
		return b, visual
	end

	local button, visualCollect = makeToggle("Toggle", "🧲", "Auto Collect", HUD.COLLECT_Y)

	-- range ring (only you see it)
	local ring = Instance.new("Part")
	ring.Name = "AutoCollectRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(120, 255, 120)
	ring.Transparency = 0.88
	ring.Size = Vector3.new(0.15, AUTO_RANGE * 2, AUTO_RANGE * 2)

	local ringConnection
	local autoOn = false
	-- Settings > "Show Auto-Collect Zone" (visual only, Auto Collect keeps working when hidden)
	local function zoneVisible()
		local settings = data:Get("settings")
		return not settings or settings.Auto_Collect_Zone ~= false
	end
	local function setState(on)
		autoOn = on
		visualCollect(on)
		if ringConnection then
			ringConnection:Disconnect()
			ringConnection = nil
		end
		if on and zoneVisible() then
			ring.Parent = workspace
			ringConnection = RunService.RenderStepped:Connect(function()
				local character = _L.Player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid then
					local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.1, 0)
					ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2)
				end
			end)
		else
			ring.Parent = nil
		end
	end

	data:Bind("auto_collect", function(value)
		setState(value == true)
	end)
	data:Bind("settings", function()
		setState(autoOn)
	end)

	button.Activated:Connect(function()
		local success = Network.Remote.Invoke("S_Auto_Collect_Toggle")
		if success and Audio then
			Audio.Play({name = "Toggle1"})
		end
	end)
end

-- "crops ready" toast (replaces the old permanent HARVEST bar feedback).
-- Batches plants that finish together, skips plants you're standing next to, and has a cooldown so it never spams.
local READY_COOLDOWN = 25
local readyPending, readyLast, readyQueued = {}, -math.huge, false
function readyNotify(model)
	if model:GetAttribute("Owner") ~= nil and model:GetAttribute("Owner") ~= _L.Player.UserId then return end
	local character = _L.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and (model:GetPivot().Position - root.Position).Magnitude < 30 then return end
	table.insert(readyPending, model:GetAttribute("DisplayName") or model:GetAttribute("Plant") or model.Name)
	if readyQueued then return end
	readyQueued = true
	task.delay(1.5, function()
		readyQueued = false
		local names = readyPending
		readyPending = {}
		if os.clock() - readyLast < READY_COOLDOWN or #names == 0 then return end
		readyLast = os.clock()
		local ok, UI = pcall(function() return _L.Get {"Client", "Modules", "UI"} end)
		local Notifications = ok and UI and UI.Get("Notifications")
		if not Notifications then return end
		local unique = {}
		for _, n in ipairs(names) do unique[n] = true end
		local count = 0
		for _ in pairs(unique) do count += 1 end
		local text = if count == 1 and #names == 1 and not tostring(names[1]):find("Bush") and names[1] ~= "Plant" then "🌱 "..tostring(names[1]).." is ready to harvest!" else "🌾 Your crops are ready to harvest!"
		Notifications:add({text = text, color = Color3.fromRGB(150, 255, 120), duration = 2.5})
		sfx("Harvest_Collect")
	end)
end

function Harvest._start()
	local regrowTokens = {}

	task.spawn(function()
		local ok, err = pcall(Harvest._buildAutoCollect)
		if not ok then
			warn("[Harvest] Auto Collect button failed:", err)
		end
	end)

	-- Every successful harvest (any player) is broadcast with the plant position:
	-- remember it so that player's fruits and pets run over to help
	Network.Remote.Fired("C_Power_Play", function(powerProps)
		if typeof(powerProps) == "table" and powerProps.player and typeof(powerProps.position) == "Vector3" then
			Harvest._targets[powerProps.player] = {position = powerProps.position, t = os.clock()}
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		Harvest._targets[player] = nil
	end)

	-- planting sound when a new crop of yours appears (not on first load)
	local startedAt = os.clock()
	local lastPlant = 0
	CollectionService:GetInstanceAddedSignal("HarvestBush"):Connect(function(model)
		if os.clock() - startedAt < 8 or os.clock() - lastPlant < 0.4 then
			return
		end
		if model:GetAttribute("Owner") == _L.Player.UserId then
			lastPlant = os.clock()
			sfx("Plant")
		end
	end)

	Network.Remote.Fired("C_Harvest_Update", function(bushId, left, regrowTime, foodName)
		local model = findBush(bushId)
		if not model then
			return
		end

		-- the bloom that was just picked is the one with Index = left + 1
		for _, d in ipairs(model:GetChildren()) do
			if d.Name == "Bloom" and d:IsA("BasePart") and d:GetAttribute("Index") == left + 1 and d.LocalTransparencyModifier < 0.5 then
				flyBloom(d)
				break
			end
		end

		applyFruitCount(model, left, false)
		bounce(model)

		if foodName then
			foodPopup(model, foodName)
		end

		if left <= 0 and regrowTime and regrowTime > 0 then
			local token = {}
			regrowTokens[bushId] = token
			setGrowing(model, regrowTime)
			task.delay(regrowTime, function()
				if regrowTokens[bushId] == token and model.Parent then
					setReady(model)
					readyNotify(model)
				end
			end)
		else
			regrowTokens[bushId] = nil
		end
	end)
end

return Harvest
