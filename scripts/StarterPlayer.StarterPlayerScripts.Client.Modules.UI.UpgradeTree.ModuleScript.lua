--> Variables
local _L = _G._L

local Services
local Tracker
local Data
local NumberUtility
local Spr
local Audio
local Network
local UI
local UpgradeTreeUtility
local Notifications

--> Constants
local COLS, ROWS = 5, 4
local BRANCH_COLORS = {
	Root = Color3.fromRGB(155, 209, 119),
	Coins = Color3.fromRGB(255, 205, 70),
	Luck = Color3.fromRGB(176, 220, 168),
	Stats = Color3.fromRGB(205, 221, 175),
	Rebirth = Color3.fromRGB(236, 206, 151),
}
local LOCKED_COLOR = Color3.fromRGB(150, 150, 165)
local MAX_COLOR = Color3.fromRGB(255, 240, 150)
local LINE_ON = Color3.fromRGB(255, 255, 255)
local LINE_OFF = Color3.fromRGB(130, 109, 76)

------------->
local UpgradeTree = {
	name = script.Name
}

function UpgradeTree:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UI = _L.Get {"Client", "Modules", "UI"}
	UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}

	self.is_open = Tracker.new(false)
end

-- Text shown for the total bonus a node currently gives
local function formatBonus(node, level)
	local amount = level * node.per_level
	if node.effect == "speed" then
		return "+" .. amount .. " Walk Speed"
	elseif node.effect == "fruit_storage" then
		return "+" .. amount .. " Fruit Storage"
	elseif node.effect == "fruit_equip" then
		return "+" .. amount .. " Fruits Equipped"
	elseif node.effect == "rebirth_discount" then
		return "-" .. math.floor(amount * 100 + 0.5) .. "% Rebirth cost"
	else
		local names = {coins = "Coins", luck = "Luck", rebirth_power = "Rebirth bonus", rebirth_gems = "Rebirth Gems"}
		return "+" .. math.floor(amount * 100 + 0.5) .. "% " .. (names[node.effect] or "")
	end
end

function UpgradeTree:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui:WaitForChild("UpgradeTree")
	local main = self.object.Main
	local tree = main.Tree
	local details = main.Details
	local template = self.object.NodeTemplate
	local function applyLayout()
		-- size from the ScreenGui's own area: it is clipped to the device safe area, which on
		-- phones is smaller than the camera viewport (notch / rounded corners), so sizing from
		-- the viewport pushed the top-right Coins chip past the clip edge. Desktop: same as before.
		local viewport = self.object.AbsoluteSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			viewport = workspace.CurrentCamera.ViewportSize
		end
		main.Size = UDim2.fromOffset(math.min(850, viewport.X - 32), math.min(580, viewport.Y - 24))
		local compact = viewport.Y < 430
		details.Icon.Visible = not compact
		details.NodeName.Position = UDim2.new(0.04, 0, 0, if compact then 4 else 46)
		details.Level.Position = UDim2.new(0.04, 0, 0, if compact then 38 else 77)
		details.Description.Position = UDim2.new(0.04, 0, 0, if compact then 64 else 100)
	end
	applyLayout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	self.object:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)

	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)

	local data = Data.Await()
	if not data then
		return
	end

	self._selected = "sprout"
	self._nodes = {}
	self._lines = {}

	-- Create node buttons
	for _, node in ipairs(UpgradeTreeUtility.getAll()) do
		local button = template:Clone()
		button.Name = node.id
		button.Visible = true
		button.Icon.Text = node.icon
		button.Position = UDim2.fromScale((node.col - 0.5) / COLS, (node.row - 0.5) / ROWS - 0.02)
		button.Parent = tree.Nodes

		button.MouseButton1Click:Connect(function()
			self._selected = node.id
			Audio.Play({name = "ButtonDown1"})
			self:_refresh(data)
		end)

		self._nodes[node.id] = {info = node, button = button}

		if node.requires then
			local line = Instance.new("Frame")
			line.Name = node.requires.node .. "_to_" .. node.id
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BorderSizePixel = 0
			line.BackgroundColor3 = LINE_OFF
			line.Parent = tree.Lines
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = line
			table.insert(self._lines, {line = line, from = node.requires.node, to = node.id, need = node.requires.level})
		end
	end

	-- Lines are drawn in pixels, so redraw when the window size changes
	local function drawLines()
		local size = tree.AbsoluteSize
		for _, l in ipairs(self._lines) do
			local a = self._nodes[l.from].info
			local b = self._nodes[l.to].info
			local pa = Vector2.new((a.col - 0.5) / COLS * size.X, ((a.row - 0.5) / ROWS - 0.02) * size.Y)
			local pb = Vector2.new((b.col - 0.5) / COLS * size.X, ((b.row - 0.5) / ROWS - 0.02) * size.Y)
			local mid = (pa + pb) / 2
			local diff = pb - pa
			l.line.Position = UDim2.fromOffset(mid.X, mid.Y)
			l.line.Size = UDim2.fromOffset(diff.Magnitude, math.max(6, size.Y * 0.018))
			l.line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
		end
	end
	tree:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawLines)
	drawLines()

	-- Buy button
	details.Buy.MouseButton1Click:Connect(function()
		local nodeId = self._selected
		local success, err = Network.Remote.Invoke("S_Tree_Upgrade", nodeId)

		if success then
			Audio.Play({name = "Success2"})
			local entry = self._nodes[nodeId]
			if entry then
				local scale = entry.button.UIScale
				scale.Scale = 1.3
				Spr.Target(scale, 0.4, 4, {Scale = 1})
			end
		elseif err == "afford" then
			local cost = UpgradeTreeUtility.getCost(nodeId, UpgradeTreeUtility.getLevel(data, nodeId))
			Notifications:add({
				text = "❌ You need " .. NumberUtility.short(cost - data:Get({"stats", "Strength"})) .. " more Coins!",
				color = Color3.fromRGB(255, 0, 0),
				audio = {name = "Fail1"},
			})
		elseif err == "locked" then
			Notifications:add({text = "🔒 Unlock the previous upgrade first!", color = Color3.fromRGB(255, 120, 0), audio = {name = "Fail1"}})
		elseif err == "maxed" then
			Notifications:add({text = "⭐ This upgrade is already maxed!", color = Color3.fromRGB(255, 200, 0)})
		end
	end)

	Tracker.Subscribe({data:Track("tree"), data:Track({"stats", "Strength"})}, function()
		self:_refresh(data)
	end)
	self:_refresh(data)
