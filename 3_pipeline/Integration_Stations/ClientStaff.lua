local ClientStaff = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientData = require(script.Parent:WaitForChild("ClientData"))
local TemplateUI = ReplicatedStorage:WaitForChild("TemplateUIStaff")
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))
local Folder = workspace.Plots:WaitForChild(game.Players.LocalPlayer.Name .. "'s plot")

local UIStations = nil
local UICaisses = nil

-- ======================================================================================================================
-- GESTION DES STATIONS
-- ======================================================================================================================

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

function ClientStaff.CreateUIStations(workerID,Update)
	ClientStaff.DestroyUIStations()

	local Stations = ClientData.Data.Stations
	if not Stations then return end
	UIStations = Instance.new("Folder")
	UIStations.Name = "UIStations"
	UIStations.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")


	for furnitureID, station in pairs(Stations) do
		for _, objet in pairs(Folder:GetDescendants()) do

			if objet:IsA("Model") and objet:GetAttribute("FurnitureID") == furnitureID then
				
				if station.Worker == "Automatic" then
					break
				end
				
				local UI = TemplateUI:Clone()
				UI.Parent = UIStations
				ancrer(UI, objet, UIStations, 8)
				
				if station.Worker ~= nil then 
					UI.Frame.ID.Text = station.Worker
					UI.Frame.SurName.Text = ClientData.Data.Workers[station.Worker].Name
				else
					UI.Frame.ID.Text = "ID: XxXxXXxx"
					UI.Frame.SurName.Text = "Empty"
				end

				local bouton = UI.Frame:FindFirstChild("Button")
				bouton.Activated:Connect(function()
					if not workerID then return end
					local succes = game.ReplicatedStorage:WaitForChild("Assignfunction"):InvokeServer(workerID ,furnitureID)
					if succes then 
						ClientStaff.DestroyUIStations(workerID)
						Update()
					end
				end)
				break 
			end
		end
	end
end

function ClientStaff.DestroyUIStations()
	if UIStations then
		UIStations:Destroy()
		UIStations = nil
	end
end

-- ======================================================================================================================
-- GESTION DES CAISSES
-- ======================================================================================================================
function ClientStaff.CreateUICaisses(workerID,Update)
	ClientStaff.DestroyUICaisses()

	local Caisses = ClientData.Data.Caisses
	if not Caisses then return end
	UICaisses = Instance.new("Folder")
	UICaisses.Name = "UICaisses"
	UICaisses.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")


	for furnitureID, caisse in pairs(Caisses) do
		for _, objet in pairs(Folder:GetDescendants()) do

			if objet:IsA("Model") and objet:GetAttribute("FurnitureID") == furnitureID then

				if caisse.Worker == "Automatic" then
					break
				end

				local UI = TemplateUI:Clone()
				UI.Parent = UICaisses
				ancrer(UI, objet, UICaisses, 6)

				if caisse.Worker ~= nil then 
					UI.Frame.ID.Text = caisse.Worker
					UI.Frame.SurName.Text = ClientData.Data.Workers[caisse.Worker].Name
				else
					UI.Frame.ID.Text = "ID: XxXxXXxx"
					UI.Frame.SurName.Text = "Empty"
				end

				local bouton = UI.Frame:FindFirstChild("Button")
				bouton.Activated:Connect(function()
					if not workerID then return end
					local succes = game.ReplicatedStorage:WaitForChild("Assignfunction"):InvokeServer(workerID ,furnitureID)
					if succes then
						ClientStaff.DestroyUICaisses(workerID)
						Update()
					end
				end)
				break 
			end
		end
	end
end

function ClientStaff.DestroyUICaisses()
	if UICaisses then
		UICaisses:Destroy()
		UICaisses = nil
	end
end

