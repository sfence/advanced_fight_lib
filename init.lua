
advanced_fight_lib = {}

local mod_path = core.get_modpath(core.get_current_modname())

dofile(mod_path.."/functions.lua")
dofile(mod_path.."/storage.lua")

dofile(mod_path.."/parts/init.lua")
dofile(mod_path.."/entity/init.lua")
dofile(mod_path.."/player/init.lua")

if core.get_modpath("mobs") then
	dofile(mod_path.."/mobs/init.lua")
end