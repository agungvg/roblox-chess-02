--!strict
-- Game.client: the whole HUD + juice, client-side only. The server decides
-- money, buys, steals and locks; this file only shows them — count-up
-- numbers, event banners, floating income labels, camera shake, the Codex,
-- quests and upgrades panels. Every system must be visible in a still.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PieceData = require(ReplicatedStorage.Shared.PieceData)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local JuiceRE = Remotes:WaitForChild("Juice") :: RemoteEvent
local SyncRE = Remotes:WaitForChild("StateSync") :: RemoteEvent
local WhackRE = Remotes:WaitForChild("Whack") :: RemoteEvent
local LockRE = Remotes:WaitForChild("LockBoard") :: RemoteEvent
local RebirthRF = Remotes:WaitForChild("Rebirth") :: RemoteFunction
local UpgradeRF = Remotes:WaitForChild("BuyUpgrade") :: RemoteFunction
local QuestRF = Remotes:WaitForChild("ClaimQuest") :: RemoteFunction

local FEEL = Config.FEEL

-- State mirrored from the server ---------------------------------------------
local money = 0
local income = 0
local ownedCount = 0
local rebirths = 0
local codexFound = 0
local carrying: string? = nil
local lockUntil = 0
local quests: { [string]: number } = {}
local questClaimed: { [string]: boolean } = {}
local upgrades: { [string]: number } = {}

-- UI helpers ------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ChessHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(
	parent: Instance,
	text: string,
	size: UDim2,
	pos: UDim2,
	fontSize: number,
	color: Color3?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.FredokaOne
	l.TextSize = fontSize
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 18
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextStrokeTransparency = 0.4
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.93 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
	return b
end

-- Top banner: the one-line formula + money -----------------------------------
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 64)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
topBar.BackgroundTransparency = 0.15
topBar.BorderSizePixel = 0
topBar.Parent = gui

label(topBar, Config.HUD_FORMULA, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 2), 15, Color3.fromRGB(255, 220, 100))
local moneyLabel =
	label(topBar, "$0", UDim2.new(0.5, 0, 0, 34), UDim2.new(0.25, 0, 0, 24), 28, Color3.fromRGB(120, 255, 140))
local subLabel = label(
	topBar,
	"+$0/s · REBIRTH 0 · x1 · 0/48 CODEX",
	UDim2.new(1, 0, 0, 16),
	UDim2.new(0, 0, 0, 48),
	13,
	Color3.fromRGB(200, 200, 220)
)

-- Count-up money (game-feel 4.7): tween a NumberValue, never snap.
local moneyValue = Instance.new("NumberValue")
moneyValue.Value = 0
moneyValue.Changed:Connect(function(v)
	moneyLabel.Text = PieceData.formatMoney(math.floor(v))
end)
local function countUp(to: number)
	TweenService:Create(
		moneyValue,
		TweenInfo.new(FEEL.CountUpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = to }
	):Play()
end

-- Event banner (centre, slides in) -------------------------------------------
local banner = Instance.new("Frame")
banner.Size = UDim2.new(0.7, 0, 0, 84)
banner.Position = UDim2.new(0.15, 0, -0.2, 0)
banner.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
banner.BorderSizePixel = 0
banner.Visible = false
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = banner
local bannerTitle = label(banner, "", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 6), 30, Color3.fromRGB(20, 12, 4))
local bannerSub = label(banner, "", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 48), 16, Color3.fromRGB(40, 24, 8))
local bannerBusy = false
local function showBanner(title: string, subtitle: string, accent: Color3?)
	if bannerBusy then
		return
	end
	bannerBusy = true
	bannerTitle.Text = title
	bannerSub.Text = subtitle
	banner.BackgroundColor3 = accent or Color3.fromRGB(255, 200, 40)
	banner.Visible = true
	TweenService:Create(
		banner,
		TweenInfo.new(FEEL.BannerInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.15, 0, 0.09, 0) }
	):Play()
	task.delay(FEEL.BannerHoldTime, function()
		TweenService:Create(
			banner,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.15, 0, -0.2, 0) }
		):Play()
		task.delay(0.3, function()
			banner.Visible = false
			bannerBusy = false
		end)
	end)
