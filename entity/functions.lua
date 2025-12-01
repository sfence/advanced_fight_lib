
function advanced_fight_lib.entity_on_hit(self, obj, hit_data)
	local storage = advanced_fight_lib.get_object_storage(obj)
	advanced_fight_lib.parts.on_hit(self, obj, storage, hit_data)
	advanced_fight_lib.parts.on_update(self, obj, storage, hit_data)
	attributes_effects.request_object_on_step_update(obj:get_guid())
end