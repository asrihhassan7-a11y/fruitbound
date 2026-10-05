--> ChatTitles (server)
-- Publishes each player's EQUIPPED title (from their saved data, via TitleUtility) as player attributes,
-- so the chat can show it. The server is the only one writing these, clients can't fake a title.
--   ChatTitle      = title text ("" when nothing is equipped)
--   ChatTitleColor = title colour as hex ("96E678")
-- The client (Controllers.ChatTitles) adds it in front of the name in TextChatService.

local _L = _G._L

local Players = game:GetService("Players")

local Network
local TitleUtility

local ChatTitles = {}

-- Legacy chat (older Studio test sessions still use it): the same title as a speaker tag
local legacyChat
local function legacyService()
	if legacyChat == nil then
		legacyChat = false
		local runner = game:GetService("ServerScriptService"):FindFirstChild("ChatServiceRunner")
		local module = runner and runner:FindFirstChild("ChatService")
		if module then
			local ok, service = pcall(require, module)
			if ok then
				legacyChat = service
			end
		end
	end
	return legacyChat or nil
end

local function setLegacyTag(player, text, color)
	local service = legacyService()
	if not service then
		return
	end
	task.spawn(function()
		local speaker
		for _ = 1, 40 do
			speaker = service:GetSpeaker(player.Name)
			if speaker or not player.Parent then
				break
			end
			task.wait(0.25)
		end
		if speaker then
			speaker:SetExtraData("Tags", if text then {{TagText = text, TagColor = color}} else {})
		end
	end)
end

local function publish(player, data)
	local ok, info = pcall(TitleUtility.getEquipped, data)
	info = ok and info or nil
	if info and typeof(info.text) == "string" then
		local color = typeof(info.color) == "Color3" and info.color or Color3.fromRGB(150, 230, 120)
		player:SetAttribute("ChatTitle", info.text:sub(1, 40))
		player:SetAttribute("ChatTitleColor", color:ToHex())
		setLegacyTag(player, info.text:sub(1, 40), color)
	else
		player:SetAttribute("ChatTitle", "")
		player:SetAttribute("ChatTitleColor", nil)
		setLegacyTag(player, nil)
	end
end

local function watch(player)
	local client
	for _ = 1, 120 do
		client = Network.Bindable.Invoke("S_Client_Get", player)
		if client and client.data then
			break
		end
		task.wait(0.5)
		if not player.Parent then
			return
		end
	end
	if not client or not client.data then
		return
	end
	local data = client.data
	publish(player, data)
	-- equipping / unequipping / new titles update the chat right away
	data:Bind("titles", function()
		if player.Parent then
			publish(player, data)
		end
	end)
end

function ChatTitles._init()
	Network = _L.Get {"Common", "Library", "Network"}
	TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
end

function ChatTitles._start()
	Players.PlayerAdded:Connect(function(p)
		task.spawn(watch, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(watch, p)
	end
end

return ChatTitles
