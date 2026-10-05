--> Fishing (client, V1.1 overhaul)
-- Draws the Fishing loop. The SERVER decides everything (Server.Controllers.Fishing): the client
-- sends an aim point, "hook" on the bite and hold / release while reeling, and shows the result.
-- The reel uses the shared deterministic simulation (FishingUtility) so the bar on screen matches
-- what the server judges. Only temporary connections: all of them end with the cast.
local _L = _G._L

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Network
local Audio
local UI
local Data
local Config
local U

local Fishing = {}

local state = "idle" -- idle | casting | waiting | bite | hooking | reeling | judging
local token = nil
local tool = nil -- equipped rod
local visuals = {}
local reelConn = nil
local aimConn = nil
local gui
local hud = {}
local holdSources = {}
local tutorialStep = nil

local FONT = Enum.Font.FredokaOne
local CREAM = Color3.fromRGB(255, 248, 230)
local WOOD = Color3.fromRGB(90, 60, 30)
local WATERBLUE = Color3.fromRGB(70, 150, 230)

------------------------------------------------------------ small helpers
local function notify(text, color)
	pcall(function()
		UI.Get("Notifications"):add({text = text, color = color or Color3.fromRGB(150, 210, 255)})
	end)
end

local function play(name, volume)
	pcall(Audio.Play, {name = name, volume = volume})
end

local function fishData()
	local data = Data.Await()
	return U.normalize(data and data:Get("fishing"))
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(0, 12)
	c.Parent = p
end

local function stroke(p, t, c)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 3
	s.Color = c or WOOD
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
end

local function label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = WOOD
	l.Text = text
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent, text, color, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	corner(b, UDim.new(0, 10))
	stroke(b, 2.5)
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(40, 30, 20)
	ts.Parent = b
	b.Parent = parent
	return b
end

local function clearVisuals()
	for _, v in ipairs(visuals) do
		pcall(function()
			if typeof(v) == "RBXScriptConnection" then
				v:Disconnect()
			elseif typeof(v) == "Instance" then
				v:Destroy()
			else
				v:Cancel()
			end
		end)
	end
	table.clear(visuals)
	if reelConn then
		reelConn:Disconnect()
		reelConn = nil
	end
	hud.status.Visible = false
	hud.reel.Visible = false
	hud.hold.Visible = false
end

------------------------------------------------------------ HUD
local function setStatus(text, big, color)
	local l = hud.status
	l.Visible = text ~= nil
	l.Text = text or ""
	l.TextColor3 = color or (if big then Color3.fromRGB(255, 225, 80) else Color3.new(1, 1, 1))
	l.Size = if big then UDim2.fromScale(0.5, 0.12) else UDim2.fromScale(0.44, 0.055)
end

local function refreshInfo()
	if not hud.info then
		return
	end
	local f = fishData()
	local rod = U.getRod(f)
	local bait = Config.bait(f.selected_bait)
	local count = if f.selected_bait == "none" then "" else (" x" .. (f.bait[f.selected_bait] or 0))
	local level, into, need = U.levelFromXp(f.xp)
	hud.rodText.Text = "🎣 " .. (rod and rod.name or "No Rod") .. "   Lv " .. level
	hud.baitButton.Text = "BAIT: " .. (bait and (bait.icon .. " " .. bait.name) or "No Bait") .. count .. "  ▼"
	hud.bagText.Text = "🎒 " .. #f.bag .. "/" .. U.bagCapacity(f)
	hud.bagText.TextColor3 = if #f.bag >= U.bagCapacity(f) then Color3.fromRGB(230, 70, 60) else WOOD
	hud.xpFill.Size = UDim2.fromScale(if need > 0 then math.clamp(into / need, 0, 1) else 1, 1)
end

