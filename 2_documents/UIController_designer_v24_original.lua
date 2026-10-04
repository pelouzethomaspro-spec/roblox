-- UIController v10 : l'interface est composée d'images rendues depuis le canvas (identiques au pixel)
-- + zones cliquables invisibles + quelques textes dynamiques. Les chemins des boutons sont ceux de ta liste.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local pg = script.Parent:IsA("PlayerGui") and script.Parent or script.Parent.Parent
local start = pg:WaitForChild("Menu"); local main = pg:WaitForChild("Main"); local loading = pg:WaitForChild("Loading")
local plot = pg:WaitForChild("Start")   -- choix de l'emplacement : Start / Choose / Center / Minus · Choose · Plus
local ContentProvider = game:GetService("ContentProvider")
local choose = start:WaitForChild("Choose"); local root = main:WaitForChild("Root")
local hud = root.HUD.HUD1; local menus = root.MENUS

-- ===== images : réapplique les numéros d'actif (sécurité si le fichier a été relu sans eux) =====
for _, o in ipairs(pg:GetDescendants()) do
	if o:IsA("ImageLabel") or o:IsA("ImageButton") then
		local src = o:FindFirstChild("Src")
		if src and src:IsA("StringValue") and src.Value ~= "" and src.Value ~= "rbxassetid://0" then o.Image = src.Value end
	end
end

-- ===== sons =====
local SoundService = game:GetService("SoundService")
local SND = require(script:WaitForChild("Sounds"))
local function play(name)
	local d = SND[name]; if not d then return end
	pcall(function()
		local s = Instance.new("Sound"); s.SoundId = d.id; s.Volume = d.volume or 0.5; s.PlaybackSpeed = d.pitch or 1; s.Parent = SoundService
		s:Play(); s.Ended:Once(function() s:Destroy() end); task.delay(3, function() if s.Parent then s:Destroy() end end)
	end)
end
-- retour visuel + son sur les boutons
local function pressFx(btn)
	if not btn or not btn:IsA("GuiButton") then return end
	btn.MouseEnter:Connect(function() play("hover") end)
	btn.MouseButton1Down:Connect(function()
		play("click")
		local sc = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", btn)
		sc.Scale = 0.95; TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	end)
end

-- ===== échelle =====
local function fit()
	local vs = workspace.CurrentCamera.ViewportSize; local k = math.min(vs.X / 1920, vs.Y / 1080)
	for _, sc in ipairs(pg:GetDescendants()) do
		if sc:IsA("UIScale") and sc.Parent and sc.Parent.Parent and sc.Parent.Parent:IsA("ScreenGui") then sc.Scale = k end
	end
end
fit(); workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
pg.DescendantAdded:Connect(function(d) if d:IsA("UIScale") then task.defer(fit) end end)
task.delay(1, fit); task.delay(3, fit)

-- fondu d'un cadre entier (remplace les CanvasGroup, que Roblox ne dessine plus au-delà d'une certaine taille)
local function fadeFrame(frame, to, dur)
	for _, o in ipairs(frame:GetDescendants()) do
		local p = {}
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then
			if o:GetAttribute("baseIT") == nil then o:SetAttribute("baseIT", o.ImageTransparency) end
			p.ImageTransparency = (to == 1) and 1 or o:GetAttribute("baseIT")
		end
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			if o:GetAttribute("baseTT") == nil then o:SetAttribute("baseTT", o.TextTransparency) end
			p.TextTransparency = (to == 1) and 1 or o:GetAttribute("baseTT")
		end
		if next(p) then TweenService:Create(o, TweenInfo.new(dur, Enum.EasingStyle.Quad), p):Play() end
	end
end
local function setFaded(frame)
	for _, o in ipairs(frame:GetDescendants()) do
		if o:IsA("ImageLabel") or o:IsA("ImageButton") then if o:GetAttribute("baseIT") == nil then o:SetAttribute("baseIT", o.ImageTransparency) end; o.ImageTransparency = 1 end
		if o:IsA("TextLabel") or o:IsA("TextButton") then if o:GetAttribute("baseTT") == nil then o:SetAttribute("baseTT", o.TextTransparency) end; o.TextTransparency = 1 end
	end
end

