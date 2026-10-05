--> Prompts (client)
-- One cute Fruitbound style for EVERY ProximityPrompt, drawn by us (Style = Custom):
--  * prompts on the same part are stacked in one neat column instead of drawing on top of each other
--  * attribute "PromptOffset" (Vector3, studs) on a prompt moves its bubble (e.g. Gift is shown
--    next to a player, away from their name / health billboard)
--  * keyboard key, gamepad button or tap, hold progress fill, pop-in animation
-- Triggering still goes through the normal ProximityPrompt events, so every existing prompt keeps working.

local _L = _G._L

local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local rgb = Color3.fromRGB
local CREAM, BROWN, GREEN = rgb(255, 248, 228), rgb(90, 60, 30), rgb(110, 190, 80)
local ROW_H, ROW_GAP, WIDTH = 44, 6, 230

local GAMEPAD_TEXT = {
	[Enum.KeyCode.ButtonX] = "X", [Enum.KeyCode.ButtonY] = "Y", [Enum.KeyCode.ButtonA] = "A", [Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonL1] = "LB", [Enum.KeyCode.ButtonR1] = "RB",
}

---------->
local Prompts = {}

local groups = {} -- [adornee] = {gui, list, rows = {[prompt] = row}}

local function adorneeOf(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Model") then
		return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart")
	end
	return parent
end

local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "👆"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_TEXT[prompt.GamepadKeyCode] or prompt.GamepadKeyCode.Name:gsub("Button", "")
	end
	local ok, s = pcall(UserInputService.GetStringForKeyCode, UserInputService, prompt.KeyboardKeyCode)
	return if ok and s and s ~= "" then string.upper(s) else prompt.KeyboardKeyCode.Name
end

local function layoutGroup(group)
	local n = 0
	for _ in pairs(group.rows) do
		n += 1
	end
	group.gui.Size = UDim2.fromOffset(WIDTH, math.max(n, 1) * (ROW_H + ROW_GAP))
	if n == 0 then
		group.gui:Destroy()
		groups[group.adornee] = nil
	end
end

local function getGroup(prompt)
	local adornee = adorneeOf(prompt)
	if not adornee then
		return nil
	end
	local group = groups[adornee]
	if group and group.gui.Parent then
		return group
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "FruitboundPrompt"
	gui.Active = true
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = adornee
	gui.StudsOffset = prompt:GetAttribute("PromptOffset") or Vector3.new(0, 1.5, 0) -- screen-space: X = right, Y = up
	gui.Size = UDim2.fromOffset(WIDTH, ROW_H + ROW_GAP)
	gui.Parent = _L.PlayerGui
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = list
	group = {adornee = adornee, gui = gui, list = list, rows = {}}
	groups[adornee] = group
	return group
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r or UDim.new(1, 0)
	c.Parent = p
end

local function onShown(prompt, inputType)
	local group = getGroup(prompt)
	if not group or group.rows[prompt] then
		return
	end

	local row = Instance.new("TextButton")
	row.Name = "Prompt"
	row.Text = ""
	row.AutoButtonColor = false
	row.Size = UDim2.fromOffset(WIDTH - 10, ROW_H)
	row.BackgroundColor3 = CREAM
	-- keep the same order every time (E before F, by key name)
	row.LayoutOrder = prompt.KeyboardKeyCode.Value * 10 + #prompt.ActionText % 10
	row.Parent = group.list
	corner(row)
	local st = Instance.new("UIStroke")
	st.Color = BROWN
	st.Thickness = 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = row

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = rgb(200, 240, 170)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = row
	corner(fill)

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 5, 0.5, 0)
	key.Size = UDim2.fromOffset(34, 34)
	key.BackgroundColor3 = GREEN
	key.Font = Enum.Font.FredokaOne
	key.TextScaled = true
	key.TextColor3 = rgb(255, 255, 255)
	key.Text = keyText(prompt, inputType)
	key.ZIndex = 2
	key.Parent = row
	corner(key)
	local ks = Instance.new("UIStroke")
	ks.Color = rgb(50, 110, 40)
	ks.Thickness = 2
	ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ks.Parent = key
	local kp = Instance.new("UIPadding")
	kp.PaddingTop = UDim.new(0, 6)
	kp.PaddingBottom = UDim.new(0, 6)
	kp.Parent = key

	local hasObject = prompt.ObjectText ~= ""
	local action = Instance.new("TextLabel")
	action.BackgroundTransparency = 1
	action.Position = UDim2.fromOffset(46, if hasObject then 4 else 9)
	action.Size = UDim2.new(1, -56, 0, if hasObject then 22 else 26)
	action.Font = Enum.Font.FredokaOne
	action.TextScaled = true
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextColor3 = rgb(95, 65, 40)
	action.Text = if prompt.ActionText ~= "" then prompt.ActionText else "Interact"
	action.ZIndex = 2
	action.Parent = row
	if hasObject then
		local object = Instance.new("TextLabel")
		object.BackgroundTransparency = 1
		object.Position = UDim2.fromOffset(46, 26)
		object.Size = UDim2.new(1, -56, 0, 14)
		object.Font = Enum.Font.FredokaOne
		object.TextScaled = true
		object.TextXAlignment = Enum.TextXAlignment.Left
		object.TextColor3 = rgb(150, 120, 90)
		object.Text = prompt.ObjectText
		object.ZIndex = 2
		object.Parent = row
	end

	-- tap / click support
	row.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	row.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	local conns = {}
	local holdTween
	table.insert(conns, prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			fill.Size = UDim2.fromScale(0, 1)
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1)})
			holdTween:Play()
		end
	end))
	table.insert(conns, prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		fill.Size = UDim2.fromScale(0, 1)
	end))
	table.insert(conns, prompt.Triggered:Connect(function()
		local s = Instance.new("UIScale")
		s.Scale = 0.9
		s.Parent = row
		TweenService:Create(s, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end))
	table.insert(conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		action.Text = prompt.ActionText
	end))

	-- pop in
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = row
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	group.rows[prompt] = {row = row, conns = conns}
	layoutGroup(group)

	local hidden
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		group.rows[prompt] = nil
		row:Destroy()
		if group.gui.Parent then
			layoutGroup(group)
		end
	end)
end

local function customize(d)
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

function Prompts._start()
	for _, d in ipairs(workspace:GetDescendants()) do
		customize(d)
	end
	workspace.DescendantAdded:Connect(customize)
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			local ok, err = pcall(onShown, prompt, inputType)
			if not ok then
				warn("[Prompts]", err)
			end
		end
	end)
end

return Prompts
