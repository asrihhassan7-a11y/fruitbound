--> Mastery menu
-- Shows mastery progress for Player, Powers, and Fruits.
-- Data is read from the client-side data replica using MasteryUtility.

local _L = _G._L

local Services
local Tracker
local Data
local Spr
local Audio
local Network
local UI
local NumberUtility
local MasteryUtility

local BLUE = Color3.fromRGB(100, 180, 255)
local GOLD = Color3.fromRGB(255, 200, 70)

local MasteryModule = {
	name = script.Name
}

function MasteryModule:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Network = _L.Get {"Common", "Library", "Network"}
	UI = _L.Get {"Client", "Modules", "UI"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	MasteryUtility = _L.Get {"Common", "Modules", "Utilities", "MasteryUtility"}

	self.is_open = Tracker.new(false)
end

function MasteryModule:_start()
	self.object = _L.PlayerGui:WaitForChild("Mastery")

	self.is_open:Bind(function(value)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)

	local data = Data.Await()
	if not data then
		return
	end
	self._data = data
	self._cards = {}

	-- Refresh when mastery data changes (cheap: at most every 0.5s)
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.delay(0.5, function()
			pending = false
			self:_refresh()
		end)
	end
	data:Bind("mastery", schedule)
	self:_refresh()
end

function MasteryModule:_refresh()
	local data = self._data
	if not data then
		return
	end

	local list = self.object.Main.List
	local template = self.object.CardTemplate
	local summary = MasteryUtility.getSummary(data)

	local order = 1
	local totalEntries = 0

	-- Helper to create or update a card
	local function updateCard(cardKey, info)
		local card = self._cards[cardKey]
		if not card then
			card = template:Clone()
			card.Name = cardKey
			card.Visible = true
			card.Parent = list
			self._cards[cardKey] = card
		end

		card.LayoutOrder = order
		order += 1
		totalEntries += 1

		-- Icon
		card.IconBg.Icon.Text = info.icon or "🎯"

		-- Name
		card.EntryName.Text = info.name

		-- Level badge
		card.LevelBadge.LevelText.Text = "Lv. " .. info.level
		if info.is_max then
			card.LevelBadge.BackgroundColor3 = GOLD
		else
			card.LevelBadge.BackgroundColor3 = BLUE
		end

		-- XP bar
		card.Bar.Fill.Size = UDim2.fromScale(math.clamp(info.progress, 0, 1), 1)
		card.Bar.Fill.Visible = info.progress > 0
		if info.is_max then
			card.Bar.Text.Text = "MAX LEVEL"
		else
			card.Bar.Text.Text = NumberUtility.commas(math.floor(info.xp)) .. " / " .. NumberUtility.commas(info.xp_needed) .. " XP"
		end

		-- Description (active bonuses)
		card.Description.Text = info.bonuses or "No bonuses yet"

		-- Milestone (next milestone info)
		if info.is_max then
			card.Milestone.Text = "\u{2605} Mastered!"
		elseif info.next_milestone_level then
			card.Milestone.Text = "Next: Lv. " .. info.next_milestone_level .. " \u{2013} " .. (info.next_milestone_desc or "")
		else
			card.Milestone.Text = ""
		end
	end

	-- Player Mastery (always shown first)
	do
		local p = summary.player
		if p then
			local totalStr = 0
			for _, m in pairs(p.active_milestones or {}) do
				if m.type == "strength_mult" then
					totalStr += m.value
				end
			end
			local bonuses = totalStr > 0
				and string.format("+%d%% All Strength", math.floor(totalStr * 100))
				or "No bonuses yet"

			updateCard("player", {
				icon = "\u{1F451}",
				name = "Player Mastery",
				level = p.level,
				is_max = p.is_max,
				progress = p.progress,
				xp = p.xp,
				xp_needed = p.xp_needed,
				bonuses = bonuses,
				next_milestone_level = p.next_milestone_level,
				next_milestone_desc = p.next_milestone_desc,
			})
		end
	end

	-- Power Mastery (per component)
	for component, p in pairs(summary.powers or {}) do
		local totalStr = 0
		for _, m in pairs(MasteryUtility.getActiveMilestones("power", p.level)) do
			if m.type == "strength_mult" then
				totalStr += m.value
			end
		end
		local bonuses = totalStr > 0
			and string.format("+%d%% Harvest Power", math.floor(totalStr * 100))
			or "No bonuses yet"

		updateCard("power_" .. component, {
			icon = "\u{1F4AA}",
			name = component .. " Mastery",
			level = p.level,
			is_max = p.is_max,
			progress = p.progress,
			xp = p.xp,
			xp_needed = p.xp_needed,
			bonuses = bonuses,
			next_milestone_level = p.next_milestone_level,
			next_milestone_desc = p.next_milestone_desc,
		})
	end

	-- Fruit Mastery (per fruit name)
	for fruitName, p in pairs(summary.fruits or {}) do
		local totalVal = 0
		local totalMut = 0
		for _, m in pairs(MasteryUtility.getActiveMilestones("fruit", p.level)) do
			if m.type == "value_mult" then
				totalVal += m.value
			elseif m.type == "mutation_chance" then
				totalMut += m.value
			end
		end
		local parts = {}
		if totalVal > 0 then
			table.insert(parts, string.format("+%d%% Value", math.floor(totalVal * 100)))
		end
		if totalMut > 0 then
			table.insert(parts, string.format("+%d%% Mutation", math.floor(totalMut * 100)))
		end
		local bonuses = #parts > 0 and table.concat(parts, ", ") or "No bonuses yet"

		updateCard("fruit_" .. fruitName, {
			icon = "\u{1F34E}",
			name = fruitName .. " Mastery",
			level = p.level,
			is_max = p.is_max,
			progress = p.progress,
			xp = p.xp,
			xp_needed = p.xp_needed,
			bonuses = bonuses,
			next_milestone_level = p.next_milestone_level,
			next_milestone_desc = p.next_milestone_desc,
		})
	end

	-- Update counter
	self.object.Main.Header.Counter.Text = totalEntries .. " mastery entries"
end

function MasteryModule:Open()
	local main = self.object.Main
	self:_refresh()
	Spr.Stop(main)
	main.Visible = true
	main.Position = UDim2.fromScale(0.5, 0.56)
	Spr.Target(main, 1, 4, {Position = UDim2.fromScale(0.5, 0.5)})
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 80})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 20})
	end
end

function MasteryModule:Close()
	self.object.Main.Visible = false
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {FieldOfView = 70})
	if Services.Lighting:FindFirstChild("Blur") then
		Spr.Target(Services.Lighting.Blur, 0.7, 4, {Size = 0})
	end
end

return MasteryModule