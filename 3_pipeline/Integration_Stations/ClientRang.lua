--[[ ClientRang (LocalScript, StarterPlayerScripts) — v55 :
	1. BADGE DE RANG au-dessus de la tete de chaque joueur : "Pseudo" + nom du rang en couleur (attribut Rank du joueur,
	   couleur dans Catalogue/Rank). Le nom Roblox par defaut est masque (le serveur met DisplayDistanceType = None).
	2. PANNEAU DES TAUX DE SPAWN au-dessus de la bouche du tunnel de son plot : quand on s'approche (< 80 studs), une bulle
	   (meme esprit que Supply / Worker) montre le rang et le % de chaque rarete a ce rang (Rank.Probas) ; les raretes a 0 %
	   sont grisees avec le rang qui les debloque.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local joueur = Players.LocalPlayer
local Rank = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Rank"))
local Car = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Car"))
local POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local POLICE_M = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)

local function rangDe(nom)
	for _, r in ipairs(Rank) do if r.Nom == nom then return r end end
	return Rank[1]
end

-- ----------------------------------------------------------------------------------------------------------------------
-- 1. badge au-dessus de la tete
-- ----------------------------------------------------------------------------------------------------------------------
local function badge(player, character)
	local tete = character:WaitForChild("Head", 10)
	if not tete then return end
	local ancien = tete:FindFirstChild("BadgeRang")
	if ancien then ancien:Destroy() end
	local bb = Instance.new("BillboardGui"); bb.Name = "BadgeRang"; bb.Size = UDim2.new(0, 260, 0, 44); bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = false; bb.MaxDistance = 120; bb.LightInfluence = 0; bb.ResetOnSpawn = false
	local nom = Instance.new("TextLabel"); nom.Name = "Nom"; nom.Size = UDim2.new(1, 0, 0, 24); nom.BackgroundTransparency = 1
	nom.FontFace = POLICE; nom.TextSize = 20; nom.TextColor3 = Color3.new(1, 1, 1); nom.TextStrokeTransparency = 0.35
	nom.Text = player.DisplayName; nom.Parent = bb
	local rang = Instance.new("TextLabel"); rang.Name = "Rang"; rang.Position = UDim2.new(0, 0, 0, 22); rang.Size = UDim2.new(1, 0, 0, 20)
	rang.BackgroundTransparency = 1; rang.FontFace = POLICE; rang.TextSize = 15; rang.TextStrokeTransparency = 0.3; rang.Parent = bb
	local function maj()
		local r = rangDe(player:GetAttribute("Rank"))
		rang.Text = string.upper(r.Nom); rang.TextColor3 = r.Couleur
	end
	maj()
	player:GetAttributeChangedSignal("Rank"):Connect(maj)
	bb.Parent = tete
end

local function suivre(player)
	if player.Character then task.spawn(badge, player, player.Character) end
	player.CharacterAdded:Connect(function(c) task.spawn(badge, player, c) end)
end
for _, p in ipairs(Players:GetPlayers()) do suivre(p) end
Players.PlayerAdded:Connect(suivre)

-- ----------------------------------------------------------------------------------------------------------------------
-- 2. panneau des taux au-dessus du tunnel du joueur
-- ----------------------------------------------------------------------------------------------------------------------
local DISTANCE = 80
local panneau = nil

local function tunnelDuJoueur()
	local plots = workspace:FindFirstChild("Plots")
	local folder = plots and plots:FindFirstChild(joueur.Name .. "'s plot")
	local ref = folder and folder:FindFirstChild("PlotCenterRef")
	local sf = ref and ref.Value and ref.Value.Parent
	return sf and sf:FindFirstChild("Tunnel")
end

local function creerPanneau(tunnel)
	local bb = Instance.new("BillboardGui"); bb.Name = "TauxSpawn"; bb.Size = UDim2.new(0, 300, 0, 250); bb.StudsOffset = Vector3.new(0, 22, 0)
	bb.AlwaysOnTop = true; bb.MaxDistance = DISTANCE + 20; bb.LightInfluence = 0; bb.Enabled = false
	local fond = Instance.new("Frame"); fond.Size = UDim2.fromScale(1, 1); fond.BackgroundColor3 = Color3.fromRGB(18, 20, 28); fond.BackgroundTransparency = 0.15
	fond.BorderSizePixel = 0; fond.Parent = bb
	Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 14)
	local contour = Instance.new("UIStroke", fond); contour.Thickness = 2; contour.Transparency = 0.2; contour.Name = "Contour"
	local titre = Instance.new("TextLabel"); titre.Name = "Titre"; titre.Size = UDim2.new(1, -16, 0, 26); titre.Position = UDim2.new(0, 8, 0, 8)
	titre.BackgroundTransparency = 1; titre.FontFace = POLICE; titre.TextSize = 18; titre.TextColor3 = Color3.new(1, 1, 1); titre.Text = "TAUX DE SPAWN"; titre.Parent = fond
	local rang = Instance.new("TextLabel"); rang.Name = "Rang"; rang.Size = UDim2.new(1, -16, 0, 22); rang.Position = UDim2.new(0, 8, 0, 32)
	rang.BackgroundTransparency = 1; rang.FontFace = POLICE_M; rang.TextSize = 15; rang.Parent = fond
	local liste = Instance.new("Frame"); liste.Name = "Liste"; liste.Position = UDim2.new(0, 10, 0, 60); liste.Size = UDim2.new(1, -20, 1, -68); liste.BackgroundTransparency = 1; liste.Parent = fond
	local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 3); layout.Parent = liste
	for i, tier in ipairs(Rank.Ordre) do
		local ligne = Instance.new("Frame"); ligne.Name = tier; ligne.Size = UDim2.new(1, 0, 0, 23); ligne.BackgroundTransparency = 1; ligne.LayoutOrder = i; ligne.Parent = liste
		local pastille = Instance.new("Frame"); pastille.Size = UDim2.new(0, 10, 0, 10); pastille.Position = UDim2.new(0, 2, 0.5, -5); pastille.BorderSizePixel = 0
		pastille.BackgroundColor3 = (Car[tier] and Car[tier].Couleur) or Color3.new(1, 1, 1); pastille.Parent = ligne
		Instance.new("UICorner", pastille).CornerRadius = UDim.new(1, 0)
		local nom = Instance.new("TextLabel"); nom.Name = "Nom"; nom.Position = UDim2.new(0, 20, 0, 0); nom.Size = UDim2.new(0.6, 0, 1, 0); nom.BackgroundTransparency = 1
		nom.FontFace = POLICE_M; nom.TextSize = 15; nom.TextXAlignment = Enum.TextXAlignment.Left; nom.TextColor3 = Color3.new(1, 1, 1)
		nom.Text = Rank.NomsRaretes[tier] or tier; nom.Parent = ligne
		local pct = Instance.new("TextLabel"); pct.Name = "Pct"; pct.AnchorPoint = Vector2.new(1, 0); pct.Position = UDim2.new(1, -4, 0, 0); pct.Size = UDim2.new(0.38, 0, 1, 0)
		pct.BackgroundTransparency = 1; pct.FontFace = POLICE; pct.TextSize = 15; pct.TextXAlignment = Enum.TextXAlignment.Right; pct.TextColor3 = Color3.new(1, 1, 1); pct.Parent = ligne
	end
	bb.Parent = tunnel
	return bb
