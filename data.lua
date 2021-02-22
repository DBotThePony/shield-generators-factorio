
data:extend({
	{
		type = 'electric-energy-interface',
		name = 'shield-generators-interface',

		icon = '__base__/graphics/icons/energy-shield-equipment.png',
		icon_size = 64,

		energy_production = '0W',
		energy_usage = '0W',

		collision_box = {
			{-0.1, -0.1},
			{0.1, 0.1},
		},

		collision_mask = {}, -- do not collide with anything

		energy_source = {
			type = 'electric',
			buffer_capacity = '1MJ',
			usage_priority = 'secondary-input',
			input_flow_limit = '600kW',
			output_flow_limit = '0W',
			drain = '0W',
		}
	}
})
