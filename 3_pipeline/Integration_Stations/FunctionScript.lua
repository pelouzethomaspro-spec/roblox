local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlotManager = require(script.Parent.PlotManager)
local StoreManager = require(script.Parent.StoreManager)
local PlayerData = require(script.Parent.PlayerData)
local WorkerManager = require(script.Parent.WorkerManager)
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

local Placefunction = ReplicatedStorage:WaitForChild("Placefunction")
local Destroyfunction = ReplicatedStorage:WaitForChild("Destroyfunction")
local Buyfunction = ReplicatedStorage:WaitForChild("Buyfunction")
local FillStationfunction = ReplicatedStorage:WaitForChild("FillStationfunction")
local Hirefunction = ReplicatedStorage:WaitForChild("Hirefunction")
local Assignfunction = ReplicatedStorage:WaitForChild("Assignfunction")
local Extensionfunction = ReplicatedStorage:WaitForChild("Extensionfunction")
local Firefunction = ReplicatedStorage:WaitForChild("Firefunction")
local UnAssignfunction = ReplicatedStorage:WaitForChild("UnAssignfunction")

-- ======================================================================================================================
-- PLOT MANAGER
-- ======================================================================================================================

Placefunction.OnServerInvoke = function(player, item, categorie, orientation, target)
	local infos = Catalogue.GetInfo(categorie, item)
	if not infos then 
		return false 
	end

	local prix = infos.Prix
	if type(prix) ~= "number" then return false, "catalogue" end
	local money = PlayerData.GetMoney(player)
	if money < prix then
		return false, ("argent insuffisant : %d $ pour %d $"):format(money, prix)
	end

	local succes, raison = PlotManager.Place(player, item, categorie, orientation, target)
	if succes then
		PlayerData.SpendMoney(player, prix)
		return true
	else
		return false, raison or "emplacement refuse (hors du plot, case occupee, pas de sol ou mur genant)"
	end
end

-- deplacement d'un objet deja pose (aucun paiement) : RemoteFunction creee ici si elle n'existe pas dans la place
local Deplacerfunction = ReplicatedStorage:FindFirstChild("Deplacerfunction")
if not Deplacerfunction then
	Deplacerfunction = Instance.new("RemoteFunction"); Deplacerfunction.Name = "Deplacerfunction"; Deplacerfunction.Parent = ReplicatedStorage
end
Deplacerfunction.OnServerInvoke = function(player, item, orientation, target)
	if typeof(item) ~= "Instance" then return false, "objet" end
	if type(orientation) ~= "number" then return false, "orientation" end
	if typeof(target) ~= "CFrame" then return false, "cible" end
	return PlotManager.Deplacer(player, item, orientation, target)
end

Destroyfunction.OnServerInvoke= function(player, target)
	if typeof(target) ~= "Instance" then return false end
	
	local item = target.Name
	local categorie = target:GetAttribute("Categorie")
	if categorie == "MurNord" or categorie == "MurOuest" then
		 categorie = "Mur"
	end
	
	local infos = Catalogue.GetInfo(categorie, item)
	if not infos or not target then 
		return false 
	end
	local prix = infos.Prix
	
	local success = PlotManager.Destroy(player, target)
	if success then
		PlayerData.AddMoney(player, prix)
		return true
	end
	
	return false
end

Extensionfunction.OnServerInvoke = function(player, axis)
	return PlotManager.BuyExtension(player, axis)
end

-- ======================================================================================================================
-- STORE MANAGER
-- ======================================================================================================================

-- achat au Stock : paye tout de suite, livre par le camion (Livraison) quand il passe devant le plot -> (true, delai en s)
local Livraison = require(script.Parent:WaitForChild("Livraison"))
Buyfunction.OnServerInvoke = function(player, itemID, quantite)
	return Livraison.Commander(player, itemID, quantite)
end

FillStationfunction.OnServerInvoke = function(player, furnitureID, itemID)
	if type(furnitureID) ~= "string" or type(itemID) ~= "string" then
		return false 
	end
	local success, amount = StoreManager.FillStation(player, furnitureID, itemID)
	return success
end

-- ======================================================================================================================
-- WORKER MANAGER
-- ======================================================================================================================

Hirefunction.OnServerInvoke = function(player, workertype)
	WorkerManager.Hire(player, workertype)
end

Assignfunction.OnServerInvoke = function(player, workerID, stationID)
	local succes = WorkerManager.Assign(player, workerID, stationID)
	return succes
end

UnAssignfunction.OnServerInvoke = function(player, workerID, stationID)
	WorkerManager.UnAssign(player, workerID)
end


Firefunction.OnServerInvoke = function(player, workerID)
	WorkerManager.Fire(player, workerID)
end
