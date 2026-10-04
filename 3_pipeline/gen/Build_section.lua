-- ===== Build =====
section("Build", function()
	local bd = menus.Build
	local DATA = require(bd.Build.BuildData)
	local tpl = bd.Build.TemplateBouton
	local CATS = {Floor = "sol", Wall = "murs", Furniture = "mobilier", Roof = "toit"}
__CARTES__
	-- cartes sans sprite ajoutees aux donnees de l'interface (apercu 3D de chaque variante)
	for _, c in ipairs(CARTES_EXTRA) do
		local id, onglet, titre = c[1], c[2], c[3]
		DATA[onglet] = DATA[onglet] or {}
		local deja = false
		for _, it in ipairs(DATA[onglet]) do if it.id == id then deja = true end end
		if not deja then table.insert(DATA[onglet], {id = id, name = titre, labels = {}, frames = 0, fw = 180, fh = 180, assetId = 0, titre3D = titre}) end
	end
	-- variantes d'une carte : seules celles dont le modele existe sont proposees (les autres sont annoncees "bientot")
	local function variantes(id)
		local c = CARTES[id]
		if not c then return nil, {} end
		return c[1], c[2]
	end
	local function objetDe(id, idx)
		local cat_, liste = variantes(id)
		local nom = liste[idx + 1]
		if not (cat_ and nom) then return nil end
		local dossier = RS:FindFirstChild(cat_)
		if not (dossier and dossier:FindFirstChild(nom)) then return nil end
		return cat_, nom
	end
	-- apercu 3D d'un modele du catalogue dans une carte (a la place du sprite quand il n'y en a pas)
	local function apercu3D(card, cat_, nom)
		local vp = card:FindFirstChild("Apercu")
		if not vp then
			vp = Instance.new("ViewportFrame"); vp.Name = "Apercu"; vp.Size = card.Img.Size; vp.Position = card.Img.Position; vp.AnchorPoint = card.Img.AnchorPoint
			vp.ZIndex = card.Img.ZIndex; vp.BackgroundTransparency = 1; vp.Ambient = Color3.fromRGB(170, 170, 170); vp.LightColor = Color3.fromRGB(255, 250, 240); vp.LightDirection = Vector3.new(-1, -2, -1)
			vp.Parent = card
		end
		for _, ch in ipairs(vp:GetChildren()) do ch:Destroy() end
		local dossier = cat_ and RS:FindFirstChild(cat_)
		local modele = dossier and nom and dossier:FindFirstChild(nom)
		if not modele then vp.Visible = false; return end
		local world = Instance.new("WorldModel"); world.Parent = vp
		local m = modele:Clone()
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") or d:IsA("Sound") then d:Destroy() end end
		m.Parent = world
		local cf, taille = m:GetBoundingBox()
		local piv = m:GetPivot()
		local diag = taille.Magnitude
		local cam = Instance.new("Camera"); cam.FieldOfView = 30; cam.Parent = vp; vp.CurrentCamera = cam
		local dist = (diag / 2) / math.tan(math.rad(cam.FieldOfView / 2)) * 1.05
		-- murs : on regarde la face avant (axe X du pivot) ; sinon vue de trois quarts
		local dir = (cat_ == "Mur") and (piv.XVector * 1 + piv.YVector * 0.35 + piv.ZVector * 0.45) or (piv.XVector * 0.8 + piv.YVector * 0.7 + piv.ZVector * 1)
		cam.CFrame = CFrame.lookAt(cf.Position + dir.Unit * dist, cf.Position)
		vp.Visible = true
	end
	local categorieActuelle = "mobilier"
	local function fill(cat)
		categorieActuelle = cat
		for _, c in ipairs(bd.Art.Center:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for _, k in ipairs({"sol", "murs", "mobilier", "toit"}) do local v = bd.Art.Variants:FindFirstChild("V_" .. k) if v then v.Visible = (k == cat) end end
		for i, it in ipairs(DATA[cat] or {}) do
			local card = tpl:Clone(); card.Visible = true; card.Name = it.id; card.Position = UDim2.fromOffset(4 + (i - 1) * 212, 4)
			local idx = 0
			local _, liste = variantes(it.id)
			local total = math.max(#liste, it.frames or 0, 1)
			local function paint()
				local cat_, nom = objetDe(it.id, idx)
				local infos = cat_ and Catalogue.GetInfo(cat_, nom)
				local prix = infos and infos.Prix
				local sprite = (it.frames or 0) > idx and (it.assetId or 0) ~= 0
				if sprite then
					card.Img.Visible = true
					card.Img.Image = "rbxassetid://" .. tostring(it.assetId)
					card.Img.ImageRectSize = Vector2.new(it.fw, it.fh); card.Img.ImageRectOffset = Vector2.new(idx * it.fw, 0)
					local vp = card:FindFirstChild("Apercu"); if vp then vp.Visible = false end
				else
					card.Img.Visible = false
					apercu3D(card, cat_, nom or liste[idx + 1])
				end
				card.Counter.Text = (idx + 1) .. " / " .. total; card.Counter.Visible = total > 1; card.Prev.Visible = total > 1; card.Next.Visible = total > 1
				local libelle = it.labels[idx + 1]
				if not libelle then
					if infos then
						libelle = (infos.Nom or nom or "") .. (infos.Matiere and (" · " .. infos.Matiere) or "")
					else
						libelle = liste[idx + 1] or ""
					end
				end
				if it.titre3D and infos and infos.Nom and not it.labels[idx + 1] then libelle = (infos.Matiere and (infos.Nom .. " · " .. infos.Matiere) or infos.Nom) end
				card.Tex.Text = libelle .. (prix and ("  ·  " .. prix .. " $") or (cat_ and "" or "  ·  bientôt"))
				for _, d in ipairs(card.Dots:GetChildren()) do if d:IsA("Frame") then d:Destroy() end end
				if total > 1 then
					local taille = (total > 8) and 5 or 8
					for j = 1, total do local d = Instance.new("Frame"); d.Size = UDim2.fromOffset(taille, taille); d.BackgroundColor3 = (j == idx + 1) and Color3.fromHex("ffd257") or Color3.new(1, 1, 1); d.BackgroundTransparency = (j == idx + 1) and 0 or 0.45; d.BorderSizePixel = 0; d.LayoutOrder = j; d.ZIndex = 26; d.Parent = card.Dots; Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0) end
				end
			end
			pressFx(card.Prev); pressFx(card.Next); pressFx(card.Select)
			card.Prev.Activated:Connect(function() idx = (idx - 1 + total) % total; paint() end)
			card.Next.Activated:Connect(function() idx = (idx + 1) % total; paint() end)
			card.Select.Activated:Connect(function()
				local cat_, nom = objetDe(it.id, idx)
				if not cat_ then message("Cet objet n'est pas encore disponible dans le jeu", true) return end
				for _, c2 in ipairs(bd.Art.Center:GetChildren()) do if c2:IsA("Frame") and c2:FindFirstChild("FrameSel") then c2.FrameSel.Visible = (c2 == card); c2.Frame.Visible = (c2 ~= card) end end
				if ClientBuild then
					ClientBuild.DestroyLaser()
					ActionManager.ChangerMode("Construction", it.id .. ":" .. idx)
					ClientBuild.CreatePhantom(nom, cat_)
					if cat_ == "Mur" then
						message("Le mur se colle au bord de case le plus proche de la souris  ·  clic au sol ou Place pour poser  ·  R ou Rotate pour retourner la face avant", false, 5)
					else
						message("Déplace la souris et clique au sol (ou bouton Place) pour poser  ·  R ou Rotate pour tourner", false, 4)
					end
				end
			end)
			paint(); card.Parent = bd.Art.Center
		end
		bd.Art.Center.CanvasSize = UDim2.fromOffset(8 + #(DATA[cat] or {}) * 212, 0); bd.Art.Center.CanvasPosition = Vector2.new(0, 0)
	end
	for n, cat in pairs(CATS) do local b = bd.Left[n]; pressFx(b); b.Activated:Connect(function() if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser() end fill(cat) end) end
	for _, n in ipairs({"Rotate", "Place", "Delete", "Cancel", "Close"}) do pressFx(bd.Top[n]) end
	bd.Top.Rotate.Activated:Connect(function()
		if not ClientBuild then return end
		if not ClientBuild.EnPlacement() then message("Sélectionne d'abord un objet (bouton ✓ d'une carte)", true) return end
		local o, txt = ClientBuild.Tourner(); message(txt or ("Rotation : " .. (o * 90) .. "°"), false, 1.5)
	end)
	bd.Top.Place.Activated:Connect(function()
		if not ClientBuild then return end
		if not ClientBuild.EnPlacement() then message("Sélectionne d'abord un objet (bouton ✓ d'une carte)", true) return end
		local ok, raison = ClientBuild.Poser()
		if ok then play("buy") else message("Placement refusé : " .. tostring(raison), true) end
	end)
	bd.Top.Delete.Activated:Connect(function() if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.CreateLaser(); message("Mode suppression : clique un objet pour le retirer (remboursé)", true, 3) end end)
	bd.Top.Cancel.Activated:Connect(function() if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser() end ActionManager.ChangerMode("Aucun"); toast.Visible = false end)
	bd.Top.Close.Activated:Connect(function() showTab(nil) end)
	ouvrir.Build = function()
		if ClientBuild then ClientCamera.Activer(); ClientBuild.CreateExtension() end
		fill(categorieActuelle)
	end
	fermer.Build = function()
		ActionManager.ChangerMode("Aucun")
		if ClientBuild then ClientBuild.DestroyPhantom(); ClientBuild.DestroyLaser(); ClientBuild.DestroyExtension() end
		ClientCamera.Desactiver()
	end
end)
