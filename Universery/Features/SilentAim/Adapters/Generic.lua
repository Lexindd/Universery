-- Features/SilentAim/Adapters/Generic.lua — Generic fire adapter (camera-read hook).
-- Universal ONLY: serves aim-oriented values to Lua weapon code while the
-- C++ renderer keeps showing the real view (zero visual movement possible).
-- Game-specific adapters live in sibling Registry (isolated, PlaceId-keyed).
-- Interface (called via Facade):
--   Probe() IsHooked() Engage() Release() Uninstall()
--   SetAim(pos, cf, org) SetCamera(cam) SetOverride(on) IsOverriding()
--   Hits() Reads() Info()
-- Read detection (Mouse.Hit/Target/UnitRay) is COUNT-ONLY: values are never
-- altered (spoofing ban upheld); it exists to identify the game's aim source.

local Universery = Require("registry")
Universery.SilentGeneric = Universery.SilentGeneric or {}
local F = Universery.SilentGeneric
local LPH = LPH_NO_VIRTUALIZE or function(f) return f end

F._hooked = false
F._hits = 0
F._error = ""
F._how = "none"
F._cam = nil
F._override = false
F._pos = nil
F._cf = nil
F._org = nil
F._raw = nil
F._probed = false
F._avail = false
F._mouse = nil
F._reads = {}

function F.Probe()
	if F._probed then
		return F._avail
	end
	F._probed = true
	if type(hookmetamethod) == "function" then
		F._avail = true
		F._how = "hookmetamethod"
	elseif type(getrawmetatable) == "function" and type(setreadonly) == "function" then
		F._avail = true
		F._how = "metatable"
	else
		F._avail = false
		F._how = "none"
		F._error = "Executor lacks hookmetamethod/setreadonly"
	end
	return F._avail
end

function F.HookFn(self, key)
	if self == F._cam and F._override then
		if key == "CFrame" then
			local cf = F._cf
			if cf ~= nil then
				F._hits = F._hits + 1
				return cf
			end
		elseif key == "ScreenPointToRay" or key == "ViewportPointToRay" then
			-- Modern API returns a Ray; served target-directed (unit length).
			local tgt = F._pos
			local org = F._org
			if tgt ~= nil and org ~= nil then
				F._hits = F._hits + 1
				return function(_, x, y, depth)
					local d = tgt - org
					local m = d.Magnitude
					if m < 0.001 then
						d = Vector3.new(0, 0, -1)
						m = 1
					end
					return Ray.new(org, d / m)
				end
			end
		elseif key == "GetRenderCFrame" then
			local cf = F._cf
			if cf ~= nil then
				F._hits = F._hits + 1
				return function() return cf end
			end
		end
	end
	if F._mouse ~= nil and self == F._mouse and (key == "Hit" or key == "Target" or key == "UnitRay") then
		F._reads[key] = (F._reads[key] or 0) + 1
	end
	return F._raw(self, key)
end

function F.Engage()
	if F._hooked then
		return true
	end
	if not F.Probe() then
		return false
	end
	local ok = false
	pcall(function()
		local wrap = LPH
		pcall(function()
			if type(newcclosure) == "function" then
				wrap = newcclosure
			end
		end)
		if F._how == "hookmetamethod" then
			F._raw = hookmetamethod(game, "__index", wrap(F.HookFn))
			ok = F._raw ~= nil
		else
			local mt = getrawmetatable(game)
			F._raw = mt.__index
			setreadonly(mt, false)
			mt.__index = wrap(F.HookFn)
			setreadonly(mt, true)
			ok = true
		end
		if ok then
			local okT = pcall(function() return game.PlaceId end)
			ok = okT
		end
	end)
	if not ok then
		F._error = "Hook install failed"
		pcall(function() F.Uninstall() end)
		return false
	end
	F._hooked = true
	return true
end

function F.Release()
	F._override = false
end

function F.Uninstall()
	if F._hooked then
		pcall(function()
			if F._how == "hookmetamethod" then
				hookmetamethod(game, "__index", F._raw)
			else
				local mt = getrawmetatable(game)
				setreadonly(mt, false)
				mt.__index = F._raw
				setreadonly(mt, true)
			end
		end)
		F._hooked = false
	end
	F._override = false
end

function F.IsHooked()
	return F._hooked and true or false
end

function F.IsOverriding()
	return (F._hooked and F._override) and true or false
end

function F.SetAim(pos, cf, org)
	F._pos = pos
	F._cf = cf
	F._org = org
end

function F.ClearAim()
	F._pos = nil
	F._cf = nil
	F._org = nil
	F._override = false
end

function F.SetCamera(cam)
	F._cam = cam
	pcall(function()
		local plrs = game:GetService("Players")
		local lp = plrs.LocalPlayer
		if lp ~= nil then
			F._mouse = lp:GetMouse()
		end
	end)
end

function F.SetOverride(on)
	F._override = (on == true)
end

function F.Hits()
	return F._hits or 0
end

function F.Info()
	return { hooked = F._hooked, how = F._how, error = F._error, hits = F._hits or 0, reads = F.Reads() }
end




function F.Reads()
	local r = {}
	for k, v in next, F._reads do
		r[k] = v
	end
	return r
end

return Universery.SilentGeneric
