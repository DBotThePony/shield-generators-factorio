
local shields, shields_dirty, shield_generators, shield_generators_dirty, shield_generators_hash, shield_generators_bound, destroy_remap
local on_destroyed, bind_shield

local values = require('__shield-generators__/values')

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = settings.startup['shield-generators-joules-per-point'].value
local HITPOINTS_PER_TICK = 1
local BAR_HEIGHT = values.BAR_HEIGHT

-- wwwwwwwwwtf??? with Lua of Wube
-- why it doesn't return inserted index
local function table_insert(tab, value)
	local insert = #tab + 1
	tab[insert] = value
	return insert
end

local RANGE_DEF = {}
local SEARCH_RANGE

local function reload_values()
	RANGE_DEF['shield-generators-generator'] = settings.global['shield-generators-provider-range-basic'].value
	RANGE_DEF['shield-generators-generator-advanced'] = settings.global['shield-generators-provider-range-advanced'].value
	RANGE_DEF['shield-generators-generator-elite'] = settings.global['shield-generators-provider-range-elite'].value
	RANGE_DEF['shield-generators-generator-ultimate'] = settings.global['shield-generators-provider-range-ultimate'].value

	SEARCH_RANGE = math.max(
		RANGE_DEF['shield-generators-generator'],
		RANGE_DEF['shield-generators-generator-advanced'],
		RANGE_DEF['shield-generators-generator-elite'],
		RANGE_DEF['shield-generators-generator-ultimate']
	)
end

script.on_init(function()
	global.shields = {}
	global.destroy_remap = {}
	global.shield_generators_bound = {}
	global.shield_generators = {}

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	shield_generators_hash = {}

	shield_generators_dirty = {}
	shields_dirty = {}

	reload_values()
end)

script.on_configuration_changed(reload_values)

script.on_load(function()
	global.shields = global.shields or {}
	global.destroy_remap = global.destroy_remap or {}
	global.shield_generators_bound = global.shield_generators_bound or {}
	global.shield_generators = global.shield_generators or {}

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators

	shield_generators_dirty = {}
	shields_dirty = {}
	shield_generators_hash = {}

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

	for i, data in ipairs(shield_generators) do
		shield_generators_hash[data.id] = data
	end

	reload_values()
end)

local function debug(str)
	game.print('[Shield Generators] ' .. str)
	log(str)
end

local function mark_shield_dirty(shield_generator)
	::MARK::
	shield_generator.tracked_dirty = shield_generator.unit.energy < shield_generator.max_energy and {} or nil

	local had_to_remove = false

	do
		local i = 1
		local size = #shield_generator.tracked

		while i <= size do
			local tracked_data = shield_generator.tracked[i]

			if not tracked_data.unit.valid then
				-- that's a fuck you from factorio engine or design oversight
				-- when quickly placing belts with drag + rotate, corners get
				-- replaced with removal and on_entity_destroyed is fired too late

				-- this also might happen on mod addition/removal
				-- if mod changed prototype (e.g. furnace -> assembling-machine)
				on_destroyed(tracked_data.unit_number, true)
				size = size - 1
				had_to_remove = true
			elseif tracked_data.shield_health < tracked_data.max_health then
				if not shield_generator.tracked_dirty then
					shield_generator.tracked_dirty = {}
				end

				tracked_data.dirty = true
				table_insert(shield_generator.tracked_dirty, i)

				if rendering.is_valid(tracked_data.shield_bar) then
					rendering.set_visible(tracked_data.shield_bar, true)
					rendering.set_visible(tracked_data.shield_bar_bg, true)
				end

				i = i + 1
			else
				i = i + 1
			end
		end
	end

	if had_to_remove then
		-- HACK - scan for entities around shield
		-- they might got replaced by game engine
		-- but why it doesn't have ANY event fired for such case?
		local found = shield_generator.unit.surface.find_entities_filtered({
			position = shield_generator.unit.position,
			radius = RANGE_DEF[shield_generator.unit.name],
			force = shield_generator.unit.force,
			type = values._allowed_types,
		})

		for i, ent in ipairs(found) do
			bind_shield(ent, shield_generator)
		end

		goto MARK
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

