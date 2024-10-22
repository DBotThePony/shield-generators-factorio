
-- Copyright (C) 2021 DBotThePony

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all copies
-- or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

local beacon = data.raw.beacon.beacon
local values = require('__shield-generators__/values')

if data.raw.technology['energy-shield-equipment'] then
	table.insert(data.raw.technology['energy-shield-equipment'].prerequisites, 'shield-generators-basics')
end

local basic_shield_provider = {
	type = 'electric-energy-interface',
	name = 'shield-generators-generator',

	flags = {
		'player-creation',
	},

	icon = '__base__/graphics/icons/beacon.png',
	-- icon = '__base__/graphics/icons/energy-shield-equipment.png',
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
		buffer_capacity = '100MJ',
		usage_priority = 'secondary-input',
		input_flow_limit = '20MW',
		output_flow_limit = '0W',
		drain = '0W',
	},

	picture = {
		layers = {
			{
				filename = '__base__/graphics/entity/beacon/beacon-bottom.png',
				width = 212,
				height = 192,
				scale = 0.5,
				shift = util.by_pixel(0.5, 1)
			},

			{
				filename = '__base__/graphics/entity/beacon/beacon-shadow.png',
				width = 244,
				height = 176,
				scale = 0.5,
				draw_as_shadow = true,
				shift = util.by_pixel(12.5, 0.5)
			},

			{
				filename = '__base__/graphics/entity/beacon/beacon-top.png',
				width = 96,
				height = 140,
				scale = 0.5,
				repeat_count = 45,
				animation_speed = 0.5,
				shift = util.by_pixel(3, -19)
			},
		},
	},
}

local advanced_shield_provider = table.deepcopy(basic_shield_provider)
advanced_shield_provider.name = 'shield-generators-generator-advanced'
advanced_shield_provider.energy_source.buffer_capacity = '800MJ'
advanced_shield_provider.energy_source.input_flow_limit = '60MW'
advanced_shield_provider.selection_box = {
	{-2.5, -2.5},
	{2.5, 2.5}
}

advanced_shield_provider.collision_box = {
	{-2, -2},
	{2, 2}
}

advanced_shield_provider.max_health = 1000
advanced_shield_provider.minable.result = 'shield-generators-generator-advanced'
advanced_shield_provider.picture.layers[1].scale = 1
advanced_shield_provider.picture.layers[2].scale = 1
advanced_shield_provider.picture.layers[3].scale = 1
advanced_shield_provider.picture.layers[3].shift = util.by_pixel(6, -31)

local elite_shield_provider = table.deepcopy(basic_shield_provider)
elite_shield_provider.name = 'shield-generators-generator-elite'
elite_shield_provider.energy_source.buffer_capacity = '2GJ'
elite_shield_provider.energy_source.input_flow_limit = '500MW'
elite_shield_provider.selection_box = {
	{-3.5, -3.5},
	{3.5, 3.5}
}

elite_shield_provider.collision_box = {
	{-3, -3},
	{3, 3}
}

elite_shield_provider.max_health = 1800
elite_shield_provider.minable.result = 'shield-generators-generator-elite'
elite_shield_provider.picture.layers[1].scale = 1.4
elite_shield_provider.picture.layers[2].scale = 1.4
elite_shield_provider.picture.layers[3].scale = 1.4
elite_shield_provider.picture.layers[3].shift = util.by_pixel(7.5, -37)

local ultimate_shield_provider = table.deepcopy(basic_shield_provider)
ultimate_shield_provider.name = 'shield-generators-generator-ultimate'
ultimate_shield_provider.energy_source.buffer_capacity = '5GJ'
ultimate_shield_provider.energy_source.input_flow_limit = '2000MW'
ultimate_shield_provider.selection_box = {
	{-4.5, -4.5},
	{4.5, 4.5}
}

ultimate_shield_provider.collision_box = {
	{-4, -4},
	{4, 4}
}

