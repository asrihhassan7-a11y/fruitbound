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
local ArrayUtility
local UI
local Network
local Purchases
local Icon
local _Settings

--> Constants
local CREAM = Color3.fromRGB(255, 248, 230)
local ROW_COLOR = Color3.fromRGB(255, 252, 242)
local WOOD = Color3.fromRGB(120, 82, 52)
local TEXT_BROWN = Color3.fromRGB(95, 65, 40)
local LEAF_GREEN = Color3.fromRGB(96, 170, 78)
local SOFT_RED = Color3.fromRGB(226, 104, 92)

-- only settings that really do something in FruitBound (Other_Pets / Your_Pets / Auto_Rebirth are legacy)
local SETTING_ROWS = {
	Music = {order = 11, label = "Music"},
	Volume_MusicVolume = {order = 12},
	SFX = {order = 13, label = "Sound Effects"},
	Volume_SFXVolume = {order = 14},
	Volume_AmbientVolume = {order = 15},
	Auto_Collect_Zone = {order = 16, label = "Show Auto-Collect Zone"},
	Notifications = {order = 17, label = "Notifications"},
	Popups = {order = 18, label = "Reward Popups"},
	Trades = {order = 19, label = "Trade Requests"},
	Trades_Friends_Only = {order = 19.5, label = "Trades: Friends Only"},
	Your_Fruits = {order = 20, label = "Show My Fruits"},
	Other_Fruits = {order = 21, label = "Show Other Fruits"},
}

-- player-facing Stats (stats.Strength is the internal Coins balance - never renamed in data)
local STAT_ROWS = {
	Strength = {order = 1, label = "Coins"},
	Gems = {order = 2, label = "Gems"},
	Rebirths = {order = 3, label = "Rebirths"},
	Food_Collected = {order = 4, label = "Crops Harvested"},
	Fruits_Collected = {order = 5, label = "Fruits Collected"},
}

------------->
local Settings = {
	name = script.Name
}

