--> Variables
local _L = _G._L

local PlayerRewards
local TableUtility

--> Constants

---------->
local PlayerRewardUtility

PlayerRewardUtility = {
	getInfo = function(playerRewardName)
		local _, playerRewardInfo = TableUtility.match(PlayerRewards, function(i, v)
			return typeof(v) == "table" and  v.name == playerRewardName
		end)

		return playerRewardInfo
	end,

	give = function(client, pr, rewardUi)
		local rewardData = {}
		local allSucceeded = true

		for _, playerReward in pairs(pr) do
			local playerRewardInfo = PlayerRewardUtility.getInfo(playerReward.name)
			if not playerRewardInfo then
				allSucceeded = false
				continue
			end

			local success, rewards = playerRewardInfo.callback(client, playerReward.props)
			if not success then
				allSucceeded = false
				continue
			end

			if typeof(rewards) == "table" then
				for _, reward in pairs(rewards) do
					table.insert(rewardData, reward)
				end
			elseif rewards ~= nil then
				table.insert(rewardData, rewards)
			end
		end

		if rewardUi and allSucceeded then
			Network.Remote.Fire("C_Reward_Open", client.player, rewardData)
		end

		return allSucceeded, rewardData
	end,

	_init = function()
		PlayerRewards = _L.Get {"Common", "Modules", "Databases", "PlayerRewards"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Network = _L.Get {"Common", "Library", "Network"}
	end
}

return PlayerRewardUtility