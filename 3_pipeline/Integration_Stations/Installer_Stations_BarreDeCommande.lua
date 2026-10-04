--[[ Installer_Stations   (a coller dans la BARRE DE COMMANDE de Studio, une seule fois, dans la place du tycoon)
	Prerequis : tu as deja colle dans cette place, depuis jeux.rbxl :
		- ReplicatedStorage > Stations                    (les modules : Client, Voiture, Donnees, Comportements...)
		- ReplicatedStorage > VoituresModeles             (facultatif : seulement pour les stations de decor en boucle)
		- ReplicatedStorage > AnimationsTest_ASupprimer   (test dans Studio tant que les animations ne sont pas publiees)
		- Workspace > Toutes_Stations_Alignees            (les 11 stations montees)
		- StarterPlayer > StarterPlayerScripts > StationsClient
	Ce script :
		1) supprime les anciens cubes "5", "6", "7", "8" de ReplicatedStorage > Furniture ;
		2) donne a chaque station un pivot compatible avec la grille (coin de la case d'ancrage, comme les cubes) ;
		3) range les 11 stations dans ReplicatedStorage > Furniture (elles apparaissent dans le menu de construction).
	Relancable sans risque.
]]
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
CHS:SetWaypoint("Avant installation des stations")

local dossier = RS:FindFirstChild("Furniture") or error("ReplicatedStorage.Furniture introuvable : es-tu dans la place du tycoon ?")
for _, n in ipairs({"Stations", "AnimationsTest_ASupprimer"}) do
	if not RS:FindFirstChild(n) then warn("Installer : ReplicatedStorage." .. n .. " manque (colle-le depuis jeux.rbxl)") end
end
if not RS.Stations:FindFirstChild("Donnees") then error("ReplicatedStorage.Stations.Donnees introuvable") end

-- 1) anciens cubes
for _, n in ipairs({"5", "6", "7", "8"}) do
	local m = dossier:FindFirstChild(n)
	if m then m:Destroy(); print("Installer : ancien cube supprime : " .. n) end
end

-- emprise au sol des pieces visibles d'un modele (les pieces invisibles Socle / Voiture / Roue_* sont ignorees)
local function emprise(m)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "Socle" and p.Name ~= "Voiture" and not p.Name:match("^Roue_") then
			local cf, h = p.CFrame, p.Size / 2
			for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
				local w = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
				lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
				hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
			end end end
		end
	end
	return lo, hi
end

-- 2) + 3) stations
local n = 0
for _, m in ipairs(CS:GetTagged("Station")) do
	if m:IsA("Model") and m:IsDescendantOf(workspace) and m:FindFirstChild("Socle") then
		local nom = m:GetAttribute("Station") or m.Name
		if not RS.Stations.Donnees:FindFirstChild(nom) then
			warn("Installer : pas de donnees pour la station " .. nom .. " (Stations > Donnees) : ignoree")
		else
			m.Name = nom
			local socle = m.Socle
			local lo, hi = emprise(m)
			local taille = hi - lo
			if math.abs(taille.X - 30) > 1 or math.abs(taille.Z - 25) > 1 then
				warn(("Installer : %s fait %.1f x %.1f studs au sol (attendu 30 x 25) : verifie le masque 3x3"):format(nom, taille.X, taille.Z))
			end
			-- pivot AU CENTRE de l'emprise (Furniture.Pivot = "centre" : la station tourne sur place),
			-- pose au niveau du bas de la dalle (le sol du plot est a +0.5, les meubles sont poses a +0.616)
			local droite = socle.CFrame.RightVector
			droite = Vector3.new(droite.X, 0, droite.Z).Unit
			local centre = Vector3.new((lo.X + hi.X) / 2, lo.Y + 0.1, (lo.Z + hi.Z) / 2)
			local base = CFrame.fromMatrix(centre, droite, Vector3.yAxis)
			m.PrimaryPart = socle
			m.WorldPivot = base
			pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
			m:SetAttribute("Boucle", nil)                      -- dans le tycoon, c'est le serveur qui commande les cycles
			local ancien = dossier:FindFirstChild(nom)
			if ancien and ancien ~= m then ancien:Destroy() end
			m.Parent = dossier
			n += 1
			print(("Installer : %s -> Furniture (emprise %.1f x %.1f, hauteur %.1f)"):format(nom, taille.X, taille.Z, taille.Y))
		end
	end
end

-- nettoyage du modele d'alignement vide
local align = workspace:FindFirstChild("Toutes_Stations_Alignees")
if align and #align:GetChildren() == 0 then align:Destroy() end
if workspace:FindFirstChild("Stations_8") then
	warn("Installer : Workspace.Stations_8 (anciennes copies non montees des stations) peut etre supprime")
end

CHS:SetWaypoint("Stations installees")
print(("Installer : %d station(s) prete(s) dans ReplicatedStorage > Furniture. Etape suivante : coller les scripts modifies."):format(n))
