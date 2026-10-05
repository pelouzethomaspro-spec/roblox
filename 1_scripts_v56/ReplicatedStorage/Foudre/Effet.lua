--[[ Foudre / Effet   (ReplicatedStorage > Foudre > Effet) - calcule chez chaque joueur, rien sur le serveur
	- eclair : trait en zigzag du ciel jusqu'a la voiture (avec branches), flash, gerbe d'etincelles, tonnerre
	  retarde selon la distance, secousse de camera pres de l'impact ;
	- voiture electrifiee : halo violet qui scintille, arcs electriques qui sautent sur la carrosserie et vers
	  le sol, etincelles, petites decharges, lumiere qui gresille, crepitement ; fumee a l'extinction.
	Optimisation : objets crees une fois par voiture puis reutilises (aucune creation par image) ; une seule boucle
	pour tout ; effet complet seulement pour les MAX_COMPLET voitures les plus proches (< DISTANCE_COMPLET),
	halo seul plus loin, rien au-dela de DISTANCE_HALO ; particules reduites selon la qualite graphique du joueur.
]]
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local R = require(script.Parent.Reglages)
local TAG = "Electrifiee"
local Effet = {}
local rng = Random.new()
local function rnd(a, b) return rng:NextNumber(a, b) end

------------------------------------------------------------------ medias
local INTEGRE = {
	Arc = "", Trait = "",
	Etincelle = "rbxasset://textures/particles/sparkles_main.dds",
	Lueur = "rbxasset://textures/particles/smoke_main.dds",      -- tache douce : bonne lueur une fois teintee et emissive
	Crepitement = "rbxasset://textures/particles/sparkles_main.dds",
}
local function valide(id) return type(id) == "string" and id:match("%d") ~= nil and not id:match("://0*$") end
local function tex(nom) local id = R.TEXTURES[nom]; return valide(id) and id or INTEGRE[nom] end
local function son(nom) local id = R.SONS[nom]; return valide(id) and id or nil end
local CRAQUE_FLIPBOOK = valide(R.TEXTURES.Crepitement)

local function qualite()
	local ok, q = pcall(function() return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value end)
	if not ok or not q or q == 0 then return 0.8 end
	return math.clamp(q / 10, 0.3, 1)
end
local Q = qualite()

local function seq(c) return ColorSequence.new(c) end
local function num(...) return NumberSequence.new(...) end
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end

local function beam(a0, a1, texture, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = texture; b.TextureMode = Enum.TextureMode.Wrap; b.TextureLength = 10
	b.LightEmission = 1; b.LightInfluence = 0; b.Brightness = 3
	b.Color = seq(Color3.new(1, 1, 1)); b.FaceCamera = true; b.Segments = 8
	if texture == "" then b.Color = seq(R.COULEUR_COEUR) end
	b.Parent = parent
	return b
end

local function emetteur(parent, nom)
	local e = Instance.new("ParticleEmitter"); e.Name = nom
	e.LightEmission = 1; e.LightInfluence = 0; e.Enabled = false; e.Rate = 0
	e.Parent = parent
	return e
end
local function etincelles(parent)
	local e = emetteur(parent, "Etincelles")
	e.Texture = tex("Etincelle"); e.Color = seq(R.COULEUR_COEUR)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Size = num(0.35, 0); e.Lifetime = NumberRange.new(0.25, 0.6)
	e.Speed = NumberRange.new(10, 22); e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0); e.Drag = 2; e.Brightness = 4
	e.Transparency = num({kp(0, 0), kp(0.7, 0.2), kp(1, 1)})
	return e
end
local function craquements(parent)
	local e = emetteur(parent, "Craquements")
	e.Texture = tex("Crepitement"); e.Color = seq(Color3.new(1, 1, 1))
	e.Color = seq(R.COULEUR_COEUR)
	if CRAQUE_FLIPBOOK then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4; e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Size = num(2.2); e.Lifetime = NumberRange.new(0.18, 0.3)
	e.Speed = NumberRange.new(0, 0.5); e.Rotation = NumberRange.new(0, 360); e.Brightness = 3
	e.Transparency = num(0)
	return e
