--[[ Stations / Montage   (utilise UNE FOIS dans Studio, par la barre de commande : voir MonterStations_Studio)
	Prepare la place pour les animations ; rien de tout cela ne tourne pendant le jeu :
		1) chaque station : pieces ancrees (figees), piece invisible "Socle" au repere du modele, une articulation
		   (Motor6D) par piece mobile a son vrai pivot, pieces invisibles "Voiture" et "Roue_AVG/AVD/ARG/ARD"
		   (la voiture de chaque cycle y sera soudee), AnimationController + Animator, etiquette "Station" ;
		2) les KeyframeSequences (fichier AnimationsStations.rbxmx) rangees la ou l'editeur d'animation les trouve :
		   ServerStorage > RBX_ANIMSAVES > <station>, + une copie de test dans ReplicatedStorage ;
		3) les voitures : rangees dans ReplicatedStorage > VoituresModeles, a 16 studs de long.
	On peut le relancer sans risque (il refait les articulations).
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Stations = script.Parent
local Outils = require(Stations.Outils)
local Reglages = require(Stations.Reglages)

local Montage = {}
local PLACES = {"AVG", "AVD", "ARG", "ARD"}
local ROUES_NOMINALES = {AVG = {-2.6, 4.6, 1.1}, AVD = {2.6, 4.6, 1.1}, ARG = {-2.6, -4.4, 1.1}, ARD = {2.6, -4.4, 1.1}}

local function trouverPiece(nom)
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == nom then return d end
	end
	return nil
end

-- repere du modele (FBX, Z en haut) -> monde, d'apres 1 ou 2 pieces de reference
local function calculerMAP(D, racine)
	local n1, n2 = D.REFS[1], D.REFS[2]
	local ref = racine:FindFirstChild(n1, true)
	local c1 = Outils.V(D.CENTRES[n1])
	local autre = n2 and racine:FindFirstChild(n2, true)
	local yaw
	if autre then
		local vb = Outils.B:VectorToWorldSpace(Outils.V(D.CENTRES[n2]) - c1)
		local va = autre.Position - ref.Position
		yaw = math.atan2(va.X, va.Z) - math.atan2(vb.X, vb.Z)
	else
		local l = ref.CFrame.LookVector
		yaw = math.atan2(-l.X, -l.Z)
	end
	return CFrame.new(ref.Position) * CFrame.Angles(0, yaw, 0) * Outils.B * CFrame.new(-c1)
end

local function invisible(nom, taille, parent, cf)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = Vector3.new(taille, taille, taille)
	p.Transparency = 1
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Massless = true
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function estMobile(n) return n:find("_Mob_") ~= nil or n:find("_Bras") ~= nil end
local function estTranslucide(n) return n:find("_Transparent") ~= nil or n:find("_Vitres") ~= nil or n:find("_Verre") ~= nil end

-- articulation : Part1 tourne / glisse autour de "pivot" (repere du modele) ; l'animation donne la valeur
local function articuler(part0, part1, MAP, pivot)
	local m = Instance.new("Motor6D")
	m.Name = "Articulation"
	local J = MAP * CFrame.new(pivot)
	m.C0 = part0.CFrame:Inverse() * J
	m.C1 = part1.CFrame:Inverse() * J
	m.Part0, m.Part1 = part0, part1
	m.Parent = part1
	return m
end

