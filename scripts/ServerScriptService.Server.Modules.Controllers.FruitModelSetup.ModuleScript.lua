--> FruitModelSetup (server)
-- Makes newly imported Meshy fruit models "just work" (see Databases.Fruits.FruitCatalog):
--   * a model named Meshy_AI_<Name>... left in Workspace is moved into Assets.Models.Fruits
--     (Meshy's "_Remesh_<numbers>_texture" suffix is removed from the name)
--   * main MeshPart -> "Handle" + PrimaryPart, non-colliding, anchored like Apple / Strawberry
--   * stood upright (Meshy exports come in lying on their back), centered on the origin
--   * scaled so the tallest side = catalog `scale` (default 4 studs)
-- Models already set up carry the attribute FruitReady = true and are never touched again.
-- Only runs on Meshy_AI_* models, so Apple / Strawberry / everything else is left alone.

local _L = _G._L

local DEFAULT_SCALE = 4

local FruitModelSetup = {}

local function catalog()
	local ok, c = pcall(require, game:GetService("ReplicatedStorage").Common.Modules.Databases.Fruits.FruitCatalog)
	return ok and c or nil
end

local function cleanName(name)
	return (name:gsub("_Remesh.*$", ""):gsub("_texture$", ""))
end

function FruitModelSetup.setup(model, dest)
	if not model:IsA("Model") or model:GetAttribute("FruitReady") then
		return false
	end
	local handle = model.PrimaryPart or model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("MeshPart", true)
	if not handle then
		warn("[FruitModelSetup] " .. model.Name .. " has no MeshPart - skipped")
		return false
	end
	local name = cleanName(model.Name)
	if dest:FindFirstChild(name) and dest[name] ~= model then
		warn("[FruitModelSetup] " .. name .. " already exists in Assets.Models.Fruits - skipped (no duplicates)")
		return false
	end
	handle.Name = "Handle"
	model.PrimaryPart = handle
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	-- upright (a Meshy export arrives rotated -90° on X) + centered
	handle.CFrame = CFrame.new()
	model.WorldPivot = CFrame.new()
	local entry = catalog() and catalog().get(name)
	local target = (entry and entry.scale) or DEFAULT_SCALE
	local size = handle.Size
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * target / biggest)
	end
	model:PivotTo(CFrame.new())
	model:SetAttribute("SourceName", model:GetAttribute("SourceName") or model.Name)
	model:SetAttribute("FruitReady", true)
	model.Name = name
	model.Parent = dest
	print("[FruitModelSetup] prepared " .. name)
	return true
end

------------------------------------------------------------ automatic eyes (for FruitAnimator blinking)
-- Meshy fruits have their eyes painted in the texture. We read the mesh (EditableMesh) + its colour map
-- (EditableImage), find the two dark painted eye blobs on the front (-Z) of the fruit, and put an
-- Attachment named "Eye" on each (same format as Strawberry: Size, LidColor, RefHeight).
-- Existing Eye attachments are never touched. If the eyes can't be found reliably: a warning, no eyes.
local AssetService = game:GetService("AssetService")

local function lum(r, g, b)
	return 0.299 * r + 0.587 * g + 0.114 * b
end

