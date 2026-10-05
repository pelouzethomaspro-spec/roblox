local ClientData = {}
ClientData.Variables = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

local InitialData = ReplicatedStorage:WaitForChild("InitialData")
local UpdateClientData = ReplicatedStorage:WaitForChild("UpdateClientData")

ClientData.OnDataChanged = Instance.new("BindableEvent")
ClientData.Ready = Instance.new("BindableEvent")

-- ======================================================================================================================
-- GESTION DES DONNÉES
-- ======================================================================================================================

InitialData.OnClientEvent:Connect(function(data)
	ClientData.Data = data
	ClientData.Ready:Fire()
end)

UpdateClientData.OnClientEvent:Connect(function(cle, value)
	if not ClientData.Data then return end
	ClientData.Data[cle] = value
	ClientData.OnDataChanged:Fire(cle)
end)

function ClientData.WaitForData()
	if not ClientData.Data then
		ClientData.Ready.Event:Wait()
	end
	return ClientData.Data
end

-- ======================================================================================================================
-- GESTION DES FONCIONS
-- ======================================================================================================================

function ClientData.GetPlotSize(player: Player)
	local currentX = 18          -- v56 : identique a PlayerData (baseX = 18 depuis la v49 ; 20 dessinait 2 colonnes sur le trottoir)
	local currentZ = 11

	if ClientData.Data and ClientData.Data.Extensions then
		local extensions = ClientData.Data.Extensions

		for name, bought in pairs(extensions) do
			if bought then
				local infoExtension = Catalogue.GetInfo("Extension", name)

				if infoExtension then
					currentX = currentX + infoExtension.AddX
					currentZ = currentZ + infoExtension.AddZ
				end
			end
		end
	end

	return currentX, currentZ
end

function ClientData.GetNextExtensions(player: Player)
	local data = ClientData.Data
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

function ClientData.GetCurrentVolume(player: Player)
	local data = ClientData.Data
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

function ClientData.GetMaxVolume(player: Player)
	local grid = ClientData.Data.Grid
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

function ClientData.GetRank()
	local Rank = require(ReplicatedStorage:WaitForChild("Catalogue"):WaitForChild("Rank"))
	local data = ClientData.Data
	if not data then return Rank[1], Rank[2] end

	local xp = data.Xp or 0
	local index = data.Index or {}

	local rang = Rank[1]
	local nextrang = Rank[2]

	for i = 2, #Rank do
		local suivant = Rank[i]

		if xp < suivant.Xp then break end

		local ok = true
		for tier, nombre in pairs(suivant.Requis) do

			local total = 0
			if index[tier] then
				for _, n in pairs(index[tier]) do
					total += n
				end
			end

			if total < nombre then
				ok = false
				break
			end
		end

		if not ok then break end
		rang = suivant
		nextrang = Rank[i + 1]
	end

	return rang, nextrang
end

function ClientData.CountTier(tier: string)
	local data = ClientData.Data
	if not data or not data.Index or not data.Index[tier] then return 0 end

	local total = 0
	for _, n in pairs(data.Index[tier]) do
		total += n
	end
	return total
end

return ClientData