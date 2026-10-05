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

--> Constants

------------->
local Notifications = {
	name = script.Name
}

function Notifications:_init()
	Network = _L.Get {"Common", "Library", "Network"}
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
	Pool = _L.Get {"Common", "Library", "Classes", "Pool"}
end

function Notifications:_start()
	self.object = _L.PlayerGui.Notifications
	
	Network.Remote.Fired("C_Notifications_Add", function(...)
		self:add(...)
	end)
	
	Network.Bindable.Fired("C_Notifications_Add", function(...)
		self:add(...)
	end)
	
	local data = Data.Await()

	if data then
		self._data = data
	end
end

-- HUD polish: small, short-lived, max 3 on screen, and repeats are merged
-- ("+1 Mint Leaf" x3 -> "+3 Mint Leaf", other repeats -> "text  x2").
local MAX_VISIBLE = 3
local BASE_SCALE = 0.72
local DEFAULT_DURATION = 2.2

local function splitCount(text)
	local n, rest = string.match(text, "^%+(%d+) (.+)$")
	if n then
		return rest, tonumber(n)
	end
	return text, nil
end

function Notifications:_remove(entry, fast)
	if entry.removed then
		return
	end
	entry.removed = true
	for i, e in ipairs(self._active) do
		if e == entry then
			table.remove(self._active, i)
			break
		end
	end
	local inst = entry.instance
	Spr.Target(inst.UIScale, 1, if fast then 8 else 4, {
		Scale = 0
	})
	task.delay(if fast then 0.25 else 0.6, function()
		Spr.Stop(inst.UIScale)
		inst:Destroy()
	end)
end

function Notifications:add(props)
	if self._data and not self._data:Get({"settings", "Notifications"}) then
		return
	end
	self._active = self._active or {}
	
	local notificationColor = props.color or Color3.fromRGB(255, 255, 255)
	local notificationText = props.text
	local notificationAudio = props.audio
	local notificationDuration = math.min(props.duration or DEFAULT_DURATION, 3)
	if typeof(notificationText) ~= "string" then
		return
	end
	
	if notificationAudio then
		Audio.Play(notificationAudio)
	end

	-- merge with an identical notification that is still on screen
	local key, amount = splitCount(notificationText)
	for _, e in ipairs(self._active) do
		if e.key == key and not e.removed then
			if amount and e.amount then
				e.amount += amount
				e.instance.Text = "+" .. e.amount .. " " .. key
			else
				e.repeats += 1
				e.instance.Text = key .. "  x" .. e.repeats
			end
			e.instance.UIScale.Scale = BASE_SCALE * 1.15
			Spr.Target(e.instance.UIScale, 0.6, 5, {
				Scale = BASE_SCALE
			})
			e.token += 1
			local token = e.token
			task.delay(notificationDuration, function()
				if e.token == token then
					self:_remove(e)
				end
			end)
			return
		end
	end

	-- never more than MAX_VISIBLE at once: the oldest leaves early
	while #self._active >= MAX_VISIBLE do
		self:_remove(self._active[1], true)
	end
	
	local notificationInstance = _L.Assets.UI.Notification:Clone()
	
	notificationInstance.TextColor3 = notificationColor
	notificationInstance.Text = notificationText
	notificationInstance.UIScale.Scale = BASE_SCALE * 1.15
	local stroke = notificationInstance:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = math.min(stroke.Thickness, 2.5)
	end
	
	Spr.Target(notificationInstance.UIScale, 0.7, 5, {
		Scale = BASE_SCALE
	})

	local entry = {key = key, amount = amount, repeats = 1, instance = notificationInstance, token = 1}
	table.insert(self._active, entry)
	
	task.delay(notificationDuration, function()
		if entry.token == 1 then
			self:_remove(entry)
		end
	end)
	
	notificationInstance.Parent = self.object.Bottom.Notifications
end

return Notifications