end
local function lueurs(parent)
	local e = emetteur(parent, "Lueur")
	e.Texture = tex("Lueur"); e.Color = seq(R.COULEUR)
	e.Size = num({kp(0, 6), kp(1, 9)}); e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(0, 1); e.Brightness = 1.2
	e.Transparency = num({kp(0, 1), kp(0.3, 0.6), kp(1, 1)})
	return e
end
local function fumee(parent)
	local e = emetteur(parent, "Fumee")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.LightEmission = 0; e.LightInfluence = 1
	e.Color = seq(Color3.fromRGB(70, 60, 80)); e.Size = num({kp(0, 2), kp(1, 7)})
	e.Lifetime = NumberRange.new(1.5, 2.5); e.Speed = NumberRange.new(2, 5); e.SpreadAngle = Vector2.new(40, 40)
	e.EmissionDirection = Enum.NormalId.Top; e.Transparency = num({kp(0, 0.6), kp(1, 1)})
	return e
end
local function sonJoue(parent, id, vol, mini, maxi, boucle)
	if not id then return nil end
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = vol * R.VOLUME; s.Looped = boucle or false
	s.RollOffMode = Enum.RollOffMode.InverseTapered; s.RollOffMinDistance = mini; s.RollOffMaxDistance = maxi
	s.Parent = parent
	return s
end

------------------------------------------------------------------ flash du ciel, ambiance, secousse
local flash = Instance.new("ColorCorrectionEffect"); flash.Name = "FoudreFlash"; flash.Parent = Lighting
local ambiance
local function flashCiel(force)
	flash.Brightness = 0.35 * force; flash.TintColor = Color3.fromRGB(255, 235, 255)
	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0, TintColor = Color3.new(1, 1, 1)}):Play()
end
local secousse = 0
RunService:BindToRenderStep("FoudreSecousse", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if secousse > 0.01 then
		local cam = workspace.CurrentCamera
		local s = secousse
		cam.CFrame = cam.CFrame * CFrame.Angles(rnd(-1, 1) * 0.02 * s, rnd(-1, 1) * 0.02 * s, 0) + Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * 0.4 * s
		secousse = math.max(0, secousse - dt * 2.5)
	end
end)
local function majAmbiance()
	if not R.AMBIANCE_ORAGE then return end
	local on = workspace:GetAttribute("FoudreOrage") == true
	if on and not ambiance then
		ambiance = Instance.new("ColorCorrectionEffect"); ambiance.Name = "FoudreAmbiance"; ambiance.Parent = Lighting
		TweenService:Create(ambiance, TweenInfo.new(3), {Brightness = -0.06, Contrast = 0.08, Saturation = -0.1, TintColor = Color3.fromRGB(228, 218, 255)}):Play()
	elseif not on and ambiance then
		local a = ambiance; ambiance = nil
		TweenService:Create(a, TweenInfo.new(3), {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)}):Play()
		Debris:AddItem(a, 3.5)
	end
end

