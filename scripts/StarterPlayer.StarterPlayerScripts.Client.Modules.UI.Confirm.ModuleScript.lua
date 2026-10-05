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
local Notifications

--> Constants

------------->
local Confirm = {
	name = script.Name
}

function Confirm:_init()
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
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Confirm:_start()
	self.object = _L.PlayerGui.Confirm
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open(props)
		else
			self:Close(props)
		end
	end)
	
	self.trove = Trove.new()
end

function Confirm:Open(props)
	local ignoreLast = props.ignore_last
	
	self.trove:Clean()
	
	local chose = false
	
	self.object.Main.TextLabel.Text = props.text
	
	local ok = function()
		local lastUIName = UI.GetLast()

		if not ignoreLast and lastUIName and lastUIName ~= "Eggs" and lastUIName ~= "Confirm" and lastUIName ~= "Trade" then
			UI.Open({name = lastUIName})
		else
			UI.Close({name = self.name})
		end
	end
	
	self.trove:Add(self.object.Main.YesBtn.MouseButton1Down:Connect(function()
		chose = true
		ok()
		props.yes()
	end))
	
	self.trove:Add(self.object.Main.NoBtn.MouseButton1Down:Connect(function()
		chose = true
		ok()
		props.no()
	end))
	
	self.trove:Add(function()
		--if not chose then
		--	props.no()
		--end
	end)
	
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
	
	Audio.Play({name = "Confirm1"})
end

function Confirm:Close()
	self.trove:Clean()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Confirm