function FruitModelSetup.setupEyes(model)
	local handle = model:FindFirstChild("Handle") or model.PrimaryPart
	if not handle or not handle:IsA("MeshPart") then
		return false, "no mesh"
	end
	for _, c in ipairs(handle:GetChildren()) do
		if c:IsA("Attachment") and (c.Name == "Eye" or c.Name == "Eye2") then
			return true, "kept existing"
		end
	end
	local sa = handle:FindFirstChildOfClass("SurfaceAppearance")
	local colorMap = (sa and sa.ColorMap ~= "" and sa.ColorMap) or (handle.TextureID ~= "" and handle.TextureID)
	if not colorMap then
		return false, "no texture"
	end
	local okM, em = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromUri(handle.MeshId))
	end)
	local okI, ei = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(colorMap))
	end)
	if not okM or not okI or not em or not ei then
		if okM and em then em:Destroy() end
		if okI and ei then ei:Destroy() end
		return false, "could not read mesh/texture"
	end

	local ok, result, reason = pcall(function()
		local W, H = ei.Size.X, ei.Size.Y
		local pixels = ei:ReadPixelsBuffer(Vector2.zero, ei.Size)
		local function sample(uv)
			local x = math.clamp(math.floor(uv.X * W), 0, W - 1)
			local y = math.clamp(math.floor(uv.Y * H), 0, H - 1)
			local i = (y * W + x) * 4
			return buffer.readu8(pixels, i) / 255, buffer.readu8(pixels, i + 1) / 255, buffer.readu8(pixels, i + 2) / 255
		end

		-- mesh space -> handle space
		local verts = em:GetVertices()
		local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		local pos = {}
		for _, v in ipairs(verts) do
			local p = em:GetPosition(v)
			pos[v] = p
			mn, mx = mn:Min(p), mx:Max(p)
		end
		local ext, mid = mx - mn, (mx + mn) / 2
		local size = handle.Size
		local function toLocal(p)
			return Vector3.new((p.X - mid.X) / ext.X * size.X, (p.Y - mid.Y) / ext.Y * size.Y, (p.Z - mid.Z) / ext.Z * size.Z)
		end

		-- classify front-facing faces
		local dark, skin = {}, {}
		for _, f in ipairs(em:GetFaces()) do
			local fv = em:GetFaceVertices(f)
			local fu = em:GetFaceUVs(f)
			if #fv == 3 and #fu == 3 then
				local a, b, c = toLocal(pos[fv[1]]), toLocal(pos[fv[2]]), toLocal(pos[fv[3]])
				local center = (a + b + c) / 3
				local n = (b - a):Cross(c - a)
				local area = n.Magnitude / 2
				if area > 0 then
					n = n.Unit
					if n:Dot(center) < 0 then
						n = -n
					end
					if n.Z < -0.35 and center.Z < 0 then
						local uv = (em:GetUV(fu[1]) + em:GetUV(fu[2]) + em:GetUV(fu[3])) / 3
						local r, g, bb = sample(uv)
						local l = lum(r, g, bb)
						local item = {p = center, n = n, a = area, col = Color3.new(r, g, bb)}
						local sat = math.max(r, g, bb) - math.min(r, g, bb)
						if l < 0.16 and sat < 0.14 then -- painted eye: near-black, not a dark leaf / shell
							table.insert(dark, item)
						elseif l > 0.18 and math.max(r, g, bb) - math.min(r, g, bb) > 0.08 then
							table.insert(skin, item) -- coloured fruit skin (not white highlights / black)
						end
					end
				end
			end
		end

		-- two eyes = the dark area left and right of the middle (the mouth sits in the middle, lower)
		local function cluster(sign)
			local sx, sy, sz, sa2, nsum = 0, 0, 0, 0, Vector3.zero
			local list = {}
			for _, d in ipairs(dark) do
				if d.p.X * sign > size.X * 0.06 and d.p.Y > -size.Y * 0.35 and d.p.Y < size.Y * 0.3 then
					table.insert(list, d)
				end
			end
			if #list < 3 then
				return nil
			end
			-- the eye = the densest compact dark blob on this side (not scattered shading / mouth corners)
			local r = size.X * 0.12
			local best, bestScore = nil, -1
			for _, d in ipairs(list) do
				local score = 0
				for _, o in ipairs(list) do
					if (o.p - d.p).Magnitude < r then
						score += o.a
					end
				end
				if score > bestScore then
					best, bestScore = d, score
				end
			end
			local center = best.p
			local keep
			for _ = 1, 3 do -- recentre a few times on the blob
				keep = {}
				local acc, wsum = Vector3.zero, 0
				for _, d in ipairs(list) do
					if (d.p - center).Magnitude < r * 1.4 then
						table.insert(keep, d)
						acc += d.p * d.a
						wsum += d.a
					end
				end
				if wsum > 0 then
					center = acc / wsum
				end
			end
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
			for _, d in ipairs(keep) do
				sx += d.p.X * d.a
				sy += d.p.Y * d.a
				sz += d.p.Z * d.a
				sa2 += d.a
				nsum += d.n * d.a
				minX, maxX = math.min(minX, d.p.X), math.max(maxX, d.p.X)
				minY, maxY = math.min(minY, d.p.Y), math.max(maxY, d.p.Y)
			end
			if sa2 <= 0 then
				return nil
			end
			return {p = Vector3.new(sx / sa2, sy / sa2, sz / sa2), n = nsum.Unit, w = maxX - minX, h = maxY - minY, area = sa2}
		end
		local L, R = cluster(-1), cluster(1)
		if not L or not R then
			return nil, "no painted eyes found on the front"
		end
		-- sanity checks: roughly level, sensible spacing and size
		local sep = math.abs(L.p.X - R.p.X)
		if math.abs(L.p.Y - R.p.Y) > size.Y * 0.18 or sep < size.X * 0.12 or sep > size.X * 0.85 then
			return nil, "eye blobs not symmetric"
		end
		local results = {}
		for _, e in ipairs({L, R}) do
			local w = math.clamp(e.w, size.X * 0.06, size.X * 0.3)
			local h = math.clamp(e.h, size.Y * 0.06, size.Y * 0.3)
			-- lid colour = the skin right around the eye
			-- median (by brightness) of the skin right around the eye: ignores highlights / other colours
			local ring = {}
			local radius = math.max(w, h)
			for _, s2 in ipairs(skin) do
				local d = (s2.p - e.p).Magnitude
				if d > radius * 0.55 and d < radius * 1.5 then
					table.insert(ring, s2.col)
				end
			end
			if #ring < 3 then
				return nil, "no skin colour around the eyes"
			end
			table.sort(ring, function(c1, c2) return lum(c1.R, c1.G, c1.B) < lum(c2.R, c2.G, c2.B) end)
			local med = ring[math.ceil(#ring * 0.55)]
			local rr, gg, bb2, cnt = med.R, med.G, med.B, 1
			local out = e.n
			local p = e.p + out * 0.05
			table.insert(results, {
				cf = CFrame.lookAt(p, p - out),
				size = Vector2.new(w, h),
				lid = Color3.new(rr / cnt, gg / cnt, bb2 / cnt),
			})
		end
		return results
	end)
	em:Destroy()
	ei:Destroy()
	if not ok or not result then
		return false, tostring(if ok then reason else result)
	end
	for _, r in ipairs(result) do
		local a = Instance.new("Attachment")
		a.Name = "Eye"
		a.CFrame = r.cf
		a:SetAttribute("Size", r.size)
		a:SetAttribute("LidColor", r.lid)
		a:SetAttribute("RefHeight", handle.Size.Y)
		a:SetAttribute("AutoEye", true)
		a.Parent = handle
	end
	return true, "created"
end

function FruitModelSetup._init()
	local dest = game:GetService("ReplicatedStorage").Assets.Models.Fruits
	for _, container in ipairs({workspace, dest}) do
		for _, m in ipairs(container:GetChildren()) do
			if m.Name:find("^Meshy_AI_") then
				local ok, err = pcall(FruitModelSetup.setup, m, dest)
				if not ok then
					warn("[FruitModelSetup] " .. m.Name .. ": " .. tostring(err))
				end
				if m.Parent == dest then
					local okE, done, why = pcall(FruitModelSetup.setupEyes, m)
					if not okE or not done then
						warn("[FRUIT SETUP] Could not automatically position eyes for " .. m.Name .. " (" .. tostring(if okE then why else done) .. "). It still works, it just won't blink - add 2 'Eye' attachments by hand.")
					end
				end
			end
		end
	end
end

function FruitModelSetup._start() end

return FruitModelSetup
