local a_parts = advanced_fight_lib.parts

function a_parts.on_hit(self, obj, storage, hit_data)
	--print(dump(hit_data))
	local hitgroup_name = hitboxes_lib.get_hitgroup_name(obj)
	local hitgroup = hitboxes_lib.hitbox_groups[hitgroup_name]
	if not storage._parts_health then
		advanced_fight_lib.object_body_parts_health(obj, storage, hitgroup)
	end
	local part = storage._parts_health[hit_data.details.name]
	part.health = part.health - hit_data.damage
	advanced_fight_lib.set_object_storage(obj, storage)
end

function a_parts.on_update(self, obj, storage, hit_data)
	local has_values_effects = self.values ~= nil and next(self.values) ~= nil
	--print("hit_data: "..dump(hit_data))
	if has_values_effects then
		print("Applying values effects for hit to part "..hit_data.details.name)
		local create_effects_group = true
		if self.effects_group_label then
			if attributes_effects.get_effects_group_id(obj:get_guid(), self.effects_group_label) then
				create_effects_group = false
			end
		end
		if create_effects_group then
			advanced_fight_lib.create_effects_group_from_values(obj, self.effects_group_label, self.values)
		end
		if self.cb_on_update then
			self:cb_on_update(obj, hit_data)
		end
	end
	local has_custom_effects = self.effects ~= nil and next(self.effects) ~= nil
	if has_custom_effects then
		print("Applying custom effects for hit to part "..hit_data.details.name)
		for name, data in pairs(self.effects) do
			local apply = true
			if data.cb_apply then
				apply = data:cb_apply(obj, hit_data)
			end
			if apply then
				data:cb_add_effect(obj, hit_data)
			end
		end
	end
end

function a_parts.on_load(self, obj, storage)
	local has_values_effects = self.values ~= nil and next(self.values) ~= nil
	if has_values_effects then
		local create_effects_group = true
		if self.effects_group_label then
			print("Checking for effects group "..self.effects_group_label.." on load")
			if attributes_effects.get_effects_group_id(obj:get_guid(), self.effects_group_label) then
				create_effects_group = false
			end
		end
		print("Creating effects group: "..tostring(create_effects_group))
		if create_effects_group then
			advanced_fight_lib.create_effects_group_from_values(obj, self.effects_group_label, self.values)
		end
		if self.cb_on_load then
			self:cb_on_load(obj)
		end
	end
	local has_custom_effects = self.effects ~= nil and next(self.effects) ~= nil
	if has_custom_effects then
		for name, data in pairs(self.effects) do
			print("Loading custom effect "..name.." on load")
			data:cb_load_effect(obj)
		end
	end
end