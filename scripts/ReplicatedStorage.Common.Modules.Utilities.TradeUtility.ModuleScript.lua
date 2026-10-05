--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local AttributeUtility
local Constants
local Network
local Services

--> Constants

---------->
local TradeUtility

TradeUtility = {
	canOccur = function(players)
		local clients = {}
		
		for i, player in pairs(players) do
			if player.Parent ~= Services.Players then
				return false
			end
			local client = Network.Bindable.Invoke("S_Client_Get", player)
			if not client or not client.player_controller then
				return false
			end
			if i == 2 and not client.data:Get({"settings", "Trades"}) then
				return false, "disabled"
			end
			
			clients[i] = client
		end
		
		for _, client in pairs(clients) do
			if client.player_controller._trade:Get() then
				return false, "trading"
			end
		end
		
		return true
	end,
	
	getTraderIndex = function(trade, player)
		return table.find(trade._players, player)
	end,
	
	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		Network = _L.Get {"Common", "Library", "Network"}
		Services = _L.Get {"Common", "Library", "Services"}
	end
}

return TradeUtility