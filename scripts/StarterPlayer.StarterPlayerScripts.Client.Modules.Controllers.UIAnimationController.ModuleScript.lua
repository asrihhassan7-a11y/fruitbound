-- // VARIABLES // --
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local UIAnimationController = {}
local buttonStates = setmetatable({}, {__mode = "k"})
local visualStates = setmetatable({}, {__mode = "k"})
local activePress

-- // FUNCTIONS // --

--[[ Releases animations owned by an interface element. ]]
local function clearTweens(state)
	for key, tween in pairs(state.tweens) do
		state.tweens[key] = nil
		tween:Cancel()
		tween:Destroy()
	end
end

--[[ Creates an owned visual lifetime for an interface element. ]]
local function getState(object)
	local state = visualStates[object]
	if state then
		return state
	end
	state = {generation = 0, tweens = {}, connections = {}}
	visualStates[object] = state
	table.insert(state.connections, object.Destroying:Connect(function()
		state.generation += 1
		clearTweens(state)
		if state.fadeProxy then
			state.fadeProxy:Destroy()
		end
		for _, connection in ipairs(state.connections) do
			connection:Disconnect()
		end
		if activePress == state then
			activePress = nil
		end
		buttonStates[object] = nil
		visualStates[object] = nil
	end))
	return state
end

