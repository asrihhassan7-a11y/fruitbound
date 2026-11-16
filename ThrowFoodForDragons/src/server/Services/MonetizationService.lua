-- Game passes + developer products with idempotent receipt processing.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Formulas = require(Shared.Formulas)
local Products = require(Shared.Config.Products)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local MonetizationService = {}
local productById: { [number]: string } = {}
local passById: { [number]: string } = {}

local function grantProduct(player: Player, key: string, profile): boolean
	local p = Products.DevProducts[key]
	if not p then
		return false
	end
	if p.kind == "boost" then
		local now = os.time()
		profile.Boosts[p.boost] = math.max(profile.Boosts[p.boost] or 0, now) + p.seconds
		PlayerService.notify(player, p.icon .. " " .. p.name .. " activated!", "purchase")
	elseif p.kind == "coins" then
		local coins = math.floor(Formulas.income(profile.MaxZone) * 60 * p.minutes)
		profile.Coins += coins
		profile.TotalCoins += coins
		PlayerService.notify(player, p.icon .. " +" .. Util.fmt(coins) .. " coins!", "purchase")
	else
		return false
	end
	PlayerService.sync(player)
	return true
end

local function processReceipt(receipt)
	local key = productById[receipt.ProductId]
	if not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = DataService.wait(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pid = receipt.PurchaseId
	if profile.Receipts[pid] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not grantProduct(player, key, profile) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Receipts[pid] = true
	table.insert(profile.ReceiptOrder, pid)
	while #profile.ReceiptOrder > 60 do
		profile.Receipts[table.remove(profile.ReceiptOrder, 1)] = nil
	end
	-- Only confirm once the grant + receipt are safely stored.
	if DataService.saveNow(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- kind = "pass" | "product"
function MonetizationService.prompt(player: Player, kind: any, key: any)
	if kind == "pass" then
		local p = Products.Passes[key]
		if not p then
			return false, "Unknown pass"
		end
		if p.id == 0 then
			return false, "This pass isn't on sale yet"
		end
		if PlayerService.hasPass(player, key) then
			return false, "You already own " .. p.name
		end
		MarketplaceService:PromptGamePassPurchase(player, p.id)
		return true
	elseif kind == "product" then
		local p = Products.DevProducts[key]
		if not p then
			return false, "Unknown product"
		end
		if p.id == 0 then
			return false, "This item isn't on sale yet"
		end
		MarketplaceService:PromptProductPurchase(player, p.id)
		return true
	end
	return false, "Invalid"
end

function MonetizationService.start()
	for key, p in Products.DevProducts do
		if p.id > 0 then
			productById[p.id] = key
		end
	end
	for key, p in Products.Passes do
		if p.id > 0 then
			passById[p.id] = key
		end
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		if purchased and key then
			PlayerService.grantPass(player, key)
			PlayerService.notify(player, Products.Passes[key].icon .. " " .. Products.Passes[key].name .. " unlocked! Thank you!", "purchase")
		end
	end)
end

return MonetizationService
