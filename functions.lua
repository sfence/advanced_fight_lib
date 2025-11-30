
function advanced_fight_lib.get_entity(name_list)
	for _, ent_name in pairs(name_list) do
		local ent = core.registered_entities[ent_name]
		if ent then
			return ent_name, ent
		end
	end
	return nil, nil
end

function advanced_fight_lib.object_body_parts_health(obj, storage, parts)
	storage._parts_health = {}
	local props = obj:get_properties()
	local max_health = props.hp_max
	for key, part in pairs(parts) do
		--print("key: "..key)
		local part_health = math.max(1, math.round(part.part_of_health * max_health))
		storage._parts_health[key] = {
			max_health = part_health,
			health = part_health,
		}
	end
end

function advanced_fight_lib.compute_effect(damage, data)
	if damage < data.threshold_start then
		return data.base_value
	elseif damage < data.threshold_peak then
		local t = (damage - data.threshold_start) / (data.threshold_peak - data.threshold_start)
		return data.base_value + t * (data.peak_value - data.base_value)
	else
		local overshoot = damage - data.threshold_peak
		local decay = 1 - math.exp(-data.curve * overshoot)
		return data.peak_value + decay * (data.over_value - data.peak_value)
	end
end

function advanced_fight_lib.create_effects_group_from_values(obj, label, values)
	return attributes_effects.add_effects_group_to_object(obj:get_guid(), label, {
		values = values,
		cb_update = function(self, obj, dtime, add_value)
			local verbose = attributes_effects.objects_list[obj:get_guid()].verbose
			local storage = advanced_fight_lib.get_object_storage(obj)
			local is_zero = true
			for name, data in pairs(self.values) do
				local damage
				if data.cb_calculate_damage then
					damage = data:cb_calculate_damage(obj)
				else
					local part = storage._parts_health[data.name]
					damage = 1.0 - part.health / part.max_health
					if verbose then
						print("  part health: "..part.health.." max_health: "..part.max_health)
					end
				end
				if verbose then
					print("  damage: "..damage)
				end
				if damage > 0.0 then is_zero = false end
				local computed = advanced_fight_lib.compute_effect(damage, data)
				local value = {
					value = computed * data.value,
					rule = data.rule,
					privilege = data.privilege,
				}

				if data.cb_on_update then
					data:cb_on_update(obj, hit_data, value)
				end

				add_value(obj, name, value)
			end
			if verbose then
				print("  is_zero: "..tostring(is_zero))
			end
			return not is_zero
		end
	})
end

function advanced_fight_lib.object_on_respawn(obj, storage)
	local hitgroup_name = hitboxes_lib.get_hitgroup_name(obj)
	local hitgroup = hitboxes_lib.hitbox_groups[hitgroup_name]
	
	advanced_fight_lib.object_body_parts_health(obj, storage, hitgroup)
	for key, part in pairs(hitgroup) do
		if part.effects then
			for effect_key, effect in pairs(part.effects) do
				if effect.cb_on_respawn then
					effect:cb_on_respawn(obj)
				elseif effect.part_damage_key then
					-- reset part damage
					local damage_key = effect.part_damage_key
					local part_storage = storage._parts_health[key]
					if part_storage[damage_key] then
						part_storage[damage_key] = nil
					end
				end
			end
		end
	end
end

function advanced_fight_lib.object_on_load(obj, storage)
	local hitgroup_name = hitboxes_lib.get_hitgroup_name(obj)
	local hitgroup = hitboxes_lib.hitbox_groups[hitgroup_name]
	
	if storage._parts_health then
		for key, part in pairs(hitgroup) do
			print("Loading part: "..key)
			if part.on_load then
				part:on_load(obj, storage)
			end
			if part.effects then
				for effect_key, effect in pairs(part.effects) do
					if effect.on_load then
						print("Calling on_load for effect: "..effect_key.." of part: "..key)
						effect:on_load(obj, storage)
					end
				end
			end
		end
	end
end

function advanced_fight_lib.object_on_heal(obj, storage, heal_amount, heal_data)
	local hitgroup_name = hitboxes_lib.get_hitgroup_name(obj)
	local hitgroup = hitboxes_lib.hitbox_groups[hitgroup_name]
	
	for key, part in pairs(hitgroup) do
		local heal_multiplier = part.heal_multiplier or part.damage_multiplier or 1.0
		local part = storage._parts_health[key]
		if part.health < part.max_health then
			part.health = math.min(
					part.health + heal_amount * heal_multiplier,
					part.max_health)
		end
		if part.effects then
			for effect_key, effect in pairs(part.effects) do
				if effect.cb_on_heal then
					effect:cb_on_heal(obj, heal_amount, heal_data)
				elseif effect.part_damage_key then
					-- reset part damage
					
				end
			end
		end
	end
