
local shields, shields_dirty, shield_generators, shield_generators_dirty, shield_generators_hash, shield_generators_bound, destroy_remap

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = 20000
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

	shield_generators_dirty = {}
	shields_dirty = {}
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

	shield_generators_dirty = {}
	shields_dirty = {}

	-- build dirty list from savegame
	for i = 1, #shield_generators do
		if shield_generators[i].tracked_dirty then
			table.insert(shield_generators_dirty, shield_generators[i])
		end
	end

	for unumber, data in pairs(shields) do
		if data.shield_health < data.max_health or data.shield.energy < 8000000 then
			data.dirty = true
			table_insert(shields_dirty, data)
		end
	end
end)

local function debug(str)
	for index, player in pairs(game.players) do
		player.print(str)
	end
end

local function markShieldDirty(shield_generator)
	shield_generator.tracked_dirty = nil

	-- build dirty list
	for i, tracked_data in ipairs(shield_generator.tracked) do
		if tracked_data.shield_health < tracked_data.max_health then
			if not shield_generator.tracked_dirty then
				shield_generator.tracked_dirty = {}
			end

			tracked_data.dirty = true
			table_insert(shield_generator.tracked_dirty, i)
		end
	end

	-- if we are dirty, let's tick
	if shield_generator.tracked_dirty then
		local hit = false

		for i, data in ipairs(shield_generators_dirty) do
			if data == shield_generator then
				hit = true
				break
			end
		end

		if not hit then
			table_insert(shield_generators_dirty, shield_generator)
		end
	else
		for i, data in ipairs(shield_generators_dirty) do
			if data == shield_generator then
				table.remove(shield_generators_dirty, i)
				break
			end
		end
	end
end

script.on_event(defines.events.on_tick, function(event)
	local check = false

	-- iterate dirty shield providers
	for i = 1, #shield_generators_dirty do
		local data = shield_generators_dirty[i]

		if data.unit.valid then
			local energy = data.unit.energy

			if energy > 0 then
				-- remember, whenever there was any dirty shields
				local run_dirty = false

				local count = #data.tracked_dirty
				local health_per_tick = HITPOINTS_PER_TICK

				if count * health_per_tick * CONSUMPTION_PER_HITPOINT > energy then
					health_per_tick = energy / (CONSUMPTION_PER_HITPOINT * count)
				end

				for i2 = count, 1, -1 do
					local tracked_data = data.tracked[data.tracked_dirty[i2]]

					if tracked_data.shield_health < tracked_data.max_health then
						run_dirty = true

						if tracked_data.health ~= tracked_data.max_health then
							-- update hacky health counter if required
							tracked_data.health = tracked_data.unit.health
						end

						local delta = math.min(energy / CONSUMPTION_PER_HITPOINT, health_per_tick, tracked_data.max_health - tracked_data.shield_health)
						tracked_data.shield_health = tracked_data.shield_health + delta
						energy = energy - delta * CONSUMPTION_PER_HITPOINT

						if tracked_data.shield_bar then
							rendering.set_right_bottom(tracked_data.shield_bar,
								tracked_data.unit, {
									-tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health,
									tracked_data.height
								})

							if tracked_data.shield_health >= tracked_data.max_health then
								rendering.set_visible(tracked_data.shield_bar, false)
								rendering.set_visible(tracked_data.shield_bar_bg, false)
							else
								rendering.set_visible(tracked_data.shield_bar, true)
								rendering.set_visible(tracked_data.shield_bar_bg, true)
							end
						end

						if energy <= 0 then break end
					else
						table.remove(data.tracked_dirty, i2)
						tracked_data.dirty = false
					end
				end

				-- not a single dirty entity - consider this shield provider is clean
				if not run_dirty then
					data.tracked_dirty = nil
					check = true
				end
			end

			data.unit.energy = energy
		else
			check = true
		end
	end

	-- if we encountered clean or invalid shield providers,
	-- remove them from ticking
	if check then
		for i = #shield_generators_dirty, 1, -1 do
			local data = shield_generators_dirty[i]

			if not data.unit.valid or not data.tracked_dirty then
				table.remove(shield_generators_dirty, i)
			end
		end
	end

	for i = #shields_dirty, 1, -1 do
		local tracked_data = shields_dirty[i]

		local energy = tracked_data.shield.energy

		if tracked_data.shield_health < tracked_data.max_health then
			if energy > 0 then
				local delta = math.min(energy / CONSUMPTION_PER_HITPOINT, HITPOINTS_PER_TICK, tracked_data.max_health - tracked_data.shield_health)
				tracked_data.shield_health = tracked_data.shield_health + delta
				energy = energy - delta * CONSUMPTION_PER_HITPOINT
				tracked_data.shield.energy = energy

				if tracked_data.health ~= tracked_data.max_health then
					-- update hacky health counter if required
					tracked_data.health = tracked_data.unit.health
				end

				rendering.set_right_bottom(tracked_data.shield_bar,
					tracked_data.unit, {
						-tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health,
						tracked_data.height
					})

				rendering.set_right_bottom(tracked_data.shield_bar_buffer,
					tracked_data.unit, {
						-tracked_data.width + 2 * tracked_data.width * energy / 8000000,
						tracked_data.height
					})
			end
		elseif energy < 8000000 then
			rendering.set_right_bottom(tracked_data.shield_bar_buffer,
				tracked_data.unit, {
					-tracked_data.width + 2 * tracked_data.width * energy / 8000000,
					tracked_data.height
				})
		else
			rendering.set_visible(tracked_data.shield_bar, false)
			rendering.set_visible(tracked_data.shield_bar_bg, false)
			rendering.set_visible(tracked_data.shield_bar_buffer, false)

			tracked_data.dirty = false
			table.remove(shields_dirty, i)
		end
	end
end)

