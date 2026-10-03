--// ESP Controller (engine adapted from wa0101/Roblox-ESP esp.lua).
-- Deliberate deviations from the reference (all documented in the report):
--  * Team check uses Universery IsSameTeam (Universal Team Resolver).
--  * Visibility uses the shared CheckVisibilityCached (no duplicate raycasts).
--  * 3D-box connectors are persistent objects (reference allocated 4 Drawings per frame).
--  * Completed upstream stubs: HealthBarSide Right, NameMode switch, Distance text,
--    HealthFormat switch, Box fill square, UseTeamColors + per-category colors.
--  * Drawings are created lazily on first visible update (reference pre-creates all).
--  * Refresh interval adapts down when FPS collapses (reference fixed rate only).
--  * SkeletonTransparency default 0 (reference default 1 = invisible).
--  * Rainbow defaults Boxes/Tracers/Text true so the "All" label is truthful.
-- Skipped reference keys with no distinct behavior: TracerStyle (Line only),
-- SnaplineStyle (Straight only), DistanceUnit (studs only), ChamsOutlineThickness
-- (no such Highlight API exists).
local ESPDrawAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"
local ESPState = { Players = {}, Highlights = {}, Bodies = {}, JointCache = {}, Rainbow = nil, RainbowT = 0, Accum = 0, Interval = 1 / 144, FpsAccum = 0, FpsCount = 0, WasOn = false, Warned = false, ErrT = 0, TextOutlineOk = nil }

local function ESPMk(kind)
	if not ESPDrawAvailable then
		return nil
	end
	local ok, obj = pcall(function() return Drawing.new(kind) end)
	if ok and obj ~= nil then
		return obj
	end
	return nil
end

local function ESPNewLine()
	local l = ESPMk("Line")
	if l ~= nil then
		l.Visible = false
	end
	return l
end

-- Max simultaneous bones (R15 has 15 Motor6Ds incl. root).
local ESPMaxBones = 16

-- Screen-space correction: WorldToViewportPoint returns viewport-relative
-- coordinates (origin below the topbar), but Drawing renders in absolute
-- window pixels. Without this, every ESP element floats ~36px above targets.
local ESPInsetY = 0
pcall(function()
	local gs = GetService("GuiService")
	local inset = __index(gs, "GetGuiInset")(gs)
	if typeof(inset) == "Vector2" then
		ESPInsetY = inset.Y
	end
end)
if type(ESPInsetY) ~= "number" then
	ESPInsetY = 0
end

-- Base offset (px): slider 0 lands exactly here. Calibrated so the box hugs
-- the character; use the UI slider only for per-executor fine-tuning.
local ESPBaseYOffset = -38

-- Single projection point for ALL ESP drawing. Returns screen Vector2 (with
-- inset + manual offset applied), raw depth, and the onScreen flag.
-- Call sites keep their original gating conditions, only the source changes.
local function ESPProject(cam, worldPos)
	local okV, sp, onScreen = pcall(function() return WorldToViewportPoint(cam, worldPos) end)
	if not okV or sp == nil then
		return nil, nil, false
	end
	local extra = Environment.ESP.ScreenYOffset
	if type(extra) ~= "number" then
		extra = 0
	end
	return Vector2.new(sp.X, sp.Y + ESPInsetY + ESPBaseYOffset + extra), sp.Z, onScreen
end

local function ESPEnsurePlayer(player)
	if player == LocalPlayer then
		return false
	end
	if ESPState.Players[player] ~= nil then
		return true
	end
	if not ESPDrawAvailable then
		if not ESPState.Warned then
			ESPState.Warned = true
			warn("[ESP] Drawing API unavailable - ESP disabled.")
		end
		return false
	end
	local st = { Box = {}, BoxOut = {}, Con = {} }
	local i
	for i = 1, 8 do st.Box[i] = ESPNewLine() end
	for i = 1, 8 do st.BoxOut[i] = ESPNewLine() end
	for i = 1, 4 do st.Con[i] = ESPNewLine() end
	st.Fill = ESPMk("Square")
	if st.Fill ~= nil then
		st.Fill.Visible = false
		st.Fill.Filled = true
	end
	st.Tracer = ESPMk("Line")
	st.Snap = ESPMk("Line")
	st.Health = { Outline = ESPMk("Square"), Fill = ESPMk("Square"), Text = ESPMk("Text") }
	st.Info = { Name = ESPMk("Text"), Dist = ESPMk("Text") }
	if st.Tracer ~= nil then st.Tracer.Visible = false end
	if st.Snap ~= nil then st.Snap.Visible = false end
	if st.Health.Outline ~= nil then st.Health.Outline.Visible = false end
	if st.Health.Fill ~= nil then st.Health.Fill.Visible = false end
	if st.Health.Text ~= nil then st.Health.Text.Visible = false end
	if st.Info.Name ~= nil then st.Info.Name.Visible = false end
	if st.Info.Dist ~= nil then st.Info.Dist.Visible = false end
	st.Bones = {}
	for i = 1, ESPMaxBones do st.Bones[i] = ESPNewLine() end
	local okH, hl = pcall(function()
		local h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Enabled = false
		return h
	end)
	if okH and hl ~= nil then
		ESPState.Highlights[player] = hl
	end
	ESPState.Players[player] = st
	return true
end

local function ESPHidePlayer(player)
	local st = ESPState.Players[player]
	if st ~= nil then
		local function off(list)
			if list ~= nil then
				for _, o in next, list do
					if o ~= nil then
						pcall(function() o.Visible = false end)
					end
				end
			end
		end
		off(st.Box)
		off(st.BoxOut)
		off(st.Con)
		if st.Fill ~= nil then pcall(function() st.Fill.Visible = false end) end
		if st.Tracer ~= nil then pcall(function() st.Tracer.Visible = false end) end
		if st.Snap ~= nil then pcall(function() st.Snap.Visible = false end) end
		if st.Health ~= nil then off(st.Health) end
		if st.Info ~= nil then off(st.Info) end
		if st.Bones ~= nil then off(st.Bones) end
	end
	local hl = ESPState.Highlights[player]
	if hl ~= nil then
		pcall(function() hl.Enabled = false end)
	end
end

local function ESPHideAll()
	for player, _ in next, ESPState.Players do
		ESPHidePlayer(player)
	end
end

local function ESPRemovePlayer(player)
	ESPHidePlayer(player)
	ESPState.Bodies[player] = nil
	local st = ESPState.Players[player]
	if st ~= nil then
		local function wipe(list)
			if list ~= nil then
				for _, o in next, list do
					if o ~= nil then
						pcall(function() o:Remove() end)
					end
				end
			end
		end
		wipe(st.Box)
		wipe(st.BoxOut)
		wipe(st.Con)
		if st.Fill ~= nil then pcall(function() st.Fill:Remove() end) end
		if st.Tracer ~= nil then pcall(function() st.Tracer:Remove() end) end
		if st.Snap ~= nil then pcall(function() st.Snap:Remove() end) end
		if st.Health ~= nil then wipe(st.Health) end
		if st.Info ~= nil then wipe(st.Info) end
		if st.Bones ~= nil then wipe(st.Bones) end
		ESPState.Players[player] = nil
	end
	local hl = ESPState.Highlights[player]
	if hl ~= nil then
		pcall(function() hl:Destroy() end)
		ESPState.Highlights[player] = nil
	end
