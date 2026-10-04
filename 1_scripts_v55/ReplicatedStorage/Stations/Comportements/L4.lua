--[[ Comportement L4 (rouleaux) : eau, mousse, sons des brosses et des rouleaux contre la voiture
	Donnees par segment (piste) : segs = {{nom, t0, t1}}, eau = {{t0, t1}}, contact = {rouleau haut, gauche, droit}
	(intervalles ou le rouleau touche vraiment la voiture), T_ARRIVEE, T_DEPART.
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)

local L4 = {}
L4.__index = L4
local UP = Outils.UP
local S = Sons.CATALOGUE
local P_ = "L4_Rouleaux_Mob_"
local TOURNE = {ouverture = true, lavage = true, pause = true, rincage = true, fermeture = true}
local MOTEUR = {approche = true, lavage = true, rincage = true, retour = true}

function L4.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, L4)
	local rep, R = st.rep, st.D.ROBOT
	local CH, CG, CD = Outils.V(R.CH), Outils.V(R.CG), Outils.V(R.CD)
	self.eau, self.mousse = {}, {}
	local aH = rep:attache(st:piece(P_ .. "ChariotH"), Vector3.new(CH.X, CH.Y - 0.1, CH.Z + R.RH + 0.2), -UP, "Jets")
	table.insert(self.eau, Effets.emetteur(aH, "eauLarge", rep)); table.insert(self.mousse, Effets.emetteur(aH, "mousse", rep))
	for _, k in ipairs({"ChariotG", "ChariotD"}) do
		local c = (k == "ChariotG") and CG or CD
		local a = rep:attache(st:piece(P_ .. k), Vector3.new(c.X + 0.3, c.Y, R.ZV[2] + 0.4), -UP, "Jets")
		table.insert(self.eau, Effets.emetteur(a, "eau", rep)); table.insert(self.mousse, Effets.emetteur(a, "mousse", rep))
	end
	local portique, chH = st:piece(P_ .. "Portique"), st:piece(P_ .. "ChariotH")
	self.snd = {
		moteur = Sons.creer(S.servo, portique, 0.5, false),
		brosses = Sons.creer(S.pompe, chH, 0.25, true, 1.25),
		eau = Sons.creer(S.fontaine, chH, 0.6, true),
		jet = Sons.creer(S.jetOuverture, chH, 0.7, false),
		mousse = Sons.creer(S.bulles, chH, 0.5, true),
		bip = Sons.creer(S.bip, portique, 0.8, false),
	}
	local liste = {}
	for _, s in pairs(self.snd) do table.insert(liste, s) end
	self.rouleaux = {}
	for i, k in ipairs({"RouleauH", "RouleauG", "RouleauD"}) do
		local p = st:piece(P_ .. k)
		local r = {niveau = 0, prochain = 0,
			frot = Sons.creer(S.eponge, p, 0, true, 1.15 + 0.1 * i),
			ecla = Sons.creer(S.eauTole, p, 0, true, 0.9 + 0.08 * i),
			splash = Sons.creer(S.splash, p, 0.55, false)}
		self.rouleaux[i] = r
		for _, s in ipairs({r.frot, r.ecla, r.splash}) do table.insert(liste, s) end
	end
	Sons.precharger(liste)
	return self
end

function L4:debut(cy)
	self.segPrec, self.tcPrec = nil, nil
	for _, r in ipairs(self.rouleaux) do r.niveau, r.prochain = 0, 0 end
end

function L4:maj(cy, tc, dt)
	local P, snd = cy.seg.piste, self.snd
	local seg = Outils.dans(P.segs, tc, 2)
	local nom = seg and seg[1]
	if nom and nom ~= self.segPrec then
		if MOTEUR[nom] then Sons.etirer(snd.moteur, seg[3] - seg[2]) end
		if nom == "lavage" or nom == "rincage" then Sons.coup(snd.jet) end
	end
	self.segPrec = nom
	local tourne = TOURNE[nom] or false
	local eau = Outils.dans(P.eau, tc) ~= nil
	Effets.activer(self.eau, eau)
	Effets.activer(self.mousse, eau and nom == "lavage")
	Sons.jouer(snd.brosses, tourne)
	Sons.jouer(snd.eau, eau)
	Sons.jouer(snd.mousse, nom == "lavage")
	-- chaque rouleau : frottement mouille + eclaboussures quand il touche la voiture, paquets d'eau au hasard
	for i, r in ipairs(self.rouleaux) do
		local contact = Outils.dans(P.contact[i], tc) ~= nil
		local cible = contact and 1 or ((tourne and eau) and 0.25 or 0)
		r.niveau += (cible - r.niveau) * math.clamp(dt * 5, 0, 1)
		if r.frot then r.frot.Volume = 0.9 * r.niveau * Sons.VOLUME; Sons.jouer(r.frot, r.niveau > 0.03) end
		if r.ecla then r.ecla.Volume = 0.6 * r.niveau * Sons.VOLUME; Sons.jouer(r.ecla, r.niveau > 0.03) end
		if r.splash and contact and tc >= r.prochain then
			Sons.coup(r.splash, 0.85 + cy.rng:NextNumber() * 0.4)
			r.prochain = tc + 0.5 + cy.rng:NextNumber() * 0.9
		end
	end
	local prec = self.tcPrec or tc
	if Outils.franchi(prec, tc, P.T_ARRIVEE + 0.4) or Outils.franchi(prec, tc, P.T_DEPART) then Sons.coup(snd.bip) end
	self.tcPrec = tc
end

function L4:fin(cy)
	for _, s in ipairs({self.snd.moteur, self.snd.brosses, self.snd.eau, self.snd.mousse}) do Sons.jouer(s, false) end
	for _, r in ipairs(self.rouleaux) do Sons.jouer(r.frot, false); Sons.jouer(r.ecla, false) end
	Effets.activer(self.eau, false); Effets.activer(self.mousse, false)
end

return L4
