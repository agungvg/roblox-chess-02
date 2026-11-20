--!strict
-- Config: one frozen table for every tuning number in Chess Brainrot
-- Battle Royale. Designers change numbers here, never inside systems.
-- (P-29: one frozen feel table, one source of truth.)

local Config = {}

Config.GAME_NAME = "Chess Brainrot Battle Royale"
Config.HUD_FORMULA =
	"48 PIECES · 6 TYPES · 8 RARITIES · 8 MUTATIONS · 6 BOARDS · 6 EVENTS · CAPTURE · LOCK · REBIRTH"

-- Board geometry. One square = 6 studs; the player board is 8x8 = 48x48.
Config.SQUARE = 6
Config.BOARD_FILES = 8
Config.BOARD_RANKS = 8

-- Scale rule (Lyso): pieces TOWER over the player (~5 studs). Total height
-- in studs, per type. Never shrink a piece below its type height.
Config.PIECE_HEIGHT = {
	Pawn = 6.2,
	Knight = 7.2,
	Bishop = 7.6,
	Rook = 7.3,
	Queen = 8.5,
	King = 10.0,
}

-- Rarities, 8 tiers. Multiplier applies to base income and price.
Config.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(180, 180, 180), mult = 1 },
	{ name = "Uncommon", color = Color3.fromRGB(110, 220, 110), mult = 2 },
	{ name = "Rare", color = Color3.fromRGB(90, 160, 255), mult = 4 },
	{ name = "Epic", color = Color3.fromRGB(180, 90, 255), mult = 8 },
	{ name = "Mythic", color = Color3.fromRGB(255, 90, 200), mult = 16 },
	{ name = "Legendary", color = Color3.fromRGB(255, 200, 40), mult = 32 },
	{ name = "Secret", color = Color3.fromRGB(255, 80, 60), mult = 64 },
	{ name = "Divine", color = Color3.fromRGB(120, 240, 255), mult = 128 },
}

-- Mutations, 8 tiers. Multiplier applies on top of rarity.
Config.MUTATIONS = {
	{ name = "Plain", mult = 1 },
	{ name = "Sprinkled", mult = 2 },
	{ name = "Gold-Plated", mult = 3 },
	{ name = "Neon", mult = 4 },
	{ name = "Deep-Fried", mult = 5 },
	{ name = "Inflated", mult = 6 },
	{ name = "Glitched", mult = 7 },
	{ name = "Cosmic", mult = 10 },
	{ name = "Haunted", mult = 13 },
}

-- Base price / income per type (Common, no mutation). Rarity and mutation
-- multipliers stack on top.
Config.TYPE_BASE = {
	Pawn = { price = 50, income = 2 },
	Knight = { price = 250, income = 9 },
	Bishop = { price = 600, income = 20 },
	Rook = { price = 1500, income = 48 },
	Queen = { price = 5000, income = 150 },
	King = { price = 20000, income = 600 },
}

-- Timed global events, on rotation. duration in seconds.
Config.EVENTS = {
	{
		name = "BLITZ STORM!",
		desc = "All pieces move 2x, income 2x",
		color = Color3.fromRGB(255, 200, 40),
		duration = 30,
		incomeMult = 2,
	},
	{
		name = "CHECKMATE RUSH!",
		desc = "A King spawns on the parade",
		color = Color3.fromRGB(255, 80, 60),
		duration = 25,
		incomeMult = 1,
	},
	{
		name = "EN PASSANT RAID!",
		desc = "Rival thieves swarm — whack them!",
		color = Color3.fromRGB(110, 220, 110),
		duration = 25,
		incomeMult = 1,
	},
	{
		name = "GOLDEN RUNAWAY!",
		desc = "A golden piece flees — catch it!",
		color = Color3.fromRGB(255, 220, 80),
		duration = 20,
		incomeMult = 1,
	},
	{
		name = "NIGHT RAID!",
		desc = "The Raccoon King steals your pieces!",
		color = Color3.fromRGB(180, 90, 255),
		duration = 30,
		incomeMult = 1,
	},
	{
		name = "TIDAL WAVE!",
		desc = "Bonus zone floods the arena — 3x income",
		color = Color3.fromRGB(90, 160, 255),
		duration = 20,
		incomeMult = 3,
	},
}
Config.EVENT_GAP = 45 -- seconds of calm between events
Config.EVENT_TEASER = 10 -- seconds of "NEXT: ..." warning before an event

