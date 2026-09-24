-- Central tuning file: prices, pets, eggs and your Roblox monetization IDs.
-- Almost all balancing can be done from here without touching game code.

local Config = {}

-- Game passes: one-time Robux purchases. Create each one in
-- Creator Dashboard > (your experience) > Monetization > Passes, then paste
-- its numeric ID into `Id`. `Price` is only a fallback label; the real price
-- is read from Roblox at runtime. Id = 0 means "not set up yet".
Config.GamePasses = {
	DoubleCoins = {
		Id = 0,
		Name = "2x Coins",
		Description = "Double ALL coins you earn, forever!",
		Price = 199,
		Order = 1,
	},
	AutoClicker = {
		Id = 0,
		Name = "Auto Clicker",
		Description = "Clicks for you 5 times per second, even while AFK.",
		Price = 149,
		Order = 2,
	},
	TripleHatch = {
		Id = 0,
		Name = "Triple Hatch",
		Description = "Hatch 3 eggs at once.",
		Price = 179,
		Order = 3,
	},
	LuckyEggs = {
		Id = 0,
		Name = "Lucky Eggs",
		Description = "3x chance for Epic, Legendary & Mythic pets.",
		Price = 249,
		Order = 4,
	},
	MorePets = {
		Id = 0,
		Name = "+3 Pet Slots",
		Description = "Equip 3 more pets at the same time.",
		Price = 299,
		Order = 5,
	},
	VIP = {
		Id = 0,
		Name = "VIP",
		Description = "+50% coins, +25% luck and a golden [VIP] chat tag.",
		Price = 399,
		Order = 6,
	},
}

-- Developer products: consumable purchases that can be bought many times.
-- Create them under Monetization > Developer Products and paste the IDs.
-- Kind:
--   "Coins"      grants `Minutes` worth of the buyer's current income (min `Min`)
--   "Rebirth"    instantly rebirths without paying the coin cost
--   "ServerLuck" gives EVERYONE in the server 2x luck for `Seconds`
Config.DevProducts = {
	{ Key = "CoinsSmall", Id = 0, Name = "Bag of Coins", Kind = "Coins", Minutes = 10, Min = 5_000, Price = 25 },
	{ Key = "CoinsMedium", Id = 0, Name = "Chest of Coins", Kind = "Coins", Minutes = 60, Min = 50_000, Price = 99 },
	{ Key = "CoinsLarge", Id = 0, Name = "Vault of Coins", Kind = "Coins", Minutes = 360, Min = 500_000, Price = 399 },
	{ Key = "SkipRebirth", Id = 0, Name = "Instant Rebirth", Kind = "Rebirth", Price = 49 },
	{ Key = "ServerLuck", Id = 0, Name = "2x Server Luck (15 min)", Kind = "ServerLuck", Seconds = 900, Price = 99 },
}

-- Estimated clicks per second of an active player, used to size coin packs.
Config.EstimatedClicksPerSecond = 5

Config.MaxClicksPerSecond = 15 -- server-side anti auto-clicker limit
Config.AutoClicksPerSecond = 5 -- clicks granted by the Auto Clicker pass
Config.PremiumBonus = 1.1 -- Roblox Premium members earn +10% (also boosts Premium Payouts)

Config.Upgrades = {
	ClickPower = {
		Name = "Click Power",
		Description = "+1 coin per click",
		BaseCost = 15,
		CostGrowth = 1.15,
		MaxLevel = 1000,
		Order = 1,
	},
	AutoCoins = {
		Name = "Coin Generator",
		Description = "+1 coin every second",
		BaseCost = 100,
		CostGrowth = 1.17,
		MaxLevel = 1000,
		Order = 2,
	},
}

Config.Rebirth = {
	BaseCost = 10_000,
	CostGrowth = 3,
	MultiplierPerRebirth = 0.5, -- each rebirth adds +50% to all coin gains
}

Config.Daily = {
	CooldownHours = 20,
	StreakResetHours = 48,
	MaxStreak = 7,
	BaseReward = 1_000,
	IncomeSeconds = 300, -- reward is also at least 5 minutes of income * streak
}

