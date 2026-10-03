-- Core/Scheduler.lua — shared update registry (replaces duplicate loops).
-- Status: DONE. Wiring milestone M2 (adopt scan loops one by one).
-- Usage: Scheduler.Init(runService); Scheduler.Register("ESP", 30, fn);
-- a single RenderStepped connection drives all entries by rate.
-- Standalone Luau module. Never errors (all callbacks pcall-guarded).

local Scheduler = {}
Scheduler._jobs = {}
Scheduler._conn = nil
Scheduler._accum = {}

function Scheduler.Init(runService, signalName)
	Scheduler.Stop()
	Scheduler._rs = runService
	Scheduler._signal = signalName or "RenderStepped"
end

function Scheduler.Register(name, rateHz, fn)
	if type(name) ~= "string" or type(fn) ~= "function" then
		return false
	end
	rateHz = tonumber(rateHz) or 30
	if rateHz < 1 then
		rateHz = 1
	end
	if rateHz > 240 then
		rateHz = 240
	end
	Scheduler._jobs[name] = { Rate = rateHz, Fn = fn }
	Scheduler._accum[name] = 0
	return true
end

function Scheduler.Unregister(name)
	Scheduler._jobs[name] = nil
	Scheduler._accum[name] = nil
end

function Scheduler.Start()
	Scheduler.Stop()
	local rs = Scheduler._rs
	if rs == nil then
		return false
	end
	local ok, signal = pcall(function() return rs[Scheduler._signal] end)
	if not ok or signal == nil then
		return false
	end
	local okC, conn = pcall(function()
		return signal:Connect(function(dt)
			Scheduler.Tick(dt or 0.016)
		end)
	end)
	if okC and conn ~= nil then
		Scheduler._conn = conn
		return true
	end
	return false
end

function Scheduler.Tick(dt)
	for name, job in next, Scheduler._jobs do
		local acc = (Scheduler._accum[name] or 0) + dt
		if acc >= (1 / job.Rate) then
			Scheduler._accum[name] = 0
			pcall(job.Fn, dt)
		else
			Scheduler._accum[name] = acc
		end
	end
end

function Scheduler.Stop()
	if Scheduler._conn ~= nil then
		pcall(function() Scheduler._conn:Disconnect() end)
		Scheduler._conn = nil
	end
end

function Scheduler.Destroy()
	Scheduler.Stop()
	Scheduler._jobs = {}
	Scheduler._accum = {}
	Scheduler._rs = nil
end

return Scheduler
