
local dir_path = core.get_modpath(core.get_current_modname()).."/mobs"

if mobs.mod ~= "redo" then
	core.log("error",
			"[advanced_fight] mobs redo mod required for advanced_fight mobs support")
	error "mobs redo mod required"
end
local mobs_version = tonumber(mobs.version) or 0
if mobs_version < 20251117 then
	core.log("error",
			"[advanced_fight] mobs redo mod version 20251117 or higher required")
	error "mobs redo mod version 20251117 or higher required"
end

dofile(dir_path.."/functions.lua")
dofile(dir_path.."/effects.lua")

