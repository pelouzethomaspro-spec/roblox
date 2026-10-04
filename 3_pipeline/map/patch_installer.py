"""Applique les crochets Station Tycoon sur l'InstallerMap livre avec la map (V21j) -> outputs/Map/InstallerMap.lua.
Usage : python3 patch_installer.py <dossier 02_Scripts_Roblox>"""
import sys, os, shutil
SRC = sys.argv[1] if len(sys.argv) > 1 else 'V21j/MAP_V17_Transfert/02_Scripts_Roblox'
O = '/mnt/user-data/outputs/Integration_Stations/Map'
s = open(os.path.join(SRC, 'InstallerMap.lua'), encoding='utf-8').read()
def rep(old, new, n=1):
    global s
    assert s.count(old) == n, (s.count(old), old[:80])
    s = s.replace(old, new)
# 1. meshes de voirie = visuels (collisions = Parts invisibles)
rep("""			elseif string.find(n, "Voirie", 1, true) then
""", """			elseif string.find(n, "Voirie", 1, true) then
				-- Station tycoon v49 : les meshes de voirie (chaussee, trottoirs, bordures, marquage) sont des VISUELS : leur
				-- enveloppe de collision par defaut couvrait tout le carreau de map (jusque dans les plots : sol invisible a 1,27,
				-- rayons du mode Supprimer bloques). Les collisions reelles sont les Parts invisibles de DonneesCollisions.
				visuel(p, false); p.Parent = groupes.Voirie
""")
# 2. herbe : haut nominal 2,05 plus bas (Roblox dessine la surface ~2 studs au-dessus)
rep("""		local H = D.herbe_haut or 0.12
""", """		-- Station tycoon v49 : Roblox dessine la surface du Terrain ~2 studs AU-DESSUS du haut nominal d'un bloc rempli
		-- (mesure en jeu : l'herbe depassait du trottoir) : on descend le haut nominal de 2,05 studs (surface ~0,1 / ~1,2)
		local H = (D.herbe_haut or 0.12) - 2.05
""")
rep("""		local HI = D.herbe_ilots_haut or 1.20
""", """		local HI = (D.herbe_ilots_haut or 1.20) - 2.05
""")
# 3. herbe des plots (InstallerHerbe)
rep("""	-- le sol et la voirie restent toujours charges (on ne tombe jamais a travers)
""", """	-- 5 quater. Station tycoon (v49) : herbe en relief dans les 8 PLOTS des joueurs (exclus des zones ci-dessus), sauf les
	-- cases interdites (courbe de la route) : module InstallerHerbe, relance a chaque demarrage par Lancement
	do
		local okH, errH = pcall(function() require(SS:WaitForChild("InstallerHerbe"))(centre) end)
		if not okH then warn("[Map] herbe des plots : " .. tostring(errH)) end
	end

	-- le sol et la voirie restent toujours charges (on ne tombe jamais a travers)
""")
# 4. PlotZones inutiles
rep("""	local n = 0
	for _, p in ipairs(map:GetDescendants()) do if p:IsA("BasePart") then n = n + 1 end end
	print(("[Map] installee : %d parts au total""", """	-- Station tycoon : les reperes orange des plots (PlotZones) ne servent pas au jeu (PlotSpawns / PlotManager)
	do local pz = workspace:FindFirstChild("PlotZones"); if pz then pz:Destroy() end end

	local n = 0
	for _, p in ipairs(map:GetDescendants()) do if p:IsA("BasePart") then n = n + 1 end end
	print(("[Map] installee : %d parts au total""")
assert 'SS:WaitForChild("InstallerHerbe")' in s and 'local SS' in s or 'SS =' in s, 'variable SS ?'
open(os.path.join(O, 'InstallerMap.lua'), 'w', encoding='utf-8').write(s)
for f in ('DonneesArbres', 'DonneesCollisions', 'PortesSas', 'Course', 'RobotStock'):
    shutil.copy(os.path.join(SRC, f + '.lua'), os.path.join(O, f + '.lua'))
print('InstallerMap V21j + crochets ->', O)
