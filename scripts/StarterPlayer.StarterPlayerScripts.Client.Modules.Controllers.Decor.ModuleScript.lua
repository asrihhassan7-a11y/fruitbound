--> Decor (client)
-- Decorate your own farm: walk to the Decor Bench at your farm entrance and press E.
--  * pick a decoration in the bottom bar -> a green preview follows your mouse (or tap on mobile)
--  * click / Place to build it (Coins), R or Rotate to turn it, Q / Cancel to stop
--  * Pick up mode: click a decoration to put it away (full refund)
-- The server (Farm controller) validates everything; this only previews.

local _L = _G._L

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Network
local FarmDecor
local NumberUtility

local rgb = Color3.fromRGB
local CREAM, CREAM2, BROWN, GREEN, RED, GOLD = rgb(255, 248, 230), rgb(245, 232, 200), rgb(90, 60, 30), rgb(110, 190, 80), rgb(235, 90, 80), rgb(255, 200, 60)
local PLOT_HALF = 70
local BENCH_AT = Vector3.new(-18, 0, 64)

local Decor = {}

local data
local gui, panel, hintBar, hintText, placeBtn, pickBtn, coinsLabel
local cards = {}
local isOpen = false
local mode = "browse" -- browse / place / pickup
local selected -- FarmDecor item
local rotation = 0
local ghost, ghostFoot, ghostBox
local ghostPos -- Vector3 in plot space
local ghostValid = false
local highlight
local hovered -- decor model under the mouse in pickup mode
local busy = false
local renderConn

------------------------------------------------------------ helpers
local function sfx(name)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name)
	end
end

local function notify(text, color)
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI.Get("Notifications"):add({text = text, color = color or rgb(120, 230, 120), duration = 2.5})
	end)
end

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

