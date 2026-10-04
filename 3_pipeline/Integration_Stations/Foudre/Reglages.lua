--[[ Foudre / Reglages   (ReplicatedStorage > Foudre > Reglages)
	Tout ce qui se regle sur l'effet de foudre. Les ID se collent apres avoir importe les images et les sons
	(voir le guide). Tant qu'un ID vaut "rbxassetid://0", l'effet utilise une texture integree a Roblox (moins jolie).
]]
return {
	-- couleurs (violet / magenta)
	COULEUR = Color3.fromRGB(175, 100, 255),         -- lueur de l'eclair, lumiere, particules
	COULEUR_COEUR = Color3.fromRGB(250, 230, 255),   -- coeur de l'eclair, arcs, lisere de la voiture (blanc-rose)
	COULEUR_CORPS = Color3.fromRGB(200, 178, 245),   -- carrosserie electrifiee (lavande lumineuse, comme le rendu)

	TEXTURES = {
		Arc = "rbxassetid://116103059348550",          -- Foudre_Arc_V.png       (arcs sur la voiture ; eclair VERTICAL : un Beam Roblox deroule sa texture dans sa longueur)
		Trait = "rbxassetid://71152108200659",         -- Foudre_Trait.png       (eclair qui tombe du ciel)
		Etincelle = "rbxassetid://139499959078693",     -- Foudre_Etincelle.png   (etincelles)
		Lueur = "rbxassetid://125021907922689",         -- Foudre_Lueur.png       (lueurs, flash d'impact)
		Crepitement = "rbxassetid://87247269519700",   -- Foudre_Crepitement.png (petites decharges animees, planche 4 x 4)
	},
	-- Images et sons du pack, importes sur le compte de Thomas (thamary4) le 29/09/2026.
	SONS = {
		Tonnerre = "rbxassetid://81842887737757",      -- Foudre_Tonnerre.ogg  
		Impact = "rbxassetid://130770728307458",        -- Foudre_Impact.ogg    
		Crepitement = "rbxassetid://86675895446445",    -- Foudre_Crepitement.ogg (boucle)
	},
	VOLUME = 1,

	-- optimisation (chez chaque joueur)
	DISTANCE_COMPLET = 150,   -- en dessous : arcs, etincelles, son (voitures les plus proches)
	DISTANCE_HALO = 400,      -- en dessous : halo + lumiere seulement ; au-dela : rien
	MAX_COMPLET = 4,          -- voitures avec l'effet complet en meme temps (les plus proches)
	MAX_HALO = 12,            -- voitures avec le halo en meme temps (Roblox limite les halos a 31)
	ARCS = 10,                -- arcs electriques par voiture
	ARCS_SOL = 2,             -- arcs qui touchent le sol
	FREQUENCE_ARCS = 16,      -- changements de forme des arcs par seconde

	-- eclair
	HAUTEUR_ECLAIR = 260,     -- hauteur de depart de l'eclair (studs)
	ECLAIR_LARGEUR = 1.1,     -- largeur du coeur de l'eclair (studs) ; la lueur fait 2,4x et 5x
	ECLAIR_ONDULATION = 0.028,-- ondulation du trait (part de sa longueur) : 0,028 = presque droit comme le rendu
	SECOUSSE_DISTANCE = 90,   -- secousse de camera en dessous de cette distance
	FLASH_DISTANCE = 600,     -- flash du ciel en dessous de cette distance
	AMBIANCE_ORAGE = true,    -- teinte sombre et violette pendant l'orage
	BLOOM = true,             -- BloomEffect (Lighting) : les eclairs et arcs rayonnent comme dans le rendu ; false = aucun
	BLOOM_INTENSITE = 1,
}
