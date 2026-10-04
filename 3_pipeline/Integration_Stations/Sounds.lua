-- Sons de l'interface (UIController/Sounds). Seuls les vrais clics et les ouvertures/fermetures de menu font un son :
-- pas de son au survol, pas de son d'erreur. Remplace les valeurs par tes propres rbxassetid://... si tu veux.
return {
	click = { id = "rbxasset://sounds/switch.wav", volume = 0.25, pitch = 0.95 },
	open  = { id = "rbxasset://sounds/button.wav", volume = 0.3, pitch = 1.15 },     -- (swoosh.wav n'est plus autorise par Roblox)
	close = { id = "rbxasset://sounds/button.wav", volume = 0.25, pitch = 0.85 },
	-- moteur de la voiture du menu (UI v21) : colle un rbxassetid:// de la Toolbox (Audio -> "car engine") ; vide = pas de son
	engine = { id = "rbxassetid://103483259110286", volume = 0.6 },
	-- klaxon du van de livraison ("poit poit", camera cinematique) : rbxassetid:// du son klaxon.ogg importe par Thomas
	klaxon = { id = "rbxassetid://126229048818711", volume = 0.9 },
	-- son "schling" de l'ecran de choix de l'emplacement (UI v23)
	schling = { id = "rbxassetid://91923071122458", volume = 0.6 },
	-- v50 : cinematique de decouverte (GT3) : whoosh / boom du saut en hyperespace (colle un rbxassetid:// ; vide = pas de son)
	hyper = { id = "", volume = 0.8 },
	-- v51 : moteur de GT3 pour la cinematique (sinon engine) et "clac" des phares qui s'allument (sinon switch.wav)
	moteurGT3 = { id = "", volume = 0.8 },
	clac = { id = "", volume = 0.9 },
	buy   = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35, pitch = 1.0 },
	-- musique de fond, en boucle des l'ecran-titre : mets ici le rbxassetid:// de ta musique publiee (vide = pas de musique)
	musique = { id = "rbxassetid://124724787424208", volume = 0.15 },   -- firefly lullaby
}
