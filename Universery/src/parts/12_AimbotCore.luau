--// Core Functions

local FixUsername = LPH_NO_VIRTUALIZE(function(String)
	for _, Value in next, GetPlayers(Players) do
		local Name = __index(Value, "Name")

		if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
			return Name
		end
	end
end)

local GetRainbowColor = LPH_NO_VIRTUALIZE(function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed

	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end)

local ConvertVector = LPH_NO_VIRTUALIZE(function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end)

-- Universal Team Resolver (multi-source). Native Roblox Teams are preserved and
-- checked first; custom sources engage only when native data is LowInformation
-- (everyone same/neutral) or when the user forces a mode. Never invents a team:
-- unknown sources yield Known=false, and strict mode ignores unknown targets.
-- Only IsSameTeam() implements team logic; the rest of the aimbot never does.
local TEAM_ATTR_NAMES = { Team = true, TeamId = true, TeamID = true, TeamName = true, Faction = true, FactionId = true, FactionID = true, FactionName = true, Side = true, SideId = true, SideID = true, Squad = true, SquadId = true, SquadID = true, Group = true, GroupId = true, GroupID = true, Alliance = true, AllianceId = true, AllianceID = true, Allegiance = true, Camp = true, CampId = true, CampID = true }
local ROLE_DENY = { Role = true, RoleName = true, Class = true, Job = true, Kit = true, Loadout = true, Weapon = true, Perk = true, Character = true, Skin = true, Title = true }
local STAT_DENY = { Level = true, Kills = true, Deaths = true, Cash = true, Money = true, Coins = true, Health = true, MaxHealth = true, Speed = true, WalkSpeed = true, JumpPower = true, Score = true, Points = true, XP = true, Experience = true, Streak = true, Damage = true, Stage = true, Wins = true, Losses = true, PlayTime = true, Age = true, Value = true }

local TeamCache = {}
local TeamHooked = {}
local TeamRanking = { Attr = {}, Value = {}, Tag = {}, NativeDiverse = false, Time = 0 }

local TeamCS = nil
pcall(function() TeamCS = GetService("CollectionService") end)

local function NormTeamId(v, cfg)
	local t = type(v)
	if t == "number" then
		return "N:" .. tostring(v)
	end
	if t == "string" then
		if cfg == nil or cfg.NormalizeCase ~= false then
			v = stringlower(v)
		end
		return "S:" .. v
	end
	if t == "boolean" then
		return "B:" .. tostring(v)
	end
	if typeof(v) == "BrickColor" then
		return "C:" .. v.Name
	end
	if typeof(v) == "Color3" then
		return "C:" .. tostring(mathfloor(v.R * 255)) .. "," .. tostring(mathfloor(v.G * 255)) .. "," .. tostring(mathfloor(v.B * 255))
	end
	if typeof(v) == "Instance" then
		local n = "?"
		pcall(function() n = v.Name end)
		return "I:" .. tostring(n)
	end
	return nil
end

local function IsSpectatorName(name, cfg)
	if type(name) ~= "string" then
		return false
	end
	local needle = stringlower(name)
	local list = (cfg ~= nil and cfg.SpectatorNames) or { "Spectator", "Lobby", "Waiting" }
	for _, s in next, list do
		if type(s) == "string" and stringlower(s) == needle then
			return true
		end
	end
	return false
end

local function ReadAttr(inst, name)
	if inst == nil or type(name) ~= "string" or #name < 1 then
		return nil
	end
	local ok, val = pcall(function() return __index(inst, "GetAttribute")(inst, name) end)
	if ok then
		return val
	end
	return nil
end

local function ReadAttrBoth(player, name)
	local v = ReadAttr(player, name)
	if v ~= nil then
		return v
	end
	local okC, char = pcall(function() return __index(player, "Character") end)
	if okC and char ~= nil then
		return ReadAttr(char, name)
	end
	return nil
end

local function ReadValuePath(rootPlayer, path)
	if type(path) ~= "string" or #path < 1 then
		return nil
	end
	local okC, char = pcall(function() return __index(rootPlayer, "Character") end)
	local node = rootPlayer
	for part in string.gmatch(path, "[^.]+") do
		if part == "Character" and node == rootPlayer then
			node = (okC and char) or nil
		else
			if node == nil then
				return nil
			end
			local okF, child = pcall(function() return FindFirstChild(node, part) end)
			if not okF or child == nil then
				return nil
			end
			node = child
		end
	end
	if node == nil then
		return nil
	end
	local okV, val = pcall(function()
		if __index(node, "IsA")(node, "ValueBase") then
			return __index(node, "Value")
		end
		return nil
	end)
	if okV then
		return val
	end
	return nil
end

