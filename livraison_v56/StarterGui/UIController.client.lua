--[[ UIController v12 (LocalScript, StarterGui) — interface en images (rendues depuis le canvas) + zones cliquables.
	Cette version BRANCHE chaque bouton sur les vraies fonctionnalites du jeu (plus aucune donnee de demonstration) :
		Start   : ecran-titre, puis choix du plot a la camera (< Choose >), puis ChoosePlotfunction
		HUD     : onglets Build / Index / Staff / Stock / Supply, Rank -> panneau Ranks, argent et XP affiches
		Build   : cartes BuildData -> objets du catalogue (table CORRESPONDANCE), fantome, Rotate, Place, Delete, Cancel, Close,
		          camera libre pendant la construction, quadrillage et zones d'extension
		Stock   : produit 1-9, quantite, prix reel, Buy -> Buyfunction
		Supply  : produit 1-9 -> panneaux 3D sur les stations compatibles -> FillStationfunction
		Staff   : Hire -> Hirefunction ; rangees des vrais employes ; Assign (panneaux 3D) / UnAssign / Fire
		Index   : cartes = voitures du catalogue (decouvertes ou silhouettes), filtres, fiche Plus
		Ranks   : rang actuel / suivant, XP et voitures requises (textes ajoutes par-dessus l'image)
	Toute la logique (prix, argent, placement, stock) reste cote serveur ; l'interface n'envoie que des identifiants.
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local joueur = Players.LocalPlayer
local pg = script.Parent:IsA("PlayerGui") and script.Parent or script.Parent.Parent
local PlayerScripts = joueur:WaitForChild("PlayerScripts")
-- v45 : rendu identique a la maquette du designer, sans les boutons Roblox du haut (liste des joueurs, sac, emotes, sante).
-- v49 : le CHAT reste (demande de Thomas : commandes /animation camion, etc.) ; la barre du haut est donc gardee, seuls les
-- autres elements Roblox sont coupes. Le menu Roblox reste accessible avec la touche Echap.
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)
local start = pg:WaitForChild("Menu"); local main = pg:WaitForChild("Main"); local loading = pg:WaitForChild("Loading")
local plot = pg:WaitForChild("Start")   -- UI v21 : choix de l'emplacement (Start / Choose / Label + Center / Minus · Choose · Plus · Dots)
local choose = start:WaitForChild("Choose"); local root = main:WaitForChild("Root")
local hud = root.HUD.HUD1; local menus = root.MENUS

local DIAG = false            -- true : encart de diagnostic en bas a gauche (clics, erreurs)

-- ===== donnees et modules du jeu =====
local ClientData = require(PlayerScripts:WaitForChild("ClientData"))
local ActionManager = require(PlayerScripts:WaitForChild("ActionManager"))
local ClientCamera = require(PlayerScripts:WaitForChild("ClientCamera"))
local Catalogue = require(RS:WaitForChild("Catalogue"))
local Car = require(RS.Catalogue:WaitForChild("Car"))
-- ces trois modules attendent le plot du joueur : charges apres le choix du plot
local ClientBuild, ClientStaff, ClientSupply

local ChoosePlotfunction = RS:WaitForChild("ChoosePlotfunction")
local Buyfunction = RS:WaitForChild("Buyfunction")
local Hirefunction = RS:WaitForChild("Hirefunction")
local Firefunction = RS:WaitForChild("Firefunction")
local UnAssignfunction = RS:WaitForChild("UnAssignfunction")

-- ===== modules dependant du plot (charges une fois le plot choisi) =====
local majHUD                          -- defini dans la section HUD
local function chargerModules()
	task.spawn(function()
		local ok, err = pcall(function()
			ClientBuild = require(PlayerScripts:WaitForChild("ClientBuild"))
			ClientStaff = require(PlayerScripts:WaitForChild("ClientStaff"))
			ClientSupply = require(PlayerScripts:WaitForChild("ClientSupply"))
		end)
		if not ok then warn("[UI] chargement des modules : " .. tostring(err)) end
		if majHUD then majHUD() end
	end)
end

-- ===== erreurs a l'ecran (STUDIO SEULEMENT) : toute erreur de script cote joueur s'affiche en bas a gauche =====
if game:GetService("RunService"):IsStudio() then
	local gui = Instance.new("ScreenGui"); gui.Name = "ErreursUI"; gui.DisplayOrder = 200; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.Parent = pg
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0, 900, 0, 110); lbl.Position = UDim2.new(0, 8, 1, -118); lbl.BackgroundColor3 = Color3.new(0.4, 0, 0); lbl.BackgroundTransparency = 0.3
	lbl.TextColor3 = Color3.new(1, 1, 1); lbl.TextSize = 13; lbl.Font = Enum.Font.Code; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Bottom; lbl.TextWrapped = true; lbl.Visible = false; lbl.Parent = gui
	local lines = {}
	game:GetService("LogService").MessageOut:Connect(function(msg, t)
		if msg:find("Failed to load sound", 1, true) then return end
		if t == Enum.MessageType.MessageError or msg:find("[UI]", 1, true) then
			table.insert(lines, msg); if #lines > 6 then table.remove(lines, 1) end
			lbl.Text = table.concat(lines, "\n"); lbl.Visible = true
		end
	end)
end

-- ===== images : reapplique les numeros d'actif =====
for _, o in ipairs(pg:GetDescendants()) do
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then
		local src = o:FindFirstChild("Src")
		if src and src:IsA("StringValue") and src.Value ~= "" and src.Value ~= "rbxassetid://0" then o.Image = src.Value end
	end
end

-- ===== sons =====
local SND = require(script:WaitForChild("Sounds"))
local function play(name)
	local d = SND[name]; if not d then return end
	pcall(function()
		local s = Instance.new("Sound"); s.SoundId = d.id; s.Volume = d.volume or 0.5; s.PlaybackSpeed = d.pitch or 1; s.Parent = SoundService
		s:Play(); s.Ended:Once(function() s:Destroy() end); task.delay(3, function() if s.Parent then s:Destroy() end end)
	end)
end
-- musique de fond : demarre des l'ecran-titre et tourne en boucle (Sounds.musique ; rien si l'id est vide)
local musique
local function lancerMusique()
	local d = SND.musique
	if musique or not d or not d.id or d.id == "" then return end
	pcall(function()
		musique = Instance.new("Sound"); musique.Name = "Musique"; musique.SoundId = d.id; musique.Volume = d.volume or 0.3
		musique.Looped = true; musique.Parent = SoundService; musique:Play()
	end)
end
local function pressFx(btn)
	if not btn or not btn:IsA("GuiButton") then return end
	btn.MouseButton1Down:Connect(function()
		play("click")
		local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
		sc.Scale = 0.95; TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
end

-- ===== message a l'ecran (toast) =====
local POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local toast = Instance.new("TextLabel"); toast.Name = "Toast"; toast.Size = UDim2.fromOffset(700, 40); toast.Position = UDim2.fromOffset(610, 590)
toast.BackgroundColor3 = Color3.fromHex("178f55"); toast.TextColor3 = Color3.new(1, 1, 1); toast.TextSize = 16; toast.FontFace = POLICE
toast.Visible = false; toast.ZIndex = 60; toast.Parent = root; Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 20)
local toastJeton = 0
local TOASTS = false     -- v49 : plus aucun message au centre de l'ecran (pas prevu dans la maquette, demande de Thomas)
local function message(txt, erreur, duree)
	if not TOASTS then return end
	toast.Text = txt; toast.BackgroundColor3 = erreur and Color3.fromHex("c0302a") or Color3.fromHex("178f55"); toast.Visible = true
	-- (pas de son sur les messages d'erreur : seuls les clics de boutons ont un son)
	toastJeton += 1; local j = toastJeton
	task.delay(duree or 2.5, function() if toastJeton == j then toast.Visible = false end end)
end

-- ===== alertes du serveur (attribut "Alerte" du joueur : ex. pas de route de goudron pour les clients) =====
-- v49 : desactivees (messages au centre de l'ecran supprimes) ; le serveur continue de poser l'attribut, rien n'est affiche.
if TOASTS then
	joueur:GetAttributeChangedSignal("Alerte"):Connect(function()
		local a = joueur:GetAttribute("Alerte")
		if type(a) == "string" and a ~= "" then message((a:gsub(" #%d+$", "")), true, 7) end
	end)
end

-- ===== diagnostic (facultatif) =====
if DIAG then
	local dbg = Instance.new("ScreenGui"); dbg.Name = "Diag"; dbg.DisplayOrder = 100; dbg.IgnoreGuiInset = true; dbg.Parent = pg
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0, 700, 0, 120); lbl.Position = UDim2.new(0, 8, 1, -128); lbl.BackgroundColor3 = Color3.new(0, 0, 0); lbl.BackgroundTransparency = 0.35
	lbl.TextColor3 = Color3.new(1, 1, 1); lbl.TextSize = 12; lbl.Font = Enum.Font.Code; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextYAlignment = Enum.TextYAlignment.Bottom; lbl.TextWrapped = true; lbl.ZIndex = 1000; lbl.Parent = dbg
	local lines = {}
	local function add(m) table.insert(lines, m); if #lines > 8 then table.remove(lines, 1) end; lbl.Text = table.concat(lines, "\n") end
	game:GetService("LogService").MessageOut:Connect(function(msg, t) if t == Enum.MessageType.MessageError or msg:find("StationTycoon") then add((t == Enum.MessageType.MessageError and "ERREUR " or "") .. msg) end end)
	UserInputService.InputBegan:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local objs = pg:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y); local names = {}
			for i, o in ipairs(objs) do if i > 7 then break end table.insert(names, o.Name .. "(" .. o.ClassName:sub(1, 4) .. ")") end
			add(string.format("clic %d,%d gp=%s : %s", input.Position.X, input.Position.Y, tostring(gp), table.concat(names, " > ")))
		end
	end)
	add("diag actif")
end

-- ===== echelle =====
-- L'interface est dessinee en 1920 x 1080 et mise a l'echelle "contain" (rien n'est coupe) : sur un ecran plus large
-- que 16:9 (telephone, 21:9), il reste des bandes a gauche et a droite. Le bandeau du bas est prolonge jusqu'aux bords
-- par un fond de la meme couleur (BandeauFond), place hors de l'echelle, pour qu'il fasse toujours toute la largeur.
local COULEUR_BANDEAU = Color3.fromHex("1d2b3a")     -- couleur du bandeau (Bar0/Bar1) ; echantillonnee en jeu
local bandeau = Instance.new("Frame"); bandeau.Name = "BandeauFond"; bandeau.BackgroundColor3 = COULEUR_BANDEAU
bandeau.BorderSizePixel = 0; bandeau.AnchorPoint = Vector2.new(0.5, 1); bandeau.Position = UDim2.new(0.5, 0, 1, 0)
bandeau.ZIndex = 0; bandeau.Parent = main                -- derriere Root (ZIndex 1)
-- v47 : MISE EN PAGE BORD A BORD. La maquette est dessinee sur une toile 1920 x 1080 ; l'echelle k (min des deux
-- rapports) la fait rentrer dans l'ecran, mais des que l'ecran n'est pas exactement 16/9 il reste des marges et les
-- elements colles aux bords (badge "Choisis ton emplacement", barre du bas, panneaux, rang) se retrouvent decolles.
-- On agrandit donc chaque toile a la taille reelle de l'ecran (en unites 1920 x 1080) et on recale chaque element
-- selon son ancrage : gauche / centre / droite, haut / milieu / bas. Les positions d'origine sont memorisees.
local recalages = {}          -- {obj, hx, vy, etirer}
local function ancrer(obj, hx, vy, etirer)
	if not (obj and obj:IsA("GuiObject")) then return end
	if obj:GetAttribute("ox") == nil then
		obj:SetAttribute("ox", obj.Position.X.Offset); obj:SetAttribute("oy", obj.Position.Y.Offset); obj:SetAttribute("ow", obj.Size.X.Offset)
	end
	table.insert(recalages, {obj = obj, hx = hx, vy = vy, etirer = etirer})
end
local toiles = {}             -- cadres de 1920 x 1080 a agrandir
local function toile(obj) if obj and obj:IsA("GuiObject") then table.insert(toiles, obj) end end
local function estToile(o) return o:IsA("GuiObject") and o.Size.X.Offset == 1920 and o.Size.Y.Offset == 1080 end
-- un panneau dont tout le contenu est ancre pareil (ex. Stock : bas-gauche) : toutes ses toiles, tous ses elements
local function ancrerPanneau(panneau, hx, vy)
	toile(panneau)
	for _, d in ipairs(panneau:GetDescendants()) do
		if estToile(d) then toile(d)
		elseif d:IsA("GuiObject") and d.Parent and (d.Parent == panneau or estToile(d.Parent) or d.Parent:IsA("Folder")) then ancrer(d, hx, vy) end
	end
end
local function recaler(W, H)
	local dx, dy = W - 1920, H - 1080
	for _, t in ipairs(toiles) do t.Size = UDim2.fromOffset(W, H) end
	for _, r in ipairs(recalages) do
		local o = r.obj
		local x = o:GetAttribute("ox") + ((r.hx == "droite") and dx or (r.hx == "centre") and dx / 2 or 0)
		local y = o:GetAttribute("oy") + ((r.vy == "bas") and dy or (r.vy == "milieu") and dy / 2 or 0)
		o.Position = UDim2.new(o.Position.X.Scale, math.floor(x + 0.5), o.Position.Y.Scale, math.floor(y + 0.5))
		if r.etirer then o.Size = UDim2.new(o.Size.X.Scale, o:GetAttribute("ow") + dx, o.Size.Y.Scale, o.Size.Y.Offset) end
	end
end
local function fit()
	local vs = workspace.CurrentCamera.ViewportSize; local k = math.min(vs.X / 1920, vs.Y / 1080)
	for _, sc in ipairs(pg:GetDescendants()) do
		if sc:IsA("UIScale") and sc.Parent and sc.Parent.Parent and sc.Parent.Parent:IsA("ScreenGui") then sc.Scale = k end
	end
	bandeau.Size = UDim2.new(1, 0, 0, math.ceil(58 * k))
	pcall(recaler, math.ceil(vs.X / k), math.ceil(vs.Y / k))