ultimate_shield_provider.max_health = 3000
ultimate_shield_provider.minable.result = 'shield-generators-generator-ultimate'
ultimate_shield_provider.picture.layers[1].scale = 1.8
ultimate_shield_provider.picture.layers[2].scale = 1.8
ultimate_shield_provider.picture.layers[3].scale = 1.8
ultimate_shield_provider.picture.layers[3].shift = util.by_pixel(8.5, -56)

local prototypes = {
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
		icon = '__base__/graphics/icons/beacon.png',

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
			'processing-unit',
			'speed-module',
		},

		unit = {
			count = 200,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'chemical-science-pack', 1},
			},

			time = 30
		},
	},

	{
		type = 'technology',
		name = 'shield-generators-generator-advanced',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/beacon.png',

		effects = {
			{
				type = 'unlock-recipe',
				recipe = 'shield-generators-generator-advanced'
			}
		},

		prerequisites = {
			'low-density-structure',
			'speed-module-2',
			'efficiency-module',
			'shield-generators-provider-shields-basics',
		},

		unit = {
			count = 350,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'chemical-science-pack', 1},
			},

			time = 45
		},
	},

	{
		type = 'technology',
		name = 'shield-generators-generator-elite',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/beacon.png',

		effects = {
			{
				type = 'unlock-recipe',
				recipe = 'shield-generators-generator-elite'
			}
		},

		prerequisites = {
			'military-4',
			'speed-module-2',
			'efficiency-module-2',
			'shield-generators-generator-advanced',
		},

		unit = {
			count = 400,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'chemical-science-pack', 1},
				{'utility-science-pack', 1},
			},

			time = 45
		},
	},

	{
		type = 'technology',
		name = 'shield-generators-generator-ultimate',

		icon_size = 64,
		icon_mipmaps = 4,
		-- icon = '__base__/graphics/technology/energy-shield-equipment.png',
		icon = '__base__/graphics/icons/beacon.png',

		effects = {
			{
				type = 'unlock-recipe',
				recipe = 'shield-generators-generator-ultimate'
			}
		},

		prerequisites = {
			'efficiency-module-3',
			'shield-generators-generator-elite',
		},

		unit = {
			count = 500,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'chemical-science-pack', 1},
				{'utility-science-pack', 1},
			},

			time = 60
		},
	},

	-- energy shield provider building (basic)
	basic_shield_provider,
	advanced_shield_provider,
	elite_shield_provider,
	ultimate_shield_provider,

	{
		type = 'item',
		name = 'shield-generators-generator',
		icon = '__base__/graphics/icons/beacon.png',
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = 'defensive-structure',
		order = 'b[turret]-n[shield-generator-a]',
		place_result = 'shield-generators-generator',
		stack_size = 10
	},

	{
		type = 'item',
		name = 'shield-generators-generator-advanced',
		icon = '__base__/graphics/icons/beacon.png',
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = 'defensive-structure',
		order = 'b[turret]-n[shield-generator-b]',
		place_result = 'shield-generators-generator-advanced',
		stack_size = 10
	},

	{
		type = 'item',
		name = 'shield-generators-generator-elite',
		icon = '__base__/graphics/icons/beacon.png',
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = 'defensive-structure',
		order = 'b[turret]-n[shield-generator-c]',
		place_result = 'shield-generators-generator-elite',
		stack_size = 10
	},

	{
		type = 'item',
		name = 'shield-generators-generator-ultimate',
		icon = '__base__/graphics/icons/beacon.png',
		icon_size = 64,
		icon_mipmaps = 4,
		subgroup = 'defensive-structure',
		order = 'b[turret]-n[shield-generator-d]',
		place_result = 'shield-generators-generator-ultimate',
		stack_size = 10
	},

	-- energy shield building recipe
	{
		type = 'recipe',
		name = 'shield-generators-generator',
		enabled = false,
		results = {{type = 'item', name = 'shield-generators-generator', amount = 1}},

		energy_required = 2,

		ingredients = {
			{type = 'item', name = 'accumulator', amount = 20},
			{type = 'item', name = 'speed-module', amount = 5},
			{type = 'item', name = 'processing-unit', amount = 10},
			-- {type = 'item', name = 'energy-shield-equipment', 15},
			{type = 'item', name = 'steel-plate', amount = 20},
		},
	},

	{
		type = 'recipe',
		name = 'shield-generators-generator-advanced',
		enabled = false,
		results = {{type = 'item', name = 'shield-generators-generator-advanced', amount = 1}},

		energy_required = 4,

		ingredients = {
			{type = 'item', name = 'accumulator', amount = 20},
			{type = 'item', name = 'speed-module-2', amount = 5},
			{type = 'item', name = 'efficiency-module', amount = 5},
			{type = 'item', name = 'processing-unit', amount = 10},
			{type = 'item', name = 'shield-generators-generator', amount = 2},
			{type = 'item', name = 'low-density-structure', amount = 10},
		},
	},

	{
		type = 'recipe',
		name = 'shield-generators-generator-elite',
		enabled = false,
		results = {{type = 'item', name = 'shield-generators-generator-elite', amount = 1}},

		energy_required = 8,

		ingredients = {
			{type = 'item', name = 'speed-module-2', amount = 5},
			{type = 'item', name = 'efficiency-module-2', amount = 5},
			{type = 'item', name = 'shield-generators-generator-advanced', amount = 2},
		},
	},

	{
		type = 'recipe',
		name = 'shield-generators-generator-ultimate',
		enabled = false,
		results = {{type = 'item', name = 'shield-generators-generator-ultimate', amount = 1}},

		energy_required = 2,

		ingredients = {
			{type = 'item', name = 'speed-module-3', amount = 5},
			{type = 'item', name = 'efficiency-module-3', amount = 5},
			{type = 'item', name = 'shield-generators-generator-elite', amount = 2},
		},
	},

	{
		type = 'technology',
		name = 'shield-generators-superconducting-shields',

		icons = {
			{
				icon_size = 64,
				icon_mipmaps = 4,
				icon = '__base__/graphics/icons/beacon.png',
			},

			{
				icon_size = 128,
				icon_mipmaps = 3,
				scale = 0.25,
				shift = {25, 25},
				icon = '__core__/graphics/icons/technology/constants/constant-health.png',
			},
		},

		effects = {
			{
				type = 'nothing',
				effect_description = {'effect-name.shield-generators-shields-health', tostring(values.SUPERCONDUCTING_PERCENT)}
			}
		},

		prerequisites = {
			'shield-generators-generator-elite',
			'space-science-pack'
		},

		unit = {
			count = 800,

			ingredients = {
				{'automation-science-pack', 1},
				{'logistic-science-pack', 1},
				{'military-science-pack', 1},
				{'utility-science-pack', 1},
				{'space-science-pack', 1},
			},

			time = 60
		},
	}
}

