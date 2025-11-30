local a_player = advanced_fight_lib.player

function a_player.effect_disarm_right(self, player, hit_data)
	if self.hit_area then
		if not vector.in_area(hit_data.details.hit_relative, self.hit_area.min, self.hit_area.max) then
			return
		end
	end

	local wielded = player:get_wielded_item()
	if wielded:is_empty() then
		return
	end
	local def = wielded:get_definition()
	if def and def.diarm_chance then
		local chance = def.diarm_chance
		if math.random() > chance then
			return
		end
	end
	player:set_wielded_item(ItemStack(""))
	
	local pos = player:get_pos()
	core.add_item(pos, wielded)
end

function a_player.effect_disarm_left(self, player, hit_data)
	-- nothing now
end
