--[[ Tutoriel (v53) — ModuleScript ServerScriptService
	Premier lancement du jeu : le joueur recoit un plot deja construit (station basique, deux bouts de route, petite
	boutique avec une caisse) et ItsCirly, le guide, lui montre le cycle complet : la voiture entre, se gare, le joueur
	lave (E), le client va payer a la caisse, le joueur encaisse (E), la voiture repart. Puis la "vitrine" : le plot
	ultra avance d'ItsCirly.

	Le serveur orchestre les ETAPES et envoie au client (ClientTutoriel) "etape", nom, params ; le client repond
	"fini", nom quand ses plans camera / dialogues sont joues. Les evenements de jeu (voiture entree, garee, service,
	caisse, paye, partie) viennent de CarManager.Observer.

	API : Tutoriel.Lancer(player, spawnFolder, plotFolder, options)   options.rejouer = true : commande /tutoriel
	      Tutoriel.EnCours(player)
]]
local Tutoriel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local PlotManager = require(ServerScriptService:WaitForChild("PlotManager"))
local CarManager = require(ServerScriptService:WaitForChild("CarManager"))
local Circulation = require(ServerScriptService:WaitForChild("Circulation"))
local Acces = require(ServerScriptService:WaitForChild("Acces"))

local CASE, DEMI = 15, 7.5
local NX = PlayerData.MAX_X or 18
local GUIDE = "ItsCirly"
local VOITURE_TUTO = "Clio4"

local Event = ReplicatedStorage:FindFirstChild("TutorielEvent")
if not Event then
	Event = Instance.new("RemoteEvent"); Event.Name = "TutorielEvent"; Event.Parent = ReplicatedStorage
end

local EnCours = {}          -- [userId] = session { attentes = {nom = true}, finis = {nom = true}, evenements = {} }

function Tutoriel.EnCours(player) return EnCours[player.UserId] ~= nil end

-- ----------------------------------------------------------------------------------------------------------------------
-- outils
-- ----------------------------------------------------------------------------------------------------------------------
local function cfCase(pc, x, z, y)
	return pc:GetPivot() * CFrame.new((x - 0.5) * CASE, y or 0, (z - 0.5) * CASE - DEMI)
end

local function meubleDe(player, furnitureID)
	local folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not folder then return nil end
	for _, m in ipairs(folder:GetChildren()) do
		if m:GetAttribute("FurnitureID") == furnitureID then return m end
	end
	return nil
end

-- attend que le client dise "fini" pour l'etape `nom` (ou le delai) ; renvoie true si le joueur est toujours la
local function attendreFini(session, player, nom, delai)
	local t0 = os.clock()
	while player.Parent and EnCours[player.UserId] == session and not session.finis[nom] and os.clock() - t0 < (delai or 60) do
		task.wait(0.1)
	end
	return player.Parent ~= nil and EnCours[player.UserId] == session
end

-- attend un evenement CarManager (entre, gare, service, caisse, encaisse, paye, parti) ; renvoie infos ou nil (delai)
local function attendreEvenement(session, player, nom, delai)
	local t0 = os.clock()
	while player.Parent and EnCours[player.UserId] == session and session.evenements[nom] == nil and os.clock() - t0 < (delai or 90) do
		task.wait(0.1)
	end
	return session.evenements[nom]
end

local function etape(session, player, nom, params)
	session.finis[nom] = nil
	Event:FireClient(player, "etape", nom, params or {})
end


