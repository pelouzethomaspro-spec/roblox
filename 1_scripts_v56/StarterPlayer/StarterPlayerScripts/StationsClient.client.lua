--[[ StationsClient   (LocalScript, StarterPlayer > StarterPlayerScripts)
	Fait vivre les stations chez chaque joueur : voitures, animations des robots, sons et effets.
	Rien ne tourne sur le serveur. Tout le code est dans ReplicatedStorage > Stations (reglages : Stations > Reglages).
	Toute erreur au lancement est affichee clairement (F9 en jeu) au lieu de couper silencieusement les animations.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ok, err = pcall(function()
	require(ReplicatedStorage:WaitForChild("Stations"):WaitForChild("Client")).lancer()
end)
if not ok then
	warn("[Stations] le systeme des stations n'a pas demarre : " .. tostring(err))
end
