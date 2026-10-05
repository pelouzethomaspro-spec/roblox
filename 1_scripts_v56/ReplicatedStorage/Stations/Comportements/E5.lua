--[[ Comportement E5 (changement de roues) : roues tenues par les bras, roues neuves dans les racks, sons
	Les bras et la voiture sont animes. Ici on ne fait que CHANGER LA PIECE A LAQUELLE CHAQUE ROUE EST SOUDEE,
	a des instants fixes du cycle :
		sur la voiture -> dans la pince (extraction) -> dans le rack (depose) -> dans la pince (prise) -> sur la voiture
	Les positions relatives (roue dans la pince, places dans le rack) ont ete enregistrees avec l'animation.
	Un segment d'animation par modele connu ; un modele inconnu prend le segment du modele le plus proche
	(empattement), legerement mis a l'echelle.
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)

local E5 = {}
E5.__index = E5
local S = Sons.CATALOGUE
local EMPATTEMENT_MAXI = 9.8    -- voiture plus longue entre les roues : legerement reduite (portee des bras)
local RAYON_ROUE_MAXI = 1.25    -- roues plus grandes : voiture legerement reduite (place dans le rack)
local DUREE_VISSEUSE = 0.7
local RAPIDE_ARRIVEE = 2.5
local MOUVEMENTS = {prepa = 1, survol = 1, approche = 1, contact = 1, extraction = 1, rangement = 1, demitourA = 1,
	demitourB = 1, versrack = 1, demitourR = 1, deposeApp = 1, depose = 1, degagement = 1, versNeuf = 1, prise = 1,
	retrait = 1, rangement2 = 1, demitourR2 = 1, retour = 1, demitour2A = 1, demitour2B = 1, approche2 = 1,
	montage = 1, degagement2 = 1, survol2 = 1, prepa2 = 1, repos = 1}

function E5.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, E5)
	-- horaires des etapes (identiques pour toutes les voitures)
	self.T0, self.IDX, self.NOMS, self.DUREES = {}, {}, {}, {}
	local t = 0
	for i, e in ipairs(st.D.ETAPES) do
		self.T0[i], self.IDX[e[1]], self.NOMS[i], self.DUREES[i] = t, i, e[1], e[2]
		t += e[2]
	end
	local c = st:piece("E5_Pneus_Mob_Verins2")
	self.snd = {
		bras = Sons.relais(S.servo, c, 0.45),
		visseuse = Sons.creer(S.visseuse, c, 0.9, false),
		verins = Sons.creer(S.pompe, c, 0.7, true),
		pince = Sons.creer(S.clac, c, 0.8, false),
		bip = Sons.creer(S.bip, c, 0.8, false),
		rotation = Sons.creer(S.servoRotation, c, 0.7, false),
	}
	local liste = self.snd.bras:liste()
	for _, s in pairs(self.snd) do if typeof(s) == "Instance" then table.insert(liste, s) end end
	Sons.precharger(liste)
	return self
end

-- voiture hors gabarit : legerement reduite
function E5:ajuster(C)
	local r = 0
	for _, roue in ipairs(C.roues) do r = math.max(r, roue.rayon) end
	return math.min(1, EMPATTEMENT_MAXI / math.max(1, C.essieux[1] - C.essieux[2]), RAYON_ROUE_MAXI / math.max(r, 0.1))
end

local function empattement(seg)
	local R = seg.roues
	return ((R.AVG or R.AVD).c[2] - (R.ARG or R.ARD).c[2])
end

-- segment du modele, sinon celui du modele le plus proche
function E5:choisirSegment(C)
	for _, s in ipairs(self.D.SEGMENTS) do if s.nom == C.modele then return s end end
	local e = C.essieux[1] - C.essieux[2]
	local best, db = self.D.SEGMENTS[1], math.huge
	for _, s in ipairs(self.D.SEGMENTS) do
		local d = math.abs(empattement(s) - e)
		if d < db then best, db = s, d end
	end
	return best
end
function E5:echelleSegment(C, seg)
	if seg.nom == C.modele then return nil end
	return math.clamp(empattement(seg) / math.max(1, C.essieux[1] - C.essieux[2]), 0.8, 1.2)
end

------------------------------------------------------------------
-- soudures des roues
------------------------------------------------------------------
local function souder(part, p0, c0)
	local w = Instance.new("Weld")
	w.Name = "SoudureStation"
	w.Part0, w.Part1, w.C0 = p0, part, c0
	w.Parent = part
	return w
end

