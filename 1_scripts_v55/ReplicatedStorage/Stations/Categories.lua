--[[ StationsCommun / Categories
	Les voitures sont rangees en quelques grandes categories, d'apres leur forme (hauteur une fois ramenees a
	16 studs de long). Les stations calculent leurs mouvements PAR CATEGORIE (enveloppe de toutes les voitures de la
	categorie) et non par modele : ajouter un modele ne demande aucun code, il rejoint sa categorie tout seul.

	Pour forcer la categorie d'un modele : attribut "Categorie" sur le modele (ex : "Haute"), ou table FORCEES.
]]
local Categories = {}

-- de la plus basse a la plus haute ; moteur = caractere du bruit de moteur (hauteur du son a l'arret / en roulant)
Categories.LISTE = {
	{nom = "Sportive", hauteurMax = 4.6, moteur = {ralenti = 0.62, roule = 1.05, volume = 0.26}},   -- basse et large
	{nom = "Berline", hauteurMax = 5.2, moteur = {ralenti = 0.5, roule = 0.85, volume = 0.22}},     -- berline / coupe
	{nom = "Compacte", hauteurMax = 6.2, moteur = {ralenti = 0.56, roule = 0.92, volume = 0.2}},    -- citadine / compacte
	{nom = "Haute", hauteurMax = math.huge, moteur = {ralenti = 0.4, roule = 0.72, volume = 0.27}}, -- SUV, 4x4, monospace
}

-- modeles dont on impose la categorie (nom ou morceau du nom du modele, sans majuscules)
Categories.FORCEES = {
	urus = "Haute",
}

local parNom = {}
for _, c in ipairs(Categories.LISTE) do parNom[c.nom] = c end

-- categorie d'un modele : forcee (attribut ou table), sinon d'apres sa hauteur
function Categories.de(modele, hauteur)
	local a = modele:GetAttribute("Categorie")
	if a and parNom[a] then return parNom[a] end
	local n = string.lower(modele.Name)
	for morceau, cat in pairs(Categories.FORCEES) do
		if n:find(morceau, 1, true) and parNom[cat] then return parNom[cat] end
	end
	for _, c in ipairs(Categories.LISTE) do
		if hauteur <= c.hauteurMax then return c end
	end
	return Categories.LISTE[#Categories.LISTE]
end

return Categories
