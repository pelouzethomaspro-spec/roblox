--[[ Comportement "Simple" : stations sans robot (L1, L2, E1, E2, E3)
	Pendant que la voiture est garee, des sons d'action (donnees de la station : SONS, ACTIONS, tau = temps depuis
	que la voiture est garee) :
		{"coup", t = 0.3, son = "bip"}                                     -- un son a un instant
		{"boucle", de = 0.5, a = 7, son = "jet", volume = 0.6}             -- un son en boucle pendant un moment
		{"hasard", de = 1, a = 7, son = "splash", intervalle = {1.2, 2.5}} -- un son de temps en temps
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)

local Simple = {}
Simple.__index = Simple

function Simple.nouveau(st)
	local self = setmetatable({st = st, D = st.D}, Simple)
	local P = st.D.PLACE
	local support = st.rep:attache(st.socle, Vector3.new(P.XC, P.YC, P.SOL + 2.5), nil, "SonsStation")
	self.actions = {}
	local liste = {}
	for _, a in ipairs(st.D.ACTIONS or {}) do
		local id = Sons.CATALOGUE[st.D.SONS[a.son]] or st.D.SONS[a.son]
		local e = {a = a, snd = Sons.creer(id, support, a.volume or 0.7, a[1] == "boucle", type(a.vitesse) == "number" and a.vitesse or 1)}
		table.insert(self.actions, e)
		if e.snd then table.insert(liste, e.snd) end
	end
	Sons.precharger(liste)
	return self
end

local function tirage(rng, v)
	if type(v) == "table" then return v[1] + (v[2] - v[1]) * rng:NextNumber() end
	return v or 1
end

function Simple:debut(cy)
	self.tauPrec = nil
	for _, e in ipairs(self.actions) do e.prochain, e.coupe = nil, nil end
end

-- sons d'action : tau = temps depuis que la voiture est garee
function Simple:maj(cy, tc, dt)
	local tau = tc - (cy.T_ARRET or 0)
	local prec = self.tauPrec or -1e9
	for _, e in ipairs(self.actions) do
		local a, s = e.a, e.snd
		if s then
			if e.coupe and tau >= e.coupe then s:Stop(); e.coupe = nil end
			if a[1] == "coup" then
				if prec < a.t and tau >= a.t and tau < a.t + 1 then
					Sons.coup(s, tirage(cy.rng, a.vitesse))
					if a.duree then e.coupe = tau + a.duree end
				end
			elseif a[1] == "boucle" then
				Sons.jouer(s, tau >= a.de and tau < a.a)
			elseif a[1] == "hasard" and tau >= a.de and tau < a.a then
				e.prochain = e.prochain or (a.de + tirage(cy.rng, a.intervalle) * 0.5)
				if tau >= e.prochain then
					Sons.coup(s, tirage(cy.rng, a.vitesse))
					if a.duree then e.coupe = tau + a.duree end
					e.prochain = tau + tirage(cy.rng, a.intervalle)
				end
			end
		end
	end
	self.tauPrec = tau
end

function Simple:fin(cy)
	for _, e in ipairs(self.actions) do if e.snd and e.snd.IsPlaying then e.snd:Stop() end end
end

return Simple
