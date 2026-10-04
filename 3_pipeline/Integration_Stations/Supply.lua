local joueur = game.Players.LocalPlayer
local PlayerScripts = joueur:WaitForChild("PlayerScripts")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientData = require(PlayerScripts:WaitForChild("ClientData"))
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))
local ClientSupply = require(PlayerScripts:WaitForChild("ClientSupply"))

local MenuSupply = script.Parent

local item = nil

local function GenererImage3D(bouton)

	local cible = bouton:FindFirstChild("ImageLabel")
	if not cible then return end
	cible.ImageTransparency = 1

	local ancien = cible:FindFirstChildOfClass("ViewportFrame")
	if ancien then ancien:Destroy() end

	local modele = ReplicatedStorage.Products:FindFirstChild(bouton.Name)
	if not modele then return end

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.5)
	viewport.Parent = cible

	local clone = modele:Clone()
	clone.Parent = viewport
	clone.CFrame = CFrame.new(0, 0, 0)

	local cf, taille = clone.CFrame, clone.Size  
	local distance = math.max(taille.X, taille.Y, taille.Z) * 1

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	camera.CFrame = CFrame.lookAt(
		cf.Position + Vector3.new(distance * 0.5, distance * 0.4, -distance),
		cf.Position
	)
end

local function ChangeButtonColor(boutonchoisi)	
	for _, bouton in pairs(MenuSupply:WaitForChild("Center"):GetChildren()) do
		if bouton:IsA("TextButton") then
			bouton.BackgroundColor3 = Color3.fromRGB(225, 226, 234)	
		end
	end
	ClientSupply.DestroyUIStations()
	boutonchoisi.BackgroundColor3 = Color3.fromRGB(235,113,12)
end

local function ResetButtonColor()
	for _, bouton in pairs(MenuSupply:WaitForChild("Center"):GetChildren()) do
		if bouton:IsA("TextButton") then
			bouton.BackgroundColor3 = Color3.fromRGB(225, 226, 234)	
		end
	end
end

local function Update()
	for _, bouton in pairs(MenuSupply:WaitForChild("Center"):GetChildren()) do
		if bouton:IsA("TextButton") or bouton:IsA("ImageButton") then
			
			GenererImage3D(bouton)
			local inventaire = ClientData.Data.Inventory or {}
			bouton.Stock.Text = `Stock: {inventaire[bouton.Name] or 0}`
		end
	end
end

MenuSupply:GetPropertyChangedSignal("Visible"):Connect(function()

	if MenuSupply.Visible == true then
		Update()
	else
		item = nil
		ResetButtonColor()
		MenuSupply:WaitForChild("Right"):WaitForChild("Type").Visible = false
		ClientSupply.DestroyUIStations()
	end

end)

for _, bouton in pairs(MenuSupply:WaitForChild("Center"):GetChildren()) do
	if bouton:IsA("TextButton") or bouton:IsA("ImageButton") then

		bouton.Activated:Connect(function()
			ChangeButtonColor(bouton)
			item = bouton.Name
			ClientSupply.CreateUIStations(item, Update)
			-- famille du produit d'apres le catalogue (Lavage, Energie, Pneus, Peinture, Vitres...)
			local infos = Catalogue.GetInfo("Consommable", item)
			local typeLabel = MenuSupply:WaitForChild("Right"):WaitForChild("Type")
			typeLabel.Text = "Type : " .. ((infos and infos.Type) or "?")
			typeLabel.Visible = true
		end)
	end
end