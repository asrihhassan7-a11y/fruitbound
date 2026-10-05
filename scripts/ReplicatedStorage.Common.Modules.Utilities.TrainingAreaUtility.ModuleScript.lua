--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local TrainingAreas
local AttributeUtility
local Constants
local Services

local TrainingAreaZones = {}

--> Constants

---------->
local TrainingAreaUtility

TrainingAreaUtility = {
	getTotalCount = function(data)
		local t = 0

		for _, trainingAreaInfo in pairs(TrainingAreas) do
			local trainingAreaId = trainingAreaInfo.id

			local canUse = TrainingAreaUtility.canUse(data, trainingAreaId)

			if canUse then
				t += 1
			end
		end

		return t
	end,
	
	getBestInfo = function(data)
		local i, v = TableUtility.max(TableUtility.filter(TrainingAreas, function(i, v)
			return typeof(v.required) ~= "table" and TrainingAreaUtility.canUse(data, v.id)
		end), function(i, v)
			return v.required
		end)
		
		return v
	end,
	
	getInfo = function(trainingAreaId)
		local _, trainingAreaInfo = TableUtility.match(TrainingAreas, function(i, v)
			return typeof(v) == "table" and v.id == trainingAreaId
		end)

		return trainingAreaInfo
	end,
	
	find = function(playerController)
		for trainingAreaId, trainingAreaZone in pairs(TrainingAreaZones) do
			if TrainingAreaUtility.canUse(playerController._data, trainingAreaId) and trainingAreaZone:findPlayer(playerController._instance) then
				return trainingAreaId
			end
		end
	end,
	
	getGardenName = function(trainingAreaId)
		local Gardens = _L.Get {"Common", "Modules", "Databases", "Gardens"}
		for _, g in ipairs(Gardens) do
			if g.id == trainingAreaId then
				return g.name
			end
		end
		return "this garden"
	end,
	
	canUse = function(data, trainingAreaId)
		local trainingAreaInfo = TrainingAreaUtility.getInfo(trainingAreaId)
		if typeof(trainingAreaInfo.required) == "table" then
			return trainingAreaInfo.required.callback(data)
		else
			return data:Get({"stats", "Strength"}) > trainingAreaInfo.required
		end
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
		Network = _L.Get {"Common", "Library", "Network"}
		TrainingAreas = _L.Get {"Common", "Modules", "Databases", "TrainingAreas"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		Zone = _L.Get {"Common", "Library", "Physics", "Zone"}
	end,
	
	_start = function()
		if Services.RunService:IsServer() then
			for _, trainingAreaInstance in pairs(_L.Map.TrainingAreas:GetChildren()) do
		if not trainingAreaInstance:FindFirstChild("Zone") then continue end
				local trainingAreaId = tonumber(trainingAreaInstance.Name)
				local trainingAreaInfo = TrainingAreaUtility.getInfo(trainingAreaId)
				
				trainingAreaInstance.Zone.Transparency = 1
				
				local newTrainingAreaZone = Zone.new(trainingAreaInstance.Zone)

				TrainingAreaZones[trainingAreaId] = newTrainingAreaZone

				newTrainingAreaZone.playerEntered:Connect(function(player)
					local client = Network.Bindable.Invoke("S_Client_Get", player)

					if not client or not client.player_controller then
						return
					end

					local currentStrength = client.data:Get({"stats", "Strength"})

					-- achievements: remember every garden the player has discovered
					local discovered = client.data:Get("discovered_gardens") or {}
					if not table.find(discovered, trainingAreaId) then
						local newDiscovered = table.clone(discovered)
						table.insert(newDiscovered, trainingAreaId)
						client.data:Set("discovered_gardens", newDiscovered)
						client.player_controller:_notify({
							text = "🗺️ New area discovered: "..TrainingAreaUtility.getGardenName(trainingAreaId).."! ("..#newDiscovered.." found)",
							color = Color3.fromRGB(120, 230, 255),
						})
					end

					if TrainingAreaUtility.canUse(client.data, trainingAreaId) then
						client.player_controller:_notify({
							text = "🌳 Welcome to "..TrainingAreaUtility.getGardenName(trainingAreaId).."! (x"..trainingAreaInfo.multiplier.." Coins)",
							color = Color3.fromRGB(255, 255, 0),
							audio = {name = "Trumpet1"}
						})
						
						client.player_controller._training_area:Set(trainingAreaId)
					else
						client.player_controller:_notify({
							text = trainingAreaInfo.error_message or "❌ You need "..NumberUtility.short(trainingAreaInfo.required - currentStrength).." more Coins to harvest in "..TrainingAreaUtility.getGardenName(trainingAreaId).."!",
							color = Color3.fromRGB(255, 0, 0),
							audio = {name = "Fail1"}
						})
					end
					
					local bestTrainingAreaInfo = TrainingAreaUtility.getBestInfo(client.data)
					
					if not player:GetAttribute("visited_best_training_area") and trainingAreaInfo == bestTrainingAreaInfo then
						player:SetAttribute("visited_best_training_area", true)
					end
				end)

				newTrainingAreaZone.playerExited:Connect(function(player)
					local client = Network.Bindable.Invoke("S_Client_Get", player)

					if not client or not client.player_controller then
						return
					end
					
					client.player_controller._training_area:Set(nil)
				end)
			end
		end
	end,
}

return TrainingAreaUtility