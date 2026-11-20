--!strict
-- BoardMath: ONE function owns every square position. squareToWorld is the
-- single source of truth for grid placement — the board builder, the parade,
-- piece placement, move highlights and the client all call it. Exact grid
-- snap: a piece resting on a square sits at its exact centre, never
-- eyeballed. a1 is the origin corner (file 1, rank 1).

local Config = require(script.Parent.Config)

local BoardMath = {}

export type Square = { file: number, rank: number }

-- The player board is centred on (0, 0) in world XZ, top face at Y = 0.
-- Square (file, rank) centre:
function BoardMath.squareToWorld(file: number, rank: number, y: number?): Vector3
	local half = (Config.BOARD_FILES * Config.SQUARE) / 2
	local x = -half + (file - 0.5) * Config.SQUARE
	local z = -half + (rank - 0.5) * Config.SQUARE
	return Vector3.new(x, y or 0, z)
end

-- Inverse: world position -> nearest square, or nil if off the board.
function BoardMath.worldToSquare(pos: Vector3): Square?
	local half = (Config.BOARD_FILES * Config.SQUARE) / 2
	local file = math.floor((pos.X + half) / Config.SQUARE) + 1
	local rank = math.floor((pos.Z + half) / Config.SQUARE) + 1
	if file < 1 or file > Config.BOARD_FILES or rank < 1 or rank > Config.BOARD_RANKS then
		return nil
	end
	return { file = file, rank = rank }
end

function BoardMath.squareKey(file: number, rank: number): string
	return file .. "," .. rank
end

function BoardMath.squareName(file: number, rank: number): string
	return string.char(96 + file) .. tostring(rank)
end

-- Real chess moves per type, from one square. Returns a list of squares.
-- Used for the legal-move highlight (green = move, red = capture).
function BoardMath.legalTargets(typeName: string, file: number, rank: number): { Square }
	local out: { Square } = {}
	local function add(f: number, r: number)
		if f >= 1 and f <= 8 and r >= 1 and r <= 8 then
			table.insert(out, { file = f, rank = r })
		end
	end
	local function slide(df: number, dr: number)
		local f, r = file + df, rank + dr
		while f >= 1 and f <= 8 and r >= 1 and r <= 8 do
			table.insert(out, { file = f, rank = r })
			f += df
			r += dr
		end
	end

	if typeName == "Pawn" then
		add(file, rank + 1)
		add(file, rank + 2)
		add(file - 1, rank + 1)
		add(file + 1, rank + 1)
	elseif typeName == "Knight" then
		for _, d in { { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } } do
			add(file + d[1], rank + d[2])
		end
	elseif typeName == "Bishop" then
		slide(1, 1)
		slide(1, -1)
		slide(-1, 1)
		slide(-1, -1)
	elseif typeName == "Rook" then
		slide(1, 0)
		slide(-1, 0)
		slide(0, 1)
		slide(0, -1)
	elseif typeName == "Queen" then
		slide(1, 1)
		slide(1, -1)
		slide(-1, 1)
		slide(-1, -1)
		slide(1, 0)
		slide(-1, 0)
		slide(0, 1)
		slide(0, -1)
	elseif typeName == "King" then
		for df = -1, 1 do
			for dr = -1, 1 do
				if df ~= 0 or dr ~= 0 then
					add(file + df, rank + dr)
				end
			end
		end
	end
	return out
end

return BoardMath
