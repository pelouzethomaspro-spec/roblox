--[[ ClientTutoriel (v53) — LocalScript StarterPlayer/StarterPlayerScripts
	Cote client du tutoriel (serveur : Tutoriel.lua). Le serveur envoie TutorielEvent("etape", nom, params) ; on joue
	les plans camera, les dialogues d'ItsCirly (panneau bas, machine a ecrire), les cases vertes / bleues, la fleche,
	les animations du guide, et on repond TutorielEvent:FireServer("fini", nom).
	Messages intermediaires : "garee", "lavage", "paye".
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Event = ReplicatedStorage:WaitForChild("TutorielEvent", 120)
if not Event then return end

local CASE, DEMI = 15, 7.5
local VITESSE_TEXTE = 45             -- caracteres / seconde
local ANIMS = {                      -- animations R15 du catalogue Roblox
	wave = "rbxassetid://507770239", point = "rbxassetid://507770453", cheer = "rbxassetid://507770677",
	laugh = "rbxassetid://507770818", dance = "rbxassetid://507771019", dance2 = "rbxassetid://507776043",
	sit = "rbxassetid://2506281703", idle = "rbxassetid://507766666",
}
-- v55 (Thomas) : couleurs pales et mates, les memes que le mode Circulation (ClientDiagnostic) : lisibles, pas de neon
local VERT = Color3.fromRGB(150, 205, 140)
local BLEU = Color3.fromRGB(140, 175, 225)
local JAUNE = Color3.fromRGB(255, 205, 60)

-- ----------------------------------------------------------------------------------------------------------------------
-- etat
-- ----------------------------------------------------------------------------------------------------------------------
local S = {
	commun = nil, guide = nil, gui = nil, dossier = nil, pistes = {}, renderStep = nil,
	camTypeAvant = nil, fovAvant = nil, guisCaches = {}, actif = false, continuer = false, messages = {},
}

local function monde(x, z, y)
	local pivot = S.commun and S.commun.pivot or CFrame.new()
	return pivot * CFrame.new((x - 0.5) * CASE, y or 0, (z - 0.5) * CASE - DEMI)
end

local function dossier()
	if not S.dossier or not S.dossier.Parent then
		S.dossier = Instance.new("Folder"); S.dossier.Name = "TutorielLocal"; S.dossier.Parent = workspace
	end
	return S.dossier
end

local function tween(objet, duree, props, style, dir)
	local t = TweenService:Create(objet, TweenInfo.new(duree, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- ----------------------------------------------------------------------------------------------------------------------
-- interface : fondu, bandes cinema, panneau de dialogue, objectif
-- ----------------------------------------------------------------------------------------------------------------------
local function interface()
	if S.gui and S.gui.Parent then return S.gui end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorielGui"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 60; gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local noir = Instance.new("Frame"); noir.Name = "Noir"; noir.Size = UDim2.fromScale(1, 1)
	noir.BackgroundColor3 = Color3.new(0, 0, 0); noir.BackgroundTransparency = 1; noir.BorderSizePixel = 0; noir.ZIndex = 50; noir.Parent = gui

	for _, nom in ipairs({"BandeHaut", "BandeBas"}) do
		local b = Instance.new("Frame"); b.Name = nom; b.BackgroundColor3 = Color3.new(0, 0, 0); b.BorderSizePixel = 0; b.ZIndex = 5
		b.AnchorPoint = Vector2.new(0, nom == "BandeHaut" and 0 or 1)
		b.Position = nom == "BandeHaut" and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 1)
		b.Size = UDim2.new(1, 0, 0, 0); b.Parent = gui
	end

	-- panneau de dialogue
	local panneau = Instance.new("Frame"); panneau.Name = "Panneau"
	panneau.AnchorPoint = Vector2.new(0.5, 1); panneau.Position = UDim2.new(0.5, 0, 1, 190)
	panneau.Size = UDim2.new(0, 760, 0, 150); panneau.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panneau.BackgroundTransparency = 0.12; panneau.BorderSizePixel = 0; panneau.ZIndex = 10; panneau.Parent = gui
	Instance.new("UICorner", panneau).CornerRadius = UDim.new(0, 18)
	local contour = Instance.new("UIStroke", panneau); contour.Color = JAUNE; contour.Thickness = 2; contour.Transparency = 0.3
	local echelle = Instance.new("UIScale", panneau); echelle.Name = "Echelle"

	local avatarFond = Instance.new("Frame"); avatarFond.Size = UDim2.new(0, 118, 0, 118); avatarFond.Position = UDim2.new(0, 16, 0.5, 0)
	avatarFond.AnchorPoint = Vector2.new(0, 0.5); avatarFond.BackgroundColor3 = JAUNE; avatarFond.BorderSizePixel = 0; avatarFond.ZIndex = 11; avatarFond.Parent = panneau
	Instance.new("UICorner", avatarFond).CornerRadius = UDim.new(1, 0)
	local avatar = Instance.new("ImageLabel"); avatar.Name = "Avatar"; avatar.Size = UDim2.new(1, -8, 1, -8); avatar.Position = UDim2.new(0, 4, 0, 4)
	avatar.BackgroundColor3 = Color3.fromRGB(40, 44, 58); avatar.BorderSizePixel = 0; avatar.ZIndex = 12; avatar.Parent = avatarFond
	Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

	local nom = Instance.new("TextLabel"); nom.Name = "Nom"; nom.Position = UDim2.new(0, 152, 0, 14); nom.Size = UDim2.new(1, -170, 0, 28)
	nom.BackgroundTransparency = 1; nom.Font = Enum.Font.GothamBlack; nom.TextSize = 24; nom.TextColor3 = JAUNE
	nom.TextXAlignment = Enum.TextXAlignment.Left; nom.Text = "ItsCirly"; nom.ZIndex = 11; nom.Parent = panneau

	local texte = Instance.new("TextLabel"); texte.Name = "Texte"; texte.Position = UDim2.new(0, 152, 0, 46); texte.Size = UDim2.new(1, -172, 1, -58)
	texte.BackgroundTransparency = 1; texte.Font = Enum.Font.GothamMedium; texte.TextSize = 22; texte.TextColor3 = Color3.new(1, 1, 1)
	texte.TextXAlignment = Enum.TextXAlignment.Left; texte.TextYAlignment = Enum.TextYAlignment.Top; texte.TextWrapped = true
	texte.Text = ""; texte.ZIndex = 11; texte.Parent = panneau

	local suite = Instance.new("TextLabel"); suite.Name = "Suite"; suite.AnchorPoint = Vector2.new(1, 1); suite.Position = UDim2.new(1, -16, 1, -8)
	suite.Size = UDim2.new(0, 260, 0, 20); suite.BackgroundTransparency = 1; suite.Font = Enum.Font.Gotham; suite.TextSize = 14
	suite.TextColor3 = Color3.fromRGB(190, 190, 200); suite.TextXAlignment = Enum.TextXAlignment.Right; suite.Text = ""; suite.ZIndex = 11; suite.Parent = panneau

	-- objectif (haut de l'ecran)
	local objectif = Instance.new("TextLabel"); objectif.Name = "Objectif"; objectif.AnchorPoint = Vector2.new(0.5, 0)
	objectif.Position = UDim2.new(0.5, 0, 0, -60); objectif.Size = UDim2.new(0, 620, 0, 48); objectif.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	objectif.BackgroundTransparency = 0.15; objectif.BorderSizePixel = 0; objectif.Font = Enum.Font.GothamBold; objectif.TextSize = 20
	objectif.TextColor3 = Color3.new(1, 1, 1); objectif.Text = ""; objectif.ZIndex = 10; objectif.Parent = gui
	Instance.new("UICorner", objectif).CornerRadius = UDim.new(0, 12)
	local co = Instance.new("UIStroke", objectif); co.Color = VERT; co.Thickness = 2

	gui.Parent = joueur:WaitForChild("PlayerGui")
	S.gui = gui

	-- portrait d'ItsCirly
	task.spawn(function()
		local id = S.guide and S.guide:GetAttribute("UserId")
		if not id or id == 0 then
			local ok, i = pcall(function() return Players:GetUserIdFromNameAsync("ItsCirly") end)
			if ok then id = i end
		end
		if id and id ~= 0 then
			local ok, img = pcall(function() return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end)
			if ok and img and avatar.Parent then avatar.Image = img end
		end
	end)
	return gui
end

local function fondu(vers, duree)
	local gui = interface()
	tween(gui.Noir, duree or 0.4, { BackgroundTransparency = vers and 0 or 1 }, Enum.EasingStyle.Linear)
	task.wait(duree or 0.4)
end

local function bandes(oui)
	local gui = interface()
	local h = oui and 70 or 0
	tween(gui.BandeHaut, 0.45, { Size = UDim2.new(1, 0, 0, h) }); tween(gui.BandeBas, 0.45, { Size = UDim2.new(1, 0, 0, h) })
end

local function montrerPanneau(oui)
	local gui = interface()
	tween(gui.Panneau, 0.35, { Position = oui and UDim2.new(0.5, 0, 1, -28) or UDim2.new(0.5, 0, 1, 190) }, Enum.EasingStyle.Back, oui and Enum.EasingDirection.Out or Enum.EasingDirection.In)
end

local function objectif(texte)
	local gui = interface()
	gui.Objectif.Text = texte or ""
	tween(gui.Objectif, 0.4, { Position = texte and UDim2.new(0.5, 0, 0, 24) or UDim2.new(0.5, 0, 0, -60) }, Enum.EasingStyle.Back)
end

-- ----------------------------------------------------------------------------------------------------------------------
-- guide : animations
-- ----------------------------------------------------------------------------------------------------------------------
local function animer(nom, boucle)
	local guide = S.guide
	local hum = guide and guide:FindFirstChildOfClass("Humanoid")
	local animator = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
	if not animator then return nil end
	local deja = S.pistes[nom]
	if deja and boucle ~= false and deja.IsPlaying then return deja end
	for _, p in pairs(S.pistes) do pcall(function() p:Stop(0.2) end) end
	S.pistes = {}
	local anim = Instance.new("Animation"); anim.AnimationId = ANIMS[nom] or ANIMS.idle
	local ok, piste = pcall(function() return animator:LoadAnimation(anim) end)
	if not ok or not piste then return nil end
	piste.Looped = boucle ~= false
	piste.Priority = Enum.AnimationPriority.Action
	piste:Play(0.15)
	S.pistes[nom] = piste
	return piste
end

-- le guide regarde un point (rotation Y seulement), sans bouger
local function regarder(position)
	local guide = S.guide
	if not (guide and guide.Parent) then return end
	local p = guide:GetPivot().Position
	local cible = Vector3.new(position.X, p.Y, position.Z)
	if (cible - p).Magnitude > 0.5 then guide:PivotTo(CFrame.lookAt(p, cible)) end
end

-- ----------------------------------------------------------------------------------------------------------------------
-- dialogue : machine a ecrire + animation ; clic / Espace pour passer
-- ----------------------------------------------------------------------------------------------------------------------
local function passer()
	S.continuer = true
end
UserInputService.InputBegan:Connect(function(input, traite)
	if traite or not S.actif then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
		passer()
	end
end)

-- dit un texte ; attendre = secondes de pause apres le texte (defaut : selon la longueur), clic pour passer
S.jeton = 0
local function dire(texte, anim, attendre)
	local gui = interface()
	S.jeton += 1
	local jeton = S.jeton
	montrerPanneau(true)
	if anim then animer(anim, anim == "sit" or anim == "idle" or anim == "dance" or anim == "dance2") end
	local label = gui.Panneau.Texte
	gui.Panneau.Suite.Text = ""
	label.Text = ""; label.MaxVisibleGraphemes = 0
	label.Text = texte
	S.continuer = false
	local n = utf8.len(texte) or #texte
	local t0 = os.clock()
	while label.MaxVisibleGraphemes < n and label.MaxVisibleGraphemes >= 0 do
		if S.continuer or S.jeton ~= jeton then break end
		label.MaxVisibleGraphemes = math.min(n, math.floor((os.clock() - t0) * VITESSE_TEXTE))
		task.wait()
	end
	if S.jeton ~= jeton then return end        -- un autre dialogue a pris la main
	label.MaxVisibleGraphemes = -1
	gui.Panneau.Suite.Text = "clic / Espace pour continuer"
	S.continuer = false
	local pause = attendre or math.clamp(0.9 + n * 0.028, 1.4, 4.5)
	local t1 = os.clock()
	while os.clock() - t1 < pause and not S.continuer and S.jeton == jeton do task.wait() end
	if S.jeton == jeton then gui.Panneau.Suite.Text = "" end
end

-- ----------------------------------------------------------------------------------------------------------------------
-- camera
-- ----------------------------------------------------------------------------------------------------------------------
local function prendreCamera()
	if S.camTypeAvant == nil then S.camTypeAvant = camera.CameraType; S.fovAvant = camera.FieldOfView end
	camera.CameraType = Enum.CameraType.Scriptable
end
local function rendreCamera()
	if S.renderStep then RunService:UnbindFromRenderStep(S.renderStep); S.renderStep = nil end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = S.fovAvant or 70
	S.camTypeAvant = nil
end

-- deplacement doux de la camera vers cf (duree s)
local function camVers(cf, duree, style)
	prendreCamera()
	if S.renderStep then RunService:UnbindFromRenderStep(S.renderStep); S.renderStep = nil end
	if not duree or duree <= 0 then camera.CFrame = cf return end
	local depart = camera.CFrame
	local t0 = os.clock()
	while os.clock() - t0 < duree do
		local a = math.clamp((os.clock() - t0) / duree, 0, 1)
		a = TweenService:GetValue(a, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		camera.CFrame = depart:Lerp(cf, a)
		task.wait()
	end
	camera.CFrame = cf
end

-- camera qui suit chaque image : fn() -> CFrame
local function camSuivre(fn)
	prendreCamera()
	if S.renderStep then RunService:UnbindFromRenderStep(S.renderStep) end
	local nom = "TutoCam" .. tostring(os.clock())
	S.renderStep = nom
	RunService:BindToRenderStep(nom, Enum.RenderPriority.Camera.Value + 1, function()
		local ok, cf = pcall(fn)
		if ok and typeof(cf) == "CFrame" then camera.CFrame = camera.CFrame:Lerp(cf, 0.18) end
	end)
end

local function cacherInterfaceJeu(oui)
	local pg = joueur:FindFirstChild("PlayerGui")
	if not pg then return end
	if oui then
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= S.gui then g.Enabled = false; S.guisCaches[g] = true end
		end
	else
		for g in pairs(S.guisCaches) do if g.Parent then g.Enabled = true end end
		S.guisCaches = {}
	end
end

-- ----------------------------------------------------------------------------------------------------------------------
-- effets sur le plot : plaques de cases, fleche, surbrillance
-- ----------------------------------------------------------------------------------------------------------------------
local function plaque(x, z, couleur, y)
	local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic; p.Color = couleur; p.Transparency = 0.45
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(2, 0.12, 2); p.CFrame = monde(x, z, y or 1.0); p.Parent = dossier()
	local contour = Instance.new("SelectionBox"); contour.Adornee = p; contour.LineThickness = 0.025
	contour.Color3 = couleur:Lerp(Color3.new(0, 0, 0), 0.35); contour.Transparency = 0.2; contour.Parent = p
	tween(p, 0.22, { Size = Vector3.new(CASE - 1.2, 0.12, CASE - 1.2) }, Enum.EasingStyle.Back)
	return p
end

local function fleche(cf, texte, couleur)
	local m = Instance.new("Model"); m.Name = "Fleche"
	local tige = Instance.new("Part"); tige.Anchored = true; tige.CanCollide = false; tige.CanQuery = false
	tige.Material = Enum.Material.Neon; tige.Color = couleur or JAUNE; tige.Size = Vector3.new(2, 7, 2)
	tige.CFrame = cf * CFrame.new(0, 14, 0); tige.Parent = m
	local pointe = Instance.new("WedgePart"); pointe.Anchored = true; pointe.CanCollide = false; pointe.CanQuery = false
	pointe.Material = Enum.Material.Neon; pointe.Color = couleur or JAUNE; pointe.Size = Vector3.new(5, 5, 5)
	pointe.CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(math.pi, 0, 0); pointe.Parent = m
	local pointe2 = pointe:Clone(); pointe2.CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(math.pi, math.pi, 0); pointe2.Parent = m
	if texte then
		local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 220, 0, 50); bb.StudsOffset = Vector3.new(0, 6, 0); bb.AlwaysOnTop = true
		local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBlack
		l.TextSize = 34; l.TextColor3 = couleur or JAUNE; l.TextStrokeTransparency = 0.2; l.Text = texte; l.Parent = bb
		bb.Parent = tige
	end
	m.Parent = dossier()
	-- va-et-vient
	task.spawn(function()
		local base = cf
		local t0 = os.clock()
		while m.Parent do
			local dy = math.sin((os.clock() - t0) * 4) * 1.5
			tige.CFrame = base * CFrame.new(0, 14 + dy, 0)
			pointe.CFrame = base * CFrame.new(0, 8 + dy, 0) * CFrame.Angles(math.pi, 0, 0)
			pointe2.CFrame = base * CFrame.new(0, 8 + dy, 0) * CFrame.Angles(math.pi, math.pi, 0)
			task.wait()
		end
	end)
	return m
end

local function surbrillance(modele, couleur)
	if not modele then return nil end
	local h = Instance.new("Highlight"); h.FillColor = couleur or VERT; h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.6; h.OutlineTransparency = 0; h.Adornee = modele; h.Parent = dossier()
	task.spawn(function()
		local t0 = os.clock()
		while h.Parent do h.FillTransparency = 0.55 + 0.3 * math.sin((os.clock() - t0) * 5); task.wait() end
	end)
	return h
end

local function meubleDuPlot(furnitureID)
	local folder = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(joueur.Name .. "'s plot")
	if not (folder and furnitureID) then return nil end
	for _, m in ipairs(folder:GetChildren()) do if m:GetAttribute("FurnitureID") == furnitureID then return m end end
	return nil
end

local function viderDossier()
	if S.dossier then S.dossier:Destroy(); S.dossier = nil end
end

-- centre du plot (monde) et vue de dessus inclinee
local function vuePlot(zoom)
	local c = S.commun
	local centre = monde(c.nx / 2 + 0.5, c.nz / 2 + 0.5, 0).Position
	local recul = (zoom or 1) * 150
	-- la camera est du cote de la route du tour (Z < 0 dans le repere du plot) et regarde vers le fond
	local versRoute = (c.pivot * CFrame.new(0, 0, -1)).Position - c.pivot.Position
	local pos = centre + versRoute.Unit * recul * 0.75 + Vector3.new(0, recul, 0)
	return CFrame.lookAt(pos, centre)
end

-- ----------------------------------------------------------------------------------------------------------------------
-- la vitrine d'ItsCirly (plot libre, purement visuelle : clones des catalogues ReplicatedStorage)
-- ----------------------------------------------------------------------------------------------------------------------
local function construireVitrine(plotSpawn)
	local pc = plotSpawn and plotSpawn:FindFirstChild("PlotCenter")
	if not pc then return nil end
	local typeA = plotSpawn:FindFirstChild("TypeA")
	local A = (typeA and typeA:IsA("BoolValue")) and typeA.Value or true
	local NX = 18
	local function mx(x) return A and x or (NX + 1 - x) end
	local pivot = pc:GetPivot()
	local function cfV(x, z, y, o)
		return pivot * CFrame.new((x - 0.5) * CASE, y or 0, (z - 0.5) * CASE - DEMI) * CFrame.Angles(0, math.rad((o or 0) * 90), 0)
	end
	local dossierV = Instance.new("Folder"); dossierV.Name = "VitrineItsCirly"; dossierV.Parent = dossier()
	-- le terrain (herbe) du plot libre recouvre les sols : on le creuse localement (cote client, non replique) et on le
	-- remettra a la fin (ReadVoxels / WriteVoxels)
	local terrain = workspace.Terrain
	local cfTrou = pivot * CFrame.new(NX * CASE / 2, -1, 14 * CASE / 2 - DEMI)
	local tailleTrou = Vector3.new(NX * CASE + 2, 14, 14 * CASE + 2)
	local sauvegarde = nil
	pcall(function()
		local demi = Vector3.new(tailleTrou.X / 2 + 8, tailleTrou.Y / 2 + 4, tailleTrou.Z / 2 + 8)
		local region = Region3.new(cfTrou.Position - demi, cfTrou.Position + demi):ExpandToGrid(4)
		local materiaux, occupations = terrain:ReadVoxels(region, 4)
		sauvegarde = { region = region, materiaux = materiaux, occupations = occupations }
		terrain:FillBlock(cfTrou, tailleTrou, Enum.Material.Air)
	end)
	S.terrainVitrine = sauvegarde
	-- coordonnees logiques (type A) ; miroir en X pour le type B : MurNord (o = 0, bord +X) passe au bord -X de la case
	-- miroir (= MurNord de la case precedente), les meubles tournent 0 <-> 2
	local function clone(categorie, nom, x, z, y, o)
		o = o or 0
		local d = ReplicatedStorage:FindFirstChild(categorie)
		local m = d and d:FindFirstChild(nom)
		if not m then return nil end
		local xx = mx(x)
		if categorie == "Mur" then
			if o == 0 and not A then xx = mx(x) - 1 end
		elseif not A and categorie == "Furniture" then
			if o == 0 then o = 2 elseif o == 2 then o = 0 end
		end
		local c = m:Clone()
		for _, s in ipairs(c:GetDescendants()) do if s:IsA("BaseScript") then s:Destroy() end end
		c:PivotTo(cfV(xx, z, y, o))
		c.Parent = dossierV
		return c
	end
	local oriStation = S.orientationStation or 3
	if not A then oriStation = (oriStation == 3) and 1 or ((oriStation == 1) and 3 or oriStation) end

	-- sols : goudron partout rangees 1-10, carrelage de la grande boutique rangees 11-13
	for x = 1, NX do
		for z = 1, 10 do clone("Sol", "sol_goudron", x, z, 0) end
		for z = 11, 13 do clone("Sol", "sol_marbre", x, z, 0) end
	end
	-- 6 stations haut de gamme sur deux lignes
	for i, x in ipairs({3, 7, 11, 15}) do clone("Furniture", (i % 2 == 0) and "L4_Rouleaux" or "L3_Karcher", x, 3, 0.616, oriStation) end
	for _, x in ipairs({5, 13}) do clone("Furniture", "L4_Rouleaux", x, 8, 0.616, oriStation) end
	-- boutique : baies vitrees en pierre, caisses automatiques, rayonnages, plantes
	for x = 1, NX do clone("Mur", "mur_baie_simple_pierre", x, 11, 0, 1) end
	for x = 1, NX do clone("Mur", "mur_plein_pierre", x, 14, 0, 1) end
	for z = 11, 13 do clone("Mur", "mur_plein_pierre", NX, z, 0, 0); clone("Mur", "mur_plein_pierre", 0, z, 0, 0) end
	for _, x in ipairs({4, 8, 12, 16}) do clone("Furniture", "2", x, 12, 0.616, 0) end
	for _, x in ipairs({2, 6, 10, 14}) do clone("Furniture", "4", x, 13, 0.616, 0) end
	for _, x in ipairs({1, 5, 9, 13, 17}) do clone("Furniture", "topiaire_cone", x, 11, 0.616, 0) end
	for _, x in ipairs({2, 17}) do clone("Furniture", "jardiniere_fleurs", x, 10, 0.616, 0) end
	-- des voitures partout : file d'attente + stations
	local modeles = ReplicatedStorage:FindFirstChild("VoituresModeles")
	local noms = {"Urus", "GT3", "M4", "ClassG", "Mercedes", "Dodge", "Golf", "Volvo240", "F448", "Clio4", "Golf2"}
	local voitures = {}
	if modeles then
		local k = 0
		for _, x in ipairs({1, 3, 5, 7, 9, 11, 13, 15, 17}) do
			k += 1
			local m = modeles:FindFirstChild(noms[(k - 1) % #noms + 1])
			if m then
				local c = m:Clone()
				for _, s in ipairs(c:GetDescendants()) do if s:IsA("BaseScript") then s:Destroy() end end
				c:PivotTo(cfV(mx(x), 6, 2.2, A and 3 or 1))
				c.Parent = dossierV
				table.insert(voitures, c)
			end
		end
		for i, x in ipairs({3, 7, 11, 15}) do
			local m = modeles:FindFirstChild(noms[(i + 4) % #noms + 1])
			if m then
				local c = m:Clone()
				for _, s in ipairs(c:GetDescendants()) do if s:IsA("BaseScript") then s:Destroy() end end
				c:PivotTo(cfV(mx(x), 3, 2.2, A and 3 or 1)); c.Parent = dossierV
			end
		end
	end
	for _, c in ipairs(dossierV:GetDescendants()) do
		if c:IsA("BasePart") then c.Anchored = true; c.CanCollide = false end
	end
	return dossierV, pivot, voitures
end

local function detruireVitrine(dossierV)
	if dossierV then dossierV:Destroy() end
	local sv = S.terrainVitrine
	if sv then
		pcall(function() workspace.Terrain:WriteVoxels(sv.region, 4, sv.materiaux, sv.occupations) end)
		S.terrainVitrine = nil
	end
end

-- ----------------------------------------------------------------------------------------------------------------------
-- ETAPES
-- ----------------------------------------------------------------------------------------------------------------------
local Etapes = {}

local function fini(nom) Event:FireServer("fini", nom) end
local function attendreMessage(nom, delai)
	local t0 = os.clock()
	while S.messages[nom] == nil and os.clock() - t0 < (delai or 60) do task.wait(0.1) end
	local v = S.messages[nom]; S.messages[nom] = nil
	return v
end

local function perso() return joueur.Character end
local function teleporter(cf)
	local c = perso()
	if c and typeof(cf) == "CFrame" then
		local root = c:FindFirstChild("HumanoidRootPart")
		if root then root.AssemblyLinearVelocity = Vector3.zero end
		c:PivotTo(cf)
	end
end
local function positionGuide() return S.guide and S.guide:GetPivot().Position or Vector3.zero end

Etapes.accueil = function(P)
	S.actif = true
	S.messages = {}
	interface()
	cacherInterfaceJeu(true)
	bandes(true)
	local gui = interface(); gui.Noir.BackgroundTransparency = 0
	local spawn = P.spawn
	-- v56 : ARRIVEE EN PICK-UP (si le modele F-150 est dans la place)
	local PK = P.pickup and P.pickup.points and creerPickup(P.pickup.modele) or nil
	if PK then
		S.pickup = PK
		local pts = P.pickup.points
		local lacher = dansLaBenne(PK, nil)
		S.lacherToit = lacher
		-- plan 1 : trois-quarts avant, assez bas, qui suit le pick-up dans la descente de la branche
		local cote = 1
		camSuivre(function()
			local cf = PK.cfCourant or pts[1].cf
			local pos = (cf * CFrame.new(cote * 12, 6, -24)).Position
			return CFrame.lookAt(pos, cf.Position + Vector3.new(0, 3, 0))
		end)
		camera.FieldOfView = 64
		do local cf = pts[1].cf; camera.CFrame = CFrame.lookAt((cf * CFrame.new(12, 6, -24)).Position, cf.Position + Vector3.new(0, 3, 0)) end
		fondu(false, 0.5)
		roulerPickup(PK, pts,
			function(coteVirage)
				-- derapage : plan exterieur bas, large, qui regarde le pick-up se mettre sur deux roues
				camera.FieldOfView = 72
				local ancre = PK.cfCourant or pts[1].cf
				local posCam = (ancre * CFrame.new((coteVirage or 1) * 20, 5, 4)).Position
				camSuivre(function()
					local cf = PK.cfCourant or ancre
					return CFrame.lookAt(posCam, cf.Position + Vector3.new(0, 3.5, 0))
				end)
				task.spawn(dire, "WOOOOH !! Doucement, DOUCEMENT !", "cheer", 1.0)
			end,
			function()
				-- il retombe sur ses quatre roues : ItsCirly se rattrape et se rassoit
				animer("sit", true)
				task.spawn(dire, "...Ouf. Ca va, ca va. Je gere.", "sit", 1.2)
			end)
		-- gare : la camera vient se poser face a la benne, ItsCirly regarde le joueur
		if S.lacherToit then S.lacherToit() end
		S.lacherToit = dansLaBenne(PK, P.pickup.versJoueur or spawn.Position)
		local park = P.pickup.parking or PK.cfCourant
		local vers = (spawn.Position - park.Position); vers = Vector3.new(vers.X, 0, vers.Z).Unit
		local posCam = park.Position + vers * 16 + Vector3.new(0, 5.5, 0)
		camera.FieldOfView = 62
		camVers(CFrame.lookAt(posCam, park.Position + Vector3.new(0, 4.5, 0)), 0.9)
		camSuivre(function() return CFrame.lookAt(posCam, positionGuide() + Vector3.new(0, 1.2, 0)) end)
		montrerPanneau(true)
		if P.rejouer then
			dire("Re ! Nouveau pick-up, meme chauffeur. On refait le tour du proprietaire ?", "wave", 1.8)
		else
			dire("Hey ! Moi c'est ItsCirly. Bienvenue a STATION TYCOON !", "wave", 2.2)
		end
		animer("sit", true)
	else
	-- plan 1 : contre-plongee legere sur ItsCirly depuis l'epaule du joueur
	local cfCam = spawn * CFrame.new(-2.5, 4.5, 5.5)
	camVers(CFrame.lookAt(cfCam.Position, positionGuide() + Vector3.new(0, 2, 0)), 0)
	fondu(false, 0.6)
	regarder(spawn.Position)
	if P.rejouer then
		dire("Re ! On refait le tour du proprietaire ? Allez, c'est parti.", "wave", 1.6)
	else
		dire("Hey ! Moi c'est ItsCirly. Bienvenue a STATION TYCOON !", "wave", 2.2)
	end
	end
	-- plan 2 : la camera glisse en travelling vers le plot pendant qu'il pointe
	local depuis = PK and (PK.cfCourant or spawn) or spawn
	task.spawn(function() camVers(CFrame.lookAt((depuis * CFrame.new(-10, 7, 5)).Position, monde(S.commun.nx / 2, 4, 0).Position), 2.4) end)
	if not PK then regarder(monde(S.commun.nx / 2, 4, 0).Position) end
	dire("Tu vois ce terrain ? C'est le TIEN. Je t'ai prepare une petite station pour demarrer.", "point", 2.2)
	if not PK then regarder(spawn.Position) end
	dire("Je te montre comment ca marche, vite fait : le premier client arrive dans une minute !", "cheer", 1.8)
	if PK then animer("sit", true) end
	montrerPanneau(false)
	fini("accueil")
end

Etapes.plot = function(P)
	S.messages = {}
	-- la camera monte au-dessus du plot
	camVers(vuePlot(1.0), 1.6, Enum.EasingStyle.Cubic)
	local c = S.commun
	regarder(monde(P.entree[1], P.entree[2], 0).Position)
	local f = fleche(monde(P.entree[1], P.entree[2], 1.5), "ENTREE", JAUNE)
	dire("Les voitures entrent par ICI, sur le bord de la branche...", "point", 0.2)
	-- cases vertes : le chemin des voitures, une par une
	local plaques = {}
	for i, cell in ipairs(P.chemin) do
		table.insert(plaques, plaque(cell[1], cell[2], VERT))
		if i % 2 == 0 then task.wait(0.045) end
	end
	local fS = fleche(monde(P.sortie[1], P.sortie[2], 1.5), "SORTIE", Color3.fromRGB(255, 120, 90))
	dire("...elles roulent sur TON goudron, se garent dans la station, et repartent par la SORTIE. Pas de route, pas de client !", "point", 2.4)
	-- cases bleues : le chemin du pieton
	dire("Le client, lui, descend de sa voiture et marche jusqu'a la CAISSE pour payer. Il lui faut un chemin a pied.", "point", 0.2)
	for _, cell in ipairs(P.pietons) do table.insert(plaques, plaque(cell[1], cell[2], BLEU, 1.3)); task.wait(0.09) end
	local fC = fleche(monde(P.caisse[1], P.caisse[2], 1.5), "CAISSE", BLEU)
	task.wait(1.8)
	-- zoom sur l'entree pour la suite
	camVers(CFrame.lookAt(monde(P.entree[1] - (c.A and 6 or -6), P.entree[2], 0).Position + Vector3.new(0, 45, 0), monde(P.entree[1], P.entree[2], 0).Position), 1.2)
	for _, p in ipairs(plaques) do tween(p, 0.35, { Transparency = 1, Size = Vector3.new(2, 0.25, 2) }) end
	task.delay(0.4, function() for _, p in ipairs(plaques) do p:Destroy() end; if fS then fS:Destroy() end; if fC then fC:Destroy() end end)
	montrerPanneau(false)
	S.flecheEntree = f
	fini("plot")
end

-- ----------------------------------------------------------------------------------------------------------------------
-- v56 : LE PICK-UP D'ITSCIRLY (F-150). Tout est local : clone du modele (ReplicatedStorage/F150 ou F150_Peintures), suivi
-- d'une courbe passant par les points envoyes par le serveur, roues qui tournent, DERAPAGE en entrant dans le plot
-- (survirage + roulis sur deux roues), ItsCirly assis dans la benne qui glisse vers la ridelle, se rattrape, retombe
-- quand le pick-up retombe sur ses quatre roues.
-- ----------------------------------------------------------------------------------------------------------------------
local PICKUP = {
	longueur = 27.1,             -- studs (F-150 5,91 m x 4,59 ; repris de Catalogue/Car si disponible)
	derive = math.rad(32),       -- angle de survirage pendant le derapage
	roulis = math.rad(24),       -- inclinaison sur deux roues
	glisse = 5.5,                -- studs : glissement d'ItsCirly vers la ridelle au plus fort du roulis
	accel = 22,                  -- studs/s^2
}

local function creerPickup(nomModele)
	local source = ReplicatedStorage:FindFirstChild(nomModele or "F150")
	if source and source:IsA("Folder") then
		local modeles = {}
		for _, m in ipairs(source:GetChildren()) do if m:IsA("Model") then table.insert(modeles, m) end end
		source = modeles[math.random(1, math.max(1, #modeles))]
	end
	if not (source and source:IsA("Model")) then return nil end
	local m = source:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BaseScript") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	-- echelle : longueur reelle du F-150 (Catalogue/Car.Longueur), le modele est dessine beaucoup plus grand
	local voulu = PICKUP.longueur
	pcall(function() local Car = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Car")); voulu = Car.Longueur("F150") or voulu end)
	local okB, cfB, taille = pcall(function() return m:GetBoundingBox() end)
	if okB and taille then
		local L = math.max(taille.X, taille.Z)
		if L > 1 then pcall(function() m:ScaleTo(m:GetScale() * voulu / L) end) end
	end
	m.Name = "PickupCirly"
	m.Parent = dossier()
	local pivot = m:GetPivot()
	local PK = { modele = m, roues = {}, parts = {} }
	-- le repere "sol" du pick-up : X = cote, Y = haut, Z = arriere (le modele regarde -Z : phares a l'avant)
	local okB2, cfB2, taille2 = pcall(function() return m:GetBoundingBox() end)
	PK.taille = (okB2 and taille2) or Vector3.new(10, 8, 27)
	PK.bas = okB2 and (pivot:PointToObjectSpace(cfB2.Position).Y - taille2.Y / 2) or -4
	-- roues : groupes Wheel_FL / FR / RL / RR (3 pieces chacune) ; axe = X du modele ; rayon = la plus grande piece
	local groupes = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local g = string.match(p.Name, "^Wheel_(%u%u)")
			if g then
				groupes[g] = groupes[g] or { parts = {}, somme = Vector3.zero, n = 0, rayon = 0 }
				local G = groupes[g]
				table.insert(G.parts, { part = p, offset = pivot:ToObjectSpace(p.CFrame) })
				G.somme += pivot:PointToObjectSpace(p.Position); G.n += 1
				G.rayon = math.max(G.rayon, math.max(p.Size.Y, p.Size.Z) / 2)
			else
				table.insert(PK.parts, { part = p, offset = pivot:ToObjectSpace(p.CFrame) })
			end
		end
	end
	for g, G in pairs(groupes) do
		G.centre = G.somme / G.n
		table.insert(PK.roues, G)
	end
	-- la benne : derriere la cabine ("windo" / "contour"), dessus des flancs ("gris" ou "black")
	local cab, flanc = m:FindFirstChild("windo") or m:FindFirstChild("contour"), m:FindFirstChild("gris") or m:FindFirstChild("black")
	local zCab = cab and (pivot:PointToObjectSpace(cab.Position).Z + cab.Size.Z / 2) or -2
	local yFlanc = flanc and (pivot:PointToObjectSpace(flanc.Position).Y + flanc.Size.Y / 2) or 2
	local zArriere = PK.taille.Z / 2 - 1.0
	PK.benne = { zAvant = zCab + 1.2, zArriere = zArriere, y = yFlanc - 0.6 }
	PK.angle = 0
	return PK
end

-- pose toutes les pieces : cf = repere du pick-up (sans roulis), roulis autour de l'axe des roues exterieures, derive = lacet
local function poserPickup(PK, cf, derive, roulis, cote)
	local base = cf * CFrame.Angles(0, derive, 0)
	if math.abs(roulis) > 1e-3 then
		-- pivot du roulis : la ligne de contact des roues du cote exterieur (bas du modele, demi-largeur)
		local demi = PK.taille.X / 2 - 0.4
		local axe = CFrame.new(cote * demi, PK.bas, 0)       -- cote exterieur du virage (virage a gauche : les roues droites)
		base = base * axe * CFrame.Angles(0, 0, roulis) * axe:Inverse()
	end
	PK.cfCourant = base
	for _, e in ipairs(PK.parts) do e.part.CFrame = base * e.offset end
	for _, G in ipairs(PK.roues) do
		local rot = CFrame.new(G.centre) * CFrame.Angles(PK.angle, 0, 0) * CFrame.new(-G.centre)
		for _, e in ipairs(G.parts) do e.part.CFrame = base * rot * e.offset end
	end
end

-- ItsCirly dans la benne, chaque image : glisse (0..1) vers la ridelle, penche (radians) et saut (studs) selon le roulis
local function dansLaBenne(PK, regarderVers)
	local guide = S.guide
	if not (guide and PK) then return function() end end
	animer("sit", true)
	PK.glisse, PK.penche, PK.saut = 0, 0, 0
	local nom = "TutoBenne"
	RunService:BindToRenderStep(nom, Enum.RenderPriority.Camera.Value - 1, function()
		if not (PK.modele.Parent and guide.Parent and PK.cfCourant) then return end
		local b = PK.benne
		local z = b.zAvant + 1.6 + (b.zArriere - b.zAvant - 2.6) * math.clamp(PK.glisse, 0, 1)
		local cf = PK.cfCourant * CFrame.new(0, b.y + 1.1 + PK.saut, z) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(PK.penche, 0, 0)
		if regarderVers and PK.glisse < 0.05 then
			local p = cf.Position
			local cible = Vector3.new(regarderVers.X, p.Y, regarderVers.Z)
			if (cible - p).Magnitude > 0.5 then cf = CFrame.lookAt(p, cible) end
		end
		guide:PivotTo(cf)
	end)
	return function() RunService:UnbindFromRenderStep(nom) end
end

-- joue le trajet du pick-up (points du serveur : {cf, v, derapage}) ; bloque jusqu'a l'arret. onDerapage() est appele au
-- debut du derapage, onRetombe() quand il retombe sur ses quatre roues.
local function roulerPickup(PK, points, onDerapage, onRetombe)
	if #points == 0 then return end
	-- 1) courbe : Bezier cubique par segment (meme regle que CarManager : poignees = corde / 3 le long des caps), echantillonnee
	local chemin = {}             -- { pos, dir, s (abscisse), v (vitesse cible), derapage }
	local prev = points[1].cf
	local s = 0
	table.insert(chemin, { pos = prev.Position, dir = prev.LookVector, s = 0, v = points[1].v, derapage = points[1].derapage })
	for i = 2, #points do
		local P1 = points[i]
		local p0, p2 = prev.Position, P1.cf.Position
		local k = (p2 - p0).Magnitude / 3
		local c1, c2 = p0 + prev.LookVector * k, p2 - P1.cf.LookVector * k
		local dernier = chemin[#chemin].pos
		for j = 1, 20 do
			local t = j / 20; local u = 1 - t
			local pt = u^3 * p0 + 3 * u^2 * t * c1 + 3 * u * t^2 * c2 + t^3 * p2
			local d = pt - dernier
			s += d.Magnitude
			table.insert(chemin, { pos = pt, dir = d.Magnitude > 1e-4 and d.Unit or P1.cf.LookVector, s = s, v = P1.v, derapage = P1.derapage })
			dernier = pt
		end
		prev = P1.cf
	end
	local longueur = s
	-- zone de derapage : du premier au dernier echantillon marque
	local sDebut, sFin = nil, nil
	for _, e in ipairs(chemin) do if e.derapage then sDebut = sDebut or e.s; sFin = e.s end end
	-- sens du virage dans la zone (gauche = +1, droite = -1) : produit vectoriel des caps a l'entree et a la sortie
	local cote = 1
	if sDebut then
		local dA, dB = nil, nil
		for _, e in ipairs(chemin) do if e.s >= sDebut and not dA then dA = e.dir end; if e.s <= sFin then dB = e.dir end end
		if dA and dB then local c = dA:Cross(dB); cote = (c.Y >= 0) and 1 or -1 end
	end
	local function echantillon(x)
		x = math.clamp(x, 0, longueur)
		local lo, hi = 1, #chemin
		while hi - lo > 1 do local mid = (lo + hi) // 2; if chemin[mid].s <= x then lo = mid else hi = mid end end
		local a, b = chemin[lo], chemin[hi]
		local t = (b.s > a.s) and (x - a.s) / (b.s - a.s) or 0
		local dir = a.dir:Lerp(b.dir, t)
		return a.pos:Lerp(b.pos, t), (dir.Magnitude > 1e-4 and dir.Unit or a.dir), (a.v or 0) * (1 - t) + (b.v or 0) * t
	end
	-- 2) deplacement : vitesse lissee (acceleration bornee), abscisse, roulis / derive en etats continus
	local x, v = 0, points[1].v or 10
	local derive, roulis, saut = 0, 0, 0
	local enDerapage, retombe = false, false
	local vRoulis = 0
	poserPickup(PK, CFrame.lookAt(chemin[1].pos, chemin[1].pos + chemin[1].dir), 0, 0, cote)
	local t0 = os.clock()
	while x < longueur - 0.05 and PK.modele.Parent and os.clock() - t0 < 40 do
		local dt = math.min(RunService.RenderStepped:Wait(), 0.05)
		local _, _, vCible = echantillon(x + 6)
		if vCible < 0.5 and longueur - x < 18 then vCible = math.max(1.5, (longueur - x) * 0.9) end   -- freinage final
		local dv = vCible - v
		v += math.clamp(dv, -PICKUP.accel * 1.8 * dt, PICKUP.accel * dt)
		x += v * dt
		local pos, dir = echantillon(x)
		local cf = CFrame.lookAt(pos, pos + dir)
		-- derapage : dans la zone, la derive et le roulis montent ; en sortant, retombee avec rebond (ressort amorti)
		local dansZone = sDebut and x >= sDebut and x <= sFin
		if dansZone and not enDerapage then enDerapage = true; if onDerapage then task.spawn(onDerapage, cote) end end
		local cibleDerive = dansZone and cote * PICKUP.derive or 0
		local cibleRoulis = dansZone and -cote * PICKUP.roulis or 0
		derive += (cibleDerive - derive) * math.min(1, dt * (dansZone and 5 or 4))
		if dansZone then
			roulis += (cibleRoulis - roulis) * math.min(1, dt * 4)
			vRoulis = 0
		else
			-- ressort : le pick-up retombe sur ses roues, petit rebond
			local acc = -roulis * 140 - vRoulis * 11
			vRoulis += acc * dt
			roulis += vRoulis * dt
			if enDerapage and not retombe and math.abs(roulis) < PICKUP.roulis * 0.25 then retombe = true; if onRetombe then task.spawn(onRetombe) end end
		end
		saut = math.max(0, math.abs(roulis) - PICKUP.roulis * 0.7) * 2
		-- roues : rotation selon la distance (rayon de la premiere roue)
		local rayon = PK.roues[1] and PK.roues[1].rayon or 2
		PK.angle -= (v * dt) / rayon
		poserPickup(PK, cf, derive, roulis, cote)
		-- ItsCirly : glisse vers la ridelle avec le roulis, penche, saute un peu a la retombee
		local r = math.abs(roulis) / PICKUP.roulis
		PK.glisse = math.clamp(r * 1.15, 0, 1)
		PK.penche = -roulis * 0.9
		PK.saut = (not dansZone and enDerapage and not retombe) and math.clamp(math.abs(vRoulis) * 0.2, 0, 1.2) or 0
		PK.vitesse = v
	end
	-- arret propre
	local fin = points[#points].cf
	poserPickup(PK, fin, 0, 0, cote)
	PK.glisse, PK.penche, PK.saut = 0, 0, 0
end

-- ItsCirly assis sur le toit de la voiture, cote client (chaque image)
local function surLeToit(voiture)
	local guide = S.guide
	if not (guide and voiture) then return function() end end
	-- hauteur du toit : le haut des pieces visibles de la carrosserie (pas la boite englobante, qui compte les pieces
	-- invisibles), dans le repere de la voiture
	local pivot = voiture:GetPivot()
	local toit, sommeX, sommeZ, n = 1.5, 0, 0, 0
	for _, p in ipairs(voiture:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.5 and p.Size.X * p.Size.Y * p.Size.Z > 0.5 then
			local l = pivot:PointToObjectSpace(p.Position)
			toit = math.max(toit, l.Y + p.Size.Y / 2)
			sommeX += l.X; sommeZ += l.Z; n += 1
		end
	end
	local centre = n > 0 and Vector3.new(sommeX / n, 0, sommeZ / n) or Vector3.zero
	toit = math.min(toit, 9)
	animer("sit", true)
	local nom = "TutoToit"
	RunService:BindToRenderStep(nom, Enum.RenderPriority.Camera.Value - 1, function()
		if not (voiture.Parent and guide.Parent) then return end
		-- assis : le bassin (pivot du personnage) a ~1 stud au-dessus du toit, un peu vers l'arriere
		local cf = voiture:GetPivot() * CFrame.new(centre.X, toit + 1.1, centre.Z + 1.0)
		guide:PivotTo(cf)
	end)
	return function() RunService:UnbindFromRenderStep(nom) end
end

-- la voiture du tutoriel : l'instance envoyee par le serveur, sinon retrouvee par son nom dans Cars_<userId>
local function trouverVoiture(P, delai)
	local v = P.voiture
	local t0 = os.clock()
	while not (v and v.Parent) and os.clock() - t0 < (delai or 6) do
		local d = P.dossierVoitures and workspace:FindFirstChild(P.dossierVoitures)
		v = (d and P.voitureNom) and d:FindFirstChild(P.voitureNom) or P.voiture
		if not (v and v.Parent) then task.wait(0.1) end
	end
	if v and v.Parent then S.voiture = v return v end
	return S.voiture
end

Etapes.voiture = function(P)
	S.messages = {}
	local voiture = trouverVoiture(P, 8)
	if not voiture then fini("voiture") return end
	fondu(true, 0.25)
	if not S.pickup then                       -- v56 : avec le pick-up, ItsCirly reste assis dans la benne (deja lie)
		local lacher = surLeToit(voiture)
		S.lacherToit = lacher
	end
	-- plan : camera avant-trois-quarts, un peu haute, qui suit la voiture (on voit la voiture ET ItsCirly sur le toit)
	local cote = S.commun.A and -1 or 1
	camSuivre(function()
		local cf = voiture:GetPivot()
		local pos = (cf * CFrame.new(cote * 13, 7.5, -22)).Position
		return CFrame.lookAt(pos, cf.Position + Vector3.new(0, 3, 0))
	end)
	camera.FieldOfView = 62
	-- on attend que la voiture soit sortie du tunnel (elle a roule 35 studs) avant d'ouvrir le noir
	local depart = voiture:GetPivot().Position
	local t1 = os.clock()
	while voiture.Parent and (voiture:GetPivot().Position - depart).Magnitude < 35 and os.clock() - t1 < 6 do task.wait(0.1) end
	camera.CFrame = (function() local cf = voiture:GetPivot(); return CFrame.lookAt((cf * CFrame.new(cote * 13, 7.5, -22)).Position, cf.Position + Vector3.new(0, 3, 0)) end)()
	fondu(false, 0.3)
	dire(S.pickup and "Regarde, la PREMIERE VOITURE arrive ! ...Moi je bouge pas de ma benne. C'est plus classe." or "Regarde, la PREMIERE VOITURE arrive ! ...Oui je suis sur le toit. C'est plus classe.", "sit", 2.6)
	dire("Elle descend la branche, fait la queue devant ton entree, et entre toute seule.", "sit", 2.0)
	montrerPanneau(false)
	fini("voiture")
end

Etapes.arrivee = function(P)
	S.messages = {}
	local voiture = trouverVoiture(P, 2)
	-- vue du dessus centree entre l'entree et la station, qui suit la voiture
	local st = monde(P.station[1], P.station[2], 0).Position
	local c = S.commun
	-- vue haute en trois-quarts depuis le cote de l'entree et de la route du tour (le toit de la station cache la voiture
	-- en vue strictement verticale)
	local versEntree = c.pivot.RightVector * (c.A and -1 or 1)
	local versRoute = (c.pivot * CFrame.new(0, 0, -1)).Position - c.pivot.Position   -- Z plot negatif = route du tour
	camSuivre(function()
		local pos = voiture and voiture.Parent and voiture:GetPivot().Position or st
		local centre = pos:Lerp(st, 0.5)
		return CFrame.lookAt(centre + versEntree * 45 + versRoute * 55 + Vector3.new(0, 62, 0), centre)
	end)
	camera.FieldOfView = 60
	if S.flecheEntree then S.flecheEntree:Destroy(); S.flecheEntree = nil end
	task.spawn(dire, "Elle entre sur ton goudron et se gare dans la station.", "sit", 1.4)
	attendreMessage("garee", 60)
	task.wait(0.4)
	if S.lacherToit then S.lacherToit(); S.lacherToit = nil end
	dire("Garee ! A toi de jouer.", "cheer", 1.3)
	montrerPanneau(false)
	fini("arrivee")
end

Etapes.laver = function(P)
	S.messages = {}
	-- retour au joueur, teleporte a cote de la station (cote client : c'est lui qui possede son personnage)
	fondu(true, 0.3)
	teleporter(P.cfJoueur)
	rendreCamera()
	bandes(false)
	cacherInterfaceJeu(false)
	task.wait(0.2)
	fondu(false, 0.4)
	local station = meubleDuPlot(P.stationID)
	local h = surbrillance(station, VERT)
	objectif("Approche-toi de la station et appuie sur  E  pour laver la voiture")
	regarder(perso() and perso():GetPivot().Position or positionGuide())
	dire("Pas encore d'employe ? Pas grave : lave-la toi-meme ! Approche et appuie sur E.", "point", 2.0)
	montrerPanneau(false)
	attendreMessage("lavage", 120)
	if h then h:Destroy() end
	objectif(nil)
	dire("Et voila, ca mousse ! Plus tard, un EMPLOYE fera ca pour toi.", "cheer", 2.0)
	dire("Pendant ce temps, le client descend... il va payer a la caisse. Suis-le !", "point", 1.6)
	montrerPanneau(false)
	fini("laver")
end

Etapes.suivre = function(P)
	S.messages = {}
	local pnj = P.pnj
	if pnj then
		bandes(true)
		camSuivre(function()
			local cf = pnj:GetPivot()
			return CFrame.lookAt((cf * CFrame.new(3, 4, 7)).Position, cf.Position + Vector3.new(0, 1.5, 0))
		end)
		dire("Il suit le chemin a pied jusqu'a la caisse. Sans chemin, il reste plante dans la station !", "point", 2.2)
		fondu(true, 0.3)
		rendreCamera()
		bandes(false)
		task.wait(0.1)
		fondu(false, 0.4)
	end
	local caisse = meubleDuPlot(P.caisseID)
	local h = surbrillance(caisse, BLEU)
	objectif("Va a la CAISSE et appuie sur  E  pour encaisser")
	regarder(perso() and perso():GetPivot().Position or positionGuide())
	dire("A toi : va a la caisse et appuie sur E pour encaisser. L'argent, c'est le nerf de la guerre !", "point", 2.0)
	montrerPanneau(false)
	local infos = attendreMessage("paye", 150)
	if h then h:Destroy() end
	objectif(nil)
	dire("CHA-CHING ! Ton premier billet. Plus la voiture est rare, plus ca rapporte.", "dance", 2.4)
	montrerPanneau(false)
	fini("suivre")
	return infos
end

Etapes.depart = function(P)
	S.messages = {}
	local voiture = trouverVoiture(P, 2)
	if voiture and voiture.Parent then
		bandes(true)
		camSuivre(function()
			local cf = voiture:GetPivot()
			return CFrame.lookAt((cf * CFrame.new(-10, 6.5, 26)).Position, cf.Position + Vector3.new(0, 1.5, 0))
		end)
		dire("Client content, voiture propre : elle repart par la SORTIE. C'est ca, la boucle. Encore et encore.", "cheer", 2.4)
	else
		dire("Client content, voiture propre : elle repart par la sortie. C'est ca, la boucle.", "cheer", 2.0)
	end
	montrerPanneau(false)
	fini("depart")
end

Etapes.vitrine = function(P)
	S.messages = {}
	fondu(true, 0.5)
	local dossierV, pivot, voitures = nil, nil, {}
	if P.vitrine then dossierV, pivot, voitures = construireVitrine(P.vitrine) end
	if not pivot then
		fondu(false, 0.3)
		dire("Moi, j'ai un plot ENORME. Mais y'a plus de place pour te le montrer... Bref : debutant, pro, bonne chance !", "laugh", 2.4)
		montrerPanneau(false)
		fini("vitrine")
		return
	end
	-- ItsCirly perche sur le toit de la premiere voiture de la file, puis danse
	local centre = (pivot * CFrame.new(135, 0, 90)).Position
	bandes(true)
	-- orbite lente autour de la vitrine
	local t0 = os.clock()
	camSuivre(function()
		local a = (os.clock() - t0) * 0.22
		local pos = centre + Vector3.new(math.cos(a) * 150, 70, math.sin(a) * 150)
		return CFrame.lookAt(pos, centre + Vector3.new(0, 5, 0))
	end)
	camera.FieldOfView = 65
	fondu(false, 0.6)
	if S.guide then S.guide:PivotTo(pivot * CFrame.new(135, 3.1, 135 - DEMI)) end
	dire("Et ca... c'est MON plot. Rouleaux, Karcher, 4 caisses automatiques, des employes, des voitures de LUXE.", "dance", 3.0)
	-- plan serre sur ItsCirly qui rigole
	camSuivre(function()
		local g = positionGuide()
		return CFrame.lookAt(g + Vector3.new(6, 3, 8), g + Vector3.new(0, 2, 0))
	end)
	dire("Toi, t'es un DEBUTANT. Moi, je suis un PRO. Mais bon... bonne chance, tu vas en avoir besoin !", "laugh", 2.6)
	montrerPanneau(false)
	fondu(true, 0.5)
	detruireVitrine(dossierV)
	fini("vitrine")
end

Etapes.fin = function(P)
	S.messages = {}
	teleporter(P.cfJoueur)
	rendreCamera()
	bandes(false)
	task.wait(0.2)
	fondu(false, 0.5)
	regarder(perso() and perso():GetPivot().Position or positionGuide())
	dire("Allez, je te laisse. Pose des routes, achete des stations, engage du monde... et deplace ton ENTREE si besoin.", "point", 2.4)
	dire("Les clients arrivent. A plus, debutant !", "wave", 1.6)
	montrerPanneau(false)
	cacherInterfaceJeu(false)
	fini("fin")
	task.wait(0.6)
	if S.lacherToit then S.lacherToit(); S.lacherToit = nil end
	S.pickup = nil                              -- v56 : le pick-up (dans TutorielLocal) part avec le dossier
	viderDossier()
	if S.gui then S.gui:Destroy(); S.gui = nil end
	S.actif = false
end

-- ----------------------------------------------------------------------------------------------------------------------
-- reception
-- ----------------------------------------------------------------------------------------------------------------------
Event.OnClientEvent:Connect(function(quoi, nom, params)
	if quoi == "etape" then
		if type(params) == "table" and params.commun then
			S.commun = params.commun
			S.guide = params.commun.guide
			if params.commun.orientationStation then S.orientationStation = params.commun.orientationStation end
		end
		local f = Etapes[nom]
		if not f then warn("[Tutoriel] etape inconnue : " .. tostring(nom)); fini(nom); return end
		task.spawn(function()
			local ok, err = pcall(f, params or {})
			if not ok then
				warn("[Tutoriel] etape " .. tostring(nom) .. " : " .. tostring(err))
				fini(nom)
			end
		end)
	elseif quoi == "garee" or quoi == "lavage" or quoi == "paye" then
		S.messages[quoi] = nom or true
	end
end)
