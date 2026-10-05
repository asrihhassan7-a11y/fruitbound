--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtility
local Trade
local TradeUtility

--> Constants

------------->
local TradeRequest = {_objects = {}}
TradeRequest.__index = TradeRequest

function TradeRequest._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Trade = _L.Get {"Server", "Modules", "Controllers", "Trade"}
	TradeUtility = _L.Get {"Common", "Modules", "Utilities", "TradeUtility"}
end

function TradeRequest._start()
	-- V1.1: legacy pet trade requests are off (they let any player answer any request).
	-- Fruit trading lives in Controllers.FruitTrade.
	Network.Remote.Invoked("S_Trade_Request_Decide", function()
		return false, "legacy"
	end)
end

function TradeRequest.new(props)
	local self = setmetatable({}, TradeRequest)
	
	self._players = props.players
	self._callback = props.callback
	
	self._uid = props.uid or Services.HttpService:GenerateGUID(false)
	
	self._trove = Trove.new()
	
	self:_construct()

	return self
end

function TradeRequest:_construct()
	Network.Remote.Fire("C_Trade_Request_Send", self._players[2], {
		uid = self._uid,
		player = self._players[1]
	})
	
	TradeRequest._objects[self._uid] = self
	
	self._trove:Add(function()
		for i, player in pairs(self._players) do
			local client = Network.Bindable.Invoke("S_Client_Get", player)

			if client and client.player_controller and i == 1 then
				client.player_controller._trade_requests[self._players[2]] = nil
			end
		end
		
		TradeRequest._objects[self._uid] = nil
	end)
	
	self._trove:Add(Services.Players.PlayerRemoving:Connect(function(player)
		if table.find(self._players, player) then
			self:Destroy()
		end
	end))
end

function TradeRequest:decide(state)
	local success, err = true, nil
	
	if state then
		local players = self._players
		success, err = TradeUtility.canOccur(players)

		if success then
			local newTrade = Trade.new({
				players = players
			})

			for _, player in pairs(players) do
				local client = Network.Bindable.Invoke("S_Client_Get", player)

				if client and client.player_controller then
					client.player_controller._trade:Set(newTrade._uid)
				else
					newTrade:Destroy()
				end
			end
		end
	end
	
	self:Destroy()
	
	return success, err
end

function TradeRequest:Destroy()
	if not self._destroyed then
		self._destroyed = true
		self._trove:Destroy()
	end
end

return TradeRequest