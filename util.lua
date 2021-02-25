
local values = require('__shield-generators__/values')
local shield_util = {}

function shield_util.turret_capacity_modifier(technologies)
	local modifier = 1
	local count = #values.TURRET_SHIELD_CAPACITY_RESEARCH

	for i = 1, count do
		if technologies['shield-generators-turret-shield-capacity-' .. i].researched then
			modifier = modifier + values.TURRET_SHIELD_CAPACITY_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function shield_util.turret_interface_name(technologies)
	local name = 'shield-generators-interface-0'

	for i = 1, #values.TURRET_SHIELD_INPUT_RESEARCH do
		if technologies['shield-generators-turret-shield-input-' .. i].researched then
			name = 'shield-generators-interface-' .. i
		else
			return name
		end
	end

	return name
end

function shield_util.turret_recovery_speed_modifier(technologies)
	local modifier = 1

	for i = 1, #values.TURRET_SHIELD_SPEED_RESEARCH do
		if technologies['shield-generators-turret-shield-speed-' .. i].researched then
			modifier = modifier + values.TURRET_SHIELD_SPEED_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function shield_util.recovery_speed_modifier(technologies)
	local modifier = 1

	for i = 1, #values.SHIELD_SPEED_RESEARCH do
		if technologies['shield-generators-provider-shield-speed-' .. i].researched then
			modifier = modifier + values.SHIELD_SPEED_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function shield_util.max_capacity_modifier(technologies)
	local modifier = 1

	if technologies['shield-generators-superconducting-shields'].researched then
		modifier = modifier + values.SUPERCONDUCTING_PERCENT / 100
	end

	return modifier
end

function shield_util.starts_with(a, b)
	return a:sub(1, #b) == b
end

return shield_util
