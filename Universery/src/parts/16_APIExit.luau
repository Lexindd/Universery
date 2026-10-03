Environment.Exit = LPH_NO_VIRTUALIZE(function(self) -- ExunysDeveloperAimbot.Exit(self)
	assert(self, "EXUNYS_AIMBOT-V3.Exit: Missing parameter #1 \"self\" <table>.")

	for Index, _ in next, ServiceConnections do
		pcall(Disconnect, ServiceConnections[Index])
	end
	pcall(function() InputConflictController:EnsureReleased() end)

	PlayerCache = {}
	VisibilityCache = {}
	FriendSet = {}
	ResetTargetState()
	pcall(function() ESPCleanup() end)
	pcall(function()
		if Environment.SilentAimCtl ~= nil then
			Environment.SilentAimCtl.Shutdown()
		end
	end)
	-- Full unload: connection-level network stats go too (respawn/target-change keeps them).
	PingState.Raw = 0
	PingState.Smoothed = 0
	PingState.Min = 0
	PingState.Max = 0
	PingState.Jitter = 0
	PingState.Samples = {}
	PingState.Quality = "Unknown"
	PingState.Correction = 1
	PingState.ErrBuf = {}
	PingState.LastPred = nil
	PingState.Effective = 0
	PingState.Available = false

	Load = nil; ConvertVector = nil; CancelLock = nil; GetClosestPlayer = nil; GetRainbowColor = nil; FixUsername = nil
	IsValidTarget = nil; RefreshScan = nil; ScoreTarget = nil; IsTeammate = nil

	self.FOVCircle:Remove()
	self.FOVCircleOutline:Remove()
	self.Tracer:Remove()
	if self.LockRadiusCircle ~= nil then
		pcall(function() self.LockRadiusCircle:Remove() end)
	end

	getgenv().ExunysDeveloperAimbot = nil; pcall(collectgarbage, "step", 200)
end)

Environment.Panic = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.Panic(<void>)
	-- Emergency stop: aim loop halts (Running=false), lock + target state cleared,
	-- prediction/smoothing stop with the lock, aimbot output disabled. UI stays alive.
	Running = false
	CancelLock()
	Environment.Settings.Enabled = false
	pcall(function() Environment.ESP.Panicked = true end)
end)

Environment.Restart = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.Restart(<void>)
	for Index, _ in next, ServiceConnections do
		pcall(Disconnect, ServiceConnections[Index])
	end

	Load()
end)

Environment.Blacklist = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Blacklisted(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")

	self.Blacklisted[#self.Blacklisted + 1] = Username
end)

Environment.Whitelist = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Whitelist(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")

	local Index = tablefind(self.Blacklisted, Username)

	assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")

	tableremove(self.Blacklisted, Index)
end)

Environment.Prioritize = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Prioritize(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Prioritize: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Prioritize: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(Username, "EXUNYS_AIMBOT-V3.Prioritize: User "..Username.." couldn't be found.")

	if not tablefind(self.PriorityPlayers, Username) then
		self.PriorityPlayers[#self.PriorityPlayers + 1] = Username
	end
end)

Environment.Deprioritize = LPH_NO_VIRTUALIZE(function(self, Username) -- ExunysDeveloperAimbot.Deprioritize(self, <string> Player Name)
	assert(self, "EXUNYS_AIMBOT-V3.Deprioritize: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Deprioritize: Missing parameter #2 \"Username\" <string>.")

	local Index = tablefind(self.PriorityPlayers, Username)

	if Index then
		tableremove(self.PriorityPlayers, Index)
	end
end)

Environment.GetClosestPlayer = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.GetClosestPlayer(<void>)
	return GetClosestPlayer(true)
end)

-- Developer scan: inspect the current game ONCE and report candidate team sources
-- with confidence + evidence. Nothing is auto-enabled; configure TeamResolver
-- manually from the results (Mode / ManualAttribute / ManualValuePath / adapter).
Environment.ScanTeamSources = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.ScanTeamSources(<void>)
	AnalyzeSources(true)
	local cfg = Environment.TeamResolver
	_warn("[Aimbot] TEAM SCAN (mode " .. tostring(cfg.Mode) .. ", native-diverse: " .. tostring(TeamRanking.NativeDiverse) .. ")")
	local function dump(title, list, show)
		_warn("[Aimbot] Possible " .. title .. ":")
		if #list < 1 then
			_warn("   (none found)")
			return
		end
		for i = 1, math.min(#list, show or 5) do
			local e = list[i]
			_warn("   " .. tostring(e.Key) .. " conf " .. string.format("%.2f", e.Conf) .. " distinct " .. tostring(e.Distinct))
		end
	end
	dump("Team Attributes", TeamRanking.Attr)
	dump("Values", TeamRanking.Value)
	dump("Tags", TeamRanking.Tag)
	local rec = "Native (meaningful)"
	if not TeamRanking.NativeDiverse then
		if #TeamRanking.Attr > 0 and TeamRanking.Attr[1].Conf >= (cfg.ConfidenceThreshold or 0.6) then
			rec = "Attribute:" .. tostring(TeamRanking.Attr[1].Key)
		elseif #TeamRanking.Value > 0 and TeamRanking.Value[1].Conf >= (cfg.ConfidenceThreshold or 0.6) then
			rec = "Value:" .. tostring(TeamRanking.Value[1].Key)
		elseif #TeamRanking.Tag > 0 and TeamRanking.Tag[1].Conf >= (cfg.ConfidenceThreshold or 0.6) then
			rec = "Tag prefix:" .. tostring(TeamRanking.Tag[1].Key)
		else
			rec = "none confident - set ManualAttribute/ManualValuePath or a GameAdapter"
		end
	end
	_warn("[Aimbot] Recommended source: " .. rec)
	return { Attributes = TeamRanking.Attr, Values = TeamRanking.Value, Tags = TeamRanking.Tag, NativeDiverse = TeamRanking.NativeDiverse, Recommended = rec }
end)

Environment.GetTargetInfo = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.GetTargetInfo(<void>)
	local locked = Environment.Locked
	local info = {
		Target = nil,
		Score = LockMeta.LastScore,
		FOV = LastBreakdown.FOV,
		Distance = LastBreakdown.Distance,
		Visibility = LastBreakdown.Visibility,
		Confidence = VelocityState.Confidence,
		Velocity = VelocityState.AvgVelocity.Magnitude,
		Stable = VelocityState.Stable,
		EffTime = PingState.Effective or 0,
		Ping = mathfloor(PingState.Smoothed or 0),
		Network = PingState.Quality,
		Method = LastAimData.Method,
		ScreenX = LastAimData.SX,
		ScreenY = LastAimData.SY,
		PredX = LastAimData.PX,
		PredY = LastAimData.PY,
		PredZ = LastAimData.PZ
	}
	if locked ~= nil then
		pcall(function() info.Target = __index(locked, "Name") end)
	end
	return info
end)

