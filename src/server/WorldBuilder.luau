--!strict
-- WorldBuilder: constructs the whole arena in code at server start — no
-- Studio hand-placement, so the Rojo build is the whole game. Layout:
-- player board at the origin (48x48), Grandmaster's Parade along the south
-- edge, 5 rival boards around the arena, and the reference image's decor:
-- 4 corner pillars with gold caps, 5 parade flag poles, 4 bushes, giant
-- King (~16-stud) + Queen (~13.7-stud) statues on marble plinths.

local BoardMath = require(game:GetService("ReplicatedStorage").Shared.BoardMath)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local PieceBuilder = require(script.Parent.PieceBuilder)
local PieceData = require(game:GetService("ReplicatedStorage").Shared.PieceData)

local WorldBuilder = {}

local GOLD = Color3.fromRGB(255, 210, 60)
local MARBLE = Color3.fromRGB(235, 230, 220)
local DARK_STONE = Color3.fromRGB(60, 52, 72)
local LIGHT_SQUARE = Color3.fromRGB(240, 217, 181)
local DARK_SQUARE = Color3.fromRGB(176, 126, 84)

export type RivalBoard = {
	owner: string,
	center: Vector3,
	lockPart: Part,
	nameTag: TextLabel,
	squares: { Part },
}

export type World = {
	paradeSlots: { Vector3 },
	rivals: { RivalBoard },
	spawnPoint: Vector3,
}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.Parent = workspace
	return p
end

local function buildPlayerBoard(): { Part }
	local squares: { Part } = {}
	local half = (Config.BOARD_FILES * Config.SQUARE) / 2
	-- Gold trim frame under the board
	local trim = part("BoardTrim", Vector3.new(half * 2 + 4, 1, half * 2 + 4), GOLD, Enum.Material.Metal)
	trim.Position = Vector3.new(0, -0.6, 0)
	trim.CanCollide = false
	for file = 1, 8 do
		for rank = 1, 8 do
			local pos = BoardMath.squareToWorld(file, rank, 0)
			local sq = part(
				"Square_" .. BoardMath.squareName(file, rank),
				Vector3.new(Config.SQUARE, 1, Config.SQUARE),
				if (file + rank) % 2 == 0 then LIGHT_SQUARE else DARK_SQUARE
			)
			sq.Position = Vector3.new(pos.X, -0.5, pos.Z)
			sq.CanCollide = true
			table.insert(squares, sq)
		end
	end
	return squares
end

local function buildRivalBoard(owner: string, ownerColor: Color3, center: Vector3): RivalBoard
	local squareSize = 3
	local half = (8 * squareSize) / 2
	local folder = Instance.new("Folder")
	folder.Name = "RivalBoard_" .. owner
	folder.Parent = workspace
	local squares: { Part } = {}
	for file = 1, 8 do
		for rank = 1, 8 do
			local sq = Instance.new("Part")
			sq.Name = "Square"
			sq.Size = Vector3.new(squareSize, 1, squareSize)
			sq.Color = if (file + rank) % 2 == 0 then LIGHT_SQUARE else DARK_SQUARE
			sq.Anchored = true
			sq.CanCollide = true
			sq.Position = Vector3.new(
				center.X - half + (file - 0.5) * squareSize,
				-0.5,
				center.Z - half + (rank - 0.5) * squareSize
			)
			sq.Parent = folder
			table.insert(squares, sq)
		end
	end
	-- Owner name tag on a post at the board's back edge
	local post = Instance.new("Part")
	post.Name = "OwnerPost"
	post.Size = Vector3.new(1, 6, 1)
	post.Color = DARK_STONE
	post.Anchored = true
	post.Position = Vector3.new(center.X, 3, center.Z - half - 2)
	post.Parent = folder
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(220, 60)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = post
	tag.Parent = post
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	label.Text = owner .. "\nLOCKED"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = tag
	-- Lock indicator orb: green = open, red = locked
	local lockPart = Instance.new("Part")
	lockPart.Name = "LockOrb"
	lockPart.Shape = Enum.PartType.Ball
	lockPart.Size = Vector3.new(2, 2, 2)
	lockPart.Color = Color3.fromRGB(255, 60, 60)
	lockPart.Material = Enum.Material.Neon
	lockPart.Anchored = true
	lockPart.Position = Vector3.new(center.X, 6.5, center.Z - half - 2)
	lockPart.Parent = folder
	return { owner = owner, center = center, lockPart = lockPart, nameTag = label, squares = squares }
end