local function openBaitPicker()
	local picker = hud.picker
	for _, c in ipairs(picker.List:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local f = fishData()
	for i, bait in ipairs(Config.BAITS) do
		local owned = if bait.id == "none" then math.huge else (f.bait[bait.id] or 0)
		if owned > 0 or bait.id == f.selected_bait then
			local b = button(picker.List, "", if bait.id == f.selected_bait then Color3.fromRGB(110, 190, 80) else Color3.fromRGB(205, 180, 140), {
				LayoutOrder = i, Size = UDim2.new(1, -8, 0, 46), TextXAlignment = Enum.TextXAlignment.Left,
			})
			b.Text = "  " .. bait.icon .. " " .. bait.name .. (if bait.id == "none" then "" else (" x" .. owned)) .. "  -  " .. bait.desc
			b.Activated:Connect(function()
				local ok, err = pcall(Network.Remote.Invoke, "S_Fishing_SelectBait", bait.id)
				picker.Visible = false
				task.delay(0.2, refreshInfo)
				if tutorialStep == 2 then
					Fishing._tutorialAdvance(2)
				end
			end)
		end
	end
	label(picker.List, "Buy more Bait from Fisher Finn at the FISHING stall.", {LayoutOrder = 99, Size = UDim2.new(1, -8, 0, 26), TextColor3 = Color3.fromRGB(120, 95, 70)})
	picker.Visible = true
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "FishingHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = _L.Player:WaitForChild("PlayerGui")

	-- info bar (only while the rod is equipped): rod, level, bait, bag
	local info = Instance.new("Frame")
	info.Name = "Info"
	info.AnchorPoint = Vector2.new(0.5, 0)
	info.Position = UDim2.new(0.5, 0, 0, 78)
	info.Size = UDim2.new(0.62, 0, 0, 52)
	info.BackgroundColor3 = CREAM
	info.Visible = false
	info.Parent = gui
	corner(info, UDim.new(0, 14))
	stroke(info, 3)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(640, 56)
	cap.Parent = info
	hud.info = info
	hud.rodText = label(info, "", {Position = UDim2.fromScale(0.02, 0.12), Size = UDim2.fromScale(0.3, 0.6), TextXAlignment = Enum.TextXAlignment.Left})
	local xp = Instance.new("Frame")
	xp.Position = UDim2.fromScale(0.02, 0.76)
	xp.Size = UDim2.fromScale(0.28, 0.12)
	xp.BackgroundColor3 = Color3.fromRGB(215, 200, 170)
	xp.Parent = info
	corner(xp, UDim.new(1, 0))
	hud.xpFill = Instance.new("Frame")
	hud.xpFill.BackgroundColor3 = WATERBLUE
	hud.xpFill.Size = UDim2.fromScale(0, 1)
	hud.xpFill.Parent = xp
	corner(hud.xpFill, UDim.new(1, 0))
	hud.baitButton = button(info, "BAIT", Color3.fromRGB(110, 170, 90), {Position = UDim2.fromScale(0.33, 0.12), Size = UDim2.fromScale(0.47, 0.76)})
	hud.baitButton.Activated:Connect(function()
		if hud.picker.Visible then
			hud.picker.Visible = false
		else
			openBaitPicker()
		end
	end)
	hud.bagText = label(info, "", {Position = UDim2.fromScale(0.82, 0.12), Size = UDim2.fromScale(0.16, 0.76)})

	-- bait picker
	local picker = Instance.new("Frame")
	picker.Name = "BaitPicker"
	picker.AnchorPoint = Vector2.new(0.5, 0)
	picker.Position = UDim2.new(0.5, 0, 0, 136)
	picker.Size = UDim2.new(0.62, 0, 0, 300)
	picker.BackgroundColor3 = CREAM
	picker.Visible = false
	picker.Parent = gui
	corner(picker, UDim.new(0, 14))
	stroke(picker, 3)
	local pcap = Instance.new("UISizeConstraint")
	pcap.MaxSize = Vector2.new(640, 320)
	pcap.Parent = picker
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 8, 0, 8)
	list.Size = UDim2.new(1, -16, 1, -16)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = picker
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	hud.picker = picker

	-- status ("Wait for a bite..." / "BITE! TAP!")
	hud.status = label(gui, "", {Name = "Status", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.44, 0.055), TextColor3 = Color3.new(1, 1, 1), Visible = false})
	stroke(hud.status, 3, Color3.fromRGB(30, 45, 80))
	hud.status:FindFirstChildOfClass("UIStroke").ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	-- reel bar: water column, green catch zone, fish icon, progress bar
	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.AnchorPoint = Vector2.new(0.5, 0.5)
	reel.Position = UDim2.fromScale(0.68, 0.45)
	reel.Size = UDim2.fromScale(0.09, 0.46)
	reel.BackgroundColor3 = Color3.fromRGB(40, 90, 150)
	reel.Visible = false
	reel.Parent = gui
	corner(reel, UDim.new(0, 12))
	stroke(reel, 4)
	local rcap = Instance.new("UISizeConstraint")
	rcap.MinSize = Vector2.new(70, 220)
	rcap.MaxSize = Vector2.new(110, 420)
	rcap.Parent = reel
	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.BackgroundColor3 = Color3.fromRGB(120, 230, 110)
	zone.BackgroundTransparency = 0.25
	zone.Size = UDim2.fromScale(0.86, 0.25)
	zone.Position = UDim2.fromScale(0.5, 0.5)
	zone.Parent = reel
	corner(zone, UDim.new(0, 8))
	local fishIcon = label(reel, "🐟", {Name = "Fish", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3})
	local prog = Instance.new("Frame")
	prog.Name = "Progress"
	prog.AnchorPoint = Vector2.new(0, 1)
	prog.Position = UDim2.new(1, 10, 1, 0)
	prog.Size = UDim2.new(0.28, 0, 1, 0)
	prog.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
	prog.Parent = reel
	corner(prog, UDim.new(0, 8))
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0.3)
	fill.BackgroundColor3 = Color3.fromRGB(255, 210, 60)
	fill.Parent = prog
	corner(fill, UDim.new(0, 8))
	hud.reel, hud.zone, hud.fish, hud.fill = reel, zone, fishIcon, fill

	-- big HOLD button (mobile + mouse); keyboard Space / gamepad R2 / mouse anywhere also work
	local hold = button(gui, "HOLD TO REEL", Color3.fromRGB(70, 150, 230), {
		Name = "Hold", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromScale(0.3, 0.1), Visible = false,
	})
	local hcap = Instance.new("UISizeConstraint")
	hcap.MinSize = Vector2.new(170, 64)
	hcap.MaxSize = Vector2.new(320, 96)
	hcap.Parent = hold
	hold.MouseButton1Down:Connect(function()
		holdSources.button = true
		if state == "bite" then
			Fishing._hook()
		end
	end)
	hold.MouseButton1Up:Connect(function()
		holdSources.button = nil
	end)
	hold.MouseLeave:Connect(function()
		holdSources.button = nil
	end)
	hud.hold = hold

	-- catch popup
	local pop = Instance.new("TextButton")
	pop.Name = "Catch"
	pop.Text = ""
	pop.AutoButtonColor = false
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Position = UDim2.fromScale(0.5, 0.45)
	pop.Size = UDim2.fromScale(0.42, 0.42)
	pop.BackgroundColor3 = CREAM
	pop.Visible = false
	pop.ZIndex = 20
	pop.Parent = gui
	corner(pop, UDim.new(0, 20))
	stroke(pop, 5)
	local popCap = Instance.new("UISizeConstraint")
	popCap.MinSize = Vector2.new(280, 230)
	popCap.MaxSize = Vector2.new(460, 340)
	popCap.Parent = pop
	local popList = Instance.new("Frame")
	popList.Name = "Lines"
	popList.BackgroundTransparency = 1
	popList.Position = UDim2.fromScale(0.05, 0.05)
	popList.Size = UDim2.fromScale(0.9, 0.9)
	popList.ZIndex = 21
	popList.Parent = pop
	local popLayout = Instance.new("UIListLayout")
	popLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	popLayout.SortOrder = Enum.SortOrder.LayoutOrder
	popLayout.Padding = UDim.new(0, 2)
	popLayout.Parent = popList
	pop.Activated:Connect(function()
		pop.Visible = false
	end)
	hud.pop, hud.popList = pop, popList

	-- tutorial card
	local tut = Instance.new("Frame")
	tut.Name = "Tutorial"
	tut.AnchorPoint = Vector2.new(0.5, 0)
	tut.Position = UDim2.new(0.5, 0, 0, 140)
	tut.Size = UDim2.new(0.5, 0, 0, 92)
	tut.BackgroundColor3 = Color3.fromRGB(225, 245, 255)
	tut.Visible = false
	tut.ZIndex = 15
	tut.Parent = gui
	corner(tut, UDim.new(0, 14))
	stroke(tut, 3, Color3.fromRGB(40, 70, 110))
	local tcap = Instance.new("UISizeConstraint")
	tcap.MinSize = Vector2.new(300, 92)
	tcap.MaxSize = Vector2.new(560, 100)
	tcap.Parent = tut
	hud.tutText = label(tut, "", {Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.5), TextColor3 = Color3.fromRGB(30, 60, 100), ZIndex = 16})
	hud.tutNext = button(tut, "Next", Color3.fromRGB(70, 150, 230), {Position = UDim2.fromScale(0.52, 0.6), Size = UDim2.fromScale(0.24, 0.32), ZIndex = 16})
	hud.tutSkip = button(tut, "Skip", Color3.fromRGB(170, 150, 130), {Position = UDim2.fromScale(0.78, 0.6), Size = UDim2.fromScale(0.19, 0.32), ZIndex = 16})
	hud.tut = tut