------------------------------------------------------------------ eclair (2 eclairs possibles en meme temps, reutilises)
local SEG, BR, BRSEG = 16, 3, 5
local ancre = workspace.Terrain
local function nouvelEclair()
	local E = {pts = {}, beams = {}, br = {}}
	for i = 1, SEG + 1 do local a = Instance.new("Attachment"); a.Name = "FoudreEclair"; a.Parent = ancre; E.pts[i] = a end
	for i = 1, SEG do E.beams[i] = beam(E.pts[i], E.pts[i + 1], tex("Trait"), ancre) end
	-- gaine : un second trait, large et translucide, couleur violette, autour du coeur blanc (lueur de l'eclair)
	E.gaine, E.gaine2 = {}, {}
	for i = 1, SEG do
		local g = beam(E.pts[i], E.pts[i + 1], "", ancre); g.Color = seq(R.COULEUR); g.Brightness = 2; g.Segments = 4
		E.gaine[i] = g
		local g2 = beam(E.pts[i], E.pts[i + 1], "", ancre); g2.Color = seq(R.COULEUR); g2.Brightness = 1; g2.Segments = 4
		E.gaine2[i] = g2
	end
	for _, b in ipairs(E.beams) do b.Color = seq(R.COULEUR_COEUR); b.Brightness = 4 end
	for b = 1, BR do
		local B = {pts = {}, beams = {}}
		for i = 1, BRSEG + 1 do local a = Instance.new("Attachment"); a.Name = "FoudreEclair"; a.Parent = ancre; B.pts[i] = a end
		for i = 1, BRSEG do B.beams[i] = beam(B.pts[i], B.pts[i + 1], tex("Trait"), ancre) end
		E.br[b] = B
	end
	local centre = Instance.new("Attachment"); centre.Name = "FoudreImpact"; centre.Parent = ancre; E.impact = centre
	E.lumiere = Instance.new("PointLight"); E.lumiere.Color = R.COULEUR; E.lumiere.Range = 60; E.lumiere.Brightness = 0
	E.lumiere.Shadows = false; E.lumiere.Parent = centre
	E.etinc = etincelles(centre); E.lueur = lueurs(centre); E.craq = craquements(centre)
	E.etinc.Speed = NumberRange.new(20, 45); E.lueur.Size = num({kp(0, 10), kp(1, 22)}); E.craq.Size = num(7)
	E.libre = true
	local function visible(v)
		for _, b in ipairs(E.beams) do b.Enabled = v end
		for i, g in ipairs(E.gaine) do g.Enabled = v; E.gaine2[i].Enabled = v end
		for _, B in ipairs(E.br) do for _, b in ipairs(B.beams) do b.Enabled = v end end
	end
	E.visible = visible
	visible(false)
	return E
end
local eclairs = {}
local function zigzag(p0, p1, n, amp)
	local pts = {}
	local d = p1 - p0
	local perp1 = d:Cross(Vector3.new(0.3, 0, 1)).Unit
	local perp2 = d:Cross(perp1).Unit
	for i = 0, n do
		local t = i / n
		local k = math.sin(t * math.pi) ^ 0.7
		pts[i + 1] = p0 + d * t + (perp1 * rnd(-1, 1) + perp2 * rnd(-1, 1)) * amp * k
	end
	return pts
end
local function formeEclair(E, haut, impact)
	-- comme le rendu : un trait presque droit, legerement ondule, epais, a coeur blanc-rose et large lueur violette
	local pts = zigzag(haut, impact, SEG, (haut - impact).Magnitude * R.ECLAIR_ONDULATION)
	for i, a in ipairs(E.pts) do a.WorldPosition = pts[i] end
	for i, b in ipairs(E.beams) do
		local t = (i - 1) / SEG
		local w = R.ECLAIR_LARGEUR * (1.15 - 0.3 * t)
		b.Width0 = w * rnd(0.9, 1.1); b.Width1 = w * rnd(0.9, 1.1); b.Transparency = num(0)
		local g, g2 = E.gaine[i], E.gaine2[i]
		g.Width0 = b.Width0 * 2.4; g.Width1 = b.Width1 * 2.4; g.Transparency = num(0.55)
		g2.Width0 = b.Width0 * 5; g2.Width1 = b.Width1 * 5; g2.Transparency = num(0.9)
	end
	for _, B in ipairs(E.br) do
		local i0 = rng:NextInteger(3, SEG - 3)
		local p0 = pts[i0]
		local dir = (impact - haut).Unit * rnd(15, 40) + Vector3.new(rnd(-1, 1), 0, rnd(-1, 1)) * rnd(15, 35)
		local q = zigzag(p0, p0 + dir, BRSEG, dir.Magnitude * 0.12)
		for i, a in ipairs(B.pts) do a.WorldPosition = q[i] end
		for _, b in ipairs(B.beams) do b.Width0 = rnd(0.35, 0.7); b.Width1 = rnd(0.15, 0.4); b.Transparency = num(rnd(0, 0.3)) end
	end
end
local function jouerEclair(impact, force)
	local cam = workspace.CurrentCamera
	local dist = cam and (cam.CFrame.Position - impact).Magnitude or 0
	if dist > R.FLASH_DISTANCE * 1.5 then return end
	local E
	for _, e in ipairs(eclairs) do if e.libre then E = e break end end
	if not E then
		if #eclairs >= 2 then return end
		E = nouvelEclair(); table.insert(eclairs, E)
	end
	E.libre = false
	local haut = impact + Vector3.new(rnd(-18, 18), R.HAUTEUR_ECLAIR, rnd(-18, 18))
	E.impact.WorldPosition = impact
	formeEclair(E, haut, impact); E.visible(true)
	E.lumiere.Brightness = 10
	E.etinc:Emit(math.floor(45 * Q)); E.lueur:Emit(2); E.craq:Emit(math.max(2, math.floor(6 * Q)))
	if dist < R.FLASH_DISTANCE then flashCiel(force or 1) end
	if dist < R.SECOUSSE_DISTANCE then secousse = math.max(secousse, 1 - dist / R.SECOUSSE_DISTANCE) end
	local si = sonJoue(E.impact, son("Impact"), 1.2, 30, 350)
	if si then si:Play(); Debris:AddItem(si, 2) end
	local idT = son("Tonnerre")
	if idT then
		task.delay(math.min(dist / 1100, 2.5), function()
			local st = sonJoue(ancre, idT, 1.6, 150, 3000)
			if st then
				local a = Instance.new("Attachment"); a.WorldPosition = impact; a.Parent = ancre; st.Parent = a
				st:Play(); Debris:AddItem(a, 6)
			end
		end)
	end
	task.spawn(function()
		-- 3 scintillements (nouvelle forme a chaque fois), puis extinction
		for k = 1, 5 do
			task.wait(0.07 + rnd(0, 0.05))
			formeEclair(E, haut, impact)
			E.lumiere.Brightness = 10 - k * 1.2
		end
		for k = 1, 6 do
			task.wait(0.05)
			local tr = num(k / 6)
			for _, b in ipairs(E.beams) do b.Transparency = tr end
			for i, g in ipairs(E.gaine) do g.Transparency = num(0.55 + 0.45 * k / 6); E.gaine2[i].Transparency = num(0.9 + 0.1 * k / 6) end
			for _, B in ipairs(E.br) do for _, b in ipairs(B.beams) do b.Transparency = tr end end
			E.lumiere.Brightness = math.max(0, E.lumiere.Brightness - 1.2)
		end
		E.visible(false); E.lumiere.Brightness = 0
		E.libre = true
	end)
end

------------------------------------------------------------------ voitures electrifiees
local voitures = {}     -- modele -> etat

local function racineDe(m)
	if m.PrimaryPart then return m.PrimaryPart end
	local seat = m:FindFirstChildWhichIsA("VehicleSeat", true)
	local best, bv = seat, -1
	if not best then
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then local s = p.Size; local v = s.X * s.Y * s.Z; if v > bv then best, bv = p, v end end
		end
	end
	return best
end

-- points sur la carrosserie (repere de la racine) : rayons tires de l'exterieur vers la voiture
local function echantillonner(m, racine)
	local cf, taille = m:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {m}
	local pts, bas = {}, {}
	local rayon = taille.Magnitude
	for _ = 1, 70 do
		local dir = Vector3.new(rnd(-1, 1), rnd(-0.25, 1), rnd(-1, 1))
		if dir.Magnitude < 0.2 then continue end
		dir = dir.Unit
		local cible = cf:PointToWorldSpace(Vector3.new(rnd(-0.35, 0.35) * taille.X, rnd(-0.15, 0.3) * taille.Y, rnd(-0.4, 0.4) * taille.Z))
		local origine = cible + cf:VectorToWorldSpace(dir) * rayon
		local r = workspace:Raycast(origine, cible - origine, params)
		if r and r.Instance and r.Instance.Transparency < 0.9 then
			table.insert(pts, racine.CFrame:PointToObjectSpace(r.Position + r.Normal * 0.12))
			if #pts >= 22 then break end
		end
	end
	if #pts < 6 then     -- repli : coins de la boite
		pts = {}
		for _, sx in ipairs({-0.45, 0.45}) do for _, sy in ipairs({-0.3, 0.4}) do for _, sz in ipairs({-0.45, 0, 0.45}) do
			table.insert(pts, racine.CFrame:PointToObjectSpace(cf:PointToWorldSpace(Vector3.new(sx * taille.X, sy * taille.Y, sz * taille.Z))))
		end end end
	end
	-- points bas (vers le sol) : les plus bas dans le repere de la voiture
	local tri = {}
	for i, p in ipairs(pts) do tri[i] = {p = p, y = cf:PointToObjectSpace(racine.CFrame:PointToWorldSpace(p)).Y} end
	table.sort(tri, function(a, b) return a.y < b.y end)
	for i = 1, math.min(6, #tri) do bas[i] = tri[i].p end
	return pts, bas, taille, cf:PointToObjectSpace(racine.Position)
end

local function construireHalo(V)
	local m, racine = V.modele, V.racine
	local h = Instance.new("Highlight"); h.Name = "FoudreHalo"
	h.FillColor = R.COULEUR_CORPS or R.COULEUR; h.OutlineColor = R.COULEUR_COEUR
	h.FillTransparency = 0.55; h.OutlineTransparency = 0; h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = m; h.Enabled = false; h.Parent = m
	V.halo = h
	local c = Instance.new("Attachment"); c.Name = "FoudreCentre"; c.Parent = racine
	c.WorldPosition = (m:GetBoundingBox()).Position
	V.centre = c
	local l = Instance.new("PointLight"); l.Color = R.COULEUR; l.Range = math.clamp(V.taille.Magnitude * 1.6, 16, 45)
	l.Brightness = 0; l.Shadows = false; l.Enabled = false; l.Parent = c
	V.lumiere = l
end

local function construireComplet(V)
	local racine = V.racine
	V.atts = {}
	for i, p in ipairs(V.pts) do
		local a = Instance.new("Attachment"); a.Name = "FoudrePoint"; a.Position = p; a.Parent = racine; V.atts[i] = a
	end
	V.atBas = {}
	for i, p in ipairs(V.bas) do
		local a = Instance.new("Attachment"); a.Name = "FoudreBas"; a.Position = p; a.Parent = racine; V.atBas[i] = a
	end
	local echelle = math.clamp(V.taille.Magnitude / 20, 0.5, 2.5)
	V.echelle = echelle
	V.arcs = {}
	for i = 1, R.ARCS do
		local b = beam(V.atts[1], V.atts[2], "", racine); b.Enabled = false; b.Name = "FoudreArc"
		b.Color = seq(R.COULEUR_COEUR); b.Segments = 10; b.Brightness = 6
		V.arcs[i] = b
	end
	V.sol = {}
	for i = 1, R.ARCS_SOL do
		local g = Instance.new("Attachment"); g.Name = "FoudreSol"; g.Parent = ancre
		local b = beam(V.atBas[1] or V.atts[1], g, "", racine); b.Enabled = false; b.Name = "FoudreArcSol"
		b.Color = seq(R.COULEUR_COEUR); b.Brightness = 6
		V.sol[i] = {b = b, g = g}
	end
	-- emetteurs : 3 points de la carrosserie + le centre
	V.emet = {}
	for k = 1, 3 do
		local a = V.atts[rng:NextInteger(1, #V.atts)]
		local e1 = etincelles(a); e1.Size = num(0.3 * echelle, 0)
		local e2 = craquements(a); e2.Size = num(2 * echelle)
		table.insert(V.emet, {e = e1, taux = 10}); table.insert(V.emet, {e = e2, taux = 5})
	end
	local l = lueurs(V.centre); l.Size = num({kp(0, 5 * echelle), kp(1, 8 * echelle)})
	table.insert(V.emet, {e = l, taux = 2.5})
	V.fumee = fumee(V.centre)
	V.boucle = sonJoue(V.centre, son("Crepitement"), 0.7, 12, 90, true)
end

local function niveauVers(V, n)
	if V.niveau == n then return end
	if n >= 1 and not V.halo then construireHalo(V) end
	if n >= 2 and not V.arcs then construireComplet(V) end
	local h = n >= 1
	if V.halo then V.halo.Enabled = h; V.lumiere.Enabled = h end
	local c = n >= 2
	if V.arcs then
		for _, b in ipairs(V.arcs) do b.Enabled = c end
		for _, s in ipairs(V.sol) do s.b.Enabled = c end
		for _, x in ipairs(V.emet) do x.e.Rate = x.taux * Q; x.e.Enabled = c end
		if V.boucle then if c then if not V.boucle.IsPlaying then V.boucle:Play() end else V.boucle:Stop() end end
	end
	V.niveau = n
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function nouvelArc(V, b)
	local n = #V.atts
	local a0 = V.atts[rng:NextInteger(1, n)]
	local a1, dmax = nil, V.taille.Magnitude * 0.55
	for _ = 1, 6 do
		local c = V.atts[rng:NextInteger(1, n)]
		local d = (c.Position - a0.Position).Magnitude
		if c ~= a0 and d > 1 and d < dmax then a1 = c break end
	end
	if not a1 or rng:NextNumber() < 0.18 then b.Transparency = num(1) return end     -- trou : l'arc s'eteint un instant
	b.Attachment0, b.Attachment1 = a0, a1
	local d = (a1.Position - a0.Position).Magnitude
	b.CurveSize0 = rnd(-0.5, 0.5) * d; b.CurveSize1 = rnd(-0.5, 0.5) * d
	local w = rnd(0.16, 0.34) * V.echelle
	b.Width0 = w; b.Width1 = w * rnd(0.5, 1.1)
	b.Transparency = num({kp(0, rnd(0, 0.2)), kp(0.5, rnd(0, 0.3)), kp(1, rnd(0, 0.2))})
end
local function nouvelArcSol(V, s)
	local a0 = V.atBas[rng:NextInteger(1, math.max(1, #V.atBas))] or V.atts[1]
	local p = a0.WorldPosition
	params.FilterDescendantsInstances = {V.modele}
	local r = workspace:Raycast(p + Vector3.new(rnd(-3, 3), 0, rnd(-3, 3)) * V.echelle, Vector3.new(0, -8 * V.echelle, 0), params)
	if not r or rng:NextNumber() < 0.35 then s.b.Transparency = num(1) return end
	s.g.WorldPosition = r.Position
	s.b.Attachment0 = a0
	s.b.CurveSize0 = rnd(-1, 1); s.b.CurveSize1 = rnd(-1, 1)
	s.b.Width0 = rnd(0.2, 0.36) * V.echelle; s.b.Width1 = rnd(0.06, 0.14) * V.echelle
	s.b.Transparency = num(rnd(0, 0.25))
end

local function detruire(V, fondu)
	voitures[V.modele] = nil
	if V.connexions then for _, c in ipairs(V.connexions) do c:Disconnect() end end
	local objets = {}
	for _, x in ipairs({V.halo, V.centre}) do table.insert(objets, x) end
	for _, t in ipairs({V.atts or {}, V.atBas or {}, V.arcs or {}}) do for _, x in ipairs(t) do table.insert(objets, x) end end
	for _, s in ipairs(V.sol or {}) do table.insert(objets, s.b); table.insert(objets, s.g) end
	if fondu and V.centre and V.centre.Parent then
		-- extinction : les arcs s'arretent, petite fumee, la lumiere et le halo s'eteignent en 1 s
		if V.arcs then for _, b in ipairs(V.arcs) do b.Enabled = false end; for _, s in ipairs(V.sol) do s.b.Enabled = false end end
		if V.emet then for _, x in ipairs(V.emet) do x.e.Enabled = false end end
		if V.boucle then V.boucle:Stop() end
		if V.fumee then V.fumee:Emit(math.floor(10 * Q)) end
		if V.halo then TweenService:Create(V.halo, TweenInfo.new(1), {FillTransparency = 1, OutlineTransparency = 1}):Play() end
		if V.lumiere then TweenService:Create(V.lumiere, TweenInfo.new(1), {Brightness = 0}):Play() end
		for _, x in ipairs(objets) do Debris:AddItem(x, 3) end
	else
		for _, x in ipairs(objets) do x:Destroy() end
	end
end

local function electrifier(m, avecEclair)
	if voitures[m] then
		if avecEclair then
			local cf, t = m:GetBoundingBox(); jouerEclair(cf.Position + Vector3.new(0, t.Y / 2, 0), 1)
		end
		return
	end
	local racine = racineDe(m)
	if not racine then return end
	local pts, bas, taille = echantillonner(m, racine)
	local V = {modele = m, racine = racine, pts = pts, bas = bas, taille = taille, niveau = 0, prochainArc = 0}
	voitures[m] = V
	V.connexions = {
		m.AncestryChanged:Connect(function(_, parent) if not parent then detruire(V, false) end end),
	}
	if avecEclair then
		local cf, t = m:GetBoundingBox()
		jouerEclair(cf.Position + Vector3.new(0, t.Y / 2, 0), 1)
	end
end

------------------------------------------------------------------ boucle unique
local tLod, tArcs, tScint = 0, 0, 0
local function lod()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local o = cam.CFrame.Position
	local liste = {}
	for m, V in pairs(voitures) do
		if V.racine.Parent then
			V.dist = (V.racine.Position - o).Magnitude; table.insert(liste, V)
		end
	end
	table.sort(liste, function(a, b) return a.dist < b.dist end)
	for i, V in ipairs(liste) do
		local marge = (V.niveau == 2) and 15 or 0          -- hysteresis : pas de clignotement a la limite
		local n = 0
		if V.dist < R.DISTANCE_COMPLET + marge and i <= R.MAX_COMPLET then n = 2
		elseif V.dist < R.DISTANCE_HALO + marge and i <= R.MAX_HALO then n = 1 end
		niveauVers(V, n)
	end
end
RunService.Heartbeat:Connect(function(dt)
	tLod -= dt; tArcs -= dt; tScint -= dt
	if tLod <= 0 then tLod = 0.4; lod() end
	if tArcs <= 0 then
		tArcs = 1 / R.FREQUENCE_ARCS
		for _, V in pairs(voitures) do
			if V.niveau == 2 then
				-- chaque arc change de forme environ une fois sur deux : mouvement irregulier
				for _, b in ipairs(V.arcs) do if rng:NextNumber() < 0.55 then nouvelArc(V, b) end end
				for _, s in ipairs(V.sol) do if rng:NextNumber() < 0.3 then nouvelArcSol(V, s) end end
			end
		end
	end
	if tScint <= 0 then
		tScint = 0.05
		for _, V in pairs(voitures) do
			if V.niveau >= 1 then
				local fort = rng:NextNumber() < 0.12
				V.lumiere.Brightness = fort and rnd(5, 8) or rnd(1.2, 3.5)
				V.halo.FillTransparency = fort and 0.4 or rnd(0.5, 0.62)
				V.halo.OutlineTransparency = rnd(0, 0.15)
			end
		end
	end
end)

------------------------------------------------------------------ lancement
function Effet.lancer()
	if R.BLOOM ~= false and not Lighting:FindFirstChild("FoudreBloom") then
		local bl = Instance.new("BloomEffect"); bl.Name = "FoudreBloom"
		bl.Intensity = R.BLOOM_INTENSITE or 1; bl.Size = 48; bl.Threshold = 0.85; bl.Parent = Lighting
	end
	local function ajout(m)
		if not m:IsA("Model") then return end
		local t = m:GetAttribute("FoudreT")
		local recent = t and (workspace:GetServerTimeNow() - t) < 2
		electrifier(m, recent)
		-- nouvel eclair sur une voiture deja electrifiee
		local V = voitures[m]
		if V then
			table.insert(V.connexions, m:GetAttributeChangedSignal("FoudreT"):Connect(function()
				local t2 = m:GetAttribute("FoudreT")
				if t2 and workspace:GetServerTimeNow() - t2 < 2 then electrifier(m, true) end
			end))
		end
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(ajout)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
		local V = voitures[m]; if V then detruire(V, true) end
	end)
	for _, m in ipairs(CollectionService:GetTagged(TAG)) do task.spawn(ajout, m) end
	workspace:GetAttributeChangedSignal("FoudreOrage"):Connect(majAmbiance)
	majAmbiance()
	local dossier = script.Parent
	local ev = dossier:WaitForChild("FoudreSol", 10)
	if ev then ev.OnClientEvent:Connect(function(p) jouerEclair(p, 0.7) end) end
end

-- pour tester depuis la barre de commande d'un client : require(...).eclair(position)
Effet.eclair = jouerEclair
Effet._voitures = voitures
return Effet
