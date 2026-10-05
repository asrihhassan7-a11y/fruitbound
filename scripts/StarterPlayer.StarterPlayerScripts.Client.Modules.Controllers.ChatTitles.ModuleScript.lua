--> ChatTitles (client)
-- Shows the sender's equipped title in front of their name in the normal Roblox chat (TextChatService):
--   [🌱 Seedling] Hasven: Hello!
-- The title comes ONLY from the ChatTitle / ChatTitleColor attributes the server sets on each player
-- (never from the message itself), and is escaped so emojis / < > & can't break the rich text.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatTitles = {}

local function escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"):gsub("'", "&apos;"))
end

local function titlePrefix(player)
	local text = player:GetAttribute("ChatTitle")
	if typeof(text) ~= "string" or text == "" then
		return nil
	end
	local hex = player:GetAttribute("ChatTitleColor")
	if typeof(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then
		hex = "96E678"
	end
	return string.format('<font color="#%s"><b>[%s]</b></font> ', hex, escape(text))
end

function ChatTitles._init() end

function ChatTitles._start()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local player = source and Players:GetPlayerByUserId(source.UserId)
		if player then
			local prefix = titlePrefix(player)
			if prefix then
				props.PrefixText = prefix .. message.PrefixText
			end
		end
		return props
	end
end

return ChatTitles