end

function advanced_fight_lib.create_point_hit_effect(data)
	local effect = table.copy(data)

	if not effect.points then
		core.log("error",
				"[advanced_fight] advanced_fight_lib.create_point_hit_effect: no points defined")
		return nil
	end
	if not effect.points_size then
		core.log("error",
				"[advanced_fight] advanced_fight_lib.create_point_hit_effect: no points_size defined")
		return nil
	end
	if not effect.points_axis then
		core.log("error",
				"[advanced_fight] advanced_fight_lib.create_point_hit_effect: no points_axis defined")
		return nil
	end

	if not effect.points_max_health then
		core.log("error",
				"[advanced_fight] advanced_fight_lib.create_point_hit_effect: no points_max_health defined")
		return nil
	end

	effect.cb_add_effect = function(self, obj, hit_data)
		--print("hit_data.details: "..dump(hit_data.details))
		local global_axis_valid = true
		local per_point_axis_check = true
		if type(self.points_axis)~="table" then
			global_axis_valid = self.points_axis == hit_data.details.hit_axis
			per_point_axis_check = false
		end
		local point_axis = self.points_axis
		if global_axis_valid then
			print("Rel pos: "..core.pos_to_string(hit_data.details.hit_relative))
			for point_index, point in pairs(self.points) do
				local axis_valid = true
				if per_point_axis_check then
					point_axis = self.points_axis[point_index]
					axis_valid = point_axis == hit_data.details.hit_axis
				end
				if axis_valid then
					point = table.copy(point)
					local hit_rel = hit_data.details.hit_relative
					local axis = string.sub(point_axis, 1, 1)
					point[axis] = hit_rel[axis]
					local dist = vector.distance(hit_rel, point)
					local point_size = self.points_size
					if type(self.points_size)=="table" then
						point_size = self.points_size[point_index]
					end
					print("dist: "..dist.." point_size: "..point_size)
					if dist < point_size then
						local damage_key = self.part_damage_key
						print("Damage key: "..damage_key)
						local storage = advanced_fight_lib.get_object_storage(obj)
						local part = storage._parts_health[hit_data.details.name]
						if not part[damage_key] then
							part[damage_key] = {}
							for i, _ in pairs(self.points) do
								part[damage_key][i] = 0
							end
						end
						local max_health = self.points_max_health
						if type(self.points_max_health)=="table" then
							max_health = self.points_max_health[point_index]
						end
						part[damage_key][point_index] = (part[damage_key][point_index] or 0) + hit_data.damage/max_health
						print("Hit point: "..point_index.." damage: "..dump(part[damage_key]))
						local create_effects_group = true
						if self.effects_group_label then
							if attributes_effects.get_effects_group_id(obj:get_guid(), self.effects_group_label) then
								print("Effects group already exists: "..self.effects_group_label)
								--print("Object attributes: "..dump(attributes_effects.objects_list[obj:get_guid()]))
								create_effects_group = false
							end
						end
						if create_effects_group then
							advanced_fight_lib.create_effects_group_from_values(obj, self.effects_group_label, self.values)
							attributes_effects.objects_list[obj:get_guid()].verbose = true
						end
						if self.cb_on_update then
							self:cb_on_update(obj, hit_data)
						end
					end
				end
			end
		end
	end
	effect.cb_load_effect = function(self, obj)
		advanced_fight_lib.create_effects_group_from_values(obj, self.effects_group_label, self.values)
		attributes_effects.objects_list[obj:get_guid()].verbose = true
		if self.cb_on_load then
			self:cb_on_load(obj)
		end
	end
	return effect
end

advanced_fight_lib.point_hit_effect_view_range_calculate_damage = function(self, obj)
	local storage = advanced_fight_lib.get_object_storage(obj)
	local part = storage._parts_health[self.name]
	local damage_key = self.part_damage_key
	print(("part: %s damage_key: %s"):format(dump(part), dump(damage_key)))
	local min_damage = math.min(unpack(part[damage_key] or {0}))
	return min_damage
end

