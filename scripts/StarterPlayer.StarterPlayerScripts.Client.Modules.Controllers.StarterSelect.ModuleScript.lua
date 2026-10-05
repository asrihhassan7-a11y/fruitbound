--> StarterSelect (client)
-- "Choose Your Starter Fruit!" - shown ONCE to brand-new players (no fruit, never picked a starter),
-- right after the loading screen. The server decides everything (Player:_starter_choose):
-- this menu only asks. Picking: click a card -> confirm -> celebration -> gameplay.

local _L = _G._L

local Network
local FruitUtility

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local rgb = Color3.fromRGB
local CREAM, BROWN, TEXT = rgb(255, 248, 228), rgb(90, 60, 30), rgb(95, 65, 40)

local CHOICES = {
	{
		name = "Strawberry", emoji = "🍓", quote = "Sweet and reliable.",
		trait = "💖 Sweet", color = rgb(255, 95, 125), dark = rgb(170, 40, 70),
		top = {rgb(255, 205, 215), rgb(255, 150, 170)}, confetti = {"🍓", "🌸", "✨", "💖"},
	},
	{
		name = "Apple", emoji = "🍎", quote = "Fresh and balanced.",
		trait = "⚖️ Balanced", color = rgb(110, 195, 80), dark = rgb(50, 120, 40),
		top = {rgb(215, 245, 190), rgb(160, 220, 120)}, confetti = {"🍎", "🍃", "✨", "🌱"},
	},
}

---------->
local StarterSelect = {}

local function sfx(name, props)
	local ok, SoundFX = pcall(_L.Get, {"Client", "Modules", "Controllers", "SoundFX"})
	if ok and SoundFX and SoundFX.play then
		SoundFX.play(name, props)
	end
end

local function notify(text, color)
	pcall(function()
		local UI = _L.Get {"Client", "Modules", "UI"}
		UI.Get("Notifications"):add({text = text, color = color or rgb(255, 170, 60), duration = 3})
	end)
end

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	inst.Parent = props and props.Parent
	return inst
end

local function corner(r)
	return new("UICorner", {CornerRadius = if typeof(r) == "UDim" then r else UDim.new(0, r or 12)})
end

local function stroke(color, thickness, border)
	return new("UIStroke", {Color = color, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual})
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or TEXT
	return new("TextLabel", props)
end

-- 3D preview: the real fruit model, facing the camera, gently swaying
local function preview(parent, fruitName)
	local vp = new("ViewportFrame", {
		Name = "Preview", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Ambient = rgb(200, 200, 200), LightColor = rgb(255, 250, 235), LightDirection = Vector3.new(-1, -1.2, 1.5),
		Parent = parent,
	})
	local info = FruitUtility.getInfo(fruitName)
	local source = _L.Assets.Models.Fruits:FindFirstChild(info and info.model or fruitName)
	local cam = new("Camera", {FieldOfView = 30, Parent = vp})
	vp.CurrentCamera = cam
	if not source then
		text({Size = UDim2.fromScale(1, 1), Text = "?", Parent = parent})
		return nil
	end
	local model = source:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.PivotOffset = CFrame.new() -- same as the fruit followers
			d.Anchored = true
		end
	end
	model.Parent = vp
	model:PivotTo(CFrame.new())
	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	local dist = math.max(size.X, size.Y, size.Z) / (2 * math.tan(math.rad(cam.FieldOfView / 2))) * 1.25
	cam.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.08, -dist), center)
	return model, center
end