------------------------------------------------------------------
-- chaine de production : pieces invisibles des voitures (+ palette, moyeux), verre, lumieres, collisions
------------------------------------------------------------------
function Montage.chaine(D, racine, socle, MAP)
	-- anciens scripts "film" (version sans animations publiees) : ils feraient doublon avec les animations
	for _, s in ipairs(racine:GetDescendants()) do
		if s:IsA("BaseScript") and (s.Name == "ChaineProduction" or s.Name == "ChaineProduction_Figer" or s.Name == "Script") then
			if s.Source and (s.Source:find("ChaineProduction", 1, true)) then s:Destroy() end
		end
	end
	for _, p in ipairs(D.PLACES) do
		local v = racine:FindFirstChild(p.nom)
		if v then v:Destroy() end
	end
	local faites = {Socle = socle}
	for _, p in ipairs(D.PLACES) do
		local p0 = faites[p.parent]
		local c0 = Outils.cf(p.c0)
		local part = invisible(p.nom, p.taille, racine, p0.CFrame * c0)
		local m = Instance.new("Motor6D"); m.Name = "Articulation"
		m.Part0, m.Part1, m.C0 = p0, part, c0
		m.Parent = part
		faites[p.nom] = part
	end
	local A = D.APPARENCE or {}
	for nom, tr in pairs(A.verre or {}) do
		local p = racine:FindFirstChild(nom, true)
		if p then p.Transparency = tr; p.CastShadow = false; p.CanCollide = true; p.CanQuery = true end
	end
	for nom, tr in pairs(A.neon or {}) do
		local p = racine:FindFirstChild(nom, true)
		if p then
			p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(255, 244, 222); p.Transparency = tr; p.CastShadow = false
			if p:IsA("MeshPart") then pcall(function() p.TextureID = "" end) end
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then sa:Destroy() end
		end
	end
	for _, nom in ipairs(A.sansCollision or {}) do
		local p = racine:FindFirstChild(nom, true)
		if p then p.CanCollide = false; p.CanQuery = false end
	end
	-- collisions fideles (hall creux : on doit pouvoir y entrer) ; pieces mobiles : simple boite
	local n = 0
	for _, nom in ipairs(A.precis or {}) do
		local p = racine:FindFirstChild(nom, true)
		if p and p:IsA("MeshPart") then
			local ok = pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition end)
			if ok then n += 1 end
		end
	end
	for _, j in ipairs(D.JOINTS) do
		local p = racine:FindFirstChild(j[1], true)
		if p and p:IsA("MeshPart") then pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end) end
	end
	if n < #(A.precis or {}) then
		warn("Montage : collisions fideles posees sur " .. n .. "/" .. #(A.precis or {}) .. " pieces (voir le guide : CollisionFidelity)")
	end
end

------------------------------------------------------------------
-- 1) une station
------------------------------------------------------------------
-- racineForcee (facultatif) : modele a monter, quand plusieurs exemplaires de la station existent (les 4 chaines de la
-- map V17, regroupees par InstallerChaines) ; sinon on cherche la premiere piece de reference dans Workspace
function Montage.station(D, racineForcee)
	local ref = racineForcee and racineForcee:FindFirstChild(D.REFS[1], true) or trouverPiece(D.REFS[1])
	if not ref then warn("Montage : station " .. D.NOM .. " absente de Workspace (piece " .. D.REFS[1] .. ")") return nil end
	local racine = racineForcee or ref.Parent
	if D.MODE == "chaine" then
		-- l'import 3D peut ranger les pieces dans des sous-modeles : on prend le modele le plus haut sous Workspace
		while not racineForcee and racine.Parent and racine.Parent ~= workspace and racine.Parent:IsA("Model") do racine = racine.Parent end
		-- figer d'abord TOUT le modele (rien ne tombe, meme si la suite echoue) ; les pieces animees sont liberees plus bas
		for _, p in ipairs(racine:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
	end
	-- nettoyage d'un montage precedent (les pieces sont revenues au repos : rien n'anime en edition)
	for _, d in ipairs(racine:GetDescendants()) do
		if (d:IsA("Motor6D") and d.Name == "Articulation") then d:Destroy() end
	end
	local socle = racine:FindFirstChild("Socle")
	local MAP = socle and socle.CFrame or calculerMAP(D, racine)
	if not socle then socle = invisible("Socle", 1, racine, MAP) end
	socle.Anchored = true
	-- figer : pieces fixes ancrees ; pieces mobiles libres (tenues par leurs articulations), sans collision
	local mobiles = {}
	for _, j in ipairs(D.JOINTS) do mobiles[j[1]] = true end
	for _, p in ipairs(racine:GetDescendants()) do
		if p:IsA("BasePart") and p ~= socle then
			p.CanTouch = false
			if mobiles[p.Name] then
				p.Anchored = false; p.Massless = true; p.CanCollide = false; p.CanQuery = false
			elseif p.Parent == racine and (p.Name == "Voiture" or p.Name:match("^Roue_")) then
				-- pieces invisibles de la voiture : refaites plus bas
			else
				p.Anchored = true
				if estMobile(p.Name) or estTranslucide(p.Name) then p.CanCollide = false; p.CanQuery = false end
				if estTranslucide(p.Name) then p.CastShadow = false end
			end
		end
	end
	-- articulations des robots
	local n = 0
	for _, j in ipairs(D.JOINTS) do
		local p1 = racine:FindFirstChild(j[1], true)
		local p0 = (j[2] == "Socle") and socle or racine:FindFirstChild(j[2], true)
		if not (p0 and p1) then error(("%s : piece introuvable : %s"):format(D.NOM, p1 and j[2] or j[1])) end
		p1:SetAttribute("Repos", p1.CFrame)
		articuler(p0, p1, MAP, Outils.V(j[4]))
		n += 1
	end
	if D.MODE == "chaine" then
		Montage.chaine(D, racine, socle, MAP)
	else
	-- pieces invisibles de la voiture (la copie de chaque cycle y est soudee par le script des joueurs)
	for _, nom in ipairs({"Voiture", "Roue_AVG", "Roue_AVD", "Roue_ARG", "Roue_ARD"}) do
		local v = racine:FindFirstChild(nom)
		if v then v:Destroy() end
	end
	local parc = Outils.cf(D.PARC or D.SEGMENTS[1].parc)
	local voiture = invisible("Voiture", 0.4, racine, MAP * parc)
	local mv = Instance.new("Motor6D"); mv.Name = "Articulation"
	mv.Part0, mv.Part1, mv.C0 = socle, voiture, parc
	mv.Parent = voiture
	for _, pl in ipairs(PLACES) do
		local c = Outils.V(ROUES_NOMINALES[pl])
		local r = invisible("Roue_" .. pl, 0.3, racine, voiture.CFrame * CFrame.new(c))
		local m = Instance.new("Motor6D"); m.Name = "Articulation"
		m.Part0, m.Part1, m.C0 = voiture, r, CFrame.new(c)
		m.Parent = r
	end
	end
	-- animateur
	local ctrl = racine:FindFirstChild("Animation")
	if not ctrl then ctrl = Instance.new("AnimationController"); ctrl.Name = "Animation"; ctrl.Parent = racine end
	if not ctrl:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = ctrl end
	if racine:IsA("Model") then
		racine.PrimaryPart = socle
		pcall(function() racine.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	end
	racine:SetAttribute("Station", D.NOM)
	CollectionService:AddTag(racine, "Station")
	print(("Montage : %s -> %d articulations"):format(D.NOM, n))
	return racine
end

------------------------------------------------------------------
-- 2) animations : rangees pour l'editeur d'animation (+ copie de test)
------------------------------------------------------------------
local function dossierDe(parent, nom, classe)
	local f = parent:FindFirstChild(nom)
	if not f then f = Instance.new(classe or "Folder"); f.Name = nom; f.Parent = parent end
	return f
