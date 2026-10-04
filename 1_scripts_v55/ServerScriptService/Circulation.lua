--[[ Circulation (ModuleScript, ServerScriptService) — les voitures ROULENT SUR LE PLOT sans traverser les objets.
	Regles (Thomas) :
	  * une voiture a besoin d'un couloir de DEUX CASES DE LARGE (30 studs) fait de goudron (sol_goudron / sol_route /
	    sol_beton), sans meuble, sans mur, de l'entree du plot jusqu'a l'entree de la station (pour entrer), puis de la
	    sortie de la station jusqu'a la sortie du plot (pour repartir : v51, sinon elle attend dans la station) ;
	  * s'il n'y a pas de couloir d'entree, la voiture ne peut pas entrer : elle passe son chemin (et le joueur est prevenu) ;
	  * v51 : l'entree est sur le bord de la BRANCHE (colonnes 1-2 ou 17-18), la sortie sur le bord de la ROUTE DU TOUR
	    (rangees 1-2) ; toutes deux deplacables (Acces) ;
	  * conduite realiste : la voiture ralentit en arrivant au plot, roule doucement dans le plot et encore moins vite dans
	    les virages, puis reaccelere sur la route.

	Modele : la grille du plot (cases de 10 studs, PlayerData.GetGrid ; case (x, z) centree en (10x - 5, 0, 10z - 10) dans
	le repere du PlotCenter). La voiture est representee par un BLOC 2 x 2 cases dont le centre est un coin de case :
	bloc (bx, bz) = cases (bx..bx+1, bz..bz+1), centre local (10 bx, 0, 10 bz - 5). Un bloc est libre si ses 4 cases sont
	roulables et qu'aucun mur ne le traverse ; un deplacement d'un bloc a son voisin est possible si aucun mur ne coupe les
	deux cases franchies. Recherche de chemin en largeur (BFS) sur les blocs, puis simplification en points de virage.
	Murs : grid[x][z].MurNord = mur sur le bord +X de la case, MurOuest = mur sur le bord -Z (convention de PlotManager).
]]
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local Circulation = {}

-- vitesses (studs/s)
Circulation.VITESSE_ROUTE = 32        -- sur la route (CarManager.VITESSE)
Circulation.VITESSE_APPROCHE = 18     -- carrefour -> devant l'entree -> dans le plot : on ralentit
Circulation.VITESSE_PLOT = 11         -- ligne droite dans le plot
Circulation.VITESSE_VIRAGE = 6.5      -- virage a 90 degres dans le plot
Circulation.VITESSE_STATION = 5       -- derniers metres pour se garer / redemarrer

-- v48 : QUADRILLAGE DE 15 STUDS (CASE) ; DEMI = demi-case. Les meshes de 10 studs du pack sont agrandis x1,5 (ECHELLE).
local CASE = rawget(_G, "CASE_TEST") or 15
local DEMI = CASE / 2
local ECHELLE = CASE / 10

-- sols sur lesquels une voiture roule (carte "Goudron" du menu Sol + route + beton)
Circulation.SOLS_ROULANTS = { sol_goudron = true, sol_route = true, sol_beton = true }

-- nom du sol d'une case : la grille memorise "nom#orientation" (PlotManager.Encoder) ou, ancien format, "nom"
function Circulation.NomSol(valeur)
	if type(valeur) ~= "string" then return nil end
	return string.match(valeur, "^(.-)#%d+$") or valeur
end
-- (BUG corrige v40 : la comparaison directe SOLS_ROULANTS[c.Sol] ignorait le suffixe "#orientation" : aucun sol n'etait
--  jamais roulable et aucune voiture ne pouvait entrer sur le plot)
function Circulation.SolRoulant(valeur)
	local nom = Circulation.NomSol(valeur)
	return nom ~= nil and Circulation.SOLS_ROULANTS[nom] == true
end

local RECUL_ENTREE = 2.5 * CASE               -- studs : point d'entree d'une station = place de parking reculee de 25 studs (hors du 3 x 3)
local AVANCE_SORTIE = 2.5 * CASE              -- studs : point de sortie = 25 studs apres la place

