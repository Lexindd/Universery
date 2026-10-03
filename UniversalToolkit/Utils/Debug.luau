-- UniversalToolkit.Utils.Debug
-- Kapatılabilir debug çıktısı. Üretimde sessiz kalır.

local Debug = {}
Debug.Enabled = false

function Debug:SetEnabled(state: boolean)
	self.Enabled = state == true
end

function Debug:Log(...)
	if not self.Enabled then
		return
	end
	print("[Toolkit]", ...)
end

function Debug:Warn(...)
	if not self.Enabled then
		return
	end
	warn("[Toolkit]", ...)
end

function Debug:Error(...)
	if not self.Enabled then
		return
	end
	warn("[Toolkit][Error]", ...)
end

return Debug
