local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

local StoreManager = {}

-- =====================================================================
-- GESTION DU VOLUME
-- =====================================================================
function StoreManager.GetCurrentVolume(player: Player)
	local data = PlayerData.GetData(player)
	if not data or not data.Inventory then return 0 end

	local total = 0
	for itemID, quantity in pairs(data.Inventory) do
		local infos = Catalogue.GetInfo("Consommable", itemID)
		if infos and infos.Volume then
			total += (infos.Volume * quantity)
		end
	end

	return total
end

function StoreManager.GetMaxVolume(player: Player)
	local grid = PlayerData.GetGrid(player)
	if not grid then return 0 end

	local max = 0
	local base = 600            -- v49 : 600 L de base (24 cartons de 25 L) au lieu de 50 : on pouvait commander 2 produits en tout

	for x = 1, #grid do
		for z = 1, #grid[x] do
			local furnitureName = grid[x][z].Furniture
			if furnitureName ~= 0 then
				local rawID = grid[x][z].FurnitureID

				if type(rawID) == "string" and string.sub(rawID, 1, 1) == "C" and string.sub(rawID, 3, 3) == "_" then
					local infos = Catalogue.GetInfo("Furniture", furnitureName)

					if infos and infos.Stockage then
						max += infos.Stockage
					end
				end
			end
		end
	end

	return max + base
end

-- =====================================================================
-- GESTION DES CONSOMMABLES
-- =====================================================================
function StoreManager.BuyConsumable(player: Player, itemID: string, quantite: number)
	
	if type(quantite) ~= "number" then return false end
	quantite = math.floor(quantite)
	if quantite <= 0 then return false end
	
	local infos = Catalogue.GetInfo("Consommable", itemID)
	if not infos then return false end

	local prix = infos.Buy * quantite
	local volumeAchat = infos.Volume * quantite

	local argent = PlayerData.GetMoney(player)
	if argent < prix then return false end

	local volumeActuel = StoreManager.GetCurrentVolume(player)
	local volumeMax = StoreManager.GetMaxVolume(player)
	if (volumeActuel + volumeAchat) > volumeMax then return false end

	PlayerData.SpendMoney(player, prix)
	PlayerData.AddItem(player, itemID, quantite)

	return true
end

-- =========================================================
-- GESTION DES STATIONS
-- =========================================================

function StoreManager.FillStation(player: Player, furnitureID: string, itemID: string)
	local data = PlayerData.GetData(player)
	if not data or not data.Stations or not data.Stations[furnitureID] then
		print("pas de station")
		return false
	end

	if not data.Inventory or not data.Inventory[itemID] or data.Inventory[itemID] <= 0 then
		print("pas d'item")
		return false
	end

	local station = data.Stations[furnitureID]
	local infosstation = Catalogue.GetInfo("Furniture", station.Name)
	if not infosstation or not infosstation.Capacity then
		print("pas de capa")
		return false
	end
	local capacity = infosstation.Capacity
	
	local infositem = Catalogue.GetInfo("Consommable", itemID)
	if not infositem or not infositem.Volume then return false end
	local itemVolume = infositem.Volume
	
	if station.Item ~= nil and station.Item ~= itemID and station.Quantity > 0 then
		PlayerData.AddItem(player, station.Item, station.Quantity)
		PlayerData.EmptyStation(player, furnitureID)
		station = data.Stations[furnitureID]
	end
	
	
	
	local maxitem = math.floor(capacity / itemVolume)
	if maxitem - station.Quantity <= 0 then
		return false
	end
	
	local amount = math.min(data.Inventory[itemID], maxitem - station.Quantity)
	PlayerData.RemoveItem(player, itemID, amount)
	PlayerData.FillStation(player, furnitureID, itemID, amount)

	return true, amount
end

return StoreManager