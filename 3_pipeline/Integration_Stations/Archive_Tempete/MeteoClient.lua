--[[ MeteoClient (LocalScript, StarterPlayerScripts) — rendu de la tempete chez chaque joueur.
	Sur ordre du serveur (RemoteEvent MeteoEvent) :
	  "tempete", true/false : le ciel se couvre en ~8 s (nuages noirs, brume, lumiere qui tombe, teinte violette), pluie
	                          battante autour de la camera, vent et pluie en boucle, grondements lointains ; retour au calme
	                          a la fin.
	  "eclair", position, voiture?, puissance : un eclair VIOLET en zigzag depuis le ciel jusqu'au point (ou la voiture),
	                          double flash blanc-violet, lumiere au sol, tonnerre retarde selon la distance (craquement sec
	                          si c'est tout pres), leger tremblement de camera ; si une voiture est visee : halo violet,
	                          etincelles et zap, puis lueur violette tant que son attribut "Electrique" est vrai.
	Tous les sons viennent de la bibliotheque libre Roblox (ProSoundEffects).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local MeteoEvent = ReplicatedStorage:WaitForChild("MeteoEvent")
local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local VIOLET = Color3.fromRGB(170, 80, 255)
local VIOLET_CLAIR = Color3.fromRGB(225, 190, 255)
local SONS = {
	pluie = "rbxassetid://9112853287",         -- Rain Heavy 1 (boucle)
	vent = "rbxassetid://9113286969",          -- Barstow Wind Light Blustery Low Howl 2 (boucle)
	tonnerres = {"rbxassetid://9120016037", "rbxassetid://9120016256", "rbxassetid://9120016241"},   -- Thunder Cracks Big Rumbling 1/3/4
	craquement = "rbxassetid://9126082854",    -- Synth Thunder Cracks Individual Explosion (eclair tout pres)
	zap = "rbxassetid://9114277402",           -- Electric Zaps 6 (voiture foudroyee)
}

-- ======================================================================================================================
-- SUPERCELLULE : un cumulonimbus geant au-dessus de la map qui TOURNE, en TEXTURES (pas de formes pleines) :
--   1) le plafond : deux disques immenses (2 800 studs) au-dessus de la map, texturés de nuages, qui tournent en sens
--      contraire a des vitesses differentes (effet de vortex par parallaxe) ;
--   2) les bandes : anneaux de Beams texturés (nuages etires, texture qui defile), de plus en plus bas, serres et rapides
--      vers le centre, legerement inclines vers l'interieur : c'est le mur de la supercellule ;
--   3) l'entonnoir : bandes en spirale qui descendent au centre, texture qui defile vers le bas ;
--   4) la masse : emetteurs de particules "nuage" (grosses volutes lentes qui tournent sur elles-memes) en orbite sur
--      trois anneaux ; les volutes sont eclairees par les flashs violets (LightInfluence).
-- Tout est local a chaque joueur (dossier sous la camera) ; apparition / disparition en fondu.
-- TEXTURES : par defaut celles livrees avec Roblox (toujours disponibles). Pour des textures de nuages plus riches,
-- publie des decals et colle leurs ID ici (TEXTURES.plafond / bande / volute).
-- ======================================================================================================================
local TEXTURES = {
	plafond = "rbxasset://textures/particles/smoke_main.dds",     -- disque du plafond (mosaique de volutes)
	bande = "rbxasset://textures/particles/smoke_main.dds",       -- bandes tournantes (Beams)
	volute = "rbxasset://textures/particles/smoke_main.dds",      -- particules
}
local CENTRE = Vector3.new(0, 0, 0)          -- centre de la map (la supercellule tourne au-dessus du rond-point)
local BASE_NUAGES = 330                       -- altitude de la base des nuages (les eclairs partent de la)
local super = nil

local function partInvisible(parent, cf)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 1; p.Size = Vector3.one; p.CFrame = cf or CFrame.new(); p.Parent = parent
	return p
end

