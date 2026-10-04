--[[ Stations / Donnees / L2_Seaux   (genere automatiquement : ne pas modifier)
	Station L2 (lavage aux seaux et produits) — voitures + sons de lavage a l'eponge
	La voiture se gare, on la lave a la main : seau d'eau, eponge mouillee, pulverisateur de produit, rincage.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "L2_Seaux",
	INDEX = 2,
	PHASE = 7.4,
	REFS = {"L2_Seaux_Partie1", "L2_Seaux_Partie3"},
	CENTRES = {L2_Seaux_Partie1 = {-88.065, 0.8546, 4.749}, L2_Seaux_Partie3 = {-100, 0, 9.775}},
	COMPORTEMENT = "Simple",
	ANIMATION = "Voitures",
	MODE = "simple",
	STOP = "fixe",
	CYCLE = 19,
	ARRET = 8,
	PLACE = {XC = -103.8, YC = 0, SOL = 0.6},
	PARC = {-103.8, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
	JOINTS = {},
	SEGMENTS = {{nom = "arrivee", debut = 0, duree = 5.5}, {nom = "depart", debut = 6, duree = 5}},
	SONS = {bip = "bip", seau = "splash", eponge = "eponge", pschit = "spray", rincage = "jetOuverture"},
	ACTIONS = {
		{"coup", t = 0.3, son = "bip", volume = 0.8},
		{"coup", t = 0.8, son = "seau", volume = 0.6},
		{"boucle", de = 1.0, a = 6.6, son = "eponge", volume = 0.5, vitesse = 1.1},
		{"hasard", de = 1.5, a = 6.4, son = "seau", volume = 0.45, intervalle = {1.6, 3.0}, vitesse = {0.9, 1.15}},
		{"hasard", de = 1.2, a = 6.2, son = "pschit", volume = 0.35, intervalle = {1.8, 3.2}, vitesse = {1.6, 1.9}, duree = 0.35},
		{"coup", t = 6.8, son = "rincage", volume = 0.45},
		{"coup", t = 7.6, son = "bip", volume = 0.8},
	},
}
