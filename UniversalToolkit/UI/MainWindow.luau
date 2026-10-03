-- UniversalToolkit.UI.MainWindow
-- Spec §3 + §30: MacLib tabanlı ana pencere, sidebar, bildirim, dialog.
-- Bağımlılık: MacLib loadstring (executor) + MacLib.Folder düzeltmesi.
-- MacLib yoksa pencere oluşturulmaz, Notify fallback olarak warn/print kullanır.

local Players = game:GetService("Players")

local MainWindow = {}
MainWindow.Window = nil
MainWindow.MacLib = nil
MainWindow.Tabs = {}
MainWindow.Available = false

local SIDEBAR_ORDER = {
	"Combat",
	"Visuals",
	"Players",
	"Movement",
	"World",
	"Automation",
	"Misc",
	"Settings",
	"Config",
	"Debug",
	"About",
}

local function loadMacLib()
	if type(loadstring) ~= "function" then
		return nil, "loadstring unavailable"
	end
	local ok, result = pcall(function()
		local src = game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt")
		return loadstring(src)()
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

function MainWindow:Init(opts)
	opts = opts or {}
	local macLib, err = loadMacLib()
	if macLib == nil then
		warn("[UI] MacLib unavailable: " .. tostring(err))
		self.Available = false
		return false, err
	end

	self.MacLib = macLib
	-- Düzeltme: SetFolder Window'dan önce çağrılamıyor, doğrudan alan ata.
	macLib.Folder = "UniversalToolkit"

	local okW, windowOrErr = pcall(function()
		return macLib:Window({
			Title = opts.Title or "Universal Toolkit",
			Subtitle = opts.Subtitle or "Phase 1",
			Size = UDim2.fromOffset(868, 650),
			DragStyle = 1,
			DisabledWindowControls = {},
			ShowUserInfo = true,
			Keybind = Enum.KeyCode.RightShift,
			AcrylicBlur = true,
		})
	end)
	if not okW then
		warn("[UI] Window create failed: " .. tostring(windowOrErr))
		self.Available = false
		return false, tostring(windowOrErr)
	end

	self.Window = windowOrErr
	self.Available = true

	local okG, tabGroupOrErr = pcall(function()
		return self.Window:TabGroup()
	end)
	if not okG then
		warn("[UI] TabGroup failed: " .. tostring(tabGroupOrErr))
		return false, tostring(tabGroupOrErr)
	end
	self.TabGroup = tabGroupOrErr

	-- Sidebar sekmelerini sırayla oluştur (Phase 1: iskelet, içerik fazlarda dolar)
	for _, name in ipairs(SIDEBAR_ORDER) do
		local okT, tabOrErr = pcall(function()
			return self.TabGroup:Tab({ Name = name })
		end)
		if okT then
			self.Tabs[name] = tabOrErr
		else
			warn("[UI] Tab failed (" .. name .. "): " .. tostring(tabOrErr))
		end
	end

	-- Varsayılan sekme
	if self.Tabs["Movement"] ~= nil then
		pcall(function()
			self.Tabs["Movement"]:Select()
		end)
	end

	return true, nil
end

function MainWindow:GetTab(name)
	return self.Tabs[name]
end

function MainWindow:MakeSection(tabName, side)
	local tab = self.Tabs[tabName]
	if tab == nil then
		return nil
	end
	local ok, sectionOrErr = pcall(function()
		return tab:Section({ Side = side })
	end)
	if not ok then
		warn("[UI] Section failed: " .. tostring(sectionOrErr))
		return nil
	end
	return sectionOrErr
end

function MainWindow:Notify(title, description, lifetime)
	if self.Available and self.Window ~= nil then
		local windowRef = self.Window
		local ok, err = pcall(function()
			windowRef:Notify({
				Title = title,
				Description = description,
				Lifetime = lifetime or 3,
			})
		end)
		if ok then
			return true
		end
		warn("[UI] Notify failed: " .. tostring(err))
	end
	print("[Notify] " .. title .. ": " .. description)
	return false
end

function MainWindow:Dialog(title, description, onConfirm)
	if self.Available and self.Window ~= nil then
		local windowRef = self.Window
		local ok, err = pcall(function()
			windowRef:Dialog({
				Title = title,
				Description = description,
				Buttons = {
					{
						Name = "Confirm",
						Callback = function()
							if type(onConfirm) == "function" then
								task.spawn(onConfirm)
							end
						end,
					},
					{ Name = "Cancel" },
				},
			})
		end)
		if ok then
			return true
		end
		warn("[UI] Dialog failed: " .. tostring(err))
	end
	return false
end

function MainWindow:Destroy()
	-- MacLib'de Window:Destroy yoksa GUI'yi güvenli şekilde bırak.
	-- Unload akışı Main.luau üzerinden Connections:DisconnectAll ile tamamlanır.
	self.Tabs = {}
	self.Window = nil
	self.Available = false
end

return MainWindow
