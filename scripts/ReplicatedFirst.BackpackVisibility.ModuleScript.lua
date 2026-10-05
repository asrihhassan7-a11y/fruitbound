--> BackpackVisibility (client)
-- The one place that turns the Roblox Backpack hotbar (where the Seed Tools live) off and on.
-- Anything that wants it hidden adds a reason; it comes back only when no reason is left:
--   "Loading"        - ReplicatedFirst.LoadingScreen, until it finishes or Skip is pressed
--   "SeedPackReveal" - SeedShop, while a Seed Pack reveal is on screen
-- Only CoreGui visibility changes: Tools, the Backpack and inventory data are never touched.
-- Adding / removing the same reason twice does nothing, and SetCoreGuiEnabled is only called
-- when the visible state really changes (no flicker, no duplicate calls).

local StarterGui = game:GetService("StarterGui")

local BackpackVisibility = {}

local reasons = {} -- [reason] = true
local applied = nil -- last state sent to the CoreGui (nil = never set by this module)

local retries = 0

local function apply()
	local visible = next(reasons) == nil
	if applied == visible then
		return
	end
	if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, visible) then
		applied = visible
		retries = 0
	elseif retries < 20 then
		-- the CoreGui can refuse very early in the join: try again shortly (never yields the caller)
		retries += 1
		task.delay(0.1, apply)
	end
end

function BackpackVisibility.hide(reason)
	if reasons[reason] then
		return
	end
	reasons[reason] = true
	apply()
end

function BackpackVisibility.show(reason)
	if not reasons[reason] then
		return
	end
	reasons[reason] = nil
	apply()
end

function BackpackVisibility.isHidden(reason)
	if reason then
		return reasons[reason] == true
	end
	return next(reasons) ~= nil
end

return BackpackVisibility
