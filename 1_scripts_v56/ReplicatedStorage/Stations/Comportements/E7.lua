--[[ Comportement E7 (teinte des vitres) : lumieres, vapeur, teinte des vitres qui suit le portique, sons
	Passe 1 "film" : la barre haute pose le film ; passe 2 "chauffe" : la teinte se fixe ; passe 3 "controle" : reflet.
	La teinte suit la position REELLE du portique (lue sur la piece animee) : elle avance exactement avec lui.
	Donnees par segment (piste) : passes = {{nom, t0, t1}}, T_ARRIVEE, T_DEPART.
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)
local Voiture = require(Stations.Voiture)

local E7 = {}
E7.__index = E7
local UP = Outils.UP
local S = Sons.CATALOGUE
local P_ = "E7_Teinte_Mob_"
-- finitions possibles : couleur + reflet (la transparence des vitres n'est jamais modifiee) ;
-- a chaque passage la voiture change de famille : brillante -> mate et foncee, mate -> brillante
local FINITIONS_BRILLANTES = {
	{Color3.fromRGB(170, 176, 184), 0.70}, {Color3.fromRGB(30, 32, 38), 0.60},
	{Color3.fromRGB(40, 60, 100), 0.55}, {Color3.fromRGB(110, 84, 50), 0.55},
}
local FINITIONS_MATES = {
	{Color3.fromRGB(12, 12, 14), 0.00}, {Color3.fromRGB(28, 30, 34), 0.02},
	{Color3.fromRGB(14, 18, 34), 0.03}, {Color3.fromRGB(14, 24, 20), 0.02},
}
local LUMIERE = {film = {Color3.fromRGB(235, 240, 255), 1.6}, chauffe = {Color3.fromRGB(255, 130, 40), 2.6},
	controle = {Color3.fromRGB(60, 210, 255), 2.2}}

function E7.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, E7)
	local rep, R = st.rep, st.D.ROBOT
	self.lampes, self.vapeur = {}, {}
	local function effets(cle, pos, dir)
		local a = rep:attache(st:piece(P_ .. cle), pos, dir, "Effets")
		table.insert(self.lampes, Effets.lumiere(a, 9))
		table.insert(self.vapeur, Effets.emetteur(a, "vapeur", rep))
	end
	effets("Barre", Outils.V(st.D.CENTRES[P_ .. "Barre"]) - UP * 0.45, -UP)
	for _, k in ipairs({"CoteG", "CoteD"}) do
		local cote = (k == "CoteG") and -1 or 1
		local pv = Outils.V((cote < 0) and R.PIVG or R.PIVD)
		effets(k, Vector3.new(pv.X, pv.Y + R.LA, (R.ZS[1] + R.ZS[2]) / 2), Vector3.new(-cote, 0, 0.2).Unit)
	end
	self.portique = st:piece(P_ .. "Portique")
	self.snd = {
		moteur = Sons.creer(S.servo, self.portique, 0.5, false),
		vapeur = Sons.creer(S.spray, st:piece(P_ .. "Barre"), 0.7, true, 0.7),
		bip = Sons.creer(S.bip, self.portique, 0.8, false),
	}
	Sons.precharger({self.snd.moteur, self.snd.vapeur, self.snd.bip})
	return self
end

local function choisirTeinte(rng, c, reflet)
	local famille = (reflet > 0.25) and FINITIONS_MATES or FINITIONS_BRILLANTES
	local liste = {}
	for _, k in ipairs(famille) do
		if math.abs(k[1].R - c.R) + math.abs(k[1].G - c.G) + math.abs(k[1].B - c.B) > 0.05 then table.insert(liste, k) end
	end
	if #liste == 0 then liste = famille end
	return liste[rng:NextInteger(1, #liste)]
end

-- avant la soudure : etendue de chaque vitre le long de la station (voiture garee, repere du modele)
function E7:avantMontage(cy)
	local C, rep = cy.C, self.st.rep
	self.vit, self.depart = {}, {}
	for _, p in ipairs(C.vitres) do
		local a, b = Voiture.boite({p}, C.CAR0, rep)                -- boite dans le repere de la voiture
		local y0, y1 = math.huge, -math.huge
		for _, x in ipairs({a.X, b.X}) do for _, y in ipairs({a.Y, b.Y}) do
			local w = cy.parc * Vector3.new(x, y, a.Z)
			y0, y1 = math.min(y0, w.Y), math.max(y1, w.Y)
		end end
		table.insert(self.vit, {part = p, y0 = y0, y1 = y1})
		self.depart[p] = {p.Color, p.Reflectance}
	end
	local v1 = C.vitres[1]
	self.arrivee = v1 and choisirTeinte(cy.rng, v1.Color, v1.Reflectance) or FINITIONS_MATES[1]
end

function E7:debut(cy) self.ipPrec, self.tcPrec = nil, nil end

function E7:maj(cy, tc, dt)
	local P, snd, rep = cy.seg.piste, self.snd, self.st.rep
	local pa, ip = Outils.dans(P.passes, tc, 2)
	local nom = pa and pa[1]
	for _, l in ipairs(self.lampes) do
		l.Enabled = nom ~= nil
		if nom then l.Color, l.Brightness = LUMIERE[nom][1], LUMIERE[nom][2] end
	end
	Effets.activer(self.vapeur, nom == "chauffe")
	-- teinte : position du portique (YA0 + avance) lue sur la piece animee
	local Y = self.D.ROBOT.YA0 + rep:modele(self.portique.Position).Y - rep:modele((self.portique:GetAttribute("Repos") or self.portique.CFrame).Position).Y
	local p1, p2, p3 = P.passes[1], P.passes[2], P.passes[3]
	for _, v in ipairs(self.vit) do
		local L = math.max(0.3, v.y1 - v.y0)
		local u1, u2, g = 0, 0, 0
		if tc >= p1[2] then u1 = (tc > p1[3]) and 1 or math.clamp((Y - v.y0) / L, 0, 1) end
		if tc >= p2[2] then u2 = (tc > p2[3]) and 1 or math.clamp((v.y1 - Y) / L, 0, 1) end
		if tc >= p3[2] and tc <= p3[3] then g = math.max(0, 1 - math.abs(Y - (v.y0 + v.y1) / 2) / 1.2) end
		local d, part = self.depart[v.part], v.part
		local m = 0.5 * u1 + 0.5 * u2
		if m > 0 and part:IsA("MeshPart") and part.TextureID ~= "" then part.TextureID = "" end
		part.Color = d[1]:Lerp(self.arrivee[1], m)
		part.Reflectance = math.clamp(d[2] + (self.arrivee[2] - d[2]) * m + 0.3 * g, 0, 1)
	end
	-- sons : un bruit de moteur par passe, souffle chaud pendant la chauffe, bips
	if ip and ip ~= self.ipPrec then Sons.etirer(snd.moteur, pa[3] - pa[2]); Sons.coup(snd.bip) end
	self.ipPrec = ip
	Sons.jouer(snd.vapeur, nom == "chauffe")
	local prec = self.tcPrec or tc
	if Outils.franchi(prec, tc, P.T_DEPART) then Sons.coup(snd.bip) end
	if Outils.franchi(prec, tc, P.T_DEPART + 1.6) then Sons.etirer(snd.moteur, 3.4) end
	self.tcPrec = tc
end

function E7:fin(cy)
	for _, s in ipairs({self.snd.moteur, self.snd.vapeur}) do Sons.jouer(s, false) end
	Effets.activer(self.lampes, false); Effets.activer(self.vapeur, false)
end

return E7
