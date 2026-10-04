--[[ MetalClient   (LocalScript, StarterPlayer > StarterPlayerScripts)
	Transformation des voitures en or / argent chez ce joueur. Reglages : ReplicatedStorage > Metal > Reglages.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Metal"):WaitForChild("Effet")).lancer()
