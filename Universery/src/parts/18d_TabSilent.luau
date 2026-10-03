--// SILENT AIM TAB (Hidden Aim Orientation - visual camera never moves)

local function BuildSilentTab()

local function espT(sec, flag, label, def, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Toggle({
		Name = label,
		Default = def,
		Callback = function(v) Write(key, v) end,
	}, flag)
	syncer(function() return El[flag]:GetState() end, function(v) Write(key, v) end)
end

local function espS(sec, flag, label, def, mn, mx, prec, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Slider({
		Name = label,
		Default = def,
		Minimum = mn,
		Maximum = mx,
		DisplayMethod = "Value",
		Precision = prec,
		Callback = function(v) Write(key, v) end,
	}, flag)
	syncer(function() return El[flag]:GetValue() end, function(v) Write(key, v) end)
end

local function espD(sec, flag, label, options, defIdx, apply)
	if sec == nil then
		return
	end
	El[flag] = sec:Dropdown({
		Name = label,
		Search = false,
		Multi = false,
		Required = true,
		Options = options,
		Default = defIdx,
		Callback = function(v) apply(v) end,
	}, flag)
	syncer(function() return El[flag].Value end, function(v) apply(v) end)
end

local function espC(sec, flag, label, def, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Colorpicker({
		Name = label,
		Default = def,
		Alpha = 0,
		Callback = function(c) Write(key, c) end,
	}, flag)
	syncer(function() return El[flag].Color end, function(v) Write(key, v) end)
end

local SilentMain = MakeSection("Silent Aim", "Left")
if SilentMain ~= nil then
	SilentMain:Header({ Text = "Silent Aim" })

	espT(SilentMain, "SA_Enabled", "Enable Silent Aim", false, "SilentAim.Enabled")
	El.SA_Key = SilentMain:Keybind({
		Name = "Silent Aim Key",
		Default = Enum.UserInputType.MouseButton2,
		Callback = function() end,
		onBinded = function(bind)
			if bind ~= nil then
				Write("SilentAim.EnabledKey", bind)
			end
		end,
	}, "SA_Key")
	syncer(function() return El.SA_Key:GetBind() end, function(v) if v ~= nil then Write("SilentAim.EnabledKey", v) end end)
	espD(SilentMain, "SA_KeyMode", "Key Mode", { "Hold", "Toggle" }, 1, function(v)
		Write("SilentAim.KeyMode", v)
	end)
	espT(SilentMain, "SA_Protect", "Game Key Protection", false, "SilentAim.GameKeyConflictProtection")
	espT(SilentMain, "SA_Hook", "Camera Hook", true, "SilentAim.UseCameraHook")
	espT(SilentMain, "SA_TeamCheck", "Team Check", true, "SilentAim.TeamCheck")
	espT(SilentMain, "SA_Visibility", "Visibility Check", false, "SilentAim.VisibilityCheck")
	espS(SilentMain, "SA_MaxDistance", "Max Distance", 1000, 50, 5000, 0, "SilentAim.MaxDistance")
	SilentMain:Button({
		Name = "Reset Silent Aim",
		Callback = function()
			local A = Aim()
			if A == nil then
				Notify("Silent Reset", "Failed: aimbot missing.")
				return
			end
			pcall(function()
				A.SilentAim.Enabled = false
				A.SilentAim.EnabledKey = Enum.UserInputType.MouseButton2
				A.SilentAim.KeyMode = "Hold"
				A.SilentAim.FOV = 150
				A.SilentAim.ShowFOV = false
				A.SilentAim.FOVColor = Color3.fromRGB(255, 255, 255)
				A.SilentAim.FOVThickness = 1
				A.SilentAim.FOVTransparency = 0
				A.SilentAim.FOVFilled = false
				A.SilentAim.FOVFillTransparency = 0.5
				A.SilentAim.FOVOrigin = "Screen Center"
				A.SilentAim.TargetPart = "Head"
				A.SilentAim.AimMode = "Closest To Crosshair"
				A.SilentAim.TeamCheck = true
				A.SilentAim.VisibilityCheck = false
				A.SilentAim.MaxDistance = 1000
				A.SilentAim.Prediction = true
				A.SilentAim.PredictionStrength = 1
				A.SilentAim.StickyTarget = true
				A.SilentAim.TargetSwitchDelay = 0.25
				A.SilentAim.IncludeDeadTargets = false
				A.SilentAim.GameKeyConflictProtection = false
				A.SilentAim.UseCameraHook = true
			end)
			if El.SA_Enabled ~= nil then pcall(function() El.SA_Enabled:UpdateState(false) end) end
			if El.SA_Key ~= nil then pcall(function() El.SA_Key:Bind(Enum.UserInputType.MouseButton2) end) end
			if El.SA_KeyMode ~= nil then pcall(function() El.SA_KeyMode:UpdateSelection("Hold") end) end
			if El.SA_Protect ~= nil then pcall(function() El.SA_Protect:UpdateState(false) end) end
			if El.SA_Hook ~= nil then pcall(function() El.SA_Hook:UpdateState(true) end) end
			if El.SA_FOV ~= nil then pcall(function() El.SA_FOV:UpdateValue(150) end) end
			if El.SA_ShowFOV ~= nil then pcall(function() El.SA_ShowFOV:UpdateState(false) end) end
			if El.SA_FOVColor ~= nil then pcall(function() El.SA_FOVColor:SetColor(Color3.fromRGB(255, 255, 255)) end) end
			if El.SA_FOVThickness ~= nil then pcall(function() El.SA_FOVThickness:UpdateValue(1) end) end
			if El.SA_FOVTransparency ~= nil then pcall(function() El.SA_FOVTransparency:UpdateValue(0) end) end
			if El.SA_FOVFilled ~= nil then pcall(function() El.SA_FOVFilled:UpdateState(false) end) end
			if El.SA_FOVFillTransparency ~= nil then pcall(function() El.SA_FOVFillTransparency:UpdateValue(0.5) end) end
			if El.SA_FOVOrigin ~= nil then pcall(function() El.SA_FOVOrigin:UpdateSelection("Screen Center") end) end
			if El.SA_TargetPart ~= nil then pcall(function() El.SA_TargetPart:UpdateSelection("Head") end) end
			if El.SA_AimMode ~= nil then pcall(function() El.SA_AimMode:UpdateSelection("Closest To Crosshair") end) end
			if El.SA_Sticky ~= nil then pcall(function() El.SA_Sticky:UpdateState(true) end) end
			if El.SA_SwitchDelay ~= nil then pcall(function() El.SA_SwitchDelay:UpdateValue(0.25) end) end
			if El.SA_TeamCheck ~= nil then pcall(function() El.SA_TeamCheck:UpdateState(true) end) end
			if El.SA_Visibility ~= nil then pcall(function() El.SA_Visibility:UpdateState(false) end) end
			if El.SA_MaxDistance ~= nil then pcall(function() El.SA_MaxDistance:UpdateValue(1000) end) end
			if El.SA_Prediction ~= nil then pcall(function() El.SA_Prediction:UpdateState(true) end) end
			if El.SA_PredStrength ~= nil then pcall(function() El.SA_PredStrength:UpdateValue(1) end) end
		end,
	})
end

local SilentFOV = MakeSection("Silent Aim", "Right")
if SilentFOV ~= nil then
	SilentFOV:Header({ Text = "FOV" })

	espS(SilentFOV, "SA_FOV", "FOV Size", 150, 10, 1000, 0, "SilentAim.FOV")
	espT(SilentFOV, "SA_ShowFOV", "Show FOV", false, "SilentAim.ShowFOV")
	espC(SilentFOV, "SA_FOVColor", "FOV Color", Color3.fromRGB(255, 255, 255), "SilentAim.FOVColor")
	espS(SilentFOV, "SA_FOVThickness", "Thickness", 1, 1, 5, 0, "SilentAim.FOVThickness")
	espS(SilentFOV, "SA_FOVTransparency", "Transparency", 0, 0, 1, 2, "SilentAim.FOVTransparency")
	espT(SilentFOV, "SA_FOVFilled", "Filled", false, "SilentAim.FOVFilled")
	espS(SilentFOV, "SA_FOVFillTransparency", "Fill Transparency", 0.5, 0, 1, 2, "SilentAim.FOVFillTransparency")
	espD(SilentFOV, "SA_FOVOrigin", "FOV Origin", { "Screen Center", "Mouse" }, 1, function(v)
		Write("SilentAim.FOVOrigin", v)
	end)
end

local SilentTarget = MakeSection("Silent Aim", "Left")
if SilentTarget ~= nil then
	SilentTarget:Header({ Text = "Target" })

	espD(SilentTarget, "SA_TargetPart", "Target Part", { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "Random", "Closest Part" }, 1, function(v)
		Write("SilentAim.TargetPart", v)
	end)
	espD(SilentTarget, "SA_AimMode", "Aim Mode", { "Closest To Crosshair", "Closest Distance", "Lowest Screen Distance" }, 1, function(v)
		Write("SilentAim.AimMode", v)
	end)
	espT(SilentTarget, "SA_Sticky", "Sticky Target", true, "SilentAim.StickyTarget")
	espS(SilentTarget, "SA_SwitchDelay", "Target Switch Delay", 0.25, 0, 1, 2, "SilentAim.TargetSwitchDelay")
end

local SilentPred = MakeSection("Silent Aim", "Right")
if SilentPred ~= nil then
	SilentPred:Header({ Text = "Prediction" })

	espT(SilentPred, "SA_Prediction", "Prediction", true, "SilentAim.Prediction")
	espS(SilentPred, "SA_PredStrength", "Prediction Strength", 1, 0, 2, 2, "SilentAim.PredictionStrength")
end

end
BuildSilentTab()