function E5:debut(cy)
	local st, P, C = self.st, cy.seg.piste, cy.C
	self.roues = {}
	self.dossier = Instance.new("Folder"); self.dossier.Name = "RouesNeuves"; self.dossier.Parent = C.voiture
	for place, info in pairs(P.roues) do
		local r = C.parPlace[place]
		if r and r.soudures then
			local poignet = st:piece(("E5_Pneus_Mob_Robot%s_Poignet"):format(info.robot))
			local e = {r = r, poignet = poignet, etat = "voiture",
				G = st.rep.MAP * Outils.cf(info.G), Hpose = Outils.cf(info.Hpose), Hprise = Outils.cf(info.Hprise), neuves = {}}
			e.poiRepos = poignet:GetAttribute("Repos") or poignet.CFrame
			-- roue neuve dans le rack : copie des pieces de la roue
			for i, p in ipairs(r.parts) do
				local c = p:Clone()
				for _, d in ipairs(c:GetDescendants()) do if d:IsA("JointInstance") then d:Destroy() end end
				c.Anchored = false
				c.Parent = self.dossier
				e.neuves[i] = souder(c, st.socle, e.Hprise * r.relatif[i])
			end
			e.neuveEtat = "prise"
			self.roues[place] = e
		end
	end
	self.kPrec, self.tVis, self.tFinRot = nil, nil, nil
end

-- etat de chaque roue a l'instant tc (sans memoire)
function E5:etatRoue(tc)
	local T0, I = self.T0, self.IDX
	if tc >= T0[I.extraction] and tc < T0[I.degagement] then return "tenue" end
	if tc >= T0[I.degagement] and tc < T0[I.retrait] then return "rack" end
	if tc >= T0[I.retrait] and tc < T0[I.degagement2] then return "tenue" end
	return "voiture"
end

function E5:appliquerRoues(tc)
	local etat = self:etatRoue(tc)
	local neuve = (tc < self.T0[self.IDX.retrait]) and "prise" or "pose"
	for place, e in pairs(self.roues) do
		if e.etat ~= etat then
			e.etat = etat
			local r = e.r
			for i, w in ipairs(r.soudures) do
				if etat == "voiture" then w.Part0, w.C0 = self.st.roues[place], r.relatif[i]
				elseif etat == "tenue" then w.Part0, w.C0 = e.poignet, e.poiRepos:Inverse() * e.G * r.relatif[i]
				else w.Part0, w.C0 = self.st.socle, e.Hpose * r.relatif[i] end
			end
		end
		if e.neuveEtat ~= neuve then
			e.neuveEtat = neuve
			local H = (neuve == "prise") and e.Hprise or e.Hpose
			for i, w in ipairs(e.neuves) do w.C0 = H * e.r.relatif[i] end
		end
	end
end

function E5:maj(cy, tc, dt)
	if cy.C then self:appliquerRoues(tc) end
	-- sons : un bruit de moteur par mouvement des bras, visseuse, verins, pince, bips
	local P, snd, T0, I = cy.seg.piste, self.snd, self.T0, self.IDX
	local k = 1
	for i = #T0, 1, -1 do if tc >= T0[i] then k = i break end end
	if k ~= self.kPrec then
		local nom, d = self.NOMS[k], self.DUREES[k]
		if k == I.levage or k == I.depart then Sons.coup(snd.bip) end
		if k == I.extraction or k == I.degagement or k == I.retrait or k == I.degagement2 then Sons.coup(snd.pince) end
		if k == I.devissage or k == I.vissage then Sons.coup(snd.visseuse); self.tVis = tc end
		if snd.rotation and table.find(P.tourne, k) then
			snd.rotation.Volume = 0.7 * Sons.VOLUME
			Sons.etirer(snd.rotation, d)
			self.tFinRot = T0[k] + d
		end
		local repli = P.haute and (nom == "arrivee" or nom == "pause")
		if MOUVEMENTS[nom] or repli then
			local dm = (nom == "arrivee") and d / RAPIDE_ARRIVEE or d
			snd.bras:mouvement(dm, T0[k] + dm)
		else
			snd.bras:arret()
		end
	end
	self.kPrec = k
	snd.bras:maj(tc, dt, 1)
	if snd.rotation and self.tFinRot then
		local reste = self.tFinRot - tc
		if reste > 0.15 and not snd.rotation.IsPlaying then Sons.coup(snd.rotation) end
		if reste <= 0 then snd.rotation:Stop(); self.tFinRot = nil end
	end
	Sons.jouer(snd.verins, k == I.levage or k == I.descente)
	if self.tVis and tc - self.tVis > DUREE_VISSEUSE then Sons.jouer(snd.visseuse, false); self.tVis = nil end
end

function E5:fin(cy)
	self.snd.bras:couper()
	for _, s in ipairs({self.snd.verins, self.snd.visseuse, self.snd.rotation}) do Sons.jouer(s, false) end
	if self.dossier then self.dossier:Destroy(); self.dossier = nil end
	self.roues = {}
end

return E5
