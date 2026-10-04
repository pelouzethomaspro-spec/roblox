--[[ Stations / Donnees / E3_Pompes   (genere automatiquement : ne pas modifier)
	Station E3 (pompes : essence, gaz, electrique) — voitures + sons de plein a la pompe
	La voiture se gare, on decroche le pistolet, la pompe tourne et le carburant coule, on raccroche, bip de fin.
	SEGMENTS : morceaux de l'animation de la station (un par categorie de voiture, par modele ou unique) ;
	parc = position de la voiture garee (repere du modele) ; piste = horaires des sons et effets.
	JOINTS = {piece, piece parente, T (glissiere) | R (rotation), pivot, axe} : articulations posees par le montage.
]]
return {
	NOM = "E3_Pompes",
	INDEX = 7,
	PHASE = 25.9,
	REFS = {"E3_Pompes_Partie2", "E3_Pompes_Partie3"},
	CENTRES = {E3_Pompes_Partie2 = {100, 0, 11.24}, E3_Pompes_Partie3 = {112.8571, 10.8374, 8.3675}},
	COMPORTEMENT = "Simple",
	ANIMATION = "Voitures",
	MODE = "simple",
	STOP = "fixe",
	CYCLE = 19,
	ARRET = 8,
	PLACE = {XC = 96.03, YC = 0, SOL = 0.6},
	PARC = {96.03, 0, 0.6, -1, 0, 0, 0, -1, 0, 0, 0, 1},
	JOINTS = {},
	SEGMENTS = {{nom = "arrivee", debut = 0, duree = 5.5}, {nom = "depart", debut = 6, duree = 5}},
	SONS = {bip = "bip", pistolet = "pistoletPompe", pompe = "pompe", carburant = "fontaine"},
	ACTIONS = {
		{"coup", t = 0.3, son = "bip", volume = 0.8},
		{"coup", t = 0.8, son = "pistolet", volume = 0.7},
		{"boucle", de = 1.3, a = 6.3, son = "pompe", volume = 0.35, vitesse = 1.35},
		{"boucle", de = 1.3, a = 6.3, son = "carburant", volume = 0.18, vitesse = 1.4},
		{"coup", t = 6.5, son = "pistolet", volume = 0.7},
		{"coup", t = 7.2, son = "bip", volume = 0.8},
	},
}
