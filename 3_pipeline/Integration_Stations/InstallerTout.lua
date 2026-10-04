--[[ InstallerTout (ModuleScript, ServerStorage) — tout installer d'un coup, une fois les FBX importes dans Workspace :
	  require(game.ServerStorage.InstallerTout)()
	1. InstallerMap            : la map V17 (collisions, arbres, eau, copies des batiments, reglages)
	2. InstallerChaines        : les 4 chaines de production animees (articulations, animations)
	3. Installer_Constructions : les vrais meshes des sols, murs, toits et decors (charges depuis ton asset publie)
	Chaque etape est independante et relancable ; une etape qui echoue n'empeche pas les suivantes. Enregistre la place ensuite.
]]
local SS = game:GetService("ServerStorage")
return function()
	local bilan = {}
	for _, nom in ipairs({"InstallerMap", "InstallerChaines", "Installer_Constructions"}) do
		local module = SS:FindFirstChild(nom)
		if not module then
			table.insert(bilan, nom .. " : module absent")
			continue
		end
		print(("[InstallerTout] ===== %s ====="):format(nom))
		local ok, err = pcall(function() return require(module)() end)
		table.insert(bilan, nom .. " : " .. (ok and "OK" or ("ERREUR " .. tostring(err))))
		if not ok then warn("[InstallerTout] " .. nom .. " : " .. tostring(err)) end
	end
	print("[InstallerTout] bilan : " .. table.concat(bilan, " | "))
	print("[InstallerTout] Enregistre / publie la place. Il reste a publier les animations Chaine* et a coller leurs ID dans Stations/Reglages.")
end
