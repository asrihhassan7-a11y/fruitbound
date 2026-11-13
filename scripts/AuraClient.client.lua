-- AuraClient : à mettre dans StarterPlayer > StarterPlayerScripts (LocalScript)
-- Appuie sur E (ou le bouton sur mobile) pour activer ton aura.

local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local remote = game:GetService("ReplicatedStorage"):WaitForChild("AuraActivate")

CAS:BindAction("Aura", function(_, state)
	if state == Enum.UserInputState.Begin then remote:FireServer() end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
CAS:SetTitle("Aura", "Aura")