end

-- Carrying indicator -----------------------------------------------------------
local carryBar = Instance.new("Frame")
carryBar.Size = UDim2.new(0.5, 0, 0, 36)
carryBar.Position = UDim2.new(0.25, 0, 0, 76)
carryBar.BackgroundColor3 = Color3.fromRGB(255, 120, 60)
carryBar.BorderSizePixel = 0
carryBar.Visible = false
carryBar.Parent = gui
local carryCorner = Instance.new("UICorner")
carryCorner.CornerRadius = UDim.new(0, 8)
carryCorner.Parent = carryBar
local carryLabel = label(carryBar, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 18)

-- Bottom action bar ------------------------------------------------------------
local actionBar = Instance.new("Frame")
actionBar.Size = UDim2.new(0.9, 0, 0, 56)
actionBar.Position = UDim2.new(0.05, 0, 1, -68)
actionBar.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
actionBar.BackgroundTransparency = 0.2
actionBar.BorderSizePixel = 0
actionBar.Parent = gui
local actionCorner = Instance.new("UICorner")
actionCorner.CornerRadius = UDim.new(0, 10)
actionCorner.Parent = actionBar

local lockBtn = button(
	actionBar,
	"LOCK [L] READY",
	UDim2.new(0.19, 0, 0.8, 0),
	UDim2.new(0.01, 0, 0.1, 0),
	Color3.fromRGB(90, 160, 255)
)
local whackBtn = button(
	actionBar,
	"WHACK [F] READY",
	UDim2.new(0.19, 0, 0.8, 0),
	UDim2.new(0.21, 0, 0.1, 0),
	Color3.fromRGB(255, 80, 60)
)
local upgradeBtn = button(
	actionBar,
	"UPGRADES [U]",
	UDim2.new(0.19, 0, 0.8, 0),
	UDim2.new(0.41, 0, 0.1, 0),
	Color3.fromRGB(180, 90, 255)
)
local rebirthBtn = button(
	actionBar,
	"REBIRTH [R]",
	UDim2.new(0.19, 0, 0.8, 0),
	UDim2.new(0.61, 0, 0.1, 0),
	Color3.fromRGB(255, 200, 40)
)
local codexBtn = button(
	actionBar,
	"CODEX [B] 0/48",
	UDim2.new(0.18, 0, 0.8, 0),
	UDim2.new(0.81, 0, 0.1, 0),
	Color3.fromRGB(90, 220, 160)
)

lockBtn.MouseButton1Click:Connect(function()
	LockRE:FireServer()
end)
whackBtn.MouseButton1Click:Connect(function()
	WhackRE:FireServer()
end)

-- Quest panel (right side) ------------------------------------------------------
local questPanel = Instance.new("Frame")
questPanel.Size = UDim2.new(0, 260, 0, 300)
questPanel.Position = UDim2.new(1, -272, 0, 80)
questPanel.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
questPanel.BackgroundTransparency = 0.2
questPanel.BorderSizePixel = 0
questPanel.Parent = gui
local questCorner = Instance.new("UICorner")
questCorner.CornerRadius = UDim.new(0, 10)
questCorner.Parent = questPanel
local questTitle = label(
	questPanel,
	"QUESTS 0/8 done",
	UDim2.new(1, 0, 0, 28),
	UDim2.new(0, 0, 0, 4),
	18,
	Color3.fromRGB(255, 220, 100)
)
local questLabels: { [string]: TextLabel } = {}
for i, q in Config.QUESTS do
	local y = 32 + (i - 1) * 32
	local l = label(questPanel, "", UDim2.new(1, -12, 0, 28), UDim2.new(0, 6, 0, y), 13)
	questLabels[q.id] = l
	local claim =
		button(questPanel, "CLAIM", UDim2.new(0, 58, 0, 24), UDim2.new(1, -64, 0, y + 2), Color3.fromRGB(90, 220, 160))
	claim.TextSize = 12
	claim.MouseButton1Click:Connect(function()
		QuestRF:InvokeServer(q.id)
	end)
