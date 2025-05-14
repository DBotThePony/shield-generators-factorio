
-- derative
local shield_generators_bound = shield_generators_bound
local shield_generators_dirty = shield_generators_dirty

-- storage
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
local table_insert = table.insert

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
	storage.shield_generators = {}
end)

on_setup_globals(function()
	shield_generators = assert(storage.shield_generators)
	shields = assert(storage.shields)

	for unumber, data in pairs(shield_generators) do
		if data.ticking then
			shield_generators_dirty[unumber] = data
		end

		for _, child in pairs(data.tracked) do
			shield_generators_bound[child.unit_number] = data
		end
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
	RANGE_DEF['shield-generators-generator'] = settings.startup['shield-generators-provider-range-basic'].value
	RANGE_DEF['shield-generators-generator-advanced'] = settings.startup['shield-generators-provider-range-advanced'].value
	RANGE_DEF['shield-generators-generator-elite'] = settings.startup['shield-generators-provider-range-elite'].value
	RANGE_DEF['shield-generators-generator-ultimate'] = settings.startup['shield-generators-provider-range-ultimate'].value

	SEARCH_RANGE = math.max(
		RANGE_DEF['shield-generators-generator'],
		RANGE_DEF['shield-generators-generator-advanced'],
		RANGE_DEF['shield-generators-generator-elite'],
		RANGE_DEF['shield-generators-generator-ultimate']
	)

	if storage['shield-generators-provider-capacity'] ~= settings.global['shield-generators-provider-capacity'].value and game then
		local value = settings.global['shield-generators-provider-capacity'].value
		storage['shield-generators-provider-capacity'] = value

		for _, data in pairs(shield_generators) do
			if data.unit.valid and data.unit.prototype.electric_energy_source_prototype then
				data.unit.electric_buffer_size = data.unit.prototype.electric_energy_source_prototype.buffer_capacity * value
				data.max_energy = data.unit.electric_buffer_size
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
	local toRemove = {}

	-- this way because i plan expanding it (adding more HP techs)
	if force ~= nil then
		local mult = util.max_capacity_modifier(force.technologies)

		for unumber, data in pairs(shield_generators) do
			if not data.unit.valid then
				table_insert(toRemove, unumber)
			elseif data.unit.force == force then
				for _, child in pairs(data.tracked) do
					child.max_health = child.unit.max_health * mult
					child.shield_health = math_min(child.max_health, child.shield_health)
				end

				rebuild_shield_provider_dirty_lists(data, tick)
			end
		end
	else
		local mults = {}

		for name, force in pairs(game.forces) do
			mults[name] = util.max_capacity_modifier(force.technologies)
		end

		for unumber, data in pairs(shield_generators) do
			if not data.unit.valid then
				table_insert(toRemove, unumber)
			else
				for _, child in pairs(data.tracked) do
					child.max_health = child.unit.max_health * mults[data.unit.force.name]
					child.shield_health = math_min(child.max_health, child.shield_health)
				end

				rebuild_shield_provider_dirty_lists(data, tick)
			end
		end
	end

	for _, id in ipairs(toRemove) do
		on_destroyed(id, tick)
	end
end

local function should_tick_child(child)
	return child.shield_health < child.max_health
end

local function should_tick_child_visuals(child)
	return child.shield_health_last ~= child.shield_health
end

function begin_ticking_shield_generator(shield_generator)
	if shield_generator.ticking then return end
	shield_generator.ticking = true
	show_shield_provider_bars(shield_generator)

	for _, child in pairs(shield_generator.tracked_dirty) do
		show_delegated_shield_bars(child)
	end

	shield_generators_dirty[shield_generator.unit_number] = shield_generator
end

-- adding new entity to shield provider, just that.
function mark_shield_provider_child_dirty(shield_generator, tick, unit_number, force)
	local not_ticking = not shield_generator.ticking

	if not_ticking then
		begin_ticking_shield_generator(shield_generator, tick)
	end

	local child = shield_generator.tracked[unit_number]

	if child then
		if shield_generator.visual_dirty_cache then
			shield_generator.visual_dirty_cache[unit_number] = child
		end

		if not_ticking or force or not child.ticking then
			child.ticking = true
			shield_generator.tracked_dirty[unit_number] = child
			shield_generator.tracked_dirty_num = shield_generator.tracked_dirty_num + 1
			show_delegated_shield_bars(child)
		end
	else
		report_error('Trying to mark_shield_provider_child_dirty on ' .. unit_number .. ' which is not present in shield_generator.tracked! This is a bug!')
	end
end

local bind_shield

-- checks all children and updates dirty list and ticking status
function rebuild_shield_provider_dirty_lists(shield_generator, tick)
	::MARK::

	if not shield_generator.unit.valid then
		-- shield somehow became invalid
		-- ???

		report_error('Provider ' .. shield_generator.unit_number .. ' turned out to be invalid, this should never happen')
		on_destroyed(shield_generator.unit_number, tick)
		return
	end

	local ticking = shield_generator.unit.energy < shield_generator.max_energy
	local toRemove = {}

	do
		for unumber, tracked_data in pairs(shield_generator.tracked) do
			if not tracked_data.unit.valid then
				-- that's a fuck you from factorio engine or design oversight
				-- when quickly placing belts with drag + rotate, corners get
				-- replaced with removal and on_entity_destroyed is fired too late

				-- this also might happen on mod addition/removal
				-- if mod changed prototype (e.g. furnace -> assembling-machine)
				table.insert(toRemove, unumber)
				goto CONTINUE
			elseif should_tick_child(tracked_data) then
				if not tracked_data.ticking then
					tracked_data.ticking = true
					shield_generator.tracked_dirty[unumber] = tracked_data
					shield_generator.tracked_dirty_num = shield_generator.tracked_dirty_num + 1
					ticking = true
					show_delegated_shield_bars(tracked_data)
				end
			elseif tracked_data.ticking then
				hide_delegated_shield_bars(tracked_data)
				shield_generator.tracked_dirty[unumber] = nil
				shield_generator.tracked_dirty_num = shield_generator.tracked_dirty_num - 1
				tracked_data.ticking = false
			end

			if tracked_data.ticking and shield_generator.visual_dirty_cache then
				-- shield generator is starving for power, so it only updates visuals
				shield_generator.visual_dirty_cache[unumber] = tracked_data
				ticking = true
			end

			::CONTINUE::
		end
	end

	if toRemove[1] ~= nil then
		for _, unumber in ipairs(toRemove) do
			on_destroyed(unumber, tick)
		end

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
	if ticking then
		begin_ticking_shield_generator(shield_generator, tick)
	else
		shield_generator.ticking = false
		hide_shield_provider_bars(shield_generator)
		shield_generators_dirty[shield_generator.unit_number] = nil
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
	if shield_provider.tracked[unit_number] then return false end
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
		ticking = false,

		width = width,
		height = height,

		last_damage = assert(tick, 'bind_shield called without tick'),
		last_damage_bar = tick,
	}

	show_delegated_shield_bars(tracked_data)

	-- tell globally that this entity has it's shield provider
	-- which we can later lookup in shield_generators[shield_provider.unit_number]
	shield_generators_bound[unit_number] = shield_provider

	-- register
	-- set tracked index value to index in shield_provider.tracked
	shield_provider.tracked[unit_number] = tracked_data

	track_entity_destruction(entity)

	return true, tracked_data
