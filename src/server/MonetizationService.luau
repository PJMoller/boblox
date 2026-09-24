-- Game pass ownership and developer product receipts.
-- ProcessReceipt only reports PurchaseGranted after the reward is saved,
-- so Roblox retries (instead of charging for nothing) if something fails.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local GameService = require(script.Parent.GameService)

local MAX_PURCHASE_HISTORY = 100

local MonetizationService = {}

local function passKeyFromId(id: number): string?
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 and pass.Id == id then
			return key
		end
	end
	return nil
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
	GameService.markDirty(player)
end

local function loadPasses(player: Player)
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
				if ok and owns and player.Parent then
					grantPass(player, key)
				elseif not ok then
					warn("[Monetization] Could not check pass", key, owns)
				end
			end)
		end
	end
end

local productHandlers = {}

function productHandlers.Coins(player: Player, data, product)
	local perSecond = GameService.getPassiveIncome(player, data)
		+ GameService.getClickValue(player, data) * Config.EstimatedClicksPerSecond
	local amount = math.max(product.Min, math.floor(perSecond * 60 * product.Minutes))
	GameService.addCoins(player, amount)
	GameService.notify(player, "+" .. Format.number(amount) .. " coins! Thank you!", Color3.fromRGB(255, 215, 0))
	return true
end

function productHandlers.Rebirth(player: Player)
	local ok, message = GameService.rebirth(player, true)
	if ok and message then
		GameService.notify(player, message, Color3.fromRGB(120, 200, 255))
	end
	return ok
end

function productHandlers.ServerLuck(player: Player, _data, product)
	local now = os.time()
	local current = math.max(workspace:GetAttribute("ServerLuckUntil") or 0, now)
	workspace:SetAttribute("ServerLuckUntil", current + product.Seconds)
	GameService.notify(
		nil,
		player.DisplayName .. " activated 2x SERVER LUCK for everyone! Go hatch eggs!",
		Color3.fromRGB(80, 255, 140)
	)
	for _, other in Players:GetPlayers() do
		GameService.markDirty(other)
	end
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = receipt.PurchaseId
	if table.find(data.PurchaseHistory, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local product = Config.getProductById(receipt.ProductId)
	if not product then
		warn("[Monetization] Unknown product id", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(productHandlers[product.Kind], player, data, product)
	if not ok or not granted then
		warn("[Monetization] Failed to grant", product.Key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(data.PurchaseHistory, purchaseId)
	while #data.PurchaseHistory > MAX_PURCHASE_HISTORY do
		table.remove(data.PurchaseHistory, 1)
	end

	if not DataService.save(player) then
		-- The reward stays in memory and the receipt is recorded, so the retry
		-- won't double-grant this session; if the server dies both are lost.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.start()
	for key, pass in Config.GamePasses do
		if pass.Id == 0 then
			warn("[Monetization] Game pass '" .. key .. "' has no Id set in Config.luau")
		end
	end
	for _, product in Config.DevProducts do
		if product.Id == 0 then
			warn("[Monetization] Developer product '" .. product.Key .. "' has no Id set in Config.luau")
		end
	end

	DataService.onLoaded(function(player)
		loadPasses(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyFromId(passId)
		if purchased and key then
			grantPass(player, key)
			GameService.notify(player, "Unlocked " .. Config.GamePasses[key].Name .. "! Thank you!", Color3.fromRGB(255, 215, 0))
			GameService.notify(nil, player.DisplayName .. " just bought " .. Config.GamePasses[key].Name .. "!")
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
