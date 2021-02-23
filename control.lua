
local shields, shields_dirty, shield_generators, shield_generators_dirty, shield_generators_hash, shield_generators_bound, destroy_remap

local on_destroyed

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = 20000
local HITPOINTS_PER_TICK = 1
local BAR_HEIGHT = 0.15

local BACKGROUND_COLOR = {40 / 255, 40 / 255, 40 / 255}
local SHIELD_COLOR = {243 / 255, 236 / 255, 53 / 255}
local SHIELD_BUFF_COLOR = {92 / 255, 143 / 255, 247 / 255}

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

local function mark_shield_dirty(shield_generator)
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
		rendering.set_visible(shield_generator.battery_bar_bg, true)
		rendering.set_visible(shield_generator.battery_bar, true)

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
		rendering.set_visible(shield_generator.battery_bar_bg, false)
		rendering.set_visible(shield_generator.battery_bar, false)

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
				-- whenever there was any dirty shields
				local run_dirty = false

				local count = #data.tracked_dirty
				local health_per_tick = HITPOINTS_PER_TICK

				if count * health_per_tick * CONSUMPTION_PER_HITPOINT > energy then
					health_per_tick = energy / (CONSUMPTION_PER_HITPOINT * count)
				end

				for i2 = count, 1, -1 do
					local tracked_data = data.tracked[data.tracked_dirty[i2]]

					if tracked_data.unit.valid then
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
					else
						debug('Encountered invalid unit with tracked index ' .. data.tracked_dirty[i2] .. ' in shield generator ' .. data.id)
					end
				end

				-- not a single dirty entity - consider this shield provider is clean
				-- also check whenever should we draw battery charge bar
				-- if we do have to, then don't mark as clean yet
				if not run_dirty and energy >= data.max_energy then
					data.tracked_dirty = nil
					check = true
				end

				rendering.set_right_bottom(data.battery_bar,
					data.unit, {
						-data.width + 2 * data.width * energy / data.max_energy,
						data.height
					})
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

			if not data.unit.valid then
				table.remove(shield_generators_dirty, i)
			elseif not data.tracked_dirty then
				table.remove(shield_generators_dirty, i)

				rendering.set_visible(data.battery_bar_bg, false)
				rendering.set_visible(data.battery_bar, false)
			end
		end
	end

	-- iterate dirty self shields
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
						tracked_data.height + BAR_HEIGHT
					})
			end
		elseif energy > 0 and energy < 8000000 then
			rendering.set_right_bottom(tracked_data.shield_bar_buffer,
				tracked_data.unit, {
					-tracked_data.width + 2 * tracked_data.width * energy / 8000000,
					tracked_data.height + BAR_HEIGHT
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

	-- bound shield generator provider
	-- process is before internal shield
	if shield_generators_bound[unit_number] then
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
					final_damage_amount = 0
				else
					final_damage_amount = final_damage_amount - tracked_data.shield_health
					tracked_data.health = health - final_damage_amount
					final_health = math.max(0, tracked_data.health)
					entity.health = tracked_data.health
					tracked_data.shield_health = 0
				end

				-- not dirty? mark shield generator as dirty
				if not shield_generator.tracked_dirty then
					mark_shield_dirty(shield_generator)

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

	-- if damage wa reflected by shield provider, don't do anything after
	if final_damage_amount <= 0 then return end

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
	end
end)

local function determineDimensions(entity)
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

local function bind_shield(entity, shield_provider)
	local unit_number = entity.unit_number

	if shield_provider.tracked_hash[unit_number] then return false end
	if shield_generators_bound[unit_number] then return false end
	local max_health = entity.prototype.max_health

	if not max_health or max_health <= 0 then return false end

	local width, height = determineDimensions(entity)

	if shields[entity.unit_number] then
		height = height + BAR_HEIGHT * 2
	end

	-- create tracked data for shield state
	local tracked_data = {
		health = entity.health,
		max_health = entity.prototype.max_health,
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		-- upper bound by max_health

		width = width,
		height = height,

		shield_bar_bg = rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height},
		}),

		shield_bar = rendering.draw_rectangle({
			color = SHIELD_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {-width, height},
		})
	}

	-- tell globally that this entity has it's shield provider
	-- which we can later lookup in shield_generators_hash[shield_provider.id]
	shield_generators_bound[entity.unit_number] = shield_provider.id

	-- register
	-- set tracked_hash index value to index in shield_provider.tracked
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	destroy_remap[script.register_on_entity_destroyed(entity)] = unit_number

	-- debug('Bound entity ' .. unit_number .. ' to shield generator ' .. shield_provider.id .. ' with max health of ' .. tracked_data.max_health)

	return true
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

