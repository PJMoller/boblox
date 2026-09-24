-- Loads, caches and saves player data with DataStoreService.
-- Loading failures kick the player instead of handing them a blank save,
-- so a DataStore outage can never wipe someone's progress.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 5

local DataService = {}

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [Player]: { Data: any, CanSave: boolean } } = {}
local loadedCallbacks: { (Player, any) -> () } = {}

local function template()
	return {
		Coins = 0,
		TotalCoins = 0,
		Clicks = 0,
		Rebirths = 0,
		Upgrades = { ClickPower = 0, AutoCoins = 0 },
		Pets = {},
		NextPetId = 1,
		EggsHatched = 0,
		DailyStreak = 0,
		LastDaily = 0,
		PurchaseHistory = {},
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill in fields added after the player's save was first created.
local function reconcile(data, defaults)
	for key, default in defaults do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
end

local function withRetries(fn: () -> any): (boolean, any)
	local ok, result
	for attempt = 1, MAX_RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < MAX_RETRIES then
			task.wait(2 ^ attempt)
		end
	end
	return false, result
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function onPlayerAdded(player: Player)
	local ok, stored = withRetries(function()
		return store:GetAsync(keyFor(player))
	end)

	if not player.Parent then
		return -- left while loading
	end

	local canSave = true
	if not ok then
		if RunService:IsStudio() then
			-- Usually "Enable Studio Access to API Services" is off. Let testing continue.
			warn("[DataService] Could not load data in Studio, using a temporary save:", stored)
			stored = nil
			canSave = false
		else
			player:Kick("Roblox data servers are having trouble. Please rejoin in a minute - your progress is safe!")
			return
		end
	end

	local data = if type(stored) == "table" then stored else template()
	reconcile(data, template())

	profiles[player] = { Data = data, CanSave = canSave }
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

function DataService.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.CanSave then
		return false
	end
	local ok, err = withRetries(function()
		return store:UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
	if not ok then
		warn("[DataService] Failed to save", player.Name, err)
	end
	return ok
end

function DataService.get(player: Player)
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataService.onLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
