--[[ ClientService (v53) — LocalScript StarterPlayer/StarterPlayerScripts
	Service manuel : quand une station (ou une caisse) du joueur porte une invite "InviteService" (CarManager.inviteSur :
	panneau "E - Laver la voiture" / "E - Encaisser"), la touche E a moins de 30 studs declenche l'action via le
	RemoteEvent ServiceManuelEvent. Doublon volontaire du ProximityPrompt (secours si l'invite Roblox ne s'affiche pas).
	Le panneau de l'invite la plus proche pulse legerement quand on est a portee.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local joueur = Players.LocalPlayer
local Event = ReplicatedStorage:WaitForChild("ServiceManuelEvent", 120)
if not Event then return end

local PORTEE = 30
local dernier = 0

local function plotDuJoueur()
	local plots = workspace:FindFirstChild("Plots")
	return plots and plots:FindFirstChild(joueur.Name .. "'s plot")
end

-- invite la plus proche du personnage (racine InviteService, meuble, distance)
local function inviteProche()
	local plot = plotDuJoueur()
	local perso = joueur.Character
	local root = perso and perso:FindFirstChild("HumanoidRootPart")
	if not (plot and root) then return nil end
	local meilleur, dmin, meuble = nil, math.huge, nil
	for _, m in ipairs(plot:GetChildren()) do
		local r = m:FindFirstChild("InviteService")
		if r and r:IsA("BasePart") then
			local d = (r.Position - root.Position).Magnitude
			if d < dmin then meilleur, dmin, meuble = r, d, m end
		end
	end
	return meilleur, meuble, dmin
end

UserInputService.InputBegan:Connect(function(input, traite)
	if traite or input.KeyCode ~= Enum.KeyCode.E then return end
	if os.clock() - dernier < 0.6 then return end
	local racine, meuble, d = inviteProche()
	if racine and d <= PORTEE then
		dernier = os.clock()
		Event:FireServer(meuble)
	end
end)

-- pulsation du panneau a portee
RunService.Heartbeat:Connect(function()
	local racine, _, d = inviteProche()
	if not racine then return end
	local panneau = racine:FindFirstChild("Panneau")
	local fond = panneau and panneau:FindFirstChildOfClass("Frame")
	if not fond then return end
	if d <= PORTEE then
		local a = 0.5 + 0.5 * math.sin(os.clock() * 6)
		fond.BackgroundColor3 = Color3.fromRGB(18, 20, 28):Lerp(Color3.fromRGB(40, 120, 60), a * 0.7)
	else
		fond.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	end
end)
