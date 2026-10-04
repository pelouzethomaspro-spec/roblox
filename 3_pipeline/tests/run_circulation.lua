-- Stubs minimaux de l'API Roblox pour tester les modules hors ligne avec l'interpreteur luau.
-- Vector3 / CFrame (rotation autour de Y uniquement) / game:GetService / require d'Instances.
local V3 = {}
V3.__index = V3
local function v3(x, y, z) return setmetatable({X = x, Y = y, Z = z}, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z) end
function V3:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return v3(0, 0, 0) end return v3(t.X / m, t.Y / m, t.Z / m) end
	return V3[k]
end
Vector3 = {new = v3, zero = v3(0, 0, 0), yAxis = v3(0, 1, 0), xAxis = v3(1, 0, 0), zAxis = v3(0, 0, 1)}

-- CFrame : position + angle autour de Y (LookVector = -Z tourne)
local CF = {}
local function cf(p, yaw) return setmetatable({Position = p, yaw = yaw or 0}, CF) end
local function rot(p, yaw) local c, s = math.cos(yaw), math.sin(yaw); return v3(c * p.X + s * p.Z, p.Y, -s * p.X + c * p.Z) end
CF.__index = function(t, k)
	if k == "LookVector" then return rot(v3(0, 0, -1), t.yaw) end
	if k == "RightVector" then return rot(v3(1, 0, 0), t.yaw) end
	if k == "X" then return t.Position.X elseif k == "Y" then return t.Position.Y elseif k == "Z" then return t.Position.Z end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(a.Position + rot(b.Position, a.yaw), a.yaw + b.yaw) end
	return a.Position + rot(b, a.yaw)
end
CF.__sub = function(a, p) return cf(a.Position - p, a.yaw) end
CF.__add = function(a, p) return cf(a.Position + p, a.yaw) end
function CF:PointToObjectSpace(p) return rot(p - self.Position, -self.yaw) end
function CF:PointToWorldSpace(p) return self.Position + rot(p, self.yaw) end
function CF:GetPivot() return self end
CFrame = {}
function CFrame.new(x, y, z)
	if getmetatable(x) == V3 then return cf(x, 0) end
	return cf(v3(x or 0, y or 0, z or 0), 0)