local _position = {}

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
								_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
								_position[2] = tracked_data.height
								rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)
							end

							if energy <= 0 then break end
						else
							rendering.set_visible(tracked_data.shield_bar, false)
							rendering.set_visible(tracked_data.shield_bar_bg, false)

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
				if not run_dirty and energy + 1 >= data.max_energy then
					data.tracked_dirty = nil
					check = true
				end

				_position[1] = -data.width + 2 * data.width * energy / data.max_energy
				_position[2] = data.height
				rendering.set_right_bottom(data.battery_bar, data.unit, _position)
			end

			data.unit.energy = energy
		else
			-- debug('Encountered invalid shield provider with index ' .. data.id)
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

				for i, tracked_data in ipairs(data.tracked) do
					rendering.set_visible(tracked_data.shield_bar, false)
					rendering.set_visible(tracked_data.shield_bar_bg, false)
				end
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

				_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
				_position[2] = tracked_data.height

				rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)

				_position[1] = -tracked_data.width + 2 * tracked_data.width * energy / 8000000
				_position[2] = tracked_data.height + BAR_HEIGHT

				rendering.set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, _position)
			end
		elseif energy > 0 and energy < 8000000 then
			_position[1] = -tracked_data.width + 2 * tracked_data.width * energy / 8000000
			_position[2] = tracked_data.height + BAR_HEIGHT

			rendering.set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, _position)
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
		local shield_generator = shield_generators_hash[shield_generators_bound[unit_number]]

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
					rendering.set_visible(tracked_data.shield_bar, true)
					rendering.set_visible(tracked_data.shield_bar_bg, true)
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

function bind_shield(entity, shield_provider)
	if not entity.destructible then return false end
	local unit_number = entity.unit_number

	if shield_generators_bound[unit_number] then return false end
	if shield_provider.tracked_hash[unit_number] then return false end
	local max_health = entity.prototype.max_health

	if not max_health or max_health <= 0 then return false end

	local width, height = determineDimensions(entity)

	if shields[unit_number] then
		height = height + BAR_HEIGHT * 2
	end

	-- create tracked data for shield state
	local tracked_data = {
		health = entity.health,
		max_health = entity.prototype.max_health,
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		-- upper bound by max_health
		unit_number = entity.unit_number,
		dirty = true,

		width = width,
		height = height,

		shield_bar_bg = rendering.draw_rectangle({
			color = values.BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height},
		}),

		shield_bar = rendering.draw_rectangle({
			color = values.SHIELD_COLOR,
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
	shield_generators_bound[unit_number] = shield_provider.id

	-- register
	-- set tracked_hash index value to index in shield_provider.tracked
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	destroy_remap[script.register_on_entity_destroyed(entity)] = unit_number

	-- debug('Bound entity ' .. unit_number .. ' to shield generator ' .. shield_provider.id .. ' with max health of ' .. tracked_data.max_health)

	return true
end

local function rebind_shield(tracked_data, shield_provider)
	local unit_number = tracked_data.unit.unit_number

	-- just remap data from one to another
	shield_generators_bound[unit_number] = shield_provider.id
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	return true
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

		surface = entity.surface.index,
		pos = entity.position,
		range = RANGE_DEF[entity.name] * RANGE_DEF[entity.name],

		battery_bar_bg = rendering.draw_rectangle({
			color = values.BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height},
		}),

		battery_bar = rendering.draw_rectangle({
			color = values.SHIELD_BUFF_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {-width, height},
		}),

		provider_radius = rendering.draw_circle({
			color = values.SHIELD_RADIUS_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			target = entity,
			radius = RANGE_DEF[entity.name],
			draw_on_ground = true,
			only_in_alt_mode = true,
		}),

		-- to be set to dynamic value later
		max_energy = entity.electric_buffer_size,
	}

	table_insert(shield_generators, data)
	shield_generators_hash[entity.unit_number] = data
	-- debug('Shield placed with index ' .. entity.unit_number .. ' and index ' .. shield_generators_hash[entity.unit_number])

	-- find buildings around already placed
	local found = entity.surface.find_entities_filtered({
		position = entity.position,
		radius = RANGE_DEF[entity.name],
		force = entity.force,
		type = values._allowed_types,
	})

	for i, ent in ipairs(found) do
		bind_shield(ent, data)
	end

	bind_shield(entity, data)
	mark_shield_dirty(data)
end

local function distance(a, b)
	return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
end

local function disttosqr(a, b)
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
end

