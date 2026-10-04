--[[ StationsCommun / Sons
	Catalogue des sons (bibliotheque officielle Roblox, Creator Store "(SFX)", publics) + fonctions communes.
	Pour changer un son partout : remplace son ID ici. "rbxassetid://0" = son coupe.
]]
local Sons = {}

Sons.VOLUME = 1                     -- volume general de toutes les stations

Sons.CATALOGUE = {
	-- machines
	servo = "rbxassetid://9118950352",          -- Servo Motor 1 : moteur d'un robot (un bruit par mouvement)
	servoRotation = "rbxassetid://9118925819",  -- Servo Motor 9 : rotation / demi-tour
	pompe = "rbxassetid://9125790253",          -- Pump Cycle Machine Mechanical Clunks : verins, pompe, moteur de brosses
	clac = "rbxassetid://9120095742",           -- Toggle Switch Metal Industrial Equipment 33 : pince, gachette, bouchon
	bip = "rbxassetid://9119141141",            -- Single High Pitch Beep Tones 9 : debut / fin de cycle
	visseuse = "rbxassetid://9117665655",       -- Pneumatic Air Blast Grinding Tool 1 : visseuse
	cliquet = "rbxassetid://9118047334",        -- Ratchet Wrench Gear Winding 1 : cle a cliquet
	etincelles = "rbxassetid://258663838",      -- electric sparks (Creator Store) : contact electrique
	-- eau / liquides
	fontaine = "rbxassetid://9120557412",       -- Water Fountain 1 : ruissellement continu
	eauTole = "rbxassetid://9120591731",        -- Water Spray Metal 4 : eau projetee sur la tole
	jetOuverture = "rbxassetid://9120503143",   -- Water Burst Boom Blast Hissing Spray 4 : ouverture d'un jet
	jetKarcher = "rbxassetid://9120561916",     -- Water Hose Gun 1 : jet haute pression
	splash = "rbxassetid://9119481909",         -- Splash Thunking Impact 1 : paquet d'eau
	eponge = "rbxassetid://9120589946",         -- Water Splash Wet Smacking Footsteps 1 : brosse / eponge mouillee
	bulles = "rbxassetid://7322736504",         -- bubble sound (Creator Store) : mousse
	glouglou1 = "rbxassetid://9114622472",      -- Glug 1 : liquide qui coule (jerrican, bidon)
	glouglou2 = "rbxassetid://9114622480",      -- Glug 2
	pistoletPompe = "rbxassetid://9114557376",  -- Gas Pump Nozzle Movement On Off 1 : pistolet de pompe a essence
	spray = "rbxassetid://9119522396",          -- Spray Paint 4 : pistolet a peinture / pulverisateur / vapeur (plus grave)
	-- voitures
	moteurVoiture = "rbxassetid://9112787518",  -- Go Kart Engine Constant 2 : ronronnement du moteur (joue plus grave)
}

-- cree un son 3D attache a parent (piece ou Attachment) ; nil si l'ID est vide ou coupe
function Sons.creer(id, parent, volume, boucle, vitesse)
	if not id or id == "" or id:match("://0$") then return nil end
	local s = Instance.new("Sound")
	s.Name = "Son"
	s.SoundId = id
	s.Volume = (volume or 1) * Sons.VOLUME
	s.Looped = boucle or false
	s.PlaybackSpeed = vitesse or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 140
	s.Parent = parent
	return s
end

-- marche / arret d'un son en boucle (sans le relancer s'il joue deja)
function Sons.jouer(s, oui)
	if not s then return end
	if oui and not s.IsPlaying then s:Play() elseif not oui and s.IsPlaying then s:Stop() end
end

-- joue un son depuis le debut
function Sons.coup(s, vitesse)
	if not s then return end
	if vitesse then s.PlaybackSpeed = vitesse end
	s.TimePosition = 0
	s:Play()
end

-- joue un son etire (ou accelere) pour qu'il dure exactement "duree" secondes
function Sons.etirer(s, duree)
	if not s then return end
	local L = s.TimeLength
	s.PlaybackSpeed = (L > 0) and math.clamp(L / math.max(duree, 0.05), 0.25, 4) or 1
	s.TimePosition = 0
	s:Play()
end

-- precharge une liste de sons (sans bloquer le script)
function Sons.precharger(liste)
	task.spawn(function()
		pcall(function() game:GetService("ContentProvider"):PreloadAsync(liste) end)
	end)
end

------------------------------------------------------------------
-- Relais : un bruit de moteur par mouvement de robot. Deux sons se relaient : chaque mouvement part sur un son
-- neuf etire a la duree du mouvement, l'ancien s'eteint en fondu ; si le son finit trop tot il est relance.
------------------------------------------------------------------
local Relais = {}
Relais.__index = Relais

function Sons.relais(id, parent, volume)
	local r = setmetatable({volume = volume, fondu = 0.1}, Relais)
	r.a = Sons.creer(id, parent, volume, false)
	r.b = Sons.creer(id, parent, volume, false)
	return r
end

-- debut d'un mouvement : duree en secondes reelles, tFin en temps du cycle
function Relais:mouvement(duree, tFin)
	local s = (self.actif == self.a) and self.b or self.a
	if not s then return end
	if self.actif then self.ancien, self.tFondu = self.actif, self.fondu end
	s.Volume = self.volume * Sons.VOLUME
	Sons.etirer(s, duree)
	self.actif, self.tFin = s, tFin
end

-- plus de mouvement : le son en cours s'eteint en fondu
function Relais:arret()
	if self.actif then self.ancien, self.tFondu = self.actif, self.fondu end
	self.actif, self.tFin = nil, nil
end

-- a appeler a chaque image : t = temps du cycle, dt = secondes reelles ecoulees, vitesse = VITESSE de la station
function Relais:maj(t, dt, vitesse)
	if self.ancien then
		self.tFondu -= dt
		if self.tFondu <= 0 then self.ancien:Stop(); self.ancien = nil
		else self.ancien.Volume = self.volume * Sons.VOLUME * self.tFondu / self.fondu end
	end
	if self.actif and self.tFin then
		local reste = (self.tFin - t) / (vitesse or 1)
		if reste > 0.15 and not self.actif.IsPlaying then self.actif.TimePosition = 0; self.actif:Play() end
		if reste <= 0 then self:arret() end
	end
end

function Relais:couper()
	for _, s in ipairs({self.a, self.b}) do if s and s.IsPlaying then s:Stop() end end
	self.actif, self.ancien, self.tFin = nil, nil, nil
end

function Relais:liste() return {self.a, self.b} end

return Sons
