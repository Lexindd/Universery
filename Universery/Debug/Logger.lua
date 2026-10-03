-- Debug/Logger.lua — central diagnostic logging.
-- Status: DONE. Wiring milestone M2 (replaces dprint/warn scatter).
-- Standalone Luau module. Zero dependencies. Never errors.

local Logger = {}
Logger.Enabled = true
Logger.Level = "Info"

local RANK = { Debug = 0, Info = 1, Warn = 2, Error = 3 }

function Logger.SetEnabled(on)
	Logger.Enabled = on and true or false
end

function Logger.SetLevel(level)
	if RANK[level] ~= nil then
		Logger.Level = level
	end
end

local function emit(level, tag, msg)
	if not Logger.Enabled then
		return
	end
	if (RANK[level] or 1) < (RANK[Logger.Level] or 1) then
		return
	end
	local line = "[Universery][" .. tostring(level) .. "][" .. tostring(tag) .. "] " .. tostring(msg)
	if level == "Warn" or level == "Error" then
		pcall(warn, line)
	else
		print(line)
	end
end

function Logger.Debug(tag, msg)
	emit("Debug", tag, msg)
end

function Logger.Info(tag, msg)
	emit("Info", tag, msg)
end

function Logger.Warn(tag, msg)
	emit("Warn", tag, msg)
end

function Logger.Error(tag, msg)
	emit("Error", tag, msg)
end

return Logger