function StarterSelect.show()
	if StarterSelect._open then
		return
	end
	StarterSelect._open = true

	-- keep other menus (e.g. the Daily Gifts popup on join) out of the way until the choice is made,
	-- then open the last one that wanted to show
	local UI = _L.Get {"Client", "Modules", "UI"}
	local deferredUI
	local function closeCurrent()
		local ok, current = pcall(function()
			return UI._current:Get()
		end)
		if ok and current and StarterSelect._open then
			deferredUI = current
			pcall(UI.Close, {name = current})
		end
	end
	closeCurrent()
	local uiWatch
	pcall(function()
		uiWatch = UI._current:Bind(function(value)
			if value and StarterSelect._open then
				task.defer(closeCurrent)
			end
		end)
	end)

	local gui = new("ScreenGui", {
		Name = "StarterSelect", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = _L.PlayerGui,
	})
	local blur = new("BlurEffect", {Name = "StarterBlur", Size = 0, Parent = Lighting})
	TweenService:Create(blur, TweenInfo.new(0.5), {Size = 14}):Play()

	-- soft meadow backdrop
	local backdrop = new("Frame", {
		Active = true, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 255),
		BackgroundTransparency = 1, Parent = gui,
	}, {
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(rgb(200, 238, 180), rgb(255, 242, 215))}),
	})
	TweenService:Create(backdrop, TweenInfo.new(0.5), {BackgroundTransparency = 0.12}):Play()

	-- drifting leaves / petals
	local floaters = {}
	local FLOAT = {"🍃", "🌸", "🌱", "✨", "🍓", "🍎", "🌼"}
	for i = 1, 16 do
		local l = text({
			Text = FLOAT[(i - 1) % #FLOAT + 1], TextTransparency = 0.35, Size = UDim2.fromOffset(34, 34),
			AnchorPoint = Vector2.new(0.5, 0.5), Parent = backdrop,
		})
		table.insert(floaters, {label = l, x = math.random(), y = math.random(), speed = 0.02 + math.random() * 0.03, sway = math.random() * 6, spin = math.random(-40, 40)})
	end

	-- everything below scales down on small screens
	local root = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 600),
		BackgroundTransparency = 1, Parent = gui,
	})
	local rootScale = new("UIScale", {Scale = 0.6, Parent = root})
	local function fitScale()
		local vs = workspace.CurrentCamera.ViewportSize
		return math.min(1.15, vs.X / 680, vs.Y / 640)
	end
	TweenService:Create(rootScale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = fitScale()}):Play()
	local viewportConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		rootScale.Scale = fitScale()
	end)

	-- TITLE
	local ribbon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(470, 64),
		BackgroundColor3 = rgb(120, 200, 85), Parent = root,
	}, {corner(UDim.new(1, 0)), stroke(rgb(50, 115, 40), 4, true),
		new("UIGradient", {Rotation = 90, Color = ColorSequence.new(rgb(150, 225, 110), rgb(100, 180, 70))})})
	local title = text({
		Size = UDim2.new(1, -40, 1, -16), Position = UDim2.fromOffset(20, 8), TextColor3 = rgb(255, 255, 255),
		Text = "Choose Your Starter Fruit!", Parent = ribbon,
	})
	stroke(rgb(40, 90, 30), 2.5).Parent = title
	text({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(560, 24),
		Text = "Your first fruit buddy follows you, helps you harvest and grows with you!", TextColor3 = rgb(90, 120, 60), Parent = root,
	})

	-- CARDS
	local cardsFrame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(600, 400),
		BackgroundTransparency = 1, Parent = root,
	})

	local cards = {}
	local selected = nil
	local busy = false

	-- CONFIRM BAR (appears after picking a card)
	local confirmBar = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 524), Size = UDim2.fromOffset(500, 64),
		BackgroundColor3 = CREAM, Visible = false, Parent = root,
	}, {corner(UDim.new(1, 0)), stroke(BROWN, 3.5, true)})
	local confirmText = text({Position = UDim2.fromOffset(22, 12), Size = UDim2.new(1, -232, 1, -28), TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = confirmBar})
	local confirmBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(190, 50),
		BackgroundColor3 = rgb(120, 200, 85), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = rgb(255, 255, 255),
		Text = "✔ Yes, this one!", AutoButtonColor = true, Parent = confirmBar,
	}, {corner(UDim.new(1, 0)), stroke(rgb(50, 115, 40), 3, true), new("UIPadding", {PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)})})
	stroke(rgb(40, 90, 30), 2).Parent = confirmBtn
	local confirmScale = new("UIScale", {Parent = confirmBtn})

	local function setSelected(choice)
		selected = choice
		for _, card in ipairs(cards) do
			local on = card.choice == choice
			TweenService:Create(card.dim, TweenInfo.new(0.2), {BackgroundTransparency = if on then 1 else 0.45}):Play()
			card.check.Visible = on
			card.stroke.Thickness = if on then 7 else 4
			card.button.Text = if on then "✔ Selected" else "Choose " .. card.choice.name
		end
		confirmText.Text = "Pick " .. choice.emoji .. " " .. choice.name .. "?"
		confirmBtn.BackgroundColor3 = choice.color
		confirmBtn:FindFirstChildOfClass("UIStroke").Color = choice.dark
		if not confirmBar.Visible then
			confirmBar.Visible = true
			confirmBar.Position = UDim2.new(0.5, 0, 0, 580)
			TweenService:Create(confirmBar, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 524)}):Play()
		end
	end

	for i, choice in ipairs(CHOICES) do
		local info = FruitUtility.getInfo(choice.name) or {}
		local holder = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(if i == 1 then 0.25 else 0.75, 0, 0, 0),
			Size = UDim2.fromOffset(270, 396), BackgroundTransparency = 1, Parent = cardsFrame,
		})
		local card = new("TextButton", {
			Name = choice.name, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundColor3 = CREAM, Parent = holder,
		}, {corner(24)})
		local cardStroke = stroke(choice.color, 4, true)
		cardStroke.Parent = card
		local scale = new("UIScale", {Scale = 0.3, Parent = card})
		task.delay(0.15 + i * 0.12, function()
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end)

		-- top: coloured window with the 3D fruit
		local top = new("Frame", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 176), BackgroundColor3 = rgb(255, 255, 255), Parent = card,
		}, {corner(18), new("UIGradient", {Rotation = 90, Color = ColorSequence.new(choice.top[1], choice.top[2])})})
		-- little sunburst behind the fruit
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(150, 150),
			BackgroundColor3 = rgb(255, 255, 255), BackgroundTransparency = 0.55, Parent = top,
		}, {corner(UDim.new(1, 0))})
		local model, center = preview(top, choice.name)
		local tag = text({Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(110, 22), Text = "🌱 STARTER", TextColor3 = rgb(255, 255, 255), Parent = top})
		stroke(choice.dark, 2).Parent = tag

		-- name + quote
		text({Position = UDim2.fromOffset(14, 192), Size = UDim2.new(1, -28, 0, 36), Text = choice.emoji .. " " .. choice.name, Parent = card})
		text({Position = UDim2.fromOffset(14, 228), Size = UDim2.new(1, -28, 0, 20), Text = "\u{201C}" .. choice.quote .. "\u{201D}", TextColor3 = rgb(150, 115, 85), Font = Enum.Font.FredokaOne, Parent = card})

		-- rarity chip
		local chip = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 254), Size = UDim2.fromOffset(190, 24),
			BackgroundColor3 = rgb(225, 240, 205), Parent = card,
		}, {corner(UDim.new(1, 0)), stroke(rgb(130, 180, 100), 2, true)})
		text({Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 1, -6), Text = (info.rarity or "Common") .. "  •  Starter Fruit", TextColor3 = rgb(70, 120, 50), Parent = chip})

		-- stats
		local stats = new("Frame", {
			Position = UDim2.fromOffset(16, 286), Size = UDim2.new(1, -32, 0, 50), BackgroundColor3 = rgb(250, 238, 210), Parent = card,
		}, {corner(12)})
		local rows = {
			{"⚡ Boost", "x" .. tostring(info.boost or 1)},
			{"⭐ Max Lv", tostring(info.max_level or 50)},
			{"Trait", choice.trait},
		}
		for r, row in ipairs(rows) do
			local col = new("Frame", {Position = UDim2.new((r - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, 0, 1, 0), BackgroundTransparency = 1, Parent = stats})
			text({Position = UDim2.fromOffset(2, 5), Size = UDim2.new(1, -4, 0, 15), Text = row[1], TextColor3 = rgb(160, 125, 95), Parent = col})
			text({Position = UDim2.fromOffset(2, 22), Size = UDim2.new(1, -4, 0, 22), Text = row[2], Parent = col})
		end

		-- choose button
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -32, 0, 42),
			BackgroundColor3 = choice.color, Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = rgb(255, 255, 255),
			Text = "Choose " .. choice.name, AutoButtonColor = true, Parent = card,
		}, {corner(UDim.new(1, 0)), stroke(choice.dark, 3, true), new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})})
		stroke(choice.dark, 2).Parent = button

		-- dim overlay when the other card is selected + check badge
		local dim = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(245, 235, 215), BackgroundTransparency = 1, ZIndex = 5, Active = false, Parent = card}, {corner(24)})
		local check = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = rgb(120, 200, 85), Font = Enum.Font.FredokaOne, TextScaled = true, TextColor3 = rgb(255, 255, 255),
			Text = "✔", Visible = false, ZIndex = 6, Parent = card,
		}, {corner(UDim.new(1, 0)), stroke(rgb(50, 115, 40), 3, true), new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})})

		local entry = {choice = choice, holder = holder, card = card, scale = scale, stroke = cardStroke, dim = dim, check = check, button = button, model = model, center = center, glow = glow, hover = false, spin = 0}
		table.insert(cards, entry)

		local function hover(on)
			if busy then
				return
			end
			entry.hover = on
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = if on then 1.04 else 1}):Play()
			TweenService:Create(card, TweenInfo.new(0.18), {Position = UDim2.new(0.5, 0, 0.5, if on then -8 else 0)}):Play()
			if on then
				entry.spin = 1 -- little happy spin
			end
		end
		local function pick()
			if busy then
				return
			end
			sfx("Harvest_Pick")
			local s = new("UIScale", {Scale = 1, Parent = button})
			TweenService:Create(s, TweenInfo.new(0.12), {Scale = 0.9}):Play()
			task.delay(0.12, function()
				TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			end)
			setSelected(choice)
		end
		for _, b in ipairs({card, button}) do
			b.MouseEnter:Connect(function() hover(true) end)
			b.MouseLeave:Connect(function() hover(false) end)
			b.Activated:Connect(pick)
		end
	end

	-- animation loop: floaters, fruit sway / spin, glow pulse, confirm pulse
	local t0 = os.clock()
	local loop = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		for _, f in ipairs(floaters) do
			f.y -= f.speed * dt
			if f.y < -0.05 then
				f.y = 1.05
				f.x = math.random()
			end
			f.label.Position = UDim2.fromScale(f.x + math.sin(t + f.sway) * 0.015, f.y)
			f.label.Rotation = math.sin(t * 0.7 + f.sway) * 20 + f.spin * 0.2
		end
		for i, c in ipairs(cards) do
			if c.model then
				if c.spin > 0 then
					c.spin = math.max(0, c.spin - dt * 1.4)
				end
				local spinAngle = (1 - c.spin) * math.pi * 2
				if c.spin <= 0 then
					spinAngle = 0
				end
				local sway = math.sin(t * 1.6 + i) * math.rad(18)
				local hop = if c.hover or selected == c.choice then math.abs(math.sin(t * 5)) * 0.35 else math.sin(t * 2 + i) * 0.08
				c.model:PivotTo(CFrame.new(0, hop, 0) * CFrame.Angles(0, sway + spinAngle, 0))
			end
			c.glow.Size = UDim2.fromOffset(150 + math.sin(t * 2 + i) * 10, 150 + math.sin(t * 2 + i) * 10)
		end
		confirmScale.Scale = 1 + math.sin(t * 5) * 0.04
	end)

	local function close(fast)
		loop:Disconnect()
		viewportConn:Disconnect()
		local time = if fast then 0.25 else 0.5
		TweenService:Create(blur, TweenInfo.new(time), {Size = 0}):Play()
		TweenService:Create(backdrop, TweenInfo.new(time), {BackgroundTransparency = 1}):Play()
		TweenService:Create(rootScale, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
		for _, f in ipairs(floaters) do
			TweenService:Create(f.label, TweenInfo.new(time), {TextTransparency = 1}):Play()
		end
		task.delay(time + 0.05, function()
			gui:Destroy()
			blur:Destroy()
			StarterSelect._open = false
			pcall(function()
				if typeof(uiWatch) == "function" then
					uiWatch()
				elseif uiWatch and uiWatch.Disconnect then
					uiWatch:Disconnect()
				elseif uiWatch and uiWatch.Destroy then
					uiWatch:Destroy()
				end
			end)
			if deferredUI then
				task.delay(0.4, function()
					pcall(UI.Open, {name = deferredUI})
				end)
			end
		end)
	end

	local function celebrate(choice)
		local chosen
		for _, c in ipairs(cards) do
			if c.choice == choice then
				chosen = c
			else
				-- the other card politely leaves
				TweenService:Create(c.holder, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = c.holder.Position + UDim2.fromOffset(0, 700)}):Play()
			end
		end
		TweenService:Create(confirmBar, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, 700)}):Play()
		chosen.check.Visible = false
		chosen.button.Text = "🎉 Welcome!"
		TweenService:Create(chosen.holder, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 0)}):Play()
		TweenService:Create(chosen.scale, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.12}):Play()
		chosen.spin = 1
		chosen.hover = true

		sfx("Mutation_Rare")
		task.delay(0.15, sfx, "Sell_Coins")

		-- flash
		local flash = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 255, 240), BackgroundTransparency = 0.3, ZIndex = 20, Parent = gui})
		TweenService:Create(flash, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()

		-- confetti burst from the middle of the screen
		for i = 1, 36 do
			local l = text({
				Text = choice.confetti[(i - 1) % #choice.confetti + 1], Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45), ZIndex = 21, Parent = gui,
			})
			local ang = math.random() * math.pi * 2
			local dist = 0.2 + math.random() * 0.35
			local target = UDim2.fromScale(0.5 + math.cos(ang) * dist * 0.8, 0.45 + math.sin(ang) * dist)
			TweenService:Create(l, TweenInfo.new(0.9 + math.random() * 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = target, Rotation = math.random(-200, 200)}):Play()
			TweenService:Create(l, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.0), {TextTransparency = 1}):Play()
		end

		-- big message
		local msg = text({
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 520), Size = UDim2.fromOffset(560, 54),
			Text = choice.emoji .. " " .. choice.name .. " joined your farm! 🎉", TextColor3 = rgb(255, 255, 255), Parent = root,
		})
		stroke(choice.dark, 3.5).Parent = msg
		local msgScale = new("UIScale", {Scale = 0, Parent = msg})
		TweenService:Create(msgScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

		task.delay(2.6, close)
	end

	confirmBtn.Activated:Connect(function()
		if busy or not selected then
			return
		end
		busy = true
		local choice = selected
		confirmBtn.Text = "🌱 ..."
		local ok, success, result = pcall(Network.Remote.Invoke, "S_Starter_Choose", choice.name)
		if ok and success then
			celebrate(choice)
		elseif ok and result == "claimed" then
			close(true) -- already has a starter (another device / tab): nothing to do
		else
			busy = false
			confirmBtn.Text = "✔ Yes, this one!"
			notify("Something went wrong, please try again!")
		end
	end)

	sfx("UI_Open")
end

-- should this player see the menu? (server has the final say anyway)
local function needsStarter(data)
	return data:Get("received_starter_fruit") == false and #(data:Get("fruits") or {}) == 0
end

function StarterSelect._init()
	Network = _L.Get {"Common", "Library", "Network"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
end

function StarterSelect._start()
	task.spawn(function()
		local Data = _L.Get {"Client", "Library", "Classes", "Data"}
		local data = Data.Await()
		if not needsStarter(data) then
			return
		end
		-- wait for the loading screen to finish
		local waited = 0
		while _L.PlayerGui:FindFirstChild("LoadingScreen") and waited < 45 do
			waited += task.wait(0.2)
		end
		task.wait(0.4)
		if needsStarter(data) then
			local ok, err = pcall(StarterSelect.show)
			if not ok then
				warn("[StarterSelect]", err)
			end
		end
	end)
end

return StarterSelect
