--> Mounts (client)
-- 🐎 Mounts menu (More > Other > Mounts), the "NEW MOUNT!" card, the ride / dismount button + keys,
-- and the leg / head / tail animation of every ridden mount (all players, driven by speed).
-- Ownership lives on the server (data "mounts", Databases.Mounts, server Mount controller):
-- the client only asks S_Mount_Equip / S_Mount_Unequip / S_Mount_Ride and shows the result.
--   Keys: G (PC) · DPad Up (controller) · 🐎 button (mobile / everyone)

local _L = _G._L

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Network
local MountUtility
local MountsDB
local AnimationPack

local rgb = Color3.fromRGB
local CREAM, CREAM2, BROWN, GREEN = rgb(255, 248, 230), rgb(245, 232, 200), rgb(90, 60, 30), rgb(110, 190, 80)
local RARITY_COLOR = {
	Common = rgb(170, 170, 170), Rare = rgb(80, 170, 255), Epic = rgb(190, 90, 255), Legendary = rgb(255, 190, 40),
	Mythical = rgb(255, 80, 120), Secret = rgb(120, 90, 200), Event = rgb(255, 130, 60), Limited = rgb(255, 80, 80),
}

local Mounts = {}

local data
local gui, panel, grid, rideGui, rideButton
local isOpen = false
local busy = false

------------------------------------------------------------ helpers
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
end
local function stroke(p, color, t, border)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = t or 2
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = p
	return s
end
local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = BROWN
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end
local function sfx(name)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name)
	end
end
local function notify(text, color)
	pcall(function()
		_L.Get {"Client", "Modules", "UI"}.Get("Notifications"):add({text = text, color = color or rgb(150, 255, 120), duration = 2.5})
	end)
end

local function owned()
	return (data and data:Get({"mounts", "owned"})) or {}
end
local function equipped()
	return data and MountUtility.getEquipped(data)
end
local function riding()
	return _L.Player:GetAttribute("RidingMount")
end

-- 3D model (ViewportFrame) or the emoji
local function makeIcon(parent, info, dark, size)
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = size
	holder.Parent = parent
	local folder = _L.Assets.Models:FindFirstChild("Mounts")
	local source = folder and folder:FindFirstChild(info.model or info.name)
	if info.image then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = info.image
		img.ImageColor3 = if dark then rgb(60, 45, 35) else rgb(255, 255, 255)
		img.Parent = holder
	elseif source then
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Size = UDim2.fromScale(1, 1)
		vp.Ambient = if dark then rgb(0, 0, 0) else rgb(200, 200, 200)
		vp.LightColor = if dark then rgb(0, 0, 0) else rgb(255, 250, 235)
		vp.ImageColor3 = if dark then rgb(60, 45, 35) else rgb(255, 255, 255)
		vp.Parent = holder
		local model = source:Clone()
		model.Parent = vp
		local cf, ext = model:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dir = (CFrame.Angles(0, math.rad(-140), 0) * Vector3.new(0, 0.25, 1)).Unit
		cam.CFrame = CFrame.lookAt(cf.Position + dir * ext.Magnitude * 1.9, cf.Position)
		cam.Parent = vp
		vp.CurrentCamera = cam
	else
		label(holder, {Size = UDim2.fromScale(1, 1), Text = info.emoji or "🐎", TextTransparency = if dark then 0.4 else 0})
	end
	return holder
end

------------------------------------------------------------ server calls
local function call(remote, ...)
	if busy then
		return
	end
	busy = true
	local ok, success, result = pcall(Network.Remote.Invoke, remote, ...)
	busy = false
	if not ok then
		return false, "error"
	end
	return success, result
end

function Mounts.equip(id)
	local success, result = call("S_Mount_Equip", id)
	local info = MountUtility.getInfo(id)
	if success then
		sfx("UI_Click")
		if result == "riding" then
			notify((info and info.emoji or "🐎") .. " Riding " .. (info and info.name or "your mount") .. "!")
		else
			notify("✅ " .. (info and info.name or "Mount") .. " equipped! Press 🐎 RIDE to hop on.")
		end
	elseif result == "not_owned" then
		notify("🔒 You don't own this mount yet!", rgb(255, 120, 100))
	elseif result ~= nil then
		notify("❌ Can't equip that right now.", rgb(255, 120, 100))
	end
