--> Titles menu
-- Lists every title (owned + locked), shows boosts and how to unlock, and lets the player equip one.
-- Titles come from Databases.Titles; nothing here needs changing when you add a title.

local _L = _G._L

local Services
local Tracker
local Data
local Spr
local Audio
local Network
local UI
local TitleUtility
local Notifications

local GREEN = Color3.fromRGB(110, 210, 90)
local PINK = Color3.fromRGB(255, 130, 170)
local GREY = Color3.fromRGB(170, 165, 160)
local ORANGE = Color3.fromRGB(255, 165, 70)

------------->
local Titles = {
	name = script.Name
}

function Titles:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UI = _L.Get {"Client", "Modules", "UI"}
	TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}

	self.is_open = Tracker.new(false)
end

function Titles:_start()
	Notifications = UI.Get("Notifications")
	self.object = _L.PlayerGui:WaitForChild("Titles")

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
	self._data = data
	self._cards = {}

	local details = self.object.Main.Details
	details.Equip.MouseButton1Click:Connect(function()
		local id = self._selected
		if id == nil or not TitleUtility.owns(data, id) then
			Audio.Play({name = "Fail1"})
			return
		end
		Network.Remote.Fire("S_Titles_Toggle_Equip", id)
		Audio.Play({name = "Equip1"})
	end)

	data:Bind("titles", function()
		self:_refresh()
	end)
end

function Titles:_visibleTitles()
	local list = {}
	for _, info in ipairs(TitleUtility.getAll()) do
		if not info.hidden or TitleUtility.owns(self._data, info.id) then
			table.insert(list, info)
		end
	end
	return list
end

function Titles:_refresh()
	local data = self._data
	if not data then
		return
	end
	local list = self.object.Main.List
	local template = self.object.CardTemplate
	local equippedInfo = TitleUtility.getEquipped(data)

	local titles = self:_visibleTitles()
	local owned = 0

	for order, info in ipairs(titles) do
		local key = tostring(info.id)
		local card = self._cards[key]
		if not card then
			card = template:Clone()
			card.Name = key
			card.Visible = true
			card.Parent = list
			card.MouseButton1Click:Connect(function()
				self._selected = info.id
				Audio.Play({name = "ButtonDown1"})
				self:_refresh()
			end)
			self._cards[key] = card
		end

		local isOwned = TitleUtility.owns(data, info.id)
		local isEquipped = equippedInfo == info
		if isOwned then
			owned += 1
		end

		card.TitleText.Text = if isOwned then info.text else ("🔒 " .. info.text)
		card.TitleText.TextColor3 = if isOwned then info.color else GREY
		local boosts = TitleUtility.describeBoosts(info)
		card.Boosts.Text = if #boosts > 0 then table.concat(boosts, "  •  ") else "No boosts"

		card.Badge.BackgroundColor3 = if isEquipped then GREEN elseif isOwned then ORANGE else GREY
		card.Badge.Text.Text = if isEquipped then "EQUIPPED" elseif isOwned then "OWNED" else "LOCKED"
		card.BackgroundColor3 = if isOwned then Color3.fromRGB(255, 253, 245) else Color3.fromRGB(238, 232, 222)
		card.Border.Color = if self._selected == info.id then PINK elseif isEquipped then GREEN else Color3.fromRGB(215, 190, 140)
		card.Border.Thickness = if self._selected == info.id then 4 else 3

		-- equipped first, then owned, then locked
		card.LayoutOrder = (if isEquipped then 0 elseif isOwned then 100 else 200) + order
	end

	self.object.Main.Header.Counter.Text = owned .. " / " .. #titles .. " unlocked"

	-- details panel
	if self._selected == nil then
		self._selected = if equippedInfo then equippedInfo.id else (titles[1] and titles[1].id)
	end
	local info = TitleUtility.getInfo(self._selected)
	local details = self.object.Main.Details
	if not info then
		return
	end
	local isOwned = TitleUtility.owns(data, info.id)
	local isEquipped = equippedInfo == info

	details.TitleName.Text = info.text
	details.TitleName.TextColor3 = if isOwned then info.color else GREY
	details.Status.Text = if isEquipped then "✅ EQUIPPED" elseif isOwned then "⭐ OWNED" else "🔒 LOCKED"
	local boosts = TitleUtility.describeBoosts(info)
	details.BoostsBox.Boosts.Text = if #boosts > 0 then table.concat(boosts, "\n") else "No boosts"
	details.UnlockBox.Unlock.Text = info.unlock or ""

	local equip = details.Equip
	equip.Label.Text = if isEquipped then "UNEQUIP" elseif isOwned then "EQUIP" else "LOCKED"
	equip.BackgroundColor3 = if isEquipped then PINK elseif isOwned then GREEN else GREY
end

function Titles:Open()
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

function Titles:Close()
	self.object.Main.Visible = false
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 70})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end
end

return Titles
