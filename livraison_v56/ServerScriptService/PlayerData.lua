local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

local UpdateClientData = game.ReplicatedStorage:WaitForChild("UpdateClientData")

local PlayerData = {}
local Data = {}

-- Grille de base : 20 cases le long de la route (200 studs : de l'entree a la sortie du plot) x 11 cases de profondeur.
-- Les extensions n'ajoutent que de la profondeur (Z) : la largeur du plot est fixee par l'entree et la sortie.
local baseX = 18                  -- v49 (map V21) : 18 colonnes de 15 studs = toute la largeur du plot (270), du trottoir au bord
local baseZ = 11
PlayerData.MAX_X = baseX          -- aucune extension en X
PlayerData.MAX_Z = baseZ + 3 * 3 + 3 * 4   -- droit1..3 (+3) et haut1..3 (+4) : 32 rangees au plus (le plot en a 32 : 480 / 15)

-- ======================================================================================================================
-- GESTION DES DATA
-- ======================================================================================================================

-- attributs du joueur lus par l'interface (UI v23) : Money, Rank (nom + palier), XP, XPNext (xp du rang suivant), Day
function PlayerData.MajAttributs(player: Player)
	local data = Data[player.UserId]
	if not data or not player.Parent then return end
	pcall(function()
		player:SetAttribute("Money", data.Money or 0)
		player:SetAttribute("XP", data.Xp or 0)
		local Rank = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Rank"))
		local rang = PlayerData.GetRank(player)
		local suivant
		for i, r in ipairs(Rank) do if r == rang then suivant = Rank[i + 1] end end
		player:SetAttribute("Rank", rang and rang.Nom or "Bronze")
		local index = 1
		for i, r in ipairs(Rank) do if r == rang then index = i end end
		player:SetAttribute("RankIndex", index)                                   -- v55 : 1..7, fenetre Rangs de l'UI v24
		player:SetAttribute("XPNext", suivant and suivant.Xp or (data.Xp or 0))
		player:SetAttribute("Day", math.max(1, math.floor((os.time() - (data.Cree or os.time())) / 86400) + 1))
	end)
end

function PlayerData.Init(player: Player, data)
	Data[player.UserId] = data
	PlayerData.ClearData(player)
	if type(data) == "table" and not data.Cree then data.Cree = os.time() end
	PlayerData.MajAttributs(player)
end

function PlayerData.GetData(player: Player)
	return Data[player.UserId]
end

function PlayerData.ClearData(player: Player)
	local data = Data[player.UserId]
	if not data then return end

	if data.Stations then
		for _, station in pairs(data.Stations) do
			station.Car = nil
			station.Service = "Available"
			station.Payment = "None"
		end
	end

	if data.Caisses then
		for _, caisse in pairs(data.Caisses) do
			caisse.Queue = {}
			caisse.Service = "Available" 
		end
	end

end

function PlayerData.Remove(player: Player)
	Data[player.UserId] = nil
end

function PlayerData.GetGrid(player: Player)
	local data = Data[player.UserId]
	if not data then return end

	-- grille MAX_X x (MAX_Z + 1) (rangee supplementaire pour le bord des murs) ; une grille enregistree plus petite
	-- (ancienne base 7 x 11 = 13 x 21) est completee, jamais tronquee
	if not data.Grid then data.Grid = {} end
	for x = 1, PlayerData.MAX_X do
		if not data.Grid[x] then data.Grid[x] = {} end
		for z = 1, PlayerData.MAX_Z + 1 do
			if not data.Grid[x][z] then
				data.Grid[x][z] = {
					Sol = 0, 
					Furniture = 0, 
					FurnitureID = 0, 
					MurNord = 0, 
					MurOuest = 0, 
					Plafond = 0
				}
			end
		end
	end

	return data.Grid
end

-- v54 : DEMI-GRILLE (7,5 studs) des petits meubles et de la deco (ReplicatedStorage > Demi). Dictionnaire sauvegarde :
-- cle "hx_hz" -> { Furniture = nom, FurnitureID = id ou "C<orientation>_id" sur la demi-case d'ancrage }.
-- Une pour la grille principale (data.Demi), une pour l'annexe (data.DemiAnnexe).
function PlayerData.GetDemi(player: Player, annexe: boolean)
	local data = Data[player.UserId]
	if not data then return end
	local cle = annexe and "DemiAnnexe" or "Demi"
	if type(data[cle]) ~= "table" then data[cle] = {} end
	return data[cle]
end

-- Zone annexe 3 x 3 (de l'autre cote de la route, en face du plot) : meme structure de cases que la grille principale,
-- 4e rangee z uniquement pour le bord des murs (comme la grille principale a une rangee de plus que maxZ).
PlayerData.ANNEXE_X, PlayerData.ANNEXE_Z = 2, 2   -- v48 : dalle de 30 x 30 = 2 x 2 cases de 15

function PlayerData.GetAnnexe(player: Player)
	local data = Data[player.UserId]
	if not data then return end

	if not data.Annexe then
		data.Annexe = {}
		for x = 1, PlayerData.ANNEXE_X do
			data.Annexe[x] = {}
			for z = 1, PlayerData.ANNEXE_Z + 1 do
				data.Annexe[x][z] = {
					Sol = 0,
					Furniture = 0,
					FurnitureID = 0,
					MurNord = 0,
					MurOuest = 0,
					Plafond = 0
				}
			end
		end
	end

	return data.Annexe
end


-- ======================================================================================================================
-- GESTION DES STATIONS
-- ======================================================================================================================

function PlayerData.InitStation(player: Player, furnitureID: string, name: string, automatic: boolean, caseAncrageX: number, caseAncrageZ: number, orientation: number)
	local data = Data[player.UserId]
	if not data then return end
	if not data.Stations then data.Stations = {} end

	if not data.Stations[furnitureID] then
		data.Stations[furnitureID] = {
			Name = name,  
			Item = nil,         
			Quantity = 0,
			Car = nil,
			Service = "Available", -- "Available", "Incoming", "Waiting", "Processing", "Completed"
			Payment = "None" ,      -- "None", "Incoming", "AwaitingPayment", "Paid"
			Worker = automatic and "Automatic" or nil,
			X = caseAncrageX,
			Z = caseAncrageZ,
			Orientation = orientation
		}
	end
	UpdateClientData:FireClient(player, "Stations", data.Stations)
end

function PlayerData.RemoveStation(player: Player, furnitureID: string)
	local data = Data[player.UserId]
	if not data or not data.Stations or not data.Stations[furnitureID] then return end

	local station = data.Stations[furnitureID]

	if station.Item and station.Quantity > 0 then
		PlayerData.AddItem(player, station.Item, station.Quantity)
	end
	
	if station.Worker then
		local worker = data.Workers[station.Worker]
		if worker then
			worker.Furniture = nil
			UpdateClientData:FireClient(player, "Workers", data.Workers) -- On prévient l'UI du joueur
		end
	end

	data.Stations[furnitureID] = nil
	UpdateClientData:FireClient(player, "Stations", data.Stations)
end

function PlayerData.EmptyStation(player: Player, furnitureID: string)
	local data = Data[player.UserId]
	if not data or not data.Stations or not data.Stations[furnitureID] then return end

	local station = data.Stations[furnitureID]
	station.Item = nil
	station.Quantity = 0
	UpdateClientData:FireClient(player, "Stations", data.Stations)
end

function PlayerData.FillStation(player: Player, furnitureID: string, itemID: string, amount: number)
	local data = Data[player.UserId]
	if not data or not data.Stations or not data.Stations[furnitureID] then 
		return 
	end

	local station = data.Stations[furnitureID]
	station.Item = itemID
	station.Quantity = station.Quantity + amount
	UpdateClientData:FireClient(player, "Stations", data.Stations)
end

function PlayerData.RemoveItemStation(player: Player, furnitureID: string)
	local data = Data[player.UserId]
	if not data or not data.Stations or not data.Stations[furnitureID] then return end
	local station = data.Stations[furnitureID]
	station.Quantity -= 1
	UpdateClientData:FireClient(player, "Stations", data.Stations)
end

-- ======================================================================================================================
-- GESTION DES CAISSES
-- ======================================================================================================================

-- demi (v54, facultatif) : { CX, CZ = centre du meuble en demi-cases (fractionnaire), DX, DZ = emprise en demi-cases apres
-- rotation } ; X / Z sont alors la demi-case d'ancrage et Demi = true (CarManager place le client devant le centre)
function PlayerData.InitCaisse(player: Player, furnitureID: string, name: string, automatic: boolean,  caseAncrageX: number, caseAncrageZ: number, orientation: number, demi)
	local data = Data[player.UserId]
	if not data then return end

	if not data.Caisses then data.Caisses = {} end

	if not data.Caisses[furnitureID] then
		data.Caisses[furnitureID] = {
			Name = name,
			Worker = automatic and "Automatic" or nil,
			Service = "Available", -- "Completed", "Available", "Servicing"
			Queue = {},
			X = caseAncrageX,
			Z = caseAncrageZ,
			Orientation = orientation,
			Demi = demi and true or nil,
			CX = demi and demi.CX or nil, CZ = demi and demi.CZ or nil,
			DX = demi and demi.DX or nil, DZ = demi and demi.DZ or nil,
		}
	end
	UpdateClientData:FireClient(player, "Caisses", data.Caisses)
end

function PlayerData.RemoveCaisse(player: Player, furnitureID: string)
	local data = Data[player.UserId]
	if not data or not data.Caisses or not data.Caisses[furnitureID] then return end

	local caisse = data.Caisses[furnitureID]
	
	if caisse.Worker then
		local worker = data.Workers[caisse.Worker]
		if worker then
			worker.Furniture = nil
			UpdateClientData:FireClient(player, "Workers", data.Workers) -- On prévient l'UI du joueur
		end
	end

	data.Caisses[furnitureID] = nil
	UpdateClientData:FireClient(player, "Caisses", data.Caisses)
end

function PlayerData.JoinQueue(player: Player, furnitureID: string, carID: string)
	local caisse = Data[player.UserId].Caisses[furnitureID]
	if #caisse.Queue <= 4 then
		table.insert(caisse.Queue, carID)
		return true
	end
	return nil
end

function PlayerData.LeaveQueue(player: Player, furnitureID: string, carID: string)
	local caisse = Data[player.UserId].Caisses[furnitureID]
	local find = table.find(caisse.Queue, carID)
	if find then
		table.remove(caisse.Queue, find)
	end
end

-- ======================================================================================================================
-- GESTION DE L'INVENTAIRE
-- ======================================================================================================================

function PlayerData.AddItem(player: Player, name , amount)
	
	if amount < 0 then 
		return 
	end
	
	local data = Data[player.UserId]
	if not data then return end

	if data.Inventory[name] then
		data.Inventory[name] += amount
	else
		data.Inventory[name] = amount
	end
	
	UpdateClientData:FireClient(player, "Inventory", data.Inventory)
end

function PlayerData.RemoveItem(player: Player, itemID: string, amount: number)
	local data = Data[player.UserId]
	if not data or not data.Inventory then return end

	if not data.Inventory[itemID] then return end

	data.Inventory[itemID] -= amount

	if data.Inventory[itemID] <= 0 then
		data.Inventory[itemID] = nil
	end
	
	UpdateClientData:FireClient(player, "Inventory", data.Inventory)
end

-- ======================================================================================================================
-- GESTION DES EMPLOYÉS
-- ======================================================================================================================

function PlayerData.InitWorker(player: Player, workerID: string, workertype: string, workername: string)
	local data = Data[player.UserId]
	if not data then return end
	if not data.Workers then data.Workers = {} end

	if not data.Workers[workerID] then
		data.Workers[workerID] = {
			Type = workertype,
			Name = workername,
			Furniture = nil,
		}
	end
	
	UpdateClientData:FireClient(player, "Workers", data.Workers)
end

function PlayerData.AssignWorker(player: Player, workerID: string, furnitureID: string, category: string)
	local data = PlayerData.GetData(player)
	if not data then return end

	local worker = data.Workers[workerID]
	local furniture = data[category][furnitureID]

	worker.Furniture = furnitureID
	furniture.Worker = workerID

	UpdateClientData:FireClient(player, "Workers", data.Workers)
	UpdateClientData:FireClient(player, category, data[category])
end

function PlayerData.FireWorker(player: Player, furnitureID: string, category: string)
	local data = Data[player.UserId]
	if not data then return end

	local furniture = data[category][furnitureID]
	local worker = data.Workers[furniture.Worker]

	worker.Furniture = nil
	furniture.Worker = nil

	UpdateClientData:FireClient(player, "Workers", data.Workers)
	UpdateClientData:FireClient(player, category, data[category])
end

function PlayerData.GetWorker(player: Player): number

	if Data[player.UserId] and Data[player.UserId].Workers then
		return Data[player.UserId].Workers
	end
	return nil
end

function PlayerData.RemoveWorker(player: Player, workerID: string)
	local data = Data[player.UserId]
	if not data or not data.Workers or not data.Workers[workerID] then return end

	data.Workers[workerID] = nil

	UpdateClientData:FireClient(player, "Workers", data.Workers)
end
-- ======================================================================================================================
-- GESTION DE L'INDEX
-- ======================================================================================================================

function PlayerData.AddCar(player: Player, carName: string, carTier: string)
	local data = Data[player.UserId]
	if not data then return end

	if not data.Index then data.Index = {} end
	if not data.Index[carTier] then data.Index[carTier] = {} end          -- v56 : ancien profil sans cette rarete

	if not data.Index[carTier][carName] then
		data.Index[carTier][carName] = 0
	end

	data.Index[carTier][carName] = data.Index[carTier][carName] + 1
	UpdateClientData:FireClient(player, "Index", data.Index)
	PlayerData.MajAttributs(player)     -- v56 : le rang depend aussi de l'Index (Requis) : attribut RankIndex a jour tout de suite
end

-- ======================================================================================================================
-- GESTION DU RANK
-- ======================================================================================================================

function PlayerData.GetRank(player: Player)
	local Rank = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Rank"))
	
	local data = Data[player.UserId]
	local xp = data and data.Xp or 0

	local rang = Rank[1]

	for i = 2, #Rank do
		local suivant = Rank[i]

		if xp < suivant.Xp then break end

		local ok = true
		for tier, nombre in pairs(suivant.Requis) do
			
			local total = 0
			for _, n in pairs((data and data.Index and data.Index[tier]) or {}) do      -- v56 : garde (ancien profil)
				total += n
			end
			
			if total < nombre then
				ok = false
				break
			end
		end

		if not ok then break end
		rang = suivant
	end

	return rang, rang.Probas
end

function PlayerData.AddXp(player: Player, amount: number)
	local data = Data[player.UserId]
	if not data or not amount or amount <= 0 then return end

	data.Xp = (data.Xp or 0) + amount
	UpdateClientData:FireClient(player, "Xp", data.Xp)
	PlayerData.MajAttributs(player)
end
-- ======================================================================================================================
-- GESTION DE LA RECOVERY QUEUE
-- ======================================================================================================================

function PlayerData.AddToRecoveryQueue(player: Player, carName: string, carTier: string)
	local data = Data[player.UserId]
	if not data then return end

	if not data.RecoveryQueue then
		data.RecoveryQueue = {}
	end

	table.insert(data.RecoveryQueue, {
		Name = carName,
		Tier = carTier
	})

end

function PlayerData.GetFromRecoveryQueue(player: Player)
	local data = Data[player.UserId]


	if not data or not data.RecoveryQueue or #data.RecoveryQueue == 0 then
		return nil, nil
	end

	local Car = table.remove(data.RecoveryQueue, 1)
	return Car.Name, Car.Tier
end


-- ======================================================================================================================
-- GESTION DE L'ARGENT
-- ======================================================================================================================

function PlayerData.GetMoney(player: Player): number
	
	if Data[player.UserId] then
		return Data[player.UserId].Money
	end
	return 0
end

function PlayerData.AddMoney(player: Player, amount: number)
	if Data[player.UserId] and amount > 0 then
		
		Data[player.UserId].Money = Data[player.UserId].Money + amount
		UpdateClientData:FireClient(player, "Money", Data[player.UserId].Money)
		player:SetAttribute("Money", Data[player.UserId].Money)
		
	end
end

function PlayerData.SpendMoney(player: Player, amount: number): boolean
	if Data[player.UserId] and amount > 0 then
		if Data[player.UserId].Money >= amount then
			
			Data[player.UserId].Money = Data[player.UserId].Money - amount
			UpdateClientData:FireClient(player, "Money", Data[player.UserId].Money)
			player:SetAttribute("Money", Data[player.UserId].Money)
			return true
		end
		return false
	end
	return amount <= 0          -- v56 : renvoie vrai/faux (etait annote boolean sans jamais rien renvoyer)
end

-- ======================================================================================================================
-- GESTION DES EXTENSIONS
-- ======================================================================================================================

function PlayerData.GetPlotSize(player: Player)
	local currentX = baseX
	local currentZ = baseZ
	
	if Data[player.UserId] then
		local extensions = Data[player.UserId].Extensions

		for name, bought in pairs(extensions) do
			if bought and Catalogue.GetInfo("Extension",name) then
				currentX = currentX + Catalogue.GetInfo("Extension",name).AddX
				currentZ = currentZ + Catalogue.GetInfo("Extension",name).AddZ
			end
		end
	end
	return currentX, currentZ
end

function PlayerData.UnlockExtension(player: Player, name: string)
	if Data[player.UserId] and Data[player.UserId].Extensions[name] ~= nil then
		Data[player.UserId].Extensions[name] = true
		UpdateClientData:FireClient(player, "Extensions", Data[player.UserId].Extensions)
	end
end

function PlayerData.GetNextExtensions(player: Player)
	local data = Data[player.UserId]
	if not data or not data.Extensions then return nil, nil end

	local unboughtX = {}
	local unboughtZ = {}

	for name, isBought in pairs(data.Extensions) do
		if isBought == false then
			local info = Catalogue.GetInfo("Extension", name)
			if info then
				if info.AddX and info.AddX > 0 then
					table.insert(unboughtX, name)
				elseif info.AddZ and info.AddZ > 0 then
					table.insert(unboughtZ, name)
				end
			end
		end
	end

	table.sort(unboughtX)
	table.sort(unboughtZ)
	local nextX = unboughtX[1]
	local nextZ = unboughtZ[1] 

	return nextX, nextZ
end

-- ======================================================================================================================
-- GESTION DE LA DATA
-- ======================================================================================================================

return PlayerData