end

function Mounts.unequip()
	local success = call("S_Mount_Unequip")
	if success then
		sfx("UI_Click")
		notify("🐎 Mount unequipped.", rgb(255, 220, 140))
	end
end

function Mounts.toggleRide()
	if not equipped() and not riding() then
		notify("🐎 Equip a mount first! (More > Mounts)", rgb(255, 220, 140))
		return
	end
	local success, result = call("S_Mount_Ride")
	if success then
		sfx(if result == "off" then "UI_Close" else "UI_Open")
	elseif result == "dead" then
		notify("❌ You can't ride right now.", rgb(255, 120, 100))
	end
end

------------------------------------------------------------ menu
local refresh

local function buildCard(info, i)
	local have = owned()[info.id] == true
	local isEquipped = equipped() == info.id
	local color = RARITY_COLOR[info.rarity] or BROWN
	local card = Instance.new("Frame")
	card.Name = info.id
	card.LayoutOrder = if isEquipped then 0 elseif have then i else 1000 + i
	card.BackgroundColor3 = if isEquipped then rgb(225, 250, 205) else CREAM
	card.Parent = grid
	corner(card, 14)
	stroke(card, if isEquipped then GREEN else color, if isEquipped then 4 else 3, true)

	local iconBg = Instance.new("Frame")
	iconBg.Position = UDim2.fromOffset(8, 8)
	iconBg.Size = UDim2.new(1, -16, 0, 104)
	iconBg.BackgroundColor3 = CREAM2
	iconBg.Parent = card
	corner(iconBg, 10)
	makeIcon(iconBg, info, not have, UDim2.fromScale(1, 1))
	if not have then
		label(iconBg, {Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, -17, 0.5, -17), Text = "🔒"})
	end

	label(card, {Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 116), Text = (info.emoji or "🐎") .. " " .. info.name})
	local rl = label(card, {Size = UDim2.new(1, -12, 0, 14), Position = UDim2.fromOffset(6, 139), Text = string.upper(info.rarity or ""), TextColor3 = color})
	stroke(rl, rgb(60, 40, 25), 1)
	local status = label(card, {Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 156),
		Text = if isEquipped then "✔ EQUIPPED" elseif have then "OWNED" else "LOCKED",
		TextColor3 = if isEquipped then rgb(60, 150, 50) elseif have then rgb(120, 90, 60) else rgb(170, 140, 110)})

	local b = Instance.new("TextButton")
	b.Name = "Action"
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -8)
	b.Size = UDim2.new(1, -20, 0, 32)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = rgb(255, 255, 255)
	b.AutoButtonColor = true
	b.Parent = card
	corner(b, 10)
	stroke(b, rgb(60, 40, 25), 2, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.Parent = b
	if isEquipped then
		b.Text = "UNEQUIP"
		b.BackgroundColor3 = rgb(235, 110, 90)
		b.MouseButton1Click:Connect(function()
			Mounts.unequip()
		end)
	elseif have then
		b.Text = "EQUIP"
		b.BackgroundColor3 = GREEN
		b.MouseButton1Click:Connect(function()
			Mounts.equip(info.id)
		end)
	else
		b.Text = if info.source == "code" then "🎟️ FROM A CODE" else "🔒 LOCKED"
		b.BackgroundColor3 = rgb(185, 165, 140)
		b.AutoButtonColor = false
		b.Selectable = false
	end
	return card
end

function refresh()
	if not grid then
		return
	end
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local have = owned()
	local shown = 0
	for i, info in ipairs(MountUtility.getAll()) do
		if not info.hidden or have[info.id] then
			buildCard(info, i)
			shown += 1
		end
	end
	local count = 0
	for id in pairs(have) do
		if MountUtility.getInfo(id) then
			count += 1
		end
	end
	panel.Count.Text = count .. " / " .. shown .. " MOUNTS"
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "MountsUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = _L.PlayerGui

	local dim = Instance.new("TextButton")
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = rgb(20, 40, 20)
	dim.BackgroundTransparency = 0.55
	dim.Selectable = false
	dim.Parent = gui
	dim.MouseButton1Click:Connect(function()
		Mounts.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromOffset(560, 420)
	panel.BackgroundColor3 = CREAM2
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, rgb(70, 140, 60), 5, true)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		local inset = GuiService:GetGuiInset()
		scale.Scale = math.clamp(math.min((vp.X - 24) / 560, (vp.Y - inset.Y - 24) / 420), 0.45, 1.15)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = rgb(110, 200, 90)
	header.Parent = panel
	corner(header, 18)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(rgb(140, 225, 100), rgb(80, 175, 80))
	grad.Rotation = 90
	grad.Parent = header
	local title = label(header, {Size = UDim2.new(1, -150, 0, 36), Position = UDim2.fromOffset(16, 10), Text = "🐎 MOUNTS", TextColor3 = rgb(255, 255, 255), TextXAlignment = Enum.TextXAlignment.Left})
	stroke(title, rgb(35, 90, 30), 2.5)
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(42, 42)
	close.BackgroundColor3 = rgb(235, 80, 80)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.Text = "X"
	close.TextColor3 = rgb(255, 255, 255)
	close.Parent = header
	corner(close, 12)
	stroke(close, rgb(120, 25, 25), 2.5, true)
	close.MouseButton1Click:Connect(function()
		Mounts.close()
	end)

	label(panel, {Name = "Count", Size = UDim2.fromOffset(220, 22), Position = UDim2.fromOffset(16, 64), Text = "0 / 0 MOUNTS", TextXAlignment = Enum.TextXAlignment.Left})
	local hint = label(panel, {Name = "Hint", Size = UDim2.new(1, -252, 0, 18), Position = UDim2.fromOffset(236, 66), TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold, TextColor3 = rgb(130, 100, 70),
		Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap 🐎 RIDE to hop on / off" else "Ride / dismount: G  ·  🎮 D-Pad Up"})
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 14
	lim.Parent = hint

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(12, 94)
	grid.Size = UDim2.new(1, -24, 1, -106)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = rgb(160, 120, 80)
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(160, 222)
	gl.CellPadding = UDim2.fromOffset(10, 10)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.Parent = grid
	local gpad = Instance.new("UIPadding")
	gpad.PaddingTop = UDim.new(0, 4)
	gpad.PaddingBottom = UDim.new(0, 8)
	gpad.Parent = grid
end

function Mounts.open()
	if not data then
		return
	end
	if not gui then
		build()
	end
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		local cur = UI._current:Get()
		if cur then
			UI.Close({name = cur})
		end
	end)
	isOpen = true
	refresh()
	gui.Enabled = true
	local sc = panel:FindFirstChildOfClass("UIScale")
	local target = sc.Scale
	sc.Scale = target * 0.85
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = target}):Play()
	sfx("UI_Open")
	if UserInputService.GamepadEnabled then
		task.defer(function()
			for _, c in ipairs(grid:GetChildren()) do
				if c:IsA("Frame") and c.LayoutOrder <= 1 and c:FindFirstChild("Action") and c.Action.Selectable then
					GuiService.SelectedObject = c.Action
					return
				end
			end
		end)
	end