-- ===== préchargement : toutes les images de l'interface avant d'afficher le menu =====
main.Enabled = false; start.Enabled = false; plot.Enabled = false; loading.Enabled = true
do
	local assets, seen = {}, {}
	for _, o in ipairs(pg:GetDescendants()) do
		if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.Image ~= "" and o.Image ~= "rbxassetid://0" and not seen[o.Image] then seen[o.Image] = true; table.insert(assets, o) end
	end
	pcall(function()
		for _, id in ipairs(require(choose.Hero.Car.DriveData).sheets) do
			if not seen[id] then seen[id] = true; table.insert(assets, id) end
		end
	end)
	task.spawn(function()
		local sh = loading.Root.Bar.Fill:FindFirstChild("Shine")
		while sh and loading.Enabled do sh.Position = UDim2.fromOffset(-120, 0); TweenService:Create(sh, TweenInfo.new(1.1, Enum.EasingStyle.Sine), {Position = UDim2.fromOffset(820, 0)}):Play(); task.wait(1.4) end
	end)
	local bar = loading.Root.Bar.Fill; local status = loading.Root.Status; local total = math.max(1, #assets); local done = 0
	local t0 = os.clock()
	task.spawn(function()
		ContentProvider:PreloadAsync(assets, function(id, st)
			done = math.min(total, done + 1); local p = math.clamp(done / total, 0, 1)
			bar.Size = UDim2.fromOffset(math.floor(812 * p), 22); status.Text = string.format("Chargement du garage  %d %%", math.floor(p * 100))
		end)
	end)
	-- attend la fin du préchargement (ou 25 s max), puis un court fondu
	local skip = false
	pcall(function()
		local sb = loading.Root.Skip
		sb.Activated:Connect(function() skip = true end); sb.MouseButton1Click:Connect(function() skip = true end)
		sb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then skip = true end end)
		sb.MouseEnter:Connect(function() sb.BackgroundTransparency = 0.1 end); sb.MouseLeave:Connect(function() sb.BackgroundTransparency = 0.3 end)
	end)
	while not skip and ((done < total and os.clock() - t0 < 25) or os.clock() - t0 < 5) do task.wait(0.05) end
	bar.Size = UDim2.fromOffset(812, 22); status.Text = "Chargement du garage  100 %"
	-- garde toutes les textures résidentes en mémoire GPU : une copie 2×2 px de chaque image, hors de vue,
	-- pour que l'affichage d'un panneau ou d'une variante soit instantané (aucun re-décodage au clic)
	local keep = Instance.new("Frame"); keep.Name = "KeepAlive"; keep.Size = UDim2.fromOffset(4, 4); keep.Position = UDim2.new(0, -20, 0, -20); keep.BackgroundTransparency = 1; keep.ClipsDescendants = true; keep.ZIndex = 0
	local k = 0
	for id in pairs(seen) do
		local il = Instance.new("ImageLabel"); il.Image = id; il.Size = UDim2.fromOffset(2, 2); il.BackgroundTransparency = 1; il.ImageTransparency = 0.98; il.BorderSizePixel = 0; il.Parent = keep; k += 1
	end
	keep.Parent = main
	task.wait(0.4)
	local fade = Instance.new("Frame"); fade.Size = UDim2.fromScale(1, 1); fade.BackgroundColor3 = Color3.fromHex("1f6fbf"); fade.BackgroundTransparency = 1; fade.ZIndex = 50; fade.Parent = loading
	TweenService:Create(fade, TweenInfo.new(0.35), {BackgroundTransparency = 0}):Play(); task.wait(0.35)
	start.Enabled = true; loading.Enabled = false; fade:Destroy(); fit()
end

