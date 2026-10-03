-- UniversalToolkit.Services.CameraService
-- Spec Phase 4 / §11: FOV slider + presetler + reset. Sadece client-side.

local Workspace = game:GetService("Workspace")

local CameraService = {}
CameraService._originalFOV = nil

local function camera()
	return Workspace.CurrentCamera
end

function CameraService:Init(_connections)
	local cam = camera()
	if cam ~= nil and self._originalFOV == nil then
		pcall(function() self._originalFOV = cam.FieldOfView end)
	end
	return true
end

function CameraService:SetFOV(value)
	local cam = camera()
	if cam == nil then
		return false
	end
	pcall(function() cam.FieldOfView = value end)
	return true
end

function CameraService:GetFOV()
	local cam = camera()
	if cam == nil then
		return 70
	end
	local v = 70
	pcall(function() v = cam.FieldOfView end)
	return v
end

function CameraService:Reset()
	if self._originalFOV ~= nil then
		self:SetFOV(self._originalFOV)
	end
end

function CameraService:Destroy()
	self:Reset()
end

return CameraService
