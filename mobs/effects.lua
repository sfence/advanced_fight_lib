
attributes_effects.register_value_effect("mobs:shoot_inaccuracy", {
	cb_is_available = function(effect_def, obj)
		local luaent = obj:get_luaentity()
		return mobs.spawning_mobs[luaent.name] ~= nil --and 
		--		(luaent.attack_type == "dogshoot" or luaent.attack_type == "shoot")
	end,
	cb_get_value = function(effect_def, obj)
		return obj:get_luaentity().shoot_inaccuracy or 0
	end,
	cb_calculate_value = function(effect_def, orig_value, value_list)
		return attributes_effects.default_calculate_value(effect_def, orig_value, value_list)
	end,
	cb_set_value = function(effect_def, obj, calc_value)
		local luaent = obj:get_luaentity()
		if luaent then
			luaent.shoot_inaccuracy = calc_value
		end
	end,
})

function advanced_fight_lib.apply_inaccuracy_to_arrow(guid, inaccuracy)
	print("Applying inaccuracy to arrow "..guid.." inaccuracy: "..inaccuracy)
	local arrow_obj = core.objects_by_guid[guid]
	if not arrow_obj then
		return
	end

	local vel = arrow_obj:get_velocity()
	--print("Original vel: "..dump(vel))

	local rot = vector.new(
			math.random()*math.pi*2,
			math.random()*math.pi*2, 0)
	local rot_axis = vector.rotate(vector.new(0, 0, 1), rot)

	inaccuracy = math.rad(2 * (math.random() - 0.5) * inaccuracy)
	vel = vector.rotate_around_axis(vel, rot_axis, inaccuracy)

	--print("New vel: "..dump(vel))
	arrow_obj:set_velocity(vel)
end
