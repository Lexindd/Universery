local function BuildESPTab()

--// ESP TAB (controls only; engine lives in aimbot.txt ESPController)

local function espT(sec, flag, label, def, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Toggle({
		Name = label,
		Default = def,
		Callback = function(v) Write(key, v) end,
	}, flag)
	syncer(function() return El[flag]:GetState() end, function(v) Write(key, v) end)
end

local function espS(sec, flag, label, def, mn, mx, prec, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Slider({
		Name = label,
		Default = def,
		Minimum = mn,
		Maximum = mx,
		DisplayMethod = "Value",
		Precision = prec,
		Callback = function(v) Write(key, v) end,
	}, flag)
	syncer(function() return El[flag]:GetValue() end, function(v) Write(key, v) end)
end

local function espD(sec, flag, label, options, defIdx, apply)
	if sec == nil then
		return
	end
	El[flag] = sec:Dropdown({
		Name = label,
		Search = false,
		Multi = false,
		Required = true,
		Options = options,
		Default = defIdx,
		Callback = function(v) apply(v) end,
	}, flag)
	syncer(function() return El[flag].Value end, function(v) apply(v) end)
end

local function espC(sec, flag, label, def, key)
	if sec == nil then
		return
	end
	El[flag] = sec:Colorpicker({
		Name = label,
		Default = def,
		Alpha = 0,
		Callback = function(c) Write(key, c) end,
	}, flag)
	syncer(function() return El[flag].Color end, function(v) Write(key, v) end)
end

local ESPMain = MakeSection("ESP", "Left")
if ESPMain ~= nil then
	ESPMain:Header({ Text = "Main" })

	El.ESP_Enabled = ESPMain:Toggle({
		Name = "Enable ESP",
		Default = false,
		Callback = function(v)
			Write("ESP_Enabled", v)
			pcall(function()
				local A = Aim()
				if A ~= nil then
					A.ESP.Panicked = false
				end
			end)
		end,
	}, "ESP_Enabled")
	syncer(function() return El.ESP_Enabled:GetState() end, function(v) Write("ESP_Enabled", v) end)

	espT(ESPMain, "ESP_TeamCheck", "Team Check", true, "ESP_TeamCheck")
	espT(ESPMain, "ESP_ShowTeam", "Show Team", false, "ESP_ShowTeam")
	espT(ESPMain, "ESP_Visibility", "Visibility Check", false, "ESP_Visibility")
	espT(ESPMain, "ESP_UseTeamColors", "Use Team Colors", true, "ESP_UseTeamColors")
	espS(ESPMain, "ESP_MaxDistance", "Max Distance", 1000, 100, 5000, 0, "ESP_MaxDistance")
	espS(ESPMain, "ESP_RefreshFPS", "Refresh Rate (FPS)", 144, 1, 144, 0, "ESP_RefreshFPS")
	espD(ESPMain, "ESP_RefreshMode", "Refresh Mode", { "Fixed", "Half FPS", "Full FPS" }, 2, function(v)
		if v == "Half FPS" then
			Write("ESP_RefreshMode", "Half")
		elseif v == "Full FPS" then
			Write("ESP_RefreshMode", "Full")
		else
			Write("ESP_RefreshMode", "Fixed")
		end
	end)
	espS(ESPMain, "ESP_FadeDistance", "Fade Distance", 500, 20, 1000, 0, "ESP_FadeDistance")
	El.ESP_DistanceFade = ESPMain:Toggle({
		Name = "Distance Fade",
		Default = true,
		Callback = function(v)
			print("[AimbotUI] DistanceFade toggled -> " .. tostring(v))
			Write("ESP_DistanceFade", v)
			local A = Aim()
			print("[AimbotUI] DistanceFade now: " .. tostring(A ~= nil and A.ESP.DistanceFade))
		end,
	}, "ESP_DistanceFade")
	syncer(function() return El.ESP_DistanceFade:GetState() end, function(v) Write("ESP_DistanceFade", v) end)
	espT(ESPMain, "ESP_ShowDistance", "Distance", true, "ESP_ShowDistance")
	espS(ESPMain, "ESP_ScreenYOffset", "Screen Y Offset", 0, -72, 72, 0, "ESP_ScreenYOffset")
	espC(ESPMain, "ESP_EnemyColor", "Enemy Color", Color3.fromRGB(255, 255, 255), "ESP_EnemyColor")
	espC(ESPMain, "ESP_AllyColor", "Ally Color", Color3.fromRGB(25, 255, 25), "ESP_AllyColor")
end

local ESPBox = MakeSection("ESP", "Right")
if ESPBox ~= nil then
	ESPBox:Header({ Text = "Box ESP" })

	espT(ESPBox, "ESP_Box", "Enable", false, "ESP_Box")
	espD(ESPBox, "ESP_BoxStyle", "Style", { "Corner", "Full", "3D" }, 2, function(v)
		if v == "3D" then
			Write("ESP_BoxStyle", "ThreeD")
		else
			Write("ESP_BoxStyle", v)
		end
	end)
	espT(ESPBox, "ESP_BoxOutline", "Outline", true, "ESP_BoxOutline")
	espT(ESPBox, "ESP_BoxFilled", "Filled", false, "ESP_BoxFilled")
	espS(ESPBox, "ESP_BoxFillTransparency", "Fill Transparency", 0.5, 0, 1, 2, "ESP_BoxFillTransparency")
	espS(ESPBox, "ESP_BoxThickness", "Thickness", 1, 1, 5, 1, "ESP_BoxThickness")
	espC(ESPBox, "ESP_BoxColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_BoxColor")
	espT(ESPBox, "ESP_IncludeAccessories", "Include Accessories", false, "ESP_IncludeAccessories")
end

local ESPTracer = MakeSection("ESP", "Left")
if ESPTracer ~= nil then
	ESPTracer:Header({ Text = "Tracer" })

	espT(ESPTracer, "ESP_Tracer", "Enable", true, "ESP_Tracer")
	espD(ESPTracer, "ESP_TracerOrigin", "Origin", { "Bottom", "Top", "Mouse", "Center" }, 1, function(v)
		Write("ESP_TracerOrigin", v)
	end)
	espS(ESPTracer, "ESP_TracerThickness", "Thickness", 1, 1, 5, 0, "ESP_TracerThickness")
	espC(ESPTracer, "ESP_TracerColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_TracerColor")
	espT(ESPTracer, "ESP_Snaplines", "Snapline", false, "ESP_Snaplines")
end

local ESPSkel = MakeSection("ESP", "Right")
if ESPSkel ~= nil then
	ESPSkel:Header({ Text = "Skeleton" })

	espT(ESPSkel, "ESP_Skeleton", "Enable", false, "ESP_Skeleton")
	espC(ESPSkel, "ESP_SkeletonColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_SkeletonColor")
	espS(ESPSkel, "ESP_SkeletonThickness", "Thickness", 1.5, 1, 3, 1, "ESP_SkeletonThickness")
	espS(ESPSkel, "ESP_SkeletonTransparency", "Transparency", 0, 0, 1, 2, "ESP_SkeletonTransparency")
end

local ESPHealth = MakeSection("ESP", "Left")
if ESPHealth ~= nil then
	ESPHealth:Header({ Text = "Health" })

	espT(ESPHealth, "ESP_Health", "Enable", false, "ESP_Health")
	espD(ESPHealth, "ESP_HealthStyle", "Style", { "Bar", "Text", "Both" }, 1, function(v)
		Write("ESP_HealthStyle", v)
	end)
	espD(ESPHealth, "ESP_HealthSide", "Side", { "Left", "Right" }, 1, function(v)
		Write("ESP_HealthSide", v)
	end)
	espD(ESPHealth, "ESP_HealthFormat", "Format", { "Number", "Percentage", "Both" }, 1, function(v)
		Write("ESP_HealthFormat", v)
	end)
	espC(ESPHealth, "ESP_HealthFullColor", "Full HP Color", Color3.fromRGB(0, 255, 0), "ESP_HealthFullColor")
end

local ESPName = MakeSection("ESP", "Right")
if ESPName ~= nil then
	ESPName:Header({ Text = "Name / Info" })

	espT(ESPName, "ESP_Name", "Name", false, "ESP_Name")
	espD(ESPName, "ESP_NameMode", "Name Mode", { "DisplayName", "Username" }, 1, function(v)
		Write("ESP_NameMode", v)
	end)
	espS(ESPName, "ESP_TextSize", "Text Size", 14, 10, 24, 0, "ESP_TextSize")
	espD(ESPName, "ESP_TextFont", "Font", { "UI", "System", "Plex", "Monospace" }, 3, function(v)
		local map = { UI = 0, System = 1, Plex = 2, Monospace = 3 }
		Write("ESP_TextFont", map[v] or 2)
	end)
	espC(ESPName, "ESP_NameColor", "Color", Color3.fromRGB(255, 255, 255), "ESP_NameColor")
end

local ESPChams = MakeSection("ESP", "Left")
if ESPChams ~= nil then
	ESPChams:Header({ Text = "Chams" })

	espT(ESPChams, "ESP_Chams", "Enable", false, "ESP_Chams")
	espC(ESPChams, "ESP_ChamsFill", "Fill Color", Color3.fromRGB(255, 0, 0), "ESP_ChamsFill")
	espC(ESPChams, "ESP_ChamsOccluded", "Occluded Color", Color3.fromRGB(150, 0, 0), "ESP_ChamsOccluded")
	espC(ESPChams, "ESP_ChamsOutline", "Outline Color", Color3.fromRGB(255, 255, 255), "ESP_ChamsOutline")
	espS(ESPChams, "ESP_ChamsTransparency", "Transparency", 0.5, 0, 1, 2, "ESP_ChamsTransparency")
	espS(ESPChams, "ESP_ChamsOutlineTransparency", "Outline Transparency", 0, 0, 1, 2, "ESP_ChamsOutlineTransparency")
end

local ESPRainbow = MakeSection("ESP", "Right")
if ESPRainbow ~= nil then
	ESPRainbow:Header({ Text = "Rainbow / Effects" })

	espT(ESPRainbow, "ESP_Rainbow", "Rainbow", false, "ESP_Rainbow")
	espS(ESPRainbow, "ESP_RainbowSpeed", "Rainbow Speed", 1, 0.1, 5, 1, "ESP_RainbowSpeed")
	local function applyRainbowParts(v)
		local A = Aim()
		if A == nil then
			return
		end
		pcall(function()
			if v == "All" then
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = true
			elseif v == "Box Only" then
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = false
				A.ESP.RainbowText = false
			elseif v == "Tracers Only" then
				A.ESP.RainbowBoxes = false
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = false
			elseif v == "Text Only" then
				A.ESP.RainbowBoxes = false
				A.ESP.RainbowTracers = false
				A.ESP.RainbowText = true
			end
		end)
	end
	espD(ESPRainbow, "ESP_RainbowParts", "Rainbow Parts", { "All", "Box Only", "Tracers Only", "Text Only" }, 1, applyRainbowParts)
	syncer(function() return El.ESP_RainbowParts.Value end, function(v) applyRainbowParts(v) end)

	ESPRainbow:Button({
		Name = "Reset ESP Settings",
		Callback = function()
			local A = Aim()
			if A == nil then
				Notify("ESP Reset", "Failed: aimbot missing.")
				return
			end
			pcall(function()
				A.ESP.Enabled = false
				A.ESP.Panicked = false
				A.ESP.TeamCheck = true
				A.ESP.ShowTeam = false
				A.ESP.VisibilityCheck = false
				A.ESP.MaxDistance = 1000
				A.ESP.RefreshFPS = 144
				A.ESP.RefreshMode = "Half"
				A.ESP.FadeDistance = 500
				A.ESP.UseTeamColors = true
				A.ESP.EnemyColor = Color3.fromRGB(255, 255, 255)
				A.ESP.AllyColor = Color3.fromRGB(25, 255, 25)
				A.ESP.BoxESP = false
				A.ESP.BoxStyle = "Full"
				A.ESP.BoxOutline = true
				A.ESP.BoxFilled = false
				A.ESP.BoxFillTransparency = 0.5
				A.ESP.BoxThickness = 1
				A.ESP.BoxColor = Color3.fromRGB(255, 255, 255)
				A.ESP.TracerESP = true
				A.ESP.TracerOrigin = "Bottom"
				A.ESP.TracerThickness = 1
				A.ESP.TracerColor = Color3.fromRGB(255, 255, 255)
				A.ESP.Snaplines = false
				A.ESP.HealthESP = false
				A.ESP.HealthStyle = "Bar"
				A.ESP.HealthBarSide = "Left"
				A.ESP.HealthFormat = "Number"
				A.ESP.HealthFullColor = Color3.fromRGB(0, 255, 0)
				A.ESP.NameESP = false
				A.ESP.NameMode = "DisplayName"
				A.ESP.ShowDistance = true
				A.ESP.TextSize = 14
				A.ESP.TextFont = 2
				A.ESP.ScreenYOffset = 0
				A.ESP.NameColor = Color3.fromRGB(255, 255, 255)
				A.ESP.RainbowEnabled = false
				A.ESP.RainbowSpeed = 1
				A.ESP.RainbowBoxes = true
				A.ESP.RainbowTracers = true
				A.ESP.RainbowText = true
				A.ESP.ChamsEnabled = false
				A.ESP.ChamsFillColor = Color3.fromRGB(255, 0, 0)
				A.ESP.ChamsOccludedColor = Color3.fromRGB(150, 0, 0)
				A.ESP.ChamsOutlineColor = Color3.fromRGB(255, 255, 255)
				A.ESP.ChamsTransparency = 0.5
				A.ESP.ChamsOutlineTransparency = 0
				A.ESP.SkeletonESP = false
				A.ESP.SkeletonColor = Color3.fromRGB(255, 255, 255)
				A.ESP.SkeletonThickness = 1.5
				A.ESP.SkeletonTransparency = 0
			end)
			local function rT(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateState(v) end) end end
			local function rS(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateValue(v) end) end end
			local function rD(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:UpdateSelection(v) end) end end
			local function rC(idx, v) if El[idx] ~= nil then pcall(function() El[idx]:SetColor(v) end) end end
			rT("ESP_Enabled", false)
			rT("ESP_TeamCheck", true)
			rT("ESP_ShowTeam", false)
			rT("ESP_Visibility", false)
			rT("ESP_UseTeamColors", true)
			rS("ESP_MaxDistance", 1000)
			rS("ESP_RefreshFPS", 144)
			rD("ESP_RefreshMode", "Half FPS")
			rS("ESP_FadeDistance", 500)
			rC("ESP_EnemyColor", Color3.fromRGB(255, 255, 255))
			rC("ESP_AllyColor", Color3.fromRGB(25, 255, 25))
			rT("ESP_Box", false)
			rD("ESP_BoxStyle", "Full")
			rT("ESP_BoxOutline", true)
			rT("ESP_BoxFilled", false)
			rS("ESP_BoxFillTransparency", 0.5)
			rS("ESP_BoxThickness", 1)
			rC("ESP_BoxColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_IncludeAccessories", false)
			rT("ESP_Tracer", true)
			rD("ESP_TracerOrigin", "Bottom")
			rS("ESP_TracerThickness", 1)
			rC("ESP_TracerColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_Snaplines", false)
			rT("ESP_Health", false)
			rD("ESP_HealthStyle", "Bar")
			rD("ESP_HealthSide", "Left")
			rD("ESP_HealthFormat", "Number")
			rC("ESP_HealthFullColor", Color3.fromRGB(0, 255, 0))
			rT("ESP_Name", false)
			rD("ESP_NameMode", "DisplayName")
			rT("ESP_ShowDistance", true)
			rT("ESP_DistanceFade", true)
			rS("ESP_TextSize", 14)
			rS("ESP_ScreenYOffset", 0)
			rD("ESP_TextFont", "Plex")
			rC("ESP_NameColor", Color3.fromRGB(255, 255, 255))
			rT("ESP_Rainbow", false)
			rS("ESP_RainbowSpeed", 1)
			rD("ESP_RainbowParts", "All")
			rT("ESP_Chams", false)
			rC("ESP_ChamsFill", Color3.fromRGB(255, 0, 0))
			rC("ESP_ChamsOccluded", Color3.fromRGB(150, 0, 0))
			rC("ESP_ChamsOutline", Color3.fromRGB(255, 255, 255))
			rS("ESP_ChamsTransparency", 0.5)
			rS("ESP_ChamsOutlineTransparency", 0)
			rT("ESP_Skeleton", false)
			rC("ESP_SkeletonColor", Color3.fromRGB(255, 255, 255))
			rS("ESP_SkeletonThickness", 1.5)
			rS("ESP_SkeletonTransparency", 0)
			Notify("ESP Reset", "ESP settings reset to defaults.")
		end,
	})
end
end

BuildESPTab()

--// DEBUG TAB (throttled reads of existing public APIs only)

