repeat task.wait() until _G._L

--> Variables
local _L = _G._L

local GIF = _L.Get {"Client", "Modules", "Classes", "GIF"}
local Rainbow = _L.Get {"Client", "Modules", "Classes", "Rainbow"}
local Spr = _L.Get {"Common", "Library", "Physics", "Spr"}

--> Constants


---------->
local newGIF = GIF.new {
	instance = script.Parent
}

--task.spawn(function()
--	while task.wait(1) do
--		Spr.Target(script.Parent, 1, 1, {
--			ImageColor3 = Color3.fromRGB(255, 0, 233)
--		})
--		task.wait(1)
--		Spr.Target(script.Parent, 1, 1, {
--			ImageColor3 = Color3.fromRGB(144, 0, 255)
--		})
--		task.wait(1)
--		Spr.Target(script.Parent, 1, 1, {
--			ImageColor3 = Color3.fromRGB(0, 28, 255)
--		})
--	end
--end)

while task.wait(math.random(6,10)/15) do
	script.Parent.Rotation = math.random(0, 360)
	newGIF:Play()
end