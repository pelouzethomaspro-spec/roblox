--[[ Enchere (ModuleScript, ServerScriptService) — v55 : ACHAT AUX ENCHERES des voitures du centre (CarAmbiance).

	Deroulement
	  1. Un joueur proche de la voiture (ProximityPrompt E, 30 studs) "Acheter" : l'enchere demarre a son nom au prix de
	     base de la voiture (PRIX_BASE x Mult de la rarete), pour un TOUR de 10 s.
	  2. Pendant le tour, tout autre joueur proche peut "Surenchérir" (E) : le prix est multiplie par 1,5 et un nouveau
	     tour de 10 s repart. Il faut avoir l'argent du nouveau prix. Le meneur ne peut pas surencherir sur lui-meme.
	  3. Quand un tour se termine sans surenchere, le meneur gagne : l'argent est debite a ce moment-la (s'il ne l'a plus,
	     l'enchere revient au precedent participant encore solvable, sinon elle est annulee), la voiture lui est
	     attribuee (CarAmbiance : etat.achat -> elle bifurque vers son plot), ETOILES + "Achetée par <pseudo>" 3 s.
	  4. ROBUX : seconde invite (F) "Acheter en Robux" : produit developpeur de la rarete (Monetisation.PRODUITS.Voiture) ;
	     la voiture est attribuee des la reception du recu (Monetisation -> Enchere.AchatRobux), meme en pleine enchere.
	     Si la voiture a disparu entre-temps, le modele est mis dans la file de recuperation du joueur (prochaine cliente).

	Affichage ("clash") : BillboardGui au-dessus de la voiture, cree par le serveur (repliquee a tous) : nom + rarete, prix
	courant, meneur, barre du temps restant, ligne "A  vs  B" quand au moins deux joueurs participent.

	API (pour CarAmbiance) :
	  Enchere.Equiper(voiture, infos) : infos = { nom, tier, prix, peutAcheter(player) -> ok, raison, gagne(player, prix) }
	  Enchere.AchatRobux(player, voiture)   (appele par Monetisation au recu du produit)
	  Enchere.Arreter(voiture)              (voiture qui quitte le centre : plus d'enchere possible)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local Car = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Car"))

local Enchere = {}
Enchere.DUREE_TOUR = 10          -- secondes par tour
Enchere.MULT = 1.5               -- surenchere : prix x 1,5
Enchere.DISTANCE = 30            -- il faut etre a moins de 30 studs (ProximityPrompt)
Enchere.DUREE_ETOILES = 3        -- "Achetee par ..." + etoiles

local POLICE = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold)
local POLICE_M = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)

local Encheres = {}              -- [voiture] = etat
local AttenteRobux = {}          -- [userId] = { voiture = , t = }

-- ----------------------------------------------------------------------------------------------------------------------
-- affichage
-- ----------------------------------------------------------------------------------------------------------------------
local function label(parent, nom, pos, taille, tailleTexte, police, couleur)
	local l = Instance.new("TextLabel"); l.Name = nom; l.Position = pos; l.Size = taille; l.BackgroundTransparency = 1
	l.FontFace = police or POLICE; l.TextSize = tailleTexte; l.TextColor3 = couleur or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5; l.TextXAlignment = Enum.TextXAlignment.Center; l.Text = ""; l.Parent = parent
	return l
end

local function creerPanneau(voiture, E)
	local root = voiture.PrimaryPart
	local bb = Instance.new("BillboardGui"); bb.Name = "Enchere"; bb.Size = UDim2.new(0, 300, 0, 132); bb.StudsOffset = Vector3.new(0, 7.5, 0)
	bb.AlwaysOnTop = true; bb.MaxDistance = 90; bb.LightInfluence = 0; bb.Enabled = false
	local fond = Instance.new("Frame"); fond.Name = "Fond"; fond.Size = UDim2.fromScale(1, 1); fond.BackgroundColor3 = Color3.fromRGB(18, 20, 28); fond.BackgroundTransparency = 0.15; fond.BorderSizePixel = 0; fond.Parent = bb
	Instance.new("UICorner", fond).CornerRadius = UDim.new(0, 14)
	local contour = Instance.new("UIStroke", fond); contour.Name = "Contour"; contour.Thickness = 2; contour.Transparency = 0.15
	contour.Color = (Car[E.tier] and Car[E.tier].Couleur) or Color3.new(1, 1, 1)
	label(fond, "Titre", UDim2.new(0, 8, 0, 6), UDim2.new(1, -16, 0, 22), 17).Text = E.nom .. "  ·  " .. tostring(E.tier)
	local prix = label(fond, "Prix", UDim2.new(0, 8, 0, 30), UDim2.new(1, -16, 0, 30), 26, nil, Color3.fromRGB(255, 210, 87))
	local meneur = label(fond, "Meneur", UDim2.new(0, 8, 0, 62), UDim2.new(1, -16, 0, 20), 15, POLICE_M, Color3.fromRGB(220, 225, 235))
	local clash = label(fond, "Clash", UDim2.new(0, 8, 0, 84), UDim2.new(1, -16, 0, 20), 15, POLICE, Color3.fromRGB(255, 120, 110))
	local piste = Instance.new("Frame"); piste.Name = "Piste"; piste.Position = UDim2.new(0, 14, 1, -18); piste.Size = UDim2.new(1, -28, 0, 8)
	piste.BackgroundColor3 = Color3.fromRGB(60, 64, 76); piste.BorderSizePixel = 0; piste.Parent = fond
	Instance.new("UICorner", piste).CornerRadius = UDim.new(1, 0)
	local barre = Instance.new("Frame"); barre.Name = "Barre"; barre.Size = UDim2.fromScale(1, 1); barre.BackgroundColor3 = Color3.fromRGB(120, 205, 120); barre.BorderSizePixel = 0; barre.Parent = piste
	Instance.new("UICorner", barre).CornerRadius = UDim.new(1, 0)
	bb.Parent = root
	prix.Text = E.prix .. " $"; meneur.Text = "Maintiens E pour acheter"
	return bb
end

local function majPanneau(E)
	local bb = E.panneau
	if not (bb and bb.Parent) then return end
	local fond = bb.Fond
	fond.Prix.Text = E.prix .. " $"
	if E.meneur then
		fond.Meneur.Text = "Meneur : " .. E.meneur.DisplayName .. "   ·   E = surenchérir (" .. math.floor(E.prix * Enchere.MULT + 0.5) .. " $)"
	else
		fond.Meneur.Text = "Maintiens E pour acheter"
	end
	local noms = {}
	for _, p in ipairs(E.participants) do table.insert(noms, p.DisplayName) end
	fond.Clash.Text = (#noms >= 2) and table.concat(noms, "  vs  ") or ""
	fond.Clash.Visible = #noms >= 2
	if #noms >= 2 then
		fond.Contour.Color = Color3.fromRGB(255, 120, 110)
	end
end

local function etoiles(voiture, texte)
	local root = voiture.PrimaryPart
	if not root then return end
	local att = Instance.new("Attachment"); att.Position = Vector3.new(0, 3, 0); att.Parent = root
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 250, 200))
	pe.LightEmission = 1; pe.Lifetime = NumberRange.new(0.8, 1.6); pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180); pe.Rate = 0; pe.Rotation = NumberRange.new(0, 360); pe.RotSpeed = NumberRange.new(-90, 90)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Acceleration = Vector3.new(0, -12, 0); pe.Parent = att
	pe:Emit(60)
	task.delay(0.6, function() if pe.Parent then pe:Emit(30) end end)
	local bb = Instance.new("BillboardGui"); bb.Name = "Achetee"; bb.Size = UDim2.new(0, 320, 0, 60); bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.AlwaysOnTop = true; bb.MaxDistance = 120; bb.LightInfluence = 0
	local l = label(bb, "Texte", UDim2.new(0, 0, 0, 0), UDim2.fromScale(1, 1), 24, POLICE, Color3.fromRGB(255, 225, 110))
	l.Text = texte; l.TextStrokeTransparency = 0.2
	bb.Parent = root
	task.delay(Enchere.DUREE_ETOILES, function() bb:Destroy(); att:Destroy() end)
