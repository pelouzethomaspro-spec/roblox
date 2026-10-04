local joueur = game.Players.LocalPlayer
local PlayerScripts = joueur:WaitForChild("PlayerScripts")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientBuild = require(PlayerScripts:WaitForChild("ClientBuild"))
local ActionManager = require(PlayerScripts:WaitForChild("ActionManager"))
local ClientCamera = require(PlayerScripts:WaitForChild("ClientCamera"))   -- camera libre pendant la construction

local MenuBuilding = script.Parent
local modeActuel = "Furniture"

local TemplateBouton = script:WaitForChild("TemplateBouton") 
local Delete = MenuBuilding:WaitForChild("Top"):WaitForChild("Delete")

local function ChangeButtonColor(boutonchoisi, frame)
	for _, bouton in pairs(MenuBuilding:WaitForChild(frame):GetChildren()) do
		if bouton:IsA("TextButton") then
			bouton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)	
			if bouton:FindFirstChild("ImageLabel") then
				bouton.ImageLabel.ImageColor3 = Color3.fromRGB(109, 109, 109)
			end
		end
	end

	boutonchoisi.BackgroundColor3 = Color3.fromRGB(235,113,12)
	if boutonchoisi:FindFirstChild("ImageLabel") then
		boutonchoisi.ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function ResetButtonColor()
	for _, bouton in pairs(MenuBuilding:WaitForChild("Center"):GetChildren()) do
		if bouton:IsA("TextButton") then
			bouton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)	
			if bouton:FindFirstChild("ImageLabel") then
				bouton.ImageLabel.ImageColor3 = Color3.fromRGB(109, 109, 109)
			end
		end
	end
end

local function GenererImage3D(bouton, categorie)
	local dossier = ReplicatedStorage:FindFirstChild(categorie)
	if not dossier then return end

	local modele = dossier:FindFirstChild(bouton.name)
	if not modele then return end

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Parent = bouton

	local clone = modele:Clone()
	clone.Parent = viewport

	local camera = Instance.new("Camera")
	viewport.CurrentCamera = camera
	camera.Parent = viewport

	local cframe, size = clone:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.5 
	camera.CFrame = CFrame.new(cframe.Position + Vector3.new(distance, distance * 0.5, distance), cframe.Position)
end

local function ChangeCategorie(categorie)

	for _, bouton in pairs(MenuBuilding:WaitForChild("Center"):GetChildren()) do
		if bouton:IsA("TextButton") then 
			bouton:Destroy() 
		end
	end

	local dossier = ReplicatedStorage:FindFirstChild(categorie)
	if not dossier then return end

	for _, objet3D in pairs(dossier:GetChildren()) do

		local newbouton = TemplateBouton:Clone()
		newbouton.Name = objet3D.Name
		newbouton.Parent = MenuBuilding:WaitForChild("Center")
		GenererImage3D(newbouton, categorie)
		newbouton.Activated:Connect(function()
			ChangeButtonColor(newbouton, "Center")
			ActionManager.ChangerMode("Construction", newbouton.Name)

			if ActionManager.ModeActuel == "Aucun" then
				ResetButtonColor()
				ClientBuild.DestroyPhantom()
				return 
			end

			ClientBuild.CreatePhantom(newbouton.Name, categorie, 0)
		end)

	end
end

for _, bouton in pairs(MenuBuilding:WaitForChild("Left"):GetChildren()) do
	if bouton:IsA("TextButton") or bouton:IsA("ImageButton") then

		bouton.Activated:Connect(function()
			ChangeButtonColor(bouton, "Left")
			ResetButtonColor()

			if bouton.Name == "Floor" then modeActuel = "Sol"
			elseif bouton.Name == "Wall" then modeActuel = "Mur"
			elseif bouton.Name == "Furniture" then modeActuel = "Furniture"
			elseif bouton.Name == "Roof" then modeActuel = "Plafond"
			end

			ActionManager.ChangerMode("Aucun")
			ClientBuild.DestroyPhantom()
			ChangeCategorie(modeActuel)
		end)
	end
end

Delete.Activated:Connect(function()
	ClientBuild.CreateLaser()
end)

MenuBuilding:GetPropertyChangedSignal("Visible"):Connect(function()
	if MenuBuilding.Visible == true then
		ClientCamera.Activer()                 -- vue plongeante deplacable au clavier
		ClientBuild.CreateExtension()
		ChangeCategorie("Furniture")
	else
		ActionManager.ChangerMode("Aucun")
		ClientBuild.DestroyPhantom()
		ClientBuild.DestroyExtension()
		ClientBuild.DestroyLaser()
		ClientCamera.Desactiver()              -- retour a la camera du personnage
	end
end)