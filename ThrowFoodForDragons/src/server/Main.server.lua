-- Throw Food for Dragons — server entry point. Starts every service in dependency order.
local Services = script.Parent:WaitForChild("Services")

local WorldBuilder = require(Services.WorldBuilder)
local DataService = require(Services.DataService)
local PlayerService = require(Services.PlayerService)
local DragonService = require(Services.DragonService)
local ThrowService = require(Services.ThrowService)
local QuestService = require(Services.QuestService)
local MonetizationService = require(Services.MonetizationService)
local ActionService = require(Services.ActionService)

WorldBuilder.build()
PlayerService.start() -- before DataService so leaderstats/pass checks exist when profiles load
QuestService.start(DragonService, ThrowService)
DataService.start()
DragonService.start()
ThrowService.start()
MonetizationService.start()
ActionService.start()

-- expose for Studio testing from the command bar: _G.TFFD.DragonService.debugSpawn("phoenixwyrm", 1)
_G.TFFD = { DataService = DataService, PlayerService = PlayerService, DragonService = DragonService, ThrowService = ThrowService, ActionService = ActionService }
-- Studio-only test hook (never exists in live servers): lets test scripts grant coins / spawn dragons.
if game:GetService("RunService"):IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "TFFD_StudioDebug"
	hook.OnInvoke = function(cmd, player, a, b)
		if cmd == "coins" then
			PlayerService.addCoins(player, a, "debug")
		elseif cmd == "spawn" then
			return DragonService.debugSpawn(a, b) ~= nil
		elseif cmd == "action" then
			return ActionService.handlers[a](player, DataService.get(player), b)
		elseif cmd == "pass" then
			PlayerService.grantPass(player, a)
		elseif cmd == "profile" then
			return DataService.get(player)
		end
		return true
	end
	hook.Parent = game:GetService("ServerStorage")
end
print("[TFFD] Server ready")
