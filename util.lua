
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
	local modifier = settings.startup['shield-generators-multiplier'].value / 100.0

	if technologies['shield-generators-superconducting-shields'].researched then
		modifier = modifier + values.SUPERCONDUCTING_PERCENT / 100
	end

	return modifier
end

function shield_util.max_capacity_modifier_self(technologies)
	return values.DURABILITY_MULTIPLIER / 100.0
end

function shield_util.starts_with(a, b)
	return a:sub(1, #b) == b
end

return shield_util
