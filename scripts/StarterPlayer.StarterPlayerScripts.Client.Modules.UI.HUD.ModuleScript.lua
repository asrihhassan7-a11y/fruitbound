--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local cancellableDelay
local Trove
local Timer
local Spr
local GIF
local _Stats
local UI
local ProgressBar
local Audio

--> Constants

------------->
local HUD = {
	name = script.Name
}

function HUD:_init()
	Audio = _L.Get {"Common", "Library", "Audio"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	GIF = _L.Get {"Client", "Modules", "Classes", "GIF"}
	_Stats = _L.Get {"Common", "Modules", "Databases", "Stats"}
	UI = _L.Get {"Client", "Modules", "UI"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
end

function HUD:_start()
	local data = Data.Await()

	if data then
		self._data = data
	end

	UI._current:Bind(function(value)
		if value then
			self:ClearStatPopups()
		end
	end)
end

local statPopups = {}
local x = 0

function HUD:StatPopup(props)
	if self._data and not self._data:Get({"settings", "Popups"}) then
		return
	end

	if x == 3 then
		x = 1
	else
		x += 1
	end

	local newTrove = Trove.new()
	local upperTrove = Trove.new()

	local statName = props.stat_name
	local statValue = props.stat_value
	local isNegative = statValue < 0

	local _, statInfo = TableUtility.match(_Stats, function(i, v)
		return v.name == statName
	end)

	local newPopupInstance = _L.Assets.UI.Popup:Clone()
	local x, y = 0.3 + (x-1) * 0.2, if x == 2 then (if math.random(1, 2) == 1 then 25 / 100 else 75 / 100) else math.random(30, 70) / 100

	newPopupInstance.TextLabel.Text = (if isNegative then "-" else "+")..NumberUtility.short(statValue).." "..(statInfo.display_name or statInfo.name)
	newPopupInstance.ImageLabel.Image = statInfo.image
	newPopupInstance.Position = UDim2.fromScale(x, 2)

	Spr.Target(newPopupInstance, 0.7, 2, {
		Position = UDim2.fromScale(x, y)
	})

	local debrisGui = _L.PlayerGui:FindFirstChild("Debris")
	if not debrisGui then
		debrisGui = Instance.new("ScreenGui")
		debrisGui.Name = "Debris"
		debrisGui.ResetOnSpawn = false
		debrisGui.IgnoreGuiInset = true
		debrisGui.DisplayOrder = 5
		debrisGui.Parent = _L.PlayerGui
	end
	newPopupInstance.Parent = debrisGui

	local statPopup = {
		instance = newPopupInstance,
		value = statValue,
		info = statInfo,
		is_negative = isNegative,
		name = statName,
		trove = newTrove,
		upper_trove = upperTrove,
		destroyed = false
	}

	newTrove:Add(function()
		if not statPopup.destroyed then
			statPopup.destroyed = true

			local i, v = TableUtility.match(statPopups, function(i, v)
				return v.instance == newPopupInstance
			end)

			table.remove(statPopups, i)

			Spr.Target(newPopupInstance.UIScale, 1, 4, {
				Scale = 1.2
			})

			Spr.Target(newPopupInstance, 1, 4, {
				Rotation = (if math.random(1, 2) == 1 then -1 else 1) * 5
			})

			task.delay(0.3, function()
				Spr.Target(newPopupInstance.UIScale, 1, 3, {
					Scale = 0
				})

				Spr.Target(newPopupInstance.ImageLabel, 1, 5, {
					ImageTransparency = 1
				})

				Spr.Target(newPopupInstance.TextLabel, 1, 5, {
					TextTransparency = 1
				})

				Spr.Target(newPopupInstance.TextLabel.UIStroke, 1, 5, {
					Transparency = 1
				})

				Spr.Target(newPopupInstance, 1, 4, {
					Rotation = 0
				})

				task.delay(5, function()
					newPopupInstance:Destroy()
				end)
			end)
		end
	end)

	table.insert(statPopups, statPopup)

	if #statPopups > 2 then
		for i = 1, #statPopups - 2 do
			local n = statPopups[i]

			if not n.destroyed then
				n.upper_trove:Destroy()				
			end
		end
	end

	local o = cancellableDelay(3, function()
		newTrove:Destroy()
	end)

	upperTrove:Add(function()
		o()
		newTrove:Destroy()
	end)
end

function HUD:ClearStatPopups()
	while #statPopups ~= 0 do
		local n = statPopups[#statPopups]

		if not n.destroyed then
			n.upper_trove:Destroy()				
		end
	end
end

return HUD