end

-- ----------------------------------------------------------------------------------------------------------------------
-- enchere
-- ----------------------------------------------------------------------------------------------------------------------
local function terminer(E, gagnant, prixPaye, robux)
	E.fini = true
	for _, p in ipairs({E.promptE, E.promptF}) do if p then p.Enabled = false end end
	if E.panneau then E.panneau:Destroy(); E.panneau = nil end
	if gagnant then
		etoiles(E.voiture, "★  Achetée par " .. gagnant.DisplayName .. (robux and "  (Robux)" or "") .. "  ★")
		E.infos.gagne(gagnant, prixPaye or 0)
	end
	Encheres[E.voiture] = nil
end

-- fin du tour : le meneur gagne s'il a toujours l'argent ; sinon on remonte les participants
local function finDuTour(E)
	if E.fini then return end
	if not (E.voiture and E.voiture.Parent) then E.fini = true; Encheres[E.voiture] = nil; return end   -- v56 : voiture deja detruite
	local ordre = E.historique                      -- { {joueur, prix}, ... } du plus recent au plus ancien
	for i = 1, #ordre do                            -- v56 : du MENEUR (plus recent) au plus ancien ; la boucle etait inversee
		local h = ordre[i]
		if h.joueur.Parent and PlayerData.GetMoney(h.joueur) >= h.prix then
			local ok, raison = E.infos.peutAcheter(h.joueur)
			if ok then
				PlayerData.SpendMoney(h.joueur, h.prix)
				terminer(E, h.joueur, h.prix, false)
				return
			else
				warn("[Enchere] " .. h.joueur.Name .. " : " .. tostring(raison))
			end
		end
	end
	-- personne de solvable : l'enchere est annulee, la voiture reste a vendre
	E.meneur = nil; E.participants = {}; E.historique = {}; E.prix = E.infos.prix; E.tour = nil
	if E.panneau then E.panneau.Enabled = false end
	E.promptE.ActionText = "Acheter"; E.promptE.ObjectText = E.texteBase
	majPanneau(E)
