-- UniversalToolkit.Services.ThemeService
-- Spec Phase 7 / §32: tema presetleri. Kendi çizdiğimiz öğelere
-- (crosshair, ESP) uygulanır. MacLib iç temasına dokunulmaz.

local ThemeService = {}
ThemeService.Current = "Mac Dark"
ThemeService.Presets = {
	["Mac Dark"] = { Accent = Color3.fromRGB(0, 122, 255), ESP = Color3.fromRGB(255, 255, 255), Crosshair = Color3.fromRGB(0, 255, 0) },
	["Midnight"] = { Accent = Color3.fromRGB(88, 101, 242), ESP = Color3.fromRGB(150, 180, 255), Crosshair = Color3.fromRGB(88, 101, 242) },
	["Purple"] = { Accent = Color3.fromRGB(170, 80, 255), ESP = Color3.fromRGB(200, 140, 255), Crosshair = Color3.fromRGB(200, 120, 255) },
	["Red"] = { Accent = Color3.fromRGB(255, 70, 70), ESP = Color3.fromRGB(255, 120, 120), Crosshair = Color3.fromRGB(255, 60, 60) },
	["Green"] = { Accent = Color3.fromRGB(50, 205, 50), ESP = Color3.fromRGB(140, 255, 140), Crosshair = Color3.fromRGB(50, 255, 50) },
	["Blue"] = { Accent = Color3.fromRGB(60, 160, 255), ESP = Color3.fromRGB(140, 200, 255), Crosshair = Color3.fromRGB(60, 180, 255) },
	["Monochrome"] = { Accent = Color3.fromRGB(200, 200, 200), ESP = Color3.fromRGB(230, 230, 230), Crosshair = Color3.fromRGB(255, 255, 255) },
}

function ThemeService:List()
	local out = {}
	for name, _ in pairs(self.Presets) do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function ThemeService:Apply(name, espService, crosshairService)
	local preset = self.Presets[name]
	if preset == nil then
		return false
	end
	self.Current = name
	if espService ~= nil then
		espService.CustomColor = preset.ESP
	end
	if crosshairService ~= nil then
		crosshairService.Color = preset.Crosshair
		if type(crosshairService.Refresh) == "function" then
			pcall(function() crosshairService:Refresh() end)
		end
	end
	return true
end

return ThemeService