end

function UpgradeTree:_refresh(data)
	if not self._nodes then
		return
	end

	local coins = data:Get({"stats", "Strength"}) or 0
	self.object.Main.Header.Coins.Amount.Text = NumberUtility.short(coins)

	for id, entry in pairs(self._nodes) do
		local node = entry.info
		local button = entry.button
		local level = UpgradeTreeUtility.getLevel(data, id)
		local unlocked = UpgradeTreeUtility.isUnlocked(data, id)
		local maxed = level >= node.max_level

		button.Level.Text = if maxed then "MAX" else (level .. "/" .. node.max_level)
		button.Lock.Visible = not unlocked
		button.BackgroundColor3 = if not unlocked then LOCKED_COLOR elseif maxed then MAX_COLOR else BRANCH_COLORS[node.branch] or BRANCH_COLORS.Root
		button.Icon.TextTransparency = if unlocked then 0 else 0.5
		button.Border.Color = if id == self._selected then Color3.fromRGB(70, 115, 45) else Color3.fromRGB(115, 84, 48)
		button.Border.Thickness = if id == self._selected then 6 else 4
	end

	for _, l in ipairs(self._lines) do
		local on = UpgradeTreeUtility.getLevel(data, l.from) >= l.need
		l.line.BackgroundColor3 = if on then LINE_ON else LINE_OFF
		l.line.BackgroundTransparency = if on then 0 else 0.4
	end

	-- Details panel
	local details = self.object.Main.Details
	local entry = self._nodes[self._selected]
	if not entry then
		return
	end
	local node = entry.info
	local level = UpgradeTreeUtility.getLevel(data, node.id)
	local unlocked = UpgradeTreeUtility.isUnlocked(data, node.id)
	local maxed = level >= node.max_level
	local cost = UpgradeTreeUtility.getCost(node.id, level)

	details.Icon.Text = node.icon
	details.NodeName.Text = node.name
	details.Level.Text = "Level " .. level .. " / " .. node.max_level
	details.Current.Text = "Now: " .. formatBonus(node, level)
	details.Next.Text = if maxed then "Maximum level reached" else "Next: " .. formatBonus(node, level + 1)

	if not unlocked then
		local parent = self._nodes[node.requires.node]
		details.Description.Text = node.description .. "\n🔒 Needs " .. parent.info.name .. " level " .. node.requires.level
	else
		details.Description.Text = node.description
	end

	local buy = details.Buy
	if maxed then
		buy.Label.Text = "MAXED"
		buy.Cost.Text = ""
		buy.CoinIcon.Visible = false
		buy.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	else
		buy.Label.Text = if unlocked then "UPGRADE" else "LOCKED"
		buy.Cost.Text = NumberUtility.short(cost)
		buy.CoinIcon.Visible = true
		buy.BackgroundColor3 = if not unlocked then LOCKED_COLOR elseif coins >= cost then Color3.fromRGB(110, 220, 90) else Color3.fromRGB(230, 110, 110)
	end
end

function UpgradeTree:Open()
	local main = self.object.Main
	Spr.Stop(main)
	main.Visible = true
	main.Position = UDim2.fromScale(0.5, 0.56)
	Spr.Target(main, 1, 4, {Position = UDim2.fromScale(0.5, 0.5)})
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 80})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 20})
	end
end

function UpgradeTree:Close()
	self.object.Main.Visible = false
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 70})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end
end

return UpgradeTree