end

local function refreshQuests()
	local done = 0
	for _, q in Config.QUESTS do
		local prog = quests[q.id] or 0
		local claimed = questClaimed[q.id] or false
		if prog >= q.target then
			done += 1
		end
		local l = questLabels[q.id]
		if l then
			l.Text = (claimed and "✓ " or "")
				.. q.name
				.. " "
				.. math.min(prog, q.target)
				.. "/"
				.. q.target
				.. " · "
				.. PieceData.formatMoney(q.reward)
		end
	end
	questTitle.Text = "QUESTS " .. done .. "/8 done"
end

-- Upgrades panel (toggle with U) ------------------------------------------------
local upgradePanel = Instance.new("Frame")
upgradePanel.Size = UDim2.new(0, 340, 0, 300)
upgradePanel.Position = UDim2.new(0.5, -170, 0.5, -150)
upgradePanel.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
upgradePanel.BorderSizePixel = 0
upgradePanel.Visible = false
upgradePanel.Parent = gui
local upCorner = Instance.new("UICorner")
upCorner.CornerRadius = UDim.new(0, 12)
upCorner.Parent = upgradePanel
label(
	upgradePanel,
	"UPGRADES — spend money, earn faster",
	UDim2.new(1, 0, 0, 30),
	UDim2.new(0, 0, 0, 6),
	16,
	Color3.fromRGB(255, 220, 100)
)
for i, u in Config.UPGRADES do
	local y = 40 + (i - 1) * 42
	local lvl = upgrades[u.id] or 0
	label(
		upgradePanel,
		u.name .. " Lv" .. lvl .. "/3 — " .. u.desc,
		UDim2.new(0.62, 0, 0, 36),
		UDim2.new(0, 10, 0, y),
		14
	)
	local buy = button(
		upgradePanel,
		PieceData.formatMoney(u.base * (lvl + 1)),
		UDim2.new(0, 110, 0, 32),
		UDim2.new(1, -120, 0, y),
		Color3.fromRGB(255, 200, 40)
	)
	buy.MouseButton1Click:Connect(function()
		UpgradeRF:InvokeServer(u.id)
	end)
end
upgradeBtn.MouseButton1Click:Connect(function()
	upgradePanel.Visible = not upgradePanel.Visible
end)

-- Codex panel (toggle with B): 48 tiles -------------------------------------------
local codexPanel = Instance.new("Frame")
codexPanel.Size = UDim2.new(0, 560, 0, 420)
codexPanel.Position = UDim2.new(0.5, -280, 0.5, -210)
codexPanel.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
codexPanel.BorderSizePixel = 0
codexPanel.Visible = false
codexPanel.Parent = gui
local codexCorner = Instance.new("UICorner")
codexCorner.CornerRadius = UDim.new(0, 12)
codexCorner.Parent = codexPanel
label(
	codexPanel,
	"PIECE CODEX — 48 pieces. Tap a tile to read its joke.",
	UDim2.new(1, 0, 0, 30),
	UDim2.new(0, 0, 0, 6),
	16,
	Color3.fromRGB(255, 220, 100)
)
local codexJoke =
	label(codexPanel, "", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 380), 14, Color3.fromRGB(200, 200, 220))