end

------------------------------------------------------------ catch popup
local function showPopup(lines, holdTime)
	local list = hud.popList
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, line in ipairs(lines) do
		label(list, line.text, {LayoutOrder = i, Size = UDim2.new(1, 0, line.h or 0.12, 0), TextColor3 = line.color or WOOD, ZIndex = 22})
	end
	local pop = hud.pop
	pop.Visible = true
	pop.Size = UDim2.fromScale(0.3, 0.3)
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.fromScale(0.42, 0.42)}):Play()
	local mine = {}
	hud.popToken = mine
	task.delay(holdTime or 4.5, function()
		if hud.popToken == mine then
			pop.Visible = false
		end
	end)
end

local function showResult(result)
	if typeof(result) ~= "table" then
		return
	end
	if result.kind == "fish" then
		local rarity = Config.RARITIES[result.rarity]
		local lines = {
			{text = "NEW CATCH!", h = 0.14, color = Color3.fromRGB(70, 150, 230)},
			{text = result.name, h = 0.16, color = rarity and rarity.color},
			{text = result.weight .. " kg  (" .. result.tier .. ")  -  " .. result.rarity, h = 0.1},
			{text = "Value: " .. result.value .. " Coins", h = 0.1, color = Color3.fromRGB(200, 150, 30)},
		}
		if result.perfect then
			table.insert(lines, {text = "✨ PERFECT CATCH! +10% value", h = 0.09, color = Color3.fromRGB(110, 190, 80)})
		end
		if result.newSpecies then
			table.insert(lines, {text = "📖 New species in your Journal!", h = 0.09, color = Color3.fromRGB(70, 150, 230)})
		end
		if result.record then
			table.insert(lines, {text = "🏆 NEW RECORD! " .. result.name .. " - " .. result.weight .. "kg", h = 0.09, color = Color3.fromRGB(230, 120, 30)})
		end
		if result.drops and #result.drops > 0 then
			table.insert(lines, {text = "Found: " .. table.concat(result.drops, ", "), h = 0.08})
		end
		if result.levelUp then
			table.insert(lines, {text = "⬆ Fishing Level " .. result.levelUp .. "!", h = 0.09, color = Color3.fromRGB(70, 150, 230)})
		end
		table.insert(lines, {text = "Bag " .. result.bag .. "/" .. result.bagSize .. "  (tap to close)", h = 0.07, color = Color3.fromRGB(150, 130, 110)})
		showPopup(lines)
		if rarity and rarity.order >= 5 then
			play("Trumpet1")
		elseif rarity and rarity.order >= 3 then
			play("Success2")
		else
			play("Reward1")
		end
	elseif result.kind == "treasure" then
		local lines = {{text = if result.chest then "🎁 TREASURE CHEST!" else "👜 " .. result.name .. "!", h = 0.18, color = Color3.fromRGB(200, 140, 30)}}
		if result.chest then
			-- short opening: shake, then the loot
			showPopup({{text = "🎁", h = 0.6}, {text = "Opening...", h = 0.14}}, 2)
			play("Tick1")
			local pop = hud.pop
			for i = 1, 6 do
				pop.Rotation = if i % 2 == 0 then 4 else -4
				task.wait(0.12)
			end
			pop.Rotation = 0
			play("Event_Rare")
		else
			play("Reward1")
		end
		for _, l in ipairs(result.lines or {}) do
			table.insert(lines, {text = l, h = 0.1})
		end
		table.insert(lines, {text = "(tap to close)", h = 0.07, color = Color3.fromRGB(150, 130, 110)})
		showPopup(lines, 5)
	end
