--// MAIN TAB, LEFT: Aimbot + Filters + Smoothing

local AimSec = MakeSection("Aimbot", "Left")
if AimSec ~= nil then
	AimSec:Header({ Text = "Aimbot" })

	El.AimbotEnabled = AimSec:Toggle({
		Name = "Enable Aimbot",
		Default = false,
		Callback = function(v) Write("Enabled", v) end,
	}, "AimbotEnabled")
	syncer(function() return El.AimbotEnabled:GetState() end, function(v) Write("Enabled", v) end)

	El.AimKey = AimSec:Keybind({
		Name = "Aim Key",
		Default = Enum.UserInputType.MouseButton2,
		Callback = function() end,
		onBinded = function(bind)
			if bind ~= nil then
				Write("TriggerKey", bind)
			end
		end,
	}, "AimKey")
	syncer(function() return El.AimKey:GetBind() end, function(v) if v ~= nil then Write("TriggerKey", v) end end)

	El.AimMode = AimSec:Dropdown({
		Name = "Aim Mode",
		Search = false,
		Multi = false,
		Required = true,
		Options = { "Hold", "Toggle" },
		Default = 1,
		Callback = function(v) Write("Toggle", v == "Toggle") end,
	}, "AimMode")
	syncer(function() return El.AimMode.Value end, function(v) Write("Toggle", v == "Toggle") end)

	El.IgnoreGameKeyConflicts = AimSec:Toggle({
		Name = "Ignore Game Key Conflicts",
		Default = false,
		Callback = function(v) Write("IgnoreGameKeyConflicts", v) end,
	}, "IgnoreGameKeyConflicts")
	syncer(function() return El.IgnoreGameKeyConflicts:GetState() end, function(v) Write("IgnoreGameKeyConflicts", v) end)

	AimSec:Label({ Text = "ON: conflicting game actions are suppressed, aimbot takes over the key." })

	AimSec:Header({ Text = "FOV" })

	El.FOVEnabled = AimSec:Toggle({
		Name = "FOV Enabled",
		Default = true,
		Callback = function(v) Write("FOVEnabled", v) end,
	}, "FOVEnabled")
	syncer(function() return El.FOVEnabled:GetState() end, function(v) Write("FOVEnabled", v) end)

	El.AcqFOV = AimSec:Slider({
		Name = "Acquisition FOV",
		Default = 180,
		Minimum = 10,
		Maximum = 500,
		DisplayMethod = "Value",
		Precision = 0,
		Callback = function(v) Write("Radius", v) end,
	}, "AcqFOV")
	syncer(function() return El.AcqFOV:GetValue() end, function(v) Write("Radius", v) end)

	El.ShowFOV = AimSec:Toggle({
		Name = "Show FOV",
		Default = true,
		Callback = function(v) Write("FOVVisible", v) end,
	}, "ShowFOV")
	syncer(function() return El.ShowFOV:GetState() end, function(v) Write("FOVVisible", v) end)

	El.ShowLockRadius = AimSec:Toggle({
		Name = "Show Lock Radius",
		Default = false,
		Callback = function(v) Write("ShowLockRadius", v) end,
	}, "ShowLockRadius")
	syncer(function() return El.ShowLockRadius:GetState() end, function(v) Write("ShowLockRadius", v) end)

	El.FOVColor = AimSec:Colorpicker({
		Name = "FOV Color",
		Default = Color3.fromRGB(255, 255, 255),
		Alpha = 0,
		Callback = function(c) Write("FOVColor", c) end,
	}, "FOVColor")
	syncer(function() return El.FOVColor.Color end, function(v) Write("FOVColor", v) end)

	El.LockRadiusColor = AimSec:Colorpicker({
		Name = "Lock Radius Color",
		Default = Color3.fromRGB(255, 150, 150),
		Alpha = 0,
		Callback = function(c) Write("LockRadiusColor", c) end,
	}, "LockRadiusColor")
	syncer(function() return El.LockRadiusColor.Color end, function(v) Write("LockRadiusColor", v) end)

	El.FOVThickness = AimSec:Slider({
		Name = "FOV Thickness",
		Default = 1,
		Minimum = 1,
		Maximum = 5,
		DisplayMethod = "Value",
		Precision = 0,
		Callback = function(v) Write("FOVThickness", v) end,
	}, "FOVThickness")
	syncer(function() return El.FOVThickness:GetValue() end, function(v) Write("FOVThickness", v) end)

	El.FOVTransparency = AimSec:Slider({
		Name = "FOV Transparency",
		Default = 1,
		Minimum = 0,
		Maximum = 1,
		DisplayMethod = "Value",
		Precision = 2,
		Callback = function(v) Write("FOVTransparency", v) end,
	}, "FOVTransparency")
	syncer(function() return El.FOVTransparency:GetValue() end, function(v) Write("FOVTransparency", v) end)
