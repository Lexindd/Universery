-- 00_registry: the single shared table. FIRST in dist, before everything.
-- Inter-module sharing goes ONLY through Universery.* fields.
-- Module files must not create chunk-level locals for shared state.

local Universery = {
	Version = "2-a",
}
