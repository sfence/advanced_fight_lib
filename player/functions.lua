
local a_player = advanced_fight_lib.player

local gstep_data = attributes_effects.gstep_data

local have_3d_armor = core.get_modpath("3d_armor") ~= nil	

function a_player.on_hit(self, player, hit_data)
	local storage = advanced_fight_lib.get_object_storage(player)
	advanced_fight_lib.parts.on_hit(self, player, storage, hit_data)
	advanced_fight_lib.parts.on_update(self, player, storage, hit_data)
	advanced_fight_lib.set_object_storage(player, storage)
	attributes_effects.request_object_on_step_update(player:get_guid())
end

function a_player.on_respawn(player)
	local storage = advanced_fight_lib.get_object_storage(player)
	print("Respawning player "..player:get_player_name()..' storage: '..dump(storage))
	advanced_fight_lib.object_on_respawn(player, storage)
	print("After respawn storage: "..dump(storage))
	advanced_fight_lib.set_object_storage(player, storage)
end

function a_player.on_join(player)
	local storage = advanced_fight_lib.get_object_storage(player)
	print("Loading player "..player:get_player_name()..' storage: '..dump(storage))
	advanced_fight_lib.object_on_load(player, storage)
	advanced_fight_lib.set_object_storage(player, storage)
	if attributes_effects.objects_list[player:get_guid()] then
		attributes_effects.objects_list[player:get_guid()].verbose = true
	end
end

function a_player.on_heal(player, heal_amount, heal_data)
	local storage = advanced_fight_lib.get_object_storage(player)
	advanced_fight_lib.object_on_heal(player, storage, heal_amount, heal_data)
	advanced_fight_lib.set_object_storage(player, storage)
end

function a_player.default_use_shield(def, hit_data)
	local use_chance = def.use_chance
	if def.use_chance_angles then
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
		local lower_use_chance = use_chance
		local upper_use_chance = use_chance

		for chance_angle, chance_value in pairs(def.use_chance_angles) do
			if chance_angle <= angle and chance_angle > lower_angle then
				lower_angle = chance_angle
				lower_use_chance = chance_value
			end
			if chance_angle >= angle and chance_angle < upper_angle then
				upper_angle = chance_angle
				upper_use_chance = chance_value
			end
		end

		-- interpolate use chance
		if upper_angle == lower_angle then
			use_chance = lower_use_chance
		else
			local t = (angle - lower_angle) / (upper_angle - lower_angle)
			use_chance = lower_use_chance + t * (upper_use_chance - lower_use_chance)
		end
	end

	-- apply time from last use
	local storage = advanced_fight_lib.get_object_storage(hit_data.target)
	if storage.shield_last_use_time then
		local time_diff = gstep_data.gstep - storage.shield_last_use_time
		local full_use_interval = def.full_use_interval or 0.6
		if time_diff < full_use_interval then
			local angle_diff = math.abs(angle - storage.shield_last_use_angle)
			local shield_speed = def.shield_speed or 45
			local angle_factor = math.min(angle_diff / shield_speed, 1.0)
			local effective_time = time_diff + (full_use_interval - time_diff) * (1.0 - angle_factor)
			local recover_factor = math.min(effective_time / full_use_interval, 1.0)
			use_chance = use_chance * recover_factor
		end
	end
	print("Shield use chance: "..use_chance)

	local use_shield = math.random() < use_chance
	
	if use_shield then
		storage.shield_last_use_time = gstep_data.gstep
		storage.shield_last_use_angle = angle
	end

	return use_shield
end

