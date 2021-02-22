
local shields, shield_generators, shield_generators_hash, shield_generators_bound, destroy_remap

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = 2000
local HITPOINTS_PER_TICK = 1

-- wwwwwwwwwtf??? with Lua of Wube
-- why it doesn't return inserted index
local function table_insert(tab, value)
	local insert = #tab + 1
	tab[insert] = value
	return insert
end

script.on_init(function()
	global.shields = {}
	global.destroy_remap = {}
	global.shield_generators_bound = {}
	global.shield_generators = {}
	global.shield_generators_hash = {}

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	shield_generators_hash = global.shield_generators_hash
end)

script.on_load(function()
	global.shields = global.shields or {}
	global.destroy_remap = global.destroy_remap or {}
	global.shield_generators_bound = global.shield_generators_bound or {}
	global.shield_generators = global.shield_generators or {}
	global.shield_generators_hash = global.shield_generators_hash or {}

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	shield_generators_hash = global.shield_generators_hash
end)

local function debug(str)
	for index, player in pairs(game.players) do
		player.print(str)
	end
end

script.on_event(defines.events.on_tick, function(event)
	for i = 1, #shield_generators do
		local data = shield_generators[i]

		if data.unit.valid then
			local energy = data.unit.energy

			if energy > 0 then
				for i2 = 1, #data.tracked do
					local tracked_data = data.tracked[i2]

					if tracked_data.shield_health < tracked_data.max_health then
						local delta = math.min(energy / CONSUMPTION_PER_HITPOINT, HITPOINTS_PER_TICK, tracked_data.max_health - tracked_data.shield_health)
						tracked_data.shield_health = tracked_data.shield_health + delta
						energy = energy - delta * CONSUMPTION_PER_HITPOINT

						if energy <= 0 then break end
					end
				end
			end

			data.unit.energy = energy
		else
			debug('Shield is still invalid but iterated ' .. data.id .. ' ' .. i)
		end
	end
end)

script.on_event(defines.events.on_entity_damaged, function(event)
	local entity, damage_type, original_damage_amount, final_damage_amount, final_health, cause, force = event.entity, event.damage_type, event.original_damage_amount, event.final_damage_amount, event.final_health, event.cause, event.force

	local unit_number = entity.unit_number
	local shield = shields[unit_number]

	-- internal shield
	if shield and shield.shield then
		local energy = shield.shield.energy
		local consumption = CONSUMPTION_PER_HITPOINT * final_damage_amount
		local health = shield.health or entity.health

		if energy - consumption > 0 then
			entity.health = health
			shields[unit_number].shield.energy = energy - consumption
		else
			shield.health = health - final_damage_amount + energy / CONSUMPTION_PER_HITPOINT
			entity.health = shield.health
			shields[unit_number].shield.energy = 0
		end
	elseif shield_generators_bound[unit_number] then -- bound shield generator provider
		local shield_generator = shield_generators[shield_generators_hash[shield_generators_bound[unit_number]]]
		local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[unit_number]]

		local health = tracked_data.health
		local shield_health = tracked_data.shield_health

		if shield_health >= final_damage_amount then
			entity.health = tracked_data.health
			tracked_data.shield_health = shield_health - final_damage_amount
		else
			tracked_data.health = health - final_damage_amount + tracked_data.shield_health
			entity.health = tracked_data.health
			tracked_data.shield_health = 0
		end
	end
end)

local function bindShield(entity, shield_provider)
	local unit_number = entity.unit_number

	if shield_provider.tracked_hash[unit_number] then return false end
	if shield_generators_bound[unit_number] then return false end
	local max_health = entity.prototype.max_health

	if not max_health or max_health <= 0 then return false end

	-- create tracked data for shield state
	local tracked_data = {
		health = entity.health,
		max_health = entity.prototype.max_health,
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		-- upper bound by max_health
	}

	-- tell globally that this entity has it's shield provider
	-- which we can later lookup in shield_generators_hash[shield_provider.id]
	shield_generators_bound[entity.unit_number] = shield_provider.id

	-- register
	-- set tracked_hash index value to index in shield_provider.tracked
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	destroy_remap[script.register_on_entity_destroyed(entity)] = unit_number

	-- debug('Bound entity ' .. unit_number .. ' to shield generator ' .. shield_provider.id .. ' with max health of ' .. tracked_data.max_health)
