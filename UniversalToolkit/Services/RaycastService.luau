-- UniversalToolkit.Services.RaycastService
-- Spec §22: tek paylaşılan görünürlük modülü. Her özellik kendi raycast'ini yazmaz.
-- Ignore: local karakter + hedef karakter. Debug ışınları opsiyonel.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RaycastService = {}
RaycastService.DebugRays = false

local function buildParams(ignore: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	-- CanQuery=false olan dekoratif parçaları atlamak için RespectCanCollide kullanma;
	-- duvar kontrolü için varsayılan collision grubunu kullan.
	if #ignore > 0 then
		params.FilterDescendantsInstances = ignore
	end
	return params
end

local function getIgnoreList(extraTarget: Model?): { Instance }
	local list: { Instance } = {}
	local lp = Players.LocalPlayer
	if lp ~= nil and lp.Character ~= nil then
		table.insert(list, lp.Character)
	end
	if extraTarget ~= nil then
		table.insert(list, extraTarget)
	end
	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		table.insert(list, cam)
	end
	return list
end

function RaycastService:SetDebug(enabled: boolean)
	self.DebugRays = enabled == true
end

-- Genel ışın: origin -> direction (direction vektörü uzunluk içerir)
function RaycastService:Cast(origin: Vector3, direction: Vector3, ignore: { Instance }?): RaycastResult?
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	if direction.Magnitude < 0.001 then
		return nil
	end
	local ok, result = pcall(function()
		return Workspace:Raycast(origin, direction, buildParams(ignore or getIgnoreList(nil)))
	end)
	if not ok then
		return nil
	end
	return result
end

-- İki nokta arası engel var mı? Yoksa true (temiz görüş).
function RaycastService:HasLineOfSight(from: Vector3, to: Vector3, targetModel: Model?): boolean
	local dir = to - from
	local dist = dir.Magnitude
	if dist < 0.001 then
		return true
	end
	local result = self:Cast(from, dir, getIgnoreList(targetModel))
	-- Çarpma yoksa temiz. Çarpma hedef modele çok yakınsa da temiz say.
	if result == nil then
		return true
	end
	-- Çarpma noktası hedefe 2 stud'dan yakınsa engel sayma (hedefin kendi uzvu)
	local hitPos = result.Position
	return (hitPos - to).Magnitude <= 2
end

function RaycastService:IsTargetVisible(targetCharacter: Model, targetPartName: string?): boolean
	if targetCharacter == nil or targetCharacter.Parent == nil then
		return false
	end
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return false
	end
	local part: BasePart? = nil
	if type(targetPartName) == "string" then
		local found = targetCharacter:FindFirstChild(targetPartName)
		if found ~= nil and found:IsA("BasePart") then
			part = found
		end
	end
	if part == nil then
		local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
		if hrp ~= nil and hrp:IsA("BasePart") then
			part = hrp
		else
			local head = targetCharacter:FindFirstChild("Head")
			if head ~= nil and head:IsA("BasePart") then
				part = head
			end
		end
	end
	if part == nil then
		return false
	end
	return self:HasLineOfSight(cam.CFrame.Position, (part :: BasePart).Position, targetCharacter)
end

return RaycastService
