-- Renders every player's equipped pets as floating orbs that follow them.
-- Purely visual and client-side; the server just publishes the
-- "EquippedPets" attribute. Swap `makePetModel` for real pet meshes later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local folder = Instance.new("Folder")
folder.Name = "PetVisuals"
folder.Parent = workspace

type Follower = { Player: Player, Parts: { BasePart }, Key: string? }
local followers: { [Player]: Follower } = {}

local function makePetModel(petType: string): BasePart
	local info = Config.PetTypes[petType]
	local rarity = Config.Rarities[info.Rarity]

	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.6, 1.6, 1.6) * (1 + (rarity.Order - 1) * 0.12)
	part.Color = rarity.Color
	part.Material = if rarity.Order >= 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 24)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.MaxDistance = 60
	billboard.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = rarity.Color
	text.Text = (petType:gsub("_", " "))
	text.TextStrokeTransparency = 0.3
	text.Parent = billboard

	part.Parent = folder
	return part
end

local function clear(follower: Follower)
	for _, part in follower.Parts do
		part:Destroy()
	end
	follower.Parts = {}
end

local function sync(player: Player)
	local follower = followers[player]
	if not follower then
		return
	end
	local key = player:GetAttribute("EquippedPets") or ""
	if key == follower.Key then
		return
	end
	follower.Key = key
	clear(follower)
	for petType in string.gmatch(key, "[^,]+") do
		if Config.PetTypes[petType] then
			table.insert(follower.Parts, makePetModel(petType))
		end
	end
end

local function track(player: Player)
	followers[player] = { Player = player, Parts = {}, Key = nil }
	sync(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		sync(player)
	end)
end

Players.PlayerAdded:Connect(track)
for _, player in Players:GetPlayers() do
	track(player)
end
Players.PlayerRemoving:Connect(function(player)
	local follower = followers[player]
	if follower then
		clear(follower)
		followers[player] = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local alpha = math.min(1, dt * 8)
	for player, follower in followers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local count = #follower.Parts
		for index, part in follower.Parts do
			local billboard = part:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard.Enabled = root ~= nil
			end
			if not root then
				part.Transparency = 1
				continue
			end
			part.Transparency = 0
			-- Arrange pets in an arc behind the player, bobbing up and down.
			local spread = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
			local angle = spread * math.rad(150)
			local offset = Vector3.new(math.sin(angle) * 5, 1 + math.sin(t * 3 + index) * 0.4, math.cos(angle) * 5)
			local target = root.CFrame * CFrame.new(offset)
			part.CFrame = part.CFrame:Lerp(CFrame.new(target.Position), alpha)
		end
	end
end)