end

local function lancerTour(E)
	E.tour = (E.tour or 0) + 1
	local monTour = E.tour
	E.fin = os.clock() + Enchere.DUREE_TOUR
	if E.panneau then
		E.panneau.Enabled = true
		local barre = E.panneau.Fond.Piste.Barre
		barre.Size = UDim2.fromScale(1, 1)
		TweenService:Create(barre, TweenInfo.new(Enchere.DUREE_TOUR, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
	end
	task.delay(Enchere.DUREE_TOUR, function()
		if E.fini or E.tour ~= monTour then return end
		finDuTour(E)
	end)
end

local function encherir(E, player)
	if E.fini then return end
	local ok, raison = E.infos.peutAcheter(player)
	if not ok then return E.refus(raison) end
	if E.meneur == player then return E.refus("Tu mènes déjà l'enchère") end
	local nouveauPrix = E.meneur and math.floor(E.prix * Enchere.MULT + 0.5) or E.prix
	if PlayerData.GetMoney(player) < nouveauPrix then return E.refus(("Argent insuffisant (%d $)"):format(nouveauPrix)) end
	E.prix = nouveauPrix
	E.meneur = player
	table.insert(E.historique, 1, { joueur = player, prix = nouveauPrix })
	local deja = false
	for _, p in ipairs(E.participants) do if p == player then deja = true end end
	if not deja then table.insert(E.participants, player) end
	E.promptE.ActionText = "Surenchérir"
	E.promptE.ObjectText = ("%s — %d $ (meneur : %s)"):format(E.nom, math.floor(E.prix * Enchere.MULT + 0.5), player.DisplayName)
	E.texteCourant = E.promptE.ObjectText
	majPanneau(E)
	lancerTour(E)
end

-- infos = { nom, tier, prix, peutAcheter(player) -> ok, raison ; gagne(player, prixPaye) }
function Enchere.Equiper(voiture, infos)
	local root = voiture.PrimaryPart
	if not root then return end
	local E = { voiture = voiture, infos = infos, nom = infos.nom, tier = infos.tier, prix = infos.prix, meneur = nil, participants = {}, historique = {}, fini = false }
	Encheres[voiture] = E

	local promptE = Instance.new("ProximityPrompt")
	promptE.Name = "Achat"; promptE.ActionText = "Acheter"
	promptE.ObjectText = ("%s (%s) — %d $"):format(infos.nom, infos.tier, infos.prix)
	promptE.KeyboardKeyCode = Enum.KeyCode.E; promptE.GamepadKeyCode = Enum.KeyCode.ButtonX
	promptE.HoldDuration = 0.6; promptE.MaxActivationDistance = Enchere.DISTANCE; promptE.RequiresLineOfSight = false
	promptE.Style = Enum.ProximityPromptStyle.Default; promptE.UIOffset = Vector2.new(0, -20); promptE.Parent = root
	E.texteBase = promptE.ObjectText; E.texteCourant = E.texteBase
	E.promptE = promptE

	local okM, Monetisation = pcall(function() return require(ServerScriptService:WaitForChild("Monetisation", 5)) end)
	local produit = okM and Monetisation and Monetisation.PRODUITS and Monetisation.PRODUITS.Voiture and Monetisation.PRODUITS.Voiture[infos.tier]
	local promptF = Instance.new("ProximityPrompt")
	promptF.Name = "AchatRobux"; promptF.ActionText = "Acheter en Robux"
	promptF.ObjectText = (produit and produit ~= 0) and "Achat immédiat" or "Bientôt disponible"
	promptF.KeyboardKeyCode = Enum.KeyCode.F; promptF.GamepadKeyCode = Enum.KeyCode.ButtonY
	promptF.HoldDuration = 0.4; promptF.MaxActivationDistance = Enchere.DISTANCE; promptF.RequiresLineOfSight = false
	promptF.Style = Enum.ProximityPromptStyle.Default; promptF.UIOffset = Vector2.new(0, 40); promptF.Parent = root
	E.promptF = promptF

	E.refus = function(msg)
		promptE.ObjectText = msg
		task.delay(2, function() if promptE.Parent and promptE.Enabled then promptE.ObjectText = E.texteCourant end end)
	end
	E.panneau = creerPanneau(voiture, E)

	promptE.Triggered:Connect(function(player) encherir(E, player) end)
	promptF.Triggered:Connect(function(player)
		if E.fini then return end
		local ok, raison = infos.peutAcheter(player)
		if not ok then return E.refus(raison) end
		if not (produit and produit ~= 0) then return E.refus("Achat en Robux bientôt disponible") end
		AttenteRobux[player.UserId] = { voiture = voiture, t = os.clock() }
		local okP, err = pcall(function() MarketplaceService:PromptProductPurchase(player, produit) end)
		if not okP then warn("[Enchere] PromptProductPurchase : " .. tostring(err)) end
	end)
	return E
end

-- recu d'un produit "Voiture" (Monetisation) : la voiture en attente est attribuee, meme en pleine enchere
function Enchere.AchatRobux(player, tier)
	local att = AttenteRobux[player.UserId]
	AttenteRobux[player.UserId] = nil
	local E = att and Encheres[att.voiture]
	if E and not E.fini and att.voiture.Parent then
		local ok, raison = E.infos.peutAcheter(player)
		if ok then terminer(E, player, 0, true) return true end
		warn("[Enchere] achat Robux refuse : " .. tostring(raison))
	end
	-- la voiture n'est plus la : le modele de la rarete achetee arrive comme prochaine cliente
	local modeles = Car[tier] and Car[tier].Models
	local nom = att and att.voiture:GetAttribute("Modele") or (modeles and modeles[math.random(1, #modeles)])
	if nom then PlayerData.AddToRecoveryQueue(player, nom, tier) end
	return true
end

function Enchere.Arreter(voiture)
	local E = Encheres[voiture]
	if E and not E.fini then
		E.fini = true
		for _, p in ipairs({E.promptE, E.promptF}) do if p then p.Enabled = false end end
		if E.panneau then E.panneau:Destroy() end
		Encheres[voiture] = nil
	end
end

function Enchere.EnCours(voiture)
	local E = Encheres[voiture]
	return E and not E.fini and E.meneur ~= nil
end

Players.PlayerRemoving:Connect(function(p) AttenteRobux[p.UserId] = nil end)

return Enchere