end
function CFrame.Angles(_, ry, _) return cf(v3(0, 0, 0), ry) end
function CFrame.lookAt(p, cible)
	local d = cible - p
	-- LookVector = (-sin? ) : rot(v3(0,0,-1), yaw) = (-sin(yaw)... on resout yaw tel que rot(-Z) = d
	-- rot(0,0,-1,yaw) = (-s, 0, -c) => d.X = -s, d.Z = -c => yaw = atan2(-d.X, -d.Z)
	return cf(p, math.atan2(-d.X, -d.Z))
end

-- Instances factices : une table avec Name, enfants, et methodes
local Inst = {}
Inst.__index = function(t, k)
	if Inst[k] then return Inst[k] end
	local enfants = rawget(t, "_enfants")
	if enfants and enfants[k] then return enfants[k] end
	return nil
end
function Inst.new(nom, props)
	local o = setmetatable({Name = nom, _enfants = {}}, Inst)
	for k, v in pairs(props or {}) do o[k] = v end
	return o
end
function Inst:Ajouter(enfant) self._enfants[enfant.Name] = enfant; enfant.Parent = self; return enfant end
function Inst:FindFirstChild(n) return self._enfants[n] end
function Inst:WaitForChild(n) return self._enfants[n] end
function Inst:GetPivot() return self.CFrame end
function Inst:IsA(c) return self.ClassName == c end
Instance = Inst

-- game / services / require d'Instances
local modules = {}          -- nom d'Instance -> module (table) renvoye par require
local services = {}
game = {}
function game:GetService(n)
	if not services[n] then services[n] = Inst.new(n) end
	return services[n]
end
local requireOrig = require
require = function(x)
	if type(x) == "table" and x.Name and modules[x.Name] then return modules[x.Name] end
	return requireOrig(x)
end
local S = {Inst = Inst, modules = modules, services = services, v3 = v3, cf = cf}

-- Tests hors ligne de Circulation (couloirs voitures 2 cases, chemins pietons 1 case). Lancer : ./luau tests/test_circulation.lua
-- PlayerData factice : la grille et la taille sont injectees par les tests
local grille, NX, NZ
S.modules.PlayerData = {
	GetGrid = function() return grille end,
	GetPlotSize = function() return NX, NZ end,
	MAX_X = 20, MAX_Z = 35,
}
game:GetService("ServerScriptService"):Ajouter(S.Inst.new("PlayerData"))
local Circulation = (function()
--[[ Circulation (ModuleScript, ServerScriptService) — les voitures ROULENT SUR LE PLOT sans traverser les objets.
	Regles (Thomas) :
	  * une voiture a besoin d'un couloir de DEUX CASES DE LARGE (20 studs) fait de goudron (sol_goudron / sol_route /
	    sol_beton), sans meuble, sans mur, de l'entree du plot jusqu'a l'entree de la station, puis de la sortie de la
	    station jusqu'a la sortie du plot ;
	  * s'il n'y a pas un tel couloir, la voiture ne peut pas entrer : elle passe son chemin (et le joueur est prevenu) ;
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

local RECUL_ENTREE = 25               -- studs : point d'entree d'une station = place de parking reculee de 25 studs (hors du 3 x 3)
local AVANCE_SORTIE = 25              -- studs : point de sortie = 25 studs apres la place

-- ----------------------------------------------------------------------------------------------------------------------
-- carte du plot
-- ----------------------------------------------------------------------------------------------------------------------
local function roulable(grid, nx, nz, x, z)
	if x < 1 or z < 1 or x > nx or z > nz then return false end
	local c = grid[x] and grid[x][z]
	if not c then return false end
	if c.Furniture ~= 0 and c.Furniture ~= nil then return false end
	return Circulation.SolRoulant(c.Sol)
end

-- mur entre (x, z) et (x + 1, z) : MurNord de (x, z) ; entre (x, z) et (x, z - 1) : MurOuest de (x, z)
local function murX(grid, x, z) local c = grid[x] and grid[x][z]; return c ~= nil and c.MurNord ~= 0 and c.MurNord ~= nil end
local function murZ(grid, x, z) local c = grid[x] and grid[x][z]; return c ~= nil and c.MurOuest ~= 0 and c.MurOuest ~= nil end

function Circulation.Carte(player)
	local grid = PlayerData.GetGrid(player)
	local nx, nz = PlayerData.GetPlotSize(player)
	if not (grid and nx and nz) then return nil end
	local C = { grid = grid, nx = nx, nz = nz }
	-- bloc (bx, bz) libre : 4 cases roulables, pas de mur interieur
	function C.blocLibre(bx, bz)
		if bx < 1 or bz < 1 or bx + 1 > nx or bz + 1 > nz then return false end
		if not (roulable(grid, nx, nz, bx, bz) and roulable(grid, nx, nz, bx + 1, bz)
			and roulable(grid, nx, nz, bx, bz + 1) and roulable(grid, nx, nz, bx + 1, bz + 1)) then return false end
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
	return math.floor(net(l.X) / 10) + 1, math.floor((net(l.Z) + 5) / 10) + 1
end

-- bloc dont le centre (coin de case) est le plus proche d'un point du monde
function Circulation.BlocDe(carte, pivot, position)
	local l = pivot:PointToObjectSpace(position)
	local bx = math.clamp(math.floor(net(l.X) / 10 + 0.5), 1, carte.nx - 1)
	local bz = math.clamp(math.floor((net(l.Z) + 5) / 10 + 0.5), 1, carte.nz - 1)
	return bx, bz
end

function Circulation.MondeBloc(pivot, bx, bz, y)
	local p = pivot:PointToWorldSpace(Vector3.new(10 * bx, 0, 10 * bz - 5))
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
	return e and e.Position.Y or pivot.Position.Y
end

-- blocs d'entree et de sortie du plot (d'apres les noeuds Entree et ExitNodes/1 du PlotSpawn).
-- L'acces fait 30 studs (3 cases) de large : DEUX blocs de 2 cases y tiennent (le bloc centre sur le noeud, et son voisin
-- cote branche). On renvoie le bloc principal + la liste des blocs acceptables, pour ne pas refuser une route posee sur les
-- deux cases de gauche plutot que les deux de droite de l'acces.
local LARGEUR_ACCES = 30
function Circulation.BlocsAcces(carte, pivot, spawnFolder)
	local e = spawnFolder:FindFirstChild("Entree")
	local s = spawnFolder:FindFirstChild("ExitNodes") and spawnFolder.ExitNodes:FindFirstChild("1")
	if not (e and s) then return nil end
	local ebx, ebz = Circulation.BlocDe(carte, pivot, e.Position)
	local sbx, sbz = Circulation.BlocDe(carte, pivot, s.Position)
	return ebx, ebz, sbx, sbz
end
-- blocs (bx) dont les DEUX cases sont entierement dans la bande de `largeur` studs (defaut : l'acces, 30) centree sur
-- un point (repere du plot). Le bloc principal (le plus proche du point) vient en premier. Sert aux acces du plot ET
-- aux entrees/sorties des stations (3 cases de large : la route de 2 cases peut etre a gauche ou a droite).
function Circulation.BlocsCandidats(carte, pivot, position, largeur)
	largeur = largeur or LARGEUR_ACCES
	local l = pivot:PointToObjectSpace(position)
	local a, b = net(l.X) - largeur / 2, net(l.X) + largeur / 2
	local c0, c1 = math.ceil((a - 0.01) / 10) + 1, math.floor((b + 0.01) / 10)   -- premiere / derniere case entierement dedans
	local principal = math.clamp(math.floor(net(l.X) / 10 + 0.5), 1, carte.nx - 1)
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
	local a, b = net(l.Z) + 5 - largeur / 2, net(l.Z) + 5 + largeur / 2
	local c0, c1 = math.ceil((a - 0.01) / 10) + 1, math.floor((b + 0.01) / 10)
	local principal = math.clamp(math.floor((net(l.Z) + 5) / 10 + 0.5), 1, carte.nz - 1)
	local liste = {principal}
	for bz = c0, c1 - 1 do
		if bz >= 1 and bz + 1 <= carte.nz and bz ~= principal then table.insert(liste, bz) end
	end
	return liste
end
-- blocs candidats pour un point de station (entree ou sortie du parking) : la station fait 3 cases de large
-- perpendiculairement a son sens ; on accepte les 2 blocs de 2 cases qui tiennent dans ces 3 cases.
local LARGEUR_STATION = 30
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

-- Une station est-elle desservie ? (couloir entree du plot -> entree de la station, et sortie de la station -> sortie du
-- plot). Renvoie true/false et, si oui, les deux chemins de blocs. Les blocs d'entree / de sortie sont choisis parmi les
-- blocs candidats de l'acces (voir BlocsCandidats) : le premier qui donne un couloir gagne.
function Circulation.StationDesservie(carte, pivot, spawnFolder, cfParc)
	local e = spawnFolder:FindFirstChild("Entree")
	local s = spawnFolder:FindFirstChild("ExitNodes") and spawnFolder.ExitNodes:FindFirstChild("1")
	if not (e and s) then return false end
	local _, ebz = Circulation.BlocDe(carte, pivot, e.Position)
	local _, sbz = Circulation.BlocDe(carte, pivot, s.Position)
	local cfEntree, cfSortie = Circulation.PointsStation(cfParc)
	local aller, retour
	for _, ebx in ipairs(Circulation.BlocsCandidats(carte, pivot, e.Position)) do
		-- les deux cases du bord (rangee 1, sous l'acces) doivent aussi etre libres : la voiture les traverse
		if carte.blocLibre(ebx, math.max(1, ebz - 1)) then
			for _, a in ipairs(Circulation.BlocsStation(carte, pivot, cfEntree)) do
				aller = Circulation.Chemin(carte, ebx, ebz, a[1], a[2])
				if aller then break end
			end
			if aller then break end
		end
	end
	if not aller then return false, "entree" end
	for _, sbx in ipairs(Circulation.BlocsCandidats(carte, pivot, s.Position)) do
		if carte.blocLibre(sbx, math.max(1, sbz - 1)) then
			for _, q in ipairs(Circulation.BlocsStation(carte, pivot, cfSortie)) do
				retour = Circulation.Chemin(carte, q[1], q[2], sbx, sbz)
				if retour then break end
			end
			if retour then break end
		end
	end
	if not retour then return false, "sortie" end
	return true, aller, retour
end

-- Le plot a-t-il au moins un couloir complet entree -> sortie ? (pour prevenir le joueur)
function Circulation.RouteTraversante(carte, pivot, spawnFolder)
	local e = spawnFolder:FindFirstChild("Entree")
	local s = spawnFolder:FindFirstChild("ExitNodes") and spawnFolder.ExitNodes:FindFirstChild("1")
	if not (e and s) then return false end
	local _, ebz = Circulation.BlocDe(carte, pivot, e.Position)
	local _, sbz = Circulation.BlocDe(carte, pivot, s.Position)
	for _, ebx in ipairs(Circulation.BlocsCandidats(carte, pivot, e.Position)) do
		for _, sbx in ipairs(Circulation.BlocsCandidats(carte, pivot, s.Position)) do
			if Circulation.Chemin(carte, ebx, ebz, sbx, sbz) then return true end
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
function Circulation.CheminPieton(grid, nx, nz, startX, startZ, cibleX, cibleZ, strict)
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

end)()

-- ---------------------------------------------------------------- outils
local function nouvelleGrille(nx, nz)
	NX, NZ = nx, nz
	grille = {}
	for x = 1, nx do
		grille[x] = {}
		for z = 1, nz + 1 do grille[x][z] = {Sol = 0, Furniture = 0, FurnitureID = 0, Plafond = 0, MurNord = 0, MurOuest = 0} end
	end
	return grille
end
local function route(x0, z0, x1, z1) for x = x0, x1 do for z = z0, z1 do grille[x][z].Sol = "sol_goudron#0" end end end
local function dalle(x0, z0, x1, z1) for x = x0, x1 do for z = z0, z1 do grille[x][z].Sol = "sol_beton#0" end end end
local function meuble(x0, z0, x1, z1, id) for x = x0, x1 do for z = z0, z1 do grille[x][z].Furniture = "truc"; grille[x][z].FurnitureID = id or "M1" end end end
local function murNord(x, z) grille[x][z].MurNord = "mur#0" end     -- bord +X de la case (x,z)
local function murOuest(x, z) grille[x][z].MurOuest = "mur#1" end   -- bord -Z de la case (x,z)

local nb, nok = 0, 0
local function test(nom, cond, detail)
	nb += 1
	if cond then nok += 1 else print("ECHEC  " .. nom .. (detail and ("  -- " .. tostring(detail)) or "")) end
end
local function cheminStr(ch) if not ch then return "nil" end local t = {} for _, b in ipairs(ch) do table.insert(t, b[1] .. "," .. b[2]) end return table.concat(t, " ") end

-- pivot identite : coordonnees du plot = coordonnees monde ; case (x,z) centree en (10x-5, 0, 10z-10)
local pivot = CFrame.new(0, 0, 0)
local function spawnFolder(xEntree, xSortie)
	local sf = S.Inst.new("Plot1")
	sf:Ajouter(S.Inst.new("Entree", {Position = Vector3.new(xEntree, 0.3, 20)}))       -- 20 studs dans le plot (rangee 3)
	local ex = sf:Ajouter(S.Inst.new("ExitNodes"))
	ex:Ajouter(S.Inst.new("1", {Position = Vector3.new(xSortie, 0.3, 20)}))
	return sf
end
-- place de parking d'une station : centre (x, z) monde, regarde vers +Z (LookVector (0,0,1)) => entree 25 studs avant (z-25), sortie 25 apres
local function parking(x, z, look) look = look or Vector3.new(0, 0, 1); return CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z) + look) end

