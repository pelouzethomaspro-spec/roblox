--[[ Stations / Donnees / E2_Barils   (genere automatiquement : ne pas modifier)
	Station E2 (barils et jerricans) — voitures + sons de plein au jerrican
	La voiture se gare, on ouvre le bouchon et on verse le jerrican (glouglou), on referme, elle repart.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "E2_Barils",
	INDEX = 6,
	PHASE = 22.2,
	REFS = {"E2_Barils_Station"},
	CENTRES = {E2_Barils_Station = {60, 0, 11.24}},
	COMPORTEMENT = "Simple",
	ANIMATION = "Voitures",
	MODE = "simple",
	STOP = "fixe",
	CYCLE = 19,
	ARRET = 8,
	PLACE = {XC = 56.03, YC = 0, SOL = 0.6},
	PARC = {56.03, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
	JOINTS = {},
	SEGMENTS = {{nom = "arrivee", debut = 0, duree = 5.5}, {nom = "depart", debut = 6, duree = 5}},
	SONS = {bip = "bip", bouchon = "clac", glou1 = "glouglou1", glou2 = "glouglou2"},
	ACTIONS = {
		{"coup", t = 0.3, son = "bip", volume = 0.8},
		{"coup", t = 0.9, son = "bouchon", volume = 0.7},
		{"hasard", de = 1.3, a = 6.0, son = "glou1", volume = 0.6, intervalle = {0.5, 0.9}, vitesse = {0.9, 1.1}},
		{"hasard", de = 1.6, a = 6.0, son = "glou2", volume = 0.5, intervalle = {0.7, 1.2}, vitesse = {0.85, 1.05}},
		{"coup", t = 6.4, son = "bouchon", volume = 0.7},
		{"coup", t = 7.6, son = "bip", volume = 0.8},
	},
}