-- ===== menu =====
local LP = Players.LocalPlayer
choose.Player.Txt.Name.Text = LP.DisplayName
task.spawn(function()
	local ok, url = pcall(function() return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
	if ok then choose.Player.Avatar.Image = url end
end)
-- infos de la sauvegarde : attributs posés par ton serveur sur le joueur (Money, Rank, Day, XP, XPNext)
local function fmtMoney(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
	return s .. " $"
end
local function saveInfo()
	local money = LP:GetAttribute("Money") or (LP:FindFirstChild("leaderstats") and (LP.leaderstats:FindFirstChild("Money") or LP.leaderstats:FindFirstChild("Cash")) and (LP.leaderstats:FindFirstChild("Money") or LP.leaderstats:FindFirstChild("Cash")).Value) or 0
	local rank = LP:GetAttribute("Rank") or "Bronze I"; local day = LP:GetAttribute("Day") or 1
	choose.SaveTitle.Text = "Garage de " .. LP.DisplayName
	choose.SaveSub.Text = string.format("%s · %s · Jour %d · sauvegarde automatique", rank, fmtMoney(money), day)
end
saveInfo(); LP.AttributeChanged:Connect(saveInfo)
-- vue 3D du terrain du joueur (dernier état) : ton jeu place son modèle dans workspace.Plots[NomDuJoueur] ou indique son chemin dans l'attribut "PlotPath"
task.spawn(function()
	local plotModel
	for _ = 1, 20 do
		local path = LP:GetAttribute("PlotPath")
		if path then plotModel = workspace:FindFirstChild(path, true) end
		if not plotModel and workspace:FindFirstChild("Plots") then plotModel = workspace.Plots:FindFirstChild(LP.Name) end
		if plotModel then break end
		task.wait(0.5)
	end
	if plotModel and plotModel:IsA("Model") then
		local vp = choose.PlotView
		local wm = Instance.new("WorldModel"); wm.Parent = vp
		local m = plotModel:Clone(); m.Parent = wm
		local cf, size = m:GetBoundingBox(); local d = math.max(size.X, size.Z)
		local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam; cam.FieldOfView = 40
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(-d * 0.6, d * 0.55, d * 0.75), cf.Position)
		vp.Visible = true
	end
end)
do
	local nd = choose.NewsDrop; local open = false
	pressFx(choose.News)
	choose.News.Activated:Connect(function()
		open = not open
		if open then setFaded(nd); nd.Visible = true; fadeFrame(nd, 0, 0.2) else fadeFrame(nd, 1, 0.15); task.delay(0.16, function() if not open then nd.Visible = false end end) end
	end)
end
do
	local hero, baseHero = choose.Hero, choose.Hero.Position
	local bubbles = {}
	for _, n in ipairs({"B1", "B2", "B3", "B4"}) do local b = choose[n]; table.insert(bubbles, {f = b, base = b.Position, t = math.random() * 8, dur = 7 + math.random() * 3, dx = math.random(-20, 20)}) end
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		if not start.Enabled then return end
		t += dt
		hero.Position = baseHero + UDim2.fromOffset(0, -13 + 13 * math.cos(t * 2 * math.pi / 6)); hero.Rotation = 0.4 * math.sin(t * 2 * math.pi / 6)
		for _, b in ipairs(bubbles) do
			b.t += dt; if b.t > b.dur then b.t = 0; b.dx = math.random(-20, 20) end
			local p = b.t / b.dur; b.f.Position = b.base + UDim2.fromOffset(b.dx * p, -260 * p); b.f.BackgroundTransparency = 1 - math.min(1, p * 5) * (1 - p) * 0.8
		end
	end)
end
local starting = false
local hint
pressFx(choose.Center.Choose)
choose.Center.Choose.Activated:Connect(function()
	if starting then return end; starting = true
	-- la voiture grise démarre : animation 3D image par image (roues qui tournent, ombre, occlusion par la station)
	local car = choose.Hero.Car
	local DD = require(car.DriveData)
	pcall(function()
		local id = SND.engine and SND.engine.id
		if id and id ~= "" then
			local s = Instance.new("Sound"); s.SoundId = id; s.Volume = SND.engine.volume or 0.6; s.PlaybackSpeed = 0.7; s.Parent = SoundService; s:Play()
			TweenService:Create(s, TweenInfo.new(2.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {PlaybackSpeed = 1.7}):Play()
			task.delay(2.6, function() s:Destroy() end)
		end
	end)
	local fps, n = 30, #DD.frames
	local t0 = os.clock(); local last = 0
	while true do
		local i = math.floor((os.clock() - t0) * fps) + 1
		if i > n then break end
		if i ~= last then
			last = i; local f = DD.frames[i]
			car.Image = DD.sheets[f.s]; car.ImageRectOffset = Vector2.new(f.rx, f.ry); car.ImageRectSize = Vector2.new(f.rw, f.rh)
			car.Position = UDim2.fromOffset(f.x, f.y); car.Size = UDim2.fromOffset(f.w, f.h)
		end
		RunService.RenderStepped:Wait()
	end
	car.Visible = false
	play("open")
	local fade = Instance.new("Frame"); fade.Size = UDim2.fromScale(1, 1); fade.BackgroundColor3 = Color3.fromHex("0c3054"); fade.BackgroundTransparency = 1; fade.ZIndex = 100; fade.Parent = start
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 0); lbl.Position = UDim2.fromScale(0, 0.47); lbl.BackgroundTransparency = 1; lbl.Text = "Chargement du garage…"; lbl.TextColor3 = Color3.new(1, 1, 1); lbl.TextSize = 34; lbl.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold); lbl.TextTransparency = 1; lbl.ZIndex = 101; lbl.Parent = fade
	TweenService:Create(fade, TweenInfo.new(0.45), {BackgroundTransparency = 0.05}):Play(); TweenService:Create(lbl, TweenInfo.new(0.45), {TextTransparency = 0}):Play()
	task.wait(0.9)
	start.Enabled = false; main.Enabled = false
	-- choix de l'emplacement (caméra libre gérée par ton jeu)
	plot.Enabled = true
	local pc = plot.Choose
	setFaded(pc); fit(); fadeFrame(pc, 0, 0.35); play("schling")
	fade:Destroy()
end)

