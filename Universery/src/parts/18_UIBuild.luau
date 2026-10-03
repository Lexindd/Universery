-- UI build scope: everything below runs once at startup. Wrapped in do/end
-- so its locals die at the end instead of occupying chunk registers
-- (Luau allows max 200 live locals per chunk).
do
local Aimbot = Aim() -- via getgenv (aimbot now lives in BuildAimbot scope)


-- Aimbot starts OFF from the UI (file default is ON; UI takes over).
pcall(function() Aimbot.Settings.Enabled = false end)

--// Adapter: Write() + Syncers + element registry (for Reset)

local El = {}
local Syncers = {}

local function syncer(get, apply)
	Syncers[#Syncers + 1] = function()
		local ok, v = pcall(get)
		if ok then
			pcall(apply, v)
		end
	end
end

local function Write(path, value)
	local A = Aim()
	if A == nil then
		return
	end
	pcall(function()
		if path == "Enabled" then A.Settings.Enabled = value
		elseif path == "TriggerKey" then A.Settings.TriggerKey = value
		elseif path == "Toggle" then A.Settings.Toggle = value
		elseif path == "FOVEnabled" then A.FOVSettings.Enabled = value
		elseif path == "Radius" then A.FOVSettings.Radius = value
		elseif path == "FOVVisible" then A.FOVSettings.Visible = value
		elseif path == "FOVColor" then A.FOVSettings.Color = value
		elseif path == "FOVThickness" then A.FOVSettings.Thickness = value
		elseif path == "FOVTransparency" then A.FOVSettings.Transparency = value
		elseif path == "ShowLockRadius" then A.FOVSettings.ShowLockRadius = value
		elseif path == "LockRadiusColor" then A.FOVSettings.LockRadiusColor = value
		elseif path == "TeamCheck" then A.Settings.TeamCheck = value
		elseif path == "TeamMode" then A.TeamResolver.Mode = value
		elseif path == "UnknownBehavior" then A.TeamResolver.UnknownBehavior = value
		elseif path == "FriendCheck" then A.Settings.FriendCheck = value
		elseif path == "AliveCheck" then A.Settings.AliveCheck = value
		elseif path == "WallCheck" then A.Settings.WallCheck = value
		elseif path == "StrictVisibility" then A.Settings.StrictVisibility = value
		elseif path == "PriorityMode" then A.Settings.PriorityMode = value
		elseif path == "PartMode" then A.Settings.PartMode = value
		elseif path == "LockPart" then A.Settings.LockPart = value
		elseif path == "MaxDistance" then A.Settings.MaxDistance = value
		elseif path == "LockRetentionRadius" then A.Settings.LockRetentionRadius = value
		elseif path == "TargetStickiness" then A.Settings.TargetStickiness = value
		elseif path == "SwitchThreshold" then A.Settings.SwitchThreshold = value
		elseif path == "PingPrediction" then A.Network.PingPrediction = value
		elseif path == "PingMultiplier" then A.Network.PingMultiplier = value
		elseif path == "PingSmoothing" then A.Network.PingSmoothing = value
		elseif path == "JitterCompensation" then A.Network.JitterCompensation = value
		elseif path == "AutoCalibration" then A.Network.AutoCalibration = value
		elseif path == "ConfidenceStrength" then A.Prediction.ConfidenceStrength = value
		elseif path == "MinLatency" then A.Network.MinLatency = value
		elseif path == "MaxLatency" then A.Network.MaxLatency = value
		elseif path == "CalibrationStrength" then A.Network.CalibrationStrength = value
		elseif path == "CalibrationRate" then A.Network.CalibrationRate = value
		elseif path == "AdaptivePrediction" then A.Prediction.Adaptive = value
		elseif path == "AdaptiveSmoothing" then A.Smoothing.Adaptive = value
		elseif path == "SmoothMin" then A.Smoothing.Min = value
		elseif path == "SmoothMax" then A.Smoothing.Max = value
		elseif path == "SmoothError" then A.Smoothing.ErrorInfluence = value
		elseif path == "SmoothDistance" then A.Smoothing.DistanceInfluence = value
		elseif path == "SmoothVelocity" then A.Smoothing.VelocityInfluence = value
		elseif path == "SmoothStability" then A.Smoothing.StabilityInfluence = value
		elseif path == "Debugger" then A.Debugger.Enabled = value
		elseif path == "IgnoreGameKeyConflicts" then A.Settings.IgnoreGameKeyConflicts = value
		elseif path == "PredictionMaster" then A.Network.PingPrediction = value
		elseif path == "PredictionStrength" then A.Prediction.ConfidenceStrength = value
		elseif path == "MinPrediction" then A.Network.MinLatency = value
		elseif path == "MaxPrediction" then A.Network.MaxLatency = value
		elseif path == "LearningRate" then A.Network.CalibrationRate = value
		elseif path == "ESP_Enabled" then A.ESP.Enabled = value
		elseif path == "ESP_TeamCheck" then A.ESP.TeamCheck = value
		elseif path == "ESP_ShowTeam" then A.ESP.ShowTeam = value
		elseif path == "ESP_Visibility" then A.ESP.VisibilityCheck = value
		elseif path == "ESP_MaxDistance" then A.ESP.MaxDistance = value
		elseif path == "ESP_RefreshFPS" then A.ESP.RefreshFPS = value
		elseif path == "ESP_RefreshMode" then A.ESP.RefreshMode = value
		elseif path == "ESP_FadeDistance" then A.ESP.FadeDistance = value
		elseif path == "ESP_UseTeamColors" then A.ESP.UseTeamColors = value
		elseif path == "ESP_EnemyColor" then A.ESP.EnemyColor = value
		elseif path == "ESP_AllyColor" then A.ESP.AllyColor = value
		elseif path == "ESP_Box" then A.ESP.BoxESP = value
		elseif path == "ESP_BoxStyle" then A.ESP.BoxStyle = value
		elseif path == "ESP_BoxOutline" then A.ESP.BoxOutline = value
		elseif path == "ESP_BoxFilled" then A.ESP.BoxFilled = value
		elseif path == "ESP_BoxFillTransparency" then A.ESP.BoxFillTransparency = value
		elseif path == "ESP_BoxThickness" then A.ESP.BoxThickness = value
		elseif path == "ESP_BoxColor" then A.ESP.BoxColor = value
		elseif path == "ESP_IncludeAccessories" then A.ESP.IncludeAccessories = value
		elseif path == "ESP_Tracer" then A.ESP.TracerESP = value
		elseif path == "ESP_TracerOrigin" then A.ESP.TracerOrigin = value
		elseif path == "ESP_TracerThickness" then A.ESP.TracerThickness = value
		elseif path == "ESP_TracerColor" then A.ESP.TracerColor = value
		elseif path == "ESP_Snaplines" then A.ESP.Snaplines = value
		elseif path == "ESP_Health" then A.ESP.HealthESP = value
		elseif path == "ESP_HealthStyle" then A.ESP.HealthStyle = value
		elseif path == "ESP_HealthSide" then A.ESP.HealthBarSide = value
		elseif path == "ESP_HealthFormat" then A.ESP.HealthFormat = value
		elseif path == "ESP_HealthFullColor" then A.ESP.HealthFullColor = value
		elseif path == "ESP_Name" then A.ESP.NameESP = value
		elseif path == "ESP_NameMode" then A.ESP.NameMode = value
		elseif path == "ESP_ShowDistance" then A.ESP.ShowDistance = value
		elseif path == "ESP_DistanceFade" then A.ESP.DistanceFade = value
		elseif path == "ESP_TextSize" then A.ESP.TextSize = value
		elseif path == "ESP_TextFont" then A.ESP.TextFont = value
		elseif path == "ESP_ScreenYOffset" then A.ESP.ScreenYOffset = value
		elseif path == "ESP_NameColor" then A.ESP.NameColor = value
		elseif path == "ESP_Rainbow" then A.ESP.RainbowEnabled = value
		elseif path == "ESP_RainbowSpeed" then A.ESP.RainbowSpeed = value
		elseif path == "ESP_RainbowBoxes" then A.ESP.RainbowBoxes = value
		elseif path == "ESP_RainbowTracers" then A.ESP.RainbowTracers = value
		elseif path == "ESP_RainbowText" then A.ESP.RainbowText = value
		elseif path == "ESP_Chams" then A.ESP.ChamsEnabled = value
		elseif path == "ESP_ChamsFill" then A.ESP.ChamsFillColor = value
		elseif path == "ESP_ChamsOccluded" then A.ESP.ChamsOccludedColor = value
		elseif path == "ESP_ChamsOutline" then A.ESP.ChamsOutlineColor = value
		elseif path == "ESP_ChamsTransparency" then A.ESP.ChamsTransparency = value
		elseif path == "ESP_ChamsOutlineTransparency" then A.ESP.ChamsOutlineTransparency = value
		elseif path == "ESP_Skeleton" then A.ESP.SkeletonESP = value
		elseif path == "ESP_SkeletonColor" then A.ESP.SkeletonColor = value
		elseif path == "ESP_SkeletonThickness" then A.ESP.SkeletonThickness = value
		elseif path == "ESP_SkeletonTransparency" then A.ESP.SkeletonTransparency = value
		elseif path == "SilentAim.Enabled" then A.SilentAim.Enabled = value
		elseif path == "SilentAim.EnabledKey" then A.SilentAim.EnabledKey = value
		elseif path == "SilentAim.KeyMode" then A.SilentAim.KeyMode = value
		elseif path == "SilentAim.FOV" then A.SilentAim.FOV = value
		elseif path == "SilentAim.ShowFOV" then A.SilentAim.ShowFOV = value
		elseif path == "SilentAim.FOVColor" then A.SilentAim.FOVColor = value
		elseif path == "SilentAim.FOVThickness" then A.SilentAim.FOVThickness = value
		elseif path == "SilentAim.FOVTransparency" then A.SilentAim.FOVTransparency = value
		elseif path == "SilentAim.FOVFilled" then A.SilentAim.FOVFilled = value
		elseif path == "SilentAim.FOVFillTransparency" then A.SilentAim.FOVFillTransparency = value
		elseif path == "SilentAim.FOVOrigin" then A.SilentAim.FOVOrigin = value
		elseif path == "SilentAim.TargetPart" then A.SilentAim.TargetPart = value
		elseif path == "SilentAim.AimMode" then A.SilentAim.AimMode = value
		elseif path == "SilentAim.TeamCheck" then A.SilentAim.TeamCheck = value
		elseif path == "SilentAim.VisibilityCheck" then A.SilentAim.VisibilityCheck = value
		elseif path == "SilentAim.MaxDistance" then A.SilentAim.MaxDistance = value
		elseif path == "SilentAim.Prediction" then A.SilentAim.Prediction = value
		elseif path == "SilentAim.PredictionStrength" then A.SilentAim.PredictionStrength = value
		elseif path == "SilentAim.StickyTarget" then A.SilentAim.StickyTarget = value
		elseif path == "SilentAim.TargetSwitchDelay" then A.SilentAim.TargetSwitchDelay = value
		elseif path == "SilentAim.IncludeDeadTargets" then A.SilentAim.IncludeDeadTargets = value
		elseif path == "SilentAim.GameKeyConflictProtection" then A.SilentAim.GameKeyConflictProtection = value
		elseif path == "SilentAim.UseCameraHook" then A.SilentAim.UseCameraHook = value
		end
	end)
end

local function PushAllToAimbot()
	for _, fn in next, Syncers do
		pcall(fn)
	end
end

--// Value maps (UI labels -> exact aimbot setting values)

local PriorityMap = {
	["Best Score"] = "Score",
	["Closest To Cursor"] = "ClosestToCursor",
	["Closest Distance"] = "ClosestDistance",
	["Lowest Health"] = "LowestHealth",
	["Priority"] = "Priority",
}

local PartModeMap = {
	["Head"] = { "Static", "Head" },
	["UpperTorso"] = { "Static", "UpperTorso" },
	["LowerTorso"] = { "Static", "LowerTorso" },
	["HumanoidRootPart"] = { "Static", "HumanoidRootPart" },
	["Torso"] = { "Static", "Torso" },
	["Nearest Visible"] = { "ClosestVisible", nil },
	["Custom"] = { "PriorityList", nil },
}

local TeamModeMap = {
	["Auto"] = "Auto",
	["Native Roblox"] = "Native",
	["Custom Attribute"] = "Attributes",
	["Value Object"] = "Values",
	["Tags"] = "Tags",
	["Game Adapter"] = "GameAdapter",
	["Manual"] = "Manual",
	["Disabled"] = "Disabled",
}

local SavedMaxDist = 1000
local SavedStick = 0.5

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
local function BuildESPTab()

--// ESP TAB (controls only; engine lives in aimbot.txt ESPController)

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

local ESPMain = MakeSection("ESP", "Left")
if ESPMain ~= nil then
	ESPMain:Header({ Text = "Main" })

	El.ESP_Enabled = ESPMain:Toggle({
		Name = "Enable ESP",
		Default = false,
		Callback = function(v)
			Write("ESP_Enabled", v)
			pcall(function()
				local A = Aim()
				if A ~= nil then
					A.ESP.Panicked = false
				end
			end)
		end,
	}, "ESP_Enabled")
	syncer(function() return El.ESP_Enabled:GetState() end, function(v) Write("ESP_Enabled", v) end)

	espT(ESPMain, "ESP_TeamCheck", "Team Check", true, "ESP_TeamCheck")
	espT(ESPMain, "ESP_ShowTeam", "Show Team", false, "ESP_ShowTeam")
	espT(ESPMain, "ESP_Visibility", "Visibility Check", false, "ESP_Visibility")
	espT(ESPMain, "ESP_UseTeamColors", "Use Team Colors", true, "ESP_UseTeamColors")
	espS(ESPMain, "ESP_MaxDistance", "Max Distance", 1000, 100, 5000, 0, "ESP_MaxDistance")
	espS(ESPMain, "ESP_RefreshFPS", "Refresh Rate (FPS)", 144, 1, 144, 0, "ESP_RefreshFPS")
	espD(ESPMain, "ESP_RefreshMode", "Refresh Mode", { "Fixed", "Half FPS", "Full FPS" }, 2, function(v)
		if v == "Half FPS" then
			Write("ESP_RefreshMode", "Half")
		elseif v == "Full FPS" then
			Write("ESP_RefreshMode", "Full")
		else
			Write("ESP_RefreshMode", "Fixed")
		end
	end)
	espS(ESPMain, "ESP_FadeDistance", "Fade Distance", 500, 20, 1000, 0, "ESP_FadeDistance")
	El.ESP_DistanceFade = ESPMain:Toggle({
		Name = "Distance Fade",
		Default = true,
		Callback = function(v)
			print("[AimbotUI] DistanceFade toggled -> " .. tostring(v))
			Write("ESP_DistanceFade", v)
			local A = Aim()
			print("[AimbotUI] DistanceFade now: " .. tostring(A ~= nil and A.ESP.DistanceFade))
		end,
	}, "ESP_DistanceFade")
	syncer(function() return El.ESP_DistanceFade:GetState() end, function(v) Write("ESP_DistanceFade", v) end)
	espT(ESPMain, "ESP_ShowDistance", "Distance", true, "ESP_ShowDistance")
	espS(ESPMain, "ESP_ScreenYOffset", "Screen Y Offset", 0, -72, 72, 0, "ESP_ScreenYOffset")
	espC(ESPMain, "ESP_EnemyColor", "Enemy Color", Color3.fromRGB(255, 255, 255), "ESP_EnemyColor")
	espC(ESPMain, "ESP_AllyColor", "Ally Color", Color3.fromRGB(25, 255, 25), "ESP_AllyColor")
end

local ESPBox = MakeSection("ESP", "Right")
if ESPBox ~= nil then
	ESPBox:Header({ Text = "Box ESP" })

	espT(ESPBox, "ESP_Box", "Enable", false, "ESP_Box")
	espD(ESPBox, "ESP_BoxStyle", "Style", { "Corner", "Full", "3D" }, 2, function(v)
		if v == "3D" then
			Write("ESP_BoxStyle", "ThreeD")
		else
			Write("ESP_BoxStyle", v)
		end
	end)
	espT(ESPBox, "ESP_BoxOutline", "Outline", true, "ESP_BoxOutline")
	espT(ESPBox, "ESP_BoxFilled", "Filled", false, "ESP_BoxFilled")
	espS(ESPBox, "ESP_BoxFillTransparency", "Fill Transparency", 0.5, 0, 1, 2, "ESP_BoxFillTransparency")
	espS(ESPBox, "ESP_BoxThickness", "Thickness", 1, 1, 5, 1, "ESP_BoxThickness")
	espC(ESPBox, "ESP_BoxColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_BoxColor")
	espT(ESPBox, "ESP_IncludeAccessories", "Include Accessories", false, "ESP_IncludeAccessories")
end

local ESPTracer = MakeSection("ESP", "Left")
if ESPTracer ~= nil then
	ESPTracer:Header({ Text = "Tracer" })

	espT(ESPTracer, "ESP_Tracer", "Enable", true, "ESP_Tracer")
	espD(ESPTracer, "ESP_TracerOrigin", "Origin", { "Bottom", "Top", "Mouse", "Center" }, 1, function(v)
		Write("ESP_TracerOrigin", v)
	end)
	espS(ESPTracer, "ESP_TracerThickness", "Thickness", 1, 1, 5, 0, "ESP_TracerThickness")
	espC(ESPTracer, "ESP_TracerColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_TracerColor")
	espT(ESPTracer, "ESP_Snaplines", "Snapline", false, "ESP_Snaplines")
end

local ESPSkel = MakeSection("ESP", "Right")
if ESPSkel ~= nil then
	ESPSkel:Header({ Text = "Skeleton" })

	espT(ESPSkel, "ESP_Skeleton", "Enable", false, "ESP_Skeleton")
	espC(ESPSkel, "ESP_SkeletonColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_SkeletonColor")
	espS(ESPSkel, "ESP_SkeletonThickness", "Thickness", 1.5, 1, 3, 1, "ESP_SkeletonThickness")
	espS(ESPSkel, "ESP_SkeletonTransparency", "Transparency", 0, 0, 1, 2, "ESP_SkeletonTransparency")
end

local ESPHealth = MakeSection("ESP", "Left")
if ESPHealth ~= nil then
	ESPHealth:Header({ Text = "Health" })

	espT(ESPHealth, "ESP_Health", "Enable", false, "ESP_Health")
	espD(ESPHealth, "ESP_HealthStyle", "Style", { "Bar", "Text", "Both" }, 1, function(v)
		Write("ESP_HealthStyle", v)
	end)
	espD(ESPHealth, "ESP_HealthSide", "Side", { "Left", "Right" }, 1, function(v)
		Write("ESP_HealthSide", v)
	end)
	espD(ESPHealth, "ESP_HealthFormat", "Format", { "Number", "Percentage", "Both" }, 1, function(v)
		Write("ESP_HealthFormat", v)
	end)
	espC(ESPHealth, "ESP_HealthFullColor", "Full HP Color", Color3.fromRGB(0, 255, 0), "ESP_HealthFullColor")
end

local ESPName = MakeSection("ESP", "Right")
if ESPName ~= nil then
	ESPName:Header({ Text = "Name / Info" })

	espT(ESPName, "ESP_Name", "Name", false, "ESP_Name")
	espD(ESPName, "ESP_NameMode", "Name Mode", { "DisplayName", "Username" }, 1, function(v)
		Write("ESP_NameMode", v)
	end)
	espS(ESPName, "ESP_TextSize", "Text Size", 14, 10, 24, 0, "ESP_TextSize")
	espD(ESPName, "ESP_TextFont", "Font", { "UI", "System", "Plex", "Monospace" }, 3, function(v)
		local map = { UI = 0, System = 1, Plex = 2, Monospace = 3 }
		Write("ESP_TextFont", map[v] or 2)
	end)
	espC(ESPName, "ESP_NameColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_NameColor")
end

local ESPChams = MakeSection("ESP", "Left")
if ESPChams ~= nil then
	ESPChams:Header({ Text = "Chams" })

	espT(ESPChams, "ESP_Chams", "Enable", false, "ESP_Chams")
	espC(ESPChams, "ESP_ChamsFill", "Fill Color", Color3.fromRGB(255, 0, 0), "ESP_ChamsFill")
	espC(ESPChams, "ESP_ChamsOccluded", "Occluded Color", Color3.fromRGB(150, 0, 0), "ESP_ChamsOccluded")
	espC(ESPChams, "ESP_ChamsOutline", "Outline Color", Color3.fromRGB(255, 255, 255), "ESP_ChamsOutline")
	espS(ESPChams, "ESP_ChamsTransparency", "Transparency", 0.5, 0, 1, 2, "ESP_ChamsTransparency")
	espS(ESPChams, "ESP_ChamsOutlineTransparency", "Outline Transparency", 0, 0, 1, 2, "ESP_ChamsOutlineTransparency")
end

local ESPRainbow = MakeSection("ESP", "Right")
if ESPRainbow ~= nil then
	ESPRainbow:Header({ Text = "Rainbow / Effects" })

	espT(ESPRainbow, "ESP_Rainbow", "Rainbow", false, "ESP_Rainbow")
	espS(ESPRainbow, "ESP_RainbowSpeed", "Rainbow Speed", 1, 0.1, 5, 1, "ESP_RainbowSpeed")
	local function applyRainbowParts(v)
		local A = Aim()
		if A == nil then
			return
		end
		pcall(function()
			if v == "All" then
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = true
			elseif v == "Box Only" then
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = false
				A.ESP.RainbowText = false
			elseif v == "Tracers Only" then
				A.ESP.RainbowBoxes = false
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = false
			elseif v == "Text Only" then
				A.ESP.RainbowBoxes = false
				A.ESP.RainbowTracers = false
				A.ESP.RainbowText = true
			end
		end)
	end
	espD(ESPRainbow, "ESP_RainbowParts", "Rainbow Parts", { "All", "Box Only", "Tracers Only", "Text Only" }, 1, applyRainbowParts)
	syncer(function() return El.ESP_RainbowParts.Value end, function(v) applyRainbowParts(v) end)

	ESPRainbow:Button({
		Name = "Reset ESP Settings",
		Callback = function()
			local A = Aim()
			if A == nil then
				Notify("ESP Reset", "Failed: aimbot missing.")
				return
			end
			pcall(function()
				A.ESP.Enabled = false
				A.ESP.Panicked = false
				A.ESP.TeamCheck = true
				A.ESP.ShowTeam = false
				A.ESP.VisibilityCheck = false
				A.ESP.MaxDistance = 1000
				A.ESP.RefreshFPS = 144
				A.ESP.RefreshMode = "Half"
				A.ESP.FadeDistance = 500
				A.ESP.UseTeamColors = true
				A.ESP.EnemyColor = Color3.fromRGB(255, 255, 255)
				A.ESP.AllyColor = Color3.fromRGB(25, 255, 25)
				A.ESP.BoxESP = false
				A.ESP.BoxStyle = "Full"
				A.ESP.BoxOutline = true
				A.ESP.BoxFilled = false
				A.ESP.BoxFillTransparency = 0.5
				A.ESP.BoxThickness = 1
				A.ESP.BoxColor = Color3.fromRGB(255, 255, 255)
				A.ESP.TracerESP = true
				A.ESP.TracerOrigin = "Bottom"
				A.ESP.TracerThickness = 1
				A.ESP.TracerColor = Color3.fromRGB(255, 255, 255)
				A.ESP.Snaplines = false
				A.ESP.HealthESP = false
				A.ESP.HealthStyle = "Bar"
				A.ESP.HealthBarSide = "Left"
				A.ESP.HealthFormat = "Number"
				A.ESP.HealthFullColor = Color3.fromRGB(0, 255, 0)
				A.ESP.NameESP = false
				A.ESP.NameMode = "DisplayName"
				A.ESP.ShowDistance = true
				A.ESP.TextSize = 14
				A.ESP.TextFont = 2
				A.ESP.ScreenYOffset = 0
				A.ESP.NameColor = Color3.fromRGB(255, 255, 255)
				A.ESP.RainbowEnabled = false
				A.ESP.RainbowSpeed = 1
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = true
				A.ESP.ChamsEnabled = false
				A.ESP.ChamsFillColor = Color3.fromRGB(255, 0, 0)
				A.ESP.ChamsOccludedColor = Color3.fromRGB(150, 0, 0)
				A.ESP.ChamsOutlineColor = Color3.fromRGB(255, 255, 255)
				A.ESP.ChamsTransparency = 0.5
				A.ESP.ChamsOutlineTransparency = 0
				A.ESP.SkeletonESP = false
				A.ESP.SkeletonColor = Color3.fromRGB(255, 255, 255)
				A.ESP.SkeletonThickness = 1.5
				A.ESP.SkeletonTransparency = 0
			end)
			local function rT(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateState(v) end) end end
			local function rS(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateValue(v) end) end end
			local function rD(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateSelection(v) end) end end
			local function rC(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:SetColor(v) end) end end
			rT("ESP_Enabled", false)
			rT("ESP_TeamCheck", true)
			rT("ESP_ShowTeam", false)
			rT("ESP_Visibility", false)
			rT("ESP_UseTeamColors", true)
			rS("ESP_MaxDistance", 1000)
			rS("ESP_RefreshFPS", 144)
			rD("ESP_RefreshMode", "Half FPS")
			rS("ESP_FadeDistance", 500)
			rC("ESP_EnemyColor", Color3.fromRGB(255, 255, 255))
			rC("ESP_AllyColor", Color3.fromRGB(25, 255, 25))
			rT("ESP_Box", false)
			rD("ESP_BoxStyle", "Full")
			rT("ESP_BoxOutline", true)
			rT("ESP_BoxFilled", false)
			rS("ESP_BoxFillTransparency", 0.5)
			rS("ESP_BoxThickness", 1)
			rC("ESP_BoxColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_IncludeAccessories", false)
			rT("ESP_Tracer", true)
			rD("ESP_TracerOrigin", "Bottom")
			rS("ESP_TracerThickness", 1)
			rC("ESP_TracerColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_Snaplines", false)
			rT("ESP_Health", false)
			rD("ESP_HealthStyle", "Bar")
			rD("ESP_HealthSide", "Left")
			rD("ESP_HealthFormat", "Number")
			rC("ESP_HealthFullColor", Color3.fromRGB(0, 255, 0))
			rT("ESP_Name", false)
			rD("ESP_NameMode", "DisplayName")
			rT("ESP_ShowDistance", true)
			rT("ESP_DistanceFade", true)
			rS("ESP_TextSize", 14)
			rS("ESP_ScreenYOffset", 0)
			rD("ESP_TextFont", "Plex")
			rC("ESP_NameColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_Rainbow", false)
			rS("ESP_RainbowSpeed", 1)
			rD("ESP_RainbowParts", "All")
			rT("ESP_Chams", false)
			rC("ESP_ChamsFill", Color3.fromRGB(255, 0, 0))
			rC("ESP_ChamsOccluded", Color3.fromRGB(150, 0, 0))
			rC("ESP_ChamsOutline", Color3.fromRGB(255, 255, 255))
			rS("ESP_ChamsTransparency", 0.5)
			rS("ESP_ChamsOutlineTransparency", 0)
			rT("ESP_Skeleton", false)
			rC("ESP_SkeletonColor", Color3.fromRGB(255, 255, 255))
			rS("ESP_SkeletonThickness", 1.5)
			rS("ESP_SkeletonTransparency", 0)
			Notify("ESP Reset", "ESP settings reset to defaults.")
		end,
	})
end
end

BuildESPTab()

--// DEBUG TAB (throttled reads of existing public APIs only)

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

local DbgSec = MakeSection("Debug", "Left")
if DbgSec ~= nil then
	DbgSec:Header({ Text = "Target" })

	El.DbgTarget = DbgSec:Label({ Text = "Target: None" })
	El.DbgTeam = DbgSec:Label({ Text = "Team: -" })
	El.DbgFOV = DbgSec:Label({ Text = "Prediction: -" })
	El.SilentDbg = DbgSec:Label({ Text = "Silent: OFF" })
	El.SilentDbg2 = DbgSec:Label({ Text = "Fire: -" })

	El.AimbotDebugger = DbgSec:Toggle({
		Name = "Aimbot Print Debugger",
		Default = false,
		Callback = function(v) Write("Debugger", v) end,
	}, "AimbotDebugger")
	syncer(function() return El.AimbotDebugger:GetState() end, function(v) Write("Debugger", v) end)

	DbgSec:Button({
		Name = "Scan Team Sources",
		Callback = function()
			local A = Aim()
			if A ~= nil and type(A.ScanTeamSources) == "function" then
				pcall(function() A.ScanTeamSources() end)
			else
				Notify("Scan", "ScanTeamSources unavailable.")
			end
		end,
	})
end

local NetSec = MakeSection("Debug", "Right")
local NetLbl, PredLbl, ChecksLbl
if NetSec ~= nil then
	NetSec:Header({ Text = "Network" })

	NetLbl = NetSec:Label({ Text = "Ping: -" })
	PredLbl = NetSec:Label({ Text = "Screen: -" })
	ChecksLbl = NetSec:Label({ Text = "Checks: -" })
end

local function SetLabel(lbl, text)
	if lbl == nil then
		return
	end
	local ok = pcall(function() lbl:UpdateName(text) end)
	if not ok then
		pcall(function() lbl.Text = text end)
	end
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local A = Aim()
		if A == nil then
			break
		end
		local okI, info = pcall(function() return A.GetTargetInfo() end)
		local okD, diag = pcall(function() return A.GetDiagnostics() end)
		if okI and type(info) == "table" then
			local tname = info.Target or "None"
			SetLabel(El.StatusLabel, "Aimbot: " .. tostring((A.Settings.Enabled and "ON") or "OFF")
				.. " | Target: " .. tostring(tname))
			SetLabel(El.DbgTarget, "Target: " .. tostring(tname) .. "  Score " .. string.format("%.2f", info.Score or -1))
			SetLabel(El.DbgFOV, "Eff " .. string.format("%.3f", info.EffTime or 0) .. "s  Conf " .. string.format("%d%%", math.floor((info.Confidence or 0) * 100)))
			SetLabel(PredLbl, "Screen " .. string.format("%.0f", info.ScreenX or 0) .. "," .. string.format("%.0f", info.ScreenY or 0))
		end
		if okD and type(diag) == "table" then
			SetLabel(El.DbgTeam, "Team: " .. tostring(diag.TargetTeam or "-") .. " | Src " .. tostring(diag.TeamSource or "?") .. " " .. string.format("%.2f", diag.TeamConfidence or 0))
			SetLabel(NetLbl, "Ping: " .. tostring(diag.Ping or 0) .. "ms / " .. tostring(diag.SmoothedPing or 0) .. "ms  Jit " .. tostring(diag.Jitter or 0) .. "ms  " .. tostring(diag.Network or "?"))
			SetLabel(ChecksLbl, "TeamCheck:" .. tostring(diag.TeamCheck) .. " Wall:" .. tostring(diag.WallCheck) .. " Retain:" .. tostring(diag.RetainRadius or 0))
		end
		local okS, sinfo = pcall(function() return A.GetSilentInfo() end)
		if okS and type(sinfo) == "table" then
			SetLabel(El.SilentDbg, "Silent: " .. tostring(sinfo.AimMethod or "-")
				.. " | Tgt " .. tostring(sinfo.Target or "None")
				.. " " .. tostring(sinfo.Part or "-")
				.. " " .. string.format("%.0f", sinfo.ScreenDist or -1)
				.. " [" .. tostring(sinfo.Source or "?") .. "]")
			SetLabel(El.SilentDbg2, "Fire: " .. tostring(sinfo.FirePipeline or "?")
				.. " | Override: " .. tostring(sinfo.Override or "?")
				.. " | Hits: " .. tostring(sinfo.HookHits or 0)
				.. " | AW: " .. tostring(sinfo.Aimwork or "?")
				.. " | Cam: UNCHANGED")
		end
	end
end)

