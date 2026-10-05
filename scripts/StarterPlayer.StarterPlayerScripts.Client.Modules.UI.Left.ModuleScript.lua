--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Timer
local FastTween
local cancellableDelay
local Constants
local AttributeUtility
local TrackerUtility
local UIAnimationController
local Module3D

--> Constants
local SEED_GARDEN_ENABLED = false -- Temporarily disabled; set to true to re-enable Seed Garden UI

------------->
local Left = {
	name = script.Name
}

function Left:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	UIAnimationController = _L.Get {"Client", "Modules", "Controllers", "UIAnimationController"}
	Module3D = _L.Get {"Common", "Library", "Classes", "Module3D"}
end

function Left:_start()
	self.object = _L.PlayerGui.Main.Left
	self._uiTrove = Trove.new()
	self._uiTrove:AttachToInstance(self.object)
	local myFarmButton = self.object.Content:FindFirstChild("MyFarm")
	-- Seed Garden disabled (SEED_GARDEN_ENABLED = false). My Farm now only opens the travel menu.
	if myFarmButton and SEED_GARDEN_ENABLED then
		self._uiTrove:Connect(myFarmButton.MouseButton1Click, function()
			local ok, SeedGarden = pcall(_L.Get, {"Client", "Modules", "Controllers", "SeedGarden"})
			if ok and SeedGarden and SeedGarden.open then
				SeedGarden.open()
			end
		end)
	end
	
	local data = Data.Await()

	if data then
		local og = self.object.Position
		
		--Tracker.Subscribe({UI._current, data:Track("tutorial_marker")}, function()
		--	local s = UI._current:Get()
		--	local t = data:Get("tutorial_marker")
		--	self.object.Visible = if s then false else true
		--	Spr.Target(self.object, 0.9, 3, {
		--		Position = UDim2.fromScale(og.X.Scale - if s or t < 3 then 1 else 0, og.Y.Scale)
		--	})
		--end)
	end
	
	local newExperienceInviteOptions = Instance.new("ExperienceInviteOptions")
	
	newExperienceInviteOptions.PromptMessage = "Earn x0.5 boost per friend invited!"
	
	self._uiTrove:Connect(self.object.Content.Invite.MouseButton1Down, function()
		Services.SocialService:PromptGameInvite(_L.Player, newExperienceInviteOptions)
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			self:_build_more(newExperienceInviteOptions)
		end)
		if not ok then
			warn("[Left] More menu failed:", err)
		end
	end)
end

-- LEFT BAR CLEANUP
-- Only core navigation stays on the left; secondary systems live in More.
-- Everything else moves into the MORE menu. The original buttons are NOT deleted: they stay
-- (hidden) in Left.Content so every script that uses them keeps working. The More menu shows
-- copies of them; tagged copies (UIToggleButton) open their UI by themselves, the others are wired here.
local MAIN_BUTTONS = {MyFarm = 1, Fruits = 2, Store = 3, TradeList = 4, Settings = 5, More = 6, Free = 7}
local MORE_BUTTONS = {"Mastery", "UpgradeTree", "Rebirth", "Daily", "Achievements", "Titles", "FruitBook", "Mounts", "Wheel", "Invite", "Codes", "Backpack"}
local MORE_SECTIONS = {
	{title = "🌱 Progression", buttons = {"Mastery", "Rebirth", "Achievements", "Titles", "Daily", "UpgradeTree"}},
	{title = "🍎 Collection", buttons = {"FruitBook", "Mounts"}},
	{title = "⚙️ Extras", buttons = {"Backpack", "Wheel", "Invite", "Codes"}},
}

