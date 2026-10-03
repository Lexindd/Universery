-- registry: the single shared Universery table.
-- Loaded first; every other module receives it via Require("registry").

local Universery = {
	Version = "2-b",
}

return Universery
