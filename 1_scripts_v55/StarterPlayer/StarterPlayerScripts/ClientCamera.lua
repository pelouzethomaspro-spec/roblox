--[[ ClientCamera   (ModuleScript, StarterPlayerScripts) — camera libre du mode construction
	Activer()   : la camera passe en vue plongeante au-dessus du personnage (troisieme personne, ~55 degres) et se
	              deplace au clavier : Z/W/S/Q/A/D ou fleches (avance / recule / gauche / droite) ; clic droit maintenu :
	              la souris fait tourner la camera (lacet et inclinaison), comme la camera normale ; molette : distance. Le personnage ne bouge pas
	              pendant ce temps (les touches de deplacement sont interceptees).
	Desactiver(): retour a la camera normale du joueur.
	Tout est local : rien n'est envoye au serveur.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ClientCamera = {}

local VITESSE = 55            -- studs par seconde (a hauteur de reference)
local HAUTEUR_DEFAUT = 45
local HAUTEUR_MIN, HAUTEUR_MAX = 15, 120
local INCLINAISON_DEFAUT = math.rad(55)             -- angle de plongee au depart
local INCLINAISON_MIN, INCLINAISON_MAX = math.rad(20), math.rad(85)
local SENSIBILITE = 0.005                            -- radians par pixel de souris (clic droit maintenu)

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera

local actif = false
local cible = Vector3.zero    -- point du sol regarde
local yaw = 0
local inclinaison = INCLINAISON_DEFAUT
local hauteur = HAUTEUR_DEFAUT     -- distance camera -> point regarde
local touches = {}
local connexions = {}
local dragSouris = false

-- ces touches deplacent la camera et NE deplacent plus le personnage tant que la camera libre est active
local TOUCHES = {
	Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.S, Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}

local function gererTouche(_, etat, input)
	touches[input.KeyCode] = (etat == Enum.UserInputState.Begin)
	return Enum.ContextActionResult.Sink
end

local function appuyee(...)
	for _, k in ipairs({...}) do if touches[k] then return true end end
	return false
end

local function placer()
	-- la camera orbite autour du point regarde : lacet (yaw) et inclinaison pilotes au clic droit, distance a la molette
	local recul = CFrame.Angles(0, yaw, 0) * Vector3.new(0, hauteur * math.sin(inclinaison), hauteur * math.cos(inclinaison))
	camera.CFrame = CFrame.lookAt(cible + recul, cible)
end

local function etape(dt)
	if not actif then return end
	dt = math.min(dt, 0.1)
	-- deplacement dans le plan horizontal, relatif a l'orientation de la camera
	local avant = CFrame.Angles(0, yaw, 0).LookVector
	avant = Vector3.new(avant.X, 0, avant.Z).Unit
	local droite = Vector3.new(-avant.Z, 0, avant.X)
	local d = Vector3.zero
	if appuyee(Enum.KeyCode.W, Enum.KeyCode.Z, Enum.KeyCode.Up) then d += avant end
	if appuyee(Enum.KeyCode.S, Enum.KeyCode.Down) then d -= avant end
	if appuyee(Enum.KeyCode.D, Enum.KeyCode.Right) then d += droite end
	if appuyee(Enum.KeyCode.A, Enum.KeyCode.Q, Enum.KeyCode.Left) then d -= droite end
	if d.Magnitude > 0 then
		cible += d.Unit * VITESSE * (hauteur / HAUTEUR_DEFAUT) * dt
	end
	placer()
end

function ClientCamera.Activer()
	if actif then return end
	actif = true
	camera = workspace.CurrentCamera
	-- point de depart : le personnage ; orientation : celle de la camera actuelle (pas de saut visuel)
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart")
	cible = racine and racine.Position or camera.CFrame.Position
	cible = Vector3.new(cible.X, racine and (cible.Y - 2.5) or cible.Y, cible.Z)
	local regard = camera.CFrame.LookVector
	yaw = math.atan2(-regard.X, -regard.Z)
	hauteur = HAUTEUR_DEFAUT
	inclinaison = INCLINAISON_DEFAUT
	table.clear(touches)
	camera.CameraType = Enum.CameraType.Scriptable
	placer()

	ContextActionService:BindActionAtPriority("CameraLibreTouches", gererTouche, false, Enum.ContextActionPriority.High.Value, table.unpack(TOUCHES))
	table.insert(connexions, UserInputService.InputChanged:Connect(function(input, traite)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			hauteur = math.clamp(hauteur - input.Position.Z * 6, HAUTEUR_MIN, HAUTEUR_MAX)
			placer()
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragSouris then
			-- clic droit maintenu : la souris fait tourner la camera, comme la camera normale du joueur
			yaw -= input.Delta.X * SENSIBILITE
			inclinaison = math.clamp(inclinaison + input.Delta.Y * SENSIBILITE, INCLINAISON_MIN, INCLINAISON_MAX)
			placer()
		end
	end))
	table.insert(connexions, UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragSouris = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition   -- le curseur reste en place pendant la rotation
		end
	end))
	table.insert(connexions, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragSouris = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))
	RunService:BindToRenderStep("CameraLibre", Enum.RenderPriority.Camera.Value + 1, etape)
end

function ClientCamera.Desactiver()
	if not actif then return end
	actif = false
	RunService:UnbindFromRenderStep("CameraLibre")
	ContextActionService:UnbindAction("CameraLibreTouches")
	for _, c in ipairs(connexions) do c:Disconnect() end
	table.clear(connexions)
	table.clear(touches)
	dragSouris = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid") or camera.CameraSubject
end

function ClientCamera.EstActive()
	return actif
end

return ClientCamera
