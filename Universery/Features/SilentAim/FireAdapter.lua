-- Features/SilentAim/FireAdapter.lua — thin facade over Generic + Registry.
-- The controller talks ONLY to this facade; engine and game adapters stay
-- behind it. No weapon/game logic lives here.

local Universery = Require("registry")
Universery.SilentFire = Universery.SilentFire or {}
local F = Universery.SilentFire

local function G()
	return Universery.SilentGeneric
end

local function R()
	return Universery.SilentRegistry
end

function F.Probe()
	return G().Probe()
end

function F.Engage()
	return G().Engage()
end

function F.Uninstall()
	G().Uninstall()
end

function F.IsHooked()
	return G().IsHooked()
end

function F.IsOverriding()
	return G().IsOverriding()
end

function F.SetAim(pos, cf, org)
	G().SetAim(pos, cf, org)
end

function F.ClearAim()
	G().ClearAim()
end

function F.SetCamera(cam)
	G().SetCamera(cam)
end

function F.SetOverride(on)
	G().SetOverride(on)
end

function F.Hits()
	return G().Hits()
end

function F.Reads()
	return G().Reads()
end

function F.Info()
	return G().Info()
end

function F.GetOrigin()
	local reg = R()
	if reg ~= nil then
		local adapter = reg.Resolve()
		if adapter ~= nil and type(adapter.GetOrigin) == "function" then
			local ok, org = pcall(adapter.GetOrigin, adapter)
			if ok and org ~= nil then
				return org
			end
		end
	end
	return nil
end

function F.RegisterAdapter(gameId, adapter)
	return R().Register(gameId, adapter)
end

function F.ResolveAdapter()
	return R().Resolve()
end

function F.ApplyCustom(pos, cf)
	local adapter = R().Resolve()
	if adapter ~= nil and type(adapter.Apply) == "function" then
		local ok = pcall(adapter.Apply, adapter, pos, cf)
		if ok then
			return true
		end
	end
	return false
end

return Universery.SilentFire
