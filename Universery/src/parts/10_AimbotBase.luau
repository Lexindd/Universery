local function BuildAimbot()
--// Luraph Macros

if LPH_OBFUSCATED == nil then -- Must wrap in an "if" statement: "The macro 'LPH_NO_VIRTUALIZE' cannot be assigned to. Check if LPH_OBFUSCATED is nil before assigning to macros."
	LPH_NO_VIRTUALIZE = function(...)
		return ...
	end
end

--// Cache

local game, workspace = game, workspace
local getrawmetatable, pcall, next, tick, getgenv = getrawmetatable, pcall, next, tick, getgenv
local Vector2new, Vector3zero, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing and Drawing.new, TweenInfo.new
local mousemoverel, mousemoveabs, tablefind, tableremove, stringlower, stringsub, mathclamp = mousemoverel or (Input and Input.MouseMove), mousemoveabs, table.find, table.remove, string.lower, string.sub, math.clamp
local mouse1press, mouse1release, taskwait = mouse1press, mouse1release, task.wait
local mathfloor, mathhuge, mathabs, mathexp, osclock = math.floor, math.huge, math.abs, math.exp, os.clock
local clonefunction, cloneref = clonefunction or LPH_NO_VIRTUALIZE(function(...)
	return ...
end), cloneref or LPH_NO_VIRTUALIZE(function(...)
	return ...
end)

--// Boot Diagnostics (print-based; silence via DeveloperSettings.DiagnosticPrints = false)

local function dprint(...)
	local show = true
	pcall(function()
		local g = getgenv()
		if g ~= nil and g.ExunysDeveloperAimbot ~= nil and g.ExunysDeveloperAimbot.DeveloperSettings ~= nil then
			if g.ExunysDeveloperAimbot.DeveloperSettings.DiagnosticPrints == false then
				show = false
			end
		end
	end)
	if show then
		print("[Aimbot][Diag]", ...)
	end
end

local DrawingAvailable = type(Drawing) == "table" and type(Drawing.new) == "function"
dprint("Drawing:", DrawingAvailable and "OK" or "MISSING - circles/tracer stubbed, aim logic still runs")
if not DrawingAvailable then
	Drawingnew = function(_kind)
		local stub = {}
		stub.Remove = function() end
		return stub
	end
end

local GameMetatable = getrawmetatable and getrawmetatable(game) or {
	-- Auxillary functions - if the executor doesn't support "getrawmetatable".

	__index = LPH_NO_VIRTUALIZE(function(self, Index)
		return self[Index]
	end),

	__newindex = LPH_NO_VIRTUALIZE(function(self, Index, Value)
		self[Index] = Value
	end)
}

local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex

local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex

local _GetService = __index(game, "GetService")
local GetService = function(Service)
	return cloneref(_GetService(game, Service))
end

--// Services

local RunService = GetService("RunService")
local UserInputService = GetService("UserInputService")
local TweenService = GetService("TweenService")
local Players = GetService("Players")

--// Service Methods