do
	local pc = plot.Choose; local center = pc.Center
	local n, i = 4, 1
	local function dots() for k = 1, n do local d = center.Dots["D" .. k]; d.BackgroundColor3 = (k == i) and Color3.fromHex("ffd257") or Color3.new(1, 1, 1); d.BackgroundTransparency = (k == i) and 0 or 0.45 end end
	pressFx(center.Minus); pressFx(center.Plus); pressFx(center.Choose)
	center.Minus.Activated:Connect(function() i = (i - 2) % n + 1; dots() end)
	center.Plus.Activated:Connect(function() i = i % n + 1; dots() end)
	local chosen = false
	center.Choose.Activated:Connect(function()
		if chosen then return end; chosen = true; play("open")
		fadeFrame(pc, 1, 0.3); task.wait(0.3)
		plot.Enabled = false
		-- l'interface de jeu est fermée à l'arrivée : touche M pour l'ouvrir
		hint = Instance.new("TextLabel"); hint.Size = UDim2.new(1, 0, 0, 30); hint.Position = UDim2.new(0, 0, 1, -44); hint.BackgroundTransparency = 1; hint.Text = "Appuie sur  M  pour ouvrir le menu"; hint.TextColor3 = Color3.new(1, 1, 1); hint.TextSize = 18
		hint.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold); hint.TextStrokeTransparency = 0.5
		local hg = Instance.new("ScreenGui"); hg.Name = "Hint"; hg.IgnoreGuiInset = true; hg.ResetOnSpawn = false; hg.Parent = pg; hint.Parent = hg
	end)
	dots()
end


-- ===== onglets : fondu + glissement, pastille active, ouverture/fermeture avec M =====
local TABS = {"Build", "Index", "Staff", "Stock", "Supply", "Station"}
local current = nil
local hudOpen = false
local function setPill(name)
	for _, n in ipairs(TABS) do hud.BarArt["Active_" .. n].Visible = (n == name) end
	hud.BarArt.Inactive_Supply.Visible = (name ~= "Supply")
end
local function showPanel(p, on)
	local art = p.Art
	if on then
		p.Visible = true; setFaded(p); art.Position = UDim2.fromOffset(0, 18)
		TweenService:Create(art, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		fadeFrame(p, 0, 0.2)
	else
		fadeFrame(p, 1, 0.14)
		TweenService:Create(art, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromOffset(0, 12)}):Play()
		task.delay(0.15, function() if current ~= p.Name then p.Visible = false end end)
	end
end
local function showTab(name)
	if name == current then return end
	local prev = current; current = name
	if prev then showPanel(menus[prev], false) end
	if name then showPanel(menus[name], true); setPill(name) end
end
local function setHud(open)
	hudOpen = open
	if open then
		main.Enabled = true; fit()
		hud.Position = UDim2.fromOffset(0, 70); TweenService:Create(hud, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(0, 0)}):Play()
		showTab("Stock"); play("open")
	else
		play("close")
		if current then showPanel(menus[current], false); current = nil end
		menus.Ranks.Visible = false; menus.Shop.Visible = false
		local tw = TweenService:Create(hud, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromOffset(0, 70)})
		tw:Play(); tw.Completed:Once(function() if not hudOpen then main.Enabled = false end end)
	end
end
pressFx(hud.Low2.Shop)
for _, n in ipairs(TABS) do
	local b = hud.Low2[n]; b.Active = true; b.Selectable = true; pressFx(b)
	b.Activated:Connect(function() showTab(n) end)
	b.MouseButton1Click:Connect(function() showTab(n) end)
end
for _, p in ipairs(TABS) do menus[p].Visible = false end
game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.M and not start.Enabled and not plot.Enabled and starting then
		if hint then hint.Parent:Destroy(); hint = nil end
		setHud(not hudOpen)
	end
end)
do
	local lo = hud.Low1
	local function money()
		local v = LP:GetAttribute("Money")
		if v == nil then local ls = LP:FindFirstChild("leaderstats"); local mv = ls and (ls:FindFirstChild("Money") or ls:FindFirstChild("Cash")); v = mv and mv.Value end
		lo.Money.V.Text = fmtMoney(v or 0)
	end
	local function xp()
		local x, n = LP:GetAttribute("XP") or 0, LP:GetAttribute("XPNext") or 1000
		local rank = LP:GetAttribute("Rank") or "Bronze I"
		lo.Rank.RankName.Text = string.upper(rank)
		lo.Rank.Medal.T.Text = rank:match("(%S+)$") or ""
		lo.Rank.XP.Text = string.format("%s / %s XP", tostring(x):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""), tostring(n):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", ""))
		TweenService:Create(lo.Rank.Track.Fill, TweenInfo.new(0.4), {Size = UDim2.fromScale(math.clamp(x / math.max(1, n), 0, 1), 1)}):Play()
	end
	money(); xp(); LP.AttributeChanged:Connect(function() money(); xp() end)
	task.spawn(function()
		local ls = LP:WaitForChild("leaderstats", 10)
		if ls then for _, v in ipairs(ls:GetChildren()) do if v:IsA("ValueBase") then v.Changed:Connect(money) end end; money() end
	end)
	task.spawn(function()
		local sh = lo.Rank.Track.Shine
		while true do sh.Position = UDim2.fromOffset(-40, 0); TweenService:Create(sh, TweenInfo.new(1.4, Enum.EasingStyle.Sine), {Position = UDim2.fromOffset(240, 0)}):Play(); task.wait(2.8) end
	end)
