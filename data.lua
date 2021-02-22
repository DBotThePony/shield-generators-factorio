
-- energy interface per entity
data:extend({
	{
		type = 'electric-energy-interface',
		name = 'shield-generators-interface',

		icon = '__base__/graphics/icons/energy-shield-equipment.png',
		icon_size = 64,
		icon_mipmaps = 4,

		energy_production = '0W',
		energy_usage = '0W',

		selection_box = {
			{-1, -1},
			{1, 1}
		},

		collision_mask = {}, -- do not collide with anything

		energy_source = {
			type = 'electric',
			buffer_capacity = '8MJ',
			usage_priority = 'primary-input',
			input_flow_limit = '600kW',
			output_flow_limit = '0W',
			drain = '0W',
		}
	}
})

local beacon = data.raw.beacon.beacon

data:extend({
	{ -- energy shield building
		type = 'electric-energy-interface',
		name = 'shield-generators-generator',

		-- icon = '__base__/graphics/icons/beacon.png',
		icon = '__base__/graphics/icons/energy-shield-equipment.png',
		icon_size = 64,
		icon_mipmaps = 4,

		energy_production = '0W',
		energy_usage = '0W',

		collision_box = beacon.collision_box,
		selection_box = beacon.selection_box,
		drawing_box = beacon.drawing_box,
		damaged_trigger_effect = beacon.damaged_trigger_effect,
		flags = beacon.flags,
		graphics_set = beacon.graphics_set,
		water_reflection = beacon.water_reflection,
		corpse = beacon.corpse,
		dying_explosion = beacon.dying_explosion,
		working_sound = beacon.working_sound,
		max_health = 600,

		vehicle_impact_sound = beacon.generic_impact,
		open_sound = beacon.machine_open,
		close_sound = beacon.machine_close,

		minable = {mining_time = 0.2, result = 'shield-generators-generator'},

		energy_source = {
			type = 'electric',
			buffer_capacity = '200MJ',
			usage_priority = 'primary-input',
			input_flow_limit = '200MW',
			output_flow_limit = '0W',
			drain = '0W',
		},

		--[[pictures = {
			sheets = {
				{
					filename = "__base__/graphics/entity/beacon/beacon-bottom.png",
					width = 16,
					height = 16,
					shift = util.by_pixel(0, 1),
					scale = 4,
				},
			}
		},]]

		picture = {
			layers = {
				{
					filename = "__base__/graphics/entity/beacon/beacon-bottom.png",
					width = 106,
					height = 96,
					shift = util.by_pixel(0, 1),
					hr_version = {
						filename = "__base__/graphics/entity/beacon/hr-beacon-bottom.png",
						width = 212,
						height = 192,
						scale = 0.5,
						shift = util.by_pixel(0.5, 1)
					}
				},

				{
					filename = "__base__/graphics/entity/beacon/beacon-shadow.png",
					width = 122,
					height = 90,
					draw_as_shadow = true,
					shift = util.by_pixel(12, 1),
					hr_version = {
						filename = "__base__/graphics/entity/beacon/hr-beacon-shadow.png",
						width = 244,
						height = 176,
						scale = 0.5,
						draw_as_shadow = true,
						shift = util.by_pixel(12.5, 0.5)
					}
				},

				{
					filename = "__base__/graphics/entity/beacon/beacon-top.png",
					width = 48,
					height = 70,
					repeat_count = 45,
					animation_speed = 0.5,
					shift = util.by_pixel(3, -19),
					hr_version = {
						filename = "__base__/graphics/entity/beacon/hr-beacon-top.png",
						width = 96,
						height = 140,
						scale = 0.5,
						repeat_count = 45,
						animation_speed = 0.5,
						shift = util.by_pixel(3, -19)
					}
				},
			},
		},
	},

	-- energy shield building item
	{
		type = "item",
		name = "shield-generators-generator",
		icon = "__base__/graphics/icons/beacon.png",
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = "defensive-structure",
    	order = "b[turret]-n[shield-generator]",
		place_result = "shield-generators-generator",
		stack_size = 10
	},

	-- energy shield building recipe
	{
		type = "recipe",
		name = "shield-generators-generator",
		enabled = true,
		result = "shield-generators-generator",

		energy_required = 2,

		ingredients = {
			{"speed-module", 4},
			{"processing-unit", 5},
			{"energy-shield-equipment", 5},
		},
	},
})