--// SETTINGS TAB: menu + config (MacLib native) + about

local MenuSec = MakeSection("Settings", "Left")
if MenuSec ~= nil then
	MenuSec:Header({ Text = "Menu" })
	MenuSec:Label({ Text = "Toggle: RightShift (aim pauses while open)" })

	El.MenuKey = MenuSec:Keybind({
		Name = "Menu Key",
		Default = Enum.KeyCode.RightShift,
		Callback = function() end,
		onBinded = function(bind)
			Notify("Menu Key", "Rebound to " .. tostring(bind) .. ". Note: visibility toggle stays on RightShift.")
		end,
	}, "MenuKey")

	MenuSec:Header({ Text = "Config" })
	local cfgDone = false
	if Tabs.Settings ~= nil then
		cfgDone = pcall(function()
			Tabs.Settings:InsertConfigSection("Left")
		end)
	end
	if not cfgDone then
		El.ConfigName = MenuSec:Input({
			Name = "Config Name",
			Placeholder = "default",
			AcceptedCharacters = "All",
			Callback = function() end,
		})
		MenuSec:Button({
			Name = "Save Config",
			Callback = function()
				local A = Aim()
				local name = "default"
				if El.ConfigName ~= nil then
					pcall(function()
						local t = El.ConfigName:GetInput()
						if type(t) == "string" and #t > 0 then
							name = t
						end
					end)
				end
				local ok, err = pcall(function()
					return MacLib:SaveConfig(name)
				end)
				if ok then
					PushAllToAimbot()
					Notify("Config", "Saved " .. tostring(name) .. ".")
				else
					Notify("Config", "Save failed: " .. tostring(err))
				end
			end,
		})
		MenuSec:Button({
			Name = "Load Config",
			Callback = function()
				local name = "default"
				if El.ConfigName ~= nil then
					pcall(function()
						local t = El.ConfigName:GetInput()
						if type(t) == "string" and #t > 0 then
							name = t
						end
					end)
				end
				local ok, err = pcall(function()
					return MacLib:LoadConfig(name)
				end)
				if ok then
					PushAllToAimbot()
					Notify("Config", "Loaded " .. tostring(name) .. ".")
				else
					Notify("Config", "Load failed: " .. tostring(err))
				end
			end,
		})
	end
end

local AboutSec = MakeSection("Settings", "Right")
if AboutSec ~= nil then
	AboutSec:Header({ Text = "About" })
	AboutSec:Paragraph({
		Header = "Universery + MacLib",
		Body = "Aimbot starts OFF. Enable it in the Aimbot tab. Hold the Aim Key to aim. RightShift toggles this UI.",
	})
end

-- Apply current UI state once at startup so visuals match the aimbot.
PushAllToAimbot()
print("[AimbotUI] UI build done. Sections: " .. tostring(SectionCount))
print("[AimbotUI] build: maclib-espv6 (m2a-modular)")

Notify("Aimbot UI", "MacLib UI loaded. Aimbot starts OFF; enable it in Aimbot.")
end -- UI build scope
