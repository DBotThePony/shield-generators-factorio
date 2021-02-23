
local values = {
	BACKGROUND_COLOR = {40 / 255, 40 / 255, 40 / 255},
	SHIELD_COLOR = {243 / 255, 236 / 255, 53 / 255},
	SHIELD_RADIUS_COLOR = {r = 243, g = 236, b = 53, a = 1},
	SHIELD_BUFF_COLOR = {92 / 255, 143 / 255, 247 / 255},

	BAR_HEIGHT = 0.15,
}

values.SHIELD_RADIUS_COLOR = {243 / 255, 236 / 255, 53 / 255, 30 / 255}
values.SHIELD_RADIUS_COLOR[1] = values.SHIELD_RADIUS_COLOR[1] * values.SHIELD_RADIUS_COLOR[4]
values.SHIELD_RADIUS_COLOR[2] = values.SHIELD_RADIUS_COLOR[2] * values.SHIELD_RADIUS_COLOR[4]
values.SHIELD_RADIUS_COLOR[3] = values.SHIELD_RADIUS_COLOR[3] * values.SHIELD_RADIUS_COLOR[4]

values.GENERATORS = {
	'shield-generators-generator',
	'shield-generators-generator-advanced',
	'shield-generators-generator-elite',
	'shield-generators-generator-ultimate',
}

values.TURRET_SHIELD_CAPACITY_RESEARCH = {
	{15, {}, 100, 30},
	{15, {{'military-3', false}}, 150, 30},
	{25, {}, 300, 30},

	{35, {{'utility-science-pack', true}}, 400, 45},
	{35, {{'military-4', false}}, 500, 45},
	{45, {}, 600, 45},

	{55, {}, 800, 60},
	-- then infinite
}

values.TURRET_SHIELD_CAPACITY_RESEARCH_INFINITE = 65

values.TURRET_SHIELD_SPEED_RESEARCH = {
	{25, {}, 250, 30},
	{35, {{'military-3', false}}, 350, 45},

	{45, {{'utility-science-pack', true}}, 500, 45},
	{45, {{'military-4', false}}, 675, 45},
	{45, {}, 800, 45},

	{65, {{'space-science-pack', true}}, 1500, 60}, -- final level
}

return values
