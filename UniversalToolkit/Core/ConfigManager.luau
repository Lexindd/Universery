-- UniversalToolkit.Core.ConfigManager
-- Spec §17: Save/Load/Delete/Rename/Duplicate/Export/Import/AutoSave/AutoLoad/Validation/Versioning
-- Sadece saf veri saklanır (feature state, values, keybinds, colors, theme). Runtime objesi saklanmaz.

local HttpService = game:GetService("HttpService")

local ConfigManager = {}
ConfigManager.VERSION = 1
ConfigManager.Folder = "UniversalToolkit"
ConfigManager._current = {} :: { [string]: any }
ConfigManager._defaults = {
	ESP = false,
	Notifications = true,
	Debug = false,
	WalkSpeedValue = 16,
	FlySpeed = 50,
	FOV = 70,
	MenuKeybind = "RightShift",
	PanicKeybind = "F8",
} :: { [string]: any }

function ConfigManager:Get(key: string, fallback: any?): any
	local v = self._current[key]
	if v == nil then
		v = self._defaults[key]
		if v == nil then
			return fallback
		end
	end
	return v
end

function ConfigManager:Set(key: string, value: any)
	-- Sadece JSON'a çevrilebilir tipleri kabul et (Instance vb. reddet)
	local t = typeof(value)
	if t == "Instance" or t == "RBXScriptConnection" then
		warn("[Config] runtime object not saved: " .. tostring(key))
		return false
	end
	self._current[key] = value
	return true
end

function ConfigManager:GetAll(): { [string]: any }
	local out = table.clone(self._defaults)
	for k, v in pairs(self._current) do
		out[k] = v
	end
	return out
end

function ConfigManager:ResetCurrentTab(_tabName: string)
	-- Phase 1: tam tab reset Phase 7'de genişletilecek. Şimdilik güvenli reset.
	table.clear(self._current)
end

function ConfigManager:ResetAll()
	table.clear(self._current)
end

function ConfigManager:Validate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	if type(data.version) ~= "number" then
		return false
	end
	if type(data.values) ~= "table" then
		return false
	end
	return true
end

function ConfigManager:Serialize(): string
	local payload = {
		version = self.VERSION,
		values = self:GetAll(),
	}
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok then
		error("Config encode failed: " .. tostring(encoded))
	end
	return encoded :: string
end

function ConfigManager:Deserialize(json: string): boolean
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok or not self:Validate(decoded) then
		return false
	end
	table.clear(self._current)
	for k, v in pairs((decoded :: any).values) do
		self:Set(k, v)
	end
	return true
end

function ConfigManager:_filePath(name: string): string
	return self.Folder .. "/settings/" .. name .. ".json"
end

function ConfigManager:Save(name: string): (boolean, string?)
	if type(name) ~= "string" or #name < 1 then
		return false, "Invalid config name"
	end
	if type(writefile) ~= "function" then
		return false, "Config system unavailable (writefile missing)"
	end
	local okMkdir, _ = pcall(function()
		if type(makefolder) == "function" then
			if not isfolder(self.Folder) then
				makefolder(self.Folder)
			end
			if not isfolder(self.Folder .. "/settings") then
				makefolder(self.Folder .. "/settings")
			end
		end
	end)
	if not okMkdir then
		-- Studio'da klasör yoksa sessizce geç
	end
	local ok, encoded = pcall(function()
		return self:Serialize()
	end)
	if not ok then
		return false, tostring(encoded)
	end
	local okW, errW = pcall(function()
		writefile(self:_filePath(name), encoded)
	end)
	if not okW then
		return false, tostring(errW)
	end
	return true, nil
end

function ConfigManager:Load(name: string): (boolean, string?)
	if type(readfile) ~= "function" or type(isfile) ~= "function" then
		return false, "Config system unavailable (readfile missing)"
	end
	local path = self:_filePath(name)
	local okE, exists = pcall(function()
		return isfile(path)
	end)
	if not okE or not exists then
		return false, "Config not found"
	end
	local okR, content = pcall(function()
		return readfile(path)
	end)
	if not okR then
		return false, tostring(content)
	end
	if self:Deserialize(content) then
		return true, nil
	end
	return false, "Invalid config data"
end

function ConfigManager:Delete(name: string): (boolean, string?)
	if type(delfile) ~= "function" or type(isfile) ~= "function" then
		return false, "Delete unavailable"
	end
	local path = self:_filePath(name)
	if not isfile(path) then
		return false, "Not found"
	end
	local ok, err = pcall(function()
		delfile(path)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

function ConfigManager:List(): { string }
	if type(listfiles) ~= "function" or type(isfolder) ~= "function" then
		return {}
	end
	local ok, files = pcall(function()
		if not isfolder(self.Folder .. "/settings") then
			return {}
		end
		return listfiles(self.Folder .. "/settings")
	end)
	if not ok or type(files) ~= "table" then
		return {}
	end
	local out = {}
	for _, f in ipairs(files) do
		if type(f) == "string" and string.sub(f, -5) == ".json" then
			table.insert(out, f)
		end
	end
	return out
end

return ConfigManager
