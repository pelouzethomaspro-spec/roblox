--[[ Appliquer_IDs_v24 — a coller dans la BARRE DE COMMANDES de Roblox Studio (place ouverte, pas en Play).
	Apres l'import des 116 images + 2 sons de l'UI v24 (Contenus -> Importer), Studio donne un identifiant par image.
	1. Remplis la table IDS ci-dessous : nom du fichier (sans .png) -> identifiant (nombre). Les noms attendus sont ceux de
	   2_a_importer/images/ du zip StationTycoon_transfert_v24 (BuildMode_path, Rangs0_00, Shop1_01, Drive30_3, TabActive_Build...).
	   Astuce : Contenus -> onglet Images -> clic droit "Copier l'identifiant" ; ou l'onglet "Gestionnaire d'actifs".
	2. Selectionne tout ce fichier, colle-le dans la barre de commandes, Entree. Le script ecrit les StringValues Src/Sel des
	   ImageLabels de StarterGui (table de correspondance = celle de transfert-roblox.md § 7.1), les 8 planches de la voiture
	   animee (Menu/Choose/Hero/Car/DriveData) et affiche ce qui reste a 0.
	3. Enregistre la place (Ctrl+S) : les identifiants sont dans les StringValues, le UIController les applique au lancement.
	Les emplacements deja remplis (images v23 ou v24 deja importees) ne sont touches que si IDS donne une valeur.
]]
local IDS = {
	-- modes Circulation / Decoration
	BuildMode_path = 0, BuildMode_deco = 0,
	-- pastilles d'onglet actif / inactif
	TabActive_Build = 0, TabActive_Index = 0, TabActive_Staff = 0, TabActive_Station = 0, TabActive_Stock = 0, TabActive_Supply = 0, TabInactive_Supply = 0,
	-- planches des menus
	Staff_01 = 0, Station_00 = 0, Supply_01 = 0,
	-- fenetre Rangs (8 planches x 2 etats)
	Rangs0_00 = 0, Rangs0_01 = 0, Rangs1_00 = 0, Rangs1_01 = 0, Rangs2_00 = 0, Rangs2_01 = 0, Rangs3_00 = 0, Rangs3_01 = 0,
	Rangs4_00 = 0, Rangs4_01 = 0, Rangs5_00 = 0, Rangs5_01 = 0, Rangs6_00 = 0, Rangs6_01 = 0, Rangs7_00 = 0, Rangs7_01 = 0,
	-- shop (3 onglets x 2 etats)
	Shop0_00 = 0, Shop0_01 = 0, Shop1_00 = 0, Shop1_01 = 0, Shop2_00 = 0, Shop2_01 = 0,
	-- voiture animee du menu (8 planches)
	Drive30_0 = 0, Drive30_1 = 0, Drive30_2 = 0, Drive30_3 = 0, Drive30_4 = 0, Drive30_5 = 0, Drive30_6 = 0, Drive30_7 = 0,
}

local SRC = {
	["Loading/Root/Title/T0"] = "LoadTitle_00", ["Loading/Root/Title/T1"] = "LoadTitle_01",
	["Menu/Choose/Tiles/T0"] = "Menu_00", ["Menu/Choose/Tiles/T2"] = "Menu_10",
	["Menu/Choose/NewsDrop/T0"] = "MenuNews_00",
	["Menu/Choose/Hero/Car"] = "Drive30_3",
	["Main/Root/HUD/HUD1/BarArt/Bar0"] = "HUD_00", ["Main/Root/HUD/HUD1/BarArt/Bar1"] = "HUD_01",
	["Main/Root/HUD/HUD1/BarArt/Inactive_Supply"] = "TabInactive_Supply",
	["Main/Root/MENUS/Build/Art/Base/T0"] = "Build_00", ["Main/Root/MENUS/Build/Art/Base/T1"] = "Build_01",
	["Main/Root/MENUS/Staff/Art/Base/T0"] = "Staff_00", ["Main/Root/MENUS/Staff/Art/Base/T1"] = "Staff_01",
	["Main/Root/MENUS/Staff/Art/Assign/T0"] = "StaffAssign_00",
	["Main/Root/MENUS/Stock/Art/Base/T0"] = "Stock_00",
	["Main/Root/MENUS/Supply/Art/Base/T0"] = "Supply_00", ["Main/Root/MENUS/Supply/Art/Base/T1"] = "Supply_01",
	["Main/Root/MENUS/Station/Art/Base/T0"] = "Station_00",
}
for _, t in ipairs({"Build", "Stock", "Supply", "Staff", "Index", "Station"}) do SRC["Main/Root/HUD/HUD1/BarArt/Active_" .. t] = "TabActive_" .. t end
for _, c in ipairs({"sol", "murs", "stations", "utilitaires", "deco", "toit"}) do SRC["Main/Root/MENUS/Build/Art/Variants/V_" .. c .. "/T0"] = "BuildStrip_" .. c .. "_00" end
for _, m in ipairs({"move", "del", "path", "deco"}) do SRC["Main/Root/MENUS/Build/Top/Active_" .. m] = "BuildMode_" .. m end
for i = 1, 9 do
	SRC["Main/Root/MENUS/Stock/Art/Variants/V" .. i .. "/T0"] = "StockR" .. i .. "_00"
	SRC["Main/Root/MENUS/Stock/Art/Center/" .. i] = "StockRow_" .. i
	SRC["Main/Root/MENUS/Supply/Art/Center/" .. i] = "SupplyCard_" .. i
