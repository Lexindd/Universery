-- UniversalToolkit.Services.MovementService
-- Spec Phase 4 / §9 + §10: WalkSpeed, JumpPower, Fly, InfiniteJump.
-- Orijinaller saklanır, Disable'da geri yüklenir. Gereksiz overwrite yok.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementService = {}
MovementService.WalkSpeedOn = false
MovementService.WalkSpeedValue = 16
MovementService.FlyOn = false
MovementService.FlySpeed = 50
MovementService.InfiniteJumpOn = false
MovementService._originals = {}
MovementService._conns = nil

local function humanoid()
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	if r ~= nil and r:IsA("BasePart") then
		return r
	end
	return nil
end

local function saveOriginals()
	local h = humanoid()
	if h ~= nil then
		if MovementService._originals.WalkSpeed == nil then
			pcall(function() MovementService._originals.WalkSpeed = h.WalkSpeed end)
		end
		if MovementService._originals.JumpPower == nil then
			pcall(function() MovementService._originals.JumpPower = h.JumpPower end)
		end
	end
end

function MovementService:Init(connections)
	self._conns = connections
	saveOriginals()
	if connections ~= nil then
		local c = UserInputService.JumpRequest:Connect(function()
			if self.InfiniteJumpOn then
				local h = humanoid()
				if h ~= nil then
					pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
				end
			end
		end)
		if type(connections.Register) == "function" then
			connections:Register("InfiniteJump", c)
		end
	end
	return true
end

function MovementService:SetWalkSpeed(value)
	self.WalkSpeedValue = value
	if self.WalkSpeedOn then
		local h = humanoid()
		if h ~= nil then
			pcall(function() h.WalkSpeed = value end)
		end
	end
end

function MovementService:EnableWalkSpeed()
	saveOriginals()
	self.WalkSpeedOn = true
	self:SetWalkSpeed(self.WalkSpeedValue)
end

function MovementService:DisableWalkSpeed()
	self.WalkSpeedOn = false
	local h = humanoid()
	if h ~= nil and self._originals.WalkSpeed ~= nil then
		pcall(function() h.WalkSpeed = self._originals.WalkSpeed end)
	end
end

function MovementService:SetJumpPower(value)
	local h = humanoid()
	if h ~= nil then
		pcall(function() h.JumpPower = value end)
	end
end

function MovementService:EnableFly()
	saveOriginals()
	if self.FlyOn then
		return
	end
	self.FlyOn = true
	local hb = RunService.Heartbeat:Connect(function(dt)
		if not self.FlyOn then
			return
		end
		local root = rootPart()
		local cam = Workspace.CurrentCamera
		if root == nil or cam == nil then
			return
		end
		local move = Vector3.new(0, 0, 0)
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
		if move.Magnitude > 0 then
			move = (move.Unit * self.FlySpeed * dt)
			root.CFrame = root.CFrame + move
			root.Velocity = Vector3.new(0, 0, 0)
		else
			root.Velocity = Vector3.new(0, 0, 0)
		end
	end)
	if self._conns ~= nil and type(self._conns.Register) == "function" then
		self._conns:Register("FlyLoop", hb)
	end
end

function MovementService:DisableFly()
	self.FlyOn = false
	if self._conns ~= nil then
		self._conns:Disconnect("FlyLoop")
	end
end

function MovementService:SetInfiniteJump(on)
	self.InfiniteJumpOn = on == true
end

function MovementService:RestoreAll()
	self:DisableWalkSpeed()
	self:DisableFly()
	self:SetInfiniteJump(false)
end

function MovementService:Destroy()
	self:RestoreAll()
end

return MovementService
