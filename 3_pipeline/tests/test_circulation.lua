-- Tests hors ligne de Circulation (couloirs voitures 2 cases, chemins pietons 1 case). Lancer : ./luau tests/test_circulation.lua
local S = require("./stubs_roblox")
-- PlayerData factice : la grille et la taille sont injectees par les tests
local grille, NX, NZ
S.modules.PlayerData = {
	GetGrid = function() return grille end,
	GetPlotSize = function() return NX, NZ end,
	MAX_X = 20, MAX_Z = 35,
}
game:GetService("ServerScriptService"):Ajouter(S.Inst.new("PlayerData"))
local Circulation = require("./Circulation")

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