-- ----------------------------------------------------------------------------------------------------------------------
-- carte du plot
-- ----------------------------------------------------------------------------------------------------------------------
-- v54 : demi-grille (petits meubles, ReplicatedStorage > Demi) : une case dont une demi-case est occupee est bloquee
local function demiOccupee(demi, x, z)
	if not demi then return false end
	local a, b = 2 * x, 2 * z
	return demi[(a - 1) .. "_" .. (b - 1)] ~= nil or demi[a .. "_" .. (b - 1)] ~= nil or demi[(a - 1) .. "_" .. b] ~= nil or demi[a .. "_" .. b] ~= nil
end
Circulation.DemiOccupee = demiOccupee

local function roulable(grid, nx, nz, x, z, demi)
	if x < 1 or z < 1 or x > nx or z > nz then return false end
	local c = grid[x] and grid[x][z]
	if not c then return false end
	if c.Furniture ~= 0 and c.Furniture ~= nil then return false end
	if demiOccupee(demi, x, z) then return false end
	return Circulation.SolRoulant(c.Sol)
end

-- mur entre (x, z) et (x + 1, z) : MurNord de (x, z) ; entre (x, z) et (x, z - 1) : MurOuest de (x, z)
local function murX(grid, x, z) local c = grid[x] and grid[x][z]; return c ~= nil and c.MurNord ~= 0 and c.MurNord ~= nil end
local function murZ(grid, x, z) local c = grid[x] and grid[x][z]; return c ~= nil and c.MurOuest ~= 0 and c.MurOuest ~= nil end

function Circulation.Carte(player)
	local grid = PlayerData.GetGrid(player)
	local nx, nz = PlayerData.GetPlotSize(player)
	if not (grid and nx and nz) then return nil end
	local demi = PlayerData.GetDemi and PlayerData.GetDemi(player, false) or nil
	local C = { grid = grid, nx = nx, nz = nz, demi = demi }
	-- bloc (bx, bz) libre : 4 cases roulables, pas de mur interieur
	function C.blocLibre(bx, bz)
		if bx < 1 or bz < 1 or bx + 1 > nx or bz + 1 > nz then return false end
		if not (roulable(grid, nx, nz, bx, bz, demi) and roulable(grid, nx, nz, bx + 1, bz, demi)
			and roulable(grid, nx, nz, bx, bz + 1, demi) and roulable(grid, nx, nz, bx + 1, bz + 1, demi)) then return false end
		if murX(grid, bx, bz) or murX(grid, bx, bz + 1) then return false end          -- mur vertical au milieu
		if murZ(grid, bx, bz + 1) or murZ(grid, bx + 1, bz + 1) then return false end  -- mur horizontal au milieu
		return true
	end
	-- passage du bloc (bx, bz) au bloc voisin dans la direction (dx, dz) (un seul des deux non nul)
	function C.passage(bx, bz, dx, dz)
		if dx == 1 then return not (murX(grid, bx + 1, bz) or murX(grid, bx + 1, bz + 1)) end
		if dx == -1 then return not (murX(grid, bx - 1, bz) or murX(grid, bx - 1, bz + 1)) end
		if dz == 1 then return not (murZ(grid, bx, bz + 2) or murZ(grid, bx + 1, bz + 2)) end
		if dz == -1 then return not (murZ(grid, bx, bz) or murZ(grid, bx + 1, bz)) end        -- frontiere bz-1 | bz
		return false
	end
	return C
end

-- ----------------------------------------------------------------------------------------------------------------------
-- conversions repere du plot <-> grille
-- ----------------------------------------------------------------------------------------------------------------------
-- coupe les erreurs d'arrondi (une rotation de 90 degres donne des composantes en 1e-8 au lieu de 0 : sans cela, un point
-- exactement sur un coin de case pouvait tomber dans la case voisine et decaler le bloc d'entree/sortie d'une station)
local function net(v) return math.round(v * 1000) / 1000 end
local function nul(v) return math.abs(v) < 1e-4 and 0 or v end

-- case contenant un point du monde
function Circulation.CaseDe(pivot, position)
	local l = pivot:PointToObjectSpace(position)
	return math.floor(net(l.X) / CASE) + 1, math.floor((net(l.Z) + DEMI) / CASE) + 1
end

