-- Stubs minimaux de l'API Roblox pour tester les modules hors ligne avec l'interpreteur luau.
-- Vector3 / CFrame (rotation autour de Y uniquement) / game:GetService / require d'Instances.
local V3 = {}
V3.__index = V3
local function v3(x, y, z) return setmetatable({X = x, Y = y, Z = z}, V3) end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z) end
function V3:Dot(b) return self.X * b.X + self.Y * b.Y + self.Z * b.Z end
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return v3(0, 0, 0) end return v3(t.X / m, t.Y / m, t.Z / m) end
	return V3[k]
end
Vector3 = {new = v3, zero = v3(0, 0, 0), yAxis = v3(0, 1, 0), xAxis = v3(1, 0, 0), zAxis = v3(0, 0, 1)}

-- CFrame : position + angle autour de Y (LookVector = -Z tourne)
local CF = {}
local function cf(p, yaw) return setmetatable({Position = p, yaw = yaw or 0}, CF) end
local function rot(p, yaw) local c, s = math.cos(yaw), math.sin(yaw); return v3(c * p.X + s * p.Z, p.Y, -s * p.X + c * p.Z) end
CF.__index = function(t, k)
	if k == "LookVector" then return rot(v3(0, 0, -1), t.yaw) end
	if k == "RightVector" then return rot(v3(1, 0, 0), t.yaw) end
	if k == "X" then return t.Position.X elseif k == "Y" then return t.Position.Y elseif k == "Z" then return t.Position.Z end
	return CF[k]
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then return cf(a.Position + rot(b.Position, a.yaw), a.yaw + b.yaw) end
	return a.Position + rot(b, a.yaw)
end
CF.__sub = function(a, p) return cf(a.Position - p, a.yaw) end
CF.__add = function(a, p) return cf(a.Position + p, a.yaw) end
function CF:PointToObjectSpace(p) return rot(p - self.Position, -self.yaw) end
function CF:PointToWorldSpace(p) return self.Position + rot(p, self.yaw) end
function CF:GetPivot() return self end
CFrame = {}
function CFrame.new(x, y, z)
	if getmetatable(x) == V3 then return cf(x, 0) end
	return cf(v3(x or 0, y or 0, z or 0), 0)
end
function CFrame.Angles(_, ry, _) return cf(v3(0, 0, 0), ry) end
function CFrame.lookAt(p, cible)
	local d = cible - p
	-- LookVector = (-sin? ) : rot(v3(0,0,-1), yaw) = (-sin(yaw)... on resout yaw tel que rot(-Z) = d
	-- rot(0,0,-1,yaw) = (-s, 0, -c) => d.X = -s, d.Z = -c => yaw = atan2(-d.X, -d.Z)
	return cf(p, math.atan2(-d.X, -d.Z))
end

-- Instances factices : une table avec Name, enfants, et methodes
local Inst = {}
Inst.__index = function(t, k)
	if Inst[k] then return Inst[k] end
	local enfants = rawget(t, "_enfants")
	if enfants and enfants[k] then return enfants[k] end
	return nil
end
function Inst.new(nom, props)
	local o = setmetatable({Name = nom, _enfants = {}}, Inst)
	for k, v in pairs(props or {}) do o[k] = v end
	return o
end
function Inst:Ajouter(enfant) self._enfants[enfant.Name] = enfant; enfant.Parent = self; return enfant end
function Inst:FindFirstChild(n) return self._enfants[n] end
function Inst:WaitForChild(n) return self._enfants[n] end
function Inst:GetPivot() return self.CFrame end
function Inst:IsA(c) return self.ClassName == c end
Instance = Inst

-- game / services / require d'Instances
local modules = {}          -- nom d'Instance -> module (table) renvoye par require
local services = {}
game = {}
function game:GetService(n)
	if not services[n] then services[n] = Inst.new(n) end
	return services[n]
end
local requireOrig = require
require = function(x)
	if type(x) == "table" and x.Name and modules[x.Name] then return modules[x.Name] end
	return requireOrig(x)
end
return {Inst = Inst, modules = modules, services = services, v3 = v3, cf = cf}
