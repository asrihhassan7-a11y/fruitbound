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
local PlayerRewardUtility
local FreeGiftUtility
local FreeGifts
local ProgressBar

--> Constants

------------->
local PetPack = {
	name = script.Name
}

function PetPack:_init()
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
	FreeGifts = _L.Get {"Common", "Modules", "Databases", "FreeGifts"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	FreeGiftUtility = _L.Get {"Common", "Modules", "Utilities", "FreeGiftUtility"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function PetPack:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.PetPack
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	self._progress_bar = ProgressBar.new({instance = self.object.Main.Time.ProgressBar, format = function(n1, n2)
		return NumberUtility.short(math.floor(n1)).." / "..NumberUtility.short(math.floor(n2))
	end,})

	local data = Data.Await()

	if data then
		AttributeUtility.waitFor(_L.Player, "join_time")

		Tracker.Subscribe({data:Track("claimed_free_pet_pack"), TrackerUtility.fromAttributeSignal("join_time")}, function()
			self:_render(data)
		end)
		
		Timer.Simple(1, function()
			self:_render(data)
		end)
		
		self.object.Main.ClaimBtn.MouseButton1Down:Connect(function()
			local success, err = Network.Remote.Invoke("S_Free_Pet_Pack_Claim")
			
			if success then
				Notifications:add({
					text = "✅ You claimed Pet Pack!",
					color = Color3.fromRGB(0, 255, 0),
					audio = {name = "Success1"}
				})
			elseif err == "claimed" then
				Notifications:add({
					text = "✅ You have already claimed your Pet Pack!",
					color = Color3.fromRGB(0, 255, 0),
					audio = {name = "Success1"}
				})
			else
				Notifications:add({
					text = "❌ Your Pet Pack reward is not ready yet!",
					color = Color3.fromRGB(255, 0, 0),
					audio = {name = "Fail1"}
				})
			end
			
		end)
	end
end

function PetPack:_render(data)
	local claimed = data:Get("claimed_free_pet_pack")
	local joinTime = _L.Player:GetAttribute("join_time")

	local max = math.floor(Constants.FREE_PET_PACK_TIME / 60)

	if claimed then
		self._progress_bar:Set({max, max})
	else
		self._progress_bar:Set({math.clamp(math.floor((os.time() - joinTime) / 60), 0, max), max})
	end
end
	
function PetPack:Open()
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
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = false end
end

function PetPack:Close()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = true end
end

return PetPack