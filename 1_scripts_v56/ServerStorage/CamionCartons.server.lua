--[[ CamionCartons  v2   (Script serveur, a mettre DANS le modele du camion)
	Animation Roblox (pas une video). Quand on declenche :
	  1. la caisse du camion se remplit de TES cartons (carton_petit / carton_moyen / carton_grand), empiles
	     proprement, portes fermees (personne ne le voit) ;
	  2. les deux portes arriere s'ouvrent : on voit la caisse chargee ;
	  3. les cartons glissent et tombent par l'arriere (vraie physique Roblox, vus par tous les joueurs),
	     les plus proches des portes d'abord, en commencant par le haut des piles ;
	  4. les portes se referment ; les cartons au sol disparaissent en fondu apres VIE_CARTONS secondes.

	3 NIVEAUX : "Peu" (une rangee pres des portes), "Moyen" (la moitie de la caisse), "Plein" (caisse pleine).

	Declenchement :
	  - boutons (ProximityPrompt) a l'arriere du camion : E = Peu, R = Moyen, F = Plein ;
	  - ou depuis un autre script serveur :   camion.CamionCartons.Declencher:Fire("Plein")

	Modeles de cartons : les pieces nommees carton_petit / carton_moyen / carton_grand (importees avec le FBX,
	dans le modele du camion, ou deja dans ServerStorage / ReplicatedStorage / Workspace). Le script les range dans
	ServerStorage > CamionCartons_Modeles et s'en sert comme modeles. Sans eux : cartons simples en Parts.
]]
------------------------------------------------------------------ reglages
local PORTES = {"PorteArriereG", "PorteArriereD"}   -- noms des portes (si introuvables : detection automatique)
local ANGLE_OUVERTURE = 115        -- degres
local DUREE_OUVERTURE = 0.9        -- secondes
local ATTENTE_AVANT = 0.5          -- secondes, portes ouvertes, avant que les cartons tombent
local MODELES = {"carton_petit", "carton_moyen", "carton_grand"}
local ECHELLE_CARTONS = 0.5        -- taille des cartons par rapport a tes modeles (1 = taille d'origine)
local NIVEAUX = {
	-- profondeur / hauteur : part de la caisse remplie ; types : modeles utilises ; max : nombre maxi de cartons
	-- ejection : duree de la vidange (s) ; vitesse : vitesse de sortie (studs/s)
	Peu   = {profondeur = 0.3, hauteur = 0.6, types = {"carton_moyen", "carton_petit"}, max = 8, ejection = 1.0, vitesse = {9, 13},
		texte = "Quelques cartons", touche = Enum.KeyCode.E},
	Moyen = {profondeur = 0.6, hauteur = 0.85, types = {"carton_grand", "carton_moyen", "carton_petit"}, max = 30, ejection = 1.8, vitesse = {10, 15},
		texte = "Des cartons", touche = Enum.KeyCode.R},
	Plein = {profondeur = 1.0, hauteur = 1.0, types = {"carton_grand", "carton_moyen", "carton_petit"}, max = 70, ejection = 3.0, vitesse = {11, 17},
		texte = "Plein de cartons", touche = Enum.KeyCode.F},
}
local ORDRE = {"Peu", "Moyen", "Plein"}
local NIVEAU_PAR_DEFAUT = "Moyen"  -- si Declencher:Fire() sans niveau
local LONGUEUR_SOUTE = nil         -- nil = longueur de la piece "Caisse" (sinon en studs)
local VIE_CARTONS = nil            -- secondes avant que les cartons disparaissent (nil : jamais, le jeu les ramasse)
local FERMETURE_APRES = 2.5        -- secondes apres la fin de l'ejection
local BOUTONS = false              -- un ProximityPrompt par niveau a l'arriere (Station tycoon : non, le jeu declenche)
local SONS = {Porte = "", Carton = ""}   -- ID de sons (facultatif), ex "rbxassetid://12345"

------------------------------------------------------------------
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

local fourgon = script.Parent
assert(fourgon:IsA("Model"), "CamionCartons doit etre dans le modele du camion")
local declencher = script:FindFirstChild("Declencher") or Instance.new("BindableEvent")
declencher.Name = "Declencher"; declencher.Parent = script
local termine = script:FindFirstChild("Termine") or Instance.new("BindableEvent")
termine.Name = "Termine"; termine.Parent = script

local HAUT = Vector3.new(0, 1, 0)

-- modeles de cartons : ranges dans ServerStorage (et retires du camion avant de le mesurer)
local ServerStorage = game:GetService("ServerStorage")
local rangement = ServerStorage:FindFirstChild("CamionCartons_Modeles") or Instance.new("Folder")
rangement.Name = "CamionCartons_Modeles"; rangement.Parent = ServerStorage
local function nomModele(n)
	n = string.lower(n)
	for _, m in ipairs(MODELES) do if n == m or n:sub(1, #m + 1) == m .. "." or n:sub(1, #m + 1) == m .. "_" then return m end end
	return nil
end
local function premierePiece(x)
	if x:IsA("BasePart") then return x end
	return x:FindFirstChildWhichIsA("BasePart", true)
end
local MODELE = {}
for _, m in ipairs(MODELES) do     -- deja ranges (installeur, ou un autre camion)
	local p = rangement:FindFirstChild(m)
	if p and p:IsA("BasePart") then MODELE[m] = p end
end
for _, lieu in ipairs({fourgon, ServerStorage, game:GetService("ReplicatedStorage"), workspace}) do
	for _, d in ipairs(lieu:GetDescendants()) do
		local m = nomModele(d.Name)
		if m and not MODELE[m] and (d:IsA("BasePart") or d:IsA("Model")) then
			local p = premierePiece(d)
			if p then
				local copie = p:Clone()
				for _, e in ipairs(copie:GetChildren()) do
					if e:IsA("JointInstance") or e:IsA("WeldConstraint") or e:IsA("BaseScript") then e:Destroy() end
				end
				copie.Name = m; copie.Anchored = true; copie.Parent = rangement
				MODELE[m] = copie
				if d:IsDescendantOf(fourgon) then d:Destroy() end
			end
		end
	end
end
for _, d in ipairs(fourgon:GetDescendants()) do     -- autres exemplaires eventuels dans le camion
	if d.Parent and nomModele(d.Name) and (d:IsA("BasePart") or d:IsA("Model")) then d:Destroy() end
end
local function pieces()
	local l = {}
	for _, p in ipairs(fourgon:GetDescendants()) do if p:IsA("BasePart") then table.insert(l, p) end end
	return l
end
-- etendue d'une piece le long d'une direction (monde)
local function etendue(p, dir)
	local cf, s = p.CFrame, p.Size
	return math.abs(cf.RightVector:Dot(dir)) * s.X + math.abs(cf.UpVector:Dot(dir)) * s.Y + math.abs(cf.LookVector:Dot(dir)) * s.Z
end
local function horiz(v) v = Vector3.new(v.X, 0, v.Z); return v.Magnitude > 1e-6 and v.Unit or Vector3.new(0, 0, 1) end

------------------------------------------------------------------ 1. trouver les portes
local cfM = fourgon:GetBoundingBox()
local centre = cfM.Position
local function trouverPortes()
	if PORTES then
		local a = fourgon:FindFirstChild(PORTES[1], true); local b = fourgon:FindFirstChild(PORTES[2], true)
		if a and b and a:IsA("BasePart") and b:IsA("BasePart") then return a, b end
		warn("CamionCartons : portes " .. PORTES[1] .. " / " .. PORTES[2] .. " introuvables, detection automatique")
	end
	-- panneaux fins de la taille d'une porte (2,5 a 5,5 de large, 5 a 9 de haut)
	local cand = {}
	for _, p in ipairs(pieces()) do
		local s = {p.Size.X, p.Size.Y, p.Size.Z}; table.sort(s)
		local h = etendue(p, HAUT)
		if s[1] < 0.9 and h > 4.5 and h < 9.5 and s[2] > 2.2 and s[2] < 5.5 then table.insert(cand, p) end
	end
	-- la paire la plus au bout du fourgon, cote a cote
	local best, bs
	for i = 1, #cand do
		for j = i + 1, #cand do
			local a, b = cand[i], cand[j]
			local da, db = horiz(a.Position - centre), horiz(b.Position - centre)
			local milieu = (a.Position + b.Position) / 2
			local dir = horiz(milieu - centre)
			local ecart = (a.Position - b.Position)
			local lateral = math.abs(ecart:Dot(dir:Cross(HAUT)))
			local memeFace = math.abs(ecart:Dot(dir)) < 0.8 and math.abs(a.Position.Y - b.Position.Y) < 1
			local score = (milieu - centre):Dot(dir)
			if memeFace and da:Dot(db) > 0.7 and lateral > 2 and lateral < 6 and (not bs or score > bs) then best, bs = {a, b}, score end
		end
	end
	assert(best, "CamionCartons : portes non trouvees, mets leurs noms dans PORTES en haut du script")
	return best[1], best[2]
end
local porteA, porteB = trouverPortes()
local ARRIERE = horiz((porteA.Position + porteB.Position) / 2 - centre)
local LATERAL = ARRIERE:Cross(HAUT)      -- vers la droite quand on regarde l'arriere depuis l'interieur... peu importe : signe calcule

-- corps : la plus grosse piece qui n'est pas une porte
local corps, vmax = nil, -1
for _, p in ipairs(pieces()) do
	if p ~= porteA and p ~= porteB then
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > vmax then corps, vmax = p, v end
	end
end

------------------------------------------------------------------ 2. charnieres (Motor6D) : chaque porte + ses vitres / poignees
local function accessoires(porte)
	-- petites pieces posees sur la porte (vitre, poignee) : elles suivent la porte
	local l = {}
	local c = porte.Position
	local w = etendue(porte, LATERAL) / 2; local h = etendue(porte, HAUT) / 2
	for _, p in ipairs(pieces()) do
		local autre = (porte == porteA) and porteB or porteA
		local plusPres = math.abs((p.Position - c):Dot(LATERAL)) <= math.abs((p.Position - autre.Position):Dot(LATERAL))
		if p ~= porte and p ~= porteA and p ~= porteB and p ~= corps and plusPres then
			local d = p.Position - c
			-- sur la porte ou devant elle (cote exterieur) ; pas les montants du cadre, qui sont derriere
			if d:Dot(ARRIERE) > -0.12 and d:Dot(ARRIERE) < 0.9 and math.abs(d:Dot(LATERAL)) + etendue(p, LATERAL) / 2 <= w + 0.3
				and math.abs(d.Y) + etendue(p, HAUT) / 2 <= h + 0.3 then
				table.insert(l, p)
			end
		end
	end
	return l
end
local function detacher(groupe)
	local dans = {}
	for _, p in ipairs(groupe) do dans[p] = true end
	for _, d in ipairs(fourgon:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = d.Part0, d.Part1
			if a and b and (dans[a] ~= dans[b]) then d:Destroy() end
		end
	end
end
local function charniere(porte)
	local groupe = {porte}
	for _, p in ipairs(accessoires(porte)) do table.insert(groupe, p) end
	detacher(groupe)
	local s = (porte.Position - centre):Dot(LATERAL)
	local cote = s >= 0 and 1 or -1
	local w = etendue(porte, LATERAL)
	local ep = etendue(porte, ARRIERE)
	-- charniere : bord exterieur de la porte, face arriere
	local pivot = porte.Position + LATERAL * cote * (w / 2) + ARRIERE * (ep / 2)
	local cfPivot = CFrame.new(pivot)
	local m = Instance.new("Motor6D"); m.Name = "CharnierePorte"
	m.Part0 = corps; m.Part1 = porte
	m.C0 = corps.CFrame:Inverse() * cfPivot
	m.C1 = porte.CFrame:Inverse() * cfPivot
	m.Parent = porte
	for i = 2, #groupe do
		local wc = Instance.new("WeldConstraint"); wc.Part0 = porte; wc.Part1 = groupe[i]; wc.Parent = groupe[i]
	end
	for _, p in ipairs(groupe) do
		p.Anchored = false; p.Massless = true
	end
	-- sens d'ouverture : le bord interieur part vers l'arriere
	local angle = math.rad(ANGLE_OUVERTURE) * (cote > 0 and -1 or 1)
	-- le repere de la charniere est aligne sur le monde au montage : son axe vertical est (0, 1, 0)
	return {moteur = m, c0 = m.C0, angle = angle, axeLocal = Vector3.new(0, 1, 0)}
end
local charnieres = {charniere(porteA), charniere(porteB)}

-- les cartons ne se cognent pas dans le fourgon (ils partent de l'interieur)
pcall(function() PhysicsService:RegisterCollisionGroup("CamionCartons_Camion") end)
pcall(function() PhysicsService:RegisterCollisionGroup("CamionCartons_Cartons") end)
pcall(function() PhysicsService:CollisionGroupSetCollidable("CamionCartons_Camion", "CamionCartons_Cartons", false) end)
for _, p in ipairs(pieces()) do p.CollisionGroup = "CamionCartons_Camion" end

------------------------------------------------------------------ 3. animation des portes
local function dos(x) local c1 = 1.2; local c3 = c1 + 1; return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2 end   -- leger rebond
local function lisse(x) return x * x * (3 - 2 * x) end
local function animerPortes(ouvrir, duree)
	local t0 = os.clock()
	while true do
		local u = math.min(1, (os.clock() - t0) / duree)
		local k = ouvrir and dos(u) or (1 - lisse(u))
		for _, c in ipairs(charnieres) do
			c.moteur.C0 = c.c0 * CFrame.fromAxisAngle(c.axeLocal, c.angle * k)
		end
		if u >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end
local function son(id, parent)
	if id == "" then return end
	local s = Instance.new("Sound"); s.SoundId = id; s.RollOffMaxDistance = 150; s.Parent = parent; s:Play(); Debris:AddItem(s, 5)
end

------------------------------------------------------------------ 4. la soute : dimensions + parois invisibles (seulement pour les cartons)
local fond = (porteA.Position + porteB.Position) / 2                      -- plan des portes (centre)
local hPorte = etendue(porteA, HAUT)
local plancher = fond.Y - hPorte / 2                                       -- bas des portes = plancher de la caisse
local plafond = fond.Y + hPorte / 2
local largeurSoute = (porteA.Position - porteB.Position):Dot(LATERAL)
largeurSoute = math.abs(largeurSoute) + (etendue(porteA, LATERAL) + etendue(porteB, LATERAL)) / 2 - 0.3
local caisse = fourgon:FindFirstChild("Caisse", true)
local longueurSoute = LONGUEUR_SOUTE or ((caisse and caisse:IsA("BasePart")) and etendue(caisse, ARRIERE) or etendue(corps, ARRIERE)) - 0.4
local baseSoute = Vector3.new(fond.X, plancher, fond.Z)
local function soute(x, y, z)   -- x : lateral, y : hauteur au-dessus du plancher, z : profondeur depuis les portes (vers l'avant)
	return baseSoute + LATERAL * x + HAUT * y - ARRIERE * z
end
pcall(function() PhysicsService:RegisterCollisionGroup("CamionCartons_Soute") end)
for _, g in ipairs({"Default", "CamionCartons_Camion"}) do
	pcall(function() PhysicsService:CollisionGroupSetCollidable("CamionCartons_Soute", g, false) end)
end
pcall(function() PhysicsService:CollisionGroupSetCollidable("CamionCartons_Soute", "CamionCartons_Cartons", true) end)
local parois = Instance.new("Folder"); parois.Name = "CamionCartons_Soute"; parois.Parent = fourgon
local function paroi(nom, taille, centreP)
	local p = Instance.new("Part"); p.Name = nom; p.Size = taille; p.Transparency = 1; p.CanQuery = false; p.CanTouch = false
	p.CFrame = CFrame.lookAt(centreP, centreP + ARRIERE); p.CollisionGroup = "CamionCartons_Soute"
	p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 1)       -- plancher glissant
	p.Anchored = corps.Anchored
	if not p.Anchored then
		p.Massless = true
		local wc = Instance.new("WeldConstraint"); wc.Part0 = corps; wc.Part1 = p; wc.Parent = p
	end
	p.Parent = parois
end
local hS = plafond - plancher
paroi("Plancher", Vector3.new(largeurSoute + 1, 1, longueurSoute + 0.5), soute(0, -0.5, longueurSoute / 2))
paroi("Plafond", Vector3.new(largeurSoute + 1, 1, longueurSoute + 0.5), soute(0, hS + 0.5, longueurSoute / 2))
paroi("Fond", Vector3.new(largeurSoute + 1, hS, 1), soute(0, hS / 2, longueurSoute + 0.5))
paroi("CoteG", Vector3.new(1, hS, longueurSoute + 0.5), soute(-largeurSoute / 2 - 0.5, hS / 2, longueurSoute / 2))
paroi("CoteD", Vector3.new(1, hS, longueurSoute + 0.5), soute(largeurSoute / 2 + 0.5, hS / 2, longueurSoute / 2))

------------------------------------------------------------------ 5. cartons
local CARTON = (function() local ok, m = pcall(function() return Enum.Material.Cardboard end); return ok and m or Enum.Material.Wood end)()
local dossierCartons = workspace:FindFirstChild("CamionCartons_Cartons") or Instance.new("Folder")
dossierCartons.Name = "CamionCartons_Cartons"; dossierCartons.Parent = workspace
local rng = Random.new()
local SECOURS = {carton_petit = Vector3.new(3.22, 2.6, 2.91), carton_moyen = Vector3.new(4.75, 3.52, 4.13), carton_grand = Vector3.new(6.43, 4.9, 5.21)}
local GLISSE = PhysicalProperties.new(0.35, 0.03, 0.15, 100, 1)       -- dans la caisse : ca glisse
local NORMAL = PhysicalProperties.new(0.35, 0.6, 0.25)                -- dehors : ca s'arrete
local function taille(m) return (MODELE[m] and MODELE[m].Size or SECOURS[m]) * ECHELLE_CARTONS end
local function nouveauCarton(m, cf)
	local c
	if MODELE[m] then
		c = MODELE[m]:Clone(); c.Size = MODELE[m].Size * ECHELLE_CARTONS
	else
		c = Instance.new("Part"); c.Size = SECOURS[m] * ECHELLE_CARTONS; c.Material = CARTON
		c.Color = Color3.fromRGB(196, 150, 98)
	end
	c.Name = "Carton"; c.CFrame = cf; c.Anchored = true; c.CanCollide = true
	c.CollisionGroup = "CamionCartons_Cartons"; c.CustomPhysicalProperties = GLISSE
	c.Parent = dossierCartons
	return c
end
-- remplit la caisse : tranches depuis les portes vers l'avant ; dans chaque tranche, des piles cote a cote
local function remplir(niv)
	local liste = {}
	local zMax = longueurSoute * niv.profondeur
	local hMax = hS * niv.hauteur - 0.05
	local z = 0.35
	while z < zMax - 0.5 do
		local epaisseur = 0
		local x = -largeurSoute / 2 + 0.1
		while true do
			-- modeles qui tiennent dans la largeur restante (on peut les tourner d'un quart de tour)
			local choix = {}
			for _, m in ipairs(niv.types) do
				local s = taille(m)
				if s.Y <= hMax then
					local sens = {}
					if x + s.X <= largeurSoute / 2 - 0.1 and z + s.Z <= longueurSoute - 0.1 then table.insert(sens, {m = m, w = s.X, d = s.Z, h = s.Y, tourne = false}) end
					if x + s.Z <= largeurSoute / 2 - 0.1 and z + s.X <= longueurSoute - 0.1 then table.insert(sens, {m = m, w = s.Z, d = s.X, h = s.Y, tourne = true}) end
					if #sens > 0 then table.insert(choix, sens[rng:NextInteger(1, #sens)]) end
				end
			end
			if #choix == 0 or #liste >= (niv.max or math.huge) then break end
			local c = choix[rng:NextInteger(1, #choix)]
			local nMax = math.floor(hMax / (c.h + 0.03))
			local n = (niv.hauteur >= 1) and nMax or math.max(1, nMax - rng:NextInteger(0, 1))
			n = math.min(n, (niv.max or math.huge) - #liste)
			for k = 1, n do
				local pos = soute(x + c.w / 2, (k - 1) * (c.h + 0.03) + c.h / 2 + 0.02, z + c.d / 2)
				local cf = CFrame.lookAt(pos, pos + ARRIERE) * CFrame.Angles(0, (c.tourne and math.pi / 2 or 0) + rng:NextNumber(-0.06, 0.06), 0)
				local carton = nouveauCarton(c.m, cf)
				table.insert(liste, {c = carton, z = z, y = k})
			end
			x += c.w + 0.08
			epaisseur = math.max(epaisseur, c.d)
		end
		if epaisseur == 0 or #liste >= (niv.max or math.huge) then break end
		z += epaisseur + 0.08
	end
	-- ordre de sortie : les plus proches des portes d'abord, le haut des piles avant le bas
	table.sort(liste, function(a, b) if math.abs(a.z - b.z) > 0.01 then return a.z < b.z end return a.y > b.y end)
	return liste
end
local function sorti(c) return (c.Position - fond):Dot(ARRIERE) > 0.6 end
local function ejecter(niv, liste)
	local n = #liste
	local actifs = {}
	local suivi = RunService.Heartbeat:Connect(function()
		for c, t0 in pairs(actifs) do
			if not c.Parent then actifs[c] = nil
			elseif sorti(c) or os.clock() - t0 > 5 then
				-- dehors : il se cogne a nouveau au camion et au decor, et ne glisse plus
				c.CollisionGroup = "Default"; c.CustomPhysicalProperties = NORMAL
				actifs[c] = nil
			end
		end
	end)
	local t0 = os.clock()
	for i, e in ipairs(liste) do
		local c = e.c
		if c.Parent then
			c.Anchored = false
			pcall(function() c:SetNetworkOwner(nil) end)
			local v = rng:NextNumber(niv.vitesse[1], niv.vitesse[2]) + e.z * 0.9          -- plus loin dans la caisse : plus vite
			c.AssemblyLinearVelocity = ARRIERE * v + HAUT * rng:NextNumber(0.5, 2.5) + LATERAL * rng:NextNumber(-1.2, 1.2)
				+ corps.AssemblyLinearVelocity
			c.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2))
			actifs[c] = os.clock()
			if i % 4 == 0 then son(SONS.Carton, c) end
		end
		local cible = t0 + niv.ejection * i / n
		while os.clock() < cible do RunService.Heartbeat:Wait() end
	end
	task.delay(6, function() suivi:Disconnect() end)
	-- disparition en fondu
	if VIE_CARTONS then task.delay(VIE_CARTONS, function()
		for k = 1, 10 do
			for _, e in ipairs(liste) do if e.c.Parent then e.c.Transparency = k / 10 end end
			task.wait(0.08)
		end
		for _, e in ipairs(liste) do e.c:Destroy() end
	end) end
end

------------------------------------------------------------------ 6. sequence + boutons
local occupe = false
local boutons = {}
local function sequence(nom)
	local niv = NIVEAUX[nom or NIVEAU_PAR_DEFAUT] or NIVEAUX[NIVEAU_PAR_DEFAUT]
	if occupe then return end
	occupe = true
	for _, b in ipairs(boutons) do b.Enabled = false end
	local liste = remplir(niv)              -- portes fermees : la caisse se charge
	son(SONS.Porte, porteA)
	animerPortes(true, DUREE_OUVERTURE)
	task.wait(ATTENTE_AVANT)
	ejecter(niv, liste)
	task.wait(FERMETURE_APRES)
	son(SONS.Porte, porteA)
	animerPortes(false, DUREE_OUVERTURE * 0.8)
	for _, b in ipairs(boutons) do b.Enabled = true end
	occupe = false
	-- Station tycoon : on previent le jeu (Livraison) avec la liste des cartons au sol
	local cartons = {}
	for _, e in ipairs(liste) do if e.c.Parent then table.insert(cartons, e.c) end end
	termine:Fire(cartons)
end
declencher.Event:Connect(function(nom) task.spawn(sequence, nom) end)

if BOUTONS then
	local a = Instance.new("Attachment"); a.Name = "BoutonPortes"; a.Parent = corps
	a.WorldPosition = fond + ARRIERE * 1.5
	for i, nom in ipairs(ORDRE) do
		local niv = NIVEAUX[nom]
		local b = Instance.new("ProximityPrompt"); b.Name = "Bouton" .. nom
		b.ActionText = niv.texte; b.ObjectText = "Ouvrir les portes"; b.KeyboardKeyCode = niv.touche
		b.HoldDuration = 0.3; b.MaxActivationDistance = 14; b.RequiresLineOfSight = false
		b.UIOffset = Vector2.new(0, (i - 2) * 72); b.Parent = a
		b.Triggered:Connect(function() task.spawn(sequence, nom) end)
		table.insert(boutons, b)
	end
end
local nm = 0; for _ in pairs(MODELE) do nm += 1 end
print(("CamionCartons v2 : pret (portes %s et %s, soute %.1f x %.1f x %.1f, %d modele(s) de carton)"):format(
	porteA.Name, porteB.Name, largeurSoute, hS, longueurSoute, nm))
