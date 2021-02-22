
local shields, destroy_remap

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = 200

script.on_init(function()
	global.shields = {}
	global.destroy_remap = {}
	shields = global.shields
	destroy_remap = global.destroy_remap
end)

script.on_load(function()
	shields = global.shields
	destroy_remap = global.destroy_remap
end)

local function debug(str)
	for index, player in pairs(game.players) do
		player.print(str)
	end
end

script.on_event(defines.events.on_entity_damaged, function(event)
	local entity, damage_type, original_damage_amount, final_damage_amount, final_health, cause, force = event.entity, event.damage_type, event.original_damage_amount, event.final_damage_amount, event.final_health, event.cause, event.force

	if not shields[entity.unit_number] then return end
	if not shields[entity.unit_number].shield then return end

	local energy = shields[entity.unit_number].shield.energy
	local consumption = CONSUMPTION_PER_HITPOINT * final_damage_amount

	if energy - consumption > 0 then
		entity.health = entity.health + final_damage_amount
		shields[entity.unit_number].shield.energy = energy - consumption
	else
		entity.health = entity.health + energy / CONSUMPTION_PER_HITPOINT
		shields[entity.unit_number].shield.energy = 0
	end
end)

script.on_event(defines.events.on_built_entity, function(event)
	local created_entity, player_index, stack, item, tags = event.created_entity, event.player_index, event.stack, event.item, event.tags

	if shields[created_entity.unit_number] then return end -- wut
	if created_entity.name == 'shield-generators-interface' then return end

	--[[for index, player in pairs(game.players) do
		player.print(tostring(created_entity))

		for k, v in pairs(created_entity) do
			player.print(tostring(k) .. ' ' .. tostring(v))
		end
	end]]

	destroy_remap[script.register_on_entity_destroyed(created_entity)] = created_entity.unit_number

	shields[created_entity.unit_number] = {
		shield = created_entity.surface.create_entity({
			name = 'shield-generators-interface',
			position = created_entity.position,
			force = created_entity.force,
		})
	}
end)

local function on_destroy(index)
	if not shields[index] then return end

	if shields[index].shield and shields[index].shield.destroy then
		shields[index].shield.destroy()
	end

	shields[index] = nil
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	local index = event.registration_number
	if not destroy_remap[index] then return end
	on_destroy(destroy_remap[index])
	destroy_remap[index] = nil
end)