do
	local prerequisites = {'shield-generators-turret-shields-basics', 'chemical-science-pack'}
	local ingredients = {
		{'automation-science-pack', 1},
		{'logistic-science-pack', 1},
		{'military-science-pack', 1},
		{'chemical-science-pack', 1},
	}

	for i, data in ipairs(values.TURRET_SHIELD_CAPACITY_RESEARCH) do
		ingredients = table.deepcopy(ingredients)

		for i2, ingr in ipairs(data[2]) do
			table.insert(prerequisites, ingr[1])

			if ingr[2] then
				table.insert(ingredients, {ingr[1], 1})
			end
		end

		table.insert(prototypes, {
			type = 'technology',
			name = 'shield-generators-turret-shield-capacity-' .. i,

			icons = {
				{
					icon_size = 64,
					icon_mipmaps = 4,
					icon = '__base__/graphics/icons/energy-shield-equipment.png',
				},

				{
					icon_size = 128,
					icon_mipmaps = 3,
					scale = 0.25,
					shift = {25, 25},
					icon = '__core__/graphics/icons/technology/constants/constant-battery.png',
				},
			},

			effects = {
				{
					type = 'nothing',
					effect_description = {'effect-name.shield-generators-turret-shield-capacity', tostring(data[1])}
				}
			},

			prerequisites = prerequisites,

			unit = {
				count = data[3],
				ingredients = ingredients,
				time = data[4]
			},

			upgrade = true,
		})

		prerequisites = {'shield-generators-turret-shield-capacity-' .. i}
	end
