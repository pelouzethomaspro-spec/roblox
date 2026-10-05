--[[ Comportement Chaine (chaine de production de voitures, decor)
	Tout le mouvement vient de l'animation "ChaineProduction" (robots, scanner, ascenseur, et 7 pieces invisibles
	Voiture_0..6 = la voiture de chaque poste). Ce module, chez chaque joueur :
		- garde 7 copies de la voiture (une par poste) : a chaque cycle la plus ancienne (sortie) est detruite, une
		  neuve apparait dans l'usine, les autres passent au poste suivant (on change juste la piece a laquelle elles
		  sont soudees) ;
		- deplace les pieces de la voiture selon l'horaire des robots : piece en stock -> dans l'outil du robot ->
		  sur la voiture (vitres, phares, feux, 4 roues) ; une piece pas encore posee est cachee ;
		- peint la carrosserie (appret gris -> couleur) dans la cabine, fait disparaitre la voiture dans le portail ;
		- sons et effets : jets de peinture, moteurs des robots, visseuses, tapis, ascenseur, scanner, bip de controle.
	La copie de la voiture est soudee avec sa position dans le repere canonique de la voiture (centre au sol, Y avant).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)
local Voiture = require(Stations.Voiture)

local Chaine = {}
Chaine.__index = Chaine
local S = Sons.CATALOGUE
local V = Outils.V
local COULEURS = {
	Color3.fromRGB(200, 22, 32),  Color3.fromRGB(24, 82, 196),  Color3.fromRGB(18, 140, 70),  Color3.fromRGB(242, 190, 24),
	Color3.fromRGB(240, 108, 22), Color3.fromRGB(24, 24, 28),   Color3.fromRGB(236, 236, 236), Color3.fromRGB(122, 128, 136),
	Color3.fromRGB(112, 40, 164), Color3.fromRGB(222, 72, 144), Color3.fromRGB(20, 160, 172), Color3.fromRGB(112, 16, 30),
}
local APPRET = Color3.fromRGB(150, 152, 156)
local ROUES = {roue_AVG = "AVG", roue_AVD = "AVD", roue_ARG = "ARG", roue_ARD = "ARD"}

local function dans(liste, t)
	for _, e in ipairs(liste) do if t >= e[1] and t < e[2] then return e end end
	return nil
end

------------------------------------------------------------------
-- creation : pieces animees, palettes, effets, sons
------------------------------------------------------------------
local function piecePalette(parent, nom, taille, c, couleur, materiau)
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.Color = couleur
	p.Material = materiau or Enum.Material.Metal
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
	p.Anchored = false
	p.CFrame = parent.CFrame * CFrame.new(c)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = parent, p, CFrame.new(c)
	w.Parent = p
	return p
end

function Chaine:palette(place)
	local P, M = self.D.PALETTE, self.D.CALES or self.D.MOYEUX
	local m = Instance.new("Model"); m.Name = "Palette"
	local parts = {}
	local z = P.z - P.epais / 2
	table.insert(parts, piecePalette(place, "Plaque", Vector3.new(P.large, P.long, P.epais), Vector3.new(0, 0, z), Color3.fromRGB(58, 60, 66), Enum.Material.DiamondPlate))
	for _, s in ipairs({-1, 1}) do
		table.insert(parts, piecePalette(place, "Bord", Vector3.new(0.3 * P.large / 5.6, P.long, P.epais + 0.04), Vector3.new(s * (P.large / 2 - 0.15 * P.large / 5.6), 0, z), Color3.fromRGB(242, 190, 24), Enum.Material.SmoothPlastic))
	end
	for _, c in pairs(M) do                                           -- cales sous les roues
		local T = self.D.CALE or {1.8, 2.6}
		table.insert(parts, piecePalette(place, "Cale", Vector3.new(T[1], T[2], -P.z), Vector3.new(c[1], c[2], P.z / 2), Color3.fromRGB(30, 30, 34), Enum.Material.Rubber))
	end
	for _, p in ipairs(parts) do p.Parent = m end
	m.Parent = self.dossier
	return parts
end