-- bloc dont le centre (coin de case) est le plus proche d'un point du monde
function Circulation.BlocDe(carte, pivot, position)
	local l = pivot:PointToObjectSpace(position)
	local bx = math.clamp(math.floor(net(l.X) / CASE + 0.5), 1, carte.nx - 1)
	local bz = math.clamp(math.floor((net(l.Z) + DEMI) / CASE + 0.5), 1, carte.nz - 1)
	return bx, bz
end

function Circulation.MondeBloc(pivot, bx, bz, y)
	local p = pivot:PointToWorldSpace(Vector3.new(CASE * bx, 0, CASE * bz - DEMI))
	return Vector3.new(p.X, y, p.Z)
end

-- ----------------------------------------------------------------------------------------------------------------------
-- chemin (BFS sur les blocs)
-- ----------------------------------------------------------------------------------------------------------------------
local DIRS = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }

-- renvoie la liste des blocs {bx, bz} du depart a l'arrivee (inclus), ou nil s'il n'y a pas de couloir
function Circulation.Chemin(carte, dbx, dbz, abx, abz)
	if not carte.blocLibre(dbx, dbz) or not carte.blocLibre(abx, abz) then return nil end
	if dbx == abx and dbz == abz then return { {dbx, dbz} } end
	local cle = function(x, z) return x * 1000 + z end
	local file, tete = { {dbx, dbz} }, 1
	local parent = { [cle(dbx, dbz)] = false }
	while tete <= #file do
		local b = file[tete]; tete += 1
		for _, d in ipairs(DIRS) do
			local nx2, nz2 = b[1] + d[1], b[2] + d[2]
			local k = cle(nx2, nz2)
			if parent[k] == nil and carte.blocLibre(nx2, nz2) and carte.passage(b[1], b[2], d[1], d[2]) then
				parent[k] = b
				if nx2 == abx and nz2 == abz then
					local chemin, cur = {}, {nx2, nz2}
					while cur do table.insert(chemin, 1, cur); cur = parent[cle(cur[1], cur[2])] end
					return chemin
				end
				table.insert(file, {nx2, nz2})
			end
		end
	end
	return nil
end

