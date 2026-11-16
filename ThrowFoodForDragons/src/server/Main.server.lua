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
print("[TFFD] Server ready")