end
-- ancrages (v47)
pcall(function()
	-- ecran "Choisis ton emplacement" : badge colle en haut a gauche, pilule centree collee en bas
	local pc0 = plot:WaitForChild("Choose")
	toile(pc0); ancrer(pc0.Label, "gauche", "haut"); ancrer(pc0.Center, "centre", "bas")
	-- jeu : barre du bas sur toute la largeur, argent a gauche, onglets au centre, rang a droite
	toile(root); toile(hud)
	for _, c in ipairs(hud:GetChildren()) do if estToile(c) then toile(c) end end
	local bar = hud.BarArt
	ancrer(bar.Bar0, "gauche", "bas"); ancrer(bar.Bar1, "droite", "bas")
	for _, c in ipairs(bar:GetChildren()) do if c:IsA("ImageLabel") and c.Name ~= "Bar0" and c.Name ~= "Bar1" then ancrer(c, "centre", "bas") end end
	local fond = Instance.new("Frame"); fond.Name = "BarFond"; fond.Position = UDim2.fromOffset(960, 1022); fond.Size = UDim2.fromOffset(0, 58)
	fond.BorderSizePixel = 0; fond.BackgroundColor3 = Color3.new(1, 1, 1); fond.ZIndex = bar.Bar0.ZIndex; fond.Parent = bar
	local g = Instance.new("UIGradient"); g.Rotation = 90
	g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 68, 79)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(31, 60, 70)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 41, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 37, 44))}); g.Parent = fond
	ancrer(fond, "gauche", "bas", true)                      -- comble l'espace entre les deux moities de la barre
	for _, c in ipairs(hud.Low2:GetChildren()) do ancrer(c, "centre", "bas") end
	ancrer(hud.Low1.Money, "gauche", "bas"); ancrer(hud.Low1.Rank, "droite", "bas")
	-- panneaux : Construction / Stock / Rayons / Personnel colles en bas a gauche ; Index a gauche, sa fiche centree ;
	-- Rangs en bas a droite
	for _, n in ipairs({"Build", "Stock", "Supply", "Staff"}) do ancrerPanneau(menus[n], "gauche", "bas") end
	ancrer(menus.Build.Art.Center, "gauche", "bas", true)   -- la bande de cartes s'etire jusqu'au bord droit
	ancrerPanneau(menus.Index, "gauche", "bas")
	for _, d in ipairs(menus.Index.Plus:GetDescendants()) do
		if d:IsA("GuiObject") and not estToile(d) and (estToile(d.Parent) or d.Parent == menus.Index.Plus) then ancrer(d, "centre", "milieu") end
	end
	ancrerPanneau(menus.Ranks, "droite", "bas")
	ancrer(toast, "centre", "milieu")
end)
fit(); workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
pg.DescendantAdded:Connect(function(d) if d:IsA("UIScale") then task.defer(fit) end end)
task.delay(1, fit); task.delay(3, fit)

-- v42 : dans Roblox, un UIGradient pose sur un TextButton / TextLabel teinte AUSSI le texte (la maquette ne teinte que le
-- fond) : le texte blanc devenait vert sur vert. On deplace fond + degrade + coins dans un Frame "Fond_<nom>" place derriere.
local function separerDegrade(obj)
	if not (obj:IsA("TextButton") or obj:IsA("TextLabel")) then return nil end
	local grad = obj:FindFirstChildOfClass("UIGradient")
	if not grad or obj.BackgroundTransparency >= 1 or obj:GetAttribute("FondSepare") then return obj.Parent:FindFirstChild("Fond_" .. obj.Name) end
	local fond = Instance.new("Frame"); fond.Name = "Fond_" .. obj.Name
	fond.AnchorPoint = obj.AnchorPoint; fond.Position = obj.Position; fond.Size = obj.Size
	fond.BackgroundColor3 = obj.BackgroundColor3; fond.BackgroundTransparency = obj.BackgroundTransparency
	fond.BorderSizePixel = 0; fond.ZIndex = obj.ZIndex - 1; fond.LayoutOrder = obj.LayoutOrder; fond.Visible = obj.Visible
	for _, c in ipairs(obj:GetChildren()) do if c:IsA("UICorner") then c:Clone().Parent = fond end end
	grad.Parent = fond
	obj.BackgroundTransparency = 1
	obj:SetAttribute("FondSepare", true)
	fond.Parent = obj.Parent
	obj:GetPropertyChangedSignal("Visible"):Connect(function() fond.Visible = obj.Visible end)
	obj:GetPropertyChangedSignal("Position"):Connect(function() fond.Position = obj.Position end)
	return fond
end
-- v42 : la maquette ignore la barre Roblox du haut (58 px) ; un element trop haut est descendu juste sous elle
local function sousTopbar(obj, marge)
	task.defer(function()
		local manque = (marge or 8) - obj.AbsolutePosition.Y
		if manque <= 0 then return end
		local k = 1
		local a = obj
		while a and not a:IsA("ScreenGui") do local sc = a:FindFirstChildOfClass("UIScale"); if sc then k = k * sc.Scale end; a = a.Parent end
		obj.Position = obj.Position + UDim2.fromOffset(0, math.ceil(manque / k))
	end)
end
-- v42 : dans les panneaux Stock / Supply de la maquette, l'image de la colonne des familles (Fams) est dessinee APRES
-- Art.Center, donc par-dessus le debut des lignes / la premiere carte (icone et nom caches). On range Fams entre le fond
-- (Art.Base) et le contenu (Art.Center).
local function centreAuDessusDesFamilles(panel)
	local art, fams = panel:FindFirstChild("Art"), panel:FindFirstChild("Fams")   -- Fams est un Folder (F0, F1, F2)
	local centre = art and art:FindFirstChild("Center")
	if not (art and fams and centre) then return end
	-- un Folder est transparent pour la mise en page : ses F0..F2 se placent par rapport au panneau, comme Art
	if (art.AbsolutePosition - panel.AbsolutePosition).Magnitude > 1 or (art.AbsoluteSize - panel.AbsoluteSize).Magnitude > 1 then
		warn("[UI] " .. panel.Name .. " : Art n'a pas le repere du panneau, familles laissees telles quelles"); return
	end
	local base = art:FindFirstChild("Base")
	if base then base.ZIndex = 1 end
	for _, f in ipairs(fams:GetChildren()) do if f:IsA("GuiObject") then f.ZIndex = 2 end end
	centre.ZIndex = 3
	fams.Parent = art
end

-- v45 : dans la maquette (HTML), le contour d'un bouton est une bordure ; exporte en UIStroke "Contextual" sur un
-- TextButton / TextLabel, Roblox le dessine autour de CHAQUE LETTRE (texte baveux : « CHOISIR CET EMPLACEMENT », PASSER,
-- boutons du personnel). On le remet en bordure de bouton (mode Border), sur le fond separe s'il existe.
local function contoursEnBordures(racine)
	for _, d in ipairs(racine:GetDescendants()) do
		if d:IsA("UIStroke") and (d.Parent:IsA("TextButton") or d.Parent:IsA("TextLabel")) and d.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			local obj = d.Parent
			local fond = obj.Parent and obj.Parent:FindFirstChild("Fond_" .. obj.Name)
			if fond then d.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; d.Parent = fond
			elseif obj.BackgroundTransparency < 1 then d.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			else d.Enabled = false end
		end
	end
end

-- fondu d'un cadre entier (remplace les CanvasGroup, que Roblox ne dessine plus au-delà d'une certaine taille)
local function fadeFrame(frame, to, dur)
	for _, o in ipairs(frame:GetDescendants()) do
		local p = {}
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then
			if o:GetAttribute("baseIT") == nil then o:SetAttribute("baseIT", o.ImageTransparency) end
			p.ImageTransparency = (to == 1) and 1 or o:GetAttribute("baseIT")
		end
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			if o:GetAttribute("baseTT") == nil then o:SetAttribute("baseTT", o.TextTransparency) end
			p.TextTransparency = (to == 1) and 1 or o:GetAttribute("baseTT")
		end
		if next(p) then TweenService:Create(o, TweenInfo.new(dur, Enum.EasingStyle.Quad), p):Play() end
	end
end
local function setFaded(frame)
	for _, o in ipairs(frame:GetDescendants()) do
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then if o:GetAttribute("baseIT") == nil then o:SetAttribute("baseIT", o.ImageTransparency) end; o.ImageTransparency = 1 end
		if o:IsA("TextLabel") or o:IsA("TextButton") then if o:GetAttribute("baseTT") == nil then o:SetAttribute("baseTT", o.TextTransparency) end; o.TextTransparency = 1 end
	end
end

