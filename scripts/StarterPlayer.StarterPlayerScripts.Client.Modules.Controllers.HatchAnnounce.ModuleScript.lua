--> HatchAnnounce (client)
-- Shows the server's rare hatch announcement as a system line in the normal Roblox chat.
-- Completely silent: no sound, no popup, no UI - just the chat line.

local _L = _G._L

local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")

local Network

local RARITY_COLOR = {
	Mythical = "FF5078", Huge = "50FFAA", Secret = "C8A0FF", Divine = "FFE68C",
}

local HatchAnnounce = {}

local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;"))
end

local recent = {} -- guard against the same line arriving twice in the same moment

local function show(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local who, fruit, rarity = tostring(payload.player or "?"), tostring(payload.fruit or "Fruit"), tostring(payload.rarity or "")
	local key = who .. fruit .. rarity .. math.floor(os.clock() * 10)
	if recent[key] then
		return
	end
	recent[key] = true
	HatchAnnounce.count = (HatchAnnounce.count or 0) + 1
	_L.Player:SetAttribute("RareHatchSeen", HatchAnnounce.count) -- local only (tests / debugging)
	task.delay(1, function()
		recent[key] = nil
	end)

	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			local color = RARITY_COLOR[rarity] or "FFD34D"
			general:DisplaySystemMessage(string.format(
				'<font color="#FFD34D"><b>🌟 [RARE HATCH]</b></font> %s hatched a <font color="#%s"><b>%s</b></font> %s!',
				escape(who), color, escape(rarity:upper()), escape(fruit)
			))
		end
	else
		-- legacy chat (Studio test sessions)
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = string.format("🌟 [RARE HATCH] %s hatched a %s %s!", who, rarity:upper(), fruit),
				Color = Color3.fromRGB(255, 211, 77),
				Font = Enum.Font.FredokaOne,
			})
		end)
	end
end

function HatchAnnounce._init()
	Network = _L.Get {"Common", "Library", "Network"}
end

function HatchAnnounce._start()
	Network.Remote.Fired("C_Rare_Hatch", show)
end

return HatchAnnounce
