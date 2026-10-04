--[[ Stations / Donnees / E1_Base   (genere automatiquement : ne pas modifier)
	Station E1 (base) — voitures + sons de controle / entretien
	La voiture se gare, petit entretien : cle a cliquet, clics d'outils, visseuse, puis elle repart.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "E1_Base",
	INDEX = 5,
	PHASE = 18.5,
	REFS = {"E1_Base_Station"},
	CENTRES = {E1_Base_Station = {20, 0, 11.24}},
	COMPORTEMENT = "Simple",
	ANIMATION = "Voitures",
	MODE = "simple",
	STOP = "fixe",
	CYCLE = 19,
	ARRET = 8,
	PLACE = {XC = 16.03, YC = 0, SOL = 0.6},
	PARC = {16.03, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
	JOINTS = {},
	SEGMENTS = {{nom = "arrivee", debut = 0, duree = 5.5}, {nom = "depart", debut = 6, duree = 5}},
	SONS = {bip = "bip", cliquet = "cliquet", clac = "clac", visseuse = "visseuse"},
	ACTIONS = {
		{"coup", t = 0.3, son = "bip", volume = 0.8},
		{"hasard", de = 1.0, a = 6.4, son = "cliquet", volume = 0.55, intervalle = {1.4, 2.6}, vitesse = {0.95, 1.1}, duree = 1.0},
		{"hasard", de = 1.5, a = 6.4, son = "clac", volume = 0.4, intervalle = {2.0, 3.5}},
		{"coup", t = 6.8, son = "visseuse", volume = 0.5, duree = 0.6},
		{"coup", t = 7.6, son = "bip", volume = 0.8},
	},
}
