-- Sound effects + music, routed through SoundGroups so settings can control volume.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = require(ReplicatedStorage:WaitForChild("TFFD").Config.Sounds)

local Audio = {}
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "TFFD_SFX"
sfxGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "TFFD_Music"
musicGroup.Parent = SoundService

local cache: { [string]: Sound } = {}
local lastPlay: { [string]: number } = {}

function Audio.play(name: string, pitch: number?)
	local cfg = Sounds[name]
	if not cfg or cfg.id == "" then
		return
	end
	local now = os.clock()
	if now - (lastPlay[name] or 0) < 0.05 then
		return -- avoid stacking the same sound in one frame
	end
	lastPlay[name] = now
	local base = cache[name]
	if not base then
		base = Instance.new("Sound")
		base.SoundId = cfg.id
		base.Volume = cfg.volume
		base.SoundGroup = sfxGroup
		base.Parent = SoundService
		cache[name] = base
	end
	local s = base:Clone()
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(6, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

function Audio.applySettings(settings)
	sfxGroup.Volume = settings.Sfx or 0.8
	musicGroup.Volume = settings.Music or 0.5
end

function Audio.start()
	local m = Sounds.Music
	if m and m.id ~= "" then
		local music = Instance.new("Sound")
		music.SoundId = m.id
		music.Volume = m.volume
		music.Looped = true
		music.SoundGroup = musicGroup
		music.Parent = SoundService
		music:Play()
	end
end

return Audio
