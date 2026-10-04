--[[ StationsCommun / Effets
	Effets de particules et lumieres des stations (eau, mousse, vapeur, peinture...).
	Chaque effet est un reglage nomme ; une station peut en changer quelques valeurs a la creation.
		local jet = Effets.emetteur(attache, "jetKarcher", rep, {Rate = 150})
]]
local Effets = {}

local FUMEE = "rbxasset://textures/particles/smoke_main.dds"
local ETINCELLE = "rbxasset://textures/particles/sparkles_main.dds"

local function taille(a, b, m) -- taille qui grandit (m = valeur au milieu, facultative)
	if m then return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.5, m), NumberSequenceKeypoint.new(1, b)}) end
	return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b)})
end
local function fondu(a, b) return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or 1)}) end
local function rgb(r, g, b) return ColorSequence.new(Color3.fromRGB(r, g, b)) end

-- gravite : vecteur dans le repere du modele (Z en haut), converti en monde a la creation
Effets.REGLAGES = {
	eau = {Rate = 45, Lifetime = {0.35, 0.6}, Speed = {7, 10}, Spread = {25, 12}, Gravite = -20,
		Size = taille(0.12, 0.45), Transparency = fondu(0.35), Color = rgb(190, 225, 255)},
	eauLarge = {Rate = 90, Lifetime = {0.35, 0.6}, Speed = {7, 10}, Spread = {70, 12}, Gravite = -20,
		Size = taille(0.12, 0.45), Transparency = fondu(0.35), Color = rgb(190, 225, 255)},
	mousse = {Rate = 30, Lifetime = {0.8, 1.4}, Speed = {1.5, 3}, Spread = {80, 20}, Gravite = -4,
		Size = taille(0.5, 1.4), Transparency = fondu(0.2), Color = rgb(250, 250, 255)},
	jetKarcher = {Rate = 220, Lifetime = {0.2, 0.25}, Speed = {26, 30}, Spread = {14, 3},
		Size = taille(0.08, 0.3), Transparency = fondu(0.25, 0.7), Color = rgb(205, 232, 255)},
	brumeEau = {Rate = 18, Lifetime = {0.5, 0.8}, Speed = {3, 6}, Spread = {25, 25},
		Size = taille(0.3, 1.2), Transparency = fondu(0.7), Color = rgb(235, 245, 255)},
	eclaboussures = {Rate = 90, Lifetime = {0.25, 0.45}, Speed = {4, 8}, Spread = {75, 75}, Gravite = -30,
		Size = taille(0.12, 0.45), Transparency = fondu(0.3), Color = rgb(200, 228, 255)},
	nuage = {Rate = 20, Lifetime = {0.8, 1.3}, Speed = {1, 2.5}, Spread = {80, 80},
		Size = taille(0.8, 2.2), Transparency = fondu(0.65), Color = rgb(235, 245, 255)},
	vapeur = {Rate = 18, Lifetime = {1.2, 2.0}, Speed = {0.8, 1.8}, Spread = {40, 40}, Drag = 1.2, Gravite = 0.6,
		Size = taille(0.4, 1.8), Transparency = fondu(0.55), Color = rgb(240, 240, 240)},
	jetPeinture = {Rate = 170, Lifetime = {0.22, 0.38}, Speed = {6.5, 8.5}, Spread = {13, 13}, Drag = 2.5,
		Size = taille(0.1, 0.85, 0.45), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1)})},
	brumePeinture = {Rate = 22, Lifetime = {1.0, 1.6}, Speed = {1.5, 3}, Spread = {35, 35}, Drag = 1.5, RotSpeed = {-30, 30},
		Size = taille(0.5, 2.4), Transparency = fondu(0.75)},
	etincelles = {Texture = ETINCELLE, Rate = 0, Lifetime = {0.25, 0.6}, Speed = {6, 12}, Spread = {70, 70}, Gravite = -25, Drag = 1,
		LightEmission = 1, Size = taille(0.35, 0)},
}

-- cree un ParticleEmitter (eteint) sur parent, d'apres le reglage "nom", avec des valeurs modifiees (surcharges)
function Effets.emetteur(parent, nom, rep, surcharges)
	local R = table.clone(Effets.REGLAGES[nom])
	for k, v in pairs(surcharges or {}) do R[k] = v end
	local e = Instance.new("ParticleEmitter")
	e.Name = nom
	e.Texture = R.Texture or FUMEE
	e.EmissionDirection = Enum.NormalId.Front
	e.Enabled = false
	e.Rate = R.Rate
	e.Lifetime = NumberRange.new(R.Lifetime[1], R.Lifetime[2])
	e.Speed = NumberRange.new(R.Speed[1], R.Speed[2])
	e.SpreadAngle = Vector2.new(R.Spread[1], R.Spread[2])
	if R.Gravite and rep then e.Acceleration = rep:direction(Vector3.new(0, 0, R.Gravite)) end
	if R.Drag then e.Drag = R.Drag end
	if R.RotSpeed then e.RotSpeed = NumberRange.new(R.RotSpeed[1], R.RotSpeed[2]) end
	if R.LightEmission then e.LightEmission = R.LightEmission end
	e.Size = R.Size
	e.Transparency = R.Transparency
	if R.Color then e.Color = R.Color end
	e.LightInfluence = 1
	e.Parent = parent
	return e
end

-- allume / eteint une liste d'emetteurs (ou de lumieres)
function Effets.activer(liste, oui)
	for _, e in ipairs(liste) do if e.Enabled ~= oui then e.Enabled = oui end end
end

-- lumiere ponctuelle eteinte
function Effets.lumiere(parent, portee, couleur)
	local l = Instance.new("PointLight")
	l.Range = portee or 8
	l.Brightness = 2
	l.Shadows = false
	l.Enabled = false
	if couleur then l.Color = couleur end
	l.Parent = parent
	return l
end

return Effets
