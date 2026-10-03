-- UniversalToolkit.Services.TargetingService
-- Spec §23 + §24 + §25: tek merkezi hedef motoru.
-- Combat özellikleri kendi scanner'ını yazmaz, burayı kullanır.
-- Döngü içermez (caller update rate'i belirler) -> performans kuralı §36.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

export type TargetOptions = {
	IgnoreFriends: boolean?,
	IgnoreTeam: boolean?,
	IgnoreDead: boolean?,
	MaxDistance: number?,
	MaxFOV: number?, -- piksel cinsinden crosshair yarıçapı
	RequireVisible: boolean?,
	TargetPart: string?, -- Head | HumanoidRootPart | Torso ...
	AllowSelf: boolean?,
}

local TargetingService = {}
TargetingService._playerSvc = nil
TargetingService._raycastSvc = nil
TargetingService._charSvc = nil
TargetingService.CurrentTarget = nil :: Player?
TargetingService.Priority = "Crosshair" :: string -- Crosshair | Distance | LowestHealth

local DEFAULT_OPTS: TargetOptions = {
	IgnoreFriends = true,
	IgnoreTeam = true,
	IgnoreDead = true,
	MaxDistance = 500,
	MaxFOV = 120,
	RequireVisible = true,
	TargetPart = "HumanoidRootPart",
	AllowSelf = false,
}

function TargetingService:Init(deps): boolean
	self._playerSvc = deps.PlayerService
	self._raycastSvc = deps.RaycastService
	self._charSvc = deps.CharacterService
	return self._playerSvc ~= nil
end

function TargetingService:SetPriority(mode: string)
	if mode == "Crosshair" or mode == "Distance" or mode == "LowestHealth" then
		self.Priority = mode
	end
end

function TargetingService:LockTarget(player: Player?)
	self.CurrentTarget = player
end

function TargetingService:Unlock()
	self.CurrentTarget = nil
end

local function getLocalRoot(): BasePart?
	local lp = Players.LocalPlayer
	local char = lp and lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getTargetRoot(player: Player, partName: string?): (BasePart?, Model?)
	local char = player.Character
	if char == nil then
		return nil, nil
	end
	local part: BasePart? = nil
	if type(partName) == "string" then
		local found = char:FindFirstChild(partName)
		if found ~= nil and found:IsA("BasePart") then
			part = found
		end
	end
	if part == nil then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp ~= nil and hrp:IsA("BasePart") then
			part = hrp
		end
	end
	return part, char
end

function TargetingService:IsValidTarget(player: Player, opts: TargetOptions?): boolean
	opts = opts or DEFAULT_OPTS
	if player == nil or player.Parent == nil then
		return false
	end
	local localPlayer = Players.LocalPlayer
	if player == localPlayer and not (opts :: TargetOptions).AllowSelf then
		return false
	end
	-- Blacklist her zaman eler, whitelist her zaman geçirir (ölü hariç değilse)
	if self._playerSvc ~= nil then
		if self._playerSvc:IsBlacklisted(player.UserId) then
			return false
		end
	end
	local char = player.Character
	if char == nil then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum == nil then
		return false
	end
	if (opts :: TargetOptions).IgnoreDead then
		local ok, hp = pcall(function() return hum.Health end)
		if not ok or hp <= 0 then
			return false
		end
	end
	if (opts :: TargetOptions).IgnoreTeam and self._playerSvc ~= nil then
		if self._playerSvc:IsSameTeam(player) then
			return false
		end
	end
	if (opts :: TargetOptions).IgnoreFriends and self._playerSvc ~= nil then
		if self._playerSvc:IsFriend(player) then
			-- Whitelist'li arkadaş yine de elenmesin mi? Spec: whitelist öncelikli.
			if not self._playerSvc:IsWhitelisted(player.UserId) then
				return false
			end
		end
	end
	-- Mesafe
	local maxD = (opts :: TargetOptions).MaxDistance or 500
	local lroot = getLocalRoot()
	local troot = char:FindFirstChild("HumanoidRootPart")
	if lroot ~= nil and troot ~= nil and troot:IsA("BasePart") then
		local d = (lroot.Position - (troot :: BasePart).Position).Magnitude
		if d > maxD then
			return false
		end
	end
	-- Görünürlük (pahalı, en son)
	if (opts :: TargetOptions).RequireVisible and self._raycastSvc ~= nil then
		if not self._raycastSvc:IsTargetVisible(char, (opts :: TargetOptions).TargetPart) then
			return false
		end
	end
	return true
end

local function screenDistToPlayer(player: Player, partName: string?): number?
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return nil
	end
	local part, _ = getTargetRoot(player, partName)
	if part == nil then
		return nil
	end
	local ok, vec, _onScreen = pcall(function()
		return cam:WorldToViewportPoint(part.Position)
	end)
	if not ok or _onScreen == false then
		return nil
	end
	local mouse: Vector2
	local okM, loc = pcall(function()
		return UserInputService:GetMouseLocation()
	end)
	if not okM then
		return nil
	end
	mouse = loc
	return (Vector2.new(vec.X, vec.Y) - mouse).Magnitude
end

local function worldDistToPlayer(player: Player): number
	local lroot = getLocalRoot()
	local part, _ = getTargetRoot(player, nil)
	if lroot == nil or part == nil then
		return math.huge
	end
	return (lroot.Position - part.Position).Magnitude
end

local function healthOf(player: Player): number
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum == nil then
		return math.huge
	end
	local ok, hp = pcall(function() return hum.Health end)
	return (ok and hp) or math.huge
end

-- Adayları topla (tek geçiş, FOV filtresi dahil)
local function collectCandidates(self, opts: TargetOptions): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if not self:IsValidTarget(p, opts) then
			continue
		end
		local maxFOV = (opts :: TargetOptions).MaxFOV
		if maxFOV ~= nil and self.Priority == "Crosshair" then
			local sd = screenDistToPlayer(p, (opts :: TargetOptions).TargetPart)
			if sd == nil or sd > maxFOV then
				continue
			end
		end
		table.insert(out, p)
	end
	return out
end

function TargetingService:GetClosestPlayer(opts: TargetOptions?): Player?
	opts = opts or DEFAULT_OPTS
	local best: Player? = nil
	local bestD = math.huge
	for _, p in ipairs(collectCandidates(self, opts)) do
		local d = worldDistToPlayer(p)
		if d < bestD then
			bestD = d
			best = p
		end
	end
	return best
end

function TargetingService:GetClosestToCursor(opts: TargetOptions?): Player?
	opts = opts or DEFAULT_OPTS
	local best: Player? = nil
	local bestD = math.huge
	for _, p in ipairs(collectCandidates(self, opts)) do
		local sd = screenDistToPlayer(p, (opts :: TargetOptions).TargetPart)
		if sd ~= nil and sd < bestD then
			bestD = sd
			best = p
		end
	end
	return best
end

function TargetingService:GetClosestVisibleTarget(opts: TargetOptions?): Player?
	local merged: TargetOptions = table.clone(DEFAULT_OPTS)
	if opts ~= nil then
		for k, v in pairs(opts) do
			(merged :: any)[k] = v
		end
	end
	merged.RequireVisible = true
	return self:GetClosestToCursor(merged)
end

function TargetingService:GetBestTarget(opts: TargetOptions?): Player?
	return self:GetTargetByPriority(self.Priority, opts)
end

function TargetingService:GetTargetByPriority(mode: string, opts: TargetOptions?): Player?
	opts = opts or DEFAULT_OPTS
	if mode == "Distance" then
		return self:GetClosestPlayer(opts)
	elseif mode == "LowestHealth" then
		local best: Player? = nil
		local bestH = math.huge
		for _, p in ipairs(collectCandidates(self, opts)) do
			local h = healthOf(p)
			if h < bestH then
				bestH = h
				best = p
			end
		end
		return best
	else
		-- Crosshair (varsayılan)
		return self:GetClosestToCursor(opts)
	end
end

function TargetingService:Destroy()
	self.CurrentTarget = nil
	self._playerSvc = nil
	self._raycastSvc = nil
	self._charSvc = nil
end

return TargetingService
