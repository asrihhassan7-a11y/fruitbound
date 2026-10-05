repeat task.wait() until _G._L

--> Variables
local _L = _G._L

local UI = _L.Get {"Client", "Modules", "UI"}
local Services = _L.Get {"Common", "Library", "Services"}

--> Constants
local STUDIO_RESOLUTION = Vector2.new(1230, 834)

---------->
UI.Await()

local objects = {}

local function getDescendant(descendant)
	local object = objects[descendant]

	if not object then
		objects[descendant] = {}
		object = objects[descendant]
	end

	return object
end

local function scaleDescendant(descendant)
	if descendant:IsA("UIStroke") then
		local object = getDescendant(descendant)

		if not object.UIStroke then
			object.UIStroke = {}
		end

		if not object.UIStroke.Thickness then
			object.UIStroke.Thickness = descendant.Thickness
		end

		descendant.Thickness = object.UIStroke.Thickness / ((STUDIO_RESOLUTION.X + STUDIO_RESOLUTION.Y) / 2) * ((workspace.CurrentCamera.ViewportSize.X + workspace.CurrentCamera.ViewportSize.Y) / 2)
	elseif (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) and descendant["ScaleType"] == Enum.ScaleType.Slice then
		local object = getDescendant(descendant)

		if not object.Slice then
			object.Slice = {}
		end

		if not object.Slice.Scale then
			object.Slice.Scale = descendant.SliceScale
		end

		descendant.SliceScale = (workspace.CurrentCamera.ViewportSize.X / STUDIO_RESOLUTION.X) * object.Slice.Scale
	end
end

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	for _, descendant in pairs(_L.PlayerGui:GetDescendants()) do
		scaleDescendant(descendant)
	end
end)

for _, descendant in pairs(_L.PlayerGui:GetDescendants()) do
	scaleDescendant(descendant)
end

_L.PlayerGui.DescendantAdded:Connect(function(descendant)
	scaleDescendant(descendant)
end)