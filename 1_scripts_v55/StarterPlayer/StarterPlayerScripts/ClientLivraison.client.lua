--[[ ClientLivraison (LocalScript, StarterPlayerScripts) — la CAMERA CINEMATIQUE du van de livraison.
	Une fois sur trois (decide par le serveur : LivraisonEvent "camion", cinema = true), quand le van part du tunnel avec
	la commande du joueur, la camera quitte le personnage et filme le van :
	  1. plan fixe au ras du sol, le van sort du tunnel et passe devant la camera (deux coups de klaxon : "poit poit") ;
	  2. travelling lateral, a cote du van ;
	  3. (v54) trois quarts AVANT en travelling : la camera roule devant et a cote du van, tournee vers lui : on voit la
	     calandre, les roues qui tournent et le derapage sur deux roues dans le rond-point ; plus de plan "dans le dos" ;
	  4. (v54) dechargement : plan lateral bas, legerement de trois quarts arriere, sur les portes qui s'ouvrent et les
	     cartons qui tombent (plus le plan plein arriere) ;
	puis la camera revient sur le personnage (ou avant, avec le bouton "Passer"). Bandes noires de cinema pendant le plan.
	Le van roule cote client (MoveCarEvent, tween) : la camera lit sa position a chaque image, elle est donc fluide.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Event = ReplicatedStorage:WaitForChild("LivraisonEvent", 30)
if not Event then return end

local POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local DUREE_PLAN_1 = 3.6
local DUREE_PLAN_2 = 3.0
local DUREE_MAX = 75                -- secondes : au-dela, on rend la camera quoi qu'il arrive

local function sons()
	local ok, S = pcall(function()
		return require(joueur:WaitForChild("PlayerGui"):WaitForChild("UIController", 10):WaitForChild("Sounds", 10))
	end)
	return ok and S or {}
end

local function klaxon()
	local S = sons()
	local d = S.klaxon
	if not (d and d.id and d.id ~= "") then return end
	local snd = Instance.new("Sound"); snd.SoundId = d.id; snd.Volume = d.volume or 0.9; snd.Parent = SoundService
	snd:Play()
	task.delay(4, function() snd:Destroy() end)
end

local enCours = false

local function bandes()
	local gui = Instance.new("ScreenGui"); gui.Name = "CinemaLivraison"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 120; gui.ResetOnSpawn = false
	for _, h in ipairs({0, 1}) do
		local b = Instance.new("Frame"); b.Name = h == 0 and "Haut" or "Bas"; b.BackgroundColor3 = Color3.new(0, 0, 0); b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, h); b.Position = UDim2.fromScale(0, h); b.Size = UDim2.new(1, 0, 0, 0); b.Parent = gui
		TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0.11, 0)}):Play()
	end
	local titre = Instance.new("TextLabel"); titre.Name = "Titre"; titre.BackgroundTransparency = 1; titre.AnchorPoint = Vector2.new(0.5, 1)
	titre.Position = UDim2.new(0.5, 0, 0.89, -8); titre.Size = UDim2.new(0.8, 0, 0, 30); titre.TextColor3 = Color3.new(1, 1, 1); titre.TextStrokeTransparency = 0.5
	titre.FontFace = POLICE; titre.TextSize = 22; titre.Text = "Ta livraison est en route…"; titre.TextTransparency = 1; titre.Parent = gui
	TweenService:Create(titre, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
	local passer = Instance.new("TextButton"); passer.Name = "Passer"; passer.AnchorPoint = Vector2.new(1, 0); passer.Position = UDim2.new(1, -18, 0.11, 10)
	passer.Size = UDim2.fromOffset(120, 34); passer.BackgroundColor3 = Color3.new(0, 0, 0); passer.BackgroundTransparency = 0.45; passer.BorderSizePixel = 0
	passer.Text = "Passer  ▸"; passer.TextColor3 = Color3.new(1, 1, 1); passer.FontFace = POLICE; passer.TextSize = 18; passer.AutoButtonColor = true; passer.Parent = gui
	local coin = Instance.new("UICorner"); coin.CornerRadius = UDim.new(0, 10); coin.Parent = passer
	gui.Parent = joueur:WaitForChild("PlayerGui")
	return gui
end

local function cinematique(van, nomGarage)
	if enCours then return end
	local root = van:FindFirstChild("Root") or van.PrimaryPart
	local t0 = os.clock()
	while not root and os.clock() - t0 < 3 do task.wait(0.1); root = van:FindFirstChild("Root") or van.PrimaryPart end
	if not root then return end
	enCours = true
	local gui = bandes()
	gui.Titre.Text = "Ta livraison est en route vers le garage " .. tostring(nomGarage or "") .. "…"
	local typeAvant = camera.CameraType
	local sujetAvant = camera.CameraSubject
	camera.CameraType = Enum.CameraType.Scriptable
	local fini = false
	gui.Passer.Activated:Connect(function() fini = true end)
	local touche = UserInputService.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Enum.KeyCode.Escape then fini = true end end)

	local depart = os.clock()
	local cfLisse = nil
	local function lisser(cible, dt, k)
		if not cfLisse then cfLisse = cible return cible end
		cfLisse = cfLisse:Lerp(cible, math.min(1, dt * (k or 4)))
		return cfLisse
	end
	-- plan 1 : camera posee au bord de la route, devant le van (il vient vers elle et la depasse)
	local cf0 = root.CFrame
	local posePlan1 = (cf0 * CFrame.new(-11, 3.2, -30)).Position
	task.delay(0.7, klaxon)
	local etapeCartons = nil
	local conn = RunService.RenderStepped:Connect(function(dt)
		if fini or not van.Parent or not root.Parent then fini = true return end
		local t = os.clock() - depart
		local cf = root.CFrame
		local etape = van:GetAttribute("Etape")
		local haut = Vector3.new(0, 3.5, 0)
		if etape == "dechargement" or etape == "garage" then
			-- plan 4 (v54) : lateral bas, trois quarts arriere : les portes et les cartons, sans etre dans le dos du van
			if not etapeCartons then etapeCartons = os.clock(); cfLisse = nil end
			local pose = (cf * CFrame.new(17, 3.6, 11)).Position
			local cible = CFrame.lookAt(pose, cf.Position + cf.LookVector * -11 + Vector3.new(0, 2.5, 0))
			camera.CFrame = lisser(cible, dt, 3)
			if etape == "garage" and os.clock() - etapeCartons > 3 then fini = true end
			if os.clock() - etapeCartons > 22 then fini = true end
		elseif t < DUREE_PLAN_1 then
			camera.CFrame = CFrame.lookAt(posePlan1, cf.Position + haut)
		elseif t < DUREE_PLAN_1 + DUREE_PLAN_2 then
			local pose = (cf * CFrame.new(15, 5, -3)).Position
			camera.CFrame = lisser(CFrame.lookAt(pose, cf.Position + haut), dt, 6)
		else
			-- plan 3 (v54) : trois quarts avant en travelling, la camera devant et sur le cote, tournee vers le van
			-- (du meme cote que le travelling du plan 2 : pas de balayage devant le van). Le lissage absorbe les virages.
			local pose = (cf * CFrame.new(17, 5.5, -24)).Position
			camera.CFrame = lisser(CFrame.lookAt(pose, cf.Position + Vector3.new(0, 2.8, 0)), dt, 3)
		end
		if t > DUREE_MAX then fini = true end
	end)
	while not fini do task.wait(0.1) end
	conn:Disconnect(); touche:Disconnect()
	for _, b in ipairs({gui.Haut, gui.Bas}) do TweenService:Create(b, TweenInfo.new(0.35), {Size = UDim2.new(1, 0, 0, 0)}):Play() end
	TweenService:Create(gui.Titre, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
	gui.Passer.Visible = false
	task.delay(0.4, function() gui:Destroy() end)
	camera.CameraType = typeAvant ~= Enum.CameraType.Scriptable and typeAvant or Enum.CameraType.Custom
	local perso = joueur.Character
	if perso then camera.CameraSubject = perso:FindFirstChildOfClass("Humanoid") or sujetAvant end
	enCours = false
end

Event.OnClientEvent:Connect(function(quoi, dossier, cinema, nomGarage, nomVan)
	if quoi ~= "camion" then return end
	print(("[Livraison] van %s en route vers %s (cinema : %s)"):format(tostring(nomVan), tostring(nomGarage), tostring(cinema)))
	if cinema ~= true or typeof(dossier) ~= "Instance" then return end
	task.spawn(function()
		local van = dossier:WaitForChild(nomVan or "Van", 8)
		if van then cinematique(van, nomGarage) else warn("[Livraison] van introuvable pour la cinematique") end
	end)
end)