--[[ Replaces an element's current visual transition. ]]
local function animate(state, key, object, properties, duration, style, completed)
	local previous = state.tweens[key]
	if previous then
		state.tweens[key] = nil
		previous:Cancel()
		previous:Destroy()
	end
	local tween = TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	state.tweens[key] = tween
	tween.Completed:Once(function(playbackState)
		if state.tweens[key] == tween then
			state.tweens[key] = nil
			if playbackState == Enum.PlaybackState.Completed and completed then
				completed()
			end
		end
		task.defer(function()
			tween:Destroy()
		end)
	end)
	tween:Play()
end


--[[ Restores an element's original visual opacity. ]]
local function restoreOpacity(state)
	for _, entry in ipairs(state.fadeEntries or {}) do
		if entry.object.Parent then
			entry.object[entry.property] = entry.value
		end
	end
end

--[[ Fades a panel while preserving its hierarchy and content colors. ]]
local function fadePanel(frame, state, opening)
	if frame:IsA("CanvasGroup") then
		if opening then
			frame.GroupTransparency = 1
		end
		animate(state, "fade", frame, {GroupTransparency = opening and 0 or 1}, opening and 0.18 or 0.12)
		return
	end
	local current = state.tweens.fade
	if current then
		state.tweens.fade = nil
		current:Cancel()
		current:Destroy()
	end
	restoreOpacity(state)
	state.fadeEntries = {}
	local objects = frame:GetDescendants()
	table.insert(objects, frame)
	for _, object in ipairs(objects) do
		local properties = {}
		if object:IsA("GuiObject") then
			table.insert(properties, "BackgroundTransparency")
		end
		if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
			table.insert(properties, "TextTransparency")
			table.insert(properties, "TextStrokeTransparency")
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") or object:IsA("ViewportFrame") then
			table.insert(properties, "ImageTransparency")
		elseif object:IsA("UIStroke") then
			table.insert(properties, "Transparency")
		end
		for _, property in ipairs(properties) do
			table.insert(state.fadeEntries, {object = object, property = property, value = object[property]})
		end
	end
	if not state.fadeProxy then
		state.fadeProxy = Instance.new("NumberValue")
		table.insert(state.connections, state.fadeProxy.Changed:Connect(function(value)
			for _, entry in ipairs(state.fadeEntries) do
				if entry.object.Parent then
					entry.object[entry.property] = entry.value + (1 - entry.value) * value
				end
			end
		end))
	end
	state.fadeProxy.Value = opening and 1 or 0
	animate(state, "fade", state.fadeProxy, {Value = opening and 0 or 1}, opening and 0.18 or 0.12, nil, function()
		if opening then
			restoreOpacity(state)
		end
	end)
end

--[[ Updates feedback without changing an element's layout. ]]
local function animateButton(state, multiplier, duration, style)
	if state.button.AbsoluteSize.X > 420 or state.button.AbsoluteSize.Y > 300 then
		return
	end
	animate(state, "button", state.scale, {Scale = state.baseScale * multiplier}, duration, style)
end

--[[ Restores feedback after an interrupted or completed press. ]]
local function releasePress()
	local state = activePress
	activePress = nil
	if state and state.button.Parent then
		state.pressed = false
		animateButton(state, state.hovering and state.hoverScale or 1, 0.18, Enum.EasingStyle.Back)
	end
end

--[[ Shows hover feedback for a registered button. ]]
function UIAnimationController.Hover(button)
	local state = buttonStates[button]
	if state then
		state.hovering = true
		if not state.pressed then
			animateButton(state, state.hoverScale, 0.12)
		end
	end
end

--[[ Restores a registered button when the pointer leaves. ]]
function UIAnimationController.Unhover(button)
	local state = buttonStates[button]
	if state then
		state.hovering = false
		if activePress == state then
			releasePress()
		else
			animateButton(state, 1, 0.12)
		end
	end
end

--[[ Shows press feedback for a registered button. ]]
function UIAnimationController.Press(button)
	local state = buttonStates[button]
	if state then
		releasePress()
		activePress = state
		state.pressed = true
		animateButton(state, state.pressScale, 0.07)
	end
end

--[[ Registers shared feedback without adding a gameplay action. ]]
function UIAnimationController.RegisterButton(button, options)
	options = options or {}
	if not button or not button:IsA("GuiButton") or buttonStates[button] or button:GetAttribute("NoAnim") then
		return false
	end
	if not options.force and CollectionService:HasTag(button, "PopButton") then
		return false
	end
	if button:FindFirstAncestorWhichIsA("BillboardGui") or button:FindFirstAncestorWhichIsA("SurfaceGui") then
		return false
	end
	local scale = button:FindFirstChildOfClass("UIScale")
	if scale and not options.force and scale.Name ~= "FB_Press" and scale.Name ~= "HudScale" then
		return false
	end
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "FB_Press"
		scale.Parent = button
	end
	local state = getState(button)
	state.button = button
	state.scale = scale
	state.baseScale = scale.Scale
	state.hoverScale = options.hoverScale or 1.05
	state.pressScale = options.pressScale or 0.95
	state.hovering = false
	state.pressed = false
	buttonStates[button] = state
	table.insert(state.connections, button.MouseEnter:Connect(function()
		UIAnimationController.Hover(button)
	end))
	table.insert(state.connections, button.MouseLeave:Connect(function()
		UIAnimationController.Unhover(button)
	end))
	table.insert(state.connections, button.MouseButton1Down:Connect(function()
		UIAnimationController.Press(button)
	end))
	table.insert(state.connections, button.MouseButton1Up:Connect(releasePress))
	table.insert(state.connections, button.Activated:Connect(function()
		if activePress == state then
			releasePress()
		else
			animateButton(state, state.hovering and state.hoverScale or 1, 0.18, Enum.EasingStyle.Back)
		end
	end))
	return true
end

--[[ Registers existing interactive descendants. ]]
function UIAnimationController.RegisterTree(root)
	if not root then
		return
	end
	if root:IsA("GuiButton") then
		UIAnimationController.RegisterButton(root)
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			UIAnimationController.RegisterButton(descendant)
		end
	end
end

--[[ Resolves a panel's existing scale without competing with its layout. ]]
local function getPanelState(frame)
	local state = getState(frame)
	if not state.panelScale then
		local scale = frame:FindFirstChildOfClass("UIScale")
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "FB_WindowScale"
			scale.Parent = frame
		end
		state.panelScale = scale
		state.panelBase = scale.Scale
	end
	state.generation += 1
	return state
end

--[[ Reveals a panel and cancels an interrupted close. ]]
function UIAnimationController.OpenFrame(frame)
	if not frame or not frame:IsA("GuiObject") then
		return
	end
	local state = getPanelState(frame)
	frame.Visible = true
	state.panelScale.Scale = state.panelBase * 0.94
	animate(state, "panel", state.panelScale, {Scale = state.panelBase}, 0.22, Enum.EasingStyle.Back)
	fadePanel(frame, state, true)
end

--[[ Hides a panel only after its current close finishes. ]]
function UIAnimationController.CloseFrame(frame, onClosed)
	if not frame or not frame:IsA("GuiObject") then
		if onClosed then
			onClosed()
		end
		return
	end
	local state = getPanelState(frame)
	local generation = state.generation
	animate(state, "panel", state.panelScale, {Scale = state.panelBase * 0.96}, 0.12, nil, function()
		if state.generation == generation and frame.Parent then
			frame.Visible = false
			if onClosed then
				onClosed()
			end
		end
	end)
	fadePanel(frame, state, false)
end

--[[ Mirrors an existing notification and highlights new availability. ]]
function UIAnimationController.SetNotification(target, visible, text)
	local badge = target
	if target and not target.Name:match("Notification") then
		badge = target:FindFirstChild("Notification")
	end
	if not badge or not badge:IsA("GuiObject") then
		return
	end
	local becameVisible = visible and not badge.Visible
	badge.Visible = visible
	local label = badge:FindFirstChild("Title")
	if text and label and label:IsA("TextLabel") then
		label.Text = text
	end
	if becameVisible then
		local scale = badge:FindFirstChild("FB_NotificationScale") or Instance.new("UIScale")
		scale.Name = "FB_NotificationScale"
		scale.Scale = 0.75
		scale.Parent = badge
		animate(getState(badge), "notification", scale, {Scale = 1}, 0.2, Enum.EasingStyle.Back)
	end
end

--[[ Highlights navigation associated with the current menu. ]]
function UIAnimationController.SetSelected(button, selected)
	if not button or not button:IsA("GuiObject") then
		return
	end
	local state = getState(button)
	if state.selected == selected then
		return
	end
	state.selected = selected
	local stroke = button:FindFirstChild("FB_Selected")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "FB_Selected"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromRGB(255, 226, 105)
		stroke.Thickness = 3
		stroke.Transparency = 1
		stroke.Parent = button
	end
	animate(state, "selected", stroke, {Transparency = selected and 0.05 or 1}, 0.15)
end

-- // INITIALIZATION // --
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		releasePress()
	end
end)
UserInputService.WindowFocusReleased:Connect(releasePress)

return UIAnimationController