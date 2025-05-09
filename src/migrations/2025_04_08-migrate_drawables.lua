
-- factorio 1.1 migration
return function()
	local type = type
	local get_object_by_id = rendering.get_object_by_id

	local function migrate(value)
		if type(value) == 'number' then
			return get_object_by_id(value)
		end

		return value
	end

	for _, data in pairs(storage.shields) do
		data.shield_bar_bg = migrate(data.shield_bar_bg)
		data.shield_bar_visual = migrate(data.shield_bar_visual)
		data.shield_bar = migrate(data.shield_bar)
		data.shield_bar_buffer = migrate(data.shield_bar_buffer)
	end

	for _, shield_generator in pairs(storage.shield_generators) do
		shield_generator.battery_bar_bg = migrate(shield_generator.battery_bar_bg)
		shield_generator.battery_bar = migrate(shield_generator.battery_bar)
		shield_generator.provider_radius = migrate(shield_generator.provider_radius)

		for _, data in pairs(shield_generator.tracked) do
			data.shield_bar_bg = migrate(data.shield_bar_bg)
			data.shield_bar_visual = migrate(data.shield_bar_visual)
			data.shield_bar = migrate(data.shield_bar)
		end
	end
end
