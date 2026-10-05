--> Variables
local _L = _G._L

local Draggables
local TableUtility
local Constants
local AttributeUtility
local Services

--> Constants

---------->
local DiscordUtility

DiscordUtility = {
	isAllowed = function(player)
		player = player or _L.Player
		
		if not player then
			return false
		end
		
		local success, result = pcall(function()
			return Services.PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)

		if not success then
			return false
		elseif result.AllowedExternalLinkReferences and table.find(result.AllowedExternalLinkReferences, "Discord") then
			return true
		end

		return false
	end,
	
	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
		Services = _L.Get {"Common", "Library", "Services"}
	end
}

return DiscordUtility