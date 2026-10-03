-- Config/Manager.lua — central config facade (Get/Set/Reset/Version/Migrate).
-- Status: DONE. Wiring milestone M2.
-- Does NOT replace MacLib native save/load. Get reads the live settings
-- tables; Set routes through the SAME Write paths as UI callbacks, so behavior
-- is identical. Old configs: missing keys fall back to live defaults; Migrate
-- fills dotted keys from a caller-supplied defaults table.
-- Standalone Luau module. Needs Bind(GetRootFn, WriteFn) before Set works.

local Manager = {}
Manager.Version = 3
Manager._getRoot = nil
Manager._write = nil

function Manager.Bind(getRootFn, writeFn)
	if type(getRootFn) == "function" then
		Manager._getRoot = getRootFn
	end
	if type(writeFn) == "function" then
		Manager._write = writeFn
	end
end

local function split(path)
	local parts = {}
	for p in string.gmatch(tostring(path), "[^%.]+") do
		parts[#parts + 1] = p
	end
	return parts
end

function Manager.Get(path)
	if Manager._getRoot == nil then
		return nil
	end
	local ok, root = pcall(Manager._getRoot)
	if not ok or type(root) ~= "table" then
		return nil
	end
	local node = root
	local parts = split(path)
	for i = 1, #parts - 1 do
		if type(node) ~= "table" then
			return nil
		end
		node = node[parts[i]]
	end
	if type(node) ~= "table" then
		return nil
	end
	return node[parts[#parts]]
end

function Manager.Set(path, value)
	if Manager._write == nil then
		pcall(warn, "[Universery][Config] Set before Bind: " .. tostring(path))
		return false
	end
	local ok = pcall(Manager._write, path, value)
	return ok
end

function Manager.Migrate(rootTable, defaultsTable)
	if type(rootTable) ~= "table" or type(defaultsTable) ~= "table" then
		return false
	end
	local function fill(dst, src)
		for k, v in next, src do
			if dst[k] == nil then
				dst[k] = v
			elseif type(dst[k]) == "table" and type(v) == "table" then
				fill(dst[k], v)
			end
		end
	end
	local ok = pcall(fill, rootTable, defaultsTable)
	return ok
end

return Manager
