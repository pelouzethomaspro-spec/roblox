--[[ Catalogue / Car — voitures clientes du tycoon, par rarete.
	Models = noms des modeles 3D : ReplicatedStorage > VoituresModeles (les 12 voitures du jeu ; ce sont aussi celles
	de la chaine de production). Le serveur les trouve avec Car.Modele(tier, nom), qui cherche d'abord dans
	ReplicatedStorage > Car > <tier> (anciens emplacements) puis dans VoituresModeles.
	Mult = multiplicateur de gain / XP de la rarete ; Couleur et Fond servent a l'interface (Index).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Car = {
	Common    = { Models = {"Clio4", "Golf2"},     Mult = 1.0,  Couleur = Color3.fromRGB(170,170,175), Fond = "rbxassetid://117081546254113" },
	Uncommon  = { Models = {"Golf", "Volvo240"},   Mult = 1.40, Couleur = Color3.fromRGB( 80,200,110), Fond = "rbxassetid://90550738991893" },
	Rare      = { Models = {"Mercedes", "Dodge"},  Mult = 2.0,  Couleur = Color3.fromRGB( 60,140,240), Fond = "rbxassetid://131107138876682" },
	Epic      = { Models = {"M4", "ClassG"},       Mult = 3.0,  Couleur = Color3.fromRGB(165, 85,225), Fond = "rbxassetid://97529190323721" },
	Legendary = { Models = {"Urus", "GT3"},        Mult = 5.0,  Couleur = Color3.fromRGB(245,185, 40), Fond = "rbxassetid://82522826407370" },
	Mythic    = { Models = {"F448"},               Mult = 10.0, Couleur = Color3.fromRGB(235, 65, 65), Fond = "rbxassetid://98277720610468" },
	Divine    = { Models = {"Follie"},             Mult = 25.0, Couleur = Color3.fromRGB(215,235,250), Fond = "rbxassetid://95313932981363" },
}

Car.Ordre = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine"}

-- Taille des voitures en jeu : longueur reelle (metres) x STUDS_PAR_METRE. Reference choisie : la M4 (4,794 m) fait
-- LONGUEUR_M4 studs ; toutes les autres gardent leurs proportions reelles (Clio plus courte que l'Urus, etc.).
-- Appliquee au demarrage du serveur aux modeles de ReplicatedStorage > VoituresModeles (CarManager.AjusterModeles) :
-- les voitures clientes, les stations (qui mesurent la voiture) et la chaine (ECHELLE_VOITURE relative) suivent.
Car.LONGUEUR_M4 = 22
Car.STUDS_PAR_METRE = Car.LONGUEUR_M4 / 4.794
Car.LongueursM = {           -- longueur hors tout reelle, en metres
	M4 = 4.794,              -- BMW M4 (G82)
	Clio4 = 4.063,           -- Renault Clio IV
	Golf2 = 3.985,           -- VW Golf II
	Golf = 4.284,            -- VW Golf VIII
	Volvo240 = 4.790,        -- Volvo 240 berline
	Mercedes = 4.686,        -- Mercedes Classe C (W205)
	Dodge = 5.020,           -- Dodge Challenger
	ClassG = 4.817,          -- Mercedes Classe G (W463)
	GT3 = 4.573,             -- Porsche 911 GT3 (992)
	Urus = 5.112,            -- Lamborghini Urus
	F448 = 4.527,            -- Ferrari 488
	Follie = 4.700,          -- (a confirmer)
	Fourgon = 5.932,         -- Mercedes Sprinter L2 (camion de livraison)
	F150 = 5.910,            -- Ford F-150 SuperCrew (pick-up d'ItsCirly, intro du tutoriel) — v56
}

-- v56 : BRUITS DE MOTEUR PAR MODELE, a partir de la rarete EPIQUE (demande de Thomas : on doit reconnaitre le moteur de la
-- vraie voiture). Deux sons par modele, a importer dans Studio (Contenus -> Importer, ou son libre de la boutique) puis
-- coller l'identifiant ici (0 = pas encore : le son generique SON_GENERIQUE est utilise) :
--   Ralenti      : moteur au ralenti / vitesse constante, EN BOUCLE (TWEENController : hauteur et volume suivent la vitesse)
--   Acceleration : grosse acceleration, UNE FOIS (joue quand la voiture achetee au centre file vers le plot : rugissement +
--                  derapage dans le rond-point ; attribut "Rugissement" pose par le serveur, CarAmbiance)
--   Hauteur      : PlaybackSpeed de base du ralenti (1 = tel quel) ; Volume : volume du rugissement
-- Les voitures Common -> Rare gardent le son generique. Guide de recherche des sons : 2_documents/SONS_MOTEURS.md
Car.Sons = {
	M4     = { Ralenti = 0, Acceleration = 0, Hauteur = 1.0, Volume = 0.7, Moteur = "BMW S58 3.0 L 6 cylindres en ligne biturbo (M4 G82)" },
	ClassG = { Ralenti = 0, Acceleration = 0, Hauteur = 0.9, Volume = 0.8, Moteur = "Mercedes-AMG M177 4.0 L V8 biturbo (G63), grondement grave + crepitements" },
	Urus   = { Ralenti = 0, Acceleration = 0, Hauteur = 0.95, Volume = 0.8, Moteur = "Lamborghini 4.0 L V8 biturbo (Urus)" },
	GT3    = { Ralenti = 0, Acceleration = 0, Hauteur = 1.1, Volume = 0.8, Moteur = "Porsche 4.0 L flat-6 atmospherique, 9 000 tr/min (911 GT3 992), hurlement aigu" },
	F448   = { Ralenti = 0, Acceleration = 0, Hauteur = 1.05, Volume = 0.8, Moteur = "Ferrari F154 3.9 L V8 biturbo (488 GTB)" },
	Follie = { Ralenti = 0, Acceleration = 0, Hauteur = 1.0, Volume = 0.9, Moteur = "V12 hypercar (a confirmer avec Thomas)" },
	F150   = { Ralenti = 0, Acceleration = 0, Hauteur = 0.85, Volume = 0.8, Moteur = "Ford 5.0 L V8 Coyote (F-150), derapage de l'intro" },
}
Car.SON_GENERIQUE = "rbxassetid://9112787518"          -- "Go Kart Engine Constant 2" (son libre Roblox), en boucle

local function idSon(v)
	if type(v) == "number" then return v ~= 0 and ("rbxassetid://" .. tostring(v)) or nil end
	if type(v) == "string" and v ~= "" and not v:match("://0*$") then return v end
	return nil
end
-- sons d'un modele (nom exact ou prefixe : "M4_bleue") : { Ralenti = "rbxassetid://..." | nil, Acceleration = ... | nil,
-- Hauteur, Volume } ; nil si le modele n'a pas de sons propres
function Car.SonDe(nom)
	if type(nom) ~= "string" then return nil end
	local S = Car.Sons[nom]
	if not S then
		for cle, v in pairs(Car.Sons) do if nom:sub(1, #cle) == cle then S = v break end end
	end
	if not S then return nil end
	local r, a = idSon(S.Ralenti), idSon(S.Acceleration)
	if not (r or a) then return nil end
	return { Ralenti = r, Acceleration = a, Hauteur = S.Hauteur or 1, Volume = S.Volume or 0.8 }
end

-- longueur voulue en studs d'un modele (nom du modele dans VoituresModeles) ; modele inconnu -> celle de la M4
function Car.Longueur(nom)
	local m = nom and Car.LongueursM[nom]
	if not m then
		for cle, v in pairs(Car.LongueursM) do          -- "M4_bleue", "Clio4 (2)"...
			if nom and nom:sub(1, #cle) == cle then m = v break end
		end
	end
	return (m or 4.794) * Car.STUDS_PAR_METRE
end

-- modele 3D d'une voiture du catalogue (nil si absent de la place)
function Car.Modele(tier, nom)
	local dossierCar = ReplicatedStorage:FindFirstChild("Car")
	local dossierTier = dossierCar and tier and dossierCar:FindFirstChild(tier)
	local m = dossierTier and nom and dossierTier:FindFirstChild(nom)
	if m then return m end
	local modeles = ReplicatedStorage:FindFirstChild("VoituresModeles")
	return modeles and nom and modeles:FindFirstChild(nom) or nil
end

-- rarete d'un modele (nil si hors catalogue)
function Car.TierDe(nom)
	for _, tier in ipairs(Car.Ordre) do
		for _, n in ipairs(Car[tier].Models) do if n == nom then return tier end end
	end
	return nil
end

return Car
