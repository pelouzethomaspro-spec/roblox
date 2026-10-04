ClientSupply = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ClientData = require(script.Parent:WaitForChild("ClientData"))

local TemplateUI = ReplicatedStorage:WaitForChild("TemplateStationUISupply")
local Folder = workspace.Plots:WaitForChild(game.Players.LocalPlayer.Name .. "'s plot")
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))

local UIStations = nil

-- ======================================================================================================================
-- ANCRE D'AFFICHAGE : un panneau 3D (BillboardGui) accroche au PIVOT du meuble, pas a son PrimaryPart.
-- Pour les stations, le PrimaryPart est le "Socle" (origine du repere FBX), qui peut etre a 200 studs de la dalle :
-- le panneau serait hors de vue. On cree une petite piece invisible locale au pivot, detruite avec le dossier d'UI.
-- ======================================================================================================================
local function ancrer(UI, objet, dossier, hauteur)
	local ancre = Instance.new("Part")
	ancre.Name = "AncreUI"
	ancre.Size = Vector3.new(1, 1, 1)
	ancre.Transparency = 1
	ancre.Anchored = true
	ancre.CanCollide = false
	ancre.CanQuery = false
	ancre.CanTouch = false
	ancre.CFrame = objet:GetPivot() * CFrame.new(0, hauteur or 6, 0)
	ancre.Parent = dossier
	UI.Adornee = ancre
end

function ClientSupply.CreateUIStations(newitem,Update)
	ClientSupply.DestroyUIStations()

	local Stations = ClientData.Data.Stations
	if not Stations then return end
	UIStations = Instance.new("Folder")
	UIStations.Name = "UIStations"
	UIStations.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")


	for furnitureID, station in pairs(Stations) do
		for _, objet in pairs(Folder:GetDescendants()) do

			if objet:IsA("Model") and objet:GetAttribute("FurnitureID") == furnitureID then

				local infosstations = Catalogue.GetInfo("Furniture", objet.Name)
				if not table.find(infosstations.Accepted, newitem) then
					break
				end

				local UI = TemplateUI:Clone()
				UI.Parent = UIStations
				ancrer(UI, objet, UIStations, 8)

				local capacity = 0
				if infosstations and infosstations.Capacity then
					capacity = infosstations.Capacity
				end

				local quantity = station.Quantity

				if quantity == 0 then
					UI.Frame.Type.Text = "Item : Empty Station"
					UI.Frame.Quantity.Text = `Volume : 0 / {capacity}L`

				else				
					local infosItem = Catalogue.GetInfo("Consommable", station.Item)
					local itemVolume = (infosItem and infosItem.Volume) or 1
					local maxitems = math.floor(capacity / itemVolume)

					UI.Frame.Type.Text = `Item : {infosItem.Name}`
					UI.Frame.Quantity.Text = `Stock : {quantity} / {maxitems}`
				end




				local bouton = UI.Frame:FindFirstChild("Button")
				bouton.Activated:Connect(function()
					if not newitem then return end
					local succes = game.ReplicatedStorage:WaitForChild("FillStationfunction"):InvokeServer(furnitureID, newitem)
					if succes == true then
						Update()
						ClientSupply.CreateUIStations(newitem)
					else
					end
				end)
				break 
			end
		end
	end
end

function ClientSupply.DestroyUIStations()
	if UIStations then
		UIStations:Destroy()
		UIStations = nil
	end
end

return ClientSupply