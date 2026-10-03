-- Shared/TeamResolver.lua — the single team-detection system.
-- Extracted verbatim from the monolith (behavior preserved); only the
-- executor-cached upvalues below were rerouted through injected deps D.
-- Contract: Universery.TeamResolver.Init({Index, FindFirstChild,
--   GetService, GetPlayers, Players, LocalPlayer, Connect, Tick, Env})
-- must run once at boot before any other TR.* call.

local Universery = Require("registry")
Universery.TeamResolver = Universery.TeamResolver or {}
local TR = Universery.TeamResolver
local D = {}
local LPH = LPH_NO_VIRTUALIZE or function(f) return f end

local TEAM_ATTR_NAMES = { Team = true, TeamId = true, TeamID = true, TeamName = true, Faction = true, FactionId = true, FactionID = true, FactionName = true, Side = true, SideId = true, SideID = true, Squad = true, SquadId = true, SquadID = true, Group = true, GroupId = true, GroupID = true, Alliance = true, AllianceId = true, AllianceID = true, Allegiance = true, Camp = true, CampId = true, CampID = true }
local ROLE_DENY = { Role = true, RoleName = true, Class = true, Job = true, Kit = true, Loadout = true, Weapon = true, Perk = true, Character = true, Skin = true, Title = true }
local STAT_DENY = { Level = true, Kills = true, Deaths = true, Cash = true, Money = true, Coins = true, Health = true, MaxHealth = true, Speed = true, WalkSpeed = true, JumpPower = true, Score = true, Points = true, XP = true, Experience = true, Streak = true, Damage = true, Stage = true, Wins = true, Losses = true, PlayTime = true, Age = true, Value = true }

local TeamCache = {}
local TeamHooked = {}
local TeamRanking = { Attr = {}, Value = {}, Tag = {}, NativeDiverse = false, Time = 0 }

local TeamCS = nil

local function NormTeamId(v, cfg)
	local t = type(v)
	if t == "number" then
		return "N:" .. tostring(v)
	end
	if t == "string" then
		if cfg == nil or cfg.NormalizeCase ~= false then
			v = string.lower(v)
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
		return "C:" .. tostring(math.floor(v.R * 255)) .. "," .. tostring(math.floor(v.G * 255)) .. "," .. tostring(math.floor(v.B * 255))
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
	local needle = string.lower(name)
	local list = (cfg ~= nil and cfg.SpectatorNames) or { "Spectator", "Lobby", "Waiting" }
	for _, s in next, list do
		if type(s) == "string" and string.lower(s) == needle then
			return true
		end
	end
	return false
end

local function ReadAttr(inst, name)
	if inst == nil or type(name) ~= "string" or #name < 1 then
		return nil
	end
	local ok, val = pcall(function() return D.__index(inst, "GetAttribute")(inst, name) end)
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
	local okC, char = pcall(function() return D.__index(player, "Character") end)
	if okC and char ~= nil then
		return ReadAttr(char, name)
	end
	return nil
end