local function find_closest_provider(force, position, surface)
	local found = {}

	if #shield_generators < 400 then
		local sindex = surface.index

		for i, generator in ipairs(shield_generators) do
			if generator.unit.valid and generator.surface == sindex and disttosqr(generator.pos, position) <= generator.range then
				table_insert(found, generator)
			end
		end
	else
		local _found = surface.find_entities_filtered({
			position = position,
			radius = SEARCH_RANGE,
			force = force,
			name = values.GENERATORS
		})

		for i, generator in ipairs(_found) do
			if distance(generator.position, position) <= RANGE_DEF[generator.name] then
				local provider_data = shield_generators_hash[generator.unit_number]

				if provider_data then
					table_insert(found, provider_data)
				end
			end
		end
	end

	local provider_data = found[1]
	if not provider_data then return end

	for i = 2, #found do
		local _provider_data = found[i]

		-- determine least loaded, or closest if load is equal
		if #_provider_data.tracked < #provider_data.tracked or #_provider_data.tracked == #provider_data.tracked and disttosqr(_provider_data.pos, position) < disttosqr(provider_data.pos, position) then
			provider_data = _provider_data
		end
	end

	return provider_data
end

local function on_built_shieldable_entity(entity)
	local provider_data = find_closest_provider(entity.force, entity.position, entity.surface)
	if not provider_data then return end

	if bind_shield(entity, provider_data) then
		mark_shield_dirty(provider_data)
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
			color = values.BACKGROUND_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {width, height + BAR_HEIGHT},
		}),

		shield_bar = rendering.draw_rectangle({
			color = values.SHIELD_COLOR,
			forces = {entity.force},
			filled = true,
			surface = entity.surface,
			left_top = entity,
			left_top_offset = {-width, height - BAR_HEIGHT},
			right_bottom = entity,
			right_bottom_offset = {-width, height},
		}),

		shield_bar_buffer = rendering.draw_rectangle({
			color = values.SHIELD_BUFF_COLOR,
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
		local shield_generator = shield_generators_hash[shield_generators_bound[index]]

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
	if RANGE_DEF[created_entity.name] then
		on_built_shield_provider(created_entity)
	else
		if values.allowed_types_self[created_entity.type] and (not created_entity.force or created_entity.force.technologies['shield-generators-turret-shields-basics'].researched) then
			-- create turret shield first
			on_built_shieldable_self(created_entity)
		end

		if values.allowed_types[created_entity.type] then
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
				type = values._allowed_types_self,
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
				type = values._allowed_types_self,
			})

			for i, ent in ipairs(found) do
				on_destroyed(ent.unit_number)
			end
		end
	end
end)

function on_destroyed(index, from_dirty)
	-- entity with internal shield destroyed
	if shields[index] then
		local tracked_data = shields[index]

		tracked_data.shield.destroy()
		rendering.destroy(tracked_data.shield_bar_bg)
		rendering.destroy(tracked_data.shield_bar)

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
		local data = shield_generators_hash[index]
		local rebound_uids = {}

		-- unbind shield generator from all of it's units
		for i, tracked_data in ipairs(data.tracked) do
			local rebound = false

			if tracked_data.unit.valid then
				-- try to rebind to other shield provider
				local provider_data = find_closest_provider(tracked_data.unit.force, tracked_data.unit.position, tracked_data.unit.surface)

				if provider_data then
					rebound = true

					if rebind_shield(tracked_data, provider_data) then
						rebound_uids[provider_data.id] = provider_data
					end
				end
			end

			if not rebound then
				-- unbind shield generator from this unit
				if tracked_data.unit_number then
					shield_generators_bound[tracked_data.unit_number] = nil
				end

				rendering.destroy(tracked_data.shield_bar_bg)
				rendering.destroy(tracked_data.shield_bar)
			end
		end

		for uid, data in pairs(rebound_uids) do
			mark_shield_dirty(data)
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

		shield_generators_hash[index] = nil
	elseif shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators_hash[shield_generators_bound[index]]

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

			if not from_dirty then
				-- force dirty list to be rebuilt
				mark_shield_dirty(shield_generator)
			end
		end

		shield_generators_bound[index] = nil
	end
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	if not destroy_remap[event.registration_number] then return end
	-- debug('DESTROY ' .. destroy_remap[event.registration_number])
	on_destroyed(destroy_remap[event.registration_number])
	destroy_remap[event.registration_number] = nil
end)

script.on_event(defines.events.on_entity_cloned, function(event)
	debug('on clone')
end)