script.on_event(defines.events.on_entity_damaged, function(event)
	local entity, damage_type, original_damage_amount, final_damage_amount, final_health, cause, force = event.entity, event.damage_type, event.original_damage_amount, event.final_damage_amount, event.final_health, event.cause, event.force

	local unit_number = entity.unit_number
	local shield = shields[unit_number]

	-- internal shield
	if shield then
		local shield_health = shield.shield_health
		local health = shield.health or entity.health

		if shield_health >= final_damage_amount then
			-- HACK HACK HACK
			-- we have no idea how to determine old health in this case
			if final_health == 0 then
				entity.health = shield.health
			else
				entity.health = entity.health + final_damage_amount
				shield.health = entity.health
			end

			shields[unit_number].shield_health = shield_health - final_damage_amount
		else
			shield.health = health - final_damage_amount + shield_health
			entity.health = shield.health
			shields[unit_number].shield_health = 0
		end

		if not shield.dirty then
			shield.dirty = true
			table_insert(shields_dirty, shield)
			rendering.set_visible(shield.shield_bar, true)
			rendering.set_visible(shield.shield_bar_bg, true)
			rendering.set_visible(shield.shield_bar_buffer, true)
		end
	elseif shield_generators_bound[unit_number] then -- bound shield generator provider
		local shield_generator = shield_generators[shield_generators_hash[shield_generators_bound[unit_number]]]

		if shield_generator then
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[unit_number]]

			if tracked_data then
				local health = tracked_data.health
				local shield_health = tracked_data.shield_health

				if shield_health >= final_damage_amount then
					-- HACK HACK HACK
					-- we have no idea how to determine old health in this case
					if final_health == 0 then
						entity.health = tracked_data.health
					else
						entity.health = entity.health + final_damage_amount
						tracked_data.health = entity.health
					end

					tracked_data.shield_health = shield_health - final_damage_amount
				else
					tracked_data.health = health - final_damage_amount + tracked_data.shield_health
					entity.health = tracked_data.health
					tracked_data.shield_health = 0
				end

				-- not dirty? mark shield generator as dirty
				if not shield_generator.tracked_dirty then
					markShieldDirty(shield_generator)

				-- shield is dirty but we are not?
				-- mark us as dirty
				elseif not tracked_data.dirty then
					tracked_data.dirty = true
					table_insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
				end
			else
				debug('Entity ' .. unit_number .. ' appears to be bound to generator ' .. shield_generator.id .. ', but it is not present in tracked[]!')
			end
		else
			debug('Entity ' .. unit_number .. ' appears to be bound to generator ' .. shield_generators_bound[unit_number] .. ', but this generator is invalid!')
		end
	end
end)

local BACKGROUND_COLOR = {40 / 255, 40 / 255, 40 / 255}
local SHIELD_COLOR = {243 / 255, 236 / 255, 53 / 255}
local SHIELD_BUFF_COLOR = {92 / 255, 143 / 255, 247 / 255}

local function makeShieldBars(entity, extra)
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

	return width, height, rendering.draw_rectangle({
		color = BACKGROUND_COLOR,
		forces = {entity.force},
		filled = true,
		surface = entity.surface,
		left_top = entity,
		left_top_offset = {-width, height - 0.15},
		right_bottom = entity,
		right_bottom_offset = {width, height},
	}), rendering.draw_rectangle({
		color = SHIELD_COLOR,
		forces = {entity.force},
		filled = true,
		surface = entity.surface,
		left_top = entity,
		left_top_offset = {-width, height - 0.15},
		right_bottom = entity,
		right_bottom_offset = {-width, height},
	}), extra and rendering.draw_rectangle({
		color = SHIELD_BUFF_COLOR,
		forces = {entity.force},
		filled = true,
		surface = entity.surface,
		left_top = entity,
		left_top_offset = {-width, height - 0.075},
		right_bottom = entity,
		right_bottom_offset = {-width, height},
	}) or nil
end