end

local function initialize_shield_provider(entity, tick, old_data)
	if shield_generators[entity.unit_number] then return end -- wut
	track_entity_destruction(entity)

	local width, height = util.determineDimensions(entity)
	height = height + values.BAR_HEIGHT

	entity.electric_buffer_size = entity.electric_buffer_size * settings.global['shield-generators-provider-capacity'].value

	local data = {
		unit = entity,
		unit_number = entity.unit_number,
		tracked = {},
		tracked_dirty = {},
		tracked_dirty_num = 0,
		ticking = false,

		width = width,
		height = height,

		surface = entity.surface.index,
		pos = entity.position,
		range = RANGE_DEF[entity.name] * RANGE_DEF[entity.name],

		last_damage = old_data and old_data.last_damage or tick or 0,

		-- to be set to dynamic value later
		max_energy = entity.electric_buffer_size,
	}

	show_shield_provider_bars(data)

	shield_generators[entity.unit_number] = data

	if old_data == nil then
		bind_shield(entity, data, tick)
	else
		local _, bind = bind_shield(entity, data, tick)
		-- find ourselves inside old data
		local old_ourselves = old_data.tracked[old_data.unit_number]

		if old_ourselves ~= nil then
			bind.shield_health = old_ourselves.shield_health
			bind.shield_health_last = old_ourselves.shield_health_last
			bind.shield_health_last_t = old_ourselves.shield_health_last_t
			bind.last_damage = old_ourselves.last_damage
			bind.last_damage_bar = old_ourselves.last_damage_bar
		end
	end

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

	rebuild_shield_provider_dirty_lists(data, tick)

	return data
