
-- derative
local shield_generators_hash = shield_generators_hash
local shield_generators_dirty = shield_generators_dirty

-- storage
local shield_generators_bound
local shield_generators
local shields

-- cache
local speed_cache
local SEARCH_RANGE
_G.RANGE_DEF = {}
local RANGE_DEF = RANGE_DEF

-- imports
local math_min = math.min
local math_max = math.max

local disttosqr = util.disttosqr
local distance = util.distance

local CONSUMPTION_PER_HITPOINT = CONSUMPTION_PER_HITPOINT
local values = CONSTANTS

local VISUAL_DAMAGE_BAR_SHRINK_SPEED = values.VISUAL_DAMAGE_BAR_SHRINK_SPEED
local VISUAL_DAMAGE_BAR_WAIT_TICKS = values.VISUAL_DAMAGE_BAR_WAIT_TICKS
local VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX = values.VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX
local set_right_bottom = set_right_bottom
local lerp = util.lerp

on_init_globals(function()
	storage.shield_generators_bound = {}
	storage.shield_generators = {}
end)

on_setup_globals(function()
	shield_generators_bound = assert(storage.shield_generators_bound)
	shield_generators = assert(storage.shield_generators)
	shields = assert(storage.shields)

	-- build dirty list from savegame
	for i = 1, #shield_generators do
		local data = shield_generators[i]

		if data.tracked_dirty then
			table.insert(shield_generators_dirty, data)
		end

		shield_generators_hash[data.id] = data
	end

	reload_shield_provider_config_values()
end)

function rebuild_shield_provider_speed_cache()
	if not game then return end

	speed_cache = {}

	local provider = settings.global['shield-generators-hitpoints-base-rate-provider'].value / 60

	for forcename, force in pairs(game.forces) do
		speed_cache[forcename] = util.recovery_speed_modifier(force.technologies) * provider
	end
end

function reload_shield_provider_config_values()
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

	if storage['shield-generators-provider-capacity'] ~= settings.global['shield-generators-provider-capacity'].value and game then
		local value = settings.global['shield-generators-provider-capacity'].value
		storage['shield-generators-provider-capacity'] = value

		for i = 1, #shield_generators do
			if shield_generators[i].unit.valid and shield_generators[i].unit.prototype.electric_energy_source_prototype then
				shield_generators[i].unit.electric_buffer_size = shield_generators[i].unit.prototype.electric_energy_source_prototype.buffer_capacity * value
				shield_generators[i].max_energy = shield_generators[i].unit.electric_buffer_size
			end
		end
	end

	rebuild_shield_provider_speed_cache()
end

script_hook({
	defines.events.on_force_created,
	defines.events.on_forces_merged,
	defines.events.on_force_reset,
	defines.events.on_force_friends_changed,
}, rebuild_shield_provider_speed_cache)

script_hook(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.setting == 'shield-generators-multiplier' then
		refresh_provider_shields_max_health(nil, event.tick)
	end

	reload_shield_provider_config_values()
end)

function refresh_provider_shields_max_health(force, tick)
	-- this way because i plan expanding it (adding more HP techs)
	if force ~= nil then
		local mult = util.max_capacity_modifier(force.technologies)

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, tick)
			elseif data.unit.force == force then
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.max_health * mult
					data.tracked[i2].shield_health = math_min(data.tracked[i2].max_health, data.tracked[i2].shield_health)
				end

				mark_shield_provider_dirty(data, tick)
			end
		end
	else
		local mults = {}

		for name, force in pairs(game.forces) do
			mults[name] = util.max_capacity_modifier(force.technologies)
		end

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, tick)
			else
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.max_health * mults[data.unit.force.name]
					data.tracked[i2].shield_health = math_min(data.tracked[i2].max_health, data.tracked[i2].shield_health)
				end

				mark_shield_provider_dirty(data, tick)
			end
		end
	end
end

function start_ticking_shield_generator(shield_generator, tick)
	show_shield_provider_bars(shield_generator)

	for i, _index in ipairs(shield_generator.tracked_dirty) do
		show_delegated_shield_bars(shield_generator.tracked[_index])
	end

	local hit = false

	for i, data in ipairs(shield_generators_dirty) do
		if data == shield_generator then
			hit = true
			break
		end
	end

	if not hit then
		table.insert(shield_generators_dirty, shield_generator)
	end
end

