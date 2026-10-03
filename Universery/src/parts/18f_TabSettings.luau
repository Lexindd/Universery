--// SETTINGS TAB: menu + config (MacLib native) + about

local MenuSec = MakeSection("Settings", "Left")
if MenuSec ~= nil then
	MenuSec:Header({ Text = "Menu" })
	MenuSec:Label({ Text = "Toggle: RightShift (aim pauses while open)" })

	El.MenuKey = MenuSec:Keybind({
		Name = "Menu Key",
		Default = Enum.KeyCode.RightShift,
		Callback = function() end,
		onBinded = function(bind)
			Notify("Menu Key", "Rebound to " .. tostring(bind) .. ". Note: visibility toggle stays on RightShift.")
		end,
	}, "MenuKey")

	MenuSec:Header({ Text = "Config" })
	local cfgDone = false
	if Tabs.Settings ~= nil then
		cfgDone = pcall(function()
			Tabs.Settings:InsertConfigSection("Left")
		end)
	end
	if not cfgDone then
		El.ConfigName = MenuSec:Input({
			Name = "Config Name",
			Placeholder = "default",
			AcceptedCharacters = "All",
			Callback = function() end,
		})
		MenuSec:Button({
			Name = "Save Config",
			Callback = function()
				local A = Aim()
				local name = "default"
				if El.ConfigName ~= nil then
					pcall(function()
						local t = El.ConfigName:GetInput()
						if type(t) == "string" and #t > 0 then
							name = t
						end
					end)
				end
				local ok, err = pcall(function()
					return MacLib:SaveConfig(name)
				end)
				if ok then
					PushAllToAimbot()
					Notify("Config", "Saved " .. tostring(name) .. ".")
				else
					Notify("Config", "Save failed: " .. tostring(err))
				end
			end,
		})
		MenuSec:Button({
			Name = "Load Config",
			Callback = function()
				local name = "default"
				if El.ConfigName ~= nil then
					pcall(function()
						local t = El.ConfigName:GetInput()
						if type(t) == "string" and #t > 0 then
							name = t
						end
					end)
				end
				local ok, err = pcall(function()
					return MacLib:LoadConfig(name)
				end)
				if ok then
					PushAllToAimbot()
					Notify("Config", "Loaded " .. tostring(name) .. ".")
				else
					Notify("Config", "Load failed: " .. tostring(err))
				end
			end,
		})
	end
end

local AboutSec = MakeSection("Settings", "Right")
if AboutSec ~= nil then
	AboutSec:Header({ Text = "About" })
	AboutSec:Paragraph({
		Header = "Universery + MacLib",
		Body = "Aimbot starts OFF. Enable it in the Aimbot tab. Hold the Aim Key to aim. RightShift toggles this UI.",
	})
end

-- Apply current UI state once at startup so visuals match the aimbot.
PushAllToAimbot()
print("[AimbotUI] UI build done. Sections: " .. tostring(SectionCount))
print("[AimbotUI] build: maclib-espv6 (m2a-modular)")

Notify("Aimbot UI", "MacLib UI loaded. Aimbot starts OFF; enable it in Aimbot.")
end -- UI build scope
