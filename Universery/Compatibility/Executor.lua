-- Compatibility/Executor.lua — central executor capability detection.
-- Status: DONE. Wiring milestone M2 (replaces scattered probes).
-- Standalone Luau module: local Executor = loadstring(...Executor.lua...)().
-- Never errors: every probe is pcall-guarded; missing APIs yield false/nil.

local Executor = {}
Executor._caps = nil
Executor._name = nil

local function detect()
	local caps = {}
	local function has(fnName)
		local ok, v = pcall(function() return _G[fnName] end)
		return ok and type(v) == "function"
	end
	caps.Drawing = type(Drawing) == "table" and type(Drawing.new) == "function"
	caps.HookMetamethod = has("hookmetamethod")
	caps.SetReadonly = has("setreadonly")
	caps.NewCClosure = has("newcclosure")
	caps.GetGenv = has("getgenv")
	caps.GetRawMetatable = (type(getrawmetatable) == "function")
	local okFs = pcall(function()
		return type(readfile) == "function" and type(writefile) == "function"
	end)
	caps.Filesystem = okFs
	caps.Request = has("request")
	caps.Loadstring = (type(loadstring) == "function")
	return caps
end

function Executor.Has(name)
	if Executor._caps == nil then
		Executor._caps = detect()
	end
	return Executor._caps[name] and true or false
end

function Executor.Get(name)
	if name == "Drawing" and Executor.Has("Drawing") then
		return Drawing
	end
	if Executor.Has(name) then
		local ok, v = pcall(function() return _G[name] end)
		if ok and type(v) == "function" then
			return v
		end
	end
	return nil
end

function Executor.Name()
	if Executor._name ~= nil then
		return Executor._name
	end
	local ok, id = pcall(function()
		if type(identifyexecutor) == "function" then
			return identifyexecutor()
		end
		return nil
	end)
	Executor._name = (ok and id) or "unknown"
	return Executor._name
end

function Executor.Require(names)
	local missing = {}
	for _, n in next, names do
		if not Executor.Has(n) then
			missing[#missing + 1] = n
		end
	end
	return #missing == 0, missing
end

return Executor