local function button(parent, text, color, darker)
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = text
	b.TextColor3 = rgb(255, 255, 255)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 10)
	stroke(b, darker, 2.5, true)
	stroke(b, rgb(40, 30, 20), 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	return b
end

local function myPlot()
	local island = _L.Map:FindFirstChild("FarmIsland")
	local plots = island and island:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, p in ipairs(plots:GetChildren()) do
		if p:GetAttribute("Owner") == _L.Player.UserId then
			return p
		end
	end
end

local function coins()
	return (data and data:Get({"stats", "Strength"})) or 0
end

------------------------------------------------------------ placement checks (mirror of the server)
local function rect(center, size)
	return {center.X, center.Z, size.X / 2, size.Z / 2}
end
local function hit(a, b, margin)
	margin = margin or 0
	return math.abs(a[1] - b[1]) < a[3] + b[3] + margin and math.abs(a[2] - b[2]) < a[4] + b[4] + margin
end

local function blocked(plot, me)
	for _, fixed in ipairs({
		rect(Vector3.new(0, 0, 64), Vector3.new(8, 0, 8)),
		rect(BENCH_AT, Vector3.new(7, 0, 5)),
		rect(Vector3.new(0, 0, 70), Vector3.new(26, 0, 3)),
	}) do
		if hit(me, fixed) then
			return true
		end
	end
	local function check(container, margin)
		if not container then
			return false
		end
		for _, m in ipairs(container:GetChildren()) do
			local c, s = m:GetAttribute("FootCenter"), m:GetAttribute("FootSize")
			if typeof(c) == "Vector3" and typeof(s) == "Vector3" and hit(me, rect(c, s), margin) then
				return true
			end
		end
		return false
	end
	local built = plot:FindFirstChild("Built")
	return check(built, 0) or check(built and built:FindFirstChild("Decor"), 0.2) or check(plot:FindFirstChild("Pads"), 0)
end

------------------------------------------------------------ preview
local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost, ghostFoot, ghostBox, ghostPos = nil, nil, nil, nil
end

local function makeGhost()
	clearGhost()
	if not selected then
		return
	end
	ghost = Instance.new("Model")
	ghost.Name = "DecorPreview"
	ghostFoot = Instance.new("Part")
	ghostFoot.Name = "Foot"
	ghostFoot.Anchored = true
	ghostFoot.CanCollide = false
	ghostFoot.CanQuery = false
	ghostFoot.CanTouch = false
	ghostFoot.Material = Enum.Material.Neon
	ghostFoot.Transparency = 0.45
	ghostFoot.Parent = ghost
	ghostBox = ghostFoot:Clone()
	ghostBox.Name = "Box"
	ghostBox.Material = Enum.Material.SmoothPlastic
	ghostBox.Transparency = 0.78
	ghostBox.Parent = ghost
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (selected.height or 3) + 2, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = ghostBox
	label(bb, {Size = UDim2.fromScale(1, 1), Text = selected.icon})
	ghost.Parent = workspace
	ghost:SetAttribute("Hidden", true)
	ghostFoot.Transparency = 1
	ghostBox.Transparency = 1
	bb.Enabled = false
end

local function updateGhost(plot, localPos)
	if not ghost or not selected then
		return
	end
	local fp = FarmDecor.footprint(selected, rotation)
	-- snap to half studs, keep inside the plot
	local x = math.floor(localPos.X * 2 + 0.5) / 2
	local z = math.floor(localPos.Z * 2 + 0.5) / 2
	ghostPos = Vector3.new(x, 0, z)
	local me = rect(ghostPos, fp)
	local inside = math.abs(x) + me[3] <= PLOT_HALF - 1.5 and math.abs(z) + me[4] <= PLOT_HALF - 1.5
	ghostValid = inside and not blocked(plot, me) and coins() >= selected.cost
	local color = if ghostValid then rgb(120, 235, 110) else rgb(255, 90, 80)
	local base = plot.Base.CFrame * CFrame.new(x, plot.Base.Size.Y / 2, z)
	ghostFoot.Size = Vector3.new(fp.X, 0.2, fp.Z)
	ghostFoot.CFrame = base * CFrame.new(0, 0.12, 0)
	ghostFoot.Color = color
	ghostFoot.Transparency = 0.45
	local h = selected.height or 3
	ghostBox.Size = Vector3.new(math.max(fp.X - 0.2, 0.4), h, math.max(fp.Z - 0.2, 0.4))
	ghostBox.CFrame = base * CFrame.new(0, h / 2 + 0.1, 0)
	ghostBox.Color = color
	ghostBox.Transparency = 0.78
	local bb = ghostBox:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb.Enabled = true
	end
	if placeBtn then
		placeBtn.BackgroundColor3 = if ghostValid then GREEN else rgb(170, 170, 160)
	end
end

local function screenToPlot(plot, screenPos, include)
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local result = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if result then
		return plot.Base.CFrame:PointToObjectSpace(result.Position), result.Instance
	end
end

local function setHover(model)
	if hovered == model then
		return
	end
	hovered = model
	if highlight then
		highlight.Adornee = model
		highlight.Enabled = model ~= nil
	end
end

local function decorUnder(plot, screenPos)
	local built = plot:FindFirstChild("Built")
	local folder = built and built:FindFirstChild("Decor")
	if not folder then
		return nil
	end
	local _, inst = screenToPlot(plot, screenPos, {folder})
	while inst and inst.Parent ~= folder do
		inst = inst.Parent
	end
	return inst
end

------------------------------------------------------------ actions
local REASONS = {
	afford = "❌ Not enough Coins!",
	blocked = "🚫 Something is in the way there",
	outside = "🚫 Keep it inside your farm",
	max = "🚫 You already have the max of this one",
	full = "🚫 Your farm is full of decorations",
	far = "🚫 Go back to your farm first",
}

local refreshCards
local setMode

local function place()
	if busy or mode ~= "place" or not selected or not ghostPos then
		return
	end
	if not ghostValid then
		if coins() < selected.cost then
			notify(REASONS.afford, RED)
		else
			notify(REASONS.blocked, RED)
		end
		return
	end
	busy = true
	local ok, reason = Network.Remote.Invoke("S_Decor_Place", selected.id, ghostPos.X, ghostPos.Z, rotation)
	busy = false
	if ok then
		sfx("Plant")
		if selected.crop then
			notify("🌱 " .. selected.name .. " planted! Harvest it when it grows.")
		end
	else
		notify(REASONS[reason] or "🚫 Can't place that there", RED)
	end
	refreshCards()
end

local function pickUp()
	if busy or mode ~= "pickup" or not hovered then
		return
	end
	local uid = hovered:GetAttribute("DecorUid")
	local item = FarmDecor.ById[hovered:GetAttribute("DecorId") or ""]
	if not uid then
		return
	end
	busy = true
	local ok = Network.Remote.Invoke("S_Decor_Remove", uid)
	busy = false
	if ok then
		sfx("Coin")
		setHover(nil)
		if item then
			notify("↩️ " .. item.name .. " put away (+💰 " .. NumberUtility.short(item.cost) .. ")", GOLD)
		end
	end
	refreshCards()
end

------------------------------------------------------------ UI
local function hintFor()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
	if pad then
		return if mode == "place" then "RT place  •  Y rotate  •  B cancel" elseif mode == "pickup" then "Face a decoration, RT to put it away" else ""
	end
	if mode == "place" then
		return if touch then "Tap the ground, then Place" else "Click to place  •  R rotate  •  Q cancel"
	elseif mode == "pickup" then
		return if touch then "Tap a decoration to put it away" else "Click a decoration to put it away (full refund)"
	end
	return ""
end

setMode = function(newMode, item)
	mode = newMode
	selected = if newMode == "place" then item else nil
	setHover(nil)
	if newMode == "place" then
		makeGhost()
	else
		clearGhost()
	end
	if hintBar then
		hintBar.Visible = newMode ~= "browse"
		hintText.Text = hintFor()
		placeBtn.Visible = newMode == "place"
		hintBar.Rotate.Visible = newMode == "place"
	end
	if pickBtn then
		pickBtn.BackgroundColor3 = if newMode == "pickup" then rgb(255, 170, 60) else rgb(150, 120, 90)
	end
	refreshCards()
end

refreshCards = function()
	local have = coins()
	if coinsLabel then
		coinsLabel.Text = "💰 " .. NumberUtility.short(math.floor(have))
	end
	for id, card in pairs(cards) do
		local item = FarmDecor.ById[id]
		local afford = have >= item.cost
		card.Price.TextColor3 = if afford then rgb(215, 150, 20) else RED
		local on = selected and selected.id == id
		card.UIStroke.Color = if on then rgb(80, 180, 60) else rgb(200, 170, 120)
		card.UIStroke.Thickness = if on then 3.5 else 2
		card.BackgroundColor3 = if on then rgb(235, 255, 215) else CREAM
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "DecorUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = _L.PlayerGui

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -14)
	panel.Size = UDim2.fromOffset(720, 150)
	panel.BackgroundColor3 = CREAM2
	panel.Parent = gui
	corner(panel, 16)
	stroke(panel, rgb(120, 85, 50), 3, true)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.clamp(math.min((vp.X - 24) / 720, vp.Y / 560), 0.5, 1)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	label(panel, {Size = UDim2.fromOffset(300, 28), Position = UDim2.fromOffset(14, 8), Text = "🌷 Decorate your farm", TextXAlignment = Enum.TextXAlignment.Left})
	coinsLabel = label(panel, {Size = UDim2.fromOffset(150, 24), Position = UDim2.fromOffset(300, 10), Text = "💰 0", TextColor3 = rgb(215, 150, 20), TextXAlignment = Enum.TextXAlignment.Left})
	stroke(coinsLabel, rgb(255, 250, 235), 1.5)

	local done = button(panel, "✔ Done", GREEN, rgb(60, 130, 50))
	done.AnchorPoint = Vector2.new(1, 0)
	done.Position = UDim2.new(1, -10, 0, 7)
	done.Size = UDim2.fromOffset(96, 30)
	done.MouseButton1Click:Connect(function()
		Decor.close()
	end)
	pickBtn = button(panel, "✋ Pick up", rgb(150, 120, 90), rgb(100, 75, 50))
	pickBtn.AnchorPoint = Vector2.new(1, 0)
	pickBtn.Position = UDim2.new(1, -114, 0, 7)
	pickBtn.Size = UDim2.fromOffset(112, 30)
	pickBtn.MouseButton1Click:Connect(function()
		setMode(if mode == "pickup" then "browse" else "pickup")
	end)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(10, 44)
	list.Size = UDim2.new(1, -20, 0, 100)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = rgb(160, 120, 80)
	list.ScrollingDirection = Enum.ScrollingDirection.X
	list.AutomaticCanvasSize = Enum.AutomaticSize.X
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = list
	local lpad = Instance.new("UIPadding")
	lpad.PaddingLeft = UDim.new(0, 3)
	lpad.PaddingRight = UDim.new(0, 3)
	lpad.Parent = list

	for _, item in ipairs(FarmDecor.Items) do
		local card = Instance.new("TextButton")
		card.Name = item.id
		card.LayoutOrder = item.order
		card.Size = UDim2.fromOffset(84, 90)
		card.BackgroundColor3 = CREAM
		card.Text = ""
		card.AutoButtonColor = true
		card.Parent = list
		corner(card, 12)
		stroke(card, rgb(200, 170, 120), 2, true)
		label(card, {Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 4), Text = item.icon})
		label(card, {Name = "ItemName", Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 44), Text = item.name})
		local price = label(card, {Name = "Price", Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 64), Text = "💰 " .. NumberUtility.short(item.cost)})
		stroke(price, rgb(255, 250, 235), 1.2)
		if item.crop then
			local badge = label(card, {Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(58, 2), Text = "🌱"})
			badge.ZIndex = 2
		end
		card.MouseButton1Click:Connect(function()
			if selected and selected.id == item.id then
				setMode("browse")
			else
				setMode("place", item)
			end
		end)
		cards[item.id] = card
	end

	-- hint bar above the panel while placing / picking up
	hintBar = Instance.new("Frame")
	hintBar.Name = "Hint"
	hintBar.AnchorPoint = Vector2.new(0.5, 1)
	hintBar.Position = UDim2.new(0.5, 0, 0, -8)
	hintBar.Size = UDim2.fromOffset(560, 40)
	hintBar.BackgroundColor3 = CREAM
	hintBar.Visible = false
	hintBar.Parent = panel
	corner(hintBar, 12)
	stroke(hintBar, rgb(120, 85, 50), 2.5, true)
	hintText = label(hintBar, {Size = UDim2.new(1, -250, 0, 24), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, Text = ""})
	local cancel = button(hintBar, "✖", RED, rgb(160, 50, 40))
	cancel.AnchorPoint = Vector2.new(1, 0.5)
	cancel.Position = UDim2.new(1, -6, 0.5, 0)
	cancel.Size = UDim2.fromOffset(40, 30)
	cancel.MouseButton1Click:Connect(function()
		setMode("browse")
	end)
	local rot = button(hintBar, "↻ Rotate", rgb(90, 160, 230), rgb(50, 110, 170))
	rot.Name = "Rotate"
	rot.AnchorPoint = Vector2.new(1, 0.5)
	rot.Position = UDim2.new(1, -52, 0.5, 0)
	rot.Size = UDim2.fromOffset(92, 30)
	rot.MouseButton1Click:Connect(function()
		rotation = (rotation + 90) % 360
	end)
	placeBtn = button(hintBar, "✔ Place", GREEN, rgb(60, 130, 50))
	placeBtn.AnchorPoint = Vector2.new(1, 0.5)
	placeBtn.Position = UDim2.new(1, -150, 0.5, 0)
	placeBtn.Size = UDim2.fromOffset(92, 30)
	placeBtn.MouseButton1Click:Connect(place)

	highlight = Instance.new("Highlight")
	highlight.FillColor = rgb(255, 210, 90)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = rgb(255, 240, 150)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = gui