end

function Montage.animations(montees)
	local source
	for _, lieu in ipairs({workspace, ServerStorage, ReplicatedStorage}) do
		source = lieu:FindFirstChild("AnimationsStations", true)
		if source then break end
	end
	if not source then
		warn("Montage : dossier AnimationsStations introuvable (insere AnimationsStations.rbxmx) - animations non rangees")
		return
	end
	local saves = dossierDe(ServerStorage, "RBX_ANIMSAVES")
	local test = dossierDe(ReplicatedStorage, "AnimationsTest_ASupprimer")
	for _, kfs in ipairs(source:GetChildren()) do
		if kfs:IsA("KeyframeSequence") then
			for racine, D in pairs(montees) do
				local piste = false
				for _, p in ipairs(D.PISTES or {}) do if p.nom == kfs.Name then piste = true end end
				if D.ANIMATION == kfs.Name or piste then
					local f = dossierDe(saves, racine.Name)
					local ancien = f:FindFirstChild(kfs.Name)
					if ancien then ancien:Destroy() end
					kfs:Clone().Parent = f
					local lien = racine:FindFirstChild("AnimSaves")
					if lien and not lien:IsA("ObjectValue") then lien.Name = "AnimSaves_ancien"; lien = nil end
					if not lien then lien = Instance.new("ObjectValue"); lien.Name = "AnimSaves"; lien.Parent = racine end
					lien.Value = f
				end
			end
			local ancien = test:FindFirstChild(kfs.Name)
			if ancien then ancien:Destroy() end
			-- copie de test (Studio seulement) tant que l'animation n'a pas d'ID publie
			local id = Reglages.ANIMATIONS and Reglages.ANIMATIONS[kfs.Name]
			if not (type(id) == "string" and id:match("%d") and not id:match("://0*$")) then kfs:Clone().Parent = test end
		end
	end
	if #test:GetChildren() == 0 then test:Destroy() end
	source.Parent = ServerStorage
	print("Montage : animations rangees dans ServerStorage > RBX_ANIMSAVES (+ copie de test dans ReplicatedStorage)")
