local ActionManager = {}

ActionManager.ModeActuel = "Aucun"
ActionManager.BoutonActuel = nil -- 👈 NOUVEAU : On retient l'outil exact
ActionManager.Item = nil 

function ActionManager.ChangerMode(nouveauMode, nomBouton)
	
	if ActionManager.Item then
		ActionManager.Item:Destroy()
		ActionManager.Item = nil
	end

	if ActionManager.ModeActuel == nouveauMode and ActionManager.BoutonActuel == nomBouton then
		ActionManager.ModeActuel = "Aucun"
		ActionManager.BoutonActuel = nil
	else
		ActionManager.ModeActuel = nouveauMode
		ActionManager.BoutonActuel = nomBouton
	end

end

return ActionManager