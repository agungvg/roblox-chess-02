--!strict
-- GameServer: the whole game state lives here. The server owns money,
-- inventory, steals, locks and saves; the client only asks, and every
-- remote is validated before anything changes. One module, one heartbeat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage.Shared.Config)
local PieceData = require(ReplicatedStorage.Shared.PieceData)
local BoardMath = require(ReplicatedStorage.Shared.BoardMath)
local PieceBuilder = require(script.Parent.PieceBuilder)
local WorldBuilder = require(script.Parent.WorldBuilder)

local GameServer = {}

export type OwnedPiece = {
	defId: string,
	mutation: number,
	file: number,
	rank: number,
	model: Model,
}

export type PlayerState = {
	money: number,
	rebirths: number,
	owned: { OwnedPiece },
	codex: { [string]: boolean },
	upgrades: { [string]: number },
	quests: { [string]: number },
	questClaimed: { [string]: boolean },
	carrying: OwnedPiece?,
	lockUntil: number,
	lastWhack: number,
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- DataStore is unavailable in an unpublished Studio place (and can fail
-- for other reasons at runtime). Never let that kill the module load:
-- fall back to session-only data (saves just don't persist).
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_KEY)
	end)
	if ok then
		store = result
	else
		warn(
			"[ChessBrainrot] DataStore unavailable ("
				.. tostring(result)
				.. ") — running session-only, saves disabled."
		)
	end
end

local world: WorldBuilder.World
local states: { [Player]: PlayerState } = {}
local parade: { { defId: string, mutation: number, model: Model?, slot: number } } = {}
local rivalPieces: { { rival: number, defId: string, mutation: number, model: Model, file: number, rank: number } } = {}
local rivalLock: { [number]: { open: boolean, untilTime: number } } = {}
local eventState = { name = "", mult = 1, active = false, endsAt = 0, nextAt = 0, nextName = "" }
local thieves: { Model } = {}

-- Remote helpers ------------------------------------------------------------
local function getRemote(name: string, className: string): Instance
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = Remotes
	return r
end

local BuyPieceRF = getRemote("BuyPiece", "RemoteFunction") :: RemoteFunction
local CaptureRF = getRemote("CapturePiece", "RemoteFunction") :: RemoteFunction
local DepositRF = getRemote("DepositPiece", "RemoteFunction") :: RemoteFunction
local WhackRE = getRemote("Whack", "RemoteEvent") :: RemoteEvent
local LockRE = getRemote("LockBoard", "RemoteEvent") :: RemoteEvent
local RebirthRF = getRemote("Rebirth", "RemoteFunction") :: RemoteFunction
local UpgradeRF = getRemote("BuyUpgrade", "RemoteFunction") :: RemoteFunction
local QuestRF = getRemote("ClaimQuest", "RemoteFunction") :: RemoteFunction
local SelectRE = getRemote("SelectPiece", "RemoteEvent") :: RemoteEvent
local JuiceRE = getRemote("Juice", "RemoteEvent") :: RemoteEvent
local SyncRE = getRemote("StateSync", "RemoteEvent") :: RemoteEvent

-- State helpers -------------------------------------------------------------
local function newState(): PlayerState
	return {
		money = 500,
		rebirths = 0,
		owned = {},
		codex = {},
		upgrades = {},
		quests = {},
		questClaimed = {},
		carrying = nil,
		lockUntil = 0,
		lastWhack = 0,
	}
end

local function codexMult(state: PlayerState): number
	local found = 0
	for _ in state.codex do
		found += 1
	end
	local mult = 1
	for _, m in Config.CODEX_MILESTONES do
		if found >= m.found then
			mult = m.mult
		end
	end
	return mult
end

local function upgradeMult(state: PlayerState, id: string): number
	local lvl = state.upgrades[id] or 0
	if id == "income" then
		return 1 + 0.25 * lvl
	end
	return 1
end