local function buildParade(): { Vector3 }
	local slots: { Vector3 } = {}
	-- Red-carpet lane along the south edge (z = +34), 6 pedestals
	local carpet = part("ParadeCarpet", Vector3.new(72, 0.4, 10), Color3.fromRGB(200, 40, 60))
	carpet.Position = Vector3.new(0, -0.2, 34)
	carpet.CanCollide = false
	for i = 1, Config.PARADE_SLOTS do
		local x = -30 + (i - 1) * 12
		local pedestal = part("Pedestal_" .. i, Vector3.new(8, 1.5, 8), MARBLE, Enum.Material.Marble)
		pedestal.Position = Vector3.new(x, 0.25, 34)
		table.insert(slots, Vector3.new(x, 1, 34))
	end
	return slots
end

local function buildPillar(x: number, z: number)
	local shaft = part("Pillar", Vector3.new(4, 22, 4), MARBLE, Enum.Material.Marble)
	shaft.Position = Vector3.new(x, 11, z)
	local cap = part("PillarCap", Vector3.new(6, 1.5, 6), GOLD, Enum.Material.Metal)
	cap.Position = Vector3.new(x, 22.5, z)
	local base = part("PillarBase", Vector3.new(6, 1.5, 6), DARK_STONE)
	base.Position = Vector3.new(x, 0.25, z)
end

local function buildFlagPole(x: number, z: number, color: Color3)
	local pole = part("FlagPole", Vector3.new(0.6, 14, 0.6), DARK_STONE, Enum.Material.Metal)
	pole.Position = Vector3.new(x, 7, z)
	local flag = part("Flag", Vector3.new(5, 3, 0.3), color)
	flag.Position = Vector3.new(x + 2.5, 12.5, z)
end

local function buildBush(x: number, z: number)
	for i, off in { { 0, 0 }, { 1.6, 0.8 }, { -1.4, 0.9 } } do
		local b = part("Bush", Vector3.new(3.2, 3.2, 3.2), Color3.fromRGB(60, 160, 80))
		b.Shape = Enum.PartType.Ball
		b.Position = Vector3.new(x + off[1], 1.6, z + off[2])
	end
end

local function buildStatue(kind: string, height: number, x: number, z: number)
	-- Marble plinth
	local plinth = part("Plinth", Vector3.new(10, 2, 10), MARBLE, Enum.Material.Marble)
	plinth.Position = Vector3.new(x, 1, z)
	-- A giant piece, scaled up from the normal builder, standing on it
	local def = PieceData.get(kind .. "_Legendary") or PieceData.get(kind .. "_Common")
	assert(def, "statue def missing: " .. kind)
	local model = PieceBuilder.build(def, 3) -- Gold-Plated
	model.Name = kind .. "Statue"
	-- Scale the whole model up to the statue height
	local scaleFactor = height / def.scale
	model:ScaleTo(scaleFactor)
	model:PivotTo(CFrame.new(x, 2, z))
	model.Parent = workspace
end

function WorldBuilder.build(): World
	-- Player board
	buildPlayerBoard()

	-- Parade lane
	local paradeSlots = buildParade()

	-- 5 rival boards around the arena
	local rivals: { RivalBoard } = {}
	local placements: { { center: Vector3, index: number } } = {
		{ center = Vector3.new(0, 0, -58), index = 1 },
		{ center = Vector3.new(58, 0, -38), index = 2 },
		{ center = Vector3.new(-58, 0, -38), index = 3 },
		{ center = Vector3.new(64, 0, 18), index = 4 },
		{ center = Vector3.new(-64, 0, 18), index = 5 },
	}
	for _, place in placements do
		local rival = Config.RIVALS[place.index]
		table.insert(rivals, buildRivalBoard(rival.name, rival.color, place.center))
	end

	-- 4 corner pillars with gold caps
	buildPillar(40, 40)
	buildPillar(-40, 40)
	buildPillar(40, -40)
	buildPillar(-40, -40)

	-- 5 parade flag poles
	local flagColors = {
		Color3.fromRGB(255, 60, 60),
		Color3.fromRGB(255, 200, 40),
		Color3.fromRGB(90, 220, 160),
		Color3.fromRGB(90, 160, 255),
		Color3.fromRGB(180, 90, 255),
	}
	for i = 1, 5 do
		buildFlagPole(-40 + (i - 1) * 20, 42, flagColors[i])
	end

	-- 4 bushes
	buildBush(30, 30)
	buildBush(-30, 30)
	buildBush(30, -30)
	buildBush(-30, -30)

	-- Giant statues: King ~16 studs, Queen ~13.7 studs, on marble plinths
	buildStatue("King", 16, -52, 32)
	buildStatue("Queen", 13.7, 52, 32)

	-- Spawn pad, south of the parade
	local spawn = part("SpawnPad", Vector3.new(12, 1, 12), Color3.fromRGB(90, 220, 160))
	spawn.Position = Vector3.new(0, -0.5, 52)
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 52)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = workspace

	return { paradeSlots = paradeSlots, rivals = rivals, spawnPoint = Vector3.new(0, 2, 52) }
end

return WorldBuilder