advanced_fight_lib.point_hit_effect_inaccurate_calculate_damage = function(self, obj)
	local storage = advanced_fight_lib.get_object_storage(obj)
	local part = storage._parts_health[self.name]
	local damage_key = self.part_damage_key
	--print(("part: %s damage_key: %s"):format(dump(part), dump(damage_key)))
	local sum = 0
	local n = 0
	--print("Calculating inaccurate damage with edge_point_damage: "..self.edge_point_damage.." undamage_point_weight: "..self.undamage_point_weight)
	for _, dmg in pairs(part[damage_key] or {}) do
		local n_add = 1
		if dmg<=self.edge_point_damage then
			if dmg > 0 then
				local t = dmg / self.edge_point_damage
				local weight = (self.undamage_point_weight - 1) * t
				n_add = (1 + weight)
			else
				n_add = self.undamage_point_weight
			end
		end
		sum = sum + dmg * n_add
		n = n + n_add
		--print("dmg: "..dmg.." sum: "..sum.." n: "..n)
	end
	return sum/n
end

function advanced_fight_lib.random_round(num)
	local lower = math.floor(num)
	local upper = math.ceil(num)
	local frac = num - lower
	if math.random() < frac then
		return upper
	else
		return lower
	end
end

function advanced_fight_lib.calculate_damage(obj, puncher, tflp, tool_caps, dir)
	local armor = obj:get_armor_groups() or {}

	local hitgroup_name = hitboxes_lib.get_hitgroup_name(obj)
	if not hitgroup_name then
		-- default calculation for mobs without hitbox
		local damage = 0
		for group,_ in pairs( (tool_caps.damage_groups or {}) ) do
			tmp = tflp / (tool_caps.full_punch_interval or 1.4)
			if tmp < 0 then tmp = 0.0 elseif tmp > 1 then tmp = 1.0 end
			damage = damage + (tool_caps.damage_groups[group] or 0)
					* tmp * ((armor[group] or 0) / 100.0)
		end
		return advanced_fight_lib.random_round(damage)
	end

	-- prepare hit_data
	local ref_pos = puncher:get_pos()

	local obj_rot
	if obj:is_player() then
		obj_rot = vector.new(0, obj:get_look_horizontal(), 0)
	else
		obj_rot = obj:get_rotation()
	end

	local hit_from_pos = vector.zero()
	local hit_from_dir = dir
	local puncher_rot
	if puncher then
		if puncher:is_player() then
			hit_from_dir = puncher:get_look_dir()
			puncher_rot = vector.new(0, hit_from_dir.y, 0)
			local eye_height = puncher:get_properties().eye_height
			hit_from_pos = vector.new(0, eye_height, 0)
		else
			puncher_rot = puncher:get_rotation()
			local ent = puncher:get_luaentity()
			if ent then
				if ent.cb_calculate_attack_dir then
					hit_from_dir = ent:cb_calculate_attack_dir(obj)
				elseif ent.attack_offsets and obj:is_player() then
					local punch_offset = ent.attack_offsets.punch_offset or vector.zero()
					local target_offset = ent.attack_offsets.target_offset or vector.zero()
					punch_offset = vector.rotate(punch_offset, puncher_rot)
					target_offset = vector.rotate(target_offset, obj_rot)
					hit_from_pos = punch_offset
					hit_from_dir = vector.normalize(vector.subtract(
							vector.add(obj:get_pos(), target_offset),
							vector.add(puncher:get_pos(), punch_offset)))
				end
			end
		end
	end

	local hit_data = {
		ref_pos = ref_pos,

		target = obj,
		hitgroup_name = hitgroup_name,
		hitbox_pos = vector.subtract(obj:get_pos(), ref_pos),
		hitbox_rot = obj_rot,

		attacker = puncher,
		hit_from_pos = hit_from_pos,
		hit_from_dir = hit_from_dir,

		dir = dir,
		tool_caps = tool_caps,
		tflp = tflp,
		damage = 0,
		details = nil,
	}

	local def
	if puncher:is_player() then
		def = puncher:get_wielded_item():get_definition()
		hit_data.range = def.range or 4.0
	else
		local def = puncher:get_luaentity()
	end

	if def then
		if def.cb_set_hit_attributes then
			def:cb_set_hit_attributes(hit_data)
		else
			hit_data.range = def._hit_range or 4.0
			if def._hit_box then
				hit_data.mode = "box"
				hit_data.box = def._hit_box
				hit_data.box_rot = puncher_rot
			elseif def._hit_sphere_radius then
				hit_data.mode = "sphere"
				hit_data.sphere_radius = def._hit_sphere_radius
			end
		end
	else
		core.log("error",
				"[advanced_fight] advanced_fight_lib.calculate_damage: could not get weapon definition")
		hit_data.range = 4.0
	end

	--print("[advanced_fight] advanced_fight_lib.calculate_damage hit_data: "..dump(hit_data))

	local hits = hitboxes_lib.detect_hits(hit_data)
	if hits==nil then
		-- miss
		--print("miss")
		core.sound_play("advanced_fight_punch_miss",
				{pos = puncher:get_pos(), max_hear_distance = 10, gain = 1.0,})
		return 0
	end

	local hit
	local hitbox_data

	for _, h in ipairs(hits) do
		hit_data.details = h
		hitbox_data = h.orig
		local miss_chance = hitbox_data.miss_chance
		if hitbox_data.cb_get_miss_chance then
			miss_chance = hitbox_data:cb_get_miss_chance(hit_data)
		end
		if miss_chance then
			local miss_roll = math.random()
			if miss_roll >= miss_chance then
				-- hit
				hit = h
				break
			end
		else
			hit = h
			break
		end
	end
	if not hit then
		-- all missed
		--print("all missed")
		core.sound_play("advanced_fight_punch_miss",
				{pos = puncher:get_pos(), max_hear_distance = 10, gain = 1.0,})
		return 0
	end

	hit_data.details = hit

	print("Hit detected for "..obj:get_guid().." to part "..hit_data.details.name.." from axis "..hit_data.details.hit_axis.." at rel pos "..core.pos_to_string(hit_data.details.hit_relative))

	--print(dump(hit_data))

	if hitbox_data.cb_calculate_damage then
		hitbox_data:cb_calculate_damage(hit_data)
	else
		if hitbox_data.cb_get_armor then
			armor = hitbox_data:cb_get_armor(hit_data, armor)
		end
		local damage = 0
		for group,_ in pairs( (tool_caps.damage_groups or {}) ) do
			local tmp = tflp / (tool_caps.full_punch_interval or 1.4)
			if tmp < 0 then tmp = 0.0 elseif tmp > 1 then tmp = 1.0 end
			damage = damage + (tool_caps.damage_groups[group] or 0)
					* tmp * ((armor[group] or 0) / 100.0)
		end
		local damage_multiplier = hitbox_data.damage_multiplier or 1.0
		if hitbox_data.cb_get_damage_multiplier then
			damage_multiplier = hitbox_data:cb_get_damage_multiplier(hit_data)
		end
		hit_data.damage = advanced_fight_lib.random_round(damage * damage_multiplier)
	end

	return hit_data
