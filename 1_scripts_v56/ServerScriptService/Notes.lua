--[[ Notes (ModuleScript, ServerScriptService) — v56 : NOTES DE LA STATION (onglet "Ma station" de l'UI v24).
	Quatre notes de 0 a 100, recalculees toutes les 5 s et posees en attributs sur le joueur (NoteProprete, NoteRapidite,
	NoteAccueil, NoteDecoration, NoteGlobale) ; l'interface les lit (UIController, section Station).
	  Proprete    : chaque voiture servie salit la station (SALETE_PAR_VOITURE points). Un AGENT D'ENTRETIEN (employe
	                "Cleaner", WorkerManager) nettoie en continu ; sans agent, le joueur nettoie lui-meme avec E (invite
	                "Nettoyer" sur une station des que la proprete passe sous SEUIL_INVITE). Sauvee dans le profil (data.Proprete).
	  Rapidite    : temps d'attente moyen des 12 derniers clients entre leur arrivee et le debut du service (file sur la
	                branche + attente de stock / d'employe). 0 s -> 100, ATTENTE_REF s -> 0.
	  Accueil     : part des stations et des caisses qui ont un employe (ou sont automatiques). Sans caisse : 0.
	  Decoration  : score du mode Decoration (Diagnostic.ScoreDecoration) ramene a 0..100 (50 = neutre).
	  Globale     : moyenne des quatre.
	EFFET SUR L'ECONOMIE (voir 2_documents/ECONOMIE_v56.md) :
	  pourboire = POURBOIRE_MIN .. POURBOIRE_MAX selon la note globale, multiplie le gain de chaque voiture (CarManager) ;
	  cadence   = CADENCE_MIN .. CADENCE_MAX selon la note globale, multiplie la frequence des clients (CarManager.Cadence).
	Rien ici n'est cru du client : tout est calcule a partir des donnees serveur.
]]
local Notes = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

Notes.REGLAGES = {
	SALETE_PAR_VOITURE = 2.5,     -- points de proprete perdus par voiture servie
	NETTOYAGE_AGENT = 0.6,        -- points rendus par seconde et par agent d'entretien (2 agents au plus comptent)
	NETTOYAGE_MANUEL = 30,        -- points rendus par un nettoyage a la main (E)
	SEUIL_INVITE = 70,            -- sous cette proprete, et sans agent, l'invite "Nettoyer" apparait
	ATTENTE_REF = 60,             -- secondes d'attente moyenne qui donnent une rapidite de 0
	ATTENTE_HISTORIQUE = 12,      -- nombre de clients retenus pour la moyenne
	POURBOIRE_MIN = 0.85, POURBOIRE_MAX = 1.30,
	CADENCE_MIN = 0.90, CADENCE_MAX = 1.15,
	PERIODE = 5,                  -- secondes entre deux recalculs
	PATROUILLE = 20,              -- secondes entre deux deplacements de l'agent d'entretien
}
local R = Notes.REGLAGES

local Etat = {}                   -- [userId] = { attentes = {}, actif = true, invite = Part?, tick = 0 }

local function etatDe(player)
	local e = Etat[player.UserId]
	if not e then e = { attentes = {}, actif = false, tick = 0 }; Etat[player.UserId] = e end
	return e
end

local function proprete(data)
	if type(data.Proprete) ~= "number" then data.Proprete = 100 end
	return data.Proprete
end

-- ------------------------------------------------------------------------------------------------ calculs
local function noteProprete(player, data)
	return math.clamp(proprete(data), 0, 100) / 100
end

local function noteRapidite(player)
	local e = etatDe(player)
	if #e.attentes == 0 then return 0.7 end            -- pas encore de client : note neutre
	local total = 0
	for _, a in ipairs(e.attentes) do total += a end
	local moy = total / #e.attentes
	return math.clamp(1 - moy / R.ATTENTE_REF, 0, 1)
end

local function noteAccueil(data)
	local ns, nsOk, nc, ncOk = 0, 0, 0, 0
	for _, st in pairs(data.Stations or {}) do ns += 1; if st.Worker ~= nil then nsOk += 1 end end
	for _, c in pairs(data.Caisses or {}) do nc += 1; if c.Worker ~= nil then ncOk += 1 end end
	if ns == 0 or nc == 0 then return 0 end
	return 0.6 * nsOk / ns + 0.4 * ncOk / nc