function a_player.get_armor(self, hit_data)
	local player = hit_data.target
	if not have_3d_armor then
		return player:get_armor_groups()
	end
	local def_groups = player:get_armor_groups()

	local hit_element = self.armor_element
	if not hit_element then
		print("No armor_element defined for hitbox "..hit_data.details.name)
		return def_groups
	end
	local hit_table = self.armor_hit_table or hit_element
	-- hit_element: "head", "torso", "legs", "feet" apod.
	local name, armor_inv = armor:get_valid_player(player, "[apply_hit_armor]")
	if not name then
		print("Player "..player:get_player_name().." has no valid armor")
		return def_groups
	end

	local list = armor_inv:get_list("armor")

	local levels = {}
	for group,_ in pairs(armor.registered_groups) do
		levels[group] = 0
	end

	-- check tool caps groups
	local dgrps = {}
	local cdgrps = 0
	if hit_data.tool_caps and hit_data.tool_caps.damage_groups then
		for group, cap in pairs(hit_data.tool_caps.damage_groups) do
			dgrps[group] = true
			cdgrps = cdgrps + 1
		end
	end

	-- check shield
	local use_shield = false

	for stack_index, stack in pairs(list) do
		if stack:get_count() == 1 then
			local def = stack:get_definition()
			if def.groups["armor_shield"] then
				-- determine if defender manage to use the shield to block attack
				if def.cb_use_shield then
					use_shield = def:cb_use_shield(hit_data)
				else
					use_shield = a_player.default_use_shield(def, hit_data)
				end
				if use_shield then
					-- apply shield damage reduction
					if def.armor_groups then
						for group, level in pairs(def.armor_groups) do
							if levels[group] then
								levels[group] = 100
							end
							if dgrps[group] then
								cdgrps = cdgrps - 1
							end
						end
					else
						levels["fleshy"] = 100
						if dgrps["fleshy"] then
							cdgrps = cdgrps - 1
						end
					end
					print("Shield used for hit_data with index: "..stack_index)
					hit_data.details.shield_index = stack_index
					hit_data.details.shield_name  = stack:get_name()
				end
				break
			end
		end
	end

	local all_blocked_by_shield = use_shield and (cdgrps == 0)

	if not all_blocked_by_shield then
		-- check armor pieces
		for stack_index, stack in pairs(list) do
			if stack:get_count() == 1 then
				local def = stack:get_definition()
				if def.groups["armor_"..hit_element] then
					local apply_armor = true
					print("Checking armor piece "..stack:get_name().." for hitbox "..hit_data.details.name)
					print(dump(def.axis_hit_tables))
					if def.axis_hit_tables and def.axis_hit_tables[hit_table] ~= nil then
						local hit_axis = hit_data.details.hit_axis
						local axis_hit_table = def.axis_hit_tables[hit_table][hit_axis]
						if axis_hit_table ~= nil then
							local rel_x, rel_y
							if hit_axis == "x+" or hit_axis == "x-" then
								rel_y = 1 - hit_data.details.hit_relative.y
								rel_x = hit_data.details.hit_relative.z
							elseif hit_axis == "y+" or hit_axis == "y-" then
								rel_y = hit_data.details.hit_relative.z
								rel_x = hit_data.details.hit_relative.x
							else
								rel_x = hit_data.details.hit_relative.x
								rel_y = 1 - hit_data.details.hit_relative.y
								rel_y = 1 - hit_data.details.hit_relative.y
							end
							local hit_space = advanced_fight_lib.convert_relative_hit_to_grid_value(rel_x, rel_y, axis_hit_table)
							print("Hit space for axis "..hit_axis.." is "..tostring(hit_space).." for pos ("..
								tostring(rel_x)..","..tostring(rel_y)..")")
							if hit_space > 0 then
								if hit_data.mode == "box" then
									local box_x = hit_data.box.x_max - hit_data.box.x_min
									local box_y = hit_data.box.y_max - hit_data.box.y_min
									if box_x < hit_space and box_y < hit_space then
										apply_armor = false -- plný průchod
									elseif box_x > hit_space and box_y > hit_space then
										apply_armor = true -- žádný průchod
									else
										-- hraniční stav: jedna souřadnice uvnitř, druhá venku
										local angle = math.random() * 2 * math.pi
										local eff_x = box_x * math.cos(angle) - box_y * math.sin(angle)
										local eff_y = box_x * math.sin(angle) + box_y * math.cos(angle)
										local eff_dist = math.max(math.abs(eff_x), math.abs(eff_y))

										if eff_dist < hit_space then
											apply_armor = false
										end
									end
								elseif hit_data.mode == "sphere" then
									if hit_data.sphere_radius >= hit_space then
										apply_armor = false
									end
								end
							end
						end
					end
					if apply_armor then
						if def.full_armor_groups then
							for group, level in pairs(def.full_armor_groups) do
								if levels[group] then
									levels[group] = levels[group] + level
								end
							end
						else
							local level = def.groups["armor_"..hit_element]
							levels["fleshy"] = levels["fleshy"] + level
						end
						print("Armor used for hit_data with index: "..stack_index)
						hit_data.details.armor_index = stack_index
						hit_data.details.armor_name  = stack:get_name()
						hit_data.details.allow_point_hit = false
					end
					break
				end
			end
		end
	end

	local groups = {}
	for group, level in pairs(levels) do
		local base = armor.registered_groups[group]
		if level > base then 
			level = base
		end
		groups[group] = base - level
	end

	print("Player armor for hit_data: "..dump(groups))
	return groups
