--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local AttributeUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Network
local TrackerUtility
local Powers

--> Constants

------------->
local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar.new(props)
	local self = setmetatable({}, ProgressBar)
	
	self._instance = props.instance
	self._format = props.format
	self._position = Tracker.new(props.position or {0, 0})
	self._default = self._instance.Progress.Size
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function ProgressBar:_construct()
	self._trove:Add(self._position:Bind(function(value)
		self._instance.ProgressText.Text = self._format(value[1], value[2])
		
		local a = value[1]
		local b = value[2]
		
		local goal1 = UDim2.fromScale(math.clamp(a / b, self._default.X.Scale, 1), 1)

		Spr.Target(self._instance.Progress, 0.7, 3, {
			Size = goal1
		})

		local goal2 = Vector2.new(math.clamp(a/b/self._default.X.Scale, 0, 1), 0)
		
		Spr.Target(self._instance.Progress.UIGradient, 0.7, 3, {
			Offset = goal2
		})
	end))
end

function ProgressBar:Set(...)
	self._position:Set(...)
end

function ProgressBar:Shine(props)
	local new = _L.Assets.UI.ProgressBar.Shine:Clone()

	new.BackgroundTransparency = 0.2
	new.Parent = self._instance

	Spr.Target(new, 1, 1.5, {
		Transparency = 1
	})

	Spr.Target(new.UIScale, 1, 1.5, {
		Scale = 1.75
	})
	
	if props.audio then
		Audio.Play(props.audio)
	end
	
	task.delay(1, function()
		new:Destroy()
	end)
end

function ProgressBar:Destroy()
	self._trove:Destroy()
end

function ProgressBar._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Powers = _L.Get {"Common", "Modules", "Databases", "Powers", "Powers"}
end

function ProgressBar._start()
end

return ProgressBar