end

function Mounts.close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	sfx("UI_Close")
end

function Mounts.isOpen()
	return isOpen
end

------------------------------------------------------------ "NEW MOUNT!" card
local function playUnlock(id)
	local info = MountUtility.getInfo(id)
	if not info then
		return
	end
	local tg = _L.PlayerGui:FindFirstChild("MountUnlockToast")
	if not tg then
		tg = Instance.new("ScreenGui")
		tg.Name = "MountUnlockToast"
		tg.ResetOnSpawn = false
		tg.DisplayOrder = 12
		tg.Parent = _L.PlayerGui
	end
	local color = RARITY_COLOR[info.rarity] or GREEN
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 110)
	card.Size = UDim2.fromOffset(310, 84)
	card.BackgroundColor3 = CREAM
	card.Parent = tg
	corner(card, 16)
	stroke(card, color, 4, true)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = card
	makeIcon(card, info, false, UDim2.fromOffset(64, 64)).Position = UDim2.fromOffset(10, 10)
	local head = label(card, {Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(80, 8), Text = "🎉 NEW MOUNT!", TextColor3 = rgb(255, 190, 40)})
	stroke(head, rgb(90, 55, 20), 2)
	label(card, {Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(80, 33), Text = (info.emoji or "🐎") .. " " .. info.name})
	label(card, {Size = UDim2.new(1, -90, 0, 16), Position = UDim2.fromOffset(80, 59), Text = "Added to your Mounts!", Font = Enum.Font.GothamBold, TextColor3 = rgb(110, 80, 50)})
	for i = 1, 6 do
		local s = label(tg, {Text = "✨", Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 152)})
		local a = (i / 6) * math.pi * 2
		TweenService:Create(s, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(a) * 180, 0, 152 + math.sin(a) * 60), TextTransparency = 1,
		}):Play()
		task.delay(0.75, function()
			s:Destroy()
		end)
	end
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	sfx("Mutation_Rare")
	task.delay(3.2, function()
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
		task.wait(0.3)
		card:Destroy()
	end)
