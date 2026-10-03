-- UniversalToolkit.Services.KeybindService
-- Spec Phase 7 / §18: Toggle/Hold/Always keybind yöneticisi + çakışma tespiti.

local UserInputService = game:GetService("UserInputService")

local KeybindService = {}
KeybindService._binds = {}
KeybindService._conns = nil

function KeybindService:Init(connections)
	self._conns = connections
	local cDown = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		for _, b in pairs(self._binds) do
			if b.mode ~= "Always" and self:_matches(b.key, input) then
				if b.mode == "Toggle" then
					b.state = not b.state
					if type(b.callback) == "function" then
						task.spawn(b.callback, b.state)
					end
				elseif b.mode == "Hold" then
					b.state = true
					if type(b.callback) == "function" then
						task.spawn(b.callback, true)
					end
				end
			end
		end
	end)
	local cUp = UserInputService.InputEnded:Connect(function(input)
		for _, b in pairs(self._binds) do
			if b.mode == "Hold" and self:_matches(b.key, input) then
				b.state = false
				if type(b.callback) == "function" then
					task.spawn(b.callback, false)
				end
			end
		end
	end)
	if connections ~= nil and type(connections.Register) == "function" then
		connections:Register("KeybindDown", cDown)
		connections:Register("KeybindUp", cUp)
	end
	return true
end

function KeybindService:_matches(key, input)
	if typeof(key) == "EnumItem" then
		return input.KeyCode == key or input.UserInputType == key
	end
	return false
end

function KeybindService:Register(name, key, mode, callback)
	if type(name) ~= "string" then
		return false, "bad name"
	end
	self._binds[name] = { key = key, mode = mode or "Toggle", callback = callback, state = false }
	return true
end

function KeybindService:Rebind(name, newKey)
	local b = self._binds[name]
	if b == nil then
		return false, "not found"
	end
	b.key = newKey
	return true
end

function KeybindService:Clear(name)
	self._binds[name] = nil
end

function KeybindService:Conflicts()
	-- Aynı tuşa bağlı birden fazla kayıt
	local seen = {}
	local out = {}
	for name, b in pairs(self._binds) do
		local k = tostring(b.key)
		if seen[k] ~= nil then
			table.insert(out, seen[k] .. " <-> " .. name .. " (" .. k .. ")")
		else
			seen[k] = name
		end
	end
	return out
end

function KeybindService:Destroy()
	for k, _ in pairs(self._binds) do
		self._binds[k] = nil
	end
end

return KeybindService
