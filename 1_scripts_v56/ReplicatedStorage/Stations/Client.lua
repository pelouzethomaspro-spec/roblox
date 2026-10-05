--[[ Stations / Client   (lance par le LocalScript StationsClient, chez chaque joueur)
	Aucun mouvement n'est calcule : les robots ET les voitures sont deplaces par les animations Roblox publiees.
	Ce module se contente, pour chaque station :
		1) de savoir ou en est le cycle (horloge commune du serveur : workspace:GetServerTimeNow(), tous les joueurs
		   voient la meme chose au meme moment) ;
		2) au debut d'un cycle : copier la voiture, la souder aux pieces "Voiture"/"Roue_..." de la station,
		   lancer l'animation au bon endroit ;
		3) pendant le cycle : sons et effets (eau, peinture, lumieres...) via le comportement de la station ;
		4) a la fin : detruire la copie.
	Une erreur dans une station n'arrete pas les autres (elle est signalee une fois dans la sortie).

	DEUX MODES (version tycoon) :
		- commande par le serveur (par defaut) : le serveur (CarManager) pose sur le modele de la station
		  l'attribut "CycleDebut" (heure serveur du debut du cycle) et un ObjectValue "VoitureCycle" (la voiture
		  cliente a traiter). Le client cache cette voiture, en anime une copie soudee a la station, puis la
		  re-affiche quand le serveur remet CycleDebut a 0. Le client ne renvoie RIEN au serveur.
		- boucle (attribut "Boucle" = true sur le modele) : demo continue avec les voitures de VoituresModeles,
		  calee sur D.PHASE / D.CYCLE (stations de decor).
	Seules les stations posees dans Workspace comptent : les apercus (menu de construction, ViewportFrame) sont ignores.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Stations = script.Parent
local Reglages = require(Stations.Reglages)
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Voiture = require(Stations.Voiture)

local Client = {}
local PLACES = {"AVG", "AVD", "ARG", "ARD"}

------------------------------------------------------------------
-- 1) voitures disponibles (meme ordre chez tous les joueurs)
------------------------------------------------------------------
local dossierVoitures
local function listeVoitures()
	local t, vus = {}, {}
	if not dossierVoitures then return t end
	for _, nom in ipairs(Reglages.VOITURES) do
		local m = dossierVoitures:FindFirstChild(nom)
		if m and m:IsA("Model") and not vus[m] then table.insert(t, m); vus[m] = true end
	end
	local autres = {}
	for _, m in ipairs(dossierVoitures:GetChildren()) do if m:IsA("Model") and not vus[m] then table.insert(autres, m) end end
	table.sort(autres, function(a, b) return a.Name < b.Name end)
	for _, m in ipairs(autres) do table.insert(t, m) end
	return t
end

------------------------------------------------------------------
-- 2) animation d'une station : ID publie ; en test dans Studio, KeyframeSequence enregistree a la volee
------------------------------------------------------------------
local function idValide(id) return type(id) == "string" and id ~= "" and not id:match("://0*$") end
local function chargerAnimation(st)
	local nom = st.D.ANIMATION
	local id = Reglages.ANIMATIONS[nom]
	if not idValide(id) then
		id = nil
		local test = ReplicatedStorage:FindFirstChild("AnimationsTest_ASupprimer")
		local kfs = test and test:FindFirstChild(nom)
		if kfs and RunService:IsStudio() then
			local ok, r = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs) end)
			if ok then id = r end
		end
	end
	if not id then
		warn(("Stations : pas d'ID d'animation pour %s (Stations > Reglages > ANIMATIONS) : la station reste immobile"):format(nom))
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = st.animator:LoadAnimation(anim)
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	return track
end

------------------------------------------------------------------
-- 3) une station
------------------------------------------------------------------
local stations = {}
local Comportements = Stations.Comportements

local function signaler(st, err)
	if st.dejaSignale ~= tostring(err) then
		st.dejaSignale = tostring(err)
		warn(("Stations : %s : %s"):format(st.D.NOM, tostring(err)))
	end