local codexTiles: { [string]: TextButton } = {}
do
	local all = PieceData.all()
	for i, def in all do
		local col = (i - 1) % 8
		local row = math.floor((i - 1) / 8)
		local tile = Instance.new("TextButton")
		tile.Size = UDim2.new(0, 62, 0, 52)
		tile.Position = UDim2.new(0, 10 + col * 68, 0, 44 + row * 56)
		tile.BackgroundColor3 = def.color
		tile.Text = "?"
		tile.Font = Enum.Font.FredokaOne
		tile.TextSize = 13
		tile.TextColor3 = Color3.fromRGB(255, 255, 255)
		tile.TextStrokeTransparency = 0.4
		tile.Parent = codexPanel
		codexTiles[def.id] = tile
		tile.MouseButton1Click:Connect(function()
			codexJoke.Text = def.name .. " (" .. def.rarity .. "): " .. def.joke
		end)
	end
end
codexBtn.MouseButton1Click:Connect(function()
	codexPanel.Visible = not codexPanel.Visible
end)

local function refreshCodex(foundSet: { [string]: boolean })
	for id, tile in codexTiles do
		local def = PieceData.get(id)
		if def then
			if foundSet[id] then
				tile.Text = def.name
				tile.BackgroundColor3 = def.color
			else
				tile.Text = "?"
				tile.BackgroundColor3 = Color3.fromRGB(60, 56, 72)
			end
		end
	end
end

-- Keybinds -----------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.L then
		LockRE:FireServer()
	elseif input.KeyCode == Enum.KeyCode.F then
		WhackRE:FireServer()
	elseif input.KeyCode == Enum.KeyCode.U then
		upgradePanel.Visible = not upgradePanel.Visible
	elseif input.KeyCode == Enum.KeyCode.B then
		codexPanel.Visible = not codexPanel.Visible
	elseif input.KeyCode == Enum.KeyCode.R then
		RebirthRF:InvokeServer()
	end
end)
rebirthBtn.MouseButton1Click:Connect(function()
	RebirthRF:InvokeServer()
end)

-- Camera shake (game-feel 4.1) -----------------------------------------------------
local camera = workspace.CurrentCamera
local trauma = 0
local shakeT = 0
local function addShake(amount: number)
	trauma = math.min(trauma + amount, 1)
end
RunService:BindToRenderStep("ChessShake", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if trauma <= 0 or not camera then
		return
	end
	shakeT += dt * 20
	local s = trauma * trauma
	camera.CFrame *= CFrame.Angles(
		math.rad(FEEL.ShakeMaxAngle) * s * math.noise(shakeT, 0),
		math.rad(FEEL.ShakeMaxAngle) * s * math.noise(0, shakeT),
		math.rad(FEEL.ShakeMaxAngle) * s * math.noise(shakeT, shakeT)
	)
	trauma = math.max(trauma - FEEL.ShakeDecay * dt, 0)
end)

