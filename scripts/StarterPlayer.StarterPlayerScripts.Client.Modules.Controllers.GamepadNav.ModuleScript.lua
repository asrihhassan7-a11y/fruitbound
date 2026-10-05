--> GamepadNav (client)
-- Controller comfort layer, one place for everything:
--  * B closes whatever menu is open (UI system menus, More menu, Fruit Book). When nothing is open,
--    B is passed through untouched.
--  * when a menu opens with a controller, the selection jumps into it (Roblox's own UI navigation does the rest)

local _L = _G._L

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local GamepadNav = {}

local function usingPad()
	return UserInputService:GetLastInputType().Name:find("Gamepad") ~= nil
end

local function closeSomething()
	local pg = _L.PlayerGui
	-- Fruit Book
	local book = pg:FindFirstChild("FruitBookUI")
	if book and book.Enabled then
		local ok, FruitBook = pcall(_L.Get, {"Client", "Modules", "Controllers", "FruitBook"})
		if ok then
			FruitBook.close()
			return true
		end
	end
	local mounts = pg:FindFirstChild("MountsUI")
	if mounts and mounts.Enabled then
		local ok, MountsController = pcall(_L.Get, {"Client", "Modules", "Controllers", "Mounts"})
		if ok then
			MountsController.close()
			return true
		end
	end
	local travel = pg:FindFirstChild("TravelMenu")
	if travel and travel.Enabled then
		travel.Enabled = false
		return true
	end
	-- More menu
	local more = pg:FindFirstChild("MoreMenu")
	if more and more.Enabled then
		more.Enabled = false
		return true
	end
	-- menus of the UI system
	local ok, UI = pcall(_L.Get, {"Client", "Modules", "UI"})
	if ok and UI then
		local cur = UI._current:Get()
		if cur then
			UI.Close({name = cur})
			return true
		end
	end
	return false
end

-- first selectable button inside a gui (top-left most)
local function firstButton(root)
	local best
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible and d.Selectable and d.AbsoluteSize.X > 20 then
			if not best or d.AbsolutePosition.Y < best.AbsolutePosition.Y - 4 or (math.abs(d.AbsolutePosition.Y - best.AbsolutePosition.Y) <= 4 and d.AbsolutePosition.X < best.AbsolutePosition.X) then
				best = d
			end
		end
	end
	return best
end

-- touch-only devices: keep the left menu clear of the thumbstick (bottom-left) zone
local function touchLayout()
	if not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
		return
	end
	local main = _L.PlayerGui:WaitForChild("Main", 20)
	local left = main and main:FindFirstChild("Left")
	if left then
		left.Position = UDim2.new(left.Position.X.Scale, left.Position.X.Offset, 0.4, 0)
		left.Size = UDim2.new(left.Size.X.Scale * 0.88, 0, left.Size.Y.Scale * 0.88, 0)
	end
end

function GamepadNav._init() end

function GamepadNav._start()
	task.spawn(touchLayout)
	ContextActionService:BindActionAtPriority("FB_GamepadClose", function(_, state)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if closeSomething() then
			GuiService.SelectedObject = nil
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)

	-- menu opened with a controller: put the selection inside it
	task.spawn(function()
		local ok, UI = pcall(_L.Get, {"Client", "Modules", "UI"})
		if not ok or not UI then
			return
		end
		UI._current:Bind(function(name)
			if not name or not usingPad() then
				return
			end
			task.delay(0.3, function()
				local gui = _L.PlayerGui:FindFirstChild(name)
				if gui and UI._current:Get() == name then
					local b = firstButton(gui)
					if b then
						GuiService.SelectedObject = b
					end
				end
			end)
		end)
	end)
end

return GamepadNav