end
pressFx(hud.Low1.Rank)
-- ===== Rangs : fenêtre avec les 8 rangs ; clic sur un rang = critères, taux d'apparition, objets =====
do
	local rk = menus.Ranks
	local function pick(k) for i = 0, 7 do rk.Sel["S" .. i].Visible = (i == k) end end
	local function openRanks(on)
		if on then rk.Visible = true; setFaded(rk); fadeFrame(rk, 0, 0.2); play("open")
		else fadeFrame(rk, 1, 0.15); task.delay(0.16, function() rk.Visible = false end); play("close") end
	end
	for i = 1, 8 do local b = rk.Hits["Rank" .. i]; pressFx(b); b.Activated:Connect(function() pick(i - 1) end) end
	pressFx(rk.Hits.Close); rk.Hits.Close.Activated:Connect(function() openRanks(false) end)
	-- rang actuel du joueur (attribut RankIndex 1..8), sinon Gold III
	pick((LP:GetAttribute("RankIndex") or 4) - 1)
	hud.Low1.Rank.Activated:Connect(function() openRanks(not rk.Visible) end)
end

-- ===== Shop : Game Pass / Argent / Voitures =====
-- Remplis ces identifiants (Créations → ton expérience → Monétisation) : Game Pass pour l'onglet 1, produits développeur pour les onglets 2 et 3
local SHOP = {
	GamePass = {0, 0, 0, 0},   -- Argent x2, VIP, Livraison express, Employés auto
	Money    = {0, 0, 0, 0},   -- Petit sac, Coffre, Trésor, Pack démarrage   (produits développeur)
	Cars     = {0, 0, 0, 0},   -- F448 Légendaire, Follie Mythique, M4 Divine, Class G Épique (produits développeur)
}
do
	local sh = menus.Shop; local tab = "GamePass"
	local MPS = game:GetService("MarketplaceService")
	local function setTab(t) tab = t; sh.Tabs.T0.Visible = (t == "GamePass"); sh.Tabs.T1.Visible = (t == "Money"); sh.Tabs.T2.Visible = (t == "Cars") end
	local function openShop(on)
		if on then sh.Visible = true; setFaded(sh); fadeFrame(sh, 0, 0.2); play("open")
		else fadeFrame(sh, 1, 0.15); task.delay(0.16, function() sh.Visible = false end); play("close") end
	end
	for _, t in ipairs({"GamePass", "Money", "Cars"}) do local b = sh.Hits[t]; pressFx(b); b.Activated:Connect(function() setTab(t) end) end
	for i = 1, 4 do
		local b = sh.Hits["Buy" .. i]; pressFx(b)
		b.Activated:Connect(function()
			local id = SHOP[tab][i]
			if not id or id == 0 then warn("[StationTycoon] Shop : identifiant manquant pour " .. tab .. " #" .. i); return end
			if tab == "GamePass" then MPS:PromptGamePassPurchase(LP, id) else MPS:PromptProductPurchase(LP, id) end
		end)
	end
	pressFx(sh.Hits.Close); sh.Hits.Close.Activated:Connect(function() openShop(false) end)
	hud.Low2.Shop.Activated:Connect(function() openShop(not sh.Visible) end)
	setTab("GamePass")
end