end

function advanced_fight_lib.calculate_get_miss_chance(self, hit_data)
  local result_miss_chance = self.miss_chance or 0.0
	if self.miss_chance_angles then
		-- angle between defender look dir and attacker
		local defender = hit_data.target
		local attacker = hit_data.attacker
		local def_look_dir
		if defender:is_player() then
			def_look_dir = defender:get_look_dir()
		else
			local rot = defender:get_rotation()
			def_look_dir = vector.rotate(vector.new(0,0,1), rot)
		end
		local dir_def_att = vector.subtract(attacker:get_pos(), defender:get_pos())
		local angle = vector.angle(dir_def_att, def_look_dir)
		angle = math.deg(angle)
		-- find appropriate angle range
		local lower_angle = -1
		local upper_angle = 181
		local lower_miss_chance = result_miss_chance
		local upper_miss_chance = result_miss_chance

		for chance_angle, chance_value in pairs(self.miss_chance_angles) do
			if chance_angle <= angle and chance_angle > lower_angle then
				lower_angle = chance_angle
				lower_miss_chance = chance_value
			end
			if chance_angle >= angle and chance_angle < upper_angle then
				upper_angle = chance_angle
				upper_miss_chance = chance_value
			end
		end

		-- interpolate miss chance
		if upper_angle == lower_angle then
			result_miss_chance = lower_miss_chance
		else
			local t = (angle - lower_angle) / (upper_angle - lower_angle)
			result_miss_chance = lower_miss_chance + t * (upper_miss_chance - lower_miss_chance)
		end
		print("angle: "..angle.." miss chance: "..result_miss_chance)
	end
	return result_miss_chance
end