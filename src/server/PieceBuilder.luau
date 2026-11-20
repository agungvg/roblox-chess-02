--!strict
-- PieceBuilder: turns a PieceDef into a Model of Parts. Every piece is a
-- human-proportioned character (head / torso / limbs in proportion, distinct
-- silhouette per type) with a face on a SurfaceGui — the reference image's
-- expressive faces, built from text so no uploaded asset is needed.
-- Accessories per type (Lyso's rule): Pawn shield+sword, Knight
-- plume+lance, Bishop crozier+gold orb, Rook banner+gold shoulder pads,
-- Queen scepter+gold waist band, King greatsword+gold epaulettes.
-- Scale rule: total height == Config.PIECE_HEIGHT[type].

local PieceData = require(game:GetService("ReplicatedStorage").Shared.PieceData)

local PieceBuilder = {}

local GOLD = Color3.fromRGB(255, 210, 60)
local DARK = Color3.fromRGB(40, 32, 48)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	return p
end

local function faceGui(head: Part, faceText: string, color: Color3): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = faceText
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = gui
	return gui
end

-- Type silhouette extras, built on top of the shared humanoid body.
-- h is the total height; all offsets are fractions of h.
local function buildSilhouette(model: Model, typeName: string, h: number, bodyColor: Color3, trimColor: Color3)
	local topY = h * 0.98
	if typeName == "Pawn" then
		-- Round helmet
		local helmet = part("Helmet", Vector3.new(h * 0.34, h * 0.12, h * 0.34), trimColor, Enum.Material.Metal)
		helmet.Shape = Enum.PartType.Ball
		helmet.Position = Vector3.new(0, topY - h * 0.06, 0)
		helmet.Parent = model
	elseif typeName == "Knight" then
		-- Horse head: a wedge-ish snout + ears, facing forward
		local snout = part("Snout", Vector3.new(h * 0.16, h * 0.14, h * 0.3), bodyColor)
		snout.Position = Vector3.new(0, topY - h * 0.1, h * 0.14)
		snout.Parent = model
		for _, sx in { -1, 1 } do
			local ear = part("Ear", Vector3.new(h * 0.06, h * 0.14, h * 0.06), bodyColor)
			ear.Position = Vector3.new(sx * h * 0.1, topY + h * 0.04, -h * 0.04)
			ear.Parent = model
		end
	elseif typeName == "Bishop" then
		-- Mitre: tall slit hat
		local mitre = part("Mitre", Vector3.new(h * 0.2, h * 0.24, h * 0.1), trimColor)
		mitre.Position = Vector3.new(0, topY + h * 0.06, 0)
		mitre.Parent = model
		local slit = part("MitreSlit", Vector3.new(h * 0.03, h * 0.18, h * 0.12), DARK)
		slit.Position = Vector3.new(0, topY + h * 0.06, 0)
		slit.Parent = model
	elseif typeName == "Rook" then
		-- Castle crenellations: four battlements on top
		for _, dx in { -1, 1 } do
			for _, dz in { -1, 1 } do
				local cren = part("Crenellation", Vector3.new(h * 0.09, h * 0.1, h * 0.09), bodyColor)
				cren.Position = Vector3.new(dx * h * 0.11, topY + h * 0.03, dz * h * 0.11)
				cren.Parent = model
			end
		end
	elseif typeName == "Queen" then
		-- Coronet: small crown band with points
		for i = 1, 5 do
			local ang = (i - 3) * 0.5
			local point = part("CoronetPoint", Vector3.new(h * 0.05, h * 0.1, h * 0.05), GOLD, Enum.Material.Metal)
			point.Position = Vector3.new(math.sin(ang) * h * 0.13, topY + h * 0.04, math.cos(ang) * h * 0.13)
			point.Parent = model
		end
	elseif typeName == "King" then
		-- Full crown: band + five tall points + jewel
		local band = part("CrownBand", Vector3.new(h * 0.34, h * 0.08, h * 0.34), GOLD, Enum.Material.Metal)
		band.Shape = Enum.PartType.Cylinder
		band.CFrame = CFrame.new(0, topY - h * 0.02, 0) * CFrame.Angles(0, 0, math.rad(90))
		band.Parent = model
		for i = 1, 5 do
			local ang = (i - 3) * 0.55
			local point = part("CrownPoint", Vector3.new(h * 0.06, h * 0.16, h * 0.06), GOLD, Enum.Material.Metal)
			point.Position = Vector3.new(math.sin(ang) * h * 0.15, topY + h * 0.06, math.cos(ang) * h * 0.15)
			point.Parent = model
		end
		local jewel =
			part("Jewel", Vector3.new(h * 0.08, h * 0.08, h * 0.08), Color3.fromRGB(255, 60, 90), Enum.Material.Neon)
		jewel.Shape = Enum.PartType.Ball
		jewel.Position = Vector3.new(0, topY + h * 0.02, h * 0.16)
		jewel.Parent = model
	end
end

local function buildAccessory(model: Model, typeName: string, h: number, bodyColor: Color3)
	local handY = h * 0.52
	local side = h * 0.24
	if typeName == "Pawn" then
		-- Shield on the left arm, sword in the right hand
		local shield =
			part("Shield", Vector3.new(h * 0.05, h * 0.26, h * 0.2), Color3.fromRGB(90, 140, 255), Enum.Material.Metal)
		shield.Position = Vector3.new(-side, handY, 0)
		shield.Parent = model
		local blade = part(
			"SwordBlade",
			Vector3.new(h * 0.04, h * 0.3, h * 0.04),
			Color3.fromRGB(230, 230, 240),
			Enum.Material.Metal
		)
		blade.Position = Vector3.new(side, handY + h * 0.16, 0)
		blade.Parent = model
		local hilt = part("SwordHilt", Vector3.new(h * 0.08, h * 0.05, h * 0.08), GOLD, Enum.Material.Metal)
		hilt.Position = Vector3.new(side, handY + h * 0.02, 0)
		hilt.Parent = model
	elseif typeName == "Knight" then
		-- Plume on the helmet, lance in the right hand
		local plume =
			part("Plume", Vector3.new(h * 0.06, h * 0.2, h * 0.12), Color3.fromRGB(255, 60, 90), Enum.Material.Neon)
		plume.Position = Vector3.new(0, h * 0.98, -h * 0.06)
		plume.Parent = model
		local lance = part("Lance", Vector3.new(h * 0.05, h * 0.62, h * 0.05), Color3.fromRGB(160, 110, 60))
		lance.Position = Vector3.new(side, handY + h * 0.2, 0)
		lance.Parent = model
		local tip = part(
			"LanceTip",
			Vector3.new(h * 0.07, h * 0.12, h * 0.07),
			Color3.fromRGB(230, 230, 240),
			Enum.Material.Metal
		)
		tip.Position = Vector3.new(side, handY + h * 0.52, 0)
		tip.Parent = model
	elseif typeName == "Bishop" then
		-- Crozier (curved staff) + gold orb in the left hand
		local staff = part("Crozier", Vector3.new(h * 0.05, h * 0.66, h * 0.05), GOLD, Enum.Material.Metal)
		staff.Position = Vector3.new(side, handY + h * 0.2, 0)
		staff.Parent = model
		local orb = part("Orb", Vector3.new(h * 0.12, h * 0.12, h * 0.12), GOLD, Enum.Material.Neon)
		orb.Shape = Enum.PartType.Ball
		orb.Position = Vector3.new(-side, handY + h * 0.06, 0)
		orb.Parent = model
	elseif typeName == "Rook" then
		-- Banner on the back, gold shoulder pads
		local banner = part("Banner", Vector3.new(h * 0.3, h * 0.4, h * 0.03), Color3.fromRGB(200, 40, 60))
		banner.Position = Vector3.new(0, h * 0.62, -h * 0.2)
		banner.Parent = model
		for _, sx in { -1, 1 } do
			local pad = part("ShoulderPad", Vector3.new(h * 0.12, h * 0.08, h * 0.16), GOLD, Enum.Material.Metal)
			pad.Position = Vector3.new(sx * side, h * 0.78, 0)
			pad.Parent = model
		end
	elseif typeName == "Queen" then
		-- Scepter in the right hand, gold waist band
		local rod = part("ScepterRod", Vector3.new(h * 0.05, h * 0.5, h * 0.05), GOLD, Enum.Material.Metal)
		rod.Position = Vector3.new(side, handY + h * 0.16, 0)
		rod.Parent = model
		local gem =
			part("ScepterGem", Vector3.new(h * 0.1, h * 0.1, h * 0.1), Color3.fromRGB(255, 60, 200), Enum.Material.Neon)
		gem.Shape = Enum.PartType.Ball
		gem.Position = Vector3.new(side, handY + h * 0.44, 0)
		gem.Parent = model
		local waist = part("WaistBand", Vector3.new(h * 0.36, h * 0.06, h * 0.36), GOLD, Enum.Material.Metal)
		waist.Position = Vector3.new(0, h * 0.42, 0)
		waist.Parent = model
	elseif typeName == "King" then
		-- Greatsword held upright, gold epaulettes
		local blade = part(
			"GreatBlade",
			Vector3.new(h * 0.07, h * 0.55, h * 0.03),
			Color3.fromRGB(230, 230, 240),
			Enum.Material.Metal
		)
		blade.Position = Vector3.new(side, handY + h * 0.3, 0)
		blade.Parent = model
		for _, sx in { -1, 1 } do
			local ep = part("Epaulette", Vector3.new(h * 0.14, h * 0.07, h * 0.18), GOLD, Enum.Material.Metal)
			ep.Position = Vector3.new(sx * side, h * 0.8, 0)
			ep.Parent = model
		end
	end
end

-- Mutation tint: a visible aura ring + colour shift on the trim.
local MUTATION_RING: { [number]: Color3? } = {
	[1] = nil,
	[2] = Color3.fromRGB(255, 180, 220),
	[3] = Color3.fromRGB(255, 210, 60),
	[4] = Color3.fromRGB(80, 255, 220),
	[5] = Color3.fromRGB(255, 140, 40),
	[6] = Color3.fromRGB(255, 120, 220),
	[7] = Color3.fromRGB(140, 80, 255),
	[8] = Color3.fromRGB(120, 220, 255),
	[9] = Color3.fromRGB(180, 60, 255),
}

function PieceBuilder.build(def: PieceData.PieceDef, mutationIndex: number): Model
	local h = def.scale
	local model = Instance.new("Model")
	model.Name = def.name

	local bodyColor = def.color
	local trimColor = Color3.fromRGB(255, 255, 255)

	-- Base plinth (cylinder lying flat)
	local base = part("Base", Vector3.new(h * 0.42, h * 0.06, h * 0.42), DARK, Enum.Material.Metal)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(0, h * 0.03, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = model

	-- Torso (humanoid proportion: ~34% of height)
	local torso = part("Torso", Vector3.new(h * 0.34, h * 0.34, h * 0.24), bodyColor)
	torso.Position = Vector3.new(0, h * 0.25, 0)
	torso.Parent = model

	-- Belt trim
	local belt = part("Belt", Vector3.new(h * 0.36, h * 0.05, h * 0.26), trimColor)
	belt.Position = Vector3.new(0, h * 0.12, 0)
	belt.Parent = model

	-- Arms (left/right, hanging at the sides)
	for _, sx in { -1, 1 } do
		local arm = part("Arm", Vector3.new(h * 0.09, h * 0.3, h * 0.09), bodyColor)
		arm.Position = Vector3.new(sx * h * 0.23, h * 0.26, 0)
		arm.Parent = model
	end

	-- Head (sphere, ~20% of height) with the face on it
	local head = part("Head", Vector3.new(h * 0.28, h * 0.28, h * 0.28), bodyColor)
	head.Shape = Enum.PartType.Ball
	head.Position = Vector3.new(0, h * 0.56, 0)
	head.Parent = model
	faceGui(head, def.face, Color3.fromRGB(20, 16, 24))

	-- Type silhouette + accessories
	buildSilhouette(model, def.typeName, h, bodyColor, trimColor)
	buildAccessory(model, def.typeName, h, bodyColor)

	-- Mutation aura ring under the base
	local ringColor = MUTATION_RING[mutationIndex]
	if ringColor then
		local ring = part("MutationRing", Vector3.new(h * 0.56, h * 0.03, h * 0.56), ringColor, Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(0, h * 0.015, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = model
	end

	-- Rarity name tag (BillboardGui, readable in screenshots)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, h + 0.8, 0)
	tag.AlwaysOnTop = true
	tag.Parent = model
	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 0.35
	tagLabel.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	tagLabel.Text = def.name .. "\n" .. def.rarity .. " · " .. PieceData.mutationName(mutationIndex)
	tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tagLabel.Font = Enum.Font.FredokaOne
	tagLabel.TextScaled = true
	tagLabel.Parent = tag

	model.PrimaryPart = torso
	return model
end

return PieceBuilder