-- anneau de Beams : n segments courbes entre attaches reparties sur un cercle (rayon r, altitude y), largeur w
local function anneauBeams(parent, r, y, n, w, inclinaison, vitesseTexture, couleur, transp)
	local attaches, beams = {}, {}
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi
		local pos = CENTRE + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		local p = partInvisible(parent, CFrame.new(pos))
		local att = Instance.new("Attachment"); att.Parent = p
		-- axe de l'attache : tangente au cercle, penchee vers le centre (le mur de nuages est un cone)
		local tangente = Vector3.new(-math.sin(a), 0, math.cos(a))
		local versCentre = Vector3.new(-math.cos(a), 0, -math.sin(a))
		att.CFrame = CFrame.fromMatrix(Vector3.zero, tangente, (Vector3.yAxis * math.cos(inclinaison) + versCentre * math.sin(inclinaison)).Unit)
		table.insert(attaches, {att = att, part = p, a = a})
	end
	for i = 1, n do
		local A, B = attaches[i], attaches[i % n + 1]
		local b = Instance.new("Beam")
		b.Attachment0 = A.att; b.Attachment1 = B.att
		b.Texture = TEXTURES.bande; b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = w * 1.4; b.TextureSpeed = vitesseTexture
		b.Width0 = w; b.Width1 = w
		b.CurveSize0 = r * 0.55 * (2 * math.pi / n); b.CurveSize1 = r * 0.55 * (2 * math.pi / n)   -- suit le cercle
		b.Color = ColorSequence.new(couleur)
		b.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, transp), NumberSequenceKeypoint.new(0.85, transp), NumberSequenceKeypoint.new(1, 1)})
		b.LightEmission = 0.05; b.LightInfluence = 0.9; b.FaceCamera = false; b.Segments = 12; b.ZOffset = 0
		b.Parent = A.part
		table.insert(beams, b)
	end
	return {attaches = attaches, beams = beams, r = r, y = y, n = n, transp = transp}
end