Environment.Load = Load -- ExunysDeveloperAimbot.Load()

Environment.GetDiagnostics = LPH_NO_VIRTUALIZE(function() -- ExunysDeveloperAimbot.GetDiagnostics(<void>)
	local lockedName = "none"
	if Environment.Locked ~= nil then
		pcall(function() lockedName = __index(Environment.Locked, "Name") end)
	end
	return {
		Drawing = DrawingAvailable,
		FriendAPI = not FriendAPIUnavailable,
		PlayersCached = #PlayerCache,
		Locked = lockedName,
		Running = Running,
		Enabled = Environment.Settings.Enabled,
		TeamCheck = Environment.Settings.TeamCheck,
		WallCheck = Environment.Settings.WallCheck,
		Ping = mathfloor(PingState.Raw or 0),
		SmoothedPing = mathfloor(PingState.Smoothed or 0),
		Jitter = mathfloor(PingState.Jitter or 0),
		Network = PingState.Quality,
		EffTime = PingState.Effective or 0,
		Correction = PingState.Correction or 1,
		AcqFOV = Environment.FOVSettings.Radius or 180,
		RetainRadius = LockMeta.RetainRadius or 0,
		GracePeriod = Environment.Settings.TargetGracePeriod or 0.1,
		ConflictState = ConflictState.Kind or "NONE",
		ConflictDetail = tostring(ConflictState.Detail or ""),
		ConflictKey = tostring(Environment.Settings.TriggerKey),
		SinkActive = ConflictState.Suppressed == true,
		TeamSource = (function()
			local s, c, t = "?", 0, "?"
			pcall(function()
				local li = ResolveTeamInfo(LocalPlayer)
				if li ~= nil then
					s = tostring(li.Source or "?")
					c = li.Confidence or 0
				end
				if Environment.Locked ~= nil then
					local ti = ResolveTeamInfo(Environment.Locked)
					if ti ~= nil and type(ti.TeamName) == "string" then
						t = tostring(ti.TeamName)
					end
				end
			end)
			return s
		end)(),
		TeamConfidence = (function()
			local c = 0
			pcall(function()
				local li = ResolveTeamInfo(LocalPlayer)
				if li ~= nil then
					c = li.Confidence or 0
				end
			end)
			return c
		end)(),
		TargetTeam = (function()
			local t = "?"
			pcall(function()
				if Environment.Locked ~= nil then
					local ti = ResolveTeamInfo(Environment.Locked)
					if ti ~= nil and type(ti.TeamName) == "string" then
						t = tostring(ti.TeamName)
					end
				end
			end)
			return t
		end)()
	}
end)

setmetatable(Environment, {__call = Load})