end

local function ESPCleanup()
	for player, _ in next, ESPState.Players do
		ESPRemovePlayer(player)
	end
	ESPState.Players = {}
	ESPState.Highlights = {}
	ESPState.Bodies = {}
	ESPState.WasOn = false
end

local function ESPIsTeammate(player)
	if not Environment.ESP.TeamCheck then
		return false
	end
	return IsSameTeam(LocalPlayer, player)
end

local function ESPCatColor(player, isMate, cat)
	local S = Environment.ESP
	if S.RainbowEnabled and ESPState.Rainbow ~= nil then
		if cat == "Box" and S.RainbowBoxes then return ESPState.Rainbow end
		if cat == "Tracer" and S.RainbowTracers then return ESPState.Rainbow end
		if cat == "Text" and S.RainbowText then return ESPState.Rainbow end
	end
	if S.UseTeamColors then
		if isMate then return S.AllyColor else return S.EnemyColor end
	end
	if cat == "Box" then return S.BoxColor end
	if cat == "Tracer" then return S.TracerColor end
	return S.NameColor
end

local function ESPLerpC(a, b, t)
	return Color3.fromRGB(
		mathfloor(a.R * 255 + (b.R * 255 - a.R * 255) * t),
		mathfloor(a.G * 255 + (b.G * 255 - a.G * 255) * t),
		mathfloor(a.B * 255 + (b.B * 255 - a.B * 255) * t))
end

local function ESPHealthColor(pct, full)
	if pct >= 0.5 then
		return ESPLerpC(Color3.fromRGB(255, 255, 0), full, (pct - 0.5) * 2)
	end
	return ESPLerpC(Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 0), pct * 2)
end

local function ESPSeg(line, x1, y1, x2, y2, color, thick)
	if line == nil then
		return
	end
	line.From = Vector2.new(x1, y1)
	line.To = Vector2.new(x2, y2)
	line.Color = color
	line.Thickness = thick
	line.Visible = true
end

