--[[ Stations / Voiture   (cote joueur)
	La voiture d'un cycle : copie locale d'un modele de ReplicatedStorage.VoituresModeles, mesuree (roues, avant,
	carrosserie, vitres, categorie), puis SOUDEE aux pieces invisibles "Voiture" et "Roue_AVG/AVD/ARG/ARD" de la
	station. Ces pieces sont deplacees par l'animation de la station : la voiture roule, s'arrete, ses roues
	tournent... sans aucun calcul de position dans le code. A la fin du cycle la copie est detruite.

	Repere canonique d'une voiture : centre de la boite au sol, Y vers l'avant, X vers la droite, Z en haut.
]]
local Outils = require(script.Parent.Outils)
local Sons = require(script.Parent.Sons)
local Categories = require(script.Parent.Categories)

local Voiture = {}
local UP = Outils.UP

Voiture.REGLAGES = {MOTEUR = true}

------------------------------------------------------------------
-- 1) mesure
------------------------------------------------------------------
local function partsDe(inst)
	local t = {}
	for _, d in ipairs(inst:GetDescendants()) do if d:IsA("BasePart") then table.insert(t, d) end end
	return t
end
local function estRoue(n)
	n = string.lower(n)
	return n:find("wheel") or n:find("roue") or n:find("pneu") or n:find("tire") or n:find("tyre")
end
local function genre(cle)          -- 1 = avant, -1 = arriere, 0 = inconnu
	local n = string.upper(cle)
	if n:find("FL") or n:find("FR") or n:find("AV") or n:find("FRONT") then return 1 end
	if n:find("RL") or n:find("RR") or n:find("AR") or n:find("REAR") or n:find("BACK") then return -1 end
	return 0
end
local function centre(parts)
	local s = Vector3.zero
	for _, p in ipairs(parts) do s += p.Position end
	return s / #parts
end