-- ----------------------------------------------------------------------------------------------------------------------
-- trajet : points de virage + vitesses (conduite realiste)
-- ----------------------------------------------------------------------------------------------------------------------
-- chemin de blocs -> liste d'etapes {cf = CFrame, vitesse = studs/s}. La voiture regarde dans le sens de la marche ;
-- a un virage elle arrive lentement, tourne (courbe de Bezier cote client) et repart.
function Circulation.Trajet(carte, pivot, chemin, y, capFinal)
	local etapes = {}
	if #chemin == 0 then return etapes end
	local function pos(b) return Circulation.MondeBloc(pivot, b[1], b[2], y) end
	-- points de virage : on garde les blocs ou la direction change, plus le dernier
	local coins = {}
	for i = 2, #chemin - 1 do
		local d1 = { chemin[i][1] - chemin[i - 1][1], chemin[i][2] - chemin[i - 1][2] }
		local d2 = { chemin[i + 1][1] - chemin[i][1], chemin[i + 1][2] - chemin[i][2] }
		if d1[1] ~= d2[1] or d1[2] ~= d2[2] then table.insert(coins, i) end
	end
	table.insert(coins, #chemin)
	local precedent = pos(chemin[1])
	for n, i in ipairs(coins) do
		local p = pos(chemin[i])
		-- direction de sortie du point : vers le bloc suivant s'il existe, sinon la direction d'arrivee (ou le cap final)
		local suivant = chemin[i + 1] and pos(chemin[i + 1]) or nil
		local dir
		if suivant then dir = (suivant - p) else dir = (p - precedent) end
		if n == #coins and capFinal then dir = capFinal end
		if dir.Magnitude < 1e-3 then dir = Vector3.new(0, 0, -1) end
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		-- vitesse : un virage (direction d'arrivee differente de la direction de sortie) se prend lentement
		local arrivee = (p - precedent); arrivee = Vector3.new(arrivee.X, 0, arrivee.Z)
		local virage = arrivee.Magnitude > 1e-3 and arrivee.Unit:Dot(dir) < 0.9
		table.insert(etapes, { cf = CFrame.lookAt(p, p + dir), vitesse = virage and Circulation.VITESSE_VIRAGE or Circulation.VITESSE_PLOT })
		precedent = p
	end
	return etapes
end

-- ----------------------------------------------------------------------------------------------------------------------
-- points d'une station : entree (25 studs avant la place, en dehors du 3 x 3) et sortie (25 studs apres)
-- ----------------------------------------------------------------------------------------------------------------------
function Circulation.PointsStation(cfParc)
	local look = Vector3.new(nul(cfParc.LookVector.X), 0, nul(cfParc.LookVector.Z)).Unit
	local entree = cfParc.Position - look * RECUL_ENTREE
	local sortie = cfParc.Position + look * AVANCE_SORTIE
	return CFrame.lookAt(entree, entree + look), CFrame.lookAt(sortie, sortie + look)
end

-- Y de roulage dans le plot (celui du noeud Entree)
function Circulation.YPlot(spawnFolder, pivot)
	local e = spawnFolder and spawnFolder:FindFirstChild("Entree")
	if not e then
		local d = spawnFolder and spawnFolder:FindFirstChild("Entrees")
		e = d and d:FindFirstChildWhichIsA("BasePart")
	end
	return e and e.Position.Y or (pivot.Position.Y + 0.75)
end

-- blocs d'entree et de sortie du plot. v54 (acces implicites, Acces) : plusieurs blocs possibles, chacun porte par un
-- noeud du PlotSpawn avec les attributs BlocX / BlocZ : Entrees/<bz> (Part : noeud dans le plot ; enfants Trottoir, Achat)
-- et Sorties/<bx> (Folder de noeuds 1..N). Compat : noeud Entree et dossier ExitNodes (acces principal, ancien PlotSpawn).
local function blocNoeud(carte, pivot, n)
	local bx, bz = n:GetAttribute("BlocX"), n:GetAttribute("BlocZ")
	if type(bx) == "number" and type(bz) == "number" then return bx, bz end
	return Circulation.BlocDe(carte, pivot, n.Position)
end
-- liste des entrees : { {bx, bz, noeud}, ... } (noeud = Part dans le plot, enfants Trottoir / Achat)
function Circulation.Entrees(carte, pivot, spawnFolder)
	local liste = {}
	local d = spawnFolder:FindFirstChild("Entrees")
	if d then
		for _, n in ipairs(d:GetChildren()) do
			if n:IsA("BasePart") then local bx, bz = blocNoeud(carte, pivot, n); table.insert(liste, {bx, bz, n}) end
		end
	end
	if #liste == 0 then
		local e = spawnFolder:FindFirstChild("Entree")
		if e then local bx, bz = blocNoeud(carte, pivot, e); table.insert(liste, {bx, bz, e}) end
	end
	-- la plus proche du tunnel d'abord (c'est l'entree principale : la file des clients commence devant elle)
	table.sort(liste, function(a, b) return a[2] > b[2] end)
	return liste
end
-- liste des sorties : { {bx, bz, dossier}, ... } (dossier = noeuds 1..N du trajet de sortie)
function Circulation.Sorties(carte, pivot, spawnFolder)
	local liste = {}
	local d = spawnFolder:FindFirstChild("Sorties")
	if d then
		for _, f in ipairs(d:GetChildren()) do
			local n1 = f:FindFirstChild("1")
			if n1 then local bx, bz = blocNoeud(carte, pivot, n1); table.insert(liste, {bx, bz, f}) end
		end
	end
	if #liste == 0 then
		local ex = spawnFolder:FindFirstChild("ExitNodes")
		local n1 = ex and ex:FindFirstChild("1")
		if n1 then local bx, bz = blocNoeud(carte, pivot, n1); table.insert(liste, {bx, bz, ex}) end
	end
	table.sort(liste, function(a, b) return a[1] < b[1] end)
	return liste
end
-- (compat) premier bloc d'entree et de sortie
function Circulation.BlocsAcces(carte, pivot, spawnFolder)
	local e, s = Circulation.Entrees(carte, pivot, spawnFolder)[1], Circulation.Sorties(carte, pivot, spawnFolder)[1]
	if not (e and s) then return nil end
	return e[1], e[2], s[1], s[2]
end
-- blocs (bx) dont les DEUX cases sont entierement dans la bande de `largeur` studs (defaut : l'acces, 30) centree sur
-- un point (repere du plot). Le bloc principal (le plus proche du point) vient en premier. Sert aux entrees/sorties des
-- stations (3 cases de large : la route de 2 cases peut etre a gauche ou a droite).
local LARGEUR_ACCES = 30
function Circulation.BlocsCandidats(carte, pivot, position, largeur)
	largeur = largeur or LARGEUR_ACCES
	local l = pivot:PointToObjectSpace(position)
	local a, b = net(l.X) - largeur / 2, net(l.X) + largeur / 2
	local c0, c1 = math.ceil((a - 0.01) / CASE) + 1, math.floor((b + 0.01) / CASE)   -- premiere / derniere case entierement dedans
	local principal = math.clamp(math.floor(net(l.X) / CASE + 0.5), 1, carte.nx - 1)
	local liste = {principal}
	for bx = c0, c1 - 1 do
		if bx >= 1 and bx + 1 <= carte.nx and bx ~= principal then table.insert(liste, bx) end
	end
	return liste
end
-- meme chose sur l'axe Z (bloc bz dont les deux cases sont dans la bande) : pour une station orientee le long de X
function Circulation.BlocsCandidatsZ(carte, pivot, position, largeur)
	largeur = largeur or LARGEUR_ACCES
	local l = pivot:PointToObjectSpace(position)
	local a, b = net(l.Z) + DEMI - largeur / 2, net(l.Z) + DEMI + largeur / 2
	local c0, c1 = math.ceil((a - 0.01) / CASE) + 1, math.floor((b + 0.01) / CASE)
	local principal = math.clamp(math.floor((net(l.Z) + DEMI) / CASE + 0.5), 1, carte.nz - 1)
	local liste = {principal}
	for bz = c0, c1 - 1 do
		if bz >= 1 and bz + 1 <= carte.nz and bz ~= principal then table.insert(liste, bz) end
	end
	return liste
end
-- blocs candidats pour un point de station (entree ou sortie du parking) : la station fait 3 cases de large
-- perpendiculairement a son sens ; on accepte les 2 blocs de 2 cases qui tiennent dans ces 3 cases.
local LARGEUR_STATION = 3 * CASE        -- station 3 x 3 cases (45 studs)
function Circulation.BlocsStation(carte, pivot, cf)
	local look = cf.LookVector
	local bx, bz = Circulation.BlocDe(carte, pivot, cf.Position)
	local lookLocal = pivot:PointToObjectSpace(cf.Position + look) - pivot:PointToObjectSpace(cf.Position)
	local liste = {}
	if math.abs(nul(lookLocal.Z)) >= math.abs(nul(lookLocal.X)) then
		-- la voiture avance le long de Z : la largeur de la station est le long de X
		for _, cx in ipairs(Circulation.BlocsCandidats(carte, pivot, cf.Position, LARGEUR_STATION)) do table.insert(liste, {cx, bz}) end
	else
		for _, cz in ipairs(Circulation.BlocsCandidatsZ(carte, pivot, cf.Position, LARGEUR_STATION)) do table.insert(liste, {bx, cz}) end
	end
	return liste
end

-- v51 (regle de Thomas : "bloquee etape par etape") : l'ENTREE dans le plot ne demande que le couloir entree du plot ->
-- entree de la station ; le couloir sortie de la station -> sortie du plot est verifie au moment de repartir (CheminSortie).
-- v54 : toutes les entrees ouvertes sont essayees (la plus proche du tunnel d'abord).
-- Renvoie true, aller (chemin de blocs), noeudEntree ou false, "entree".
function Circulation.StationDesservie(carte, pivot, spawnFolder, cfParc)
	local cfEntree = Circulation.PointsStation(cfParc)
	local blocsStation = Circulation.BlocsStation(carte, pivot, cfEntree)
	for _, e in ipairs(Circulation.Entrees(carte, pivot, spawnFolder)) do
		for _, a in ipairs(blocsStation) do
			local aller = Circulation.Chemin(carte, e[1], e[2], a[1], a[2])
			if aller then return true, aller, e[3] end
		end
	end
	return false, "entree"
end

-- couloir de la sortie de la station (place cfParc : la voiture y est garee) jusqu'a une SORTIE du plot ; renvoie
-- retour (chemin de blocs), dossierSortie (noeuds 1..N) ou nil
function Circulation.CheminSortie(carte, pivot, spawnFolder, cfParc)
	local _, cfSortie = Circulation.PointsStation(cfParc)
	local blocsStation = Circulation.BlocsStation(carte, pivot, cfSortie)
	for _, s in ipairs(Circulation.Sorties(carte, pivot, spawnFolder)) do
		for _, q in ipairs(blocsStation) do
			local retour = Circulation.Chemin(carte, q[1], q[2], s[1], s[2])
			if retour then return retour, s[3] end
		end
	end
	return nil
end

-- Le plot a-t-il au moins un couloir complet entree -> sortie ? (pour prevenir le joueur)
function Circulation.RouteTraversante(carte, pivot, spawnFolder)
	for _, e in ipairs(Circulation.Entrees(carte, pivot, spawnFolder)) do
		for _, s in ipairs(Circulation.Sorties(carte, pivot, spawnFolder)) do
			if Circulation.Chemin(carte, e[1], e[2], s[1], s[2]) then return true end
		end
	end
	return false
end

-- ----------------------------------------------------------------------------------------------------------------------
-- PIETONS : chemin d'un PNJ sur la grille (1 case de large), du depart a la cible, en 4 directions
-- ----------------------------------------------------------------------------------------------------------------------
-- strict = true : il marche sur un sol pose, sans traverser les meubles (sauf ceux du depart et de la cible : il sort de
-- la station et arrive devant la caisse) ni les murs (MurNord = bord +X de la case, MurOuest = bord -Z).
-- strict = false : n'importe quel sol, meubles et murs ignores (secours pour ne jamais bloquer un client).
-- Renvoie true, {{x, z}, ...} (depart inclus) ou nil.
-- demi (v54, facultatif) : dictionnaire de la demi-grille ; une case partiellement occupee est infranchissable, sauf la
-- case de depart et la case cible (le client sort de la station et arrive devant la caisse)
function Circulation.CheminPieton(grid, nx, nz, startX, startZ, cibleX, cibleZ, strict, demi)
	if not grid then return nil end
	local function case(x, z) return grid[x] and grid[x][z] end
	local cDepart, cCible = case(startX, startZ), case(cibleX, cibleZ)
	if not (cDepart and cCible) then return nil end
	local meublesOK = {}       -- meubles qu'on a le droit de traverser : celui du depart et celui de la cible
	if cDepart.FurnitureID ~= 0 and cDepart.FurnitureID ~= nil then meublesOK[cDepart.FurnitureID] = true end
	if cCible.FurnitureID ~= 0 and cCible.FurnitureID ~= nil then meublesOK[cCible.FurnitureID] = true end
	local function marchable(x, z)
		if x < 1 or z < 1 or x > nx or z > nz then return false end
		local c = case(x, z)
		if not c or c.Sol == 0 or c.Sol == nil then return false end
		if not strict then return true end
		if c.Furniture ~= 0 and c.Furniture ~= nil and not meublesOK[c.FurnitureID] then return false end
		if demi and not ((x == startX and z == startZ) or (x == cibleX and z == cibleZ)) and demiOccupee(demi, x, z) then return false end
		return true
	end
	local function mur(x, z, dx, dz)
		if not strict then return false end
		if dx == 1 then return murX(grid, x, z) end
		if dx == -1 then return murX(grid, x - 1, z) end
		if dz == -1 then return murZ(grid, x, z) end
		if dz == 1 then return murZ(grid, x, z + 1) end
		return false
	end
	local DIRS4 = { {1, 0}, {-1, 0}, {0, 1}, {0, -1} }
	local file, tete = { {startX, startZ} }, 1
	local parent = { [startX * 1000 + startZ] = false }
	while tete <= #file do
		local a = file[tete]; tete += 1
		if a[1] == cibleX and a[2] == cibleZ then
			local chemin, cur = {}, a
			while cur do table.insert(chemin, 1, {x = cur[1], z = cur[2]}); cur = parent[cur[1] * 1000 + cur[2]] end
			return true, chemin
		end
		for _, d in ipairs(DIRS4) do
			local vx, vz = a[1] + d[1], a[2] + d[2]
			local k = vx * 1000 + vz
			if parent[k] == nil and marchable(vx, vz) and not mur(a[1], a[2], d[1], d[2]) then
				parent[k] = a
				table.insert(file, {vx, vz})
			end
		end
	end
	return nil
end

return Circulation
