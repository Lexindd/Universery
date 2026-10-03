-- UniversalToolkit.Core.FeatureRegistry
-- Tüm özellikler buraya kaydolur. Search / Config / Debug / Keybind bu listeyi kullanır.
-- Spec §41 + §42 (aliases).

export type FeatureEntry = {
	Name: string,
	Category: string,
	Description: string?,
	Aliases: { string }?,
	Enabled: boolean,
	State: string, -- OFF | ON | AUTO | ERROR | UNAVAILABLE
	Enable: (() -> ())?,
	Disable: (() -> ())?,
	Toggle: (() -> boolean)?,
}

local Registry = {}
Registry._features = {} :: { [string]: FeatureEntry }

local function normalizeKey(name: string): string
	return string.lower(name)
end

function Registry:Register(entry: FeatureEntry)
	assert(type(entry.Name) == "string", "Feature.Name required")
	assert(type(entry.Category) == "string", "Feature.Category required")
	entry.Enabled = entry.Enabled == true
	if entry.State == nil then
		entry.State = if entry.Enabled then "ON" else "OFF"
	end
	if entry.Aliases == nil then
		entry.Aliases = {}
	end
	self._features[normalizeKey(entry.Name)] = entry
	return entry
end

function Registry:Get(name: string): FeatureEntry?
	if type(name) ~= "string" then
		return nil
	end
	local direct = self._features[normalizeKey(name)]
	if direct ~= nil then
		return direct
	end
	-- alias araması
	local needle = string.lower(name)
	for _, entry in pairs(self._features) do
		if entry.Aliases ~= nil then
			for _, alias in ipairs(entry.Aliases) do
				if string.lower(alias) == needle then
					return entry
				end
			end
		end
	end
	return nil
end

function Registry:SetState(name: string, state: string, enabled: boolean?)
	local entry = self:Get(name)
	if entry == nil then
		return false
	end
	entry.State = state
	if enabled ~= nil then
		entry.Enabled = enabled == true
	end
	return true
end

function Registry:List(): { FeatureEntry }
	local out = {}
	for _, entry in pairs(self._features) do
		table.insert(out, entry)
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

function Registry:ListByCategory(category: string): { FeatureEntry }
	local out = {}
	for _, entry in pairs(self._features) do
		if entry.Category == category then
			table.insert(out, entry)
		end
	end
	return out
end

-- Spec §31: hızlı arama (isim + açıklama + alias + kategori)
function Registry:Search(query: string): { FeatureEntry }
	if type(query) ~= "string" or string.len(query) < 1 then
		return self:List()
	end
	local needle = string.lower(query)
	local out = {}
	for _, entry in pairs(self._features) do
		local hay = string.lower(entry.Name .. " " .. (entry.Description or "") .. " " .. entry.Category)
		if string.find(hay, needle, 1, true) ~= nil then
			table.insert(out, entry)
			continue
		end
		if entry.Aliases ~= nil then
			for _, alias in ipairs(entry.Aliases) do
				if string.find(string.lower(alias), needle, 1, true) ~= nil then
					table.insert(out, entry)
					break
				end
			end
		end
	end
	return out
end

function Registry:DisableAll()
	for _, entry in pairs(self._features) do
		if entry.Enabled and type(entry.Disable) == "function" then
			local ok, err = pcall(entry.Disable)
			if not ok then
				entry.State = "ERROR"
				warn("[Registry] disable failed for " .. entry.Name .. ": " .. tostring(err))
			else
				entry.Enabled = false
				entry.State = "OFF"
			end
		end
	end
end

function Registry:Clear()
	table.clear(self._features)
end

return Registry