end

local FilterSec = MakeSection("Aimbot", "Left")
if FilterSec ~= nil then
	FilterSec:Header({ Text = "Filters" })

	El.TeamCheck = FilterSec:Toggle({
		Name = "Team Check",
		Default = true,
		Callback = function(v) Write("TeamCheck", v) end,
	}, "TeamCheck")
	syncer(function() return El.TeamCheck:GetState() end, function(v) Write("TeamCheck", v) end)

	El.TeamDetectionMode = FilterSec:Dropdown({
		Name = "Team Detection Mode",
		Search = false,
		Multi = false,
		Required = true,
		Options = { "Auto", "Native Roblox", "Custom Attribute", "Value Object", "Tags", "Game Adapter", "Manual", "Disabled" },
		Default = 1,
		Callback = function(v) Write("TeamMode", TeamModeMap[v] or "Auto") end,
	}, "TeamDetectionMode")
	syncer(function() return El.TeamDetectionMode.Value end, function(v) Write("TeamMode", TeamModeMap[v] or "Auto") end)

	El.UnknownTeamBehavior = FilterSec:Dropdown({
		Name = "Unknown Team Behavior",
		Search = false,
		Multi = false,
		Required = true,
		Options = { "Ignore", "Target" },
		Default = 1,
		Callback = function(v) Write("UnknownBehavior", v) end,
	}, "UnknownTeamBehavior")
	syncer(function() return El.UnknownTeamBehavior.Value end, function(v) Write("UnknownBehavior", v) end)

	El.FriendCheck = FilterSec:Toggle({
		Name = "Friend Check",
		Default = true,
		Callback = function(v) Write("FriendCheck", v) end,
	}, "FriendCheck")
	syncer(function() return El.FriendCheck:GetState() end, function(v) Write("FriendCheck", v) end)

	El.AliveCheck = FilterSec:Toggle({
		Name = "Alive Check",
		Default = true,
		Callback = function(v) Write("AliveCheck", v) end,
	}, "AliveCheck")
	syncer(function() return El.AliveCheck:GetState() end, function(v) Write("AliveCheck", v) end)

	El.VisibilityCheck = FilterSec:Toggle({
		Name = "Visibility Check",
		Default = true,
		Callback = function(v) Write("WallCheck", v) end,
	}, "VisibilityCheck")
	syncer(function() return El.VisibilityCheck:GetState() end, function(v) Write("WallCheck", v) end)

	El.StrictVisibility = FilterSec:Toggle({
		Name = "Strict Visibility",
		Default = true,
		Callback = function(v) Write("StrictVisibility", v) end,
	}, "StrictVisibility")
	syncer(function() return El.StrictVisibility:GetState() end, function(v) Write("StrictVisibility", v) end)
end

local SmoothSec = MakeSection("Aimbot", "Left")
if SmoothSec ~= nil then
	SmoothSec:Header({ Text = "Smoothing" })

	El.AdaptiveSmoothing = SmoothSec:Toggle({
		Name = "Adaptive Smoothing",
		Default = true,
		Callback = function(v) Write("AdaptiveSmoothing", v) end,
	}, "AdaptiveSmoothing")
	syncer(function() return El.AdaptiveSmoothing:GetState() end, function(v) Write("AdaptiveSmoothing", v) end)

	local function smoothSlider(flag, label, def)
		El[flag] = SmoothSec:Slider({
			Name = label,
			Default = def,
			Minimum = 0,
			Maximum = 1,
			DisplayMethod = "Value",
			Precision = 2,
			Callback = function(v) Write(flag, v) end,
		}, flag)
		syncer(function() return El[flag]:GetValue() end, function(v) Write(flag, v) end)
	end
	smoothSlider("SmoothMin", "Minimum Smoothing", 0.08)
	smoothSlider("SmoothMax", "Maximum Smoothing", 0.9)
	smoothSlider("SmoothError", "Aim Error Influence", 0.6)
	smoothSlider("SmoothDistance", "Distance Influence", 0.2)
	smoothSlider("SmoothVelocity", "Velocity Influence", 0.3)
	smoothSlider("SmoothStability", "Stability Influence", 0.4)
