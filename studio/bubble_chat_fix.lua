--[[
FruitBound — Bubble Chat final fix (Studio Command Bar script)

HOW TO RUN
  1. Open the place in Studio (Edit mode, NOT Play).
  2. View > Command Bar, paste this whole file, press Enter.
  3. Read the [BubbleChatFix] lines in Output. Every step prints OK / SKIP / FAIL.
  4. Ctrl+Z undoes all of it (one waypoint) if anything looks wrong.
  5. Save / publish yourself. This script never publishes.

WHAT IT CHANGES (and nothing else)
  1. TextChatService.ChatVersion = TextChatService
  2. TextChatService.BubbleChatConfiguration:
       - deletes the ImageLabel child ONLY if its Image is empty
       - deletes the UIGradient child ONLY if it is disabled
       - keeps UICorner
       - MaxDistance = 80 (every other bubble setting is left as is)
  3. ServerScriptService.Server.Scripts.server-main:
       removes the redundant legacy chat block that did
       WaitForChild("ChatServiceRunner") (infinite yield under TextChatService).
       Server ChatTitles already sets legacy speaker tags with a FindFirstChild guard.

NOT TOUCHED: NPCDialogue, ChatTitles (client/server), Titles data, CharacterBillboard,
moderation, any gameplay system.

Safe to run twice: already-applied steps print SKIP.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local TextChatService = game:GetService("TextChatService")
local ServerScriptService = game:GetService("ServerScriptService")

local TAG = "[BubbleChatFix]"
local failures = 0
local function ok(msg) print(TAG, "OK  ", msg) end
local function skip(msg) print(TAG, "SKIP", msg) end
local function fail(msg) failures += 1 warn(TAG, "FAIL", msg) end

local recording = ChangeHistoryService:TryBeginRecording("FruitBound Bubble Chat fix")

-- 1. Chat version -------------------------------------------------------------
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	skip("ChatVersion already TextChatService")
else
	local success, err = pcall(function()
		TextChatService.ChatVersion = Enum.ChatVersion.TextChatService
	end)
	if success and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		ok("ChatVersion -> TextChatService")
	else
		fail("could not set ChatVersion: " .. tostring(err))
	end
end

-- 2. BubbleChatConfiguration --------------------------------------------------
local bubble = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
if not bubble then
	fail("BubbleChatConfiguration not found under TextChatService")
else
	local image = bubble:FindFirstChildOfClass("ImageLabel")
	if not image then
		skip("no ImageLabel under BubbleChatConfiguration")
	elseif image.Image ~= "" then
		fail("ImageLabel has an Image set (" .. image.Image .. "), left in place - check it manually")
	else
		image:Destroy()
		ok("deleted empty ImageLabel")
	end

	local gradient = bubble:FindFirstChildOfClass("UIGradient")
	if not gradient then
		skip("no UIGradient under BubbleChatConfiguration")
	elseif gradient.Enabled then
		fail("UIGradient is ENABLED, left in place - check it manually")
	else
		gradient:Destroy()
		ok("deleted disabled UIGradient")
	end

	if bubble:FindFirstChildOfClass("UICorner") then
		ok("UICorner kept")
	else
		skip("no UICorner present (nothing to keep)")
	end

	if bubble.MaxDistance == 80 then
		skip("MaxDistance already 80")
	else
		local before = bubble.MaxDistance
		bubble.MaxDistance = 80
		ok("MaxDistance " .. tostring(before) .. " -> 80")
	end

	-- report the untouched settings so they can be compared with the audit
	print(TAG, "INFO", string.format(
		"Enabled=%s MaxBubbles=%s BubbleDuration=%s BubblesSpacing=%s MinimizeDistance=%s BackgroundTransparency=%s TailVisible=%s TextSize=%s VerticalStudsOffset=%s AdorneeName=%s",
		tostring(bubble.Enabled), tostring(bubble.MaxBubbles), tostring(bubble.BubbleDuration),
		tostring(bubble.BubblesSpacing), tostring(bubble.MinimizeDistance),
		tostring(bubble.BackgroundTransparency), tostring(bubble.TailVisible),
		tostring(bubble.TextSize), tostring(bubble.VerticalStudsOffset), tostring(bubble.AdorneeName)))
end

-- 3. server-main legacy chat block ---------------------------------------------
local START = 'task.spawn(function()\n\tlocal ChatService = require(Services.ServerScriptService:WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))'
local END = '\t\t\tspeaker:SetExtraData("Tags", nil)\n\t\tend)\n\tend)\nend)\n'
local REPLACEMENT = '-- Legacy chat speaker tags are handled by Server.Modules.Controllers.ChatTitles\n-- (FindFirstChild guard, no infinite WaitForChild under TextChatService).\n'

local scripts = ServerScriptService:FindFirstChild("Server")
scripts = scripts and scripts:FindFirstChild("Scripts")
local serverMain = scripts and scripts:FindFirstChild("server-main")
if not serverMain or not serverMain:IsA("Script") then
	fail("ServerScriptService.Server.Scripts.server-main not found")
else
	local source = serverMain.Source
	local s = string.find(source, START, 1, true)
	if not s then
		if string.find(source, "ChatServiceRunner", 1, true) then
			fail("server-main still mentions ChatServiceRunner but the block text differs - edit by hand")
		else
			skip("legacy ChatServiceRunner block already removed")
		end
	else
		local _, e = string.find(source, END, s, true)
		if not e then
			fail("found the block start but not its end - left unchanged, edit by hand")
		else
			local newSource = string.sub(source, 1, s - 1) .. REPLACEMENT .. string.sub(source, e + 1)
			local success, err = pcall(function()
				ScriptEditorService:UpdateSourceAsync(serverMain, function()
					return newSource
				end)
			end)
			if success and not string.find(serverMain.Source, "ChatServiceRunner", 1, true) then
				ok("removed legacy ChatServiceRunner block from server-main (" .. (e - s + 1) .. " chars)")
			else
				fail("could not update server-main: " .. tostring(err))
			end
		end
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

if failures == 0 then
	print(TAG, "DONE - all steps OK/SKIP. Now run the 2-player test (see studio/bubble_chat_test.md).")
else
	warn(TAG, "DONE WITH " .. failures .. " FAILURE(S) - read the FAIL lines above before saving.")
end
