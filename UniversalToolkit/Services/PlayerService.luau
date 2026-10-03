-- UniversalToolkit.Services.PlayerService
-- Spec §8 + §25: oyuncu listesi, bilgi paneli, team/friend, whitelist/blacklist.
-- Roblox'un client'a verdiği verinin dışına çıkmaz (özel veri çekmez).

local Players = game:GetService("Players")

local PlayerService = {}
PlayerService._whitelist = {} :: { [number]: boolean }
PlayerService._blacklist = {} :: { [number]: boolean }
PlayerService._recent = {} :: { string }
PlayerService._conns = nil

local MAX_RECENT = 20

local function pushRecent(name: string)
	for i, n in ipairs(PlayerService._recent) do
		if n == name then
			table.remove(PlayerService._recent, i)
			break
		end
	end
	table.insert(PlayerService._recent, 1, name)
	while #PlayerService._recent > MAX_RECENT do
		table.remove(PlayerService._recent)
	end
end

function PlayerService:Init(connections): boolean
	self._conns = connections
	-- Mevcut oyuncuları recent'e işle
	for _, p in ipairs(Players:GetPlayers()) do
		pushRecent(p.Name)
	end
	local c1 = Players.PlayerAdded:Connect(function(p)
		pushRecent(p.Name)
	end)
	if connections ~= nil and type(connections.Register) == "function" then
		connections:Register("Player_Added", c1)
	end
	return true
end

function PlayerService:GetPlayers(excludeLocal: boolean?): { Player }
	local out = {}
	local localPlayer = Players.LocalPlayer
	for _, p in ipairs(Players:GetPlayers()) do
		if excludeLocal and p == localPlayer then
			continue
		end
		table.insert(out, p)
	end
	return out
end

function PlayerService:Count(): number
	local ok, n = pcall(function()
		return #Players:GetPlayers()
	end)
	return (ok and n) or 0
end

function PlayerService:FindByName(query: string): { Player }
	local out = {}
	if type(query) ~= "string" or #query < 1 then
		return out
	end
	local needle = string.lower(query)
	for _, p in ipairs(Players:GetPlayers()) do
		local ok, name = pcall(function() return p.Name end)
		local okD, disp = pcall(function() return p.DisplayName end)
		local hay = string.lower((ok and name or "") .. " " .. (okD and disp or ""))
		if string.find(hay, needle, 1, true) ~= nil then
			table.insert(out, p)
		end
	end
	return out
end

function PlayerService:GetInfo(player: Player): { [string]: any }
	local info: { [string]: any } = {
		Name = "?",
		DisplayName = "?",
		UserId = 0,
		Team = "-",
		Health = 0,
		MaxHealth = 100,
		Distance = -1,
		RigType = "Unknown",
	}
	pcall(function() info.Name = player.Name end)
	pcall(function() info.DisplayName = player.DisplayName end)
	pcall(function() info.UserId = player.UserId end)
	pcall(function()
		local t = player.Team
		info.Team = if t ~= nil then t.Name else "-"
	end)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum ~= nil then
		pcall(function() info.Health = hum.Health end)
		pcall(function() info.MaxHealth = hum.MaxHealth end)
		pcall(function() info.RigType = hum.RigType.Name end)
	end
	-- Distance: local root'e göre, karakter yoksa -1
	local lp = Players.LocalPlayer
	local lchar = lp and lp.Character
	local lroot = lchar and lchar:FindFirstChild("HumanoidRootPart")
	local troot = char and char:FindFirstChild("HumanoidRootPart")
	if lroot ~= nil and troot ~= nil and lroot:IsA("BasePart") and troot:IsA("BasePart") then
		pcall(function()
			info.Distance = (lroot.Position - troot.Position).Magnitude
		end)
	end
	return info
end

function PlayerService:IsFriend(player: Player): boolean
	-- Güvenli kontrol: API yoksa false (UNAVAILABLE yerine sessiz false).
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil or player == localPlayer then
		return false
	end
	-- Gerçek API: Player:IsFriendsWith(userId) bazı ortamlarda var.
	local ok, result = pcall(function()
		local fn = (player :: any).IsFriendsWith or (localPlayer :: any).IsFriendsWith
		if type(fn) == "function" then
			-- Hangi tarafta tanımlıysa onu kullan
			if (player :: any).IsFriendsWith ~= nil then
				return (player :: any):IsFriendsWith(localPlayer.UserId)
			else
				return (localPlayer :: any):IsFriendsWith(player.UserId)
			end
		end
		return false
	end)
	return ok and result == true
end

function PlayerService:IsSameTeam(player: Player): boolean
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil or player == localPlayer then
		return false
	end
	local ok, result = pcall(function()
		return localPlayer.Team ~= nil and localPlayer.Team == player.Team
	end)
	return ok and result == true
end

-- Whitelist / Blacklist (UserId tabanlı)
function PlayerService:AddWhitelist(userId: number)
	self._whitelist[userId] = true
end
function PlayerService:RemoveWhitelist(userId: number)
	self._whitelist[userId] = nil
end
function PlayerService:IsWhitelisted(userId: number): boolean
	return self._whitelist[userId] == true
end
function PlayerService:AddBlacklist(userId: number)
	self._blacklist[userId] = true
end
function PlayerService:RemoveBlacklist(userId: number)
	self._blacklist[userId] = nil
end
function PlayerService:IsBlacklisted(userId: number): boolean
	return self._blacklist[userId] == true
end

function PlayerService:GetRecent(): { string }
	return table.clone(self._recent)
end

function PlayerService:Destroy()
	table.clear(self._whitelist)
	table.clear(self._blacklist)
	table.clear(self._recent)
end

return PlayerService