end

function a_player.on_punch(player, hitter, tflp, tool_caps, dir, damage)
	local hit_data = advanced_fight_lib.calculate_damage(player, hitter, tflp, tool_caps, dir)

	if type(hit_data)~="table" then
		return hit_data<=0
	end

	--print("restore hit "..(hit~=nil).." for "..guid.." at step "..gstep)
	local hitbox = hit_data.details.orig
	print("Player "..player:get_player_name().." is hit to "..hit_data.details.name)
	if hitbox.on_hit then
		hitbox:on_hit(player, hit_data)
	end

	--print("Player "..player:get_player_name().." hit "..hit_data.details.name..
	--		" for "..hit_data.damage.." damage by "..hitter:get_guid())

	if hit_data.damage>0 then
		local player_name
		if have_3d_armor then
			player_name = player:get_player_name()
			print("Applying damage "..hit_data.damage.." to player "..player_name.." with armor index "..tostring(hit_data.details.armor_index))
			advanced_fight_lib.player_3d_armor_index[player_name] = {
				hit_data.details.armor_index,
				hit_data.details.shield_index,
			}
		end
		player:set_hp(player:get_hp() - hit_data.damage, {
			type = "punch",
		})
		if have_3d_armor then
			advanced_fight_lib.player_3d_armor_index[player_name] = nil
			armor:save_armor_inventory(player)
			print("Player "..player_name.." now has hp "..player:get_hp())
		end
	else
		if have_3d_armor then
			if hit_data.details.armor_index or hit_data.details.shield_index then
				local player_name = player:get_player_name()
				advanced_fight_lib.player_3d_armor_index[player_name] = {
					hit_data.details.armor_index,
					hit_data.details.shield_index,
				}
				armor:punch(player, hit_data.attacker, hit_data.tflp, hit_data.tool_caps)
				advanced_fight_lib.player_3d_armor_index[player_name] = nil
				armor:save_armor_inventory(player)
			end
		end
	end

	return true
end

if have_3d_armor then

	advanced_fight_lib.player_3d_armor_index = {}

	local armor_punch_inv = {
		get_list = function(self, listname)
			local list = self.inv:get_list(listname)
			if listname == "armor" then
				local index = advanced_fight_lib.player_3d_armor_index[self.player_name]
				if index then
					print("Filtering armor inventory for player "..self.player_name..
						" to keep only indexes "..tostring(index[1]).." and "..tostring(index[2]))
					local new_list = {}
					-- keep only armor which should be damaged
					for i, stack in ipairs(list) do
						if i == index[1] or i == index[2] then
							new_list[i] = stack
						else
							new_list[i] = ItemStack()
						end
					end
					return new_list
				end
			end
			return list
		end,
		set_list = function(self, listname, list)
			return self.inv:set_list(listname, list)
		end,
		get_size = function(self, listname)
			return self.inv:get_size(listname)
		end,
		get_stack = function(self, listname, index)
			return self.inv:get_stack(listname, index)
		end,
		set_stack = function(self, listname, index, stack)
			return self.inv:set_stack(listname, index, stack)
		end,
	}

	local create_armor_punch_inv = function(player_name, inv)
		local armor_inv = {
			player_name = player_name,
			inv = inv,
		}
		-- set metadata to armor-punch_inv
		setmetatable(armor_inv, {__index = armor_punch_inv})
		return armor_inv
	end

	local armor_get_valid_player = armor.get_valid_player

	armor.get_valid_player = function(self, player, msg)
		local name, inv = armor_get_valid_player(self, player, msg)
		if not name then
			return
		end
		-- overwrite inv
		return name, create_armor_punch_inv(name, inv)
	end
end

function a_player.set_default_hit_attributes(hit_data)
	hit_data.mode = "box"
	hit_data.box = hitboxes_lib.collisionbox_to_box(
			{-0.11, -0.11, -0.11, 0.11, 0.11, 0.11})
	hit_data.box_rot = vector.new(0, hit_data.puncher:get_look_horizontal(), 0)
	hit_data.hit_area = 0.22*0.22
end

players_effects.register_on_respawn_callback(a_player.on_respawn)
players_effects.register_on_heal_callback(a_player.on_heal)