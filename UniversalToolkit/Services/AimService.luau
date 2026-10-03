-- UniversalToolkit.Services.AimService
-- Spec Phase 5 / §4: hold-to-aim kamera yardımı (izinli test ortamları için).
-- TargetingService'ten hedef alır, kamerayı yumuşakça hedefe döndürür.
-- Toggle/Hold + FOV limiti + Smoothness. Kendi scanner'ı yok.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local AimService = {}
AimService.Enabled = false
AimService.HoldKey = Enum.UserInputType.MouseButton2
AimService.Smoothness = 0.2
AimService.MaxFOV = 120
AimService._targeting = nil
AimService._conns = nil
AimService._holding = false

function AimService:Init(deps)
	self._targeting = deps and deps.TargetingService
	if deps and deps.Connections ~= nil then
		self._conns = deps.Connections
	end
	local cDown = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.UserInputType == self.HoldKey or input.KeyCode == self.HoldKey then
			self._holding = true
		end
	end)
	local cUp = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == self.HoldKey or input.KeyCode == self.HoldKey then
			self._holding = false
		end
	end)
	if self._conns ~= nil and type(self._conns.Register) == "function" then
		self._conns:Register("AimHoldDown", cDown)
		self._conns:Register("AimHoldUp", cUp)
	end
	return true
end

local function aimAt(dt)
	local cam = Workspace.CurrentCamera
	if cam == nil or AimService._targeting == nil then
		return
	end
	local target = AimService._targeting:GetClosestToCursor({ MaxFOV = AimService.MaxFOV, RequireVisible = true })
	if target == nil then
		return
	end
	local char = target.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local goal = CFrame.new(cam.CFrame.Position, head.Position)
	local alpha = math.clamp(AimService.Smoothness, 0.01, 1)
	cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end

function AimService:Enable()
	if self.Enabled then
		return
	end
	self.Enabled = true
	local loop = RunService.RenderStepped:Connect(function(dt)
		if self.Enabled and self._holding then
			local ok, err = pcall(aimAt, dt)
			if not ok then
				warn("[Aim] step failed: " .. tostring(err))
			end
		end
	end)
	if self._conns ~= nil and type(self._conns.Register) == "function" then
		self._conns:Register("AimLoop", loop)
	end
end

function AimService:Disable()
	self.Enabled = false
	self._holding = false
	if self._conns ~= nil then
		self._conns:Disconnect("AimLoop")
	end
end

function AimService:Toggle()
	if self.Enabled then
		self:Disable()
		return false
	end
	self:Enable()
	return true
end

function AimService:Destroy()
	self:Disable()
end

return AimService
