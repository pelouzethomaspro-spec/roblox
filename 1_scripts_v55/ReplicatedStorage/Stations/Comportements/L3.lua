--[[ Comportement L3 (karcher au plafond) : jet d'eau, eclaboussures, sons
	Le jet part de la buse (qui bouge avec l'animation) ; un rayon vers le bas donne le point d'impact
	(sur la voiture ou au sol) : les gouttes s'arretent a cette distance, les eclaboussures y apparaissent.
	Donnees par segment (piste) : segs = {{nom, t0, t1}}, eau = {{t0, t1}}, T_ARRIVEE, T_DEPART.
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)

local L3 = {}
L3.__index = L3
local UP = Outils.UP
local S = Sons.CATALOGUE
local MOTEUR = {descente = true, aller = true, retour = true, montee = true}

function L3.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, L3)
	local rep, D = st.rep, st.D
	local lance, pont = st:piece("L3_Karcher_Mob_Lance"), st:piece("L3_Karcher_Mob_Pont")
	self.buse = rep:attache(lance, Outils.V(D.NOZ), -UP, "Buse")
	self.jet = {Effets.emetteur(self.buse, "jetKarcher", rep), Effets.emetteur(self.buse, "brumeEau", rep)}
	self.impact = Instance.new("Attachment"); self.impact.Name = "Impact"; self.impact.Parent = st.socle
	self.sol = {Effets.emetteur(self.impact, "eclaboussures", rep), Effets.emetteur(self.impact, "nuage", rep)}
	self.snd = {
		moteur = Sons.creer(S.servo, pont, 0.45, false),
		jet = Sons.creer(S.jetKarcher, lance, 0.8, true),
		impact = Sons.creer(S.eauTole, self.impact, 0, true),
		ouverture = Sons.creer(S.jetOuverture, lance, 0.6, false),
		gachette = Sons.creer(S.clac, lance, 0.7, false),
		bip = Sons.creer(S.bip, pont, 0.8, false),
	}
	local liste = {}
	for _, s in pairs(self.snd) do table.insert(liste, s) end
	Sons.precharger(liste)
	self.params = RaycastParams.new()
	self.params.FilterType = Enum.RaycastFilterType.Include
	return self
end

function L3:debut(cy)
	self.segPrec, self.tcPrec, self.niveau = nil, nil, 0
	self.params.FilterDescendantsInstances = {cy.C.voiture}
end

function L3:maj(cy, tc, dt)
	local P, rep, snd = cy.seg.piste, self.st.rep, self.snd
	local seg = Outils.dans(P.segs, tc, 2)
	local nom = seg and seg[1]
	if nom and nom ~= self.segPrec then                      -- un bruit de moteur par deplacement
		if MOTEUR[nom] then Sons.etirer(snd.moteur, seg[3] - seg[2]) end
		if nom == "aller" then Sons.coup(snd.ouverture) end
		if nom == "montee" then Sons.coup(snd.gachette) end
	end
	self.segPrec = nom
	local eau = Outils.dans(P.eau, tc) ~= nil
	Effets.activer(self.jet, eau)
	Effets.activer(self.sol, eau)
	Sons.jouer(snd.jet, eau)
	local surV = false
	if eau then
		-- point d'impact : rayon vers le bas depuis la buse (voiture), sinon le sol
		local b = self.buse.WorldPosition
		local r = workspace:Raycast(b, rep:direction(-UP) * 12, self.params)
		local pi
		if r then pi, surV = r.Position, true
		else local bm = rep:modele(b); pi = rep:point(Vector3.new(bm.X, bm.Y, self.D.PLACE.SOL)) end
		local dist = math.max(0.3, (b - pi).Magnitude)
		if math.abs(dist - (self.dist or 0)) > 0.05 then
			self.dist = dist
			self.jet[1].Lifetime = NumberRange.new(dist / 30, dist / 26)
		end
		local up = rep:direction(UP)
		self.impact.WorldCFrame = CFrame.lookAt(pi + up * 0.05, pi + up)
	end
	-- impact : plus fort sur la voiture que sur le sol
	local cible = eau and (surV and 1 or 0.4) or 0
	self.niveau += (cible - self.niveau) * math.clamp(dt * 6, 0, 1)
	if snd.impact then
		snd.impact.Volume = 0.75 * self.niveau * Sons.VOLUME
		snd.impact.PlaybackSpeed = surV and 1.05 or 0.9
		Sons.jouer(snd.impact, self.niveau > 0.03)
	end
	local prec = self.tcPrec or tc
	if Outils.franchi(prec, tc, P.T_ARRIVEE + 0.4) or Outils.franchi(prec, tc, P.T_DEPART) then Sons.coup(snd.bip) end
	self.tcPrec = tc
end

function L3:fin(cy)
	for _, s in ipairs({self.snd.moteur, self.snd.jet, self.snd.impact}) do Sons.jouer(s, false) end
	Effets.activer(self.jet, false); Effets.activer(self.sol, false)
end

return L3