-- The old gift box hanging at the top is kept (the Free script still updates it) but hidden;
-- this button copies its timer / gift count and animates:
--   waiting -> soft bob + timer under the icon      ready -> wiggle + glow + "Claim!" + red badge
function Left:_setup_gift_button(button)
	local top = _L.PlayerGui.Main:FindFirstChild("Top")
	local old = top and top:FindFirstChild("Free")
	if not old then
		button.Visible = false
		return
	end
	local oldNumber = old:FindFirstChild("Counter") and old.Counter:FindFirstChild("Number")
	local title = button:FindFirstChild("Title")
	local emoji = button:FindFirstChild("Emoji")
	local notif = button:FindFirstChild("Notification")

	local glow = Instance.new("UIStroke")
	glow.Name = "ReadyGlow"
	glow.Color = Color3.fromRGB(255, 225, 90)
	glow.Thickness = 0
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	glow.Parent = button

	local hasGifts = old.Visible
	local hiding = false
	local function hideOld()
		hiding = true
		old.Visible = false
		hiding = false
	end

	local baseSize = emoji and emoji.Size or UDim2.fromScale(0.62, 0.62)
	local ready = false
	local function refresh()
		button.Visible = hasGifts
		local text = oldNumber and oldNumber.Text or ""
		ready = string.sub(text, 1, 1) == "x"
		if title then
			title.Text = if ready then "Claim!" elseif text ~= "" then text else "Gifts"
		end
		if notif then
			UIAnimationController.SetNotification(notif, ready)
			glow.Thickness = if ready then 3 else 0
			local nt = notif:FindFirstChild("Title")
			if nt then
				nt.Text = string.sub(text, 2)
			end
		end
	end

	-- the Free script shows the old box when gifts are left and hides it when all are claimed
	self._uiTrove:Connect(old:GetPropertyChangedSignal("Visible"), function()
		if hiding then
			return
		end
		hasGifts = old.Visible
		hideOld()
		refresh()
	end)
	if oldNumber then
		self._uiTrove:Connect(oldNumber:GetPropertyChangedSignal("Text"), refresh)
	end
	hideOld()
	refresh()


end

function Left:_setup_fruit_companions(button)
	if button:FindFirstChild("FruitCompanions") then
		return
	end
	local icon = button:FindFirstChild("Icon")
	if icon then
		icon.Visible = false
	end
	local group = Instance.new("Frame")
	group.Name = "FruitCompanions"
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.44)
	group.Size = UDim2.fromScale(0.92, 0.82)
	group.BackgroundTransparency = 1
	group.ClipsDescendants = false
	group.Parent = button

	local function addFruit(name, position, size, zIndex)
		local source = _L.Assets.Models.Fruits:FindFirstChild(name)
		if not source then
			return
		end
		local slot = Instance.new("Frame")
		slot.Name = name
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Position = position
		slot.Size = size
		slot.BackgroundTransparency = 1
		slot.ZIndex = zIndex
		slot.Parent = group
		local model = source:Clone()
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.PivotOffset = CFrame.new()
			end
		end
		local model3D = Module3D:Attach3D(slot, model)
		self._uiTrove:Add(function()
			model3D:Destroy()
			model:Destroy()
		end)
		model3D.LightColor = Color3.fromRGB(255, 255, 255)
		model3D.Ambient = Color3.fromRGB(245, 245, 245)
		model3D.LightDirection = Vector3.new(1, 1, 1)
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0))
		model3D.AdornFrame.ZIndex = zIndex
		model3D.Visible = true
	end

	addFruit("Strawberry", UDim2.fromScale(0.68, 0.36), UDim2.fromScale(0.56, 0.72), 2)
	addFruit("Apple", UDim2.fromScale(0.35, 0.55), UDim2.fromScale(0.68, 0.85), 3)
end

