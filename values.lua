
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

return values