-- adding new entity to shield provider, just that.
function mark_shield_provider_child_dirty(shield_generator, tick, unit_number, force)
	if not shield_generator.unit.valid then
		-- shield somehow became invalid
		-- ???

		report_error('Provider ' .. shield_generator.id .. ' turned out to be invalid, this should never happen')
		on_destroyed(shield_generator.id, false, tick)
		return
	end

	local ticking = not shield_generator.tracked_dirty

	if ticking then
		shield_generator.tracked_dirty = {}
		start_ticking_shield_generator(shield_generator, tick)
	end

	--[[for i = 1, #shield_generator.tracked do
		if shield_generator.tracked[i].unit_number == unit_number then
			table.insert(shield_generator.tracked_dirty, i)
			break
		end
	end]]

	local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[unit_number]]

	if tracked_data then
		if ticking or force or not tracked_data.dirty then
			tracked_data.dirty = true
			table.insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
			show_delegated_shield_bars(tracked_data)
		end
	else
		report_error('Trying to mark_shield_provider_child_dirty on ' .. unit_number .. ' which is not present in shield_generator.tracked_hash! This is a bug!')
	end
end

local bind_shield

function mark_shield_provider_dirty(shield_generator, tick)
	::MARK::

	if not shield_generator.unit.valid then
		-- shield somehow became invalid
		-- ???

		report_error('Provider ' .. shield_generator.id .. ' turned out to be invalid, this should never happen')
		on_destroyed(shield_generator.id, nil, tick) -- TODO: from_dirty = true?
		return
	end

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
				on_destroyed(tracked_data.unit_number, true, tick)
				size = size - 1
				had_to_remove = true
			elseif tracked_data.shield_health < tracked_data.max_health then
				if not shield_generator.tracked_dirty then
					shield_generator.tracked_dirty = {}
				end

				table.insert(shield_generator.tracked_dirty, i)

				if not tracked_data.dirty then
					tracked_data.dirty = true
					hide_delegated_shield_bars(tracked_data)
				end

				i = i + 1
			elseif tracked_data.dirty then
				hide_delegated_shield_bars(tracked_data)

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
			if not values.blacklist[ent.name] then
				bind_shield(ent, shield_generator, tick)
			end
		end

		goto MARK
	end

	-- if we are dirty, let's tick
	if shield_generator.tracked_dirty then
		start_ticking_shield_generator(shield_generator, tick)
	else
		hide_shield_provider_bars(shield_generator)

		for i, data in ipairs(shield_generators_dirty) do
			if data == shield_generator then
				table.remove(shield_generators_dirty, i)
				break
			end
		end
	end
end

script_hook(defines.events.on_research_finished, function(event)
	if event.research.name == 'shield-generators-superconducting-shields' then
		refresh_provider_shields_max_health(event.research.force, event.tick)
	end
end)

script_hook(defines.events.on_research_reversed, function(event)
	if event.research.name == 'shield-generators-superconducting-shields' then
		refresh_provider_shields_max_health(event.research.force, event.tick)
	end
end)

function bind_shield(entity, shield_provider, tick)
	if not entity.destructible then return false end
	local unit_number = entity.unit_number

	if shield_generators_bound[unit_number] then return false end
	if shield_provider.tracked_hash[unit_number] then return false end
	local max_health = entity.max_health

	if not max_health or max_health <= 0 then return false end

	local width, height = util.determineDimensions(entity)

	if shields[unit_number] then
		height = height + values.BAR_HEIGHT * 2
	end

	-- create tracked data for shield state
	local tracked_data = {
		health = entity.health,
		max_health = entity.max_health * util.max_capacity_modifier(shield_provider.unit.force.technologies),
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		shield_health_last = 0,
		shield_health_last_t = 0,
		-- upper bound by max_health
		unit_number = entity.unit_number,
		dirty = true,

		width = width,
		height = height,

		last_damage = assert(tick, 'bind_shield called without tick'),
		last_damage_bar = tick,
	}

	show_delegated_shield_bars(tracked_data)

	-- tell globally that this entity has it's shield provider
	-- which we can later lookup in shield_generators_hash[shield_provider.id]
	shield_generators_bound[unit_number] = shield_provider.id

	-- register
	-- set tracked_hash index value to index in shield_provider.tracked
	shield_provider.tracked_hash[unit_number] = util.insert(shield_provider.tracked, tracked_data)

	track_entity_destruction(entity)

	return true
