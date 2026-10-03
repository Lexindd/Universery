-- UniversalToolkit.Services.CharacterService
-- Spec §26 + §27: local karakter yönetimi, respawn güvenliği.
-- Stale referans tutulmaz; her erişimde doğrulanır.

local Players = game:GetService("Players")

local CharacterService = {}
CharacterService._char = nil :: Model?
CharacterService._hum = nil :: Humanoid?
CharacterService._root = nil :: BasePart?
CharacterService._conns = nil
CharacterService._respawnCallbacks = {} :: { (() -> ()) }

local function resolveRefs(char: Model?)
	if char == nil then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if root ~= nil and not root:IsA("BasePart") then
		root = nil
	end
	return char, hum, root :: any
end

function CharacterService:Init(connections): boolean
	self._conns = connections
	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return false
	end

	local function refresh(char: Model?)
		self._char, self._hum, self._root = resolveRefs(char)
		for _, cb in ipairs(self._respawnCallbacks) do
			task.spawn(cb)
		end
	end

	-- Mevcut karakter varsa hemen bağla
	if localPlayer.Character ~= nil then
		refresh(localPlayer.Character)
	end

	local c1 = localPlayer.CharacterAdded:Connect(function(char)
		-- Humanoid tam yüklenmeden okumak hatalı olur, kısa bekle
		task.defer(function()
			-- CharacterAdded sonrası 0.5s beklemek respawn race'i önler
			task.wait(0.5)
			if localPlayer.Character == char then
				refresh(char)
			end
		end)
	end)
	local c2 = localPlayer.CharacterRemoving:Connect(function(_char)
		self._char = nil
		self._hum = nil
		self._root = nil
	end)

	if connections ~= nil and type(connections.Register) == "function" then
		connections:Register("Char_Added", c1)
		connections:Register("Char_Removing", c2)
	end
	return true
end

function CharacterService:OnRespawn(callback: () -> ())
	assert(type(callback) == "function", "callback required")
	table.insert(self._respawnCallbacks, callback)
end

function CharacterService:GetCharacter(): Model?
	local localPlayer = Players.LocalPlayer
	local live = localPlayer and localPlayer.Character
	if live ~= self._char then
		self._char, self._hum, self._root = resolveRefs(live)
	end
	return self._char
end

function CharacterService:GetHumanoid(): Humanoid?
	self:GetCharacter()
	if self._hum ~= nil and self._hum.Parent == nil then
		self._hum = nil
	end
	return self._hum
end

function CharacterService:GetRootPart(): BasePart?
	self:GetCharacter()
	if self._root ~= nil and self._root.Parent == nil then
		self._root = nil
	end
	-- Root kaybolmuşsa tekrar bulmayı dene
	if self._root == nil and self._char ~= nil then
		local found = self._char:FindFirstChild("HumanoidRootPart")
		if found ~= nil and found:IsA("BasePart") then
			self._root = found
		end
	end
	return self._root
end

function CharacterService:IsAlive(): boolean
	local hum = self:GetHumanoid()
	if hum == nil then
		return false
	end
	local ok, health = pcall(function()
		return hum.Health
	end)
	return ok and health > 0
end

function CharacterService:GetHealth(): (number, number)
	local hum = self:GetHumanoid()
	if hum == nil then
		return 0, 100
	end
	local okH, h = pcall(function() return hum.Health end)
	local okM, m = pcall(function() return hum.MaxHealth end)
	if not okH then h = 0 end
	if not okM then m = 100 end
	return h :: number, m :: number
end

function CharacterService:GetRigType(): string
	local hum = self:GetHumanoid()
	if hum == nil then
		return "Unknown"
	end
	local ok, rig = pcall(function()
		return hum.RigType.Name
	end)
	return (ok and rig) or "Unknown"
end

function CharacterService:Destroy()
	table.clear(self._respawnCallbacks)
	self._char = nil
	self._hum = nil
	self._root = nil
end

return CharacterService
