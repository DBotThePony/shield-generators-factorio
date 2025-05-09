
util = util or {}
local values = CONSTANTS

function util.determineDimensions(entity)
	local width, height

	if entity.prototype.selection_box then
		if entity.direction == defines.direction.east or entity.direction == defines.direction.west then
			width = math.abs(entity.prototype.selection_box.left_top.y - entity.prototype.selection_box.right_bottom.y)
			height = math.abs(entity.prototype.selection_box.right_bottom.x)
		else
			width = math.abs(entity.prototype.selection_box.left_top.x - entity.prototype.selection_box.right_bottom.x)
			height = math.abs(entity.prototype.selection_box.right_bottom.y)
		end
	else
		width = 1
		height = 0
	end

	if width < 1 then
		width = 1
	end

	height = height + 0.4
	width = width / 2

	return width, height
end

function util.turret_capacity_modifier(technologies)
	local modifier = 1
	local count = #values.TURRET_SHIELD_CAPACITY_RESEARCH

	for i = 1, count do
		if technologies['shield-generators-turret-shield-capacity-' .. i].researched then
			modifier = modifier + values.TURRET_SHIELD_CAPACITY_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function util.turret_interface_name(technologies)
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

function util.turret_recovery_speed_modifier(technologies)
	local modifier = 1

	for i = 1, #values.TURRET_SHIELD_SPEED_RESEARCH do
		if technologies['shield-generators-turret-shield-speed-' .. i].researched then
			modifier = modifier + values.TURRET_SHIELD_SPEED_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function util.recovery_speed_modifier(technologies)
	local modifier = 1

	for i = 1, #values.SHIELD_SPEED_RESEARCH do
		if technologies['shield-generators-provider-shield-speed-' .. i].researched then
			modifier = modifier + values.SHIELD_SPEED_RESEARCH[i][1] / 100
		end
	end

	return modifier
end

function util.max_capacity_modifier(technologies)
	local modifier = settings.global['shield-generators-multiplier'].value / 100.0

	if technologies['shield-generators-superconducting-shields'].researched then
		modifier = modifier + values.SUPERCONDUCTING_PERCENT / 100
	end

	return modifier
end

function util.max_capacity_modifier_self(technologies)
	return settings.global['shield-generators-multiplier'].value / 100.0
end

function util.starts_with(a, b)
	return a:sub(1, #b) == b
end

function report_error(str)
	-- game.print('[Shield Generators] Reported managed error: ' .. str)
	log('Reporting managed error: ' .. str)
end

function util.distance(a, b)
	return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
end

function util.disttosqr(a, b)
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
end

function util.lerp(t, a, b)
	if t < 0 then return a end
	if t >= 1 then return b end
	return a + (b - a) * t
end

function util.insert(tab, value)
	local insert = #tab + 1
	tab[insert] = value
	return insert
end

function util.count(tab)
	local i = 0

	for a, b in pairs(tab) do
		i = i + 1
	end

	return i
end

return util