-- boite englobante de pieces dans le repere Fr (repere du modele)
function Voiture.boite(parts, Fr, rep)
	local Fi = Fr:Inverse()
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in ipairs(parts) do
		local h = p.Size / 2
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			local l = Fi * rep:modele(p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			lo = Vector3.new(math.min(lo.X, l.X), math.min(lo.Y, l.Y), math.min(lo.Z, l.Z))
			hi = Vector3.new(math.max(hi.X, l.X), math.max(hi.Y, l.Y), math.max(hi.Z, l.Z))
		end end end
	end
	return lo, hi
end
local boite = Voiture.boite

local function groupesRoues(voiture, toutes)
	local groupes, ordre = {}, {}
	for _, p in ipairs(toutes) do
		-- un modele "roue" regroupe ses pieces ; sinon on regroupe par nom sans le suffixe _1, _2...
		local a, cle = p.Parent, nil
		while a and a ~= voiture do
			if a:IsA("Model") and estRoue(a.Name) then cle = a.Name end
			a = a.Parent
		end
		if not cle and estRoue(p.Name) then cle = (p.Name:gsub("[_%s%-]*%d+$", "")) end
		if cle then
			if not groupes[cle] then groupes[cle] = {}; table.insert(ordre, cle) end
			table.insert(groupes[cle], p)
		end
	end
	return groupes, ordre
end

local function trouverCarrosserie(toutes, dansRoue)
	local corps = {}
	for _, p in ipairs(toutes) do if p:GetAttribute("Carrosserie") then table.insert(corps, p) end end
	if #corps == 0 then
		for _, p in ipairs(toutes) do
			local n = string.lower(p.Name)
			if not dansRoue[p] and (n == "model" or n == "body" or n == "carrosserie" or n == "caisse") then table.insert(corps, p) end
		end
	end
	if #corps == 0 then                                          -- sinon : la plus grosse piece opaque hors roues
		local best, vb = nil, -1
		for _, p in ipairs(toutes) do
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if not dansRoue[p] and p.Transparency < 0.3 and v > vb then best, vb = p, v end
		end
		if best then corps = {best} end
	end
	return corps
end

local function trouverVitres(C, rep)
	local estCorps = {}
	for _, p in ipairs(C.corps) do estCorps[p] = true end
	local function ok(p) return not C.dansRoue[p] and not estCorps[p] end
	local vitres = {}
	for _, p in ipairs(C.toutes) do if p:GetAttribute("Vitre") then table.insert(vitres, p) end end
	if #vitres == 0 then
		for _, p in ipairs(C.toutes) do
			local n = string.lower(p.Name)
			if ok(p) and (n:find("wind") or n:find("vitre") or n:find("glass") or n:find("verre")) then table.insert(vitres, p) end
		end
	end
	if #vitres == 0 then
		for _, p in ipairs(C.toutes) do
			if ok(p) and (p.Transparency >= 0.05 or p.Material == Enum.Material.Glass) then table.insert(vitres, p) end
		end
	end
	if #vitres == 0 then                                         -- piece la plus haute qui couvre l'habitacle
		local best, zb = nil, -1e9
		for _, p in ipairs(C.toutes) do
			if ok(p) then
				local a, b = boite({p}, C.CAR0, rep)
				if (b.X - a.X) > 0.5 * (C.hi.X - C.lo.X) and (b.Y - a.Y) > 0.3 * (C.hi.Y - C.lo.Y) and (a.Z + b.Z) / 2 > zb then
					best, zb = p, (a.Z + b.Z) / 2
				end
			end
		end
		if best then vitres = {best} end
	end
	return vitres
end

-- mesure une voiture (copie posee n'importe ou) ; rep = repere de la station
function Voiture.mesurer(voiture, rep)
	local C = {voiture = voiture, nom = voiture.Name}
	local toutes = partsDe(voiture)
	local groupes, ordre = groupesRoues(voiture, toutes)
	local dansRoue = {}
	for i, cle in ipairs(ordre) do for _, p in ipairs(groupes[cle]) do dansRoue[p] = i end end
	C.toutes, C.dansRoue = toutes, dansRoue
	-- avant de la voiture (roues FL/FR vs RL/RR, sinon orientation du modele)
	local av, ar, na, nr = Vector3.zero, Vector3.zero, 0, 0
	for _, cle in ipairs(ordre) do
		local g, c = genre(cle), centre(groupes[cle])
		if g == 1 then av += c; na += 1 elseif g == -1 then ar += c; nr += 1 end
	end
	local fwdR
	if na >= 1 and nr >= 1 then fwdR = av / na - ar / nr
	else fwdR = CFrame.Angles(0, math.rad(voiture:GetAttribute("Rotation") or 0), 0) * voiture:GetPivot().LookVector end
	fwdR = Vector3.new(fwdR.X, 0, fwdR.Z).Unit
	local fwd = rep:directionModele(fwdR)
	fwd = Vector3.new(fwd.X, fwd.Y, 0).Unit
	local F = CFrame.fromMatrix(rep:modele(voiture:GetPivot().Position), fwd:Cross(UP), fwd, UP)
	local lo, hi = boite(toutes, F, rep)
	C.CAR0 = F * CFrame.new((lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2, lo.Z)    -- repere canonique (repere du modele)
	C.CAR0I = C.CAR0:Inverse()
	C.lo, C.hi = boite(toutes, C.CAR0, rep)
	local caisse = {}
	for _, p in ipairs(toutes) do if not dansRoue[p] then table.insert(caisse, p) end end
	local cl, ch = boite(caisse, C.CAR0, rep)
	C.caisse, C.DESSOUS, C.DEMI_LARGEUR, C.HAUT_CAISSE = caisse, cl.Z, math.max(-cl.X, ch.X), ch.Z
	C.roues, C.MILIEU_Y = {}, 0
	for _, cle in ipairs(ordre) do
		local parts = groupes[cle]
		local a, b = boite(parts, C.CAR0, rep)
		table.insert(C.roues, {cle = cle, parts = parts, c = (a + b) / 2, demiLarg = (b.X - a.X) / 2, rayon = math.max(b.Y - a.Y, b.Z - a.Z) / 2})
		C.MILIEU_Y += (a.Y + b.Y) / 2 / #ordre
	end
	local yAv, yAr = -1e9, 1e9
	for _, r in ipairs(C.roues) do yAv = math.max(yAv, r.c.Y); yAr = math.min(yAr, r.c.Y) end
	if #C.roues < 2 or yAv - yAr < 1 then yAv, yAr = C.hi.Y * 0.6, C.lo.Y * 0.6 end
	C.essieux = {yAv, yAr}
	C.corps = trouverCarrosserie(toutes, dansRoue)
	if #C.corps > 0 then C.cLo, C.cHi = boite(C.corps, C.CAR0, rep) end
	C.vitres = trouverVitres(C, rep)
	C.categorie = Categories.de(voiture, C.hi.Z - C.lo.Z)
	-- roues rangees par place (avant / arriere, gauche / droite) ; une place deja prise : roue fixe
	C.parPlace = {}
	for _, r in ipairs(C.roues) do
		local place = ((r.c.Y > 0) and "AV" or "AR") .. ((r.c.X < 0) and "G" or "D")
		if not C.parPlace[place] then C.parPlace[place] = r; r.place = place end
	end
	return C
end

------------------------------------------------------------------
-- 2) copie d'un modele pour un cycle
------------------------------------------------------------------
local dossierLocal
local function dossier()
	if not dossierLocal or not dossierLocal.Parent then
		dossierLocal = Instance.new("Folder")
		dossierLocal.Name = "VoituresDesStations"
		dossierLocal.Parent = workspace
	end
	return dossierLocal
end

-- copie + mesure ; k = facteur d'echelle eventuel (fonction ajuster(C) -> k)
function Voiture.copier(modele, rep, ajuster)
	local v = modele:Clone()
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") or d:IsA("BaseScript") then d:Destroy()
		elseif d:IsA("BasePart") and d.Name == "Root" and d.Transparency >= 1 then
			d:Destroy()                -- racine invisible des voitures clientes du tycoon : ne doit pas fausser la mesure (elle depasse sous les roues)
		elseif d:IsA("BasePart") then
			d.Anchored = true; d.CanCollide = false; d.CanTouch = false; d.CanQuery = true; d.Massless = true
		end
	end
	v.Name = modele.Name
	v.Parent = dossier()
	local C = Voiture.mesurer(v, rep)
	local k = ajuster and ajuster(C)
	if k and math.abs(k - 1) > 0.001 then
		v:ScaleTo(v:GetScale() * k)
		C = Voiture.mesurer(v, rep)
	end
	C.modele = modele.Name
	return C
end

------------------------------------------------------------------
-- 3) soudure aux pieces animees de la station
--    st.voiture / st.roues[place] = pieces invisibles ; st.motVoiture / st.motRoues[place] = leurs Motor6D
--    parc = position de la voiture garee (repere du modele)
------------------------------------------------------------------
local function souder(part, p0, cadre)
	local w = Instance.new("Weld")
	w.Name = "SoudureStation"
	w.Part0 = p0
	w.Part1 = part
	w.C0 = cadre:Inverse() * part.CFrame
	w.Parent = part
	return w
end

function Voiture.monter(C, st, parc)
	local cadre = st.rep.MAP * C.CAR0                          -- repere canonique de la copie, dans le monde
	for _, p in ipairs(C.caisse) do souder(p, st.voiture, cadre) end
	for _, r in ipairs(C.roues) do
		local hub = r.place and st.roues[r.place]
		if hub then
			st.motRoues[r.place].C0 = CFrame.new(r.c)
			local cr = cadre * CFrame.new(r.c)
			r.soudures, r.relatif = {}, {}
			for i, p in ipairs(r.parts) do
				r.relatif[i] = cr:Inverse() * p.CFrame                -- piece de roue dans le repere du moyeu
				r.soudures[i] = souder(p, hub, cr)
			end
		else
			for _, p in ipairs(r.parts) do souder(p, st.voiture, cadre) end
		end
	end
	st.motVoiture.C0 = parc
	for _, p in ipairs(C.toutes) do p.Anchored = false end
	C.st = st
end

function Voiture.detruire(C)
	if C and C.voiture then C.voiture:Destroy() end
end

------------------------------------------------------------------
-- 4) bruit de moteur (caractere selon la categorie), plus aigu quand la voiture roule
------------------------------------------------------------------
function Voiture.moteur(C)
	if not Voiture.REGLAGES.MOTEUR or C.son then return end
	local m = C.categorie.moteur
	local support = C.corps[1] or C.caisse[1] or C.toutes[1]
	C.son = Sons.creer(Sons.CATALOGUE.moteurVoiture, support, m.volume, true, m.ralenti)
	if C.son then
		C.son.RollOffMinDistance = 8; C.son.RollOffMaxDistance = 90
		C.son:Play()
	end
end

-- a chaque image : la vitesse est lue sur la piece "Voiture" (deplacee par l'animation)
function Voiture.majMoteur(C, dt)
	local s = C.son
	local p = C.st and C.st.voiture.Position
	if not s or not p then return end
	local v = (C.pPrec and dt > 0) and (p - C.pPrec).Magnitude / dt or 0
	C.pPrec = p
	C.vLisse = (C.vLisse or 0) + (v - (C.vLisse or 0)) * math.clamp(dt * 6, 0, 1)
	local m = C.categorie.moteur
	local u = math.clamp(C.vLisse / 8, 0, 1)
	s.PlaybackSpeed = m.ralenti + (m.roule - m.ralenti) * u
	s.Volume = m.volume * (0.8 + 0.5 * u) * Sons.VOLUME
end

return Voiture
