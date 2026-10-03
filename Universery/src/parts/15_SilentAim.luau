--// Silent Aim (Hidden Aim Orientation / Decoupled Aim)
-- Visual camera is NEVER touched here. Target acquisition, FOV, validation
-- and prediction run universally; the actual aim orientation is applied ONLY
-- through a game-supplied applier (SilentAim.Applier or
-- GameAdapter.ApplySilentAim). Without one the state stays Unsupported
-- (honest fallback - no camera flicker, no remote spoofing, no Mouse.Hit).

local SilentAim = {
	Target = nil, TargetPart = nil, TargetChar = nil,
	TargetPos = nil, PredictedPos = nil, AimCFrame = nil,
	Method = "Off", SupportReason = "Disabled",
	KeyHeld = false, KeyToggle = false,
	ScanAccum = 0, LostAt = 0,
	Vel = nil, RandomFor = nil, RandomPick = nil,
	FOVCircle = nil, FOVCircleOutline = nil,
	CustomOn = false,
	FireHeld = false, LastFireEvent = 0,
	Dbg = { ScreenDist = -1, Visible = false, Team = "-", Part = "-", Source = "-" },
}
Environment.SilentAimCtl = SilentAim

function SilentAim.IsArmed()
	local S = Environment.SilentAim
	if S == nil or not S.Enabled then
		return false
	end
	local keyOn = SilentAim.KeyHeld or (S.KeyMode == "Toggle" and SilentAim.KeyToggle)
	if not keyOn then
		return false
	end
	if S.GameKeyConflictProtection then
		local kind = InputConflictController:Evaluate(S.EnabledKey, true)
		if kind ~= "NONE" then
			return false
		end
	end
	return true
end

function SilentAim.OnKey(input, gpe, down)
	if gpe then
		return
	end
	local S = Environment.SilentAim
	if S == nil then
		return
	end
	local key = S.EnabledKey
	if key == nil then
		return
	end
	local match = false
	pcall(function()
		if input.UserInputType == key or input.KeyCode == key then
			match = true
		end
	end)
	if not match then
		return
	end
	if down then
		InputConflictController:OnPressAccepted()
		if S.KeyMode == "Toggle" then
			SilentAim.KeyToggle = not SilentAim.KeyToggle
		else
			SilentAim.KeyHeld = true
		end
	else
		SilentAim.KeyHeld = false
	end
end

function SilentAim.Clear()
	if SilentAim.Target ~= nil then
		SilentAim.LostAt = tick()
	end
	SilentAim.Target = nil
	SilentAim.TargetPart = nil
	SilentAim.TargetChar = nil
	SilentAim.TargetPos = nil
	SilentAim.PredictedPos = nil
	SilentAim.AimCFrame = nil
	SilentAim.CustomOn = false
	SilentAim.Vel = nil
	SilentAim.RandomFor = nil
	SilentAim.RandomPick = nil
	SilentAim.Dbg = { ScreenDist = -1, Visible = false, Team = "-", Part = "-", Source = "-" }
end

function SilentAim.OriginPos(viewport)
	local S = Environment.SilentAim
	if S.FOVOrigin == "Mouse" then
		local okM, mp = pcall(function() return GetMouseLocation(UserInputService) end)
		if okM and mp ~= nil then
			return Vector2.new(mp.X, mp.Y)
		end
	end
	return Vector2.new(viewport.X / 2, viewport.Y / 2)
end

