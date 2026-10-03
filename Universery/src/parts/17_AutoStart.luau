--// Auto-start: dosya direkt çalıştırılınca manuel Load() gerekmez.
do
	local persistOk = false
	pcall(function()
		getgenv().__universery_persist_check = true
		persistOk = getgenv().__universery_persist_check == true
		getgenv().__universery_persist_check = nil
	end)
	if not persistOk then
		warn("[Aimbot] FATAL: getgenv() state does not persist in this executor - aborting safely (no loops wired).")
		error("[Aimbot] non-persistent getgenv; aborting.")
	end
end
if Environment.DeveloperSettings.AutoStart ~= false then
	if PreviousInstance ~= nil and type(PreviousInstance.Exit) == "function" then
		pcall(function() PreviousInstance:Exit() end)
		getgenv().ExunysDeveloperAimbot = Environment -- Exit slotu nilledi, geri koy.
		dprint("previous instance exited (duplicate loops prevented)")
	end
	local okL, errL = pcall(function() Load() end)
	if okL then
		dprint("auto-started OK - hold", tostring(Environment.Settings.TriggerKey), "to aim")
	else
		warn("[Aimbot] auto-start failed: " .. tostring(errL) .. " - try manual: getgenv().ExunysDeveloperAimbot.Load()")
	end
else
	dprint("chunk loaded OK. Start with: getgenv().ExunysDeveloperAimbot.Load()")
end
dprint("hold", tostring(Environment.Settings.TriggerKey), "to aim (Toggle =", tostring(Environment.Settings.Toggle) .. ")")
dprint("tip: run GetDiagnostics() any time, or set Debugger.Enabled = true for live target stats")
end -- BuildAimbot
BuildAimbot()


