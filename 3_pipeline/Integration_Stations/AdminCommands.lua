--[[ AdminCommands   (Script, ServerScriptService)
	Commandes de test dans le chat, reservees aux comptes de la liste ADMINS (identifies par UserId : un pseudo peut
	changer et etre repris par quelqu'un d'autre, un UserId jamais).

		/money 5000          ajoute 5000 $ (entier de 1 a 1 000 000 000)
		/money -500          retire 500 $ (jamais en dessous de 0)
		/unlock droit1       debloque une extension (droit1..3, haut1..3)
		/give 4 10           ajoute 10 exemplaires du consommable "4" (defaut : 10)
		/mutation foudre     un eclair frappe la voiture la plus proche de toi (electrique 45 s, paie x1,5)
		/mutation or         la voiture la plus proche devient en or (paie x3)   |  /mutation argent (x2)
		/mutation stop       retablit toutes les voitures
		/animation camion    lance la livraison (van) tout de suite, pour voir l'animation
		/cinematique GT3     rejoue la cinematique de decouverte de la GT3 sur la prochaine voiture
		/goudron 1 1 10 9    (test) pose du goudron sur les cases x 1..10, z 1..9
		/poser L4_Rouleaux 7 5   (test) pose un meuble du catalogue en (x, z) [orientation 0-3]
		/tutoriel                rejoue le tutoriel d'ItsCirly
		/stock 20            (test) remplit toutes les stations (consommable 1 par defaut)
		/acces [entree|sortie n]   etat des acces, ou deplace l'entree (rangee) / la sortie (colonne)
		/aide                rappelle ces commandes

	Tout autre joueur qui tape ces commandes est ignore (et signale dans la sortie du serveur).
]]
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

-- UserIds autorises (toi : thamary4). Pour ajouter quelqu'un : [123456] = true,
local ADMINS = {
	[1558910815] = true,
}

local MONTANT_MAX = 1_000_000_000

-- nombre entier fini dans les bornes, sinon nil (refuse "nan", "inf", 1e400, 12.5 ...)
local function entier(texte, mini, maxi)
	local n = tonumber(texte)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	if math.floor(n) ~= n or n < mini or n > maxi then return nil end
	return n
end

local function repondre(player, texte)
	print(("[ADMIN] %s : %s"):format(player.Name, texte))
end

local COMMANDES = {}

COMMANDES.money = function(player, args)
	local montant = entier(args[1], -MONTANT_MAX, MONTANT_MAX)
	if not montant or montant == 0 then return repondre(player, "usage : /money <entier non nul>") end
	if montant > 0 then
		PlayerData.AddMoney(player, montant)
	else
		local actuel = PlayerData.GetMoney(player)
		PlayerData.SpendMoney(player, math.min(-montant, actuel))
	end
	repondre(player, ("argent %s%d -> %d $"):format(montant > 0 and "+" or "", montant, PlayerData.GetMoney(player)))
end

COMMANDES.unlock = function(player, args)
	local nom = args[1]
	if not nom or not Catalogue.GetInfo("Extension", nom) then return repondre(player, "usage : /unlock <droit1|droit2|droit3|haut1|haut2|haut3>") end
	PlayerData.UnlockExtension(player, nom)
	repondre(player, "extension debloquee : " .. nom)
end

COMMANDES.give = function(player, args)
	local item = args[1]
	if not item or not Catalogue.GetInfo("Consommable", item) then return repondre(player, "usage : /give <id consommable> [quantite]") end
	local qte = args[2] and entier(args[2], 1, 100000) or 10
	PlayerData.AddItem(player, item, qte)
	repondre(player, ("+%d x consommable %s"):format(qte, item))
end

-- /livrer [quantite] [item] : commande de test sans passer par le Stock (pas de verification de place) : le van part tout de suite
COMMANDES.livrer = function(player, args)
	local qte = args[1] and entier(args[1], 1, 99) or 5
	local item = args[2] or "1"
	if not Catalogue.GetInfo("Consommable", item) then return repondre(player, "usage : /livrer [quantite] [id consommable]") end
	local data = PlayerData.GetData(player)
	if not data then return end
	if type(data.Livraisons) ~= "table" then data.Livraisons = {} end
	table.insert(data.Livraisons, {item = item, qte = qte})
	local L = require(ServerScriptService:WaitForChild("Livraison"))
	L.Envoyer(player, workspace:GetServerTimeNow())
	repondre(player, ("van envoye avec %d x %s"):format(qte, item))
end

-- /animation camion : lance la livraison (le van sort du tunnel, voie de gauche, rond-point, cour, cartons) pour la voir
COMMANDES.animation = function(player, args)
	local quoi = (args[1] or ""):lower()
	if quoi == "camion" or quoi == "livraison" or quoi == "van" then
		return COMMANDES.livrer(player, {"5", "1"})
	end
	repondre(player, "usage : /animation camion")
end