-- ----------------------------------------------------------------------------------------------------------------------
-- PNJ ItsCirly (apparence du compte Roblox ItsCirly, repli : mannequin)
-- ----------------------------------------------------------------------------------------------------------------------
local cacheUserId = nil
local function creerGuide()
	local modele = nil
	local okId, id = pcall(function() return cacheUserId or Players:GetUserIdFromNameAsync(GUIDE) end)
	if okId and type(id) == "number" then
		cacheUserId = id
		local okM, m = pcall(function() return Players:CreateHumanoidModelFromUserId(id) end)
		if okM and m then modele = m end
	end
	if not modele then
		local desc = Instance.new("HumanoidDescription")
		local okM, m = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
		if okM and m then modele = m end
	end
	if not modele then return nil end
	modele.Name = GUIDE
	local hum = modele:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = GUIDE
		hum.NameDisplayDistance = 120
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	end
	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false; p.CanQuery = false end
	end
	local root = modele:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = true end
	modele:SetAttribute("UserId", cacheUserId or 0)
	return modele
end

-- ----------------------------------------------------------------------------------------------------------------------
-- PLOT DE DEPART (coordonnees "logiques" type A : branche en X < 0, route du tour en Z < 0 ; miroir en X pour le type B)
-- ----------------------------------------------------------------------------------------------------------------------

