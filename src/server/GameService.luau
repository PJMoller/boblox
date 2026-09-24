-- Core gameplay: clicking, upgrades, rebirths, eggs, pets and daily rewards.
-- The server is authoritative; clients only send requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)

local GameService = {}

local rng = Random.new()
local remotes: Folder
local dirty: { [Player]: boolean } = {}
local clickTokens: { [Player]: number } = {}

local function remote(className: string, name: string)
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = remotes
	return instance
end

-- Game pass ownership is stored as player attributes ("Pass_VIP" = true) by
-- MonetizationService, which also lets the client read it.
function GameService.hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function GameService.serverLuckActive(): boolean
	return (workspace:GetAttribute("ServerLuckUntil") or 0) > os.time()
end

function GameService.getLuck(player: Player): number
	local luck = 1
	if GameService.hasPass(player, "LuckyEggs") then
		luck *= 3
	end
	if GameService.hasPass(player, "VIP") then
		luck *= 1.25
	end
	if GameService.serverLuckActive() then
		luck *= 2
	end
	return luck
end

function GameService.getPetBoost(data): number
	local boost = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			boost += Config.PetTypes[pet.Type].Boost
		end
	end
	return boost
end

function GameService.getMultiplier(player: Player, data): number
	local mult = 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth
	mult *= 1 + GameService.getPetBoost(data)
	if GameService.hasPass(player, "DoubleCoins") then
		mult *= 2
	end
	if GameService.hasPass(player, "VIP") then
		mult *= 1.5
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		mult *= Config.PremiumBonus
	end
	return mult
end

function GameService.getClickValue(player: Player, data): number
	return (1 + data.Upgrades.ClickPower) * GameService.getMultiplier(player, data)
end

function GameService.getPassiveIncome(player: Player, data): number
	local income = data.Upgrades.AutoCoins * GameService.getMultiplier(player, data)
	if GameService.hasPass(player, "AutoClicker") then
		income += Config.AutoClicksPerSecond * GameService.getClickValue(player, data)
	end
	return income
end

function GameService.getMaxEquipped(player: Player): number
	local slots = Config.Pets.BaseEquipSlots
	if GameService.hasPass(player, "MorePets") then
		slots += Config.Pets.ExtraSlotsFromPass
	end
	return slots
end

function GameService.markDirty(player: Player)
	dirty[player] = true
end

function GameService.notify(player: Player?, text: string, color: Color3?)
	local event = remotes:FindFirstChild("Notify") :: RemoteEvent
	if player then
		event:FireClient(player, text, color)
	else
		event:FireAllClients(text, color)
	end
end

