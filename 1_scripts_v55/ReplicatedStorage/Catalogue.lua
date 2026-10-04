local Catalogue = {}

Catalogue.Furniture = require(script:WaitForChild("Furniture"))
Catalogue.Extension = require(script:WaitForChild("Extension"))
Catalogue.Sol = require(script:WaitForChild("Sol"))
Catalogue.Plafond = require(script:WaitForChild("Plafond"))
Catalogue.Mur = require(script:WaitForChild("Mur"))
Catalogue.Consommable = require(script:WaitForChild("Consommable"))

function Catalogue.GetInfo(categorie, name)
	if categorie == "Furniture"or  categorie == "Mur" or categorie == "Sol" or categorie == "Plafond" or categorie == "Extension" or categorie == "Consommable" then
		return Catalogue[categorie][name]
	end
	return nil
end

return Catalogue