end

local Diagnostic = nil
local function noteDecoration(player)
	if Diagnostic == nil then
		local ok, mod = pcall(function() return require(ServerScriptService:WaitForChild("Diagnostic", 10)) end)
		Diagnostic = ok and mod or false
	end
	if not (Diagnostic and Diagnostic.ScoreDecoration) then return 0.5 end
	local ok, score = pcall(Diagnostic.ScoreDecoration, player)
	if not ok then return 0.5 end
	return math.clamp(0.5 + score / 200, 0, 1)
end

-- les quatre notes (0..1) et la globale
function Notes.Calculer(player)
	local data = PlayerData.GetData(player)
	if not data then return { proprete = 1, rapidite = 0.7, accueil = 0, decoration = 0.5, globale = 0.55 } end
	local n = {
		proprete = noteProprete(player, data),
		rapidite = noteRapidite(player),
		accueil = noteAccueil(data),
		decoration = noteDecoration(player),
	}
	n.globale = (n.proprete + n.rapidite + n.accueil + n.decoration) / 4
	return n
end

local Derniere = {}               -- [userId] = derniere table de notes (evite de recalculer la decoration a chaque voiture)
local function globale(player)
	local n = Derniere[player.UserId]
	if not n then n = Notes.Calculer(player); Derniere[player.UserId] = n end
	return n.globale
end

-- multiplicateur du gain d'une voiture (pourboire) : 0,85 .. 1,30 selon la note globale
function Notes.Pourboire(player)
	local ok, g = pcall(globale, player)
	if not ok then return 1 end
	return R.POURBOIRE_MIN + (R.POURBOIRE_MAX - R.POURBOIRE_MIN) * math.clamp(g, 0, 1)
end

-- multiplicateur de la frequence des clients : 0,90 .. 1,15 selon la note globale
function Notes.MultCadence(player)
	local ok, g = pcall(globale, player)
	if not ok then return 1 end
	return R.CADENCE_MIN + (R.CADENCE_MAX - R.CADENCE_MIN) * math.clamp(g, 0, 1)
end

-- ------------------------------------------------------------------------------------------------ evenements
-- une voiture vient d'etre servie (CarManager, au paiement)
function Notes.VoitureServie(player)
	local data = PlayerData.GetData(player)
	if not data then return end
	data.Proprete = math.clamp(proprete(data) - R.SALETE_PAR_VOITURE, 0, 100)
end

-- attente d'un client (secondes) entre son arrivee et le debut du service (CarManager)
function Notes.EnregistrerAttente(player, secondes)
	local e = etatDe(player)
	table.insert(e.attentes, math.max(0, secondes or 0))
	while #e.attentes > R.ATTENTE_HISTORIQUE do table.remove(e.attentes, 1) end
end

-- nettoyage (agent ou joueur)
function Notes.Nettoyer(player, points)
	local data = PlayerData.GetData(player)
	if not data then return end
	data.Proprete = math.clamp(proprete(data) + (points or R.NETTOYAGE_MANUEL), 0, 100)
end

-- ------------------------------------------------------------------------------------------------ agents et invite
local function dossierPlot(player)
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(player.Name .. "'s plot") or nil
end

local function agents(data)
	local n = 0
	for _, w in pairs(data.Workers or {}) do if w.Type == "Cleaner" then n += 1 end end
	return n
end

-- meubles 3D (stations) du plot : [FurnitureID] = Model
local function stations3D(player, data)
	local dossier = dossierPlot(player)
	local out = {}
	if not dossier then return out end
	for _, o in ipairs(dossier:GetChildren()) do
		local id = o:GetAttribute("FurnitureID")
		if id and data.Stations and data.Stations[id] then out[id] = o end
	end
	return out
end

