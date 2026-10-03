-- Features/SilentAim/Adapters/Registry.lua — game-specific adapter registry.
-- Isolated per PlaceId; the universal core never hardcodes game logic.
-- Adapter contract (all optional except Apply):
--   { Apply = function(self, pos, cf) -> boolean,
--     GetOrigin = function(self) -> Vector3|nil,
--     ConfirmHit = function(self, info) -> boolean }

local Universery = Require("registry")
Universery.SilentRegistry = Universery.SilentRegistry or {}
local R = Universery.SilentRegistry

R._byGame = R._byGame or {}
R._generic = R._generic

function R.Register(gameId, adapter)
	if type(adapter) ~= "table" then
		return false
	end
	if gameId == "*" then
		R._generic = adapter
	else
		R._byGame[tonumber(gameId) or gameId] = adapter
	end
	return true
end

function R.Resolve()
	local gameId = nil
	pcall(function()
		if game ~= nil then
			gameId = game.PlaceId or game.GameId
		end
	end)
	if gameId ~= nil and R._byGame[gameId] ~= nil then
		return R._byGame[gameId], tostring(gameId)
	end
	if R._generic ~= nil then
		return R._generic, "generic"
	end
	return nil, "none"
end

function R.List()
	local ids = {}
	for id, _ in next, R._byGame do
		ids[#ids + 1] = tostring(id)
	end
	return ids
end

return Universery.SilentRegistry