local function creerSupercellule()
	if super then return end
	local dossier = Instance.new("Folder"); dossier.Name = "Supercellule_Local"; dossier.Parent = camera
	local S = {dossier = dossier, plafonds = {}, anneaux = {}, orbites = {}, t = 0, fondu = 0, lumieres = {}}
	local SOMBRE = Color3.fromRGB(52, 42, 70)
	local CLAIR = Color3.fromRGB(98, 84, 122)

	-- 1) plafond : deux disques textures qui tournent en sens contraire
	for i, D in ipairs({{y = 700, tuile = 700, vit = 0.010, transp = 0.35, coul = SOMBRE, sens = 1}, {y = 640, tuile = 460, vit = 0.017, transp = 0.5, coul = CLAIR, sens = -1}}) do
		local disque = Instance.new("Part")
		disque.Anchored = true; disque.CanCollide = false; disque.CanQuery = false; disque.CanTouch = false; disque.CastShadow = false
		disque.Size = Vector3.new(3000, 2, 3000); disque.Material = Enum.Material.SmoothPlastic
		disque.Color = Color3.fromRGB(20, 16, 28); disque.Transparency = 1
		disque.CFrame = CFrame.new(CENTRE + Vector3.new(0, D.y, 0))
		disque.Parent = dossier
		local tex = Instance.new("Texture"); tex.Texture = TEXTURES.plafond; tex.Face = Enum.NormalId.Bottom
		tex.StudsPerTileU = D.tuile; tex.StudsPerTileV = D.tuile; tex.Color3 = D.coul; tex.Transparency = 1; tex.Parent = disque
		table.insert(S.plafonds, {part = disque, textures = {tex}, vit = D.vit * D.sens, transp = D.transp, angle = i, y = D.y})
	end

	-- 2) bandes : anneaux de Beams, du plus large et haut au plus serre et bas
	local ETAGES = {
		{r = 1150, y = 600, n = 20, w = 260, incl = 0.10, vt = 0.020, coul = SOMBRE, transp = 0.30},
		{r = 900,  y = 520, n = 18, w = 240, incl = 0.16, vt = 0.030, coul = CLAIR,  transp = 0.40},
		{r = 660,  y = 450, n = 16, w = 220, incl = 0.24, vt = 0.045, coul = SOMBRE, transp = 0.32},
		{r = 450,  y = 390, n = 14, w = 190, incl = 0.34, vt = 0.065, coul = CLAIR,  transp = 0.42},
		{r = 280,  y = 340, n = 12, w = 150, incl = 0.48, vt = 0.095, coul = SOMBRE, transp = 0.35},
	}
	for _, E in ipairs(ETAGES) do
		local A = anneauBeams(dossier, E.r, E.y, E.n, E.w, E.incl, E.vt, E.coul, E.transp)
		A.vit = E.vt * 0.9
		table.insert(S.anneaux, A)
	end
	-- 3) entonnoir : anneaux serres qui descendent, tres inclines, texture qui defile vers le bas
	for k = 0, 5 do
		local u = k / 5
		local A = anneauBeams(dossier, 170 - u * 110, 330 - u * 120, 10, 110 - u * 60, 0.9, 0.12 + u * 0.1, (k % 2 == 0) and SOMBRE or CLAIR, 0.30)
		A.vit = 0.14 + u * 0.12
		table.insert(S.anneaux, A)
	end

	-- 4) masse : emetteurs de volutes en orbite (3 anneaux), eclaires par les flashs
	for _, O in ipairs({{r = 1000, y = 560, n = 10, taille = 320, vit = 0.014}, {r = 700, y = 470, n = 9, taille = 280, vit = 0.024}, {r = 420, y = 380, n = 8, taille = 220, vit = 0.04}}) do
		for i = 1, O.n do
			local a = (i - 1) / O.n * 2 * math.pi
			local p = partInvisible(dossier, CFrame.new(CENTRE + Vector3.new(math.cos(a) * O.r, O.y, math.sin(a) * O.r)))
			local e = Instance.new("ParticleEmitter")
			e.Texture = TEXTURES.volute
			e.Rate = 0; e.Lifetime = NumberRange.new(9, 13); e.Speed = NumberRange.new(4, 9); e.SpreadAngle = Vector2.new(180, 180)
			e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, O.taille * 0.7), NumberSequenceKeypoint.new(0.5, O.taille), NumberSequenceKeypoint.new(1, O.taille * 0.8)})
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.42), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 1)})
			e.Color = ColorSequence.new(SOMBRE, CLAIR)
			e.RotSpeed = NumberRange.new(-8, 8); e.Rotation = NumberRange.new(0, 360)
			e.LightInfluence = 1; e.LightEmission = 0; e.Squash = NumberSequence.new(-0.35); e.ZOffset = -2
			e.Parent = p
			local lum = Instance.new("PointLight"); lum.Color = VIOLET; lum.Range = O.taille * 1.6; lum.Brightness = 0; lum.Enabled = false; lum.Shadows = false; lum.Parent = p
			table.insert(S.orbites, {part = p, e = e, r = O.r, y = O.y, a = a, vit = O.vit, taux = 1.2})
			table.insert(S.lumieres, lum)
		end
	end
	super = S
	-- flashs internes : un emetteur s'allume en violet (les volutes autour s'eclairent), souvent en double
	task.spawn(function()
		while super == S do
			task.wait(0.3 + math.random() * 1.1)
			if super ~= S then break end
			local lum = S.lumieres[math.random(1, #S.lumieres)]
			local function on(b) lum.Brightness = b; lum.Enabled = b > 0 end
			on(12); task.delay(0.07 + math.random() * 0.08, function() on(0) end)
			if math.random() < 0.4 then task.delay(0.16, function() on(7); task.delay(0.06, function() on(0) end) end) end
		end
	end)
end

local function animerSupercellule(dt)
	local S = super
	if not S then return end
	S.t += dt
	local cible = S.finir and 0 or 1
	S.fondu = S.fondu + (cible - S.fondu) * math.min(1, dt / 4)
	if S.finir and S.fondu < 0.02 then S.dossier:Destroy(); if super == S then super = nil end return end
	local f = S.fondu
	-- plafond : rotation lente, fondu
	for _, P in ipairs(S.plafonds) do
		P.angle += P.vit * dt
		P.part.CFrame = CFrame.new(CENTRE + Vector3.new(0, P.y, 0)) * CFrame.Angles(0, P.angle, 0)
		for _, t in ipairs(P.textures) do t.Transparency = 1 - (1 - P.transp) * f end
	end
	-- anneaux : rotation des attaches (les Beams suivent), fondu ; leger battement d'altitude
	for _, A in ipairs(S.anneaux) do
		local da = A.vit * dt
		for _, at in ipairs(A.attaches) do
			at.a += da
			local y = A.y + math.sin(S.t * 0.3 + at.a) * 6
			at.part.CFrame = CFrame.new(CENTRE + Vector3.new(math.cos(at.a) * A.r, y, math.sin(at.a) * A.r))
		end
		for _, b in ipairs(A.beams) do
			local tr = 1 - (1 - A.transp) * f
			b.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, tr), NumberSequenceKeypoint.new(0.85, tr), NumberSequenceKeypoint.new(1, 1)})
		end
	end
	-- emetteurs en orbite (vitesse tangentielle donnee aux volutes par l'orientation de la piece)
	for _, O in ipairs(S.orbites) do
		O.a += O.vit * dt
		local pos = CENTRE + Vector3.new(math.cos(O.a) * O.r, O.y, math.sin(O.a) * O.r)
		local tangente = Vector3.new(-math.sin(O.a), 0, math.cos(O.a))
		O.part.CFrame = CFrame.lookAt(pos, pos + tangente)
		O.e.Rate = O.taux * f
	end
end

local function finirSupercellule()
	if super then super.finir = true end
end

RunService.Heartbeat:Connect(animerSupercellule)

-- ======================================================================================================================
-- CIEL ET PLUIE
-- ======================================================================================================================
local origine = nil          -- reglages d'eclairage d'avant la tempete
local actif = false
local pluie, sonPluie, sonVent, grondements = nil, nil, nil, nil

local function son(id, parent, volume, boucle)
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = volume; s.Looped = boucle or false
	s.Parent = parent
	return s
end

local function tween(objet, props, duree)
	TweenService:Create(objet, TweenInfo.new(duree or 8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
end

local function atmosphere()
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if not a then a = Instance.new("Atmosphere"); a.Density = 0.3; a.Offset = 0.25; a.Color = Color3.fromRGB(199, 199, 199); a.Decay = Color3.fromRGB(106, 112, 125); a.Glare = 0; a.Haze = 0; a.Parent = Lighting end
	return a
end

local function nuages()
	local c = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not c then c = Instance.new("Clouds"); c.Cover = 0.5; c.Density = 0.7; c.Color = Color3.fromRGB(252, 255, 255); c.Parent = workspace.Terrain end
	return c
end

local function commencerTempete()
	if actif then return end
	actif = true
	local a, c = atmosphere(), nuages()
	origine = {
		Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
		ColorShift_Top = Lighting.ColorShift_Top, ExposureCompensation = Lighting.ExposureCompensation,
		Atm = {Density = a.Density, Haze = a.Haze, Color = a.Color, Decay = a.Decay, Glare = a.Glare},
		Nuages = {Cover = c.Cover, Density = c.Density, Color = c.Color, Enabled = c.Enabled},
	}
	c.Enabled = true
	creerSupercellule()
	tween(Lighting, {Brightness = math.max(0.3, Lighting.Brightness * 0.25), Ambient = Color3.fromRGB(40, 32, 60), OutdoorAmbient = Color3.fromRGB(60, 50, 90), ColorShift_Top = Color3.fromRGB(120, 80, 170), ExposureCompensation = Lighting.ExposureCompensation - 0.6}, 8)
	tween(a, {Density = 0.62, Haze = 6, Color = Color3.fromRGB(90, 80, 110), Decay = Color3.fromRGB(50, 40, 70), Glare = 0}, 8)
	tween(c, {Cover = 1, Density = 0.95, Color = Color3.fromRGB(38, 30, 52)}, 8)

	-- pluie : emetteur au-dessus de la camera (suit la camera), gouttes etirees dans le sens de la chute
	pluie = Instance.new("Part"); pluie.Name = "Pluie"; pluie.Anchored = true; pluie.CanCollide = false; pluie.CanQuery = false; pluie.CanTouch = false
	pluie.Transparency = 1; pluie.Size = Vector3.new(160, 1, 160); pluie.Parent = camera
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0; e.Lifetime = NumberRange.new(1.1, 1.4); e.Speed = NumberRange.new(90, 110)
	e.Acceleration = Vector3.new(6, -40, 0); e.SpreadAngle = Vector2.new(3, 3); e.EmissionDirection = Enum.NormalId.Bottom
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.12)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.75)})
	e.Color = ColorSequence.new(Color3.fromRGB(200, 205, 230))
	e.LightEmission = 0.2; e.Squash = NumberSequence.new(2.5); e.Parent = pluie
	TweenService:Create(e, TweenInfo.new(6), {Rate = 900}):Play()

	sonPluie = son(SONS.pluie, SoundService, 0, true); sonPluie:Play(); tween(sonPluie, {Volume = 0.45}, 6)
	sonVent = son(SONS.vent, SoundService, 0, true); sonVent:Play(); tween(sonVent, {Volume = 0.35}, 6)
	-- grondements lointains
	grondements = task.spawn(function()
		while actif do
			task.wait(6 + math.random() * 10)
			if not actif then break end
			local g = son(SONS.tonnerres[math.random(1, #SONS.tonnerres)], SoundService, 0.15 + math.random() * 0.15, false)
			g.PlaybackSpeed = 0.75 + math.random() * 0.2
			g.PlayOnRemove = false; g:Play(); g.Ended:Once(function() g:Destroy() end)
		end
	end)
end

local function finirTempete()
	if not actif then return end
	actif = false
	finirSupercellule()
	local a, c = atmosphere(), nuages()
	if origine then
		tween(Lighting, {Brightness = origine.Brightness, Ambient = origine.Ambient, OutdoorAmbient = origine.OutdoorAmbient, ColorShift_Top = origine.ColorShift_Top, ExposureCompensation = origine.ExposureCompensation}, 10)
		tween(a, origine.Atm, 10)
		tween(c, {Cover = origine.Nuages.Cover, Density = origine.Nuages.Density, Color = origine.Nuages.Color}, 10)
		task.delay(10.5, function() if not actif then c.Enabled = origine.Nuages.Enabled end end)
	end
	if pluie then
		local e = pluie:FindFirstChildOfClass("ParticleEmitter")
		if e then TweenService:Create(e, TweenInfo.new(6), {Rate = 0}):Play() end
		local p = pluie; pluie = nil
		task.delay(8, function() p:Destroy() end)
	end
	for _, s in ipairs({sonPluie, sonVent}) do
		if s then tween(s, {Volume = 0}, 6); task.delay(6.5, function() s:Destroy() end) end
	end
	sonPluie, sonVent = nil, nil
end

-- la pluie suit la camera
RunService.RenderStepped:Connect(function()
	if pluie then pluie.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 70, 0)) end
end)

-- ======================================================================================================================
-- ECLAIRS
-- ======================================================================================================================
local dossierEclairs = Instance.new("Folder"); dossierEclairs.Name = "Eclairs_Local"; dossierEclairs.Parent = camera

local function segment(a, b, epaisseur, parent)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = VIOLET_CLAIR
	p.Size = Vector3.new(epaisseur, epaisseur, (b - a).Magnitude)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	p.Parent = parent
	return p
end

local function zigzag(depart, arrivee, n, amplitude)
	local pts = {depart}
	for i = 1, n - 1 do
		local t = i / n
		local base = depart:Lerp(arrivee, t)
		local k = amplitude * (1 - 0.6 * t)
		table.insert(pts, base + Vector3.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * k * 0.4, (math.random() - 0.5) * 2 * k))
	end
	table.insert(pts, arrivee)
	return pts
