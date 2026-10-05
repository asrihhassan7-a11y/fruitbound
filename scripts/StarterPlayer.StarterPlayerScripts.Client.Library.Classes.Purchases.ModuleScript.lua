--> Variables
local _L = _G._L

local TableUtility
local Services
local Promise
local Signal
local Gamepasses
local Data

--> Constants
	
------------->
local Purchases = {_objects = {}}
Purchases.__index = Purchases

function Purchases.Await(player, dontYield)
	player = player or _L.Player
	
	local purchases = Purchases._objects[player]

	if purchases then
		return purchases
	elseif not dontYield then
		local newTrove = Trove.new()

		return Promise.new(function(resolve, reject)
			local purchases = Purchases._objects[player]

			if purchases then
				resolve(purchases)
				return
			end
			
			newTrove:Connect(Purchases.Added, function(addedPurchases)
				if addedPurchases._player == player then
					resolve(addedPurchases)
				end
			end)

			newTrove:Connect(Services.Players.PlayerRemoving, function(removedPlayer)
				if removedPlayer == player then
					reject()
				end
			end)
		end):finally(function()
			newTrove:Destroy()
		end):catch(warn):expect()
	end
end

function Purchases.GetProductInfoFromId(productId)
	local _, productInfo = TableUtility.match(Products, function(k, v)
		return typeof(v) == "table" and v.id == productId
	end)

	return productInfo
end

function Purchases.GetGamepassInfoFromId(gamepassId)
	local _, gamepassInfo = TableUtility.match(Gamepasses, function(k, v)
		return typeof(v) == "table" and v.id == gamepassId
	end)

	return gamepassInfo
end

function Purchases.GetProductInfoFromName(productName)
	local _, productInfo = TableUtility.match(Products, function(k, v)
		return typeof(v) == "table" and v.name == productName
	end)

	return productInfo
end

function Purchases.GetGamepassInfoFromName(gamepassName)
	local _, gamepassInfo = TableUtility.match(Gamepasses, function(k, v)
		return typeof(v) == "table" and v.name == gamepassName
	end)

	return gamepassInfo
end

function Purchases.Add(player)
	local purchases = Purchases._objects[player]

	if not purchases then
		local newPurchases = Purchases.new(player)
		purchases = newPurchases
	end

	return purchases
end

function Purchases.Remove(player)
	local purchases = Purchases._objects[player]

	if purchases then
		Purchases._objects[player] = nil
		purchases:Destroy()
	end
end

-- Products switched off until the new fruit models are ready (baskets + King Fruit pack).
-- Remove a name here to sell it again (and make its Store section visible in StarterGui.Store).
local DISABLED_PRODUCTS = {
	["1_Dragon_Egg"] = true, ["3_Dragon_Eggs"] = true, ["10_Dragon_Eggs"] = true,
	["1_Midnight_Egg"] = true, ["3_Midnight_Eggs"] = true, ["10_Midnight_Eggs"] = true,
	["Electro_Pack"] = true, ["Electrolyte"] = true, ["Electro_Spirit"] = true,
}

function Purchases.PromptProduct(productName)
	local player = _L.Player
	if DISABLED_PRODUCTS[productName] then
		pcall(function()
			local UI = _L.Get {"Client", "Modules", "UI"}
			UI.Get("Notifications"):add({text = "🍓 Coming SOON!", color = Color3.fromRGB(255, 200, 70), duration = 2})
		end)
		return
	end
	
	local _, productInfo = TableUtility.match(Products, function(k, v)
		return typeof(v) == "table" and v.name == productName
	end)

	if productInfo then
		Services.MarketplaceService:PromptProductPurchase(player, productInfo.id)
	end
end

function Purchases.PromptGamepass(gamepassName)
	local player = _L.Player
	
	local _, gamepassInfo = TableUtility.match(Gamepasses, function(k, v)
		return typeof(v) == "table" and v.name == gamepassName
	end)

	if gamepassInfo then
		Services.MarketplaceService:PromptGamePassPurchase(player, gamepassInfo.id)
	end
end

function Purchases.new(player)
	local self = setmetatable({}, Purchases)

	self._player = player
	
	self._data = nil
	
	self._trove = Trove.new()

	self:_construct()

	return self
end

function Purchases:_construct()
	self._trove:AddPromise(Promise.new(function(resolve, reject)
		self._data = Data.Await(self._player)
		
		if self._data then
			Purchases._objects[self._player] = self
			Purchases.Added:Fire(self)
			
			resolve()
		end
	end)):expect()
end

function Purchases:OwnsGamepass(gamepassName)
	local gamepassInfo = Purchases.GetGamepassInfoFromName(gamepassName)
	local gamepassId = gamepassInfo.id

	return table.find(self._data:Get("gamepasses"), gamepassId) ~= nil
end

function Purchases:Destroy()
	self._trove:Destroy()
end

function Purchases._init()
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Gamepasses = _L.Get {"Common", "Modules", "Databases", "Gamepasses"}
	Products = _L.Get {"Common", "Modules", "Databases", "Products"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	
	Purchases.Added = Signal.new()
end

function Purchases._start()
	Services.Players.PlayerRemoving:Connect(function(player)
		Purchases.Remove(player)
	end)

	for _, player in pairs(Services.Players:GetPlayers()) do
		task.spawn(function()
			Purchases.Add(player)
		end)
	end

	Services.Players.PlayerAdded:Connect(function(player)
		Purchases.Add(player)
	end)
end

return Purchases