-- Course : LocalScript a mettre dans StarterPlayer > StarterPlayerScripts.
-- Maj (gauche ou droite) maintenue = courir ; manette : clic du stick gauche ;
-- telephone : bouton "Courir" a l'ecran (maintenir). Petit elargissement de la
-- camera pendant la course.
local Players = game:GetService("Players")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local joueur = Players.LocalPlayer
local enCourse = false

local function humanoide()
	local c = joueur.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function appliquer()
	local hum = humanoide()
	if not hum then return end
	local marche = hum:GetAttribute("VitesseMarche") or 16
	local course = hum:GetAttribute("VitesseCourse") or 28
	hum.WalkSpeed = enCourse and course or marche
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.25), {FieldOfView = enCourse and 80 or 70}):Play()
	end
end

local function action(_, etat)
	if etat == Enum.UserInputState.Begin then
		enCourse = true
	elseif etat == Enum.UserInputState.End or etat == Enum.UserInputState.Cancel then
		enCourse = false
	end
	appliquer()
	return Enum.ContextActionResult.Pass
end

CAS:BindAction("Courir", action, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
CAS:SetTitle("Courir", "Courir")
CAS:SetPosition("Courir", UDim2.new(1, -170, 1, -170))

local function nouveauPerso(c)
	enCourse = false
	local hum = c:WaitForChild("Humanoid")
	hum:GetAttributeChangedSignal("VitesseMarche"):Connect(appliquer)
	appliquer()
end
joueur.CharacterAdded:Connect(nouveauPerso)
if joueur.Character then task.spawn(nouveauPerso, joueur.Character) end
