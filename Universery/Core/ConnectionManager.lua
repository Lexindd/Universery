-- Core/ConnectionManager.lua — central connection + drawing registry.
-- Status: DONE. Wiring milestone M2 (adopt feature connections gradually).
-- Standalone Luau module. CleanupAll/CleanupCategory mirror Exit semantics.

local ConnectionManager = {}
ConnectionManager._conns = {}
ConnectionManager._drawings = {}

function ConnectionManager:Connect(signal, fn, category)
	if signal == nil or type(fn) ~= "function" then
		return nil
	end
	local ok, conn = pcall(function()
		return signal:Connect(fn)
	end)
	if not ok or conn == nil then
		return nil
	end
	category = category or "Global"
	if self._conns[category] == nil then
		self._conns[category] = {}
	end
	self._conns[category][#self._conns[category] + 1] = conn
	return conn
end

function ConnectionManager:TrackDrawing(obj, category)
	if obj == nil then
		return
	end
	category = category or "Global"
	if self._drawings[category] == nil then
		self._drawings[category] = {}
	end
	self._drawings[category][#self._drawings[category] + 1] = obj
end

local function drop(list, worker)
	if type(list) ~= "table" then
		return
	end
	for _, o in next, list do
		pcall(worker, o)
	end
end

function ConnectionManager:CleanupCategory(category)
	drop(self._conns[category], function(c) c:Disconnect() end)
	self._conns[category] = nil
	drop(self._drawings[category], function(d) d:Remove() end)
	self._drawings[category] = nil
end

function ConnectionManager:CleanupAll()
	for category, _ in next, self._conns do
		drop(self._conns[category], function(c) c:Disconnect() end)
	end
	self._conns = {}
	for category, _ in next, self._drawings do
		drop(self._drawings[category], function(d) d:Remove() end)
	end
	self._drawings = {}
end

return ConnectionManager
