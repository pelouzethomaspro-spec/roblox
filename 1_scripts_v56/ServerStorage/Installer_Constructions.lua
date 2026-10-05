--[[ Installer_Constructions — installe les vrais meshes du pack de constructions (PACK_10_3) dans la place.

	COMMENT LANCER (dans Roblox Studio, place ouverte) : Affichage > Barre de commande, puis tape :
		require(game.ServerStorage.Installer_Constructions)()
	et Entree. (Ou colle tout ce fichier dans la barre de commande : il s'execute aussi tel quel.)

	CE QUE FAIT LE SCRIPT : il charge le modele publie "PACK_10_3 (1)" (ID_PACK ci-dessous, ton asset Model) avec
	InsertService — ou reutilise un modele "PACK_10..." deja present dans Workspace / selectionne — puis, pour chaque
	construction du pack (sols, murs, toits, decor), il prend les MeshParts, les regroupe dans un Model au nom du
	catalogue, verifie l'echelle (10 studs), ancre tout, place le pivot exactement comme le jeu l'attend (dessus du sol
	a +0.5, bas des murs au sol, face avant des portes vers l'exterieur, toits au sommet des murs) et remplace la
	boite provisoire de ReplicatedStorage/<categorie>. Il ne touche pas aux stations. Relancable : ne remplace que les
	boites provisoires (FORCER = true pour tout refaire) et verifie / corrige les pivots des constructions deja installees.
	Enregistre la place ensuite (Ctrl+S / publier).
]]
local ID_PACK = 90907777498961      -- asset Model "PACK_10_3 (1)" publie par thamary4
local FORCER = false

local SOL_DESSUS, MEUBLE_Y = 0.5, 0.616

local CONSTRUCTIONS = {
	["barriere_arceau"] = {cat = "Furniture", taille = Vector3.new(4.700, 2.393, 0.300), principale = "barriere_arceau_vert", pieces = {"barriere_arceau_gris", "barriere_arceau_vert"}, nx = 1, nz = 1},
	["barriere_grille"] = {cat = "Furniture", taille = Vector3.new(5.000, 2.600, 0.130), principale = "barriere_grille_noir", pieces = {"barriere_grille_noir"}, nx = 1, nz = 1},
	["barriere_potelets"] = {cat = "Furniture", taille = Vector3.new(4.920, 2.540, 0.720), principale = "barriere_potelets_noir", pieces = {"barriere_potelets_noir", "barriere_potelets_vert"}, nx = 1, nz = 1},
	["barriere_rails"] = {cat = "Furniture", taille = Vector3.new(5.360, 2.770, 0.360), principale = "barriere_rails_gris", pieces = {"barriere_rails_gris"}, nx = 1, nz = 1},
	["barriere_verre"] = {cat = "Furniture", taille = Vector3.new(5.320, 2.612, 0.320), principale = "barriere_verre_gris", pieces = {"barriere_verre_gris", "barriere_verre_verre"}, nx = 1, nz = 1},
	["buisson_boule"] = {cat = "Furniture", taille = Vector3.new(3.483, 3.275, 3.394), principale = "buisson_boule_feuillage", pieces = {"buisson_boule_feuillage"}, nx = 1, nz = 1},
	["carton_grand"] = {cat = "Furniture", taille = Vector3.new(6.432, 4.900, 5.207), principale = "carton_grand_mur", pieces = {"carton_grand_mur"}, nx = 1, nz = 1},
	["carton_moyen"] = {cat = "Furniture", taille = Vector3.new(4.747, 3.522, 4.135), principale = "carton_moyen_mur", pieces = {"carton_moyen_mur"}, nx = 1, nz = 1},
	["carton_petit"] = {cat = "Furniture", taille = Vector3.new(3.216, 2.603, 2.910), principale = "carton_petit_mur", pieces = {"carton_petit_mur"}, nx = 1, nz = 1},
	["colonne_taillee"] = {cat = "Furniture", taille = Vector3.new(2.162, 7.988, 2.273), principale = "colonne_taillee_feuillage", pieces = {"colonne_taillee_feuillage"}, nx = 1, nz = 1},
	["haie_bloc"] = {cat = "Furniture", taille = Vector3.new(6.147, 2.575, 1.926), principale = "haie_bloc_feuillage", pieces = {"haie_bloc_feuillage"}, nx = 1, nz = 1},
	["jardiniere_fleurs"] = {cat = "Furniture", taille = Vector3.new(4.754, 2.035, 2.154), principale = "jardiniere_fleurs_bac", pieces = {"jardiniere_fleurs_bac", "jardiniere_fleurs_coeur", "jardiniere_fleurs_feuillage", "jardiniere_fleurs_fleur", "jardiniere_fleurs_fleur2", "jardiniere_fleurs_terreau", "jardiniere_fleurs_tige"}, nx = 1, nz = 1},
	["jardiniere_longue"] = {cat = "Furniture", taille = Vector3.new(6.539, 1.871, 1.939), principale = "jardiniere_longue_bac", pieces = {"jardiniere_longue_bac", "jardiniere_longue_coeur", "jardiniere_longue_feuillage", "jardiniere_longue_fleur", "jardiniere_longue_fleur2", "jardiniere_longue_terreau", "jardiniere_longue_tige"}, nx = 1, nz = 1},
	["mur_baie_arche_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_brique_mur", pieces = {"mur_baie_arche_brique_cadre", "mur_baie_arche_brique_mur", "mur_baie_arche_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_clin_mur", pieces = {"mur_baie_arche_clin_cadre", "mur_baie_arche_clin_mur", "mur_baie_arche_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_crepi_mur", pieces = {"mur_baie_arche_crepi_cadre", "mur_baie_arche_crepi_mur", "mur_baie_arche_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_enduit_mur", pieces = {"mur_baie_arche_enduit_cadre", "mur_baie_arche_enduit_mur", "mur_baie_arche_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_nue_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_nue_brique_mur", pieces = {"mur_baie_arche_nue_brique_cadre", "mur_baie_arche_nue_brique_mur", "mur_baie_arche_nue_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_nue_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_nue_clin_mur", pieces = {"mur_baie_arche_nue_clin_cadre", "mur_baie_arche_nue_clin_mur", "mur_baie_arche_nue_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_nue_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_nue_crepi_mur", pieces = {"mur_baie_arche_nue_crepi_cadre", "mur_baie_arche_nue_crepi_mur", "mur_baie_arche_nue_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_nue_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_nue_enduit_mur", pieces = {"mur_baie_arche_nue_enduit_cadre", "mur_baie_arche_nue_enduit_mur", "mur_baie_arche_nue_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_nue_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_nue_pierre_mur", pieces = {"mur_baie_arche_nue_pierre_cadre", "mur_baie_arche_nue_pierre_mur", "mur_baie_arche_nue_pierre_verre"}, nx = 1, nz = 1},
	["mur_baie_arche_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_arche_pierre_mur", pieces = {"mur_baie_arche_pierre_cadre", "mur_baie_arche_pierre_mur", "mur_baie_arche_pierre_verre"}, nx = 1, nz = 1},
	["mur_baie_barreaudee_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_barreaudee_brique_mur", pieces = {"mur_baie_barreaudee_brique_cadre", "mur_baie_barreaudee_brique_mur", "mur_baie_barreaudee_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_barreaudee_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_barreaudee_clin_mur", pieces = {"mur_baie_barreaudee_clin_cadre", "mur_baie_barreaudee_clin_mur", "mur_baie_barreaudee_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_barreaudee_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_barreaudee_crepi_mur", pieces = {"mur_baie_barreaudee_crepi_cadre", "mur_baie_barreaudee_crepi_mur", "mur_baie_barreaudee_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_barreaudee_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_barreaudee_enduit_mur", pieces = {"mur_baie_barreaudee_enduit_cadre", "mur_baie_barreaudee_enduit_mur", "mur_baie_barreaudee_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_barreaudee_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_barreaudee_pierre_mur", pieces = {"mur_baie_barreaudee_pierre_cadre", "mur_baie_barreaudee_pierre_mur", "mur_baie_barreaudee_pierre_verre"}, nx = 1, nz = 1},
	["mur_baie_croisee_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_croisee_brique_mur", pieces = {"mur_baie_croisee_brique_cadre", "mur_baie_croisee_brique_mur", "mur_baie_croisee_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_croisee_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_croisee_clin_mur", pieces = {"mur_baie_croisee_clin_cadre", "mur_baie_croisee_clin_mur", "mur_baie_croisee_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_croisee_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_croisee_crepi_mur", pieces = {"mur_baie_croisee_crepi_cadre", "mur_baie_croisee_crepi_mur", "mur_baie_croisee_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_croisee_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_croisee_enduit_mur", pieces = {"mur_baie_croisee_enduit_cadre", "mur_baie_croisee_enduit_mur", "mur_baie_croisee_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_croisee_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_croisee_pierre_mur", pieces = {"mur_baie_croisee_pierre_cadre", "mur_baie_croisee_pierre_mur", "mur_baie_croisee_pierre_verre"}, nx = 1, nz = 1},
	["mur_baie_grille_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_grille_brique_mur", pieces = {"mur_baie_grille_brique_cadre", "mur_baie_grille_brique_mur", "mur_baie_grille_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_grille_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_grille_clin_mur", pieces = {"mur_baie_grille_clin_cadre", "mur_baie_grille_clin_mur", "mur_baie_grille_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_grille_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_grille_crepi_mur", pieces = {"mur_baie_grille_crepi_cadre", "mur_baie_grille_crepi_mur", "mur_baie_grille_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_grille_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_grille_enduit_mur", pieces = {"mur_baie_grille_enduit_cadre", "mur_baie_grille_enduit_mur", "mur_baie_grille_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_grille_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_grille_pierre_mur", pieces = {"mur_baie_grille_pierre_cadre", "mur_baie_grille_pierre_mur", "mur_baie_grille_pierre_verre"}, nx = 1, nz = 1},
	["mur_baie_simple_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_simple_brique_mur", pieces = {"mur_baie_simple_brique_cadre", "mur_baie_simple_brique_mur", "mur_baie_simple_brique_verre"}, nx = 1, nz = 1},
	["mur_baie_simple_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_simple_clin_mur", pieces = {"mur_baie_simple_clin_cadre", "mur_baie_simple_clin_mur", "mur_baie_simple_clin_verre"}, nx = 1, nz = 1},
	["mur_baie_simple_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_simple_crepi_mur", pieces = {"mur_baie_simple_crepi_cadre", "mur_baie_simple_crepi_mur", "mur_baie_simple_crepi_verre"}, nx = 1, nz = 1},
	["mur_baie_simple_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_simple_enduit_mur", pieces = {"mur_baie_simple_enduit_cadre", "mur_baie_simple_enduit_mur", "mur_baie_simple_enduit_verre"}, nx = 1, nz = 1},
	["mur_baie_simple_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_baie_simple_pierre_mur", pieces = {"mur_baie_simple_pierre_cadre", "mur_baie_simple_pierre_mur", "mur_baie_simple_pierre_verre"}, nx = 1, nz = 1},
	["mur_deux_baies_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_deux_baies_brique_mur", pieces = {"mur_deux_baies_brique_cadre", "mur_deux_baies_brique_mur", "mur_deux_baies_brique_verre"}, nx = 1, nz = 1},
	["mur_deux_baies_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_deux_baies_clin_mur", pieces = {"mur_deux_baies_clin_cadre", "mur_deux_baies_clin_mur", "mur_deux_baies_clin_verre"}, nx = 1, nz = 1},
	["mur_deux_baies_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_deux_baies_crepi_mur", pieces = {"mur_deux_baies_crepi_cadre", "mur_deux_baies_crepi_mur", "mur_deux_baies_crepi_verre"}, nx = 1, nz = 1},
	["mur_deux_baies_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_deux_baies_enduit_mur", pieces = {"mur_deux_baies_enduit_cadre", "mur_deux_baies_enduit_mur", "mur_deux_baies_enduit_verre"}, nx = 1, nz = 1},
	["mur_deux_baies_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_deux_baies_pierre_mur", pieces = {"mur_deux_baies_pierre_cadre", "mur_deux_baies_pierre_mur", "mur_deux_baies_pierre_verre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_croix_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_croix_brique_mur", pieces = {"mur_fenetre_arche_croix_brique_cadre", "mur_fenetre_arche_croix_brique_mur", "mur_fenetre_arche_croix_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_croix_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_croix_clin_mur", pieces = {"mur_fenetre_arche_croix_clin_cadre", "mur_fenetre_arche_croix_clin_mur", "mur_fenetre_arche_croix_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_croix_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_croix_crepi_mur", pieces = {"mur_fenetre_arche_croix_crepi_cadre", "mur_fenetre_arche_croix_crepi_mur", "mur_fenetre_arche_croix_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_croix_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_croix_enduit_mur", pieces = {"mur_fenetre_arche_croix_enduit_cadre", "mur_fenetre_arche_croix_enduit_mur", "mur_fenetre_arche_croix_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_croix_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_croix_pierre_mur", pieces = {"mur_fenetre_arche_croix_pierre_cadre", "mur_fenetre_arche_croix_pierre_mur", "mur_fenetre_arche_croix_pierre_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_pleine_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_pleine_brique_briqu", pieces = {"mur_fenetre_arche_pleine_brique_briqu", "mur_fenetre_arche_pleine_brique_cadre", "mur_fenetre_arche_pleine_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_pleine_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_pleine_clin_mur", pieces = {"mur_fenetre_arche_pleine_clin_cadre", "mur_fenetre_arche_pleine_clin_mur", "mur_fenetre_arche_pleine_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_pleine_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_pleine_crepi_mur", pieces = {"mur_fenetre_arche_pleine_crepi_cadre", "mur_fenetre_arche_pleine_crepi_mur", "mur_fenetre_arche_pleine_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_pleine_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_pleine_enduit_endui", pieces = {"mur_fenetre_arche_pleine_enduit_cadre", "mur_fenetre_arche_pleine_enduit_endui", "mur_fenetre_arche_pleine_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_pleine_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_pleine_pierre_pierr", pieces = {"mur_fenetre_arche_pleine_pierre_cadre", "mur_fenetre_arche_pleine_pierre_pierr", "mur_fenetre_arche_pleine_pierre_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_vitrine_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_vitrine_brique_bri", pieces = {"mur_fenetre_arche_vitrine_brique_bri", "mur_fenetre_arche_vitrine_brique_cadre", "mur_fenetre_arche_vitrine_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_vitrine_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_vitrine_clin_mur", pieces = {"mur_fenetre_arche_vitrine_clin_cadre", "mur_fenetre_arche_vitrine_clin_mur", "mur_fenetre_arche_vitrine_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_vitrine_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_vitrine_crepi_crep", pieces = {"mur_fenetre_arche_vitrine_crepi_cadre", "mur_fenetre_arche_vitrine_crepi_crep", "mur_fenetre_arche_vitrine_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_vitrine_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_vitrine_enduit_end", pieces = {"mur_fenetre_arche_vitrine_enduit_cadre", "mur_fenetre_arche_vitrine_enduit_end", "mur_fenetre_arche_vitrine_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_arche_vitrine_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_arche_vitrine_pierre_pie", pieces = {"mur_fenetre_arche_vitrine_pierre_cadre", "mur_fenetre_arche_vitrine_pierre_pie", "mur_fenetre_arche_vitrine_pierre_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_grille_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_grille_brique_mur", pieces = {"mur_fenetre_grille_brique_cadre", "mur_fenetre_grille_brique_mur", "mur_fenetre_grille_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_grille_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_grille_clin_mur", pieces = {"mur_fenetre_grille_clin_cadre", "mur_fenetre_grille_clin_mur", "mur_fenetre_grille_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_grille_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_grille_crepi_mur", pieces = {"mur_fenetre_grille_crepi_cadre", "mur_fenetre_grille_crepi_mur", "mur_fenetre_grille_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_grille_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_grille_enduit_mur", pieces = {"mur_fenetre_grille_enduit_cadre", "mur_fenetre_grille_enduit_mur", "mur_fenetre_grille_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_grille_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_grille_pierre_mur", pieces = {"mur_fenetre_grille_pierre_cadre", "mur_fenetre_grille_pierre_mur", "mur_fenetre_grille_pierre_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_haute_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_haute_brique_mur", pieces = {"mur_fenetre_haute_brique_cadre", "mur_fenetre_haute_brique_mur", "mur_fenetre_haute_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_haute_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_haute_clin_mur", pieces = {"mur_fenetre_haute_clin_cadre", "mur_fenetre_haute_clin_mur", "mur_fenetre_haute_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_haute_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_haute_crepi_mur", pieces = {"mur_fenetre_haute_crepi_cadre", "mur_fenetre_haute_crepi_mur", "mur_fenetre_haute_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_haute_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_haute_enduit_mur", pieces = {"mur_fenetre_haute_enduit_cadre", "mur_fenetre_haute_enduit_mur", "mur_fenetre_haute_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_haute_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_haute_pierre_mur", pieces = {"mur_fenetre_haute_pierre_cadre", "mur_fenetre_haute_pierre_mur", "mur_fenetre_haute_pierre_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_simple_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_simple_brique_mur", pieces = {"mur_fenetre_simple_brique_cadre", "mur_fenetre_simple_brique_mur", "mur_fenetre_simple_brique_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_simple_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_simple_clin_mur", pieces = {"mur_fenetre_simple_clin_cadre", "mur_fenetre_simple_clin_mur", "mur_fenetre_simple_clin_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_simple_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_simple_crepi_mur", pieces = {"mur_fenetre_simple_crepi_cadre", "mur_fenetre_simple_crepi_mur", "mur_fenetre_simple_crepi_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_simple_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_simple_enduit_mur", pieces = {"mur_fenetre_simple_enduit_cadre", "mur_fenetre_simple_enduit_mur", "mur_fenetre_simple_enduit_vitre"}, nx = 1, nz = 1},
	["mur_fenetre_simple_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_fenetre_simple_pierre_mur", pieces = {"mur_fenetre_simple_pierre_cadre", "mur_fenetre_simple_pierre_mur", "mur_fenetre_simple_pierre_vitre"}, nx = 1, nz = 1},
	["mur_muret_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 4.420, 1.000), principale = "mur_muret_brique_mur", pieces = {"mur_muret_brique_mur"}, nx = 1, nz = 1},
	["mur_muret_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 4.420, 1.000), principale = "mur_muret_clin_mur", pieces = {"mur_muret_clin_mur"}, nx = 1, nz = 1},
	["mur_muret_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 4.420, 1.000), principale = "mur_muret_crepi_mur", pieces = {"mur_muret_crepi_mur"}, nx = 1, nz = 1},
	["mur_muret_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 4.420, 1.000), principale = "mur_muret_enduit_mur", pieces = {"mur_muret_enduit_mur"}, nx = 1, nz = 1},
	["mur_muret_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 4.420, 1.000), principale = "mur_muret_pierre_mur", pieces = {"mur_muret_pierre_mur"}, nx = 1, nz = 1},
	["mur_plein_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_plein_brique_mur", pieces = {"mur_plein_brique_mur"}, nx = 1, nz = 1},
	["mur_plein_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_plein_clin_mur", pieces = {"mur_plein_clin_mur"}, nx = 1, nz = 1},
	["mur_plein_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_plein_crepi_mur", pieces = {"mur_plein_crepi_mur"}, nx = 1, nz = 1},
	["mur_plein_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_plein_enduit_mur", pieces = {"mur_plein_enduit_mur"}, nx = 1, nz = 1},
	["mur_plein_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_plein_pierre_mur", pieces = {"mur_plein_pierre_mur"}, nx = 1, nz = 1},
	["mur_porte_blanche_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_blanche_brique_mur", pieces = {"mur_porte_blanche_brique_metal", "mur_porte_blanche_brique_mur", "mur_porte_blanche_brique_structure", "mur_porte_blanche_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_blanche_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_blanche_clin_mur", pieces = {"mur_porte_blanche_clin_metal", "mur_porte_blanche_clin_mur", "mur_porte_blanche_clin_structure", "mur_porte_blanche_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_blanche_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_blanche_crepi_mur", pieces = {"mur_porte_blanche_crepi_metal", "mur_porte_blanche_crepi_mur", "mur_porte_blanche_crepi_structure", "mur_porte_blanche_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_blanche_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_blanche_enduit_mur", pieces = {"mur_porte_blanche_enduit_metal", "mur_porte_blanche_enduit_mur", "mur_porte_blanche_enduit_structure", "mur_porte_blanche_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_blanche_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_blanche_pierre_mur", pieces = {"mur_porte_blanche_pierre_metal", "mur_porte_blanche_pierre_mur", "mur_porte_blanche_pierre_structure", "mur_porte_blanche_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_bois_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_bois_brique_mur", pieces = {"mur_porte_bois_brique_metal", "mur_porte_bois_brique_mur", "mur_porte_bois_brique_structure", "mur_porte_bois_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_bois_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_bois_clin_mur", pieces = {"mur_porte_bois_clin_metal", "mur_porte_bois_clin_mur", "mur_porte_bois_clin_structure", "mur_porte_bois_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_bois_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_bois_crepi_mur", pieces = {"mur_porte_bois_crepi_metal", "mur_porte_bois_crepi_mur", "mur_porte_bois_crepi_structure", "mur_porte_bois_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_bois_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_bois_enduit_mur", pieces = {"mur_porte_bois_enduit_metal", "mur_porte_bois_enduit_mur", "mur_porte_bois_enduit_structure", "mur_porte_bois_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_bois_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_bois_pierre_mur", pieces = {"mur_porte_bois_pierre_metal", "mur_porte_bois_pierre_mur", "mur_porte_bois_pierre_structure", "mur_porte_bois_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_brique_mur", pieces = {"mur_porte_brique_cadre", "mur_porte_brique_mur"}, nx = 1, nz = 1},
	["mur_porte_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_clin_mur", pieces = {"mur_porte_clin_cadre", "mur_porte_clin_mur"}, nx = 1, nz = 1},
	["mur_porte_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_crepi_mur", pieces = {"mur_porte_crepi_cadre", "mur_porte_crepi_mur"}, nx = 1, nz = 1},
	["mur_porte_deco_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_deco_brique_mur", pieces = {"mur_porte_deco_brique_metal", "mur_porte_deco_brique_mur", "mur_porte_deco_brique_structure", "mur_porte_deco_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_deco_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_deco_clin_mur", pieces = {"mur_porte_deco_clin_metal", "mur_porte_deco_clin_mur", "mur_porte_deco_clin_structure", "mur_porte_deco_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_deco_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_deco_crepi_mur", pieces = {"mur_porte_deco_crepi_metal", "mur_porte_deco_crepi_mur", "mur_porte_deco_crepi_structure", "mur_porte_deco_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_deco_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_deco_enduit_mur", pieces = {"mur_porte_deco_enduit_metal", "mur_porte_deco_enduit_mur", "mur_porte_deco_enduit_structure", "mur_porte_deco_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_deco_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_deco_pierre_mur", pieces = {"mur_porte_deco_pierre_metal", "mur_porte_deco_pierre_mur", "mur_porte_deco_pierre_structure", "mur_porte_deco_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_double_bois_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_bois_brique_mur", pieces = {"mur_porte_double_bois_brique_bois", "mur_porte_double_bois_brique_cadre", "mur_porte_double_bois_brique_metal", "mur_porte_double_bois_brique_mur", "mur_porte_double_bois_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_double_bois_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_bois_clin_mur", pieces = {"mur_porte_double_bois_clin_bois", "mur_porte_double_bois_clin_cadre", "mur_porte_double_bois_clin_metal", "mur_porte_double_bois_clin_mur", "mur_porte_double_bois_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_double_bois_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_bois_crepi_mur", pieces = {"mur_porte_double_bois_crepi_bois", "mur_porte_double_bois_crepi_cadre", "mur_porte_double_bois_crepi_metal", "mur_porte_double_bois_crepi_mur", "mur_porte_double_bois_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_double_bois_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_bois_enduit_mur", pieces = {"mur_porte_double_bois_enduit_bois", "mur_porte_double_bois_enduit_cadre", "mur_porte_double_bois_enduit_metal", "mur_porte_double_bois_enduit_mur", "mur_porte_double_bois_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_double_bois_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_bois_pierre_mur", pieces = {"mur_porte_double_bois_pierre_bois", "mur_porte_double_bois_pierre_cadre", "mur_porte_double_bois_pierre_metal", "mur_porte_double_bois_pierre_mur", "mur_porte_double_bois_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_double_verte_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_verte_brique_mur", pieces = {"mur_porte_double_verte_brique_cadre", "mur_porte_double_verte_brique_mur", "mur_porte_double_verte_brique_sombre", "mur_porte_double_verte_brique_verre", "mur_porte_double_verte_brique_vert"}, nx = 1, nz = 1},
	["mur_porte_double_verte_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_verte_clin_mur", pieces = {"mur_porte_double_verte_clin_cadre", "mur_porte_double_verte_clin_mur", "mur_porte_double_verte_clin_sombre", "mur_porte_double_verte_clin_verre", "mur_porte_double_verte_clin_vert"}, nx = 1, nz = 1},
	["mur_porte_double_verte_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_verte_crepi_mur", pieces = {"mur_porte_double_verte_crepi_cadre", "mur_porte_double_verte_crepi_mur", "mur_porte_double_verte_crepi_sombre", "mur_porte_double_verte_crepi_verre", "mur_porte_double_verte_crepi_vert"}, nx = 1, nz = 1},
	["mur_porte_double_verte_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_verte_enduit_mur", pieces = {"mur_porte_double_verte_enduit_cadre", "mur_porte_double_verte_enduit_mur", "mur_porte_double_verte_enduit_sombre", "mur_porte_double_verte_enduit_verre", "mur_porte_double_verte_enduit_vert"}, nx = 1, nz = 1},
	["mur_porte_double_verte_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_double_verte_pierre_mur", pieces = {"mur_porte_double_verte_pierre_cadre", "mur_porte_double_verte_pierre_mur", "mur_porte_double_verte_pierre_sombre", "mur_porte_double_verte_pierre_verre", "mur_porte_double_verte_pierre_vert"}, nx = 1, nz = 1},
	["mur_porte_double_vitree_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_double_vitree_brique_mur", pieces = {"mur_porte_double_vitree_brique_cadre", "mur_porte_double_vitree_brique_metal", "mur_porte_double_vitree_brique_mur", "mur_porte_double_vitree_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_double_vitree_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_double_vitree_clin_mur", pieces = {"mur_porte_double_vitree_clin_cadre", "mur_porte_double_vitree_clin_metal", "mur_porte_double_vitree_clin_mur", "mur_porte_double_vitree_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_double_vitree_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_double_vitree_crepi_mur", pieces = {"mur_porte_double_vitree_crepi_cadre", "mur_porte_double_vitree_crepi_metal", "mur_porte_double_vitree_crepi_mur", "mur_porte_double_vitree_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_double_vitree_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_double_vitree_enduit_mur", pieces = {"mur_porte_double_vitree_enduit_cadre", "mur_porte_double_vitree_enduit_metal", "mur_porte_double_vitree_enduit_mur", "mur_porte_double_vitree_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_double_vitree_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_double_vitree_pierre_mur", pieces = {"mur_porte_double_vitree_pierre_cadre", "mur_porte_double_vitree_pierre_metal", "mur_porte_double_vitree_pierre_mur", "mur_porte_double_vitree_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_enduit_mur", pieces = {"mur_porte_enduit_cadre", "mur_porte_enduit_mur"}, nx = 1, nz = 1},
	["mur_porte_garage_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_garage_brique_mur", pieces = {"mur_porte_garage_brique_blanc", "mur_porte_garage_brique_mur", "mur_porte_garage_brique_sombre", "mur_porte_garage_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_garage_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_garage_clin_mur", pieces = {"mur_porte_garage_clin_blanc", "mur_porte_garage_clin_mur", "mur_porte_garage_clin_sombre", "mur_porte_garage_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_garage_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_garage_crepi_mur", pieces = {"mur_porte_garage_crepi_blanc", "mur_porte_garage_crepi_mur", "mur_porte_garage_crepi_sombre", "mur_porte_garage_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_garage_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_garage_enduit_mur", pieces = {"mur_porte_garage_enduit_blanc", "mur_porte_garage_enduit_mur", "mur_porte_garage_enduit_sombre", "mur_porte_garage_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_garage_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.000), principale = "mur_porte_garage_pierre_mur", pieces = {"mur_porte_garage_pierre_blanc", "mur_porte_garage_pierre_mur", "mur_porte_garage_pierre_sombre", "mur_porte_garage_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_imposte_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_imposte_brique_mur", pieces = {"mur_porte_imposte_brique_cadre", "mur_porte_imposte_brique_mur", "mur_porte_imposte_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_imposte_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_imposte_clin_mur", pieces = {"mur_porte_imposte_clin_cadre", "mur_porte_imposte_clin_mur", "mur_porte_imposte_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_imposte_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_imposte_crepi_mur", pieces = {"mur_porte_imposte_crepi_cadre", "mur_porte_imposte_crepi_mur", "mur_porte_imposte_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_imposte_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_imposte_enduit_mur", pieces = {"mur_porte_imposte_enduit_cadre", "mur_porte_imposte_enduit_mur", "mur_porte_imposte_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_imposte_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_imposte_pierre_mur", pieces = {"mur_porte_imposte_pierre_cadre", "mur_porte_imposte_pierre_mur", "mur_porte_imposte_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_porte_pierre_mur", pieces = {"mur_porte_pierre_cadre", "mur_porte_pierre_mur"}, nx = 1, nz = 1},
	["mur_porte_pleine_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_pleine_brique_mur", pieces = {"mur_porte_pleine_brique_metal", "mur_porte_pleine_brique_mur", "mur_porte_pleine_brique_structure", "mur_porte_pleine_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_pleine_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_pleine_clin_mur", pieces = {"mur_porte_pleine_clin_metal", "mur_porte_pleine_clin_mur", "mur_porte_pleine_clin_structure", "mur_porte_pleine_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_pleine_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_pleine_crepi_mur", pieces = {"mur_porte_pleine_crepi_metal", "mur_porte_pleine_crepi_mur", "mur_porte_pleine_crepi_structure", "mur_porte_pleine_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_pleine_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_pleine_enduit_mur", pieces = {"mur_porte_pleine_enduit_metal", "mur_porte_pleine_enduit_mur", "mur_porte_pleine_enduit_structure", "mur_porte_pleine_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_pleine_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_pleine_pierre_mur", pieces = {"mur_porte_pleine_pierre_metal", "mur_porte_pleine_pierre_mur", "mur_porte_pleine_pierre_structure", "mur_porte_pleine_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_service_bois_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_bois_brique_mur", pieces = {"mur_porte_service_bois_brique_bois", "mur_porte_service_bois_brique_cadre", "mur_porte_service_bois_brique_metal", "mur_porte_service_bois_brique_mur", "mur_porte_service_bois_brique_signB", "mur_porte_service_bois_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_service_bois_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_bois_clin_mur", pieces = {"mur_porte_service_bois_clin_bois", "mur_porte_service_bois_clin_cadre", "mur_porte_service_bois_clin_metal", "mur_porte_service_bois_clin_mur", "mur_porte_service_bois_clin_signB", "mur_porte_service_bois_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_service_bois_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_bois_crepi_mur", pieces = {"mur_porte_service_bois_crepi_bois", "mur_porte_service_bois_crepi_cadre", "mur_porte_service_bois_crepi_metal", "mur_porte_service_bois_crepi_mur", "mur_porte_service_bois_crepi_signB", "mur_porte_service_bois_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_service_bois_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_bois_enduit_mur", pieces = {"mur_porte_service_bois_enduit_bois", "mur_porte_service_bois_enduit_cadre", "mur_porte_service_bois_enduit_metal", "mur_porte_service_bois_enduit_mur", "mur_porte_service_bois_enduit_signB", "mur_porte_service_bois_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_service_bois_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_bois_pierre_mur", pieces = {"mur_porte_service_bois_pierre_bois", "mur_porte_service_bois_pierre_cadre", "mur_porte_service_bois_pierre_metal", "mur_porte_service_bois_pierre_mur", "mur_porte_service_bois_pierre_signB", "mur_porte_service_bois_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_service_verte_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_verte_brique_mur", pieces = {"mur_porte_service_verte_brique_cadre", "mur_porte_service_verte_brique_metal", "mur_porte_service_verte_brique_mur", "mur_porte_service_verte_brique_signN", "mur_porte_service_verte_brique_verre", "mur_porte_service_verte_brique_vert"}, nx = 1, nz = 1},
	["mur_porte_service_verte_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_verte_clin_mur", pieces = {"mur_porte_service_verte_clin_cadre", "mur_porte_service_verte_clin_metal", "mur_porte_service_verte_clin_mur", "mur_porte_service_verte_clin_signN", "mur_porte_service_verte_clin_verre", "mur_porte_service_verte_clin_vert"}, nx = 1, nz = 1},
	["mur_porte_service_verte_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_verte_crepi_mur", pieces = {"mur_porte_service_verte_crepi_cadre", "mur_porte_service_verte_crepi_metal", "mur_porte_service_verte_crepi_mur", "mur_porte_service_verte_crepi_signN", "mur_porte_service_verte_crepi_verre", "mur_porte_service_verte_crepi_vert"}, nx = 1, nz = 1},
	["mur_porte_service_verte_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_verte_enduit_mur", pieces = {"mur_porte_service_verte_enduit_cadre", "mur_porte_service_verte_enduit_metal", "mur_porte_service_verte_enduit_mur", "mur_porte_service_verte_enduit_signN", "mur_porte_service_verte_enduit_verre", "mur_porte_service_verte_enduit_vert"}, nx = 1, nz = 1},
	["mur_porte_service_verte_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.009), principale = "mur_porte_service_verte_pierre_mur", pieces = {"mur_porte_service_verte_pierre_cadre", "mur_porte_service_verte_pierre_metal", "mur_porte_service_verte_pierre_mur", "mur_porte_service_verte_pierre_signN", "mur_porte_service_verte_pierre_verre", "mur_porte_service_verte_pierre_vert"}, nx = 1, nz = 1},
	["mur_porte_service_vitree_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_service_vitree_brique_briqu", pieces = {"mur_porte_service_vitree_brique_briqu", "mur_porte_service_vitree_brique_cadre", "mur_porte_service_vitree_brique_metal", "mur_porte_service_vitree_brique_verre"}, nx = 1, nz = 1},
	["mur_porte_service_vitree_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_service_vitree_clin_mur", pieces = {"mur_porte_service_vitree_clin_cadre", "mur_porte_service_vitree_clin_metal", "mur_porte_service_vitree_clin_mur", "mur_porte_service_vitree_clin_verre"}, nx = 1, nz = 1},
	["mur_porte_service_vitree_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_service_vitree_crepi_mur", pieces = {"mur_porte_service_vitree_crepi_cadre", "mur_porte_service_vitree_crepi_metal", "mur_porte_service_vitree_crepi_mur", "mur_porte_service_vitree_crepi_verre"}, nx = 1, nz = 1},
	["mur_porte_service_vitree_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_service_vitree_enduit_endui", pieces = {"mur_porte_service_vitree_enduit_cadre", "mur_porte_service_vitree_enduit_endui", "mur_porte_service_vitree_enduit_metal", "mur_porte_service_vitree_enduit_verre"}, nx = 1, nz = 1},
	["mur_porte_service_vitree_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.155), principale = "mur_porte_service_vitree_pierre_pierr", pieces = {"mur_porte_service_vitree_pierre_cadre", "mur_porte_service_vitree_pierre_metal", "mur_porte_service_vitree_pierre_pierr", "mur_porte_service_vitree_pierre_verre"}, nx = 1, nz = 1},
	["mur_porte_simple_blanche_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_blanche_brique_briqu", pieces = {"mur_porte_simple_blanche_brique_briqu", "mur_porte_simple_blanche_brique_metal", "mur_porte_simple_blanche_brique_structure", "mur_porte_simple_blanche_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_blanche_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_blanche_clin_mur", pieces = {"mur_porte_simple_blanche_clin_metal", "mur_porte_simple_blanche_clin_mur", "mur_porte_simple_blanche_clin_structure", "mur_porte_simple_blanche_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_blanche_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_blanche_crepi_mur", pieces = {"mur_porte_simple_blanche_crepi_metal", "mur_porte_simple_blanche_crepi_mur", "mur_porte_simple_blanche_crepi_structure", "mur_porte_simple_blanche_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_blanche_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_blanche_enduit_endui", pieces = {"mur_porte_simple_blanche_enduit_endui", "mur_porte_simple_blanche_enduit_metal", "mur_porte_simple_blanche_enduit_structure", "mur_porte_simple_blanche_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_blanche_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_blanche_pierre_pierr", pieces = {"mur_porte_simple_blanche_pierre_metal", "mur_porte_simple_blanche_pierre_pierr", "mur_porte_simple_blanche_pierre_structure", "mur_porte_simple_blanche_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_bois_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_bois_brique_mur", pieces = {"mur_porte_simple_bois_brique_metal", "mur_porte_simple_bois_brique_mur", "mur_porte_simple_bois_brique_structure", "mur_porte_simple_bois_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_bois_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_bois_clin_mur", pieces = {"mur_porte_simple_bois_clin_metal", "mur_porte_simple_bois_clin_mur", "mur_porte_simple_bois_clin_structure", "mur_porte_simple_bois_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_bois_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_bois_crepi_mur", pieces = {"mur_porte_simple_bois_crepi_metal", "mur_porte_simple_bois_crepi_mur", "mur_porte_simple_bois_crepi_structure", "mur_porte_simple_bois_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_bois_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_bois_enduit_mur", pieces = {"mur_porte_simple_bois_enduit_metal", "mur_porte_simple_bois_enduit_mur", "mur_porte_simple_bois_enduit_structure", "mur_porte_simple_bois_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_bois_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.291), principale = "mur_porte_simple_bois_pierre_mur", pieces = {"mur_porte_simple_bois_pierre_metal", "mur_porte_simple_bois_pierre_mur", "mur_porte_simple_bois_pierre_structure", "mur_porte_simple_bois_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_deco_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_simple_deco_brique_mur", pieces = {"mur_porte_simple_deco_brique_metal", "mur_porte_simple_deco_brique_mur", "mur_porte_simple_deco_brique_structure", "mur_porte_simple_deco_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_deco_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_simple_deco_clin_mur", pieces = {"mur_porte_simple_deco_clin_metal", "mur_porte_simple_deco_clin_mur", "mur_porte_simple_deco_clin_structure", "mur_porte_simple_deco_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_deco_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_simple_deco_crepi_mur", pieces = {"mur_porte_simple_deco_crepi_metal", "mur_porte_simple_deco_crepi_mur", "mur_porte_simple_deco_crepi_structure", "mur_porte_simple_deco_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_deco_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_simple_deco_enduit_mur", pieces = {"mur_porte_simple_deco_enduit_metal", "mur_porte_simple_deco_enduit_mur", "mur_porte_simple_deco_enduit_structure", "mur_porte_simple_deco_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_deco_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.218), principale = "mur_porte_simple_deco_pierre_mur", pieces = {"mur_porte_simple_deco_pierre_metal", "mur_porte_simple_deco_pierre_mur", "mur_porte_simple_deco_pierre_structure", "mur_porte_simple_deco_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_pleine_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_simple_pleine_brique_mur", pieces = {"mur_porte_simple_pleine_brique_metal", "mur_porte_simple_pleine_brique_mur", "mur_porte_simple_pleine_brique_structure", "mur_porte_simple_pleine_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_pleine_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_simple_pleine_clin_mur", pieces = {"mur_porte_simple_pleine_clin_metal", "mur_porte_simple_pleine_clin_mur", "mur_porte_simple_pleine_clin_structure", "mur_porte_simple_pleine_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_pleine_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_simple_pleine_crepi_mur", pieces = {"mur_porte_simple_pleine_crepi_metal", "mur_porte_simple_pleine_crepi_mur", "mur_porte_simple_pleine_crepi_structure", "mur_porte_simple_pleine_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_pleine_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_simple_pleine_enduit_mur", pieces = {"mur_porte_simple_pleine_enduit_metal", "mur_porte_simple_pleine_enduit_mur", "mur_porte_simple_pleine_enduit_structure", "mur_porte_simple_pleine_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_pleine_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.364), principale = "mur_porte_simple_pleine_pierre_mur", pieces = {"mur_porte_simple_pleine_pierre_metal", "mur_porte_simple_pleine_pierre_mur", "mur_porte_simple_pleine_pierre_structure", "mur_porte_simple_pleine_pierre_vitre"}, nx = 1, nz = 1},
	["mur_porte_simple_verre_sombre_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_simple_verre_sombre_brique_so", pieces = {"mur_porte_simple_verre_sombre_brique_so", "mur_porte_simple_verre_sombre_brique_so2", "mur_porte_simple_verre_sombre_brique_sombre"}, nx = 1, nz = 1},
	["mur_porte_simple_verre_sombre_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_simple_verre_sombre_clin_somb", pieces = {"mur_porte_simple_verre_sombre_clin_s", "mur_porte_simple_verre_sombre_clin_somb", "mur_porte_simple_verre_sombre_clin_v"}, nx = 1, nz = 1},
	["mur_porte_simple_verre_sombre_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_simple_verre_sombre_crepi_som", pieces = {"mur_porte_simple_verre_sombre_crepi_", "mur_porte_simple_verre_sombre_crepi_som", "mur_porte_simple_verre_sombre_crepi_som2"}, nx = 1, nz = 1},
	["mur_porte_simple_verre_sombre_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_simple_verre_sombre_enduit_so", pieces = {"mur_porte_simple_verre_sombre_enduit_so", "mur_porte_simple_verre_sombre_enduit_so2", "mur_porte_simple_verre_sombre_enduit_sombre"}, nx = 1, nz = 1},
	["mur_porte_simple_verre_sombre_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_simple_verre_sombre_pierre_so", pieces = {"mur_porte_simple_verre_sombre_pierre_so", "mur_porte_simple_verre_sombre_pierre_so2", "mur_porte_simple_verre_sombre_pierre_sombre"}, nx = 1, nz = 1},
	["mur_porte_verre_sombre_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_verre_sombre_brique_mur", pieces = {"mur_porte_verre_sombre_brique_mur", "mur_porte_verre_sombre_brique_structure", "mur_porte_verre_sombre_brique_vitre"}, nx = 1, nz = 1},
	["mur_porte_verre_sombre_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_verre_sombre_clin_mur", pieces = {"mur_porte_verre_sombre_clin_mur", "mur_porte_verre_sombre_clin_structure", "mur_porte_verre_sombre_clin_vitre"}, nx = 1, nz = 1},
	["mur_porte_verre_sombre_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_verre_sombre_crepi_mur", pieces = {"mur_porte_verre_sombre_crepi_mur", "mur_porte_verre_sombre_crepi_structure", "mur_porte_verre_sombre_crepi_vitre"}, nx = 1, nz = 1},
	["mur_porte_verre_sombre_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_verre_sombre_enduit_mur", pieces = {"mur_porte_verre_sombre_enduit_mur", "mur_porte_verre_sombre_enduit_structure", "mur_porte_verre_sombre_enduit_vitre"}, nx = 1, nz = 1},
	["mur_porte_verre_sombre_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.436), principale = "mur_porte_verre_sombre_pierre_mur", pieces = {"mur_porte_verre_sombre_pierre_mur", "mur_porte_verre_sombre_pierre_structure", "mur_porte_verre_sombre_pierre_vitre"}, nx = 1, nz = 1},
	["mur_vitrine_brique"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_vitrine_brique_mur", pieces = {"mur_vitrine_brique_cadre", "mur_vitrine_brique_mur", "mur_vitrine_brique_verre"}, nx = 1, nz = 1},
	["mur_vitrine_clin"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_vitrine_clin_mur", pieces = {"mur_vitrine_clin_cadre", "mur_vitrine_clin_mur", "mur_vitrine_clin_verre"}, nx = 1, nz = 1},
	["mur_vitrine_crepi"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_vitrine_crepi_mur", pieces = {"mur_vitrine_crepi_cadre", "mur_vitrine_crepi_mur", "mur_vitrine_crepi_verre"}, nx = 1, nz = 1},
	["mur_vitrine_enduit"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_vitrine_enduit_mur", pieces = {"mur_vitrine_enduit_cadre", "mur_vitrine_enduit_mur", "mur_vitrine_enduit_verre"}, nx = 1, nz = 1},
	["mur_vitrine_pierre"] = {cat = "Mur", taille = Vector3.new(10.000, 16.000, 1.036), principale = "mur_vitrine_pierre_mur", pieces = {"mur_vitrine_pierre_cadre", "mur_vitrine_pierre_mur", "mur_vitrine_pierre_verre"}, nx = 1, nz = 1},
	["pot_buisson"] = {cat = "Furniture", taille = Vector3.new(4.340, 5.687, 4.229), principale = "pot_buisson_feuillage", pieces = {"pot_buisson_feuillage", "pot_buisson_pierre", "pot_buisson_terreau"}, nx = 1, nz = 1},
	["pot_cactus"] = {cat = "Furniture", taille = Vector3.new(3.410, 5.931, 3.410), principale = "pot_cactus_terrecuite", pieces = {"pot_cactus_cactus", "pot_cactus_terreau", "pot_cactus_terrecuite"}, nx = 1, nz = 1},
	["rayonnage_vide"] = {cat = "Furniture", taille = Vector3.new(20.000, 15.500, 10.812), principale = "rayonnage_vide_mur", pieces = {"rayonnage_vide_mur"}, nx = 2, nz = 1},
	["sol_ardoise"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_ardoise_mur", pieces = {"sol_ardoise_mur"}, nx = 1, nz = 1},
	["sol_batons_rompus"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_batons_rompus_mur", pieces = {"sol_batons_rompus_mur"}, nx = 1, nz = 1},
	["sol_beton"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_beton_mur", pieces = {"sol_beton_mur"}, nx = 1, nz = 1},
	["sol_briques"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_briques_mur", pieces = {"sol_briques_mur"}, nx = 1, nz = 1},
	["sol_carrelage_gris"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_carrelage_gris_mur", pieces = {"sol_carrelage_gris_mur"}, nx = 1, nz = 1},
	["sol_chene_dore"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_chene_dore_mur", pieces = {"sol_chene_dore_mur"}, nx = 1, nz = 1},
	["sol_chene_rustique"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_chene_rustique_mur", pieces = {"sol_chene_rustique_mur"}, nx = 1, nz = 1},
	["sol_chevron"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_chevron_mur", pieces = {"sol_chevron_mur"}, nx = 1, nz = 1},
	["sol_chevron_pale"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_chevron_pale_mur", pieces = {"sol_chevron_pale_mur"}, nx = 1, nz = 1},
	["sol_damier"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_damier_mur", pieces = {"sol_damier_mur"}, nx = 1, nz = 1},
	["sol_echelle"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_echelle_mur", pieces = {"sol_echelle_mur"}, nx = 1, nz = 1},
	["sol_galets"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_galets_mur", pieces = {"sol_galets_mur"}, nx = 1, nz = 1},
	["sol_goudron"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_goudron_mur", pieces = {"sol_goudron_mur"}, nx = 1, nz = 1},
	["sol_graviers"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_graviers_mur", pieces = {"sol_graviers_mur"}, nx = 1, nz = 1},
	["sol_marbre"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_marbre_mur", pieces = {"sol_marbre_mur"}, nx = 1, nz = 1},
	["sol_moquette"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_moquette_mur", pieces = {"sol_moquette_mur"}, nx = 1, nz = 1},
	["sol_mosaique"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_mosaique_mur", pieces = {"sol_mosaique_mur"}, nx = 1, nz = 1},
	["sol_parquet_chevron"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_chevron_mur", pieces = {"sol_parquet_chevron_mur"}, nx = 1, nz = 1},
	["sol_parquet_clair"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_clair_mur", pieces = {"sol_parquet_clair_mur"}, nx = 1, nz = 1},
	["sol_parquet_fonce"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_fonce_mur", pieces = {"sol_parquet_fonce_mur"}, nx = 1, nz = 1},
	["sol_parquet_larges"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_larges_mur", pieces = {"sol_parquet_larges_mur"}, nx = 1, nz = 1},
	["sol_parquet_rouge"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_rouge_mur", pieces = {"sol_parquet_rouge_mur"}, nx = 1, nz = 1},
	["sol_parquet_vieilli"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_parquet_vieilli_mur", pieces = {"sol_parquet_vieilli_mur"}, nx = 1, nz = 1},
	["sol_paves"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_paves_mur", pieces = {"sol_paves_mur"}, nx = 1, nz = 1},
	["sol_planches_fines"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_planches_fines_mur", pieces = {"sol_planches_fines_mur"}, nx = 1, nz = 1},
	["sol_planches_larges"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_planches_larges_mur", pieces = {"sol_planches_larges_mur"}, nx = 1, nz = 1},
	["sol_route"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_route_mur", pieces = {"sol_route_mur"}, nx = 1, nz = 1},
	["sol_terrazzo"] = {cat = "Sol", taille = Vector3.new(10.000, 0.300, 10.000), principale = "sol_terrazzo_mur", pieces = {"sol_terrazzo_mur"}, nx = 1, nz = 1},
	["toit"] = {cat = "Plafond", taille = Vector3.new(10.000, 0.860, 10.000), principale = "toit_mur", pieces = {"toit_mur"}, nx = 1, nz = 1},
	["toit_angle"] = {cat = "Plafond", taille = Vector3.new(10.132, 2.060, 10.132), principale = "toit_angle_gravier", pieces = {"toit_angle_acrotere", "toit_angle_gravier"}, nx = 1, nz = 1},
	["toit_bac"] = {cat = "Plafond", taille = Vector3.new(10.000, 0.860, 10.000), principale = "toit_bac_cadre", pieces = {"toit_bac_bac", "toit_bac_cadre"}, nx = 1, nz = 1},
	["toit_bac_angle"] = {cat = "Plafond", taille = Vector3.new(10.189, 1.480, 10.094), principale = "toit_bac_angle_cadre", pieces = {"toit_bac_angle_bac", "toit_bac_angle_cadre"}, nx = 1, nz = 1},
	["toit_bac_angle2"] = {cat = "Plafond", taille = Vector3.new(10.189, 1.480, 10.094), principale = "toit_bac_angle2_cadre", pieces = {"toit_bac_angle2_bac", "toit_bac_angle2_cadre"}, nx = 1, nz = 1},
	["toit_bac_bord_x"] = {cat = "Plafond", taille = Vector3.new(10.094, 1.480, 10.000), principale = "toit_bac_bord_x_cadre", pieces = {"toit_bac_bord_x_bac", "toit_bac_bord_x_cadre"}, nx = 1, nz = 1},
	["toit_bac_bord_y"] = {cat = "Plafond", taille = Vector3.new(10.189, 1.480, 10.094), principale = "toit_bac_bord_y_cadre", pieces = {"toit_bac_bord_y_bac", "toit_bac_bord_y_cadre"}, nx = 1, nz = 1},
	["toit_bord"] = {cat = "Plafond", taille = Vector3.new(10.132, 2.060, 10.000), principale = "toit_bord_gravier", pieces = {"toit_bord_acrotere", "toit_bord_gravier"}, nx = 1, nz = 1},
	["toit_clair"] = {cat = "Plafond", taille = Vector3.new(10.000, 0.600, 10.000), principale = "toit_clair_clair", pieces = {"toit_clair_clair"}, nx = 1, nz = 1},
	["toit_clair_angle"] = {cat = "Plafond", taille = Vector3.new(10.132, 2.060, 10.132), principale = "toit_clair_angle_clair", pieces = {"toit_clair_angle_acrotere", "toit_clair_angle_clair", "toit_clair_angle_vert"}, nx = 1, nz = 1},
	["toit_clair_bord"] = {cat = "Plafond", taille = Vector3.new(10.132, 2.060, 10.000), principale = "toit_clair_bord_clair", pieces = {"toit_clair_bord_acrotere", "toit_clair_bord_clair", "toit_clair_bord_vert"}, nx = 1, nz = 1},
	["toit_membrane"] = {cat = "Plafond", taille = Vector3.new(10.000, 0.600, 10.000), principale = "toit_membrane_membrane", pieces = {"toit_membrane_membrane"}, nx = 1, nz = 1},
	["toit_plat"] = {cat = "Plafond", taille = Vector3.new(10.000, 0.600, 10.000), principale = "toit_plat_gravier", pieces = {"toit_plat_gravier"}, nx = 1, nz = 1},
	["topiaire_boule"] = {cat = "Furniture", taille = Vector3.new(3.280, 5.750, 3.123), principale = "topiaire_boule_feuillage", pieces = {"topiaire_boule_feuillage", "topiaire_boule_pierre", "topiaire_boule_terreau", "topiaire_boule_tronc"}, nx = 1, nz = 1},
	["topiaire_cone"] = {cat = "Furniture", taille = Vector3.new(2.420, 7.208, 2.420), principale = "topiaire_cone_feuillage", pieces = {"topiaire_cone_feuillage", "topiaire_cone_pierre", "topiaire_cone_terreau"}, nx = 1, nz = 1},
}

local RS = game:GetService("ReplicatedStorage")

local function boiteMonde(parts)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		local cf, s = p.CFrame, p.Size / 2
		for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			local c = cf:PointToWorldSpace(Vector3.new(s.X * sx, s.Y * sy, s.Z * sz))
			lo = lo:Min(c); hi = hi:Max(c)
		end end end
	end
	return lo, hi
end

local function estVerre(p)
	local n = string.lower(p.Name)
	return p.Transparency > 0.05 or n:find("verre") or n:find("vitre") or n:find("_glass")
end

-- piece principale (dalle / pan de mur) : celle du catalogue, sinon la plus grande
local function piecePrincipale(info, parts)
	for _, p in ipairs(parts) do if p.Name == info.principale then return p end end
	local best, principale = -1, nil
	for _, p in ipairs(parts) do local v = p.Size.X * p.Size.Z + p.Size.X * p.Size.Y + p.Size.Y * p.Size.Z if v > best then best = v principale = p end end
	return principale
end

-- pivot attendu par le jeu (repere du monde, calcule sur les pieces telles qu'elles sont posees)
local function calculerPivot(info, parts, principale)
	local lo, hi = boiteMonde(parts)
	local plo, phi = boiteMonde({principale})
	local pc = (plo + phi) / 2
	if info.cat == "Sol" then
		return CFrame.new(pc.X, phi.Y - SOL_DESSUS, pc.Z)                              -- dessus de la dalle a +0.5
	elseif info.cat == "Plafond" then
		return CFrame.new(pc.X, lo.Y, pc.Z)                                            -- dessous du toit au sommet des murs
	elseif info.cat == "Mur" then
		-- pan de mur : longueur = axe horizontal le plus long, epaisseur = l'autre ; face avant = cote des saillies
		local d = phi - plo
		local axeEp = (d.X < d.Z) and Vector3.xAxis or Vector3.zAxis
		local saillieP, saillieM = 0, 0
		for _, p in ipairs(parts) do
			if p ~= principale then
				local l2, h2 = boiteMonde({p})
				saillieP = math.max(saillieP, h2:Dot(axeEp) - phi:Dot(axeEp))
				saillieM = math.max(saillieM, plo:Dot(axeEp) - l2:Dot(axeEp))
			end
		end
		local avant
		if saillieM > saillieP + 0.03 then avant = -axeEp
		elseif saillieP > saillieM + 0.03 then avant = axeEp
		else avant = -axeEp end                                                          -- symetrique : face avant = -Z (convention du pack)
		local pos = Vector3.new(pc.X, plo.Y - SOL_DESSUS, pc.Z) - avant * 5               -- pivot 5 studs derriere le mur, bas du mur au sol
		return CFrame.fromMatrix(pos, avant, Vector3.yAxis)                               -- X local = vers l'avant, Z local = le long du mur
	else
		-- decor : 1 case = pivot au centre ; plusieurs cases = centre de la premiere case (x min, z min)
		local cx = (info.nx > 1) and (lo.X + 5) or (lo.X + hi.X) / 2
		local cz = (info.nz > 1) and (lo.Z + 5) or (lo.Z + hi.Z) / 2
		return CFrame.new(cx, lo.Y + (MEUBLE_Y - SOL_DESSUS), cz)                       -- bas du meuble pose sur le sol
	end
end

-- Le pivot d'un Model qui a un PrimaryPart est celui du PrimaryPart (CFrame * PivotOffset) : WorldPivot est ignore.
-- L'import 3D laisse dans PivotOffset l'origine du FBX (un coin de la dalle) : on ecrit donc le pivot voulu dans
-- PivotOffset, ce qui rend GetPivot / PivotTo exacts quel que soit le chemin utilise par le jeu.
local function appliquerPivot(modele, principale, pivot)
	principale.PivotOffset = principale.CFrame:ToObjectSpace(pivot)
	modele.PrimaryPart = principale
	modele.WorldPivot = pivot
end

-- Passe de correction sur les constructions deja installees (relancable) : renvoie le nombre corrige
local function corrigerPivots()
	local corriges = 0
	for nom, info in pairs(CONSTRUCTIONS) do
		local dossier = RS:FindFirstChild(info.cat)
		local modele = dossier and dossier:FindFirstChild(nom)
		if modele and modele:IsA("Model") and not modele:FindFirstChild("Provisoire") then
			local parts = {}
			for _, d in ipairs(modele:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end
			local principale = modele.PrimaryPart or piecePrincipale(info, parts)
			if principale and #parts > 0 then
				local pivot = calculerPivot(info, parts, principale)
				local ecart = (modele:GetPivot().Position - pivot.Position).Magnitude
					+ (modele:GetPivot().LookVector - pivot.LookVector).Magnitude
				if ecart > 1e-3 then
					appliquerPivot(modele, principale, pivot)
					corriges += 1
				end
			end
		end
	end
	return corriges
end

local function installer()
local Selection = game:GetService("Selection")
local InsertService = game:GetService("InsertService")

-- 0. constructions deja en place : pivots verifies / corriges, et rien a charger si tout est installe
local corriges = corrigerPivots()
if corriges > 0 then print(("[Installer] pivots corriges sur %d constructions deja installees"):format(corriges)) end
local aFaire = 0
for nom, info in pairs(CONSTRUCTIONS) do
	local dossier = RS:FindFirstChild(info.cat)
	local ancien = dossier and dossier:FindFirstChild(nom)
	if not ancien or ancien:FindFirstChild("Provisoire") or FORCER then aFaire += 1 end
end
if aFaire == 0 then
	print("[Installer] toutes les constructions sont deja installees (pivots verifies).")
	return 0, 0
end

-- modele importe : selection, sinon un Model de Workspace dont le nom commence par PACK_10, sinon chargement de l'asset
local racine = Selection:Get()[1]
if racine and not (racine:IsA("Model") and string.sub(racine.Name, 1, 7) == "PACK_10") then racine = nil end
if not racine then
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and string.sub(m.Name, 1, 7) == "PACK_10" then racine = m break end
	end
end
local chargeParScript = false
if not racine then
	print("[Installer] chargement de l'asset", ID_PACK, "…")
	local ok, conteneur = pcall(function() return InsertService:LoadAsset(ID_PACK) end)
	assert(ok and conteneur, "Impossible de charger l'asset " .. tostring(ID_PACK) .. " : " .. tostring(conteneur) .. " (connecte-toi dans Studio avec le compte proprietaire, ou importe le FBX dans Workspace)")
	racine = conteneur:FindFirstChildWhichIsA("Model") or conteneur
	racine.Parent = workspace
	conteneur:Destroy()
	chargeParScript = true
end
print("[Installer] modele importe :", racine:GetFullName())

-- index des descendants par nom (rapide)
local parNom = {}
for _, d in ipairs(racine:GetDescendants()) do
	parNom[d.Name] = parNom[d.Name] or {}
	table.insert(parNom[d.Name], d)
end

local installes, ignores, manquants = 0, 0, {}

for nom, info in pairs(CONSTRUCTIONS) do
	local dossier = RS:FindFirstChild(info.cat)
	if not dossier then dossier = Instance.new("Folder"); dossier.Name = info.cat; dossier.Parent = RS end
	local ancien = dossier:FindFirstChild(nom)
	if ancien and not ancien:FindFirstChild("Provisoire") and not FORCER then
		ignores += 1
		continue
	end

	-- 1. pieces importees : d'abord un Model du meme nom, sinon les MeshParts nommes comme dans le FBX
	local sources = {}
	local groupe = nil
	for _, d in ipairs(parNom[nom] or {}) do if d:IsA("Model") then groupe = d break end end
	if groupe then
		for _, d in ipairs(groupe:GetDescendants()) do if d:IsA("BasePart") then table.insert(sources, d) end end
	else
		for _, pn in ipairs(info.pieces) do
			for _, d in ipairs(parNom[pn] or {}) do if d:IsA("BasePart") then table.insert(sources, d) break end end
		end
	end
	if #sources == 0 then table.insert(manquants, nom) continue end

	-- 2. nouveau modele a plat : une copie de chaque piece (avec ses SurfaceAppearance / textures)
	local modele = Instance.new("Model"); modele.Name = nom
	local parts = {}
	for _, s in ipairs(sources) do
		local c = s:Clone()
		for _, ch in ipairs(c:GetChildren()) do
			if ch:IsA("BaseScript") or ch:IsA("JointInstance") or ch:IsA("Attachment") then ch:Destroy() end
		end
		c.PivotOffset = CFrame.new()
		c.Parent = modele
		table.insert(parts, c)
	end
	modele.Parent = workspace   -- temporaire (ScaleTo et GetBoundingBox veulent un modele dans le monde)

	-- 3. echelle : la hauteur importee doit valoir la hauteur du FBX (1 unite = 1 stud)
	local lo, hi = boiteMonde(parts)
	local h = hi.Y - lo.Y
	if h > 1e-4 then
		local ratio = info.taille.Y / h
		if math.abs(ratio - 1) > 0.02 then
			warn(("[Installer] %s : echelle corrigee x%.3f (importe %.2f studs de haut, attendu %.2f)"):format(nom, ratio, h, info.taille.Y))
			modele.WorldPivot = CFrame.new(lo)
			modele:ScaleTo(ratio)
		end
	end

	-- 4. piece principale (dalle / pan de mur) et proprietes physiques
	local principale = piecePrincipale(info, parts)
	for _, p in ipairs(parts) do
		p.Anchored = true
		p.CanTouch = false
		p.CanQuery = true
		p.CanCollide = not estVerre(p)
		if estVerre(p) and p.Transparency < 0.3 then p.Transparency = 0.45 end
	end

	-- 5. pivot selon la categorie (PivotOffset de la piece principale, voir appliquerPivot)
	appliquerPivot(modele, principale, calculerPivot(info, parts, principale))
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- 6. remplacement dans ReplicatedStorage
	if ancien then ancien:Destroy() end
	modele.Parent = dossier
	installes += 1
end

print(("[Installer] %d constructions installees, %d deja en place (ignorees), %d introuvables dans l'import"):format(installes, ignores, #manquants))
if #manquants > 0 then warn("[Installer] introuvables : " .. table.concat(manquants, ", ")) end
if chargeParScript then racine:Destroy(); print("[Installer] Modele charge par le script supprime de Workspace.") else print("[Installer] Tu peux supprimer le modele importe de Workspace.") end
print("[Installer] Enregistre / publie la place pour conserver les meshes.")
return installes, #manquants
end

-- module : require(game.ServerStorage.Installer_Constructions)() ; colle dans la barre de commande : s'execute directement
if script and script:IsA("ModuleScript") then return installer end
return installer()