function Settings:_init()
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Icon = _L.Get {"Client", "Modules", "Icon"}
	_Settings = _L.Get {"Common", "Modules", "Databases", "Settings"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Settings:_start()
	self.object = _L.PlayerGui.Settings
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()

	if data then
		_L.PlayerGui.Main.Left.Content.Settings.MouseButton1Down:Connect(function()
			Audio.Play({name = "Plop1"})
			UI.Toggle({name = self.name})
			UI.Close({name = "Daily"})
		end)
		
		local tab = Tracker.new("Settings")
		
		self.object.Main.Buttons.Settings.MouseButton1Down:Connect(function()
			tab:Set("Settings")
		end)
		
		self.object.Main.Buttons.Titles.MouseButton1Down:Connect(function()
			tab:Set("Titles")
		end)
		
		self.object.Main.Buttons.Stats.MouseButton1Down:Connect(function()
			tab:Set("Stats")
		end)
		
		-- real fruit-visibility settings (used by client-main) that never had a row
		local rowTemplate = self.object.Main.Middle.Settings:FindFirstChild("Popups")
		for _, settingName in ipairs({"Your_Fruits", "Other_Fruits", "Trades_Friends_Only"}) do
			if rowTemplate and not self.object.Main.Middle.Settings:FindFirstChild(settingName) then
				local row = rowTemplate:Clone()
				row.Name = settingName
				row.Parent = self.object.Main.Middle.Settings
			end
		end

		for _, settingFrame in pairs(self.object.Main.Middle.Settings:GetChildren()) do
			if settingFrame:IsA("Frame") then
				local settingName = settingFrame.Name
				
				local settingInfo = _Settings[settingName]
				
				data:Bind("settings", function(value)
					local settingData = value[settingName]
					
					settingFrame.Main.StateBtn.Image = if settingData then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_RED
					settingFrame.Main.StateBtn.TextLabel.Text = if settingData then "On" else "Off"
				end)
				
				settingFrame.Main.StateBtn.MouseButton1Down:Connect(function()
					local success, err = Network.Remote.Invoke("S_Settings_Toggle", settingName)
					
					if not success then
						if settingName == "Auto_Rebirth" and err == "owns" then
							UI.Open({name = "Store", props = {
								subject = "Gamepasses",
								subject_callback = function()
									Purchases.PromptGamepass("Auto_Rebirth")
								end,
							}})
						end
					end
				end)
			end
		end
		
		self:_build_stats(data)
		
		self._title_instances = {}
		
		for _, titleButton in pairs(self.object.Main.Middle.Titles:GetChildren()) do
			if titleButton:IsA("Frame") then
				local titleId = tonumber(titleButton.Name)

				self._title_instances[titleId] = titleButton

				titleButton.Main.MouseButton1Down:Connect(function()
					Audio.Play({name = "ButtonDown1"})
					Network.Remote.Fire("S_Titles_Toggle_Equip", titleId)
				end)
			end
		end

		data:Bind("titles", function(value)
			for titleId, titleButton in pairs(self._title_instances) do
				local _, titleData = TableUtility.match(value, function(i, v)
					return v.id == titleId
				end)

				local titleEquipped = titleData and titleData.equipped

				titleButton.Main.Equipped.Visible = titleEquipped
				titleButton.Main.Locked.Visible = titleData == nil
			end
		end)
		
		tab:Bind(function(value)
			for _, a in pairs(self.object.Main.Middle:GetChildren()) do
				a.Visible = value == a.Name
			end
		end)

		self:_style_settings(data)
	end
end

-- ============================================================
-- FRUITBOUND STYLE: cream rows, wood outlines, green accents, sections
-- ============================================================
local function stroke(parent, color, thickness)
	-- always a fresh stroke, configured before it is parented: the GUI scaling script remembers a
	-- stroke's thickness the moment it appears, so reused / cloned strokes kept stale widths
	local old = parent:FindFirstChildOfClass("UIStroke")
	if old then
		old:Destroy()
	end
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thickness
	st.Transparency = 0
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = parent
	return st
end

local function corner(parent, radius)
	local c = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function styleRow(row, label)
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(0.94, 0, 0, 52)
	local main = row:FindFirstChild("Main")
	if not main then
		return
	end
	main.BackgroundColor3 = ROW_COLOR
	main.BackgroundTransparency = 0
	main.Size = UDim2.fromScale(1, 0.9)
	corner(main, UDim.new(0.25, 0))
	stroke(main, WOOD, 2)
	local icon = main:FindFirstChild("ImageLabel")
	if icon then
		icon.Visible = false -- old pet-simulator icons
	end
	local title = main:FindFirstChild("Title")
	if title then
		if label then
			title.Text = label
		end
		title.TextColor3 = TEXT_BROWN
		title.AnchorPoint = Vector2.new(0, 0.5)
		title.Position = UDim2.fromScale(0.05, 0.5)
		title.Size = UDim2.fromScale(0.5, 0.55)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextScaled = true
		local ts = title:FindFirstChildOfClass("UIStroke")
		if ts then
			ts.Enabled = false
		end
	end
end

local function header(parent, name, text, order)
	local h = parent:FindFirstChild(name) or Instance.new("TextLabel")
	h.Name = name
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(0.94, 0, 0, 30)
	h.Font = Enum.Font.FredokaOne
	h.Text = text
	h.TextScaled = true
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextColor3 = LEAF_GREEN
	h.LayoutOrder = order
	h.Parent = parent
	stroke(h, Color3.fromRGB(255, 255, 255), 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	return h
end

local function makeButton(parent, name, text, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Parent = parent
	corner(b, UDim.new(0.3, 0))
	stroke(b, WOOD, 2.5)
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Color = Color3.fromRGB(70, 50, 35)
	ts.Thickness = 1.5
	ts.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = b
	return b
end

function Settings:_style_settings(data)
	local main = self.object.Main
	local list = main.Middle.Settings

	main.BackgroundColor3 = CREAM
	stroke(main, WOOD, 4)

	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarImageColor3 = WOOD
	list.ScrollBarThickness = 6

	header(list, "Header_General", "GENERAL", 10)
	local tutorialHeader = header(list, "Header_Tutorial", "TUTORIAL", 30)

	local function apply(row)
		if not row:IsA("Frame") then
			return
		end
		local info = SETTING_ROWS[row.Name]
		if info then
			row.LayoutOrder = info.order
			row.Visible = true
			styleRow(row, info.label)
		elseif row.Name ~= "Skip_Tutorial" then
			row.Visible = false -- legacy toggles with no FruitBound effect
		end
	end
	for _, row in ipairs(list:GetChildren()) do
		apply(row)
	end
	-- the volume rows are added a moment later by SoundFX
	list.ChildAdded:Connect(function(row)
		task.defer(apply, row)
	end)

	-- TUTORIAL > Skip Tutorial (only while the tutorial is not finished)
	local template = list:FindFirstChild("Popups")
	if not template then
		return
	end
	local skipRow = template:Clone()
	skipRow.Name = "Skip_Tutorial"
	skipRow.LayoutOrder = 31
	styleRow(skipRow, "Skip Tutorial")
	local oldBtn = skipRow.Main:FindFirstChild("StateBtn")
	if oldBtn then
		oldBtn:Destroy()
	end
	local skipBtn = makeButton(skipRow.Main, "SkipBtn", "SKIP", SOFT_RED)
	skipBtn.AnchorPoint = Vector2.new(1, 0.5)
	skipBtn.Position = UDim2.fromScale(0.96, 0.5)
	skipBtn.Size = UDim2.fromScale(0.28, 0.72)
	skipRow.Parent = list

	local confirm = self:_build_skip_confirm(data)
	skipBtn.MouseButton1Click:Connect(function()
		Audio.Play({name = "Plop1"})
		confirm.Visible = true
	end)

	data:Bind("tutorial_marker", function(marker)
		local incomplete = typeof(marker) == "number" and marker < 8
		skipRow.Visible = incomplete
		tutorialHeader.Visible = incomplete
		if not incomplete then
			confirm.Visible = false
		end
	end)
end

-- "Skip Tutorial?" popup inside the Settings menu (dims and blocks the menu behind it)
function Settings:_build_skip_confirm(data)
	local Guide = _L.Get {"Client", "Modules", "Controllers", "Guide"}

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "SkipTutorialConfirm"
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.ZIndex = 50
	backdrop.Visible = false
	backdrop.Parent = self.object.Main
	corner(backdrop, UDim.new(0.04, 0))

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.82, 0.6)
	card.BackgroundColor3 = CREAM
	card.ZIndex = 51
	card.Parent = backdrop
	corner(card, UDim.new(0.08, 0))
	stroke(card, WOOD, 4)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(240, 150)
	limit.MaxSize = Vector2.new(520, 300)
	limit.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.06)
	title.Size = UDim2.fromScale(0.88, 0.24)
	title.Font = Enum.Font.FredokaOne
	title.Text = "Skip Tutorial?"
	title.TextScaled = true
	title.TextColor3 = TEXT_BROWN
	title.ZIndex = 52
	title.Parent = card

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.08, 0.32)
	body.Size = UDim2.fromScale(0.84, 0.26)
	body.Font = Enum.Font.FredokaOne
	body.Text = "Are you sure you want to skip the tutorial?"
	body.TextScaled = true
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(130, 100, 70)
	body.ZIndex = 52
	body.Parent = card

	local cancel = makeButton(card, "Cancel", "CANCEL", Color3.fromRGB(170, 150, 130))
	cancel.Position = UDim2.fromScale(0.06, 0.66)
	cancel.Size = UDim2.fromScale(0.4, 0.26)
	cancel.ZIndex = 52

	local yes = makeButton(card, "Yes", "YES, SKIP", LEAF_GREEN)
	yes.Position = UDim2.fromScale(0.54, 0.66)
	yes.Size = UDim2.fromScale(0.4, 0.26)
	yes.ZIndex = 52

	cancel.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	local pending = false
	yes.MouseButton1Click:Connect(function()
		if pending then
			return
		end
		pending = true
		Guide.skipping = true
		local ok, success = pcall(Network.Remote.Invoke, "S_Tutorial_Skip")
		pending = false
		backdrop.Visible = false
		if ok and success then
			UI.Get("Notifications"):add({text = "Tutorial skipped.", color = Color3.fromRGB(110, 220, 120)})
		else
			Guide.skipping = false
			UI.Get("Notifications"):add({text = "Couldn't skip the tutorial. Try again!", color = Color3.fromRGB(255, 120, 80)})
		end
	end)

	return backdrop