-- Floating income labels (game-feel 4.4) --------------------------------------------
local function floatLabel(worldPos: Vector3, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = workspace.Terrain
	-- Anchor to a temporary part so the label has a world position
	local anchor = Instance.new("Part")
	anchor.Name = "FloatAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = worldPos
	anchor.Parent = workspace
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextStrokeTransparency = 0.2
	l.Parent = billboard
	TweenService:Create(
		billboard,
		TweenInfo.new(FEEL.LabelRiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }
	):Play()
	task.delay(0.7, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

-- Server events --------------------------------------------------------------------
JuiceRE.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "event" then
		showBanner(a, b or "", Color3.fromRGB(255, 200, 40))
		addShake(0.2)
	elseif kind == "eventTeaser" then
		showBanner(a, "Get ready!", Color3.fromRGB(90, 160, 255))
	elseif kind == "eventEnd" then
		showBanner(a, "", Color3.fromRGB(120, 120, 140))
	elseif kind == "buy" then
		addShake(0.15)
		if typeof(b) == "Vector3" then
			floatLabel(b, "BOUGHT!", Color3.fromRGB(120, 255, 140))
		end
	elseif kind == "steal" then
		showBanner("CAPTURE!", a or "", Color3.fromRGB(255, 120, 60))
		addShake(FEEL.ShakeAddSteal)
	elseif kind == "whack" then
		addShake(FEEL.ShakeAddHurt)
		if typeof(b) == "Vector3" then
			floatLabel(b, "WHACKED! +$250", Color3.fromRGB(255, 220, 80))
		end
	elseif kind == "rebirth" then
		showBanner("REBIRTH!", a or "", Color3.fromRGB(255, 200, 40))
		addShake(0.5)
	elseif kind == "lock" then
		showBanner("BOARD LOCKED", a or "", Color3.fromRGB(90, 160, 255))
	elseif kind == "quest" then
		showBanner("QUEST DONE!", a or "", Color3.fromRGB(90, 220, 160))
	elseif kind == "deposit" then
		addShake(0.2)
		if typeof(b) == "Vector3" then
			floatLabel(b, "BANKED!", Color3.fromRGB(120, 255, 140))
		end
	end
end)

-- State sync -------------------------------------------------------------------------
SyncRE.OnClientEvent:Connect(function(data: any)
	if data.highlight then
		-- Legal-move highlight: tint squares green (client-side, cosmetic)
		for _, sq in data.highlight do
			local part = workspace:FindFirstChild("Square_" .. string.char(96 + sq.file) .. tostring(sq.rank))
			if part and part:IsA("BasePart") then
				local original = part.Color
				part.Color = Color3.fromRGB(90, 255, 120)
				task.delay(3, function()
					part.Color = original
				end)
			end
		end
		return
	end
	if data.money ~= nil then
		if data.money ~= money then
			countUp(data.money)
		end
		money = data.money
	end
	if data.income ~= nil then
		income = data.income
	end
	if data.owned ~= nil then
		ownedCount = data.owned
	end
	if data.rebirths ~= nil then
		rebirths = data.rebirths
	end
	if data.codexFound ~= nil then
		codexFound = data.codexFound
	end
	if data.codex ~= nil then
		refreshCodex(data.codex)
	end
	if data.carrying ~= nil then
		carrying = data.carrying
		carryBar.Visible = carrying ~= nil
		if carrying then
			local def = PieceData.get(carrying :: string)
			carryLabel.Text = "CARRYING: " .. (def and def.name or carrying) .. " -> DROP AT YOUR BOARD"
		end
	end
	if data.lockUntil ~= nil then
		lockUntil = data.lockUntil
	end
	if data.quests ~= nil then
		quests = data.quests
	end
	if data.questClaimed ~= nil then
		questClaimed = data.questClaimed
	end
	if data.upgrades ~= nil then
		upgrades = data.upgrades
	end
	refreshQuests()
	local mult = 1 + rebirths * 2
	subLabel.Text = "+"
		.. PieceData.formatMoney(income)
		.. "/s · "
		.. ownedCount
		.. " PIECES · REBIRTH "
		.. rebirths
		.. " · x"
		.. mult
		.. " · "
		.. codexFound
		.. "/48 CODEX"
	codexBtn.Text = "CODEX [B] " .. codexFound .. "/48"
end)

-- Lock button countdown ----------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.5)
		local remaining = lockUntil - os.clock()
		if remaining > 0 then
			lockBtn.Text = "LOCK [L] " .. math.ceil(remaining) .. "s"
		else
			lockBtn.Text = "LOCK [L] READY"
		end
	end
end)

-- Income floaters: every 5s, a +$ label rises off the board ------------------------------
task.spawn(function()
	while true do
		task.wait(5)
		if income > 0 then
			floatLabel(
				Vector3.new(math.random(-20, 20), 2, math.random(-20, 20)),
				"+" .. PieceData.formatMoney(income) .. "/s",
				Color3.fromRGB(120, 255, 140)
			)
		end
	end
end)

print("[ChessBrainrot] Client HUD ready.")