end

-- la vraie voiture cliente (objet du serveur) est cachee chez ce joueur pendant que sa copie est animee
local function cacherReelle(m, oui)
	if not m then return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.LocalTransparencyModifier = oui and 1 or 0 end
	end
end

local function enregistrer(modele)
	if stations[modele] then return end
	-- ignorer les apercus : fantome du menu de construction, clones dans un ViewportFrame...
	if not modele:IsDescendantOf(workspace) or modele:GetAttribute("Apercu") then return end
	local nom = modele:GetAttribute("Station")
	local mod = nom and Stations.Donnees:FindFirstChild(nom)
	if not mod then return end
	local D = require(mod)
	local socle = modele:WaitForChild("Socle", 10)
	local ctrl = modele:WaitForChild("Animation", 10)
	local voiture = D.MODE ~= "chaine" and modele:WaitForChild("Voiture", 10)
	if not (socle and ctrl and (voiture or D.MODE == "chaine")) then warn("Stations : " .. nom .. " n'est pas montee (lance MonterStations_Studio)") return end
	local st = {modele = modele, D = D, socle = socle, rep = Outils.repere(socle), voiture = voiture, roues = {}, motRoues = {}, cache = {}}
	st.animator = ctrl:FindFirstChildOfClass("Animator") or ctrl:WaitForChild("Animator", 10)
	st.motVoiture = voiture and voiture:FindFirstChild("Articulation")
	for _, pl in ipairs(PLACES) do
		local r = modele:FindFirstChild("Roue_" .. pl)
		if r then st.roues[pl] = r; st.motRoues[pl] = r:FindFirstChild("Articulation") end
	end
	function st:piece(n)
		local p = self.cache[n]
		if not p then p = self.modele:FindFirstChild(n, true); self.cache[n] = p end
		return p
	end
	st.comp = require(Comportements:FindFirstChild(D.COMPORTEMENT)).nouveau(st)
	st.track = chargerAnimation(st)
	st.centre = st.rep:point(Outils.cf(D.PARC or D.SEGMENTS[1].parc).Position)      -- milieu de la place
	st.actif = false
	st.boucle = modele:GetAttribute("Boucle") == true or D.MODE == "chaine"      -- demo continue (decor, chaine de production) ; sinon commande par le serveur
	stations[modele] = st
end

local function oublier(modele)
	local st = stations[modele]
	if not st then return end
	stations[modele] = nil
	if st.cycle then pcall(function() st.comp:fin(st.cycle) end); Voiture.detruire(st.cycle.C) end
	if st.comp.arreter then pcall(function() st.comp:arreter() end) end
	if st.track then st.track:Stop(0) end
	cacherReelle(st.reelle, false); st.reelle = nil
end

-- segment de l'animation pour cette voiture (categorie, modele ou unique)
local function choisirSegment(st, C)
	local D = st.D
	if st.comp.choisirSegment then return st.comp:choisirSegment(C) end
	if D.MODE == "categorie" then
		for _, s in ipairs(D.SEGMENTS) do if s.nom == C.categorie.nom then return s end end
		-- categorie absente : la plus proche dans l'ordre des categories
		local ordre = {Sportive = 1, Berline = 2, Compacte = 3, Haute = 4}
		local best, db = D.SEGMENTS[1], math.huge
		for _, s in ipairs(D.SEGMENTS) do
			local d = math.abs((ordre[s.nom] or 0) - (ordre[C.categorie.nom] or 0))
			if d < db then best, db = s, d end
		end
		return best
	end
	return D.SEGMENTS[1]
end

