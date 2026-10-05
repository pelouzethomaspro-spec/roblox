--[[ ClientDiagnostic (ModuleScript, StarterPlayerScripts) — v55 : modes CIRCULATION et DECORATION de l'onglet Construction.
	Affiche au sol, en plaques MATES et PALES (pas de neon, lisibles), le resultat de Diagnostic (serveur) :
	  circulation : vert = couloir des voitures (entree -> stations -> sortie), bleu = chemin a pied des clients vers la
	                caisse, rouge barre = rupture (station non desservie, pas de chemin de sortie, pas de caisse joignable)
	  decoration  : rouge (3 intensites) = malus des stations / stockage, vert = bonus des elements de decoration
	Se met a jour en direct : ClientBuild appelle Rafraichir() apres chaque pose / suppression / deplacement.
	API : ClientDiagnostic.Activer(mode) | Desactiver() | Basculer(mode) | Rafraichir() | Mode()
	      ClientDiagnostic.Plaque(dossier, cf, couleur, barree) : fabrique de plaque partagee (le tutoriel l'utilise aussi).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local ClientDiagnostic = {}

local CASE, DEMI = 15, 7.5
local HAUTEUR = 0.9                       -- dessus des dalles 0,57 + marge ; les plaques flottent a 2 cm au-dessus des sols
local COULEURS = {
	vert = Color3.fromRGB(150, 205, 140),
	bleu = Color3.fromRGB(140, 175, 225),
	rouge = Color3.fromRGB(220, 110, 100),
	rougeFort = Color3.fromRGB(225, 95, 85), rougeMoyen = Color3.fromRGB(230, 150, 135), rougeFaible = Color3.fromRGB(235, 195, 180),
	vertFort = Color3.fromRGB(120, 195, 120), vertMoyen = Color3.fromRGB(165, 215, 160),
}
local TRANSPARENCE = 0.45

local joueur = Players.LocalPlayer
-- v56 : on n'attend plus la RemoteFunction au chargement (60 s d'ecran de chargement si le serveur ne l'avait pas creee) :
-- elle est cherchee au premier rafraichissement, avec un court delai.
local Fonction = ReplicatedStorage:FindFirstChild("DiagnosticFunction")
local function fonction()
	if Fonction and Fonction.Parent then return Fonction end
	Fonction = ReplicatedStorage:WaitForChild("DiagnosticFunction", 5)
	return Fonction
end

local mode = nil
local dossier = nil
local enAttente = false
local plotcenter = nil

local function dossierPlaques()
	if dossier and dossier.Parent then return dossier end
	dossier = Instance.new("Folder"); dossier.Name = "DiagnosticPlaques"; dossier.Parent = workspace
	return dossier
end

local function trouverPlotCenter()
	if plotcenter and plotcenter.Parent then return plotcenter end
	local plots = workspace:FindFirstChild("Plots")
	local folder = plots and plots:FindFirstChild(joueur.Name .. "'s plot")
	local ref = folder and folder:FindFirstChild("PlotCenterRef")
	plotcenter = ref and ref.Value or nil
	return plotcenter
end

-- CFrame du centre d'une case (repere du plot -> monde)
local function cfCase(x, z)
	local pc = trouverPlotCenter()
	if not pc then return nil end
	return pc:GetPivot() * CFrame.new((x - 0.5) * CASE, HAUTEUR, (z - 0.5) * CASE - DEMI)
end

-- plaque mate pale ; barree = deux barres diagonales rouges (croix) par-dessus
function ClientDiagnostic.Plaque(parent, cf, couleur, barree, taille)
	taille = taille or (CASE - 1.2)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic; p.Color = couleur; p.Transparency = TRANSPARENCE
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(taille, 0.12, taille); p.CFrame = cf; p.Parent = parent
	-- contour fin, un peu plus sombre
	local contour = Instance.new("SelectionBox"); contour.Adornee = p; contour.LineThickness = 0.025
	contour.Color3 = couleur:Lerp(Color3.new(0, 0, 0), 0.35); contour.Transparency = 0.2; contour.Parent = p
	if barree then
		for _, a in ipairs({45, -45}) do
			local b = Instance.new("Part")
			b.Anchored = true; b.CanCollide = false; b.CanQuery = false; b.CanTouch = false; b.CastShadow = false
			b.Material = Enum.Material.SmoothPlastic; b.Color = Color3.fromRGB(190, 40, 40); b.Transparency = 0.1
			b.Size = Vector3.new(taille * 1.25, 0.14, 1.2); b.CFrame = cf * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, math.rad(a), 0)
			b.Parent = parent
		end
	end
	return p
end

local function vider()
	if dossier then dossier:Destroy(); dossier = nil end
end

local function afficherCirculation(res)
	local d = dossierPlaques()
	for _, c in ipairs(res.vert or {}) do local cf = cfCase(c[1], c[2]); if cf then ClientDiagnostic.Plaque(d, cf, COULEURS.vert, false) end end
	for _, c in ipairs(res.bleu or {}) do local cf = cfCase(c[1], c[2]); if cf then ClientDiagnostic.Plaque(d, cf * CFrame.new(0, 0.05, 0), COULEURS.bleu, false, CASE - 5) end end
	for _, c in ipairs(res.rouge or {}) do local cf = cfCase(c[1], c[2]); if cf then ClientDiagnostic.Plaque(d, cf * CFrame.new(0, 0.1, 0), COULEURS.rouge, true) end end
end

local function afficherDecoration(res)
	local d = dossierPlaques()
	for _, c in ipairs(res.cases or {}) do
		local v = c[3]
		local couleur
		if v <= -3 then couleur = COULEURS.rougeFort elseif v <= -2 then couleur = COULEURS.rougeMoyen elseif v < 0 then couleur = COULEURS.rougeFaible
		elseif v >= 2 then couleur = COULEURS.vertFort else couleur = COULEURS.vertMoyen end
		local cf = cfCase(c[1], c[2])
		if cf then ClientDiagnostic.Plaque(d, cf, couleur, false) end
	end
end

local function fondu(d)
	-- apparition douce des plaques (0,25 s)
	for _, p in ipairs(d:GetChildren()) do
		if p:IsA("BasePart") then
			local cible = p.Transparency
			p.Transparency = 1
			TweenService:Create(p, TweenInfo.new(0.25), { Transparency = cible }):Play()
		end
	end
end

local jeton = 0
function ClientDiagnostic.Rafraichir()
	if not mode then return end
	if enAttente then return end
	enAttente = true
	jeton += 1
	local monJeton = jeton
	task.spawn(function()
		task.wait(0.3)                       -- regroupe les poses en serie
		enAttente = false
		if mode == nil or monJeton ~= jeton then return end
		local f = fonction()
		if not f then mode = nil; return end
		local ok, res = pcall(function() return f:InvokeServer(mode) end)
		if not (ok and res) or mode == nil or monJeton ~= jeton then return end
		vider()
		if mode == "decoration" then afficherDecoration(res) else afficherCirculation(res) end
		if dossier then fondu(dossier) end
		ClientDiagnostic.DernieresInfos = res.infos
	end)
end

function ClientDiagnostic.Activer(m)
	if not fonction() then warn("[Diagnostic] DiagnosticFunction absente : mode indisponible"); mode = nil; return nil end   -- v56
	mode = m
	vider()
	ClientDiagnostic.Rafraichir()
	return m
end

function ClientDiagnostic.Desactiver()
	mode = nil
	vider()
end

function ClientDiagnostic.Basculer(m)
	if mode == m then ClientDiagnostic.Desactiver() return nil end
	ClientDiagnostic.Activer(m)
	return m
end

function ClientDiagnostic.Mode() return mode end

-- mise a jour quand les donnees du joueur changent (stations / caisses) : le serveur envoie UpdateClientData
task.spawn(function()
	local ev = ReplicatedStorage:WaitForChild("UpdateClientData", 30)
	if ev then ev.OnClientEvent:Connect(function(champ) if mode and (champ == "Stations" or champ == "Caisses") then ClientDiagnostic.Rafraichir() end end) end
end)

return ClientDiagnostic