end

-- Stats tab: Coins / Gems / Rebirths / Crops Harvested / Fruits Collected (no Strength, Kills or Deaths)
function Settings:_build_stats(data)
	local list = self.object.Main.Middle.Stats
	local template
	for _, statFrame in pairs(list:GetChildren()) do
		if statFrame:IsA("Frame") then
			template = template or statFrame
			if not STAT_ROWS[statFrame.Name] then
				statFrame.Visible = false -- Kills / Deaths are not part of FruitBound
			end
		end
	end
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()

	for statName, info in pairs(STAT_ROWS) do
		local statFrame = list:FindFirstChild(statName)
		if not statFrame and template then
			statFrame = template:Clone()
			statFrame.Name = statName
			statFrame.Parent = list
		end
		if statFrame then
			statFrame.LayoutOrder = info.order
			statFrame.Visible = true
			styleRow(statFrame)
			local title = statFrame.Main:FindFirstChild("Title")
			if title then
				title.Size = UDim2.fromScale(0.9, 0.55)
				data:Bind({"stats", statName}, function(value)
					title.Text = info.label .. ": " .. NumberUtility.short(value or 0)
				end)
			end
		end
	end
end

function Settings:Open()
	Spr.Stop(self.object.Main)
	
	
	self.object.Main.Visible = true
	self.object.Main.Position = UDim2.fromScale(0.5, 0.55)
	
	Spr.Target(self.object.Main, 1, 4, {
		Position = UDim2.fromScale(0.5, 0.5)
	})
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 80
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 20
	})
end

function Settings:Close()
	
	self.object.Main.Visible = false
	local confirm = self.object.Main:FindFirstChild("SkipTutorialConfirm")
	if confirm then
		confirm.Visible = false
	end
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
end

return Settings