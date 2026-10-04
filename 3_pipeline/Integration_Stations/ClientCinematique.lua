--[[ ClientCinematique (LocalScript, StarterPlayerScripts) — v50 (v55 : ~8 s, plus nerveuse) : cinematiques de DECOUVERTE d'une voiture.
	La premiere fois qu'un joueur voit un modele a cinematique (CarManager.CINEMATIQUES : GT3 pour l'instant), le serveur
	laisse la voiture dans le tunnel et envoie CinematiqueEvent("voiture", voiture, nom). Ici, sequence "HYPERESPACE" :
	  1. coupe : la camera est devant la voiture, dans l'ESPACE (boite noire, etoiles) sur une route sombre ; titre
	     "PORSCHE 911 GT3 — nouveau modele debloque" ; moteur qui monte ;
	  2. la voiture accelere de plus en plus (bandes de la route qui defilent, roues qui tournent, etoiles qui s'etirent
	     en traits comme un saut en hyperespace, flammes bleues a l'arriere), la camera tourne autour d'elle en reculant,
	     champ de vision qui s'ouvre, tremblement ;
	  3. flash blanc ;
	  4. retour sur la VRAIE voiture a la sortie du tunnel, qui demarre sur la route (la camera la suit 3 s), puis la camera
	     revient au personnage.
	Tout est local au client (scene construite a 4 000 studs d'altitude, detruite a la fin) ; bouton "Passer" / Echap.
	Sons : Sounds.moteurGT3 (sinon Sounds.engine), Sounds.clac (phares ; sinon switch.wav), Sounds.hyper (facultatif).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Event = ReplicatedStorage:WaitForChild("CinematiqueEvent", 30)
if not Event then return end
local Car = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Car"))

local POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
-- v51 (Thomas) : noir -> "clac" les phares s'allument -> la voiture dans l'espace accelere (roues, moteur), la camera tourne
-- autour et se met DANS SON DOS -> hyperespace -> flash -> la map apparait depuis le meme angle, derriere la vraie voiture.
-- v55 (Thomas) : la meme sequence, plus courte (~8 s au lieu de ~14) et plus nerveuse : clac plus tot, acceleration
-- immediate, camera qui plonge le long du flanc (passage pres de la roue) avant de se caler dans le dos, traits
-- d'hyperespace des la moitie, tremblement et champ de vision plus marques, saut en hyperespace conserve + flash.
local T_CLAC = 0.7                 -- instant ou les phares s'allument (secondes)
local T_ACCEL = 1.1                -- debut de l'acceleration (etoiles, moteur)
local DUREE_HYPER = 6.0            -- fin de la partie "espace" (flash)
local DUREE_FLASH = 0.4            -- montee du flash blanc
local DUREE_RETOUR = 1.5           -- camera derriere la vraie voiture qui demarre (la map se revele)
local DUREE_RACCORD = 0.7          -- retour en douceur a la camera du joueur
local BASE = CFrame.new(0, 4000, 0) -- ou l'on construit la scene (loin de tout)
local VITESSE_MAX = 2200           -- studs/s "virtuels" au maximum
-- camera finale (repere de la voiture : Root regarde l'avant) : derriere et au-dessus, meme angle dans l'espace et sur la map
local CAM_DOS = Vector3.new(0, 4.2, 17)

local TITRES = {
	GT3 = { titre = "PORSCHE 911 GT3", sous = "NOUVEAU MODÈLE DÉBLOQUÉ  ·  LÉGENDAIRE" },
}

local function sons()
	local ok, S = pcall(function()
		return require(joueur:WaitForChild("PlayerGui"):WaitForChild("UIController", 10):WaitForChild("Sounds", 10))
	end)
	return ok and S or {}
end

local function estRoue(n)
	n = string.lower(n)
	return n:find("wheel") or n:find("roue") or n:find("pneu") or n:find("tire") or n:find("tyre")
end

local function genreRoue(n)
	n = string.upper(n)
	if n:find("FL") or n:find("FR") or n:find("AV") or n:find("FRONT") then return 1 end
	if n:find("RL") or n:find("RR") or n:find("AR") or n:find("REAR") or n:find("BACK") then return -1 end
	return 0
end
-- direction avant d'un modele d'apres ses roues (centre des roues avant - centre des roues arriere), nil si inconnue
local function sensDeMarche(car)
	local sAV, nAV, sAR, nAR = Vector3.zero, 0, Vector3.zero, 0
	for _, p in ipairs(car:GetDescendants()) do
		if p:IsA("BasePart") then
			local cle = nil
			local a = p.Parent
			while a and a ~= car do
				if a:IsA("Model") and estRoue(a.Name) then cle = a.Name end
				a = a.Parent
			end
			if not cle and estRoue(p.Name) then cle = p.Name end
			if cle then
				local g = genreRoue(cle)
				if g == 1 then sAV += p.Position; nAV += 1 elseif g == -1 then sAR += p.Position; nAR += 1 end
			end
		end
	end
	if nAV == 0 or nAR == 0 then return nil end
	local d = sAV / nAV - sAR / nAR
	d = Vector3.new(d.X, 0, d.Z)
	if d.Magnitude < 0.5 then return nil end
	return d.Unit
end

local function lisse(u) u = math.clamp(u, 0, 1); return u * u * (3 - 2 * u) end

-- taille d'un modele dans un repere donne (X = largeur, Y = hauteur, Z = longueur, le repere regardant l'avant) :
-- GetBoundingBox est aligne sur le monde, ce qui mettait les projecteurs des phares sur les roues d'une voiture tournee.
local function tailleDans(modele, cf)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = cf:ToObjectSpace(d.CFrame)
			local h = d.Size / 2
			local ex = Vector3.new(math.abs(rel.XVector.X) * h.X + math.abs(rel.YVector.X) * h.Y + math.abs(rel.ZVector.X) * h.Z,
				math.abs(rel.XVector.Y) * h.X + math.abs(rel.YVector.Y) * h.Y + math.abs(rel.ZVector.Y) * h.Z,
				math.abs(rel.XVector.Z) * h.X + math.abs(rel.YVector.Z) * h.Y + math.abs(rel.ZVector.Z) * h.Z)
			mn = mn:Min(rel.Position - ex); mx = mx:Max(rel.Position + ex)
		end
	end
	if mn.X == math.huge then return Vector3.new(8, 4, 16) end
	return mx - mn
end

-- ======================================================================================================================
-- interface : bandes noires, titre, flash, bouton Passer
-- ======================================================================================================================
local function interface(nom)
	local gui = Instance.new("ScreenGui"); gui.Name = "CinematiqueVoiture"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 130; gui.ResetOnSpawn = false
	for _, h in ipairs({0, 1}) do
		local b = Instance.new("Frame"); b.Name = h == 0 and "Haut" or "Bas"; b.BackgroundColor3 = Color3.new(0, 0, 0); b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, h); b.Position = UDim2.fromScale(0, h); b.Size = UDim2.new(1, 0, 0, 0); b.ZIndex = 5; b.Parent = gui
		TweenService:Create(b, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0.12, 0)}):Play()
	end
	local noir = Instance.new("Frame"); noir.Name = "Noir"; noir.BackgroundColor3 = Color3.new(0, 0, 0); noir.BorderSizePixel = 0
	noir.Size = UDim2.fromScale(1, 1); noir.BackgroundTransparency = 0; noir.ZIndex = 3; noir.Parent = gui
	local flash = Instance.new("Frame"); flash.Name = "Flash"; flash.BackgroundColor3 = Color3.new(1, 1, 1); flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1); flash.BackgroundTransparency = 1; flash.ZIndex = 10; flash.Parent = gui
	local T = TITRES[nom] or { titre = string.upper(nom), sous = "NOUVEAU MODÈLE DÉBLOQUÉ" }
	local tier = Car.TierDe(nom)
	local couleur = (tier and Car[tier] and Car[tier].Couleur) or Color3.new(1, 1, 1)
	local titre = Instance.new("TextLabel"); titre.Name = "Titre"; titre.BackgroundTransparency = 1; titre.AnchorPoint = Vector2.new(0.5, 1)
	titre.Position = UDim2.new(0.5, 0, 0.86, 0); titre.Size = UDim2.new(0.9, 0, 0, 64); titre.TextColor3 = Color3.new(1, 1, 1)
	titre.TextStrokeTransparency = 0.4; titre.FontFace = POLICE; titre.TextSize = 54; titre.Text = T.titre; titre.TextTransparency = 1; titre.ZIndex = 6; titre.Parent = gui
	local sous = Instance.new("TextLabel"); sous.Name = "Sous"; sous.BackgroundTransparency = 1; sous.AnchorPoint = Vector2.new(0.5, 0)
	sous.Position = UDim2.new(0.5, 0, 0.86, 2); sous.Size = UDim2.new(0.9, 0, 0, 26); sous.TextColor3 = couleur
	sous.TextStrokeTransparency = 0.5; sous.FontFace = POLICE; sous.TextSize = 20; sous.Text = T.sous; sous.TextTransparency = 1; sous.ZIndex = 6; sous.Parent = gui
	local passer = Instance.new("TextButton"); passer.Name = "Passer"; passer.AnchorPoint = Vector2.new(1, 0); passer.Position = UDim2.new(1, -18, 0.12, 10)
	passer.Size = UDim2.fromOffset(120, 34); passer.BackgroundColor3 = Color3.new(0, 0, 0); passer.BackgroundTransparency = 0.45; passer.BorderSizePixel = 0
	passer.Text = "Passer  ▸"; passer.TextColor3 = Color3.new(1, 1, 1); passer.FontFace = POLICE; passer.TextSize = 18; passer.AutoButtonColor = true; passer.ZIndex = 12; passer.Parent = gui
	Instance.new("UICorner", passer).CornerRadius = UDim.new(0, 10)
	gui.Parent = joueur:WaitForChild("PlayerGui")
	return gui