local _allowed_types_self = {}

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

for i, _type in ipairs(_allowed_types) do
	allowed_types[_type] = true
end

for _type in pairs(allowed_types_self) do
	table_insert(_allowed_types_self, _type)
end

local function on_built_shield_provider(entity)
	if shield_generators_hash[entity.unit_number] then return end -- wut

	destroy_remap[script.register_on_entity_destroyed(entity)] = entity.unit_number

	local width, height = determineDimensions(entity)
	height = height + BAR_HEIGHT

	local data = {
		unit = entity,
		id = entity.unit_number,
		tracked = {}, -- sequential table for quick iteration
		tracked_hash = {}, -- hash table for quick lookup

		width = width,
		height = height,

		battery_bar_bg = rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height},
		}),

		battery_bar = rendering.draw_rectangle({
			color = SHIELD_BUFF_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {-width, height},
		}),

		-- to be set to dynamic value later
		max_energy = entity.electric_buffer_size,
	}

	shield_generators_hash[entity.unit_number] = table_insert(shield_generators, data)
	-- debug('Shield placed with index ' .. entity.unit_number .. ' and index ' .. shield_generators_hash[entity.unit_number])

	-- find buildings around already placed
	local found = entity.surface.find_entities_filtered({
		position = entity.position,
		radius = 32,
		force = entity.force,
		type = _allowed_types,
	})

	for i, ent in ipairs(found) do
		bind_shield(ent, data)
	end

	bind_shield(entity, data)
	mark_shield_dirty(data)
end

local function on_built_shieldable_entity(entity)
	-- find shield generators
	local found = entity.surface.find_entities_filtered({
		position = entity.position,
		radius = 32,
		force = entity.force,
		name = 'shield-generators-generator'
	})

	if found[1] and shield_generators_hash[found[1].unit_number] then
		local shield_generator = shield_generators[shield_generators_hash[found[1].unit_number]]

		if bind_shield(entity, shield_generator) then
			mark_shield_dirty(shield_generator)
		end
	end
end

local function on_built_shieldable_self(entity)
	local index = entity.unit_number
	if shields[index] then return end -- wut

	destroy_remap[script.register_on_entity_destroyed(entity)] = index

	local width, height = determineDimensions(entity)

	local tracked_data = {
		shield = entity.surface.create_entity({
			name = 'shield-generators-interface',
			position = entity.position,
			force = entity.force,
		}),

		max_health = entity.prototype.max_health,
		shield_health = 0,

		width = width,
		height = height,

		shield_bar_bg = rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height + BAR_HEIGHT},
		}),

		shield_bar = rendering.draw_rectangle({
			color = SHIELD_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {-width, height},
		}),

		shield_bar_buffer = rendering.draw_rectangle({
			color = SHIELD_BUFF_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height},
			right_bottom = entity,
			right_bottom_offset = {-width, height + BAR_HEIGHT},
		}),

		health = entity.health,
		unit = entity,
		id = index,

		dirty = true
	}

	tracked_data.shield.destructible = false
	tracked_data.shield.minable = false
	tracked_data.shield.rotatable = false

	shields[index] = tracked_data
	table_insert(shields_dirty, tracked_data)

	-- case: we got self shield after getting shield from shield provider
	-- update bars for them to not overlap with ours
	if shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators[shield_generators_hash[shield_generators_bound[index]]]

		if shield_generator then
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			if tracked_data then
				tracked_data.height = tracked_data.height + BAR_HEIGHT * 2

				rendering.set_top_left(tracked_data.shield_bar, tracked_data.unit, {-tracked_data.width, tracked_data.height})
				rendering.set_top_left(tracked_data.shield_bar_bg, tracked_data.unit, {-tracked_data.width, tracked_data.height})
			end
		end
	end
