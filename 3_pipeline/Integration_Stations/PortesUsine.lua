--[[ PortesUsine (Script, ServerScriptService) — double portes coulissantes vitrees des usines.
	Chaque usine a, devant la sortie lumineuse des voitures, un auvent vitre (NE_Avancee...) de 20,7 studs de profondeur
	dont les deux parois laterales sont en verre (a u = +-67,5 studs de l'axe de la diagonale, entre r = 175,7 et 196,4
	studs du centre de la map, 62 studs de haut). On pose dans chaque paroi une double porte coulissante "de magasin" :
	ouverture de 16 studs de large x 22 de haut, deux vantaux vitres de 8 studs qui coulissent tous les deux vers le fond
	(dans le batiment) quand un joueur approche, et se referment derriere lui. Les vantaux sont animes chez chaque joueur
	(PortesClient) : le serveur ne fait que construire les portes et remplacer la boite de collision de la paroi
	(qui bloquait tout le mur) par des morceaux autour de l'ouverture.
	Les parois sont posees en repere de la map ; le decalage d'import (Workspace.DecalageMap) est ajoute.
]]
local CollectionService = game:GetService("CollectionService")

local R_MUR0, R_MUR1 = 175.7, 196.4          -- profondeur de l'auvent (distances au centre de la map, le long de la diagonale)
local U_PAROI = 67.5                          -- demi-largeur de l'auvent (position des parois laterales)
local H_MUR = 62.07                           -- hauteur des parois
local LARGEUR, HAUTEUR = 16, 22               -- ouverture de la porte
local EPAISSEUR = 0.5
local COULEUR_CADRE = Color3.fromRGB(38, 40, 44)
local COULEUR_VERRE = Color3.fromRGB(180, 215, 235)

local function decalage()
	local d = workspace:GetAttribute("DecalageMap")
	return (typeof(d) == "Vector3") and d or Vector3.zero
end

