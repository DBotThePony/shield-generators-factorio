
local beacon = data.raw.beacon.beacon

if data.raw.technology['energy-shield-equipment'] then
	table.insert(data.raw.technology['energy-shield-equipment'].prerequisites, 'shield-generators-basics')
end

data:extend({
	-- technologies
	-- basics of shields
	{
		type = 'technology',
		name = 'shield-generators-basics',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/energy-shield-equipment.png',

		effects = {

		},

		prerequisites = {'military-2', 'logistic-science-pack', 'military-science-pack'},

		unit = {
			count = 100,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
			},

			time = 15
		},
	},

	-- turret internal shields
	{
		type = 'technology',
		name = 'shield-generators-turret-shields-basics',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/energy-shield-equipment.png',

		effects = {

		},

		prerequisites = {'shield-generators-basics', 'gun-turret'},

		unit = {
			count = 200,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
			},

			time = 30
		},
	},

	-- basic shield provider
	{
		type = 'technology',
		name = 'shield-generators-provider-shields-basics',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/energy-shield-equipment.png',

		effects = {
			{
				type = 'unlock-recipe',
				recipe = 'shield-generators-generator'
			}
		},

		prerequisites = {
			'shield-generators-basics',
			'chemical-science-pack',
			'military-3',
			'advanced-electronics-2',
			'speed-module',
		},

		unit = {
			count = 300,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'chemical-science-pack', 1},
			},

			time = 30
		},
	},

	-- energy interface per turret
	{
		type = 'electric-energy-interface',
		name = 'shield-generators-interface',

		icon = '__base__/graphics/icons/energy-shield-equipment.png',
		icon_size = 64,
		icon_mipmaps = 4,

		max_health = 15,

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
			input_flow_limit = '300kW',
			output_flow_limit = '0W',
			drain = '0W',
		}
	},

	-- energy shield provider building (basic)
	{
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
			buffer_capacity = '60MJ',
			usage_priority = 'primary-input',
			input_flow_limit = '4MW',
			output_flow_limit = '0W',
			drain = '0W',
		},

		picture = {
			layers = {
				{
					filename = '__base__/graphics/entity/beacon/beacon-bottom.png',
					width = 106,
					height = 96,
					shift = util.by_pixel(0, 1),
					hr_version = {
						filename = '__base__/graphics/entity/beacon/hr-beacon-bottom.png',
						width = 212,
						height = 192,
						scale = 0.5,
						shift = util.by_pixel(0.5, 1)
					}
				},

				{
					filename = '__base__/graphics/entity/beacon/beacon-shadow.png',
					width = 122,
					height = 90,
					draw_as_shadow = true,
					shift = util.by_pixel(12, 1),
					hr_version = {
						filename = '__base__/graphics/entity/beacon/hr-beacon-shadow.png',
						width = 244,
						height = 176,
						scale = 0.5,
						draw_as_shadow = true,
						shift = util.by_pixel(12.5, 0.5)
					}
				},

				{
					filename = '__base__/graphics/entity/beacon/beacon-top.png',
					width = 48,
					height = 70,
					repeat_count = 45,
					animation_speed = 0.5,
					shift = util.by_pixel(3, -19),
					hr_version = {
						filename = '__base__/graphics/entity/beacon/hr-beacon-top.png',
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
		type = 'item',
		name = 'shield-generators-generator',
		icon = '__base__/graphics/icons/beacon.png',
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = 'defensive-structure',
    	order = 'b[turret]-n[shield-generator]',
		place_result = 'shield-generators-generator',
		stack_size = 10
	},

	-- energy shield building recipe
	{
		type = 'recipe',
		name = 'shield-generators-generator',
		enabled = false,
		result = 'shield-generators-generator',

		energy_required = 2,

		ingredients = {
			{'speed-module', 5},
			{'processing-unit', 10},
			{'energy-shield-equipment', 15},
			{'steel-plate', 20},
		},
	},
})