-- ===== Stock =====
local ok_, err_ = pcall(function()
	local st = menus.Stock; local prices = {10, 10, 65, 25, 30, 120, 90, 40, 35}; local sel, qty = 1, 1
	local function refresh()
		for i = 1, 9 do st.Variants["V" .. i].Visible = (i == sel); local r = st.Center[tostring(i)]; r.Image = (i == sel) and r.Sel.Value or r.Src.Value end
		st.Right.Box.Text = tostring(qty); st.Right.Price.Text = (prices[sel] * qty) .. "$"
	end
	-- familles : Lavage (1-3), Énergie (4-6), Pièces auto (7-9)
	local function setFam(f)
		for k = 0, 2 do st.Fams["F" .. k].Visible = (k == f) end
		for i = 1, 9 do st.Center[tostring(i)].Visible = (st.Center[tostring(i)].Fam.Value == f) end
		sel = f * 3 + 1; qty = 1; refresh()
	end
	for k, n in ipairs({"Wash", "Energy", "Parts"}) do local b = st.Left[n]; pressFx(b); b.Activated:Connect(function() setFam(k - 1) end) end
	-- prochaine livraison : attribut NextDelivery (os.time() de la prochaine livraison) posé par ton serveur ; sinon cycle d'une minute
	task.spawn(function()
		local d = st.Delivery; local t0 = os.time()
		while true do
			local nxt = LP:GetAttribute("NextDelivery")
			local left = nxt and math.max(0, nxt - os.time()) or (60 - ((os.time() - t0) % 60))
			d.Time.Text = string.format("%d:%02d", math.floor(left / 60), left % 60)
			d.Ring.Prog.Transparency = 0; d.Ring.Prog.Color = (left <= 5) and Color3.fromHex("ffd257") or Color3.fromHex("2dbd75")
			if left == 0 then local sc = d:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", d); sc.Scale = 1.08; TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Scale = 1}):Play() end
			task.wait(1)
		end
	end)
	for i = 1, 9 do local b = st.Center[tostring(i)]; b.Activated:Connect(function() sel = i; qty = 1; refresh() end); b.MouseEnter:Connect(function() play("hover") end); b.MouseButton1Down:Connect(function() play("click") end) end
	pressFx(st.Right.Minus); pressFx(st.Right.Plus)
	st.Right.Minus.Activated:Connect(function() qty = math.max(1, qty - 1); refresh() end)
	st.Right.Plus.Activated:Connect(function() qty = math.min(50, qty + 1); refresh() end)
	st.Right.Buy.Activated:Connect(function()
		play("buy")
		local sc = st.Right.Buy:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", st.Right.Buy); sc.Scale = 0.94
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
		-- ← ici : envoyer l'achat au serveur (produit sel, quantité qty)
	end)
	refresh()
end)
if not ok_ then warn("[StationTycoon] " .. "Stock : " .. tostring(err_)) end


-- ===== Supply =====
local ok_, err_ = pcall(function()
	local sp = menus.Supply
	local function select(k)
		for i = 1, 9 do local b = sp.Center[tostring(i)]; b.Image = (i == k) and b.Sel.Value or b.Src.Value end
	end
	local FIRST = {2, 4, 7}
	local function setFam(f)
		for k = 0, 2 do sp.Fams["F" .. k].Visible = (k == f) end
		for i = 1, 9 do sp.Center[tostring(i)].Visible = (sp.Center[tostring(i)].Fam.Value == f) end
		select(FIRST[f + 1])
	end
	for k, n in ipairs({"Wash", "Energy", "Parts"}) do local b = sp.Left[n]; pressFx(b); b.Activated:Connect(function() setFam(k - 1) end) end
	for i = 1, 9 do local b = sp.Center[tostring(i)]; b.Activated:Connect(function() select(i) end); b.MouseEnter:Connect(function() play("hover") end); b.MouseButton1Down:Connect(function() play("click") end) end
	setFam(0)
end)
if not ok_ then warn("[StationTycoon] " .. "Supply : " .. tostring(err_)) end


-- ===== Staff =====
local ok_, err_ = pcall(function()
	local sf = menus.Staff; local tpl = sf.Staff.Template; local list = sf.Left.List
	local names = {"Michel", "Léa", "Karim", "Sophie", "Nabil", "Chloé", "Yanis", "Inès"}; local count = 0
	local G = ColorSequence.new(Color3.fromHex("23a866"), Color3.fromHex("127f4b")); local W = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHex("eef0ea"))
	local function add(role)
		if count >= 8 then return end; count += 1
		local row = tpl:Clone(); row.Visible = true; row.Name = "Emp" .. count; row.LayoutOrder = count
		row.N.Text = names[count]; row.Av.T.Text = names[count]:sub(1, 1); row.Av.BackgroundColor3 = Color3.fromHex(({Attendant = "2f7fd6", Caissier = "8e44d6", Logistique = "e0862a", ["Agent d'entretien"] = "17a2b8"})[role] or "2f7fd6")
		local assigned = false
		local function paint() row:FindFirstChildOfClass("UIGradient").Color = assigned and G or W; row.N.TextColor3 = assigned and Color3.new(1, 1, 1) or Color3.fromHex("213038"); row.R.TextColor3 = assigned and Color3.fromHex("d6f2e2") or Color3.fromHex("5b6b70"); row.R.Text = role .. (assigned and " ✓" or "") end
		row.Assign.Activated:Connect(function() assigned = true; paint() end); row.UnAssign.Activated:Connect(function() assigned = false; paint() end); row.Fire.Activated:Connect(function() row:Destroy(); count -= 1 end)
		paint(); row.Parent = list
	end
	pressFx(sf.Top.Hire); pressFx(sf.Top.Assign)
	for n, role in pairs({Attendant = "Attendant", Cashier = "Caissier", Logistics = "Logistique", Cleaner = "Agent d'entretien"}) do
		local b = sf.CenterHire[n].Hire; pressFx(b); b.Activated:Connect(function() add(role) end)   -- ← ici : demander le recrutement au serveur
	end
	sf.Top.Hire.Activated:Connect(function() sf.Assign.Visible = false; sf.CenterHire.Visible = true end)
	sf.Top.Assign.Activated:Connect(function() sf.Assign.Visible = true; sf.CenterHire.Visible = false end)
	add("Attendant")