local LocalPlayer = __index(Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")

do
	local tries = 0
	while Camera == nil and tries < 100 do
		taskwait(0.1)
		tries = tries + 1
		pcall(function() Camera = __index(workspace, "CurrentCamera") end)
	end
end
dprint("LocalPlayer:", (LocalPlayer ~= nil and __index(LocalPlayer, "Name")) or "NIL")
dprint("Camera:", Camera ~= nil and "OK" or "NIL")
dprint("mouse1press/mouse1release:", type(mouse1press), type(mouse1release))
dprint("mousemoverel/mousemoveabs:", type(mousemoverel), type(mousemoveabs))
if LocalPlayer == nil then
	error("[Aimbot] LocalPlayer is nil - run this after spawning (not in Studio command bar).")
end
if Camera == nil then
	error("[Aimbot] CurrentCamera is nil - open a game world first, then re-execute.")
end

local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
local GetDescendants = __index(game, "GetDescendants")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
local GetPlayers = __index(Players, "GetPlayers")
local GetPlayerFromCharacter = __index(Players, "GetPlayerFromCharacter")
local Mouse = __index(LocalPlayer, "GetMouse")(LocalPlayer)
local CameraViewportSize = __index(Camera, "ViewportSize")

--// Variables

local RequiredDistance, Required3DDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, 10000, false, false, {}, nil, nil
local Connect, Disconnect = __index(game, "DescendantAdded").Connect

do
	local TemporaryConnection = Connect(__index(game, "DescendantAdded"), function() end)
	Disconnect = TemporaryConnection.Disconnect
	Disconnect(TemporaryConnection)
end

--// Upgrade Caches (scheduler / hysteresis / prediction state)

local PlayerCache, PlayerCacheTime = {}, 0
local VisibilityCache = {}
local FriendSet, FriendSetTime, FriendAPIUnavailable = {}, 0, false
local VelocityState = { Samples = {}, AvgVelocity = Vector3zero, SmoothVel = nil, Acceleration = Vector3zero, Confidence = 0, LastPos = nil, LastTime = 0, Stable = true }
-- Network stats belong to the connection, NOT the target: never cleared on target change.
local PingState = { Raw = 0, Smoothed = 0, Min = 0, Max = 0, Jitter = 0, Samples = {}, Quality = "Unknown", Correction = 1, ErrBuf = {}, LastPred = nil, Effective = 0, LastUpdate = 0, LastCalib = 0, Available = false }
local ScanState = { Time = 0, Best = nil, BestScore = -1, Results = {} }
local LockMeta = { Since = 0, LastSeen = 0, LastScore = -1 }
local LastAimData = { SX = 0, SY = 0, PX = 0, PY = 0, PZ = 0, Method = "Camera" }
local LastBreakdown = { FOV = 0, Distance = 0, Visibility = 0, Health = 0, Priority = 0 }
local DebugLastPrint = 0
local TriggerBusy, TriggerLastClick = false, 0

-- Input Conflict Protection (Game Key Conflict Protection).
-- Decides whether the aim key is ALSO consumed by the game, WITHOUT sinking
-- input and WITHOUT hardcoded game assumptions:
--   1. Static: ContextActionService CAS bindings containing the aim key
--      (reliable: real bound actions, e.g. a game's Scope action on RMB).
--   2. Dynamic: scope-zoom signature - Camera FOV collapsing right after the
--      aim key is pressed (heuristic for UserInputService-driven game code).
-- HONEST LIMIT: games reading raw input with no CAS binding and no FOV change
-- cannot be detected; then this system stays silent (no false certainty).
local ConflictState = { StaticMap = nil, StaticScanned = false, StaticTime = 0, BaseFov = 0, PressTime = 0, Latched = false, Kind = "NONE", Detail = "", Suppressed = false, SuppressedKey = nil }

local InputConflictController = {}
InputConflictController.StaticTTL = 5

local function RefreshStaticBindings()
	local now = tick()
	if ConflictState.StaticScanned and (now - ConflictState.StaticTime) < InputConflictController.StaticTTL then
		return
	end
	ConflictState.StaticScanned = true
	ConflictState.StaticTime = now
	ConflictState.StaticMap = nil
	local okC, cas = pcall(function() return GetService("ContextActionService") end)
	if not okC or cas == nil then
		return
	end
	local okB, bound = pcall(function() return __index(cas, "GetAllBoundActionInfo")(cas) end)
	if not okB or type(bound) ~= "table" then
		return
	end
	ConflictState.StaticMap = bound
end

local function FindStaticConflict(aimKey)
	RefreshStaticBindings()
	local bound = ConflictState.StaticMap
	if type(bound) ~= "table" or aimKey == nil then
		return nil
	end
	for actionName, info in next, bound do
		if type(info) == "table" and type(info.inputTypes) == "table" then
			for _, it in next, info.inputTypes do
				if it == aimKey then
					return tostring(actionName)
				end
			end
		end
	end
	return nil
end

function InputConflictController:OnPressAccepted()
	local okF, fov = pcall(function() return __index(Camera, "FieldOfView") end)
	ConflictState.BaseFov = (okF and type(fov) == "number") and fov or 0
	ConflictState.PressTime = tick()
	ConflictState.Latched = false
	ConflictState.Kind = "NONE"
	ConflictState.Detail = ""
end

function InputConflictController:ReleaseLatch()
	ConflictState.Latched = false
	ConflictState.Kind = "NONE"
	ConflictState.Detail = ""
end

function InputConflictController:ReleaseSuppression()
	if not ConflictState.Suppressed then
		ConflictState.SuppressedKey = nil
		return
	end
	pcall(function()
		local cas = GetService("ContextActionService")
		__index(cas, "UnbindAction")(cas, "UniverseryAimbotKey")
	end)
	ConflictState.Suppressed = false
	ConflictState.SuppressedKey = nil
end

-- Takeover: suppress the conflicting game CAS binding with a High-priority
-- sink while (and only while) protection is ON and the aimbot is enabled.
-- Reversible by design: unbinding restores the game binding untouched.
-- Non-CAS game input cannot be suppressed by anyone; it simply coexists.
function InputConflictController:EnsureSuppressed()
	if Environment == nil then
		return
	end
	local Settings = Environment.Settings
	local aimKey = Settings.TriggerKey
	local keyStr = (typeof(aimKey) == "EnumItem") and tostring(aimKey) or ""
	local action = nil
	if keyStr ~= "" then
		action = FindStaticConflict(aimKey)
	end
	if action ~= nil then
		if not ConflictState.Suppressed or ConflictState.SuppressedKey ~= keyStr then
			self:ReleaseSuppression()
			local okC, cas = pcall(function() return GetService("ContextActionService") end)
			if okC and cas ~= nil then
				local okB = pcall(function()
					__index(cas, "BindActionAtPriority")(cas, "UniverseryAimbotKey", function()
						return Enum.ContextActionResult.Sink
					end, false, 3000, aimKey)
				end)
				if okB then
					ConflictState.Suppressed = true
					ConflictState.SuppressedKey = keyStr
				end
			end
		end
	else
		self:ReleaseSuppression()
	end
end

function InputConflictController:EnsureReleased()
	if ConflictState.Suppressed then
		self:ReleaseSuppression()
	end
end

-- Returns kind ("NONE"|"CAS"|"SCOPE") + detail. Never errors. Cheap: cached
-- static map, two property reads for the dynamic check.
function InputConflictController:Evaluate(keyOverride, protectionOverride)
	if Environment == nil then
		return "NONE", ""
	end
	local Settings = Environment.Settings
	local protect = protectionOverride
	if protect == nil then
		protect = Settings.IgnoreGameKeyConflicts
	end
	if not protect then
		return "NONE", ""
	end
	local aimKey = keyOverride or Settings.TriggerKey
	local action = FindStaticConflict(aimKey)
	if action ~= nil then
		ConflictState.Kind = "CAS"
		ConflictState.Detail = action
		return "CAS", action
	end
	if ConflictState.Latched then
		return "SCOPE", ConflictState.Detail
	end
	local dt = tick() - (ConflictState.PressTime or 0)
	if dt >= 0 and dt < 1.5 and (ConflictState.BaseFov or 0) > 0 then
		local okF, fov = pcall(function() return __index(Camera, "FieldOfView") end)
		if okF and type(fov) == "number" then
			if (ConflictState.BaseFov - fov) >= 12 then
				ConflictState.Latched = true
				ConflictState.Kind = "SCOPE"
				ConflictState.Detail = "FOV " .. tostring(mathfloor(ConflictState.BaseFov)) .. "->" .. tostring(mathfloor(fov))
				return "SCOPE", ConflictState.Detail
			end
		end
	end
	ConflictState.Kind = "NONE"
	ConflictState.Detail = ""
	return "NONE", ""
end

--// Environment

dprint("getgenv:", type(getgenv), "getrawmetatable:", type(getrawmetatable))
if type(getgenv) ~= "function" then
	error("[Aimbot] getgenv() is missing - this script needs an executor with getgenv support.")
end

-- Eski bir örnek zaten çalışıyorsa (tekrar çalıştırma), önce onu temizleyebilelim.
local PreviousInstance = getgenv().ExunysDeveloperAimbot

