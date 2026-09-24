-- All player-facing UI, built in code so the whole game lives in this repo.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClickRemote = Remotes:WaitForChild("Click") :: RemoteEvent
local StateRemote = Remotes:WaitForChild("State") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent
local RequestStateRemote = Remotes:WaitForChild("RequestState") :: RemoteEvent
local ActionRemote = Remotes:WaitForChild("Action") :: RemoteFunction

local player = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()

local COLORS = {
	Panel = Color3.fromRGB(30, 34, 48),
	Row = Color3.fromRGB(44, 50, 70),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(180, 190, 215),
	Green = Color3.fromRGB(60, 200, 100),
	Gold = Color3.fromRGB(255, 190, 40),
	Blue = Color3.fromRGB(70, 140, 255),
	Red = Color3.fromRGB(230, 70, 80),
	Purple = Color3.fromRGB(160, 90, 255),
	Disabled = Color3.fromRGB(90, 95, 110),
}

local state = nil -- latest snapshot from the server
local refreshers: { () -> () } = {}

-- Helpers ----------------------------------------------------------------

local function make(className: string, props: { [string]: any }, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(thickness: number?)
	return make("UIStroke", { Thickness = thickness or 2, Color = Color3.new(0, 0, 0), Transparency = 0.4 })
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return make("TextLabel", props, { make("UIStroke", { Thickness = 1.5, Transparency = 0.3 }) })
end

local function button(props, onClick: () -> ())
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or COLORS.Text
	props.TextScaled = true
	props.AutoButtonColor = true
	local btn = make("TextButton", props, {
		corner(8),
		make("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	}) :: TextButton
	btn.Activated:Connect(onClick)
	return btn
end

local function setEnabled(btn: TextButton, enabled: boolean, color: Color3)
	btn.BackgroundColor3 = if enabled then color else COLORS.Disabled
	btn.AutoButtonColor = enabled
end

local function prettyName(name: string): string
	return (name:gsub("_", " "))
end

-- Screen -----------------------------------------------------------------

local gui = make("ScreenGui", {
	Name = "GameUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Toasts (top-right) -----------------------------------------------------

local toastHolder = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 60),
	Size = UDim2.new(0, 340, 0.6, 0),
	Parent = gui,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
})

local function toast(text: string, color: Color3?)
	local frame = make("Frame", {
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = toastHolder,
	}, {
		corner(8),
		make("UIStroke", { Color = color or COLORS.Blue, Thickness = 2 }),
	})
	label({
		Text = text,
		TextColor3 = color or COLORS.Text,
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.new(0, 8, 0, 5),
		Parent = frame,
	})
	task.delay(4, function()
		frame:Destroy()
	end)
end

NotifyRemote.OnClientEvent:Connect(toast)

local function act(actionName: string, ...): (boolean, any)
	local ok, success, result = pcall(ActionRemote.InvokeServer, ActionRemote, actionName, ...)
	if not ok then
		toast("Something went wrong, try again", COLORS.Red)
		return false, nil
	end
	if not success and type(result) == "string" then
		toast(result, COLORS.Red)
	elseif success and type(result) == "string" then
		toast(result, COLORS.Green)
	end
	return success, result
end

-- Top bar ----------------------------------------------------------------

local topBar = make("Frame", {
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(0, 420, 0, 84),
	Parent = gui,
}, { corner(14), stroke() })

local coinsLabel = label({
	Text = "0",
	TextColor3 = COLORS.Gold,
	Size = UDim2.new(1, -20, 0, 46),
	Position = UDim2.new(0, 10, 0, 4),
	Parent = topBar,
})

local statsLabel = label({
	Text = "",
	TextColor3 = COLORS.SubText,
	Size = UDim2.new(1, -20, 0, 24),
	Position = UDim2.new(0, 10, 0, 52),
	Parent = topBar,
})

local luckLabel = label({
	Text = "",
	TextColor3 = Color3.fromRGB(80, 255, 140),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 98),
	Size = UDim2.new(0, 360, 0, 28),
	Visible = false,
	Parent = gui,
})

-- Click button -----------------------------------------------------------

local clickButton = make("TextButton", {
	Text = "CLICK!",
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	TextColor3 = COLORS.Text,
	BackgroundColor3 = COLORS.Gold,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.new(0, 170, 0, 170),
	Parent = gui,
}, {
	corner(999),
	make("UIStroke", { Thickness = 5, Color = Color3.fromRGB(200, 120, 0) }),
	make("UIPadding", {
		PaddingTop = UDim.new(0.3, 0),
		PaddingBottom = UDim.new(0.3, 0),
		PaddingLeft = UDim.new(0.15, 0),
		PaddingRight = UDim.new(0.15, 0),
	}),
}) :: TextButton
local clickScale = make("UIScale", { Parent = clickButton }) :: UIScale

local function popup(text: string)
	local x = clickButton.AbsolutePosition.X + clickButton.AbsoluteSize.X * math.random()
	local y = clickButton.AbsolutePosition.Y
	local pop = label({
		Text = text,
		TextColor3 = COLORS.Gold,
		Position = UDim2.fromOffset(x - 60, y - 20),
		Size = UDim2.fromOffset(120, 36),
		Parent = gui,
	})
	local tween = TweenService:Create(pop, TweenInfo.new(0.8), {
		Position = UDim2.fromOffset(x - 60, y - 110),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
end

clickButton.Activated:Connect(function()
	ClickRemote:FireServer()
	if state then
		popup("+" .. Format.number(state.ClickValue))
	end
	clickScale.Scale = 0.92
	TweenService:Create(clickScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
end)

-- Panels -----------------------------------------------------------------

local panels = {}
local openPanel: string? = nil

local function createPanel(name: string, title: string)
	local frame = make("Frame", {
		Name = name,
		BackgroundColor3 = COLORS.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 560, 0, 400),
		Visible = false,
		Parent = gui,
	}, {
		corner(16),
		stroke(3),
		make("UISizeConstraint", { MaxSize = Vector2.new(560, 400) }),
	})
	-- Fit small (phone) screens.
	local function fit()
		local viewport = workspace.CurrentCamera.ViewportSize
		frame.Size = UDim2.fromOffset(math.min(560, viewport.X - 120), math.min(400, viewport.Y - 140))
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	label({
		Text = title,
		Size = UDim2.new(1, -80, 0, 40),
		Position = UDim2.new(0, 16, 0, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	button({
		Text = "X",
		BackgroundColor3 = COLORS.Red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		Parent = frame,
	}, function()
		frame.Visible = false
		openPanel = nil
	end)
	local content = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0, 56),
		Size = UDim2.new(1, -24, 1, -68),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = frame,
	})
	panels[name] = frame
	return frame, content
end

local function togglePanel(name: string)
	for key, frame in panels do
		frame.Visible = key == name and openPanel ~= name
	end
	openPanel = if openPanel == name then nil else name
	for _, refresh in refreshers do
		refresh()
	end
end

local function list(parent: Instance, padding: number?)
	make("UIListLayout", {
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

local function row(parent: Instance, order: number, height: number?)
	return make("Frame", {
		BackgroundColor3 = COLORS.Row,
		Size = UDim2.new(1, -8, 0, height or 64),
		LayoutOrder = order,
		Parent = parent,
	}, { corner(10) })
end

local function header(parent: Instance, order: number, text: string)
	return label({
		Text = text,
		TextColor3 = COLORS.Gold,
		Size = UDim2.new(1, -8, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function rowText(parent: Instance, title: string, subtitle: string)
	local titleLabel = label({
		Text = title,
		Size = UDim2.new(0.62, 0, 0, 28),
		Position = UDim2.new(0, 10, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	local subtitleLabel = label({
		Text = subtitle,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.SubText,
		Size = UDim2.new(0.62, 0, 0, 20),
		Position = UDim2.new(0, 10, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	return titleLabel, subtitleLabel
end

local function rowButton(parent: Instance, text: string, color: Color3, onClick: () -> ())
	return button({
		Text = text,
		BackgroundColor3 = color,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.34, 0, 0, 44),
		Parent = parent,
	}, onClick)
end

-- Robux price labels come from Roblox so they're always correct.
local function fetchPrice(id: number, infoType: Enum.InfoType, fallback: number, apply: (string) -> ())
	apply("R$ " .. fallback)
	if id == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			apply("R$ " .. info.PriceInRobux)
		end
	end)
end

local function sortedPasses()
	local keys = {}
	for key in Config.GamePasses do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return Config.GamePasses[a].Order < Config.GamePasses[b].Order
	end)
	return keys
end

local function isConfigured(id: number): boolean
	return id ~= 0 or IS_STUDIO
end

local function promptProduct(key: string)
	local product = Config.getProductByKey(key)
	if not product or product.Id == 0 then
		toast("Set this product's Id in Config.luau first", COLORS.Red)
		return
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
end

-- Shop panel -------------------------------------------------------------

do
	local _, content = createPanel("Shop", "Shop")
	list(content)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	header(content, nextOrder(), "Upgrades")
	local upgradeKeys = {}
	for key in Config.Upgrades do
		table.insert(upgradeKeys, key)
	end
	table.sort(upgradeKeys, function(a, b)
		return Config.Upgrades[a].Order < Config.Upgrades[b].Order
	end)
	for _, key in upgradeKeys do
		local upgrade = Config.Upgrades[key]
		local frame = row(content, nextOrder())
		local title, subtitle = rowText(frame, upgrade.Name, upgrade.Description)
		local buy = rowButton(frame, "Buy", COLORS.Green, function()
			act("BuyUpgrade", key)
		end)
		table.insert(refreshers, function()
			if not state then
				return
			end
			local level = state.Upgrades[key]
			local cost = Config.upgradeCost(key, level)
			title.Text = string.format("%s (Lv %d)", upgrade.Name, level)
			subtitle.Text = upgrade.Description
			if level >= upgrade.MaxLevel then
				buy.Text = "MAX"
				setEnabled(buy, false, COLORS.Green)
			else
				buy.Text = Format.number(cost) .. " coins"
				setEnabled(buy, state.Coins >= cost, COLORS.Green)
			end
		end)
	end

	header(content, nextOrder(), "Game Passes (permanent)")
	for _, key in sortedPasses() do
		local pass = Config.GamePasses[key]
		if isConfigured(pass.Id) then
			local frame = row(content, nextOrder())
			rowText(frame, pass.Name, pass.Description)
			local priceText = "R$ " .. pass.Price
			local buy = rowButton(frame, priceText, COLORS.Purple, function()
				if state and state.Passes[key] then
					return
				end
				if pass.Id == 0 then
					toast("Set this pass's Id in Config.luau first", COLORS.Red)
					return
				end
				MarketplaceService:PromptGamePassPurchase(player, pass.Id)
			end)
			fetchPrice(pass.Id, Enum.InfoType.GamePass, pass.Price, function(text)
				priceText = text
			end)
			table.insert(refreshers, function()
				local owned = state and state.Passes[key]
				buy.Text = if owned then "OWNED" else priceText
				setEnabled(buy, not owned, COLORS.Purple)
			end)
		end
	end

	header(content, nextOrder(), "Boosts & Coins")
	for _, product in Config.DevProducts do
		if isConfigured(product.Id) then
			local frame = row(content, nextOrder())
			local description = if product.Kind == "Coins"
				then string.format("%d minutes of income (min %s)", product.Minutes, Format.number(product.Min))
				elseif product.Kind == "Rebirth" then "Rebirth now without paying coins"
				else "Everyone in the server gets 2x egg luck!"
			local _, subtitle = rowText(frame, product.Name, description)
			local buy = rowButton(frame, "R$ " .. product.Price, COLORS.Blue, function()
				promptProduct(product.Key)
			end)
			fetchPrice(product.Id, Enum.InfoType.Product, product.Price, function(text)
				buy.Text = text
			end)
			if product.Kind == "Coins" then
				table.insert(refreshers, function()
					if state then
						local perSecond = state.PassiveIncome + state.ClickValue * Config.EstimatedClicksPerSecond
						local amount = math.max(product.Min, math.floor(perSecond * 60 * product.Minutes))
						subtitle.Text = "Get +" .. Format.number(amount) .. " coins"
					end
				end)
			end
		end
	end
end

-- Eggs panel -------------------------------------------------------------

local hatchPopup

do
	local _, content = createPanel("Eggs", "Eggs")
	list(content)
	for index, egg in Config.Eggs do
		local frame = row(content, index, 118)
		label({
			Text = egg.Name .. "  -  " .. Format.number(egg.Cost) .. " coins",
			Size = UDim2.new(0.62, 0, 0, 28),
			Position = UDim2.new(0, 10, 0, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local odds = make("TextLabel", {
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			TextColor3 = COLORS.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(0.62, 0, 0, 76),
			Position = UDim2.new(0, 10, 0, 36),
			Parent = frame,
		})
		local hatchOne = button({
			Text = "Hatch x1",
			BackgroundColor3 = COLORS.Green,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.new(0.34, 0, 0, 44),
			Parent = frame,
		}, function()
			local ok, pets = act("Hatch", egg.Key, 1)
			if ok then
				hatchPopup(pets)
			end
		end)
		local hatchThree = button({
			Text = "Hatch x3",
			BackgroundColor3 = COLORS.Purple,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 62),
			Size = UDim2.new(0.34, 0, 0, 44),
			Parent = frame,
		}, function()
			if state and not state.Passes.TripleHatch then
				local pass = Config.GamePasses.TripleHatch
				if pass.Id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.Id)
				else
					toast("Set the Triple Hatch pass Id in Config.luau first", COLORS.Red)
				end
				return
			end
			local ok, pets = act("Hatch", egg.Key, 3)
			if ok then
				hatchPopup(pets)
			end
		end)
		table.insert(refreshers, function()
			if not state then
				return
			end
			local chances = Config.eggChances(egg, state.Luck)
			local parts = {}
			for i, entry in egg.Pets do
				local petInfo = Config.PetTypes[entry.Pet]
				local color = Config.Rarities[petInfo.Rarity].Color:ToHex()
				table.insert(
					parts,
					string.format(
						'<font color="#%s">%s</font> x%s %s',
						color,
						prettyName(entry.Pet),
						Format.number(1 + petInfo.Boost),
						Format.percent(chances[i])
					)
				)
			end
			odds.Text = table.concat(parts, "  |  ")
			setEnabled(hatchOne, state.Coins >= egg.Cost, COLORS.Green)
			if state.Passes.TripleHatch then
				hatchThree.Text = "Hatch x3"
				setEnabled(hatchThree, state.Coins >= egg.Cost * 3, COLORS.Purple)
			else
				hatchThree.Text = "Hatch x3 (Pass)"
				setEnabled(hatchThree, true, COLORS.Purple)
			end
		end)
	end
end

-- Hatch result popup -----------------------------------------------------

do
	local frame = make("Frame", {
		BackgroundColor3 = COLORS.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(420, 150),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	}, { corner(16), make("UIStroke", { Thickness = 4, Color = COLORS.Gold }) })
	local title = label({
		Text = "You hatched:",
		Size = UDim2.new(1, -20, 0, 36),
		Position = UDim2.new(0, 10, 0, 10),
		ZIndex = 11,
		Parent = frame,
	})
	local results = make("TextLabel", {
		BackgroundTransparency = 1,
		RichText = true,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = COLORS.Text,
		Size = UDim2.new(1, -20, 0, 80),
		Position = UDim2.new(0, 10, 0, 56),
		ZIndex = 11,
		Parent = frame,
	})
	local scale = make("UIScale", { Parent = frame }) :: UIScale
	local showId = 0

	function hatchPopup(pets: { string })
		local parts = {}
		for _, petType in pets do
			local info = Config.PetTypes[petType]
			local color = Config.Rarities[info.Rarity].Color:ToHex()
			table.insert(parts, string.format('<font color="#%s">%s (%s)</font>', color, prettyName(petType), info.Rarity))
		end
		title.Text = "You hatched:"
		results.Text = table.concat(parts, "\n")
		frame.Size = UDim2.fromOffset(420, 70 + 40 * #pets)
		results.Size = UDim2.new(1, -20, 0, 36 * #pets)
		frame.Visible = true
		scale.Scale = 0.3
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		showId += 1
		local myId = showId
		task.delay(2.5, function()
			if showId == myId then
				frame.Visible = false
			end
		end)
	end
end

-- Pets panel -------------------------------------------------------------

do
	local _, content = createPanel("Pets", "Pets")
	local infoLabel = label({
		Text = "",
		TextColor3 = COLORS.SubText,
		Size = UDim2.new(0.6, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	button({
		Text = "Equip Best",
		BackgroundColor3 = COLORS.Green,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0.3, 0, 0, 34),
		Parent = content,
	}, function()
		act("EquipBest")
	end)
	local grid = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.fromOffset(120, 110),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local lastSignature = ""
	table.insert(refreshers, function()
		if not state or openPanel ~= "Pets" then
			return
		end
		local equipped = 0
		local signature = {}
		for _, pet in state.Pets do
			if pet.Equipped then
				equipped += 1
			end
			table.insert(signature, pet.Id .. (if pet.Equipped then "e" else ""))
		end
		infoLabel.Text = string.format(
			"Equipped %d/%d  |  Pets %d/%d",
			equipped,
			state.MaxEquipped,
			#state.Pets,
			Config.Pets.MaxInventory
		)
		local sig = table.concat(signature, ",")
		if sig == lastSignature then
			return
		end
		lastSignature = sig

		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local sorted = table.clone(state.Pets)
		table.sort(sorted, function(a, b)
			if a.Equipped ~= b.Equipped then
				return a.Equipped
			end
			return Config.PetTypes[a.Type].Boost > Config.PetTypes[b.Type].Boost
		end)
		for index, pet in sorted do
			local info = Config.PetTypes[pet.Type]
			local rarityColor = Config.Rarities[info.Rarity].Color
			local card = button({
				Text = "",
				BackgroundColor3 = COLORS.Row,
				LayoutOrder = index,
				Parent = grid,
			}, function()
				act("ToggleEquip", pet.Id)
			end)
			make("UIStroke", {
				Thickness = if pet.Equipped then 4 else 2,
				Color = if pet.Equipped then COLORS.Green else rarityColor,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = card,
			})
			label({ Text = prettyName(pet.Type), TextColor3 = rarityColor, Size = UDim2.new(1, 0, 0, 26), Parent = card })
			label({
				Text = info.Rarity,
				Font = Enum.Font.GothamMedium,
				TextColor3 = COLORS.SubText,
				Size = UDim2.new(1, 0, 0, 18),
				Position = UDim2.new(0, 0, 0, 28),
				Parent = card,
			})
			label({
				Text = "+" .. Format.percent(info.Boost),
				TextColor3 = COLORS.Gold,
				Size = UDim2.new(1, 0, 0, 24),
				Position = UDim2.new(0, 0, 0, 48),
				Parent = card,
			})
			button({
				Text = "Delete",
				BackgroundColor3 = COLORS.Red,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0),
				Size = UDim2.new(0.8, 0, 0, 22),
				Parent = card,
			}, function()
				act("DeletePet", pet.Id)
			end)
			if pet.Equipped then
				label({
					Text = "EQUIPPED",
					TextColor3 = COLORS.Green,
					Size = UDim2.new(1, 0, 0, 14),
					Position = UDim2.new(0, 0, 0, 72),
					Parent = card,
				})
			end
		end
	end)
end

-- Rebirth panel ----------------------------------------------------------

do
	local _, content = createPanel("Rebirth", "Rebirth")
	list(content)
	local infoLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = 20,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.Text,
		Size = UDim2.new(1, -8, 0, 150),
		LayoutOrder = 1,
		Parent = content,
	})
	local rebirthButton = button({
		Text = "Rebirth",
		BackgroundColor3 = COLORS.Blue,
		Size = UDim2.new(1, -8, 0, 54),
		LayoutOrder = 2,
		Parent = content,
	}, function()
		act("Rebirth")
	end)
	local skip = Config.getProductByKey("SkipRebirth")
	if skip and isConfigured(skip.Id) then
		local skipButton = button({
			Text = "Instant Rebirth - R$ " .. skip.Price,
			BackgroundColor3 = COLORS.Purple,
			Size = UDim2.new(1, -8, 0, 44),
			LayoutOrder = 3,
			Parent = content,
		}, function()
			promptProduct("SkipRebirth")
		end)
		fetchPrice(skip.Id, Enum.InfoType.Product, skip.Price, function(text)
			skipButton.Text = "Instant Rebirth - " .. text
		end)
	end
	table.insert(refreshers, function()
		if not state then
			return
		end
		local per = Config.Rebirth.MultiplierPerRebirth
		local current = 1 + state.Rebirths * per
		infoLabel.Text = string.format(
			"Rebirths: %d\n\nRebirthing resets your coins and upgrades but keeps your pets.\n\nBase multiplier: x%s  ->  x%s",
			state.Rebirths,
			Format.number(current),
			Format.number(current + per)
		)
		rebirthButton.Text = "Rebirth for " .. Format.number(state.RebirthCost) .. " coins"
		setEnabled(rebirthButton, state.Coins >= state.RebirthCost, COLORS.Blue)
	end)
end

-- Daily panel ------------------------------------------------------------

local dailyReadyDot

do
	local _, content = createPanel("Daily", "Daily Reward")
	list(content)
	local infoLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		TextWrapped = true,
		TextSize = 22,
		Font = Enum.Font.GothamMedium,
		TextColor3 = COLORS.Text,
		Size = UDim2.new(1, -8, 0, 140),
		LayoutOrder = 1,
		Parent = content,
	})
	local claim = button({
		Text = "Claim",
		BackgroundColor3 = COLORS.Green,
		Size = UDim2.new(1, -8, 0, 54),
		LayoutOrder = 2,
		Parent = content,
	}, function()
		act("ClaimDaily")
	end)
	table.insert(refreshers, function()
		if not state then
			return
		end
		local remaining = state.DailyReadyAt - state.ServerTime
		infoLabel.Text = string.format(
			"Come back every day to grow your streak (up to %dx rewards)!\n\nCurrent streak: %d day(s)\nNext reward: %s coins",
			Config.Daily.MaxStreak,
			state.DailyStreak,
			Format.number(state.DailyReward)
		)
		if remaining > 0 then
			claim.Text = "Ready in " .. Format.duration(remaining)
			setEnabled(claim, false, COLORS.Green)
		else
			claim.Text = "Claim!"
			setEnabled(claim, true, COLORS.Green)
		end
	end)
end

-- Side menu --------------------------------------------------------------

do
	local menu = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(110, 330),
		Parent = gui,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local entries = {
		{ "Shop", COLORS.Gold },
		{ "Eggs", COLORS.Green },
		{ "Pets", COLORS.Blue },
		{ "Rebirth", COLORS.Purple },
		{ "Daily", COLORS.Red },
	}
	for index, entry in entries do
		local btn = button({
			Text = entry[1],
			BackgroundColor3 = entry[2],
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = index,
			Parent = menu,
		}, function()
			togglePanel(entry[1])
		end)
		stroke().Parent = btn
		if entry[1] == "Daily" then
			dailyReadyDot = make("Frame", {
				BackgroundColor3 = COLORS.Gold,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(20, 20),
				Visible = false,
				Parent = btn,
			}, { corner(999) })
		end
	end
end

-- VIP chat tag -----------------------------------------------------------

do
	local TextChatService = game:GetService("TextChatService")
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender and sender:GetAttribute("VIP") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = '<font color="#FFD700">[VIP]</font> ' .. message.PrefixText
			return props
		end
		return nil
	end
end

-- State updates ----------------------------------------------------------

local function refreshAll()
	if not state then
		return
	end
	coinsLabel.Text = Format.number(math.floor(state.Coins)) .. " coins"
	statsLabel.Text = string.format(
		"x%s multiplier  |  +%s/click  |  +%s/sec",
		Format.number(state.Multiplier),
		Format.number(state.ClickValue),
		Format.number(state.PassiveIncome)
	)
	if dailyReadyDot then
		dailyReadyDot.Visible = state.DailyReadyAt <= state.ServerTime
	end
	for _, refresh in refreshers do
		refresh()
	end
end

StateRemote.OnClientEvent:Connect(function(newState)
	state = newState
	refreshAll()
end)

-- Server luck banner + countdowns tick every second.
task.spawn(function()
	while true do
		local luckUntil = workspace:GetAttribute("ServerLuckUntil") or 0
		local now = workspace:GetServerTimeNow()
		luckLabel.Visible = luckUntil > now
		if luckLabel.Visible then
			luckLabel.Text = "2x SERVER LUCK: " .. Format.duration(luckUntil - now)
		end
		if state then
			state.ServerTime += 1
			refreshAll()
		end
		task.wait(1)
	end
end)

RequestStateRemote:FireServer()