end

function rebind_shield(tracked_data, shield_provider)
	local unit_number = tracked_data.unit.unit_number

	-- just remap data from one to another
	shield_generators_bound[unit_number] = shield_provider.id
	shield_provider.tracked_hash[unit_number] = util.insert(shield_provider.tracked, tracked_data)

	return true
end

local function initialize_shield_provider(entity, tick)
	if shield_generators_hash[entity.unit_number] then return end -- wut
	track_entity_destruction(entity)

	local width, height = util.determineDimensions(entity)
	height = height + values.BAR_HEIGHT

	entity.electric_buffer_size = entity.electric_buffer_size * settings.global['shield-generators-provider-capacity'].value

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

		last_damage = tick or 0,

		-- to be set to dynamic value later
		max_energy = entity.electric_buffer_size,
	}

	show_shield_provider_bars(data)

	table.insert(shield_generators, data)
	shield_generators_hash[entity.unit_number] = data

	-- find buildings around already placed
	local found = entity.surface.find_entities_filtered({
		position = entity.position,
		radius = RANGE_DEF[entity.name],
		force = entity.force,
		type = values._allowed_types,
	})

	for i, ent in ipairs(found) do
		if not values.blacklist[ent.name] then
			bind_shield(ent, data, tick)
		end
	end

	bind_shield(entity, data, tick)
	mark_shield_provider_dirty(data, tick)

	return data
end

local function find_shield_provider(force, position, surface)
	local found = {}

	if #shield_generators < 400 then
		local sindex = surface.index

		for i = 1, #shield_generators do
			local generator = shield_generators[i]

			if generator.unit.valid and generator.surface == sindex and disttosqr(generator.pos, position) <= generator.range then
				table.insert(found, generator)
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
					table.insert(found, provider_data)
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

local function create_delegated_shield(entity, tick)
	if values.blacklist[entity.name] then return end

	local provider_data = find_shield_provider(entity.force, entity.position, entity.surface)
	if not provider_data then return end

	if bind_shield(entity, provider_data, tick) then
		-- mark_shield_provider_dirty(provider_data, tick)
		mark_shield_provider_child_dirty(provider_data, tick, entity.unit_number, true)
	end
end

on_built_entity(function(event)
	local created_entity, tick = event.entity, event.tick

	if RANGE_DEF[created_entity.name] then
		initialize_shield_provider(created_entity, tick)
	elseif values.allowed_types[created_entity.type] then
		-- create provider shield second
		create_delegated_shield(created_entity, tick)
	end
end)

script_hook(defines.events.on_entity_cloned, function(event)
	local source = event.source
	local destination = event.destination

	if RANGE_DEF[destination.name] and shield_generators_hash[source.unit_number] then
		local old_data = shield_generators_hash[source.unit_number]
		local new_data = initialize_shield_provider(destination, event.tick)

		new_data.shield_energy = old_data.shield_energy
		new_data.max_energy = old_data.max_energy

		new_data.disabled = old_data.disabled

		if old_data.disabled then
			destination.electric_buffer_size = 0
			destination.energy = 0
		end
	elseif RANGE_DEF[destination.name] then
		initialize_shield_provider(destination, event.tick)
	end
end)