end)
if not ok_ then warn("[StationTycoon] " .. "Staff : " .. tostring(err_)) end


-- ===== Index =====
local ok_, err_ = pcall(function()
	local ix = menus.Index
	local FILTERS = {All = "all", Common = "commune", Uncommon = "peucommune", Rare = "rare", Epic = "epique", Legendary = "legendaire", Mythic = "mythique", Divine = "divine"}
	local CARS = { {"ClassG", "commune"}, {"M4", "commune"}, {"M4", "peucommune"}, {"F448", "peucommune"}, {"Follie", "rare"}, {"ClassG", "rare"}, {"F448", "epique"}, {"M4", "epique"}, {"Follie", "legendaire"}, {"ClassG", "legendaire"}, {"F448", "mythique"}, {"Follie", "divine"} }
	local carModels = RS:FindFirstChild("CarModels")
	local function viewport(vp, modelName)
		local model = carModels and carModels:FindFirstChild(modelName); if not model then return nil end
		for _, ch in ipairs(vp:GetChildren()) do if ch:IsA("WorldModel") or ch:IsA("Camera") then ch:Destroy() end end
		local world = Instance.new("WorldModel"); world.Parent = vp; local m = model:Clone(); m.Parent = world
		local cf, size = m:GetBoundingBox(); local d = math.max(size.X, size.Z)
		local cam = Instance.new("Camera"); cam.Parent = vp; vp.CurrentCamera = cam
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, d * 0.55, -d * 1.45), cf.Position); cam.FieldOfView = 32
		m:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, math.rad(40), 0)); vp.Visible = true; return m
	end
	local cards = {}
	for i = 1, 12 do cards[i] = ix.Center[string.format("IndexCard_%02d", i)] end
	local function layout(filter)
		local k = 0
		for i, c in ipairs(CARS) do
			local card = cards[i]
			if filter == "all" or c[2] == filter then
				local col, row = k % 3, math.floor(k / 3); k += 1
				card.Position = UDim2.fromOffset(4 + col * 263, 4 + row * 186); card.Visible = true
			else card.Visible = false end
		end
		ix.Center.CanvasSize = UDim2.fromOffset(0, 8 + math.ceil(k / 3) * 186)
	end
	for i, c in ipairs(CARS) do
		local card = cards[i]
		local model = nil; local angle, conn = math.rad(40), nil
		card.Clic.MouseEnter:Connect(function() if model and not conn then conn = RunService.RenderStepped:Connect(function(dt) angle += dt * 1.2; local cf = model:GetPivot(); model:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, angle, 0)) end) end end)
		card.Clic.MouseLeave:Connect(function() if conn then conn:Disconnect(); conn = nil end end)
		card.Clic.Activated:Connect(function()
			ix.Plus.Visible = true
			local pm = nil
			if pm then local a = math.rad(40); local pc; pc = RunService.RenderStepped:Connect(function(dt) if not ix.Plus.Visible then pc:Disconnect(); return end a += dt * 0.8; local cf = pm:GetPivot(); pm:PivotTo(CFrame.new(cf.Position) * CFrame.Angles(0, a, 0)) end) end
		end)
	end
	ix.Plus.Close.Activated:Connect(function() ix.Plus.Visible = false end)
	for name, id in pairs(FILTERS) do local b = ix.Right[name]; pressFx(b); b.Activated:Connect(function() layout(id) end) end
	layout("all")
end)
if not ok_ then warn("[StationTycoon] " .. "Index : " .. tostring(err_)) end


