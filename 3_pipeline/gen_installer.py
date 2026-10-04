"""Genere gen/Installer_Constructions.lua (barre de commande Studio) depuis gen/constructions.json."""
import json, os
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'gen')
inv = json.load(open(os.path.join(OUT, 'constructions.json')))

def lua_str(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

lignes = []
for e in inv:
    pieces = ', '.join(lua_str(p['nom']) for p in e['pieces'])
    t = e['taille']
    nx = len(e['masque'][0]) if e.get('masque') else 1
    nz = len(e['masque']) if e.get('masque') else 1
    lignes.append(f'\t[{lua_str(e["nom"])}] = {{cat = {lua_str(e["categorie"])}, taille = Vector3.new({t[0]:.3f}, {t[1]:.3f}, {t[2]:.3f}), principale = {lua_str(e["principale"])}, pieces = {{{pieces}}}, nx = {nx}, nz = {nz}}},')
table = '\n'.join(lignes)

script = r'''--[[ Installer_Constructions — installe les vrais meshes du pack de constructions (PACK_10_3) dans la place.

	COMMENT LANCER (dans Roblox Studio, place ouverte) : Affichage > Barre de commande, puis tape :
		require(game.ServerStorage.Installer_Constructions)()
	et Entree. (Ou colle tout ce fichier dans la barre de commande : il s'execute aussi tel quel.)

	CE QUE FAIT LE SCRIPT : il charge le modele publie "PACK_10_3 (1)" (ID_PACK ci-dessous, ton asset Model) avec
	InsertService — ou reutilise un modele "PACK_10..." deja present dans Workspace / selectionne — puis, pour chaque
	construction du pack (sols, murs, toits, decor), il prend les MeshParts, les regroupe dans un Model au nom du
	catalogue, verifie l'echelle (10 studs), ancre tout, place le pivot exactement comme le jeu l'attend (dessus du sol
	a +0.5, bas des murs au sol, face avant des portes vers l'exterieur, toits au sommet des murs) et remplace la
	boite provisoire de ReplicatedStorage/<categorie>. Il ne touche pas aux stations. Relancable : ne remplace que les
	boites provisoires (FORCER = true pour tout refaire) et verifie / corrige les pivots des constructions deja installees.
	Enregistre la place ensuite (Ctrl+S / publier).
]]
local ID_PACK = 90907777498961      -- asset Model "PACK_10_3 (1)" publie par thamary4
local FORCER = false

local SOL_DESSUS, MEUBLE_Y = 0.5, 0.616

local CONSTRUCTIONS = {
__TABLE__
}

local RS = game:GetService("ReplicatedStorage")

local function boiteMonde(parts)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size / 2
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			local c = cf:PointToWorldSpace(Vector3.new(s.X * sx, s.Y * sy, s.Z * sz))
			lo = lo:Min(c); hi = hi:Max(c)
		end end end
	end
	return lo, hi
end

local function estVerre(p)
	local n = string.lower(p.Name)
	return p.Transparency > 0.05 or n:find("verre") or n:find("vitre") or n:find("_glass")
end

-- piece principale (dalle / pan de mur) : celle du catalogue, sinon la plus grande
local function piecePrincipale(info, parts)
	for _, p in ipairs(parts) do if p.Name == info.principale then return p end end
	local best, principale = -1, nil
	for _, p in ipairs(parts) do local v = p.Size.X * p.Size.Z + p.Size.X * p.Size.Y + p.Size.Y * p.Size.Z if v > best then best = v principale = p end end
	return principale
end

-- pivot attendu par le jeu (repere du monde, calcule sur les pieces telles qu'elles sont posees)
local function calculerPivot(info, parts, principale)
	local lo, hi = boiteMonde(parts)
	local plo, phi = boiteMonde({principale})
	local pc = (plo + phi) / 2
	if info.cat == "Sol" then
		return CFrame.new(pc.X, phi.Y - SOL_DESSUS, pc.Z)                              -- dessus de la dalle a +0.5
	elseif info.cat == "Plafond" then
		return CFrame.new(pc.X, lo.Y, pc.Z)                                            -- dessous du toit au sommet des murs
	elseif info.cat == "Mur" then
		-- pan de mur : longueur = axe horizontal le plus long, epaisseur = l'autre ; face avant = cote des saillies
		local d = phi - plo
		local axeEp = (d.X < d.Z) and Vector3.xAxis or Vector3.zAxis
		local saillieP, saillieM = 0, 0
		for _, p in ipairs(parts) do
			if p ~= principale then
				local l2, h2 = boiteMonde({p})
				saillieP = math.max(saillieP, h2:Dot(axeEp) - phi:Dot(axeEp))
				saillieM = math.max(saillieM, plo:Dot(axeEp) - l2:Dot(axeEp))
			end
		end
		local avant
		if saillieM > saillieP + 0.03 then avant = -axeEp
		elseif saillieP > saillieM + 0.03 then avant = axeEp
		else avant = -axeEp end                                                          -- symetrique : face avant = -Z (convention du pack)
		local pos = Vector3.new(pc.X, plo.Y - SOL_DESSUS, pc.Z) - avant * 5               -- pivot 5 studs derriere le mur, bas du mur au sol
		return CFrame.fromMatrix(pos, avant, Vector3.yAxis)                               -- X local = vers l'avant, Z local = le long du mur
	else
		-- decor : 1 case = pivot au centre ; plusieurs cases = centre de la premiere case (x min, z min)
		local cx = (info.nx > 1) and (lo.X + 5) or (lo.X + hi.X) / 2
		local cz = (info.nz > 1) and (lo.Z + 5) or (lo.Z + hi.Z) / 2
		return CFrame.new(cx, lo.Y + (MEUBLE_Y - SOL_DESSUS), cz)                       -- bas du meuble pose sur le sol
	end
end

-- Le pivot d'un Model qui a un PrimaryPart est celui du PrimaryPart (CFrame * PivotOffset) : WorldPivot est ignore.
-- L'import 3D laisse dans PivotOffset l'origine du FBX (un coin de la dalle) : on ecrit donc le pivot voulu dans
-- PivotOffset, ce qui rend GetPivot / PivotTo exacts quel que soit le chemin utilise par le jeu.
local function appliquerPivot(modele, principale, pivot)
	principale.PivotOffset = principale.CFrame:ToObjectSpace(pivot)
	modele.PrimaryPart = principale
	modele.WorldPivot = pivot
end

-- Passe de correction sur les constructions deja installees (relancable) : renvoie le nombre corrige
local function corrigerPivots()
	local corriges = 0
	for nom, info in pairs(CONSTRUCTIONS) do
		local dossier = RS:FindFirstChild(info.cat)
		local modele = dossier and dossier:FindFirstChild(nom)
		if modele and modele:IsA("Model") and not modele:FindFirstChild("Provisoire") then
			local parts = {}
			for _, d in ipairs(modele:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
			local principale = modele.PrimaryPart or piecePrincipale(info, parts)
			if principale and #parts > 0 then
				local pivot = calculerPivot(info, parts, principale)
				local ecart = (modele:GetPivot().Position - pivot.Position).Magnitude
					+ (modele:GetPivot().LookVector - pivot.LookVector).Magnitude
				if ecart > 1e-3 then
					appliquerPivot(modele, principale, pivot)
					corriges += 1
				end
			end
		end
	end
	return corriges
end

local function installer()
local Selection = game:GetService("Selection")
local InsertService = game:GetService("InsertService")

-- 0. constructions deja en place : pivots verifies / corriges, et rien a charger si tout est installe
local corriges = corrigerPivots()
if corriges > 0 then print(("[Installer] pivots corriges sur %d constructions deja installees"):format(corriges)) end
local aFaire = 0
for nom, info in pairs(CONSTRUCTIONS) do
	local dossier = RS:FindFirstChild(info.cat)
	local ancien = dossier and dossier:FindFirstChild(nom)
	if not ancien or ancien:FindFirstChild("Provisoire") or FORCER then aFaire += 1 end
end
if aFaire == 0 then
	print("[Installer] toutes les constructions sont deja installees (pivots verifies).")
	return 0, 0
end

-- modele importe : selection, sinon un Model de Workspace dont le nom commence par PACK_10, sinon chargement de l'asset
local racine = Selection:Get()[1]
if racine and not (racine:IsA("Model") and string.sub(racine.Name, 1, 7) == "PACK_10") then racine = nil end
if not racine then
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and string.sub(m.Name, 1, 7) == "PACK_10" then racine = m break end
	end
end
local chargeParScript = false
if not racine then
	print("[Installer] chargement de l'asset", ID_PACK, "…")
	local ok, conteneur = pcall(function() return InsertService:LoadAsset(ID_PACK) end)
	assert(ok and conteneur, "Impossible de charger l'asset " .. tostring(ID_PACK) .. " : " .. tostring(conteneur) .. " (connecte-toi dans Studio avec le compte proprietaire, ou importe le FBX dans Workspace)")
	racine = conteneur:FindFirstChildWhichIsA("Model") or conteneur
	racine.Parent = workspace
	conteneur:Destroy()
	chargeParScript = true
end
print("[Installer] modele importe :", racine:GetFullName())

-- index des descendants par nom (rapide)
local parNom = {}
for _, d in ipairs(racine:GetDescendants()) do
	parNom[d.Name] = parNom[d.Name] or {}
	table.insert(parNom[d.Name], d)
end

local installes, ignores, manquants = 0, 0, {}

for nom, info in pairs(CONSTRUCTIONS) do
	local dossier = RS:FindFirstChild(info.cat)
	if not dossier then dossier = Instance.new("Folder"); dossier.Name = info.cat; dossier.Parent = RS end
	local ancien = dossier:FindFirstChild(nom)
	if ancien and not ancien:FindFirstChild("Provisoire") and not FORCER then
		ignores += 1
		continue
	end

	-- 1. pieces importees : d'abord un Model du meme nom, sinon les MeshParts nommes comme dans le FBX
	local sources = {}
	local groupe = nil
	for _, d in ipairs(parNom[nom] or {}) do if d:IsA("Model") then groupe = d break end end
	if groupe then
		for _, d in ipairs(groupe:GetDescendants()) do if d:IsA("BasePart") then table.insert(sources, d) end end
	else
		for _, pn in ipairs(info.pieces) do
			for _, d in ipairs(parNom[pn] or {}) do if d:IsA("BasePart") then table.insert(sources, d) break end end
		end
	end
	if #sources == 0 then table.insert(manquants, nom) continue end

	-- 2. nouveau modele a plat : une copie de chaque piece (avec ses SurfaceAppearance / textures)
	local modele = Instance.new("Model"); modele.Name = nom
	local parts = {}
	for _, s in ipairs(sources) do
		local c = s:Clone()
		for _, ch in ipairs(c:GetChildren()) do
			if ch:IsA("BaseScript") or ch:IsA("JointInstance") or ch:IsA("Attachment") then ch:Destroy() end
		end
		c.PivotOffset = CFrame.new()
		c.Parent = modele
		table.insert(parts, c)
	end
	modele.Parent = workspace   -- temporaire (ScaleTo et GetBoundingBox veulent un modele dans le monde)

	-- 3. echelle : la hauteur importee doit valoir la hauteur du FBX (1 unite = 1 stud)
	local lo, hi = boiteMonde(parts)
	local h = hi.Y - lo.Y
	if h > 1e-4 then
		local ratio = info.taille.Y / h
		if math.abs(ratio - 1) > 0.02 then
			warn(("[Installer] %s : echelle corrigee x%.3f (importe %.2f studs de haut, attendu %.2f)"):format(nom, ratio, h, info.taille.Y))
			modele.WorldPivot = CFrame.new(lo)
			modele:ScaleTo(ratio)
		end
	end

	-- 4. piece principale (dalle / pan de mur) et proprietes physiques
	local principale = piecePrincipale(info, parts)
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanTouch = false
		p.CanQuery = true
		p.CanCollide = not estVerre(p)
		if estVerre(p) and p.Transparency < 0.3 then p.Transparency = 0.45 end
	end

	-- 5. pivot selon la categorie (PivotOffset de la piece principale, voir appliquerPivot)
	appliquerPivot(modele, principale, calculerPivot(info, parts, principale))
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- 6. remplacement dans ReplicatedStorage
	if ancien then ancien:Destroy() end
	modele.Parent = dossier
	installes += 1
end

print(("[Installer] %d constructions installees, %d deja en place (ignorees), %d introuvables dans l'import"):format(installes, ignores, #manquants))
if #manquants > 0 then warn("[Installer] introuvables : " .. table.concat(manquants, ", ")) end
if chargeParScript then racine:Destroy(); print("[Installer] Modele charge par le script supprime de Workspace.") else print("[Installer] Tu peux supprimer le modele importe de Workspace.") end
print("[Installer] Enregistre / publie la place pour conserver les meshes.")
return installes, #manquants
end

-- module : require(game.ServerStorage.Installer_Constructions)() ; colle dans la barre de commande : s'execute directement
if script and script:IsA("ModuleScript") then return installer end
return installer()
'''
open(os.path.join(OUT, 'Installer_Constructions.lua'), 'w').write(script.replace('__TABLE__', table))
print('installer :', len(inv), 'constructions')
