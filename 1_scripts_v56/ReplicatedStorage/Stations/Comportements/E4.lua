--[[ Comportement E4 (bornes) : lumieres du bras, flash et etincelles a chaque contact, sons
	Evenements (donnees de la station), tau = temps depuis que la voiture est garee (debut du bras) :
		{tau, "lumiere", "on" | "off"}, {tau, "son", "moteur", duree}, {tau, "son", "allumage" | "extinction"},
		{tau, "touche", "essence" | "gaz" | "elec" | "voiture"}
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)

local E4 = {}
E4.__index = E4
local S = Sons.CATALOGUE
local COULEURS = {
	essence = Color3.fromRGB(255, 150, 40), gaz = Color3.fromRGB(80, 170, 255),
	elec = Color3.fromRGB(120, 255, 240), voiture = Color3.fromRGB(90, 255, 120),
}

function E4.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, E4)
	local rep, D = st.rep, st.D
	local tourelle = st:piece("E4_Bornes_Bras1_Tourelle")
	local att = rep:attache(st:piece("E4_Bornes_Bras5_Pince"), Outils.V(D.POINTE), nil, "Pointe")
	self.lum = Effets.lumiere(att, 7, Color3.fromRGB(120, 220, 255)); self.lum.Enabled = true; self.lum.Brightness = 0
	self.lumT = Effets.lumiere(tourelle, 6, Color3.fromRGB(255, 170, 60)); self.lumT.Enabled = true; self.lumT.Brightness = 0
	self.etin = Effets.emetteur(att, "etincelles", rep)
	self.son = {
		moteur = Sons.creer(S.servo, tourelle, 0.45, false),
		rotation = Sons.creer(S.servoRotation, tourelle, 0.7, false),
		contact = Sons.creer(S.bip, att, 0.7, false),
		clac = Sons.creer(S.clac, att, 0.7, false),
		etincelles = Sons.creer(S.etincelles, att, 0.7, false),
	}
	local liste = {}
	for _, s in pairs(self.son) do table.insert(liste, s) end
	Sons.precharger(liste)
	for _, e in ipairs(D.EVENEMENTS) do
		if e[2] == "lumiere" and e[3] == "on" then self.ALLUMAGE = e[1] end
		if e[2] == "lumiere" and e[3] == "off" then self.EXTINCTION = e[1] end
	end
	return self
end

function E4:debut(cy) self.tauPrec = nil end

local function jouer(s, duree)
	if not s then return end
	if duree then Sons.etirer(s, duree) else Sons.coup(s, 1) end
end

function E4:maj(cy, tc, dt)
	local tau = tc - self.D.T_BRAS
	-- lumieres (sans memoire) : allumage qui clignote, flash colore a chaque contact
	local base = 0
	if tau >= self.ALLUMAGE and tau < self.EXTINCTION then
		local u = tau - self.ALLUMAGE
		base = (u < 0.8 and math.floor(u * 10) % 3 == 0) and 0 or 1.2
	elseif tau >= self.EXTINCTION and tau < self.EXTINCTION + 0.5 then
		base = 1.2 * (1 - (tau - self.EXTINCTION) / 0.5)
	end
	local col, br = Color3.fromRGB(120, 220, 255), base
	for _, e in ipairs(self.D.EVENEMENTS) do
		if e[2] == "touche" and tau >= e[1] and tau < e[1] + 1.0 then
			local u = tau - e[1]
			col = COULEURS[e[3]] or col
			br = base + 4 * (1 - u) * (0.75 + 0.25 * math.sin(u * 40))
		end
	end
	self.lum.Color, self.lum.Brightness = col, br
	self.lumT.Brightness = base * 0.8
	-- evenements franchis depuis l'image precedente
	local prec = self.tauPrec or tau
	for _, e in ipairs(self.D.EVENEMENTS) do
		if Outils.franchi(prec, tau, e[1]) then
			if e[2] == "son" and e[3] == "moteur" then jouer(self.son.moteur, e[4])
			elseif e[2] == "son" and (e[3] == "allumage" or e[3] == "extinction") then jouer(self.son.rotation, 1.2); jouer(self.son.clac)
			elseif e[2] == "touche" then
				jouer(self.son.contact); jouer(self.son.clac)
				if e[3] == "elec" then jouer(self.son.etincelles) end
				self.etin.Color = ColorSequence.new(COULEURS[e[3]] or Color3.new(1, 1, 1))
				self.etin:Emit(e[3] == "elec" and 60 or 25)
			end
		end
	end
	self.tauPrec = tau
end

function E4:fin(cy)
	self.lum.Brightness = 0; self.lumT.Brightness = 0
end

return E4
