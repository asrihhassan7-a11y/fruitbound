--> Variables
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Loader)

--> Constants

---------->
local Common = {}

function Common._init()
	Loader._start {
		instance = script
	}
end


return Common

