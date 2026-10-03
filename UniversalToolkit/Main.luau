--[[
    Universal Roblox Toolkit
    Version: 0.3.0 (Phase 1-7)
    Build: phase-all

    Supported (Phase 1+2):
      - Lifecycle: Init/Start/Stop/Unload/Panic
      - ConnectionManager, ConfigManager, FeatureRegistry
      - MacLib MainWindow iskeleti + Notifications/Dialog wrapper
      - Debug + Compatibility katmanı
      - CharacterService (respawn-safe), PlayerService (liste/bilgi/team/friend)
      - RaycastService (tek paylaşılan LOS), TargetingService (merkezi hedef motoru)

    Optional Dependencies:
      - MacLib (executor loadstring + game:HttpGet gerektirir)
      - writefile/readfile/listfiles (config dosyası için, yoksa bellek modu)

    Controls:
      - Menu: RightShift (MacLib Window Keybind)
      - Panic: F8 (örnek, Keybind fazında düzenlenebilir)

    Configuration:
      - UniversalToolkit/Core/ConfigManager (JSON, version=1)
      - Bellek modu her zaman çalışır, dosya modu varsa eklenir.

    Limitations:
      - Test edilmedi olarak kabul et; oyunda denemeden "çalışıyor" varsayma.
      - Combat/ESP/Movement özellikleri Phase 2+ (bu dosyada iskelet kaydı var).
      - Server-side durumlar client'tan kontrol edilemez; sadece client-side preview.

    Modül etkileşimi:
      Main -> Utils.Connections (tüm bağlantılar)
      Main -> Core.FeatureRegistry (arama/config/debug kaynağı)
      Main -> Core.ConfigManager (saf veri)
      Main -> UI.MainWindow (MacLib; logic'ten ayrı)

    Yeni özellik ekleme:
      1. Features/<Kategori>/<Ozellik>.luau oluştur (Enable/Disable/Toggle/Update/Destroy).
      2. FeatureRegistry:Register ile kaydet.
      3. UI katmanında ilgili Tab/Section'a kontrol ekle (logic'i UI'ya gömme).
      4. ConfigManager:Set ile sadece saf veriyi sakla.
]]

-- Entry ModuleScript olarak varsayılır:
-- UniversalToolkit/Main (ModuleScript)
--  ├─ Utils/Connections, Utils/Debug, Utils/Compatibility
--  ├─ Core/ConfigManager, Core/FeatureRegistry
--  └─ UI/MainWindow

local Connections = require(script.Parent.Utils.Connections)
local Debug = require(script.Parent.Utils.Debug)
local Compatibility = require(script.Parent.Utils.Compatibility)
local ConfigManager = require(script.Parent.Core.ConfigManager)
local FeatureRegistry = require(script.Parent.Core.FeatureRegistry)
local MainWindow = require(script.Parent.UI.MainWindow)
local CharacterService = require(script.Parent.Services.CharacterService)
local PlayerService = require(script.Parent.Services.PlayerService)
local RaycastService = require(script.Parent.Services.RaycastService)
local TargetingService = require(script.Parent.Services.TargetingService)
local ESPService = require(script.Parent.Services.ESPService)
local CrosshairService = require(script.Parent.Services.CrosshairService)
local MovementService = require(script.Parent.Services.MovementService)
local CameraService = require(script.Parent.Services.CameraService)
local AimService = require(script.Parent.Services.AimService)
local TriggerService = require(script.Parent.Services.TriggerService)
local AutomationService = require(script.Parent.Services.AutomationService)
local PerformanceService = require(script.Parent.Services.PerformanceService)
local ThemeService = require(script.Parent.Services.ThemeService)
local KeybindService = require(script.Parent.Services.KeybindService)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Toolkit = {}
Toolkit.State = "Initializing"
Toolkit.Originals = {}

local LocalPlayer = Players.LocalPlayer

local function cacheOriginals()
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum ~= nil then
		if Toolkit.Originals.WalkSpeed == nil then
			Toolkit.Originals.WalkSpeed = hum.WalkSpeed
		end
		if Toolkit.Originals.JumpPower == nil then
			Toolkit.Originals.JumpPower = hum.JumpPower
		end
	end
	local cam = workspace.CurrentCamera
	if cam ~= nil and Toolkit.Originals.FOV == nil then
		Toolkit.Originals.FOV = cam.FieldOfView
	end
end

local function restoreOriginals()
	local char = LocalPlayer and LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum ~= nil then
		if Toolkit.Originals.WalkSpeed ~= nil then
			pcall(function()
				hum.WalkSpeed = Toolkit.Originals.WalkSpeed
			end)
		end
		if Toolkit.Originals.JumpPower ~= nil then
			pcall(function()
				hum.JumpPower = Toolkit.Originals.JumpPower
			end)
		end
	end
	local cam = workspace.CurrentCamera
	if cam ~= nil and Toolkit.Originals.FOV ~= nil then
		pcall(function()
			cam.FieldOfView = Toolkit.Originals.FOV
		end)
	end
end

local function registerPhase1Features()
	-- Phase 1: sadece güvenli çekirdek özellikleri. Agresif varsayılan YOK (§43).
	FeatureRegistry:Register({
		Name = "Notifications",
		Category = "Settings",
		Description = "Bildirim sistemi aç/kapat",
		Aliases = { "Notify", "Bildirim" },
		Enabled = true,
		State = "ON",
		Enable = function()
			ConfigManager:Set("Notifications", true)
		end,
		Disable = function()
			ConfigManager:Set("Notifications", false)
		end,
	})

	FeatureRegistry:Register({
		Name = "Debug Mode",
		Category = "Debug",
		Description = "Debug çıktısını aç/kapat",
		Aliases = { "Debug", "Log" },
		Enabled = false,
		State = "OFF",
		Enable = function()
			Debug:SetEnabled(true)
			ConfigManager:Set("Debug", true)
		end,
		Disable = function()
			Debug:SetEnabled(false)
			ConfigManager:Set("Debug", false)
		end,
	})

	-- Phase 2+ yer tutucular: şimdiden UNAVAILABLE değil, OFF olarak kayıtlı.
	-- Böylece Search/Config sistemi şemayı erken tanır, logic fazlarda gelir.
	for _, stub in ipairs({
		{ Name = "Walk Speed", Category = "Movement", Aliases = { "Speed", "Hız" } },
		{ Name = "Fly", Category = "Movement", Aliases = { "Uçma", "Air" } },
		{ Name = "Player ESP", Category = "Visuals", Aliases = { "ESP", "Wall ESP" } },
		{ Name = "Aim Assist", Category = "Combat", Aliases = { "Aim", "Aimbot" } },
	}) do
		FeatureRegistry:Register({
			Name = stub.Name,
			Category = stub.Category,
			Description = "Phase 2+ (iskelet)",
			Aliases = stub.Aliases,
			Enabled = false,
			State = "OFF",
		})
	end
end

local function registerPhase2Features()
	-- Phase 2 gerçek kayıtları: önceki iskeletleri gerçek Enable/Disable ile güncelle.
	for _, name in ipairs({ "Walk Speed", "Fly", "Player ESP", "Aim Assist" }) do
		local entry = FeatureRegistry:Get(name)
		if entry ~= nil then
			entry.Description = "Phase 3+ logic (şu an kapalı iskelet)"
		end
	end

	FeatureRegistry:Register({
		Name = "Target Lock",
		Category = "Combat",
		Description = "Merkezi hedef motorundan en iyi hedefi kilitle",
		Aliases = { "Target", "Lock", "Hedef" },
		Enabled = false,
		State = "OFF",
		Enable = function()
			local target = TargetingService:GetBestTarget(nil)
			TargetingService:LockTarget(target)
			FeatureRegistry:SetState("Target Lock", "ON", true)
		end,
		Disable = function()
			TargetingService:Unlock()
			FeatureRegistry:SetState("Target Lock", "OFF", false)
		end,
	})

	FeatureRegistry:Register({
		Name = "Player Info Refresh",
		Category = "Players",
		Description = "Oyuncu listesi bilgisini tazele (event bazlı, düşük frekans)",
		Aliases = { "Player List", "Oyuncu" },
		Enabled = false,
		State = "OFF",
	})
end

local function initPhase2Services()
	CharacterService:Init(Connections)
	PlayerService:Init(Connections)
	TargetingService:Init({
		PlayerService = PlayerService,
		RaycastService = RaycastService,
		CharacterService = CharacterService,
	})
	-- Varsayılan hedef önceliği config'ten
	local prio = ConfigManager:Get("TargetPriority", "Crosshair")
	if type(prio) == "string" then
		TargetingService:SetPriority(prio)
	end
end

local function initPhase3to7Services()
	-- Hepsi pcall korumalı: biri patlarsa diğerleri kurulmaya devam eder.
	pcall(function() ESPService:Init(Connections) end)
	pcall(function() MovementService:Init(Connections) end)
	pcall(function() CameraService:Init(Connections) end)
	pcall(function() AimService:Init({ TargetingService = TargetingService, Connections = Connections }) end)
	pcall(function() TriggerService:Init({ TargetingService = TargetingService }) end)
	pcall(function() KeybindService:Init(Connections) end)
	pcall(function()
		PerformanceService:Init({ Connections = Connections, FeatureRegistry = FeatureRegistry, ESPService = ESPService })
	end)
end

local function registerPhase3to7Features()
	local defs = {
		{ Name = "Player ESP", Category = "Visuals", Aliases = { "ESP", "Wall ESP" },
			Enable = function() ESPService:Enable() end, Disable = function() ESPService:Disable() end },
		{ Name = "Crosshair", Category = "Visuals", Aliases = { "Cross" },
			Enable = function() CrosshairService:Enable() end, Disable = function() CrosshairService:Disable() end },
		{ Name = "Walk Speed", Category = "Movement", Aliases = { "Speed", "Hız" },
			Enable = function() MovementService:EnableWalkSpeed() end, Disable = function() MovementService:DisableWalkSpeed() end },
		{ Name = "Fly", Category = "Movement", Aliases = { "Uçma", "Air" },
			Enable = function() MovementService:EnableFly() end, Disable = function() MovementService:DisableFly() end },
		{ Name = "Aim Assist", Category = "Combat", Aliases = { "Aim", "Aimbot" },
			Enable = function() AimService:Enable() end, Disable = function() AimService:Disable() end },
		{ Name = "Trigger Bot", Category = "Combat", Aliases = { "Trigger" },
			Enable = function() TriggerService:Enable() end, Disable = function() TriggerService:Disable() end },
	}
	for _, d in ipairs(defs) do
		local existing = FeatureRegistry:Get(d.Name)
		if existing ~= nil then
			existing.Description = "Hazır (Enable/Disable bağlı)"
			existing.Enable = d.Enable
			existing.Disable = d.Disable
		else
			FeatureRegistry:Register({
				Name = d.Name,
				Category = d.Category,
				Description = "Hazır (Enable/Disable bağlı)",
				Aliases = d.Aliases,
				Enabled = false,
				State = "OFF",
				Enable = d.Enable,
				Disable = d.Disable,
			})
		end
	end
end
local function bindCharacterSafety()
	-- §26 + §27: respawn'da referansları tazele, enabled özellikleri yeniden uygula.
	if LocalPlayer == nil then
		return
	end
	local conn = LocalPlayer.CharacterAdded:Connect(function(_char)
		-- Eski humanoid referansı çöp; orijinalleri sıfırlama, yeniden cache'le.
		task.defer(function()
			task.wait(0.5)
			cacheOriginals()
			Debug:Log("Character respawned, refs refreshed")
		end)
	end)
	Connections:Register("CharacterAdded", conn)
end

local function bindPanicKey()
	local code = Enum.KeyCode.F8
	local conn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == code then
			Toolkit:Panic()
		end
	end)
	Connections:Register("PanicKey", conn)
