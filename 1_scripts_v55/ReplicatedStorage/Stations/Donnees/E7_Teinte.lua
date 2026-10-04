--[[ Stations / Donnees / E7_Teinte   (genere automatiquement : ne pas modifier)
	Station E7_Teinte.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "E7_Teinte",
	INDEX = 11,
	PHASE = 40.7,
	REFS = {"E7_Teinte_Mob_CoteG", "E7_Teinte_Mob_CoteD"},
	CENTRES = {E7_Teinte_Mob_CoteG = {250.4873, -9.65, 3.9}, E7_Teinte_Mob_CoteD = {261.5873, -9.65, 3.9}, E7_Teinte_Mob_Barre = {256.03, -10.6, 8.7665}},
	COMPORTEMENT = "E7",
	ANIMATION = "E7_Teinte",
	MODE = "categorie",
	STOP = "milieu",
	CYCLE = 30.5,
	JOINTS = {
		{"E7_Teinte_Mob_Portique", "Socle", "T", {256.211, -10.6, 6.9685}, {0, 1, 0}},
		{"E7_Teinte_Mob_Barre", "E7_Teinte_Mob_Portique", "T", {256.03, -10.6, 8.7665}, {0, 0, 1}},
		{"E7_Teinte_Mob_CoteG", "E7_Teinte_Mob_Portique", "R", {250.48, -10.6, 4}, {0, 0, 1}},
		{"E7_Teinte_Mob_CoteD", "E7_Teinte_Mob_Portique", "R", {261.58, -10.6, 4}, {0, 0, 1}},
	},
	ROBOT = {YA0 = -10.6, LA = 1.8, ZS = {2.4, 5.3}, PIVG = {250.48, -10.6, 4}, PIVD = {261.58, -10.6, 4}},
	SEGMENTS = {
		{
			nom = "Sportive",
			debut = 0,
			duree = 29.5,
			membres = {"Follie", "F448", "Mercedes"},
			parc = {256.03001, 0.09809, 1, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = 0.2981,
			roues = {
				AVG = {c = {-2.7656, 4.8528, 1.1248}, r = 1.1372},
				AVD = {c = {2.7656, 4.8528, 1.12}, r = 1.1372},
				ARG = {c = {-2.7631, -4.2566, 1.2348}, r = 1.1285},
				ARD = {c = {2.7631, -4.2566, 1.23}, r = 1.1285},
			},
			piste = {T_ARRIVEE = 5, T_DEPART = 23.5, passes = {{"film", 5.5, 11}, {"chauffe", 11.6, 17.6}, {"controle", 18.2, 22.7}}},
		},
		{
			nom = "Berline",
			debut = 30,
			duree = 29.5,
			membres = {"M4", "Dodge", "GT3", "Volvo240"},
			parc = {256.03001, 0.4569, 1, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = 0.6569,
			roues = {
				AVG = {c = {-2.1865, 5.0173, 1.1053}, r = 1.1174},
				AVD = {c = {2.1908, 5.0173, 1.1005}, r = 1.1174},
				ARG = {c = {-2.3409, -3.7035, 1.1062}, r = 0.9639},
				ARD = {c = {2.3452, -3.7035, 1.1021}, r = 0.9639},
			},
			piste = {T_ARRIVEE = 5, T_DEPART = 23.5, passes = {{"film", 5.5, 11}, {"chauffe", 11.6, 17.6}, {"controle", 18.2, 22.7}}},
		},
		{
			nom = "Compacte",
			debut = 60,
			duree = 29.5,
			membres = {"Golf", "Clio4"},
			parc = {256.03001, -0.51775, 1, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = -0.3177,
			roues = {
				AVG = {c = {-2.9424, 4.7843, 1.4084}, r = 1.3114},
				AVD = {c = {2.9424, 4.7843, 1.4029}, r = 1.3114},
				ARG = {c = {-2.9328, -5.4198, 1.3195}, r = 1.334},
				ARD = {c = {2.9328, -5.4198, 1.3139}, r = 1.334},
			},
			piste = {T_ARRIVEE = 5, T_DEPART = 23.5, passes = {{"film", 5.5, 11}, {"chauffe", 11.6, 17.6}, {"controle", 18.2, 22.7}}},
		},
		{
			nom = "Haute",
			debut = 90,
			duree = 29.5,
			membres = {"ClassG", "Golf2", "Urus"},
			parc = {256.03001, -0.31333, 1, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = -0.1133,
			roues = {
				AVG = {c = {-2.5265, 4.6473, 1.3417}, r = 1.3564},
				AVD = {c = {2.5265, 4.6473, 1.3359}, r = 1.3564},
				ARG = {c = {-2.8383, -4.874, 1.4903}, r = 1.2567},
				ARD = {c = {2.8383, -4.874, 1.485}, r = 1.2567},
			},
			piste = {T_ARRIVEE = 5, T_DEPART = 23.5, passes = {{"film", 5.5, 11}, {"chauffe", 11.6, 17.6}, {"controle", 18.2, 22.7}}},
		},
	},
}
