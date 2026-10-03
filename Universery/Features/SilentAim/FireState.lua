-- Features/SilentAim/FireState.lua — fire-event abstraction (no MB1 monopoly).
-- Detects the actual supported firing pathways in this environment:
--   * MouseButton1 press/hold (polled; capability-probed, not assumed)
--   * Tool.Activated on the local character's tools (wired per character)
-- Exposes: IsFiring() / GetLastFireTime() / OnFire(callback) / Reset() /
-- Capabilities(). Override decisions consume IsFiring(), never raw MB1 state.

local Universery = Require("registry")
Universery.FireState = Universery.FireState or {}
local FS = Universery.FireState

FS._mbHeld = false
FS._mbPrev = false
FS._mbTime = 0
FS._toolChar = nil
FS._toolConns = {}
FS._toolTime = 0
FS._listeners = {}
FS._caps = nil
FS._mbEvents = 0
FS._toolEvents = 0

local function now()
	local ok, t = pcall(function() return tick() end)
	if ok and type(t) == "number" then
		return t
	end
	return 0
end

local function uis()
	local ok, u = pcall(function() return game:GetService("UserInputService") end)
	if ok then
		return u
	end
	return nil
end

function FS.Capabilities()
	if FS._caps ~= nil then
		return FS._caps
	end
	local caps = { MouseButton1 = false, ToolActivated = true }
	pcall(function()
		local u = uis()
		if u ~= nil then
			u:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			caps.MouseButton1 = true
		end
	end)
	FS._caps = caps
	return caps
end

local function fireEvent(source)
	local t = now()
	if source == "mb" then
		FS._mbTime = t
		FS._mbEvents = (FS._mbEvents or 0) + 1
	else
		FS._toolTime = t
		FS._toolEvents = (FS._toolEvents or 0) + 1
	end
	for _, fn in next, FS._listeners do
		pcall(fn, source)
	end
end

function FS.Poll()
	local caps = FS.Capabilities()
	if not caps.MouseButton1 then
		return FS._mbHeld
	end
	local held = false
	pcall(function()
		local u = uis()
		if u ~= nil then
			held = u:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and true or false
		end
	end)
	FS._mbHeld = held
	if held and not FS._mbPrev then
		fireEvent("mb")
	end
	FS._mbPrev = held
	return held
end

local function trackTool(tool)
	local ok, conn = pcall(function()
		return tool.Activated:Connect(function()
			fireEvent("tool")
		end)
	end)
	if ok and conn ~= nil then
		FS._toolConns[#FS._toolConns + 1] = conn
	end
end

function FS.RefreshTools()
	local ch = nil
	pcall(function()
		local plrs = game:GetService("Players")
		local lp = plrs.LocalPlayer
		if lp ~= nil then
			ch = lp.Character
		end
	end)
	if ch == FS._toolChar then
		return
	end
	for _, c in next, FS._toolConns do
		pcall(function() c:Disconnect() end)
	end
	FS._toolConns = {}
	FS._toolChar = ch
	if ch == nil then
		return
	end
	pcall(function()
		for _, d in next, ch:GetChildren() do
			if d:IsA("Tool") then
				trackTool(d)
			end
		end
	end)
	pcall(function()
		local okC, conn = pcall(function()
			return ch.ChildAdded:Connect(function(d)
				pcall(function()
					if d:IsA("Tool") then
						trackTool(d)
					end
				end)
			end)
		end)
		if okC and conn ~= nil then
			FS._toolConns[#FS._toolConns + 1] = conn
		end
	end)
end

function FS.IsFiring()
	if FS._mbHeld then
		return true
	end
	local t = now()
	if (t - (FS._mbTime or 0)) < 0.15 then
		return true
	end
	if (t - (FS._toolTime or 0)) < 0.15 then
		return true
	end
	return false
end

function FS.GetLastFireTime()
	local a = FS._mbTime or 0
	local b = FS._toolTime or 0
	if a > b then
		return a
	end
	return b
end

function FS.FireEvents()
	return (FS._mbEvents or 0) + (FS._toolEvents or 0)
end

function FS.ToolEvents()
	return FS._toolEvents or 0
end

function FS.OnFire(callback)
	if type(callback) == "function" then
		FS._listeners[#FS._listeners + 1] = callback
	end
end

function FS.Reset()
	for _, c in next, FS._toolConns do
		pcall(function() c:Disconnect() end)
	end
	FS._toolConns = {}
	FS._toolChar = nil
	FS._mbHeld = false
	FS._mbPrev = false
	FS._mbTime = 0
	FS._toolTime = 0
end

return Universery.FireState