-- ===== Build =====
local ok_, err_ = pcall(function()
	local bd = menus.Build
	local DATA = require(bd.Build.BuildData)
	local tpl = bd.Build.TemplateBouton
	local CATS = {Floor = "sol", Wall = "murs", Furniture = "stations", Utility = "utilitaires", Deco = "deco", Roof = "toit"}
	local selected
	local toast = Instance.new("TextLabel"); toast.Size = UDim2.fromOffset(600, 36); toast.Position = UDim2.fromOffset(660, 600); toast.BackgroundColor3 = Color3.fromHex("178f55"); toast.TextColor3 = Color3.new(1, 1, 1); toast.TextSize = 13
	toast.FontFace = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.ExtraBold); toast.Visible = false; toast.ZIndex = 35; toast.Parent = bd; Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 18)
	local function fill(cat)
		for _, c in ipairs(bd.Center:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for _, k in ipairs({"sol", "murs", "stations", "utilitaires", "deco", "toit"}) do bd.Variants["V_" .. k].Visible = (k == cat) end
		for i, it in ipairs(DATA[cat]) do
			local card = tpl:Clone(); card.Visible = true; card.Name = it.id; card.Position = UDim2.fromOffset(4 + (i - 1) * 228, 4)
			card.NameL.Text = it.name
			local sz = it.small and 137 or 202
			card.Img.Size = UDim2.fromOffset(sz, sz); card.Img.Position = UDim2.fromOffset(105 - sz / 2, 103 - sz / 2)
			local idx = 0
			local function paint()
				local sheet, j = it.assetId, idx
				if it.split and idx >= it.split then sheet, j = it.assetId2, idx - it.split end
				card.Img.Image = "rbxassetid://" .. tostring(sheet or 0)
				card.Img.ImageRectSize = Vector2.new(it.fw, it.fh); card.Img.ImageRectOffset = Vector2.new(j * it.fw, 0)
				card.Counter.Text = (idx + 1) .. " / " .. it.frames; card.Counter.Visible = it.frames > 1; card.Prev.Visible = it.frames > 1; card.Next.Visible = it.frames > 1
				card.Tex.Text = it.labels[idx + 1] or ""
				for _, d in ipairs(card.Dots:GetChildren()) do if d:IsA("Frame") then d:Destroy() end end
				if it.frames > 1 then for j = 1, it.frames do local d = Instance.new("Frame"); d.Size = UDim2.fromOffset(8, 8); d.BackgroundColor3 = (j == idx + 1) and Color3.fromHex("ffd257") or Color3.new(1, 1, 1); d.BackgroundTransparency = (j == idx + 1) and 0 or 0.45; d.BorderSizePixel = 0; d.LayoutOrder = j; d.ZIndex = 26; d.Parent = card.Dots; Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0) end end
			end
			card.Prev.Activated:Connect(function() idx = (idx - 1 + it.frames) % it.frames; paint() end)
			card.Next.Activated:Connect(function() idx = (idx + 1) % it.frames; paint() end)
			card.Select.Activated:Connect(function()
				selected = it.name
				for _, c2 in ipairs(bd.Center:GetChildren()) do if c2:IsA("Frame") and c2:FindFirstChild("FrameSel") then c2.FrameSel.Visible = (c2 == card); c2.Frame.Visible = (c2 ~= card) end end
			end)
			paint(); card.Parent = bd.Center
		end
		bd.Center.CanvasSize = UDim2.fromOffset(8 + #DATA[cat] * 228, 0); bd.Center.CanvasPosition = Vector2.new(0, 0)
	end
	for n, cat in pairs(CATS) do local b = bd.Left[n]; pressFx(b); b.Activated:Connect(function() fill(cat) end) end

	local rot = 0
	local function show(txt, red) toast.Text = txt; toast.BackgroundColor3 = red and Color3.fromHex("c0302a") or Color3.fromHex("178f55"); toast.Visible = true end
	bd.Top.Rotate.Activated:Connect(function() rot = (rot + 90) % 360; show("Rotation : " .. rot .. "°") end)
	bd.Top.Place.Activated:Connect(function() show("Mode placement : clique au sol pour poser « " .. (selected or "un objet") .. " »") end)
	local mode = nil
	local function setMode(m)
		mode = (mode == m) and nil or m
		for _, k in ipairs({"move", "del", "path", "deco"}) do bd.Top["Active_" .. k].Visible = (mode == k) end
		if mode == "move" then show("Mode déplacement : clique un objet puis sa nouvelle place")
		elseif mode == "del" then show("Mode suppression : clique un objet pour le retirer", true)
		elseif mode == "path" then show("Mode trajectoire : trace le chemin des voitures"); toast.BackgroundColor3 = Color3.fromHex("7b2fc0")
		elseif mode == "deco" then show("Mode décoration : place des éléments décoratifs")
		else toast.Visible = false end
		bd:SetAttribute("Mode", mode or "")   -- ton script de construction peut écouter cet attribut
	end
	for n, m in pairs({Move = "move", Delete = "del", Path = "path", Deco = "deco"}) do local b = bd.Top[n]; pressFx(b); b.Activated:Connect(function() setMode(m) end) end
	bd.Top.Cancel.Activated:Connect(function() toast.Visible = false end)
	bd.Top.Close.Activated:Connect(function() toast.Visible = false; bd.Visible = false end)
	fill("stations")
end)
if not ok_ then warn("[StationTycoon] " .. "Build : " .. tostring(err_)) end

