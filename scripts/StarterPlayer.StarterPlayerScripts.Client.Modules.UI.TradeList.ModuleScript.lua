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
local Purchases
local Icon
local Notifications

--> Constants

------------->
local TradeList = {
	name = script.Name
}

function TradeList:_init()
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
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
	Icon = _L.Get {"Client", "Modules", "Icon"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function TradeList:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.TradeList
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()

	if data then
		local players = Tracker.new(self:get_players())
		
		Services.Players.ChildAdded:Connect(function()
			players:Set(self:get_players())
		end)
		
		Services.Players.ChildRemoved:Connect(function()
			players:Set(self:get_players())
		end)
		
		local objects = {}
		
		players:Bind(function(value)
			for player, object in pairs(objects) do
				if not table.find(value, player) or player == _L.Player then
					objects[player] = nil
					object.trove:Destroy()
				end
			end
			
			for _, player in pairs(value) do
				if not objects[player] and player ~= _L.Player then
					local newTrove = Trove.new()
					local newFrame = newTrove:Add(_L.Assets.UI.Trade.ListTemplate:Clone())
					
					newFrame.Main.TradeBtn.MouseButton1Down:Connect(function()
						-- V1.1 Fruit Trading (Server.Controllers.FruitTrade)
						local ok, success, err, extra = pcall(Network.Remote.Invoke, "S_FTrade_Request", player)
						if not ok then
							success, err = false, "invalid"
						end
						Notifications:add({
							text = if success then ("Trade request sent to " .. player.DisplayName .. ".")
								elseif err == "disabled" then "That player has trade requests turned off."
								elseif err == "friends" then "That player only accepts trades from friends."
								elseif err == "trading" then "That player is already trading."
								elseif err == "you_trading" then "Finish your current trade first."
								elseif err == "cooldown" then ("Wait " .. tostring(extra or "a few") .. "s before asking again.")
								else "Couldn't send the request. Try again.",
							duration = 2
						})
					end)
					
					newFrame.Main.Title.Text = player.Name
					newFrame.Parent = self.object.Main.Middle
					
					objects[player] = {
						player = player,
						instance = newFrame,
						trove = newTrove
					}
				end
			end
		end)
	end
end

function TradeList:get_players()
	return ArrayUtility.filter(Services.Players:GetPlayers(), function(i, v)
		return v.ClassName == "Player"
	end)
end

function TradeList:Open()
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
end

function TradeList:Close()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return TradeList