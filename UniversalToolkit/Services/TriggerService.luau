-- UniversalToolkit.Services.TriggerService
-- Spec Phase 5 / §5: debounce'lu trigger yardımcısı. Kontrolsüz loop yok.
-- mouse1click varsa kullanır, yoksa UNAVAILABLE döner (crash yok).

local TriggerService = {}
TriggerService.Enabled = false
TriggerService.Delay = 0.15
TriggerService.Cooldown = 0.5
TriggerService._targeting = nil
TriggerService._running = false
TriggerService._lastShot = 0

function TriggerService:Init(deps)
	self._targeting = deps and deps.TargetingService
	return true
end

function TriggerService:CanFire()
	-- Ortam tıklamayı destekliyor mu?
	return type(mouse1click) == "function"
end

function TriggerService:Enable()
	if self.Enabled then
		return false, "already on"
	end
	if not self:CanFire() then
		return false, "Unavailable (mouse1click missing)"
	end
	self.Enabled = true
	self._running = true
	task.spawn(function()
		while self._running do
			task.wait(self.Delay)
			if not self._running or not self.Enabled then
				break
			end
			local now = os.clock()
			if now - self._lastShot < self.Cooldown then
				continue
			end
			local target = nil
			if self._targeting ~= nil then
				local ok, t = pcall(function()
					return self._targeting:GetClosestToCursor({ MaxFOV = 60, RequireVisible = true })
				end)
				if ok then target = t end
			end
			if target ~= nil then
				self._lastShot = now
				pcall(function() mouse1click() end)
			end
		end
	end)
	return true
end

function TriggerService:Disable()
	self.Enabled = false
	self._running = false
end

function TriggerService:Toggle()
	if self.Enabled then
		self:Disable()
		return false
	end
	local ok, err = self:Enable()
	if not ok then
		warn("[Trigger] " .. tostring(err))
		return false
	end
	return true
end

function TriggerService:Destroy()
	self:Disable()
end

return TriggerService