end

------------------------------------------------------------ open / close
function Decor.open()
	if isOpen then
		return
	end
	local plot = myPlot()
	if not plot then
		notify("🌱 Your farm is still loading...", RED)
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
	rotation = 0
	gui.Enabled = true
	setMode("browse")
	panel.Position = UDim2.new(0.5, 0, 1, 170)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 1, -14)}):Play()
	sfx("UI_Open")

	renderConn = RunService.RenderStepped:Connect(function()
		local p = myPlot()
		local char = _L.Player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not p or not root or (hum and hum.Health <= 0) then
			Decor.close()
			return
		end
		local rel = p.Base.CFrame:PointToObjectSpace(root.Position)
		if math.abs(rel.X) > PLOT_HALF + 40 or math.abs(rel.Z) > PLOT_HALF + 40 then
			Decor.close()
			return
		end
		-- controller: the preview sits a few studs in front of your character
		local lastType = UserInputService:GetLastInputType()
		if lastType.Name:find("Gamepad") then
			if mode == "place" then
				local front = root.Position + root.CFrame.LookVector * 9
				updateGhost(p, p.Base.CFrame:PointToObjectSpace(front))
			elseif mode == "pickup" then
				local vp = workspace.CurrentCamera.ViewportSize
				setHover(decorUnder(p, Vector2.new(vp.X / 2, vp.Y / 2)))
			end
		-- mouse users: the preview follows the mouse (touch users move it by tapping)
		elseif UserInputService.MouseEnabled then
			local mouse = UserInputService:GetMouseLocation() -- viewport coordinates
			if mode == "place" then
				local localPos = screenToPlot(p, mouse, {p.Base})
				if localPos then
					updateGhost(p, localPos)
				end
			elseif mode == "pickup" then
				setHover(decorUnder(p, mouse))
			end
		elseif mode == "place" and ghostPos then
			updateGhost(p, ghostPos) -- keep colour / rotation up to date
		end
	end)