end

------------------------------------------------------------ ride / dismount button (only while a mount is equipped)
local function updateRideButton()
	if not rideButton then
		return
	end
	local show = equipped() ~= nil or riding() ~= nil
	rideGui.Enabled = show
	rideButton.Text = if riding() then "🐎 DISMOUNT" else "🐎 RIDE"
	rideButton.BackgroundColor3 = if riding() then rgb(235, 140, 70) else GREEN
end

local function buildRideButton()
	rideGui = Instance.new("ScreenGui")
	rideGui.Name = "MountRideButton"
	rideGui.ResetOnSpawn = false
	rideGui.DisplayOrder = 4
	rideGui.Enabled = false
	rideGui.Parent = _L.PlayerGui
	rideButton = Instance.new("TextButton")
	rideButton.Name = "Ride"
	rideButton.AnchorPoint = Vector2.new(0.5, 1)
	rideButton.Position = UDim2.new(0.5, 0, 1, -14)
	rideButton.Size = UDim2.fromOffset(150, 42)
	rideButton.Font = Enum.Font.FredokaOne
	rideButton.TextScaled = true
	rideButton.TextColor3 = rgb(255, 255, 255)
	rideButton.BackgroundColor3 = GREEN
	rideButton.Parent = rideGui
	corner(rideButton, 14)
	stroke(rideButton, rgb(60, 40, 25), 2.5, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 7)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = rideButton
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Color = rgb(60, 40, 25)
	ts.Thickness = 1.5
	ts.Parent = rideButton
	if UserInputService.KeyboardEnabled then
		local key = label(rideButton, {Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 2, 0, -2), Text = "G", TextColor3 = BROWN, BackgroundTransparency = 0, BackgroundColor3 = CREAM})
		corner(key, 6)
	end
	rideButton.MouseButton1Click:Connect(Mounts.toggleRide)
end