end

local function buildPhase1UI()
	local ok, err = MainWindow:Init({
		Title = "Universal Toolkit",
		Subtitle = "Phase 1",
	})
	if not ok then
		Debug:Warn("UI unavailable: " .. tostring(err))
		return false
	end

	-- Settings sekmesine Phase 1 kontrolleri (logic UI'ya gömülmez, registry/config çağrılır)
	local section = MainWindow:MakeSection("Settings", "Left")
	if section ~= nil then
		pcall(function()
			section:Toggle({
				Name = "Notifications",
				Default = (ConfigManager:Get("Notifications", true) == true),
				Callback = function(v)
					ConfigManager:Set("Notifications", v)
				end,
			}, "NotificationsToggle")

			section:Toggle({
				Name = "Debug Mode",
				Default = false,
				Callback = function(v)
					Debug:SetEnabled(v)
					ConfigManager:Set("Debug", v)
				end,
			}, "DebugToggle")

			;section:Button({
				Name = "Panic (F8)",
				Callback = function()
					Toolkit:Panic()
				end,
			})

			;section:Button({
				Name = "Unload",
				Callback = function()
					Toolkit:Unload()
				end,
			})
		end)
	end

	-- Config sekmesi
	local cfgSection = MainWindow:MakeSection("Config", "Left")
	if cfgSection ~= nil then
		pcall(function()
			;cfgSection:Button({
				Name = "Save default",
				Callback = function()
					local okS, errS = ConfigManager:Save("default")
					MainWindow:Notify("Config", if okS then "Saved default" else "Save failed: " .. tostring(errS))
				end,
			})
			;cfgSection:Button({
				Name = "Load default",
				Callback = function()
					local okL, errL = ConfigManager:Load("default")
					MainWindow:Notify("Config", if okL then "Loaded default" else "Load failed: " .. tostring(errL))
				end,
			})
		end)
	end

	return true
end

local function buildPhase2UI()
	-- Players sekmesi: arama + hedef önceliği + target lock (logic UI'ya gömülmez)
	local playersLeft = MainWindow:MakeSection("Players", "Left")
	if playersLeft ~= nil then
		pcall(function()
			;playersLeft:Input({
				Name = "Player Search",
				Placeholder = "isim yaz...",
				AcceptedCharacters = "All",
				Callback = function(input)
					local found = PlayerService:FindByName(input)
					MainWindow:Notify("Players", "Found: " .. tostring(#found))
				end,
			}, "PlayerSearchInput")

			;playersLeft:Dropdown({
				Name = "Target Priority",
				Search = false,
				Multi = false,
				Required = true,
				Options = { "Crosshair", "Distance", "LowestHealth" },
				Default = 1,
				Callback = function(value)
					if type(value) == "string" then
						TargetingService:SetPriority(value)
						ConfigManager:Set("TargetPriority", value)
					end
				end,
			}, "TargetPriorityDropdown")

			;playersLeft:Toggle({
				Name = "Target Lock",
				Default = false,
				Callback = function(v)
					local entry = FeatureRegistry:Get("Target Lock")
					if entry ~= nil then
						if v and type(entry.Enable) == "function" then
							entry.Enable()
						elseif not v and type(entry.Disable) == "function" then
							entry.Disable()
						end
					end
				end,
			}, "TargetLockToggle")
		end)
	end

	local playersRight = MainWindow:MakeSection("Players", "Right")
	if playersRight ~= nil then
		pcall(function()
			;playersRight:Button({
				Name = "Print Player Count",
				Callback = function()
					MainWindow:Notify("Players", "Count: " .. tostring(PlayerService:Count()))
				end,
			})
			;playersRight:Button({
				Name = "Print Best Target",
				Callback = function()
					local target = TargetingService:GetBestTarget(nil)
					local label = "none"
					if target ~= nil then
						pcall(function() label = target.DisplayName .. " (@" .. target.Name .. ")" end)
					end
					MainWindow:Notify("Targeting", "Best: " .. label)
				end,
			})
		end)
	end

	-- Debug sekmesi: hedef + karakter durumu (düşük frekans, event bazlı)
	local debugLeft = MainWindow:MakeSection("Debug", "Left")
	if debugLeft ~= nil then
		pcall(function()
			;debugLeft:Button({
				Name = "Log Current Target",
				Callback = function()
					local t = TargetingService.CurrentTarget
					local alive = CharacterService:IsAlive()
					Debug:SetEnabled(true)
					Debug:Log("Alive:", alive, "Locked:", if t ~= nil then t.Name else "none")
				end,
			})
		end)
	end

	return true
end

function Toolkit:Init()
	self.State = "Loading"
	cacheOriginals()
	registerPhase1Features()
	initPhase2Services()
	registerPhase2Features()
	initPhase3to7Services()
	registerPhase3to7Features()
	bindCharacterSafety()
	-- CharacterService respawn'da orijinalleri tazelesin
	CharacterService:OnRespawn(function()
		cacheOriginals()
	end)
	bindPanicKey()
	buildPhase1UI()
	buildPhase2UI()
	self.State = "Ready"
	Debug:Log("Init done. UI available: " .. tostring(MainWindow.Available))
	return true
end

function Toolkit:Start()
	if self.State ~= "Ready" and self.State ~= "Paused" then
		return false
	end
	self.State = "Running"
	MainWindow:Notify("Universal Toolkit", "Running (Phase 2)")
	return true
end

function Toolkit:Stop()
	self.State = "Paused"
	return true
end

function Toolkit:Panic()
	-- §19: opsiyonel özellikleri kapat, automation'ı durdur, görselleri temizle,
	-- hareketi restore et, loop'ları kes, menüyü gizle (MacLib minimize yoksa Destroy'a düşme).
	if self.State == "Panic" then
		return
	end
	self.State = "Panic"
	TargetingService:Unlock()
	pcall(function() AutomationService:EmergencyStop() end)
	pcall(function() MovementService:RestoreAll() end)
	FeatureRegistry:DisableAll()
	restoreOriginals()
	Connections:DisconnectAll()
	-- Panic tuşunu tekrar bağla ki kullanıcı geri dönebilsin
	bindPanicKey()
	MainWindow:Notify("Panic", "All features disabled, values restored")
	Debug:Warn("Panic triggered")
end

function Toolkit:Unload()
	-- §29: tüm özellikleri kapat, ESP/UI kaldır, bağlantıları kes, orijinalleri restore et.
	self.State = "Unloading"
	local ok, err = pcall(function()
		TargetingService:Unlock()
		TargetingService:Destroy()
		CharacterService:Destroy()
		PlayerService:Destroy()
		ESPService:Destroy()
		CrosshairService:Destroy()
		MovementService:Destroy()
		AimService:Destroy()
		TriggerService:Destroy()
		AutomationService:Destroy()
		PerformanceService:Destroy()
		KeybindService:Destroy()
		FeatureRegistry:DisableAll()
		restoreOriginals()
		Connections:DisconnectAll()
		MainWindow:Destroy()
		FeatureRegistry:Clear()
	end)
	if not ok then
		warn("[Toolkit] Unload error: " .. tostring(err))
	end
	self.State = "Destroyed"
	print("[Toolkit] Unloaded. No background tasks should remain.")
end

-- Debug/ESP fazları için servis erişimi (UI logic'i buradan alır, global kirletmez)
Toolkit.Services = {
	Character = CharacterService,
	Players = PlayerService,
	Raycast = RaycastService,
	Targeting = TargetingService,
	ESP = ESPService,
	Crosshair = CrosshairService,
	Movement = MovementService,
	Camera = CameraService,
	Aim = AimService,
	Trigger = TriggerService,
	Automation = AutomationService,
	Performance = PerformanceService,
	Theme = ThemeService,
	Keybind = KeybindService,
}

return Toolkit