end

--// MAIN TAB, RIGHT: Targeting + Prediction + Utility

local TargetSec = MakeSection("Aimbot", "Right")
if TargetSec ~= nil then
	TargetSec:Header({ Text = "Targeting" })

	El.TargetSelection = TargetSec:Dropdown({
		Name = "Target Selection",
		Search = false,
		Multi = false,
		Required = true,
		Options = { "Best Score", "Closest To Cursor", "Closest Distance", "Lowest Health", "Priority" },
		Default = 1,
		Callback = function(v) Write("PriorityMode", PriorityMap[v] or "Score") end,
	}, "TargetSelection")
	syncer(function() return El.TargetSelection.Value end, function(v) Write("PriorityMode", PriorityMap[v] or "Score") end)

	El.TargetPart = TargetSec:Dropdown({
		Name = "Target Part",
		Search = false,
		Multi = false,
		Required = true,
		Options = { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "Torso", "Nearest Visible", "Custom" },
		Default = 1,
		Callback = function(v)
			local m = PartModeMap[v]
			if m == nil then
				return
			end
			if v == "Nearest Visible" then
				Write("PartMode", "ClosestVisible")
			elseif v == "Custom" then
				Write("PartMode", "PriorityList")
			else
				Write("PartMode", m[1])
				Write("LockPart", m[2])
			end
		end,
	}, "TargetPart")

	El.UseDistanceLimit = TargetSec:Toggle({
		Name = "Use Distance Limit",
		Default = true,
		Callback = function(v)
			local A = Aim()
			if A == nil then
				return
			end
			if v then
				Write("MaxDistance", SavedMaxDist)
			else
				pcall(function() SavedMaxDist = A.Settings.MaxDistance end)
				Write("MaxDistance", 100000)
			end
		end,
	}, "UseDistanceLimit")

	El.MaxDistance = TargetSec:Slider({
		Name = "Max Distance",
		Default = 1000,
		Minimum = 0,
		Maximum = 5000,
		DisplayMethod = "Value",
		Precision = 0,
		Callback = function(v)
			SavedMaxDist = v
			Write("MaxDistance", v)
		end,
	}, "MaxDistance")
	syncer(function() return El.MaxDistance:GetValue() end, function(v) SavedMaxDist = v Write("MaxDistance", v) end)

	El.LockRetention = TargetSec:Slider({
		Name = "Lock Retention Radius",
		Default = 30,
		Minimum = 5,
		Maximum = 200,
		DisplayMethod = "Value",
		Precision = 0,
		Callback = function(v) Write("LockRetentionRadius", v) end,
	}, "LockRetention")
	syncer(function() return El.LockRetention:GetValue() end, function(v) Write("LockRetentionRadius", v) end)

	El.EnableStickiness = TargetSec:Toggle({
		Name = "Enable Stickiness",
		Default = true,
		Callback = function(v)
			if v then
				Write("TargetStickiness", SavedStick)
			else
				local A = Aim()
				if A ~= nil then
					pcall(function() SavedStick = A.Settings.TargetStickiness end)
				end
				Write("TargetStickiness", 0)
			end
		end,
	}, "EnableStickiness")

	El.StickinessStrength = TargetSec:Slider({
		Name = "Stickiness Strength",
		Default = 0.5,
		Minimum = 0,
		Maximum = 1,
		DisplayMethod = "Value",
		Precision = 2,
		Callback = function(v)
			SavedStick = v
			Write("TargetStickiness", v)
		end,
	}, "StickinessStrength")
	syncer(function() return El.StickinessStrength:GetValue() end, function(v) SavedStick = v Write("TargetStickiness", v) end)

	El.SwitchThreshold = TargetSec:Slider({
		Name = "Switch Threshold",
		Default = 0.12,
		Minimum = 0,
		Maximum = 0.5,
		DisplayMethod = "Value",
		Precision = 2,
		Callback = function(v) Write("SwitchThreshold", v) end,
	}, "SwitchThreshold")
	syncer(function() return El.SwitchThreshold:GetValue() end, function(v) Write("SwitchThreshold", v) end)
