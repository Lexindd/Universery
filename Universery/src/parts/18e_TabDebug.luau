local DbgSec = MakeSection("Debug", "Left")
if DbgSec ~= nil then
	DbgSec:Header({ Text = "Target" })

	El.DbgTarget = DbgSec:Label({ Text = "Target: None" })
	El.DbgTeam = DbgSec:Label({ Text = "Team: -" })
	El.DbgFOV = DbgSec:Label({ Text = "Prediction: -" })
	El.SilentDbg = DbgSec:Label({ Text = "Silent: OFF" })
	El.SilentDbg2 = DbgSec:Label({ Text = "Fire: -" })
	El.SilentDbg3 = DbgSec:Label({ Text = "Checks: -" })

	El.AimbotDebugger = DbgSec:Toggle({
		Name = "Aimbot Print Debugger",
		Default = false,
		Callback = function(v) Write("Debugger", v) end,
	}, "AimbotDebugger")
	syncer(function() return El.AimbotDebugger:GetState() end, function(v) Write("Debugger", v) end)

	DbgSec:Button({
		Name = "Scan Team Sources",
		Callback = function()
			local A = Aim()
			if A ~= nil and type(A.ScanTeamSources) == "function" then
				pcall(function() A.ScanTeamSources() end)
			else
				Notify("Scan", "ScanTeamSources unavailable.")
			end
		end,
	})
end

local NetSec = MakeSection("Debug", "Right")
local NetLbl, PredLbl, ChecksLbl
if NetSec ~= nil then
	NetSec:Header({ Text = "Network" })

	NetLbl = NetSec:Label({ Text = "Ping: -" })
	PredLbl = NetSec:Label({ Text = "Screen: -" })
	ChecksLbl = NetSec:Label({ Text = "Checks: -" })
end

local function SetLabel(lbl, text)
	if lbl == nil then
		return
	end
	local ok = pcall(function() lbl:UpdateName(text) end)
	if not ok then
		pcall(function() lbl.Text = text end)
	end
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local A = Aim()
		if A == nil then
			break
		end
		local okI, info = pcall(function() return A.GetTargetInfo() end)
		local okD, diag = pcall(function() return A.GetDiagnostics() end)
		if okI and type(info) == "table" then
			local tname = info.Target or "None"
			SetLabel(El.StatusLabel, "Aimbot: " .. tostring((A.Settings.Enabled and "ON") or "OFF")
				.. " | Target: " .. tostring(tname))
			SetLabel(El.DbgTarget, "Target: " .. tostring(tname) .. "  Score " .. string.format("%.2f", info.Score or -1))
			SetLabel(El.DbgFOV, "Eff " .. string.format("%.3f", info.EffTime or 0) .. "s  Conf " .. string.format("%d%%", math.floor((info.Confidence or 0) * 100)))
			SetLabel(PredLbl, "Screen " .. string.format("%.0f", info.ScreenX or 0) .. "," .. string.format("%.0f", info.ScreenY or 0))
		end
		if okD and type(diag) == "table" then
			SetLabel(El.DbgTeam, "Team: " .. tostring(diag.TargetTeam or "-") .. " | Src " .. tostring(diag.TeamSource or "?") .. " " .. string.format("%.2f", diag.TeamConfidence or 0))
			SetLabel(NetLbl, "Ping: " .. tostring(diag.Ping or 0) .. "ms / " .. tostring(diag.SmoothedPing or 0) .. "ms  Jit " .. tostring(diag.Jitter or 0) .. "ms  " .. tostring(diag.Network or "?"))
			SetLabel(ChecksLbl, "TeamCheck:" .. tostring(diag.TeamCheck) .. " Wall:" .. tostring(diag.WallCheck) .. " Retain:" .. tostring(diag.RetainRadius or 0))
		end
		local okS, sinfo = pcall(function() return A.GetSilentInfo() end)
		if okS and type(sinfo) == "table" then
			SetLabel(El.SilentDbg, "Silent: " .. ((sinfo.Enabled and "ON") or "OFF")
				.. " | Key: " .. ((sinfo.KeyHeld and "YES") or "NO")
				.. " | Tgt " .. tostring(sinfo.Target or "None")
				.. " " .. tostring(sinfo.Part or "-"))
			local scrXY = "-"
			if sinfo.Target ~= nil then
				scrXY = string.format("%.0f,%.0f", sinfo.ScreenX or -1, sinfo.ScreenY or -1)
			end
			SetLabel(El.SilentDbg2, "FOV " .. tostring(sinfo.FOVOrigin or "?")
				.. " | Mouse " .. tostring(sinfo.MouseX or -1) .. "," .. tostring(sinfo.MouseY or -1)
				.. " | R " .. tostring(sinfo.FOV or 0)
				.. " | Scr " .. scrXY
				.. " | MouseDist " .. string.format("%.0f", sinfo.MouseDist or -1)
				.. " | InFOV: " .. ((sinfo.InFOV and "YES") or "NO"))
			local awd = sinfo.AWDiag
			if type(awd) ~= "table" then
				awd = {}
			end
			SetLabel(El.SilentDbg3, "AW src/class/inst/trk/iter: "
				.. tostring(awd.source) .. "/" .. tostring(awd.class) .. "/"
				.. tostring(awd.instance) .. "/" .. tostring(awd.tracker) .. "/"
				.. tostring(awd.iterate) .. " | Sel: " .. tostring(awd.selected)
				.. " | Pred: " .. tostring(sinfo.Predicted or "-")
				.. " | Dir: " .. tostring(sinfo.AimDirection or "-")
				.. " | Behind: " .. tostring(sinfo.Behind or 0)
				.. " | Fire: " .. tostring(sinfo.FirePipeline or "?")
				.. " | Override: " .. tostring(sinfo.Override or "?")
				.. " | Apps: " .. tostring(sinfo.OverrideApps or 0)
				.. " | Ev: " .. tostring(sinfo.FireEvents or 0)
				.. " | Cam: UNCHANGED")
		end
	end
end)