end

do
	local prerequisites = {'shield-generators-turret-shields-basics', 'chemical-science-pack'}
	local ingredients = {
		{'automation-science-pack', 1},
		{'logistic-science-pack', 1},
		{'military-science-pack', 1},
		{'chemical-science-pack', 1},
	}

	local base = {
		type = 'electric-energy-interface',
		name = 'shield-generators-interface-0',
		localised_name = {'entity-name.shield-generators-interface'},

		flags = {
			'not-on-map',
			'not-deconstructable',
			'not-blueprintable',
			'not-flammable',
			'not-upgradable',
			'not-in-kill-statistics',
			'not-repairable',
			'placeable-off-grid',
			'not-selectable-in-game',
			'no-copy-paste'
		},

		hidden = true,
		hidden_in_factoriopedia = true,
		selectable_in_game = false,

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

		collision_mask = {layers = {}}, -- do not collide with anything

		energy_source = {
			type = 'electric',
			buffer_capacity = '8MJ',
			usage_priority = 'secondary-input',
			input_flow_limit = '600kW',
			output_flow_limit = '0W',
			drain = '0W',
		}
	}

	-- energy interface per turret
	table.insert(prototypes, table.deepcopy(base))

	local modifier = 1

	for i, data in ipairs(values.TURRET_SHIELD_INPUT_RESEARCH) do
		ingredients = table.deepcopy(ingredients)

		for i2, ingr in ipairs(data[2]) do
			table.insert(prerequisites, ingr[1])

			if ingr[2] then
				table.insert(ingredients, {ingr[1], 1})
			end
		end

		table.insert(prototypes, {
			type = 'technology',
			name = 'shield-generators-turret-shield-input-' .. i,

			icons = {
				{
					icon_size = 64,
					icon_mipmaps = 4,
					icon = '__base__/graphics/icons/energy-shield-equipment.png',
				},

				{
					icon_size = 128,
					icon_mipmaps = 3,
					scale = 0.25,
					shift = {25, 25},
					icon = '__core__/graphics/icons/technology/constants/constant-speed.png',
				},
			},

			effects = {
				{
					type = 'nothing',
					effect_description = {'effect-name.shield-generators-turret-shield-input', tostring(data[1])}
				}
			},

			prerequisites = prerequisites,

			unit = {
				count = data[3],
				ingredients = ingredients,
				time = data[4]
			},

			upgrade = true,
		})

		modifier = modifier + data[1] / 100
		base.energy_source.input_flow_limit = string.format('%.2fkW', 600 * modifier)
		base.name = 'shield-generators-interface-' .. i
		table.insert(prototypes, table.deepcopy(base))

		prerequisites = {'shield-generators-turret-shield-input-' .. i}
	end
end

do
	local prerequisites = {'shield-generators-turret-shields-basics', 'chemical-science-pack'}
	local ingredients = {
		{'automation-science-pack', 1},
		{'logistic-science-pack', 1},
		{'military-science-pack', 1},
		{'chemical-science-pack', 1},
	}

	for i, data in ipairs(values.TURRET_SHIELD_SPEED_RESEARCH) do
		ingredients = table.deepcopy(ingredients)

		for i2, ingr in ipairs(data[2]) do
			table.insert(prerequisites, ingr[1])

			if ingr[2] then
				table.insert(ingredients, {ingr[1], 1})
			end
		end

		table.insert(prototypes, {
			type = 'technology',
			name = 'shield-generators-turret-shield-speed-' .. i,

			icons = {
				{
					icon_size = 64,
					icon_mipmaps = 4,
					icon = '__base__/graphics/icons/energy-shield-equipment.png',
				},

				{
					icon_size = 128,
					icon_mipmaps = 3,
					scale = 0.25,
					shift = {25, 25},
					icon = '__core__/graphics/icons/technology/constants/constant-movement-speed.png',
				},
			},

			effects = {
				{
					type = 'nothing',
					effect_description = {'effect-name.shield-generators-turret-shield-speed', tostring(data[1])}
				}
			},

			prerequisites = prerequisites,

			unit = {
				count = data[3],
				ingredients = ingredients,
				time = data[4]
			},

			upgrade = true,
		})

		prerequisites = {'shield-generators-turret-shield-speed-' .. i}
	end