end

local PredSec = MakeSection("Aimbot", "Right")
if PredSec ~= nil then
	PredSec:Header({ Text = "Prediction" })

	local function predToggle(flag, label, def, tip)
		El[flag] = PredSec:Toggle({
			Name = label,
			Default = def,
			Callback = function(v) Write(flag, v) end,
		}, flag)
		syncer(function() return El[flag]:GetState() end, function(v) Write(flag, v) end)
	end
	predToggle("PredictionMaster", "Ping Prediction", true)
	predToggle("AdaptivePrediction", "Adaptive Prediction", true)
	predToggle("PingSmoothing", "Ping Smoothing", true)
	predToggle("JitterCompensation", "Jitter Compensation", true)
	predToggle("AutoCalibration", "Auto Calibration", true)

	local function predSlider(flag, label, def, mn, mx, prec)
		El[flag] = PredSec:Slider({
			Name = label,
			Default = def,
			Minimum = mn,
			Maximum = mx,
			DisplayMethod = "Value",
			Precision = prec,
			Callback = function(v) Write(flag, v) end,
		}, flag)
		syncer(function() return El[flag]:GetValue() end, function(v) Write(flag, v) end)
	end
	predSlider("PingMultiplier", "Ping Multiplier", 1, 0.5, 1.5, 2)
	predSlider("PredictionStrength", "Prediction Strength", 0.6, 0, 1, 2)
	predSlider("MinPrediction", "Min Prediction", 0.02, 0, 0.2, 3)
	predSlider("MaxPrediction", "Max Prediction", 0.3, 0.05, 0.5, 2)
	predSlider("CalibrationStrength", "Calibration Strength", 1, 0, 2, 2)
	predSlider("LearningRate", "Learning Rate", 0.05, 0, 0.2, 3)
end