end

-- lookup hash table
local allowed_types = {}

-- array to pass to find_entities_filtered and to build hash above
local _allowed_types = {
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

	-- turrets, maybe give them their own shields
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

for i, _type in ipairs(_allowed_types) do
	allowed_types[_type] = true
end

script.on_event(defines.events.on_built_entity, function(event)
	local created_entity, player_index, stack, item, tags = event.created_entity, event.player_index, event.stack, event.item, event.tags

	if shields[created_entity.unit_number] then return end -- wut
	if created_entity.name == 'shield-generators-interface' then return end

	if created_entity.name == 'shield-generators-generator' then
		destroy_remap[script.register_on_entity_destroyed(created_entity)] = created_entity.unit_number

		local data = {
			unit = created_entity,
			id = created_entity.unit_number,
			tracked = {}, -- sequential table for quick iteration
			tracked_hash = {}, -- hash table for quick lookup
		}

		shield_generators_hash[created_entity.unit_number] = table_insert(shield_generators, data)
		-- debug('Shield placed with index ' .. created_entity.unit_number .. ' and index ' .. shield_generators_hash[created_entity.unit_number])

		-- find buildings around already placed
		local found = created_entity.surface.find_entities_filtered({
			position = created_entity.position,
			radius = 32,
			force = created_entity.force,
			type = _allowed_types,
		})

		for i, ent in ipairs(found) do
			bindShield(ent, data)
		end

		return
	end

	if not allowed_types[created_entity.type] then return end

	-- find shield generators
	local found = created_entity.surface.find_entities_filtered({
		position = created_entity.position,
		radius = 32,
		force = created_entity.force,
		name = 'shield-generators-generator'
	})

	if found[1] and shield_generators_hash[found[1].unit_number] then
		bindShield(created_entity, shield_generators[shield_generators_hash[found[1].unit_number]])
	end

	if true then return end

	destroy_remap[script.register_on_entity_destroyed(created_entity)] = created_entity.unit_number

	shields[created_entity.unit_number] = {
		shield = created_entity.surface.create_entity({
			name = 'shield-generators-interface',
			position = created_entity.position,
			force = created_entity.force,
		}),

		health = created_entity.health,
	}
end)

local function on_destroy(index)
	-- entity with internal shield destroyed
	if shields[index] then
		if shields[index].shield and shields[index].shield.destroy then
			shields[index].shield.destroy()
		end

		shields[index] = nil
	elseif shield_generators_hash[index] then -- shield generator destroyed
		local data = shield_generators[shield_generators_hash[index]]

		-- unbind shield generator from all of it's units
		for i, tracked_data in ipairs(data.tracked) do
			-- unbind shield generator from this unit
			shield_generators_bound[tracked_data.unit.unit_number] = nil
		end

		-- destroy tracked data in sequential table
		for i, _data in ipairs(shield_generators) do
			if _data == index then
				table.remove(shield_generators, i)
				break
			end
		end

		-- destroy tracked data
		table.remove(shield_generators, shield_generators_hash[index])
		local above = shield_generators_hash[index]
		shield_generators_hash[index] = nil

		-- update hash table to reflect change to indexes
		for unit_number, index in pairs(shield_generators_hash) do
			if index >= above then
				shield_generators_hash[unit_number] = index - 1
			end
		end
	elseif shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators[shield_generators_hash[shield_generators_bound[index]]]

		if shield_generator then
			-- we got our shield generator data
			-- let's remove us from tracked entities

			table.remove(shield_generator.tracked, shield_generator.tracked_hash[index])
			local above = shield_generator.tracked_hash[index]
			shield_generator.tracked_hash[index] = nil

			-- update hash table to reflect change to indexes
			for unit_number, index in pairs(shield_generator.tracked_hash) do
				if index >= above then
					shield_generator.tracked_hash[unit_number] = index - 1
				end
			end
		end
	end
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	local index = event.registration_number
	if not destroy_remap[index] then return end
	on_destroy(destroy_remap[index])
	destroy_remap[index] = nil
end)
