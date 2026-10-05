local Extension = {
OrderX = {"droit1", "droit2","droit3"},
	OrderZ = {"haut1", "haut2","haut3"},

		droit1 = {
			Prix = 3000,
			AddX = 0,
			AddZ = 3
		},
		droit2 = {
			Prix = 8000,
			AddX = 0,
			AddZ = 3
		},
		droit3 = {
			Prix = 20000,            -- v56 : 25 000 -> 20 000
			AddX = 0,
			AddZ = 3
		},

		-- La largeur du plot le long de la route est fixee (18 cases de 15 = toute la largeur, map V21) : les extensions
		-- "haut" ajoutent elles aussi de la profondeur (4 rangees chacune), apres droit1..3. Profondeur max : 32 rangees.
		haut1 = {
			Prix = 40000,            -- v56 : 30 000 -> 40 000
			AddX = 0,
			AddZ = 4
		},
		haut2 = {
			Prix = 90000,            -- v56 : 80 000 -> 90 000
			AddX = 0,
			AddZ = 4
		},
		haut3 = {
			Prix = 180000,           -- v56 : 250 000 -> 180 000 (~ 6 h de jeu a 500 $/min au lieu de 8)
			AddX = 0,
			AddZ = 4
		}
	}


return Extension