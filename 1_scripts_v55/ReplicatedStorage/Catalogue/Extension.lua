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
			Prix = 25000,
			AddX = 0,
			AddZ = 3
		},

		-- La largeur du plot le long de la route est fixee (18 cases de 15 = toute la largeur, map V21) : les extensions
		-- "haut" ajoutent elles aussi de la profondeur (4 rangees chacune), apres droit1..3. Profondeur max : 32 rangees.
		haut1 = {
			Prix = 30000,
			AddX = 0,
			AddZ = 4
		},
		haut2 = {
			Prix = 80000,
			AddX = 0,
			AddZ = 4
		},
		haut3 = {
			Prix = 250000,
			AddX = 0,
			AddZ = 4
		}
	}


return Extension