function tick_shield_providers(tick, delay, max_time, max_speed)
	local check = false

	if not speed_cache then
		rebuild_shield_provider_speed_cache()
	end

	-- iterate dirty shield providers
	for i = 1, #shield_generators_dirty do
		local data = shield_generators_dirty[i]

		if data.unit.valid then
			local energy = data.disabled and data.shield_energy or data.unit.energy

			if energy > 0 then
				-- whenever there was any dirty shields
				local run_dirty = false

				local count = #data.tracked_dirty
				local health_per_tick = speed_cache[data.unit.force.name]
				local mult = 1

				-- first 1.5 seconds - base recharge rate
				-- then linearly increase to triple speed
				-- in next 3 seconds
				if data.last_damage and tick - data.last_damage > delay then
					mult = lerp((tick - data.last_damage - delay) / max_time, 1, max_speed)
				end

				if count * health_per_tick * mult * CONSUMPTION_PER_HITPOINT > energy then
					health_per_tick = energy / (CONSUMPTION_PER_HITPOINT * count * mult)
				else
					health_per_tick = health_per_tick * mult
				end

				-- iterate dirty shields inside shield provider
				for i2 = count, 1, -1 do
					local tracked_data = data.tracked[data.tracked_dirty[i2]]

					if tracked_data.unit.valid then
						if tracked_data.shield_health < tracked_data.max_health then
							run_dirty = true

							if tracked_data.health ~= tracked_data.max_health then
								-- update hacky health counter if required
								tracked_data.health = tracked_data.unit.health
							end

							local delta = math_min(energy / CONSUMPTION_PER_HITPOINT, health_per_tick, tracked_data.max_health - tracked_data.shield_health)
							tracked_data.shield_health = tracked_data.shield_health + delta
							energy = energy - delta * CONSUMPTION_PER_HITPOINT

							if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
								tracked_data.shield_health_last_t = tracked_data.shield_health
								tracked_data.last_damage_bar = tick
							end

							tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

							set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health, tracked_data.height)
							set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)

							if energy <= 0 then break end
						elseif tracked_data.shield_health_last > tracked_data.shield_health then

							if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
								tracked_data.shield_health_last_t = tracked_data.shield_health
								tracked_data.last_damage_bar = tick
							end

							tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

							set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health, tracked_data.height)
							set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)
						else
							hide_delegated_shield_bars(tracked_data)

							table.remove(data.tracked_dirty, i2)
							tracked_data.dirty = false
						end
					else
						report_error('Encountered invalid unit with tracked index ' .. data.tracked_dirty[i2] .. ' in shield generator ' .. data.id)
						check = true
					end
				end

				-- not a single dirty entity - consider this shield provider is clean
				-- also check whenever should we draw battery charge bar
				-- if we do have to, then don't mark as clean yet
				if not run_dirty and energy + 1 >= data.max_energy then
					data.tracked_dirty = nil
					check = true
				end

				set_right_bottom(data.battery_bar, data.unit, -data.width + 2 * data.width * energy / data.max_energy, data.height)
			elseif data.disabled then
				check = true
			end

			if data.disabled then
				data.shield_energy = energy
			else
				data.unit.energy = energy
			end
		else
			-- report_error('Encountered invalid shield provider with index ' .. data.id)
			check = true
		end
	end

	-- if we encountered clean or invalid shield providers,
	-- remove them from ticking
	if check then
		for i = #shield_generators_dirty, 1, -1 do
			local data = shield_generators_dirty[i]

			if not data.unit.valid or data.disabled and data.shield_energy <= 0 then
				table.remove(shield_generators_dirty, i)
			elseif not data.tracked_dirty then
				table.remove(shield_generators_dirty, i)

				hide_shield_provider_bars(data)

				local tracked = data.tracked

				--for i, tracked_data in ipairs(data.tracked) do
				for i = 1, #tracked do
					local tracked_data = tracked[i]

					if tracked_data.unit.valid then
						hide_delegated_shield_bars(tracked_data)
					else
						mark_shield_provider_dirty(data, tick)
						break
					end
				end
			end
		end
	end
end

listen_on_destroyed(function(index, from_dirty, tick)
	if shield_generators_hash[index] then -- shield generator destroyed
		local data = shield_generators_hash[index]
		local rebound_uids = {}

		-- unbind shield generator from all of it's units
		for i, tracked_data in ipairs(data.tracked) do
			local rebound = false

			if tracked_data.unit.valid then
				-- try to rebind to other shield provider
				local provider_data = find_shield_provider(tracked_data.unit.force, tracked_data.unit.position, tracked_data.unit.surface)

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

				hide_delegated_shield_bars(tracked_data)
			end
		end

		for uid, data in pairs(rebound_uids) do
			mark_shield_provider_dirty(data, tick)
		end

		-- destroy tracked data in sequential table
		for i, _data in ipairs(shield_generators) do
			if _data == data then
				table.remove(shield_generators, i)
				break
			end
		end

		hide_shield_provider_bars(data)

		shield_generators_hash[index] = nil
	elseif shield_generators_bound[index] then -- entity under shield generator protection destroyed
		local shield_generator = shield_generators_hash[shield_generators_bound[index]]

		if shield_generator then
			-- we got our shield generator data
			-- let's remove us from tracked entities
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			hide_delegated_shield_bars(tracked_data)

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
				mark_shield_provider_dirty(shield_generator, tick)
			end
		end

		shield_generators_bound[index] = nil
	end
end)