end

local function majPanneau(bb)
	local r = rangDe(joueur:GetAttribute("Rank"))
	local fond = bb:FindFirstChildOfClass("Frame")
	fond.Contour.Color = r.Couleur
	fond.Rang.Text = "Ton rang : " .. string.upper(r.Nom) .. "  ·  les voitures qui arrivent chez toi"
	fond.Rang.TextColor3 = r.Couleur
	for i, tier in ipairs(Rank.Ordre) do
		local ligne = fond.Liste:FindFirstChild(tier)
		local p = (r.Probas and r.Probas[i]) or 0
		if ligne then
			if p > 0 then
				ligne.Pct.Text = (p >= 0.01) and string.format("%d %%", math.floor(p * 100 + 0.5)) or string.format("%.1f %%", p * 100)
				ligne.Pct.TextColor3 = Color3.new(1, 1, 1); ligne.Nom.TextTransparency = 0; ligne.Pct.TextTransparency = 0
			else
				-- rang qui debloque cette rarete
				local debloque = nil
				for _, rr in ipairs(Rank) do if (rr.Probas[i] or 0) > 0 then debloque = rr break end end
				ligne.Pct.Text = debloque and ("dès " .. debloque.Nom) or "—"
				ligne.Pct.TextColor3 = Color3.fromRGB(150, 150, 160); ligne.Nom.TextTransparency = 0.45; ligne.Pct.TextTransparency = 0.2
			end
		end
	end
end

RunService.Heartbeat:Connect(function()
	local tunnel = tunnelDuJoueur()
	if not tunnel then if panneau then panneau:Destroy(); panneau = nil end return end
	if not panneau or panneau.Parent ~= tunnel then
		if panneau then panneau:Destroy() end
		panneau = creerPanneau(tunnel)
		joueur:GetAttributeChangedSignal("Rank"):Connect(function() if panneau then majPanneau(panneau) end end)
	end
	local perso = joueur.Character
	local root = perso and perso:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local proche = (root.Position - tunnel.Position).Magnitude < DISTANCE
	if proche and not panneau.Enabled then majPanneau(panneau); panneau.Enabled = true
	elseif not proche and panneau.Enabled then panneau.Enabled = false end
end)