end

------------------------------------------------------------ cast
local function pointerWater()
	-- water point under the mouse / last touch, in the open (nil if not water)
	local camera = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	if hud.lastTouch then
		pos = hud.lastTouch
	end
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {camera, _L.Player.Character}
	params.IgnoreWater = false
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if hit and ((hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Water) or hit.Instance:GetAttribute("FishingWater") == true) then
		return hit.Position
	end
	return nil
end

local function makeBobber(position)
	local f = fishData()
	local cosmetic = Config.cosmetic(f.cosmetics.bobber)
	local bobber = Instance.new("Part")
	bobber.Name = "FishingBobber"
	bobber.Shape = Enum.PartType.Ball
	bobber.Size = Vector3.new(0.7, 0.7, 0.7)
	bobber.Color = cosmetic and cosmetic.color or Color3.fromRGB(235, 70, 60)
	bobber.Material = if cosmetic and cosmetic.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	bobber.Anchored = true
	bobber.CanCollide = false
	bobber.CanQuery = false
	bobber.CanTouch = false
	bobber.CFrame = CFrame.new(position)
	bobber.Parent = workspace.CurrentCamera
	table.insert(visuals, bobber)
	local top = Instance.new("Part")
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(0.45, 0.45, 0.45)
	top.Color = Color3.new(1, 1, 1)
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.CFrame = bobber.CFrame + Vector3.new(0, 0.3, 0)
	top.Parent = bobber
	local a1 = Instance.new("Attachment")
	a1.Parent = bobber
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Tip")
	if tip then
		local line = Instance.new("Beam")
		line.Attachment0 = tip
		line.Attachment1 = a1
		line.Width0 = 0.05
		line.Width1 = 0.05
		line.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		line.FaceCamera = true
		line.CurveSize0 = -1
		line.Parent = bobber
	end
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splash"
	splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	splash.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	splash.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	splash.Lifetime = NumberRange.new(0.4, 0.7)
	splash.Speed = NumberRange.new(4, 7)
	splash.SpreadAngle = Vector2.new(40, 40)
	splash.Acceleration = Vector3.new(0, -18, 0)
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Rate = 0
	splash.Parent = a1
	hud.splash = splash
	return bobber
