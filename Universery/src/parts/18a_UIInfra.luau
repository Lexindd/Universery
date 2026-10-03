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
		elseif path == "SilentAim.FOVOutline" then A.SilentAim.FOVOutline = value
		elseif path == "SilentAim.FOVOutlineColor" then A.SilentAim.FOVOutlineColor = value
		elseif path == "SilentAim.FOVOutlineThickness" then A.SilentAim.FOVOutlineThickness = value
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

