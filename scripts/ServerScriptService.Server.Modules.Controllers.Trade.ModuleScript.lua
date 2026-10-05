--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtility
local Create
local ArrayUtility
local Timer

--> Constants
local TRADING_STATES = {"Default", "Completed", "Cancelled"}

------------->
local Trade = {_objects = {}}
Trade.__index = Trade

function Trade._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"} 
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"} 
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
end

function Trade._start()
end

function Trade.new(props)
	local self = setmetatable({}, Trade)
	
	self._players = props.players
	self._uid = props.uid or Services.HttpService:GenerateGUID(false)
	
	self._traders = {}
	self._state = {tracker = Tracker.new("Default"), trove = Trove.new()}
	
	self._trove = Trove.new()
	
	self:_construct()

	return self
end

function Trade:_construct()
	self._trove:Add(self._state.trove)
	
	Trade._objects[self._uid] = self

	self._trove:Add(function()
		for _, client in pairs(self._clients) do
			local playerController = client.player_controller
			if playerController then
				playerController._trade:Set(nil)
			end
		end
		
		Trade._objects[self._uid] = nil
	end)
	
	self._trove:Add(Services.Players.PlayerRemoving:Connect(function(player)
		if table.find(self._players, player) then
			self:Destroy()
		end
	end))
	
	self._holder = self._trove:Add(self:_create_holder())
	
	self._clients = {}
	
	for i, player in pairs(self._players) do
		local client = Network.Bindable.Invoke("S_Client_Get", player)
		if client and client.player_controller then
			self._clients[i] = client
		else
			self:Destroy()
			return
		end
	end
	
	for i, client in pairs(self._clients) do
		self._traders[i] = self:_create_trader(client)
	end
	
	self._state.tracker:Bind(function(value)
		self._state.trove:Clean()
		
		local props = {}
		
		if value == "Completed" then
			self._state.trove:Add(task.spawn(function()
				self:_update_state(props)
				
				local pets = {}

				for i, trader in pairs(self._traders) do
					local client = self._clients[i]
					local otherIndex = if i == 1 then 2 else 1
					local otherTrader = self._traders[otherIndex]
					local otherClient = self._clients[otherIndex]

					if client and trader and client.player.Parent == Services.Players and otherTrader and otherClient and otherClient.player.Parent == Services.Players then
						local newPets = client.data:Get("pets")

						for _, petUid in pairs(trader.pets) do
							local i, newPetData = TableUtility.match(newPets, function(i, v)
								return v.uid == petUid
							end)

							if newPetData then
								pets[petUid] = {petUid, newPetData.name, newPetData.tier}
								table.remove(newPets, i)
							end
						end

						client.data:Set("pets", newPets)
					else
						self:Destroy()
						return
					end
				end

				for i, trader in pairs(self._traders) do
					local client = self._clients[i]
					local otherIndex = if i == 1 then 2 else 1
					local otherTrader = self._traders[otherIndex]
					local otherClient = self._clients[otherIndex]

					if client and trader and client.player.Parent == Services.Players and otherTrader and otherClient and otherClient.player.Parent == Services.Players then
						PlayerRewardUtility.give(client, ArrayUtility.map(otherTrader.pets, function(i, v)
							return if v then {name = "Pet", props = {
								uid = pets[v][1],
								name = pets[v][2],
								tier = pets[v][3]
							}} else nil
						end), true)
					else
						self:Destroy()
						return
					end
					
					task.spawn(function()
						if client and client.player then
							Services.BadgeService:AwardBadge(client.player.UserId, 2149635682)
						end
					end)
				end
				
				self:_update_state(props)
				
				for i, trader in pairs(self._traders) do
					local client = self._clients[i]
					Network.Remote.Fire("C_Trade_Completed", client.player)
				end
				
				self:Destroy()
			end))
		elseif value == "Cancelled" then
			self:_update_state(props)
			self:Destroy()
		elseif value == "Default" then
			self:_update_state(props)
		end
	end)
	
	self:_update_traders()
end

function Trade:_create_holder()
	return Create("Folder", {
		Name = self._uid,
		Parent = _L.Debris.Trades
	})
end

function Trade:_update_state(props)
	AttributeUtility.set(self._holder, "state", {
		value = self._state.tracker:Get(),
		props = props
	})
end

function Trade:_update_traders()
	AttributeUtility.set(self._holder, "traders", TableUtility.map(self._traders, function(i, v)
		return i, {
			user_id = v.user_id,
			ready = v.ready:Get(),
			pets = v.pets
		}
	end))
end
	
function Trade:_create_trader(client)
	local readyTracker = Tracker.new(false)
	local traderPets = {}
	
	self._trove:Add(readyTracker:Bind(function(value)
		local isAllReady = TableUtility.all(self._traders, function(i, v)
			return v.ready:Get()
		end)
		
		if isAllReady then
			self._state.tracker:Set("Completed")
		else
			self._state.tracker:Set("Default")
		end
		
		self:_update_traders()
	end))
	
	self._trove:Add(client.data:Bind("pets", function(value)
		if self._state.tracker:Get() ~= "Completed" then
			for _, petUid in pairs(traderPets) do
				if not value[petUid] then
					local petIndex = table.find(traderPets, petUid)

					if petIndex then
						table.remove(traderPets, petIndex)
					end
				end
			end

			self._state.tracker:Set("Default")

			self:_unready_all()
		
			self:_update_traders()
		end
	end))
	
	return {
		ready = readyTracker,
		user_id = client.player.UserId,
		pets = traderPets
	}
end

function Trade:_unready_all()
	for _, trader in pairs(self._traders) do
		trader.ready:Set(false)
	end
end

function Trade:Destroy()
	self._trove:Destroy()
end

return Trade