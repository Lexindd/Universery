-- UniversalToolkit.Services.PerformanceService
-- Spec Phase 6 / §16: FPS + oyuncu sayısı + bağlantı/özellik sayaçları.
-- RenderStepped'i sadece örnekleme açıkken kullanır.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PerformanceService = {}
PerformanceService._frames = 0
PerformanceService._fps = 0
PerformanceService._sampling = false
PerformanceService._conns = nil
PerformanceService._registry = nil
PerformanceService._esp = nil

function PerformanceService:Init(deps)
	if deps ~= nil then
		self._conns = deps.Connections
		self._registry = deps.FeatureRegistry
		self._esp = deps.ESPService
	end
	if not self._sampling then
		self._sampling = true
		local c = RunService.RenderStepped:Connect(function()
			self._frames = self._frames + 1
		end)
		if self._conns ~= nil and type(self._conns.Register) == "function" then
			self._conns:Register("PerfFrames", c)
		end
		task.spawn(function()
			while self._sampling do
				task.wait(1)
				self._fps = self._frames
				self._frames = 0
			end
		end)
	end
	return true
end

function PerformanceService:GetFPS()
	return self._fps
end

function PerformanceService:GetStats()
	local stats = { fps = self._fps, players = #Players:GetPlayers(), esp = 0, features = 0, connections = 0 }
	if self._esp ~= nil and type(self._esp.Count) == "function" then
		local ok, n = pcall(function() return self._esp:Count() end)
		if ok then stats.esp = n end
	end
	if self._registry ~= nil and type(self._registry.List) == "function" then
		local ok, list = pcall(function() return self._registry:List() end)
		if ok and type(list) == "table" then stats.features = #list end
	end
	if self._conns ~= nil and type(self._conns.Count) == "function" then
		local ok, n = pcall(function() return self._conns:Count() end)
		if ok then stats.connections = n end
	end
	return stats
end

function PerformanceService:Destroy()
	self._sampling = false
	if self._conns ~= nil then
		self._conns:Disconnect("PerfFrames")
	end
end

return PerformanceService