-- l'agent d'entretien se promene de station en station (il n'a pas de poste)
local function patrouiller(player, data)
	local dossier = dossierPlot(player)
	if not dossier then return end
	local cibles = {}
	for _, m in pairs(stations3D(player, data)) do table.insert(cibles, m) end
	if #cibles == 0 then return end
	for id, w in pairs(data.Workers or {}) do
		if w.Type == "Cleaner" then
			local dummy = dossier:FindFirstChild(id)
			local cible = cibles[math.random(1, #cibles)]
			if dummy and cible then
				local ok, pivot = pcall(function() return cible:GetPivot() end)
				if ok then
					local angle = math.random() * math.pi * 2
					local pos = pivot.Position + Vector3.new(math.cos(angle) * 24, 0, math.sin(angle) * 24)
					local sol = pivot.Position.Y + 3.616
					pcall(function() dummy:PivotTo(CFrame.lookAt(Vector3.new(pos.X, sol, pos.Z), Vector3.new(pivot.Position.X, sol, pivot.Position.Z))) end)
				end
			end
		end
	end
end

-- invite "E - Nettoyer" sur une station (piece InviteNettoyage, distincte de l'InviteService du service manuel)
local function retirerInvite(e)
	if e.invite then e.invite:Destroy(); e.invite = nil end
end
local function poserInvite(player, data, e)
	if e.invite and e.invite.Parent then return end
	local meuble = nil
	for _, m in pairs(stations3D(player, data)) do meuble = m break end
	if not meuble then return end
	local ok, pivot = pcall(function() return meuble:GetPivot() end)
	if not ok then return end
	local racine = Instance.new("Part"); racine.Name = "InviteNettoyage"; racine.Anchored = true; racine.CanCollide = false
	racine.CanTouch = false; racine.CanQuery = false; racine.Transparency = 1; racine.Size = Vector3.new(1, 1, 1); racine.CastShadow = false
	racine.CFrame = CFrame.new(pivot.Position + Vector3.new(6, 4, 6))
	local p = Instance.new("ProximityPrompt"); p.Name = "Nettoyer"
	p.KeyboardKeyCode = Enum.KeyCode.E; p.HoldDuration = 1.0; p.MaxActivationDistance = 22
	p.RequiresLineOfSight = false; p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	p.ActionText = "Nettoyer la station"; p.ObjectText = "Propreté " .. math.floor(proprete(data)) .. " %"; p.Parent = racine
	p.Triggered:Connect(function(qui)
		if qui ~= player then return end
		Notes.Nettoyer(player, R.NETTOYAGE_MANUEL)
		local d = PlayerData.GetData(player)
		if d then p.ObjectText = "Propreté " .. math.floor(proprete(d)) .. " %" end
		Notes.Publier(player)
		if d and proprete(d) >= R.SEUIL_INVITE then retirerInvite(e) end
	end)
	racine.Parent = meuble
	e.invite = racine
end

-- ------------------------------------------------------------------------------------------------ publication
function Notes.Publier(player)
	if not player.Parent then return end
	local n = Notes.Calculer(player)
	Derniere[player.UserId] = n
	pcall(function()
		player:SetAttribute("NoteProprete", math.floor(n.proprete * 100 + 0.5))
		player:SetAttribute("NoteRapidite", math.floor(n.rapidite * 100 + 0.5))
		player:SetAttribute("NoteAccueil", math.floor(n.accueil * 100 + 0.5))
		player:SetAttribute("NoteDecoration", math.floor(n.decoration * 100 + 0.5))
		player:SetAttribute("NoteGlobale", math.floor(n.globale * 100 + 0.5))
	end)
	return n
end

function Notes.Demarrer(player)
	local e = etatDe(player)
	if e.actif then return end
	e.actif = true
	Notes.Publier(player)
	task.spawn(function()
		while e.actif and player.Parent do
			task.wait(R.PERIODE)
			if not (e.actif and player.Parent) then break end
			local data = PlayerData.GetData(player)
			if not data then break end
			local ok, err = pcall(function()
				-- agents d'entretien : nettoyage continu et patrouille
				local n = agents(data)
				if n > 0 then
					Notes.Nettoyer(player, R.NETTOYAGE_AGENT * math.min(n, 2) * R.PERIODE)
					retirerInvite(e)
					e.tick += 1
					if e.tick % math.max(1, math.floor(R.PATROUILLE / R.PERIODE)) == 0 then patrouiller(player, data) end
				elseif proprete(data) < R.SEUIL_INVITE then
					poserInvite(player, data, e)
				else
					retirerInvite(e)
				end
				Notes.Publier(player)
			end)
			if not ok then warn("[Notes] " .. tostring(err)) end
		end
	end)
end

function Notes.Arreter(player)
	local e = Etat[player.UserId]
	if e then e.actif = false; retirerInvite(e) end
	Etat[player.UserId] = nil
	Derniere[player.UserId] = nil
end

Players.PlayerRemoving:Connect(Notes.Arreter)

return Notes