end
for k = 0, 2 do
	SRC["Main/Root/MENUS/Stock/Fams/F" .. k .. "/T0"] = "StockFam" .. k .. "_00"
	SRC["Main/Root/MENUS/Supply/Fams/F" .. k .. "/T0"] = "SupplyFam" .. k .. "_00"
	SRC["Main/Root/MENUS/Shop/Tabs/T" .. k .. "/T0"] = "Shop" .. k .. "_00"; SRC["Main/Root/MENUS/Shop/Tabs/T" .. k .. "/T1"] = "Shop" .. k .. "_01"
end
for k = 0, 7 do SRC["Main/Root/MENUS/Ranks/Sel/S" .. k .. "/T0"] = "Rangs" .. k .. "_00"; SRC["Main/Root/MENUS/Ranks/Sel/S" .. k .. "/T1"] = "Rangs" .. k .. "_01" end
local SEL = {}
for i = 1, 9 do SEL["Main/Root/MENUS/Stock/Art/Center/" .. i] = "StockRowSel_" .. i; SEL["Main/Root/MENUS/Supply/Art/Center/" .. i] = "SupplyCardSel_" .. i end

local StarterGui = game:GetService("StarterGui")
local function trouver(chemin)
	local o = StarterGui
	for part in string.gmatch(chemin, "[^/]+") do o = o and o:FindFirstChild(part) end
	return o
end
local ecrits, restants = 0, {}
local function appliquer(table_, nomValeur)
	for chemin, image in pairs(table_) do
		local o = trouver(chemin)
		local sv = o and o:FindFirstChild(nomValeur)
		if sv and sv:IsA("StringValue") then
			local id = IDS[image]
			if id and id ~= 0 then
				sv.Value = "rbxassetid://" .. tostring(id); ecrits += 1
				if nomValeur == "Src" and o:IsA("ImageLabel") or o:IsA("ImageButton") then o.Image = sv.Value end
			elseif sv.Value == "rbxassetid://0" or sv.Value == "" then
				table.insert(restants, image .. "  (" .. chemin .. ")")
			end
		end
	end
end
appliquer(SRC, "Src"); appliquer(SEL, "Sel")
-- voiture animee du menu : 8 planches
local dd = trouver("Menu/Choose/Hero/Car/DriveData")
if dd and dd:IsA("ModuleScript") then
	local planches = {}
	local ok = true
	for k = 0, 7 do local id = IDS["Drive30_" .. k]; if not id or id == 0 then ok = false end; planches[k + 1] = "rbxassetid://" .. tostring(id or 0) end
	if ok then
		local src = dd.Source
		local nouveau = 'sheets = {"' .. table.concat(planches, '", "') .. '"}'
		local remplace, n = string.gsub(src, "sheets%s*=%s*%b{}", nouveau)
		if n > 0 then dd.Source = remplace; ecrits += 8; print("[IDs v24] DriveData.sheets mis a jour") else warn("[IDs v24] DriveData : champ sheets introuvable, a editer a la main : " .. nouveau) end
	else
		table.insert(restants, "Drive30_0..7 (Menu/Choose/Hero/Car/DriveData : sheets)")
	end
end
print(("[IDs v24] %d identifiants ecrits. Restent a 0 : %d"):format(ecrits, #restants))
for _, r in ipairs(restants) do print("   - " .. r) end
print("[IDs v24] Enregistre la place (Ctrl+S).")