-- ---------------------------------------------------------------------------------------------------------------------
-- v51 : commandes de TEST de construction (sans passer par l'interface)
--   /goudron x0 z0 x1 z1        pose du goudron sur le rectangle de cases (grille principale)
--   /poser <meuble> x z [o]     pose un meuble du catalogue Furniture (ex : /poser L4_Rouleaux 7 5 0, /poser 2 9 8)
--   /stock [qte] [item]         remplit toutes les stations (defaut 20 x consommable 1, dans la limite de leur capacite)
--   /acces [entree|sortie n]    etat des acces, ou deplacement
-- ---------------------------------------------------------------------------------------------------------------------
local function plotCenterDe(player)
	local folder = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	local ref = folder and folder:FindFirstChild("PlotCenterRef")
	return ref and ref.Value
end
local function cfCase(pc, x, z, y) return pc:GetPivot() * CFrame.new((x - 0.5) * 15, y or 0, (z - 0.5) * 15 - 7.5) end

COMMANDES.goudron = function(player, args)
	local x0, z0, x1, z1 = entier(args[1], 1, 18), entier(args[2], 1, 33), entier(args[3], 1, 18), entier(args[4], 1, 33)
	if not (x0 and z0 and x1 and z1) then return repondre(player, "usage : /goudron x0 z0 x1 z1") end
	local pc = plotCenterDe(player)
	if not pc then return repondre(player, "pas de plot") end
	local PM = require(ServerScriptService:WaitForChild("PlotManager"))
	local n = 0
	for x = math.min(x0, x1), math.max(x0, x1) do
		for z = math.min(z0, z1), math.max(z0, z1) do
			if PM.Place(player, "sol_goudron", "Sol", 0, cfCase(pc, x, z)) then n += 1 end
		end
	end
	repondre(player, ("goudron : %d case(s) posee(s)"):format(n))
end

COMMANDES.poser = function(player, args)
	local nom = args[1]
	local x, z = entier(args[2], 1, 18), entier(args[3], 1, 33)
	local o = args[4] and entier(args[4], 0, 3) or 0
	if not (nom and x and z and Catalogue.GetInfo("Furniture", nom)) then return repondre(player, "usage : /poser <meuble du catalogue> x z [orientation 0-3]") end
	local pc = plotCenterDe(player)
	if not pc then return repondre(player, "pas de plot") end
	local PM = require(ServerScriptService:WaitForChild("PlotManager"))
	local ok, raison = PM.Place(player, nom, "Furniture", o, cfCase(pc, x, z, 0.616))
	repondre(player, ok and ("%s pose en (%d, %d)"):format(nom, x, z) or ("pose refusee : " .. tostring(raison)))
end

COMMANDES.stock = function(player, args)
	local qte = args[1] and entier(args[1], 1, 1000) or 20
	local item = args[2] or "1"
	if not Catalogue.GetInfo("Consommable", item) then return repondre(player, "usage : /stock [qte] [id consommable]") end
	local data = PlayerData.GetData(player)
	if not (data and data.Stations) then return repondre(player, "aucune station") end
	local n = 0
	for id, st in pairs(data.Stations) do
		local infos = Catalogue.GetInfo("Furniture", st.Name)
		local accepte = not infos or not infos.Accepted or table.find(infos.Accepted, item) ~= nil
		if accepte then
			local capa = infos and infos.Capacity or 1000
			local ajout = math.max(0, math.min(qte, capa - (st.Quantity or 0)))
			if ajout > 0 then PlayerData.FillStation(player, id, item, ajout); n += 1 end
		end
	end
	repondre(player, ("stock : %d station(s) remplie(s) avec %s"):format(n, item))
end

COMMANDES.acces = function(player, args)
	local A = require(ServerScriptService:WaitForChild("Acces"))
	local PM = require(ServerScriptService:WaitForChild("PlotManager"))
	local sf = PM.SpawnFolderDe(player)
	if not sf then return repondre(player, "pas de plot") end
	local quoi = (args[1] or ""):lower()
	if quoi == "" then return repondre(player, "acces : " .. A.Resume(player, sf)) end
	local n = entier(args[2], 1, 33)
	if not n or (quoi ~= "entree" and quoi ~= "sortie") then return repondre(player, "usage : /acces  |  /acces entree|sortie <rangee|colonne>") end
	local ok, raison = A.Deplacer(player, quoi == "entree" and "Entree" or "Sortie", n)
	repondre(player, ok and (quoi .. " deplacee en " .. n) or ("refuse : " .. tostring(raison)))
end

-- /cinematique GT3 : rejoue la cinematique de decouverte sur la prochaine voiture cliente (qui sera une GT3)
COMMANDES.cinematique = function(player, args)
	local nom = args[1] or "GT3"
	local CM = require(ServerScriptService:WaitForChild("CarManager"))
	local ok, err = CM.ForcerCinematique(player, nom)
	if ok then repondre(player, "cinematique " .. nom .. " sur la prochaine voiture (15-25 s)") else repondre(player, tostring(err)) end
end

-- v53 : rejoue le tutoriel (ItsCirly) sur le plot actuel
COMMANDES.tutoriel = function(player, args)
	local T = require(ServerScriptService:WaitForChild("Tutoriel"))
	if T.EnCours(player) then return repondre(player, "tutoriel deja en cours") end
	local PM = require(ServerScriptService:WaitForChild("PlotManager"))
	local spawnFolder = PM.SpawnFolderDe(player)
	local plotFolder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not (spawnFolder and plotFolder) then return repondre(player, "pas de plot") end
	repondre(player, "tutoriel : c'est parti")
	task.spawn(T.Lancer, player, spawnFolder, plotFolder, { rejouer = true })
end

-- mutations : pack Foudre + pack Metal (ServerScriptService/FoudreServeur, MetalServeur, Mutations)
local function mutations()
	local m = ServerScriptService:FindFirstChild("FoudreServeur")
	local F = m and require(m)
	return F and F.Mutations or nil
end

local function voitureLaPlusProche(player, liste)
	local racine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local centre = racine and racine.Position or Vector3.zero
	local best, bd = nil, math.huge
	for _, v in ipairs(liste) do
		local d = (v:GetPivot().Position - centre).Magnitude
		if d < bd then best, bd = v, d end
	end
	return best, bd
end

-- /mutation foudre|or|argent : mute la voiture la plus proche ; /mutation stop : tout retablir
COMMANDES.mutation = function(player, args)
	local M = mutations()
	if not M then return repondre(player, "script Mutations introuvable") end
	local genre = (args[1] or ""):lower()
	if genre == "stop" or genre == "fin" then M.toutRetablir(); return repondre(player, "toutes les voitures sont retablies") end
	local carte = {foudre = "Electrique", electrique = "Electrique", eclair = "Electrique", ["or"] = "Or", gold = "Or", argent = "Argent", silver = "Argent"}
	if not carte[genre] then return repondre(player, "usage : /mutation foudre | or | argent | stop") end
	local best, bd = voitureLaPlusProche(player, M.voitures())
	if not best then return repondre(player, "aucune voiture en circulation") end
	M.appliquer(best, carte[genre])
	repondre(player, ("%s sur %s (a %d studs)"):format(carte[genre], best.Name, bd))
end
COMMANDES.foudre = function(player, args) COMMANDES.mutation(player, {args[1] == "stop" and "stop" or "foudre"}) end

COMMANDES.aide = function(player)
	repondre(player, "/money <n>  |  /unlock <extension>  |  /give <item> [qte]  |  /livrer [qte] [item]  |  /animation camion  |  /cinematique GT3  |  /mutation foudre|or|argent|stop  |  /goudron x0 z0 x1 z1  |  /poser <meuble> x z [o]  |  /stock [qte] [item]  |  /acces [entree|sortie n]  |  /tutoriel")
end

-- v49 : une meme commande peut arriver deux fois (Player.Chatted + TextChatCommand.Triggered) : on ignore un doublon < 1 s
local dernier = {}
local function surMessage(player, message)
	if type(message) ~= "string" or message:sub(1, 1) ~= "/" then return end
	local d = dernier[player.UserId]
	if d and d.texte == message and os.clock() - d.t < 1 then return end
	dernier[player.UserId] = {texte = message, t = os.clock()}
	local mots = message:split(" ")
	local nom = mots[1]:sub(2):lower()
	local cmd = COMMANDES[nom]
	if not cmd then return end
	if not ADMINS[player.UserId] then
		warn(("[ADMIN] tentative refusee : %s (UserId %d) a tape %s"):format(player.Name, player.UserId, message))
		return
	end
	local args = {}
	for i = 2, #mots do if mots[i] ~= "" then table.insert(args, mots[i]) end end
	local ok, err = pcall(cmd, player, args)
	if not ok then warn("[ADMIN] erreur : " .. tostring(err)) end
end

local function brancher(player)
	player.Chatted:Connect(function(message) surMessage(player, message) end)
end

Players.PlayerAdded:Connect(brancher)
for _, p in ipairs(Players:GetPlayers()) do brancher(p) end

-- v49 : avec le chat TextChatService, un message qui commence par "/" est une COMMANDE de chat : il n'est pas envoye et
-- Player.Chatted ne se declenche pas. On declare donc chaque commande comme TextChatCommand (alias /nom) : Triggered
-- arrive sur le serveur avec le texte complet.
do
	local TextChatService = game:GetService("TextChatService")
	local ok = pcall(function()
		local dossier = TextChatService:FindFirstChild("CommandesAdmin")
		if not dossier then dossier = Instance.new("Folder"); dossier.Name = "CommandesAdmin"; dossier.Parent = TextChatService end
		for nom in pairs(COMMANDES) do
			if not dossier:FindFirstChild(nom) then
				local c = Instance.new("TextChatCommand")
				c.Name = nom
				c.PrimaryAlias = "/" .. nom
				c.Parent = dossier
				c.Triggered:Connect(function(source, texte)
					local player = source and Players:GetPlayerByUserId(source.UserId)
					if player then surMessage(player, texte) end
				end)
			end
		end
	end)
	if not ok then warn("[ADMIN] TextChatCommand indisponible : seules les commandes du chat classique marchent") end
end