function GameServer.incomePerSecond(state: PlayerState): number
	local total = 0
	for _, piece in state.owned do
		local def = PieceData.get(piece.defId)
		if def then
			total += PieceData.incomeWithMutation(def, piece.mutation)
		end
	end
	total *= (Config.REBIRTH_MULT ^ state.rebirths)
	total *= codexMult(state)
	total *= upgradeMult(state, "income")
	total *= eventState.mult
	return math.floor(total)
end

local function sync(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local found = 0
	for _ in state.codex do
		found += 1
	end
	SyncRE:FireClient(player, {
		money = math.floor(state.money),
		income = GameServer.incomePerSecond(state),
		owned = #state.owned,
		rebirths = state.rebirths,
		codexFound = found,
		codex = state.codex,
		carrying = state.carrying and state.carrying.defId or nil,
		lockUntil = state.lockUntil,
		quests = state.quests,
		questClaimed = state.questClaimed,
		upgrades = state.upgrades,
	})
end

local function juiceAll(kind: string, a: any, b: any)
	JuiceRE:FireAllClients(kind, a, b)
end

-- Selecting one of your own pieces highlights its legal moves (green).
local function doSelect(player: Player, file: number, rank: number)
	local state = states[player]
	if not state then
		return
	end
	for _, piece in state.owned do
		if piece.file == file and piece.rank == rank then
			local def = PieceData.get(piece.defId)
			if def then
				SyncRE:FireClient(player, { highlight = BoardMath.legalTargets(def.typeName, file, rank) })
			end
			return
		end
	end
end

-- Board squares are clickable: carrying -> deposit here, else select a piece.
local function wireSquareClicks()
	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") and part.Name:match("^Square_[a-h][1-8]$") then
			local sq = part.Name:sub(8)
			local file = string.byte(sq:sub(1, 1)) - 96
			local rank = tonumber(sq:sub(2, 2)) or 1
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 30
			click.Parent = part
			click.MouseClick:Connect(function(plr: Player)
				local state = states[plr]
				if not state then
					return
				end
				if state.carrying then
					DepositRF.OnServerInvoke(plr, file, rank)
				else
					doSelect(plr, file, rank)
				end
			end)
		end
	end
end

local function bumpQuest(state: PlayerState, id: string, amount: number)
	state.quests[id] = (state.quests[id] or 0) + amount
end

local function checkRowQuest(state: PlayerState)
	-- Fill a full row of 8: any rank with 8 owned pieces
	local perRank: { [number]: number } = {}
	for _, piece in state.owned do
		perRank[piece.rank] = (perRank[piece.rank] or 0) + 1
	end
	for _, count in perRank do
		if count >= 8 then
			state.quests["row8"] = 8
			return
		end
	end
end

-- Parade --------------------------------------------------------------------
local function spawnParadePiece(slot: number, delaySeconds: number)
	task.delay(delaySeconds, function()
		local luckLevel = 0
		local defs = PieceData.all()
		local def = defs[math.random(1, #defs)]
		-- Parade skews toward affordable pieces for new players
		if math.random() < 0.6 then
			def = defs[math.random(1, 24)]
		end
		local mutation = PieceData.rollMutation(luckLevel)
		local pos = world.paradeSlots[slot]
		local model = PieceBuilder.build(def, mutation)
		-- March in from the west end of the carpet, then settle on the pedestal
		model:PivotTo(CFrame.new(pos.X - 34, 1, pos.Z))
		model.Parent = workspace
		-- Walk in from the west end of the carpet, then settle on the pedestal.
		-- TweenService can't tween a multi-part Model's pivot, so step it
		-- manually in small lerps (same easing feel, exact landing square).
		local startCf = model:GetPivot()
		local targetCf = CFrame.new(pos)
		local steps = 24
		for i = 1, steps do
			local alpha = i / steps
			model:PivotTo(startCf:Lerp(targetCf, alpha))
			task.wait(1.6 / steps)
		end
		-- Price label above the pedestal. Adornee MUST be set explicitly:
		-- a BillboardGui parented to a Model with no Adornee renders at
		-- the world origin (0,0,0). Torso centre is at scale*0.25, so
		-- the offset is scale*0.75 + 1.2 to stay scale+1.2 above the base.
		local price = PieceData.priceWithMutation(def, mutation)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PriceTag"
		billboard.Size = UDim2.fromOffset(180, 54)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, def.scale * 0.75 + 1.2, 0)
		billboard.AlwaysOnTop = true
		local primary = model.PrimaryPart
		assert(primary, "parade piece has no PrimaryPart")
		billboard.Adornee = primary
		billboard.Parent = model
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
		label.Text = def.name
			.. "\n"
			.. PieceData.formatMoney(price)
			.. " · "
			.. PieceData.formatMoney(PieceData.incomeWithMutation(def, mutation))
			.. "/s"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = billboard
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 20
		click.Parent = model.PrimaryPart
		click.MouseClick:Connect(function(plr: Player)
			BuyPieceRF.OnServerInvoke(plr, slot)
		end)
		parade[slot] = { defId = def.id, mutation = mutation, model = model, slot = slot }
	end)
end

-- Rival boards ---------------------------------------------------------------
local function spawnRivalPieces()
	for rivalIndex, rival in ipairs(world.rivals) do
		for i = 1, 6 do
			local defs = PieceData.all()
			local def = defs[math.random(1, #defs)]
			local mutation = PieceData.rollMutation(0)
			local model = PieceBuilder.build(def, mutation)
			local file = math.random(1, 8)
			local rank = math.random(1, 8)
			-- Rival boards are 3-stud squares centred on rival.center
			local half = 12
			local x = rival.center.X - half + (file - 0.5) * 3
			local z = rival.center.Z - half + (rank - 0.5) * 3
			model:ScaleTo(0.5)
			model:PivotTo(CFrame.new(x, 0, z))
			model.Parent = workspace
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 24
			click.Parent = model.PrimaryPart
			click.MouseClick:Connect(function(plr: Player)
				CaptureRF.OnServerInvoke(plr, rivalIndex, 1)
			end)
			table.insert(
				rivalPieces,
				{ rival = rivalIndex, defId = def.id, mutation = mutation, model = model, file = file, rank = rank }
			)
		end
		rivalLock[rivalIndex] = { open = true, untilTime = os.clock() + Config.LOCK_OPEN }
	end
end

local function updateRivalLocks()
	for i, rival in ipairs(world.rivals) do
		local lock = rivalLock[i]
		if lock and os.clock() >= lock.untilTime then
			lock.open = not lock.open
			lock.untilTime = os.clock() + (lock.open and Config.LOCK_OPEN or Config.LOCK_CLOSED)
			rival.lockPart.Color = lock.open and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 60, 60)
			rival.nameTag.Text = rival.owner .. "\n" .. (lock.open and "OPEN — CAPTURE!" or "LOCKED")
		end
	end
end

-- Thieves --------------------------------------------------------------------
local function spawnThief(boss: boolean)
	local def = PieceData.get(boss and "King_Secret" or "Pawn_Common")
	assert(def, "thief def missing")
	local model = PieceBuilder.build(def, boss and 9 or 1)
	model.Name = boss and "RaccoonKing" or "Thief"
	local startX = math.random(-30, 30)
	model:PivotTo(CFrame.new(startX, 1, 40))
	model.Parent = workspace
	table.insert(thieves, model)
	-- Walk toward the player board; if it arrives, it steals a piece.
	task.spawn(function()
		local steps = 40
		for i = 1, steps do
			if not model.Parent then
				return
			end
			local alpha = i / steps
			local pos = model:GetPivot().Position
			model:PivotTo(CFrame.new(pos.X, 1, 40 - alpha * 40))
			task.wait(0.5)
		end
		-- Reached the board: steal the cheapest owned piece from a random player
		for player, state in states do
			if #state.owned > 0 then
				local victim = state.owned[1]
				table.remove(state.owned, 1)
				if victim.model then
					victim.model:Destroy()
				end
				juiceAll("steal", player.Name .. " lost a piece to a thief!", nil)
				sync(player)
				break
			end
		end
		model:Destroy()
	end)
end

-- Events ---------------------------------------------------------------------
local eventIndex = 0
local function startNextEvent()
	eventIndex = (eventIndex % #Config.EVENTS) + 1
	local ev = Config.EVENTS[eventIndex]
	eventState.nextName = ev.name
	eventState.nextAt = os.clock() + Config.EVENT_TEASER
	juiceAll("eventTeaser", "NEXT: " .. ev.name .. " in " .. Config.EVENT_TEASER .. "s", ev.color)
	task.delay(Config.EVENT_TEASER, function()
		eventState.name = ev.name
		eventState.mult = ev.incomeMult
		eventState.active = true
		eventState.endsAt = os.clock() + ev.duration
		juiceAll("event", ev.name, ev.desc)
		if ev.name == "CHECKMATE RUSH!" then
			-- A King parades: force a King into slot 1
			local slot = parade[1]
			if slot and slot.model then
				slot.model:Destroy()
			end
			local king = PieceData.get("King_Legendary")
			assert(king, "king def missing")
			local model = PieceBuilder.build(king, 3)
			model:PivotTo(CFrame.new(world.paradeSlots[1]))
			model.Parent = workspace
			parade[1] = { defId = king.id, mutation = 3, model = model, slot = 1 }
		elseif ev.name == "EN PASSANT RAID!" then
			for _ = 1, 3 do
				spawnThief(false)
			end
		elseif ev.name == "NIGHT RAID!" then
			spawnThief(true)
			spawnThief(false)
		end
		task.delay(ev.duration, function()
			eventState.active = false
			eventState.mult = 1
			eventState.nextAt = os.clock() + Config.EVENT_GAP
			juiceAll("eventEnd", ev.name .. " is over!", nil)
		end)
	end)
end

-- Remotes --------------------------------------------------------------------
local function freeSquare(state: PlayerState): (number?, number?)
	for _ = 1, 40 do
		local file = math.random(1, 8)
		local rank = math.random(1, 8)
		local taken = false
		for _, piece in state.owned do
			if piece.file == file and piece.rank == rank then
				taken = true
				break
			end
		end
		if not taken then
			return file, rank
		end
	end
	return nil, nil
end

BuyPieceRF.OnServerInvoke = function(player: Player, slot: number)
	local state = states[player]
	if not state then
		return false, "no state"
	end
	local entry = parade[slot]
	if not entry or not entry.model then
		return false, "slot empty"
	end
	local def = PieceData.get(entry.defId)
	if not def then
		return false, "bad piece"
	end
	local price = PieceData.priceWithMutation(def, entry.mutation)
	if state.money < price then
		return false, "not enough money"
	end
	local file, rank = freeSquare(state)
	if not file or not rank then
		return false, "board full"
	end
	state.money -= price
	-- Move the parade model onto the player's board square
	local model = entry.model
	local priceTag = model:FindFirstChild("PriceTag")
	if priceTag then
		priceTag:Destroy()
	end
	local click = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("ClickDetector")
	if click then
		click:Destroy()
	end
	local target = BoardMath.squareToWorld(file, rank :: number, 0)
	model:PivotTo(CFrame.new(target))
	local ownedClick = Instance.new("ClickDetector")
	ownedClick.MaxActivationDistance = 24
	ownedClick.Parent = model.PrimaryPart
	ownedClick.MouseClick:Connect(function(plr: Player)
		doSelect(plr, file, rank :: number)
	end)
	local owned: OwnedPiece =
		{ defId = def.id, mutation = entry.mutation, file = file, rank = rank :: number, model = model }
	table.insert(state.owned, owned)
	state.codex[def.id] = true
	bumpQuest(state, "buy1", 1)
	bumpQuest(state, "buy5", 1)
	if def.typeName == "Queen" then
		bumpQuest(state, "queen1", 1)
	end
	checkRowQuest(state)
	parade[slot] = nil
	spawnParadePiece(slot, Config.PARADE_RESPAWN)
	juiceAll("buy", player.Name .. " bought " .. def.name .. "!", model:GetPivot().Position)
	sync(player)
	return true, def.name
end

CaptureRF.OnServerInvoke = function(player: Player, rivalIndex: number, pieceIndex: number)
	local state = states[player]
	if not state then
		return false, "no state"
	end
	if state.carrying then
		return false, "already carrying"
	end
	local lock = rivalLock[rivalIndex]
	if not lock or not lock.open then
		return false, "DENIED! LOCKED"
	end
	local target: any = nil
	for i, rp in rivalPieces do
		if rp.rival == rivalIndex then
			target = rp
			table.remove(rivalPieces, i)
			break
		end
	end
	if not target then
		return false, "no piece"
	end
	local def = PieceData.get(target.defId)
	if not def then
		return false, "bad piece"
	end
	-- Attach the stolen piece above the player's head
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, "no character"
	end
	local model = target.model
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart
	weld.C0 = CFrame.new(0, 6, 0)
	weld.Parent = root
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	state.carrying = { defId = def.id, mutation = target.mutation, file = 0, rank = 0, model = model }
	bumpQuest(state, "capture2", 1)
	juiceAll("steal", player.Name .. " captured " .. def.name .. "!", root.Position)
	sync(player)
	return true, def.name
end

DepositRF.OnServerInvoke = function(player: Player, file: number, rank: number)
	local state = states[player]
	if not state or not state.carrying then
		return false, "not carrying"
	end
	if file < 1 or file > 8 or rank < 1 or rank > 8 then
		return false, "off board"
	end
	for _, piece in state.owned do
		if piece.file == file and piece.rank == rank then
			return false, "square taken"
		end
	end
	local carried = state.carrying
	state.carrying = nil
	local model = carried.model
	-- Unweld and place on the square
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local target = BoardMath.squareToWorld(file, rank, 0)
	model:PivotTo(CFrame.new(target))
	local ownedClick = Instance.new("ClickDetector")
	ownedClick.MaxActivationDistance = 24
	ownedClick.Parent = model.PrimaryPart
	ownedClick.MouseClick:Connect(function(plr: Player)
		doSelect(plr, file, rank)
	end)
	carried.file = file
	carried.rank = rank
	table.insert(state.owned, carried)
	local def = PieceData.get(carried.defId)
	if def then
		state.codex[def.id] = true
	end
	checkRowQuest(state)
	juiceAll("deposit", player.Name .. " banked a capture!", target)
	sync(player)
	return true, "deposited"
end

WhackRE.OnServerEvent:Connect(function(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if os.clock() - state.lastWhack < Config.WHACK_COOLDOWN then
		return
	end
	state.lastWhack = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local range = Config.WHACK_RANGE + 4 * (state.upgrades["whack"] or 0)
	for i = #thieves, 1, -1 do
		local thief = thieves[i]
		if thief.Parent and (thief:GetPivot().Position - root.Position).Magnitude <= range then
			table.remove(thieves, i)
			thief:Destroy()
			state.money += Config.WHACK_REWARD
			bumpQuest(state, "whack3", 1)
			juiceAll("whack", player.Name .. " WHACKED a thief! +$" .. Config.WHACK_REWARD, root.Position)
			sync(player)
			return
		end
	end
end)

LockRE.OnServerEvent:Connect(function(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local lockTime = 30 + 10 * (state.upgrades["lock"] or 0)
	state.lockUntil = os.clock() + lockTime
	juiceAll("lock", player.Name .. " locked their board for " .. lockTime .. "s!", nil)
	sync(player)
end)

RebirthRF.OnServerInvoke = function(player: Player)
	local state = states[player]
	if not state then
		return false, "no state"
	end
	local cost = Config.REBIRTH_BASE_COST * (state.rebirths + 1)
	if state.money < cost then
		return false, "need " .. PieceData.formatMoney(cost)
	end
	state.money = 0
	state.rebirths += 1
	for _, piece in state.owned do
		if piece.model then
			piece.model:Destroy()
		end
	end
	state.owned = {}
	bumpQuest(state, "rebirth1", 1)
	juiceAll("rebirth", player.Name .. " REBIRTHED! Income x" .. (Config.REBIRTH_MULT ^ state.rebirths), nil)
	sync(player)
	return true, "rebirth " .. state.rebirths
end

UpgradeRF.OnServerInvoke = function(player: Player, id: string)
	local state = states[player]
	if not state then
		return false, "no state"
	end
	local def: any = nil
	for _, u in Config.UPGRADES do
		if u.id == id then
			def = u
			break
		end
	end
	if not def then
		return false, "bad upgrade"
	end
	local level = state.upgrades[id] or 0
	if level >= 3 then
		return false, "max level"
	end
	local cost = def.base * (level + 1)
	if state.money < cost then
		return false, "not enough money"
	end
	state.money -= cost
	state.upgrades[id] = level + 1
	sync(player)
	return true, def.name .. " Lv" .. (level + 1)
end

QuestRF.OnServerInvoke = function(player: Player, id: string)
	local state = states[player]
	if not state then
		return false, "no state"
	end
	local def: any = nil
	for _, q in Config.QUESTS do
		if q.id == id then
			def = q
			break
		end
	end
	if not def then
		return false, "bad quest"
	end
	if state.questClaimed[id] then
		return false, "already claimed"
	end
	if (state.quests[id] or 0) < def.target then
		return false, "not done yet"
	end
	state.questClaimed[id] = true
	state.money += def.reward
	juiceAll("quest", player.Name .. " completed a quest! +$" .. def.reward, nil)
	sync(player)
	return true, def.name
end

SelectRE.OnServerEvent:Connect(doSelect)

-- Player lifecycle ------------------------------------------------------------
local function loadState(player: Player): PlayerState
	local state = newState()
	if not store then
		-- Session-only mode (DataStore unavailable): fresh state, no load.
		return state
	end
	local ok, data = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if ok and type(data) == "table" then
		local d = data :: any
		state.money = d.money or 500
		state.rebirths = d.rebirths or 0
		state.codex = d.codex or {}
		state.upgrades = d.upgrades or {}
		state.quests = d.quests or {}
		state.questClaimed = d.questClaimed or {}
	end
	return state
end

local function saveState(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if not store then
		-- Session-only mode (DataStore unavailable): nothing to persist.
		return
	end
	pcall(function()
		store:SetAsync("player_" .. player.UserId, {
			money = math.floor(state.money),
			rebirths = state.rebirths,
			codex = state.codex,
			upgrades = state.upgrades,
			quests = state.quests,
			questClaimed = state.questClaimed,
		})
	end)
end

Players.PlayerAdded:Connect(function(player: Player)
	states[player] = loadState(player)
	sync(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	saveState(player)
	states[player] = nil
end)

-- Main loops ------------------------------------------------------------------
function GameServer.start()
	world = WorldBuilder.build()
	wireSquareClicks()
	for slot = 1, Config.PARADE_SLOTS do
		spawnParadePiece(slot, (slot - 1) * 1.5)
	end
	spawnRivalPieces()

	-- Income tick: 1 second
	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				state.money += GameServer.incomePerSecond(state)
				sync(player)
			end
			updateRivalLocks()
		end
	end)

	-- Event rotation
	task.spawn(function()
		task.wait(20) -- first event after 20s of calm
		while true do
			startNextEvent()
			-- wait for teaser + duration + gap
			local ev = Config.EVENTS[eventIndex]
			task.wait(Config.EVENT_TEASER + ev.duration + Config.EVENT_GAP)
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_EVERY)
			for player in states do
				saveState(player)
			end
		end
	end)
end

return GameServer
