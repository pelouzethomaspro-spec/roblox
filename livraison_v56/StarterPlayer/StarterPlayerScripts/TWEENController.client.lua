--[[ TWEENController (LocalScript, StarterPlayerScripts)
	Tout le mouvement visible des PNJ et des voitures se joue ICI, chez chaque joueur. Le serveur ne fait qu'annoncer
	"cette voiture va a ce point en N secondes" (MoveCarEvent) et pose la voiture a l'arrivee : il ne calcule aucune
	image intermediaire, ne touche jamais aux roues ni aux sons.

	Voitures :
	  - trajet le long d'une courbe de Bezier (le Root de la voiture regarde toujours vers l'avant du modele) ;
	  - roues : elles tournent d'apres la distance parcourue a chaque image (angle = distance / rayon), autour de
	    l'axe lateral de la voiture ; les pieces des roues sont detachees localement de la soudure (ancrees) et posees
	    chaque image par rapport au Root -> aucun calcul physique, aucune replication ;
	  - moteur : un Sound 3D local par voiture, en boucle, dont la hauteur et le volume suivent la vitesse
	    (ralenti a l'arret). Cree a la premiere mise en mouvement, detruit avec la voiture.
	Cout : quelques CFrame par roue et par image, uniquement pour les voitures en train de rouler.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MovePnjEvent = ReplicatedStorage:WaitForChild("MovePnjEvent")
local MoveCarEvent = ReplicatedStorage:WaitForChild("MoveCarEvent")

-- Son du moteur : le meme "Go Kart Engine Constant 2" (son libre Roblox) que les stations (Stations/Sons.moteurVoiture),
-- joue grave. Pour en changer : remplace l'ID (asset audio publie sur ton compte ou son libre de la boutique) ; "" = aucun son.
local SON_MOTEUR = {
	id = "rbxassetid://9112787518",
	volume = 0.22,                -- volume en roulant (au ralenti : la moitie)
	hauteurArret = 0.5,           -- PlaybackSpeed au ralenti
	hauteurRoute = 0.9,           -- PlaybackSpeed a la vitesse de croisiere (45 studs/s)
	porteeMin = 20,               -- distance (studs) sans attenuation
	porteeMax = 180,              -- distance au-dela de laquelle on n'entend plus rien
}
local VITESSE_CROISIERE = 32      -- studs/s : vitesse des trajets calcules par le serveur (CarManager.VITESSE)
-- v56 : sons PAR MODELE a partir d'Epique (Catalogue/Car.Sons : Ralenti en boucle, Acceleration une fois au "Rugissement")
local CarCat = nil
pcall(function() CarCat = require(ReplicatedStorage:WaitForChild("Catalogue", 10):WaitForChild("Car", 10)) end)
local function sonsDe(car)
	if not (CarCat and CarCat.SonDe) then return nil end
	local nom = car:GetAttribute("Name") or car:GetAttribute("Modele") or car.Name
	local ok, S = pcall(CarCat.SonDe, nom)
	return ok and S or nil
end

-- ======================================================================================================================
-- PNJ (inchange) : tween lineaire + animation de marche
-- ======================================================================================================================
local PnjAnimations = {}

MovePnjEvent.OnClientEvent:Connect(function(pnj, cible, duree, etatanimation)
	if not pnj or not pnj.PrimaryPart then return end

	local humanoid = pnj:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChild("Animator")

	local animation = pnj:FindFirstChild("Marche")
	if not animator or not animation then return end

	local track = PnjAnimations[pnj]
	if not track then
		track = animator:LoadAnimation(animation)
		PnjAnimations[pnj] = track
	end

	if (etatanimation == 0 or etatanimation == 3) then
		track:Play()
	end

	local root = pnj.PrimaryPart
	local offset = pnj:GetPivot():ToObjectSpace(root.CFrame)
	local cibleRoot = cible * offset

	local tweenInfo = TweenInfo.new(duree, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(pnj.PrimaryPart, tweenInfo, {CFrame = cibleRoot})
	tween:Play()

	if etatanimation == 2 or etatanimation == 3 then
		tween.Completed:Once(function()
			if track.IsPlaying then
				track:Stop()
			end
			PnjAnimations[pnj] = nil
		end)
	end
end)

-- ======================================================================================================================
-- VOITURES : roues et moteur
-- ======================================================================================================================
local Voitures = {}          -- [car] = { root, roues = { {parts = {{part, offset}}, centre = Vector3, rayon} }, angle, son, vitesse, enTrajet, tween }

local function estRoue(n)
	n = string.lower(n)
	return n:find("wheel") or n:find("roue") or n:find("pneu") or n:find("tire") or n:find("tyre") or n:find("jante") or n:find("rim")
end

-- v54 : roues sans nom (le van de livraison : pieces "Part" / "Mesh") -> reconnues a leur forme : pieces rondes (deux
-- dimensions egales, la troisieme = l'epaisseur, plus petite), posees au ras du bas du vehicule, regroupees par proximite
local function rouesParGeometrie(car, root)
	local okB, cfB, taille = pcall(function() return car:GetBoundingBox() end)
	if not okB then return {}, {} end
	local bas = cfB.Position.Y - taille.Y / 2
	local rootCF = root.CFrame
	local candidats = {}
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 0.9 then
			local sz = p.Size
			local d = {sz.X, sz.Y, sz.Z}; table.sort(d)
			local epaisseur, d1, d2 = d[1], d[2], d[3]
			local rond = d2 > 1.8 and d2 < 12 and (d2 - d1) / d2 < 0.2 and epaisseur < d1 * 0.75
			local auSol = p.Position.Y - bas < d2 * 0.75                  -- centre a moins de 3/4 de diametre du bas
			local l = rootCF:PointToObjectSpace(p.Position)
			local surLeCote = math.abs(l.X) > taille.X * 0.2              -- pas au milieu du chassis
			if rond and auSol and surLeCote then table.insert(candidats, {p = p, r = d2 / 2, l = l}) end
		end
	end
	-- regroupement par proximite (pneu + jante + enjoliveur d'une meme roue)
	local groupes, ordre = {}, {}
	for _, c in ipairs(candidats) do
		local cle = nil
		for k, g in pairs(groupes) do
			if (g.centre - c.l).Magnitude < math.max(c.r, g.r) * 0.9 then cle = k break end
		end
		if not cle then cle = "RoueGeo" .. (#ordre + 1); groupes[cle] = { parts = {}, centre = c.l, r = c.r }; table.insert(ordre, cle) end
		table.insert(groupes[cle].parts, c.p)
		groupes[cle].r = math.max(groupes[cle].r, c.r)
	end
	local out = {}
	for _, cle in ipairs(ordre) do out[cle] = groupes[cle].parts end
	return out, ordre
end

-- groupes de roues : un Model "Roue_AVG" regroupe ses pieces ; sinon les pieces "Roue_AVG_1", "Roue_AVG_2"... ensemble
local function groupesRoues(car, root)
	local groupes, ordre = {}, {}
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			local a, cle = p.Parent, nil
			while a and a ~= car do
				if a:IsA("Model") and estRoue(a.Name) then cle = a.Name end
				a = a.Parent
			end
			if not cle and estRoue(p.Name) then cle = (p.Name:gsub("[_%s%-]*%d+$", "")) end
			if cle then
				if not groupes[cle] then groupes[cle] = {}; table.insert(ordre, cle) end
				table.insert(groupes[cle], p)
			end
		end
	end
	return groupes, ordre
end

local poserRoues                     -- (definie plus bas ; declaree ici pour preparerVoiture)
local function preparerVoiture(car, root)
	local V = Voitures[car]
	if V and V.root == root then return V end
	V = { root = root, car = car, roues = {}, angle = 0, vitesse = 0, enTrajet = false }
	local groupes, ordre = groupesRoues(car, root)
	if #ordre == 0 then groupes, ordre = rouesParGeometrie(car, root) end
	local rootCF = root.CFrame
	-- v54 : gabarit pour le roulis du derapage (pivot sur les roues exterieures, au sol)
	do
		local okB, cfB, taille = pcall(function() return car:GetBoundingBox() end)
		if okB then
			V.demiLargeur = taille.X / 2 - 0.6
			V.hauteurSol = rootCF.Position.Y - (cfB.Position.Y - taille.Y / 2)
		else
			V.demiLargeur, V.hauteurSol = 4, 2.5
		end
	end
	V.derive, V.roulis = 0, 0
	local estDansRoue = {}
	for _, cle in ipairs(ordre) do
		local parts = groupes[cle]
		-- v56 : l'axe de rotation passe par le centre du PNEU (la plus grande piece du groupe), pas par la moyenne des pieces :
		-- un enjoliveur decale faisait tourner la roue autour d'un point excentre (roue qui "danse")
		local plusGrande, rayon = nil, 0
		for _, p in ipairs(parts) do
			local r = math.max(p.Size.X, p.Size.Y, p.Size.Z) / 2
			if r > rayon then rayon = r; plusGrande = p end
		end
		local centre = rootCF:PointToObjectSpace((plusGrande or parts[1]).Position)
		local roue = { parts = {}, centre = centre, rayon = math.max(rayon, 0.4) }
		for _, p in ipairs(parts) do
			p.Anchored = true                                 -- local : la roue n'est plus tiree par la soudure, on la pose nous-memes
			estDansRoue[p] = true
			table.insert(roue.parts, { part = p, offset = rootCF:ToObjectSpace(p.CFrame) })
		end
		table.insert(V.roues, roue)
	end
	-- v56 : la CARROSSERIE aussi est posee par le script, dans la MEME image que les roues. Avant, elle suivait le Root par
	-- soudure (assemblage deplace par le moteur physique, une image apres), et les roues, posees directement, avancaient et
	-- reculaient de 1 a 2 studs par rapport aux passages de roue ("roues mal fixees au chassis", video de Thomas du 05/10).
	V.corps = {}
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root and not estDansRoue[p] then
			p.Anchored = true
			table.insert(V.corps, { part = p, offset = rootCF:ToObjectSpace(p.CFrame) })
		end
	end
	Voitures[car] = V
	-- v56 : ROUES FANTOMES : les roues sont ancrees localement et ne sont posees que pendant un trajet. Quand le serveur
	-- TELEPORTE la voiture (fin du cycle de la station : PivotTo vers la sortie, le temps que le client paie a la caisse), la
	-- carrosserie bougeait et les roues restaient dans la station. On les repose a chaque changement de CFrame du Root hors trajet.
	root:GetPropertyChangedSignal("CFrame"):Connect(function()
		if not V.enTrajet and Voitures[car] == V then poserRoues(V) end
	end)
	poserRoues(V)
	car.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			if V.son then V.son:Destroy() end
			if V.tween then V.tween:Cancel() end
			Voitures[car] = nil
		end
	end)
	return V
end

-- pose la carrosserie puis les roues par rapport au Root (roues tournees de V.angle autour de l'axe lateral, X du Root)
poserRoues = function(V)
	local rootCF = V.root.CFrame
	for _, e in ipairs(V.corps or {}) do
		if e.part.Parent then e.part.CFrame = rootCF * e.offset end
	end
	for _, roue in ipairs(V.roues) do
		local rot = CFrame.new(roue.centre) * CFrame.Angles(V.angle, 0, 0) * CFrame.new(-roue.centre)
		for _, e in ipairs(roue.parts) do
			if e.part.Parent then e.part.CFrame = rootCF * rot * e.offset end
		end
	end
end

local function avancerRoues(V, distance)
	if distance <= 0 then poserRoues(V) return end            -- v56 : la carrosserie est posee meme a l'arret (derive / roulis)
	if #V.roues == 0 then poserRoues(V) return end
	-- en roulant vers l'avant (-Z du Root), le dessus de la roue part vers l'avant : rotation negative autour de +X
	V.angle -= distance / V.roues[1].rayon
	if V.angle < -math.pi * 2 then V.angle += math.pi * 2 end
	poserRoues(V)
end

local function moteur(V)
	if SON_MOTEUR.id == "" then return nil end
	if V.son and V.son.Parent then return V.son end
	local s = Instance.new("Sound")
	s.Name = "Moteur"
	-- v56 : son de ralenti propre au modele (Epique et plus) si son identifiant est renseigne, sinon le generique
	local propre = V.car and sonsDe(V.car)
	V.sons = propre
	if propre and propre.Ralenti then
		s.SoundId = propre.Ralenti
		V.hauteurArret, V.hauteurRoute = propre.Hauteur, propre.Hauteur * 1.45
	else
		s.SoundId = SON_MOTEUR.id
		V.hauteurArret, V.hauteurRoute = SON_MOTEUR.hauteurArret, SON_MOTEUR.hauteurRoute
	end
	s.Looped = true
	s.Volume = SON_MOTEUR.volume * 0.5
	s.PlaybackSpeed = V.hauteurArret
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = SON_MOTEUR.porteeMin
	s.RollOffMaxDistance = SON_MOTEUR.porteeMax
	s.Parent = V.root
	s:Play()
	V.son = s
	return s
end

-- le moteur suit la vitesse (lissage) ; boucle legere : seulement les voitures qui ont un son
RunService.Heartbeat:Connect(function(dt)
	local k = math.min(1, dt * 4)
	for car, V in pairs(Voitures) do
		local s = V.son
		if s and s.Parent then
			local cible = V.enTrajet and math.clamp(V.vitesse / VITESSE_CROISIERE, 0, 1.6) or 0
			local hA, hR = V.hauteurArret or SON_MOTEUR.hauteurArret, V.hauteurRoute or SON_MOTEUR.hauteurRoute
			local hauteur = hA + (hR - hA) * cible
			local volume = SON_MOTEUR.volume * (0.5 + 0.5 * math.min(cible, 1))
			s.PlaybackSpeed += (hauteur - s.PlaybackSpeed) * k
			s.Volume += (volume - s.Volume) * k
		end
	end
end)

-- ======================================================================================================================
-- VOITURES : trajet
-- ======================================================================================================================
local function CalculerBezierCubique(t, p0, controle1, controle2, p2)
	local u = 1 - t
	return u^3 * p0 + 3 * u^2 * t * controle1 + 3 * u * t^2 * controle2 + t^3 * p2
end

local function CalculerDirectionCubique(t, p0, controle1, controle2, p2)
	local u = 1 - t
	return 3 * u^2 * (controle1 - p0) + 6 * u * t * (controle2 - controle1) + 3 * t^2 * (p2 - controle2)
end

-- ======================================================================================================================
-- DERAPAGE (etat 4, camion de livraison v49 / v54) : survirage (le nez pointe vers l'interieur du virage, la voiture glisse
-- le long de sa trajectoire) + roulis sur deux roues + fumee des pneus arriere. v54 : l'angle et le roulis sont des ETATS
-- continus de la voiture (lisses d'une image a l'autre, d'un segment a l'autre) : plus d'a-coup a chaque noeud ; ils
-- montent au debut du derapage, restent tant qu'il dure, et redescendent en douceur quand il s'arrete.
-- ======================================================================================================================
local DERAPAGE_ANGLE = math.rad(30)
local ROULIS_ANGLE = math.rad(16)          -- deux roues : inclinaison du vehicule vers l'exterieur du virage
local VITESSE_DERIVE = 2.2                 -- 1/s : rapidite d'approche de l'angle de derive
local VITESSE_ROULIS = 1.6                 -- 1/s : rapidite d'approche du roulis
-- applique derive + roulis a un CFrame de route (le roulis pivote sur les roues exterieures, au sol)
local function appliquerDerapage(V, cf)
	if math.abs(V.derive) < 1e-3 and math.abs(V.roulis) < 1e-3 then return cf end
	cf = cf * CFrame.Angles(0, V.derive, 0)
	if math.abs(V.roulis) > 1e-3 then
		-- roulis positif (rotation +Z) = le cote droit (+X) monte : pivot sur les roues gauches (-X), et inversement
		local cote = (V.roulis > 0) and -1 or 1
		local pivot = Vector3.new(cote * (V.demiLargeur or 4), -(V.hauteurSol or 2.5), 0)
		cf = cf * CFrame.new(pivot) * CFrame.Angles(0, 0, V.roulis) * CFrame.new(-pivot)
	end
	return cf
end
local function fumee(V, actif)
	if actif and not V.fumee then
		local root = V.root
		local car = root.Parent
		local _, taille = car:GetBoundingBox()
		local arriere = taille.Z / 2 - 2
		local liste = {}
		for _, x in ipairs({-taille.X / 2 + 1, taille.X / 2 - 1}) do
			local a = Instance.new("Attachment")
			a.Name = "Derapage"; a.Position = Vector3.new(x, 0.3, arriere); a.Parent = root
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1)})
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7)})
			e.Lifetime = NumberRange.new(0.6, 1.1); e.Rate = 45; e.Speed = NumberRange.new(2, 5)
			e.SpreadAngle = Vector2.new(35, 35); e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-60, 60)
			e.LightEmission = 0.1; e.EmissionDirection = Enum.NormalId.Back; e.Parent = a
			table.insert(liste, a)
		end
		V.fumee = liste
	elseif not actif and V.fumee then
		for _, a in ipairs(V.fumee) do
			for _, e in ipairs(a:GetChildren()) do if e:IsA("ParticleEmitter") then e.Enabled = false end end
			task.delay(1.5, function() a:Destroy() end)
		end
		V.fumee = nil
	end
