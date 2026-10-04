--[[ Stations / Outils
	Petites fonctions partagees. Repere du modele (celui des FBX) : X = largeur de la station, Y = longueur (sens de
	passage des voitures), Z = hauteur. Le "Socle" de chaque station (piece invisible posee par le script de montage)
	porte ce repere : Socle.CFrame = passage repere du modele -> monde.
]]
local Outils = {}

Outils.UP = Vector3.new(0, 0, 1)                 -- le haut dans le repere du modele
Outils.X = Vector3.new(1, 0, 0)
-- passage du repere du modele (Z en haut) au repere Roblox (Y en haut), avant recalage sur la station
Outils.B = CFrame.fromMatrix(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))

function Outils.V(t) return Vector3.new(t[1], t[2], t[3]) end
-- {x, y, z, R00 ... R22} -> CFrame
function Outils.cf(t) return CFrame.new(t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9], t[10], t[11], t[12]) end

function Outils.lisse(u)
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

function Outils.pas(a, b, e)
	local n = math.max(1, math.floor((b - a) / e))
	local t = table.create(n + 1)
	for i = 0, n do t[i + 1] = a + (b - a) * i / n end
	return t
end

-- intervalle de la liste qui contient t : liste = {{t0, t1}, ...} ou {{nom, t0, t1}, ...} (i0 = position de t0)
function Outils.dans(liste, t, i0)
	i0 = i0 or 1
	for i, e in ipairs(liste) do
		if t > e[i0] and t <= e[i0 + 1] then return e, i end
	end
	return nil
end

-- vrai si l'instant "seuil" vient d'etre franchi entre deux images (prec -> t)
function Outils.franchi(prec, t, seuil) return prec < seuil and t >= seuil end

------------------------------------------------------------------
-- Repere d'une station : conversions repere du modele <-> monde (d'apres le Socle)
------------------------------------------------------------------
local Repere = {}
Repere.__index = Repere

-- v49 : les modeles des stations du plot sont agrandis (Model:ScaleTo, x1,5 avec les cases de 15 studs) ; les donnees
-- (PARC, points d'attache, trajets) sont en studs du modele d'origine : on applique l'echelle du modele a tous les points
-- (pas aux directions). Chaines de production (echelle 1) : inchange.
function Outils.repere(socle)
	local MAP = socle.CFrame
	local modele = socle:FindFirstAncestorOfClass("Model")
	local ok, s = pcall(function() return modele and modele:GetScale() or 1 end)
	if not ok or type(s) ~= "number" or s <= 0 then s = 1 end
	return setmetatable({MAP = MAP, MAPI = MAP:Inverse(), socle = socle, echelle = s}, Repere)
end
function Repere:point(p) return self.MAP * (p * self.echelle) end
function Repere:direction(d) return self.MAP:VectorToWorldSpace(d) end
function Repere:modele(pw) return (self.MAPI * pw) / self.echelle end
function Repere:directionModele(dw) return self.MAPI:VectorToWorldSpace(dw) end

-- attache (Attachment) sur une piece, placee a un point du modele (pos), orientee vers dir (modele) ;
-- cfRepos = position de la piece au repos (attribut "Repos" des pieces animees)
function Repere:attache(part, pos, dir, nom)
	local cfRepos = part:GetAttribute("Repos") or part.CFrame
	local lp = cfRepos:Inverse() * self:point(pos)
	local a = Instance.new("Attachment")
	a.Name = nom or "Attache"
	if dir then
		local ld = cfRepos:VectorToObjectSpace(self:direction(dir))
		a.CFrame = CFrame.lookAt(lp, lp + ld)
	else
		a.CFrame = CFrame.new(lp)
	end
	a.Parent = part
	return a
end

-- point d'une piece animee exprime dans le repere du modele, en tenant compte de son deplacement actuel
-- (pRepos = point du modele sur la piece au repos)
function Repere:suivre(part, pRepos)
	local cfRepos = part:GetAttribute("Repos") or part.CFrame
	return self:modele(part.CFrame * (cfRepos:Inverse() * self:point(pRepos)))
end

return Outils