-- Rival boards: 5 named AI owners. Lock cycles open/closed.
Config.RIVALS = {
	{ name = "BIG LOU", color = Color3.fromRGB(255, 120, 60) },
	{ name = "GRANDMA GERT", color = Color3.fromRGB(255, 150, 200) },
	{ name = "LEO TAMER-23", color = Color3.fromRGB(90, 220, 160) },
	{ name = "THE ROOK", color = Color3.fromRGB(160, 140, 255) },
	{ name = "PAWN SHOP PETE", color = Color3.fromRGB(220, 200, 90) },
}
Config.LOCK_OPEN = 40 -- seconds a rival board stays open
Config.LOCK_CLOSED = 25 -- seconds a rival board stays locked

-- Whack (anti-thief mallet).
Config.WHACK_RANGE = 12
Config.WHACK_COOLDOWN = 0.35
Config.WHACK_REWARD = 250

-- Rebirth: costs a round number, multiplies ALL income.
Config.REBIRTH_BASE_COST = 100_000_000
Config.REBIRTH_MULT = 3

-- Upgrades shop: 6 upgrades, each 3 levels.
Config.UPGRADES = {
	{ id = "income", name = "Golden Scepter", desc = "+25% income / level", base = 10000, mult = 3 },
	{ id = "speed", name = "Knight Boots", desc = "+3 walk speed / level", base = 8000, mult = 3 },
	{ id = "lock", name = "Iron Fortress", desc = "+10s lock time / level", base = 12000, mult = 3 },
	{ id = "whack", name = "Rook Mallet+", desc = "+4 whack range / level", base = 6000, mult = 3 },
	{ id = "parade", name = "Parade Horn", desc = "Rarer pieces parade / level", base = 15000, mult = 3 },
	{ id = "luck", name = "Lucky Dice", desc = "+15% mutation chance / level", base = 20000, mult = 3 },
}

-- Quests: 8, always visible, cash rewards.
Config.QUESTS = {
	{ id = "buy1", name = "Buy your first piece", target = 1, reward = 500 },
	{ id = "buy5", name = "Own 5 pieces", target = 5, reward = 2500 },
	{ id = "capture2", name = "Capture 2 rival pieces", target = 2, reward = 5000 },
	{ id = "queen1", name = "Buy a Queen", target = 1, reward = 8000 },
	{ id = "whack3", name = "Whack 3 thieves", target = 3, reward = 3000 },
	{ id = "row8", name = "Fill a full row of 8", target = 8, reward = 10000 },
	{ id = "event1", name = "Survive a Blitz Storm unhit", target = 1, reward = 6000 },
	{ id = "rebirth1", name = "Rebirth once", target = 1, reward = 50000 },
}

-- Codex milestones: pieces found -> income multiplier.
Config.CODEX_MILESTONES = {
	{ found = 6, mult = 1.25 },
	{ found = 12, mult = 1.5 },
	{ found = 18, mult = 2 },
	{ found = 24, mult = 2.5 },
	{ found = 36, mult = 3 },
	{ found = 48, mult = 5 },
}

-- Parade: how many pedestals, how fast pieces march.
Config.PARADE_SLOTS = 6
Config.PARADE_SPEED = 4 -- studs per second along the lane
Config.PARADE_RESPAWN = 8 -- seconds before a bought slot refills

-- Feel table (game-feel P-29): every juice number in one place.
Config.FEEL = table.freeze({
	ShakeAddSteal = 0.5,
	ShakeAddHurt = 0.3,
	ShakeDecay = 1.3,
	ShakeMaxAngle = 2.5,
	HitStopLight = 0.06,
	HitStopHeavy = 0.12,
	PickupPopScale = 1.25,
	PickupPopTime = 0.2,
	LabelRiseTime = 1.1,
	LabelRiseHeight = 2.5,
	BannerInTime = 0.35,
	BannerHoldTime = 2.6,
	SquashAmount = 0.3,
	SquashTime = 0.12,
	CountUpTime = 0.6,
	ParticleBurst = 12,
})

Config.DATASTORE_KEY = "ChessBrainrot_v2"
Config.AUTOSAVE_EVERY = 120 -- seconds

return Config
