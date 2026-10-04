--[[ Catalogue Plafond : genere depuis le pack de constructions PACK_10_3 (1 case = 10 studs).
	Nom = libelle affiche ; Famille / Matiere servent au menu de construction ; Prix en $ (debite par le serveur).
]]
local Plafond = {
	["toit"] = { Nom = "Tuiles", Prix = 25, Famille = "toits" },
	["toit_angle"] = { Nom = "Angle gravier", Prix = 18, Famille = "toits_angles" },
	["toit_bac"] = { Nom = "Bac acier", Prix = 18, Famille = "toits" },
	["toit_bac_angle"] = { Nom = "Angle bac acier", Prix = 24, Famille = "toits_angles" },
	["toit_bac_angle2"] = { Nom = "Angle bac acier 2", Prix = 24, Famille = "toits_angles" },
	["toit_bac_bord_x"] = { Nom = "Bord bac acier", Prix = 22, Famille = "toits_bords" },
	["toit_bac_bord_y"] = { Nom = "Bord bac acier (travers)", Prix = 22, Famille = "toits_bords" },
	["toit_bord"] = { Nom = "Bord gravier", Prix = 16, Famille = "toits_bords" },
	["toit_clair"] = { Nom = "Toit clair", Prix = 14, Famille = "toits" },
	["toit_clair_angle"] = { Nom = "Angle clair", Prix = 20, Famille = "toits_angles" },
	["toit_clair_bord"] = { Nom = "Bord clair", Prix = 18, Famille = "toits_bords" },
	["toit_membrane"] = { Nom = "Membrane", Prix = 12, Famille = "toits" },
	["toit_plat"] = { Nom = "Toit plat", Prix = 10, Famille = "toits" },
}
return Plafond
