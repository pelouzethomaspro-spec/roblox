--[[ Comportement E6 (cabine de peinture) : jet de peinture, taches de peinture fraiche, nouvelle couleur, sons
	Les taches sont posees sur la carrosserie de CETTE voiture (rayons sur la copie, une fois par modele) ; chacune
	apparait quand la buse passe devant (trajet de la buse enregistre avec l'animation), puis la carrosserie prend
	la nouvelle couleur en fin de peinture.
	Donnees par segment (piste) : peint = {{t0, t1}}, mouvements = {{t0, t1, rotation}}, pos = {{t, Nx, Ny, Nz, gx, gy, gz}},
	T_ARRIVEE, T_FINPEINT, T_DEPART, tDebJet, tFinJet.
]]
local Stations = script.Parent.Parent
local Outils = require(Stations.Outils)
local Sons = require(Stations.Sons)
local Effets = require(Stations.Effets)

local E6 = {}
E6.__index = E6
local UP = Outils.UP
local S = Sons.CATALOGUE
local P_ = "E6_Peinture_Mob_"
local TAILLE_TACHE = 2.0
local TEXTURE_TACHE = "rbxasset://textures/particles/smoke_main.dds"
local SO_DESSUS = 1.35
local FONDU = 0.6
local COULEURS = {
	Color3.fromRGB(200, 22, 32),  Color3.fromRGB(24, 82, 196),  Color3.fromRGB(18, 140, 70),  Color3.fromRGB(242, 190, 24),
	Color3.fromRGB(240, 108, 22), Color3.fromRGB(24, 24, 28),   Color3.fromRGB(236, 236, 236), Color3.fromRGB(122, 128, 136),
	Color3.fromRGB(112, 40, 164), Color3.fromRGB(222, 72, 144), Color3.fromRGB(20, 160, 172), Color3.fromRGB(112, 16, 30),
}

function E6.nouveau(st)
	local self = setmetatable({st = st, D = st.D, cacheTaches = {}, taches = {}}, E6)
	local rep, R = st.rep, st.D.ROBOT
	local pist, ch = st:piece(P_ .. "Pistolet"), st:piece(P_ .. "Chariot")
	local a = rep:attache(pist, Outils.V(R.BUSE), Outils.V(R.f0), "Buse")
	self.jet = {Effets.emetteur(a, "jetPeinture", rep), Effets.emetteur(a, "brumePeinture", rep)}
	self.snd = {
		spray = Sons.creer(S.spray, pist, 0.8, true),
		moteur = Sons.relais(S.servo, ch, 0.45),
		rotation = Sons.creer(S.servoRotation, ch, 0.6, false),
		bip = Sons.creer(S.bip, st:piece(P_ .. "Pont"), 0.8, false),
	}
	local liste = self.snd.moteur:liste()
	for _, s in pairs(self.snd) do if typeof(s) == "Instance" then table.insert(liste, s) end end
	Sons.precharger(liste)
	self.dossier = Instance.new("Folder"); self.dossier.Name = "PeintureFraiche"; self.dossier.Parent = workspace
	return self
end

-- points de la carrosserie (repere canonique de la voiture) : dessus, cotes, avant / arriere ; une fois par modele
local function releve(C, rep)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = C.corps
	local lo, hi = C.cLo, C.cHi
	if not lo then return {} end
	local H = hi.Z - lo.Z
	local hw = math.max(-lo.X, hi.X)
	local pas = 0.85
	local pts, grille = {}, {}
	local function cle(p) return math.floor(p.X / 0.5) .. "," .. math.floor(p.Y / 0.5) .. "," .. math.floor(p.Z / 0.5) end
	local function tir(oL, dL, long, test)
		local r = workspace:Raycast(rep:point(C.CAR0 * oL), rep:direction(C.CAR0:VectorToWorldSpace(dL)) * long, params)
		if not r then return end
		local pL = C.CAR0I * rep:modele(r.Position)
		local nL = C.CAR0I:VectorToWorldSpace(rep:directionModele(r.Normal))
		if nL:Dot(dL) > -0.35 then return end                        -- face vue de trop biais
		if not test(pL) then return end                             -- rayon passe par une vitre : touche l'interieur
		local k = cle(pL)
		if grille[k] then return end
		grille[k] = true
		table.insert(pts, {p = pL, n = nL})
	end
	local function serie(a0, a1, b0, b1, f)
		local na, nb = math.max(1, math.floor((a1 - a0) / pas)), math.max(1, math.floor((b1 - b0) / pas))
		for i = 0, na do for j = 0, nb do f(a0 + (a1 - a0) * i / na, b0 + (b1 - b0) * j / nb) end end
	end
	serie(lo.X + pas / 2, hi.X - pas / 2, lo.Y + pas / 2, hi.Y - pas / 2, function(x, y)
		tir(Vector3.new(x, y, hi.Z + 2), Vector3.new(0, 0, -1), H + 3, function(pL) return pL.Z > lo.Z + 0.38 * H end)
	end)
	for _, s in ipairs({-1, 1}) do
		serie(lo.Y + pas / 2, hi.Y - pas / 2, lo.Z + 0.25, hi.Z - 0.25, function(y, z)
			tir(Vector3.new(s * (hw + 2), y, z), Vector3.new(-s, 0, 0), hw + 3, function(pL) return pL.X * s > 0.55 * hw end)
		end)
	end
	for _, s in ipairs({-1, 1}) do
		local ye = (s > 0) and hi.Y or lo.Y
		serie(lo.X + pas / 2, hi.X - pas / 2, lo.Z + 0.25, hi.Z - 0.25, function(x, z)
			tir(Vector3.new(x, ye + s * 2, z), Vector3.new(0, -s, 0), (hi.Y - lo.Y) * 0.45 + 2, function(pL) return pL.Y * s > 0.25 * (hi.Y - lo.Y) end)
		end)
	end
	-- collision en "boite" : les rayons ne suivent pas la forme -> pas de taches, la couleur change en fondu
	for _, p in ipairs(C.corps) do
		local ok, cf = pcall(function() return p.CollisionFidelity end)
		if ok and cf == Enum.CollisionFidelity.Box then return {} end
	end
	if #pts < 20 then return {} end
	return pts
end

local function choisirCouleur(rng, c)
	local liste = {}
	for _, k in ipairs(COULEURS) do
		if math.abs(k.R - c.R) + math.abs(k.G - c.G) + math.abs(k.B - c.B) > 0.6 then table.insert(liste, k) end
	end
	if #liste == 0 then liste = COULEURS end
	return liste[rng:NextInteger(1, #liste)]
end

-- avant la soudure : taches de CETTE voiture, instant ou la buse passe devant chacune
function E6:avantMontage(cy)
	local C, rep, P = cy.C, self.st.rep, cy.seg.piste
	local pts = self.cacheTaches[C.modele]
	if not pts then pts = releve(C, rep); self.cacheTaches[C.modele] = pts end
	self.ancienne = C.corps[1] and C.corps[1].Color or Color3.new(1, 1, 1)
	self.nouvelle = choisirCouleur(cy.rng, self.ancienne)
	for _, e in ipairs(self.jet) do e.Color = ColorSequence.new(self.nouvelle) end
	local R0 = cy.parc.Rotation
	local liste, parts, cfs = {}, {}, {}
	for i, t0 in ipairs(pts) do
		local p, n = cy.parc * t0.p, R0 * t0.n                     -- voiture garee, repere du modele
		local tr = P.tFinJet
		for _, s in ipairs(P.pos) do
			local N, g = Vector3.new(s[2], s[3], s[4]), Vector3.new(s[5], s[6], s[7])
			local v = p - N
			local d = v:Dot(g)
			if d > 0.2 and d < SO_DESSUS + 1.4 and n:Dot(g) < -0.05 and (v - g * d).Magnitude < 0.45 + 0.55 * d then tr = s[1] break end
		end
		local tache = self.taches[i]
		if not tache then
			local part = Instance.new("Part")
			part.Name = "Tache"; part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(TAILLE_TACHE, TAILLE_TACHE, 0.02)
			local dcl = Instance.new("Decal")
			dcl.Texture = TEXTURE_TACHE; dcl.Face = Enum.NormalId.Front
			dcl.Parent = part
			part.Parent = self.dossier
			tache = {part = part, decal = dcl}
			self.taches[i] = tache
		end
		local c = rep:point(p + n * 0.03)
		parts[i], cfs[i] = tache.part, CFrame.lookAt(c, c + rep:direction(n))
		tache.decal.Color3 = self.nouvelle; tache.decal.Transparency = 1
		liste[i] = {decal = tache.decal, tr = tr, alpha = 1}
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	self.pts = liste
	self.fondu = (#liste == 0)
end

function E6:debut(cy) self.mvPrec, self.tcPrec = nil, nil end

function E6:maj(cy, tc, dt)
	local P, snd, C = cy.seg.piste, self.snd, cy.C
	local peint = Outils.dans(P.peint, tc) ~= nil
	Effets.activer(self.jet, peint)
	Sons.jouer(snd.spray, peint)
	-- taches : apparaissent au passage de la buse, puis se fondent dans la nouvelle couleur
	local fin = P.T_FINPEINT
	for _, tc_ in ipairs(self.pts) do
		local a
		if tc < fin then a = 1 - math.clamp((tc - tc_.tr) / 0.4, 0, 1) * 0.95
		else a = 0.05 + 0.95 * math.clamp((tc - fin) / FONDU, 0, 1) end
		if math.abs(a - tc_.alpha) > 0.02 or (a >= 1) ~= (tc_.alpha >= 1) then tc_.decal.Transparency = a; tc_.alpha = a end
	end
	-- carrosserie : prend la nouvelle couleur sous la peinture fraiche, en fin de peinture
	if C then
		local u = math.clamp((tc - fin) / FONDU, 0, 1)
		if self.fondu then u = math.clamp((tc - P.tDebJet) / math.max(1, P.tFinJet - P.tDebJet), 0, 1) end
		if u ~= self.uPrec then
			self.uPrec = u
			local col = self.ancienne:Lerp(self.nouvelle, u)
			for _, p in ipairs(C.corps) do
				if u > 0 and p:IsA("MeshPart") and p.TextureID ~= "" then p.TextureID = "" end
				p.Color = col
			end
		end
	end
	-- sons : un bruit de moteur par deplacement du robot (hors peinture), rotation de la tourelle
	local mv, i = Outils.dans(P.mouvements, tc)
	if mv and i ~= self.mvPrec then
		snd.moteur:mouvement(mv[2] - mv[1], mv[2])
		if mv[3] and snd.rotation then Sons.etirer(snd.rotation, mv[2] - mv[1]) end
	end
	self.mvPrec = i
	snd.moteur:maj(tc, dt, 1)
	local prec = self.tcPrec or tc
	if Outils.franchi(prec, tc, P.T_ARRIVEE + 0.6) or Outils.franchi(prec, tc, P.T_DEPART) then Sons.coup(snd.bip) end
	self.tcPrec = tc
end

function E6:fin(cy)
	Sons.jouer(self.snd.spray, false); self.snd.moteur:couper(); Sons.jouer(self.snd.rotation, false)
	Effets.activer(self.jet, false)
	for _, t in ipairs(self.taches) do t.decal.Transparency = 1 end
	self.pts, self.uPrec = {}, nil
end

return E6
