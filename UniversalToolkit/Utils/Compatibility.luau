-- UniversalToolkit.Utils.Compatibility
-- Ortam tespiti. Eksik API'de crash yerine UNAVAILABLE döndürmek için kullanılır.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Compatibility = {}

function Compatibility:IsStudio(): boolean
	local ok, result = pcall(function()
		return RunService:IsStudio()
	end)
	if not ok then
		return false
	end
	return result == true
end

function Compatibility:HasKeyboard(): boolean
	local ok, result = pcall(function()
		return UserInputService.KeyboardEnabled
	end)
	return ok and result == true
end

function Compatibility:HasMouse(): boolean
	local ok, result = pcall(function()
		return UserInputService.MouseEnabled
	end)
	return ok and result == true
end

function Compatibility:HasTouch(): boolean
	local ok, result = pcall(function()
		return UserInputService.TouchEnabled
	end)
	return ok and result == true
end

function Compatibility:HasGamepad(): boolean
	local ok, result = pcall(function()
		return UserInputService.GamepadEnabled
	end)
	return ok and result == true
end

function Compatibility:IsMobile(): boolean
	return self:HasTouch() and not self:HasKeyboard()
end

function Compatibility:HasExecutorFn(name: string): boolean
	-- getgenv, writefile, readfile, loadstring vb. executor'e özeldir.
	-- typeof/getfenv ile güvenli kontrol.
	local ok, fn = pcall(function()
		return (getgenv and getgenv()[name]) or (_G and (_G :: any)[name])
	end)
	if not ok then
		return false
	end
	return type(fn) == "function"
end

function Compatibility:CanWriteFile(): boolean
	return type(writefile) == "function" and type(isfolder) == "function"
end

function Compatibility:CanReadFile(): boolean
	return type(readfile) == "function" and type(isfile) == "function"
end

function Compatibility:Summary(): { [string]: boolean }
	return {
		IsStudio = self:IsStudio(),
		Keyboard = self:HasKeyboard(),
		Mouse = self:HasMouse(),
		Touch = self:HasTouch(),
		Gamepad = self:HasGamepad(),
		CanWriteFile = self:CanWriteFile(),
		CanReadFile = self:CanReadFile(),
	}
end

return Compatibility