end

local function find_shield_provider(force, position, surface)
	local found = {}

	local sindex = surface.index

	for _, generator in pairs(shield_generators) do
		if generator.unit.valid and generator.surface == sindex and disttosqr(generator.pos, position) <= generator.range then
			table.insert(found, generator)
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

on_built_entity(function(event)
	local created_entity, tick = event.entity, event.tick

	if RANGE_DEF[created_entity.name] then
		initialize_shield_provider(created_entity, tick)
	elseif values.allowed_types[created_entity.type] and not values.blacklist[created_entity.name] then
		-- create provider shield second
		local provider_data = find_shield_provider(created_entity.force, created_entity.position, created_entity.surface)
		if not provider_data then return end

		if bind_shield(created_entity, provider_data, tick) then
			mark_shield_provider_child_dirty(provider_data, tick, created_entity.unit_number, true)
		end
	end
end)

script_hook(defines.events.on_entity_cloned, function(event)
	local source = event.source
	local destination = event.destination

	if RANGE_DEF[destination.name] and shield_generators[source.unit_number] then
		local old_data = shield_generators[source.unit_number]
		local new_data = initialize_shield_provider(destination, event.tick, old_data)

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

local function tick_visuals(tick, tracked_data)
	if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
		tracked_data.shield_health_last_t = tracked_data.shield_health
		tracked_data.last_damage_bar = tick
	end

	tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

	set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health, tracked_data.height)
	set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)
end

