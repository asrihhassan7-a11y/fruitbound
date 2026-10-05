--> Variables
local _L = _G._L

local Services
local Create

--> Constants

------------->
local UI = {}

function UI._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
end

function UI._start()
	local newUIStorageFolder = Create("Folder", {
		Name = "UI",
		Parent = _L.Storage
	})
	
	for _, instance in pairs(Services.StarterGui:GetChildren()) do
		instance.Parent = newUIStorageFolder
	end
end

return UI