end

local function bob(bobber, rest)
	local tween = TweenService:Create(bobber, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {CFrame = CFrame.new(rest + Vector3.new(0, 0.12, 0))})
	tween:Play()
	table.insert(visuals, tween)
	local top = bobber:FindFirstChildOfClass("Part")
	local follow = RunService.RenderStepped:Connect(function()
		if top then
			top.CFrame = bobber.CFrame + Vector3.new(0, 0.3, 0)
		end
	end)
	table.insert(visuals, follow)
	return tween
end

local function castAnimation(target)
	-- rod flick + bobber arc from the rod tip to the water
	if tool then
		local base = tool.Grip
		local back = TweenService:Create(tool, TweenInfo.new(0.15), {Grip = base * CFrame.Angles(math.rad(-45), 0, 0)})
		back:Play()
		task.delay(0.15, function()
			if tool then
				TweenService:Create(tool, TweenInfo.new(0.2), {Grip = base}):Play()
			end
		end)
	end
	play("Swing1")
	local handle = tool and tool:FindFirstChild("Handle")
	local start = handle and (handle.CFrame * CFrame.new(0, 0, -3)).Position or target + Vector3.new(0, 5, 0)
	local bobber = makeBobber(start)
	local t0 = os.clock()
	local DURATION = 0.45
	while os.clock() - t0 < DURATION do
		local a = (os.clock() - t0) / DURATION
		local p = start:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 3, 0)
		bobber.CFrame = CFrame.new(p)
		local top = bobber:FindFirstChildOfClass("Part")
		if top then
			top.CFrame = bobber.CFrame + Vector3.new(0, 0.3, 0)
		end
		RunService.RenderStepped:Wait()
	end
	bobber.CFrame = CFrame.new(target + Vector3.new(0, 0.15, 0))
	if hud.splash then
		hud.splash:Emit(12)
	end
	play("Plop1")
	return bobber
