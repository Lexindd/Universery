-- Features/SilentAim/AimworkAdapter.lua — Aimwork API -> Universery API.
-- NEVER touches Aimwork internals beyond its documented surface:
--   Aimwork.new(config) -> instance; instance:Iterate();
--   instance.selected {player, part, position, distance};
--   instance:RegisterCustomFov(obj); instance:Destroy().
-- Upstream stays verbatim under Libraries/Aimwork/upstream/.
-- Normalized target: {Player, Part, PartName, Position, Distance} | nil.
-- Team filtering is INTENTIONALLY left to Universery post-validation
-- (Aimwork only sees native teams; custom games would wipe out everyone).

local Universery = Require("registry")
Universery.AimworkAdapter = Universery.AimworkAdapter or {}
local A = Universery.AimworkAdapter

A._class = nil
A._instance = nil
A._state = "NOT INSTALLED"
A._detail = "Libraries/Aimwork source not present"
A._cooldownUntil = 0

local fovOrigin = nil
local fovRadius = 150

local headless = {
	id = "UniverserySilentFOV",
	Destroy = function() end,
	Update = function() end,
	InsideFOV = function(_, screenPos)
		local o = fovOrigin
		if o == nil or screenPos == nil then
			return false, nil
		end
		local r = fovRadius or 150
		local d = (Vector2.new(screenPos.X, screenPos.Y) - o).Magnitude
		if d > r then
			return false, nil
		end
		return true, d
	end,
}

local function defaultRaycastIgnore(player, camera)
	local ignored = { camera }
	if player ~= nil and player.character ~= nil then
		table.insert(ignored, player.character)
	end
	return ignored
end

function A.IsReady()
	return A._state == "READY" and A._instance ~= nil
end

function A.State()
	return A._state, A._detail
end

function A.SetFOV(origin, radius)
	fovOrigin = origin
	if type(radius) == "number" then
		fovRadius = radius
	end
end

function A.BuildConfig(S)
	local dead = true
	if S ~= nil and S.IncludeDeadTargets then
		dead = false
	end
	local wall = false
	if S ~= nil and S.VisibilityCheck then
		wall = "Full"
	end
	local pfType, pfName = "Blocklist", {}
	local mode = S ~= nil and S.TargetPart or "Head"
	if mode == "Head" or mode == "HumanoidRootPart" or mode == "UpperTorso" or mode == "LowerTorso" then
		pfType = "Allowlist"
		pfName = { [mode] = true }
	end
	return {
		TargetLock = { Enabled = false, LockOnly = false, Mode = "Lock", Bind = Enum.KeyCode.F1 },
		Checks = {
			ForceField = true,
			Friend = false,
			Dead = dead,
			Invisible = true,
			Ignored = false,
			WallCheck = wall,
		},
		PartFilter = { Type = pfType, Name = pfName },
		Ignored = {
			IgnoreLocalTeam = false,
			AllowlistEnabledFor = { Teams = false, Players = false },
			Teams = {},
			Players = {},
		},
		RaycastIgnore = defaultRaycastIgnore,
	}
end

function A.SyncSettings(S)
	if A._instance == nil or A._instance.settings == nil then
		return false
	end
	local ok = pcall(function()
		local cfg = A.BuildConfig(S)
		local cur = A._instance.settings
		cur.TargetLock.Enabled = false
		cur.TargetLock.LockOnly = false
		cur.Checks.ForceField = cfg.Checks.ForceField
		cur.Checks.Friend = cfg.Checks.Friend
		cur.Checks.Dead = cfg.Checks.Dead
		cur.Checks.Invisible = cfg.Checks.Invisible
		cur.Checks.Ignored = cfg.Checks.Ignored
		cur.Checks.WallCheck = cfg.Checks.WallCheck
		cur.PartFilter = cfg.PartFilter
	end)
	return ok
end

function A.Ensure(S)
	if A.IsReady() then
		return true
	end
	if tick() < (A._cooldownUntil or 0) then
		return false
	end
	local loader = Universery.AimworkLoad
	if loader == nil then
		A._state = "ERROR"
		A._detail = "aimwork loader missing from dist"
		A._cooldownUntil = tick() + 5
		return false
	end
	local okC, class = pcall(function() return loader.Load("aimwork") end)
	if not okC or type(class) ~= "table" or type(class.new) ~= "function" then
		A._state = "NOT COMPATIBLE"
		A._detail = "aimwork source failed to load (executor parse?)"
		A._cooldownUntil = tick() + 5
		return false
	end
	A._class = class
	local okN, inst = pcall(function() return class.new(A.BuildConfig(S)) end)
	if not okN or inst == nil then
		A._state = "ERROR"
		A._detail = "Aimwork.new failed"
		A._cooldownUntil = tick() + 5
		return false
	end
	A._instance = inst
	local okR = pcall(function() return inst:RegisterCustomFov(headless) end)
	if not okR then
		pcall(function()
			inst.visuals.objects[headless] = { update = false, check = true }
		end)
	end
	A._state = "READY"
	A._detail = "running (headless FOV, manual iterate)"
	return true
end

function A.Update()
	if not A.IsReady() then
		return false
	end
	local ok = pcall(function() return A._instance:Iterate() end)
	return ok
end

function A.GetTarget()
	if not A.IsReady() then
		return nil
	end
	local sel = nil
	pcall(function() sel = A._instance.selected end)
	if type(sel) ~= "table" then
		return nil
	end
	local pl, pt = nil, nil
	pcall(function() pl = sel.player end)
	pcall(function() pt = sel.part end)
	if pl == nil or pt == nil then
		return nil
	end
	local isLocal = false
	pcall(function()
		local lp = game:GetService("Players").LocalPlayer
		isLocal = (pl == lp)
	end)
	if isLocal then
		return nil
	end
	local pos, pname, sdist = nil, nil, nil
	pcall(function() pos = pt.Position end)
	pcall(function() pname = pt.Name end)
	pcall(function() sdist = sel.distance end)
	if pos == nil then
		return nil
	end
	return { Player = pl, Part = pt, PartName = pname, Position = pos, Distance = sdist }
end

function A.Teardown()
	if A._instance ~= nil then
		pcall(function() return A._instance:Destroy() end)
		A._instance = nil
	end
	if A._state == "READY" then
		A._state = "BOUND"
		A._detail = "stopped"
	end
end

return Universery.AimworkAdapter
