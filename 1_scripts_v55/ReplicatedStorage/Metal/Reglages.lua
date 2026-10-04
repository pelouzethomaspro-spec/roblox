--[[ Metal / Reglages   (ReplicatedStorage > Metal > Reglages)
	Transformation d'une voiture en OR ou en ARGENT. Les ID se collent apres avoir importe les images et les sons
	(voir le guide). Tant qu'un ID vaut "rbxassetid://0", l'effet utilise une texture integree a Roblox et reste muet.
]]
return {
	VARIANTES = {
		Or = {
			couleur = Color3.fromRGB(255, 192, 62),       -- carrosserie
			reflet = 0.25,                                -- Reflectance
			materiau = Enum.Material.Foil,
			lueur = Color3.fromRGB(255, 176, 56),         -- anneau, paillettes, eclat
			etoile = Color3.fromRGB(255, 226, 150),       -- etoiles qui scintillent
		},
		Argent = {
			couleur = Color3.fromRGB(214, 220, 230),
			reflet = 0.35,
			materiau = Enum.Material.Foil,
			lueur = Color3.fromRGB(190, 225, 255),
			etoile = Color3.fromRGB(235, 245, 255),
		},
	},

	TEXTURES = {
		Etoile = "rbxassetid://80774331458383",      -- Metal_Etoile.png    (etoiles a 4 branches)
		Paillette = "rbxassetid://105981056022666",   -- Metal_Paillette.png (point lumineux doux)
		Trait = "rbxassetid://91553058897152",       -- Metal_Trait.png     (anneau de lumiere, onde au sol)
	},
	SONS = {
		Transformation = "rbxassetid://79600640791649",   -- Metal_Transformation.ogg (scintillement qui monte)
		Eclat = "rbxassetid://106386032223402",            -- Metal_Eclat.ogg          (tintement final)
	},
	VOLUME = 1,

	-- deroule de l'animation (secondes)
	SPIRALE = 1.0,          -- paillettes qui s'enroulent autour de la voiture
	BALAYAGE = 2.3,         -- l'anneau de lumiere balaie la voiture de l'avant a l'arriere

	-- optimisation (chez chaque joueur)
	DISTANCE_ANIMATION = 300,   -- au-dela : pas d'animation, la voiture devient directement en or / argent
	DISTANCE_ETOILES = 120,     -- etoiles qui scintillent sur le metal en dessous de cette distance
	MAX_ETOILES = 6,            -- voitures avec les etoiles en meme temps (les plus proches)
}
