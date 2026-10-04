--[[ Stations / Donnees / E4_Bornes   (genere automatiquement : ne pas modifier)
	Station E4 (bornes) : bras robot au plafond + voitures.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "E4_Bornes",
	INDEX = 8,
	PHASE = 29.6,
	REFS = {"E4_Bornes_Partie1", "E4_Bornes_Partie3"},
	CENTRES = {E4_Bornes_Partie1 = {152.003, -3.847, 6.776}, E4_Bornes_Partie3 = {140, 0, 11.24}},
	COMPORTEMENT = "E4",
	ANIMATION = "E4_Bornes",
	MODE = "unique",
	STOP = "fixe",
	CYCLE = 43,
	T_BRAS = 5.5,
	JOINTS = {
		{"E4_Bornes_Bras0_Chariot", "Socle", "T", {146.135, 0, 16.57}, {0, 1, 0}},
		{"E4_Bornes_Bras1_Tourelle", "E4_Bornes_Bras0_Chariot", "R", {146, 0, 15.85}, {0, 0, 1}},
		{"E4_Bornes_Bras2_BrasHaut", "E4_Bornes_Bras1_Tourelle", "R", {146, 0, 14.05}, {0, 1, 0}},
		{"E4_Bornes_Bras3_AvantBras", "E4_Bornes_Bras2_BrasHaut", "R", {141.86, 0, 12.19}, {0, 1, 0}},
		{"E4_Bornes_Bras4_Poignet", "E4_Bornes_Bras3_AvantBras", "R", {145.16, 0, 11.35}, {0, 1, 0}},
		{"E4_Bornes_Bras5_Pince", "E4_Bornes_Bras4_Poignet", "R", {145.16, 0, 9.91}, {0, 0, 1}},
	},
	SEGMENTS = {
		{
			nom = "Unique",
			debut = 0,
			duree = 42.5,
			membres = {"M4"},
			parc = {136.02999, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
			milieu = 0.1883,
			roues = {
				AVG = {c = {-2.8172, 4.8844, 1.2037}, r = 1.2169},
				AVD = {c = {2.8172, 4.8844, 1.1986}, r = 1.2169},
				ARG = {c = {-2.8162, -4.5077, 1.1922}, r = 1.1111},
				ARD = {c = {2.8162, -4.5077, 1.1875}, r = 1.1111},
			},
		},
	},
	EVENEMENTS = {
		{0.2, "lumiere", "on"},
		{0.2, "son", "allumage"},
		{2.25, "son", "moteur", 1.55},
		{4.8, "touche", "essence"},
		{5.65, "son", "moteur", 0.85},
		{6.55, "son", "moteur", 1.05},
		{7.65, "son", "moteur", 1.3},
		{9.9, "touche", "gaz"},
		{10.85, "son", "moteur", 0.75},
		{11.65, "son", "moteur", 1.5},
		{13.25, "son", "moteur", 2.1},
		{15.45, "son", "moteur", 1.5},
		{18, "touche", "elec"},
		{19.05, "son", "moteur", 0.9},
		{20.25, "son", "moteur", 0.9},
		{21.25, "son", "moteur", 1.7},
		{24, "touche", "voiture"},
		{25.85, "son", "moteur", 1.1},
		{27.05, "son", "moteur", 1.5},
		{28.9, "lumiere", "off"},
		{28.9, "son", "extinction"},
	},
	POINTE = {145.0583, 0, 9.1591},
}