function tick_shield_providers(tick, delay, max_time, max_speed)
	if not speed_cache then
		rebuild_shield_provider_speed_cache()
	end

	local stopTicking = {}

	-- iterate dirty shield providers
	for unumber, data in pairs(shield_generators_dirty) do
		if not data.unit.valid then
			-- report_error('Encountered invalid shield provider with index ' .. data.unit_number)
			table_insert(stopTicking, data)
			goto CONTINUE
		end

		local energy = data.disabled and data.shield_energy or data.unit.energy

		if energy > 0 then
			data.visual_dirty_cache = nil

			-- whenever there was any dirty shields
			local run_dirty = false

			local count = data.tracked_dirty_num
			local health_per_tick = speed_cache[data.unit.force.name] * 4
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

			local stopTickingChildren = {}
			local removedChildren = {}

			-- iterate dirty shields inside shield provider
			for child_unumber, tracked_data in pairs(data.tracked_dirty) do
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

						tick_visuals(tick, tracked_data)
						if energy <= 0 then break end
					elseif should_tick_child_visuals(tracked_data) then
						run_dirty = true
						tick_visuals(tick, tracked_data)
					else
						hide_delegated_shield_bars(tracked_data)
						table_insert(stopTickingChildren, child_unumber)
						tracked_data.ticking = false
					end
				else
					report_error('Encountered invalid unit ' .. child_unumber .. ' in shield generator ' .. data.unit_number)
					table_insert(removedChildren, child_unumber)
				end
			end

			for _, child_unumber in ipairs(stopTickingChildren) do
				data.tracked_dirty[child_unumber] = nil
				data.tracked_dirty_num = data.tracked_dirty_num - 1
			end

			for _, child_unumber in ipairs(removedChildren) do
				on_destroyed(child_unumber, tick)
			end

			-- not a single dirty entity - consider this shield provider is clean
			-- also check whenever should we draw battery charge bar
			-- if we do have to, then don't mark as clean yet
			if not run_dirty and energy + 1 >= data.max_energy then
				data.ticking = false
				table_insert(stopTicking, data)
			end

			set_right_bottom(data.battery_bar, data.unit, -data.width + 2 * data.width * energy / data.max_energy, data.height)
		else
			local any_updates = false
			local removeChildren = {}

			if not data.visual_dirty_cache then
				data.visual_dirty_cache = {}

				for child_unumber, tracked_data in pairs(data.tracked_dirty) do
					if tracked_data.unit.valid and should_tick_child_visuals(tracked_data) then
						data.visual_dirty_cache[child_unumber] = tracked_data
					end
				end
			end

			for child_unumber, tracked_data in pairs(data.visual_dirty_cache) do
				if tracked_data.unit.valid then
					any_updates = true
					tick_visuals(tick, tracked_data)

					-- post check, so it updates at least once
					if not should_tick_child_visuals(tracked_data) then
						table_insert(removeChildren, child_unumber)
					end
				else
					table_insert(removeChildren, child_unumber)
				end
			end

			for _, child_unumber in ipairs(removeChildren) do
				data.visual_dirty_cache[child_unumber] = nil
			end

			if not any_updates then
				table_insert(stopTicking, data)
			end
		end

		if data.disabled then
			data.shield_energy = energy
		else
			data.unit.energy = energy
		end

		::CONTINUE::
	end

	for _, data in ipairs(stopTicking) do
		if not data.unit.valid then
			on_destroyed(data.unit_number, tick)
		elseif data.disabled and data.shield_energy <= 0 then
			data.ticking = false
			shield_generators_dirty[data.unit_number] = nil
		elseif not data.ticking then
			shield_generators_dirty[data.unit_number] = nil
			hide_shield_provider_bars(data)
		end
	end
end

listen_on_destroyed(function(index, tick)
	if shield_generators[index] then -- shield generator destroyed
		local data = shield_generators[index]
		shield_generators[index] = nil
		local rebound_uids = {}

		-- unbind shield generator from all of its units
		for unumber, tracked_data in pairs(data.tracked) do
			local rebound = false
			local unit = tracked_data.unit

			if unit.valid then
				-- try to rebind to other shield provider
				local provider_data = find_shield_provider(unit.force, unit.position, unit.surface)

				if provider_data then
					rebound = true

					shield_generators_bound[unumber] = provider_data
					provider_data.tracked[unumber] = tracked_data
					tracked_data.ticking = false
					rebound_uids[provider_data.unit_number] = provider_data
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
			rebuild_shield_provider_dirty_lists(data, tick)
		end
	elseif shield_generators_bound[index] then -- entity under shield generator protection destroyed
		local shield_generator = shield_generators_bound[index]

		-- we got our shield generator data
		-- let's remove us from tracked entities
		local tracked_data = assert(shield_generator.tracked[index], 'shield_generator.tracked[index] is nil')
		shield_generator.tracked[index] = nil

		if tracked_data.ticking then
			shield_generator.tracked_dirty[index] = nil
			shield_generator.tracked_dirty_num = shield_generator.tracked_dirty_num - 1
		end

		hide_delegated_shield_bars(tracked_data)
		shield_generators_bound[index] = nil
	end
end)
