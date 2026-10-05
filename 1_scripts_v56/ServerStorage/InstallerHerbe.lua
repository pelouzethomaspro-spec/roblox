--[[ InstallerHerbe (ModuleScript, ServerStorage) — v49 (map V21) : herbe en relief (Terrain Grass, brins animes) dans les
	8 PLOTS des joueurs. Le reste de la map (espaces verts, ilots) est fait par InstallerMap V21 (DonneesArbres.herbe), qui
	EXCLUT les plots : sans ce module, les plots seraient en herbe plate (mesh).
	Appele par InstallerMap a l'installation et a CHAQUE lancement du serveur par Lancement (rapide : 8 x 18 x 32 cases).
	PlotManager affine ensuite case par case pour les plots occupes (Ground sous les dalles, bande rase de 3 studs autour).

	Regles :
	  - chaque case de 15 studs des 8 plots (PlotSpawns.PlotN : PlotCenter + grille 18 x 32) recoit un bloc de Grass dont le
	    dessus nominal est a Y = -1,95 (Roblox dessine la surface ~2 studs plus haut : herbe a ~0, sous la chaussee a 0,57) ;
	  - les CASES INTERDITES (StringValue "CasesInterdites" du PlotSpawn : la courbe de la route du tour mord le coin du plot)
	    restent vides (Air) : la chaussee et le trottoir de la map passent dessus ;
	  - sous les tabliers de bitume des acces (Parts "*_Tablier") : Ground (pas de brins) ;
	  - l'annexe (Part "Annexe", 2 x 2 cases) : Grass aussi.
	Appel : require(game.ServerStorage.InstallerHerbe)(centre)  -- centre = CFrame du decalage d'import (facultatif)
]]
local CASE = 15
local DEMI = CASE / 2
local NX, NZ = 18, 32
local Y_NAPPE = -2
-- v51 : les voxels du terrain font 4 studs : un bloc dont le bord ne tombe pas sur la grille des voxels se termine par une
-- PENTE (voxel a moitie plein) de 4 studs sans brins : l'herbe semblait s'arreter loin du trottoir (Thomas). On deborde donc
-- de DEBORD studs SOUS les trottoirs (invisible : dessus du trottoir a 1,27, herbe a ~0) pour que le dernier voxel visible
-- soit plein : l'herbe arrive au ras de la bordure.
local DEBORD = 4

return function(centre)
	local T = workspace.Terrain
	local t0 = os.clock()
	local spawns = workspace:FindFirstChild("PlotSpawns")
	if not spawns then warn("[Herbe] PlotSpawns introuvable : pas d'herbe dans les plots"); return end
	pcall(function() T:SetMaterialColor(Enum.Material.LeafyGrass, T:GetMaterialColor(Enum.Material.Grass)) end)

	local function bloc(cf, taille, mat)
		local p = cf.Position
		local rot = cf - p
		T:FillBlock(CFrame.new(p.X, Y_NAPPE - 2.05, p.Z) * rot, Vector3.new(taille.X, 4.2, taille.Z), mat)
	end

	-- v49 : zones d'herbe de la map (DonneesArbres.herbe / herbe_ilots) : la base cuite les avait avec le haut nominal a
	-- 0,12 / 1,20, dessines ~2 studs trop haut (l'herbe depassait des trottoirs). On les refait a chaque lancement avec le
	-- haut nominal 2,05 plus bas (surface ~0,1 / ~1,2), apres avoir vide la colonne.
	local okD, D = pcall(function() return require(game:GetService("ServerStorage"):WaitForChild("DonneesArbres", 5)) end)
	local nZones = 0   -- (fait AVANT les plots : le vidage des colonnes ne doit pas mordre l'herbe des plots)
	if okD and type(D) == "table" and D.herbe then
		local centreMap = CFrame.new(workspace:GetAttribute("DecalageMap") or Vector3.zero)
		local function zone(r, haut)
			local sx, sz = r[3] - r[1] + 2 * DEBORD, r[4] - r[2] + 2 * DEBORD          -- v51 : deborde sous les trottoirs
			local cx, cz = (r[1] + r[3]) / 2, (r[2] + r[4]) / 2
			T:FillBlock(centreMap * CFrame.new(cx, -1, cz), Vector3.new(sx, 10, sz), Enum.Material.Air)
			T:FillBlock(centreMap * CFrame.new(cx, (haut - 6) / 2, cz), Vector3.new(sx, haut + 6, sz), Enum.Material.Grass)
			nZones += 1
		end
		local H = (D.herbe_haut or 0.12) - 2.05
		for _, r in ipairs(D.herbe) do zone(r, H) end
		local HI = (D.herbe_ilots_haut or 1.20) - 2.05
		for _, r in ipairs(D.herbe_ilots or {}) do zone(r, HI) end
	end

	local nPlots, nCases = 0, 0
	for _, plot in ipairs(spawns:GetChildren()) do
		local pc = plot:FindFirstChild("PlotCenter")
		if pc and pc:IsA("BasePart") then
			local base = pc.CFrame
			local interdites = {}
			local sv = plot:FindFirstChild("CasesInterdites")
			if sv and sv:IsA("StringValue") then
				for cx, cz in string.gmatch(sv.Value, "(%d+),(%d+)") do interdites[tonumber(cx) .. "_" .. tonumber(cz)] = true end
			end
			-- herbe : colonne par colonne, en bandes continues (moins d'appels FillBlock)
			for x = 1, NX do
				local z = 1
				while z <= NZ do
					if interdites[x .. "_" .. z] then
						z += 1
					else
						local z0 = z
						while z + 1 <= NZ and not interdites[x .. "_" .. (z + 1)] do z += 1 end
						local n = z - z0 + 1
						-- v51 : deborde de DEBORD sous les trottoirs aux bords du plot (colonnes 1 / NX, rangee 1, rangee NZ)
						local ex0, ex1 = (x == 1) and DEBORD or 0, (x == NX) and DEBORD or 0
						local ez0, ez1 = (z0 == 1) and DEBORD or 0, (z == NZ) and DEBORD or 0
						bloc(base * CFrame.new((x - 0.5) * CASE + (ex1 - ex0) / 2, 0, ((z0 - 1) + (z - 1)) / 2 * CASE + (ez1 - ez0) / 2),
							Vector3.new(CASE + ex0 + ex1, 0, n * CASE + ez0 + ez1), Enum.Material.Grass)
						nCases += n
						z += 1
					end
				end
			end
			-- annexe
			local an = plot:FindFirstChild("Annexe")
			if an and an:IsA("BasePart") then bloc(an.CFrame, Vector3.new(an.Size.X, 0, an.Size.Z), Enum.Material.Grass) end
			-- tabliers des acces : sans brins
			for _, t in ipairs(plot:GetDescendants()) do
				if t:IsA("BasePart") and string.find(t.Name, "_Tablier", 1, true) then
					bloc(t.CFrame, Vector3.new(t.Size.X + 2, 0, t.Size.Z + 2), Enum.Material.Ground)
				end
			end
			nPlots += 1
		end
	end
	print(("[Herbe] herbe en relief dans %d plots (%d cases), cases interdites laissees vides ; %d zones de la map rabaissees (%.2f s)"):format(nPlots, nCases, nZones, os.clock() - t0))
end
