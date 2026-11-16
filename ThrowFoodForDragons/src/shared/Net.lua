-- All remotes live in ReplicatedStorage.TFFD_Remotes and are created only by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Throw", "State", "FoodThrown", "Dragons", "Fed", "Notify", "Discover" }
local FUNCTIONS = { "Action", "GetDragons" }

local Net = {}
local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("TFFD_Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TFFD_Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, n in EVENTS do
		if not folder:FindFirstChild(n) then
			local r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
	end
	for _, n in FUNCTIONS do
		if not folder:FindFirstChild(n) then
			local r = Instance.new("RemoteFunction")
			r.Name = n
			r.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("TFFD_Remotes") :: Folder
end

function Net.get(name: string): any
	return folder:WaitForChild(name)
end

return Net
