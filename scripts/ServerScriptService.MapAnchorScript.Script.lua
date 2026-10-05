-- MapAnchorScript
-- Automatically anchors and locks every BasePart in the Workspace when the server starts.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Check if a part belongs to a player character (skip those)
local function isPlayerCharacter(part)
    -- never anchor held items (seed Tools etc.): an anchored Handle anchors the character
    if part:FindFirstAncestorWhichIsA("Tool") then
        return true
    end
    local ancestor = part.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
            -- Check if this model is a player's character
            local player = Players:GetPlayerFromCharacter(ancestor)
            if player then
                return true
            end
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function anchorMap()
    local count = 0
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and not isPlayerCharacter(descendant) then
            descendant.Anchored = true
            count += 1
        end
    end
    print("[MapAnchorScript] Anchored " .. count .. " BaseParts in the Workspace.")
end

-- Run once on server start
anchorMap()

-- Also anchor any parts that get added to the Workspace later (e.g. dynamically spawned map geometry)
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("BasePart") and not isPlayerCharacter(descendant) then
        descendant.Anchored = true
    end
end)
