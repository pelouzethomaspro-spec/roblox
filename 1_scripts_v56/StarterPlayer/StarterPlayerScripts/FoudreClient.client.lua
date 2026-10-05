--[[ FoudreClient   (LocalScript, StarterPlayer > StarterPlayerScripts)
	Effets de foudre chez ce joueur (eclairs, voitures electrifiees). Reglages : ReplicatedStorage > Foudre > Reglages.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
require(ReplicatedStorage:WaitForChild("Foudre"):WaitForChild("Effet")).lancer()
