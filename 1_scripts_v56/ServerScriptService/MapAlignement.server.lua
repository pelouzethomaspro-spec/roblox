--[[ MapAlignement (Script, ServerScriptService) — recale le jeu sur la map V17 importee.
	La map est construite autour de (0, 0, 0) mais l'import 3D de Studio peut la decaler. Comme InstallerMap, on mesure
	le decalage sur la dalle de reference "Sol_Herbe_0_0" et on l'applique a tout ce qui est place en coordonnees de map :
	les 8 plots (Workspace/PlotSpawns : PlotCenter, apparition, camera, noeuds des voitures) et les trajets des voitures
	d'ambiance (attribut Workspace.DecalageMap lu par CarAmbiance). Sans la map (pas encore importee), rien ne bouge et
	le sol plat provisoire reste en place pour pouvoir tester.
]]
-- position attendue de Sol_Herbe_0_0 : celle de la map installee (ServerStorage/DonneesArbres.reference), jamais une
-- valeur figee (V17 : -1011.22 ; V17m : -1007.74 -- la valeur figee decalait tous les plots et trajets de 3,48 studs)
local REFERENCE = Vector3.new(-1007.74, 0, 1007.74)
do
	local ok, D = pcall(function() return require(game:GetService("ServerStorage"):WaitForChild("DonneesArbres", 10)) end)
	if ok and type(D) == "table" and D.reference and typeof(D.reference.position) == "Vector3" then
		REFERENCE = D.reference.position
	else
		warn("[Map] DonneesArbres.reference introuvable : reference par defaut " .. tostring(REFERENCE))
	end
end

local function trouverReference()
	for _, enfant in ipairs(workspace:GetChildren()) do
		if enfant:IsA("Model") or enfant:IsA("Folder") then
			for _, d in ipairs(enfant:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Sol_Herbe_0_0", 1, true) then return d end
			end
		end
	end
end

local ref = trouverReference()
local solProvisoire = workspace:FindFirstChild("SolProvisoire")
if not ref then
	warn("[Map] map V17 non importee : sol plat provisoire conserve (Accueil > Importer 3D > MAP_MOTIFS_V17_AVEC_CHAINES.fbx puis ARBRES_V17.fbx)")
	workspace:SetAttribute("DecalageMap", Vector3.zero)
	return
end
if solProvisoire then solProvisoire:Destroy() end
-- reperes de debug d'InstallerMap (zones orange des plots) : inutiles, le jeu a sa propre grille
local zones = workspace:FindFirstChild("PlotZones")
if zones then zones:Destroy() end

local decalage = ref.Position - REFERENCE
decalage = Vector3.new(decalage.X, 0, decalage.Z)          -- la map est posee a Y = 0 : on ne recale qu'a l'horizontale
workspace:SetAttribute("DecalageMap", decalage)
if decalage.Magnitude < 0.05 then
	print("[Map] map V17 en place, aucun decalage")
	return
end

local plots = workspace:FindFirstChild("PlotSpawns")
if plots then
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:IsA("Model") and not plot:GetAttribute("Recale") then
			plot:PivotTo(plot:GetPivot() + decalage)
			plot:SetAttribute("Recale", true)
		end
	end
end
print(("[Map] decalage de l'import applique aux plots : %s"):format(tostring(decalage)))