end

------------------------------------------------------------------
-- 3) voitures : ReplicatedStorage > VoituresModeles, a la bonne longueur
------------------------------------------------------------------
local TESTS = {
	function(m, n) return m == n end,
	function(m, n) return m:sub(1, #n) == n and not m:sub(#n + 1, #n + 1):match("%w") end,
	function(m, n) return m:find(n, 1, true) ~= nil end,
}
function Montage.voitures()
	local dossier = dossierDe(ReplicatedStorage, "VoituresModeles")
	local function exclu(d)
		if d:IsDescendantOf(dossier) then return true end
		local a = d
		while a do
			if a:GetAttribute("Station") or a.Name == "AnimationsStations" or a.Name == "RBX_ANIMSAVES" then return true end
			a = a.Parent
		end
		return false
	end
	local function chercher(nom, niveau)
		local n = string.lower(nom)
		for _, lieu in ipairs({workspace, ServerStorage, ReplicatedStorage}) do
			for _, d in ipairs(lieu:GetDescendants()) do
				if d:IsA("Model") and TESTS[niveau](string.lower(d.Name), n) and not exclu(d) and d:FindFirstChildWhichIsA("BasePart", true) then return d end
			end
		end
	end
	local restant = {}
	for _, nom in ipairs(Reglages.VOITURES) do if not dossier:FindFirstChild(nom) then table.insert(restant, nom) end end
	for niveau = 1, 3 do
		for i = #restant, 1, -1 do
			local m = chercher(restant[i], niveau)
			if m then m.Name = restant[i]; m.Parent = dossier; table.remove(restant, i) end
		end
	end
	for _, nom in ipairs(restant) do warn("Montage : voiture introuvable : " .. nom) end
	local okCar, Car = pcall(function() return require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Car")) end)
	local L0 = Reglages.LONGUEUR_VOITURE
	local n = 0
	for _, m in ipairs(dossier:GetChildren()) do
		if m:IsA("Model") then
			n += 1
			for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
			local voulu = (okCar and Car.Longueur) and Car.Longueur(m.Name) or L0
			if voulu then
				local ext = m:GetExtentsSize()
				local L = math.max(ext.X, ext.Z)
				if math.abs(L - voulu) > 0.3 then m:ScaleTo(m:GetScale() * voulu / L) end
			end
		end
	end
	print(("Montage : %d voiture(s) dans ReplicatedStorage > VoituresModeles"):format(n))
end

------------------------------------------------------------------
-- tout
------------------------------------------------------------------
function Montage.tout()
	local montees = {}
	for _, m in ipairs(Stations.Donnees:GetChildren()) do
		if m:IsA("ModuleScript") then
			local D = require(m)
			local ok, r = pcall(Montage.station, D)
			if not ok then warn("Montage : " .. D.NOM .. " : " .. tostring(r)) elseif r then montees[r] = D end
		end
	end
	Montage.animations(montees)
	Montage.voitures()
	print("Montage termine. Etape suivante : publier les animations (guide).")
end

return Montage