end

-- ======================================================================================================================
-- scene : l'espace (boite noire + etoiles + traits d'hyperespace) et la copie de la voiture ; pas de route (Thomas)
-- ======================================================================================================================
local function part(parent, nom, taille, cf, couleur, materiau, transparence)
	local p = Instance.new("Part"); p.Name = nom; p.Size = taille; p.CFrame = cf
	p.Color = couleur or Color3.new(0, 0, 0); p.Material = materiau or Enum.Material.SmoothPlastic; p.Transparency = transparence or 0
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth; p.Parent = parent
	return p
end

local function estPhare(n)
	n = string.lower(n)
	return n:find("phare") or n:find("headlight") or n:find("head_light") or n:find("lamp") or n:find("light")
end

-- allume les phares d'un modele (pieces "phare"...) : Neon blanc + 2 projecteurs vers l'avant. Renvoie une fonction qui eteint.
local function allumerPhares(modele, rootCF, taille)
	local etat = {}
	local lumieres = {}
	for _, d in ipairs(modele:GetDescendants()) do
		if d:IsA("BasePart") and estPhare(d.Name) and not estRoue(d.Name) then
			table.insert(etat, {part = d, mat = d.Material, couleur = d.Color, sa = d:FindFirstChildOfClass("SurfaceAppearance")})
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			if sa then sa.Parent = nil end                  -- la texture masquerait le Neon
			d.Material = Enum.Material.Neon; d.Color = Color3.fromRGB(255, 252, 240)
		end
	end
	-- projecteurs (meme si aucune piece "phare" n'a ete trouvee)
	local avant = rootCF * CFrame.new(0, 2.0, -taille.Z / 2 + 0.6)
	for _, x in ipairs({-taille.X / 2 + 1.4, taille.X / 2 - 1.4}) do
		local a = Instance.new("Attachment"); a.Name = "PhareCine"; a.WorldCFrame = avant * CFrame.new(x, 0, 0)
		local root = modele.PrimaryPart or modele:FindFirstChildWhichIsA("BasePart")
		a.Parent = root
		local sl = Instance.new("SpotLight"); sl.Angle = 75; sl.Range = 140; sl.Brightness = 8; sl.Color = Color3.fromRGB(255, 250, 235); sl.Face = Enum.NormalId.Front; sl.Parent = a
		table.insert(lumieres, a)
	end
	return function()
		for _, e in ipairs(etat) do
			if e.part.Parent then e.part.Material = e.mat; e.part.Color = e.couleur; if e.sa then e.sa.Parent = e.part end end
		end
		for _, a in ipairs(lumieres) do a:Destroy() end
	end
end

local function scene(carSource, nom)
	local S = { dossier = Instance.new("Folder") }
	S.dossier.Name = "CinematiqueScene"; S.dossier.Parent = workspace
	local D = 280                                        -- demi-cote de la boite noire
	local noir = Color3.fromRGB(1, 1, 3)
	for _, m in ipairs({{Vector3.new(0, D, 0), Vector3.new(2 * D, 1, 2 * D)}, {Vector3.new(0, -D, 0), Vector3.new(2 * D, 1, 2 * D)},
		{Vector3.new(D, 0, 0), Vector3.new(1, 2 * D, 2 * D)}, {Vector3.new(-D, 0, 0), Vector3.new(1, 2 * D, 2 * D)},
		{Vector3.new(0, 0, D), Vector3.new(2 * D, 2 * D, 1)}, {Vector3.new(0, 0, -D), Vector3.new(2 * D, 2 * D, 1)}}) do
		part(S.dossier, "Espace", m[2], BASE * CFrame.new(m[1]), noir)
	end
	-- etoiles fixes (apparaissent a T_ACCEL : avant, c'est le noir complet)
	local volume = part(S.dossier, "Etoiles", Vector3.new(2 * D - 10, 2 * D - 10, 2 * D - 10), BASE, noir, nil, 1)
	local etoiles = Instance.new("ParticleEmitter")
	etoiles.Shape = Enum.ParticleEmitterShape.Box; etoiles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	etoiles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	etoiles.Color = ColorSequence.new(Color3.fromRGB(230, 236, 255)); etoiles.LightEmission = 1
	etoiles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.1)})
	etoiles.Lifetime = NumberRange.new(60, 60); etoiles.Speed = NumberRange.new(0, 0); etoiles.Enabled = false
	etoiles.Rate = 700; etoiles.Transparency = NumberSequence.new(0.1); etoiles.Parent = volume
	S.etoiles = etoiles
	-- traits d'hyperespace : emis loin devant la voiture, ils foncent vers elle (et vers la camera, qui finit derriere)
	S.traits = {}
	for _, dx in ipairs({-70, 0, 70}) do
		for _, dy in ipairs({-20, 30}) do
			local src = part(S.dossier, "SourceTraits", Vector3.new(160, 110, 1), BASE * CFrame.new(dx, dy, -D + 20), noir, nil, 1)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 170, 255))})
			e.LightEmission = 1; e.Orientation = Enum.ParticleOrientation.VelocityParallel
			e.Size = NumberSequence.new(0.4); e.Lifetime = NumberRange.new(1.0, 1.6); e.Speed = NumberRange.new(60, 80)
			e.EmissionDirection = Enum.NormalId.Back
			e.Rate = 0; e.Squash = NumberSequence.new(0); e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
			e.Parent = src
			table.insert(S.traits, e)
		end
	end
	-- la voiture : copie (regarde -Z, a l'origine locale), eteinte dans le noir
	local ok, copie = pcall(function()
		carSource.Archivable = true
		return carSource:Clone()
	end)
	if ok and copie then
		for _, d in ipairs(copie:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false
			elseif d:IsA("Sound") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("SpotLight") or d:IsA("PointLight") or d:IsA("SurfaceLight") then d:Destroy() end
		end
		local voulu = Car.Longueur and Car.Longueur(nom)
		local ext = copie:GetExtentsSize()
		local L = math.max(ext.X, ext.Z)
		if voulu and L > 0 and math.abs(L - voulu) > 0.3 then pcall(function() copie:ScaleTo(copie:GetScale() * voulu / L) end) end
		local root = copie:FindFirstChild("Root") or copie.PrimaryPart
		local centre, taille = copie:GetBoundingBox()
		local rootCF
		if root then
			rootCF = root.CFrame
		else
			local avant = sensDeMarche(copie) or ((taille.X > taille.Z) and centre.RightVector or centre.LookVector)
			avant = Vector3.new(avant.X, 0, avant.Z)
			if avant.Magnitude < 1e-3 then avant = Vector3.new(0, 0, -1) end
			local bas = centre.Position - Vector3.new(0, taille.Y / 2, 0)
			rootCF = CFrame.lookAt(bas, bas + avant.Unit)
		end
		copie:PivotTo(CFrame.lookAt(BASE.Position, BASE.Position + Vector3.new(0, 0, -1)) * (rootCF:Inverse() * copie:GetPivot()))
		copie.Parent = S.dossier
		S.ref = CFrame.lookAt(BASE.Position, BASE.Position + Vector3.new(0, 0, -1))      -- repere "Root" de la copie
		taille = tailleDans(copie, S.ref)                                                 -- v55 : taille dans le repere de la voiture
		S.voiture = copie; S.taille = taille
		if not copie.PrimaryPart then copie.PrimaryPart = copie:FindFirstChildWhichIsA("BasePart") end
		-- roues (pieces nommees roue/wheel) : on les fait tourner nous-memes
		S.roues = {}
		for _, d in ipairs(copie:GetDescendants()) do
			if d:IsA("BasePart") then
				local nomRoue = nil
				local a = d
				while a and a ~= copie do if (a:IsA("Model") or a:IsA("BasePart")) and estRoue(a.Name) then nomRoue = a.Name end a = a.Parent end
				if nomRoue then
					local groupe = nil
					for _, g in ipairs(S.roues) do if g.nom == nomRoue then groupe = g end end
					if not groupe then groupe = {nom = nomRoue, pieces = {}, somme = Vector3.zero, n = 0, rayon = 1}; table.insert(S.roues, groupe) end
					table.insert(groupe.pieces, {part = d, offset = S.ref:ToObjectSpace(d.CFrame)})
					groupe.somme += S.ref:PointToObjectSpace(d.Position); groupe.n += 1
					groupe.rayon = math.max(groupe.rayon, math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2)
				end
			end
		end
		for _, g in ipairs(S.roues) do g.centre = g.somme / g.n end
		-- lumiere d'ambiance tres faible (la voiture se devine dans le noir), montee quand les phares s'allument
		local lampe = part(S.dossier, "Lampe", Vector3.new(1, 1, 1), S.ref * CFrame.new(0, 16, 6), Color3.new(0, 0, 0), nil, 1)
		local pl = Instance.new("PointLight"); pl.Range = 70; pl.Brightness = 0.15; pl.Color = Color3.fromRGB(150, 170, 255); pl.Parent = lampe
		S.lampe = pl
		-- flammes bleues a l'arriere (boost) : rate monte avec la vitesse
		S.boost = {}
		for _, x in ipairs({-1.6, 1.6}) do
			local ech = part(S.dossier, "Echappement", Vector3.new(0.4, 0.4, 0.4), S.ref * CFrame.new(x, 1.0, taille.Z / 2 + 0.2), Color3.new(0, 0, 0), nil, 1)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/fire_main.dds"
			e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 60, 255))})
			e.LightEmission = 1; e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.2)})
			e.Lifetime = NumberRange.new(0.15, 0.3); e.Speed = NumberRange.new(40, 70); e.Rate = 0; e.EmissionDirection = Enum.NormalId.Back
			e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)}); e.Parent = ech
			table.insert(S.boost, e)
		end
	end
	return S