local UtilSec = MakeSection("Aimbot", "Right")
if UtilSec ~= nil then
	UtilSec:Header({ Text = "Utility" })

	UtilSec:Button({
		Name = "Panic / Stop Aimbot",
		Callback = function()
			local A = Aim()
			if A ~= nil and type(A.Panic) == "function" then
				pcall(function() A.Panic() end)
				pcall(function()
					if El.AimbotEnabled ~= nil then
						El.AimbotEnabled:UpdateState(false)
					end
				end)
				Notify("Panic", "Aimbot disabled, lock cleared.")
			else
				Notify("Panic", "Unavailable (aimbot missing).")
			end
		end,
	})

	UtilSec:Button({
		Name = "Reset Aimbot Settings",
		Callback = function()
			local A = Aim()
			if A == nil then
				Notify("Reset", "Failed: aimbot missing.")
				return
			end
			pcall(function()
			A.Settings.Enabled = false
			A.Settings.Toggle = false
			A.Settings.IgnoreGameKeyConflicts = false
			A.Settings.TriggerKey = Enum.UserInputType.MouseButton2
				A.FOVSettings.Enabled = true
				A.FOVSettings.Radius = 180
				A.FOVSettings.Visible = true
				A.FOVSettings.Color = Color3.fromRGB(255, 255, 255)
				A.FOVSettings.Thickness = 1
				A.FOVSettings.Transparency = 1
				A.FOVSettings.ShowLockRadius = false
				A.FOVSettings.LockRadiusColor = Color3.fromRGB(255, 150, 150)
				A.Settings.TeamCheck = true
				A.TeamResolver.Mode = "Auto"
				A.TeamResolver.UnknownBehavior = "Ignore"
				A.Settings.FriendCheck = true
				A.Settings.AliveCheck = true
				A.Settings.WallCheck = true
				A.Settings.StrictVisibility = true
				A.Settings.PriorityMode = "Score"
				A.Settings.PartMode = "Static"
				A.Settings.LockPart = "Head"
				A.Settings.MaxDistance = 1000
				A.Settings.LockRetentionRadius = 30
				A.Settings.TargetStickiness = 0.5
				A.Settings.SwitchThreshold = 0.12
				A.Network.PingPrediction = true
				A.Network.PingMultiplier = 1
				A.Network.PingSmoothing = true
				A.Network.JitterCompensation = true
				A.Network.AutoCalibration = true
				A.Prediction.ConfidenceStrength = 0.6
				A.Network.MinLatency = 0.02
				A.Network.MaxLatency = 0.3
				A.Network.CalibrationStrength = 1
				A.Network.CalibrationRate = 0.05
				A.Prediction.Adaptive = true
				A.Smoothing.Adaptive = true
				A.Smoothing.Min = 0.08
				A.Smoothing.Max = 0.9
				A.Smoothing.ErrorInfluence = 0.6
				A.Smoothing.DistanceInfluence = 0.2
				A.Smoothing.VelocityInfluence = 0.3
				A.Smoothing.StabilityInfluence = 0.4
			end)
			SavedMaxDist = 1000
			SavedStick = 0.5
			local function setT(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateState(v) end) end end
			local function setS(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateValue(v) end) end end
			local function setD(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateSelection(v) end) end end
			setT("AimbotEnabled", false)
			setT("IgnoreGameKeyConflicts", false)
			if El.AimKey ~= nil then pcall(function() El.AimKey:Bind(Enum.UserInputType.MouseButton2) end) end
			setD("AimMode", "Hold")
			setT("FOVEnabled", true)
			setS("AcqFOV", 180)
			setT("ShowFOV", true)
			setT("ShowLockRadius", false)
			if El.FOVColor ~= nil then pcall(function() El.FOVColor:SetColor(Color3.fromRGB(255, 255, 255)) end) end
			if El.LockRadiusColor ~= nil then pcall(function() El.LockRadiusColor:SetColor(Color3.fromRGB(255, 150, 150)) end) end
			setS("FOVThickness", 1)
			setS("FOVTransparency", 1)
			setT("TeamCheck", true)
			setD("TeamDetectionMode", "Auto")
			setD("UnknownTeamBehavior", "Ignore")
			setT("FriendCheck", true)
			setT("AliveCheck", true)
			setT("VisibilityCheck", true)
			setT("StrictVisibility", true)
			setD("TargetSelection", "Best Score")
			setD("TargetPart", "Head")
			setT("UseDistanceLimit", true)
			setS("MaxDistance", 1000)
			setS("LockRetention", 30)
			setT("EnableStickiness", true)
			setS("StickinessStrength", 0.5)
			setS("SwitchThreshold", 0.12)
			setT("PredictionMaster", true)
			setT("AdaptivePrediction", true)
			setS("PingMultiplier", 1)
			setT("PingSmoothing", true)
			setT("JitterCompensation", true)
			setT("AutoCalibration", true)
			setS("PredictionStrength", 0.6)
			setS("MinPrediction", 0.02)
			setS("MaxPrediction", 0.3)
			setS("CalibrationStrength", 1)
			setS("LearningRate", 0.05)
			setT("AdaptiveSmoothing", true)
			setS("SmoothMin", 0.08)
			setS("SmoothMax", 0.9)
			setS("SmoothError", 0.6)
			setS("SmoothDistance", 0.2)
			setS("SmoothVelocity", 0.3)
			setS("SmoothStability", 0.4)
			Notify("Reset", "Aimbot settings reset to defaults.")
		end,
	})

	El.StatusLabel = UtilSec:Label({ Text = "Aimbot: OFF | Target: None" })

	El.PanicKey = UtilSec:Keybind({
		Name = "Panic Key",
		Default = Enum.KeyCode.F8,
		Callback = function()
			local A = Aim()
			if A ~= nil and type(A.Panic) == "function" then
				pcall(function() A.Panic() end)
				pcall(function()
					if El.AimbotEnabled ~= nil then
						El.AimbotEnabled:UpdateState(false)
					end
				end)
			end
		end,
		onBinded = function() end,
	}, "PanicKey")

	El.ToggleAimbotKey = UtilSec:Keybind({
		Name = "Toggle Aimbot Key",
		Default = Enum.KeyCode.F7,
		Callback = function()
			if El.AimbotEnabled ~= nil then
				local ok, st = pcall(function() return El.AimbotEnabled:GetState() end)
				if ok then
					pcall(function() El.AimbotEnabled:UpdateState(not st) end)
					Write("Enabled", not st)
				end
			end
		end,
		onBinded = function() end,
	}, "ToggleAimbotKey")
end

-- ESP tab lives in its own function so the main chunk stays under Lua's
-- 200-local register limit (the aimbot section already holds ~170).
