local WorkerManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local Catalogue = require(ReplicatedStorage:WaitForChild("Catalogue"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local Actif = {}

local Names = {"Bob", "Kevin", "Sarah", "Michel", "Emma", "Jean", "Alice", "Cirly"}

-- ======================================================================================================================
-- UNIFORME : polo et casquette aux couleurs de la station (employe de station en bleu, caissier en vert), pantalon
-- sombre, bras et tete couleur peau, badge "ST" sur la casquette, petit nom au-dessus de la tete.
-- Les modeles AttendantTemplate / CashierTemplate sont des personnages R6 en briques : tout est fait par couleurs et
-- quelques pieces soudees, sans aucun asset a importer.
-- ======================================================================================================================
local UNIFORMES = {
	Attendant = { polo = Color3.fromRGB(37, 99, 235),  casquette = Color3.fromRGB(37, 99, 235),  visiere = Color3.fromRGB(245, 247, 250), role = "Employe" },
	Cashier   = { polo = Color3.fromRGB(23, 143, 85),  casquette = Color3.fromRGB(23, 143, 85),  visiere = Color3.fromRGB(245, 247, 250), role = "Caissier" },
	Logistician = { polo = Color3.fromRGB(232, 120, 24), casquette = Color3.fromRGB(232, 120, 24), visiere = Color3.fromRGB(245, 247, 250), role = "Logisticien" },
}
local SALAIRES = { Attendant = 12, Cashier = 7, Logistician = 10 }     -- $/min
-- le logisticien : affecte au garage de l'atelier (Livraison), il va chercher les cartons du van tout seul.
-- Son "meuble" est data.Garage.Garage (categorie "Garage", id "Garage") ; son poste = attribut GaragePoste du joueur (CFrame)
local function categorieDe(workertype)
	if workertype == "Attendant" then return "Stations" elseif workertype == "Cashier" then return "Caisses" elseif workertype == "Logistician" then return "Garage" end
	return nil
end
local function posteGarage(player)
	local cf = player:GetAttribute("GaragePoste")
	if typeof(cf) == "CFrame" then return cf end
	return nil
end
local function garantirGarage(data)
	if type(data.Garage) ~= "table" then data.Garage = {} end
	if type(data.Garage.Garage) ~= "table" then data.Garage.Garage = {Worker = nil} end
end
local PEAU = { Color3.fromRGB(234, 192, 158), Color3.fromRGB(204, 142, 105), Color3.fromRGB(150, 95, 62), Color3.fromRGB(110, 70, 45), Color3.fromRGB(245, 215, 190) }
local PANTALON = Color3.fromRGB(38, 44, 56)
local CHAUSSURES = Color3.fromRGB(20, 20, 24)

local function piece(nom, taille, cf, couleur, materiau, parent)
	local p = Instance.new("Part")
	p.Name = nom; p.Size = taille; p.CFrame = cf; p.Color = couleur
	p.Material = materiau or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true; p.CastShadow = false
	p.Parent = parent
	return p
end

local function souder(a, b)
	local w = Instance.new("WeldConstraint"); w.Part0 = a; w.Part1 = b; w.Parent = a
end

local function Uniforme(dummy, workertype, nom)
	local U = UNIFORMES[workertype] or UNIFORMES.Attendant
	local peau = PEAU[math.random(1, #PEAU)]
	local tete = dummy:FindFirstChild("Head")
	for _, p in ipairs(dummy:GetChildren()) do
		if p:IsA("BasePart") then
			local n = p.Name
			if n == "Torso" or n == "UpperTorso" or n == "LowerTorso" then p.Color = U.polo
			elseif n:find("Leg") or n:find("Foot") then p.Color = (n:find("Foot") and CHAUSSURES) or PANTALON
			elseif n:find("Arm") or n:find("Hand") or n == "Head" then p.Color = peau end
			if n ~= "HumanoidRootPart" then p.Material = Enum.Material.SmoothPlastic end
		end
	end
	for _, v in ipairs({"Shirt", "Pants", "ShirtGraphic"}) do local x = dummy:FindFirstChildOfClass(v); if x then x:Destroy() end end
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum.DisplayName = nom or ""; hum.NameDisplayDistance = 0; hum.HealthDisplayDistance = 0 end) end
	local bc = dummy:FindFirstChildOfClass("BodyColors")
	if bc then bc.TorsoColor3 = U.polo; bc.LeftArmColor3 = peau; bc.RightArmColor3 = peau; bc.HeadColor3 = peau; bc.LeftLegColor3 = PANTALON; bc.RightLegColor3 = PANTALON end
	if not tete then return end
	-- casquette : calotte (demi-sphere aplatie) + visiere, aux dimensions de la tete
	local h = tete.Size
	local e = math.max(h.X, h.Z) * 0.62                       -- diametre de la calotte (la tete R6 fait 2 x 1 x 1 avec un mesh a 1,25)
	local casquette = Instance.new("Model"); casquette.Name = "Casquette"; casquette.Parent = dummy
	-- calotte : ellipsoide qui coiffe le haut de la tete (deborde de ~0,1 stud tout autour)
	local calotte = piece("Calotte", Vector3.new(e * 1.14, e * 0.5, e * 1.14), tete.CFrame * CFrame.new(0, h.Y * 0.56, -0.02), U.casquette, Enum.Material.Fabric, casquette)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Scale = Vector3.new(1, 1, 1); mesh.Parent = calotte
	-- bande : cylindre (axe X -> vertical) autour du haut de la tete, plus large que la tete pour etre bien visible
	local bande = piece("Bande", Vector3.new(e * 0.16, e * 1.18, e * 1.18), tete.CFrame * CFrame.new(0, h.Y * 0.50, -0.02) * CFrame.Angles(0, 0, math.rad(90)), U.casquette, Enum.Material.Fabric, casquette)
	local meshB = Instance.new("SpecialMesh"); meshB.MeshType = Enum.MeshType.Cylinder; meshB.Parent = bande
	-- visiere : plaque fine devant, legerement inclinee vers le bas
	local visiere = piece("Visiere", Vector3.new(e * 1.0, 0.08, e * 0.6), tete.CFrame * CFrame.new(0, h.Y * 0.44, -e * 0.62 - 0.1) * CFrame.Angles(math.rad(-8), 0, 0), U.visiere, Enum.Material.SmoothPlastic, casquette)
	local bouton = piece("Bouton", Vector3.new(0.16, 0.16, 0.16), tete.CFrame * CFrame.new(0, h.Y * 0.56 + e * 0.25, -0.02), U.visiere, Enum.Material.SmoothPlastic, casquette)
	local meshC = Instance.new("SpecialMesh"); meshC.MeshType = Enum.MeshType.Sphere; meshC.Parent = bouton
	for _, p in ipairs({calotte, bande, visiere, bouton}) do souder(tete, p) end
	-- logo "ST" sur le devant de la calotte
	local plaque = piece("Logo", Vector3.new(e * 0.42, e * 0.14, 0.05), tete.CFrame * CFrame.new(0, h.Y * 0.50, -0.02 - e * 0.59 - 0.02), U.casquette, Enum.Material.Fabric, casquette)
	souder(tete, plaque)
	local gui = Instance.new("SurfaceGui"); gui.Face = Enum.NormalId.Front; gui.CanvasSize = Vector2.new(200, 120); gui.LightInfluence = 1; gui.Parent = plaque
	local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1; t.Text = "ST"; t.TextScaled = true
	t.TextColor3 = U.visiere; t.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold); t.Parent = gui
	-- nom et role au-dessus de la tete
	if nom then
		local bb = Instance.new("BillboardGui"); bb.Name = "Nom"; bb.Size = UDim2.fromOffset(120, 34); bb.StudsOffset = Vector3.new(0, h.Y * 1.3 + 0.6, 0)
		bb.AlwaysOnTop = false; bb.MaxDistance = 90; bb.Adornee = tete; bb.Parent = tete
		local l = Instance.new("TextLabel"); l.Size = UDim2.fromScale(1, 1); l.BackgroundTransparency = 1; l.TextScaled = true
		l.Text = nom .. "  ·  " .. U.role; l.TextColor3 = Color3.new(1, 1, 1); l.TextStrokeTransparency = 0.4
		l.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold); l.Parent = bb
	end
end
WorkerManager.Uniforme = Uniforme

function WorkerManager.Start(player : Player, Folder: Folder)
	
	local Folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not Folder then return false end

	local Workers = PlayerData.GetWorker(player)
	Actif[player.UserId] = true
	
	for workerID, workerdata in pairs(Workers) do
		
		local template = nil
		if workerdata.Type == "Attendant" or workerdata.Type == "Logistician" then
			template = ReplicatedStorage:FindFirstChild("AttendantTemplate")
		elseif workerdata.Type == "Cashier" then
			template = ReplicatedStorage:FindFirstChild("CashierTemplate")
		end
		if not template then continue end

		local dummy = template:Clone()
		dummy.Name = workerID
		Uniforme(dummy, workerdata.Type, workerdata.Name)
		dummy.Parent = Folder	
		dummy.PrimaryPart.Anchored = true
		local destination = Folder.PlotCenterRef.Value		
		local cibleID = workerdata.Furniture

		if cibleID == "Garage" and workerdata.Type == "Logistician" then
			local poste = posteGarage(player)
			if poste then dummy:PivotTo(poste * CFrame.new(0, 3.616, 0)) else dummy:PivotTo(destination:GetPivot() * CFrame.new(0, 5, 0)) end
			continue
		end
		if cibleID then
			for _, objet in ipairs(Folder:GetDescendants()) do
				if objet:GetAttribute("FurnitureID") == cibleID then
					destination = objet
					break
				end
			end
		end

		local offset = CFrame.new(3, 3.616, 10.5) * CFrame.Angles(0, math.rad(90), 0)
		dummy:PivotTo(destination:GetPivot() * offset)
		
		
	end
	

	task.spawn(function()
		while Actif[player.UserId] do
			task.wait(60)
			if not Actif[player.UserId] then break end

			local Workers = PlayerData.GetWorker(player)
			if not Workers then break end

			for workerID, workerdata in pairs(Workers) do
				PlayerData.SpendMoney(player, SALAIRES[workerdata.Type] or 10)
			end
		end
	end)
end

function WorkerManager.Hire(player: Player, workertype: string)
	
	local Folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not Folder then return false end

	if workertype ~= "Attendant" and workertype ~= "Cashier" and workertype ~= "Logistician" then
		return
	end
	
	local workerID = HttpService:GenerateGUID(false)
	
	local template = nil
	if workertype == "Attendant" or workertype == "Logistician" then
		template = ReplicatedStorage:FindFirstChild("AttendantTemplate")
	elseif workertype == "Cashier" then
		template = ReplicatedStorage:FindFirstChild("CashierTemplate")
	end

	local workername = Names[math.random(1, #Names)]
		
	if template then
			local dummy = template:Clone()
			dummy.Name = workerID
			Uniforme(dummy, workertype, workername)
			dummy.Parent = Folder
			dummy:PivotTo(Folder.PlotCenterRef.Value:GetPivot() * CFrame.new(0, 5, 0))
	end		
		PlayerData.InitWorker(player, workerID, workertype, workername)
end

function WorkerManager.Assign(player: Player, workerID: string, furnitureID: string)
	local Folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not Folder then return false end
	
	local data = PlayerData.GetData(player)

	if not data or not data.Workers or not data.Workers[workerID] then
		return false
	end

	local worker = data.Workers[workerID]

	local category = categorieDe(worker.Type)
	if not category then return false end
	if category == "Garage" then
		if furnitureID ~= "Garage" then return false end
		garantirGarage(data)
	end

	if not data[category] or not data[category][furnitureID] then
		return false
	end

	local furniture = data[category][furnitureID]

	if furniture.Worker ~= nil and furniture.Worker ~= "Automatic" then
		PlayerData.FireWorker(player, furnitureID, category)
		furniture = data[category][furnitureID]
	end
	if worker.Station then
		PlayerData.FireWorker(player, worker.Station, "Stations")
	end
	if worker.Caisse then
		PlayerData.FireWorker(player, worker.Caisse, "Caisses")
	end
	
	PlayerData.AssignWorker(player, workerID, furnitureID, category)

	local worker3D = Folder:FindFirstChild(workerID)
	local furniture3D = nil
	if category == "Garage" then
		local poste = posteGarage(player)
		if worker3D and poste then worker3D:PivotTo(poste * CFrame.new(0, 3.616, 0)) end
		-- des cartons deja au sol ? il y va tout de suite
		task.delay(1, function()
			local ok, Livraison = pcall(function() return require(ServerScriptService:WaitForChild("Livraison")) end)
			if ok and Livraison.LogisticienRecupere then
				local S = Livraison.SessionDe and Livraison.SessionDe(player)
				if S and S.Cartons then Livraison.LogisticienRecupere(player, S) end
			end
		end)
		return true
	end

	for _, objet in ipairs(Folder:GetDescendants()) do
		if objet:GetAttribute("FurnitureID") == furnitureID then
			furniture3D = objet
			break
		end
	end

	if worker3D and furniture3D then
		local offset = CFrame.new(3, 3.616, 10.5) * CFrame.Angles(0, math.rad(90), 0)
		worker3D:PivotTo(furniture3D:GetPivot() * offset)

	end

	return true
end

function WorkerManager.UnAssign(player: Player, workerID: string)
	local Folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not Folder then return false end

	local data = PlayerData.GetData(player)

	if not data or not data.Workers or not data.Workers[workerID] then
		return false
	end

	local worker = data.Workers[workerID]

	local category = categorieDe(worker.Type)
	if not category then return false end

	if worker.Furniture then
		PlayerData.FireWorker(player, worker.Furniture, category)
	end
	
	return true
end

function WorkerManager.Fire(player: Player, workerID: string)
	local Folder = workspace.Plots:FindFirstChild(player.Name .. "'s plot")
	if not Folder then return false end

	local data = PlayerData.GetData(player)

	if not data or not data.Workers or not data.Workers[workerID] then
		return false
	end

	local worker = data.Workers[workerID]

	local category = categorieDe(worker.Type)
	if not category then return false end

	if worker.Furniture then
		PlayerData.FireWorker(player, worker.Furniture, category)
	end

	PlayerData.RemoveWorker(player, workerID)

	local worker3D = Folder:FindFirstChild(workerID)
	if worker3D then
		worker3D:Destroy()
	end

	return true
end

function WorkerManager.Stop(player: Player)
	Actif[player.UserId] = nil
end

return WorkerManager