end

function Decor.close()
	if not isOpen then
		return
	end
	isOpen = false
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	setMode("browse")
	if gui then
		gui.Enabled = false
	end
	sfx("UI_Close")
end

------------------------------------------------------------
function Decor._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FarmDecor = _L.Get {"Common", "Modules", "Databases", "FarmDecor"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
end

function Decor._start()
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		data = Data.Await()
		data:Bind("stats", function()
			if isOpen then
				refreshCards()
			end
		end)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name ~= "DecoratePrompt" then
			return
		end
		local bench = prompt:FindFirstAncestor("DecorBench")
		if bench and bench:GetAttribute("Owner") ~= _L.Player.UserId then
			notify("🌱 You can only decorate your own farm!", RED)
			return
		end
		Decor.open()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not isOpen or processed then
			return
		end
		local plot = myPlot()
		if not plot then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if mode == "place" then
				place()
			elseif mode == "pickup" then
				pickUp()
			end
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y) + Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
			if mode == "place" then
				local localPos = screenToPlot(plot, pos, {plot.Base})
				if localPos then
					updateGhost(plot, localPos)
				end
			elseif mode == "pickup" then
				setHover(decorUnder(plot, pos))
				pickUp()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			if mode == "place" then
				place()
			elseif mode == "pickup" then
				pickUp()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonY and mode == "place" then
			rotation = (rotation + 90) % 360
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			if mode ~= "browse" then
				setMode("browse")
			else
				Decor.close()
			end
		elseif input.KeyCode == Enum.KeyCode.R and mode == "place" then
			rotation = (rotation + 90) % 360
		elseif input.KeyCode == Enum.KeyCode.Q then
			setMode("browse")
		end
	end)
end

return Decor
