local per_player_data = {}

function advanced_fight_lib.get_object_storage(obj)
	if obj:is_player() then
		local guid = obj:get_guid()
		if not per_player_data[guid] then
			local meta_data = obj:get_meta():get("advanced_fight:storage")
			per_player_data[guid] = core.parse_json(meta_data or "{}") or {}
		end
		return per_player_data[guid]
	end
	return obj:get_luaentity()
end

function advanced_fight_lib.set_object_storage(obj, data)
	if obj:is_player() then
		obj:get_meta():set_string("advanced_fight:storage", core.write_json(data or {}))
	end
end