end

local function flash(intensite)
	local b0 = Lighting.Brightness
	local amb = Lighting.Ambient
	Lighting.Brightness = b0 + 4 * intensite
	Lighting.Ambient = Color3.fromRGB(190, 150, 255)
	task.delay(0.06, function()
		Lighting.Brightness = b0 + 1.2 * intensite; Lighting.Ambient = amb
		task.delay(0.05, function()
			Lighting.Brightness = b0 + 3 * intensite
			task.delay(0.08, function() Lighting.Brightness = b0 end)
		end)
	end)
end

local function secousse(force)
	local hum = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local dt = os.clock() - t0
		if dt > 0.5 then conn:Disconnect(); hum.CameraOffset = Vector3.zero return end
		local k = force * (1 - dt / 0.5)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
end

local function voitureElectrique(voiture, position)
	local racine = voiture.PrimaryPart or voiture:FindFirstChildWhichIsA("BasePart")
	if not racine then return end
	local halo = Instance.new("Highlight"); halo.FillColor = VIOLET; halo.OutlineColor = VIOLET_CLAIR
	halo.FillTransparency = 0.2; halo.OutlineTransparency = 0; halo.Parent = voiture
	local etincelles = Instance.new("ParticleEmitter")
	etincelles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	etincelles.Color = ColorSequence.new(VIOLET_CLAIR, VIOLET); etincelles.LightEmission = 1
	etincelles.Rate = 120; etincelles.Lifetime = NumberRange.new(0.3, 0.7); etincelles.Speed = NumberRange.new(15, 30)
	etincelles.SpreadAngle = Vector2.new(180, 180); etincelles.Size = NumberSequence.new(0.6, 0.1)
	etincelles.Parent = racine
	local z = son(SONS.zap, racine, 1, false); z:Play(); z.Ended:Once(function() z:Destroy() end)
	-- 6 s d'orage sur la voiture, puis simple lueur tant qu'elle est "Electrique"
	task.delay(6, function()
		etincelles.Rate = 12
		TweenService:Create(halo, TweenInfo.new(2), {FillTransparency = 0.75, OutlineTransparency = 0.3}):Play()
		local conn
		conn = voiture:GetAttributeChangedSignal("Electrique"):Connect(function()
			if not voiture:GetAttribute("Electrique") then
				conn:Disconnect(); halo:Destroy(); etincelles:Destroy()
			end
		end)
		if not voiture:GetAttribute("Electrique") then conn:Disconnect(); halo:Destroy(); etincelles:Destroy() end
	end)