end

local function aimRing()
	local ring = Instance.new("Part")
	ring.Name = "FishingAim"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 2.4, 2.4)
	ring.Color = Color3.fromRGB(120, 230, 255)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = workspace.CurrentCamera
	return ring
end

local function startAim()
	if aimConn then
		return
	end
	local ring = aimRing()
	hud.ring = ring
	aimConn = RunService.RenderStepped:Connect(function()
		if state ~= "idle" or not tool then
			ring.Parent = nil
			return
		end
		local p = pointerWater()
		local root = _L.Player.Character and _L.Player.Character:FindFirstChild("HumanoidRootPart")
		local rod = U.getRod(fishData())
		if p and root and rod and Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z).Magnitude <= rod.cast then
			ring.Parent = workspace.CurrentCamera
			ring.CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		else
			ring.Parent = nil
		end
	end)
end

local function stopAim()
	if aimConn then
		aimConn:Disconnect()
		aimConn = nil
	end
	if hud.ring then
		hud.ring:Destroy()
		hud.ring = nil
	end
end

local CAST_ERRORS = {
	zone = "🎣 Fish at a Fishing Spot: the river by Fisher Finn's FISHING stall.",
	nowater = "Aim at the water!",
	bagfull = "🎒 FISHING BAG FULL! Sell your fish to Fisher Finn.",
	nobait = "Out of that Bait - switched to No Bait.",
	rod = "Equip your Fishing Rod first!",
	needbait = "Nothing here bites that Bait. Check the Journal for what these fish like!",
}

local function cast()
	if state ~= "idle" or not tool then
		return
	end
	state = "casting"
	local aim = pointerWater()
	local ok, success, result, extra = pcall(Network.Remote.Invoke, "S_Fishing_Cast", aim)
	if not ok or not success then
		state = "idle"
		local code = if ok then result else "error"
		if code == "zonelocked" then
			notify("🔒 This spot needs a " .. tostring(extra) .. ". Upgrade at Fisher Finn!", Color3.fromRGB(255, 190, 90))
		elseif CAST_ERRORS[code] then
			notify(CAST_ERRORS[code], Color3.fromRGB(255, 190, 90))
		end
		task.delay(0.2, refreshInfo)
		return
	end
	token = result.token
	local bobber = castAnimation(result.bobber)
	if state ~= "casting" then
		return
	end
	state = "waiting"
	hud.rest = result.bobber + Vector3.new(0, 0.15, 0)
	bob(bobber, hud.rest)
	setStatus("Wait for a bite...")
	hud.hold.Visible = true
	hud.hold.Text = "TAP ON BITE!"
	refreshInfo()
	Fishing._tutorialAdvance(3)
end

------------------------------------------------------------ reel
local function holding()
	return next(holdSources) ~= nil
end