-- ===== prechargement des images =====
main.Enabled = false; start.Enabled = false; plot.Enabled = false; loading.Enabled = true
local chargementPasse = false          -- bouton "Passer" de l'ecran de chargement
do
	local assets, seen = {}, {}
	for _, o in ipairs(pg:GetDescendants()) do
		if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.Image ~= "rbxassetid://0" and not seen[o.Image] then seen[o.Image] = true; table.insert(assets, o) end
	end
	-- planches de l'animation de la voiture du menu (DriveData)
	pcall(function()
		for _, id in ipairs(require(start.Choose.Hero.Car.DriveData).sheets) do
			if id ~= "rbxassetid://0" and not seen[id] then seen[id] = true; table.insert(assets, id) end
		end
	end)
	pcall(function()
		local sb = loading.Root.Skip
		sb.Activated:Connect(function() chargementPasse = true end); sb.MouseButton1Click:Connect(function() chargementPasse = true end)
		sb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then chargementPasse = true end end)
		sb.MouseEnter:Connect(function() sb.BackgroundTransparency = 0.1 end); sb.MouseLeave:Connect(function() sb.BackgroundTransparency = 0.3 end)
	end)
	task.spawn(function()      -- reflet qui parcourt la barre de chargement (v23)
		local sh = loading.Root.Bar.Fill:FindFirstChild("Shine")
		while sh and loading.Enabled do sh.Position = UDim2.fromOffset(-120, 0); TweenService:Create(sh, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {Position = UDim2.fromOffset(820, 0)}):Play(); task.wait(1.4) end
	end)
	local bar = loading.Root.Bar.Fill; local status = loading.Root.Status; local total = math.max(1, #assets); local done = 0
	local t0 = os.clock()
	task.spawn(function()
		ContentProvider:PreloadAsync(assets, function()
			done = math.min(total, done + 1); local p = math.clamp(done / total, 0, 1)
			bar.Size = UDim2.fromOffset(math.floor(812 * p), 22); status.Text = string.format("Chargement du garage  %d %%", math.floor(p * 100))
		end)
	end)
	while not chargementPasse and done < total and os.clock() - t0 < 25 do task.wait(0.05) end
	bar.Size = UDim2.fromOffset(812, 22); status.Text = "Prêt !"
	-- la suite (affichage de l'ecran-titre) est faite par terminerChargement(), tout en bas du script, apres le
	-- pre-rendu de tous les panneaux (voir prerendu) : l'interface est alors vraiment prete, pas seulement telechargee
end
-- ===== textures residentes en pleine resolution =====
-- Roblox ne garde en memoire que le niveau de detail correspondant a la taille a laquelle une image est dessinee, et
-- decharge les images qui ne sont plus affichees : un panneau ferme puis rouvert repasse par une version floue.
-- KeepAlive garde donc une copie de CHAQUE image, dessinee en permanence a sa taille reelle (1:1, memes ImageRect),
-- dans un cadre de 6 x 6 px qui rogne tout (ClipsDescendants) : cout d'affichage nul, textures toujours nettes.
-- dans son propre ScreenGui, toujours actif (Main est desactive avant l'entree en jeu), sous tout le reste
local keepGui = Instance.new("ScreenGui"); keepGui.Name = "KeepAlive"; keepGui.DisplayOrder = 0; keepGui.IgnoreGuiInset = true; keepGui.ResetOnSpawn = false; keepGui.Parent = pg
local keep = Instance.new("Frame"); keep.Name = "Cadre"; keep.Size = UDim2.fromOffset(6, 6); keep.Position = UDim2.fromOffset(0, 0)
keep.BackgroundTransparency = 1; keep.ClipsDescendants = true; keep.ZIndex = 0; keep.Parent = keepGui
local residents = {}
local function garderResident(o)
	if not (o:IsA("ImageLabel") or o:IsA("ImageButton")) then return end
	if o.Image == "" or o.Image == "rbxassetid://0" then return end
	local cle = o.Image .. "|" .. tostring(o.ImageRectSize)
	if residents[cle] then return end
	residents[cle] = true
	local il = Instance.new("ImageLabel"); il.Image = o.Image; il.ImageRectSize = o.ImageRectSize; il.ImageRectOffset = o.ImageRectOffset
	local sx, sy = o.Size.X.Offset, o.Size.Y.Offset
	if sx <= 0 or sy <= 0 then sx, sy = math.max(o.AbsoluteSize.X, 1920), math.max(o.AbsoluteSize.Y, 1080) end
	il.Size = UDim2.fromOffset(sx, sy); il.BackgroundTransparency = 1; il.ImageTransparency = 0.9; il.BorderSizePixel = 0; il.ZIndex = 0; il.Parent = keep
end
for _, o in ipairs(pg:GetDescendants()) do garderResident(o) end
pg.DescendantAdded:Connect(function(o) if o:IsDescendantOf(keep) then return end task.defer(garderResident, o) end)

local function terminerChargement()
	loading.Root.Status.Text = "Prêt !"
	task.wait(0.2)
	local fade = Instance.new("Frame"); fade.Size = UDim2.fromScale(1, 1); fade.BackgroundColor3 = Color3.fromHex("1f6fbf"); fade.BackgroundTransparency = 1; fade.ZIndex = 50; fade.Parent = loading
	TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play(); task.wait(0.35)
	start.Enabled = true; loading.Enabled = false; fit()
	lancerMusique()
	fade:Destroy()
end

-- ===== ecran de depart, en deux etapes =====
--   1) "titre"  : l'ecran d'accueil (Menu : fond, tuiles, heros station + voiture, bulles, bouton Choose)
--   2) "plot"   : l'ecran Start de l'UI v21 (badge "Choisis ton emplacement", pilule < Choisir >, points) ; la camera se
--                 pose sur un plot, < > passent d'un plot a l'autre, Choisir le prend (ChoosePlotfunction)
-- ===== ecran-titre v23 : panneau joueur (avatar, pseudo, version), resume de la sauvegarde, apercu 3D du garage, news =====
local function fmtNombre(n)
	local s = tostring(math.floor(tonumber(n) or 0)):reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (s:gsub("^ ", ""))
end
local function fmtMoney(n)
	n = tonumber(n) or 0
	local cents = math.floor((n - math.floor(n)) * 100 + 0.5)
	return string.format("%s,%02d $", fmtNombre(math.floor(n)), cents)      -- v45 : "64 978,00 $" comme la maquette
end
pcall(function()
	-- v45 : position de la maquette conservee (la barre Roblox du haut est desactivee, plus rien ne la recouvre)
	local nom = choose.Player.Txt:FindFirstChild("Name")          -- (":FindFirstChild" : .Name est la propriete Name de Txt)
	if nom then nom.Text = joueur.DisplayName end
	local v = choose.Player.Txt:FindFirstChild("Version"); if v then v.Text = "Version " .. tostring(game.PlaceVersion) end
end)
task.spawn(function()
	local ok, url = pcall(function() return Players:GetUserThumbnailAsync(joueur.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok and choose:FindFirstChild("Player") then choose.Player.Avatar.Image = url end
end)
-- resume de la sauvegarde : attributs poses par le serveur sur le joueur (Money, Rank, Day, XP, XPNext : PlayerData.MajAttributs)
local function saveInfo()
	local money = joueur:GetAttribute("Money") or 0
	local rank = joueur:GetAttribute("Rank") or "Bronze I"; local day = joueur:GetAttribute("Day") or 1
	local st, ss = choose:FindFirstChild("SaveTitle"), choose:FindFirstChild("SaveSub")
	if st then st.Text = "Garage de " .. joueur.DisplayName end
	if ss then ss.Text = string.format("%s · %s · Jour %d · sauvegarde automatique", tostring(rank), fmtMoney(money), tonumber(day) or 1) end
end
saveInfo(); joueur.AttributeChanged:Connect(saveInfo)
-- "Ta partie" : vue 3D du garage du joueur tel qu'il l'a laisse. Le serveur (PlotManager.Apercu) construit une copie de
-- sa parcelle des la connexion, loin sous la map, et donne son nom dans l'attribut PlotPath ; sans construction, on
-- garde l'image d'illustration du cadre.
task.spawn(function()
	local vp = choose:FindFirstChild("PlotView")
	if not (vp and vp:IsA("ViewportFrame")) then return end
	local modele
	for _ = 1, 60 do
		local path = joueur:GetAttribute("PlotPath")
		if path and path ~= "" then modele = workspace:FindFirstChild(path, true) end
		if modele then break end
		task.wait(0.5)
	end
	if not modele then return end
	local ok, err = pcall(function()
		local wm = Instance.new("WorldModel"); wm.Parent = vp
		local m = Instance.new("Model"); m.Name = "Apercu"
		for _, c in ipairs(modele:GetChildren()) do if c:IsA("BasePart") or c:IsA("Model") then c:Clone().Parent = m end end
		m.Parent = wm
		if #m:GetChildren() == 0 then m:Destroy(); wm:Destroy(); return end
		-- v47 : cadrage sur les constructions seules (le decor Decor_* : herbe, trottoirs, routes n'entre pas dans la boite)
		local bati = Instance.new("Model")
		for _, c in ipairs(m:GetChildren()) do if not c.Name:find("^Decor_") then c:Clone().Parent = bati end end
		local cf, size = (#bati:GetChildren() > 0 and bati or m):GetBoundingBox(); bati:Destroy()
		local d = math.max(size.X, size.Z, 30)
		local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam; cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-d * 0.45, d * 0.38, d * 0.62), cf.Position - Vector3.new(0, size.Y * 0.2, 0))
		vp.Ambient = Color3.fromRGB(180, 180, 180); vp.LightColor = Color3.fromRGB(255, 250, 235); vp.LightDirection = Vector3.new(-1, -2, -1)
		vp.Visible = true
	end)
	if not ok then warn("[UI] apercu du garage : " .. tostring(err)) end
end)
-- bouton Newsletter : deroule le panneau des nouveautes
pcall(function()
	local nd = choose.NewsDrop; local ouvert = false
	nd.Visible = false
	pressFx(choose.News)
	choose.News.Activated:Connect(function()
		ouvert = not ouvert
		play("click")
		if ouvert then setFaded(nd); nd.Visible = true; fadeFrame(nd, 0, 0.2) else fadeFrame(nd, 1, 0.15); task.delay(0.16, function() if not ouvert then nd.Visible = false end end) end
	end)
end)
do
	local hero, baseHero = choose.Hero, choose.Hero.Position
	local bubbles = {}
	for _, n in ipairs({"B1", "B2", "B3", "B4"}) do local b = choose[n]; table.insert(bubbles, {f = b, base = b.Position, t = math.random() * 8, dur = 7 + math.random() * 3, dx = math.random(-20, 20)}) end
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		if not start.Enabled or not hero.Visible then return end
		t += dt
		hero.Position = baseHero + UDim2.fromOffset(0, -13 + 13 * math.cos(t * 2 * math.pi / 6)); hero.Rotation = 0.4 * math.sin(t * 2 * math.pi / 6)
		for _, b in ipairs(bubbles) do
			b.t += dt; if b.t > b.dur then b.t = 0; b.dx = math.random(-20, 20) end
			local p = b.t / b.dur; b.f.Position = b.base + UDim2.fromOffset(b.dx * p, -260 * p); b.f.BackgroundTransparency = 1 - math.min(1, p * 5) * (1 - p) * 0.8
		end
	end)
end

local PlotSpawns = workspace:WaitForChild("PlotSpawns")
local plots = {}
for _, p in ipairs(PlotSpawns:GetChildren()) do if p:FindFirstChild("PlotCenter") then table.insert(plots, p) end end
table.sort(plots, function(a, b) return a.Name < b.Name end)
local numero = 1
local etape = "titre"
local starting = false
local enJeu = false
local setHud   -- defini dans la section onglets
local cameraJ = workspace.CurrentCamera
local function plotLibre(p) return p:GetAttribute("OwnerId") == nil end
local function afficherPlot()
	local p = plots[numero]
	local cam = p and p:FindFirstChild("Camera")
	if cam and cam:IsA("BasePart") then
		cameraJ.CameraType = Enum.CameraType.Scriptable
		TweenService:Create(cameraJ, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = cam.CFrame}):Play()
	end
end
-- page "Choisis ton emplacement" de l'UI v21 : Start / Choose (CanvasGroup) / Label, Center / Minus · Choose · Plus · Dots
local pc = plot:WaitForChild("Choose"); local centre = pc:WaitForChild("Center")
local VERT_UI = Color3.fromHex("178f55")
local ptsPagination = {}
do
	-- autant de points que de plots (la page en a 4 : on complete en clonant, repartis autour du centre)
	local dots = centre:FindFirstChild("Dots")
	if dots then
		local modele = dots:FindFirstChild("D1")
		for i = 1, #plots do
			local d = dots:FindFirstChild("D" .. i)
			if not d and modele then d = modele:Clone(); d.Name = "D" .. i; d.Parent = dots end
			if d then
				d.Position = UDim2.fromOffset(math.floor(270 - (#plots - 1) * 9 + (i - 1) * 18 - 5), d.Position.Y.Offset)
				ptsPagination[i] = d
			end
		end
		for _, d in ipairs(dots:GetChildren()) do
			local i = tonumber(d.Name:match("^D(%d+)$"))
			if i and i > #plots then d.Visible = false end
		end
	end
end
local choisirTexte = centre.Choose:IsA("TextButton") and centre.Choose.Text or nil
local labelTexte = pc:FindFirstChild("Label") and pc.Label.Text or nil
for _, o in ipairs(pc:GetDescendants()) do separerDegrade(o) end                     -- v42 : texte blanc, fond degrade
for _, g in ipairs({plot, start, main, loading}) do pcall(contoursEnBordures, g) end   -- v45 : contours = bordures, pas lettres
local fondChoose = centre:FindFirstChild("Fond_Choose")
local function majPagination()
	for i, d in ipairs(ptsPagination) do
		d.BackgroundColor3 = (i == numero) and Color3.fromHex("ffd257") or Color3.new(1, 1, 1)
		d.BackgroundTransparency = (i == numero) and 0 or 0.45
	end
	local p = plots[numero]
	local occupe = p and not plotLibre(p)
	if centre.Choose:IsA("TextButton") and choisirTexte then centre.Choose.Text = occupe and "EMPLACEMENT OCCUPÉ" or choisirTexte end
	local porteur = fondChoose or centre.Choose
	local grad = porteur:FindFirstChildOfClass("UIGradient"); if grad then grad.Enabled = not occupe end
	porteur.BackgroundColor3 = occupe and Color3.fromHex("8a9490") or VERT_UI
	local lbl = pc:FindFirstChild("Label")
	if lbl and labelTexte then lbl.Text = occupe and "EMPLACEMENT OCCUPÉ" or labelTexte end      -- v45 : texte de la maquette, sans compteur
end

local function passerAuChoixDuPlot()
	etape = "plot"
	start.Enabled = false; main.Enabled = false
	plot.Enabled = true
	setFaded(pc); fit(); fadeFrame(pc, 0, 0.35); play("schling")
	for i, p in ipairs(plots) do if plotLibre(p) then numero = i break end end
	afficherPlot(); majPagination()
end

-- clic sur Choose (menu) : la voiture du heros demarre (animation image par image, planches DriveData), puis choix du plot
local function demarrerVoiture()
	local car = choose.Hero:FindFirstChild("Car")
	local DD = car and car:FindFirstChild("DriveData") and require(car.DriveData)
	if not (DD and DD.frames and #DD.frames > 0 and DD.sheets and DD.sheets[1] ~= "rbxassetid://0") then return end
	pcall(function()
		local d = SND.engine
		if d and d.id and d.id ~= "" then
			local snd = Instance.new("Sound"); snd.SoundId = d.id; snd.Volume = d.volume or 0.6; snd.PlaybackSpeed = 0.7; snd.Parent = SoundService; snd:Play()
			TweenService:Create(snd, TweenInfo.new(2.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {PlaybackSpeed = 1.7}):Play()
			task.delay(2.6, function() snd:Destroy() end)
		end
	end)
	local fps, n = 30, #DD.frames            -- v24 : animation re-rendue a 30 images/s (8 planches Drive30_*)
	local t0 = os.clock(); local last = 0
	while true do
		local i = math.floor((os.clock() - t0) * fps) + 1
		if i > n then break end
		if i ~= last then
			last = i; local f = DD.frames[i]
			car.Image = DD.sheets[f.s]; car.ImageRectOffset = Vector2.new(f.rx, f.ry); car.ImageRectSize = Vector2.new(f.rw, f.rh)
			car.Position = UDim2.fromOffset(f.x, f.y); car.Size = UDim2.fromOffset(f.w, f.h)
		end
		RunService.RenderStepped:Wait()
	end
	car.Visible = false
end

local function prendrePlot()
	if starting then return end
	local cible = plots[numero]
	if not (cible and plotLibre(cible)) then message("Cet emplacement est occupé : choisis-en un autre avec ‹ et ›", true) return end
	starting = true
	local okInv, ok = pcall(function() return ChoosePlotfunction:InvokeServer(cible) end)
	if not okInv then starting = false; message("Erreur serveur au choix du plot : " .. tostring(ok), true, 6); warn("[UI] ChoosePlot : " .. tostring(ok)) return end
	if not ok then starting = false; message("Impossible de prendre ce plot (données pas encore chargées ?)", true) return end
	play("open")
	fadeFrame(pc, 1, 0.3); task.wait(0.3)
	plot.Enabled = false
	-- fondu "Chargement du garage…" dans son propre ScreenGui (par-dessus tout)
	local fg = Instance.new("ScreenGui"); fg.Name = "FonduGarage"; fg.DisplayOrder = 150; fg.IgnoreGuiInset = true; fg.ResetOnSpawn = false; fg.Parent = pg
	local fade = Instance.new("Frame"); fade.Size = UDim2.fromScale(1, 1); fade.BackgroundColor3 = Color3.fromHex("0c3054"); fade.BackgroundTransparency = 1; fade.BorderSizePixel = 0; fade.Parent = fg
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 0); lbl.Position = UDim2.fromScale(0, 0.47); lbl.BackgroundTransparency = 1; lbl.Text = "Chargement du garage…"; lbl.TextColor3 = Color3.new(1, 1, 1); lbl.TextSize = 34; lbl.FontFace = POLICE; lbl.TextTransparency = 1; lbl.Parent = fade
	TweenService:Create(fade, TweenInfo.new(0.45), {BackgroundTransparency = 0.05}):Play(); TweenService:Create(lbl, TweenInfo.new(0.45), {TextTransparency = 0}):Play()
	chargerModules()
	task.wait(1.2)
	fg:Destroy()
	cameraJ.CameraType = Enum.CameraType.Custom
	local perso = joueur.Character; if perso then cameraJ.CameraSubject = perso:FindFirstChildOfClass("Humanoid") end
	enJeu = true
	setHud(true)                   -- la barre du bas est toujours visible en jeu ; les panneaux s'ouvrent au clic
end

pressFx(choose.Center.Choose)
local menuEnCours = false
choose.Center.Choose.Activated:Connect(function()
	if etape ~= "titre" or menuEnCours then return end
	menuEnCours = true
	play("open")
	demarrerVoiture()
	task.wait(0.3)
	passerAuChoixDuPlot()
	menuEnCours = false
end)
do
	pressFx(centre.Minus); pressFx(centre.Plus); pressFx(centre.Choose)
	centre.Plus.Activated:Connect(function() if etape == "plot" then numero = numero % #plots + 1; afficherPlot(); majPagination() end end)
	centre.Minus.Activated:Connect(function() if etape == "plot" then numero = (numero - 2) % #plots + 1; afficherPlot(); majPagination() end end)
	centre.Choose.Activated:Connect(function() if etape == "plot" then prendrePlot() end end)
end
for _, p in ipairs(plots) do p:GetAttributeChangedSignal("OwnerId"):Connect(function() if etape == "plot" then majPagination() end end) end

-- ===== HUD : argent, XP, rang (bandeau v23 : Low1.Money.V, Low1.Rank.RankName / Medal.T / XP / Track.Fill) =====
local function label(parent, nom, pos, taille, tailleTexte, align)
	local l = Instance.new("TextLabel"); l.Name = nom; l.Position = pos; l.Size = taille; l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1); l.TextStrokeTransparency = 0.6; l.TextSize = tailleTexte; l.FontFace = POLICE
	l.TextXAlignment = align or Enum.TextXAlignment.Left; l.ZIndex = 30; l.Parent = parent
	return l
end
majHUD = function()
	local lo = hud.Low1
	local d = ClientData.Data
	local money = (d and d.Money) or joueur:GetAttribute("Money") or 0
	local x = (d and d.Xp) or joueur:GetAttribute("XP") or 0
	local rang, suivant = nil, nil
	pcall(function() rang, suivant = ClientData.GetRank() end)
	local nomRang = (rang and rang.Nom) or joueur:GetAttribute("Rank") or "Bronze I"
	local n = (suivant and suivant.Xp) or joueur:GetAttribute("XPNext") or math.max(1, x)
	pcall(function() lo.Money.V.Text = fmtMoney(money) end)
	pcall(function()
		lo.Rank.RankName.Text = string.upper(nomRang)
		local ROMAINS = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII"}
		lo.Rank.Medal.T.Text = ROMAINS[joueur:GetAttribute("RankIndex") or 1] or tostring(nomRang):match("(%S+)$") or ""   -- v55 : numero du rang (1..7)
		lo.Rank.XP.Text = string.format("%s / %s XP", fmtNombre(x), fmtNombre(n))
		TweenService:Create(lo.Rank.Track.Fill, TweenInfo.new(0.4), {Size = UDim2.fromScale(math.clamp(x / math.max(1, n), 0, 1), 1)}):Play()
	end)
end
joueur.AttributeChanged:Connect(function(a) if a == "Money" or a == "XP" or a == "Rank" or a == "XPNext" or a == "RankIndex" then majHUD() end end)
task.spawn(function()          -- reflet qui parcourt la barre d'XP
	local sh = hud.Low1:FindFirstChild("Rank") and hud.Low1.Rank:FindFirstChild("Track") and hud.Low1.Rank.Track:FindFirstChild("Shine")
	while sh do
		if main.Enabled then sh.Position = UDim2.fromOffset(-40, 0); TweenService:Create(sh, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {Position = UDim2.fromOffset(240, 0)}):Play() end
		task.wait(2.8)
	end
end)

-- ===== onglets =====
local TABS = {"Build", "Index", "Staff", "Stock", "Supply", "Station"}   -- v24 : + Ma station (image fixe)
local current = nil
local hudOpen = false
local ouvrir, fermer = {}, {}         -- callbacks par onglet, remplis par les sections ci-dessous
local prechauffer = {}                -- pre-rendu au chargement (facultatif par onglet, sinon ouvrir[] est utilise)
local function setPill(name)
	for _, n in ipairs(TABS) do local a = hud.BarArt:FindFirstChild("Active_" .. n) if a then a.Visible = (n == name) end end
	local ia = hud.BarArt:FindFirstChild("Inactive_Supply"); if ia then ia.Visible = (name ~= "Supply") end
end
local function showPanel(p, on)
	local art = p:FindFirstChild("Art")
	if on then
		-- (pas de setFaded ici : les boutons crees par ouvrir[] pendant le fondu resteraient transparents ; on ne fait que
		-- ramener ce que la fermeture precedente a estompe)
		p.Visible = true
		if art then
			art.Position = UDim2.fromOffset(0, 18)
			TweenService:Create(art, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		end
		fadeFrame(p, 0, 0.2)
	else
		fadeFrame(p, 1, 0.14)
		if art then TweenService:Create(art, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromOffset(0, 12)}):Play() end
		task.delay(0.15, function() if current ~= p.Name then p.Visible = false end end)
	end
end
local function showTab(name)
	if name == current then return end
	local prev = current; current = name
	if prev then showPanel(menus[prev], false); if fermer[prev] then pcall(fermer[prev]) end end
	if name then showPanel(menus[name], true); setPill(name); if ouvrir[name] then pcall(ouvrir[name]) end else setPill(nil) end
end
setHud = function(open)
	hudOpen = open
	if open then
		main.Enabled = true; majHUD(); fit()
		hud.Position = UDim2.fromOffset(0, 70); TweenService:Create(hud, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		showTab(nil); play("open")     -- seule la barre : aucun panneau ouvert
	else
		play("close")
		showTab(nil)
		menus.Ranks.Visible = false
		local shop = menus:FindFirstChild("Shop"); if shop then shop.Visible = false end
		local tw = TweenService:Create(hud, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromOffset(0, 70)})
		tw:Play(); tw.Completed:Once(function() if not hudOpen then main.Enabled = false end end)
	end
end
for _, n in ipairs(TABS) do
	local b = hud.Low2[n]; b.Active = true; b.Selectable = true; pressFx(b)
	b.Activated:Connect(function() if current == n then showTab(nil) else showTab(n) end end)   -- re-cliquer l'onglet ouvert le ferme
end
for _, p in ipairs(TABS) do menus[p].Visible = false end
-- M ou Echap : ferme le panneau ouvert (la barre du bas reste toujours affichee)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if not enJeu then return end
	if input.KeyCode == Enum.KeyCode.Escape and current then showTab(nil)
	elseif input.KeyCode == Enum.KeyCode.M then
		if current then showTab(nil) else showTab("Build") end       -- v56 : regle du designer, M ouvre ET ferme
	end
end)
ClientData.OnDataChanged.Event:Connect(function(cle)
	if cle == "Money" or cle == "Xp" or cle == "Index" then majHUD() end
end)

-- ===== sections isolees : une erreur dans un menu n'empeche pas les autres de fonctionner =====
local function section(nom, f)
	local ok, err = pcall(f)
	if not ok then warn("[UI] section " .. nom .. " : " .. tostring(err)) end
end

-- ===== Ranks (UI v24 : fenetre "Rangs & Récompenses", 8 planches Sel/S0..S7, zones cliquables Hits/Rank1..8 + Close) =====
-- Les planches sont des images completes de la maquette (valeurs d'exemple) ; le rang affiche a l'ouverture est celui du
-- joueur (attribut RankIndex pose par le serveur, 1..7 pour les rangs Bronze..Légende de Catalogue/Rank).
section("Ranks", function()
	local rk = menus.Ranks
	local hits, sel = rk:FindFirstChild("Hits"), rk:FindFirstChild("Sel")
	local function pick(k) if sel then for i = 0, 7 do local f = sel:FindFirstChild("S" .. i) if f then f.Visible = (i == k) end end end end
	local function ouvrirRangs(on)
		if on then
			pick(math.clamp((joueur:GetAttribute("RankIndex") or 1) - 1, 0, 7))
			rk.Visible = true; setFaded(rk); fadeFrame(rk, 0, 0.2); play("open")
		else
			fadeFrame(rk, 1, 0.15); task.delay(0.16, function() rk.Visible = false end); play("close")
		end
	end
	if hits then
		for i = 1, 8 do local b = hits:FindFirstChild("Rank" .. i) if b then pressFx(b); b.Activated:Connect(function() pick(i - 1) end) end end
		local close = hits:FindFirstChild("Close"); if close then pressFx(close); close.Activated:Connect(function() ouvrirRangs(false) end) end
	elseif rk:FindFirstChild("Close") then
		pressFx(rk.Close); rk.Close.Activated:Connect(function() ouvrirRangs(false) end)
	end
	pressFx(hud.Low1.Rank)
	hud.Low1.Rank.Activated:Connect(function() ouvrirRangs(not rk.Visible) end)
	pick(0)
end)

-- ===== Shop (UI v24 : Game Pass / Argent / Voitures, 4 articles par onglet, achat via MarketplaceService) =====
-- Identifiants a remplir par Thomas (Créations -> ton expérience -> Monétisation) : Game Pass pour l'onglet 1, produits
-- developpeur pour les onglets 2 et 3. La remise des recompenses se fait cote serveur (StoreManager / ProcessReceipt).
-- v56 : identifiants lus dans ReplicatedStorage/Catalogue/Boutique (meme fichier que le serveur)
local SHOP = { GamePass = {0, 0, 0, 0}, Money = {0, 0, 0, 0}, Cars = {0, 0, 0, 0} }
pcall(function() SHOP = require(RS:WaitForChild("Catalogue"):WaitForChild("Boutique", 5)).IdsShop() end)
section("Shop", function()
	local sh = menus:FindFirstChild("Shop"); local bouton = hud.Low2:FindFirstChild("Shop")
	if not (sh and bouton) then return end
	local MPS = game:GetService("MarketplaceService")
	local tab = "GamePass"
	local function setTab(t)
		tab = t
		local T = sh:FindFirstChild("Tabs")
		if T then T.T0.Visible = (t == "GamePass"); T.T1.Visible = (t == "Money"); T.T2.Visible = (t == "Cars") end
	end
	local function ouvrirShop(on)
		if on then sh.Visible = true; setFaded(sh); fadeFrame(sh, 0, 0.2); play("open")
		else fadeFrame(sh, 1, 0.15); task.delay(0.16, function() sh.Visible = false end); play("close") end
	end
	local hits = sh:FindFirstChild("Hits")
	if hits then
		for _, t in ipairs({"GamePass", "Money", "Cars"}) do local b = hits:FindFirstChild(t) if b then pressFx(b); b.Activated:Connect(function() setTab(t) end) end end
		for i = 1, 4 do
			local b = hits:FindFirstChild("Buy" .. i)
			if b then
				pressFx(b)
				b.Activated:Connect(function()
					local id = SHOP[tab][i]
					if not id or id == 0 then message("Article bientôt disponible", true) return end
					if tab == "GamePass" then MPS:PromptGamePassPurchase(joueur, id) else MPS:PromptProductPurchase(joueur, id) end
				end)
			end
		end
		local close = hits:FindFirstChild("Close"); if close then pressFx(close); close.Activated:Connect(function() ouvrirShop(false) end) end
	end
	bouton.Active = true; bouton.Selectable = true; pressFx(bouton)
	bouton.Activated:Connect(function() ouvrirShop(not sh.Visible) end)
	setTab("GamePass"); sh.Visible = false
end)

-- ===== Ma station (UI v24 : note globale + detail) =====
-- v56 : les notes viennent du serveur (module Notes : attributs NoteGlobale / NoteProprete / NoteRapidite / NoteAccueil /
-- NoteDecoration, 0..100). L'image de la maquette (Art/Base/T0, a importer) sert de fond ; les valeurs sont des TextLabels
-- et des barres crees par script PAR-DESSUS (aucun objet du designer n'est renomme ni deplace). Positions en fraction du
-- panneau : a ajuster sur la maquette une fois l'image Station_00 importee.
section("Station", function()
	local sn = menus.Station
	local POS = {                      -- {x, y} en fraction du panneau, et largeur
		globale = { 0.50, 0.22 },
		lignes = { { "proprete", "Propreté", 0.40 }, { "rapidite", "Rapidité", 0.50 }, { "accueil", "Accueil", 0.60 }, { "decoration", "Décoration", 0.70 } },
		x = 0.22, largeur = 0.56,
	}
	local calque = sn:FindFirstChild("NotesCalque")
	if not calque then
		calque = Instance.new("Frame"); calque.Name = "NotesCalque"; calque.BackgroundTransparency = 1; calque.Size = UDim2.fromScale(1, 1); calque.ZIndex = 40; calque.Parent = sn
	end
	local function texte(nom, pos, taille, aligne)
		local l = calque:FindFirstChild(nom)
		if not l then
			l = Instance.new("TextLabel"); l.Name = nom; l.BackgroundTransparency = 1; l.FontFace = POLICE; l.TextColor3 = Color3.fromRGB(32, 40, 52)
			l.TextSize = taille; l.ZIndex = 41; l.Parent = calque
		end
		l.Position = UDim2.fromScale(pos[1], pos[2]); l.AnchorPoint = Vector2.new(0.5, 0.5); l.Size = UDim2.fromScale(0.5, 0.08)
		l.TextXAlignment = aligne or Enum.TextXAlignment.Center
		return l
	end
	local etoiles = texte("Globale", POS.globale, 54)
	local sousTitre = texte("GlobaleTexte", { POS.globale[1], POS.globale[2] + 0.07 }, 20)
	local barres = {}
	for _, li in ipairs(POS.lignes) do
		local cle, libelle, y = li[1], li[2], li[3]
		local nom = texte("Nom_" .. cle, { POS.x + 0.08, y }, 22, Enum.TextXAlignment.Left); nom.Size = UDim2.fromScale(0.18, 0.06); nom.Text = libelle
		local val = texte("Val_" .. cle, { POS.x + POS.largeur + 0.05, y }, 22, Enum.TextXAlignment.Right); val.Size = UDim2.fromScale(0.1, 0.06)
		local piste = calque:FindFirstChild("Piste_" .. cle)
		if not piste then
			piste = Instance.new("Frame"); piste.Name = "Piste_" .. cle; piste.BackgroundColor3 = Color3.fromRGB(226, 230, 236); piste.BorderSizePixel = 0; piste.ZIndex = 41
			Instance.new("UICorner", piste).CornerRadius = UDim.new(1, 0)
			local fill = Instance.new("Frame"); fill.Name = "Fill"; fill.BackgroundColor3 = Color3.fromRGB(23, 143, 85); fill.BorderSizePixel = 0; fill.ZIndex = 42; fill.Size = UDim2.fromScale(0, 1)
			Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0); fill.Parent = piste
			piste.Parent = calque
		end
		piste.AnchorPoint = Vector2.new(0, 0.5); piste.Position = UDim2.fromScale(POS.x + 0.18, y); piste.Size = UDim2.fromScale(POS.largeur - 0.22, 0.022)
		barres[cle] = { val = val, fill = piste.Fill }
	end
	local COULEURS = { Color3.fromRGB(220, 110, 100), Color3.fromRGB(235, 185, 60), Color3.fromRGB(23, 143, 85) }
	local function maj()
		local g = joueur:GetAttribute("NoteGlobale") or 0
		local n = math.clamp(math.floor(g / 20 + 0.5), 0, 5)
		etoiles.Text = string.rep("★", n) .. string.rep("☆", 5 - n)
		etoiles.TextColor3 = Color3.fromRGB(245, 185, 40)
		local pourboire = 0.85 + 0.45 * g / 100
		sousTitre.Text = ("Note %d / 100  ·  pourboires ×%.2f  ·  clients ×%.2f"):format(g, pourboire, 0.90 + 0.25 * g / 100)
		for cle, b in pairs(barres) do
			local v = joueur:GetAttribute("Note" .. (cle:gsub("^%l", string.upper))) or 0
			b.val.Text = tostring(v) .. " %"
			b.fill.Size = UDim2.fromScale(math.clamp(v / 100, 0, 1), 1)
			b.fill.BackgroundColor3 = COULEURS[(v < 40 and 1) or (v < 70 and 2) or 3]
		end
	end
	joueur.AttributeChanged:Connect(function(a) if a:sub(1, 4) == "Note" and sn.Visible then maj() end end)
	ouvrir.Station = function() maj() end
	fermer.Station = function() end
	maj()
end)

-- ===== Stock =====
section("Stock", function()
	local st = menus.Stock; local sel, qty = 1, 1
	centreAuDessusDesFamilles(st)                                                     -- v42
	local function refresh()
		for i = 1, 9 do
			local v = st.Art.Variants:FindFirstChild("V" .. i) if v then v.Visible = (i == sel) end
			local r = st.Art.Center:FindFirstChild(tostring(i))
			if r and r:IsA("ImageButton") and r:FindFirstChild("Sel") and r:FindFirstChild("Src") then r.Image = (i == sel) and r.Sel.Value or r.Src.Value end
		end
		local infos = Catalogue.GetInfo("Consommable", tostring(sel))
		st.Right.Box.Text = tostring(qty)
		st.Right.Price.Text = infos and ((infos.Buy * qty) .. "$") or "?"
	end
	for i = 1, 9 do
		local b = st.Art.Center:FindFirstChild(tostring(i))
		if b then
			b.Activated:Connect(function() sel = i; qty = 1; refresh() end)
			b.MouseButton1Down:Connect(function() play("click") end)
		end
	end
	pressFx(st.Right.Minus); pressFx(st.Right.Plus); pressFx(st.Right.Buy)
	-- familles (v23) : Lavage (1-3), Energie (4-6), Pieces auto (7-9) : onglets a gauche, bandeau d'illustration Fams/F0..F2,
	-- seules les cartes de la famille sont visibles (IntValue Fam de chaque carte)
	local famActuelle = 0
	local function setFam(f)
		famActuelle = f
		local fams = st:FindFirstChild("Fams", true)
		if fams then for k = 0, 2 do local fr = fams:FindFirstChild("F" .. k) if fr then fr.Visible = (k == f) end end end
		local premier = nil
		for i = 1, 9 do
			local b = st.Art.Center:FindFirstChild(tostring(i))
			if b then
				local fam = b:FindFirstChild("Fam"); local dedans = (fam == nil) or (fam.Value == f)
				b.Visible = dedans
				if dedans and not premier then premier = i end
			end
		end
		local bs = st.Art.Center:FindFirstChild(tostring(sel)); local fs = bs and bs:FindFirstChild("Fam")
		if fs and fs.Value ~= f and premier then sel = premier; qty = 1 end
		refresh()
	end
	local gauche = st:FindFirstChild("Left")
	if gauche then for k, n in ipairs({"Wash", "Energy", "Parts"}) do local b = gauche:FindFirstChild(n) if b then pressFx(b); b.Activated:Connect(function() play("click"); setFam(k - 1) end) end end end
	-- prochaine livraison (v23, cadran Delivery) : attribut NextDelivery (os.time() serveur du prochain depart du van, Livraison.Commander)
	task.spawn(function()
		local dv = st:FindFirstChild("Delivery")
		if not dv then return end
		while true do
			local nxt = joueur:GetAttribute("NextDelivery")
			local left = nxt and math.max(0, math.floor(nxt - os.time())) or nil
			pcall(function()
				dv.Time.Text = left and string.format("%d:%02d", math.floor(left / 60), left % 60) or "--:--"
				dv.Ring.Prog.Transparency = 0; dv.Ring.Prog.Color = (left and left <= 5) and Color3.fromHex("ffd257") or Color3.fromHex("2dbd75")
				if left == 0 then local sc = dv:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", dv); sc.Scale = 1.08; TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play() end
			end)
			task.wait(1)
		end
	end)
	st.Right.Minus.Activated:Connect(function() qty = math.max(1, qty - 1); refresh() end)
	st.Right.Plus.Activated:Connect(function() qty = math.min(99, qty + 1); refresh() end)
	st.Right.Buy.Activated:Connect(function()
		local sc = st.Right.Buy:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", st.Right.Buy); sc.Scale = 0.94
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
		local ok, eta = Buyfunction:InvokeServer(tostring(sel), qty)
		if ok then
			play("buy")
			local infos = Catalogue.GetInfo("Consommable", tostring(sel))
			if type(eta) == "number" and eta > 0 then
				message(string.format("Commande passée : %d × %s  —  livraison dans %d s", qty, infos and infos.Name or sel, math.ceil(eta)), false, 4)
			else
				message(string.format("Commande passée : %d × %s  —  le camion partira dès que ton plot sera prêt", qty, infos and infos.Name or sel), false, 4)
			end
		else
			-- v49 : plus de message au centre de l'ecran : la raison s'affiche dans le panneau Stock (ligne Camion), 4 s
			local lbl = st.Right:FindFirstChild("Camion")
			if lbl then
				lbl.Text = "Achat refusé : argent ou place de stockage insuffisants"
				task.delay(4, function() if lbl.Text:sub(1, 12) == "Achat refusé" then lbl.Text = "" end end)
			end
		end
	end)

	-- camion de livraison : compte a rebours dans l'onglet + message a la livraison (RemoteEvent LivraisonEvent, serveur)
	local camion = Instance.new("TextLabel"); camion.Name = "Camion"; camion.AnchorPoint = Vector2.new(0.5, 1)
	camion.Size = UDim2.new(1, -10, 0, 22); camion.Position = UDim2.new(0.5, 0, 1, -6); camion.BackgroundTransparency = 1
	camion.TextColor3 = Color3.fromHex("ffd166"); camion.TextSize = 15; camion.FontFace = POLICE; camion.TextScaled = false
	camion.Text = ""; camion.ZIndex = 30; camion.Parent = st.Right
	local arrivee = nil                                        -- heure serveur de la livraison en cours
	local LivraisonEvent = RS:WaitForChild("LivraisonEvent", 15)
	if LivraisonEvent then
		LivraisonEvent.OnClientEvent:Connect(function(quoi, arg, arg2)
			if quoi == "commande" and type(arg) == "number" then
				arrivee = workspace:GetServerTimeNow() + arg
			elseif quoi == "deposee" then
				arrivee = nil; camion.Text = "Cartons déposés au garage " .. tostring(arg2 or "") .. " : va les récupérer (E)"
				message(("Ta livraison est déposée devant le garage %s (%d cartons) : va les récupérer avec E, ou laisse ton logisticien s'en charger"):format(tostring(arg2 or ""), tonumber(arg) or 0), false, 7)
			elseif quoi == "message" and type(arg) == "string" then
				message(arg, true, 4)
			elseif quoi == "livree" then
				arrivee = nil; camion.Text = ""
				local parts = {}
				if type(arg) == "table" then for _, l in ipairs(arg) do table.insert(parts, ("%d × %s"):format(l.qte or 0, tostring(l.nom or l.item))) end end
				play("buy")
				message("Livraison reçue : " .. (#parts > 0 and table.concat(parts, ", ") or "ta commande") .. string.format("  —  inventaire %d / %d L", ClientData.GetCurrentVolume(), ClientData.GetMaxVolume()), false, 5)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			if arrivee then
				local reste = arrivee - workspace:GetServerTimeNow()
				camion.Text = reste > 0 and ("Le van arrive au garage dans %d s"):format(math.ceil(reste)) or "Le van arrive au garage…"
			end
		end
	end)
	ouvrir.Stock = function() setFam(famActuelle) end
	setFam(0)
end)

-- ===== Supply =====
section("Supply", function()
	local sp = menus.Supply
	centreAuDessusDesFamilles(sp)                                                     -- v42
	local sel = nil
	local function select(k)
		sel = k
		local variants = sp.Art:FindFirstChild("Variants")
		for i = 1, 9 do
			if variants then local v = variants:FindFirstChild("V" .. i) if v then v.Visible = (i == k) end end
			local b = sp.Art.Center:FindFirstChild(tostring(i))
			if b and b:IsA("ImageButton") and b:FindFirstChild("Sel") and b:FindFirstChild("Src") then b.Image = (i == k) and b.Sel.Value or b.Src.Value end
		end
		if ClientSupply and k then
			local function refresh() if sel == k then ClientSupply.CreateUIStations(tostring(k), function() end) end end
			ClientSupply.CreateUIStations(tostring(k), refresh)
		end
	end
	for i = 1, 9 do
		local b = sp.Art.Center:FindFirstChild(tostring(i))
		if b then
			b.Activated:Connect(function() select(i) end)
			b.MouseButton1Down:Connect(function() play("click") end)
		end
	end
	-- familles (v23) : Lavage / Energie / Pieces auto, premiere carte de la famille selectionnee
	local FIRST = {2, 4, 7}
	local famActuelle = 0
	local function setFam(f)
		famActuelle = f
		local fams = sp:FindFirstChild("Fams", true)
		if fams then for k = 0, 2 do local fr = fams:FindFirstChild("F" .. k) if fr then fr.Visible = (k == f) end end end
		for i = 1, 9 do
			local b = sp.Art.Center:FindFirstChild(tostring(i))
			if b then local fam = b:FindFirstChild("Fam"); b.Visible = (fam == nil) or (fam.Value == f) end
		end
		local bs = sel and sp.Art.Center:FindFirstChild(tostring(sel)); local fs = bs and bs:FindFirstChild("Fam")
		if not sel or (fs and fs.Value ~= f) then select(FIRST[f + 1]) else select(sel) end
	end
	local gauche = sp:FindFirstChild("Left")
	if gauche then for k, n in ipairs({"Wash", "Energy", "Parts"}) do local b = gauche:FindFirstChild(n) if b then pressFx(b); b.Activated:Connect(function() play("click"); setFam(k - 1) end) end end end
	ouvrir.Supply = function() setFam(famActuelle) end
	fermer.Supply = function() if ClientSupply then ClientSupply.DestroyUIStations() end end
end)

-- ===== Staff =====
section("Staff", function()
	local sf = menus.Staff; local tpl = sf.Staff.Template; local list = sf.Left.List
	local G = ColorSequence.new(Color3.fromHex("23a866"), Color3.fromHex("127f4b")); local W = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("eef0ea"))
	local ROLE = {Attendant = "Attendant", Cashier = "Caissier", Logistician = "Logistique"}      -- libelles v24
	local COULEUR_AV = {Attendant = Color3.fromHex("2f7fd6"), Cashier = Color3.fromHex("8e44d6"), Logistician = Color3.fromHex("e87818")}
	local function refresh()
		for _, c in ipairs(list:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		local d = ClientData.Data
		if not (d and d.Workers) then return end
		local ids = {}
		for id in pairs(d.Workers) do table.insert(ids, id) end
		table.sort(ids, function(a, b) return (d.Workers[a].Name .. a) < (d.Workers[b].Name .. b) end)
		local sansLayout = list:FindFirstChildWhichIsA("UIListLayout") == nil
		for i, id in ipairs(ids) do
			local w = d.Workers[id]
			local row = tpl:Clone(); row.Visible = true; row.Name = id; row.LayoutOrder = i
			if sansLayout then row.Position = UDim2.fromOffset(0, (i - 1) * 56) end
			local assigned = w.Furniture ~= nil
			row.N.Text = w.Name or "?"; row.Av.T.Text = (w.Name or "?"):sub(1, 1); row.Av.BackgroundColor3 = COULEUR_AV[w.Type] or Color3.fromHex("8e44d6")
			local grad = row:FindFirstChildOfClass("UIGradient"); if grad then grad.Color = assigned and G or W end
			row.N.TextColor3 = assigned and Color3.new(1, 1, 1) or Color3.fromHex("213038")
			row.R.TextColor3 = assigned and Color3.fromHex("d6f2e2") or Color3.fromHex("5b6b70")
			row.R.Text = (ROLE[w.Type] or w.Type) .. (assigned and " ✓" or "")                     -- v24 : liste de 8 lignes, libelle court
			row.Assign.Visible = not assigned; row.UnAssign.Visible = assigned
			pressFx(row.Assign); pressFx(row.UnAssign); pressFx(row.Fire)
			row.Assign.Activated:Connect(function()
				if not ClientStaff then return end
				ClientStaff.DestroyUIStations(); ClientStaff.DestroyUICaisses(); if ClientStaff.DestroyUIGarage then ClientStaff.DestroyUIGarage() end
				if w.Type == "Attendant" then ClientStaff.CreateUIStations(id, refresh)
				elseif w.Type == "Logistician" and ClientStaff.CreateUIGarage then ClientStaff.CreateUIGarage(id, refresh)
				else ClientStaff.CreateUICaisses(id, refresh) end
				local ou = w.Type == "Attendant" and "au-dessus d'une station" or (w.Type == "Logistician" and "du garage de l'atelier (au bord de l'avenue, marqué sur la carte)" or "au-dessus d'une caisse")
				message("Clique le panneau " .. ou .. " pour y affecter " .. (w.Name or "l'employé"), false, 5)
			end)
			row.UnAssign.Activated:Connect(function() UnAssignfunction:InvokeServer(id) end)
			row.Fire.Activated:Connect(function() Firefunction:InvokeServer(id); if ClientStaff then ClientStaff.DestroyUIStations(); ClientStaff.DestroyUICaisses(); if ClientStaff.DestroyUIGarage then ClientStaff.DestroyUIGarage() end end end)
			row.Parent = list
		end
	end
	pressFx(sf.Top.Hire); pressFx(sf.Top.Assign)
	local function embaucher(type_)
		local ok = Hirefunction:InvokeServer(type_)
		if ok == false then message("Embauche refusée", true) else play("buy") end
	end
	-- UI v24 : 4 cartes de recrutement (Attendant, Caissier, Logistique, Agent d'entretien) -> types serveur de WorkerManager
	local METIERS = { Attendant = "Attendant", Cashier = "Cashier", Logistics = "Logistician", Cleaner = "Cleaner" }   -- v56 : agent d'entretien code (Notes)
	for carte, type_ in pairs({ Attendant = "Attendant", Cashier = "Cashier", Logistics = "Logistician", Cleaner = "Cleaner" }) do
		local c = sf.CenterHire:FindFirstChild(carte); local b = c and c:FindFirstChild("Hire")
		if b then
			pressFx(b)
			b.Activated:Connect(function()
				embaucher(METIERS[carte])
			end)
		end
	end
	local function onglet(assign)
		local art = sf.Art:FindFirstChild("Assign"); if art then art.Visible = assign end
		sf.CenterHire.Visible = not assign
	end
	sf.Top.Hire.Activated:Connect(function() onglet(false) end)
	sf.Top.Assign.Activated:Connect(function() onglet(true) end)
	ClientData.OnDataChanged.Event:Connect(function(cle) if cle == "Workers" and menus.Staff.Visible then refresh() end end)
	ouvrir.Staff = function() onglet(false); refresh() end
	fermer.Staff = function() if ClientStaff then ClientStaff.DestroyUIStations(); ClientStaff.DestroyUICaisses(); if ClientStaff.DestroyUIGarage then ClientStaff.DestroyUIGarage() end end end
end)

-- ===== Index =====
section("Index", function()
	local ix = menus.Index
	local FILTERS = {"All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine"}
	-- cartes du canvas : 2 par rarete pour les 5 premieres, 1 pour Mythic et Divine (dupliquee si besoin)
	local CARTE_PAR_TIER = {Common = {1, 2}, Uncommon = {3, 4}, Rare = {5, 6}, Epic = {7, 8}, Legendary = {9, 10}, Mythic = {11}, Divine = {12}}
	local function carteSource(i) return ix.Art.Center:FindFirstChild(string.format("IndexCard_%02d", i)) end
	-- l'UI v21 n'a plus de ViewportFrame "Car" dans les cartes ni dans la fiche Plus : on le cree (memes dimensions qu'avant)
	local function vpCarte(card)
		local vp = card:FindFirstChild("Car")
		if not vp then vp = Instance.new("ViewportFrame"); vp.Name = "Car"; vp.Size = UDim2.fromOffset(250, 156); vp.BackgroundTransparency = 1; vp.ZIndex = (card.ZIndex or 22) + 2; vp.Parent = card end
		return vp
	end
	local function vpPlus()
		local vp = ix.Plus:FindFirstChild("Car")
		if not vp then vp = Instance.new("ViewportFrame"); vp.Name = "Car"; vp.Position = UDim2.fromOffset(616, 341); vp.Size = UDim2.fromOffset(400, 250); vp.BackgroundTransparency = 1; vp.ZIndex = 43; vp.Parent = ix.Plus end
		return vp
	end
	local function viewport(vp, modele, decouverte)
		for _, ch in ipairs(vp:GetChildren()) do if ch:IsA("WorldModel") or ch:IsA("Camera") then ch:Destroy() end end
		local world = Instance.new("WorldModel"); world.Parent = vp
		local m = modele:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy()
			elseif not decouverte then
				if d:IsA("BasePart") then d.Color = Color3.new(0, 0, 0); d.Material = Enum.Material.Neon
					local sa = d:FindFirstChildOfClass("SurfaceAppearance"); if sa then sa:Destroy() end
					if d:IsA("MeshPart") then pcall(function() d.TextureID = "" end) end
				elseif d:IsA("Texture") or d:IsA("Decal") then d:Destroy() end
			end
		end
		m.Parent = world
		local cf, size = m:GetBoundingBox(); local dist = math.max(size.X, size.Z)
		local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, dist * 0.55, -dist * 1.45), cf.Position); cam.FieldOfView = 32
		m:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(40), 0)); vp.Visible = true
		return m
	end
	local cartes = {}          -- {card, tier, nom, modele, liaison}
	local construit = false
	local function construire()
		if construit then return end; construit = true
		for _, tier in ipairs(Car.Ordre) do
			local pool = Car[tier]; local sources = CARTE_PAR_TIER[tier] or {12}
			for k, nom in ipairs(pool.Models) do
				local src = carteSource(sources[k] or sources[#sources])
				if src then
					local card = (sources[k] and k <= #sources) and src or src:Clone()
					if card ~= src then card.Name = src.Name .. "_" .. nom; card.Parent = ix.Art.Center end
					local modele = Car.Modele and Car.Modele(tier, nom) or nil
					table.insert(cartes, {card = card, tier = tier, nom = nom, modele = modele})
				end
			end
		end
	end
	local function peindre(filtre)
		local d = ClientData.Data or {}; local index = d.Index or {}
		local k = 0
		for _, c in ipairs(cartes) do
			local quantite = (index[c.tier] and index[c.tier][c.nom]) or 0
			local visible = (filtre == "All" or filtre == c.tier)
			c.card.Visible = visible
			if visible then
				local col, row = k % 3, math.floor(k / 3); k += 1
				c.card.Position = UDim2.fromOffset(4 + col * 263, 4 + row * 186)
				local decouverte = quantite > 0
				if c.modele and c.decouverte ~= decouverte then
					c.decouverte = decouverte
					c.m = viewport(vpCarte(c.card), c.modele, decouverte)
					if not c.liaison then
						c.liaison = true
						local angle, conn = math.rad(40), nil
						c.card.Clic.MouseEnter:Connect(function() if c.m and not conn then conn = RunService.RenderStepped:Connect(function(dt) angle += dt * 1.2; local cf = c.m:GetPivot(); c.m:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, angle, 0)) end) end end)
						c.card.Clic.MouseLeave:Connect(function() if conn then conn:Disconnect(); conn = nil end end)
						c.card.Clic.Activated:Connect(function()
							ix.Plus.Visible = true
							local pm = viewport(vpPlus(), c.modele, c.decouverte)
							local a = math.rad(40); local pc
							pc = RunService.RenderStepped:Connect(function(dt) if not ix.Plus.Visible then pc:Disconnect(); return end a += dt * 0.8; local cf = pm:GetPivot(); pm:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, a, 0)) end)
							local q = ((ClientData.Data or {}).Index or {})[c.tier]; q = q and q[c.nom] or 0
							message(string.format("%s (%s) — vue %d fois", c.nom, c.tier, q), false, 3)
						end)
					end
				end
			end
		end
		ix.Art.Center.CanvasSize = UDim2.fromOffset(0, 8 + math.ceil(k / 3) * 186)
	end
	local filtreActuel = "All"
	pressFx(ix.Plus.Close)
	ix.Plus.Close.Activated:Connect(function() ix.Plus.Visible = false end)
	for _, name in ipairs(FILTERS) do local b = ix.Right:FindFirstChild(name); if b then pressFx(b); b.Activated:Connect(function() filtreActuel = name; peindre(name) end) end end
	ouvrir.Index = function() construire(); peindre(filtreActuel) end
	fermer.Index = function() ix.Plus.Visible = false end
	ClientData.OnDataChanged.Event:Connect(function(cle) if cle == "Index" and menus.Index.Visible then peindre(filtreActuel) end end)
end)

-- ===== Build =====
section("Build", function()
	local bd = menus.Build
	local DATA = require(bd.Build.BuildData)
	local tpl = bd.Build.TemplateBouton
	local CATS = {Floor = "sol", Wall = "murs", Furniture = "stations", Utility = "utilitaires", Deco = "deco", Roof = "toit"}
	local ONGLETS = {"sol", "murs", "stations", "utilitaires", "deco", "toit"}
	-- Image publiee en double : Variants/V_mobilier/T0 (moitie gauche : titre + boutons de categorie) a recu la meme
	-- image que T1 (moitie droite), d'ou une barre d'outils en double et plus de boutons de categorie dans l'onglet
	-- mobilier. On masque cette moitie gauche pour laisser voir celle du fond (Base/T0), qui contient les boutons.
	-- A retirer quand la bonne image V_mobilier_T0 sera publiee et son numero renseigne dans Src.
	local IMAGES_EN_DOUBLE = {["81276375909626"] = true, ["104569280553761"] = true}
	for _, couche in ipairs(bd.Art.Variants:GetChildren()) do
		local t0 = couche:FindFirstChild("T0")
		if t0 and t0:IsA("ImageLabel") then
			local id = string.match(t0.Image, "%d+")
			if id and IMAGES_EN_DOUBLE[id] then
				t0.Visible = false
				warn("[UI] " .. couche.Name .. "/T0 : image publiee en double, moitie gauche masquee (republier V_" .. couche.Name:sub(3) .. "_T0)")
			end
		end
	end
	-- CARTES : carte du menu Build -> {categorie du catalogue, {variante 1, variante 2, ...}}
	-- Les premieres variantes correspondent aux images (sprites) de la carte ; les suivantes sont montrees en 3D.
	local CARTES = {
		x_goudron = {"Sol", {"sol_goudron", "sol_route", "sol_beton"}},
		sol_parquets = {"Sol", {"sol_parquet_clair", "sol_chene_dore", "sol_chevron", "sol_parquet_fonce", "sol_planches_larges", "sol_batons_rompus", "sol_chene_rustique", "sol_chevron_pale", "sol_echelle", "sol_parquet_chevron", "sol_parquet_larges", "sol_parquet_rouge", "sol_parquet_vieilli", "sol_planches_fines"}},
		sol_carrelages = {"Sol", {"sol_carrelage_gris", "sol_damier", "sol_marbre", "sol_terrazzo", "sol_mosaique", "sol_ardoise", "sol_moquette"}},
		sol_exterieur = {"Sol", {"sol_beton", "sol_paves", "sol_goudron", "sol_graviers", "sol_galets", "sol_briques", "sol_route"}},
		murs_plein = {"Mur", {"mur_plein_brique", "mur_plein_clin", "mur_plein_crepi", "mur_plein_enduit", "mur_plein_pierre"}},
		murs_vitrine = {"Mur", {"mur_vitrine_brique", "mur_vitrine_clin", "mur_vitrine_crepi", "mur_vitrine_enduit", "mur_vitrine_pierre"}},
		murs_muret = {"Mur", {"mur_muret_brique", "mur_muret_clin", "mur_muret_crepi", "mur_muret_enduit", "mur_muret_pierre"}},
		x_murs_vitrine = {"Mur", {"mur_vitrine_brique", "mur_vitrine_clin", "mur_vitrine_crepi", "mur_vitrine_enduit", "mur_vitrine_pierre"}},
		x_murs_muret = {"Mur", {"mur_muret_brique", "mur_muret_clin", "mur_muret_crepi", "mur_muret_enduit", "mur_muret_pierre"}},
		fen_simple = {"Mur", {"mur_fenetre_simple_brique", "mur_fenetre_simple_clin", "mur_fenetre_simple_crepi", "mur_fenetre_simple_enduit", "mur_fenetre_simple_pierre"}},
		fen_arche = {"Mur", {"mur_baie_arche_brique", "mur_baie_arche_clin", "mur_baie_arche_crepi", "mur_baie_arche_enduit", "mur_baie_arche_pierre"}},
		fen_double = {"Mur", {"mur_vitrine_brique", "mur_vitrine_clin", "mur_vitrine_crepi", "mur_vitrine_enduit", "mur_vitrine_pierre"}},
		porte_bois = {"Mur", {"mur_porte_bois_brique", "mur_porte_bois_clin", "mur_porte_bois_crepi", "mur_porte_bois_enduit", "mur_porte_bois_pierre"}},
		porte_garage = {"Mur", {"mur_porte_garage_brique", "mur_porte_garage_clin", "mur_porte_garage_crepi", "mur_porte_garage_enduit", "mur_porte_garage_pierre"}},
		porte_vitree = {"Mur", {"mur_porte_double_vitree_brique", "mur_porte_double_vitree_clin", "mur_porte_double_vitree_crepi", "mur_porte_double_vitree_enduit", "mur_porte_double_vitree_pierre"}},
		x_mur_fenetre_haute = {"Mur", {"mur_fenetre_haute_brique", "mur_fenetre_haute_clin", "mur_fenetre_haute_crepi", "mur_fenetre_haute_enduit", "mur_fenetre_haute_pierre"}},
		x_mur_fenetre_grille = {"Mur", {"mur_fenetre_grille_brique", "mur_fenetre_grille_clin", "mur_fenetre_grille_crepi", "mur_fenetre_grille_enduit", "mur_fenetre_grille_pierre"}},
		x_mur_fenetre_arche_croix = {"Mur", {"mur_fenetre_arche_croix_brique", "mur_fenetre_arche_croix_clin", "mur_fenetre_arche_croix_crepi", "mur_fenetre_arche_croix_enduit", "mur_fenetre_arche_croix_pierre"}},
		x_mur_fenetre_arche_pleine = {"Mur", {"mur_fenetre_arche_pleine_brique", "mur_fenetre_arche_pleine_clin", "mur_fenetre_arche_pleine_crepi", "mur_fenetre_arche_pleine_enduit", "mur_fenetre_arche_pleine_pierre"}},
		x_mur_fenetre_arche_vitrine = {"Mur", {"mur_fenetre_arche_vitrine_brique", "mur_fenetre_arche_vitrine_clin", "mur_fenetre_arche_vitrine_crepi", "mur_fenetre_arche_vitrine_enduit", "mur_fenetre_arche_vitrine_pierre"}},
		x_mur_baie_arche_nue = {"Mur", {"mur_baie_arche_nue_brique", "mur_baie_arche_nue_clin", "mur_baie_arche_nue_crepi", "mur_baie_arche_nue_enduit", "mur_baie_arche_nue_pierre"}},
		x_mur_baie_barreaudee = {"Mur", {"mur_baie_barreaudee_brique", "mur_baie_barreaudee_clin", "mur_baie_barreaudee_crepi", "mur_baie_barreaudee_enduit", "mur_baie_barreaudee_pierre"}},
		x_mur_baie_croisee = {"Mur", {"mur_baie_croisee_brique", "mur_baie_croisee_clin", "mur_baie_croisee_crepi", "mur_baie_croisee_enduit", "mur_baie_croisee_pierre"}},
		x_mur_baie_grille = {"Mur", {"mur_baie_grille_brique", "mur_baie_grille_clin", "mur_baie_grille_crepi", "mur_baie_grille_enduit", "mur_baie_grille_pierre"}},
		x_mur_baie_simple = {"Mur", {"mur_baie_simple_brique", "mur_baie_simple_clin", "mur_baie_simple_crepi", "mur_baie_simple_enduit", "mur_baie_simple_pierre"}},
		x_mur_deux_baies = {"Mur", {"mur_deux_baies_brique", "mur_deux_baies_clin", "mur_deux_baies_crepi", "mur_deux_baies_enduit", "mur_deux_baies_pierre"}},
		x_mur_porte = {"Mur", {"mur_porte_brique", "mur_porte_clin", "mur_porte_crepi", "mur_porte_enduit", "mur_porte_pierre"}},
		x_mur_porte_blanche = {"Mur", {"mur_porte_blanche_brique", "mur_porte_blanche_clin", "mur_porte_blanche_crepi", "mur_porte_blanche_enduit", "mur_porte_blanche_pierre"}},
		x_mur_porte_deco = {"Mur", {"mur_porte_deco_brique", "mur_porte_deco_clin", "mur_porte_deco_crepi", "mur_porte_deco_enduit", "mur_porte_deco_pierre"}},
		x_mur_porte_double_bois = {"Mur", {"mur_porte_double_bois_brique", "mur_porte_double_bois_clin", "mur_porte_double_bois_crepi", "mur_porte_double_bois_enduit", "mur_porte_double_bois_pierre"}},
		x_mur_porte_double_verte = {"Mur", {"mur_porte_double_verte_brique", "mur_porte_double_verte_clin", "mur_porte_double_verte_crepi", "mur_porte_double_verte_enduit", "mur_porte_double_verte_pierre"}},
		x_mur_porte_imposte = {"Mur", {"mur_porte_imposte_brique", "mur_porte_imposte_clin", "mur_porte_imposte_crepi", "mur_porte_imposte_enduit", "mur_porte_imposte_pierre"}},
		x_mur_porte_pleine = {"Mur", {"mur_porte_pleine_brique", "mur_porte_pleine_clin", "mur_porte_pleine_crepi", "mur_porte_pleine_enduit", "mur_porte_pleine_pierre"}},
		x_mur_porte_service_bois = {"Mur", {"mur_porte_service_bois_brique", "mur_porte_service_bois_clin", "mur_porte_service_bois_crepi", "mur_porte_service_bois_enduit", "mur_porte_service_bois_pierre"}},
		x_mur_porte_service_verte = {"Mur", {"mur_porte_service_verte_brique", "mur_porte_service_verte_clin", "mur_porte_service_verte_crepi", "mur_porte_service_verte_enduit", "mur_porte_service_verte_pierre"}},
		x_mur_porte_service_vitree = {"Mur", {"mur_porte_service_vitree_brique", "mur_porte_service_vitree_clin", "mur_porte_service_vitree_crepi", "mur_porte_service_vitree_enduit", "mur_porte_service_vitree_pierre"}},
		x_mur_porte_simple_blanche = {"Mur", {"mur_porte_simple_blanche_brique", "mur_porte_simple_blanche_clin", "mur_porte_simple_blanche_crepi", "mur_porte_simple_blanche_enduit", "mur_porte_simple_blanche_pierre"}},
		x_mur_porte_simple_bois = {"Mur", {"mur_porte_simple_bois_brique", "mur_porte_simple_bois_clin", "mur_porte_simple_bois_crepi", "mur_porte_simple_bois_enduit", "mur_porte_simple_bois_pierre"}},
		x_mur_porte_simple_deco = {"Mur", {"mur_porte_simple_deco_brique", "mur_porte_simple_deco_clin", "mur_porte_simple_deco_crepi", "mur_porte_simple_deco_enduit", "mur_porte_simple_deco_pierre"}},
		x_mur_porte_simple_pleine = {"Mur", {"mur_porte_simple_pleine_brique", "mur_porte_simple_pleine_clin", "mur_porte_simple_pleine_crepi", "mur_porte_simple_pleine_enduit", "mur_porte_simple_pleine_pierre"}},
		x_mur_porte_simple_verre_sombre = {"Mur", {"mur_porte_simple_verre_sombre_brique", "mur_porte_simple_verre_sombre_clin", "mur_porte_simple_verre_sombre_crepi", "mur_porte_simple_verre_sombre_enduit", "mur_porte_simple_verre_sombre_pierre"}},
		x_mur_porte_verre_sombre = {"Mur", {"mur_porte_verre_sombre_brique", "mur_porte_verre_sombre_clin", "mur_porte_verre_sombre_crepi", "mur_porte_verre_sombre_enduit", "mur_porte_verre_sombre_pierre"}},
		toits = {"Plafond", {"toit_plat", "toit_membrane", "toit_clair", "toit_bac", "toit"}},
		toit_simple = {"Plafond", {"toit", "toit_bac", "toit_clair", "toit_plat", "toit_membrane"}},
		toit_angle = {"Plafond", {"toit_angle", "toit_bac_angle", "toit_clair_angle", "toit_bac_angle2"}},
		toit_bord = {"Plafond", {"toit_bord", "toit_bac_bord_x", "toit_clair_bord", "toit_bac_bord_y"}},
		stations_energie = {"Furniture", {"E2_Barils", "E3_Pompes", "E4_Bornes"}},
		stations_lavage = {"Furniture", {"L2_Seaux", "L3_Karcher", "L4_Rouleaux"}},
		stations_pieces = {"Furniture", {"E7_Teinte", "E6_Peinture", "E5_Pneus"}},
		caisses = {"Furniture", {"2", "1"}},
		etagere = {"Furniture", {"4", "rayonnage_vide"}},
		carton = {"Furniture", {"3", "carton_petit", "carton_moyen", "carton_grand"}},
		stockage2 = {"Furniture", {"4", "3", "carton_petit", "carton_moyen", "carton_grand"}},
		presentoirs = {"Furniture", {"rayonnage_vide"}},           -- gondole : pas encore de modele ("bientot")
		pubs = {"Furniture", {"PUB_1_PANCARTE", "PUB_2_CHEVALET", "PUB_3_MONUMENT", "PUB_4_PORTIQUE", "PUB_5_ENSEIGNE", "PUB_6_BIPODE", "PUB_7_TREILLIS", "PUB_8_MAT", "PUB_9_TOTEM"}},   -- v55 : 9 panneaux (annexe, face au tunnel)
		x_barrieres = {"Furniture", {"barriere_arceau", "barriere_grille", "barriere_potelets", "barriere_rails", "barriere_verre"}},
		x_plantes = {"Furniture", {"buisson_boule", "colonne_taillee", "haie_bloc", "jardiniere_fleurs", "jardiniere_longue", "pot_buisson", "pot_cactus", "topiaire_boule", "topiaire_cone"}},
	}
	-- cartes supplementaires (pas de sprite : apercu 3D) : id -> {onglet, titre}
	local CARTES_EXTRA = {
		-- v49 : carte "Goudron" de retour en tete de l'onglet Sols (demande de Thomas : il ne trouvait plus le goudron,
		-- 3e variante de la carte Exterieur) : goudron, route (ligne blanche), beton
		{"x_goudron", "sol", "Goudron", true},
		{"x_barrieres", "deco", "Barrières"},
		{"x_plantes", "deco", "Plantes & décor"},
		{"x_murs_vitrine", "murs", "Vitrine"},
		{"x_murs_muret", "murs", "Muret"},
		{"x_mur_fenetre_haute", "murs", "Fenêtre haute"},
		{"x_mur_fenetre_grille", "murs", "Fenêtre grillagée"},
		{"x_mur_fenetre_arche_croix", "murs", "Fenêtre arche à croisillons"},
		{"x_mur_fenetre_arche_pleine", "murs", "Fenêtre arche pleine"},
		{"x_mur_fenetre_arche_vitrine", "murs", "Fenêtre arche vitrine"},
		{"x_mur_baie_arche_nue", "murs", "Baie en arche nue"},
		{"x_mur_baie_barreaudee", "murs", "Baie barreaudée"},
		{"x_mur_baie_croisee", "murs", "Baie croisée"},
		{"x_mur_baie_grille", "murs", "Baie grillagée"},
		{"x_mur_baie_simple", "murs", "Baie simple"},
		{"x_mur_deux_baies", "murs", "Deux baies"},
		{"x_mur_porte", "murs", "Ouverture"},
		{"x_mur_porte_blanche", "murs", "Porte blanche"},
		{"x_mur_porte_deco", "murs", "Porte décorée"},
		{"x_mur_porte_double_bois", "murs", "Double porte bois"},
		{"x_mur_porte_double_verte", "murs", "Double porte verte"},
		{"x_mur_porte_imposte", "murs", "Porte à imposte"},
		{"x_mur_porte_pleine", "murs", "Porte pleine"},
		{"x_mur_porte_service_bois", "murs", "Porte de service bois"},
		{"x_mur_porte_service_verte", "murs", "Porte de service verte"},
		{"x_mur_porte_service_vitree", "murs", "Porte de service vitrée"},
		{"x_mur_porte_simple_blanche", "murs", "Porte simple blanche"},
		{"x_mur_porte_simple_bois", "murs", "Porte simple bois"},
		{"x_mur_porte_simple_deco", "murs", "Porte simple décorée"},
		{"x_mur_porte_simple_pleine", "murs", "Porte simple pleine"},
		{"x_mur_porte_simple_verre_sombre", "murs", "Porte simple verre sombre"},
		{"x_mur_porte_verre_sombre", "murs", "Porte verre sombre"},
	}
	-- cartes sans sprite ajoutees aux donnees de l'interface (apercu 3D de chaque variante)
	for _, c in ipairs(CARTES_EXTRA) do
		local id, onglet, titre = c[1], c[2], c[3]
		DATA[onglet] = DATA[onglet] or {}
		local deja = false
		for _, it in ipairs(DATA[onglet]) do if it.id == id then deja = true end end
		if not deja then
			local item = {id = id, name = titre, labels = {}, frames = 0, fw = 180, fh = 180, assetId = 0, titre3D = titre}
			if c[4] then table.insert(DATA[onglet], 1, item) else table.insert(DATA[onglet], item) end
		end
	end
	-- v55 : verrou de rang (champ Rang du catalogue) et objets uniques (champ Unique) : "des <rang>" / "deja pose"
	local RankCat = nil
	pcall(function() RankCat = require(RS:WaitForChild("Catalogue"):WaitForChild("Rank", 5)) end)
	local function verrou(infos, nom)
		if not infos then return nil end
		if infos.Rang and RankCat and RankCat.Numero then
			local requis = RankCat.Numero(infos.Rang)
			if (joueur:GetAttribute("RankIndex") or 1) < requis then return "dès le rang " .. tostring(infos.Rang) end
		end
		if infos.Unique then
			local plots = workspace:FindFirstChild("Plots")
			local dossier = plots and plots:FindFirstChild(joueur.Name .. "'s plot")
			if dossier and dossier:FindFirstChild(nom) then return "déjà posé" end
		end
		return nil
	end
	-- variantes d'une carte : seules celles dont le modele existe sont proposees (les autres sont annoncees "bientot")
	local function variantes(id)
		local c = CARTES[id]
		if not c then return nil, {} end
		return c[1], c[2]
	end
	local function objetDe(id, idx)
		local cat_, liste = variantes(id)
		local nom = liste[idx + 1]
		if not (cat_ and nom) then return nil end
		local dossier = RS:FindFirstChild(cat_)
		if not (dossier and dossier:FindFirstChild(nom)) then return nil end
		return cat_, nom
	end
	-- apercu 3D d'un modele du catalogue dans une carte (a la place du sprite quand il n'y en a pas)
	local function apercu3D(card, cat_, nom)
		local vp = card:FindFirstChild("Apercu")
		if not vp then
			vp = Instance.new("ViewportFrame"); vp.Name = "Apercu"; vp.Size = card.Img.Size; vp.Position = card.Img.Position; vp.AnchorPoint = card.Img.AnchorPoint
			vp.ZIndex = card.Img.ZIndex; vp.BackgroundTransparency = 1; vp.Ambient = Color3.fromRGB(170, 170, 170); vp.LightColor = Color3.fromRGB(255, 250, 240); vp.LightDirection = Vector3.new(-1, -2, -1)
			vp.Parent = card
		end
		for _, ch in ipairs(vp:GetChildren()) do ch:Destroy() end
		local dossier = cat_ and RS:FindFirstChild(cat_)
		local modele = dossier and nom and dossier:FindFirstChild(nom)
		if not modele then vp.Visible = false; return end
		local world = Instance.new("WorldModel"); world.Parent = vp
		local m = modele:Clone()
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") or d:IsA("Sound") then d:Destroy() end end
		m.Parent = world
		local cf, taille = m:GetBoundingBox()
		local piv = m:GetPivot()
		local diag = taille.Magnitude
		local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp; vp.CurrentCamera = cam
		local dist = (diag / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
		-- murs : on regarde la face avant (axe X du pivot) ; sinon vue de trois quarts
		local dir = (cat_ == "Mur") and (piv.XVector * 1 + piv.YVector * 0.35 + piv.ZVector * 0.45) or (piv.XVector * 0.8 + piv.YVector * 0.7 + piv.ZVector * 1)
		cam.CFrame = CFrame.lookAt(cf.Position + dir.Unit * dist, cf.Position)
		vp.Visible = true
	end
	local categorieActuelle = "stations"     -- v24 : la maquette ouvre Construction sur les stations
	local PAS_CARTE = 228              -- UI v21 : cartes de 220 px espacees de 228
	local function fill(cat)
		categorieActuelle = cat
		for _, c in ipairs(bd.Art.Center:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for _, k in ipairs(ONGLETS) do local v = bd.Art.Variants:FindFirstChild("V_" .. k) if v then v.Visible = (k == cat) end end
		for i, it in ipairs(DATA[cat] or {}) do
			local card = tpl:Clone(); card.Visible = true; card.Name = it.id; card.Position = UDim2.fromOffset(4 + (i - 1) * PAS_CARTE, 4)
			local nameL = card:FindFirstChild("NameL"); if nameL then nameL.Text = it.name or it.titre3D or "" end
			-- petites vignettes (sols, toits) : image centree en 137 px au lieu de 202
			local sz = it.small and 137 or 202
			card.Img.Size = UDim2.fromOffset(sz, sz); card.Img.Position = UDim2.fromOffset(105 - sz / 2, 103 - sz / 2)
			local idx = 0
			local _, liste = variantes(it.id)
			local total = math.max(#liste, it.frames or 0, 1)
			local function paint()
				local cat_, nom = objetDe(it.id, idx)
				local infos = cat_ and Catalogue.GetInfo(cat_, nom)
				local prix = infos and infos.Prix
				local sprite = (it.frames or 0) > idx and (it.assetId or 0) ~= 0
				if sprite then
					card.Img.Visible = true
					-- planche double (UI v21, ex. panneaux publicitaires) : a partir de la vue "split", on lit assetId2
					local sheet, j = it.assetId, idx
					if it.split and idx >= it.split and (it.assetId2 or 0) ~= 0 then sheet, j = it.assetId2, idx - it.split end
					card.Img.Image = "rbxassetid://" .. tostring(sheet)
					card.Img.ImageRectSize = Vector2.new(it.fw, it.fh); card.Img.ImageRectOffset = Vector2.new(j * it.fw, 0)
					local vp = card:FindFirstChild("Apercu"); if vp then vp.Visible = false end
				else
					card.Img.Visible = false
					apercu3D(card, cat_, nom or liste[idx + 1])
				end
				card.Counter.Text = (idx + 1) .. " / " .. total; card.Counter.Visible = total > 1; card.Prev.Visible = total > 1; card.Next.Visible = total > 1
				local libelle = it.labels[idx + 1]
				if not libelle then
					if infos then
						libelle = (infos.Nom or nom or "") .. (infos.Matiere and (" · " .. infos.Matiere) or "")
					else
						libelle = liste[idx + 1] or ""
					end
				end
				local ferme = verrou(infos, nom)
				card.Tex.Text = libelle .. (ferme and ("  ·  🔒 " .. ferme) or (prix and ("  ·  " .. prix .. " $") or (cat_ and "" or "  ·  bientôt")))
				for _, d in ipairs(card.Dots:GetChildren()) do if d:IsA("Frame") then d:Destroy() end end
				if total > 1 then
					local taille = (total > 8) and 5 or 8
					for j = 1, total do local d = Instance.new("Frame"); d.Size = UDim2.fromOffset(taille, taille); d.BackgroundColor3 = (j == idx + 1) and Color3.fromHex("ffd257") or Color3.new(1, 1, 1); d.BackgroundTransparency = (j == idx + 1) and 0 or 0.45; d.BorderSizePixel = 0; d.LayoutOrder = j; d.ZIndex = 26; d.Parent = card.Dots; Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0) end
				end
			end
			pressFx(card.Prev); pressFx(card.Next); pressFx(card.Select)
			card.Prev.Activated:Connect(function() idx = (idx - 1 + total) % total; paint() end)
			card.Next.Activated:Connect(function() idx = (idx + 1) % total; paint() end)
			card.Select.Activated:Connect(function()
				local cat_, nom = objetDe(it.id, idx)
				if not cat_ then message("Cet objet n'est pas encore disponible dans le jeu", true) return end
				local ferme = verrou(Catalogue.GetInfo(cat_, nom), nom)
				if ferme then message("Indisponible : " .. ferme, true) return end
				for _, c2 in ipairs(bd.Art.Center:GetChildren()) do if c2:IsA("Frame") and c2:FindFirstChild("FrameSel") then c2.FrameSel.Visible = (c2 == card); c2.Frame.Visible = (c2 ~= card) end end
				if ClientBuild then
					ClientBuild.DestroyLaser()
					ActionManager.ChangerMode("Construction", it.id .. ":" .. idx)
					ClientBuild.CreatePhantom(nom, cat_)
					if cat_ == "Mur" then
						message("Le mur se colle au bord de case le plus proche de la souris  ·  clic au sol ou Place pour poser  ·  R ou Rotate pour retourner la face avant", false, 5)
					else
						message("Déplace la souris et clique au sol (ou bouton Place) pour poser  ·  R ou Rotate pour tourner", false, 4)
					end
				end
			end)
			paint(); card.Parent = bd.Art.Center
		end
		bd.Art.Center.CanvasSize = UDim2.fromOffset(8 + #(DATA[cat] or {}) * PAS_CARTE, 0); bd.Art.Center.CanvasPosition = Vector2.new(0, 0)
	end
	for n, cat in pairs(CATS) do local b = bd.Left:FindFirstChild(n); if b then pressFx(b); b.Activated:Connect(function()
		if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser() end
		for _, k in ipairs({"move", "del"}) do local a = bd.Top:FindFirstChild("Active_" .. k) if a then a.Visible = false end end   -- v56 : le laser est detruit, la vignette aussi
		fill(cat)
	end) end end
	for _, n in ipairs({"Rotate", "Place", "Delete", "Cancel", "Close"}) do pressFx(bd.Top[n]) end
	bd.Top.Rotate.Activated:Connect(function()
		if not ClientBuild then return end
		if not ClientBuild.EnPlacement() then message("Sélectionne d'abord un objet (bouton ✓ d'une carte)", true) return end
		local o, txt = ClientBuild.Tourner(); message(txt or ("Rotation : " .. (o * 90) .. "°"), false, 1.5)
	end)
	bd.Top.Place.Activated:Connect(function()
		if not ClientBuild then return end
		if not ClientBuild.EnPlacement() then message("Sélectionne d'abord un objet (bouton ✓ d'une carte)", true) return end
		local ok, raison = ClientBuild.Poser()
		if ok then play("buy") else message((ClientBuild.EnDeplacement and ClientBuild.EnDeplacement()) and ("Déplacement refusé : " .. tostring(raison)) or ("Placement refusé : " .. tostring(raison)), true) end
	end)
	-- vignettes "mode actif" (v23) : Active_move / Active_del au-dessus des boutons Deplacer / Supprimer
	local fermerDiagnostic = nil          -- v55 : eteint le mode Circulation / Decoration a la fermeture de l'onglet
	local function modeVignette(m)
		for _, k in ipairs({"move", "del", "path", "deco"}) do
			local a = bd.Top:FindFirstChild("Active_" .. k)
			if a then a.Visible = (m == k) end
		end
		pcall(function() bd:SetAttribute("Mode", m or "") end)
	end
	modeVignette(nil)
	local move = bd.Top:FindFirstChild("Move")
	if move then
		pressFx(move)
		move.Activated:Connect(function()
			if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser(); if ClientBuild.ActiverDeplacement then ClientBuild.ActiverDeplacement() end end
			ActionManager.ChangerMode("Aucun"); modeVignette("move")
			message("Mode déplacement : clique un objet posé, puis sa nouvelle place (gratuit)", false, 4)
		end)
	end
	bd.Top.Delete.Activated:Connect(function() if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.CreateLaser(); modeVignette("del"); message("Mode suppression : clique un objet pour le retirer (remboursé)", true, 3) end end)
	-- v55 : modes CIRCULATION (bouton Trajectoire, violet) et DECORATION (bouton Déco, vert) de la barre v24 : plaques
	-- mates au sol via ClientDiagnostic, mises a jour en direct pendant la construction. Vignettes Active_path / Active_deco.
	do
		local okD, ClientDiagnostic = pcall(function() return require(PlayerScripts:WaitForChild("ClientDiagnostic", 10)) end)
		local bCirc, bDeco = bd.Top:FindFirstChild("Path"), bd.Top:FindFirstChild("Deco")
		if okD and ClientDiagnostic and bCirc and bDeco then
			local VIGNETTE = { circulation = "path", decoration = "deco" }
			local function rafraichirBoutons()
				local m = ClientDiagnostic.Mode()
				modeVignette(m and VIGNETTE[m] or nil)
			end
			pressFx(bCirc); pressFx(bDeco)
			local function basculer(mode, texte)
				if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser() end
				ActionManager.ChangerMode("Aucun")
				local m = ClientDiagnostic.Basculer(mode); rafraichirBoutons()
				if m then message(texte, false, 5) else toast.Visible = false end
			end
			bCirc.Activated:Connect(function() basculer("circulation", "Circulation : vert = trajet des voitures, bleu = chemin des clients vers la caisse, rouge barré = passage coupé") end)
			bDeco.Activated:Connect(function() basculer("decoration", "Décoration : rouge = malus des stations et du stockage, vert = bonus de la décoration") end)
			fermerDiagnostic = function() ClientDiagnostic.Desactiver(); modeVignette(nil) end
			-- Deplacer / Supprimer eteignent le diagnostic
			local move = bd.Top:FindFirstChild("Move")
			if move then move.Activated:Connect(function() ClientDiagnostic.Desactiver() end) end
			bd.Top.Delete.Activated:Connect(function() ClientDiagnostic.Desactiver() end)
		elseif bCirc and bDeco then
			bCirc.Activated:Connect(function() message("Mode circulation indisponible", true) end)
			bDeco.Activated:Connect(function() message("Mode décoration indisponible", true) end)
		end
	end
	bd.Top.Cancel.Activated:Connect(function()
		if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser() end
		ActionManager.ChangerMode("Aucun"); toast.Visible = false
		if fermerDiagnostic then fermerDiagnostic() else modeVignette(nil) end      -- v56 : Annuler eteint aussi le mode Circulation / Decoration
	end)
	-- v56 : un objet UNIQUE vient d'etre pose (panneau pub) : on repeint les cartes ("deja pose")
	task.spawn(function()
		local t0 = os.clock()
		while not ClientBuild and os.clock() - t0 < 120 do task.wait(0.5) end
		if ClientBuild and ClientBuild.Pose then
			ClientBuild.Pose.Event:Connect(function(_, _, infos) if infos and infos.Unique and menus.Build.Visible then fill(categorieActuelle) end end)
		end
	end)
	bd.Top.Close.Activated:Connect(function() showTab(nil) end)
	local astuceDonnee = false
	ouvrir.Build = function()
		if ClientBuild then ClientCamera.Activer(); ClientBuild.CreateExtension(); if ClientBuild.ActiverDeplacement then ClientBuild.ActiverDeplacement() end end
		fill(categorieActuelle)
		if not astuceDonnee then
			astuceDonnee = true
			message("Astuce : maintiens le clic et glisse pour poser en série  ·  clique un objet déjà posé pour le déplacer (gratuit)", false, 6)
		end
	end
	prechauffer.Build = function()
		local avant = categorieActuelle
		for _, c in ipairs(ONGLETS) do fill(c); task.wait(0.5) end
		fill(avant)               -- on revient a la categorie de depart (stations), pas a la derniere pre-rendue
	end
	fermer.Build = function()
		modeVignette(nil)
		if fermerDiagnostic then fermerDiagnostic() end
		ActionManager.ChangerMode("Aucun")
		if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser(); ClientBuild.DestroyExtension(); if ClientBuild.DesactiverDeplacement then ClientBuild.DesactiverDeplacement() end end
		ClientCamera.Desactiver()
	end
end)

-- ===== pre-rendu : chaque panneau est affiche une fois, en entier, derriere l'ecran de chargement =====
-- PreloadAsync ne fait que telecharger les images : Roblox ne les decode et ne les envoie a la carte graphique que la
-- premiere fois qu'elles sont dessinees a leur vraie taille, d'ou des panneaux flous et saccades a la premiere
-- ouverture. Ici on dessine tout (barre, 5 panneaux, les 4 categories de construction, le panneau des rangs) pendant
-- quelques images alors que l'ecran de chargement (au-dessus, opaque) cache encore tout.
local function prerendu()
	loading.Root.Status.Text = "Préparation de l'interface…"
	main.Enabled = true
	hud.Position = UDim2.fromOffset(0, 0)
	for _, n in ipairs(TABS) do
		local p = menus[n]
		p.Visible = true
		local art = p:FindFirstChild("Art")
		if art then art.Position = UDim2.fromOffset(0, 0) end
		fadeFrame(p, 0, 0)
		if prechauffer[n] then pcall(prechauffer[n]) elseif ouvrir[n] then pcall(ouvrir[n]) end
		task.wait(0.6)                 -- le temps que la pleine resolution arrive et soit dessinee
		if fermer[n] then pcall(fermer[n]) end
		p.Visible = false
	end
	menus.Ranks.Visible = true; task.wait(0.4); menus.Ranks.Visible = false
	-- les cartes creees pendant le pre-rendu (sprites du menu Construction) sont maintenant residentes elles aussi
	for _, o in ipairs(pg:GetDescendants()) do garderResident(o) end
	task.wait(0.8)
end
pcall(prerendu)
terminerChargement()
