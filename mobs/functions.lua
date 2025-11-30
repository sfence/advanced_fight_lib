
advanced_fight_lib.mobs = {}

local a_mobs = advanced_fight_lib.mobs

local obj_hit = {}

local gstep_data = attributes_effects.gstep_data

function a_mobs.cmi_calculate_damage(obj, puncher, tflp, tool_caps, dir)
	local hit_data = advanced_fight_lib.calculate_damage(obj, puncher, tflp, tool_caps, dir)

	if type(hit_data)~="table" then
		return hit_data
	end

	local guid = obj:get_guid()
	--print("store hit for "..guid.." at step "..gstep)
	obj_hit[guid] = {
		gstep = gstep_data.gstep,
		hit_data = hit_data,
	}

	return hit_data.damage
end

function a_mobs.mobs_do_punch(ent)
	local guid = ent.object:get_guid()
	local hit = obj_hit[guid]
	--print("restore hit "..(hit~=nil).." for "..guid.." at step "..gstep)
	if hit then
		if hit.gstep == gstep_data.gstep then
			local hitbox = hit.hit_data.details.orig
			if hitbox.on_hit then
				hitbox:on_hit(ent.object, hit.hit_data)
			end
		end
		obj_hit[guid] = nil
	end
end

function a_mobs.replace_do_punch(ent_def)
	local old_do_punch = ent_def.do_punch
	ent_def.do_punch = function(ent, puncher, tflp, tool_caps, dir, damage)
		if damage == 0 then
			return false
		end
		a_mobs.mobs_do_punch(ent)
		if old_do_punch then
			return old_do_punch(ent, puncher, tflp, tool_caps, dir, damage)
		end
		return true
	end
end

function a_mobs.inaccuracy_arrow_override(self, shooter_ent)
	local inaccuracy = shooter_ent.shoot_inaccuracy or 0
	print("Arrow override called for "..self.object:get_guid().." shooter inaccuracy: "..inaccuracy)
	if inaccuracy > 0 then
		core.after(0.01, advanced_fight_lib.apply_inaccuracy_to_arrow, self.object:get_guid(), inaccuracy)
	end
end

function a_mobs.replace_override_arrow(ent_def)
	local old_arrow_override = ent_def.arrow_override
	ent_def.arrow_override = function(self, shooter_ent)
		if old_arrow_override then
			old_arrow_override(self, shooter_ent)
		end
		a_mobs.inaccuracy_arrow_override(self, shooter_ent)
	end
end

function a_mobs.point_hit_effects_group_on_update(self, obj, hit_data)
	local ent = obj:get_luaentity()
	local damage_key = self.part_damage_key
	for point_index, point in pairs(self.points) do
		if ent._parts_health[self.name][damage_key] then
			local damage = ent._parts_health[self.name][damage_key][point_index] or 0
			local max_health = self.points_max_health
			if type(self.points_max_health)=="table" then
				max_health = self.points_max_health[point_index]
			end
			if damage >= max_health then
				local point_texture = string.format(self.texture_hit_point, point_index)
				if not ent.base_texture[1]:find("%^"..point_texture, 1, true) then
					ent.base_texture = table.copy(ent.base_texture)
					ent.base_texture[1] = ent.base_texture[1].."^"..point_texture
					obj:set_properties({
						textures = ent.base_texture,
					})
				end
			end
		end
	end
end