local function ReadValuePath(rootPlayer, path)
	if type(path) ~= "string" or #path < 1 then
		return nil
	end
	local okC, char = pcall(function() return D.__index(rootPlayer, "Character") end)
	local node = rootPlayer
	for part in string.gmatch(path, "[^.]+") do
		if part == "Character" and node == rootPlayer then
			node = (okC and char) or nil
		else
			if node == nil then
				return nil
			end
			local okF, child = pcall(function() return D.FindFirstChild(node, part) end)
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
		if D.__index(node, "IsA")(node, "ValueBase") then
			return D.__index(node, "Value")
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
		local okT, tags = pcall(function() return D.__index(TeamCS, "GetTags")(TeamCS, inst) end)
		if okT and type(tags) == "table" then
			for _, t in next, tags do
				out[#out + 1] = t
			end
		end
	end
	grab(player)
	local okC, char = pcall(function() return D.__index(player, "Character") end)
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
		if string.sub(tag, 1, #pre) == pre then
			local suf = string.sub(tag, #pre + 1)
			if #suf > 0 then
				return "S:" .. string.lower(suf), 0.75
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
local AnalyzeSources = LPH(function(Force)
	local cfg = D.Env.TeamResolver
	local now = D.Tick()
	if not Force and (now - TeamRanking.Time) < (cfg.ReanalyzeRate or 5) then
		return
	end
	TeamRanking = { Attr = {}, Value = {}, Tag = {}, NativeDiverse = false, Time = now }
	local players = {}
	for _, p in next, D.GetPlayers(D.Players) do
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
		local okT, team = pcall(function() return D.__index(p, "Team") end)
		if okT and team ~= nil then
			local okN, tname = pcall(function() return D.__index(team, "Name") end)
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
			local okA, attrs = pcall(function() return D.__index(inst, "GetAttributes")(inst) end)
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
		local okC, char = pcall(function() return D.__index(p, "Character") end)
		if okC then
			scanAttrs(char)
		end
		-- value objects: direct children + one-level Data-style containers
		local function scanValues(inst, prefix)
			if inst == nil then
				return
			end
			local okK, kids = pcall(function() return D.__index(inst, "GetChildren")(inst) end)
			if not okK or type(kids) ~= "table" then
				return
			end
			for _, child in next, kids do
				local okN, cname = pcall(function() return D.__index(child, "Name") end)
				if okN and type(cname) == "string" then
					local okV, isV = pcall(function() return D.__index(child, "IsA")(child, "ValueBase") end)
					if okV and isV then
						if TEAM_ATTR_NAMES[cname] and not ROLE_DENY[cname] and not STAT_DENY[cname] then
							local okVal, vv = pcall(function() return D.__index(child, "Value") end)
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
		local okC2, char2 = pcall(function() return D.__index(p, "Character") end)
		if okC2 and char2 ~= nil then
			scanValues(char2, "Character.")
		end
		-- tags
		local seenPre = {}
		for _, tag in next, ReadTags(p) do
			for _, pre in next, { "Team_", "Faction_", "Side_", "Squad_" } do
				if type(tag) == "string" and string.sub(tag, 1, #pre) == pre then
					local suf = string.sub(tag, #pre + 1)
					if #suf > 0 and seenPre[pre] == nil then
						seenPre[pre] = true
						tally(tagVals, tagCov, pre, "S:" .. string.lower(suf))
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
	local okU, uid = pcall(function() return D.__index(Player, "UserId") end)
	if okU and uid ~= nil then
		TeamCache[uid] = nil
	end
end

-- One-time invalidation hooks per player (native team / neutral / attributes).
local HookTeamInvalidation = LPH(function(Player)
	local okU, uid = pcall(function() return D.__index(Player, "UserId") end)
	if not okU or uid == nil or TeamHooked[uid] then
		return
	end
	TeamHooked[uid] = true
	local function clearIt()
		TeamCache[uid] = nil
	end
	pcall(function()
		D.Connect(D.__index(Player, "GetPropertyChangedSignal")(Player, "Team"), clearIt)
	end)
	pcall(function()
		D.Connect(D.__index(Player, "GetPropertyChangedSignal")(Player, "TeamColor"), clearIt)
	end)
	pcall(function()
		D.Connect(D.__index(Player, "GetPropertyChangedSignal")(Player, "Neutral"), clearIt)
	end)
	pcall(function()
		D.Connect(D.__index(Player, "AttributeChanged"), LPH(function() clearIt() end))
	end)
end)

local function CustomSourcesExist()
	local adapter = D.Env.GameAdapter
	if type(adapter) == "table" and type(adapter.GetTeam) == "function" then
		return true
	end
	local cfg = D.Env.TeamResolver
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
local ResolveTeamInfo = LPH(function(Player)
	HookTeamInvalidation(Player)
	local cfg = D.Env.TeamResolver
	local now = D.Tick()
	local okU, uid = pcall(function() return D.__index(Player, "UserId") end)
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
	local adapter = D.Env.GameAdapter
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
		local okT, team = pcall(function() return D.__index(Player, "Team") end)
		local okN, neutral = pcall(function() return D.__index(Player, "Neutral") end)
		if okN and neutral == true then
			team = nil
		end
		local okC, tcolor = pcall(function() return D.__index(Player, "TeamColor") end)
		if mode == "Native" then
			if okT and team ~= nil then
				local okTN, tname = pcall(function() return D.__index(team, "Name") end)
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
				local okTN, tname = pcall(function() return D.__index(team, "Name") end)
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
			info.Confidence = math.clamp(wantAttr.Conf, 0, 0.95)
			info.TeamId = nid
			info.TeamName = v
			return commit()
		end
	end
	local wantVal = (mode == "Auto" or mode == "Values") and useKind("Values", TeamRanking.Value) or nil
	if wantVal ~= nil then
		local rel = wantVal.Key
		local v = nil
		if string.sub(rel, 1, 10) == "Character." then
			local okC, char = pcall(function() return D.__index(Player, "Character") end)
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
			info.Confidence = math.clamp(wantVal.Conf, 0, 0.9)
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
						if string.sub(tag, 1, #pre) == pre and best.Key == pre then
							info.Known = true
							info.Source = "Tag:" .. tag
							info.Confidence = math.clamp(best.Conf, 0, 0.8)
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
local LegacyPairTeammates = LPH(function(A, B)
	local Settings = D.Env.Settings
	local TA, TB
	pcall(function() TA = D.__index(A, "Team") end)
	pcall(function() TB = D.__index(B, "Team") end)
	if TA ~= nil and TB ~= nil then
		return TA == TB
	end
	if Settings.UseTeamColorFallback then
		local CA, CB
		pcall(function() CA = D.__index(A, "TeamColor") end)
		pcall(function() CB = D.__index(B, "TeamColor") end)
		if CA ~= nil and CB ~= nil then
			return CA == CB
		end
	end
	return false
end)

-- THE single team-relationship function. Everything else delegates here.
local IsSameTeam = LPH(function(A, B)
	if A == B then
		return true
	end
	local cfg = D.Env.TeamResolver
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
local IsTeammate = LPH(function(Player)
	local Settings = D.Env.Settings

	if Player == D.LocalPlayer then
		return true
	end

	if not Settings.TeamCheck then
		return false
	end

	return IsSameTeam(D.LocalPlayer, Player)
end)

local IsNeutral = LPH(function(Player)
	local Team
	pcall(function() Team = D.__index(Player, "Team") end)
	return Team == nil
end)

-- Friend list: one-time async build via the real Friends API, refreshed slowly.
local RefreshFriends = LPH(function()
	if FriendAPIUnavailable then
		return
	end
	local ok, err = pcall(function()
		local pages = D.__index(D.Players, "GetFriendsAsync")(D.Players, D.__index(D.LocalPlayer, "UserId"))
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
	FriendSetTime = D.Tick()
end)

local IsFriend = LPH(function(Player)
	if not D.Env.Settings.FriendCheck then
		return false
	end
	if Player == D.LocalPlayer then
		return false
	end
	if FriendAPIUnavailable then
		return false
	end
	local id
	pcall(function() id = D.__index(Player, "UserId") end)
	return id ~= nil and FriendSet[id] == true
end)

TR.AnalyzeSources = AnalyzeSources
TR.ClearTeamCache = ClearTeamCache
TR.ResolveTeamInfo = ResolveTeamInfo
TR.IsSameTeam = IsSameTeam
TR.IsTeammate = IsTeammate
TR.IsNeutral = IsNeutral
TR.RefreshFriends = RefreshFriends
TR.IsFriend = IsFriend

function TR.Init(deps)
	if type(deps) ~= "table" then
		error("TeamResolver.Init: deps table required")
	end
	for _, k in next, { "Index", "FindFirstChild", "GetService", "GetPlayers", "Players", "LocalPlayer", "Connect", "Tick", "Env" } do
		if deps[k] == nil then
			error("TeamResolver.Init: missing dep " .. tostring(k))
		end
		D[k] = deps[k]
	end
	pcall(function() TeamCS = D.GetService("CollectionService") end)
	return true
end

function TR.Forget(userId)
	if userId == nil then
		return
	end
	TeamCache[userId] = nil
	FriendSet[userId] = nil
end

function TR.ResetFriends()
	FriendSet = {}
end

function TR.MaybeRefreshFriends()
	if (D.Tick() - FriendSetTime) > 120 then
		RefreshFriends()
	end
end

function TR.GetRanking()
	return TeamRanking
end

function TR.FriendAPIOk()
	return not FriendAPIUnavailable
end

return Universery.TeamResolver