local function startReel(params, settle)
	state = "reeling"
	setStatus(nil)
	hud.reel.Visible = true
	hud.hold.Visible = true
	hud.hold.Text = "HOLD TO REEL"
	hud.zone.Size = UDim2.fromScale(0.86, params.zone)
	local sim = U.newReel(params)
	local lastSent = false
	local acc = 0
	local tickT = 0
	reelConn = RunService.Heartbeat:Connect(function(dt)
		if state ~= "reeling" then
			return
		end
		acc += dt
		while acc >= U.DT and not sim.done do
			acc -= U.DT
			local h = holding()
			if h ~= lastSent then
				lastSent = h
				Network.Remote.Fire("S_Fishing_Input", token, sim.step + 1, h)
			end
			U.stepReel(sim, h)
		end
		hud.zone.Position = UDim2.fromScale(0.5, 1 - sim.zonePos)
		hud.fish.Position = UDim2.fromScale(0.5, 1 - sim.fishPos)
		hud.fill.Size = UDim2.fromScale(1, math.clamp(sim.progress, 0, 1))
		local inside = math.abs(sim.fishPos - sim.zonePos) <= sim.zone / 2
		hud.zone.BackgroundColor3 = if inside then Color3.fromRGB(120, 230, 110) else Color3.fromRGB(240, 150, 90)
		tickT += dt
		if inside and tickT > 0.3 then
			tickT = 0
			play("Tick2", 0.25)
		end
		if sim.done then
			state = "judging"
			reelConn:Disconnect()
			reelConn = nil
			setStatus(if sim.done == "caught" then "Reeling in..." else "It's pulling away...")
		end
	end)
end

function Fishing._hook()
	if state ~= "bite" then
		return
	end
	state = "hooking"
	local ok, success, result = pcall(Network.Remote.Invoke, "S_Fishing_Hook")
	if not ok or not success then
		-- the server sends C_Fishing_End with the reason (early / missed)
		if state == "hooking" then
			state = "waiting"
		end
		return
	end
	if result.token ~= token then
		return
	end
	play("Water", 0.6)
	startReel(result.params, result.settle)
	Fishing._tutorialAdvance(4)
end

local END_TEXT = {
	early = {"Too early! The fish swam away.", Color3.fromRGB(255, 190, 90)},
	missed = {"Too slow! It got away.", Color3.fromRGB(255, 160, 90)},
	escaped = {"💨 The fish escaped!", Color3.fromRGB(255, 160, 90)},
	timeout = {"Nothing is biting. Try again!", Color3.fromRGB(255, 190, 90)},
}

local function endCast(data)
	if state == "idle" then
		return
	end
	state = "idle"
	token = nil
	holdSources = {}
	clearVisuals()
	local e = END_TEXT[data.reason]
	if e then
		notify(e[1], e[2])
		play("Fail1")
	end
	if data.reason == "caught" then
		task.spawn(showResult, data.result)
		Fishing._tutorialAdvance(5)
	end
	task.delay(0.3, refreshInfo)
end

local function onActivated()
	if state == "idle" then
		task.spawn(cast)
	elseif state == "bite" then
		Fishing._hook()
	elseif state == "waiting" then
		-- tapping before the bite pulls the line in (server: "early", the Bait is already used)
		pcall(Network.Remote.Invoke, "S_Fishing_Hook")
	end
end

local function cancel()
	if state ~= "idle" then
		endCast({reason = "cancel"})
		pcall(Network.Remote.Invoke, "S_Fishing_Cancel")
	end
end

------------------------------------------------------------ tutorial (first rod only, skippable)
local TUTORIAL = {
	"1/6  Equip your Fishing Rod from the hotbar.",
	"2/6  Choose a Bait with the BAIT button. Worms attract more river fish!",
	"3/6  Tap the water near you to cast (aim at the blue ring).",
	"4/6  Wait for BITE!, then tap fast to hook the fish.",
	"5/6  HOLD to lift the green bar, let go to drop it. Keep the fish inside!",
	"6/6  Sell fish, buy Bait and track your Journal at Fisher Finn's FISHING stall.",
}

local function showTutorial(step)
	tutorialStep = step
	if not step or step > #TUTORIAL then
		hud.tut.Visible = false
		tutorialStep = nil
		pcall(Network.Remote.Invoke, "S_Fishing_TutorialDone")
		return
	end
	hud.tut.Visible = true
	hud.tutText.Text = TUTORIAL[step]
	hud.tutNext.Text = if step == #TUTORIAL then "Done" else "Next"
end

function Fishing._tutorialAdvance(step)
	if tutorialStep and tutorialStep == step then
		showTutorial(step + 1)
	end