end

local function on_built(created_entity)
	if created_entity.name == 'shield-generators-generator' then
		on_built_shield_provider(created_entity)
	else
		if allowed_types_self[created_entity.type] and (not created_entity.force or created_entity.force.technologies['shield-generators-turret-shields-basics'].researched) then
			-- create turret shield first
			on_built_shieldable_self(created_entity)
		end

		if allowed_types[created_entity.type] then
			-- create provider shield second
			on_built_shieldable_entity(created_entity)
		end
	end
end

script.on_event(defines.events.on_built_entity, function(event)
	on_built(event.created_entity)
end)

script.on_event(defines.events.script_raised_built, function(event)
	on_built(event.entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	on_built(event.created_entity)
end)

script.on_event(defines.events.on_research_finished, function(event)
	if event.research.name == 'shield-generators-turret-shields-basics' then
		for name, surface in pairs(game.surfaces) do
			local found = surface.find_entities_filtered({
				force = event.research.force,
				type = _allowed_types_self,
			})

			for i, ent in ipairs(found) do
				on_built_shieldable_self(ent)
			end
		end
	end
end)

script.on_event(defines.events.on_research_reversed, function(event)
	if event.research.name == 'shield-generators-turret-shields-basics' then
		for name, surface in pairs(game.surfaces) do
			local found = surface.find_entities_filtered({
				force = event.research.force,
				type = _allowed_types_self,
			})

			for i, ent in ipairs(found) do
				on_destroyed(ent.unit_number)
			end
		end
	end
end)

function on_destroyed(index)
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
	end

	if shield_generators_hash[index] then -- shield generator destroyed
		local data = shield_generators[shield_generators_hash[index]]

		-- unbind shield generator from all of it's units
		for i, tracked_data in ipairs(data.tracked) do
			-- unbind shield generator from this unit
			if tracked_data.unit.valid then
				shield_generators_bound[tracked_data.unit.unit_number] = nil
			end

			rendering.destroy(tracked_data.shield_bar_bg)
			rendering.destroy(tracked_data.shield_bar)
		end

		-- destroy tracked data in sequential table
		for i, _data in ipairs(shield_generators) do
			if _data == index then
				table.remove(shield_generators, i)
				break
			end
		end

		rendering.destroy(data.battery_bar_bg)
		rendering.destroy(data.battery_bar)

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

		-- debug('Removing entity ' .. index .. ' from tracked!')

		if shield_generator then
			-- we got our shield generator data
			-- let's remove us from tracked entities

			-- debug('Removing entity ' .. index .. ' from tracked of ' .. shield_generator.id .. '!')

			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			rendering.destroy(tracked_data.shield_bar_bg)
			rendering.destroy(tracked_data.shield_bar)

			local oindex = shield_generator.tracked_hash[index]
			table.remove(shield_generator.tracked, shield_generator.tracked_hash[index])

			if shield_generator.tracked_dirty then
				for i, _index in ipairs(shield_generator.tracked_dirty) do
					if _index == oindex then
						table.remove(shield_generator.tracked_dirty, i)
						break
					end
				end
			end

			shield_generator.tracked_hash[index] = nil

			-- force dirty list to be rebuilt
			mark_shield_dirty(shield_generator)

			-- update hash table to reflect change to indexes
			for unit_number, index in pairs(shield_generator.tracked_hash) do
				if index >= oindex then
					shield_generator.tracked_hash[unit_number] = index - 1
				end
			end

			if shield_generator.tracked_dirty then
				for i, _index in ipairs(shield_generator.tracked_dirty) do
					if _index > oindex then
						shield_generator.tracked_dirty[i] = _index - 1
					end
				end
			end
		end

		shield_generators_bound[index] = nil
	end
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	if not destroy_remap[event.registration_number] then return end
	on_destroyed(destroy_remap[event.registration_number])
	destroy_remap[event.registration_number] = nil
end)
