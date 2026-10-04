--[[ InstallerBrume -- Brume V2 : NAPPES de brouillard graduelles au bord de la map (ModuleScript, ServerStorage).
	Le bord de la map (~ +/- 1 350 studs) est entoure d'anneaux carres de nappes translucides (texture de fumee douce sur
	des Parts invisibles) : de plus en plus opaques vers l'exterieur (0,9 -> 0,12 de transparence), rien a l'interieur.
	7 rangs de nappes verticales (de plus en plus hautes) + 4 anneaux de brume rampante au sol. La couleur est celle de
	l'Atmosphere du jeu (le brouillard se fond dans le ciel et les lointains), jamais lumineuse.
	Appele par InstallerMap ; relancable seul dans la barre de commandes :  require(game.ServerStorage.InstallerBrume)()
	(il retrouve la map, cache les anciens rideaux "Brume_Rideau" et refait le dossier Workspace/Brume/Nappes).
]]
local Lighting = game:GetService("Lighting")
local SS = game:GetService("ServerStorage")

local TEX = "rbxasset://textures/particles/smoke_main.dds"
-- rangs verticaux : { distance au-dela du bord (studs), transparence, hauteur, taille des volutes }
local RANGS = {
	{ -60, 0.90, 70, 110 }, { 20, 0.80, 95, 140 }, { 110, 0.68, 120, 170 }, { 220, 0.55, 150, 210 },
	{ 360, 0.40, 190, 260 }, { 540, 0.25, 240, 320 }, { 800, 0.12, 300, 400 },
}
-- brume rampante au sol : { debut, fin (au-dela du bord), transparence, hauteur, taille des volutes }
local SOLS = { { -120, 0, 0.88, 6, 160 }, { -40, 260, 0.72, 14, 220 }, { 120, 700, 0.55, 30, 300 }, { 500, 1400, 0.40, 60, 420 } }

local function essayer(f) return pcall(f) end

local function trouverMap()
	for _, enfant in ipairs(workspace:GetChildren()) do
		if enfant:IsA("Model") or enfant:IsA("Folder") then
			for _, d in ipairs(enfant:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Sol_Herbe_0_0", 1, true) then return enfant, d end
			end
		end
	end
end

return function(map, offset, brumeDossier)
	local ref
	if not map then map, ref = trouverMap() end
	assert(map, "Map introuvable (Sol_Herbe_0_0)")
	if not offset then
		if not ref then for _, d in ipairs(map:GetDescendants()) do if d:IsA("BasePart") and string.find(d.Name, "Sol_Herbe_0_0", 1, true) then ref = d break end end end
		local D = SS:FindFirstChild("DonneesArbres") and require(SS.DonneesArbres)
		offset = (ref and D) and (ref.Position - D.reference.position) or Vector3.zero
	end
	if not brumeDossier then
		brumeDossier = workspace:FindFirstChild("Brume")
		if not brumeDossier then brumeDossier = Instance.new("Model"); brumeDossier.Name = "Brume"; brumeDossier.Parent = workspace end
	end
	-- anciens rideaux du FBX (mur lumineux) : caches
	local rideaux = 0
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") and string.find(p.Name, "Brume_Rideau", 1, true) then p.Transparency = 1; rideaux = rideaux + 1 end
	end
	-- demi-largeur de la map d'apres les dalles d'herbe
	local demiMap = 0
	for _, prt in ipairs(map:GetDescendants()) do
		if prt:IsA("BasePart") and string.find(prt.Name, "Sol_Herbe_", 1, true) then
			local l = prt.Position - offset
			demiMap = math.max(demiMap, math.abs(l.X) + prt.Size.X / 2, math.abs(l.Z) + prt.Size.Z / 2)
		end
	end
	if demiMap < 500 or demiMap > 4000 then demiMap = 1348 end
	-- couleur : celle de l'Atmosphere (ciel / lointains), un peu eclaircie
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local couleur = atmo and atmo.Decay:Lerp(atmo.Color, 0.5):Lerp(Color3.new(1, 1, 1), 0.12) or Color3.fromRGB(255, 220, 196)

	local ancien = brumeDossier:FindFirstChild("Nappes"); if ancien then ancien:Destroy() end
	local nappes = Instance.new("Model"); nappes.Name = "Nappes"; nappes.Parent = brumeDossier
	essayer(function() nappes.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	local n = 0
	local function texture(part, face, transp, tuile, du, dv)
		local t = Instance.new("Texture"); t.Texture = TEX; t.Face = face; t.Color3 = couleur
		t.Transparency = transp; t.StudsPerTileU = tuile; t.StudsPerTileV = tuile
		t.OffsetStudsU = du; t.OffsetStudsV = dv; t.Parent = part
	end
	local function nappe(nom, cf, taille, faces, transp, tuile, graine)
		local p = Instance.new("Part"); p.Name = nom; p.Anchored = true
		p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
		p.Transparency = 1; p.Size = taille; p.CFrame = cf; p.Parent = nappes
		for k, f in ipairs(faces) do texture(p, f, transp, tuile, (graine * 37 + k * 53) % tuile, (graine * 71 + k * 29) % tuile) end
		n = n + 1
		return p
	end
	local c = offset
	local FB, LR, TB = {Enum.NormalId.Front, Enum.NormalId.Back}, {Enum.NormalId.Left, Enum.NormalId.Right}, {Enum.NormalId.Top, Enum.NormalId.Bottom}
	for r, R in ipairs(RANGS) do
		local d, transp, h, tuile = demiMap + R[1], R[2], R[3], R[4]
		local long = 2 * d + 40
		nappe("Nappe_N_" .. r, CFrame.new(c + Vector3.new(0, h / 2, -d)), Vector3.new(long, h, 1), FB, transp, tuile, r * 4 + 1)
		nappe("Nappe_S_" .. r, CFrame.new(c + Vector3.new(0, h / 2, d)), Vector3.new(long, h, 1), FB, transp, tuile, r * 4 + 2)
		nappe("Nappe_E_" .. r, CFrame.new(c + Vector3.new(d, h / 2, 0)), Vector3.new(1, h, long), LR, transp, tuile, r * 4 + 3)
		nappe("Nappe_O_" .. r, CFrame.new(c + Vector3.new(-d, h / 2, 0)), Vector3.new(1, h, long), LR, transp, tuile, r * 4 + 4)
	end
	for r, S in ipairs(SOLS) do
		local d0, d1, transp, y, tuile = demiMap + S[1], demiMap + S[2], S[3], S[4], S[5]
		local larg, mil = d1 - d0, (d0 + d1) / 2
		nappe("Sol_N_" .. r, CFrame.new(c + Vector3.new(0, y, -mil)), Vector3.new(2 * d1, 1, larg), TB, transp, tuile, 100 + r * 4 + 1)
		nappe("Sol_S_" .. r, CFrame.new(c + Vector3.new(0, y, mil)), Vector3.new(2 * d1, 1, larg), TB, transp, tuile, 100 + r * 4 + 2)
		nappe("Sol_E_" .. r, CFrame.new(c + Vector3.new(mil, y, 0)), Vector3.new(larg, 1, 2 * d0), TB, transp, tuile, 100 + r * 4 + 3)
		nappe("Sol_O_" .. r, CFrame.new(c + Vector3.new(-mil, y, 0)), Vector3.new(larg, 1, 2 * d0), TB, transp, tuile, 100 + r * 4 + 4)
	end
	print(("[Brume] %d nappes graduelles autour de la map (bord a %d studs), %d rideaux caches, couleur %s"):format(n, demiMap, rideaux, tostring(couleur)))
	return n, demiMap
end
