-- Universery + MacLib (SINGLE FILE)
-- Tek dosya: aimbot gomulu gelir (auto-start, OFF baslar), tum kontrol MacLib UI uzerinden.
-- Aimbot sekmesindeki Enable Aimbot ile acilir/kapatilir. Menu: RightShift.

--[[
	Universal Aimbot x MacLib UI
	============================
	UI layer for the existing aimbot (aimbot section runs above in the merged
	file). This file contains NO targeting, prediction, raycast, camera or
	player-loop logic.

	Adapter pattern (decouples future UI migrations):
		MacLib controls -> Write(path, value) -> aimbot live config tables
		MacLib controls -> Syncers[] -> PushAllToAimbot() (re-applies UI state,
		                  e.g. right after a config load, regardless of whether
		                  MacLib fires callbacks on load).

	Load order: aimbot section first (auto-start, OFF), then this UI section.
]]

--// MacLib load (verified API: github.com/biggaboy212/Maclib, brady-xyz.gitbook.io)

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
print("[AimbotUI] MacLib module loaded")
MacLib.Folder = "UniversalAimbot"

--// Aimbot accessor (single integration point; never duplicated logic)

local function Aim()
	local ok, genv = pcall(function() return getgenv() end)
	if not ok or genv == nil then
		return nil
	end
	return genv.ExunysDeveloperAimbot
end

--// Window (MacLib built-in RightShift keybind toggles visibility)

local okWin, Window = pcall(function()
	return MacLib:Window({
		Title = "Universal Aimbot",
		Subtitle = "MacLib UI",
		Size = UDim2.fromOffset(868, 650),
		DragStyle = 1,
		DisabledWindowControls = { "Exit", "Minimize" },
		ShowUserInfo = true,
		Keybind = Enum.KeyCode.RightShift,
		AcrylicBlur = true,
	})
end)
if not okWin or Window == nil then
	print("[AimbotUI] FATAL: MacLib Window creation failed:", tostring(Window))
	return
end
print("[AimbotUI] Window created")

local function Notify(title, desc)
	pcall(function()
		Window:Notify({ Title = title, Description = desc, Lifetime = 3 })
	end)
	print("[AimbotUI]", title .. ": " .. desc)
end

local okTG, TabGroup = pcall(function()
	return Window:TabGroup()
end)
if not okTG or TabGroup == nil then
	print("[AimbotUI] FATAL: TabGroup creation failed:", tostring(TabGroup))
	return
end
local Tabs = {}
local TabDefs = {
	{ Name = "Aimbot", Image = "rbxassetid://10709791437" },
	{ Name = "ESP" },
	{ Name = "Silent Aim" },
	{ Name = "Debug" },
	{ Name = "Settings" },
}
for _, def in next, TabDefs do
	local okT, tab = pcall(function()
		return TabGroup:Tab({ Name = def.Name, Image = def.Image })
	end)
	if okT and tab ~= nil then
		Tabs[def.Name] = tab
		print("[AimbotUI] Tab created:", def.Name)
	else
		print("[AimbotUI] Tab FAILED:", def.Name, tostring(tab))
	end
end

local SectionCount = 0
local function MakeSection(tabName, side)
	local tab = Tabs[tabName]
	if tab == nil then
		print("[AimbotUI] Section SKIPPED (no tab):", tabName, side)
		return nil
	end
	local okS, sec = pcall(function()
		return tab:Section({ Side = side })
	end)
	if okS then
		SectionCount = SectionCount + 1
		return sec
	end
	print("[AimbotUI] Section FAILED:", tabName, side, tostring(sec))
	return nil
end

--[[

	Universal Aimbot Module by Exunys © CC0 1.0 Universal (2023)

	https://github.com/Exunys

	UPGRADED (in-place): adaptive targeting layer.
	PREDICTION V2: latency-driven (ping -> time, velocity -> direction) + EMA velocity,
	jitter-aware confidence, slow auto-calibration. Legacy paths kept as fallback.
	- Centralized validation pipeline (single IsValidTarget).
	- Correct nil-safe Team Check (Team-first, optional TeamColor fallback, neutral handling).
	- Weighted target scoring (FOV / Distance / Visibility / Health / Priority / Persistence).
	- Target hysteresis (switch threshold, stickiness, grace period).
	- Velocity history + acceleration estimate + adaptive prediction + confidence.
	- Adaptive smoothing (error / distance / velocity driven), no per-frame Tween allocation.
	- Visibility cache + player cache + performance scheduler (scan at medium rate, aim every frame).
	- Throttled debug mode, full cleanup, preserved public API.

]]

-- Aimbot scope: the whole aimbot lives in this function so its ~160 locals
-- do not occupy chunk registers (Luau max: 200 live locals per chunk).
-- The UI below talks to it only via getgenv (Aim()).