function SilentAim.Candidates(Character)
	local out = {}
	for _, nm in next, { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" } do
		local p = FindFirstChild(Character, nm)
		if p ~= nil then
			local okB, pos = pcall(function()
				if not p:IsA("BasePart") then
					return nil
				end
				return p.Position
			end)
			if okB and pos ~= nil then
				out[#out + 1] = { Name = nm, Part = p, Pos = pos }
			end
		end
	end
	return out
end

function SilentAim.ResolvePart(Character, player, mode, refPos, cam)
	local list = SilentAim.Candidates(Character)
	if #list < 1 then
		return nil, nil
	end
	if mode == "Random" then
		local pickName = nil
		if SilentAim.RandomFor == player and SilentAim.RandomPick ~= nil then
			pickName = SilentAim.RandomPick
		end
		local chosen = nil
		if pickName ~= nil then
			for _, e in next, list do
				if e.Name == pickName then
					chosen = e
					break
				end
			end
		end
		if chosen == nil then
			chosen = list[math.random(1, #list)]
			SilentAim.RandomFor = player
			SilentAim.RandomPick = chosen.Name
		end
		return chosen.Pos, chosen.Name
	end
	if mode == "Closest Part" then
		local best, bestD = nil, nil
		for _, e in next, list do
			local sp, _, onScreen = ESPProject(cam, e.Pos)
			if sp ~= nil and onScreen then
				local d = (Vector2.new(sp.X, sp.Y) - refPos).Magnitude
				if bestD == nil or d < bestD then
					best, bestD = e, d
				end
			end
		end
		if best == nil then
			return nil, nil
		end
		return best.Pos, best.Name
	end
	for _, e in next, list do
		if e.Name == mode then
			return e.Pos, e.Name
		end
	end
	return nil, nil
end

function SilentAim.Validate(player, S, cam, camPos, viewport, origin, overPos, overName)
	local bad = { valid = false }
	local okPar, par = pcall(function() return __index(player, "Parent") end)
	if not okPar or par == nil then
		return bad
	end
	if player == LocalPlayer then
		return bad
	end
	local Character, Humanoid = GetCharacterData(player)
	if Character == nil or Humanoid == nil then
		return bad
	end
	if not S.IncludeDeadTargets then
		local okH, hp = pcall(function() return Humanoid.Health end)
		if not okH or hp <= 0 then
			return bad
		end
	end
	if S.TeamCheck and IsSameTeam(LocalPlayer, player) then
		return bad
	end
	local partPos, partName
	if overPos ~= nil then
		partPos, partName = overPos, overName or (S.TargetPart or "Head")
	else
		partPos, partName = SilentAim.ResolvePart(Character, player, S.TargetPart or "Head", origin, cam)
	end
	if partPos == nil then
		return bad
	end
	local worldDist = (camPos - partPos).Magnitude
	if worldDist > (S.MaxDistance or 1000) then
		return bad
	end
	local scr, depth = ESPProject(cam, partPos)
	if scr == nil or depth == nil or depth <= 0 then
		SilentAim.BehindCount = (SilentAim.BehindCount or 0) + 1
		return bad
	end
	local fovDist = (Vector2.new(scr.X, scr.Y) - origin).Magnitude
	if fovDist > (S.FOV or 150) then
		return bad
	end
	local visible = true
	if S.VisibilityCheck then
		local okV, vis = pcall(function() return CheckVisibilityCached(partPos, Character) end)
		visible = (okV and vis) and true or false
		if not visible then
			return bad
		end
	end
	return {
		valid = true, Player = player, Character = Character, Humanoid = Humanoid,
		Part = partName, PartPos = partPos, Screen = scr, CamPos = camPos,
		WorldDist = worldDist, FovDist = fovDist, Visible = visible,
	}
end

function SilentAim.Predict(S, st)
	SilentAim.TargetPos = st.PartPos
	local pred = st.PartPos
	if S.Prediction then
		local alive = true
		local okHp, hp = pcall(function() return st.Humanoid.Health end)
		if not okHp or hp <= 0 then
			alive = false
		end
		if alive then
			local okS, state = pcall(function() return st.Humanoid:GetState() end)
			if okS and state ~= nil then
				local okD, deadE = pcall(function() return Enum.HumanoidStateType.Dead end)
				local okR, ragE = pcall(function() return Enum.HumanoidStateType.Ragdoll end)
				if (okD and state == deadE) or (okR and state == ragE) then
					alive = false
				end
			end
		end
		if alive then
			local okC, hasChar = pcall(function() return st.Character.Parent ~= nil end)
			if not okC or not hasChar then
				alive = false
			end
		end
		if alive and SilentAim.Vel ~= nil and SilentAim.Vel.Vel ~= nil then
			local t = 0.1
			if PingState.Available and (PingState.Effective or 0) > 0 then
				t = PingState.Effective
			end
			pred = pred + SilentAim.Vel.Vel * (t * (S.PredictionStrength or 1))
		end
	end
	SilentAim.PredictedPos = pred
end

function SilentAim.UpdateOrientation()
	SilentAim.CustomOn = false
	if SilentAim.Target == nil or SilentAim.PredictedPos == nil then
		SilentAim.AimCFrame = nil
		return
	end
	local cam = workspace.CurrentCamera or Camera
	local origin = Universery.SilentFire.GetOrigin()
	if origin == nil then
		pcall(function() origin = cam.CFrame.Position end)
	end
	if origin == nil then
		SilentAim.AimCFrame = nil
		return
	end
	local aimCF = nil
	pcall(function() aimCF = CFrame.lookAt(origin, SilentAim.PredictedPos) end)
	if aimCF == nil then
		pcall(function() aimCF = CFramenew(origin) end)
	end
	SilentAim.AimCFrame = aimCF
	local S = Environment.SilentAim
	local applier = S.Applier
	if type(applier) ~= "function" then
		local ga = Environment.GameAdapter
		if type(ga) == "table" and type(ga.ApplySilentAim) == "function" then
			applier = function(pos, cf) return ga:ApplySilentAim(pos, cf) end
		end
	end
	if type(applier) ~= "function" then
		if Universery.SilentFire.ApplyCustom(SilentAim.PredictedPos, aimCF) then
			SilentAim.CustomOn = true
		end
		return
	end
	local okA = pcall(applier, SilentAim.PredictedPos, aimCF)
	if okA then
		SilentAim.CustomOn = true
	end
end

function SilentAim.Commit(st, source)
	local S = Environment.SilentAim
	local changed = (SilentAim.Target ~= st.Player)
	SilentAim.Target = st.Player
	SilentAim.TargetPart = st.Part
	SilentAim.TargetChar = st.Character
	SilentAim.HookOrigin = st.CamPos
	SilentAim.LostAt = 0
	local now = tick()
	if changed or SilentAim.Vel == nil or SilentAim.Vel.Pos == nil then
		SilentAim.Vel = { Pos = st.PartPos, Time = now, Vel = Vector3zero }
	else
		local V = SilentAim.Vel
		local dt = now - (V.Time or now)
		if dt > 0.001 and dt < 0.5 then
			local instV = (st.PartPos - V.Pos) / dt
			if instV.Magnitude < 250 then
				V.Vel = V.Vel * 0.65 + instV * 0.35
			else
				V.Vel = Vector3zero
			end
		end
		V.Pos = st.PartPos
		V.Time = now
	end
	SilentAim.Predict(S, st)
	SilentAim.UpdateOrientation()
	local teamName = "-"
	local okT, ti = pcall(function() return ResolveTeamInfo(st.Player) end)
	if okT and type(ti) == "table" and ti.TeamName ~= nil then
		teamName = tostring(ti.TeamName)
	end
	SilentAim.Dbg = { ScreenDist = st.FovDist, Visible = st.Visible, Team = teamName, Part = st.Part, Source = source or "BuiltIn", ScreenX = st.Screen.X, ScreenY = st.Screen.Y }
end

function SilentAim.ConsultAimwork(S, origin)
	local A = Universery.AimworkAdapter
	if A == nil then
		return nil
	end
	if not A.IsReady() then
		local okE = A.Ensure(S)
		if not okE then
			return nil
		end
	end
	A.SetFOV(origin, S.FOV or 150)
	if not A.Update() then
		return nil
	end
	return A.GetTarget()
end

function SilentAim.Scan()
	local S = Environment.SilentAim
	local cam = workspace.CurrentCamera or Camera
	if cam == nil then
		SilentAim.Clear()
		return
	end
	local okV, viewport = pcall(function() return cam.ViewportSize end)
	if not okV or viewport == nil then
		SilentAim.Clear()
		return
	end
	local okC, camCF = pcall(function() return cam.CFrame end)
	if not okC or camCF == nil then
		SilentAim.Clear()
		return
	end
	local camPos = camCF.Position
	local origin = SilentAim.OriginPos(viewport)
	SilentAim.BehindCount = 0
	if S.StickyTarget and SilentAim.Target ~= nil then
		local st = SilentAim.Validate(SilentAim.Target, S, cam, camPos, viewport, origin)
		if st.valid then
			SilentAim.Commit(st, "BuiltIn")
			return
		end
		SilentAim.Clear()
	end
	if SilentAim.Target == nil and SilentAim.LostAt > 0 and (tick() - SilentAim.LostAt) < (S.TargetSwitchDelay or 0) then
		return
	end
	local awT = SilentAim.ConsultAimwork(S, origin)
	if awT ~= nil then
		local st
		if (S.TargetPart or "Head") == "Random" then
			st = SilentAim.Validate(awT.Player, S, cam, camPos, viewport, origin)
		else
			st = SilentAim.Validate(awT.Player, S, cam, camPos, viewport, origin, awT.Position, awT.PartName)
		end
		if st.valid then
			SilentAim.Commit(st, "Aimwork")
			return
		end
	end
	local mode = S.AimMode or "Closest To Mouse"
	local best, bestScore = nil, nil
	local plist = SilentAim.PlayersCache
	if plist == nil or (tick() - (SilentAim.PlayersCacheT or 0)) > 1 then
		local okP, ps = pcall(function() return GetPlayers(Players) end)
		plist = (okP and ps) or {}
		SilentAim.PlayersCache = plist
		SilentAim.PlayersCacheT = tick()
	end
	for _, player in next, plist do
		if player ~= LocalPlayer then
			local st = SilentAim.Validate(player, S, cam, camPos, viewport, origin)
			if st.valid then
				local score = st.FovDist
				if mode == "Closest Distance" then
					score = st.WorldDist
				end
				if bestScore == nil or score < bestScore then
					best, bestScore = st, score
				end
			end
		end
	end
	if best ~= nil then
		SilentAim.Commit(best, "BuiltIn")
	else
		SilentAim.Clear()
		SilentAim.Method = "Idle"
		SilentAim.SupportReason = "No valid target"
	end
end

function SilentAim.DrawFOV()
	local S = Environment.SilentAim
	if SilentAim.FOVCircle == nil then
		SilentAim.FOVCircle = ESPMk("Circle")
	end
	if SilentAim.FOVCircleOutline == nil then
		SilentAim.FOVCircleOutline = ESPMk("Circle")
	end
	local c = SilentAim.FOVCircle
	local oc = SilentAim.FOVCircleOutline
	if c == nil then
		if oc ~= nil then
			oc.Visible = false
		end
		return
	end
	if S == nil or not S.Enabled or not S.ShowFOV then
		c.Visible = false
		if oc ~= nil then
			oc.Visible = false
		end
		return
	end
	local viewport = Vector2.new(0, 0)
	pcall(function()
		local camNow = workspace.CurrentCamera or Camera
		if camNow ~= nil then
			local vs = camNow.ViewportSize
			if vs ~= nil then
				viewport = Vector2.new(vs.X, vs.Y)
			end
		end
	end)
	local o = SilentAim.OriginPos(viewport)
	local radius = S.FOV or 150
	local thick = S.FOVThickness or 1
	local pad = S.FOVOutlineThickness or 2
	c.Position = o
	c.Radius = radius
	c.Color = S.FOVColor or Color3fromRGB(255, 255, 255)
	c.Thickness = thick
	c.ZIndex = 1
	if S.FOVFilled then
		c.Filled = true
		c.Transparency = S.FOVFillTransparency or 0.5
	else
		c.Filled = false
		c.Transparency = S.FOVTransparency or 0
	end
	c.Visible = true
	if oc ~= nil and S.FOVOutline then
		oc.Position = o
		oc.Radius = radius + pad
		oc.Color = S.FOVOutlineColor or Color3fromRGB(0, 0, 0)
		oc.Thickness = thick + 2
		oc.Filled = false
		oc.Transparency = S.FOVTransparency or 0
		oc.ZIndex = 0
		oc.Visible = true
	elseif oc ~= nil then
		oc.Visible = false
	end
end

function SilentAim.Frame(dt)
	local S = Environment.SilentAim
	local Fire = Universery.SilentFire
	if S == nil or not S.Enabled then
		Fire.Uninstall()
		if Universery.AimworkAdapter ~= nil then
			pcall(Universery.AimworkAdapter.Teardown)
		end
		if SilentAim.Method ~= "Off" then
			SilentAim.Clear()
			SilentAim.Method = "Off"
			SilentAim.SupportReason = "Disabled"
		end
		SilentAim.DrawFOV()
		return
	end
	SilentAim.DrawFOV()
	if S.UseCameraHook and Fire.Probe() then
		if not Fire.IsHooked() then
			Fire.Engage()
		end
	elseif Fire.IsHooked() then
		Fire.Uninstall()
	end
	pcall(function() Fire.SetCamera(workspace.CurrentCamera or Camera) end)
	local FS = Universery.FireState
	FS.Poll()
	FS.RefreshTools()
	SilentAim.FireHeld = FS.IsFiring()
	SilentAim.ScanAccum = SilentAim.ScanAccum + (dt or 0.016)
	if SilentAim.ScanAccum >= (1 / 45) then
		SilentAim.ScanAccum = 0
		if SilentAim.IsArmed() then
			SilentAim.Scan()
		else
			SilentAim.Clear()
		end
	end
	local firing = FS.IsFiring()
	local armed = SilentAim.IsArmed()
	Fire.SetAim(SilentAim.PredictedPos, SilentAim.AimCFrame, SilentAim.HookOrigin)
	Fire.SetOverride(Fire.IsHooked() and armed and SilentAim.Target ~= nil and SilentAim.PredictedPos ~= nil and firing)
	if Fire.IsOverriding() and not SilentAim.PrevOverride then
		SilentAim.OverrideApps = (SilentAim.OverrideApps or 0) + 1
	end
	SilentAim.PrevOverride = Fire.IsOverriding()
	local customOn = SilentAim.CustomOn and SilentAim.Target ~= nil
	if not armed then
		SilentAim.Method = "Idle"
		SilentAim.SupportReason = "Waiting for key"
	elseif Fire.IsOverriding() then
		if customOn then
			SilentAim.Method = "Active (Custom)"
			SilentAim.SupportReason = "Custom aim applier engaged; visual camera unchanged"
		else
			SilentAim.Method = "Active (Hook)"
			SilentAim.SupportReason = "Camera reads redirected to target; visual unchanged | hookreads=" .. tostring(Fire.HookReads())
		end
	elseif SilentAim.Target == nil then
		SilentAim.Method = "Idle"
		SilentAim.SupportReason = "No valid target"
	elseif not Fire.IsHooked() and not customOn then
		if S.UseCameraHook and not Fire.Probe() then
			SilentAim.Method = "Unsupported"
			SilentAim.SupportReason = "Executor lacks hook API (need hookmetamethod or setreadonly)"
		elseif not S.UseCameraHook then
			SilentAim.Method = "Unsupported"
			SilentAim.SupportReason = "Camera hook disabled and no custom applier"
		else
			local finfo = Fire.Info()
			SilentAim.SupportReason = (finfo.error ~= "" and finfo.error) or "Weapon does not expose compatible client-side aim orientation"
			SilentAim.Method = "Unsupported"
		end
	else
		SilentAim.Method = "Armed"
		SilentAim.SupportReason = "Target acquired; awaiting fire"
	end
end

function SilentAim.Shutdown()
	SilentAim.Clear()
	SilentAim.KeyHeld = false
	SilentAim.KeyToggle = false
	SilentAim.Method = "Off"
	SilentAim.SupportReason = "Disabled"
	Universery.SilentFire.Uninstall()
	if Universery.AimworkAdapter ~= nil then
		pcall(Universery.AimworkAdapter.Teardown)
	end
	Universery.FireState.Reset()
	if SilentAim.FOVCircle ~= nil then
		pcall(function() SilentAim.FOVCircle:Remove() end)
		SilentAim.FOVCircle = nil
	end
	if SilentAim.FOVCircleOutline ~= nil then
		pcall(function() SilentAim.FOVCircleOutline:Remove() end)
		SilentAim.FOVCircleOutline = nil
	end
end

function SilentAim.Probe()
	if SilentAim.ProbeCache ~= nil and (tick() - (SilentAim.ProbeT or 0)) < 2 then
		return SilentAim.ProbeCache[1], SilentAim.ProbeCache[2]
	end
	local S = Environment.SilentAim
	local hasApplier = type(S.Applier) == "function"
	if not hasApplier then
		local ga = Environment.GameAdapter
		hasApplier = type(ga) == "table" and type(ga.ApplySilentAim) == "function"
	end
	local tool = "none"
	pcall(function()
		local ch = __index(LocalPlayer, "Character")
		if ch ~= nil then
			local descs = GetDescendants(ch)
			for _, d in next, descs do
				if d:IsA("Tool") then
					tool = tostring(d.Name)
					break
				end
			end
		end
	end)
	SilentAim.ProbeCache = { hasApplier, tool }
	SilentAim.ProbeT = tick()
	return hasApplier, tool
end

Environment.GetSilentInfo = LPH_NO_VIRTUALIZE(function()
	local S = Environment.SilentAim
	local tname = nil
	if SilentAim.Target ~= nil then
		pcall(function() tname = __index(SilentAim.Target, "Name") end)
	end
	local hasApplier, tool = SilentAim.Probe()
	local keyHeld = (SilentAim.KeyHeld or (S.KeyMode == "Toggle" and SilentAim.KeyToggle)) and true or false
	local Fire2 = Universery.SilentFire
	local regAdapter = Fire2.ResolveAdapter()
	local awState = "NOT INSTALLED"
	if Universery.AimworkAdapter ~= nil then
		local okAW, stAW = pcall(Universery.AimworkAdapter.State)
		if okAW and stAW ~= nil then
			awState = tostring(stAW)
		end
	end
	local awDiag = nil
	if Universery.AimworkAdapter ~= nil then
		pcall(function()
			local d = Universery.AimworkAdapter.Diag()
			if type(d) == "table" then
				awDiag = d
			end
		end)
	end
	local pipe = "NOT CONNECTED"
	if hasApplier or regAdapter ~= nil then
		pipe = "CUSTOM"
	elseif Fire2.IsHooked() then
		pipe = "HOOKED"
	end
	local awDiag = { source = false, class = false, instance = false, tracker = false, iterate = false, selected = "NONE" }
	if Universery.AimworkAdapter ~= nil then
		pcall(function()
			local d = Universery.AimworkAdapter.Diag()
			if type(d) == "table" then
				awDiag = d
			end
		end)
	end
	local effT, velM, predPos = 0, 0, nil
	if S.Prediction then
		if PingState.Available and (PingState.Effective or 0) > 0 then
			effT = PingState.Effective
		else
			effT = 0.1
		end
	end
	if SilentAim.Vel ~= nil and SilentAim.Vel.Vel ~= nil then
		pcall(function() velM = SilentAim.Vel.Vel.Magnitude end)
	end
	if SilentAim.PredictedPos ~= nil then
		pcall(function()
			local p = SilentAim.PredictedPos
			predPos = string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)
		end)
	end
	local aimOrg, aimTgt, aimDir = nil, nil, nil
	pcall(function()
		local o = Universery.SilentFire.GetOrigin()
		if o == nil and SilentAim.HookOrigin ~= nil then
			o = SilentAim.HookOrigin
		end
		if o ~= nil and SilentAim.PredictedPos ~= nil then
			local t = SilentAim.PredictedPos
			local d = t - o
			local m = d.Magnitude
			aimOrg = string.format("%.1f,%.1f,%.1f", o.X, o.Y, o.Z)
			aimTgt = string.format("%.1f,%.1f,%.1f", t.X, t.Y, t.Z)
			if m > 0.001 then
				local u = d / m
				aimDir = string.format("%.3f,%.3f,%.3f", u.X, u.Y, u.Z)
			end
		end
	end)
	local mx, my = -1, -1
	pcall(function()
		local mp = GetMouseLocation(UserInputService)
		if mp ~= nil then
			mx, my = mp.X, mp.Y
		end
	end)
	local mouseDist = SilentAim.Dbg.ScreenDist or -1
	local inFov = false
	if SilentAim.Target ~= nil and mouseDist >= 0 and mouseDist <= (S.FOV or 150) then
		inFov = true
	end
	local fireEvents, toolEvents = 0, 0
	if Universery.FireState ~= nil then
		pcall(function() fireEvents = Universery.FireState.FireEvents() end)
		pcall(function() toolEvents = Universery.FireState.ToolEvents() end)
	end
	local mreads = { Hit = 0, Target = 0, UnitRay = 0 }
	pcall(function()
		local r = Fire2.Info().reads
		if type(r) == "table" then
			mreads = r
		end
	end)
	return {
		Enabled = S.Enabled,
		KeyHeld = keyHeld,
		Target = tname,
		Part = SilentAim.TargetPart or "-",
		ScreenDist = SilentAim.Dbg.ScreenDist or -1,
		ScreenX = SilentAim.Dbg.ScreenX or -1,
		ScreenY = SilentAim.Dbg.ScreenY or -1,
		Visible = SilentAim.Dbg.Visible,
		Team = SilentAim.Dbg.Team or "-",
		Prediction = S.Prediction,
		AimMethod = SilentAim.Method,
		Reason = SilentAim.SupportReason,
		FirePipeline = pipe,
		Override = (Fire2.IsOverriding() and "ACTIVE" or "INACTIVE"),
		HookReads = Fire2.HookReads(),
		Hooked = Fire2.IsHooked(),
		Aimwork = awState,
		AWDiag = awDiag,
		Source = SilentAim.Dbg.Source or "-",
		EffLatency = effT,
		VelMag = velM,
		Predicted = predPos,
		AimOrigin = aimOrg,
		AimTarget = aimTgt,
		AimDirection = aimDir,
		Firing = SilentAim.FireHeld and true or false,
		FOVOrigin = S.FOVOrigin or "?",
		MouseX = mx,
		MouseY = my,
		MouseDist = mouseDist,
		InFOV = inFov,
		Behind = SilentAim.BehindCount or 0,
		OverrideApps = SilentAim.OverrideApps or 0,
		Behind = SilentAim.BehindCount or 0,
		FireEvents = fireEvents,
		ToolEvents = toolEvents,
		OverrideApps = SilentAim.OverrideApps or 0,
		MouseReads = mreads,
		Tool = tool,
		VisualCamera = "Unchanged",
		FOV = S.FOV,
	}
end)