function GameService.addCoins(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	data.Coins += amount
	data.TotalCoins += amount
	GameService.markDirty(player)
end

local function spend(data, amount: number): boolean
	if data.Coins < amount then
		return false
	end
	data.Coins -= amount
	return true
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	leaderstats.Coins.Value = Format.number(data.Coins)
	leaderstats.Rebirths.Value = data.Rebirths
end

-- Other players' clients render our equipped pets from this attribute.
local function updateEquippedAttribute(player: Player, data)
	local names = {}
	for _, pet in data.Pets do
		if pet.Equipped then
			table.insert(names, pet.Type)
		end
	end
	player:SetAttribute("EquippedPets", table.concat(names, ","))
end

local function buildState(player: Player, data)
	local passes = {}
	for key in Config.GamePasses do
		passes[key] = GameService.hasPass(player, key)
	end
	return {
		Coins = data.Coins,
		TotalCoins = data.TotalCoins,
		Rebirths = data.Rebirths,
		Upgrades = data.Upgrades,
		Pets = data.Pets,
		MaxEquipped = GameService.getMaxEquipped(player),
		Multiplier = GameService.getMultiplier(player, data),
		ClickValue = GameService.getClickValue(player, data),
		PassiveIncome = GameService.getPassiveIncome(player, data),
		RebirthCost = Config.rebirthCost(data.Rebirths),
		Luck = GameService.getLuck(player),
		Passes = passes,
		DailyStreak = data.DailyStreak,
		DailyReadyAt = data.LastDaily + Config.Daily.CooldownHours * 3600,
		DailyReward = GameService.dailyReward(player, data),
		ServerTime = os.time(),
	}
end

function GameService.flush(player: Player)
	dirty[player] = nil
	local data = DataService.get(player)
	if not data then
		return
	end
	updateLeaderstats(player, data)
	updateEquippedAttribute(player, data)
	;(remotes:FindFirstChild("State") :: RemoteEvent):FireClient(player, buildState(player, data))
end

-- Rebirth ----------------------------------------------------------------

function GameService.rebirth(player: Player, free: boolean): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Data not loaded"
	end
	if not free and not spend(data, Config.rebirthCost(data.Rebirths)) then
		return false, "Not enough coins to rebirth"
	end
	data.Rebirths += 1
	data.Coins = 0
	for key in data.Upgrades do
		data.Upgrades[key] = 0
	end
	GameService.markDirty(player)
	local mult = 1 + data.Rebirths * Config.Rebirth.MultiplierPerRebirth
	return true, string.format("Rebirth %d! Base multiplier is now x%s", data.Rebirths, Format.number(mult))
end

-- Pets -------------------------------------------------------------------

local function rollPet(egg, luck: number): string
	local chances = Config.eggChances(egg, luck)
	local roll = rng:NextNumber()
	for i, entry in egg.Pets do
		roll -= chances[i]
		if roll <= 0 then
			return entry.Pet
		end
	end
	return egg.Pets[#egg.Pets].Pet
end

local function findPet(data, id: number)
	for index, pet in data.Pets do
		if pet.Id == id then
			return pet, index
		end
	end
	return nil, nil
end

local function countEquipped(data): number
	local count = 0
	for _, pet in data.Pets do
		if pet.Equipped then
			count += 1
		end
	end
	return count
end

local function equipBest(player: Player, data)
	local sorted = table.clone(data.Pets)
	table.sort(sorted, function(a, b)
		return Config.PetTypes[a.Type].Boost > Config.PetTypes[b.Type].Boost
	end)
	local slots = GameService.getMaxEquipped(player)
	for index, pet in sorted do
		pet.Equipped = index <= slots
	end
end

local function hatch(player: Player, data, eggKey: string, count: number)
	local egg = Config.getEgg(eggKey)
	if not egg then
		return false, "Unknown egg"
	end
	if count ~= 1 and count ~= 3 then
		return false, "Invalid amount"
	end
	if count == 3 and not GameService.hasPass(player, "TripleHatch") then
		return false, "Requires the Triple Hatch pass"
	end
	if #data.Pets + count > Config.Pets.MaxInventory then
		return false, "Your pet inventory is full - delete some pets"
	end
	if not spend(data, egg.Cost * count) then
		return false, "Not enough coins"
	end

	local luck = GameService.getLuck(player)
	local hatched = {}
	local hadFreeSlot = countEquipped(data) < GameService.getMaxEquipped(player)
	for _ = 1, count do
		local petType = rollPet(egg, luck)
		table.insert(data.Pets, { Id = data.NextPetId, Type = petType, Equipped = false })
		data.NextPetId += 1
		data.EggsHatched += 1
		table.insert(hatched, petType)

		local rarity = Config.PetTypes[petType].Rarity
		if Config.Rarities[rarity].Order >= Config.Rarities.Legendary.Order then
			GameService.notify(
				nil,
				string.format("%s hatched a %s %s!", player.DisplayName, rarity, (petType:gsub("_", " "))),
				Config.Rarities[rarity].Color
			)
		end
	end
	-- New players shouldn't have to discover the pets menu to get their boost.
	if hadFreeSlot then
		equipBest(player, data)
	end
	GameService.markDirty(player)
	return true, hatched
end

-- Daily reward -----------------------------------------------------------

function GameService.dailyReward(player: Player, data): number
	local nextStreak = GameService.nextDailyStreak(data)
	local base = math.max(Config.Daily.BaseReward, GameService.getPassiveIncome(player, data) * Config.Daily.IncomeSeconds)
	base = math.max(base, GameService.getClickValue(player, data) * Config.EstimatedClicksPerSecond * Config.Daily.IncomeSeconds)
	return math.floor(base * nextStreak)
end

function GameService.nextDailyStreak(data): number
	local elapsed = os.time() - data.LastDaily
	if data.LastDaily == 0 or elapsed > Config.Daily.StreakResetHours * 3600 then
		return 1
	end
	return math.min(data.DailyStreak + 1, Config.Daily.MaxStreak)
end

local function claimDaily(player: Player, data)
	if os.time() - data.LastDaily < Config.Daily.CooldownHours * 3600 then
		return false, "Come back later for your next reward"
	end
	local reward = GameService.dailyReward(player, data)
	data.DailyStreak = GameService.nextDailyStreak(data)
	data.LastDaily = os.time()
	GameService.addCoins(player, reward)
	return true, string.format("Day %d reward: +%s coins!", data.DailyStreak, Format.number(reward))
end

-- Client actions ---------------------------------------------------------

local actions = {}

function actions.BuyUpgrade(player: Player, data, key: any)
	local upgrade = if type(key) == "string" then Config.Upgrades[key] else nil
	if not upgrade then
		return false, "Unknown upgrade"
	end
	local level = data.Upgrades[key]
	if level >= upgrade.MaxLevel then
		return false, "Max level reached"
	end
	if not spend(data, Config.upgradeCost(key, level)) then
		return false, "Not enough coins"
	end
	data.Upgrades[key] = level + 1
	GameService.markDirty(player)
	return true
end

function actions.Rebirth(player: Player)
	return GameService.rebirth(player, false)
end

function actions.Hatch(player: Player, data, eggKey: any, count: any)
	if type(eggKey) ~= "string" or type(count) ~= "number" then
		return false, "Invalid request"
	end
	return hatch(player, data, eggKey, count)
end

function actions.ToggleEquip(player: Player, data, id: any)
	local pet = if type(id) == "number" then findPet(data, id) else nil
	if not pet then
		return false, "Pet not found"
	end
	if not pet.Equipped and countEquipped(data) >= GameService.getMaxEquipped(player) then
		return false, "All pet slots are full"
	end
	pet.Equipped = not pet.Equipped
	GameService.markDirty(player)
	return true
end

function actions.DeletePet(player: Player, data, id: any)
	local pet, index = nil, nil
	if type(id) == "number" then
		pet, index = findPet(data, id)
	end
	if not pet then
		return false, "Pet not found"
	end
	table.remove(data.Pets, index)
	GameService.markDirty(player)
	return true
end

function actions.EquipBest(player: Player, data)
	equipBest(player, data)
	GameService.markDirty(player)
	return true
end

function actions.ClaimDaily(player: Player, data)
	return claimDaily(player, data)
end

-- Setup ------------------------------------------------------------------

local function setupPlayer(player: Player, data)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = leaderstats
	leaderstats.Parent = player

	-- Old saves may have more equipped pets than they now have slots for.
	if countEquipped(data) > GameService.getMaxEquipped(player) then
		equipBest(player, data)
	end
	clickTokens[player] = Config.MaxClicksPerSecond
	GameService.flush(player)
end

function GameService.start()
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remote("RemoteEvent", "State")
	remote("RemoteEvent", "Notify")
	local clickRemote = remote("RemoteEvent", "Click") :: RemoteEvent
	local requestStateRemote = remote("RemoteEvent", "RequestState") :: RemoteEvent
	local actionRemote = remote("RemoteFunction", "Action") :: RemoteFunction
	remotes.Parent = ReplicatedStorage

	DataService.onLoaded(setupPlayer)

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		clickTokens[player] = nil
	end)

	clickRemote.OnServerEvent:Connect(function(player)
		local data = DataService.get(player)
		local tokens = clickTokens[player]
		if not data or not tokens or tokens < 1 then
			return
		end
		clickTokens[player] = tokens - 1
		data.Clicks += 1
		GameService.addCoins(player, GameService.getClickValue(player, data))
	end)

	requestStateRemote.OnServerEvent:Connect(function(player)
		GameService.markDirty(player)
	end)

	actionRemote.OnServerInvoke = function(player, actionName, ...)
		local data = DataService.get(player)
		local handler = if type(actionName) == "string" then actions[actionName] else nil
		if not data or not handler then
			return false, "Invalid action"
		end
		return handler(player, data, ...)
	end

	-- Refill click budgets; push state changes at 10Hz instead of per click.
	local sinceFlush = 0
	RunService.Heartbeat:Connect(function(dt)
		for player, tokens in clickTokens do
			clickTokens[player] = math.min(Config.MaxClicksPerSecond, tokens + Config.MaxClicksPerSecond * dt)
		end
		sinceFlush += dt
		if sinceFlush >= 0.1 then
			sinceFlush = 0
			for player in dirty do
				GameService.flush(player)
			end
		end
	end)

	-- Passive income (Coin Generator upgrade + Auto Clicker pass).
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService.get(player)
				if data then
					local income = GameService.getPassiveIncome(player, data)
					if income > 0 then
						GameService.addCoins(player, income)
					end
				end
			end
		end
	end)
end

return GameService
