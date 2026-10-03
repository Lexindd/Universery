getgenv().ExunysDeveloperAimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1, -- Bigger = Slower
		DisableWarnings = false,
		DiagnosticPrints = true, -- Boot/step logs via print. Set false to silence.
		AutoStart = true -- Load() otomatik çağrılır; dosyayı çalıştırman yeterli.
	},

	Settings = {
		Enabled = true,

		TeamCheck = true, -- Same-team players are never targeted. Nil-safe (see IsTeammate).
		UseTeamColorFallback = true, -- If Team objects are unusable, fall back to TeamColor comparison.
		IncludeNeutralPlayers = true, -- Players with no team are valid targets when true.
		FriendCheck = true, -- Roblox friends are skipped (one-time async friend list, cached).
		AliveCheck = true,
		WallCheck = true, -- Visibility gate (cached raycasts, see Performance.VisibilityTTL).

		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		Sensitivity = 0, -- Base lock-on time (seconds). 0 = instant. Still respected; adaptive layer scales it.
		Sensitivity2 = 1, -- mousemoverel Sensitivity

		LockMode = 1, -- 1 = CFrame; 2 = mousemoverel; 3 = mousemoveabs
		LockPart = "Head", -- Used when PartMode = "Static".
		PartMode = "Static", -- Static | PriorityList | ClosestToCursor | ClosestVisible
		TargetParts = { "Head", "UpperTorso", "LowerTorso", "Torso", "HumanoidRootPart" },
		MaxDistance = 1000, -- World studs. Beyond this, targets are rejected before scoring.
		StrictVisibility = true, -- true = obstructed targets rejected; false = only scored lower.

		PriorityMode = "Score", -- Score | ClosestToCursor | ClosestDistance | LowestHealth | Priority
		SwitchThreshold = 0.12, -- New target must beat current by this much to steal the lock.
		TargetStickiness = 0.5, -- Persistence bonus (0-1) added to the locked target's score.
		TargetGracePeriod = 0.1, -- Grace for LIVE targets only (brief occlusion/FOV exit). 0 = off. Conservative by design.
		LockRetentionRadius = 30, -- px floor for lock retention. The live retention radius is
		                          -- acquisition-anchored (original Exunys semantics) but NEVER the full
		                          -- acquisition FOV by default. See LockMeta.RetainRadius.
		PositionSanityCheck = true, -- Secondary net: impossible single-frame jumps invalidate (relative, no world-Y hardcode).
		MaxTargetDisplacement = 400, -- studs/sec allowance (+5 base). Only impossible movement trips it.
		MaxVerticalDisplacement = 300, -- studs/sec vertical allowance (+5 base).

		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false,
		IgnoreGameKeyConflicts = false, -- Conflict protection master switch (default OFF = legacy behavior).
	},

	Scoring = {
		FOVWeight = 3,
		DistanceWeight = 1,
		VisibilityWeight = 1.5,
		HealthWeight = 0, -- 0 = off. Raise to prefer low-health targets.
		PriorityWeight = 2,
		PersistenceWeight = 1
	},

	Prediction = {
		Adaptive = true,
		Base = 0.12, -- Legacy fixed prediction time. Used when PingPrediction is OFF/unavailable, or when Adaptive = false.
		Min = 0,
		Max = 0.3,
		VelocityInfluence = 0.35, -- Legacy velocity-based path only.
		DistanceInfluence = 0.25, -- Legacy velocity-based path only.
		AccelerationInfluence = 0.15, -- Legacy velocity-based path only.
		VelocitySmoothing = true, -- EMA-smoothed velocity feeds prediction (less noisy than raw average).
		VelocityAlpha = 0.35,
		ConfidenceStrength = 0.6 -- Prediction scales with (1-strength) + strength*confidence.
	},

	Network = {
		PingPrediction = true, -- Master switch. OFF = legacy velocity-only prediction paths.
		PingMultiplier = 1.0, -- User tune for effective latency (0.5 / 0.75 / 1.0 / 1.25 / 1.5 ...).
		PingSmoothing = true, -- EMA instead of raw ping. False = follow raw ping (not recommended).
		PingAlpha = 0.1, -- EMA alpha. Lower = slower, more stable.
		PingHistory = 20, -- Bounded rolling buffer size (min/max/jitter source).
		PingUpdateRate = 0.25, -- Ping sampling interval (seconds). Low frequency by design.
		MinLatency = 0.02, -- Clamp: one-way latency floor (seconds).
		MaxLatency = 0.3, -- Clamp: one-way latency ceiling (seconds).
		JitterCompensation = true, -- High jitter -> lower confidence + calmer prediction.
		JitterStrength = 0.5,
		DistanceCompensation = true, -- Far targets get a small extra lead (latency stays primary).
		DistanceStrength = 1.0,
		AutoCalibration = true, -- Slow self-correction of overshoot/undershoot bias.
		CalibrationStrength = 1.0,
		CalibrationRate = 0.05, -- Learning rate (kept slow on purpose).
		CalibrationMin = 0.5, -- Hard clamp on the auto correction multiplier.
		CalibrationMax = 1.5,
		ErrorSamples = 10 -- Rolling error buffer size.
	},

	Smoothing = {
		Adaptive = true,
		Min = 0.08, -- Minimum lerp factor per frame.
		Max = 0.9, -- Maximum lerp factor per frame.
		ErrorInfluence = 0.6,
		DistanceInfluence = 0.2,
		VelocityInfluence = 0.3,
		StabilityInfluence = 0.4
	},

	Performance = {
		TargetScanRate = 0.12, -- Full candidate scan interval (seconds).
		VisibilityTTL = 0.15, -- Visibility cache lifetime (seconds).
		VelocitySamples = 5, -- Rolling velocity history length.
		PlayerReconcile = 2 -- Player cache reconcile interval (seconds).
	},

	Debugger = {
		Enabled = false,
		Rate = 0.5 -- Throttled debug print interval (seconds). Never spams per frame.
	},

	ESP = {
		Enabled = false,
		Panicked = false, -- set by Panic(); cleared when the Enable toggle is used.
		TeamCheck = true, -- teammates hidden (via Universal Team Resolver) unless ShowTeam.
		ShowTeam = false,
		VisibilityCheck = false, -- occluded players hidden (chams still show occluded color).
		MaxDistance = 1000,
		RefreshFPS = 144, -- target refresh; auto-lowers if FPS collapses (min ~20fps).
		RefreshMode = "Half", -- Fixed | Half | Full: ESP rate follows render FPS (Half = fps/2).
		UseTeamColors = true, -- true = team colors; false = per-category colors below.
		EnemyColor = Color3.fromRGB(255, 255, 255),
		AllyColor = Color3.fromRGB(25, 255, 25),
		BoxESP = false,
		BoxStyle = "Full", -- Corner | Full | ThreeD
		BoxOutline = true,
		BoxFilled = false,
		BoxFillTransparency = 0.5,
		BoxThickness = 1,
		BoxColor = Color3.fromRGB(255, 255, 255),
		IncludeAccessories = false, -- hats/hair/tools stay out of box bounds unless ON.
		TracerESP = true,
		TracerOrigin = "Bottom", -- Bottom | Top | Mouse | Center
		TracerThickness = 1,
		TracerColor = Color3.fromRGB(255, 255, 255),
		Snaplines = false, -- second bottom-center line (Straight, like the reference).
		HealthESP = false,
		HealthStyle = "Bar", -- Bar | Text | Both
		HealthBarSide = "Left", -- Left | Right
		HealthFormat = "Number", -- Number | Percentage | Both
		HealthTextSuffix = "HP",
		HealthFullColor = Color3.fromRGB(0, 255, 0), -- full-HP endpoint of the dynamic gradient.
		NameESP = false,
		NameMode = "DisplayName", -- DisplayName | Username
		NameColor = Color3.fromRGB(255, 255, 255),
		ShowDistance = true,
		DistanceFade = true, -- fade box+tracer transparency with distance instead of distance text (max 0.9, never invisible).
		FadeDistance = 500, -- studs at which fade reaches max (0.9); linear below it.
		TextSize = 14,
		TextFont = 2, -- 0 UI, 1 System, 2 Plex, 3 Monospace
		ScreenYOffset = 0, -- fine-tune around the calibrated base (0 = aligned).
		RainbowEnabled = false,
		RainbowSpeed = 1,
		RainbowBoxes = true,
		RainbowTracers = true,
		RainbowText = true,
		ChamsEnabled = false,
		ChamsFillColor = Color3.fromRGB(255, 0, 0),
		ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
		ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
		ChamsTransparency = 0.5,
		ChamsOutlineTransparency = 0,
		SkeletonESP = false,
		SkeletonColor = Color3.fromRGB(255, 255, 255),
		SkeletonThickness = 1.5,
		SkeletonTransparency = 0
	},

	SilentAim = {
		Enabled = false,
		EnabledKey = Enum.UserInputType.MouseButton2,
		KeyMode = "Hold", -- Hold | Toggle
		FOV = 150,
		ShowFOV = true,
		FOVColor = Color3.fromRGB(255, 255, 255),
		FOVThickness = 1,
		FOVTransparency = 0,
		FOVFilled = false,
		FOVFillTransparency = 0.5,
		FOVOutline = true,
		FOVOutlineColor = Color3.fromRGB(0, 0, 0),
		FOVOutlineThickness = 2, -- outline radius padding + added line thickness
		FOVOrigin = "Mouse", -- Mouse | Screen Center
		TargetPart = "Head", -- Head | HumanoidRootPart | UpperTorso | LowerTorso | Random | Closest Part
		AimMode = "Closest To Mouse", -- Closest To Mouse | Closest Distance
		TeamCheck = true,
		VisibilityCheck = false,
		MaxDistance = 1000,
		Prediction = true,
		PredictionStrength = 1, -- 0..2 multiplier on velocity * time
		StickyTarget = true,
		TargetSwitchDelay = 0.25, -- seconds to wait before acquiring a DIFFERENT target
		IncludeDeadTargets = false,
		GameKeyConflictProtection = false,
		UseCameraHook = true, -- master switch for the camera-read hook (resolver works without it)
		Applier = nil, -- fn(targetPos, aimCFrame): game-specific aim applier (dot-call). Nil = Unsupported.
	},

	PriorityPlayers = {}, -- Array of exact player Names that receive a priority score multiplier.

	TeamResolver = {
		Mode = "Auto", -- Auto | Native | Attributes | Values | Tags | GameAdapter | Manual | Disabled
		ManualAttribute = "", -- e.g. "Faction": player:GetAttribute("Faction") becomes authoritative.
		ManualValuePath = "", -- e.g. "Data.Team" (from Player) or "Character.Stats.Side" (from character).
		UnknownBehavior = "Ignore", -- UNKNOWN target: "Ignore" (strict, skip) or "Target" (permissive).
		NormalizeCase = true, -- "Red" == "red". Disable if case carries meaning in your game.
		IgnoreSpectators = true, -- Spectator/Lobby/Waiting states are never treated as enemies.
		SpectatorNames = { "Spectator", "Spectators", "Lobby", "Waiting", "Dead", "Observer", "Observers", "AFK", "Queue" },
		UseVisualDetection = false, -- Unreliable by design; resolver returns Unknown for visuals.
		ExperimentalDetection = false, -- Billboard/OCR-style sources. Never primary; off by default.
		ConfidenceThreshold = 0.6, -- Auto-detected sources below this are not used.
		CacheTTL = 1.0, -- Per-player team cache lifetime (seconds).
		ReanalyzeRate = 5.0 -- Cross-player consistency re-analysis interval (seconds).
	},

	-- Optional game-specific adapter. Shape:
	--   GameAdapter = { GetTeam = function(player) return { TeamId = "Red", TeamName = "Red", TeamColor = Color3.fromRGB(255,0,0) } end }
	-- Return nil / {} when unknown. Never hardcode game paths in the generic resolver.
	GameAdapter = nil,

	Triggerbot = {
		Enabled = false,

		TeamCheck = true,
		AliveCheck = true,
		AimLockedCheck = false,

		Delay = 0, -- Time it takes for the trigger bot to react / click (seconds).
		Cooldown = 0.25 -- Minimum seconds between clicks (debounce; prevents click storms).
	},

	ClosestPlayerTracer = {
		Enabled = true,
		Position = 3, -- 1 = Bottom; 2 = Center; 3 = Mouse

		Transparency = 0.5,
		Thickness = 1,

		RainbowColor = false,
		Color = Color3fromRGB(150, 150, 255)
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,

		Radius = 180,
		NumSides = 60,

		Thickness = 1,
		Transparency = 1,
		Filled = false,

		DynamicFOV = false, -- Closer target = smaller effective FOV, farther = larger (clamped).
		DynamicMin = 0.7,
		DynamicMax = 1.3,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150),
		ShowLockRadius = false, -- Second visual ring for the SMALL lock-retention radius (debug aid).
		LockRadiusColor = Color3fromRGB(255, 150, 150)
	},

	Blacklisted = {},
	FOVCircleOutline = Drawingnew("Circle"),
	FOVCircle = Drawingnew("Circle"),
	LockRadiusCircle = Drawingnew("Circle"),
	Tracer = Drawingnew("Line")
}

local Environment, _warn = getgenv().ExunysDeveloperAimbot, clonefunction(warn); warn = function(...)
	return not Environment.DeveloperSettings.DisableWarnings and _warn(...)
end

repeat
	taskwait(0)
until Environment and Environment.FOVCircle and Environment.FOVCircleOutline

setrenderproperty(Environment.FOVCircle, "Visible", false)
setrenderproperty(Environment.FOVCircleOutline, "Visible", false)
setrenderproperty(Environment.LockRadiusCircle, "Visible", false)

