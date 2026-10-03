-- UniversalToolkit.Services.CrosshairService
-- Spec Phase 3 / §12: ScreenGui tabanlı özel crosshair (çizgi + nokta).
-- Drawing API'sine bağımlı değil, her ortamda çalışır.

local Players = game:GetService("Players")

local CrosshairService = {}
CrosshairService.Enabled = false
CrosshairService.Size = 12
CrosshairService.Gap = 6
CrosshairService.Thickness = 2
CrosshairService.Color = Color3.fromRGB(0, 255, 0)
CrosshairService.ShowDot = true
CrosshairService._gui = nil
CrosshairService._parts = {}

local function build()
	local lp = Players.LocalPlayer
	local parent = lp and lp:FindFirstChildOfClass("PlayerGui")
	if parent == nil then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "UTK_Crosshair"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9999
	local function bar(name)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = CrosshairService.Color
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Parent = gui
		return f
	end
	CrosshairService._parts = {
		Top = bar("Top"),
		Bottom = bar("Bottom"),
		Left = bar("Left"),
		Right = bar("Right"),
		Dot = bar("Dot"),
	}
	CrosshairService:Refresh()
	gui.Parent = parent
	return gui
end

function CrosshairService:Refresh()
	local p = self._parts
	if p.Top == nil then
		return
	end
	local s, g, t = self.Size, self.Gap, self.Thickness
	p.Top.Size = UDim2.fromOffset(t, s)
	p.Top.Position = UDim2.new(0.5, 0, 0.5, -(g + s / 2))
	p.Bottom.Size = UDim2.fromOffset(t, s)
	p.Bottom.Position = UDim2.new(0.5, 0, 0.5, (g + s / 2))
	p.Left.Size = UDim2.fromOffset(s, t)
	p.Left.Position = UDim2.new(0.5, -(g + s / 2), 0.5, 0)
	p.Right.Size = UDim2.fromOffset(s, t)
	p.Right.Position = UDim2.new(0.5, (g + s / 2), 0.5, 0)
	p.Dot.Size = UDim2.fromOffset(t, t)
	p.Dot.Position = UDim2.new(0.5, 0, 0.5, 0)
	p.Dot.Visible = self.ShowDot
	for _, f in pairs(p) do
		f.BackgroundColor3 = self.Color
	end
end

function CrosshairService:Enable()
	if self.Enabled then
		return
	end
	self.Enabled = true
	self._gui = build()
end

function CrosshairService:Disable()
	self.Enabled = false
	if self._gui ~= nil then
		pcall(function() self._gui:Destroy() end)
	end
	self._gui = nil
	self._parts = {}
end

function CrosshairService:Toggle()
	if self.Enabled then
		self:Disable()
		return false
	end
	self:Enable()
	return true
end

function CrosshairService:Destroy()
	self:Disable()
end

return CrosshairService
