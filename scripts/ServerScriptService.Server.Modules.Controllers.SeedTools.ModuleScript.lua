-- // VARIABLES // --
local _L = _G._L

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network
local SeedPacks

-- Mirrors the saved seed_inventory into Backpack Tools so players can
-- equip a seed and tap/click to plant it. The inventory stays the single
-- source of truth (FarmingV2 still owns all planting validation); these
-- tools are purely a view of it.
local SeedTools = {}

local tools = {} -- [player] = {[seedId] = Tool}
local binds = {}
local characterConnections = {}

-- // FUNCTIONS // --

--[[
Returns the loaded player profile controller.
@param player Player -- Profile owner.
@return table? -- Existing player controller.
]]
local function getController(player)
	local client = Network.Bindable.Invoke("S_Client_Get", player)
	return client and client.player_controller or nil
end

--[[
Builds one equipable Seed Tool from the shared seed visual.
@param seedId string -- Stable Seed identifier.
@param count number -- Owned quantity.
@return Tool? -- Configured Tool.
]]
local function buildTool(seedId, count)
	local seed = SeedPacks.getSeed(seedId)
	if not seed then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = seed.display_name or seedId
	tool.ToolTip = (seed.display_name or seedId) .. " (x" .. count .. ")"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("SeedId", seedId)
	tool:SetAttribute("SeedCount", count)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local seedsFolder = models and models:FindFirstChild("Seeds")
	local template = seedsFolder and seedsFolder:FindFirstChild(seed.visual or seedId)
	local mesh = template and template:FindFirstChildWhichIsA("BasePart")

	local handle
	if mesh then
		handle = mesh:Clone()
		handle.Name = "Handle"
		-- keep the seed pocket-sized in-hand
		local size = handle.Size
		local longest = math.max(size.X, size.Y, size.Z)
		if longest > 1.6 then
			pcall(function()
				handle.Size = size * (1.6 / longest)
			end)
		end
	else
		handle = Instance.new("Part")
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.new(0.9, 0.9, 0.9)
		handle.Color = seed.fruit or Color3.fromRGB(120, 200, 120)
		handle.Material = Enum.Material.SmoothPlastic
	end
	-- The seed templates are Anchored display meshes. An anchored Handle gets welded to the
	-- hand on equip and anchors the whole character (it floats / freezes), so the in-hand
	-- copy must be a plain, physics-free part held only by the Tool's own grip weld.
	handle.Anchored = false
	handle.Massless = true
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	handle.Parent = tool
	return tool
end

--[[
Reconciles the player's Backpack Tools with the saved seed_inventory.
Safe to run repeatedly: creates missing tools, updates counts, and
removes tools for seeds that were spent.
@param player Player -- Profile owner.
]]
local function sync(player)
	local mine = tools[player]
	if not mine then
		return
	end
	local controller = getController(player)
	if not controller or not controller._data then
		return
	end
	local inventory = controller._data:Get("seed_inventory")
	if typeof(inventory) ~= "table" then
		inventory = {}
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	-- update or remove existing tools
	for seedId, tool in pairs(mine) do
		local count = inventory[seedId]
		local alive = tool.Parent ~= nil and tool:IsDescendantOf(player)
		if typeof(count) ~= "number" or count <= 0 or not alive then
			pcall(function()
				tool.Parent = nil
			end)
			mine[seedId] = nil
		else
			local owned = math.floor(count)
			tool:SetAttribute("SeedCount", owned)
			local seed = SeedPacks.getSeed(seedId)
			if seed and seed.display_name then
				tool.ToolTip = seed.display_name .. " (x" .. owned .. ")"
			end
			-- a tool can lose its parent when the old Backpack is cleared on
			-- respawn; put it back into the live Backpack
			if not tool.Parent and backpack then
				tool.Parent = backpack
			end
		end
	end

	-- add tools for newly owned seeds
	if not backpack then
		return
	end
	for seedId, count in pairs(inventory) do
		if typeof(count) == "number" and count > 0 and not mine[seedId] then
			local tool = buildTool(seedId, math.floor(count))
			if tool then
				mine[seedId] = tool
				tool.Parent = backpack
			end
		end
	end
end

--[[
Sets up tool mirroring for one player (rejoin safe: waits for the profile).
@param player Player -- Profile owner.
]]
local function onPlayer(player)
	tools[player] = {}

	local controller
	for _ = 1, 120 do
		controller = getController(player)
		if controller or not player.Parent then
			break
		end
		task.wait(0.5)
	end
	if not controller or not player.Parent then
		tools[player] = nil
		return
	end

	sync(player)

	-- keep tools in step with the inventory whenever FarmingV2 changes it
	-- (buying packs and planting both Set("seed_inventory", ...))
	local data = controller._data
	if data and data.Bind then
		local ok, bind = pcall(data.Bind, data, "seed_inventory", function()
			task.spawn(sync, player)
		end)
		if ok then
			binds[player] = bind
		end
	end

	-- the Backpack is recreated on every respawn, so rebuild for the new one
	characterConnections[player] = player.CharacterAdded:Connect(function()
		task.wait(0.2)
		sync(player)
		end)
end

function SeedTools._init()
	Network = _L.Get {"Common", "Library", "Network"}
	SeedPacks = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
end

function SeedTools._start()
	-- the client asks for one normal rebuild after a Seed Pack reveal (no hidden state:
	-- it just re-mirrors the saved seed_inventory); at most once per second per player
	local lastRefresh = {}
	Network.Remote.Invoked("S_SeedTools_Refresh", function(player)
		local now = os.clock()
		if tools[player] and now - (lastRefresh[player] or 0) >= 1 then
			lastRefresh[player] = now
			sync(player)
		end
		return true
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRefresh[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayer, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local bind = binds[player]
		if bind then
			pcall(function()
				if typeof(bind) == "function" then
					bind()
				elseif bind.Disconnect then
					bind:Disconnect()
				elseif bind.destroy then
					bind:destroy()
				end
			end)
		end
		binds[player] = nil
		local conn = characterConnections[player]
		if conn then
			conn:Disconnect()
		end
		characterConnections[player] = nil
		tools[player] = nil
	end)
end

-- // INITIALIZATION // --
return SeedTools