Config.Pets = {
	MaxInventory = 60,
	BaseEquipSlots = 3,
	ExtraSlotsFromPass = 3,
}

-- Lucky rarities are boosted by luck multipliers (passes, server luck).
Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(200, 200, 200), Lucky = false },
	Uncommon = { Order = 2, Color = Color3.fromRGB(90, 220, 110), Lucky = false },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 150, 255), Lucky = false },
	Epic = { Order = 4, Color = Color3.fromRGB(180, 90, 255), Lucky = true },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 190, 40), Lucky = true },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 70, 110), Lucky = true },
}

-- Boost is additive: equipping pets with 0.25 and 0.5 gives x1.75 coins.
Config.PetTypes = {
	Dog = { Rarity = "Common", Boost = 0.1 },
	Cat = { Rarity = "Common", Boost = 0.12 },
	Bunny = { Rarity = "Uncommon", Boost = 0.2 },
	Fox = { Rarity = "Rare", Boost = 0.35 },
	Owl = { Rarity = "Epic", Boost = 0.6 },

	Monkey = { Rarity = "Uncommon", Boost = 0.5 },
	Tiger = { Rarity = "Rare", Boost = 0.9 },
	Parrot = { Rarity = "Rare", Boost = 1.1 },
	Panda = { Rarity = "Epic", Boost = 1.8 },
	Dragon = { Rarity = "Legendary", Boost = 3.5 },

	Alien = { Rarity = "Rare", Boost = 3 },
	Robot = { Rarity = "Epic", Boost = 5 },
	Phoenix = { Rarity = "Legendary", Boost = 10 },
	Galaxy_Cat = { Rarity = "Mythic", Boost = 25 },
}

Config.Eggs = {
	{
		Key = "Basic",
		Name = "Basic Egg",
		Cost = 250,
		Pets = {
			{ Pet = "Dog", Weight = 45 },
			{ Pet = "Cat", Weight = 35 },
			{ Pet = "Bunny", Weight = 15 },
			{ Pet = "Fox", Weight = 4.5 },
			{ Pet = "Owl", Weight = 0.5 },
		},
	},
	{
		Key = "Jungle",
		Name = "Jungle Egg",
		Cost = 25_000,
		Pets = {
			{ Pet = "Monkey", Weight = 50 },
			{ Pet = "Tiger", Weight = 30 },
			{ Pet = "Parrot", Weight = 15 },
			{ Pet = "Panda", Weight = 4.8 },
			{ Pet = "Dragon", Weight = 0.2 },
		},
	},
	{
		Key = "Cosmic",
		Name = "Cosmic Egg",
		Cost = 5_000_000,
		Pets = {
			{ Pet = "Alien", Weight = 60 },
			{ Pet = "Robot", Weight = 32 },
			{ Pet = "Phoenix", Weight = 7.9 },
			{ Pet = "Galaxy_Cat", Weight = 0.1 },
		},
	},
}

function Config.getEgg(key: string)
	for _, egg in Config.Eggs do
		if egg.Key == key then
			return egg
		end
	end
	return nil
end

function Config.getProductByKey(key: string)
	for _, product in Config.DevProducts do
		if product.Key == key then
			return product
		end
	end
	return nil
end

function Config.getProductById(id: number)
	if id == 0 then
		return nil
	end
	for _, product in Config.DevProducts do
		if product.Id == id then
			return product
		end
	end
	return nil
end

function Config.upgradeCost(key: string, level: number): number
	local upgrade = Config.Upgrades[key]
	return math.floor(upgrade.BaseCost * upgrade.CostGrowth ^ level)
end

function Config.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

-- Per-pet hatch chances for an egg, as fractions of 1, after applying luck.
function Config.eggChances(egg, luck: number): { number }
	local weights = {}
	local total = 0
	for i, entry in egg.Pets do
		local rarity = Config.PetTypes[entry.Pet].Rarity
		local weight = entry.Weight
		if Config.Rarities[rarity].Lucky then
			weight *= luck
		end
		weights[i] = weight
		total += weight
	end
	for i, weight in weights do
		weights[i] = weight / total
	end
	return weights
end

return Config
