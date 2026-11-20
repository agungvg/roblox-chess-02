--!strict
-- PieceData: the 48-piece roster (6 types x 8 rarities). Each piece has a
-- joke name, a face (shown on a SurfaceGui so every piece has personality),
-- a colour, and a price/income computed from type base x rarity x mutation.
-- All data is generated here from the tables — no hand-written 48-row list
-- to drift out of sync with the rarities.

local Config = require(script.Parent.Config)

local PieceData = {}

export type PieceDef = {
	id: string, -- e.g. "Pawn_Common"
	typeName: string,
	rarity: string,
	rarityIndex: number,
	name: string, -- display name, e.g. "Peewee Pawn"
	face: string, -- SurfaceGui face
	color: Color3,
	price: number,
	income: number, -- $/s, no mutation
	scale: number, -- total height in studs
	joke: string, -- Codex flavour line
}

local TYPE_NAMES: { [string]: { string } } = {
	Pawn = {
		"Peewee Pawn",
		"Grumpy Grunt",
		"Helmet Head",
		"Squire Steve",
		"Brave Bean",
		"Tiny Tank",
		"Pawn Storm",
		"Frontline Fred",
	},
	Knight = {
		"Neigh-sayer",
		"Sir Gallops",
		"Horse Power",
		"Lancelot Jr",
		"The Knightmare",
		"Plume Pete",
		"Charge Charlie",
		"Stable Star",
	},
	Bishop = {
		"Holy Sniper",
		"Bishop Blitz",
		"Diagonal Dan",
		"The Mitre",
		"Prayer Pete",
		"Slopey Steve",
		"Cross-Eyed Carl",
		"Sniper Fodder",
	},
	Rook = {
		"Castle Crash",
		"Tower Tom",
		"The Fortress",
		"Brick House",
		"Rampart Ray",
		"Stonewall Sam",
		"Turret Tina",
		"Bastion Bob",
	},
	Queen = {
		"Queen Bee",
		"Her Majesty",
		"Crown Jewel",
		"The Boss Lady",
		"Scepter Sue",
		"Royal Rumble",
		"Duchess Doom",
		"Empress Ivy",
	},
	King = {
		"The Big Cheese",
		"Kingpin",
		"Crown King",
		"Checkmate Charlie",
		"His Royal Grump",
		"Throne Tom",
		"The Grandmaster",
		"Lord Checkmate",
	},
}

local TYPE_FACES: { [string]: string } = {
	Pawn = "•_•",
	Knight = "≧◡≦",
	Bishop = "¬_¬",
	Rook = "•̀_•́",
	Queen = "✿◠‿◠",
	King = "ಠ‿ಠ",
}

local TYPE_JOKES: { [string]: string } = {
	Pawn = "Moves one square at a time. Dreams of promotion. Still waiting.",
	Knight = "The only piece that jumps. Show-off. Neighs at strangers.",
	Bishop = "Only moves diagonally. Has never seen a straight line. Proud of it.",
	Rook = "A castle that walks. Nobody told it castles don't walk.",
	Queen = "Moves anywhere. Does everything. Still underpaid.",
	King = "The most important piece and the worst at moving. One square. Slowly.",
}

local ALL: { PieceDef } = {}
local BY_ID: { [string]: PieceDef } = {}

local types = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" }
for _, typeName in types do
	local base = Config.TYPE_BASE[typeName]
	for rarityIndex, rarity in Config.RARITIES do
		local id = typeName .. "_" .. rarity.name
		local def: PieceDef = {
			id = id,
			typeName = typeName,
			rarity = rarity.name,
			rarityIndex = rarityIndex,
			name = TYPE_NAMES[typeName][rarityIndex],
			face = TYPE_FACES[typeName],
			color = rarity.color,
			price = math.floor(base.price * rarity.mult),
			income = math.floor(base.income * rarity.mult),
			scale = Config.PIECE_HEIGHT[typeName],
			joke = TYPE_JOKES[typeName],
		}
		table.insert(ALL, def)
		BY_ID[id] = def
	end
end

function PieceData.all(): { PieceDef }
	return ALL
end

function PieceData.get(id: string): PieceDef?
	return BY_ID[id]
end

function PieceData.count(): number
	return #ALL
end

-- Price / income for a piece WITH a mutation applied.
function PieceData.priceWithMutation(def: PieceDef, mutationIndex: number): number
	local mut = Config.MUTATIONS[mutationIndex] or Config.MUTATIONS[1]
	return math.floor(def.price * mut.mult)
end

function PieceData.incomeWithMutation(def: PieceDef, mutationIndex: number): number
	local mut = Config.MUTATIONS[mutationIndex] or Config.MUTATIONS[1]
	return math.floor(def.income * mut.mult)
end

function PieceData.mutationName(mutationIndex: number): string
	local mut = Config.MUTATIONS[mutationIndex]
	return mut and mut.name or "Plain"
end

function PieceData.mutationMult(mutationIndex: number): number
	local mut = Config.MUTATIONS[mutationIndex]
	return mut and mut.mult or 1
end

-- Weighted random rarity: common is common, divine is a miracle.
local RARITY_WEIGHTS = { 40, 26, 15, 9, 5, 3, 1.4, 0.6 }
function PieceData.rollRarity(luckBonus: number): number
	local total = 0
	for i, w in RARITY_WEIGHTS do
		total += w
	end
	local roll = math.random() * total
	local acc = 0
	for i, w in RARITY_WEIGHTS do
		acc += w
		if roll <= acc then
			return i
		end
	end
	return 1
end

-- Mutation roll: most pieces are plain; luck upgrades raise the chance.
function PieceData.rollMutation(luckLevel: number): number
	local chance = 0.25 + 0.15 * luckLevel
	if math.random() > chance then
		return 1
	end
	-- mutated: weighted toward the small multipliers
	local weights = { 30, 22, 16, 11, 8, 6, 4, 3 }
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = math.random() * total
	local acc = 0
	for i, w in weights do
		acc += w
		if roll <= acc then
			return i + 1 -- index 2..9 into MUTATIONS
		end
	end
	return 2
end

-- Money formatting: 1234567 -> $1.23M
function PieceData.formatMoney(n: number): string
	if n >= 1_000_000_000 then
		return string.format("$%.2fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("$%.2fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("$%.2fK", n / 1_000)
	else
		return "$" .. tostring(math.floor(n))
	end
end

return PieceData
