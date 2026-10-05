-- ============================================================
-- GEARS UI MODULE
-- ============================================================
-- Shop interface for buying and equipping farming gears.
-- Also shows garden expansion info.
-- Opened by the Gardener NPC or via UI.Open({name = "Gears"}).
-- ============================================================

local _L = _G._L

local Services
local Tracker
local Spr
local Audio
local Network
local UI
local NumberUtility

local GearsModule = {
	name = script.Name
}

function GearsModule:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UI = _L.Get {"Client", "Modules", "UI"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}

	self.is_open = Tracker.new(false)
	self._cards = {}
end

function GearsModule:_start()
	self.object = _L.PlayerGui:WaitForChild("Gears")

	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
		end)

	-- Close button
	self.object.Main.Header.CloseBtn.MouseButton1Click:Connect(function()
		UI.Close({name = self.name})
	end)

	-- Garden expand button
	self.object.Main.ExpandFrame.ExpandBtn.MouseButton1Click:Connect(function()
		local success, newExpansion = Network.Remote.Invoke("S_Garden_Expand")
		if success then
			self:_notify("Garden expanded to tier " .. (newExpansion or 1) .. "!")
			self:_refresh()
		else
			self:_notify("Not enough coins to expand!")
		end
		end)

	-- Initial refresh
	self:_refresh()
end

function GearsModule:_notify(msg)
	local Notifications = _L.Get {"Client", "Modules", "UI", "Notifications"}
	if Notifications and Notifications.add then
		Notifications.add(msg)
	end
end

function GearsModule:_refresh()
	local summary = Network.Remote.Invoke("S_Gears_Get_Summary")
	local gardenState = Network.Remote.Invoke("S_Garden_Get_State")

	if not summary then
		return
	end

	local list = self.object.Main.List
	local template = self.object.CardTemplate

	-- Clear old cards
	for _, card in pairs(self._cards) do
		card:Destroy() -- also drops its button connections
	end
	table.clear(self._cards)

	local order = 1

	for _, gearInfo in ipairs(summary.gears or {}) do
		local card = template:Clone()
		card.Name = gearInfo.id
		card.Visible = true
		card.LayoutOrder = order
		order += 1
		card.Parent = list
		self._cards[gearInfo.id] = card

		-- Icon
		card.IconBg.Icon.Text = gearInfo.icon or "🧰"

		-- Name
		card.GearName.Text = gearInfo.name or gearInfo.id

		-- Description
		card.Description.Text = gearInfo.description or ""

		-- Level badge
		card.LevelBadge.LevelText.Text = "Lv. " .. (gearInfo.level or 1)
		if gearInfo.is_max then
			card.LevelBadge.BackgroundColor3 = Color3.fromRGB(255, 200, 70)
		else
			card.LevelBadge.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		end

		-- Action button: Buy / Equip / Equipped
		local btn = card.ActionBtn
		if gearInfo.equipped then
			btn.Text = "✓ Equipped"
			btn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			btn.AutoButtonColor = false

			btn.MouseButton1Click:Connect(function()
				Network.Remote.Invoke("S_Gears_Unequip")
				self:_refresh()
			end)
		else
			btn.Text = "Equip"
			btn.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
			btn.AutoButtonColor = true

			btn.MouseButton1Click:Connect(function()
				Network.Remote.Invoke("S_Gears_Equip", gearInfo.id)
				self:_refresh()
			end)
		end

		-- If gear is owned, show Equip. If not owned, show Buy with cost.
		-- We check ownership via the summary - gears in the summary are already owned.
		-- For unowned gears, we need the full gear list. Let's fetch it.
	end

	-- Fetch all gears from server to show unowned ones
	-- Actually, the summary only returns owned gears. Let's also show unowned ones.
	-- We can get all gear definitions from the Gears database (which is in ReplicatedStorage)
	local ok, Gears = pcall(function() return _L.Get {"Common", "Modules", "Databases", "Gears"} end)
	if ok and Gears then
		local ownedIds = {}
		for _, g in ipairs(summary.gears or {}) do
			ownedIds[g.id] = true
		end

		for _, gearDef in ipairs(Gears) do
			if not ownedIds[gearDef.id] then
				local card = template:Clone()
				card.Name = gearDef.id
				card.Visible = true
				card.LayoutOrder = order
				order += 1
				card.Parent = list
				self._cards[gearDef.id] = card

				card.IconBg.Icon.Text = gearDef.icon or "🧰"
				card.GearName.Text = gearDef.name
				card.Description.Text = gearDef.description or ""
				card.LevelBadge.LevelText.Text = "Not Owned"
				card.LevelBadge.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

				local btn = card.ActionBtn
				local costText = NumberUtility.short(gearDef.cost)
				btn.Text = "Buy - " .. costText
				btn.BackgroundColor3 = Color3.fromRGB(80, 160, 90)
				btn.AutoButtonColor = true

				btn.MouseButton1Click:Connect(function()
					local success, err = Network.Remote.Invoke("S_Gears_Buy", gearDef.id)
					if success then
						self:_notify("Purchased " .. gearDef.name .. "!")
						self:_refresh()
					elseif err == "afford" then
						self:_notify("Not enough coins!")
					elseif err == "already_owned" then
						self:_refresh()
					else
						self:_notify("Could not purchase: " .. (err or "unknown"))
					end
				end)
			end
		end
	end

	-- Update garden expansion info
	if gardenState then
		local infoText = string.format("Garden Slots: %d/%d  |  Next Expansion: %s coins",
			gardenState.used_slots or 0,
			gardenState.max_slots or 10,
			NumberUtility.short(gardenState.next_expansion_cost or 500)
		)
		self.object.Main.ExpandFrame.Info.Text = infoText
	end
end

function GearsModule:Open()
	local main = self.object.Main
	self:_refresh()
	Spr.Stop(main)
	main.Visible = true
	main.Position = UDim2.fromScale(0.5, 0.56)
	Spr.Target(main, 1, 4, {Position = UDim2.fromScale(0.5, 0.5)})
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 80})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 20})
	end
end

function GearsModule:Close()
	self.object.Main.Visible = false
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 70})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end
end

return GearsModule