local function ReadTags(player)
	local out = {}
	if TeamCS == nil then
		return out
	end
	local function grab(inst)
		if inst == nil then
			return
		end
		local okT, tags = pcall(function() return __index(TeamCS, "GetTags")(TeamCS, inst) end)
		if okT and type(tags) == "table" then
			for _, t in next, tags do
				out[#out + 1] = t
			end
		end
	end
	grab(player)
	local okC, char = pcall(function() return __index(player, "Character") end)
	if okC then
		grab(char)
	end
	return out
end

local function TagTeamId(tag)
	if type(tag) ~= "string" then
		return nil
	end
	for _, pre in next, { "Team_", "Faction_", "Side_", "Squad_" } do
		if stringsub(tag, 1, #pre) == pre then
			local suf = stringsub(tag, #pre + 1)
			if #suf > 0 then
				return "S:" .. stringlower(suf), 0.75
			end
		end
	end
	if tag == "Enemy" then
		return "__enemy__", 0.7
	end
	if tag == "Ally" then
		return "__ally__", 0.7
	end
	return nil
end

local function RankConfidence(distinct, coverage)
	local base = 0.15
	if distinct >= 2 and distinct <= 4 then
		base = 0.95
	elseif distinct <= 8 then
		base = 0.8
	elseif distinct > 8 then
		base = 0.4
	end
	return base * coverage
end

-- Cross-player consistency analysis (slow gate): an attribute/value/tag is only
-- trusted as a team source when its values actually separate players.
local AnalyzeSources = LPH_NO_VIRTUALIZE(function(Force)
	local cfg = Environment.TeamResolver
	local now = tick()
	if not Force and (now - TeamRanking.Time) < (cfg.ReanalyzeRate or 5) then
		return
	end
	TeamRanking = { Attr = {}, Value = {}, Tag = {}, NativeDiverse = false, Time = now }
	local players = {}
	for _, p in next, GetPlayers(Players) do
		players[#players + 1] = p
	end
	if #players < 1 then
		return
	end

	local attrVals, attrCov = {}, {}
	local valVals, valCov = {}, {}
	local tagVals, tagCov = {}, {}
	local nativeSet, nativeCount = {}, 0

	local function tally(t, cov, key, normId)
		if normId == nil then
			return
		end
		if t[key] == nil then
			t[key] = {}
		end
		t[key][normId] = (t[key][normId] or 0) + 1
		cov[key] = (cov[key] or 0) + 1
	end

	for _, p in next, players do
		-- native diversity
		local okT, team = pcall(function() return __index(p, "Team") end)
		if okT and team ~= nil then
			local okN, tname = pcall(function() return __index(team, "Name") end)
			if okN and tname ~= nil then
				if nativeSet[tname] == nil then
					nativeSet[tname] = true
					nativeCount = nativeCount + 1
				end
			end
		end
		-- attributes (player + character)
		local seen = {}
		local function scanAttrs(inst)
			if inst == nil then
				return
			end
			local okA, attrs = pcall(function() return __index(inst, "GetAttributes")(inst) end)
			if not okA or type(attrs) ~= "table" then
				return
			end
			for k, v in next, attrs do
				if TEAM_ATTR_NAMES[k] and not ROLE_DENY[k] and not STAT_DENY[k] and seen[k] == nil then
					seen[k] = true
					tally(attrVals, attrCov, k, NormTeamId(v, cfg))
				end
			end
		end
		scanAttrs(p)
		local okC, char = pcall(function() return __index(p, "Character") end)
		if okC then
			scanAttrs(char)
		end
		-- value objects: direct children + one-level Data-style containers
		local function scanValues(inst, prefix)
			if inst == nil then
				return
			end
			local okK, kids = pcall(function() return __index(inst, "GetChildren")(inst) end)
			if not okK or type(kids) ~= "table" then
				return
			end
			for _, child in next, kids do
				local okN, cname = pcall(function() return __index(child, "Name") end)
				if okN and type(cname) == "string" then
					local okV, isV = pcall(function() return __index(child, "IsA")(child, "ValueBase") end)
					if okV and isV then
						if TEAM_ATTR_NAMES[cname] and not ROLE_DENY[cname] and not STAT_DENY[cname] then
							local okVal, vv = pcall(function() return __index(child, "Value") end)
							if okVal then
								tally(valVals, valCov, prefix .. cname, NormTeamId(vv, cfg))
							end
						end
					elseif prefix == "" and (cname == "Data" or cname == "PlayerData" or cname == "Stats" or cname == "leaderstats" or cname == "Values") then
						scanValues(child, cname .. ".")
					end
				end
			end
		end
		scanValues(p, "")
		local okC2, char2 = pcall(function() return __index(p, "Character") end)
		if okC2 and char2 ~= nil then
			scanValues(char2, "Character.")
		end
		-- tags
		local seenPre = {}
		for _, tag in next, ReadTags(p) do
			for _, pre in next, { "Team_", "Faction_", "Side_", "Squad_" } do
				if type(tag) == "string" and stringsub(tag, 1, #pre) == pre then
					local suf = stringsub(tag, #pre + 1)
					if #suf > 0 and seenPre[pre] == nil then
						seenPre[pre] = true
						tally(tagVals, tagCov, pre, "S:" .. stringlower(suf))
					end
				end
			end
		end
	end

	TeamRanking.NativeDiverse = nativeCount > 1
	local function rankInto(t, cov, dest)
		for key, set in next, t do
			local distinct = 0
			for _ in next, set do
				distinct = distinct + 1
			end
			local coverage = (cov[key] or 0) / #players
			dest[#dest + 1] = { Key = key, Conf = RankConfidence(distinct, coverage), Distinct = distinct }
		end
		table.sort(dest, function(a, b) return a.Conf > b.Conf end)
	end
	rankInto(attrVals, attrCov, TeamRanking.Attr)
	rankInto(valVals, valCov, TeamRanking.Value)
	rankInto(tagVals, tagCov, TeamRanking.Tag)
end)

local function ClearTeamCache(Player)
	local okU, uid = pcall(function() return __index(Player, "UserId") end)
	if okU and uid ~= nil then
		TeamCache[uid] = nil
	end
end

-- One-time invalidation hooks per player (native team / neutral / attributes).
local HookTeamInvalidation = LPH_NO_VIRTUALIZE(function(Player)
	local okU, uid = pcall(function() return __index(Player, "UserId") end)
	if not okU or uid == nil or TeamHooked[uid] then
		return
	end
	TeamHooked[uid] = true
	local function clearIt()
		TeamCache[uid] = nil
	end
	pcall(function()
		Connect(__index(Player, "GetPropertyChangedSignal")(Player, "Team"), clearIt)
	end)
	pcall(function()
		Connect(__index(Player, "GetPropertyChangedSignal")(Player, "TeamColor"), clearIt)
	end)
	pcall(function()
		Connect(__index(Player, "GetPropertyChangedSignal")(Player, "Neutral"), clearIt)
	end)
	pcall(function()
		Connect(__index(Player, "AttributeChanged"), LPH_NO_VIRTUALIZE(function() clearIt() end))
	end)
end)

local function CustomSourcesExist()
	local adapter = Environment.GameAdapter
	if type(adapter) == "table" and type(adapter.GetTeam) == "function" then
		return true
	end
	local cfg = Environment.TeamResolver
	if (cfg.ManualAttribute ~= nil and cfg.ManualAttribute ~= "") or (cfg.ManualValuePath ~= nil and cfg.ManualValuePath ~= "") then
		return true
	end
	AnalyzeSources(false)
	local th = cfg.ConfidenceThreshold or 0.6
	if #TeamRanking.Attr > 0 and TeamRanking.Attr[1].Conf >= th then
		return true
	end
	if #TeamRanking.Value > 0 and TeamRanking.Value[1].Conf >= th then
		return true
	end
	if #TeamRanking.Tag > 0 and TeamRanking.Tag[1].Conf >= th then
		return true
	end
	return false
end

-- Central resolver. Returns {TeamId, TeamName, TeamColor, Source, Confidence, Known}.
local ResolveTeamInfo = LPH_NO_VIRTUALIZE(function(Player)
	HookTeamInvalidation(Player)
	local cfg = Environment.TeamResolver
	local now = tick()
	local okU, uid = pcall(function() return __index(Player, "UserId") end)
	local ckey = (okU and uid) or nil
	if ckey ~= nil then
		local hit = TeamCache[ckey]
		if hit ~= nil and (now - (hit.T or 0)) < (cfg.CacheTTL or 1) then
			return hit
		end
	end
	local info = { Known = false, Source = "Unknown", Confidence = 0, TeamId = nil, TeamName = nil, TeamColor = nil, T = now }
	local function commit()
		if ckey ~= nil then
			TeamCache[ckey] = info
		end
		return info
	end
	local mode = cfg.Mode or "Auto"
	if mode == "Disabled" then
		return commit()
	end

	-- 1. Explicit game adapter (highest priority).
	local adapter = Environment.GameAdapter
	if (mode == "Auto" or mode == "GameAdapter") and type(adapter) == "table" and type(adapter.GetTeam) == "function" then
		local okA, res = pcall(function() return adapter:GetTeam(Player) end)
		if okA and type(res) == "table" and res.TeamId ~= nil and NormTeamId(res.TeamId, cfg) ~= nil then
			info.Known = true
			info.Source = "GameAdapter"
			info.Confidence = 1.0
			info.TeamId = NormTeamId(res.TeamId, cfg)
			info.TeamName = res.TeamName or res.TeamId
			info.TeamColor = res.TeamColor
			return commit()
		end
		if mode == "GameAdapter" then
			return commit()
		end
	end

	-- 2. Explicit user-configured source.
	if cfg.ManualAttribute ~= nil and cfg.ManualAttribute ~= "" then
		local v = ReadAttrBoth(Player, cfg.ManualAttribute)
		local nid = NormTeamId(v, cfg)
		if v ~= nil and nid ~= nil then
			info.Known = true
			info.Source = "Manual:" .. cfg.ManualAttribute
			info.Confidence = 0.98
			info.TeamId = nid
			info.TeamName = v
			return commit()
		end
	end
	if cfg.ManualValuePath ~= nil and cfg.ManualValuePath ~= "" then
		local v = ReadValuePath(Player, cfg.ManualValuePath)
		local nid = NormTeamId(v, cfg)
		if v ~= nil and nid ~= nil then
			info.Known = true
			info.Source = "ManualPath:" .. cfg.ManualValuePath
			info.Confidence = 0.98
			info.TeamId = nid
			info.TeamName = v
			return commit()
		end
	end
	if mode == "Manual" then
		return commit()
	end

	-- 3. Native Roblox Team (authoritative ONLY when meaningful).
	if mode == "Auto" or mode == "Native" then
		local okT, team = pcall(function() return __index(Player, "Team") end)
		local okN, neutral = pcall(function() return __index(Player, "Neutral") end)
		if okN and neutral == true then
			team = nil
		end
		local okC, tcolor = pcall(function() return __index(Player, "TeamColor") end)
		if mode == "Native" then
			if okT and team ~= nil then
				local okTN, tname = pcall(function() return __index(team, "Name") end)
				if okTN and tname ~= nil then
					info.Known = true
					info.Source = "Native"
					info.Confidence = 1.0
					info.TeamId = NormTeamId(tname, cfg)
					info.TeamName = tname
					info.TeamColor = okC and tcolor or nil
				end
			elseif okC and tcolor ~= nil then
				info.Known = true
				info.Source = "NativeColor"
				info.Confidence = 0.9
				info.TeamId = NormTeamId(tcolor, cfg)
				info.TeamName = tcolor.Name
				info.TeamColor = tcolor
			end
			return commit()
		end
		AnalyzeSources(false)
		if TeamRanking.NativeDiverse then
			if okT and team ~= nil then
				local okTN, tname = pcall(function() return __index(team, "Name") end)
				if okTN and tname ~= nil then
					info.Known = true
					info.Source = "Native"
					info.Confidence = 1.0
					info.TeamId = NormTeamId(tname, cfg)
					info.TeamName = tname
					info.TeamColor = okC and tcolor or nil
					return commit()
				end
			end
		end
		-- else: LowInformation -> keep investigating custom sources.
	end

	AnalyzeSources(false)
	local th = cfg.ConfidenceThreshold or 0.6
	local function useKind(kind, list)
		if (mode == "Auto" or mode == kind) and #list > 0 and list[1].Conf >= th then
			return list[1]
		end
		return nil
	end
	local wantAttr = (mode == "Auto" or mode == "Attributes") and useKind("Attributes", TeamRanking.Attr) or nil
	if wantAttr ~= nil then
		local v = ReadAttrBoth(Player, wantAttr.Key)
		local nid = NormTeamId(v, cfg)
		if v ~= nil and nid ~= nil then
			info.Known = true
			info.Source = "Attribute:" .. wantAttr.Key
			info.Confidence = mathclamp(wantAttr.Conf, 0, 0.95)
			info.TeamId = nid
			info.TeamName = v
			return commit()
		end
	end
	local wantVal = (mode == "Auto" or mode == "Values") and useKind("Values", TeamRanking.Value) or nil
	if wantVal ~= nil then
		local rel = wantVal.Key
		local v = nil
		if stringsub(rel, 1, 10) == "Character." then
			local okC, char = pcall(function() return __index(Player, "Character") end)
			if okC and char ~= nil then
				v = ReadValuePath(Player, rel)
			end
		else
			v = ReadValuePath(Player, rel)
		end
		local nid = NormTeamId(v, cfg)
		if v ~= nil and nid ~= nil then
			info.Known = true
			info.Source = "Value:" .. rel
			info.Confidence = mathclamp(wantVal.Conf, 0, 0.9)
			info.TeamId = nid
			info.TeamName = v
			return commit()
		end
	end
	if mode == "Auto" or mode == "Tags" then
		local best = useKind("Tags", TeamRanking.Tag)
		for _, tag in next, ReadTags(Player) do
			local tid, tconf = TagTeamId(tag)
			if tid ~= nil then
				if best ~= nil then
					for _, pre in next, { "Team_", "Faction_", "Side_", "Squad_" } do
						if stringsub(tag, 1, #pre) == pre and best.Key == pre then
							info.Known = true
							info.Source = "Tag:" .. tag
							info.Confidence = mathclamp(best.Conf, 0, 0.8)
							info.TeamId = tid
							info.TeamName = tag
							return commit()
						end
					end
				end
				if tag == "Enemy" or tag == "Ally" then
					info.Known = true
					info.Source = "Tag:" .. tag
					info.Confidence = tconf
					info.TeamId = tid
					info.TeamName = tag
					return commit()
				end
			end
		end
	end
	return commit()
end)

-- Legacy native-only comparison (exact old semantics). Used when the resolver has
-- no knowledge AND no custom sources exist anywhere (pure native/neutral game).
local LegacyPairTeammates = LPH_NO_VIRTUALIZE(function(A, B)
	local Settings = Environment.Settings
	local TA, TB
	pcall(function() TA = __index(A, "Team") end)
	pcall(function() TB = __index(B, "Team") end)
	if TA ~= nil and TB ~= nil then
		return TA == TB
	end
	if Settings.UseTeamColorFallback then
		local CA, CB
		pcall(function() CA = __index(A, "TeamColor") end)
		pcall(function() CB = __index(B, "TeamColor") end)
		if CA ~= nil and CB ~= nil then
			return CA == CB
		end
	end
	return false
end)

-- THE single team-relationship function. Everything else delegates here.
local IsSameTeam = LPH_NO_VIRTUALIZE(function(A, B)
	if A == B then
		return true
	end
	local cfg = Environment.TeamResolver
	local infoA = ResolveTeamInfo(A)
	local infoB = ResolveTeamInfo(B)
	-- Spectator / lobby / waiting states are never enemies.
	if cfg.IgnoreSpectators ~= false then
		if (type(infoA.TeamName) == "string" and IsSpectatorName(infoA.TeamName, cfg)) or (type(infoB.TeamName) == "string" and IsSpectatorName(infoB.TeamName, cfg)) then
			return true
		end
	end
	-- Same compatible source: compare normalized identifiers.
	if infoA.Known and infoB.Known and infoA.Source == infoB.Source then
		if infoA.TeamId == "__enemy__" or infoB.TeamId == "__enemy__" then
			return infoA.TeamId == "__ally__" and infoB.TeamId == "__ally__"
		end
		return infoA.TeamId == infoB.TeamId
	end
	-- Incomplete knowledge: legacy path only when NO custom source exists at all.
	if not CustomSourcesExist() then
		return LegacyPairTeammates(A, B)
	end
	-- Strict by default: unknown custom-team target is skipped.
	if cfg.UnknownBehavior == "Target" then
		return false
	end
	return true
end)

-- Team Check (nil-safe). Thin wrapper now; all logic lives in IsSameTeam.
local IsTeammate = LPH_NO_VIRTUALIZE(function(Player)
	local Settings = Environment.Settings

	if Player == LocalPlayer then
		return true
	end

	if not Settings.TeamCheck then
		return false
	end

	return IsSameTeam(LocalPlayer, Player)
end)

local IsNeutral = LPH_NO_VIRTUALIZE(function(Player)
	local Team
	pcall(function() Team = __index(Player, "Team") end)
	return Team == nil
end)

-- Friend list: one-time async build via the real Friends API, refreshed slowly.
local RefreshFriends = LPH_NO_VIRTUALIZE(function()
	if FriendAPIUnavailable then
		return
	end
	local ok, err = pcall(function()
		local pages = __index(Players, "GetFriendsAsync")(Players, __index(LocalPlayer, "UserId"))
		while true do
			local items = pages:GetCurrentPage()
			for _, item in next, items do
				if item and item.Id then
					FriendSet[item.Id] = true
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		FriendAPIUnavailable = true
		warn("Aimbot: Friends API unavailable, Friend Check passes through (" .. tostring(err) .. ")")
	end
	FriendSetTime = tick()
end)

local IsFriend = LPH_NO_VIRTUALIZE(function(Player)
	if not Environment.Settings.FriendCheck then
		return false
	end
	if Player == LocalPlayer then
		return false
	end
	if FriendAPIUnavailable then
		return false
	end
	local id
	pcall(function() id = __index(Player, "UserId") end)
	return id ~= nil and FriendSet[id] == true
end)

-- Single character lookup reused by validation/scoring (no repeated hierarchy walks).
local GetCharacterData = LPH_NO_VIRTUALIZE(function(Player)
	local Character
	pcall(function() Character = __index(Player, "Character") end)
	if Character == nil then
		return nil
	end
	local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
	local RootPart = FindFirstChild(Character, "HumanoidRootPart")
	if Humanoid == nil or RootPart == nil then
		return nil
	end
	return Character, Humanoid, RootPart
end)

-- Target-part resolution per PartMode. Never errors on missing parts.
local ResolveAimPart = LPH_NO_VIRTUALIZE(function(Character)
	local Settings = Environment.Settings
	local Mode = Settings.PartMode or "Static"

	if Mode == "PriorityList" then
		local list = Settings.TargetParts
		if type(list) == "table" then
			for _, PartName in next, list do
				local part = FindFirstChild(Character, PartName)
				if part ~= nil then
					local okPos, pos = pcall(function() return __index(part, "Position") end)
					if okPos and pos ~= nil then
						return part, pos
					end
				end
			end
		end
		return nil, nil
	end

	if Mode == "ClosestToCursor" or Mode == "ClosestVisible" then
		local list = Settings.TargetParts
		local bestPart, bestPos, bestDist = nil, nil, mathhuge
		local mousePos = GetMouseLocation(UserInputService)
		if type(list) == "table" then
			for _, PartName in next, list do
				local part = FindFirstChild(Character, PartName)
				if part ~= nil then
					local okPos, pos = pcall(function() return __index(part, "Position") end)
					if okPos and pos ~= nil then
						if Mode == "ClosestVisible" then
							local vis = CheckVisibilityCached(pos, Character)
							if not vis then
								-- skip obstructed parts in this mode
							else
								local okV, vec, onScreen = pcall(function() return WorldToViewportPoint(Camera, pos) end)
								if okV and onScreen then
									local d = (mousePos - ConvertVector(vec)).Magnitude
									if d < bestDist then
										bestPart, bestPos, bestDist = part, pos, d
									end
								end
							end
						else
							local okV, vec, onScreen = pcall(function() return WorldToViewportPoint(Camera, pos) end)
							if okV and onScreen then
								local d = (mousePos - ConvertVector(vec)).Magnitude
								if d < bestDist then
									bestPart, bestPos, bestDist = part, pos, d
								end
							end
						end
					end
				end
			end
		end
		return bestPart, bestPos
	end

	-- Static (legacy LockPart behavior, read live so runtime config changes apply).
	local part = FindFirstChild(Character, Settings.LockPart)
	if part == nil then
		return nil, nil
	end
	local okPos, pos = pcall(function() return __index(part, "Position") end)
	if not okPos or pos == nil then
		return nil, nil
	end
	return part, pos
end)

-- Cached visibility: short-lived, invalidated by TTL. One shared pipeline.
CheckVisibilityCached = LPH_NO_VIRTUALIZE(function(PartPosition, Character)
	local Settings = Environment.Settings
	local ttl = Environment.Performance.VisibilityTTL or 0.15
	local key = tostring(__index(Character, "Name") or Character) .. "@" .. tostring(mathfloor(PartPosition.X)) .. "," .. tostring(mathfloor(PartPosition.Y)) .. "," .. tostring(mathfloor(PartPosition.Z))
	local now = tick()
	local hit = VisibilityCache[key]
	if hit ~= nil and (now - hit.Time) < ttl then
		return hit.Visible
	end

	local BlacklistTable = {}
	pcall(function()
		local localChar = __index(LocalPlayer, "Character")
		if localChar ~= nil then
			for _, v in next, GetDescendants(localChar) do
				BlacklistTable[#BlacklistTable + 1] = v
			end
		end
	end)
	for _, v in next, GetDescendants(Character) do
		BlacklistTable[#BlacklistTable + 1] = v
	end

	local visible = true
	local ok, parts = pcall(function()
		return GetPartsObscuringTarget(Camera, { PartPosition }, BlacklistTable)
	end)
	if ok and parts ~= nil and #parts > 0 then
		visible = false
	end

	VisibilityCache[key] = { Visible = visible, Time = now }
	return visible
end)

local EffectiveFOVRadius = LPH_NO_VIRTUALIZE(function(WorldDistance)
	local FOVSettings = Environment.FOVSettings
	local radius = FOVSettings.Enabled and FOVSettings.Radius or 2000
	if FOVSettings.DynamicFOV and WorldDistance ~= nil then
		local scale = mathclamp(WorldDistance / 500, FOVSettings.DynamicMin or 0.7, FOVSettings.DynamicMax or 1.3)
		radius = radius * scale
	end
	return radius
end)

-- Canonical validation pipeline (§35 order). No scoring here; cheap checks first.
local IsValidTarget = LPH_NO_VIRTUALIZE(function(Player)
	local Settings = Environment.Settings

	if Player == nil then
		return false
	end
	local okParent = pcall(function() return __index(Player, "Parent") end)
	if not okParent or __index(Player, "Parent") == nil then
		return false
	end
	if Player == LocalPlayer then
		return false
	end

	local Character, Humanoid, RootPart = GetCharacterData(Player)
	if Character == nil then
		return false
	end

	if Settings.AliveCheck then
		local okH, hp = pcall(function() return __index(Humanoid, "Health") end)
		if not okH or hp <= 0 then
			return false
		end
	end

	-- 6. Team Check (before scoring; teammates never receive a score).
	if IsTeammate(Player) then
		return false
	end

	-- Neutral handling.
	if IsNeutral(Player) and not Settings.IncludeNeutralPlayers then
		return false
	end

	-- 7. Friend Check. 8. Blacklist (blacklist always wins; no score calculated).
	if IsFriend(Player) then
		return false
	end
	local playerName
	pcall(function() playerName = __index(Player, "Name") end)
	if playerName ~= nil and tablefind(Environment.Blacklisted, playerName) then
		return false
	end

	-- 10/11. Distance + FOV + part existence (part check before visibility: no part = no aim).
	local _, partPos = ResolveAimPart(Character)
	if partPos == nil then
		return false
	end

	local camPos = __index(Camera, "CFrame").Position
	local worldDist = (camPos - partPos).Magnitude
	if worldDist > (Settings.MaxDistance or 1000) then
		return false
	end

	local okV, vec, onScreen = pcall(function() return WorldToViewportPoint(Camera, partPos) end)
	if not okV or not onScreen then
		return false
	end
	local screenDist = (GetMouseLocation(UserInputService) - ConvertVector(vec)).Magnitude
	if screenDist > EffectiveFOVRadius(worldDist) then
		return false
	end

	-- 12. Visibility.
	if Settings.WallCheck then
		local visible = CheckVisibilityCached(partPos, Character)
		if not visible and Settings.StrictVisibility then
			return false
		end
	end

	return true
end)

-- Weighted scoring. All metrics normalized 0-1; higher = better.
local ScoreTarget = LPH_NO_VIRTUALIZE(function(Player, ScreenDist, WorldDist, Visible, HealthFrac, IsCurrent)
	local Settings = Environment.Settings
	local W = Environment.Scoring
	local radius = EffectiveFOVRadius(WorldDist)
	if radius <= 0 then
		radius = 1
	end

	local fovScore = 1 - mathclamp(ScreenDist / radius, 0, 1)
	local distScore = 1 - mathclamp(WorldDist / (Settings.MaxDistance or 1000), 0, 1)
	local visScore = 1
	if Settings.WallCheck then
		if Visible then
			visScore = 1
		elseif Settings.StrictVisibility then
			visScore = 0
		else
			visScore = 0.35
		end
	end
	local healthScore = 1 - mathclamp(HealthFrac or 0, 0, 1)

	local priorityScore = 1
	if #Environment.PriorityPlayers > 0 then
		priorityScore = 0.2
		local playerName
		pcall(function() playerName = __index(Player, "Name") end)
		if playerName ~= nil and tablefind(Environment.PriorityPlayers, playerName) then
			priorityScore = 1
		end
	end

	local totalW = (W.FOVWeight or 0) + (W.DistanceWeight or 0) + (W.VisibilityWeight or 0) + (W.HealthWeight or 0) + (W.PriorityWeight or 0) + (W.PersistenceWeight or 0)
	if totalW <= 0 then
		totalW = 1
	end

	local score = (fovScore * (W.FOVWeight or 0)
		+ distScore * (W.DistanceWeight or 0)
		+ visScore * (W.VisibilityWeight or 0)
		+ healthScore * (W.HealthWeight or 0)
		+ priorityScore * (W.PriorityWeight or 0)) / totalW

	if IsCurrent then
		score = score + (Settings.TargetStickiness or 0) * (W.PersistenceWeight or 0) / totalW
	end

	LastBreakdown.FOV = fovScore
	LastBreakdown.Distance = distScore
	LastBreakdown.Visibility = visScore
	LastBreakdown.Health = healthScore
	LastBreakdown.Priority = priorityScore

	return score
end)

local ShouldSwitchTarget = LPH_NO_VIRTUALIZE(function(NewScore, CurrentScore)
	return NewScore > CurrentScore + (Environment.Settings.SwitchThreshold or 0.12)
end)

-- Full candidate scan at scheduler rate. Single shared pipeline: IsValidTarget
-- gates (populating the visibility cache), then scoring data is gathered with
-- no duplicate raycasts. Returns best player + score per PriorityMode.
local RefreshScan = LPH_NO_VIRTUALIZE(function()
	local Settings = Environment.Settings
	local mousePos = GetMouseLocation(UserInputService)
	local camPos = __index(Camera, "CFrame").Position

	local results = {}
	local best, bestScore = nil, -1
	local bestBreakdown = nil
	local cursorBest, cursorDist = nil, mathhuge
	local distBest, distDist = nil, mathhuge
	local hpBest, hpFrac = nil, mathhuge

	for _, Value in next, PlayerCache do
		if Value ~= LocalPlayer and Value.Parent ~= nil and IsValidTarget(Value) then
			local Character = __index(Value, "Character")
			if Character ~= nil then
				local _, partPos = ResolveAimPart(Character)
				if partPos ~= nil then
					local worldDist = (camPos - partPos).Magnitude
					local okV, vec, onScreen = pcall(function() return WorldToViewportPoint(Camera, partPos) end)
					if okV and onScreen then
						local screenDist = (mousePos - ConvertVector(vec)).Magnitude
						local visible = true
						if Settings.WallCheck then
							visible = CheckVisibilityCached(partPos, Character)
						end
						local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
						local healthFrac = 0
						if Humanoid ~= nil then
							local okH, hp, maxHp = pcall(function()
								return __index(Humanoid, "Health"), __index(Humanoid, "MaxHealth")
							end)
							if okH and maxHp > 0 then
								healthFrac = mathclamp(hp / maxHp, 0, 1)
							end
						end
						local isCurrent = (Environment.Locked == Value)
						local score = ScoreTarget(Value, screenDist, worldDist, visible, healthFrac, isCurrent)
						results[#results + 1] = { Player = Value, Score = score, ScreenDist = screenDist, WorldDist = worldDist, Health = healthFrac }
						if score > bestScore then
							best, bestScore = Value, score
							bestBreakdown = { FOV = LastBreakdown.FOV, Distance = LastBreakdown.Distance, Visibility = LastBreakdown.Visibility, Health = LastBreakdown.Health, Priority = LastBreakdown.Priority }
						end
						if screenDist < cursorDist then
							cursorBest, cursorDist = Value, screenDist
						end
						if worldDist < distDist then
							distBest, distDist = Value, worldDist
						end
						if healthFrac < hpFrac then
							hpBest, hpFrac = Value, healthFrac
						end
					end
				end
			end
		end
	end

	local mode = Settings.PriorityMode or "Score"
	if mode == "ClosestToCursor" and cursorBest ~= nil then
		best = cursorBest
		for _, r in next, results do
			if r.Player == best then
				bestScore = r.Score
				break
			end
		end
	elseif mode == "ClosestDistance" and distBest ~= nil then
		best = distBest
		for _, r in next, results do
			if r.Player == best then
				bestScore = r.Score
				break
			end
		end
	elseif mode == "LowestHealth" and hpBest ~= nil then
		best = hpBest
		for _, r in next, results do
			if r.Player == best then
				bestScore = r.Score
				break
			end
		end
	elseif mode == "Priority" then
		-- Best score among PriorityPlayers; falls back to score-best when none present.
		local prioBest, prioScore = nil, -1
		for _, r in next, results do
			local okN, pname = pcall(function() return __index(r.Player, "Name") end)
			if okN and pname ~= nil and tablefind(Environment.PriorityPlayers, pname) and r.Score > prioScore then
				prioBest, prioScore = r.Player, r.Score
			end
		end
		if prioBest ~= nil then
			best, bestScore = prioBest, prioScore
		end
	end

	if bestBreakdown ~= nil then
		LastBreakdown.FOV = bestBreakdown.FOV
		LastBreakdown.Distance = bestBreakdown.Distance
		LastBreakdown.Visibility = bestBreakdown.Visibility
		LastBreakdown.Health = bestBreakdown.Health
		LastBreakdown.Priority = bestBreakdown.Priority
	end

	ScanState.Best = best
	ScanState.BestScore = bestScore
	ScanState.Results = results
	ScanState.Time = tick()
	return best, bestScore
end)

local ResetTargetState = LPH_NO_VIRTUALIZE(function()
	VelocityState.Samples = {}
	VelocityState.AvgVelocity = Vector3zero
	VelocityState.SmoothVel = nil
	VelocityState.Acceleration = Vector3zero
	VelocityState.Confidence = 0
	VelocityState.LastPos = nil
	VelocityState.LastTime = 0
	VelocityState.Stable = true
	-- Target-specific prediction state goes; connection-level ping stats stay.
	PingState.ErrBuf = {}
	PingState.LastPred = nil
end)

-- Forward declaration: HookTargetDied is assigned after CancelLock/DebugLockRelease
-- (its body calls both, so it must be defined textually after them).
local HookTargetDied

local AcquireLock = LPH_NO_VIRTUALIZE(function(Player, Score)
	if Environment.Locked ~= Player then
		ResetTargetState()
		LockMeta.Previous = Environment.Locked
		LockMeta.PrevPos = nil
		LockMeta.PrevTime = 0
		HookTargetDied(Player)
		local name = "?"
		pcall(function() name = __index(Player, "Name") end)
		if (tick() - (LockMeta.LastAcqPrint or 0)) > 1 then
			LockMeta.LastAcqPrint = tick()
			dprint("lock acquired:", name, "score:", string.format("%.2f", Score or -1))
		end
	end
	Environment.Locked = Player
	LockMeta.Since = tick()
	LockMeta.LastSeen = tick()
	LockMeta.LastScore = Score or 0
end)

local CancelLock = LPH_NO_VIRTUALIZE(function()
	if ServiceConnections.TargetDied ~= nil then
		pcall(Disconnect, ServiceConnections.TargetDied)
		ServiceConnections.TargetDied = nil
	end
	if ServiceConnections.TargetCharAdded ~= nil then
		pcall(Disconnect, ServiceConnections.TargetCharAdded)
		ServiceConnections.TargetCharAdded = nil
	end
	if ServiceConnections.TargetCharRemoving ~= nil then
		pcall(Disconnect, ServiceConnections.TargetCharRemoving)
		ServiceConnections.TargetCharRemoving = nil
	end
	Environment.Locked = nil
	LockMeta.LastScore = -1
	LockMeta.Since = 0
	LockMeta.LastSeen = 0
	LockMeta.PrevPos = nil
	LockMeta.PrevTime = 0
	LockMeta.RetainRadius = nil

	setrenderproperty(Environment.FOVCircle, "Color", Environment.FOVSettings.Color)
	__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)

	if Animation then
		Animation:Cancel()
	end

	ResetTargetState()
	setrenderproperty(Environment.Tracer, "Visible", Environment.ClosestPlayerTracer.Enabled)
end)

-- Locked-target fast path: cheap checks every frame (no raycast; cache only).
local ValidateLocked = LPH_NO_VIRTUALIZE(function()
	local locked = Environment.Locked
	if locked == nil then
		return false
	end
	if locked.Parent == nil then
		return false
	end
	if IsTeammate(locked) then
		return false
	end
	local Character, Humanoid, _ = GetCharacterData(locked)
	if Character == nil then
		return false
	end
	if Environment.Settings.AliveCheck then
		local okH, hp = pcall(function() return __index(Humanoid, "Health") end)
		if not okH or hp <= 0 then
			return false
		end
	end
	local _, partPos = ResolveAimPart(Character)
	if partPos == nil then
		return false
	end
	-- Still inside effective FOV? (Uses last scan radius semantics: reject only when
	-- clearly outside, so the lock survives small cursor movement = stickiness.)
	local camPos = __index(Camera, "CFrame").Position
	local worldDist = (camPos - partPos).Magnitude
	local okV, vec, onScreen = pcall(function() return WorldToViewportPoint(Camera, partPos) end)
	if not okV or not onScreen then
		return false
	end
	local screenDist = (GetMouseLocation(UserInputService) - ConvertVector(vec)).Magnitude
	-- Lock retention: acquisition-anchored SMALL radius (LockMeta.RetainRadius),
	-- never the broad acquisition FOV. A target leaving the active aim region is
	-- released immediately even if still inside the FOV and otherwise valid.
	-- Stickiness/hysteresis only choose BETWEEN valid targets; they never retain this one.
	local retainR = LockMeta.RetainRadius or Environment.Settings.LockRetentionRadius or 30
	if screenDist > retainR then
		return false
	end
	LockMeta.LastSeen = tick()
	return true
end)

-- Hard-invalid detection for the CURRENT lock. Death / destruction / departure /
-- team change must cancel the lock IMMEDIATELY (no grace period) so a corpse's
-- falling velocity can never reach prediction. Returns a reason string, or nil
-- when the lock is alive and usable. Cheap: property reads only, no raycasts.
local LockDeathReason = LPH_NO_VIRTUALIZE(function()
	local locked = Environment.Locked
	if locked == nil then
		return "No lock"
	end
	local okParent, parent = pcall(function() return __index(locked, "Parent") end)
	if not okParent or parent == nil then
		return "TARGET_LEFT_GAME"
	end
	local okChar, Character = pcall(function() return __index(locked, "Character") end)
	if not okChar or Character == nil then
		return "TARGET_REPLACED"
	end
	-- A dead character may linger briefly: it must still live in the world.
	local okWorld, inWorld = pcall(function()
		return __index(Character, "IsDescendantOf")(Character, workspace)
	end)
	if not okWorld or not inWorld then
		return "TARGET_LEFT_WORKSPACE"
	end
	local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
	if Humanoid == nil then
		return "TARGET_MISSING_HUMANOID"
	end
	if Environment.Settings.AliveCheck then
		local okH, hp = pcall(function() return __index(Humanoid, "Health") end)
		if not okH then
			return "TARGET_HEALTH_ZERO"
		end
		if hp <= 0 then
			return "TARGET_DIED"
		end
		-- Health can lag replication on kill: the Dead state is authoritative.
		local okS, state = pcall(function()
			return __index(Humanoid, "GetState")(Humanoid)
		end)
		if okS and state == Enum.HumanoidStateType.Dead then
			return "TARGET_STATE_DEAD"
		end
	end
	local part, _ = ResolveAimPart(Character)
	if part == nil then
		return "TARGET_PART_MISSING"
	end
	local okA, inChar = pcall(function()
		return __index(part, "IsDescendantOf")(part, Character)
	end)
	if not okA or not inChar then
		return "TARGET_PART_MISSING"
	end
	if IsTeammate(locked) then
		return "TARGET_TEAM_CHANGED"
	end
	return nil
end)

local LockReleaseLastLog = 0

-- Throttled lock-release snapshot: reason + the exact values that were alive
-- at release time (proves no corpse velocity leaks into the next frames).
local DebugLockRelease = LPH_NO_VIRTUALIZE(function(Reason, Detail)
	if not Environment.Debugger.Enabled then
		return
	end
	local now = tick()
	if (now - LockReleaseLastLog) < (Environment.Debugger.Rate or 0.5) then
		return
	end
	LockReleaseLastLog = now
	local locked = Environment.Locked
	local hp, hState, cParent, sdTxt = -1, "?", "?", "?"
	local rawVel, smoothVel, accel = Vector3zero, Vector3zero, Vector3zero
	local partPosTxt, prevTxt = "?", "none"
	if locked ~= nil then
		pcall(function()
			local Character = __index(locked, "Character")
			if Character ~= nil then
				cParent = tostring(__index(Character, "Parent"))
				local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
				if Humanoid ~= nil then
					hp = __index(Humanoid, "Health")
					hState = tostring(__index(Humanoid, "GetState")(Humanoid))
				end
				local _, pp = ResolveAimPart(Character)
				if pp ~= nil then
					partPosTxt = string.format("(%.1f, %.1f, %.1f)", pp.X, pp.Y, pp.Z)
					local okV, vec, onS = pcall(function() return WorldToViewportPoint(Camera, pp) end)
					if okV and onS then
						sdTxt = string.format("%.0f", (GetMouseLocation(UserInputService) - ConvertVector(vec)).Magnitude)
					end
				end
			end
		end)
	end
	local samples = VelocityState.Samples
	if #samples > 0 then
		rawVel = samples[#samples]
	end
	if VelocityState.SmoothVel ~= nil then
		smoothVel = VelocityState.SmoothVel
	end
	accel = VelocityState.Acceleration
	if LockMeta.PrevPos ~= nil then
		prevTxt = string.format("(%.1f, %.1f, %.1f)", LockMeta.PrevPos.X, LockMeta.PrevPos.Y, LockMeta.PrevPos.Z)
	end
	_warn(string.format(
		"[Aimbot] LOCK RELEASED: %s | HP %.0f STATE %s CHARPARENT %s | POS %s PREV %s | ACQ %d RET %.0f SD %s | RAWVEL (%.1f, %.1f, %.1f) | SMOOTHVEL (%.1f, %.1f, %.1f) | ACCEL %.1f | EFFTIME %.3fs | CONF %.2f | ACTION: RELEASE LOCK | %s",
		tostring(Reason), hp, tostring(hState), tostring(cParent),
		partPosTxt, prevTxt,
		(Environment.FOVSettings.Radius or 180),
		(LockMeta.RetainRadius or (Environment.Settings.LockRetentionRadius or 30)),
		sdTxt,
		rawVel.X, rawVel.Y, rawVel.Z,
		smoothVel.X, smoothVel.Y, smoothVel.Z,
		accel.Magnitude, PingState.Effective or 0, VelocityState.Confidence,
		tostring(Detail or "")
	))
end)

-- Humanoid.Died hookup for the CURRENT lock: death invalidates immediately,
-- without waiting for the next scan cycle. Exactly one connection exists at a
-- time; it is replaced on target change and removed on cancel / leave / unload
-- (via ServiceConnections). Re-hooking the same humanoid never duplicates.
HookTargetDied = LPH_NO_VIRTUALIZE(function(Player)
	if ServiceConnections.TargetDied ~= nil then
		pcall(Disconnect, ServiceConnections.TargetDied)
		ServiceConnections.TargetDied = nil
	end
	if ServiceConnections.TargetCharAdded ~= nil then
		pcall(Disconnect, ServiceConnections.TargetCharAdded)
		ServiceConnections.TargetCharAdded = nil
	end
	if ServiceConnections.TargetCharRemoving ~= nil then
		pcall(Disconnect, ServiceConnections.TargetCharRemoving)
		ServiceConnections.TargetCharRemoving = nil
	end
	if Player == nil then
		return
	end
	-- Player-level hooks survive respawns (the Player object is stable, the
	-- Humanoid is not): any character swap cancels the lock so stale velocity
	-- history can never transfer to the new character.
	local okA, connA = pcall(function()
		return Connect(__index(Player, "CharacterAdded"), LPH_NO_VIRTUALIZE(function()
			ClearTeamCache(Player)
			if Environment.Locked == Player then
				DebugLockRelease("TARGET_REPLACED (respawn)")
				CancelLock()
			end
		end))
	end)
	if okA and connA ~= nil then
		ServiceConnections.TargetCharAdded = connA
	end
	local okR, connR = pcall(function()
		return Connect(__index(Player, "CharacterRemoving"), LPH_NO_VIRTUALIZE(function()
			if Environment.Locked == Player then
				DebugLockRelease("CHARACTER_REMOVED")
				CancelLock()
			end
		end))
	end)
	if okR and connR ~= nil then
		ServiceConnections.TargetCharRemoving = connR
	end
	local okC, Character = pcall(function() return __index(Player, "Character") end)
	if not okC or Character == nil then
		return
	end
	local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
	if Humanoid == nil then
		return
	end
	local okD, conn = pcall(function()
		return Connect(__index(Humanoid, "Died"), LPH_NO_VIRTUALIZE(function()
			if Environment.Locked == Player then
				DebugLockRelease("TARGET_DIED (event)")
				CancelLock()
			end
		end))
	end)
	if okD and conn ~= nil then
		ServiceConnections.TargetDied = conn
	end
end)

-- Position sanity (secondary net): finite check + impossible single-frame
-- displacement. Generous by design: legit fast movement (vehicles, falling,
-- flings within reason) passes; map-fall-through / teleport-scale jumps fail.
-- Purely relative to the previous valid position: no world-Y hardcoding, so
-- maps with legitimate negative coordinates are unaffected.
local CheckPositionSanity = LPH_NO_VIRTUALIZE(function(Pos, DeltaTime)
	if Pos.X ~= Pos.X or Pos.Y ~= Pos.Y or Pos.Z ~= Pos.Z then
		return false, "TARGET_POSITION_INVALID"
	end
	if mathabs(Pos.X) > 100000 or mathabs(Pos.Y) > 100000 or mathabs(Pos.Z) > 100000 then
		return false, "TARGET_POSITION_INVALID"
	end
	local S = Environment.Settings
	if not S.PositionSanityCheck then
		return true
	end
	local prev = LockMeta.PrevPos
	if prev == nil then
		return true -- baseline frame; nothing to compare against yet
	end
	local dt = tick() - (LockMeta.PrevTime or tick())
	if dt <= 0 then
		dt = DeltaTime or 0.016
	end
	local allow = (S.MaxTargetDisplacement or 400) * dt + 5
	if (Pos - prev).Magnitude > allow then
		return false, "TARGET_MOVED_TOO_FAR"
	end
	local vAllow = (S.MaxVerticalDisplacement or 300) * dt + 5
	if mathabs(Pos.Y - prev.Y) > vAllow then
		return false, "TARGET_MOVED_TOO_FAR"
	end
	return true
end)

-- GetClosestPlayer: preserved public behavior, now backed by the shared pipeline.
-- Aux=true  -> returns best candidate WITHOUT locking (tracer / queries).
-- Aux=nil   -> maintains Environment.Locked with hysteresis.
local GetClosestPlayer = LPH_NO_VIRTUALIZE(function(Aux)
	local Settings = Environment.Settings

	if not Environment.Locked or Aux then
		local now = tick()
		if (now - ScanState.Time) >= (Environment.Performance.TargetScanRate or 0.12) or ScanState.Best == nil then
			RefreshScan()
		end

		local best, bestScore = ScanState.Best, ScanState.BestScore
		if best == nil then
			-- Fallback: legacy ClosestDistance within scan results for ClosestDistance mode.
			return nil
		end

		if not Aux then
			RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000
			local acqDist = Settings.LockRetentionRadius or 30
			local _, partPos = ResolveAimPart(__index(best, "Character"))
			if partPos ~= nil then
				Required3DDistance = (__index(Camera, "CFrame").Position - partPos).Magnitude
				local okV, vec, _ = pcall(function() return WorldToViewportPoint(Camera, partPos) end)
				if okV then
					RequiredDistance = (GetMouseLocation(UserInputService) - ConvertVector(vec)).Magnitude
					acqDist = RequiredDistance
				end
			end
			-- Retention anchor: acquisition-anchored (original Exunys semantics) with
			-- the small configured floor. A kill-time lock is therefore tight: the
			-- falling body exits it within a few frames.
			LockMeta.RetainRadius = math.max(Settings.LockRetentionRadius or 30, acqDist)
			AcquireLock(best, bestScore)
		elseif not Running and not Environment.Locked then
			return best
		end
		return best
	else
		-- Hard-invalid (dead / destroyed / left / teammate): cancel IMMEDIATELY.
		-- No grace period here: grace exists for briefly-occluded LIVE targets,
		-- and a corpse's falling velocity must never reach prediction.
		local deathReason = LockDeathReason()
		if deathReason ~= nil then
			DebugLockRelease(deathReason)
			CancelLock()
			return nil
		end
		-- Hysteresis: keep the lock unless clearly invalid; switch only when a
		-- challenger is meaningfully better.
		if ValidateLocked() then
			local now = tick()
			if (now - ScanState.Time) >= (Environment.Performance.TargetScanRate or 0.12) then
				RefreshScan()
				local best, bestScore = ScanState.Best, ScanState.BestScore
				if best ~= nil and best ~= Environment.Locked and ShouldSwitchTarget(bestScore, LockMeta.LastScore) then
					AcquireLock(best, bestScore)
				elseif best ~= nil and best == Environment.Locked then
					LockMeta.LastScore = bestScore
				end
			end
			return Environment.Locked
		end

		-- Grace period (LIVE targets only: briefly out-of-FOV / occluded).
		-- Dead, destroyed, left or teammate targets never reach here:
		-- they are cancelled above with no grace and fully cleared state.
		if (tick() - LockMeta.LastSeen) < (Settings.TargetGracePeriod or 0.1) then
			return Environment.Locked
		end
		CancelLock()
		return nil
	end
end)

-- Velocity sampling (locked target only, every frame): short rolling history,
-- average velocity, acceleration estimate, direction-change aware confidence.
local SampleVelocity = LPH_NO_VIRTUALIZE(function(Part, DeltaTime)
	local now = tick()
	local pos
	local okP, p = pcall(function() return __index(Part, "Position") end)
	if not okP or p == nil then
		return
	end
	pos = p

	local vel = nil
	local root = FindFirstChild(__index(Part, "Parent"), "HumanoidRootPart")
	if root ~= nil then
		local okV, v = pcall(function() return __index(root, "AssemblyLinearVelocity") end)
		if okV and v ~= nil and v.Magnitude < 10000 then
			vel = v
		else
			local okV2, v2 = pcall(function() return __index(root, "Velocity") end)
			if okV2 and v2 ~= nil and v2.Magnitude < 10000 then
				vel = v2
			end
		end
	end
	if vel == nil and VelocityState.LastPos ~= nil and DeltaTime > 0 then
		vel = (pos - VelocityState.LastPos) / DeltaTime
	end
	if vel == nil then
		return
	end

	local samples = VelocityState.Samples
	samples[#samples + 1] = vel
	local maxSamples = Environment.Performance.VelocitySamples or 5
	while #samples > maxSamples do
		tableremove(samples, 1)
	end

	local sum = Vector3zero
	for _, v in next, samples do
		sum = sum + v
	end
	local avg = sum / #samples
	local prevAvg = VelocityState.AvgVelocity
	VelocityState.AvgVelocity = avg
	-- Smoothed velocity (EMA): the value prediction actually uses. Quieter than
	-- the rolling average when samples are noisy.
	local Nw = Environment.Network
	if Nw ~= nil and Nw.VelocitySmoothing == false then
		VelocityState.SmoothVel = vel
	else
		local va = (Nw ~= nil and Nw.VelocityAlpha) or 0.35
		local sv = VelocityState.SmoothVel
		if sv == nil then
			VelocityState.SmoothVel = vel
		else
			VelocityState.SmoothVel = sv + (vel - sv) * mathclamp(va, 0.01, 1)
		end
	end
	if DeltaTime > 0 then
		VelocityState.Acceleration = (avg - prevAvg) / DeltaTime
	end

	-- Direction change: latest sample vs average.
	local dirStable = true
	if avg.Magnitude > 1 and vel.Magnitude > 1 then
		local dot = (avg.Unit.X * vel.Unit.X) + (avg.Unit.Y * vel.Unit.Y) + (avg.Unit.Z * vel.Unit.Z)
		if dot < 0.5 then
			dirStable = false
		end
	end

	-- Stability: low variance across samples = stable.
	local variance = 0
	for _, v in next, samples do
		variance = variance + (v - avg).Magnitude
	end
	variance = variance / #samples
	local stable = dirStable and variance < 12

	if stable then
		VelocityState.Confidence = mathclamp(VelocityState.Confidence + DeltaTime * 2, 0, 1)
	else
		VelocityState.Confidence = mathclamp(VelocityState.Confidence - DeltaTime * 4, 0, 1)
	end
	VelocityState.Stable = stable
	VelocityState.LastPos = pos
	VelocityState.LastTime = now
end)

-- Latency-driven prediction.
--   Ping    -> HOW FAR into the future to predict (time).
--   Velocity-> WHICH DIRECTION / how far in space (direction).
--   Jitter  -> confidence adjustment (never a direct prediction value).
-- Falls back to the legacy paths when ping is unavailable or PingPrediction is OFF.
local ComputePrediction = LPH_NO_VIRTUALIZE(function(PartPos, WorldDistance)
	local P = Environment.Prediction
	local N = Environment.Network
	local vel = VelocityState.SmoothVel or VelocityState.AvgVelocity or Vector3zero

	if N == nil or not N.PingPrediction or not PingState.Available then
		if not P.Adaptive then
			return PartPos + vel * mathclamp(P.Base or 0.12, P.Min or 0, P.Max or 0.3), 1
		end

		local speed = vel.Magnitude
		local accel = VelocityState.Acceleration.Magnitude
		local time = (P.Base or 0.12)
			+ mathclamp(speed * (P.VelocityInfluence or 0.35) * 0.01, 0, 0.15)
			+ mathclamp((WorldDistance or 0) * (P.DistanceInfluence or 0.25) * 0.0002, 0, 0.1)
			+ mathclamp(accel * (P.AccelerationInfluence or 0.15) * 0.001, 0, 0.08)
		time = mathclamp(time, P.Min or 0, P.Max or 0.3)

		local conf = VelocityState.Confidence
		if #VelocityState.Samples == 0 then
			conf = 0.5
		end
		local predicted = PartPos + vel * time * (0.4 + 0.6 * conf)
		return predicted, conf
	end

	-- One-way latency estimate: Roblox ping is round-trip, so halve the smoothed value.
	local oneWay = (PingState.Smoothed / 1000) / 2
	local time = oneWay * (N.PingMultiplier or 1)
	time = time * PingState.Correction -- slow auto-calibration (overshoot/undershoot bias)
	if N.DistanceCompensation ~= false then
		time = time + mathclamp((WorldDistance or 0) / 1000 * 0.05 * (N.DistanceStrength or 1), 0, 0.06)
	end

	local conf = VelocityState.Confidence
	if #VelocityState.Samples == 0 then
		conf = 0.5
	end
	if N.JitterCompensation ~= false then
		conf = conf * (1 - mathclamp(PingState.Jitter / 80, 0, 0.6) * (N.JitterStrength or 0.5))
	end
	conf = mathclamp(conf, 0, 1)

	local strength = P.ConfidenceStrength or 0.6
	time = time * ((1 - strength) + strength * conf)
	time = mathclamp(time, N.MinLatency or 0.02, N.MaxLatency or 0.3)
	PingState.Effective = time

	local predicted = PartPos
	if vel.Magnitude > 0.01 then
		predicted = PartPos + vel * time
	end
	return predicted, conf
end)

-- Ping sampling (low frequency). Reads the real Stats ping, smooths with EMA +
-- spike rejection, keeps a bounded history, derives jitter + connection quality.
-- Never errors: on failure PingState.Available stays false and legacy paths run.
local SamplePing = LPH_NO_VIRTUALIZE(function()
	local N = Environment.Network
	local raw = nil
	local okS, stats = pcall(function() return GetService("Stats") end)
	if okS and stats ~= nil then
		local okI, item = pcall(function()
			return __index(__index(__index(stats, "Network"), "ServerStatsItem"), "Data Ping")
		end)
		if okI and item ~= nil then
			local okV, v = pcall(function() return item:GetValue() end)
			if okV and type(v) == "number" and v > 0 and v < 10000 then
				raw = v
			else
				local okS2, s = pcall(function() return item:GetValueString() end)
				if okS2 and type(s) == "string" then
					local num = string.match(s, "%d+")
					if num ~= nil then
						raw = tonumber(num)
					end
				end
			end
		end
	end
	if raw == nil then
		PingState.Available = false
		return
	end

	PingState.Available = true
	PingState.Raw = raw
	if PingState.Smoothed <= 0 then
		PingState.Smoothed = raw
	else
		local alpha = (N ~= nil and N.PingAlpha) or 0.1
		if N ~= nil and N.PingSmoothing == false then
			alpha = 1
		end
		if mathabs(raw - PingState.Smoothed) > 120 then
			alpha = alpha * 0.2 -- spike rejection: don't chase single bad samples
		end
		PingState.Smoothed = PingState.Smoothed + (raw - PingState.Smoothed) * mathclamp(alpha, 0.01, 1)
	end

	local hist = PingState.Samples
	hist[#hist + 1] = raw
	local maxH = (N ~= nil and N.PingHistory) or 20
	while #hist > maxH do
		tableremove(hist, 1)
	end
	local mn, mx, sum = mathhuge, 0, 0
	for _, v in next, hist do
		if v < mn then mn = v end
		if v > mx then mx = v end
		sum = sum + v
	end
	PingState.Min = mn
	PingState.Max = mx

	local inst = mathabs(raw - PingState.Smoothed)
	PingState.Jitter = PingState.Jitter + (inst - PingState.Jitter) * (((N ~= nil and N.PingAlpha) or 0.1))

	local s, j = PingState.Smoothed, PingState.Jitter
	if s < 120 and j < 20 then
		PingState.Quality = "Stable"
	elseif s < 250 and j < 50 then
		PingState.Quality = "Moderate"
	else
		PingState.Quality = "Unstable"
	end
	PingState.LastUpdate = tick()
end)

-- Slow self-calibration: compares actual positions against earlier predictions
-- (directional bias only) and nudges the correction multiplier. Heavily clamped
-- so one bad frame can never rewrite prediction.
local UpdateCalibration = LPH_NO_VIRTUALIZE(function()
	local N = Environment.Network
	if N == nil or not N.AutoCalibration then
		return
	end
	local buf = PingState.ErrBuf
	if #buf < 4 then
		return
	end
	local sum = 0
	for _, v in next, buf do
		sum = sum + v
	end
	local mean = sum / #buf
	local step = mathclamp(mean, -1, 1) * (N.CalibrationRate or 0.05) * (N.CalibrationStrength or 1)
	step = mathclamp(step, -0.01, 0.01)
	PingState.Correction = mathclamp(PingState.Correction + step, N.CalibrationMin or 0.5, N.CalibrationMax or 1.5)
	PingState.ErrBuf = {}
end)

-- Adaptive smoothing: small error = subtle correction, large error = stronger;
-- unstable targets get more smoothing. Output is a clamped per-frame lerp factor.
local ComputeSmoothing = LPH_NO_VIRTUALIZE(function(DeltaTime, ErrorPx, WorldDistance)
	local S = Environment.Smoothing
	local Settings = Environment.Settings

	local base
	if Settings.Sensitivity and Settings.Sensitivity > 0 then
		base = mathclamp(DeltaTime / Settings.Sensitivity * 4, 0.02, 1)
	else
		base = 1
	end

	if not S.Adaptive then
		return base
	end

	local errF = mathclamp(ErrorPx / 200, 0, 1)
	local distF = mathclamp((WorldDistance or 0) / 1000, 0, 1)
	local speedF = mathclamp(VelocityState.AvgVelocity.Magnitude / 50, 0, 1)

	local factor = base
		* (1 + errF * (S.ErrorInfluence or 0.6))
		* (1 + distF * (S.DistanceInfluence or 0.2))
		* (1 + speedF * (S.VelocityInfluence or 0.3))
	if not VelocityState.Stable then
		factor = factor * (1 - (S.StabilityInfluence or 0.4))
	end
	-- Unstable connection -> calmer aim output (jitter must not drive the crosshair).
	if PingState.Quality == "Unstable" then
		factor = factor * 0.7
	elseif PingState.Quality == "Moderate" then
		factor = factor * 0.85
	end

	return mathclamp(factor, S.Min or 0.08, S.Max or 0.9)
end)

-- (Aim output dispatch was reverted to the proven direct branch in the main
-- loop after a regression report; the shared pipeline above is untouched.)

local PurgePlayer = LPH_NO_VIRTUALIZE(function(UserId)
	VisibilityCache = {}
	FriendSet[UserId] = nil
	TeamCache[UserId] = nil
	if Environment.Locked ~= nil then
		local lockedId
		pcall(function() lockedId = __index(Environment.Locked, "UserId") end)
		if lockedId == UserId then
			CancelLock()
		end
	end
end)

local DebugPrint = LPH_NO_VIRTUALIZE(function(Extra)
	if not Environment.Debugger.Enabled then
		return
	end
	local now = tick()
	if (now - DebugLastPrint) < (Environment.Debugger.Rate or 0.5) then
		return
	end
	DebugLastPrint = now

	local locked = Environment.Locked
	local targetName, targetTeam, teamCheck = "none", "-", "N/A"
	local localTeam = "-"
	pcall(function()
		local t = __index(LocalPlayer, "Team")
		localTeam = t ~= nil and __index(t, "Name") or "-"
	end)
	if locked ~= nil then
		pcall(function() targetName = __index(locked, "Name") end)
		pcall(function()
			local t = __index(locked, "Team")
			targetTeam = t ~= nil and __index(t, "Name") or "-"
		end)
		teamCheck = IsTeammate(locked) and "REJECT" or "PASS"
	end

	local acqR = Environment.FOVSettings.Radius or 180
	local retR = LockMeta.RetainRadius or (Environment.Settings.LockRetentionRadius or 30)
	local sdNow, graceLeft = -1, 0
	if locked ~= nil then
		pcall(function()
			local Character = __index(locked, "Character")
			if Character ~= nil then
				local _, pp = ResolveAimPart(Character)
				if pp ~= nil then
					local okV, vec, onS = pcall(function() return WorldToViewportPoint(Camera, pp) end)
					if okV and onS then
						sdNow = (GetMouseLocation(UserInputService) - ConvertVector(vec)).Magnitude
					end
				end
			end
		end)
		graceLeft = math.max(0, (Environment.Settings.TargetGracePeriod or 0.1) - (tick() - LockMeta.LastSeen))
	end

	local tsrc, tconf = "?", 0
	if locked ~= nil then
		pcall(function()
			local ti = ResolveTeamInfo(locked)
			if ti ~= nil then
				tsrc = tostring(ti.Source or "?")
				tconf = ti.Confidence or 0
			end
		end)
	end

	local confKind, confDetail = "NONE", ""
	if ConflictState.Kind ~= nil and ConflictState.Kind ~= "NONE" then
		confKind = tostring(ConflictState.Kind)
		confDetail = tostring(ConflictState.Detail or "")
	end

	_warn(string.format(
		"[Aimbot] TARGET: %s | TEAM: %s | LOCAL TEAM: %s | TEAM CHECK: %s | SCORE: %.2f (FOV %.2f DIST %.2f VIS %.2f HP %.2f PRIO %.2f) | CONF: %.2f | VEL: %.1f | PING %d/%dms JIT %dms NET %s | EFF %.3fs CORR %.2f | ACQ %d RET %.0f SD %.0f GRACE %.2f STICK %.2f | TSRC %s %.2f | CONFLICT %s %s %s",
		tostring(targetName), tostring(targetTeam), tostring(localTeam), tostring(teamCheck),
		LockMeta.LastScore or -1, LastBreakdown.FOV, LastBreakdown.Distance,
		LastBreakdown.Visibility, LastBreakdown.Health, LastBreakdown.Priority,
		VelocityState.Confidence, VelocityState.AvgVelocity.Magnitude,
		mathfloor(PingState.Raw or 0), mathfloor(PingState.Smoothed or 0), mathfloor(PingState.Jitter or 0),
		tostring(PingState.Quality), PingState.Effective or 0, PingState.Correction or 1,
		acqR, retR, sdNow, graceLeft, Environment.Settings.TargetStickiness or 0,
		tsrc, tconf,
		confKind, confDetail,
		tostring(Extra or "")
	))
end)