------------------------------------------------------------ mount animation (every rider, local only)
-- Body: AnimationPack clips (<set>_Idle / _Walk / _Run loops blended by speed, plus Start / Stop / Jump /
-- Land / Celebrate one-shots). Leg / neck / tail joints (rigged mounts) keep the speed-synced code below.
local JOINTS = {"Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "NeckJoint", "TailJoint", "BodyJoint"}
local animState = {} -- [model] = {phase, amt, run, motors, set, ...}
local STOP_AFTER = 0.5 -- moved at least this long before a stop settles

-- one-shot: your uploaded animation (Databases.AnimationIds) when it is loaded, else the AnimationPack clip
local function playShot(st, action, delay)
	if AnimationPack.trackShot(st.tracks, action) then
		return
	end
	AnimationPack.play(st, AnimationPack.resolve(st.set, action), delay)
end
local rodeAt = {} -- [player] = os.clock() when they hopped on (celebrate only then, not when a mount streams in)

local function animate(dt)
	local t = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local model = character and character:FindFirstChild("RideMount")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if model and root and model.PrimaryPart then
			local st = animState[model]
			if not st then
				local motors = {}
				for _, name in ipairs(JOINTS) do
					local j = model.PrimaryPart:FindFirstChild(name)
					if j and j:IsA("Motor6D") then
						motors[name] = j
					end
				end
				local info = MountUtility.getInfo(model:GetAttribute("MountId"))
				st = {phase = 0, amt = 0, run = 0, motors = motors, gait = (info and info.gait) or {}, set = info and info.anim_set,
					moving = false, movedFor = 0, air = false, airFor = 0, idleT = math.random() * 4}
				animState[model] = st
				-- your uploaded Deer / Mount animations (Root -> Body rig), if any IDs are set
				st.tracks = AnimationPack.trackSet(model, st.set or "Mount", "Mount")
				-- hopping on: a short proud celebrate
				if os.clock() - (rodeAt[player] or -math.huge) < 3 then
					playShot(st, "Celebrate", 0.25)
				end
				model.AncestryChanged:Connect(function(_, parent)
					if not parent then
						AnimationPack.trackStop(st.tracks)
						animState[model] = nil
					end
				end)
			end
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local gait = st.gait
			local runSpeed = gait.run_speed or 26
			local moving = if speed > 1.5 then 1 else 0
			local running = if speed > runSpeed then 1 else 0
			local k = math.min(1, dt * 8)
			st.amt += (moving - st.amt) * k
			st.run += (running - st.run) * k
			local rate = (gait.walk_rate or 1.1) + ((gait.run_rate or 1.6) - (gait.walk_rate or 1.1)) * st.run
			st.phase += dt * math.clamp(speed, 4, 40) * 0.42 * rate
			local p = st.phase
			local swing = 0.55 * st.amt * (1 + 0.25 * st.run)
			-- walk: diagonal pairs; run (gallop): front pair / back pair
			local walkFL, walkFR = math.sin(p), math.sin(p + math.pi)
			local runF, runB = math.sin(p), math.sin(p + math.pi * 0.8)
			local fl = walkFL + (runF - walkFL) * st.run
			local fr = walkFR + (runF * 0.9 - walkFR) * st.run
			local bl = walkFR + (runB - walkFR) * st.run
			local br = walkFL + (runB * 0.9 - walkFL) * st.run
			local m = st.motors
			if m.Leg_FL then m.Leg_FL.Transform = CFrame.Angles(fl * swing, 0, 0) end
			if m.Leg_FR then m.Leg_FR.Transform = CFrame.Angles(fr * swing, 0, 0) end
			if m.Leg_BL then m.Leg_BL.Transform = CFrame.Angles(bl * swing, 0, 0) end
			if m.Leg_BR then m.Leg_BR.Transform = CFrame.Angles(br * swing, 0, 0) end
			if m.NeckJoint then
				local idle = math.sin(t * 1.6) * 0.05 * (1 - st.amt)
				local nod = math.sin(p * 2) * 0.09 * st.amt
				m.NeckJoint.Transform = CFrame.Angles(idle + nod, math.sin(t * 0.5) * 0.08 * (1 - st.amt), 0)
			end
			-- one-shots: start / stop moving, jump / land (Humanoid floor state, works for every rider)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local inAir = humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air
			if inAir and not st.air and v.Y > 2 then
				playShot(st, "Jump")
			elseif not inAir and st.air and st.airFor > 0.25 then
				playShot(st, "Land")
			end
			st.airFor = if inAir then st.airFor + dt else 0
			st.air = inAir
			local nowMoving = speed > 1.5
			if not inAir and not AnimationPack.playing(st) and not AnimationPack.trackBusy(st.tracks) then
				if nowMoving and not st.moving then
					playShot(st, "Start")
				elseif not nowMoving and st.moving and st.movedFor > STOP_AFTER then
					playShot(st, "Stop")
				end
			end
			st.movedFor = if nowMoving then st.movedFor + dt else 0
			st.moving = nowMoving

			-- uploaded loops (Idle / Walk / Run): crossfaded only when the gait changes, sped up with the stride
			local loopAction = if st.amt < 0.5 then "Idle" elseif st.run > 0.5 then "Run" else "Walk"
			local loopSpeed = if loopAction == "Idle" then 1 else math.clamp(speed / (if loopAction == "Run" then runSpeed else 10), 0.6, 1.8)
			local trackLoop = AnimationPack.trackLoop(st.tracks, loopAction, loopSpeed)
			local trackDriven = (trackLoop or AnimationPack.trackBusy(st.tracks)) and not AnimationPack.playing(st)

			-- single-mesh mounts: the whole body plays the clips (rider sits on Root, so the saddle stays put).
			-- While an uploaded animation drives the Body joint, the procedural layer leaves it alone.
			if m.BodyJoint and not trackDriven then
				st.idleT += dt
				local cycle = (p / (math.pi * 2)) % 1 -- walk / run clips are synced to the stride (no foot sliding)
				local walkClip = AnimationPack.get(AnimationPack.resolve(st.set, "Walk"))
				local runClip = AnimationPack.get(AnimationPack.resolve(st.set, "Run"))
				local idle = AnimationPack.sample(AnimationPack.resolve(st.set, "Idle"), st.idleT)
				local walk = AnimationPack.sample(AnimationPack.resolve(st.set, "Walk"), cycle * walkClip.duration)
				local run = AnimationPack.sample(AnimationPack.resolve(st.set, "Run"), cycle * runClip.duration)
				local pose = idle:Lerp(walk:Lerp(run, st.run), st.amt)
				m.BodyJoint.Transform = AnimationPack.shot(st, dt, pose)
			end
			if m.TailJoint then
				m.TailJoint.Transform = CFrame.Angles(0.15 * st.amt, math.sin(t * (4 + 6 * st.amt)) * 0.35, 0)
			end
		end
	end
end

------------------------------------------------------------
function Mounts._init()
	Network = _L.Get {"Common", "Library", "Network"}
	MountUtility = _L.Get {"Common", "Modules", "Utilities", "MountUtility"}
	MountsDB = _L.Get {"Common", "Modules", "Databases", "Mounts"}
	AnimationPack = _L.Get {"Client", "Modules", "Classes", "AnimationPack"}
end

function Mounts._start()
	Network.Remote.Fired("C_Mount_Unlocked", function(id)
		if typeof(id) == "string" then
			pcall(playUnlock, id)
		end
	end)
	buildRideButton()
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		data = Data.Await()
		data:Bind("mounts", function()
			updateRideButton()
			if isOpen then
				refresh()
			end
		end)
		updateRideButton()
	end)
	-- while riding, the (raised) rider must not trip over / tip into FallingDown when bumping into things
	local function rideStability()
		local humanoid = _L.Player.Character and _L.Player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local on = riding() == nil
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, on)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, on)
		end
	end
	_L.Player:GetAttributeChangedSignal("RidingMount"):Connect(function()
		rideStability()
		updateRideButton()
		if isOpen then
			refresh()
		end
	end)

	ContextActionService:BindAction("FB_MountRide", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if not equipped() and not riding() then
			return Enum.ContextActionResult.Pass
		end
		task.spawn(Mounts.toggleRide)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)

	local function watchRide(player)
		player:GetAttributeChangedSignal("RidingMount"):Connect(function()
			if player:GetAttribute("RidingMount") then
				rodeAt[player] = os.clock()
			end
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watchRide(player)
	end
	Players.PlayerAdded:Connect(watchRide)
	Players.PlayerRemoving:Connect(function(player)
		rodeAt[player] = nil
	end)

	-- PreSimulation runs after the character's Animator, so our leg poses aren't overwritten
	RunService.PreSimulation:Connect(animate)

	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI._current:Bind(function(v)
			if v and isOpen then
				Mounts.close()
			end
		end)
	end)
end

return Mounts
