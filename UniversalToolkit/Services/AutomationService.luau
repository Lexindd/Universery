-- UniversalToolkit.Services.AutomationService
-- Spec Phase 6 / §14: tekrarlı aksiyon yöneticisi.
-- Her aksiyonda Enable/Disable/Pause/Resume/Stop/Clear. Kontrolsüz loop yok.

local AutomationService = {}
AutomationService._tasks = {}

function AutomationService:Start(name, interval, fn)
	if type(name) ~= "string" or type(fn) ~= "function" then
		return false, "bad args"
	end
	self:Stop(name)
	local task_ = { running = true, paused = false, count = 0 }
	self._tasks[name] = task_
	task.spawn(function()
		while task_.running do
			task.wait(interval or 1)
			if not task_.running then
				break
			end
			if not task_.paused then
				local ok, err = pcall(fn)
				task_.count = task_.count + 1
				if not ok then
					warn("[Automation][" .. name .. "] " .. tostring(err))
				end
			end
		end
	end)
	return true
end

function AutomationService:Stop(name)
	local t = self._tasks[name]
	if t ~= nil then
		t.running = false
		self._tasks[name] = nil
		return true
	end
	return false
end

function AutomationService:Pause(name)
	local t = self._tasks[name]
	if t ~= nil then t.paused = true return true end
	return false
end

function AutomationService:Resume(name)
	local t = self._tasks[name]
	if t ~= nil then t.paused = false return true end
	return false
end

function AutomationService:Count(name)
	local t = self._tasks[name]
	return t and t.count or 0
end

function AutomationService:Status()
	local out = {}
	for name, t in pairs(self._tasks) do
		out[name] = { running = t.running, paused = t.paused, count = t.count }
	end
	return out
end

function AutomationService:EmergencyStop()
	for name, _ in pairs(self._tasks) do
		self:Stop(name)
	end
end

function AutomationService:Destroy()
	self:EmergencyStop()
end

return AutomationService