end

-- ======================================================================================================================
-- v55 : TRAJET CONTINU (CarManager.AnimationTrajetCar) : une liste de segments { cf, duree, v0, v1, etat } jouee d'une
-- traite : courbes de Bezier bout a bout (tangentes = caps des noeuds, poignees d'un tiers de corde), vitesse continue
-- (acceleration uniforme sur chaque segment entre v0 et v1), derapage continu, roues. Plus aucun arret entre deux noeuds.
-- ======================================================================================================================
local function arreterTrajet(V)
	if V.trajetConn then V.trajetConn:Disconnect(); V.trajetConn = nil end
	V.trajet = nil
end

-- v56 : RUGISSEMENT : la voiture achetee au centre file vers le plot (CarAmbiance pose l'attribut "Rugissement" le temps du
-- trajet) : son d'acceleration du modele, une fois, par-dessus le ralenti
local function rugir(V)
	local car = V.car
	if not (car and car:GetAttribute("Rugissement") == true) then return end
	if V.rugit and V.rugit.Parent then return end
	local S = V.sons or (car and sonsDe(car))
	if not (S and S.Acceleration) then return end
	local s = Instance.new("Sound"); s.Name = "Rugissement"; s.SoundId = S.Acceleration; s.Volume = S.Volume or 0.8
	s.PlaybackSpeed = 1; s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = 30; s.RollOffMaxDistance = 320
	s.Parent = V.root; s:Play(); V.rugit = s
	s.Ended:Once(function() if V.rugit == s then V.rugit = nil end; s:Destroy() end)
end

local function jouerTrajet(car, root, V, segs, etatFinal)
	arreterTrajet(V)
	if V.tween then V.tween:Cancel(); V.tween = nil end
	rugir(V)
	-- geometrie de chaque segment depuis la position courante
	local prevCF = root.CFrame
	local liste = {}
	local total = 0
	for _, sgm in ipairs(segs) do
		local cf = sgm.cf
		local p0, p2 = prevCF.Position, cf.Position
		local k = (p2 - p0).Magnitude / 3
		local e = {
			cf = cf, p0 = p0, p2 = p2, c1 = p0 + prevCF.LookVector * k, c2 = p2 - cf.LookVector * k,
			duree = math.max(sgm.duree or 0.05, 0.02), v0 = sgm.v0 or 0, v1 = sgm.v1 or 0, etat = sgm.etat or 0,
			debut = total,
		}
		-- longueur d'arc approchee
		local L, pr = 0, p0
		for j = 1, 12 do
			local t = j / 12
			local pt = CalculerBezierCubique(t, e.p0, e.c1, e.c2, e.p2)
			L += (pt - pr).Magnitude; pr = pt
		end
		e.L = math.max(L, 0.01)
		total += e.duree
		table.insert(liste, e)
		prevCF = cf
	end
	if #liste == 0 then return end
	local T = { segs = liste, total = total, t0 = os.clock(), i = 1, precedent = root.CFrame.Position, horloge = os.clock(), etatFinal = etatFinal }
	V.trajet = T
	V.enTrajet = true
	moteur(V)
	V.trajetConn = RunService.RenderStepped:Connect(function()
		if not (root.Parent and car.Parent) then arreterTrajet(V) return end
		local maintenant = os.clock()
		local t = maintenant - T.t0
		local dt = maintenant - T.horloge; T.horloge = maintenant
		-- segment courant
		while T.i < #T.segs and t >= T.segs[T.i].debut + T.segs[T.i].duree do T.i += 1 end
		local e = T.segs[T.i]
		local tau = math.clamp(t - e.debut, 0, e.duree)
		-- distance parcourue sur le segment : acceleration uniforme de v0 a v1 sur la duree
		local va, vb = math.max(e.v0, 4), math.max(e.v1, 4)        -- v56 : meme profil que le serveur (CarManager : vb = max(v, 4))
		local sMax = (va + vb) / 2 * e.duree
		local sv = va * tau + (vb - va) * tau * tau / (2 * e.duree)
		local u = (sMax > 0) and math.clamp(sv / sMax, 0, 1) or 1
		local fin = (T.i == #T.segs) and t >= e.debut + e.duree
		if fin then u = 1 end
		local position = CalculerBezierCubique(u, e.p0, e.c1, e.c2, e.p2)
		local direction = CalculerDirectionCubique(u, e.p0, e.c1, e.c2, e.p2)
		if direction.Magnitude < 0.001 then direction = e.cf.LookVector end
		-- derapage continu (etat 4 sur le segment)
		local derapage = (e.etat == 4)
		fumee(V, derapage)
		local sens = V.sensDerapage or 1
		if derapage then
			local d1 = e.cf.LookVector
			local c = direction.X * d1.Z - direction.Z * d1.X
			if math.abs(c) > 0.05 then sens = (c > 0) and 1 or -1 end
			V.sensDerapage = sens
		end
		local cibleDerive = derapage and (DERAPAGE_ANGLE * sens) or 0
		local cibleRoulis = derapage and (-ROULIS_ANGLE * sens) or 0
		local kd, kr = math.min(1, math.max(dt, 0) * VITESSE_DERIVE), math.min(1, math.max(dt, 0) * VITESSE_ROULIS)
		V.derive += (cibleDerive - V.derive) * kd
		V.roulis += (cibleRoulis - V.roulis) * kr
		root.CFrame = appliquerDerapage(V, fin and e.cf or CFrame.lookAt(position, position + direction))
		local distance = (position - T.precedent).Magnitude
		if dt > 0 then V.vitesse = distance / dt end
		T.precedent = position
		avancerRoues(V, distance)
		if fin then
			arreterTrajet(V)
			fumee(V, false)
			V.enTrajet = false
			V.vitesse = 0
		end
	end)
end

MoveCarEvent.OnClientEvent:Connect(function(car, cible, duree, etatanimation)
	if not car or not car.PrimaryPart then return end

	local root = car.PrimaryPart
	local V = preparerVoiture(car, root)
	if typeof(cible) == "table" then jouerTrajet(car, root, V, cible, etatanimation) return end
	arreterTrajet(V)
	if V.tween then V.tween:Cancel(); V.tween = nil end
	moteur(V)
	local derapage = (etatanimation == 4)
	fumee(V, derapage)
	-- sens du virage : vers la gauche (+) ou la droite (-) ; le nez tourne du meme cote (survirage)
	local sens = 0
	if derapage then
		local d0, d1 = root.CFrame.LookVector, cible.LookVector
		local c = d0.X * d1.Z - d0.Z * d1.X
		sens = (c > 0) and 1 or -1
		if math.abs(c) < 0.05 then sens = (V.sensDerapage or 1) end
		V.sensDerapage = sens
	end

	local style = Enum.EasingStyle.Linear
	if etatanimation == 1 or etatanimation == 2 then
		style = Enum.EasingStyle.Sine
	end
	local tweenInfo = TweenInfo.new(duree, style, Enum.EasingDirection.Out)

	local depart = root.CFrame
	local p0 = depart.Position
	local p2 = cible.Position

	local k = (p2 - p0).Magnitude * 0.39
	local controle1 = p0 + depart.LookVector * k   -- devant la voiture
	local controle2 = p2 - cible.LookVector * k    -- derriere le node d'arrivee

	local t = Instance.new("NumberValue")
	t.Value = 0
	local precedent = p0
	local horloge = os.clock()
	V.enTrajet = true

	local connection
	connection = t.Changed:Connect(function(valeur)
		local position = CalculerBezierCubique(valeur, p0, controle1, controle2, p2)
		local direction = CalculerDirectionCubique(valeur, p0, controle1, controle2, p2)

		local distance = (position - precedent).Magnitude
		local maintenant = os.clock()
		local dt = maintenant - horloge
		-- derive et roulis : etats continus (v54)
		local cibleDerive = derapage and (DERAPAGE_ANGLE * sens) or 0
		local cibleRoulis = derapage and (-ROULIS_ANGLE * sens) or 0           -- le vehicule penche vers l'exterieur
		local kd, kr = math.min(1, math.max(dt, 0) * VITESSE_DERIVE), math.min(1, math.max(dt, 0) * VITESSE_ROULIS)
		V.derive += (cibleDerive - V.derive) * kd
		V.roulis += (cibleRoulis - V.roulis) * kr
		if direction.Magnitude > 0.001 then
			root.CFrame = appliquerDerapage(V, CFrame.lookAt(position, position + direction))
		end
		if dt > 0 then V.vitesse = distance / dt end
		horloge = maintenant
		precedent = position
		avancerRoues(V, distance)
	end)

	local tween = TweenService:Create(t, tweenInfo, {Value = 1})
	V.tween = tween
	tween:Play()

	tween.Completed:Once(function(etat)
		connection:Disconnect()
		t:Destroy()
		if V.tween == tween then V.tween = nil end
		if etat == Enum.PlaybackState.Completed then
			root.CFrame = appliquerDerapage(V, cible)        -- v54 : pas de saut : la derive / le roulis en cours restent
			poserRoues(V)
		end
		if derapage and etat ~= Enum.PlaybackState.Cancelled then fumee(V, false) end
		V.enTrajet = false
		V.vitesse = 0
	end)
end)