-- ---------------------------------------------------------------- 1. blocs et murs
do
	nouvelleGrille(20, 11)
	route(3, 1, 6, 8)                      -- couloir 4 cases de large, 8 de long
	local C = Circulation.Carte()
	test("bloc libre au milieu du couloir", C.blocLibre(4, 3))
	test("bloc hors couloir non libre", not C.blocLibre(8, 3))
	test("bloc sur le bord de la grille (bx = nx) non libre", not C.blocLibre(20, 3))
	test("bloc bz = nz non libre", not C.blocLibre(4, 11))
	murNord(4, 3)                          -- mur entre les colonnes 4 et 5 sur la rangee 3
	test("mur vertical au milieu du bloc (4,3) -> bloque", not C.blocLibre(4, 3))
	test("mur vertical : bloc (4,1) (rangees 1-2) pas concerne", C.blocLibre(4, 1))
	test("bloc (3,3) : mur sur son bord +X exterieur -> libre", C.blocLibre(3, 3))
	test("passage (3,3) -> +X bloque par le mur", not C.passage(3, 3, 1, 0))
	test("passage (5,3) -> -X bloque par le mur", not C.passage(5, 3, -1, 0))
	test("passage (3,2) -> +X : le mur ne coupe que la rangee 3 (bloc rangees 2-3) -> bloque", not C.passage(3, 2, 1, 0))
	test("passage (3,4) -> +X libre (rangees 4-5)", C.passage(3, 4, 1, 0))
	grille[4][3].MurNord = 0
	murOuest(4, 5)                         -- mur entre les rangees 4 et 5 sur la colonne 4
	test("mur horizontal au milieu du bloc (4,4) -> bloque", not C.blocLibre(4, 4))
	test("mur horizontal : bloc (3,4) aussi (cases 3-4 x 4-5) -> bloque", not C.blocLibre(3, 4))
	test("bloc (5,4) pas concerne", C.blocLibre(5, 4))
	test("passage (4,3) -> +Z bloque (franchit rangees 4|5 en colonne 4)", not C.passage(4, 3, 0, 1))
	test("passage (4,6) -> -Z : franchit 5|6, libre", C.passage(4, 6, 0, -1))
	test("passage (4,5) -> -Z : franchit 4|5 -> bloque", not C.passage(4, 5, 0, -1))
