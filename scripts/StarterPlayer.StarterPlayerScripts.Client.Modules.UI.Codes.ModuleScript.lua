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
local Codes = {
	name = script.Name
}

function Codes:_init()
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
	
	self.trove = Trove.new()
end

function Codes:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.Store.Main.Middle.Codes
	
	self.object.Main.VerifyBtn.MouseButton1Click:Connect(function()
		local currentCode = self.object.Main.TextBox.Text
		
		currentCode = string.lower(currentCode)
		
		self.object.Main.TextBox.Text = ""
		
		local success, err = Network.Remote.Invoke("S_Codes_Submit", currentCode)
		
		if err == "used" then
			Notifications:add({
				text = "❌ Code already used!",
				color = Color3.fromRGB(255, 0, 0),
				audio = {name = "Fail1"}
			})
		elseif err == "invalid" then
			Notifications:add({
				text = "❌ You entered an invalid code!",
				color = Color3.fromRGB(255, 0, 0),
				audio = {name = "Fail1"}
			})
		elseif err == "mount_owned" then
			Notifications:add({
				text = "✓ You already own this mount!",
				color = Color3.fromRGB(255, 220, 120),
			})
		elseif success and err == "mount" then
			-- the Mounts controller shows the "NEW MOUNT!" card (C_Mount_Unlocked)
		elseif success then
			Notifications:add({
				text = "✅ Code redeemed successfully!",
				color = Color3.fromRGB(0, 255, 0),
				audio = {name = "Success1"}
			})
		end
		
	end)
	
	_L.PlayerGui.Main.Left.Content.Codes.MouseButton1Down:Connect(function()
		UI.Open({name = "Store", props = {
			subject = "Codes"
		}})
	end)
end

return Codes