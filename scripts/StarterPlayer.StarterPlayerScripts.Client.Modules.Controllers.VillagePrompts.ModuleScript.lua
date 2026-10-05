--> VillagePrompts (client)
-- Any ProximityPrompt with an "OpenUI" attribute (village shops, rewards podiums, fruit pen boards)
-- opens that existing menu. To add a new shop: put a ProximityPrompt on it and set OpenUI = "<UI name>".

local _L = _G._L

local ProximityPromptService = game:GetService("ProximityPromptService")

local VillagePrompts = {}

function VillagePrompts._start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local uiName = prompt:GetAttribute("OpenUI")
		if not uiName then
			return
		end
		local ok, err = pcall(function()
			local UI = _L.Get {"Client", "Modules", "UI"}
			if not UI.Get(uiName) then
				return
			end
			local Audio = _L.Get {"Common", "Library", "Audio"}
			pcall(function()
				Audio.Play({name = "Plop1"})
			end)
			UI.Open({name = uiName, props = prompt:GetAttribute("Subject") and {subject = prompt:GetAttribute("Subject")} or nil})
		end)
		if not ok then
			warn("[VillagePrompts]", err)
		end
	end)
end

return VillagePrompts