local function commencer(st, n)
	local D = st.D
	if D.MODE == "chaine" then                                   -- chaine : le comportement gere lui-meme ses voitures
		local cy = {n = n, plages = {{t0 = 0, t1 = D.CYCLE, anim = 0}}, fin = D.CYCLE}
		st.comp:debut(cy)
		st.cycle = cy
		return
	end
	local modele
	if st.boucle then                                            -- demo : voitures de VoituresModeles, a tour de role
		local liste = listeVoitures()
		if #liste == 0 then return end
		modele = liste[(n + D.INDEX * Reglages.DECALAGE) % #liste + 1]
	else                                                         -- tycoon : la voiture cliente designee par le serveur
		local ov = st.modele:FindFirstChild("VoitureCycle")
		local reelle = ov and ov.Value
		if not (reelle and reelle:IsDescendantOf(workspace) and reelle:FindFirstChildWhichIsA("BasePart", true)) then
			st.n = nil                                           -- pas encore repliquee chez ce joueur : on reessaie a l'image suivante
			return
		end
		cacherReelle(reelle, true)
		st.reelle = reelle
		modele = reelle
	end
	local C
	local ok, err = pcall(function()
		C = Voiture.copier(modele, st.rep, st.comp.ajuster and function(c) return st.comp:ajuster(c) end)
		local seg = choisirSegment(st, C)
		if st.comp.echelleSegment then                             -- ex : E5, modele inconnu -> voiture ramenee au gabarit du segment
			local k = st.comp:echelleSegment(C, seg)
			if k and math.abs(k - 1) > 0.001 then
				local v = C.voiture
				v:ScaleTo(v:GetScale() * k)
				C = Voiture.mesurer(v, st.rep); C.modele = modele.Name
			end
		end
		local cy = {n = n, C = C, seg = seg, rng = Random.new(n * 131 + D.INDEX * 7)}
		-- position garee : celle du segment, decalee pour que CETTE voiture s'arrete a sa place (milieu des roues)
		local parc = Outils.cf(seg.parc or D.PARC)
		if D.STOP == "milieu" and seg.milieu then parc = CFrame.new(0, C.MILIEU_Y - seg.milieu, 0) * parc end
		cy.parc = parc
		if D.MODE == "simple" then
			local arr, dep = D.SEGMENTS[1], D.SEGMENTS[2]
			cy.T_ARRET, cy.T_DEPART = arr.duree, arr.duree + D.ARRET
			cy.plages = {{t0 = 0, t1 = arr.duree, anim = arr.debut}, {t0 = cy.T_DEPART, t1 = cy.T_DEPART + dep.duree, anim = dep.debut}}
			cy.fin = cy.T_DEPART + dep.duree
		else
			cy.plages = {{t0 = 0, t1 = seg.duree, anim = seg.debut}}
			cy.fin = seg.duree
		end
		if st.comp.avantMontage then st.comp:avantMontage(cy) end
		Voiture.monter(C, st, parc)
		Voiture.moteur(C)
		st.comp:debut(cy)
		st.cycle = cy
	end)
	if not ok then Voiture.detruire(C); st.cycle = nil; error(err, 0) end
end

local function terminer(st)
	local cy = st.cycle
	st.cycle = nil
	if st.track and st.track.IsPlaying then st.track:Stop(0) end
	if cy then
		Voiture.detruire(cy.C)
		st.comp:fin(cy)
	end
end

local function majStation(st, maintenant, dt)
	local D = st.D
	local n, tc
	if st.boucle then
		local u = (maintenant - D.PHASE) / D.CYCLE
		n = math.floor(u)
		tc = (u - n) * D.CYCLE
	else
		-- commande par le serveur : CycleDebut = heure serveur du debut du cycle en cours (0 ou absent = rien a faire)
		local debut = st.modele:GetAttribute("CycleDebut")
		if type(debut) ~= "number" or debut <= 0 then
			if st.cycle then terminer(st) end
			st.n = nil
			if st.reelle then cacherReelle(st.reelle, false); st.reelle = nil end   -- le serveur a repris la main sur la voiture
			return
		end
		n = debut                                                -- l'heure de debut identifie le cycle
		tc = maintenant - debut
		if tc < 0 then return end                                -- horloge legerement en avance : on attend
	end
	if n ~= st.n then
		st.n = n
		terminer(st)
		commencer(st, n)
	end
	local cy = st.cycle
	if not cy then return end
	-- animation : elle joue pendant les plages du cycle, calee sur l'horloge commune
	local plage
	for _, p in ipairs(cy.plages) do if tc >= p.t0 and tc < p.t1 then plage = p break end end
	local tr = st.track
	if plage then
		if tr then
			local cible = plage.anim + (tc - plage.t0)
			if not tr.IsPlaying then
				tr:Play(0, 1, 1)
				tr.TimePosition = cible
			elseif math.abs(tr.TimePosition - cible) > 0.12 then
				tr.TimePosition = cible
			end
		end
	else
		if tc >= cy.fin and cy.C then Voiture.detruire(cy.C); cy.C = nil end
		if tr and tr.IsPlaying then tr:Stop(0) end
	end
	if cy.C then Voiture.majMoteur(cy.C, dt) end
	st.comp:maj(cy, tc, dt)
end

------------------------------------------------------------------
-- 4) lancement
------------------------------------------------------------------
function Client.lancer()
	-- rien a animer en mode edition (un plugin peut lancer les LocalScripts hors partie : on ne cree alors ni voitures
	-- ni effets, sinon ils finissent enregistres dans la place). Surtout pas RunService:IsEdit() ici : cette methode est
	-- reservee aux plugins (PluginSecurity) et fait planter le script dans le jeu publie -> plus aucune animation en ligne.
	if RunService:IsStudio() and not RunService:IsRunning() then return end
	Sons.VOLUME = Reglages.VOLUME or 1
	Voiture.REGLAGES.MOTEUR = Reglages.MOTEUR ~= false
	-- VoituresModeles ne sert qu'au mode boucle (decor) : on ne bloque pas le lancement s'il manque
	dossierVoitures = ReplicatedStorage:FindFirstChild("VoituresModeles")
	if not dossierVoitures then
		task.spawn(function()
			dossierVoitures = ReplicatedStorage:WaitForChild("VoituresModeles", 30)
			if not dossierVoitures then warn("Stations : ReplicatedStorage.VoituresModeles introuvable (mode boucle indisponible)") end
		end)
	end
	for _, m in ipairs(CollectionService:GetTagged("Station")) do task.spawn(enregistrer, m) end
	CollectionService:GetInstanceAddedSignal("Station"):Connect(function(m) task.spawn(enregistrer, m) end)
	CollectionService:GetInstanceRemovedSignal("Station"):Connect(oublier)
	-- seules les stations proches du joueur (de sa camera) vivent : au-dela, rien n'est anime ni calcule
	local D_ON = Reglages.DISTANCE_ACTIVE or 150
	-- marge de 20 studs entre marche et arret : pas de marche / arret en boucle a la limite
	local function etape(dt)
		local maintenant = workspace:GetServerTimeNow()
		local cam = workspace.CurrentCamera
		local oeil = cam and cam.CFrame.Position
		for _, st in pairs(stations) do
			local d = oeil and (st.centre - oeil).Magnitude or 0
			local on = st.D.DISTANCE_ACTIVE or D_ON                 -- (la chaine, tres longue, a sa propre distance)
			if st.actif and d > on + 20 then
				st.actif = false
				pcall(terminer, st)                                 -- voiture detruite, animation et sons arretes
				if st.comp.arreter then pcall(function() st.comp:arreter() end) end
				st.n = nil                                          -- en revenant : reprise au bon moment du cycle
			elseif not st.actif and d < on then
				st.actif = true
			end
			if st.actif then
				local ok, err = pcall(majStation, st, maintenant, dt)
				if not ok then signaler(st, err) end
			end
		end
	end
	-- avant le calcul des animations de l'image : la voiture et l'animation partent dans la meme image
	local ok, ev = pcall(function() return RunService.PreAnimation end)
	if not ok or not ev then ev = RunService.Stepped end
	ev:Connect(function(a, b) etape(b or a) end)
end

Client._stations = stations          -- pour les tests
return Client