end

function Fishing._startTutorial()
	if tutorialStep then
		return
	end
	showTutorial(if tool then 2 else 1)
end

------------------------------------------------------------ tools
local function onEquipped(rod)
	tool = rod
	hud.info.Visible = true
	refreshInfo()
	startAim()
	Fishing._tutorialAdvance(1)
	local f = fishData()
	if not f.tutorial and not tutorialStep then
		Fishing._startTutorial()
	end
end

local function onUnequipped()
	cancel()
	tool = nil
	hud.info.Visible = false
	hud.picker.Visible = false
	stopAim()
end

local function hookTool(t)
	if not t:IsA("Tool") or t:GetAttribute("FishingRod") ~= true or t:GetAttribute("FishingHooked") then
		return
	end
	t:SetAttribute("FishingHooked", true)
	t.Activated:Connect(onActivated)
	t.Equipped:Connect(function()
		onEquipped(t)
	end)
	t.Unequipped:Connect(onUnequipped)
end

function Fishing._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Config = _L.Get {"Common", "Modules", "Databases", "Fishing"}
	U = _L.Get {"Common", "Modules", "Utilities", "FishingUtility"}
end

function Fishing._start()
	buildGui()
	hud.tutNext.Activated:Connect(function()
		if tutorialStep then
			showTutorial(tutorialStep + 1)
		end
	end)
	hud.tutSkip.Activated:Connect(function()
		showTutorial(nil)
	end)

	-- hold inputs while reeling: mouse anywhere, touch (not on other buttons), Space, gamepad R2 / A
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Touch then
			hud.lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
		if state ~= "reeling" and state ~= "bite" then
			return
		end
		local key = nil
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			key = "mouse"
		elseif input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonA then
			key = input.KeyCode.Name
		end
		if key then
			holdSources[key] = true
			if state == "bite" then
				Fishing._hook()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holdSources.mouse = nil
		else
			holdSources[input.KeyCode.Name] = nil
		end
	end)

	Network.Remote.Fired("C_Fishing_Bite", function(data)
		if typeof(data) ~= "table" or data.token ~= token or state ~= "waiting" then
			return
		end
		state = "bite"
		play("Ding1")
		setStatus("BITE! TAP!", true)
		hud.hold.Text = "TAP!"
		-- bobber dips + splash
		local bobber = visuals[1]
		if bobber and bobber:IsA("BasePart") and hud.rest then
			for _, v in ipairs(visuals) do
				if typeof(v) == "Instance" and v:IsA("Tween") then
					v:Cancel()
				end
			end
			bobber.CFrame = CFrame.new(hud.rest - Vector3.new(0, 0.45, 0))
			if hud.splash then
				hud.splash:Emit(14)
			end
		end
		-- holding Space / R2 / mouse through the bite also hooks
		if holding() then
			Fishing._hook()
		end
	end)
	Network.Remote.Fired("C_Fishing_End", function(data)
		if typeof(data) ~= "table" or (token ~= nil and data.token ~= token) then
			return
		end
		endCast(data)
	end)
	Network.Remote.Fired("C_Fishing_RodClaimed", function(data)
		task.delay(0.5, function()
			local f = fishData()
			if typeof(data) == "table" and data.first and not f.tutorial then
				Fishing._startTutorial()
			end
			refreshInfo()
		end)
	end)

	local data = Data.Await()
	if data then
		data:Bind({"fishing"}, function()
			if hud.info.Visible then
				refreshInfo()
			end
		end)
	end

	local function watch(container)
		for _, child in ipairs(container:GetChildren()) do
			hookTool(child)
		end
		container.ChildAdded:Connect(hookTool)
	end
	local function onCharacter(character)
		cancel()
		watch(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.Died:Connect(cancel)
		end
	end
	local backpack = _L.Player:WaitForChild("Backpack", 10)
	if backpack then
		watch(backpack)
	end
	_L.Player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	if _L.Player.Character then
		task.spawn(onCharacter, _L.Player.Character)
	end
	_L.Player.CharacterAdded:Connect(onCharacter)
end

return Fishing