local function piece(nom, cf, taille, couleur, materiau, transparence, parent)
	local p = Instance.new("Part")
	p.Name = nom
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = false
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = materiau
	p.Transparency = transparence or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- retire la boite de collision de la paroi (Collisions/*, 20,7 x 62 x 1,2 au centre de la paroi)
local function retirerCollisionParoi(centre)
	local coll = workspace:FindFirstChild("Collisions", true)
	if not coll then return end
	for _, p in ipairs(coll:GetChildren()) do
		if p:IsA("BasePart") and (p.Position - centre).Magnitude < 3 and math.abs(p.Size.Y - H_MUR) < 1 and p.Size.X < 25 then
			p:Destroy()
			return true
		end
	end
	return false
end

local dossier = Instance.new("Folder"); dossier.Name = "PortesUsines"; dossier.Parent = workspace
local n = 0
for _, coin in ipairs({{"NE", 1, -1}, {"NO", -1, -1}, {"SE", 1, 1}, {"SO", -1, 1}}) do
	local nom, sx, sz = coin[1], coin[2], coin[3]
	local d = Vector3.new(sx, 0, sz).Unit                                  -- centre -> usine (le long de la diagonale)
	local u = Vector3.new(-sz, 0, sx).Unit                                 -- perpendiculaire (le long de la facade)
	for _, cote in ipairs({-1, 1}) do
		local rMilieu = (R_MUR0 + R_MUR1) / 2
		local centreParoi = d * rMilieu + u * (cote * U_PAROI) + decalage()
		-- repere de la porte : X = le long de la paroi vers le fond (+d), Y = haut, Z = normale (vers l'exterieur de l'auvent)
		local F = CFrame.fromMatrix(Vector3.new(centreParoi.X, 0, centreParoi.Z), d, Vector3.yAxis)
		local porte = Instance.new("Model"); porte.Name = "PorteUsine_" .. nom .. (cote > 0 and "_G" or "_D")
		porte.Parent = dossier
		-- cadre : deux montants et un linteau (sur la face exterieure de la paroi)
		local x0, x1 = -LARGEUR / 2, LARGEUR / 2
		piece("Montant", F * CFrame.new(x0 - 0.5, HAUTEUR / 2, 0), Vector3.new(1, HAUTEUR, 1.6), COULEUR_CADRE, Enum.Material.Metal, 0, porte).CanCollide = true
		piece("Montant", F * CFrame.new(x1 + 0.5, HAUTEUR / 2, 0), Vector3.new(1, HAUTEUR, 1.6), COULEUR_CADRE, Enum.Material.Metal, 0, porte).CanCollide = true
		piece("Linteau", F * CFrame.new(0, HAUTEUR + 0.5, 0), Vector3.new(LARGEUR + 2, 1, 1.6), COULEUR_CADRE, Enum.Material.Metal, 0, porte).CanCollide = true
		-- deux vantaux vitres (fermes : cote a cote dans l'ouverture ; ouverts : tous deux vers le fond, x = +12 et +20)
		local vA = piece("VantailA", F * CFrame.new(-LARGEUR / 4, HAUTEUR / 2, 0), Vector3.new(LARGEUR / 2 - 0.2, HAUTEUR - 0.6, EPAISSEUR), COULEUR_VERRE, Enum.Material.Glass, 0.35, porte)
		local vB = piece("VantailB", F * CFrame.new(LARGEUR / 4, HAUTEUR / 2, 0), Vector3.new(LARGEUR / 2 - 0.2, HAUTEUR - 0.6, EPAISSEUR), COULEUR_VERRE, Enum.Material.Glass, 0.35, porte)
		vA.CanCollide = true; vB.CanCollide = true
		for _, v in ipairs({vA, vB}) do
			-- barre de poignee soudee au vantail (non ancree : elle suit le vantail quand il coulisse)
			local barre = piece("Poignee", v.CFrame * CFrame.new(0, 0, EPAISSEUR / 2 + 0.15), Vector3.new(LARGEUR / 2 - 0.2, 0.6, 0.3), COULEUR_CADRE, Enum.Material.Metal, 0, v)
			barre.CanCollide = false; barre.CanQuery = false; barre.Massless = true; barre.Anchored = false
			local w = Instance.new("WeldConstraint"); w.Part0 = v; w.Part1 = barre; w.Parent = v
		end
		porte:SetAttribute("Course", LARGEUR)                              -- deplacement de chaque vantail a l'ouverture (studs, vers +X)
		porte:SetAttribute("Portee", 26)                                   -- distance d'ouverture (studs)
		porte:SetAttribute("Cadre", F)
		porte.PrimaryPart = vA
		CollectionService:AddTag(porte, "PorteCoulissante")
		-- collision de la paroi : on retire la boite entiere et on remet le mur autour de l'ouverture
		if retirerCollisionParoi(centreParoi + Vector3.new(0, H_MUR / 2, 0)) then
			local longueur = R_MUR1 - R_MUR0
			local coll = Instance.new("Folder"); coll.Name = "CollisionParoi"; coll.Parent = porte
			local function mur(cx, cy, lx, ly)
				local p = piece("Mur", F * CFrame.new(cx, cy, 0), Vector3.new(lx, ly, 1.2), COULEUR_CADRE, Enum.Material.SmoothPlastic, 1, coll)
				p.CanCollide = true; p.CanQuery = false
			end
			local bord = LARGEUR / 2 + 1                                                    -- bord exterieur des montants
			local reste = longueur / 2 - bord                                               -- paroi restante de chaque cote
			mur(0, (H_MUR + HAUTEUR + 1) / 2, longueur, H_MUR - HAUTEUR - 1)                -- au-dessus du linteau
			if reste > 0.2 then
				mur(-(bord + longueur / 2) / 2, H_MUR / 2, reste, H_MUR)                    -- cote avant (vers le centre)
				mur((bord + longueur / 2) / 2, H_MUR / 2, reste, H_MUR)                     -- cote fond (vers l'usine)
			end
		end
		n += 1
	end
end
print(("[Portes] %d doubles portes coulissantes posees sur les auvents des usines"):format(n))
