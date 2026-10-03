-- UniversalToolkit.Utils.Connections
-- Merkezi bağlantı yöneticisi. Tüm RenderStepped/Heartbeat/InputBegan
-- gibi bağlantılar buradan geçmeli ki Disable/Unload/Panic hepsini kapatabilsin.

local Connections = {}
Connections._list = {}

local function safeDisconnect(conn)
	if typeof(conn) == "RBXScriptConnection" then
		local ok, err = pcall(function()
			conn:Disconnect()
		end)
		if not ok then
			warn("[Connections] disconnect failed: " .. tostring(err))
		end
		return ok
	elseif type(conn) == "function" then
		-- task.cancel edilebilir thread / cleanup callback
		local ok, err = pcall(conn)
		if not ok then
			warn("[Connections] cleanup fn failed: " .. tostring(err))
		end
		return ok
	end
	return false
end

function Connections:Register(key: string, conn)
	assert(type(key) == "string", "key must be string")
	if self._list[key] ~= nil then
		self:Disconnect(key)
	end
	self._list[key] = conn
	return conn
end

function Connections:Disconnect(key: string)
	local conn = self._list[key]
	if conn == nil then
		return false
	end
	safeDisconnect(conn)
	self._list[key] = nil
	return true
end

function Connections:DisconnectAll()
	for key, conn in pairs(self._list) do
		safeDisconnect(conn)
		self._list[key] = nil
	end
	table.clear(self._list)
end

function Connections:Count(): number
	local n = 0
	for _ in pairs(self._list) do
		n += 1
	end
	return n
end

function Connections:Has(key: string): boolean
	return self._list[key] ~= nil
end

return Connections