end

-- ---------------------------------------------------------------- 2. chemins de blocs
do
	nouvelleGrille(20, 11)
	route(4, 1, 5, 9)                      -- couloir droit de 2 cases (colonnes 4-5)
	local C = Circulation.Carte()
	local ch = Circulation.Chemin(C, 4, 2, 4, 8)
	test("couloir droit 2 cases : chemin trouve", ch ~= nil, cheminStr(ch))
	test("couloir droit : 7 blocs", ch and #ch == 7, ch and #ch)
	route(4, 1, 4, 9); for z = 1, 9 do grille[5][z].Sol = 0 end
	C = Circulation.Carte()
	test("couloir de 1 case : pas de chemin", Circulation.Chemin(C, 4, 2, 4, 8) == nil)
	-- couloir en L
	nouvelleGrille(20, 11)
	route(4, 1, 5, 6); route(4, 5, 12, 6)
	C = Circulation.Carte()
	ch = Circulation.Chemin(C, 4, 2, 11, 5)
	test("couloir en L : chemin trouve", ch ~= nil, cheminStr(ch))
	-- meuble dans le couloir
	meuble(5, 4, 5, 4)
	C = Circulation.Carte()
	test("meuble sur une case du couloir : bloque", Circulation.Chemin(C, 4, 2, 11, 5) == nil)
	grille[5][4].Furniture = 0; grille[5][4].FurnitureID = 0
	-- coin interieur manquant dans le L (case (4,5) enlevee) : le bloc 2x2 ne passe plus
	grille[4][5].Sol = 0
	C = Circulation.Carte()
	test("L avec coin interieur manquant : bloque", Circulation.Chemin(C, 4, 2, 11, 5) == nil)
	grille[4][5].Sol = "sol_goudron#0"
	-- mur en travers du couloir (rangee 3|4, colonnes 4 et 5)
	murOuest(4, 4); murOuest(5, 4)
	C = Circulation.Carte()
	test("mur en travers du couloir : bloque", Circulation.Chemin(C, 4, 2, 11, 5) == nil)
	grille[4][4].MurOuest = 0; grille[5][4].MurOuest = 0
	-- mur le long du couloir (bord +X de la colonne 5) : ne gene pas
	for z = 1, 4 do murNord(5, z) end
	C = Circulation.Carte()
	test("mur le long du couloir : passe", Circulation.Chemin(C, 4, 2, 11, 5) ~= nil)
	-- depart = arrivee
	ch = Circulation.Chemin(C, 4, 2, 4, 2)
	test("depart = arrivee : chemin d'un bloc", ch and #ch == 1)
	-- beton et route roulables, herbe/parquet non
	nouvelleGrille(20, 11); dalle(4, 1, 5, 9); C = Circulation.Carte()
	test("beton roulable", Circulation.Chemin(C, 4, 2, 4, 8) ~= nil)
	for x = 4, 5 do grille[x][5].Sol = "sol_parquet#0" end; C = Circulation.Carte()
	test("parquet non roulable : bloque", Circulation.Chemin(C, 4, 2, 4, 8) == nil)
	-- chemin ne sort jamais de la grille (couloir colle au bord x = 1)
	nouvelleGrille(20, 11); route(1, 1, 2, 9); C = Circulation.Carte()
	ch = Circulation.Chemin(C, 1, 2, 1, 8)
	test("couloir colle au bord x=1 : ok", ch ~= nil)
	local ok = true; for _, b in ipairs(ch or {}) do if b[1] < 1 or b[1] + 1 > 20 or b[2] < 1 or b[2] + 1 > 11 then ok = false end end
	test("aucun bloc hors grille", ok)
end

-- ---------------------------------------------------------------- 3. station desservie (entree, sortie, blocs candidats)
do
	-- entree centree sur x = 40 (cases 3-4-5 = studs 20..50) ; sortie sur x = 180 (cases 17-19)
	local sf = spawnFolder(35, 175)            -- acces reels : centres des cases 3..5 et 17..19
	-- station 3x3 en (8..10, 6..8), place de parking au centre (x=85, z=60) regardant +Z : entree du parking z=35 (bloc rangees 3-4),
	-- sortie z=85 (bloc rangees 8-9)
	nouvelleGrille(20, 11)
	route(4, 1, 5, 9); route(4, 8, 9, 9)            -- (pas de station : juste pour la geometrie) => pas utilise
	nouvelleGrille(20, 11)
	route(4, 2, 5, 11)                              -- couloir depuis l'entree (cases 4-5) jusqu'a la station
	route(4, 10, 18, 11)                            -- puis vers la sortie (cases 17-18) en bas
	route(17, 2, 18, 11)
	local cfParc = parking(45, 60)               -- station a la fin du couloir, entree du parking en z = 35 (bloc (4,3)), sortie z = 85 (bloc (4,8))
	local C = Circulation.Carte()
	local ok, aller, retour = Circulation.StationDesservie(C, pivot, sf, cfParc)
	test("station desservie par un couloir en U", ok == true, aller)
	-- la route pose sur les cases 3-4 (au lieu de 4-5) de l'acces doit aussi marcher
	nouvelleGrille(20, 11)
	route(3, 2, 4, 11); route(3, 10, 18, 11); route(17, 2, 18, 11)
	C = Circulation.Carte()
	local cfParc2 = parking(35, 60)
	ok = Circulation.StationDesservie(C, pivot, sf, cfParc2)
	test("acces : route sur les cases 3-4 acceptee", ok == true)
	-- route sur les cases 2-3 (hors de l'acces de 30 studs = cases 3..5) : refusee
	nouvelleGrille(20, 11)
	route(2, 2, 3, 11); route(2, 10, 18, 11); route(17, 2, 18, 11)
	C = Circulation.Carte()
	ok = Circulation.StationDesservie(C, pivot, sf, parking(25, 60))
	test("acces : route sur les cases 2-3 refusee", ok ~= true)
	-- la rangee 2 (sous l'acces) doit etre roulable
	nouvelleGrille(20, 11)
	route(4, 3, 5, 11); route(4, 10, 18, 11); route(17, 2, 18, 11)
	C = Circulation.Carte()
	ok = Circulation.StationDesservie(C, pivot, sf, cfParc)
	test("rangee 2 manquante sous l'entree : refusee", ok ~= true)
	-- sortie manquante
	nouvelleGrille(20, 11)
	route(4, 2, 5, 11); route(4, 10, 18, 11)
	C = Circulation.Carte()
	local ok2, raison = Circulation.StationDesservie(C, pivot, sf, cfParc)
	test("pas de couloir de sortie : refusee", ok2 ~= true and raison == "sortie", raison)
	-- RouteTraversante
	nouvelleGrille(20, 11); route(4, 2, 5, 11); route(4, 10, 18, 11); route(17, 2, 18, 11); C = Circulation.Carte()
	test("route traversante entree -> sortie", Circulation.RouteTraversante(C, pivot, sf))
	nouvelleGrille(20, 11); route(4, 2, 5, 11); C = Circulation.Carte()
	test("pas de route traversante", not Circulation.RouteTraversante(C, pivot, sf))
	-- blocs candidats de l'acces
	local cands = Circulation.BlocsCandidats(C, pivot, Vector3.new(35, 0, 20))
	table.sort(cands)
	test("blocs candidats de l'acces x=35 : {3, 4}", #cands == 2 and cands[1] == 3 and cands[2] == 4, table.concat(cands, ","))
end

-- ---------------------------------------------------------------- 4. trajet (points de virage et vitesses)
do
	nouvelleGrille(20, 11); route(4, 1, 5, 6); route(4, 5, 12, 6); local C = Circulation.Carte()
	local ch = Circulation.Chemin(C, 4, 2, 11, 5)
	local etapes = Circulation.Trajet(C, pivot, ch, 0.3, nil)
	test("trajet en L : 2 etapes (le virage, l'arrivee)", #etapes == 2, #etapes)
	test("premiere etape = virage (vitesse virage)", etapes[1] and etapes[1].vitesse == Circulation.VITESSE_VIRAGE, etapes[1] and etapes[1].vitesse)
	test("derniere etape a la vitesse plot", etapes[2] and etapes[2].vitesse == Circulation.VITESSE_PLOT)
end

-- ---------------------------------------------------------------- 5. pietons (1 case, 4 directions, murs, meubles)
do
	nouvelleGrille(20, 11)
	dalle(2, 2, 8, 2)                                  -- chemin de 1 case de large
	local ok, ch = Circulation.CheminPieton(grille, 20, 11, 2, 2, 8, 2, true)
	test("pieton : couloir de 1 case", ok == true and #ch == 7, ch and #ch)
	grille[5][2].Sol = 0
	test("pieton : trou dans le sol -> bloque", Circulation.CheminPieton(grille, 20, 11, 2, 2, 8, 2, true) == nil)
	test("pieton : trou -> bloque meme en mode secours (il faut un sol)", Circulation.CheminPieton(grille, 20, 11, 2, 2, 8, 2, false) == nil)
	grille[5][2].Sol = "sol_beton#0"
	meuble(5, 2, 5, 2, "M9")
	test("pieton : meuble sur le chemin -> bloque (strict)", Circulation.CheminPieton(grille, 20, 11, 2, 2, 8, 2, true) == nil)
	test("pieton : meuble ignore en mode secours", Circulation.CheminPieton(grille, 20, 11, 2, 2, 8, 2, false) ~= nil)
	grille[5][2].Furniture = 0; grille[5][2].FurnitureID = 0
	-- meubles de depart et d'arrivee traversables (station 3x3 et caisse)
	meuble(2, 1, 4, 3, "STATION"); meuble(8, 2, 8, 2, "CAISSE")
	dalle(1, 1, 9, 3)
	ok, ch = Circulation.CheminPieton(grille, 20, 11, 3, 2, 8, 2, true)
	test("pieton : sort de sa station et arrive a la caisse", ok == true, ch and #ch)
	-- mur en travers
	murNord(6, 2)
	test("pieton : mur +X sur la case 6 (rangee 2) -> bloque en ligne droite mais contourne par les rangees 1/3", Circulation.CheminPieton(grille, 20, 11, 3, 2, 8, 2, true) ~= nil)
	murNord(6, 1); murNord(6, 3)
	test("pieton : mur complet -> bloque", Circulation.CheminPieton(grille, 20, 11, 3, 2, 8, 2, true) == nil)
	grille[6][1].MurNord = 0; grille[6][2].MurNord = 0; grille[6][3].MurNord = 0
	-- mur -Z (MurOuest) : entre (x, z) et (x, z-1)
	nouvelleGrille(20, 11); dalle(3, 1, 3, 6); murOuest(3, 4)
	test("pieton : MurOuest (3,4) bloque le passage 3|4 vers +Z", Circulation.CheminPieton(grille, 20, 11, 3, 1, 3, 6, true) == nil)
	test("pieton : ... et vers -Z", Circulation.CheminPieton(grille, 20, 11, 3, 6, 3, 1, true) == nil)
	grille[3][4].MurOuest = 0
	test("pieton : sans mur, passe", Circulation.CheminPieton(grille, 20, 11, 3, 1, 3, 6, true) ~= nil)
	-- hors grille / cases inexistantes
	test("pieton : depart hors grille -> nil", Circulation.CheminPieton(grille, 20, 11, 0, 1, 3, 6, true) == nil)
	test("pieton : cible hors grille -> nil", Circulation.CheminPieton(grille, 20, 11, 3, 1, 25, 6, true) == nil)
	test("pieton : depart = cible", (Circulation.CheminPieton(grille, 20, 11, 3, 1, 3, 1, true)) == true)
	-- ne sort jamais de la grille sur le bord
	nouvelleGrille(20, 11); dalle(1, 1, 1, 11)
	ok, ch = Circulation.CheminPieton(grille, 20, 11, 1, 1, 1, 11, true)
	local dedans = true; for _, c in ipairs(ch or {}) do if c.x < 1 or c.z < 1 or c.x > 20 or c.z > 11 then dedans = false end end
	test("pieton : longe le bord x=1 sans sortir", ok == true and dedans)
end

-- ---------------------------------------------------------------- 6. robustesse / performance
do
	nouvelleGrille(20, 35); route(1, 1, 20, 35)
	local C = Circulation.Carte()
	local t0 = os.clock()
	for _ = 1, 200 do Circulation.Chemin(C, 1, 1, 19, 34) end
	local dt = os.clock() - t0
	test("200 BFS sur une grille 20x35 pleine en < 2 s", dt < 2, dt)
	t0 = os.clock()
	for _ = 1, 200 do Circulation.CheminPieton(grille, 20, 35, 1, 1, 20, 35, true) end
	dt = os.clock() - t0
	test("200 chemins pietons 20x35 en < 2 s", dt < 2, dt)
	-- grille avec des cases nil (extension partielle) : pas d'erreur
	grille[7] = nil
	C = Circulation.Carte()
	local okp = pcall(function() Circulation.Chemin(C, 1, 1, 19, 34); Circulation.CheminPieton(grille, 20, 35, 1, 1, 20, 35, true) end)
	test("colonne manquante dans la grille : pas d'erreur", okp)
end

-- ---------------------------------------------------------------- 7. stations 3 cases de large : route a gauche ou a droite, orientation X
do
	local sf = spawnFolder(35, 175)
	-- station 3x3 centree case (5, 7) (cases 4..6 x 6..8), parking au centre (45, 60) vers +Z : entree z=35, sortie z=85
	-- route de 2 cases sur les colonnes 4-5 (gauche de la station) puis vers la sortie
	nouvelleGrille(20, 11)
	route(4, 2, 5, 11); route(4, 10, 18, 11); route(17, 2, 18, 11)
	local C = Circulation.Carte()
	test("station 3 large : route sur ses 2 cases de gauche", Circulation.StationDesservie(C, pivot, sf, parking(45, 60)) == true)
	-- route sur les colonnes 5-6 (droite de la station)
	nouvelleGrille(20, 11)
	route(3, 2, 4, 5); route(3, 4, 6, 5); route(5, 4, 6, 11); route(5, 10, 18, 11); route(17, 2, 18, 11)
	C = Circulation.Carte()
	test("station 3 large : route sur ses 2 cases de droite", Circulation.StationDesservie(C, pivot, sf, parking(45, 60)) == true)
	-- route sur les colonnes 6-7 (deborde de la station) : refusee
	nouvelleGrille(20, 11)
	route(3, 2, 4, 5); route(3, 4, 7, 5); route(6, 4, 7, 11); route(6, 10, 18, 11); route(17, 2, 18, 11)
	C = Circulation.Carte()
	test("station 3 large : route decalee hors de la station : refusee", Circulation.StationDesservie(C, pivot, sf, parking(45, 60)) ~= true)
	-- station orientee le long de X (regarde +X) : centre (85, 50) = case (9, 6) ; entree x=60, sortie x=110 ; route horizontale rangees 5-6 ou 6-7
	nouvelleGrille(20, 11)
	route(4, 2, 5, 7); route(4, 6, 18, 7); route(17, 2, 18, 11)
	C = Circulation.Carte()
	test("station le long de X : route sur ses rangees du bas (6-7)", Circulation.StationDesservie(C, pivot, sf, parking(85, 50, Vector3.new(1, 0, 0))) == true)
	nouvelleGrille(20, 11)
	route(4, 2, 5, 6); route(4, 5, 18, 6); route(17, 2, 18, 11)
	C = Circulation.Carte()
	test("station le long de X : route sur ses rangees du haut (5-6)", Circulation.StationDesservie(C, pivot, sf, parking(85, 50, Vector3.new(1, 0, 0))) == true)
	-- decodage des noms de sol
	test("NomSol decode nom#orientation", Circulation.NomSol("sol_goudron#3") == "sol_goudron")
	test("NomSol ancien format", Circulation.NomSol("sol_route") == "sol_route")
	test("NomSol non-chaine", Circulation.NomSol(0) == nil)
	test("SolRoulant goudron#1", Circulation.SolRoulant("sol_goudron#1") == true)
	test("SolRoulant parquet", Circulation.SolRoulant("sol_parquet#0") == false)
end

print(string.format("%d / %d tests OK", nok, nb))
if nok ~= nb then error("des tests echouent") end