local function idValide(id) return type(id) == "string" and id ~= "" and not id:match("://0*$") end
function Chaine:chargerPiste(nom)
	local Reglages = require(Stations.Reglages)
	local id = Reglages.ANIMATIONS and Reglages.ANIMATIONS[nom]
	if not idValide(id) then
		id = nil
		local test = ReplicatedStorage:FindFirstChild("AnimationsTest_ASupprimer")
		local kfs = test and test:FindFirstChild(nom)
		if kfs and game:GetService("RunService"):IsStudio() then
			local ok, r = pcall(function() return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs) end)
			if ok then id = r end
		end
	end
	if not id then
		warn(("Chaine de production : pas d'ID d'animation pour %s (Stations > Reglages > ANIMATIONS) : ce poste reste immobile"):format(nom))
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local tr = self.st.animator:LoadAnimation(anim)
	tr.Looped = false
	tr.Priority = Enum.AnimationPriority.Action
	return tr
end

-- voiture numero id -> nombre pseudo-aleatoire (identique chez tous les joueurs) : modele et couleur tires au hasard
local function hachage(i)
	local h = i % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16)); h = (h * 40507) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13)); h = (h * 48271) % 4294967296
	return bit32.bxor(h, bit32.rshift(h, 16))
end
function Chaine:modeleDe(id)
	local L = self.D.VOITURES
	return L[hachage(id) % #L + 1]
end

-- v56 : reecriture des translations de Transform (x ECHELLE_ANIM) ; appelee au montage et a chaque reveil
function Chaine:brancherEchelle()
	if self.connEchelle or not self.echelleAnim or #(self.moteursEchelle or {}) == 0 then return end
	local s, moteurs = self.echelleAnim, self.moteursEchelle
	self.connEchelle = RunService.Stepped:Connect(function()
		for _, m in ipairs(moteurs) do
			local t = m.Transform
			local pos = t.Position
			if pos.Magnitude > 1e-4 then m.Transform = (t - pos) + pos * s end
		end
	end)
end

function Chaine.nouveau(st)
	local D, rep = st.D, st.rep
	local self = setmetatable({st = st, D = D, rep = rep, E = D.EVENEMENTS, voitures = {}, signale = {}}, Chaine)
	self.places = {}
	for k = 0, 6 do self.places[k] = st:piece("Voiture_" .. k) end
	self.moyeux, self.motMoyeux = {}, {}
	for pl in pairs(D.MOYEUX) do
		local m = st:piece("Roue_" .. pl .. "_6")
		self.moyeux[pl] = m
		self.motMoyeux[pl] = m and m:FindFirstChild("Articulation")
	end
	-- pour chaque voiture : groupe de chaque piece (vitres, phares...), soudure de chaque groupe (stock, prise, horaires)
	self.groupeDe, self.soud = {}, {}
	for m, M in pairs(D.MODELES) do
		self.groupeDe[m], self.soud[m] = {}, {}
		for g, noms in pairs(M.PIECES) do for _, n in ipairs(noms) do self.groupeDe[m][n] = g end end
		for _, s in ipairs(M.SOUDURES) do
			local outil = st:piece(s.outil)
			self.soud[m][s.piece] = {s = s, outil = outil, repos = outil and (outil:GetAttribute("Repos") or outil.CFrame), G = Outils.cf(s.G), stock = Outils.cf(s.stock)}
		end
	end
	-- pistes : une animation par poste (un morceau par voiture) ; chaque poste joue le morceau de la voiture qu'il a devant lui
	self.pistes = {}
	for _, p in ipairs(D.PISTES or {}) do
		table.insert(self.pistes, {nom = p.nom, k = p.k, debuts = p.debuts, track = self:chargerPiste(p.nom)})
	end
	self.dossier = Instance.new("Folder"); self.dossier.Name = "ChaineProduction_Voitures"; self.dossier.Parent = workspace
	self.palettes = {}
	for k = 0, 5 do self:palette(self.places[k]) end
	self.palette6 = self:palette(st:piece("Palette_6"))
	-- v55 : les animations publiees (ChaineTapis, ChaineSortie) ont ete faites sur la chaine M4_3 (gabarit 36) ; la chaine
	-- M4_9 de la map est 22/36 plus petite (Donnees.ECHELLE_ANIM). Les ROTATIONS des robots ne changent pas, mais les
	-- TRANSLATIONS (tapis : voitures et palettes, scanner, ascenseur, sortie) doivent etre reduites d'autant : on reecrit
	-- la translation de Transform juste apres l'animateur (Stepped), sinon les voitures traversent les murs du hall.
	-- v56 : la connexion est RETABLIE a chaque reveil (debut) : arreter() la coupait quand le joueur s'eloignait et elle
	-- n'etait jamais refaite au retour (les voitures retraversaient les murs).
	local echelle = D.ECHELLE_ANIM
	self.moteursEchelle = {}
	if echelle and math.abs(echelle - 1) > 1e-3 then
		self.echelleAnim = echelle
		for _, nom in ipairs({"Voiture_0", "Voiture_1", "Voiture_2", "Voiture_3", "Voiture_4", "Voiture_5", "Voiture_6", "Palette_6", "CP_Mob_Scanner", "CP_Mob_Ascenseur"}) do
			local p = st:piece(nom)
			local m = p and p:FindFirstChild("Articulation")
			if m then table.insert(self.moteursEchelle, m) end
		end
	end
	self:brancherEchelle()

	-- robots : moteur (un bruit par mouvement), clac a la prise / pose, visseuse
	self.robots = {}
	local precharge = {}
	for nom, o in pairs(D.OUTILS) do
		local tour, outil = st:piece(o.tourelle), st:piece(o.piece)
		local R = {nom = nom, mouv = D.EVENEMENTS.mouvements[nom] or {}}
		R.relais = Sons.relais(S.servo, tour, 0.32)
		local a = rep:attache(outil, V(o.pointe), nil, "Pointe")
		R.clac = Sons.creer(S.clac, a, 0.6, false)
		R.pointe = a
		for _, s in ipairs(R.relais:liste()) do table.insert(precharge, s) end
		table.insert(precharge, R.clac)
		self.robots[nom] = R
	end
	for _, e in ipairs(D.EVENEMENTS.visseuse) do
		local R = self.robots[e[3]]
		if R and not R.visseuse then R.visseuse = Sons.creer(S.visseuse, R.pointe, 0.5, false); table.insert(precharge, R.visseuse) end
	end
	-- pistolets de peinture
	self.pistolets = {}
	for nom, b in pairs(D.BUSES) do
		local a = rep:attache(st:piece(b.piece), V(b.pos), V(b.dir), "Buse")
		local P = {jets = {Effets.emetteur(a, "jetPeinture", rep), Effets.emetteur(a, "brumePeinture", rep)}, son = Sons.creer(S.spray, a, 0.55, true),
			plages = D.EVENEMENTS.spray[nom] or {}}
		table.insert(precharge, P.son)
		self.pistolets[nom] = P
	end
	-- decor : tapis, ascenseur, scanner, voyant du controle, portail
	local socle = st.socle
	self.tapis = {}
	for i, p in ipairs(D.POINTS.tapis) do
		local s = Sons.creer(S.pompe, rep:attache(socle, V(p), nil, "Tapis" .. i), 0.35, true, 0.55)
		table.insert(self.tapis, s); table.insert(precharge, s)
	end
	self.sonAsc = Sons.creer(S.pompe, rep:attache(socle, V(D.POINTS.ascenseur), nil, "Ascenseur"), 0.6, false)
	local scan = st:piece("CP_Mob_Scanner")
	local aS = rep:attache(scan, V(D.POINTS.scanner), Vector3.new(0, 0, -1), "Scan")
	self.lumScan = Instance.new("SpotLight")
	self.lumScan.Angle = 80; self.lumScan.Range = 11 * (D.ECHELLE_VOITURE or 1); self.lumScan.Brightness = 4; self.lumScan.Color = Color3.fromRGB(150, 220, 255)
	self.lumScan.Face = Enum.NormalId.Front; self.lumScan.Shadows = false; self.lumScan.Enabled = false; self.lumScan.Parent = aS
	self.sonScan = Sons.creer(S.servoRotation, aS, 0.4, false)
	local aV = rep:attache(socle, V(D.POINTS.voyantVert), nil, "VoyantVert")
	self.lumOk = Effets.lumiere(aV, math.min(60, 12 * (D.ECHELLE_VOITURE or 1)), Color3.fromRGB(60, 255, 90))
	self.bip = Sons.creer(S.bip, aV, 0.8, false)
	self.lumPortail = {}                                                  -- tunnel de lumiere + portail exterieur
	for i, p in ipairs(D.POINTS.portails or {D.POINTS.portail}) do
		local l = Effets.lumiere(rep:attache(socle, V(p), nil, "Portail" .. i), math.min(60, 30 * (D.ECHELLE_VOITURE or 1)), Color3.fromRGB(255, 244, 222))
		l.Enabled = true
		table.insert(self.lumPortail, l)
	end
	for _, s in ipairs({self.sonAsc, self.sonScan, self.bip}) do table.insert(precharge, s) end
	Sons.precharger(precharge)
	return self
end

------------------------------------------------------------------
-- voitures
------------------------------------------------------------------
function Chaine:creerVoiture(id)
	local nomM = self:modeleDe(id)
	local dossierV = ReplicatedStorage:FindFirstChild("VoituresModeles")
	local modele = dossierV and dossierV:FindFirstChild(nomM)
	if not modele then error("ReplicatedStorage > VoituresModeles > " .. nomM .. " introuvable", 0) end
	local k = self.D.ECHELLE_VOITURE or 1                        -- voiture agrandie pour la chaine (16 studs de large)
	local C = Voiture.copier(modele, self.rep, function() return k end)
	C.voiture.Name = "V_" .. id
	C.voiture.Parent = self.dossier
	local ci = (self.rep.MAP * C.CAR0):Inverse()
	local v = {id = id, modele = nomM, C = C, pcan = {}, sw = {}, groupe = {}, etat = {}, lt = {}, centres = {}, couleur = COULEURS[hachage(id * 7 + 3) % #COULEURS + 1]}
	for _, p in ipairs(C.toutes) do
		v.pcan[p] = ci * p.CFrame                                  -- position de la piece dans le repere canonique
		v.groupe[p] = self.groupeDe[nomM][p.Name]
		local w = Instance.new("Weld"); w.Name = "SoudureChaine"; w.Part1 = p
		v.sw[p] = w
	end
	for g, pl in pairs(ROUES) do                                   -- centre de chaque roue (pivot de la rotation en sortie)
		local parts = {}
		for _, p in ipairs(C.toutes) do if v.groupe[p] == g then table.insert(parts, p) end end
		if #parts > 0 then local a, b = Voiture.boite(parts, C.CAR0, self.rep); v.centres[pl] = (a + b) / 2 end
	end
	for _, p in ipairs(C.corps) do
		if p:IsA("MeshPart") then pcall(function() p.TextureID = "" end) end
	end
	return v
end

function Chaine:detruireVoiture(v)
	if v.C and v.C.son then v.C.son:Destroy() end
	if v.C and v.C.voiture then v.C.voiture:Destroy() end
end

-- a qui est soudee chaque piece de la voiture v (au poste k, instant tc du cycle), visible ou cachee
function Chaine:placer(v, k, tc)
	local place = self.places[k]
	local fondu = 0
	if k == 6 then
		local f = self.E.fondu
		fondu = math.clamp((tc - f[1]) / (f[2] - f[1]), 0, 1)
		if k == 6 and not v.moyeuxPoses then                        -- voiture de sortie : les roues tournent autour de leur centre
			v.moyeuxPoses = true
			for pl, m in pairs(self.motMoyeux) do if m and v.centres[pl] then m.C0 = CFrame.new(v.centres[pl]) end end
		end
	end
	for p, w in pairs(v.sw) do
		local g = v.groupe[p]
		local p0, c0, cle, cache = place, v.pcan[p], k, false
		if g then
			local poste, so = self.D.POSTE[g], self.soud[v.modele][g]
			if k >= poste or (k == poste - 1 and so and tc >= so.s.tPose) then        -- posee
				local pl = ROUES[g]
				if k == 6 and pl and self.moyeux[pl] and v.centres[pl] then
					p0, c0, cle = self.moyeux[pl], CFrame.new(v.centres[pl]):Inverse() * v.pcan[p], "moyeu"
				end
			elseif k == poste - 1 and so and so.outil then
				if tc >= so.s.tPrise then                                             -- dans l'outil du robot
					p0, c0, cle = so.outil, so.repos:Inverse() * self.rep.MAP * so.G * v.pcan[p], "outil"
				else                                                                  -- en stock
					p0, c0, cle = self.st.socle, so.stock * v.pcan[p], "stock"
				end
			elseif k == poste - 2 and so and so.outil and tc >= so.s.tStock then    -- stock recharge : piece de la voiture suivante
				p0, c0, cle = self.st.socle, so.stock * v.pcan[p], "stock"
			else
				cache = true
			end
		end
		if v.etat[p] ~= cle then
			v.etat[p] = cle
			w.Part0 = p0; w.C0 = c0
			if not w.Parent then w.Parent = p end
		end
		local lt = cache and 1 or fondu
		if v.lt[p] ~= lt then v.lt[p] = lt; p.LocalTransparencyModifier = lt end
	end
	if not v.libre then                                                -- soudee partout : on peut liberer la copie
		v.libre = true
		for _, p in ipairs(v.C.toutes) do p.Anchored = false end
	end
end

function Chaine:peindre(v, k, tc)
	local col = v.couleur
	if k <= 0 then
		local a, b = self.E.peinture[1], self.E.peinture[2]
		local u = (k < 0) and 0 or math.clamp((tc - a) / (b - a), 0, 1)
		col = APPRET:Lerp(v.couleur, u)
	end
	if v.teinte ~= col then
		v.teinte = col
		for _, p in ipairs(v.C.corps) do p.Color = col end
	end
end

function Chaine:sortie(v, tc, dt)
	local C, E = v.C, self.E
	if tc >= E.sortie.pose - 0.4 and tc < E.fondu[2] then
		if not C.son then
			C.st = {voiture = self.places[6]}
			Voiture.moteur(C)
		end
		Voiture.majMoteur(C, dt)
	elseif C.son then
		C.son:Destroy(); C.son = nil
	end
end

------------------------------------------------------------------
-- cycle
------------------------------------------------------------------
function Chaine:debut(cy)
	self:brancherEchelle()                      -- v56
	local n = cy.n
	for id, v in pairs(self.voitures) do
		if id < n - 6 or id > n then self:detruireVoiture(v); self.voitures[id] = nil end
	end
	for k = 6, 0, -1 do
		local id = n - k
		if not self.voitures[id] then
			local ok, r = pcall(self.creerVoiture, self, id)
			if ok then self.voitures[id] = r
			elseif not self.signale[tostring(r)] then self.signale[tostring(r)] = true; warn("Chaine de production : " .. tostring(r)) end
		end
	end
	self.n = n
	self.tPrec = nil
	for _, P in pairs(self.pistolets) do P.couleur = nil end
end

function Chaine:maj(cy, tc, dt)
	local E, n = self.E, cy.n
	for id, v in pairs(self.voitures) do
		local k = n - id
		self:placer(v, k, tc)
		self:peindre(v, k, tc)
		if k == 6 then self:sortie(v, tc, dt) end
	end
	-- pistes des postes : morceau de la voiture presente, cale sur l'horloge commune
	for _, P in ipairs(self.pistes) do
		local tr = P.track
		if tr then
			local cible = (P.debuts[self:modeleDe(n - P.k)] or 0) + tc
			if not tr.IsPlaying then tr:Play(0, 1, 1); tr.TimePosition = cible
			elseif math.abs(tr.TimePosition - cible) > 0.12 then tr.TimePosition = cible end
		end
	end
	-- palette de sortie : cachee une fois descendue dans la fosse
	local c6 = (tc >= E.paletteCachee) and 1 or 0
	if self.c6 ~= c6 then
		self.c6 = c6
		for _, p in ipairs(self.palette6) do p.LocalTransparencyModifier = c6 end
	end
	local prec = self.tPrec or tc
	local function franchi(s) return prec < s and tc >= s end
	-- robots
	for nom, R in pairs(self.robots) do
		for _, m in ipairs(R.mouv) do
			if franchi(m[1]) then R.relais:mouvement(m[2] - m[1], m[2]) end
		end
		R.relais:maj(tc, dt, 1)
	end
	for _, e in ipairs(E.prises) do if franchi(e[1]) then Sons.coup(self.robots[e[2]].clac, 1.1) end end
	for _, e in ipairs(E.poses) do if franchi(e[1]) then Sons.coup(self.robots[e[2]].clac, 0.9) end end
	for _, e in ipairs(E.visseuse) do if franchi(e[1]) then Sons.etirer(self.robots[e[3]].visseuse, e[2] - e[1]) end end
	-- peinture : couleur de la voiture dans la cabine
	local vp = self.voitures[n]
	for _, P in pairs(self.pistolets) do
		local on = dans(P.plages, tc) ~= nil
		if vp and P.couleur ~= vp.couleur then
			P.couleur = vp.couleur
			for _, e in ipairs(P.jets) do e.Color = ColorSequence.new(vp.couleur) end
		end
		Effets.activer(P.jets, on)
		Sons.jouer(P.son, on)
	end
	-- tapis (transfert), ascenseur, scanner, controle
	local tr = tc < E.transfert[2]
	for _, s in ipairs(self.tapis) do Sons.jouer(s, tr) end
	for _, e in ipairs(E.ascenseur) do if franchi(e[1]) then Sons.etirer(self.sonAsc, e[2] - e[1]) end end
	local sc = E.scan
	self.lumScan.Enabled = (tc >= sc.aller[1] and tc < sc.aller[2]) or (tc >= sc.retour[1] and tc < sc.retour[2])
	if franchi(sc.aller[1]) then Sons.etirer(self.sonScan, sc.aller[2] - sc.aller[1]) end
	if franchi(sc.retour[1]) then Sons.etirer(self.sonScan, sc.retour[2] - sc.retour[1]) end
	if franchi(sc.ok) then Sons.coup(self.bip, 1) end
	local u = tc - sc.ok
	self.lumOk.Enabled = u >= 0 and u < 2.5
	if self.lumOk.Enabled then self.lumOk.Brightness = (u < 0.8 and math.floor(u * 8) % 2 == 0) and 0.5 or 3 end
	-- portail : la lumiere s'intensifie quand la voiture le traverse
	local f = E.fondu
	local w = math.clamp(1 - math.abs(tc - (f[1] + f[2]) / 2) / ((f[2] - f[1]) / 2 + 0.6), 0, 1)
	for _, l in ipairs(self.lumPortail) do l.Brightness = 1.5 + 5 * w end
	self.tPrec = tc
end

function Chaine:fin(cy)
	for _, P in pairs(self.pistolets) do Effets.activer(P.jets, false); Sons.jouer(P.son, false) end
end

-- station qui s'endort (joueur loin) : tout est detruit, recree au retour
function Chaine:arreter()
	for _, P in ipairs(self.pistes) do if P.track and P.track.IsPlaying then P.track:Stop(0) end end
	for id, v in pairs(self.voitures) do self:detruireVoiture(v) end
	self.voitures = {}
	for _, R in pairs(self.robots) do R.relais:couper() end
	for _, s in ipairs(self.tapis) do Sons.jouer(s, false) end
	for _, P in pairs(self.pistolets) do Effets.activer(P.jets, false); Sons.jouer(P.son, false) end
	self.lumScan.Enabled = false; self.lumOk.Enabled = false
	if self.connEchelle then self.connEchelle:Disconnect(); self.connEchelle = nil end
	-- (le dossier ChaineProduction_Voitures garde les palettes creees au montage : il n'est PAS detruit ici)
	self.n = nil
end

return Chaine