end

do
	local prerequisites = {'shield-generators-provider-shields-basics'}
	local ingredients = {
		{'automation-science-pack', 1},
		{'logistic-science-pack', 1},
		{'military-science-pack', 1},
		{'chemical-science-pack', 1},
	}

	for i, data in ipairs(values.SHIELD_SPEED_RESEARCH) do
		ingredients = table.deepcopy(ingredients)

		for i2, ingr in ipairs(data[2]) do
			table.insert(prerequisites, ingr[1])

			if ingr[2] then
				table.insert(ingredients, {ingr[1], 1})
			end
		end

		table.insert(prototypes, {
			type = 'technology',
			name = 'shield-generators-provider-shield-speed-' .. i,

			icons = {
				{
					icon_size = 64,
					icon_mipmaps = 4,
					-- icon = '__base__/graphics/icons/energy-shield-equipment.png',
					icon = '__base__/graphics/icons/beacon.png',
				},

				{
					icon_size = 128,
					icon_mipmaps = 3,
					scale = 0.25,
					shift = {25, 25},
					icon = '__core__/graphics/icons/technology/constants/constant-movement-speed.png',
				},
			},

			effects = {
				{
					type = 'nothing',
					effect_description = {'effect-name.shield-generators-provider-shield-speed', tostring(data[1])}
				}
			},

			prerequisites = prerequisites,

			unit = {
				count = data[3],
				ingredients = ingredients,
				time = data[4]
			},

			upgrade = true,
		})

		prerequisites = {'shield-generators-provider-shield-speed-' .. i}
	end
end

local switch_prototype = {
	type = 'selection-tool',
	name = 'shield-generator-switch',
	icon = '__shield-generators__/graphics/icons/toggle-shields.png',
	icon_size = 32,

	select = {
		border_color = {92 / 255, 143 / 255, 247 / 255},
		mode = {'any-entity', 'same-force'},
		cursor_box_type = 'entity',
		entity_type_filters = {'electric-energy-interface'},
	},

	flags = {'only-in-cursor', 'spawnable'},
	subgroup = 'tool',
	order = 'd[tools]-a[shield-generators-toggle]',
	stack_size = 1
}

switch_prototype.alt_select = switch_prototype.select

table.insert(prototypes, switch_prototype)

local switch_shortcut = {
	type = 'shortcut',
	name = 'shield-generator-switch',
	localised_name = {'item-name.shield-generator-switch'},

	order = 'b[tools]-a[shield-generators-toggle]',

	associated_control_input = 'shield-generator-switch',
	action = 'spawn-item',
	item_to_spawn = 'shield-generator-switch',
	technology_to_unlock = 'shield-generators-basics',
	icons = {{
		icon = '__shield-generators__/graphics/icons/toggle-shields-shortcut.png',
		icon_size = 64,
		scale = 0.5,
	}},
}

switch_shortcut.small_icons = switch_shortcut.icons
table.insert(prototypes, switch_shortcut)

table.insert(prototypes, {
	type = 'custom-input',
	name = 'shield-generator-switch',
	localised_name = {'item-name.shield-generator-switch'},
	action = 'spawn-item',
	item_to_spawn = 'shield-generator-switch',
	key_sequence = 'ALT + S',
})

data:extend(prototypes)