end

local function eclair(position, voiture, puissance)
	puissance = puissance or 1
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart")
	local distance = racine and (racine.Position - position).Magnitude or 500
	-- trace principale + 2 branches
	local groupe = Instance.new("Folder"); groupe.Parent = dossierEclairs
	-- depart dans la base des nuages, legerement decale ; coeur blanc-violet fin + gaine violette large et translucide
	local sommet = Vector3.new(position.X + (math.random() - 0.5) * 140, BASE_NUAGES + 20 + math.random() * 40, position.Z + (math.random() - 0.5) * 140)
	local pts = zigzag(sommet, position, 11, 30)
	for i = 1, #pts - 1 do
		local ep = 2.0 * puissance * (1 - 0.5 * (i / #pts))
		segment(pts[i], pts[i + 1], math.max(0.4, ep), groupe)
		local gaine = segment(pts[i], pts[i + 1], math.max(1.2, ep * 3.2), groupe)
		gaine.Color = VIOLET; gaine.Transparency = 0.72; gaine.Name = "Gaine"
	end
	for _ = 1, 3 do
		local i = math.random(3, #pts - 3)
		local fin = pts[i] + Vector3.new((math.random() - 0.5) * 90, -50 - math.random() * 60, (math.random() - 0.5) * 90)
		local br = zigzag(pts[i], fin, 5, 14)
		for j = 1, #br - 1 do
			segment(br[j], br[j + 1], 0.6 * puissance, groupe)
			local g = segment(br[j], br[j + 1], 1.8 * puissance, groupe); g.Color = VIOLET; g.Transparency = 0.8; g.Name = "Gaine"
		end
	end
	-- deuxieme coup (re-frappe) une fois sur trois : la meme trace re-eclaire 0,2 s plus tard
	local refrappe = math.random() < 0.34
	local lum = Instance.new("PointLight"); lum.Color = VIOLET; lum.Brightness = 6 * puissance; lum.Range = 140
	local support = Instance.new("Part"); support.Anchored = true; support.CanCollide = false; support.CanQuery = false; support.Transparency = 1
	support.Size = Vector3.one; support.CFrame = CFrame.new(position + Vector3.new(0, 8, 0)); support.Parent = groupe; lum.Parent = support
	flash(puissance * math.clamp(1.2 - distance / 900, 0.2, 1))
	if distance < 220 then secousse(1.6 * puissance * (1 - distance / 220)) end
	-- extinction en deux temps (re-flash plus faible), puis eventuelle re-frappe
	local function montrer(k)
		for _, p in ipairs(groupe:GetChildren()) do
			if p:IsA("Part") and p ~= support then
				if p.Name == "Gaine" then p.Transparency = 1 - (1 - 0.72) * k else p.Transparency = 1 - k end
			end
		end
		lum.Brightness = 6 * puissance * k
	end
	task.delay(0.12, function()
		montrer(0.4)
		task.delay(0.06, function()
			montrer(0.85)
			task.delay(0.1, function()
				if refrappe then
					montrer(0)
					task.delay(0.2, function()
						montrer(1); flash(puissance * 0.7)
						task.delay(0.15, function() groupe:Destroy() end)
					end)
				else
					groupe:Destroy()
				end
			end)
		end)
	end)
	-- tonnerre : retard selon la distance (~1 s pour 300 studs, 3 s maxi), fort et sec si tout pres
	local retard = math.min(3, distance / 300)
	task.delay(retard, function()
		local id = (distance < 160) and SONS.craquement or SONS.tonnerres[math.random(1, #SONS.tonnerres)]
		local vol = math.clamp(1.1 - distance / 1200, 0.15, 1) * puissance
		local t = son(id, SoundService, vol, false)
		t.PlaybackSpeed = (distance < 160) and 1 or (0.85 + math.random() * 0.2)
		t:Play(); t.Ended:Once(function() t:Destroy() end)
	end)
	if voiture and voiture.Parent then voitureElectrique(voiture, position) end
end

-- ======================================================================================================================
MeteoEvent.OnClientEvent:Connect(function(action, a, b, c)
	if action == "tempete" then
		if a then commencerTempete() else finirTempete() end
	elseif action == "eclair" then
		eclair(a, b, c)
	end
end)
if workspace:GetAttribute("Tempete") then commencerTempete() end
