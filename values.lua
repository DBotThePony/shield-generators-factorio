
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

local values = {
	BACKGROUND_COLOR = {40 / 255, 40 / 255, 40 / 255},
	SHIELD_COLOR = {243 / 255, 236 / 255, 53 / 255},
	SHIELD_COLOR_VISUAL = {1, 0, 0},
	SHIELD_RADIUS_COLOR = {r = 243, g = 236, b = 53, a = 1},
	SHIELD_BUFF_COLOR = {92 / 255, 143 / 255, 247 / 255},

	BAR_HEIGHT = 0.15,
}

values.SHIELD_RADIUS_COLOR = {243 / 255, 236 / 255, 53 / 255, 15 / 255}
values.SHIELD_RADIUS_COLOR[1] = values.SHIELD_RADIUS_COLOR[1] * values.SHIELD_RADIUS_COLOR[4]
values.SHIELD_RADIUS_COLOR[2] = values.SHIELD_RADIUS_COLOR[2] * values.SHIELD_RADIUS_COLOR[4]
values.SHIELD_RADIUS_COLOR[3] = values.SHIELD_RADIUS_COLOR[3] * values.SHIELD_RADIUS_COLOR[4]

values.VISUAL_DAMAGE_BAR_SHRINK_SPEED = 0.01
values.VISUAL_DAMAGE_BAR_WAIT_TICKS = 30
values.VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX = 90

values.GENERATORS = {
	'shield-generators-generator',
	'shield-generators-generator-advanced',
	'shield-generators-generator-elite',
	'shield-generators-generator-ultimate',
}


values.TURRET_SHIELD_CAPACITY_RESEARCH = {
	{15, {}, 100, 30},
	{25, {{'military-3', false}}, 150, 30},

	{35, {{'utility-science-pack', true}}, 400, 45},
	{45, {{'military-4', false}}, 500, 45},
}

values.SUPERCONDUCTING_PERCENT = 100

values.TURRET_SHIELD_INPUT_RESEARCH = {
	{25, {}, 250, 30},
	{35, {{'military-3', false}}, 350, 45},

	{45, {{'utility-science-pack', true}}, 500, 45},
	{45, {{'military-4', false}}, 675, 45},
	{45, {}, 800, 45},

	{65, {{'space-science-pack', true}}, 1500, 60}, -- final level
}

values.SELF_GENERATORS = {
	'shield-generators-interface-0'
}

for i, data in ipairs(values.TURRET_SHIELD_INPUT_RESEARCH) do
	table.insert(values.SELF_GENERATORS, 'shield-generators-interface-' .. i)
end

values.TURRET_SHIELD_SPEED_RESEARCH = {
	{25, {}, 300, 30},
	{45, {{'military-3', false}}, 400, 30},

	{55, {{'utility-science-pack', true}}, 500, 45},
	{65, {{'military-4', false}}, 600, 45},

	{85, {{'space-science-pack', true}}, 1000, 60}, -- final level
}

values.SHIELD_SPEED_RESEARCH = {
	{15, {}, 200, 30},
	{25, {}, 300, 30},
	{35, {{'military-3', false}}, 400, 30},
	{35, {}, 500, 30},

	{45, {{'utility-science-pack', true}}, 600, 45},
	{45, {}, 700, 60},
	{55, {{'military-4', false}}, 800, 75},
	{55, {}, 900, 75},

	{65, {{'space-science-pack', true}}, 2000, 90},
}

values.TECH_REBUILD_TRIGGERS = {}

for i in ipairs(values.SHIELD_SPEED_RESEARCH) do
	values.TECH_REBUILD_TRIGGERS['shield-generators-provider-shield-speed-' .. i] = true
end

for i in ipairs(values.TURRET_SHIELD_SPEED_RESEARCH) do
	values.TECH_REBUILD_TRIGGERS['shield-generators-turret-shield-speed-' .. i] = true
end

values.SENTRY_REBUILD_TRIGGERS = {}

for i in ipairs(values.TURRET_SHIELD_INPUT_RESEARCH) do
	values.SENTRY_REBUILD_TRIGGERS['shield-generators-turret-shield-input-' .. i] = true
end

for i in ipairs(values.TURRET_SHIELD_CAPACITY_RESEARCH) do
	values.SENTRY_REBUILD_TRIGGERS['shield-generators-turret-shield-capacity-' .. i] = true
end

-- lookup hash table
values.allowed_types = {}

values.allowed_types_self = {
	['turret'] = true,
	['ammo-turret'] = true,
	['electric-turret'] = true,
	['fluid-turret'] = true,
	['artillery-turret'] = true,
}

values._allowed_types_self = {}

-- array to pass to find_entities_filtered and to build hash above
values._allowed_types = {
	'boiler',
	'beacon',
	'artillery-turret',
	'accumulator',
	'burner-generator',
	'assembling-machine',
	'rocket-silo',
	'furnace',
	-- 'electric-energy-interface', -- porbably, interfaces are not good for this
	'electric-pole',
	'gate',
	'generator',
	'heat-pipe',
	-- 'heat-interface', -- porbably, interfaces are not good for this
	'inserter',
	'lab',
	'lamp',
	-- 'land-mine', -- i think no
	'linked-container',
	'market',
	'mining-drill',
	'offshore-pump',
	'pipe',
	'infinity-pipe', -- editor stuff
	'pipe-to-ground',
	'power-switch',
	'programmable-speaker',
	'pump',
	'radar',
	'curved-rail',
	'straight-rail',
	'rail-chain-signal',
	'rail-signal',
	'reactor',
	'roboport',
	'solar-panel',
	'storage-tank',
	'train-stop',
	'loader-1x1',
	'loader',
	'splitter',
	'transport-belt',
	'underground-belt',

	-- turrets have their own shield, but if we build shield protector near them
	-- protect them too
	'turret',
	'ammo-turret',
	'electric-turret',
	'fluid-turret',

	'wall',

	-- logic entities
	'arithmetic-combinator',
	'decider-combinator',
	'constant-combinator',

	-- chests
	'container',
	'logistic-container',
	'infinity-container', -- editor specific
}

values.blacklist = {}

values._blacklist = {
	'tf-pole' -- tidy factory pole
}

for i, _type in ipairs(values._allowed_types) do
	values.allowed_types[_type] = true
end

for i, _type in ipairs(values._blacklist) do
	values.blacklist[_type] = true
end

for _type in pairs(values.allowed_types_self) do
	table.insert(values._allowed_types_self, _type)
end

return values