local function bindShield(entity, shield_provider)
	local unit_number = entity.unit_number

	if shield_provider.tracked_hash[unit_number] then return false end
	if shield_generators_bound[unit_number] then return false end
	local max_health = entity.prototype.max_health

	if not max_health or max_health <= 0 then return false end

	local width, height, shield_bar_bg, shield_bar = makeShieldBars(entity)

	-- create tracked data for shield state
	local tracked_data = {
		health = entity.health,
		max_health = entity.prototype.max_health,
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		-- upper bound by max_health

		width = width,
		height = height,

		shield_bar_bg = shield_bar_bg,
		shield_bar = shield_bar
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

local allowed_types_self = {
	['turret'] = true,
	['ammo-turret'] = true,
	['electric-turret'] = true,
	['fluid-turret'] = true,
	['artillery-turret'] = true,
}

-- array to pass to find_entities_filtered and to build hash above
local _allowed_types = {
	'boiler',
	'beacon',
	-- 'artillery-turret',
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
	-- 'turret',
	-- 'ammo-turret',
	-- 'electric-turret',
	-- 'fluid-turret',

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

local function on_build(created_entity)
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

		bindShield(created_entity, data)
		markShieldDirty(data)

		return
	elseif allowed_types[created_entity.type] then
		-- find shield generators
		local found = created_entity.surface.find_entities_filtered({
			position = created_entity.position,
			radius = 32,
			force = created_entity.force,
			name = 'shield-generators-generator'
		})

		if found[1] and shield_generators_hash[found[1].unit_number] then
			local shield_generator = shield_generators[shield_generators_hash[found[1].unit_number]]
			bindShield(created_entity, shield_generator)
			markShieldDirty(shield_generator)
		end
	elseif allowed_types_self[created_entity.type] then
		destroy_remap[script.register_on_entity_destroyed(created_entity)] = created_entity.unit_number

		local width, height, shield_bar_bg, shield_bar, shield_bar_buffer = makeShieldBars(created_entity, true)

		local tracked_data = {
			shield = created_entity.surface.create_entity({
				name = 'shield-generators-interface',
				position = created_entity.position,
				force = created_entity.force,
			}),

			max_health = created_entity.prototype.max_health,
			shield_health = 0,

			width = width,
			height = height,
			shield_bar_bg = shield_bar_bg,
			shield_bar = shield_bar,
			shield_bar_buffer = shield_bar_buffer,

			health = created_entity.health,
			unit = created_entity,
			id = created_entity.unit_number,

			dirty = true
		}

		tracked_data.shield.destructible = false
		tracked_data.shield.minable = false
		tracked_data.shield.rotatable = false

		shields[created_entity.unit_number] = tracked_data
		table_insert(shields_dirty, tracked_data)
	end
end

script.on_event(defines.events.on_built_entity, function(event)
	on_build(event.created_entity)
end)

script.on_event(defines.events.script_raised_built, function(event)
	on_build(event.entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	on_build(event.created_entity)
end)

local function on_destroy(index)
	-- entity with internal shield destroyed
	if shields[index] then
		local tracked_data = shields[index]

		if tracked_data.shield and tracked_data.shield.destroy then
			tracked_data.shield.destroy()
		end

		if tracked_data.shield_bar_bg then
			rendering.destroy(tracked_data.shield_bar_bg)
		end

		if tracked_data.shield_bar then
			rendering.destroy(tracked_data.shield_bar)
		end

		if tracked_data.dirty then
			for i = 1, #shields_dirty do
				if shields_dirty[i] == tracked_data then
					table.remove(shields_dirty, i)
					break
				end
			end
		end

		shields[index] = nil
	elseif shield_generators_hash[index] then -- shield generator destroyed
		local data = shield_generators[shield_generators_hash[index]]

		-- unbind shield generator from all of it's units
		for i, tracked_data in ipairs(data.tracked) do
			-- unbind shield generator from this unit
			if tracked_data.unit.valid then
				shield_generators_bound[tracked_data.unit.unit_number] = nil
			end

			if tracked_data.shield_bar_bg then
				rendering.destroy(tracked_data.shield_bar_bg)
			end

			if tracked_data.shield_bar then
				rendering.destroy(tracked_data.shield_bar)
			end
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

			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			if tracked_data.shield_bar_bg then
				rendering.destroy(tracked_data.shield_bar_bg)
			end

			if tracked_data.shield_bar then
				rendering.destroy(tracked_data.shield_bar)
			end

			table.remove(shield_generator.tracked, shield_generator.tracked_hash[index])
			local above = shield_generator.tracked_hash[index]
			shield_generator.tracked_hash[index] = nil

			-- force dirty list to be rebuilt
			markShieldDirty(shield_generator)

			-- update hash table to reflect change to indexes
			for unit_number, index in pairs(shield_generator.tracked_hash) do
				if index >= above then
					shield_generator.tracked_hash[unit_number] = index - 1
				end
			end
		end

		shield_generators_bound[index] = nil
	end
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	local index = event.registration_number
	if not destroy_remap[index] then return end
	on_destroy(destroy_remap[index])
	destroy_remap[index] = nil
end)
