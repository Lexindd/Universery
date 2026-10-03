-- Core/Services.lua — central service registry (no repeated GetService).
-- Status: DONE. Wiring milestone M2.
-- Standalone Luau module. Only dependency: the game global.

local Services = {}
Services._cache = {}

function Services.Get(name)
	if Services._cache[name] == nil then
		local ok, svc = pcall(function()
			return game:GetService(name)
		end)
		if ok and svc ~= nil then
			Services._cache[name] = svc
		else
			return nil
		end
	end
	return Services._cache[name]
end

function Services.Players()
	return Services.Get("Players")
end

function Services.RunService()
	return Services.Get("RunService")
end

function Services.UserInputService()
	return Services.Get("UserInputService")
end

function Services.Workspace()
	local ok, ws = pcall(function() return workspace end)
	if ok then
		return ws
	end
	return nil
end

function Services.Clear()
	Services._cache = {}
end

return Services
