-- Libraries/Aimwork/loader.luau — require-shim + embedded blobs -> live Aimwork class.
-- Consumes Universery.AimworkSources (generated). Exposes Universery.AimworkLoad klass.
-- Rules honored: upstream files verbatim (blobs), no fork, graceful degrade.

local Universery = Require("registry")
Universery.AimworkLoad = Universery.AimworkLoad or {}
local L = Universery.AimworkLoad
L._cache = L._cache or {}
L._loading = L._loading or {}

local function dirOf(path)
	local dir = path:match("^(.*)/[^/]*$")
	if dir == nil or dir == "" then
		return ""
	end
	return dir
end

local function mapReq(req, requirer)
	if req == "@pkgs/trove" then
		return "pkgs/trove"
	end
	if req:sub(1, 1) ~= "@" then
		error("aimwork loader: relative require not supported: " .. tostring(req))
	end
	local rest = req:sub(2)
	if rest == "self" then
		local d = dirOf(requirer)
		if d == "" then
			return "init"
		end
		return d .. "/init"
	end
	local head = rest:match("^([^/]+)$")
	if head ~= nil then
		return head .. "/init"
	end
	if rest:sub(1, 5) == "self/" then
		local d = dirOf(requirer)
		local tail = rest:sub(6)
		if d == "" then
			return tail
		end
		return d .. "/" .. tail
	end
	return rest
end

function L.Load(key)
	if L._cache[key] ~= nil then
		return L._cache[key]
	end
	if L._loading[key] then
		return nil
	end
	local src = Universery.AimworkSources[key]
	if src == nil then
		error("aimwork loader: missing module " .. tostring(key))
	end
	L._loading[key] = true
	local req = function(rp)
		return L.Load(mapReq(rp, key))
	end
	local fn, perr = loadstring("local require = ...\n" .. src, "@aimwork/" .. key)
	if fn == nil then
		L._loading[key] = nil
		error("aimwork loader: parse failed " .. tostring(key) .. ": " .. tostring(perr))
	end
	local mod = fn(req)
	L._loading[key] = nil
	L._cache[key] = mod
	return mod
end

function L.Reset()
	L._cache = {}
	L._loading = {}
end

return Universery.AimworkLoad
