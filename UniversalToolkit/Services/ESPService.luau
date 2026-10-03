-- UniversalToolkit.Services.ESPService
-- Spec Phase 3 / §6: Highlight + Billboard tabanlı oyuncu ESP'si.
-- Saf Roblox API (Highlight, BillboardGui). Drawing kütüphanesi gerekmez.
-- Düşük frekanslı yenileme (0.25s), mesafe filtresi, takım renkleri.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ESPService = {}
ESPService.Enabled = false
ESPService.MaxDistance = 500
ESPService.UseTeamColors = true
ESPService.CustomColor = Color3.fromRGB(255, 255, 255)
ESPService._folder = nil
ESPService._conns = nil
ESPService._running = false

local function getFolder()
	if ESPService._folder ~= nil and ESPService._folder.Parent ~= nil then
		return ESPService._folder
	end
	local f = Instance.new("Folder")
	f.Name = "UTK_ESP"
	f.Parent = Workspace
	ESPService._folder = f
	return f
end

local function localRoot()
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function pickColor(player)
	if ESPService.UseTeamColors then
		local ok, teamColor = pcall(function()
			return player.TeamColor.Color
		end)
		if ok and teamColor ~= nil then
			return teamColor
		end
	end
	return ESPService.CustomColor
end

local function rebuild()
	local folder = getFolder()
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
	if not ESPService.Enabled then
		return
	end
	local lr = localRoot()
	for _, p in ipairs(Players:GetPlayers()) do
		if p == Players.LocalPlayer then
			continue
		end
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum == nil then
			continue
		end
		local hpOk, hp = pcall(function() return hum.Health end)
		if not hpOk or hp <= 0 then
			continue
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local dist = -1
		if lr ~= nil and hrp ~= nil and hrp:IsA("BasePart") then
			dist = (lr.Position - hrp.Position).Magnitude
			if dist > ESPService.MaxDistance then
				continue
			end
		end
		local color = pickColor(p)
		local hl = Instance.new("Highlight")
		hl.Name = "ESP_" .. p.Name
		hl.Adornee = char
		hl.FillColor = color
		hl.FillTransparency = 0.6
		hl.OutlineColor = color
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = folder
		local head = char:FindFirstChild("Head")
		if head ~= nil and head:IsA("BasePart") then
			local bb = Instance.new("BillboardGui")
			bb.Name = "ESPLabel_" .. p.Name
			bb.Adornee = head
			bb.Size = UDim2.fromOffset(120, 32)
			bb.StudsOffset = Vector3.new(0, 1.5, 0)
			bb.AlwaysOnTop = true
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 12
			label.TextStrokeTransparency = 0.5
			label.TextColor3 = color
			label.Text = p.DisplayName .. " (" .. math.floor(dist) .. "m)"
			label.Parent = bb
			bb.Parent = folder
		end
	end
end

function ESPService:Init(connections)
	self._conns = connections
	return true
end

function ESPService:Enable()
	if self.Enabled then
		return
	end
	self.Enabled = true
	self._running = true
	rebuild()
	task.spawn(function()
		while self._running do
			task.wait(0.25)
			if not self._running then
				break
			end
			local ok, err = pcall(rebuild)
			if not ok then
				warn("[ESP] refresh failed: " .. tostring(err))
			end
		end
	end)
end

function ESPService:Disable()
	self.Enabled = false
	self._running = false
	if self._folder ~= nil then
		pcall(function() self._folder:Destroy() end)
		self._folder = nil
	end
end

function ESPService:Toggle()
	if self.Enabled then
		self:Disable()
		return false
	end
	self:Enable()
	return true
end

function ESPService:Count()
	if self._folder == nil then
		return 0
	end
	return #self._folder:GetChildren()
end

function ESPService:Destroy()
	self:Disable()
end

return ESPService
