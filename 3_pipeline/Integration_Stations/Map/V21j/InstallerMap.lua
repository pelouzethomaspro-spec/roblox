--[[ InstallerMap -- installation optimisee de la map (V18), a lancer UNE FOIS dans Studio.

Mode d'emploi
  1. Importer MAP_MOTIFS_V17_AVEC_CHAINES.fbx (dans Workspace) : sol, voirie,
     tunnels, square central et les 4 chaines de production deja placees
     (pieces NE_CP_..., NO_CP_..., SO_CP_..., SE_CP_...). Importer aussi
     ARBRES_V17.fbx (Workspace ou ServerStorage).
     V17m : clic droit sur ServerStorage > "Insert from File..." > CAMIONS_V17.rbxm
     (les 3 vehicules : Van, TallVan, Camion ; ne pas les tourner).
     V18 : Script PortesSas dans ServerScriptService (portes coulissantes des sas des chaines).
  2. Mettre ces 3 ModuleScripts dans ServerStorage : InstallerMap, DonneesCollisions,
     DonneesArbres (copier-coller le contenu des fichiers .lua).
  3. Barre de commandes (View > Command Bar) :
        require(game.ServerStorage.InstallerMap)()
  4. Sauvegarder la place. On peut ensuite supprimer les 3 ModuleScripts et la
     bibliotheque d'arbres.

Ce que fait le script (guide d'optimisation) :
  * tout est Anchored ; les meshes detailles n'ont ni collision, ni Touch, ni
    requetes (CanCollide / CanTouch / CanQuery = false), CollisionFidelity = Box,
    RenderFidelity = Automatic (LOD) ;
  * la collision est faite par ~3 000 Parts invisibles et simples (sol, chaussee,
    trottoirs, parvis, murs, cloisons, bornes, butees, square, troncs) ;
  * CastShadow = false sur la voirie, le sol et les petits objets ;
  * le batiment vert (Vert_Batiment, Vert_Parvis) est un mesh visuel, ses murs,
    sols et passerelles ont des collisions invisibles ; les arbres sont des copies des 27 modeles de la
    bibliotheque (instancing) ;
  * PointLights sans ombre (plafonniers du batiment vert + square) ;
  * rangement en Models / Folders, ModelStreamingMode (Atomic / Persistent),
    LevelOfDetail = StreamingMesh sur les batiments ;
  * Workspace.StreamingEnabled = true, rayons de streaming, Lighting.Technology =
    ShadowMap.
Relancer le script est sans danger : il efface d'abord ce qu'il a cree.
]]

local SS = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local function chercherPart(racine, motif)
	for _, d in ipairs(racine:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, motif, 1, true) then
			return d
		end
	end
end

local function chercherConteneur(motif, lieux)
	for _, lieu in ipairs(lieux) do
		for _, enfant in ipairs(lieu:GetChildren()) do
			if (enfant:IsA("Model") or enfant:IsA("Folder")) and chercherPart(enfant, motif) then
				return enfant
			end
		end
	end
end

local function essayer(f)
	local ok, err = pcall(f)
	return ok
end

local function visuel(p, ombre)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = ombre
	if p:IsA("MeshPart") then
		essayer(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
		essayer(function() p.RenderFidelity = Enum.RenderFidelity.Automatic end)
	end
end

local function dossier(parent, nom, classe)
	local ancien = parent:FindFirstChild(nom)
	if ancien then ancien:Destroy() end
	local f = Instance.new(classe or "Folder")
	f.Name = nom
	f.Parent = parent
	return f
end

return function()
	local D = require(SS:FindFirstChild("DonneesArbres"))
	local C = require(SS:FindFirstChild("DonneesCollisions"))
	local map = chercherConteneur(D.reference.nom, {workspace})
	assert(map, "Map introuvable : importer MAP_MOTIFS_V17_AVEC_CHAINES.fbx dans Workspace")
	local lib = chercherConteneur("Arbre_RP_0", {workspace, SS, game:GetService("ReplicatedStorage")})
	assert(lib, "Bibliotheque d'arbres introuvable : importer ARBRES_V17.fbx")

	-- repere : l'import peut avoir deplace la map, on recale tout sur la reference
	local ref = chercherPart(map, D.reference.nom)
	local offset = ref.Position - D.reference.position
	local centre = CFrame.new(offset)
	print(("[Map] decalage de l'import : %s"):format(tostring(offset)))

	-- 1. rangement + reglages des meshes de la map
	local groupes = {}
	for _, nom in ipairs({"Sol", "Voirie", "Tunnels", "Square", "Batiments"}) do
		groupes[nom] = map:FindFirstChild(nom) or dossier(map, nom, "Model")
	end
	-- V17g : le sol (map + horizon jusqu'a 6 000 studs) reste toujours charge : pas de bord dans le vide
	essayer(function() groupes.Sol.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") then
			local n = p.Name
			if string.find(n, "Brume_Rideau", 1, true) or string.find(n, "Brume_Nappe", 1, true) then
				-- V17h : rideaux de brume (degrade d'opacite dans la texture) : toujours charges, sans ombre
				visuel(p, false); p.Parent = groupes.Sol
				p.Transparency = 0.001                  -- passe transparente : l'alpha de la texture est respecte
			elseif string.find(n, "Trottoir_Plot", 1, true) == 1 then
				-- V21d : segments de trottoir du bord route des plots (entree / sortie deplacables) : rien ici,
				-- ranges plus bas dans Voirie.TrottoirsPlots.PlotN.<segment> (Model = meshes + collision)
				visuel(p, false)
			elseif string.find(n, "Voirie", 1, true) then
				-- Station tycoon v49 : les meshes de voirie (chaussee, trottoirs, bordures, marquage) sont des VISUELS : leur
				-- enveloppe de collision par defaut couvrait tout le carreau de map (jusque dans les plots : sol invisible a 1,27,
				-- rayons du mode Supprimer bloques). Les collisions reelles sont les Parts invisibles de DonneesCollisions.
				visuel(p, false); p.Parent = groupes.Voirie
			elseif string.find(n, "Sol_", 1, true) then
				visuel(p, false); p.Parent = groupes.Sol
			elseif string.find(n, "Tunnel", 1, true) then
				visuel(p, true); p.Parent = groupes.Tunnels
				-- tetes de tunnel : fin de map, on les ferme par leur enveloppe convexe
				p.CanCollide = true; p.CanQuery = true
				essayer(function() p.CollisionFidelity = Enum.CollisionFidelity.Hull end)
			elseif string.find(n, "Square", 1, true) then
				local grand = string.find(n, "Monument", 1, true) or string.find(n, "Emplacements", 1, true)
				visuel(p, grand and true or false); p.Parent = groupes.Square
			elseif string.find(n, "Batiment_", 1, true) then
				visuel(p, true)
			elseif string.find(n, "Bloc_", 1, true) or string.find(n, "_Avancee", 1, true) then
				-- V16c : blocs beton et avancees de facade des chaines : visuels, collisions par Parts invisibles
				visuel(p, true)
				p.Parent = groupes.Batiments
			elseif string.find(n, "Vert_", 1, true) then
				-- batiment vert (V16) : mesh visuel, collisions par les Parts invisibles
				visuel(p, string.find(n, "Batiment", 1, true) and true or false)
				p.Parent = groupes.Batiments
			end
		end
	end

	-- 2. batiments : 2 prototypes + 6 copies tournees (meme MeshId = instancing)
	--    (V14+ : plus de batiments F1, la liste D.batiments est vide)
	local protos = {}
	for k = 0, (#D.batiments > 0) and 1 or -1 do
		local m = dossier(groupes.Batiments, "Batiment_" .. k, "Model")
		for _, p in ipairs(map:GetDescendants()) do
			if p:IsA("BasePart") and string.find(p.Name, "Batiment_" .. k, 1, true) and not p:IsDescendantOf(m) then
				p.Parent = m
			end
		end
		protos[k] = m
	end
	for _, b in ipairs(D.batiments) do
		local k, proto, angle = b[1], b[2], b[3]
		local copie = protos[proto]:Clone()
		copie.Name = "Batiment_" .. k
		local rot = centre * CFrame.Angles(0, math.rad(angle), 0) * centre:Inverse()
		for _, p in ipairs(copie:GetDescendants()) do
			if p:IsA("BasePart") then p.CFrame = rot * p.CFrame end
		end
		local ancien = groupes.Batiments:FindFirstChild(copie.Name)
		if ancien then ancien:Destroy() end
		copie.Parent = groupes.Batiments
	end
	for _, m in ipairs(groupes.Batiments:GetChildren()) do
		if m:IsA("Model") then
			essayer(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
			essayer(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
		end
	end

	-- 2 bis. batiments industriels : les prototypes du coin NE sont dans le FBX, les
	-- 3 autres coins sont des copies tournees autour du centre (meme MeshId = instancing)
	local nCopies = 0
	for _, c in ipairs(D.copies or {}) do
		local proto
		for _, p in ipairs(map:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == c[1] then proto = p break end
		end
		if proto then
			local ancien = groupes.Batiments:FindFirstChild(c[3])
			if ancien then ancien:Destroy() end
			local copie = proto:Clone()
			copie.Name = c[3]
			local rot = centre * CFrame.Angles(0, math.rad(c[2]), 0) * centre:Inverse()
			copie.CFrame = rot * proto.CFrame
			copie.Parent = groupes.Batiments
			nCopies = nCopies + 1
		else
			warn("[Map] prototype introuvable : " .. c[1])
		end
	end
	if nCopies > 0 then print(("[Map] %d batiments industriels copies (instancing)"):format(nCopies)) end

	-- 3. lumieres interieures (sans ombre)
	local lum = dossier(groupes.Batiments, "Lumieres")
	for _, l in ipairs(D.lumieres) do
		local a = Instance.new("Part")
		a.Name = "Plafonnier"; a.Size = Vector3.new(1, 1, 1); a.Transparency = 1
		a.Anchored = true; a.CanCollide = false; a.CanTouch = false; a.CanQuery = false; a.CastShadow = false
		a.CFrame = centre * CFrame.new(l[1], l[2], l[3])
		local pl = Instance.new("PointLight")
		pl.Range = 40; pl.Brightness = 1.3; pl.Shadows = false; pl.Color = Color3.fromRGB(255, 244, 220)
		pl.Parent = a
		a.Parent = lum
	end

	-- 4. arbres : copies de la bibliotheque (instancing)
	local modeles = {}
	for _, p in ipairs(lib:GetDescendants()) do
		if p:IsA("MeshPart") then modeles[p.Name] = p end
	end
	local arbres = dossier(map, "Arbres", "Model")
	local manquants = 0
	for _, a in ipairs(D.arbres) do
		local modele = modeles[a[1]]
		if modele then
			local c = modele:Clone()
			c.Size = modele.Size * a[6]
			c.CFrame = centre * CFrame.new(a[2], a[3], a[4]) * CFrame.Angles(0, a[5], 0)
			visuel(c, true)
			c.Parent = arbres
		else
			manquants = manquants + 1
		end
	end
	if manquants > 0 then warn(("[Map] %d arbres sans modele (noms de la bibliotheque ?)"):format(manquants)) end

	-- 4 bis. chaine de production : on deplace le modele de Thomas (sans toucher a ses
	-- reglages) pour que sa piece CP_Hall arrive a la position et a l'orientation voulues
	for _, c in ipairs(D.chaines or {}) do
		local modele = chercherConteneur("CP_Hall", {workspace})
		if modele and modele ~= map then
			local hall
			for _, p in ipairs(modele:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "CP_Hall" then hall = p break end
			end
			hall = hall or chercherPart(modele, "CP_Hall")
			-- mise a l'echelle (3 etages de 22,5 studs) : Model:ScaleTo, idempotent
			if modele:IsA("Model") and c.echelle and math.abs(modele:GetScale() - c.echelle) > 1e-3 then
				modele:ScaleTo(c.echelle)
			end
			local cible = centre * CFrame.new(c.hall) * CFrame.Angles(0, math.rad(c.angle), 0)
			local actuel = CFrame.new(hall.Position)          -- orientation d'import (identite)
			local delta = cible * actuel:Inverse()
			if modele:IsA("Model") then
				modele:PivotTo(delta * modele:GetPivot())
			else
				for _, p in ipairs(modele:GetDescendants()) do
					if p:IsA("BasePart") then p.CFrame = delta * p.CFrame end
				end
			end
			modele.Name = "ChaineProduction_" .. c.nom
			print(("[Map] chaine de production %s placee"):format(c.nom))
		elseif modele == map then
			print(("[Map] chaine %s deja incluse dans la map (FBX AVEC_CHAINES) : rien a deplacer"):format(c.nom))
		else
			warn("[Map] chaine de production introuvable : importe MAP_MOTIFS_V17_AVEC_CHAINES.fbx")
		end
	end

	-- 5. collisions : Parts invisibles et simples
	local col = dossier(map, "Collisions", "Model")
	local function proxy(nom, cf, taille, forme)
		local p = Instance.new("Part")
		p.Name = nom
		if forme then p.Shape = forme end
		p.Size = taille; p.CFrame = cf
		p.Anchored = true; p.CanCollide = true; p.CanTouch = false; p.CanQuery = true
		p.CastShadow = false; p.Transparency = 1; p.Material = Enum.Material.SmoothPlastic
		p.Parent = col
	end
	for _, b in ipairs(C.boites) do
		proxy(b[8], centre * CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, b[7], 0),
			Vector3.new(math.max(b[4], 0.05), math.max(b[5], 0.05), math.max(b[6], 0.05)))
	end
	for _, c in ipairs(C.cylindres) do
		proxy(c[6], centre * CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(math.max(c[4], 0.05), c[5], c[5]), Enum.PartType.Cylinder)
	end
	-- V17e : plans inclines des entrees de plots (traversee du trottoir abaisse, rampes)
	for _, q in ipairs(C.plans or {}) do
		proxy(q[13], centre * CFrame.fromMatrix(Vector3.new(q[1], q[2], q[3]), Vector3.new(q[7], q[8], q[9]), Vector3.new(q[10], q[11], q[12])),
			Vector3.new(q[4], q[5], q[6]))
	end
	-- 5 ter (V21d). Segments de trottoir des bords de plots : un Model par segment (Trottoir_PlotN_kk) qui
	-- contient ses MeshParts (une par texture) et sa Part de collision (renommee "Collision"). Le jeu ouvre
	-- une entree / sortie en masquant les Models choisis (ex. Parent = nil ou Transparency 1 + CanCollide false)
	-- et en posant lui-meme la traversee abaissee et les rampes.
	do
		local voirie = map:FindFirstChild("Voirie") or dossier(map, "Voirie", "Model")
		local racine = dossier(voirie, "TrottoirsPlots", "Folder")
		local segs = {}
		local function seg(nom)
			if not segs[nom] then
				local plot = string.match(nom, "^Trottoir_(Plot%d+)_")
				local f = racine:FindFirstChild(plot) or dossier(racine, plot, "Folder")
				local m = Instance.new("Model"); m.Name = nom; m.Parent = f
				essayer(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
				segs[nom] = m
			end
			return segs[nom]
		end
		local n = 0
		for _, p in ipairs(map:GetDescendants()) do
			if p:IsA("BasePart") and not p:IsDescendantOf(racine) then
				local nom = string.match(p.Name, "^(Trottoir_Plot%d+_%d+)")
				if nom then
					if p.Parent == col then
						p.Name = "Collision"
					end
					p.Parent = seg(nom); n = n + 1
				end
			end
		end
		print(("[Map] V21d : %d pieces de segments de trottoir de plots rangees"):format(n))
	end

	-- 5 bis. V18 : herbe realiste de Roblox SEULEMENT sur les espaces verts. Les zones sont calculees
	-- a partir de la geometrie de la map (herbe_zones.py) : pelouses hors routes, trottoirs, ilots,
	-- tunnels, batiments, dallages, cours des garages, plots des joueurs et place centrale, reculees de
	-- 4 studs de chaque bordure ; + la pelouse des 4 ilots des ronds-points exterieurs. Rectangles de
	-- la grille des voxels (4 studs) dans DonneesArbres.herbe (sol, dessus 0,12 stud au-dessus du mesh
	-- d'herbe, bien sous la chaussee a 0,57) et DonneesArbres.herbe_ilots (dessus des ilots, 1,08 + 0,12).
	-- Le mesh d'herbe de la map reste visible dessous (meme teinte) : il fait les bords.
	do
		local T = workspace.Terrain
		local demi = (D.carte and D.carte.demi) or 1340
		local VERT = Color3.fromRGB(111, 126, 62)
		essayer(function() T.Decoration = true end)
		essayer(function() T.GrassLength = 0.7 end)
		essayer(function() T:SetMaterialColor(Enum.Material.Grass, VERT) end)
		essayer(function() T:SetMaterialColor(Enum.Material.Ground, VERT) end)
		-- on repart d'un terrain vide sur la map (anciennes versions : herbe partout)
		local pas = 512
		local n = math.ceil(2 * (demi + 16) / pas)
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				local x0, z0 = -demi - 16 + i * pas, -demi - 16 + j * pas
				T:FillBlock(centre * CFrame.new(x0 + pas / 2, -4, z0 + pas / 2), Vector3.new(pas, 24, pas), Enum.Material.Air)
			end
		end
		-- Station tycoon v49 : Roblox dessine la surface du Terrain ~2 studs AU-DESSUS du haut nominal d'un bloc rempli
		-- (mesure en jeu : l'herbe depassait du trottoir) : on descend le haut nominal de 2,05 studs (surface ~0,1 / ~1,2)
		local H = (D.herbe_haut or 0.12) - 2.05
		local nb = 0
		for _, r in ipairs(D.herbe or {}) do                     -- {x0, z0, x1, z1} en studs
			local sx, sz = r[3] - r[1], r[4] - r[2]
			T:FillBlock(centre * CFrame.new((r[1] + r[3]) / 2, (H - 6) / 2, (r[2] + r[4]) / 2), Vector3.new(sx, H + 6, sz), Enum.Material.Grass)
			nb = nb + 1
		end
		local HI = (D.herbe_ilots_haut or 1.20) - 2.05
		for _, r in ipairs(D.herbe_ilots or {}) do
			local sx, sz = r[3] - r[1], r[4] - r[2]
			T:FillBlock(centre * CFrame.new((r[1] + r[3]) / 2, (HI - 6) / 2, (r[2] + r[4]) / 2), Vector3.new(sx, HI + 6, sz), Enum.Material.Grass)
			nb = nb + 1
		end
		-- le mesh d'herbe de la map reste visible (il borde les pelouses de Terrain)
		for _, p in ipairs(map:GetDescendants()) do
			if p:IsA("BasePart") and string.find(p.Name, "Sol_Herbe", 1, true) then p.Transparency = 0 end
		end
		print(("[Map] herbe realiste : %d zones de Terrain Grass (espaces verts et ilots seulement)"):format(nb))
	end

	-- 5 quater. Station tycoon (v49) : herbe en relief dans les 8 PLOTS des joueurs (exclus des zones ci-dessus), sauf les
	-- cases interdites (courbe de la route) : module InstallerHerbe, relance a chaque demarrage par Lancement
	do
		local okH, errH = pcall(function() require(SS:WaitForChild("InstallerHerbe"))(centre) end)
		if not okH then warn("[Map] herbe des plots : " .. tostring(errH)) end
	end

	-- le sol et la voirie restent toujours charges (on ne tombe jamais a travers)
	essayer(function() col.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)

	-- 6. ancrage general + streaming + eclairage
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	essayer(function() workspace.StreamingEnabled = true end)
	essayer(function() workspace.StreamingTargetRadius = 768 end)
	essayer(function() workspace.StreamingMinRadius = 192 end)
	essayer(function() Lighting.Technology = Enum.Technology.ShadowMap end)

	-- 6 ter. verres (V17) : Transparency 0,6 et Reflectance 0,2 sur toutes les pieces de verre
	-- (facades vitrees des batiments verts, avancees, tour du monument, cabines)
	local nVerre = 0
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") then
			local n = string.lower(p.Name)
			-- (pas les batiments d'angle "Bloc_" : ils n'ont pas d'interieur, on verrait a travers)
			-- (V21e : sauf le bureau vitre du hangar de stockage, "..._hangar_Vitre", qui a un interieur)
			if (string.find(n, "verre", 1, true) or string.find(n, "vitre", 1, true)) and (not string.find(n, "bloc_", 1, true) or string.find(n, "hangar_vitre", 1, true)) then
				p.Transparency = 0.6; p.Reflectance = 0.2; p.CastShadow = false
				nVerre = nVerre + 1
			end
		end
	end
	print(("[Map] %d pieces de verre : Transparency 0.6, Reflectance 0.2"):format(nVerre))
	-- V21g : dalles LED du plafond des hangars de stockage ("..._hangar_LED") : Neon blanc (lumineux)
	local nLed = 0
	for _, p in ipairs(map:GetDescendants()) do
		if p:IsA("BasePart") and string.find(string.lower(p.Name), "hangar_led", 1, true) then
			if p:IsA("MeshPart") then pcall(function() p.TextureID = "" end) end
			p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(176, 174, 162); p.CastShadow = false   -- V21h : Neon attenue (moins eblouissant)
			nLed = nLed + 1
		end
	end
	print(("[Map] %d dalles LED de hangar en Neon"):format(nLed))

	-- 6 quater. bassin du monument : vraie eau Roblox (Terrain), hexagone entre le piedestal et la margelle
	local Terrain = workspace.Terrain
	essayer(function()
		Terrain.WaterColor = Color3.fromRGB(38, 120, 150)
		Terrain.WaterTransparency = 0.55
		Terrain.WaterReflectance = 0.6
		Terrain.WaterWaveSize = 0.05
		Terrain.WaterWaveSpeed = 6
	end)
	local B = D.bassin
	if B then
		local r0, r1 = B.apotheme_int, B.apotheme_ext            -- studs
		local rm, larg = 0.5 * (r0 + r1), (r1 - r0)
		local cote = 2 * r1 * math.tan(math.rad(30)) + 2       -- longueur d'un cote (bord exterieur)
		for k = 0, 5 do
			local a = math.rad(60 * k)
			local cf = centre * CFrame.new(B.centre) * CFrame.Angles(0, a, 0) * CFrame.new(rm, (B.y0 + B.y1) / 2, 0)
			Terrain:FillBlock(cf, Vector3.new(larg, B.y1 - B.y0, cote), Enum.Material.Water)
		end
	end

	-- jets d'eau du bassin : emetteurs de particules (gerbes blanches qui retombent)
	local fontaine = dossier(groupes.Square, "Fontaine")
	for _, j in ipairs(D.jets or {}) do
		local a = Instance.new("Part"); a.Name = "Jet"; a.Size = Vector3.new(0.4, 0.4, 0.4); a.Transparency = 1
		a.Anchored = true; a.CanCollide = false; a.CanTouch = false; a.CanQuery = false; a.CastShadow = false
		a.CFrame = centre * CFrame.new(j[1], j[2], j[3]); a.Parent = fontaine
		local pe = Instance.new("ParticleEmitter"); pe.Name = "Eau"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.fromRGB(235, 248, 255), Color3.fromRGB(160, 210, 235))
		pe.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1)})
		pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.9)})
		pe.EmissionDirection = Enum.NormalId.Top; pe.SpreadAngle = Vector2.new(4, 4)
		local v = math.sqrt(2 * 45 * j[4] * 3)                              -- gerbes de 10 a 15 studs (echelle des joueurs x3)
		pe.Speed = NumberRange.new(v * 0.95, v * 1.05); pe.Acceleration = Vector3.new(0, -45, 0)
		pe.Lifetime = NumberRange.new(2 * v / 45); pe.Rate = 60; pe.LightEmission = 0.3; pe.Drag = 0
		pe.Parent = a
	end

	-- 6 bis. plots des joueurs (V17) : zone au sol (orange translucide), bouche du tunnel, angle droit
	local zonesPlots = dossier(workspace, "PlotZones")
	for _, pl in ipairs(D.plots or {}) do
		local m = Instance.new("Model"); m.Name = pl.nom
		local manque = {}
		for _, c in ipairs(pl.manquantes or {}) do manque[c[1] .. "_" .. c[2]] = true end
		local function repere(nom, cf, taille, couleur, transp)
			local p = Instance.new("Part"); p.Name = nom; p.Anchored = true
			p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic; p.Color = couleur; p.Transparency = transp
			p.Size = taille; p.CFrame = cf; p.Parent = m
			return p
		end
		-- zone au sol : une bande par colonne (cases de pl.case studs), sans les cases qui mordent la route
		local u, v, o = pl.axeU, pl.axeV, offset + pl.origine
		local rot = CFrame.fromMatrix(Vector3.zero, u, Vector3.yAxis, -v)
		for i = 0, pl.nx - 1 do
			local j = 0
			while j < pl.ny do
				while j < pl.ny and manque[i .. "_" .. j] do j = j + 1 end
				local j0 = j
				while j < pl.ny and not manque[i .. "_" .. j] do j = j + 1 end
				if j > j0 then
					local c = o + u * ((i + 0.5) * pl.case) + v * ((j0 + j) * 0.5 * pl.case) + Vector3.new(0, 0.15, 0)
					repere("Colonne" .. i, CFrame.new(c) * rot, Vector3.new(pl.case - 0.3, 0.2, (j - j0) * pl.case - 0.3), Color3.fromRGB(255, 140, 0), 0.75)
				end
			end
		end
		-- annexe 3 x 3 cases de l'autre cote de la branche
		if pl.annexe then
			local ao = offset + pl.annexe.origine
			for i = 0, pl.annexe.n - 1 do
				for j = 0, pl.annexe.n - 1 do
					local c = ao - u * ((i + 0.5) * pl.case) + v * ((j + 0.5) * pl.case) + Vector3.new(0, 0.15, 0)
					repere("Annexe_" .. i .. "_" .. j, CFrame.new(c) * rot, Vector3.new(pl.case - 0.3, 0.2, pl.case - 0.3), Color3.fromRGB(0, 150, 255), 0.6)
				end
			end
		end
		m:SetAttribute("Case", pl.case); m:SetAttribute("NX", pl.nx); m:SetAttribute("NY", pl.ny)
		local t = repere("Tunnel", CFrame.new(offset + pl.tunnel + Vector3.new(0, 0.5, 0)), Vector3.new(4, 1, 4), Color3.fromRGB(255, 60, 60), 0.3)
		t.CFrame = CFrame.lookAt(t.Position, t.Position + pl.sortie)
		repere("Angle", CFrame.new(offset + pl.angle + Vector3.new(0, 0.5, 0)), Vector3.new(4, 1, 4), Color3.fromRGB(255, 220, 0), 0.3)
		-- V17e : entree et sortie du plot (trottoir abaisse) : repere vert (entree) / violet (sortie) au bord du plot, tourne vers le plot
		for _, a in ipairs(pl.acces or {}) do
			local coul = (a.nom == "Entree") and Color3.fromRGB(40, 220, 90) or Color3.fromRGB(225, 60, 230)
			local r = repere(a.nom, CFrame.new(offset + a.bord + Vector3.new(0, 0.5, 0)), Vector3.new(a.n * pl.case - 2, 1, 4), coul, 0.3)
			r.CFrame = CFrame.lookAt(r.Position, r.Position + a.dedans)
			m:SetAttribute(a.nom .. "_I0", a.i0)
		end
		m.Parent = zonesPlots
	end

	-- 6 quinquies. V17g : brouillard progressif "un peu magique" au bord de la map, accorde au ciel
	-- de Station Tycoon (Atmosphere peche). Bancs de brume (anneau exterieur dense, anneau interieur
	-- leger : la brume s'epaissit vers le bord) + poussiere doree qui monte doucement.
	-- Textures integrees a Roblox (rbxasset://), rien a importer.
	local brumeDossier = dossier(workspace, "Brume", "Model")
	essayer(function() brumeDossier.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
	local function support(nom, pos, taille)
		local p = Instance.new("Part"); p.Name = nom; p.Anchored = true
		p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
		p.Transparency = 1; p.Size = taille; p.CFrame = CFrame.new(pos); p.Parent = brumeDossier
		return p
	end
	for i, b in ipairs(D.brume or {}) do
		local ext = (b[3] == 1)
		local p = support("Brume_" .. i, offset + Vector3.new(b[1], ext and 35 or 20, b[2]),
			ext and Vector3.new(320, 50, 320) or Vector3.new(220, 25, 220))
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "Brume"
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		essayer(function() pe.Shape = Enum.ParticleEmitterShape.Box; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)
		pe.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 192)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 208, 186)), ColorSequenceKeypoint.new(1, Color3.fromRGB(238, 204, 232))})
		pe.LightEmission = 0.25; pe.LightInfluence = 0.5
		pe.Size = NumberSequence.new({kp(0, ext and 90 or 55), kp(1, ext and 180 or 110)})
		pe.Transparency = NumberSequence.new({kp(0, 1), kp(0.3, ext and 0.5 or 0.75), kp(0.7, ext and 0.55 or 0.8), kp(1, 1)})
		pe.Lifetime = NumberRange.new(16, 24); pe.Rate = ext and 0.5 or 0.25
		pe.Speed = NumberRange.new(1, 3); pe.SpreadAngle = Vector2.new(180, 180)
		pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-5, 5)
		pe.Acceleration = Vector3.new(0, 0.2, 0); pe.Drag = 0.3
		pe.Parent = p
		pe:Emit(ext and 8 or 4)                             -- deja la au lancement
	end
	for i, e in ipairs(D.etincelles or {}) do
		local p = support("Etincelles_" .. i, offset + Vector3.new(e[1], 12, e[2]), Vector3.new(220, 20, 220))
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "PoussiereMagique"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		essayer(function() pe.Shape = Enum.ParticleEmitterShape.Box; pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 232, 170), Color3.fromRGB(255, 190, 228))
		pe.LightEmission = 1; pe.LightInfluence = 0
		pe.Size = NumberSequence.new({kp(0, 0.4), kp(0.5, 2.2), kp(1, 0)})
		pe.Transparency = NumberSequence.new({kp(0, 1), kp(0.2, 0.15), kp(0.8, 0.35), kp(1, 1)})
		pe.Lifetime = NumberRange.new(4, 8); pe.Rate = 2.5
		pe.Speed = NumberRange.new(1, 3); pe.SpreadAngle = Vector2.new(60, 60)
		pe.RotSpeed = NumberRange.new(-60, 60); pe.Acceleration = Vector3.new(0, 1.2, 0); pe.Drag = 0.5
		pe.Parent = p
	end
	-- V21 : "j'aime beaucoup le brouillard des rendus mais je n'ai pas le meme dans Roblox".
	-- Les rendus montrent : une brume peche qui s'epaissit avec la distance, un ciel CREME uni (pas de
	-- ciel bleu derriere les rideaux), le bord de la map fondu dans ce ciel. On reproduit ca ici :
	--   * Atmosphere reglee comme l'apercu (couleurs mesurees sur les rendus) : on REMPLACE les reglages
	--     de la place (avant : on gardait l'Atmosphere du jeu si elle existait) ;
	--   * "coque de ciel" : murs creme tres loin (au-dela des rideaux, sur le sol d'horizon), sans ombre ni
	--     collision, toujours charges : l'Atmosphere les fond completement -> ciel creme au ras de l'horizon
	--     comme sur les rendus, quelle que soit la Skybox du jeu.
	-- Mettre BROUILLARD_RENDU = false pour garder l'Atmosphere / le ciel d'origine du jeu.
	local BROUILLARD_RENDU = true
	local ATMO = {Density = 0.45, Offset = 0.0, Glare = 0.0, Haze = 2.5,
		Color = Color3.fromRGB(247, 226, 207), Decay = Color3.fromRGB(255, 240, 226)}
	local CIEL = {distance = 5200, hauteur = 2400, couleur = Color3.fromRGB(250, 238, 226)}
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if BROUILLARD_RENDU or not a then
		a = a or Instance.new("Atmosphere")
		for k, v in pairs(ATMO) do a[k] = v end
		a.Parent = Lighting
	end
	local ciel = dossier(workspace, "CielCreme", "Model")
	essayer(function() ciel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	if BROUILLARD_RENDU then
		local R, H = CIEL.distance, CIEL.hauteur
		local n = math.ceil(2 * R / 2000); local w = 2 * R / n
		local nh = math.ceil(H / 2000); local hh = H / nh
		local function panneau(pos, taille)
			local p = Instance.new("Part"); p.Name = "Ciel"; p.Anchored = true
			p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic; p.Color = CIEL.couleur
			p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = taille; p.CFrame = CFrame.new(offset + pos); p.Parent = ciel
		end
		for k = 0, n - 1 do
			local u = -R + (k + 0.5) * w
			for j = 0, nh - 1 do
				local y = (j + 0.5) * hh - 30
				panneau(Vector3.new(u, y, -R), Vector3.new(w + 8, hh, 8))
				panneau(Vector3.new(u, y, R), Vector3.new(w + 8, hh, 8))
				panneau(Vector3.new(-R, y, u), Vector3.new(8, hh, w + 8))
				panneau(Vector3.new(R, y, u), Vector3.new(8, hh, w + 8))
			end
		end
	end
	print(("[Map] brume : %d bancs, %d emetteurs d'etincelles"):format(#(D.brume or {}), #(D.etincelles or {})))

	-- 6 sexies. V17m : garages des ateliers (8 coins) -- un van dans le garage ouvert, un camion et
	-- un grand van sur le parking. Modeles de Thomas (CAMIONS_V17.rbxm dans ServerStorage) : dans
	-- le fichier, la longueur est le long de Z et l'avant (phares) vers -Z. Copies ancrees.
	do
		local vDossier = dossier(workspace, "Vehicules", "Folder")
		local sources, cadres = {}, {}
		local function chercherModele(nom)
			for _, lieu in ipairs({SS, game:GetService("ReplicatedStorage"), workspace}) do
				for _, m in ipairs(lieu:GetDescendants()) do
					if m:IsA("Model") and m.Name == nom and not m:IsDescendantOf(vDossier) and not m:IsDescendantOf(map) then
						return m
					end
				end
			end
		end
		local function cadre(m)
			local mn = Vector3.new(math.huge, math.huge, math.huge)
			local mx = -mn
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") then
					local h = p.Size / 2
					for _, c in ipairs({Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
						Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1)}) do
						local w = p.CFrame * (h * c)
						mn = mn:Min(w); mx = mx:Max(w)
					end
				end
			end
			return CFrame.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
		end
		local n = 0
		for _, v in ipairs(D.vehicules or {}) do
			local src = sources[v.modele]
			if src == nil then
				src = chercherModele(v.modele) or false
				sources[v.modele] = src
				if src then
					cadres[v.modele] = cadre(src)
				else
					warn("[Map] vehicule introuvable : " .. v.modele .. " (inserer CAMIONS_V17.rbxm dans ServerStorage)")
				end
			end
			if src then
				local pos = offset + v.pos
				local cible = CFrame.lookAt(pos, pos + v.avant)
				local c = src:Clone()
				c.Name = v.modele .. "_" .. v.coin
				-- V18 : vehicules x2 (a l'echelle des joueurs x3), cadre recalcule apres l'agrandissement
				local k = D.echelle_vehicules or 1
				if k ~= 1 then essayer(function() c:ScaleTo(c:GetScale() * k) end) end
				local cad = (k ~= 1) and cadre(c) or cadres[v.modele]
				c:PivotTo(cible * cad:Inverse() * c:GetPivot())
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then p.Anchored = true end
				end
				c.Parent = vDossier
				n = n + 1
			end
		end
		for _, src in pairs(sources) do
			if src and src:IsDescendantOf(workspace) then src.Parent = SS end      -- les originaux ne restent pas en jeu
		end
		-- plafonnier de chaque garage ouvert
		for i, g in ipairs(D.garages or {}) do
			local p = Instance.new("Part"); p.Name = "LumiereGarage_" .. i
			p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
			p.Transparency = 1; p.Size = Vector3.new(1, 1, 1); p.CFrame = CFrame.new(offset + g); p.Parent = vDossier
			local l = Instance.new("PointLight"); l.Range = 40; l.Brightness = 0.8; l.Shadows = false   -- V21h : hangar moins lumineux (etait 1,5)
			l.Color = Color3.fromRGB(255, 244, 226); l.Parent = p
		end
		print(("[Map] vehicules poses : %d / %d ; garages eclaires : %d"):format(n, #(D.vehicules or {}), #(D.garages or {})))
	end

	-- 6 septies. V18 : sas d'entree des 4 chaines de production. De chaque cote du portail, 2 portes
	-- coulissantes vitrees l'une derriere l'autre : porte 1 dans la facade arrondie verte, porte 2 dans
	-- la facade du hall (ouverture deja percee dans les meshes). Battants = Parts ancrees (vitre +
	-- cadre), Model tague "PorteCoulissante" ; le Script PortesSas (ServerScriptService) les ouvre
	-- quand un joueur approche. Les meshes du hall recoivent des collisions precises (on entre a pied).
	do
		local CS = game:GetService("CollectionService")
		local pDossier = dossier(workspace, "PortesSas", "Folder")
		for _, a in ipairs(pDossier:GetChildren()) do a:Destroy() end
		local VERRE, CADRE, VERT = Color3.fromRGB(150, 196, 214), Color3.fromRGB(58, 62, 68), Color3.fromRGB(40, 150, 84)
		local UP = Vector3.new(0, 1, 0)
		for _, q in ipairs(D.portes_sas or {}) do
			local m = Instance.new("Model"); m.Name = ("PorteSas_%s_%s_%d"):format(q.chaine, q.cote, q.rang)
			local t, nn = q.axe.Unit, q.dedans.Unit
			local base = offset + q.pos + nn * q.decal
			local W, H = q.largeur, q.hauteur
			local wl = W / 2 + 0.5                          -- chaque battant recouvre 0,5 stud du tableau
			local function piece(nom, c, taille, couleur, matiere, transp, sens, bloque)
				local p = Instance.new("Part"); p.Name = nom; p.Anchored = true
				p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
				p.CanCollide = bloque and true or false
				p.Size = taille; p.CFrame = CFrame.fromMatrix(c, t, UP)
				p.Color = couleur; p.Material = matiere; p.Transparency = transp
				if sens then
					p:SetAttribute("Ferme", p.CFrame)
					p:SetAttribute("Ouvert", p.CFrame + t * (sens * (wl - 0.4)))
					p:SetAttribute("Bloque", bloque and true or false)
				end
				p.Parent = m
				return p
			end
			for _, sens in ipairs({-1, 1}) do
				local suf = sens < 0 and "G" or "D"
				local c = base + t * (sens * wl / 2) + UP * (H / 2)
				piece("Battant_" .. suf, c, Vector3.new(wl - 0.9, H - 1.1, 0.25), VERRE, Enum.Material.Glass, 0.55, sens, true)
				piece("Montant_" .. suf .. "_1", c - t * (wl / 2 - 0.3), Vector3.new(0.6, H, 0.45), CADRE, Enum.Material.Metal, 0, sens)
				piece("Montant_" .. suf .. "_2", c + t * (wl / 2 - 0.3), Vector3.new(0.6, H, 0.45), CADRE, Enum.Material.Metal, 0, sens)
				piece("Traverse_" .. suf .. "_B", c - UP * (H / 2 - 0.4), Vector3.new(wl, 0.8, 0.45), CADRE, Enum.Material.Metal, 0, sens)
				piece("Traverse_" .. suf .. "_H", c + UP * (H / 2 - 0.3), Vector3.new(wl, 0.6, 0.45), CADRE, Enum.Material.Metal, 0, sens)
			end
			-- porte 1 : bandeau vert "ENTREE" au-dessus du passage, cote exterieur
			if q.rang == 1 then
				local c = offset + q.pos - nn * 0.9 + UP * (H + 5.0)
				local p = piece("Enseigne", c, Vector3.new(math.min(W, 12), 2.4, 0.3), VERT, Enum.Material.SmoothPlastic, 0)
				local g = Instance.new("SurfaceGui")
				g.Face = (t:Cross(UP):Dot(nn) > 0) and Enum.NormalId.Front or Enum.NormalId.Back
				g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; g.PixelsPerStud = 40
				g.LightInfluence = 0; g.Brightness = 1.5
				local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1
				l.Text = "ENTRÉE"; l.TextScaled = true; l.Font = Enum.Font.GothamBold; l.TextColor3 = Color3.new(1, 1, 1)
				l.Parent = g; g.Parent = p
			end
			m:SetAttribute("Centre", base + UP * (H / 2))
			m.Parent = pDossier
			CS:AddTag(m, "PorteCoulissante")
		end
		-- collisions precises des meshes du hall : le passage de la porte 2 reste libre
		local nh = 0
		for _, p in ipairs(workspace:GetDescendants()) do
			if p:IsA("MeshPart") and (string.match(p.Name, "_CP_Hall$") or string.match(p.Name, "_CP_Hall_Verre$")) then
				if essayer(function() p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end) then nh = nh + 1 end
			end
		end
		print(("[Map] sas des chaines : %d portes coulissantes (Script PortesSas), %d meshes du hall en collision precise")
			:format(#(D.portes_sas or {}), nh))
	end

	-- 7. bibliotheque d'arbres : rangee (plus visible une fois les copies posees)
	if lib:IsDescendantOf(workspace) then lib.Parent = SS end

	-- 8. point d'apparition sur l'esplanade du rond-point central, tourne vers le monument
	local spawn = workspace:FindFirstChild("Depart")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = "Depart"
		spawn.Parent = workspace
	end
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Anchored = true; spawn.CanCollide = false; spawn.CanQuery = false; spawn.CanTouch = true
	spawn.Transparency = 1; spawn.Neutral = true; spawn.Duration = 0
	for _, d in ipairs(spawn:GetChildren()) do if d:IsA("Decal") then d:Destroy() end end
	spawn.CFrame = CFrame.lookAt(offset + Vector3.new(90, 2.2, 0), offset + Vector3.new(0, 2.2, 0))

	-- Station tycoon : les reperes orange des plots (PlotZones) ne servent pas au jeu (PlotSpawns / PlotManager)
	do local pz = workspace:FindFirstChild("PlotZones"); if pz then pz:Destroy() end end

	local n = 0
	for _, p in ipairs(map:GetDescendants()) do if p:IsA("BasePart") then n = n + 1 end end
	print(("[Map] installee : %d parts au total (%d collisions, %d arbres, %d lumieres). Pense a sauvegarder.")
		:format(n, #col:GetChildren(), #arbres:GetChildren(), #D.lumieres))
end