function Left:_polish_main_buttons(content)
	local responsiveScale = content:FindFirstChild("FB_ResponsiveScale")
	if responsiveScale then
		responsiveScale:Destroy()
	end
	local function updateScale()
		local viewport = workspace.CurrentCamera.ViewportSize
		local compact = viewport.Y <= 500 or viewport.X <= 700
		local cell = if compact then 48 else 64
		local columns = if compact then 3 else 2
		local layout = content:FindFirstChildOfClass("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(cell, cell)
		layout.CellPadding = UDim2.fromOffset(10, compact and 12 or 16)
		layout.FillDirectionMaxCells = columns
		local height = if compact then 180 else cell * 4 + 66
		local width = cell * columns + (columns - 1) * 10
		self.object.AnchorPoint = compact and Vector2.zero or Vector2.new(0, 0.5)
		self.object.Position = compact and UDim2.fromOffset(14, 8 - math.min(0, self.object.Parent.AbsolutePosition.Y)) or UDim2.fromScale(0.02, 0.48)
		self.object.Size = UDim2.fromOffset(width, height)
		content.AnchorPoint = Vector2.zero
		content.Position = UDim2.fromOffset(0, 0)
		content.Size = UDim2.fromOffset(width, height)
		for _, button in ipairs(content:GetChildren()) do
			local title = button:FindFirstChild("Title")
			if button:IsA("GuiButton") and MAIN_BUTTONS[button.Name] and title and title:IsA("TextLabel") then
				title.AnchorPoint = Vector2.new(0.5, 0)
				title.Position = UDim2.fromScale(0.5, 0.93)
				title.Size = UDim2.fromScale(1.1, 0.25)
			end
		end
	end
	self._uiTrove:Connect(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
	self._uiTrove:Connect(self.object.Parent:GetPropertyChangedSignal("AbsolutePosition"), updateScale)
	updateScale()
	local colors = {
		MyFarm = Color3.fromRGB(226, 255, 211),
		Fruits = Color3.fromRGB(255, 244, 184),
		Store = Color3.fromRGB(255, 226, 190),
		TradeList = Color3.fromRGB(211, 238, 255),
		Settings = Color3.fromRGB(232, 229, 242),
		More = Color3.fromRGB(225, 249, 215),
	}
	for name, color in pairs(colors) do
		local button = content:FindFirstChild(name)
		local front = button and button:FindFirstChild("Front")
		if front and front:IsA("ImageLabel") then
			front.ImageColor3 = color
		end
	end
	local fruits = content:FindFirstChild("Fruits")
	if fruits then
		local scale = fruits:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1
		end
		self:_setup_fruit_companions(fruits)
		local emphasis = Instance.new("UIStroke")
		emphasis.Name = "FB_FruitEmphasis"
		emphasis.Color = Color3.fromRGB(255, 209, 77)
		emphasis.Thickness = 3
		emphasis.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		emphasis.Parent = fruits
	end
	local selectedNames = {Fruits = true, Store = true, TradeList = true, Settings = true}
	UI._current:Bind(function(value)
		for name in pairs(selectedNames) do
			UIAnimationController.SetSelected(content:FindFirstChild(name), value == name)
		end
	end)
end

function Left:_build_more(inviteOptions)
	if self._moreBuilt then
		return
	end
	self._moreBuilt = true
	local CollectionService = game:GetService("CollectionService")
	local content = self.object.Content

	-- makes a new side button out of an existing one (same look), with a new name / title / emoji
	local function makeButton(template, name, title, emoji, keepToggleTag)
		local b = template:Clone()
		b.Name = name
		if not keepToggleTag then
			CollectionService:RemoveTag(b, "UIToggleButton")
		end
		local notif = b:FindFirstChild("Notification")
		if notif then
			notif.Visible = false
		end
		if b:FindFirstChild("Title") then
			b.Title.Text = title
		end
		local emojiLabel = b:FindFirstChild("Emoji")
		if emoji then
			if not emojiLabel then
				emojiLabel = Instance.new("TextLabel")
				emojiLabel.Name = "Emoji"
				emojiLabel.BackgroundTransparency = 1
				emojiLabel.TextScaled = true
				emojiLabel.Font = Enum.Font.FredokaOne
				emojiLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				emojiLabel.Position = UDim2.fromScale(0.5, 0.42)
				emojiLabel.Size = UDim2.fromScale(0.62, 0.62)
				emojiLabel.Parent = b
			end
			emojiLabel.Text = emoji
			emojiLabel.Visible = true
			if b:FindFirstChild("Icon") then
				b.Icon.Visible = false
			end
		end
		return b
	end

	-- 1) left bar: Shop and More
	if content.Store:FindFirstChild("Title") then
		content.Store.Title.Text = "Store"
	end
	local moreButton = content:FindFirstChild("More")
	if not moreButton then
		moreButton = makeButton(content.Mastery, "More", "More", "🌼", false)
		moreButton.Parent = content
	end
	if not content:FindFirstChild("Backpack") then
		local backpackButton = makeButton(content.Mastery, "Backpack", "Backpack", "🎒", false)
		backpackButton.Parent = content
	end

	-- FREE GIFTS: moved from the top of the screen into the left bar ("Free" = opens the Free UI)
	local giftButton = content:FindFirstChild("Free")
	if not giftButton then
		giftButton = makeButton(content.Mastery, "Free", "Gifts", "🎁", true)
		giftButton.Parent = content
	end
	self:_setup_gift_button(giftButton)

	for _, b in ipairs(content:GetChildren()) do
		if b:IsA("GuiButton") then
			if MAIN_BUTTONS[b.Name] then
				b.LayoutOrder = MAIN_BUTTONS[b.Name]
				if b ~= giftButton then
					b.Visible = true
				end
			else
				b.Visible = false
			end
		end
	end
	-- keep them hidden even if another script shows one again (e.g. Season / Clans)
	for _, b in ipairs(content:GetChildren()) do
		if b:IsA("GuiButton") and not MAIN_BUTTONS[b.Name] then
			self._uiTrove:Connect(b:GetPropertyChangedSignal("Visible"), function()
				if b.Visible then
					b.Visible = false
				end
			end)
		end
	end

	for _, button in ipairs(content:GetChildren()) do
		if button:IsA("GuiButton") and MAIN_BUTTONS[button.Name] then
			local badge = button:FindFirstChild("Notification")
			if badge and badge:IsA("GuiObject") then
				badge.AnchorPoint = Vector2.new(1, 0)
				badge.Position = UDim2.fromScale(0.97, 0.03)
			end
		end
	end
	self:_polish_main_buttons(content)
	-- 2) the MORE menu
	local gui = Instance.new("ScreenGui")
	gui.Name = "MoreMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = _L.PlayerGui
	self._uiTrove:Add(gui)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(20, 40, 20)
	backdrop.BackgroundTransparency = 0.55
	backdrop.ZIndex = 0
	backdrop.Parent = gui

	local panel = Instance.new("CanvasGroup")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.88, 0.86)
	panel.BackgroundColor3 = Color3.fromRGB(255, 246, 220)
	panel.ZIndex = 2
	panel.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1.05
	aspect.Parent = panel
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(470, 450)
	sizeLimit.MinSize = Vector2.new(170, 165) -- small enough for tiny phone screens
	sizeLimit.Parent = panel
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0.07, 0)
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(70, 140, 60)
	panelStroke.Thickness = 5
	panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	panelStroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromScale(1, 0.16)
	header.BackgroundColor3 = Color3.fromRGB(110, 200, 90)
	header.Parent = panel
	Instance.new("UICorner", header).CornerRadius = UDim.new(0.4, 0)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(140, 225, 100), Color3.fromRGB(80, 175, 80))
	grad.Rotation = 90
	grad.Parent = header

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(0.7, 0.8)
	title.Position = UDim2.fromScale(0.05, 0.1)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "🌿 More"
	title.Parent = header
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 2.5
	titleStroke.Color = Color3.fromRGB(35, 90, 30)
	titleStroke.Parent = title

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.fromScale(0.97, 0.5)
	close.Size = UDim2.fromScale(0.13, 0.78)
	close.BackgroundColor3 = Color3.fromRGB(235, 80, 80)
	close.Font = Enum.Font.FredokaOne
	close.TextScaled = true
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = header
	local closeSize = Instance.new("UISizeConstraint")
	closeSize.MinSize = Vector2.new(44, 44)
	closeSize.Parent = close
	local closeAspect = Instance.new("UIAspectRatioConstraint")
	closeAspect.Parent = close
	Instance.new("UICorner", close).CornerRadius = UDim.new(0.3, 0)
	local closeStroke = Instance.new("UIStroke")
	closeStroke.Thickness = 2.5
	closeStroke.Color = Color3.fromRGB(120, 25, 25)
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = close

	-- sections: small title + a row of buttons each (Progression / Social / Other)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0.05, 6, 0.19, 0)
	grid.Size = UDim2.new(0.9, -12, 0.78, 0)
	grid.Parent = panel
	local sectionList = Instance.new("UIListLayout")
	sectionList.SortOrder = Enum.SortOrder.LayoutOrder
	sectionList.Padding = UDim.new(0, 4)
	sectionList.Parent = grid
	local sectionRows = {}
	for si, section in ipairs(MORE_SECTIONS) do
		local head = Instance.new("TextLabel")
		head.Name = "SectionTitle" .. si
		head.LayoutOrder = si * 2 - 1
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 24)
		head.Font = Enum.Font.FredokaOne
		head.TextScaled = true
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.TextColor3 = Color3.fromRGB(95, 65, 40)
		head.Text = section.title
		head.Parent = grid
		local row = Instance.new("Frame")
		row.Name = "Section" .. si
		row.LayoutOrder = si * 2
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 110)
		row.Parent = grid
		local rl = Instance.new("UIGridLayout")
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.CellSize = UDim2.fromOffset(64, 64)
		rl.CellPadding = UDim2.fromOffset(8, 24)
		rl.FillDirectionMaxCells = 6
		rl.Parent = row
		for bi, name in ipairs(section.buttons) do
			sectionRows[name] = {row = row, order = bi, count = #section.buttons}
		end
	end

	local desiredOpen = false
	local function setOpen(open)
		desiredOpen = open
		if open then
			local current = UI._current:Get()
			if current then
				UI.Close({name = current}, true)
				UI._current:Set(nil)
			end
			local travel = _L.PlayerGui:FindFirstChild("TravelMenu")
			if travel then
				travel.Enabled = false
			end
			gui.Enabled = true
			UIAnimationController.OpenFrame(panel)
		else
			UIAnimationController.CloseFrame(panel, function()
				gui.Enabled = false
			end)
		end
	end

	self._uiTrove:Connect(content.MyFarm.MouseButton1Click, function()
		local current = UI._current:Get()
		if current then
			UI.Close({name = current}, true)
			UI._current:Set(nil)
		end
		setOpen(false)
	end)

	self._uiTrove:Connect(moreButton.MouseButton1Click, function()
		pcall(function()
			Audio.Play({name = "Plop1"})
		end)
		setOpen(not desiredOpen)
	end)
	self._uiTrove:Connect(_L.Player.CharacterRemoving, function()
		setOpen(false)
	end)

	self._uiTrove:Connect(close.MouseButton1Click, function()
		setOpen(false)
	end)
	self._uiTrove:Connect(backdrop.MouseButton1Click, function()
		setOpen(false)
	end)

	local EXTRA_ACTIONS = {
		FruitBook = function()
			local ok, FruitBook = pcall(_L.Get, {"Client", "Modules", "Controllers", "FruitBook"})
			if ok and FruitBook then
				FruitBook.open()
			end
		end,
		Mounts = function()
			local ok, MountsController = pcall(_L.Get, {"Client", "Modules", "Controllers", "Mounts"})
			if ok and MountsController then
				MountsController.open()
			end
		end,
		Codes = function()
			UI.Open({name = "Store", props = {subject = "Codes"}})
		end,
		Daily = function()
			UI.Toggle({name = "Daily"})
			UI.Close({name = "Settings"})
		end,
		Settings = function()
			UI.Toggle({name = "Settings"})
			UI.Close({name = "Daily"})
		end,
		Backpack = function()
			local backpackGui = _L.PlayerGui:FindFirstChild("Backpack")
			local window = backpackGui and backpackGui:FindFirstChild("Window")
			local ok, Backpack = pcall(_L.Get, {"Client", "Modules", "Controllers", "Backpack"})
			if ok and Backpack and Backpack.open then
				Backpack.open()
			end
			if window then
				window.Visible = true
			end
		end,
		Invite = function()
			Services.SocialService:PromptGameInvite(_L.Player, inviteOptions)
		end,
	}

	local notifSources = {}
	for i, name in ipairs(MORE_BUTTONS) do
		local original = content:FindFirstChild(name)
		if not original then
			continue
		end
		local copy = original:Clone()
		copy.Name = name -- same name: UIToggleButton copies open the same UI
		copy.Visible = true
		local badge = copy:FindFirstChild("Notification")
		if badge and badge:IsA("GuiObject") then
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.fromScale(0.97, 0.03)
		end
		local slot = sectionRows[name]
		copy.LayoutOrder = if slot then slot.order else i
		local buttonWidth = if slot then math.min(0.16, (1 - math.max(slot.count - 1, 0) * 0.025) / slot.count) else 0.16
		copy.Size = UDim2.fromScale(buttonWidth, 0.76)
		-- readable label under the icon (dark text on the cream panel)
		local ct = copy:FindFirstChild("Title")
		if ct and ct:IsA("TextLabel") then
			ct.AnchorPoint = Vector2.new(0.5, 0)
			ct.Position = UDim2.fromScale(0.5, 1.03)
			ct.Size = UDim2.fromScale(1, 0.28)
			ct.TextColor3 = Color3.fromRGB(95, 65, 40)
			local st = ct:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = Color3.fromRGB(255, 250, 235)
				st.Thickness = 1.5
			end
		end
		local ar = copy:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
		ar.AspectRatio = 1
		ar.Parent = copy
		copy.Parent = if slot then slot.row else grid

		local action = EXTRA_ACTIONS[name]
		self._uiTrove:Connect(copy.MouseButton1Click, function()
			setOpen(false)
			if action then
				pcall(function()
					Audio.Play({name = "Plop1"})
				end)
				action()
			end
		end)

		-- mirror red "!" badges and titles from the hidden original
		local origNotif = original:FindFirstChild("Notification")
		local copyNotif = copy:FindFirstChild("Notification")
		if origNotif and copyNotif then
			local function sync()
				UIAnimationController.SetNotification(copyNotif, origNotif.Visible)
				local ot, ct = origNotif:FindFirstChild("Title"), copyNotif:FindFirstChild("Title")
				if ot and ct then
					ct.Text = ot.Text
				end
			end
			sync()
			self._uiTrove:Connect(origNotif:GetPropertyChangedSignal("Visible"), sync)
			if origNotif:FindFirstChild("Title") then
				self._uiTrove:Connect(origNotif.Title:GetPropertyChangedSignal("Text"), sync)
			end
			table.insert(notifSources, origNotif)
		end
		local origTitle = original:FindFirstChild("Title")
		if origTitle and copy:FindFirstChild("Title") then
			self._uiTrove:Connect(origTitle:GetPropertyChangedSignal("Text"), function()
				copy.Title.Text = origTitle.Text
			end)
		end
	end

	for _, descendant in ipairs(panel:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = math.max(descendant.ZIndex, 3)
		end
	end

	-- the More button gets a "!" when something inside needs attention
	local moreNotif = moreButton:FindFirstChild("Notification")
	if moreNotif then
		local function syncMore()
			local any = false
			for _, n in ipairs(notifSources) do
				if n.Visible then
					any = true
				end
			end
			UIAnimationController.SetNotification(moreNotif, any, "!")
			if moreNotif:FindFirstChild("Title") then
				moreNotif.Title.Text = "!"
			end
		end
		for _, n in ipairs(notifSources) do
			self._uiTrove:Connect(n:GetPropertyChangedSignal("Visible"), syncMore)
		end
		syncMore()
	end

	local function updateRows()
		local available = backdrop.AbsoluteSize
		local panelWidth = math.min(470, available.X * 0.88, available.Y * 0.84 * 1.05)
		panel.Size = UDim2.fromOffset(panelWidth, panelWidth / 1.05)
		local width = grid.AbsoluteSize.X - 12
		local columns = if width < 360 then 3 else 6
		local cell = math.clamp(math.floor((width - (columns - 1) * 8) / columns), 44, 68)
		for _, row in ipairs(grid:GetChildren()) do
			if row:IsA("Frame") then
				local layout = row:FindFirstChildOfClass("UIGridLayout")
				layout.CellSize = UDim2.fromOffset(cell, cell)
				layout.FillDirectionMaxCells = columns
				local count = 0
				for _, child in ipairs(row:GetChildren()) do
					if child:IsA("GuiButton") then count += 1 end
				end
				row.Size = UDim2.new(1, 0, 0, math.ceil(count / columns) * (cell + 24))
			end
		end
	end
	self._uiTrove:Connect(grid:GetPropertyChangedSignal("AbsoluteSize"), updateRows)
	self._uiTrove:Connect(backdrop:GetPropertyChangedSignal("AbsoluteSize"), updateRows)
	updateRows()
	UIAnimationController.RegisterTree(panel)
	-- close the More menu whenever another window opens
	pcall(function()
		UI._current:Bind(function(value)
			if value then
				setOpen(false)
			end
		end)
	end)
end

return Left