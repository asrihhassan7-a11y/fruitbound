--> Achievements menu
-- Shows every achievement with progress, reward and a Claim button.
-- Achievements come from Databases.Achievements; nothing here needs changing when you add one.

local _L = _G._L

local Services
local Tracker
local Data
local Spr
local Audio
local Network
local UI
local NumberUtility
local AchievementUtility
local Notifications

local GREEN = Color3.fromRGB(110, 210, 90)
local GREY = Color3.fromRGB(175, 170, 165)
local CREAM_DONE = Color3.fromRGB(232, 245, 220)

------------->
local Achievements = {
	name = script.Name
}

function Achievements:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UI = _L.Get {"Client", "Modules", "UI"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	AchievementUtility = _L.Get {"Common", "Modules", "Utilities", "AchievementUtility"}

	self.is_open = Tracker.new(false)
end

function Achievements:_start()
	Notifications = UI.Get("Notifications")
	self.object = _L.PlayerGui:WaitForChild("Achievements")

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
	self._announced = {}

	-- refresh when progress or claims change (cheap: at most every 0.5s)
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.delay(0.5, function()
			pending = false
			self:_refresh()
		end)
	end
	data:Bind("stats", schedule)
	data:Bind("discovered_gardens", schedule)
	data:Bind("achievements", schedule)
	data:Bind("farm", schedule)
	self:_refresh()
end

function Achievements:_refresh()
	local data = self._data
	if not data then
		return
	end
	local list = self.object.Main.List
	local template = self.object.CardTemplate
	local all = AchievementUtility.getAll()
	local done = 0
	local claimable = 0

	for order, info in ipairs(all) do
		local card = self._cards[info.id]
		if not card then
			card = template:Clone()
			card.Name = info.id
			card.Visible = true
			card.IconBg.Icon.Text = info.icon or "⭐"
			card.AchName.Text = info.name
			card.Description.Text = info.description
			card.Reward.Text = "🎁 " .. (info.reward_text or "")
			card.Parent = list
			card.Claim.MouseButton1Click:Connect(function()
				if AchievementUtility.getState(data, info.id) ~= "Claimable" then
					Audio.Play({name = "Fail1"})
					return
				end
				local success = Network.Remote.Invoke("S_Achievements_Claim", info.id)
				if success then
					Audio.Play({name = "Success2"})
					Notifications:add({text = "🏆 Claimed: " .. info.name .. "! " .. (info.reward_text or ""), color = Color3.fromRGB(255, 200, 70)})
				end
			end)
			self._cards[info.id] = card
		end

		local state = AchievementUtility.getState(data, info.id)
		local progress, goal = AchievementUtility.getProgress(data, info.id)

		card.Bar.Fill.Size = UDim2.fromScale(math.clamp(progress / goal, 0, 1), 1)
		card.Bar.Fill.Visible = progress > 0
		card.Bar.Text.Text = NumberUtility.commas(math.floor(progress)) .. " / " .. NumberUtility.commas(goal)

		local claim = card.Claim
		if state == "Claimed" then
			done += 1
			claim.Label.Text = "✔ DONE"
			claim.BackgroundColor3 = Color3.fromRGB(150, 200, 140)
			claim.AutoButtonColor = false
			card.BackgroundColor3 = CREAM_DONE
			card.Border.Color = Color3.fromRGB(150, 200, 120)
			card.LayoutOrder = 300 + order
		elseif state == "Claimable" then
			claimable += 1
			claim.Label.Text = "CLAIM!"
			claim.BackgroundColor3 = GREEN
			claim.AutoButtonColor = true
			card.BackgroundColor3 = Color3.fromRGB(255, 250, 225)
			card.Border.Color = Color3.fromRGB(255, 190, 60)
			card.LayoutOrder = order
			if not self._announced[info.id] then
				self._announced[info.id] = true
				Notifications:add({text = "🏆 Achievement complete: " .. info.name .. "! Claim it in the Achievements menu.", color = Color3.fromRGB(255, 200, 70), audio = {name = "Reward1"}})
			end
		else
			claim.Label.Text = "🔒 " .. math.floor(progress / goal * 100) .. "%"
			claim.BackgroundColor3 = GREY
			claim.AutoButtonColor = false
			card.BackgroundColor3 = Color3.fromRGB(255, 253, 245)
			card.Border.Color = Color3.fromRGB(215, 190, 140)
			card.LayoutOrder = 100 + order
		end
	end

	self.object.Main.Header.Counter.Text = done .. " / " .. #all .. " completed"

	-- "!" on the menu button when something can be claimed
	local button = _L.PlayerGui.Main.Left.Content:FindFirstChild("Achievements")
	local badge = button and button:FindFirstChild("Notification")
	if badge then
		badge.Visible = claimable > 0
	end
end

function Achievements:Open()
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

function Achievements:Close()
	self.object.Main.Visible = false
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 70})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end
end

return Achievements