local function construirePlotDepart(player, spawnFolder)
	local G = Acces.Geometrie(spawnFolder)
	if not G then return nil end
	local pc = G.pc
	local A = G.A
	local lettre = A and "A" or "B"
	local function mx(x) return A and x or (NX + 1 - x) end

	-- acces aux positions du tutoriel (rangees 4-5 cote branche, colonnes 10-11 / 8-9 cote route) : la disposition
	-- construite ci-dessous en depend
	local ENTREE_TUTO, SORTIE_TUTO = { A = 4, B = 4 }, { A = 10, B = 8 }
	local e, s = Acces.Lire(player, spawnFolder)
	if e ~= ENTREE_TUTO[lettre] then pcall(Acces.Deplacer, player, "Entree", ENTREE_TUTO[lettre]) end
	if s ~= SORTIE_TUTO[lettre] then pcall(Acces.Deplacer, player, "Sortie", SORTIE_TUTO[lettre]) end

	local function sol(nom, x, z) return PlotManager.Place(player, nom, "Sol", 0, cfCase(pc, mx(x), z)) end
	local function meuble(nom, x, z, o)
		if not A then
			-- miroir en X : orientation 0 <-> 2 (1 et 3 inchangees) ; les meubles 1 x 1 a pivot central ne bougent pas
			if o == 0 then o = 2 elseif o == 2 then o = 0 end
		end
		return PlotManager.Place(player, nom, "Furniture", o, cfCase(pc, mx(x), z, 0.616))
	end
	-- murs : MurNord (orientation 0) = bord +X de la case ; MurOuest (orientation 1) = bord -Z de la case
	local function murN(nom, x, z) local xx = A and x or (mx(x) - 1); return PlotManager.Place(player, nom, "Mur", 0, cfCase(pc, xx, z)) end
	local function murO(nom, x, z) return PlotManager.Place(player, nom, "Mur", 1, cfCase(pc, mx(x), z)) end

	-- 1. goudron : couloir d'entree (rangees 3-6, colonnes 1-11) + couloir de sortie (colonnes 10-11, rangees 1-2)
	local chemin = {}
	for x = 1, 11 do
		for z = 3, 6 do sol("sol_goudron", x, z) end
		table.insert(chemin, {mx(x), 4}); table.insert(chemin, {mx(x), 5})
	end
	for _, z in ipairs({2, 1}) do
		for _, x in ipairs({10, 11}) do sol("sol_goudron", x, z); table.insert(chemin, {mx(x), z}) end
	end

	-- 2. la station : L1_Vide au centre (7, 5), orientee pour que la voiture la traverse dans le sens entree -> sortie.
	-- On essaie les orientations et on garde la premiere desservie (couloir d'entree ET couloir de sortie).
	local data = PlayerData.GetData(player)
	local stationID, orientationStation = nil, 3
	local avant = {}
	if data and data.Stations then for id in pairs(data.Stations) do avant[id] = true end end
	local pivot = pc:GetPivot()
	for _, o in ipairs({3, 1, 0, 2}) do
		if PlotManager.Place(player, "L1_Vide", "Furniture", o, cfCase(pc, mx(7), 5, 0.616)) then
			local id = nil
			for k in pairs(data.Stations) do if not avant[k] then id = k end end
			local carte = Circulation.Carte(player)
			local cf = id and CarManager.CfStation and CarManager.CfStation(player, id)
			local ok = cf and carte and Circulation.StationDesservie(carte, pivot, spawnFolder, cf)
			local retour = ok and Circulation.CheminSortie(carte, pivot, spawnFolder, cf)
			if ok and retour then stationID = id; orientationStation = o break end
			local m = id and meubleDe(player, id)
			if m then PlotManager.Destroy(player, m) else break end
		end
	end
	if not stationID and data and data.Stations then
		-- rejeu (/tutoriel) sur un plot deja construit : on prend une station existante
		for id, st in pairs(data.Stations) do if st.X == mx(7) and st.Z == 5 then stationID = id end end
		if not stationID then for id in pairs(data.Stations) do stationID = id end end
	end
	if stationID then
		local st = data.Stations[stationID]
		if st and (st.Quantity or 0) < 3 then PlayerData.FillStation(player, stationID, st.Item or "1", 6) end
	end

	-- 3. le chemin a pied : paves de la station a la boutique
	local pietons = { {7, 6}, {8, 6}, {9, 6}, {9, 7}, {10, 7}, {11, 7}, {12, 7}, {12, 8}, {13, 8} }
	for _, c in ipairs({ {9, 7}, {10, 7}, {11, 7}, {12, 7}, {12, 8}, {12, 9} }) do sol("sol_paves", c[1], c[2]) end
	local bleues = {}
	for _, c in ipairs(pietons) do table.insert(bleues, {mx(c[1]), c[2]}) end

	-- 4. la boutique : carrelage 13-15 x 7-9, murs crepi, porte (ouverture) cote ouest en (12/13, 8)
	for x = 13, 15 do for z = 7, 9 do sol("sol_carrelage_gris", x, z) end end
	for x = 13, 15 do murO("mur_plein_crepi", x, 7); murO("mur_plein_crepi", x, 10) end
	murN("mur_fenetre_simple_crepi", 15, 7); murN("mur_porte_double_vitree_crepi", 15, 8); murN("mur_fenetre_simple_crepi", 15, 9)
	murN("mur_fenetre_simple_crepi", 12, 7); murN("mur_plein_crepi", 12, 9)

	-- 5. la caisse (face a l'ouest : le client fait la queue cote porte), un peu de decor
	local caisseOK
	if A then caisseOK = meuble("1", 14, 8, 0) else caisseOK = PlotManager.Place(player, "1", "Furniture", 2, cfCase(pc, mx(14), 9, 0.616)) end
	meuble("3", 15, 9, 0)
	meuble("pot_buisson", 13, 9, 0)
	meuble("pot_buisson", 12, 9, 0)
	meuble("pot_buisson", 15, 7, 0)

	local caisseID = nil
	if data and data.Caisses then for id in pairs(data.Caisses) do caisseID = id end end

	return {
		A = A, pivot = pivot, nx = NX, nz = select(2, PlayerData.GetPlotSize(player)) or 11,
		stationID = stationID, caisseID = caisseID, caisseOK = caisseOK, orientationStation = orientationStation,
		station = {mx(7), 5}, caisse = {mx(14), 8}, boutique = {mx(14), 8}, joueurLavage = {mx(7), 7},
		chemin = chemin, pietons = bleues,
		-- centres des blocs d'acces (en cases, pour ClientTutoriel.monde)
		entree = {mx(1) + (A and 0.5 or -0.5), 4.5}, sortie = {mx(10) + (A and 0.5 or -0.5), 1.5},
	}
end

-- plot libre le plus proche pour la vitrine d'ItsCirly (construite par le client, purement visuelle)
local function plotVitrine(spawnFolder)
	local dossier = workspace:FindFirstChild("PlotSpawns")
	local pc0 = spawnFolder:FindFirstChild("PlotCenter")
	if not (dossier and pc0) then return nil end
	local meilleur, dmin = nil, math.huge
	for _, sf in ipairs(dossier:GetChildren()) do
		local pc = sf:FindFirstChild("PlotCenter")
		if sf ~= spawnFolder and pc and sf:GetAttribute("OwnerId") == nil then
			local d = (pc.Position - pc0.Position).Magnitude
			if d < dmin then meilleur, dmin = sf, d end
		end
	end
	return meilleur
end

-- ----------------------------------------------------------------------------------------------------------------------
-- LANCEMENT
-- ----------------------------------------------------------------------------------------------------------------------
function Tutoriel.Lancer(player, spawnFolder, plotFolder, options)
	if EnCours[player.UserId] then return false end
	local data = PlayerData.GetData(player)
	if not data then return false end
	-- un joueur qui a deja construit (profil d'avant la v53) n'a pas besoin du tutoriel : on ne lui ajoute pas un plot
	-- de depart par-dessus le sien. /tutoriel (rejouer) passe outre.
	local dejaConstruit = false
	if data.Stations then for _ in pairs(data.Stations) do dejaConstruit = true end end
	if data.Caisses then for _ in pairs(data.Caisses) do dejaConstruit = true end end
	if dejaConstruit and not (options and options.rejouer) then data.Tutoriel = true return false end
	local session = { finis = {}, evenements = {} }
	EnCours[player.UserId] = session

	-- reponses du client
	local connexion = Event.OnServerEvent:Connect(function(p, quoi, nom)
		if p ~= player or EnCours[player.UserId] ~= session then return end
		if quoi == "fini" and type(nom) == "string" then session.finis[nom] = true end
	end)

	-- evenements de jeu
	CarManager.Observer(player, function(evenement, car, infos)
		session.evenements[evenement] = { car = car, infos = infos or {}, t = os.clock() }
	end)
	CarManager.Pause(player, true)

	local dossier = Instance.new("Folder"); dossier.Name = "Tutoriel_" .. player.UserId; dossier.Parent = workspace
	local focus = nil

	local function nettoyer()
		connexion:Disconnect()
		CarManager.Observer(player, nil)
		CarManager.Pause(player, false)
		if player.Parent then player.ReplicationFocus = nil end
		dossier:Destroy()
		if EnCours[player.UserId] == session then EnCours[player.UserId] = nil end
	end

	local ok, err = pcall(function()
		-- 0. le plot de depart
		local P = construirePlotDepart(player, spawnFolder)
		if not P then error("plot de depart impossible") end
		P.guide = creerGuide()
		if P.guide then P.guide.Parent = dossier end
		local guide = P.guide
		local function placerGuide(cf)
			if guide and guide.Parent then guide:PivotTo(cf * CFrame.new(0, 3, 0)) end
		end

		-- position de depart : le trottoir devant le plot (PlayerSpawn du PlotSpawn)
		local spawn = spawnFolder:FindFirstChild("PlayerSpawn")
		local cfSpawn = spawn and spawn:GetPivot() or cfCase(spawnFolder.PlotCenter, 9, 0)
		local character = player.Character or player.CharacterAdded:Wait()
		character:PivotTo(cfSpawn * CFrame.new(0, 3, 0))
		-- le guide a 5 studs a droite du joueur, tourne vers lui
		local posGuide = (cfSpawn * CFrame.new(5, 0, 0)).Position
		placerGuide(CFrame.lookAt(posGuide, cfSpawn.Position))

		local commun = { pivot = P.pivot, A = P.A, nx = P.nx, nz = P.nz, guide = guide, plotSpawn = spawnFolder, orientationStation = P.orientationStation }
		local dossierVoitures = "Cars_" .. player.UserId

		-- v56 (Thomas) : ItsCirly ARRIVE DANS SON PICK-UP F-150, assis dans la benne ; le pick-up descend la branche, derape en
		-- entrant dans le plot (deux roues, ItsCirly manque de tomber de la benne), retombe et va se garer sur l'herbe.
		-- Tout est joue cote client (ClientTutoriel) a partir de ces points ; le modele doit etre dans ReplicatedStorage
		-- (Model "F150", ou Folder "F150_Peintures" avec les 5 couleurs : une au hasard). Sans modele : ancien comportement.
		local pickup = nil
		do
			local okP, res = pcall(function()
				local modele = ReplicatedStorage:FindFirstChild("F150") or ReplicatedStorage:FindFirstChild("F150_Peintures")
				if not modele then return nil end
				local pc = spawnFolder.PlotCenter
				local function mx(x) return P.A and x or (NX + 1 - x) end
				local points = {}
				local file = spawnFolder:FindFirstChild("QueueNodes")
				local n = file and #file:GetChildren() or 0
				for i = math.min(n, 5), 1, -1 do                        -- les 5 derniers noeuds de la file, du haut vers l'entree
					local node = file:FindFirstChild(tostring(i))
					if node then table.insert(points, { cf = node.CFrame, v = (i <= 2) and 26 or 34 }) end
				end
				local entree = spawnFolder:FindFirstChild("Entree")
				local trottoir = entree and entree:FindFirstChild("Trottoir")
				if trottoir then table.insert(points, { cf = trottoir.CFrame, v = 24, derapage = true }) end
				if entree then table.insert(points, { cf = entree.CFrame, v = 20, derapage = true }) end
				local dirPlot = entree and entree.CFrame.LookVector or (pc:GetPivot().RightVector * (P.A and 1 or -1))
				local c1 = cfCase(pc, mx(3), 4.5, 0.6)
				table.insert(points, { cf = CFrame.lookAt(c1.Position, c1.Position + dirPlot), v = 13, derapage = true })
				-- parking sur l'herbe : colonnes 3-4, rangee 8 (hors du goudron, de la station et du chemin pieton)
				local c2 = cfCase(pc, mx(3.5), 6.6, 0.6)
				local park = cfCase(pc, mx(3.5), 8.6, 0.6)
				local versFond = (park.Position - c2.Position).Unit
				table.insert(points, { cf = CFrame.lookAt(c2.Position, c2.Position + versFond), v = 8 })
				local cfPark = CFrame.lookAt(park.Position, park.Position + versFond)
				table.insert(points, { cf = cfPark, v = 0 })
				return { modele = modele.Name, points = points, parking = cfPark, versJoueur = cfSpawn.Position }
			end)
			if okP then pickup = res else warn("[Tutoriel] pickup : " .. tostring(res)) end
		end

		-- 1. ACCUEIL
		etape(session, player, "accueil", { commun = commun, spawn = cfSpawn, rejouer = options and options.rejouer or false, pickup = pickup })
		if not attendreFini(session, player, "accueil", 40) then return end

		-- 2. LE PLOT : cases vertes (voitures) puis bleues (pietons), indicateur sur l'entree
		etape(session, player, "plot", { commun = commun, chemin = P.chemin, pietons = P.pietons, entree = P.entree, sortie = P.sortie, station = P.station, caisse = P.caisse })
		if not attendreFini(session, player, "plot", 60) then return end

		-- 3. LA PREMIERE VOITURE : depart immediat, ItsCirly sur le toit (cote client)
		session.evenements.entre = nil; session.evenements.gare = nil
		local car = CarManager.DepartImmediat(player, VOITURE_TUTO, 6)
		etape(session, player, "voiture", { commun = commun, voiture = car, voitureNom = car and car.Name, dossierVoitures = dossierVoitures, pickup = pickup })
		local entre = attendreEvenement(session, player, "entre", 90)
		if not player.Parent then return end

		-- 4. VUE DU DESSUS : la voiture entre et se gare
		car = car or (entre and entre.car)
		etape(session, player, "arrivee", { commun = commun, voiture = car, voitureNom = car and car.Name, dossierVoitures = dossierVoitures, station = P.station })
		local gare = attendreEvenement(session, player, "gare", 60)
		if not player.Parent then return end
		car = car or (gare and gare.car) or (entre and entre.car)
		Event:FireClient(player, "garee")
		if not attendreFini(session, player, "arrivee", 20) then return end

		-- 5. LAVER : le joueur est teleporte dans la station avec ItsCirly ; E pour laver
		local cfLav = cfCase(spawnFolder.PlotCenter, P.joueurLavage[1], P.joueurLavage[2], 1)
		character = player.Character or character
		if character then character:PivotTo(cfLav * CFrame.new(0, 3, 0)) end
		local cfSt = cfCase(spawnFolder.PlotCenter, P.station[1], P.station[2], 1)
		placerGuide(CFrame.lookAt((cfLav * CFrame.new(-4, 0, 0)).Position, cfSt.Position))
		etape(session, player, "laver", { commun = commun, voiture = car, station = P.station, stationID = P.stationID, cfJoueur = cfLav * CFrame.new(0, 3, 0) })
		attendreEvenement(session, player, "service", 120)
		if not player.Parent then return end
		Event:FireClient(player, "lavage")

		-- 6. SUIVRE LE CLIENT : il descend et marche jusqu'a la caisse ; le joueur encaisse (E)
		local caisse = attendreEvenement(session, player, "caisse", 90)
		if not player.Parent then return end
		local cfCaisse = cfCase(spawnFolder.PlotCenter, P.caisse[1], P.caisse[2], 1)
		-- le guide attend dans la boutique, derriere la caisse
		placerGuide(CFrame.lookAt((cfCaisse * CFrame.new(P.A and 12 or -12, 0, -6)).Position, cfCaisse.Position))
		etape(session, player, "suivre", { commun = commun, pnj = caisse and caisse.infos.pnj, caisse = P.caisse, caisseID = P.caisseID })
		local paye = attendreEvenement(session, player, "encaisse", 150) or attendreEvenement(session, player, "paye", 5)
		if not player.Parent then return end
		Event:FireClient(player, "paye", paye and paye.infos or {})

		-- 7. LA VOITURE REPART
		local parti = attendreEvenement(session, player, "parti", 60)
		car = (parti and parti.car) or car
		etape(session, player, "depart", { commun = commun, voiture = car, voitureNom = car and car.Name, dossierVoitures = dossierVoitures, sortie = P.sortie })
		if not attendreFini(session, player, "depart", 25) then return end

		-- 8. LA VITRINE D'ITSCIRLY : plot libre voisin, construit par le client ; focus de replication la-bas
		local vitrine = plotVitrine(spawnFolder)
		if vitrine then
			focus = Instance.new("Part"); focus.Anchored = true; focus.CanCollide = false; focus.Transparency = 1
			focus.Size = Vector3.new(1, 1, 1); focus.CFrame = vitrine.PlotCenter:GetPivot() * CFrame.new(135, 10, 100); focus.Parent = dossier
			player.ReplicationFocus = focus
			placerGuide(vitrine.PlotCenter:GetPivot() * CFrame.new(135, 0, 120))
		end
		etape(session, player, "vitrine", { commun = commun, vitrine = vitrine })
		if not attendreFini(session, player, "vitrine", 70) then return end
		if player.Parent then player.ReplicationFocus = nil end

		-- 9. FIN : retour au plot, les voitures reprennent
		character = player.Character or character
		if character then character:PivotTo(cfLav * CFrame.new(0, 3, 0)) end
		placerGuide(CFrame.lookAt((cfLav * CFrame.new(-4, 0, 0)).Position, cfLav.Position))
		etape(session, player, "fin", { commun = commun, cfJoueur = cfLav * CFrame.new(0, 3, 0) })
		attendreFini(session, player, "fin", 30)
		data.Tutoriel = true
	end)
	if not ok then warn("[Tutoriel] " .. tostring(err)) end
	data.Tutoriel = true
	nettoyer()
	return true
end

return Tutoriel
