--[[ Stations / Donnees / L3_Karcher   (genere automatiquement : ne pas modifier)
	Station L3_Karcher.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "L3_Karcher",
	INDEX = 3,
	PHASE = 11.1,
	REFS = {"L3_Karcher_Mob_Pont", "L3_Karcher_Mob_Chariot"},
	CENTRES = {L3_Karcher_Mob_Pont = {-63.75, -9, 12.96}, L3_Karcher_Mob_Chariot = {-59.25, -8.675, 11.4893}},
	COMPORTEMENT = "L3",
	ANIMATION = "L3_Karcher",
	MODE = "categorie",
	STOP = "fixe",
	CYCLE = 34.7,
	JOINTS = {
		{"L3_Karcher_Mob_Pont", "Socle", "T", {-63.75, -9, 12.96}, {0, 1, 0}},
		{"L3_Karcher_Mob_Chariot", "L3_Karcher_Mob_Pont", "T", {-59.25, -8.675, 11.4893}, {1, 0, 0}},
		{"L3_Karcher_Mob_Tube", "L3_Karcher_Mob_Chariot", "T", {-59.25, -9, 11.209}, {0, 0, 1}},
		{"L3_Karcher_Mob_Lance", "L3_Karcher_Mob_Chariot", "T", {-59.25, -8.97, 10.256}, {0, 0, 1}},
	},
	NOZ = {-59.25, -9, 8.3},
	PLACE = {SOL = 0.6},
	SEGMENTS = {
		{
			nom = "Sportive",
			debut = 0,
			duree = 33.7,
			membres = {"Follie", "F448", "Mercedes"},
			parc = {-63.75, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = 0.2981,
			roues = {
				AVG = {c = {-2.7656, 4.8528, 1.1248}, r = 1.1372},
				AVD = {c = {2.7656, 4.8528, 1.12}, r = 1.1372},
				ARG = {c = {-2.7631, -4.2566, 1.2348}, r = 1.1285},
				ARD = {c = {2.7631, -4.2566, 1.23}, r = 1.1285},
			},
			piste = {
				T_ARRIVEE = 5.5,
				T_DEPART = 27.7,
				segs = {{"descente", 5.9, 7.5}, {"aller", 7.5, 16.5}, {"pause", 16.5, 16.9}, {"retour", 16.9, 25.9}, {"montee", 25.9, 27.5}},
				eau = {{7.5, 25.9}},
			},
		},
		{
			nom = "Berline",
			debut = 34.2,
			duree = 33.7,
			membres = {"M4", "Dodge", "GT3", "Volvo240"},
			parc = {-63.74999, 0, 0.59999, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = 0.6569,
			roues = {
				AVG = {c = {-2.1865, 5.0173, 1.1053}, r = 1.1174},
				AVD = {c = {2.1908, 5.0173, 1.1005}, r = 1.1174},
				ARG = {c = {-2.3409, -3.7035, 1.1062}, r = 0.9639},
				ARD = {c = {2.3452, -3.7035, 1.1021}, r = 0.9639},
			},
			piste = {
				T_ARRIVEE = 5.5,
				T_DEPART = 27.7,
				segs = {{"descente", 5.9, 7.5}, {"aller", 7.5, 16.5}, {"pause", 16.5, 16.9}, {"retour", 16.9, 25.9}, {"montee", 25.9, 27.5}},
				eau = {{7.5, 25.9}},
			},
		},
		{
			nom = "Compacte",
			debut = 68.4,
			duree = 33.7,
			membres = {"Golf", "Clio4"},
			parc = {-63.75, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = -0.3177,
			roues = {
				AVG = {c = {-2.9424, 4.7843, 1.4084}, r = 1.3114},
				AVD = {c = {2.9424, 4.7843, 1.4029}, r = 1.3114},
				ARG = {c = {-2.9328, -5.4198, 1.3195}, r = 1.334},
				ARD = {c = {2.9328, -5.4198, 1.3139}, r = 1.334},
			},
			piste = {
				T_ARRIVEE = 5.5,
				T_DEPART = 27.7,
				segs = {{"descente", 5.9, 7.5}, {"aller", 7.5, 16.5}, {"pause", 16.5, 16.9}, {"retour", 16.9, 25.9}, {"montee", 25.9, 27.5}},
				eau = {{7.5, 25.9}},
			},
		},
		{
			nom = "Haute",
			debut = 102.6,
			duree = 33.7,
			membres = {"ClassG", "Golf2", "Urus"},
			parc = {-63.75, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = -0.1133,
			roues = {
				AVG = {c = {-2.5265, 4.6473, 1.3416}, r = 1.3564},
				AVD = {c = {2.5265, 4.6473, 1.3359}, r = 1.3564},
				ARG = {c = {-2.8383, -4.874, 1.4903}, r = 1.2567},
				ARD = {c = {2.8383, -4.874, 1.485}, r = 1.2567},
			},
			piste = {
				T_ARRIVEE = 5.5,
				T_DEPART = 27.7,
				segs = {{"descente", 5.9, 7.5}, {"aller", 7.5, 16.5}, {"pause", 16.5, 16.9}, {"retour", 16.9, 25.9}, {"montee", 25.9, 27.5}},
				eau = {{7.5, 25.9}},
			},
		},
	},
}
