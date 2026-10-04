--[[ Stations / Reglages   (le seul fichier a modifier)

	ANIMATIONS : ID des 14 animations publiees le 28/09/2026 depuis les KeyframeSequences de la place (compte thamary4,
	type Animation). Si un ID vaut "rbxassetid://0", la station utilise, en test dans Studio seulement, l'animation
	rangee dans ReplicatedStorage > AnimationsTest_ASupprimer ; en jeu publie elle reste immobile.
]]
return {
	ANIMATIONS = {
		L3_Karcher = "rbxassetid://101473143464949",
		L4_Rouleaux = "rbxassetid://129678978667519",
		E4_Bornes = "rbxassetid://124808314879197",
		E5_Pneus = "rbxassetid://130631330736829",
		E6_Peinture = "rbxassetid://89375072654777",
		E7_Teinte = "rbxassetid://104100644296520",
		Voitures = "rbxassetid://123789074663025",         -- voitures des stations sans robot (L1, L2, E1, E2, E3)
		ChaineTapis = "rbxassetid://79680264263541",      -- chaine de production (decor) : tapis, voitures, scanner, ascenseur
		ChainePeinture = "rbxassetid://85491310553048",   -- chaine : robots de peinture
		ChaineVitres = "rbxassetid://112731938669411",     -- chaine : robot des vitres
		ChainePhares = "rbxassetid://105877497588390",     -- chaine : robot des phares
		ChaineFeux = "rbxassetid://122217160231946",       -- chaine : robot des feux
		ChaineRoues = "rbxassetid://70994659312280",      -- chaine : robots des roues
		ChaineSortie = "rbxassetid://83036419393204",     -- chaine : voiture qui sort
	},

	-- voitures, dans l'ordre de passage (noms des modeles dans ReplicatedStorage > VoituresModeles) ;
	-- un modele ajoute dans ce dossier passe aussi (apres ceux-ci). Chaque station commence a un endroit different.
	VOITURES = {"M4", "Follie", "Dodge", "F448", "ClassG", "GT3", "Golf", "Golf2", "Volvo240", "Urus", "Mercedes", "Clio4"},
	LONGUEUR_VOITURE = nil,    -- (obsolete) la longueur par modele vient de ReplicatedStorage > Catalogue > Car (Car.Longueur), appliquee au demarrage par CarManager
	DECALAGE = 5,              -- ecart dans la liste des voitures d'une station a la suivante

	DISTANCE_ACTIVE = 150,     -- une station ne vit (voiture, animation, sons) que si le joueur est a moins de cette distance (studs)

	VOLUME = 1,                -- volume general des sons des stations
	MOTEUR = true,             -- bruit de moteur des voitures
}
