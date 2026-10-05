--[[ Stations / Donnees / L1_Vide   (genere automatiquement : ne pas modifier)
	Station L1 (lavage : place libre) — voitures + sons de lavage au jet
	La voiture se gare, on la rince au jet d'eau (bruit de jet, eau sur la tole, paquets d'eau), puis elle repart.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "L1_Vide",
	INDEX = 1,
	PHASE = 3.7,
	REFS = {"L1_Vide_Station"},
	CENTRES = {L1_Vide_Station = {-140, 0, 9.775}},
	COMPORTEMENT = "Simple",
	ANIMATION = "Voitures",
	MODE = "simple",
	STOP = "fixe",
	CYCLE = 19,
	ARRET = 8,
	PLACE = {XC = -143.8, YC = 0, SOL = 0.6},
	PARC = {-143.8, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
	JOINTS = {},
	SEGMENTS = {{nom = "arrivee", debut = 0, duree = 5.5}, {nom = "depart", debut = 6, duree = 5}},
	SONS = {bip = "bip", ouverture = "jetOuverture", jet = "jetKarcher", tole = "eauTole", splash = "splash", clac = "clac"},
	ACTIONS = {
		{"coup", t = 0.3, son = "bip", volume = 0.8},
		{"coup", t = 0.7, son = "ouverture", volume = 0.6},
		{"boucle", de = 0.9, a = 7.0, son = "jet", volume = 0.55},
		{"boucle", de = 1.1, a = 7.0, son = "tole", volume = 0.35},
		{"hasard", de = 1.3, a = 6.8, son = "splash", volume = 0.45, intervalle = {1.2, 2.4}, vitesse = {0.9, 1.2}},
		{"coup", t = 7.1, son = "clac", volume = 0.7},
		{"coup", t = 7.6, son = "bip", volume = 0.8},
	},
}