-- Rig-agnostic joint discovery: reads the character's actual Motor6D rig
-- (works on R6, R15 and custom rigs). Cached per character; rebuilt on swap.
local function ESPGetJoints(player, character)
	local hit = ESPState.JointCache[player]
	if hit ~= nil and hit.Character == character and hit.Pairs ~= nil then
		return hit.Pairs
	end
	local found = {}
	if character ~= nil then
		local okD, descs = pcall(function() return GetDescendants(character) end)
		if okD and type(descs) == "table" then
			for _, inst in next, descs do
				local okM, isMotor = pcall(function() return inst:IsA("Motor6D") end)
				if okM and isMotor then
					local a, b
					pcall(function()
						a = inst.Part0
						b = inst.Part1
					end)
					if a ~= nil and b ~= nil then
						local okB, both = pcall(function() return a:IsA("BasePart") and b:IsA("BasePart") end)
						if okB and both then
							found[#found + 1] = { a, b }
							if #found >= ESPMaxBones then
								break
							end
						end
					end
				end
			end
		end
	end
	ESPState.JointCache[player] = { Character = character, Pairs = found }
	local pname = "?"
	pcall(function() pname = player.Name end)
	print(string.format("[ESP] rig scan %s: %d Motor6D joints", tostring(pname), #found))
	return found
end

local function ESPSkeletonDrawJoints(cam, st, jointPairs, color, thick, transp)
	for i = 1, ESPMaxBones do
		local line = st.Bones[i]
		local pr = jointPairs[i]
		if line == nil or pr == nil then
			if line ~= nil then
				line.Visible = false
			end
		else
			local okP, pa, ona, pb, onb = pcall(function()
				local va, oa = ESPProject(cam, pr[1].Position)
				local vb, ob = ESPProject(cam, pr[2].Position)
				return va, oa, vb, ob
			end)
			if not okP or pa == nil or pb == nil or not ona or not onb then
				line.Visible = false
			else
				line.From = pa
				line.To = pb
				line.Color = color
				line.Thickness = thick
				line.Transparency = transp
				line.Visible = true
			end
		end
	end
end

-- Skeleton renderer adapted from the reference script: RigType-driven joints,
-- reference R6/R15 topologies, R6 arm offset, onScreen-only visibility (no
-- viewport-bounds culling - bones stay visible at close range). Persistent
-- lines, no per-frame allocation, missing parts hide their line silently.
local function ESPSkeletonDraw(cam, player, character, st, color, thick, transp)
	local function hideFrom(n)
		local i
		for i = n, ESPMaxBones do
			if st.Bones[i] ~= nil then
				st.Bones[i].Visible = false
			end
		end
	end
	local joints = ESPGetJoints(player, character)
	if #joints > 0 then
		ESPSkeletonDrawJoints(cam, st, joints, color, thick, transp)
		return
	end
	local humanoid = FindFirstChild(character, "Humanoid")
	if humanoid == nil then
		hideFrom(1)
		return
	end
	local okR, rig = pcall(function() return humanoid.RigType end)
	if not okR or rig == nil then
		hideFrom(1)
		return
	end
	local function part(name)
		local f = FindFirstChild(character, name)
		if f ~= nil and f:IsA("BasePart") then
			return f
		end
		return nil
	end
	local function seg(index, jointA, jointB, yOff)
		local line = st.Bones[index]
		if line == nil or jointA == nil or jointB == nil then
			if line ~= nil then
				line.Visible = false
			end
			return
		end
		local bp = jointB.Position
		if yOff ~= nil and yOff ~= 0 then
			bp = bp + Vector3.new(0, yOff, 0)
		end
		local pa, _, ona = ESPProject(cam, jointA.Position)
		local pb, _, onb = ESPProject(cam, bp)
		if pa == nil or pb == nil or not ona or not onb then
			line.Visible = false
			return
		end
		line.From = pa
		line.To = pb
		line.Color = color
		line.Thickness = thick
		line.Transparency = transp
		line.Visible = true
	end
	if rig == Enum.HumanoidRigType.R6 then
		seg(1, part("Head"), part("Torso"), nil)
		seg(2, part("Torso"), part("Left Arm"), 0.5)
		seg(3, part("Torso"), part("Right Arm"), 0.5)
		seg(4, part("Torso"), part("Left Leg"), nil)
		seg(5, part("Torso"), part("Right Leg"), nil)
		hideFrom(6)
		return
	end
	local jHead = part("Head")
	local jUT = part("UpperTorso")
	if jHead == nil or jUT == nil then
		hideFrom(1)
		return
	end
	seg(1, jHead, jUT, nil)
	seg(2, jUT, part("LowerTorso"), nil)
	seg(3, jUT, part("LeftUpperArm"), nil)
	seg(4, part("LeftUpperArm"), part("LeftLowerArm"), nil)
	seg(5, part("LeftLowerArm"), part("LeftHand"), nil)
	seg(6, jUT, part("RightUpperArm"), nil)
	seg(7, part("RightUpperArm"), part("RightLowerArm"), nil)
	seg(8, part("RightLowerArm"), part("RightHand"), nil)
	seg(9, part("LowerTorso"), part("LeftUpperLeg"), nil)
	seg(10, part("LeftUpperLeg"), part("LeftLowerLeg"), nil)
	seg(11, part("LeftLowerLeg"), part("LeftFoot"), nil)
	seg(12, part("LowerTorso"), part("RightUpperLeg"), nil)
	seg(13, part("RightUpperLeg"), part("RightLowerLeg"), nil)
	seg(14, part("RightLowerLeg"), part("RightFoot"), nil)
end

local function ESPChamsUpdate(player, character, visible)
	local S = Environment.ESP
	local hl = ESPState.Highlights[player]
	if hl == nil then
		return
	end
	if S.ChamsEnabled and character ~= nil then
		pcall(function()
			hl.Parent = character
			if visible then
				hl.FillColor = S.ChamsFillColor
			else
				hl.FillColor = S.ChamsOccludedColor
			end
			hl.OutlineColor = S.ChamsOutlineColor
			hl.FillTransparency = S.ChamsTransparency or 0.5
			hl.OutlineTransparency = S.ChamsOutlineTransparency or 0
			hl.Enabled = true
		end)
	else
		pcall(function() hl.Enabled = false end)
	end
end

-- Body-part cache: rebuilt only when the character object changes (respawn /
-- swap) or when the IncludeAccessories option flips. Per-frame code only reads
-- CFrame/Size from these cached parts: no GetDescendants, no name scans.
local function ESPGetBodyParts(player, character)
	local includeAcc = Environment.ESP.IncludeAccessories
	local entry = ESPState.Bodies[player]
	if entry ~= nil and entry.Character == character and entry.WithAcc == includeAcc and entry.Parts ~= nil then
		return entry.Parts
	end
	local parts = {}
	if character ~= nil then
		local okD, descs = pcall(function() return GetDescendants(character) end)
		if okD and type(descs) == "table" then
			for _, inst in next, descs do
				local okC = pcall(function() return inst:IsA("BasePart") end)
				if okC and inst:IsA("BasePart") then
					local excluded = false
					if inst:FindFirstAncestorOfClass("Tool") ~= nil then
						excluded = true
					elseif not includeAcc then
						if inst:FindFirstAncestorOfClass("Accessory") ~= nil then
							excluded = true
						elseif inst.Name == "Handle" then
							excluded = true
						end
					end
					if not excluded then
						parts[#parts + 1] = inst
					end
				end
			end
		end
	end
	ESPState.Bodies[player] = { Character = character, WithAcc = includeAcc, Parts = parts }
	return parts
end

local ESPBoxCorners = {
	{ -1, -1, -1 }, { 1, -1, -1 }, { -1, 1, -1 }, { 1, 1, -1 },
	{ -1, -1, 1 }, { 1, -1, 1 }, { -1, 1, 1 }, { 1, 1, 1 }
}

-- True screen-space bounds: every cached body part contributes its 8 world
-- corners, each projected individually. Perspective (front/side/top/diagonal),
-- distance and camera FOV all resolve automatically - no fixed ratios, no
-- side detection, no root-part guessing. Feet are included because leg/foot
-- parts are body parts. Accessories/tools are already filtered by the cache.
-- Returns nil when nothing is in front of the camera.
local function GetCharacterScreenBounds(character, cam, viewport, player)
	local parts = ESPGetBodyParts(player, character)
	if #parts < 1 then
		return nil
	end
	local minX, minY = mathhuge, mathhuge
	local maxX, maxY = -mathhuge, -mathhuge
	local wmin = Vector3.new(mathhuge, mathhuge, mathhuge)
	local wmax = Vector3.new(-mathhuge, -mathhuge, -mathhuge)
	local hitFront = false
	for _, part in next, parts do
		local okC, cf = pcall(function() return part.CFrame end)
		local okS, sz = pcall(function() return part.Size end)
		if okC and okS and cf ~= nil and sz ~= nil then
			local hx, hy, hz = sz.X / 2, sz.Y / 2, sz.Z / 2
			for k = 1, 8 do
				local o = ESPBoxCorners[k]
				local wp = cf * Vector3.new(o[1] * hx, o[2] * hy, o[3] * hz)
				if wp.X < wmin.X then wmin = Vector3.new(wp.X, wmin.Y, wmin.Z) end
				if wp.Y < wmin.Y then wmin = Vector3.new(wmin.X, wp.Y, wmin.Z) end
				if wp.Z < wmin.Z then wmin = Vector3.new(wmin.X, wmin.Y, wp.Z) end
				if wp.X > wmax.X then wmax = Vector3.new(wp.X, wmax.Y, wmax.Z) end
				if wp.Y > wmax.Y then wmax = Vector3.new(wmax.X, wp.Y, wmax.Z) end
				if wp.Z > wmax.Z then wmax = Vector3.new(wmax.X, wmax.Y, wp.Z) end
			local scr, depth = ESPProject(cam, wp)
			if scr ~= nil and depth ~= nil and depth > 0 then
				hitFront = true
				if scr.X < minX then minX = scr.X end
				if scr.Y < minY then minY = scr.Y end
				if scr.X > maxX then maxX = scr.X end
				if scr.Y > maxY then maxY = scr.Y end
			end
			end
		end
	end
	if not hitFront then
		return nil
	end
	if minX < 0 then minX = 0 end
	if minY < 0 then minY = 0 end
	if maxX > viewport.X then maxX = viewport.X end
	if maxY > viewport.Y then maxY = viewport.Y end
	if maxX <= minX or maxY <= minY then
		return nil
	end
	return {
		MinX = minX, MaxX = maxX, MinY = minY, MaxY = maxY,
		Width = maxX - minX, Height = maxY - minY,
		CenterX = (minX + maxX) / 2, CenterY = (minY + maxY) / 2,
		WMin = wmin, WMax = wmax
	}
end

local function ESPUpdatePlayer(player, cam, mousePos, viewport)
	local S = Environment.ESP
	local st = ESPState.Players[player]
	if st == nil then
		return
	end
	local character = player.Character
	if character == nil then
		ESPHidePlayer(player)
		return
	end
	local rootPart = FindFirstChild(character, "HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		ESPHidePlayer(player)
		return
	end
	local humanoid = FindFirstChildOfClass(character, "Humanoid")
	local okH, hp = false, 0
	if humanoid ~= nil then
		okH, hp = pcall(function() return humanoid.Health end)
	end
	if humanoid == nil or not okH or hp <= 0 then
		ESPHidePlayer(player)
		return
	end
	local isMate = ESPIsTeammate(player)
	if isMate and not S.ShowTeam then
		ESPHidePlayer(player)
		return
	end
	local okR, rpos = pcall(function() return rootPart.Position end)
	if not okR or rpos == nil then
		ESPHidePlayer(player)
		return
	end
	local pos, _, onScreen = ESPProject(cam, rpos)
	if pos == nil or not onScreen then
		ESPHidePlayer(player)
		return
	end
	local dist = (rpos - cam.CFrame.Position).Magnitude
	if dist > (S.MaxDistance or 1000) then
		ESPHidePlayer(player)
		return
	end
	local fade = 0
	if S.DistanceFade then
		fade = (1 - mathclamp(dist / (S.FadeDistance or 500), 0, 1)) * 0.9
	end
	local effFade = fade
	if not S.DistanceFade then
		effFade = 1
	end
	if (tick() - (ESPState.FadeDbgT or 0)) > 3 then
		ESPState.FadeDbgT = tick()
		print(string.format("[ESP] fade check: dist=%.1f df=%s FadeDistance=%s fade=%.2f tracer=%s showdist=%s", dist, tostring(S.DistanceFade), tostring(S.FadeDistance), fade, tostring(S.TracerESP), tostring(S.ShowDistance)))
	end
	local visOk, vis = pcall(function() return CheckVisibilityCached(rpos, character) end)
	local visible = true
	if S.VisibilityCheck then
		visible = (visOk and vis) and true or false
		if not visible then
			ESPHidePlayer(player)
			ESPChamsUpdate(player, character, false)
			return
		end
	end
	local bounds = GetCharacterScreenBounds(character, cam, viewport, player)
	if bounds == nil or bounds.Height <= 2 then
		ESPHidePlayer(player)
		return
	end
	local boxX, boxY = bounds.MinX, bounds.MinY
	local boxW, screenH = bounds.Width, bounds.Height
	local boxPosition = Vector2.new(boxX, boxY)
	local boxSize = Vector2.new(boxW, screenH)
	local boxColor = ESPCatColor(player, isMate, "Box")
	local tColor = ESPCatColor(player, isMate, "Tracer")
	local txtColor = ESPCatColor(player, isMate, "Text")
	local thick = S.BoxThickness or 1
	local function hideBox()
		local i
		for i = 1, 8 do
			if st.Box[i] ~= nil then st.Box[i].Visible = false end
			if st.BoxOut[i] ~= nil then st.BoxOut[i].Visible = false end
		end
		for i = 1, 4 do
			if st.Con[i] ~= nil then st.Con[i].Visible = false end
		end
		if st.Fill ~= nil then st.Fill.Visible = false end
	end
	hideBox()
	if S.BoxESP then
		if S.BoxStyle == "ThreeD" then
			local wmin, wmax = bounds.WMin, bounds.WMax
			local pts = {
				{ wmin.X, wmax.Y, wmin.Z }, { wmax.X, wmax.Y, wmin.Z },
				{ wmin.X, wmin.Y, wmin.Z }, { wmax.X, wmin.Y, wmin.Z },
				{ wmin.X, wmax.Y, wmax.Z }, { wmax.X, wmax.Y, wmax.Z },
				{ wmin.X, wmin.Y, wmax.Z }, { wmax.X, wmin.Y, wmax.Z }
			}
			local allOk = true
			local scr = {}
			for i = 1, 8 do
				local p = pts[i]
				local v, depth, on = ESPProject(cam, Vector3.new(p[1], p[2], p[3]))
				if v == nil or not on or depth == nil or depth < 0 then
					allOk = false
					break
				end
				scr[i] = Vector2.new(v.X, v.Y)
			end
			if allOk then
				ESPSeg(st.Box[1], scr[1].X, scr[1].Y, scr[2].X, scr[2].Y, boxColor, thick)
				ESPSeg(st.Box[2], scr[2].X, scr[2].Y, scr[4].X, scr[4].Y, boxColor, thick)
				ESPSeg(st.Box[3], scr[3].X, scr[3].Y, scr[4].X, scr[4].Y, boxColor, thick)
				ESPSeg(st.Box[4], scr[1].X, scr[1].Y, scr[3].X, scr[3].Y, boxColor, thick)
				ESPSeg(st.Box[5], scr[5].X, scr[5].Y, scr[6].X, scr[6].Y, boxColor, thick)
				ESPSeg(st.Box[6], scr[6].X, scr[6].Y, scr[8].X, scr[8].Y, boxColor, thick)
				ESPSeg(st.Box[7], scr[7].X, scr[7].Y, scr[8].X, scr[8].Y, boxColor, thick)
				ESPSeg(st.Box[8], scr[5].X, scr[5].Y, scr[7].X, scr[7].Y, boxColor, thick)
				ESPSeg(st.Con[1], scr[1].X, scr[1].Y, scr[5].X, scr[5].Y, boxColor, thick)
				ESPSeg(st.Con[2], scr[2].X, scr[2].Y, scr[6].X, scr[6].Y, boxColor, thick)
				ESPSeg(st.Con[3], scr[3].X, scr[3].Y, scr[7].X, scr[7].Y, boxColor, thick)
				ESPSeg(st.Con[4], scr[4].X, scr[4].Y, scr[8].X, scr[8].Y, boxColor, thick)
			end
		elseif S.BoxStyle == "Full" then
			ESPSeg(st.Box[1], boxX, boxY, boxX, boxY + screenH, boxColor, thick)
			ESPSeg(st.Box[2], boxX + boxW, boxY, boxX + boxW, boxY + screenH, boxColor, thick)
			ESPSeg(st.Box[3], boxX, boxY, boxX + boxW, boxY, boxColor, thick)
			ESPSeg(st.Box[4], boxX, boxY + screenH, boxX + boxW, boxY + screenH, boxColor, thick)
			if S.BoxOutline then
				local oc = Color3.fromRGB(0, 0, 0)
				ESPSeg(st.BoxOut[1], boxX - 1, boxY - 1, boxX - 1, boxY + screenH + 1, oc, thick)
				ESPSeg(st.BoxOut[2], boxX + boxW + 1, boxY - 1, boxX + boxW + 1, boxY + screenH + 1, oc, thick)
				ESPSeg(st.BoxOut[3], boxX - 1, boxY - 1, boxX + boxW + 1, boxY - 1, oc, thick)
				ESPSeg(st.BoxOut[4], boxX - 1, boxY + screenH + 1, boxX + boxW + 1, boxY + screenH + 1, oc, thick)
			end
		else
			local cs = boxW * 0.2
			local oc = Color3.fromRGB(0, 0, 0)
			ESPSeg(st.Box[1], boxX, boxY, boxX + cs, boxY, boxColor, thick)
			ESPSeg(st.Box[2], boxX + boxW - cs, boxY, boxX + boxW, boxY, boxColor, thick)
			ESPSeg(st.Box[3], boxX, boxY + screenH, boxX + cs, boxY + screenH, boxColor, thick)
			ESPSeg(st.Box[4], boxX + boxW - cs, boxY + screenH, boxX + boxW, boxY + screenH, boxColor, thick)
			ESPSeg(st.Box[5], boxX, boxY, boxX, boxY + cs, boxColor, thick)
			ESPSeg(st.Box[6], boxX + boxW, boxY, boxX + boxW, boxY + cs, boxColor, thick)
			ESPSeg(st.Box[7], boxX, boxY + screenH - cs, boxX, boxY + screenH, boxColor, thick)
			ESPSeg(st.Box[8], boxX + boxW, boxY + screenH - cs, boxX + boxW, boxY + screenH, boxColor, thick)
			if S.BoxOutline then
				ESPSeg(st.BoxOut[1], boxX - 1, boxY - 1, boxX + cs + 1, boxY - 1, oc, thick)
				ESPSeg(st.BoxOut[2], boxX + boxW - cs - 1, boxY - 1, boxX + boxW + 1, boxY - 1, oc, thick)
				ESPSeg(st.BoxOut[3], boxX - 1, boxY + screenH + 1, boxX + cs + 1, boxY + screenH + 1, oc, thick)
				ESPSeg(st.BoxOut[4], boxX + boxW - cs - 1, boxY + screenH + 1, boxX + boxW + 1, boxY + screenH + 1, oc, thick)
				ESPSeg(st.BoxOut[5], boxX - 1, boxY - 1, boxX - 1, boxY + cs + 1, oc, thick)
				ESPSeg(st.BoxOut[6], boxX + boxW + 1, boxY - 1, boxX + boxW + 1, boxY + cs + 1, oc, thick)
				ESPSeg(st.BoxOut[7], boxX - 1, boxY + screenH - cs - 1, boxX - 1, boxY + screenH + 1, oc, thick)
				ESPSeg(st.BoxOut[8], boxX + boxW + 1, boxY + screenH - cs - 1, boxX + boxW + 1, boxY + screenH + 1, oc, thick)
			end
		end
		if S.BoxFilled and st.Fill ~= nil then
			st.Fill.Position = Vector2.new(boxX, boxY)
			st.Fill.Size = Vector2.new(boxW, screenH)
			st.Fill.Color = boxColor
			local fillT = S.BoxFillTransparency or 0.5
			if effFade > fillT then fillT = effFade end
			st.Fill.Transparency = fillT
			st.Fill.Visible = true
		end
	end
	local function tracerOrigin()
		if S.TracerOrigin == "Top" then
			return Vector2.new(viewport.X / 2, 0)
		end
		if S.TracerOrigin == "Mouse" then
			return mousePos
		end
		if S.TracerOrigin == "Center" then
			return Vector2.new(viewport.X / 2, viewport.Y / 2)
		end
		return Vector2.new(viewport.X / 2, viewport.Y)
	end
	if S.TracerESP and st.Tracer ~= nil then
		st.Tracer.From = tracerOrigin()
		st.Tracer.To = Vector2.new(pos.X, pos.Y)
		st.Tracer.Color = tColor
		st.Tracer.Thickness = S.TracerThickness or 1
		st.Tracer.Transparency = effFade
		st.Tracer.Visible = true
	elseif st.Tracer ~= nil then
		st.Tracer.Visible = false
	end
	if S.Snaplines and st.Snap ~= nil then
		st.Snap.From = Vector2.new(viewport.X / 2, viewport.Y)
		st.Snap.To = Vector2.new(pos.X, pos.Y)
		st.Snap.Color = tColor
		st.Snap.Thickness = 1
		st.Snap.Visible = true
	elseif st.Snap ~= nil then
		st.Snap.Visible = false
	end
	do
		local i
		for i = 1, 8 do
			if st.Box[i] ~= nil then st.Box[i].Transparency = effFade end
			if st.BoxOut[i] ~= nil then st.BoxOut[i].Transparency = effFade end
		end
		for i = 1, 4 do
			if st.Con[i] ~= nil then st.Con[i].Transparency = effFade end
		end
		if st.Snap ~= nil then st.Snap.Transparency = effFade end
	end
	do
		local hb = st.Health
		local showBar = S.HealthESP and (S.HealthStyle == "Bar" or S.HealthStyle == "Both")
		local showText = S.HealthESP and (S.HealthStyle == "Text" or S.HealthStyle == "Both")
		local maxHp, hpNow = 100, hp
		if humanoid ~= nil then
			pcall(function() maxHp = humanoid.MaxHealth end)
		end
		if maxHp <= 0 then
			maxHp = 100
		end
		local pct = mathclamp(hpNow / maxHp, 0, 1)
		local barH = screenH * 0.8
		local barW = 4
		local barX = boxX - barW - 2
		if S.HealthBarSide == "Right" then
			barX = boxX + boxW + 2
		end
		local barY = boxY + (screenH - barH) / 2
		if showBar and hb.Outline ~= nil and hb.Fill ~= nil then
			hb.Outline.Size = Vector2.new(barW, barH)
			hb.Outline.Position = Vector2.new(barX, barY)
			hb.Outline.Transparency = effFade
			hb.Outline.Visible = true
			hb.Fill.Size = Vector2.new(barW - 2, barH * pct)
			hb.Fill.Position = Vector2.new(barX + 1, barY + barH * (1 - pct))
			hb.Fill.Color = ESPHealthColor(pct, S.HealthFullColor)
			hb.Fill.Transparency = effFade
			hb.Fill.Visible = true
		else
			if hb.Outline ~= nil then hb.Outline.Visible = false end
			if hb.Fill ~= nil then hb.Fill.Visible = false end
		end
		if showText and hb.Text ~= nil then
			local txt = tostring(mathfloor(hpNow)) .. (S.HealthTextSuffix or "HP")
			if S.HealthFormat == "Percentage" then
				txt = tostring(mathfloor(pct * 100)) .. "%"
			elseif S.HealthFormat == "Both" then
				txt = tostring(mathfloor(hpNow)) .. (S.HealthTextSuffix or "HP") .. " " .. tostring(mathfloor(pct * 100)) .. "%"
			end
			hb.Text.Text = txt
			hb.Text.Size = S.TextSize or 14
			hb.Text.Font = S.TextFont or 2
			hb.Text.Color = ESPHealthColor(pct, S.HealthFullColor)
			hb.Text.Center = true
			hb.Text.Transparency = effFade
			hb.Text.Position = Vector2.new(barX + barW + 2, barY + barH / 2)
			hb.Text.Visible = true
		elseif hb.Text ~= nil then
			hb.Text.Visible = false
		end
	end
	do
		local inf = st.Info
		if S.NameESP and inf.Name ~= nil then
			local nm = "?"
			if S.NameMode == "Username" then
				pcall(function() nm = player.Name end)
			else
				pcall(function() nm = player.DisplayName end)
			end
			inf.Name.Text = tostring(nm)
			inf.Name.Size = S.TextSize or 14
			inf.Name.Font = S.TextFont or 2
			inf.Name.Color = txtColor
			inf.Name.Center = true
			inf.Name.Transparency = effFade
			if ESPState.TextOutlineOk then
				inf.Name.Outline = true
			end
			inf.Name.Position = Vector2.new(boxX + boxW / 2, boxY - (S.TextSize or 14) - 6)
			inf.Name.Visible = true
		elseif inf.Name ~= nil then
			inf.Name.Visible = false
		end
		if S.ShowDistance and inf.Dist ~= nil then
			inf.Dist.Text = tostring(mathfloor(dist)) .. "m"
			inf.Dist.Size = S.TextSize or 14
			inf.Dist.Font = S.TextFont or 2
			inf.Dist.Color = txtColor
			inf.Dist.Center = true
			inf.Dist.Transparency = effFade
			if ESPState.TextOutlineOk then
				inf.Dist.Outline = true
			end
			inf.Dist.Position = Vector2.new(boxX + boxW / 2, boxY + screenH + 2)
			inf.Dist.Visible = true
		elseif inf.Dist ~= nil then
			inf.Dist.Visible = false
		end
	end
	do
		ESPChamsUpdate(player, character, visible)
	end
	if S.SkeletonESP then
		local skelT = S.SkeletonTransparency or 0
		if effFade > skelT then skelT = effFade end
		ESPSkeletonDraw(cam, player, character, st, S.SkeletonColor, S.SkeletonThickness or 1.5, skelT)
	else
		local i
		for i = 1, ESPMaxBones do
			if st.Bones[i] ~= nil then
				st.Bones[i].Visible = false
			end
		end
	end
end

local function ESPRefresh(dt)
	local S = Environment.ESP
	if (not S.Enabled) or S.Panicked then
		if ESPState.WasOn then
			ESPHideAll()
			ESPState.WasOn = false
		end
		return
	end
	ESPState.WasOn = true
	if not ESPDrawAvailable then
		if not ESPState.Warned then
			ESPState.Warned = true
			warn("[ESP] Drawing API unavailable - ESP disabled.")
		end
		return
	end
	if ESPState.TextOutlineOk == nil then
		local okT, tobj = pcall(function() return Drawing.new("Text") end)
		if okT and tobj ~= nil then
			local okO = pcall(function() tobj.Outline = true end)
			ESPState.TextOutlineOk = okO
			pcall(function() tobj:Remove() end)
		else
			ESPState.TextOutlineOk = false
		end
	end
	if dt == nil or dt <= 0 then
		dt = 0.016
	end
	ESPState.FpsAccum = ESPState.FpsAccum + dt
	ESPState.FpsCount = ESPState.FpsCount + 1
	if ESPState.FpsAccum >= 2 then
		local fps = ESPState.FpsCount / ESPState.FpsAccum
		local mode = S.RefreshMode or "Fixed"
		if mode == "Half" or mode == "Full" then
			local rate = fps / (mode == "Full" and 1 or 2)
			if rate < 20 then rate = 20 end
			if rate > 240 then rate = 240 end
			ESPState.Interval = 1 / rate
		else
			local wantFPS = S.RefreshFPS or 144
			if wantFPS < 1 then
				wantFPS = 1
			end
			local base = 1 / wantFPS
			if fps < 30 and base < 1 / 20 then
				ESPState.Interval = base * 1.5
				if ESPState.Interval > 1 / 20 then
					ESPState.Interval = 1 / 20
				end
			else
				ESPState.Interval = base
			end
		end
		ESPState.FpsAccum = 0
		ESPState.FpsCount = 0
	end
	ESPState.Accum = ESPState.Accum + dt
	if ESPState.Accum < ESPState.Interval then
		return
	end
	ESPState.Accum = 0
	if (tick() - ESPState.RainbowT) >= 0.1 then
		ESPState.RainbowT = tick()
		ESPState.Rainbow = Color3fromHSV(tick() * (S.RainbowSpeed or 1) % 1, 1, 1)
	end
	local cam = workspace.CurrentCamera or Camera
	if cam == nil then
		return
	end
	local okM, mousePos = pcall(function() return GetMouseLocation(UserInputService) end)
	if not okM or mousePos == nil then
		mousePos = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
	end
	local viewport = cam.ViewportSize
	for _, player in next, GetPlayers(Players) do
		if player ~= LocalPlayer then
			if ESPEnsurePlayer(player) then
				local okU, errU = pcall(ESPUpdatePlayer, player, cam, mousePos, viewport)
				if not okU then
					if (tick() - ESPState.ErrT) > 5 then
						ESPState.ErrT = tick()
						warn("[ESP] update failed: " .. tostring(errU))
					end
					ESPHidePlayer(player)
				end
			else
				ESPHidePlayer(player)
			end
		end
	end
end

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")
	dprint("Load: wiring connections (mode:", tostring(Environment.DeveloperSettings.UpdateMode) .. ")")

	local Settings, Triggerbot, Tracer, FOVCircle, FOVCircleOutline, TracerSettings, FOVSettings, Offset = Environment.Settings, Environment.Triggerbot, Environment.Tracer, Environment.FOVCircle, Environment.FOVCircleOutline, Environment.ClosestPlayerTracer, Environment.FOVSettings

	local DeveloperSettings = Environment.DeveloperSettings
	local UpdateMode = DeveloperSettings.UpdateMode
	local TeamCheckOption = DeveloperSettings.TeamCheckOption

	-- Player cache: incremental updates + slow reconcile (never stale, never rebuilt per frame).
	local function RebuildPlayerCache()
		PlayerCache = {}
		for _, p in next, GetPlayers(Players) do
			PlayerCache[#PlayerCache + 1] = p
		end
		PlayerCacheTime = tick()
	end
	RebuildPlayerCache()
	RefreshFriends()
	ServiceConnections.PlayerAdded = Connect(__index(Players, "PlayerAdded"), LPH_NO_VIRTUALIZE(function(Player)
		PlayerCache[#PlayerCache + 1] = Player
	end))
	ServiceConnections.PlayerRemoving = Connect(__index(Players, "PlayerRemoving"), LPH_NO_VIRTUALIZE(function(Player)
		for i, p in next, PlayerCache do
			if p == Player then
				tableremove(PlayerCache, i)
				break
			end
		end
		local id
		pcall(function() id = __index(Player, "UserId") end)
		if id ~= nil then
			PurgePlayer(id)
		end
	end))
	-- Slow friend-list refresh (amortized, not per frame).
	ServiceConnections.FriendRefresh = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function()
		Universery.TeamResolver.MaybeRefreshFriends()
		if (tick() - PlayerCacheTime) > (Environment.Performance.PlayerReconcile or 2) then
			RebuildPlayerCache()
		end
		-- Ping sampling + auto-calibration run on slow gates. No extra loops.
		local Nw = Environment.Network
		if Nw ~= nil and Nw.PingPrediction ~= false and (tick() - PingState.LastUpdate) >= (Nw.PingUpdateRate or 0.25) then
			SamplePing()
		end
		if (tick() - (PingState.LastCalib or 0)) >= 1 then
			PingState.LastCalib = tick()
			UpdateCalibration()
		end
	end))

	-- ESP render loop (single RenderStepped; throttled + adaptive internally).
	ServiceConnections.ESPLoop = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function(dt)
		ESPRefresh(dt or 0.016)
	end))
	ServiceConnections.ESPPlayerRemoving = Connect(__index(Players, "PlayerRemoving"), LPH_NO_VIRTUALIZE(function(player)
		ESPRemovePlayer(player)
	end))

	-- Silent Aim wiring (scan 45Hz + FOV render + key state). Resolved via the
	-- Environment registry so Load order never matters.
	ServiceConnections.SilentAimFrame = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function(dt)
		local C = Environment.SilentAimCtl
		if C ~= nil then
			pcall(C.Frame, dt or 0.016)
		end
	end))
	ServiceConnections.SilentKeyDown = Connect(__index(UserInputService, "InputBegan"), LPH_NO_VIRTUALIZE(function(input, gpe)
		local C = Environment.SilentAimCtl
		if C ~= nil then
			pcall(C.OnKey, input, gpe, true)
		end
	end))
	ServiceConnections.SilentKeyUp = Connect(__index(UserInputService, "InputEnded"), LPH_NO_VIRTUALIZE(function(input, gpe)
		local C = Environment.SilentAimCtl
		if C ~= nil then
			pcall(C.OnKey, input, gpe, false)
		end
	end))

	if mouse1press and mouse1release then
		ServiceConnections.Triggerbot = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function()
			if Triggerbot.Enabled and Mouse.Target then
				if TriggerBusy then
					return -- debounce: previous click cycle still in flight
				end
				if (osclock() - TriggerLastClick) < (Triggerbot.Cooldown or 0.25) then
					return
				end
				local Character = Mouse.Target.Parent
				local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
				local Player = GetPlayerFromCharacter(Players, Character)

				if Character and Humanoid and Player then
					if Triggerbot.TeamCheck and IsTeammate(Player) then
						return
					end

					if Triggerbot.AliveCheck and __index(Humanoid, "Health") <= 0 then
						return
					end

					if Triggerbot.AimLockedCheck and not Environment.Locked then
						return
					end

					TriggerBusy = true
					TriggerLastClick = osclock()
					if Triggerbot.Delay ~= 0 then
						taskwait(Triggerbot.Delay)
					end

					mouse1press(); taskwait(0); mouse1release()
					TriggerBusy = false
				end
			end
		end))
	end

	ServiceConnections.UpdateTracer = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function()
		-- Uses the shared scan cache; no independent player loop.
		local now = tick()
		local ClosestPlayer = nil
		if TracerSettings.Enabled and Settings.Enabled then
			if (now - ScanState.Time) >= (Environment.Performance.TargetScanRate or 0.12) then
				RefreshScan()
			end
			ClosestPlayer = ScanState.Best
		end

		if ClosestPlayer then
			setrenderproperty(Tracer, "Visible", true)

			for Index, Value in next, TracerSettings do
				if Index == "Color" then
					continue
				end

				if pcall(getrenderproperty, Tracer, Index) then
					setrenderproperty(Tracer, Index, Value)
				end
			end

			setrenderproperty(Tracer, "Color", TracerSettings.RainbowColor and GetRainbowColor() or TracerSettings.Color)

			if TracerSettings.Position == 1 then
				setrenderproperty(Tracer, "From", Vector2new(CameraViewportSize.X / 2, CameraViewportSize.Y))
			elseif TracerSettings.Position == 2 then
				setrenderproperty(Tracer, "From", CameraViewportSize / 2)
			elseif TracerSettings.Position == 3 then
				setrenderproperty(Tracer, "From", GetMouseLocation(UserInputService))
			else
				TracerSettings.Position = 3
			end

			local charOk, char = pcall(function() return __index(ClosestPlayer, "Character") end)
			if charOk and char ~= nil then
				local _, partPos = ResolveAimPart(char)
				if partPos ~= nil then
					setrenderproperty(Tracer, "To", ConvertVector(WorldToViewportPoint(Camera, partPos)))
				end
			end
		else
			setrenderproperty(Tracer, "Visible", false)
		end
	end))

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, UpdateMode), LPH_NO_VIRTUALIZE(function(DeltaTime)
		if FOVSettings.Enabled and Settings.Enabled then
			for Index, Value in next, FOVSettings do
				if Index == "Color" or Index == "ShowLockRadius" or Index == "LockRadiusColor" then
					continue
				end

				if pcall(getrenderproperty, FOVCircle, Index) then
					setrenderproperty(FOVCircle, Index, Value)
					setrenderproperty(FOVCircleOutline, Index, Value)
				end
			end

			setrenderproperty(FOVCircle, "Color", (Environment.Locked and FOVSettings.LockedColor) or FOVSettings.RainbowColor and GetRainbowColor() or FOVSettings.Color)
			setrenderproperty(FOVCircleOutline, "Color", FOVSettings.RainbowOutlineColor and GetRainbowColor() or FOVSettings.OutlineColor)

			setrenderproperty(FOVCircleOutline, "Thickness", FOVSettings.Thickness + 1)
			setrenderproperty(FOVCircle, "Position", GetMouseLocation(UserInputService))
			setrenderproperty(FOVCircleOutline, "Position", GetMouseLocation(UserInputService))

			-- Lock-retention ring (render only; never participates in targeting logic).
			local LockRing = Environment.LockRadiusCircle
			if FOVSettings.ShowLockRadius and LockRing ~= nil then
				setrenderproperty(LockRing, "Visible", FOVSettings.Visible ~= false)
				setrenderproperty(LockRing, "Radius", LockMeta.RetainRadius or Settings.LockRetentionRadius or 30)
				setrenderproperty(LockRing, "Color", FOVSettings.LockRadiusColor or Color3fromRGB(255, 150, 150))
				setrenderproperty(LockRing, "Thickness", 1)
				setrenderproperty(LockRing, "Transparency", 0.5)
				setrenderproperty(LockRing, "Filled", false)
				setrenderproperty(LockRing, "NumSides", FOVSettings.NumSides or 60)
				setrenderproperty(LockRing, "Position", GetMouseLocation(UserInputService))
			elseif LockRing ~= nil then
				setrenderproperty(LockRing, "Visible", false)
			end
		else
			setrenderproperty(FOVCircle, "Visible", false)
			setrenderproperty(FOVCircleOutline, "Visible", false)
			if Environment.LockRadiusCircle ~= nil then
				setrenderproperty(Environment.LockRadiusCircle, "Visible", false)
			end
		end

		-- Key takeover: while protection is ON and the aimbot is enabled, a
		-- conflicting game CAS binding stays suppressed (High-priority sink),
		-- so the GAME cannot steal the aim key. The aimbot's own input path is
		-- untouched. Anything else (or protection OFF) releases the sink.
		if Settings.IgnoreGameKeyConflicts and Settings.Enabled then
			InputConflictController:EnsureSuppressed()
		else
			InputConflictController:EnsureReleased()
		end
		InputConflictController:Evaluate()
		if Running and Settings.Enabled then
			GetClosestPlayer()

			if Environment.Locked then
				-- Lifecycle gate: validate BEFORE prediction. A dead/invalid target
				-- must never produce a single velocity sample or predicted position.
				-- (GetClosestPlayer already hard-cancels; this is the aim-path guard
				-- for the same frame. `return` only skips this frame's callback.)
				local hardReason = LockDeathReason()
				if hardReason ~= nil then
					DebugLockRelease(hardReason)
					CancelLock()
					return
				end
				local Character = __index(Environment.Locked, "Character")
				if Character == nil then
					CancelLock()
				else
					local AimPart, PartPos = ResolveAimPart(Character)
					if AimPart == nil or PartPos == nil then
						CancelLock()
					else
						-- Position sanity BEFORE any velocity/prediction work.
						local sane, saneReason = CheckPositionSanity(PartPos, DeltaTime)
						if not sane then
							local prevTxt = "none"
							if LockMeta.PrevPos ~= nil then
								prevTxt = string.format("(%.1f, %.1f, %.1f)", LockMeta.PrevPos.X, LockMeta.PrevPos.Y, LockMeta.PrevPos.Z)
							end
							DebugLockRelease(saneReason, string.format("POS (%.1f, %.1f, %.1f) PREV %s", PartPos.X, PartPos.Y, PartPos.Z, prevTxt))
							CancelLock()
							return
						end
						LockMeta.PrevPos = PartPos
						LockMeta.PrevTime = tick()
						-- Lock retention (explicit pipeline order): current screen
						-- distance vs the SMALL retention radius. Prediction below
						-- only runs for targets inside it; prediction never justifies
						-- keeping a target that left the active aim region.
						do
							local okR, vecR, onR = pcall(function() return WorldToViewportPoint(Camera, PartPos) end)
							if not okR or not onR then
								CancelLock()
								return
							end
							local sdNow = (GetMouseLocation(UserInputService) - ConvertVector(vecR)).Magnitude
							if sdNow > (LockMeta.RetainRadius or Settings.LockRetentionRadius or 30) then
								DebugLockRelease("LOCK_RADIUS_EXIT")
								CancelLock()
								return
							end
						end
						local OffsetToMoveDirection = Settings.OffsetToMoveDirection
						local OffsetValue = Vector3zero
						if OffsetToMoveDirection then
							local humOk, moveDir = pcall(function()
								return __index(FindFirstChildOfClass(Character, "Humanoid"), "MoveDirection")
							end)
							if humOk and moveDir ~= nil then
								OffsetValue = moveDir * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10)
							end
						end

						SampleVelocity(AimPart, DeltaTime or 0.016)

						local camPos = __index(Camera, "CFrame").Position
						local worldDist = (camPos - PartPos).Magnitude
						local PredictedPos, Confidence = ComputePrediction(PartPos, worldDist)
						PredictedPos = PredictedPos + OffsetValue

						-- Calibration sampling: directional bias of the previous prediction
						-- vs the actual position now. Sign only matters (over/undershoot);
						-- magnitude is normalized and learning is clamped in UpdateCalibration.
						do
							local prev = PingState.LastPred
							local sv = VelocityState.SmoothVel or VelocityState.AvgVelocity
							if prev ~= nil and prev.Pos ~= nil and sv ~= nil and sv.Magnitude > 2 and Confidence > 0.3 then
								local errVec = PartPos - prev.Pos
								local bias = ((errVec.X * sv.Unit.X) + (errVec.Y * sv.Unit.Y) + (errVec.Z * sv.Unit.Z)) / (sv.Magnitude * 0.12 + 1)
								local buf = PingState.ErrBuf
								buf[#buf + 1] = mathclamp(bias, -2, 2)
								local maxE = (Environment.Network and Environment.Network.ErrorSamples) or 10
								while #buf > maxE do
									tableremove(buf, 1)
								end
							end
							PingState.LastPred = { Pos = PredictedPos }
						end

						-- Camera safety: a stale/NaN prediction never touches the camera.
						-- (No Y-clamping workaround: the lifecycle fix above is the real
						-- fix; this only guards against corrupt float state.)
						if PredictedPos.X ~= PredictedPos.X or PredictedPos.Y ~= PredictedPos.Y or PredictedPos.Z ~= PredictedPos.Z
							or mathabs(PredictedPos.X) > 100000 or mathabs(PredictedPos.Y) > 100000 or mathabs(PredictedPos.Z) > 100000 then
							DebugLockRelease("Stale predicted position")
							CancelLock()
							return
						end
						local LockedScreen = WorldToViewportPoint(Camera, PredictedPos)
						local mousePos = GetMouseLocation(UserInputService)
						local errPx = (mousePos - ConvertVector(LockedScreen)).Magnitude

						-- Final gate: re-validate immediately before touching the camera,
						-- so a death in the microseconds since prediction can't pull aim.
						local preCamReason = LockDeathReason()
						if preCamReason ~= nil then
							DebugLockRelease(preCamReason)
							CancelLock()
							return
						end
						if Settings.LockMode == 2 then
							mousemoverel((LockedScreen.X - mousePos.X) / Settings.Sensitivity2, (LockedScreen.Y - mousePos.Y) / Settings.Sensitivity2)
						elseif Settings.LockMode == 3 and mousemoveabs then
							mousemoveabs(LockedScreen.X, LockedScreen.Y)
						else
							local alpha = ComputeSmoothing(DeltaTime or 0.016, errPx, worldDist)
							local goal = CFramenew(camPos, PredictedPos)
							__newindex(Camera, "CFrame", __index(Camera, "CFrame"):Lerp(goal, alpha))
						end

						__newindex(UserInputService, "MouseDeltaSensitivity", 0)

						LastAimData.SX = LockedScreen.X
						LastAimData.SY = LockedScreen.Y
						LastAimData.PX = PredictedPos.X
						LastAimData.PY = PredictedPos.Y
						LastAimData.PZ = PredictedPos.Z
						LastAimData.Method = "LockMode " .. tostring(Settings.LockMode or 1)

						setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
						setrenderproperty(Tracer, "Visible", false)

						DebugPrint("PRED " .. string.format("%.3f", (PredictedPos - PartPos).Magnitude) .. " CONF " .. string.format("%.2f", Confidence))
					end
				end
			end
		end
	end))

	ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), LPH_NO_VIRTUALIZE(function(Input)
		if Typing then
			return
		end

		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Settings.IgnoreGameKeyConflicts then
				InputConflictController:OnPressAccepted()
			end
			if Toggle then
				Running = not Running

				if not Running then
					CancelLock()
				end
			else
				Running = true
			end
		end
	end))

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), LPH_NO_VIRTUALIZE(function(Input)
		if Typing then
			return
		end

		local TriggerKey = Settings.TriggerKey

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			InputConflictController:ReleaseLatch()
			Running = false; CancelLock()
		end
	end))
end