-- ======================================================================================================================
-- GARAGE (logisticien) : un seul panneau, au rideau du garage de l'atelier (attribut GaragePorte du joueur, pose par
-- Livraison cote serveur) ; la camera y est amenee un instant pour que le joueur voie ou c'est
-- ======================================================================================================================
local UIGarage = nil
local cameraGarage = nil
function ClientStaff.CreateUIGarage(workerID, Update)
	ClientStaff.DestroyUIGarage()
	local joueur = game.Players.LocalPlayer
	local porte = joueur:GetAttribute("GaragePorte")
	if typeof(porte) ~= "Vector3" then return end
	UIGarage = Instance.new("Folder"); UIGarage.Name = "UIGarage"; UIGarage.Parent = joueur:WaitForChild("PlayerGui")
	local ancre = Instance.new("Part"); ancre.Name = "AncreUI"; ancre.Size = Vector3.new(1, 1, 1); ancre.Transparency = 1; ancre.Anchored = true
	ancre.CanCollide = false; ancre.CanQuery = false; ancre.CanTouch = false; ancre.CFrame = CFrame.new(porte + Vector3.new(0, 24, 0)); ancre.Parent = UIGarage
	local UI = TemplateUI:Clone(); UI.Adornee = ancre; UI.MaxDistance = 2000; UI.Parent = UIGarage
	local G = ClientData.Data and ClientData.Data.Garage and ClientData.Data.Garage.Garage
	if G and G.Worker and ClientData.Data.Workers[G.Worker] then
		UI.Frame.ID.Text = G.Worker; UI.Frame.SurName.Text = ClientData.Data.Workers[G.Worker].Name
	else
		UI.Frame.ID.Text = "Garage " .. tostring(joueur:GetAttribute("Garage") or ""); UI.Frame.SurName.Text = "Empty"
	end
	-- fleche / balise bien visible au-dessus du garage
	local balise = Instance.new("Part"); balise.Name = "Balise"; balise.Shape = Enum.PartType.Ball; balise.Size = Vector3.new(6, 6, 6); balise.Material = Enum.Material.Neon
	balise.Color = Color3.fromRGB(255, 140, 30); balise.Anchored = true; balise.CanCollide = false; balise.CanQuery = false; balise.CanTouch = false; balise.Transparency = 0.35
	balise.CFrame = CFrame.new(porte + Vector3.new(0, 30, 0)); balise.Parent = UIGarage
	local bouton = UI.Frame:FindFirstChild("Button")
	bouton.Activated:Connect(function()
		if not workerID then return end
		local succes = game.ReplicatedStorage:WaitForChild("Assignfunction"):InvokeServer(workerID, "Garage")
		if succes then
			ClientStaff.DestroyUIGarage()
			Update()
		end
	end)
	-- on montre ou est le garage : la camera y va et y reste tant que le panneau est ouvert (clic sur le panneau,
	-- fermeture du menu Personnel ou Echap : la camera revient sur le personnage)
	task.spawn(function()
		local cam = workspace.CurrentCamera
		local avantType = cam.CameraType
		cameraGarage = {type = avantType ~= Enum.CameraType.Scriptable and avantType or Enum.CameraType.Custom}
		cam.CameraType = Enum.CameraType.Scriptable
		local vise = porte + Vector3.new(0, 8, 0)
		local depuis = cam.CFrame.Position
		local cible = CFrame.lookAt(porte + Vector3.new(0, 60, 0) + (Vector3.new(depuis.X, 0, depuis.Z) - Vector3.new(porte.X, 0, porte.Z)).Unit * 80, vise)
		local tw = game:GetService("TweenService"):Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = cible})
		tw:Play()
	end)
end

function ClientStaff.DestroyUIGarage()
	if UIGarage then
		UIGarage:Destroy()
		UIGarage = nil
	end
	if cameraGarage then
		local cam = workspace.CurrentCamera
		cam.CameraType = cameraGarage.type or Enum.CameraType.Custom
		local perso = game.Players.LocalPlayer.Character
		if perso then cam.CameraSubject = perso:FindFirstChildOfClass("Humanoid") end
		cameraGarage = nil
	end
end

return ClientStaff