end

-- ======================================================================================================================
-- la sequence
-- ======================================================================================================================
local enCours = false

-- camera "dans le dos" : CAM_DOS dans le repere de la voiture (Root regarde l'avant), regard vers l'avant de la voiture
local function cameraDos(refCF, melange)
	-- melange 0 = devant (face a la voiture), 1 = derriere ; l'angle tourne autour de la voiture par la droite.
	-- v55 : au milieu du mouvement la camera plonge pres du sol le long du flanc (passage au ras de la roue), puis remonte.
	local a = math.pi * (1 - melange)                                     -- pi = devant, 0 = derriere (en repere Root : +Z = derriere)
	local creux = math.sin(math.pi * melange)                             -- 0 aux extremites, 1 au milieu
	local d = 15 + 2 * melange - 8.5 * creux                              -- se rapproche jusqu'a ~7 studs au passage sur le flanc
	local h = 1.6 + (CAM_DOS.Y - 1.6) * melange - 1.0 * creux             -- descend presque au ras du sol
	local pose = refCF * CFrame.new(math.sin(a) * d, math.max(0.6, h), math.cos(a) * d)
	local cible = refCF * CFrame.new(0, 1.2 + 0.8 * melange - 0.6 * creux, -3 - 7 * melange)
	return CFrame.lookAt(pose.Position, cible.Position)
end

local function cinematique(voiture, nom, carID, dossierNom, position)
	if enCours then return end
	local modele = Car.Modele and Car.Modele(Car.TierDe and Car.TierDe(nom), nom)
	if typeof(voiture) ~= "Instance" then voiture = nil end
	local source = voiture or modele
	if not source then warn("[Cinematique] aucun modele pour " .. tostring(nom)); return end
	enCours = true
	local root = voiture and (voiture:FindFirstChild("Root") or voiture.PrimaryPart)
	task.spawn(function()
		if typeof(position) == "Vector3" then pcall(function() joueur:RequestStreamAroundAsync(position, 3) end) end
		local limite = os.clock() + DUREE_HYPER + DUREE_RETOUR + 1
		while not voiture and os.clock() < limite do
			local dossier = dossierNom and dossierNom ~= "" and workspace:FindFirstChild(dossierNom)
			local v = dossier and carID and dossier:FindFirstChild(carID)
			if v then voiture = v else task.wait(0.2) end
		end
		while voiture and not root and os.clock() < limite do
			root = voiture:FindFirstChild("Root") or voiture.PrimaryPart
			if not root then task.wait(0.1) end
		end
	end)

	local gui = interface(nom)
	local pg = joueur:FindFirstChild("PlayerGui")
	local main = pg and pg:FindFirstChild("Main")
	local mainEtait = main and main.Enabled
	if main then main.Enabled = false end
	local typeAvant = camera.CameraType
	local fovAvant = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local densiteAvant = atmo and atmo.Density
	if atmo then atmo.Density = 0.01 end

	local S = scene(source, nom)
	local fini = false
	local function finir(raison) if not fini then fini = true; print("[Cinematique] fin : " .. raison) end end
	gui.Passer.Activated:Connect(function() finir("bouton Passer") end)
	local touche = UserInputService.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Enum.KeyCode.Escape then finir("Echap") end end)

	-- sons
	local Sons = sons()
	local function son(def, defaut, volume)
		local id = (def and def.id and def.id ~= "") and def.id or defaut
		if not id or id == "" then return nil end
		local s = Instance.new("Sound"); s.SoundId = id; s.Volume = volume or (def and def.volume) or 0.6; s.Parent = SoundService
		return s
	end
	local moteur = son(Sons.moteurGT3, Sons.engine and Sons.engine.id, 0)
	if moteur then moteur.Looped = true; moteur.PlaybackSpeed = 0.55 end
	local clac = son(Sons.clac, "rbxasset://sounds/switch.wav", 0.9)
	if clac then clac.PlaybackSpeed = 0.7 end
	local hyper = son(Sons.hyper, nil)

	-- titre apres le clac, disparait avant le flash
	task.delay(T_CLAC + 0.5, function()
		TweenService:Create(gui.Titre, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
		TweenService:Create(gui.Sous, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
	end)
	task.delay(DUREE_HYPER - 1.1, function()
		TweenService:Create(gui.Titre, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
		TweenService:Create(gui.Sous, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
	end)
	gui.Noir.BackgroundTransparency = 1          -- le noir, c'est la scene elle-meme

	local depart = os.clock()
	local angleRoues = 0
	local phase = "espace"
	local flashLance, pharesFaits, eteindreVrais = false, false, nil
	local cfLisse = nil
	local function lisser(cible, dt, k)
		if not cfLisse then cfLisse = cible return cible end
		cfLisse = cfLisse:Lerp(cible, math.min(1, dt * (k or 4)))
		return cfLisse
	end
	local rng = Random.new()
	local conn
	local function etape(dt)
		if fini then return end
		local t = os.clock() - depart
		if phase == "espace" then
			-- 1. le noir : la voiture eteinte, face a nous
			if t >= T_CLAC and not pharesFaits then
				pharesFaits = true
				if S.voiture then allumerPhares(S.voiture, S.ref, S.taille) end
				if S.lampe then S.lampe.Brightness = 1.6 end
				if clac then clac:Play() end
				gui.Flash.BackgroundTransparency = 0.6
				TweenService:Create(gui.Flash, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
			end
			if t >= T_ACCEL and S.etoiles and not S.etoiles.Enabled then
				S.etoiles.Enabled = true
				task.delay(1.2, function() if S.etoiles then S.etoiles.Enabled = false end end)
				if moteur then moteur:Play() end
			end
			-- 2. l'acceleration : u = 0 au debut, 1 au flash
			local u = math.clamp((t - T_ACCEL) / (DUREE_HYPER - T_ACCEL), 0, 1)
			local acc = lisse(u) ^ 1.3
			local v = (t >= T_ACCEL) and (10 + (VITESSE_MAX - 10) * acc) or 0
			if S.roues and S.ref then
				angleRoues -= v * dt / (S.roues[1] and S.roues[1].rayon or 1)
				if angleRoues < -2 * math.pi then angleRoues += 2 * math.pi end
				local trem = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * 0.03 * acc
				local refV = S.ref + trem
				for _, g in ipairs(S.roues) do
					local rot = CFrame.new(g.centre) * CFrame.Angles(angleRoues, 0, 0) * CFrame.new(-g.centre)
					for _, e in ipairs(g.pieces) do if e.part.Parent then e.part.CFrame = refV * rot * e.offset end end
				end
			end
			-- traits d'hyperespace (a partir des deux tiers), flammes
			local hyperU = math.clamp((u - 0.45) / 0.55, 0, 1)
			for _, e in ipairs(S.traits) do
				e.Rate = 80 * hyperU + 480 * hyperU * hyperU
				e.Speed = NumberRange.new(80 + v * 0.8, 120 + v * 1.2)
				e.Size = NumberSequence.new(0.3 + 0.7 * hyperU)
			end
			for _, e in ipairs(S.boost) do e.Rate = math.clamp((acc - 0.35) * 400, 0, 260) end
			-- camera : face a la voiture, puis tourne autour et se place dans son dos (fin : CAM_DOS)
			local melange = lisse(math.clamp((t - T_ACCEL) / (DUREE_HYPER - T_ACCEL - 0.9), 0, 1))
			local cf = cameraDos(S.ref, melange)
			local trem = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 0.45 * acc * acc
			local roulis = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-1, 1) * 1.5 * acc * acc))
			camera.CFrame = (cf + trem) * roulis
			camera.FieldOfView = 70 + 38 * acc
			if moteur then moteur.PlaybackSpeed = 0.55 + 2.1 * acc; moteur.Volume = (t >= T_ACCEL) and (0.3 + 0.6 * acc) or 0 end
			-- 3. flash blanc, puis bascule sur la vraie voiture
			if t >= DUREE_HYPER - DUREE_FLASH and not flashLance then
				flashLance = true
				if hyper then hyper:Play() end
				TweenService:Create(gui.Flash, TweenInfo.new(DUREE_FLASH, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0}):Play()
			end
			if t >= DUREE_HYPER then
				phase = "retour"; depart = os.clock(); cfLisse = nil
				S.dossier:Destroy(); S.dossier = nil
				if atmo and densiteAvant then atmo.Density = densiteAvant end
				print(("[Cinematique] plan final : voiture %s, root %s"):format(tostring(voiture and voiture.Parent and voiture.Name), tostring(root and root.Parent and root.Name)))
				if voiture and root then
					-- la vraie voiture : phares allumes, camera exactement au meme angle (dans son dos)
					local tailleV = tailleDans(voiture, root.CFrame)
					pcall(function() eteindreVrais = allumerPhares(voiture, root.CFrame, tailleV) end)
					camera.CFrame = cameraDos(root.CFrame, 1)
				end
				camera.FieldOfView = 70 + 38
				TweenService:Create(camera, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()
				TweenService:Create(gui.Flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
				if moteur then TweenService:Create(moteur, TweenInfo.new(2.2), {Volume = 0, PlaybackSpeed = 0.8}):Play() end
				for _, b in ipairs({gui.Haut, gui.Bas}) do TweenService:Create(b, TweenInfo.new(DUREE_RETOUR), {Size = UDim2.new(1, 0, 0, 0)}):Play() end
			end
		elseif phase == "retour" then
			-- 4. la map : camera dans le dos de la vraie voiture qui demarre, puis retour en douceur au joueur
			if not (voiture and root and voiture.Parent and root.Parent) then finir("voiture disparue") return end
			if t < DUREE_RETOUR then
				camera.CFrame = lisser(cameraDos(root.CFrame, 1), dt, 6)
			else
				local u = lisse((t - DUREE_RETOUR) / DUREE_RACCORD)
				local perso = joueur.Character
				local hrp = perso and perso:FindFirstChild("HumanoidRootPart")
				if hrp then
					local cible = CFrame.lookAt(hrp.Position + hrp.CFrame.LookVector * -12 + Vector3.new(0, 6, 0), hrp.Position + Vector3.new(0, 1.5, 0))
					camera.CFrame = (cfLisse or camera.CFrame):Lerp(cible, u)
				end
				if t >= DUREE_RETOUR + DUREE_RACCORD then finir("plan final termine") end
			end
		end
	end
	conn = RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(etape, dt)
		if not ok then warn("[Cinematique] erreur : " .. tostring(err)); finir("erreur") end
	end)
	while not fini do task.wait(0.05) end
	conn:Disconnect(); touche:Disconnect()
	if S.dossier then S.dossier:Destroy() end
	if atmo and densiteAvant then atmo.Density = densiteAvant end
	if moteur then moteur:Destroy() end
	if clac then task.delay(2, function() clac:Destroy() end) end
	if hyper then task.delay(3, function() hyper:Destroy() end) end
	-- les phares de la vraie voiture restent allumes tant qu'elle existe (elle vient d'arriver de nuit... dans l'espace)
	if eteindreVrais and voiture then voiture.AncestryChanged:Connect(function() if not voiture.Parent then pcall(eteindreVrais) end end) end
	gui.Flash.BackgroundTransparency = 1
	for _, b in ipairs({gui.Haut, gui.Bas}) do TweenService:Create(b, TweenInfo.new(0.35), {Size = UDim2.new(1, 0, 0, 0)}):Play() end
	gui.Passer.Visible = false
	task.delay(0.4, function() gui:Destroy() end)
	camera.FieldOfView = fovAvant
	camera.CameraType = typeAvant ~= Enum.CameraType.Scriptable and typeAvant or Enum.CameraType.Custom
	local perso = joueur.Character
	if perso then camera.CameraSubject = perso:FindFirstChildOfClass("Humanoid") end
	if main and mainEtait then main.Enabled = true end
	enCours = false
end

Event.OnClientEvent:Connect(function(quoi, voiture, nom, carID, dossierNom, position)
	if quoi ~= "voiture" then return end
	print(("[Cinematique] decouverte : %s (voiture %s)"):format(tostring(nom), typeof(voiture) == "Instance" and "repliquee" or "pas encore repliquee"))
	task.spawn(cinematique, voiture, tostring(nom), carID, dossierNom, position)
end)
