
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

function mark_migration_applied(name)
	_G['migration_' .. name .. '_applied'] = true
end

function is_migration_applied(name)
	return _G['migration_' .. name .. '_applied'] == true
end

RANGE_DEF = {}
local values = require('__shield-generators__/values')

require('__shield-generators__/src/runtime/visual_functions')
require('__shield-generators__/src/runtime/runtime_utils')

local util = util

local shields, shields_dirty, shield_generators, shield_generators_dirty, shield_generators_hash, shield_generators_bound, destroy_remap
-- shield entity -> entity it protect map
local shield_to_self_map
-- hash table to hold
local lazy_unconnected_self_iter
local on_destroyed, bind_shield

local speed_cache, turret_speed_cache
local first_tick_validation = true

-- joules per hitpoint
local CONSUMPTION_PER_HITPOINT = settings.startup['shield-generators-joules-per-point'].value
local BAR_HEIGHT = values.BAR_HEIGHT

local math_min = math.min
local math_max = math.max

-- wwwwwwwwwtf??? with Lua of Wube
-- why it doesn't return inserted index
local function table_insert(tab, value)
	local insert = #tab + 1
	tab[insert] = value
	return insert
end

local function lerp(t, a, b)
	if t < 0 then return a end
	if t >= 1 then return b end
	return a + (b - a) * t
end

local RANGE_DEF = RANGE_DEF
local SEARCH_RANGE

local function rebuild_speed_cache()
	if not game then return end -- a

	speed_cache, turret_speed_cache = {}, {}

	local turret = settings.global['shield-generators-hitpoints-base-rate-turret'].value / 60
	local provider = settings.global['shield-generators-hitpoints-base-rate-provider'].value / 60

	for forcename, force in pairs(game.forces) do
		speed_cache[forcename] = util.recovery_speed_modifier(force.technologies) * provider
		turret_speed_cache[forcename] = util.turret_recovery_speed_modifier(force.technologies) * turret
	end
end

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

	rebuild_speed_cache()
end

local report_error

script.on_configuration_changed(function()
	reload_values()
end)

do
	-- migrations are not applied when world is created for the first time, so we need to apply them manually
	-- I hope Wube will (re)consider adding an option into info.json for forcefully executing Lua migrations
	-- when world is created with mod present (so it behaves like mod was added to existing save),
	-- and I won't have to do this crap
	local migration_names = {
		'2025_03_31-initial'
	}

	local migrations = {}

	for _, name in ipairs(migration_names) do
		table_insert(migrations, require('__shield-generators__/src/migrations/' .. name))
	end

	script.on_init(function()
		for i, migrate in ipairs(migrations) do
			local name = migration_names[i]
			mark_migration_applied(name)
			migrate()
		end

		-- set only this, since intial migration assumes it is true if it is missing
		storage.keep_interfaces = settings.global['shield-generators-keep-interfaces'].value
		-- reloading values here (should) provide nothing of value, since they will get overwritten by on_load before any read happen from them
		-- reload_values()

		setup_globals()
	end)
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	reload_values()

	if storage.keep_interfaces ~= settings.global['shield-generators-keep-interfaces'].value then
		storage.keep_interfaces = settings.global['shield-generators-keep-interfaces'].value

		if storage.keep_interfaces then
			::RETRY::

			for unumber, data in pairs(shields) do
				if not data.unit.valid then
					report_error('Shielded entity ' .. unumber .. ' is no longer valid, but present in _G.shields... Removing! This might be a bug.')
					on_destroyed(unumber, true, 0)
					goto RETRY
				end

				if not data.shield.valid then
					local entity = data.unit

					data.shield = entity.surface.create_entity({
						name = util.turret_interface_name(entity.force.technologies),
						position = entity.position,
						force = entity.force,
					})

					if shield_to_self_map then
						shield_to_self_map[data.shield.unit_number] = data
					end

					data.shield.destructible = false
					data.shield.minable = false
					data.shield.rotatable = false
					data.shield.electric_buffer_size = data.shield.electric_buffer_size * util.turret_capacity_modifier(entity.force.technologies)
					data.max_energy = data.shield.electric_buffer_size - 1

					if data.shield_energy then
						data.shield.energy = data.shield_energy
						data.shield_energy = nil
					end
				end
			end
		else
			::RETRY::

			for unumber, data in pairs(shields) do
				if not data.unit.valid then
					report_error('Shielded entity ' .. unumber .. ' is no longer valid, but present in _G.shields... Removing! This might be a bug.')
					on_destroyed(unumber, true, 0)
					goto RETRY
				end

				if data.shield.valid then
					if data.disabled then
						data.shield.electric_buffer_size = data.max_energy + 1
						data.shield.energy = data.shield_energy

						if not data.dirty then
							data.dirty = true
							data.disabled = nil

							show_self_shield_bars(data)
							table_insert(shields_dirty, data)
						end
					end

					if data.shield.energy >= data.max_energy and not data.dirty then
						data.shield_energy = data.shield.energy
						data.shield.destroy()
					end
				else
					data.shield_energy = data.shield_energy or 0
				end
			end
		end
	end

	if event.setting == 'shield-generators-multiplier' then
		local nextDirtyIndex = #shields_dirty + 1

		for _, data in pairs(shields) do
			local old = data.max_health
			data.max_health = data.unit.max_health * util.max_capacity_modifier_self(data.unit.force.technologies)
			data.shield_health = math_min(data.shield_health, data.max_health)

			if old < data.max_health and not data.dirty then
				data.dirty = true
				shields_dirty[nextDirtyIndex] = data
				nextDirtyIndex = nextDirtyIndex + 1
			end
		end
	end
end)

function setup_globals()
	shields = assert(storage.shields)
	destroy_remap = assert(storage.destroy_remap)
	shield_generators_bound = assert(storage.shield_generators_bound)
	shield_generators = assert(storage.shield_generators)
	lazy_unconnected_self_iter = assert(storage.lazy_unconnected_self_iter)

	shield_generators_dirty = {}
	shields_dirty = {}
	shield_generators_hash = {}
	-- shield_to_self_map = {}

	-- build dirty list from savegame
	for i = 1, #shield_generators do
		local data = shield_generators[i]

		if data.tracked_dirty then
			table.insert(shield_generators_dirty, data)
		end

		shield_generators_hash[data.id] = data
	end

	first_tick_validation = true

	local nextindex = 1

	-- build dirty list for self shielding entities from savegame
	for unumber, data in pairs(shields) do
		if data.dirty or data.shield_health < data.max_health or data.shield.valid and data.shield.energy < data.max_energy then
			-- data.dirty = true
			shields_dirty[nextindex] = data
			nextindex = nextindex + 1
		end
	end

	reload_values()
end

script.on_load(function()
	setup_globals()
end)

local function fill_shield_to_self_map()
	shield_to_self_map = {}

	for unumber, data in pairs(shields) do
		if data.shield.valid then
			shield_to_self_map[data.shield.unit_number] = data
		end
	end
end

function report_error(str)
	-- game.print('[Shield Generators] Reported managed error: ' .. str)
	log('Reporting managed error: ' .. str)
end

local function start_ticking_shield_generator(shield_generator, tick)
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
		table_insert(shield_generators_dirty, shield_generator)
	end
end

-- adding new entity to shield provider, just that.
local function mark_shield_provider_child_dirty(shield_generator, tick, unit_number, force)
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
			table_insert(shield_generator.tracked_dirty, i)
			break
		end
	end]]

	local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[unit_number]]

	if tracked_data then
		if ticking or force or not tracked_data.dirty then
			tracked_data.dirty = true
			table_insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
			show_delegated_shield_bars(tracked_data)
		end
	else
		report_error('Trying to mark_shield_provider_child_dirty on ' .. unit_number .. ' which is not present in shield_generator.tracked_hash! This is a bug!')
	end
end

local function mark_shield_provider_dirty(shield_generator, tick)
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

				table_insert(shield_generator.tracked_dirty, i)

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

local VISUAL_DAMAGE_BAR_SHRINK_SPEED = values.VISUAL_DAMAGE_BAR_SHRINK_SPEED
local VISUAL_DAMAGE_BAR_WAIT_TICKS = values.VISUAL_DAMAGE_BAR_WAIT_TICKS
local VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX = values.VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX
local set_right_bottom = set_right_bottom

script.on_event(defines.events.on_tick, function(event)
	if not speed_cache then
		rebuild_speed_cache()
	end

	-- since inside on_load LuaEntities are invalid
	-- we have to do this on next game tick
	if not shield_to_self_map then
		fill_shield_to_self_map()
	end

	local check = false
	local tick = event.tick

	local delay = settings.global['shield-generators-delay'].value * 60
	local max_time = settings.global['shield-generators-max-time'].value * 60
	local max_speed = settings.global['shield-generators-max-speed'].value

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
						mark_shield_provider_dirty(data, event.tick)
						break
					end
				end
			end
		end
	end

	local _value

	for i = 1, 5 do
		if storage.lazy_key ~= nil and not lazy_unconnected_self_iter[storage.lazy_key] then
			storage.lazy_key = nil
		end

		storage.lazy_key, _value = next(lazy_unconnected_self_iter, storage.lazy_key)

		if not _value then
			storage.lazy_key, _value = next(lazy_unconnected_self_iter)
		end

		if _value then
			local _data = shields[storage.lazy_key]

			if _data then
				local _shield = _data.shield

				if _shield.valid then
					if _shield.is_connected_to_electric_network() then
						_data.dirty = true
						show_self_shield_bars(_data)
						table_insert(shields_dirty, _data)
						lazy_unconnected_self_iter[storage.lazy_key] = nil
						-- storage.lazy_key = nil
					end
				else
					lazy_unconnected_self_iter[storage.lazy_key] = nil
					-- storage.lazy_key = nil
					break
				end
			else
				lazy_unconnected_self_iter[storage.lazy_key] = nil
				storage.lazy_key = nil
				break
			end
		else
			break
		end
	end

	if first_tick_validation then
		first_tick_validation = false

		for i = #shields_dirty, 1, -1 do
			local tracked_data = shields_dirty[i]

			if tracked_data.unit.valid and tracked_data.shield.valid then
				show_self_shield_bars(tracked_data)
			end
		end
	end

	-- iterate dirty self shields
	for i = #shields_dirty, 1, -1 do
		local tracked_data = shields_dirty[i]

		if tracked_data.unit.valid and tracked_data.shield.valid then
			local energy = tracked_data.disabled and tracked_data.shield_energy or tracked_data.shield.energy

			if tracked_data.shield_health < tracked_data.max_health then
				-- energy above 0, proceed as normal
				if energy > 0 then
					local mult = 1

					-- first 1.5 seconds - base recharge rate
					-- then linearly increase to triple speed
					-- in next 3 seconds
					if tracked_data.last_damage and tick - tracked_data.last_damage > 90 then
						mult = lerp((tick - tracked_data.last_damage - delay) / max_time, 1, max_speed)
					end

					local delta = math_min(energy / CONSUMPTION_PER_HITPOINT, turret_speed_cache[tracked_data.shield.force.name] * mult, tracked_data.max_health - tracked_data.shield_health)
					tracked_data.shield_health = tracked_data.shield_health + delta
					energy = energy - delta * CONSUMPTION_PER_HITPOINT

					if tracked_data.disabled then
						tracked_data.shield_energy = energy
					else
						tracked_data.shield.energy = energy
					end

					if tracked_data.health ~= tracked_data.max_health then
						-- update hacky health counter if required
						tracked_data.health = tracked_data.unit.health
					end

					if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
						tracked_data.shield_health_last_t = tracked_data.shield_health
						tracked_data.last_damage_bar = tick
					end

					tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

					set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health, tracked_data.height)
					set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)
					set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy, tracked_data.height + BAR_HEIGHT)
				-- we don't have any energy, but visual red bar is above current health, shrink it
				elseif tracked_data.shield_health_last > tracked_data.shield_health then
					if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
						tracked_data.shield_health_last_t = tracked_data.shield_health
						tracked_data.last_damage_bar = tick
					end

					tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

					set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health, tracked_data.height)
					set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)
				-- at least, we check connection to any electrical grid
				-- if we are not connected to any electrical grid, stop ticking
				elseif not tracked_data.shield.is_connected_to_electric_network() or tracked_data.disabled then
					-- update bars before untracking

					set_right_bottom(tracked_data.shield_bar, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health, tracked_data.height)
					set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width, tracked_data.height + BAR_HEIGHT)

					-- remove shield from dirty list if energy empty and is not connected to any power network
					tracked_data.dirty = false
					table.remove(shields_dirty, i)

					if not tracked_data.disabled then
						lazy_unconnected_self_iter[tracked_data.id] = true
					end
				end
			elseif energy < tracked_data.max_energy then
				set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy, tracked_data.height + BAR_HEIGHT)

				if not tracked_data.shield.is_connected_to_electric_network() then
					-- remove shield from dirty list if energy half-full/empty and is not connected to any power network
					tracked_data.dirty = false
					table.remove(shields_dirty, i)
					lazy_unconnected_self_iter[tracked_data.id] = true
				elseif tracked_data.disabled then
					-- shield is disabled - stop tracking it
					tracked_data.dirty = false
					table.remove(shields_dirty, i)
				end
			else
				hide_self_shield_bars(tracked_data)

				tracked_data.dirty = false
				table.remove(shields_dirty, i)

				if not storage.keep_interfaces then
					shield_to_self_map[tracked_data.shield.unit_number] = nil
					tracked_data.shield_energy = tracked_data.shield.energy
					tracked_data.shield.destroy()
				end
			end
		else
			report_error('Late removal of self-shielded entity with id ' .. tracked_data.id)
			on_destroyed(tracked_data.id, false, tick)

			if shields_dirty[i] == tracked_data then
				table.remove(shields_dirty, i)
			end
		end
	end
end)

local function player_select_area(event)
	if event.item ~= 'shield-generator-switch' then return end

	for i, ent in ipairs(event.entities) do
		local shield = shield_to_self_map[ent.unit_number]

		if shield and storage.keep_interfaces then
			if shield.disabled then
				ent.electric_buffer_size = shield.max_energy + 1
				ent.energy = shield.shield_energy
			else
				shield.shield_energy = ent.energy
				shield.max_energy = ent.electric_buffer_size - 1

				ent.electric_buffer_size = 0
				ent.energy = 0
			end

			shield.disabled = not shield.disabled

			if not shield.dirty then
				shield.dirty = true
				show_self_shield_bars(shield)
				table_insert(shields_dirty, shield)
			end
		elseif shield_generators_hash[ent.unit_number] then
			shield = shield_generators_hash[ent.unit_number]

			if shield.disabled then
				ent.electric_buffer_size = shield.max_energy + 1
				ent.energy = shield.shield_energy
			else
				shield.shield_energy = ent.energy
				shield.max_energy = ent.electric_buffer_size - 1

				ent.electric_buffer_size = 0
				ent.energy = 0
			end

			shield.disabled = not shield.disabled

			if not shield.dirty then
				shield.dirty = true
				table_insert(shield_generators_dirty, shield)
			end
		end
	end
end

script.on_event(defines.events.on_player_selected_area, player_select_area)
script.on_event(defines.events.on_player_alt_selected_area, player_select_area)

script.on_event(defines.events.on_entity_damaged, function(event)
	local entity, final_damage_amount = event.entity, event.final_damage_amount
	local final_health

	local unit_number = entity.unit_number

	-- bound shield generator provider
	-- process is before internal shield
	if shield_generators_bound[unit_number] then
		local shield_generator = shield_generators_hash[shield_generators_bound[unit_number]]

		if shield_generator then
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[unit_number]]

			if tracked_data then
				if final_damage_amount >= 1 then
					shield_generator.last_damage = event.tick
					tracked_data.last_damage = event.tick
				end

				local health = tracked_data.health
				local shield_health = tracked_data.shield_health

				-- full absorption
				if shield_health >= final_damage_amount then
					-- HACK HACK HACK
					-- we have no idea how to determine old health in this case
					if event.final_health == 0 then
						entity.health = tracked_data.health
					else
						entity.health = entity.health + final_damage_amount
						tracked_data.health = entity.health
					end

					tracked_data.shield_health = shield_health - final_damage_amount
					final_damage_amount = 0
				else
				-- partial absorption
					final_damage_amount = final_damage_amount - tracked_data.shield_health

					--tracked_data.health = health - final_damage_amount

					if event.final_health == 0 then
						tracked_data.health = health - final_damage_amount
					else
						tracked_data.health = entity.health + tracked_data.shield_health
					end

					entity.health = tracked_data.health
					final_health = math_max(0, tracked_data.health)
					tracked_data.shield_health = 0
				end

				-- not dirty? mark shield generator as dirty
				if not shield_generator.tracked_dirty then
					-- mark_shield_provider_dirty(shield_generator, event.tick)
					mark_shield_provider_child_dirty(shield_generator, event.tick, unit_number)

				-- shield is dirty but we are not?
				-- mark us as dirty
				elseif not tracked_data.dirty then
					tracked_data.dirty = true
					table_insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
					show_delegated_shield_bars(tracked_data)
				end
			else
				report_error('Entity ' .. unit_number .. ' appears to be bound to generator ' .. shield_generator.id .. ', but it is not present in tracked[]!')
			end
		else
			report_error('Entity ' .. unit_number .. ' appears to be bound to generator ' .. shield_generators_bound[unit_number] .. ', but this generator is invalid!')
		end
	end

	-- if damage wa reflected by shield provider, just update our "last damaged" tick
	if final_damage_amount <= 0 then
		if shield and final_damage_amount >= 1 then
			shield.last_damage = event.tick
		end

		return
	end

	local shield = shields[unit_number]

	-- internal shield
	if shield then
		local shield_health = shield.shield_health
		local health = shield.health or entity.health

		if final_damage_amount >= 1 then
			shield.last_damage = event.tick
		end

		shield.shield_health_last = math_max(shield.shield_health_last or 0, shield_health)

		if shield_health >= final_damage_amount then
			-- HACK HACK HACK
			-- we have no idea how to determine old health in this case
			final_health = final_health or event.final_health

			if final_health == 0 then
				entity.health = shield.health
			else
				entity.health = entity.health + final_damage_amount
				shield.health = entity.health
			end

			shield.shield_health = shield_health - final_damage_amount
		else
			shield.health = health - final_damage_amount + shield_health
			entity.health = shield.health
			shield.shield_health = 0
		end

		if not shield.dirty then
			shield.dirty = true
			table_insert(shields_dirty, shield)

			if not shield.shield.valid then
				shield.shield = entity.surface.create_entity({
					name = util.turret_interface_name(entity.force.technologies),
					position = entity.position,
					force = entity.force,
				})

				if shield_to_self_map then
					shield_to_self_map[shield.shield.unit_number] = shield
				end

				shield.shield.destructible = false
				shield.shield.minable = false
				shield.shield.rotatable = false
				shield.shield.electric_buffer_size = shield.shield.electric_buffer_size * util.turret_capacity_modifier(entity.force.technologies)
				shield.max_energy = shield.shield.electric_buffer_size - 1

				if shield.shield_energy then
					shield.shield.energy = shield.shield_energy
					shield.shield_energy = nil
				end
			end

			lazy_unconnected_self_iter[unit_number] = nil
			show_self_shield_bars(shield)
		end
	end
end, values.filter_types)

function bind_shield(entity, shield_provider, tick)
	if not entity.destructible then return false end
	local unit_number = entity.unit_number

	if shield_generators_bound[unit_number] then return false end
	if shield_provider.tracked_hash[unit_number] then return false end
	local max_health = entity.max_health

	if not max_health or max_health <= 0 then return false end

	local width, height = util.determineDimensions(entity)

	if shields[unit_number] then
		height = height + BAR_HEIGHT * 2
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
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	destroy_remap[script.register_on_object_destroyed(entity)] = unit_number

	return true
end

local function rebind_shield(tracked_data, shield_provider)
	local unit_number = tracked_data.unit.unit_number

	-- just remap data from one to another
	shield_generators_bound[unit_number] = shield_provider.id
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	return true
end

local function initialize_shield_provider(entity, tick)
	if shield_generators_hash[entity.unit_number] then return end -- wut

	destroy_remap[script.register_on_object_destroyed(entity)] = entity.unit_number

	local width, height = util.determineDimensions(entity)
	height = height + BAR_HEIGHT

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

	table_insert(shield_generators, data)
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

local function distance(a, b)
	return math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
end

local function disttosqr(a, b)
	return (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)
end

local function find_shield_provider(force, position, surface)
	local found = {}

	if #shield_generators < 400 then
		local sindex = surface.index

		for i = 1, #shield_generators do
			local generator = shield_generators[i]

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

local function create_delegated_shield(entity, tick)
	if values.blacklist[entity.name] then return end

	local provider_data = find_shield_provider(entity.force, entity.position, entity.surface)
	if not provider_data then return end

	if bind_shield(entity, provider_data, tick) then
		-- mark_shield_provider_dirty(provider_data, tick)
		mark_shield_provider_child_dirty(provider_data, tick, entity.unit_number, true)
	end
end

local function create_self_shield(entity, tick)
	local index = entity.unit_number
	if shields[index] or entity.max_health <= 0 then return end -- wut

	destroy_remap[script.register_on_object_destroyed(entity)] = index

	local width, height = util.determineDimensions(entity)

	local tracked_data = {
		shield = entity.surface.create_entity({
			name = util.turret_interface_name(entity.force.technologies),
			position = entity.position,
			force = entity.force,
		}),

		max_health = entity.max_health * util.max_capacity_modifier_self(entity.force.technologies),
		shield_health = 0,
		shield_health_last = 0,
		shield_health_last_t = 0,

		width = width,
		height = height,

		last_damage = assert(tick, 'create_self_shield called without tick'),
		last_damage_bar = tick,

		health = entity.health,
		unit = entity,
		id = index,

		dirty = true
	}

	show_self_shield_bars(tracked_data)

	tracked_data.shield.destructible = false
	tracked_data.shield.minable = false
	tracked_data.shield.rotatable = false
	tracked_data.shield.electric_buffer_size = tracked_data.shield.electric_buffer_size * util.turret_capacity_modifier(entity.force.technologies)
	tracked_data.max_energy = tracked_data.shield.electric_buffer_size - 1

	shields[index] = tracked_data
	table_insert(shields_dirty, tracked_data)

	if not shield_to_self_map then
		fill_shield_to_self_map()
	end

	shield_to_self_map[tracked_data.shield.unit_number] = tracked_data

	-- case: we got self shield after getting shield from shield provider
	-- update bars for them to not overlap with ours
	if shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators_hash[shield_generators_bound[index]]

		if shield_generator then
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			if tracked_data then
				tracked_data.height = tracked_data.height + BAR_HEIGHT * 2

				if tracked_data.shield_bar then
					hide_delegated_shield_bars(tracked_data)
					show_delegated_shield_bars(tracked_data)
				end
			end
		end
	end

	return tracked_data
end

local function on_built(created_entity, tick)
	if RANGE_DEF[created_entity.name] then
		initialize_shield_provider(created_entity, tick)
		return
	end

	if values.allowed_types_self[created_entity.type] and (not created_entity.force or created_entity.force.technologies['shield-generators-turret-shields-basics'].researched) then
		-- create turret shield first
		create_self_shield(created_entity, tick)
	end

	if values.allowed_types[created_entity.type] then
		-- create provider shield second
		create_delegated_shield(created_entity, tick)
	end

	-- check for poles
	if created_entity.type == 'electric-pole' then
		local pos = created_entity.position
		local area = created_entity.prototype.get_supply_area_distance(created_entity.quality)

		-- find any self shield in pole area
		local found = created_entity.surface.find_entities_filtered({
			area = {
				{x = pos.x - area, y = pos.y - area},
				{x = pos.x + area, y = pos.y + area},
			},

			force = created_entity.force,
			name = values.SELF_GENERATORS
		})

		if not shield_to_self_map then
			fill_shield_to_self_map()
		end

		for i, ent in ipairs(found) do
			local tracked_data = shield_to_self_map[ent.unit_number]

			-- if we hit a self-shield that is idle and not energy full, wake it up
			if tracked_data and not tracked_data.dirty and tracked_data.unit.valid and ent.energy ~= tracked_data.max_energy then
				tracked_data.dirty = true
				table_insert(shields_dirty, tracked_data)
				lazy_unconnected_self_iter[tracked_data.id] = nil
				show_self_shield_bars(tracked_data)
			end
		end
	end
end

local iface_name_length = #'shield-generators-interface'

local function on_entity_cloned(event)
	local source = event.source
	local destination = event.destination

	if string.sub(source.name, 1, iface_name_length) == 'shield-generators-interface' then
		destination.destroy()
	elseif shields[source.unit_number] then
		local old_data = shields[source.unit_number]
		local new_data = create_self_shield(destination, event.tick)

		new_data.dirty = true
		-- new_data.max_health = old_data.max_health
		new_data.shield_health = old_data.shield_health
		new_data.shield_health_last = old_data.shield_health_last
		new_data.shield_health_last_t = old_data.shield_health_last_t
		new_data.last_damage = assert(old_data.last_damage, 'old data is missing last_damage')
		new_data.last_damage_bar = assert(old_data.last_damage_bar, 'old data is missing last_damage_bar')
		new_data.disabled = old_data.disabled
		-- new_data.health = old_data.health

		if old_data.disabled then
			new_data.max_energy = old_data.max_energy
			new_data.shield_energy = old_data.shield_energy
			new_data.shield.electric_buffer_size = 0
			new_data.shield.energy = 0
		else
			if old_data.shield.valid then
				new_data.shield.energy = old_data.shield.energy
				new_data.shield.electric_buffer_size = old_data.shield.electric_buffer_size
			elseif old_data.shield_energy then
				new_data.shield.energy = old_data.shield_energy
			end
		end

		hide_self_shield_bars(new_data)
		show_self_shield_bars(new_data)
	elseif RANGE_DEF[destination.name] and shield_generators_hash[source.unit_number] then
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
end

script.on_event(defines.events.on_entity_cloned, on_entity_cloned)

script.on_event(defines.events.on_built_entity, function(event)
	on_built(event.entity, event.tick)
end, values.filter_types)

script.on_event(defines.events.script_raised_built, function(event)
	on_built(event.entity, event.tick)
end, values.filter_types)

script.on_event(defines.events.script_raised_revive, function(event)
	on_built(event.entity, event.tick)
end, values.filter_types)

script.on_event(defines.events.on_robot_built_entity, function(event)
	on_built(event.entity, event.tick)
end, values.filter_types)

local function refresh_turret_shields(force)
	local classname = util.turret_interface_name(force.technologies)
	local modif = util.turret_capacity_modifier(force.technologies)

	local nextindex = #shields_dirty + 1

	for index, tracked_data in pairs(shields) do
		if tracked_data.unit.force == force then
			if not tracked_data.shield.valid or tracked_data.shield.name ~= classname then
				local energy =
					tracked_data.disabled and tracked_data.energy or
					tracked_data.shield.valid and tracked_data.shield.energy or
					tracked_data.shield_energy or 0

				if shield_to_self_map and tracked_data.shield.valid then
					shield_to_self_map[tracked_data.shield.unit_number] = nil
				end

				if tracked_data.shield.valid then
					tracked_data.shield.destroy()
				end

				local shield = tracked_data.unit.surface.create_entity({
					-- name = 'shield-generators-interface',
					name = classname,
					position = tracked_data.unit.position,
					force = tracked_data.unit.force,
				})

				if shield_to_self_map then
					shield_to_self_map[shield.unit_number] = tracked_data
				end

				tracked_data.shield = shield

				shield.destructible = false
				shield.minable = false
				shield.rotatable = false
				shield.electric_buffer_size = shield.electric_buffer_size * modif
				tracked_data.max_energy = shield.electric_buffer_size - 1

				if tracked_data.disabled then
					shield.electric_buffer_size = 0
				else
					shield.energy = energy
				end

				if not tracked_data.dirty then
					tracked_data.dirty = true
					show_self_shield_bars(tracked_data)
					shields_dirty[nextindex] = tracked_data
					nextindex = nextindex + 1
				end
			else
				local iface = tracked_data.shield.prototype.electric_energy_source_prototype

				if iface then
					local shield = tracked_data.shield

					shield.electric_buffer_size = iface.buffer_capacity * modif
					tracked_data.max_energy = shield.electric_buffer_size - 1

					if tracked_data.disabled then
						shield.electric_buffer_size = 0
					end

					if not tracked_data.dirty then
						tracked_data.dirty = true
						show_self_shield_bars(tracked_data)
						shields_dirty[nextindex] = tracked_data
						nextindex = nextindex + 1
					end
				end
			end
		end
	end
end

script.on_event(defines.events.on_research_finished, function(event)
	if event.research.name == 'shield-generators-turret-shields-basics' then
		for name, surface in pairs(game.surfaces) do
			local found = surface.find_entities_filtered({
				force = event.research.force,
				type = values._allowed_types_self,
			})

			for i, ent in ipairs(found) do
				create_self_shield(ent, event.tick)
			end
		end
	elseif event.research.name == 'shield-generators-superconducting-shields' then
		-- this way because i plan expanding it (adding more HP techs)
		local mult = util.max_capacity_modifier(event.research.force.technologies)
		local force = event.research.force

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, event.tick)
			elseif data.unit.force == force then
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.max_health * mult
				end

				mark_shield_provider_dirty(data, event.tick)
			end
		end
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_speed_cache()
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_turret_shields(event.research.force)
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
				on_destroyed(ent.unit_number, false, event.tick)
			end
		end
	elseif event.research.name == 'shield-generators-superconducting-shields' then
		-- this way because i plan expanding it (adding more HP techs)
		local mult = util.max_capacity_modifier(event.research.force.technologies)
		local force = event.research.force

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, event.tick)
			elseif data.unit.force == force then
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.max_health * mult
					data.tracked[i2].shield_health = math_min(data.tracked[i2].max_health, data.tracked[i2].shield_health)
				end

				mark_shield_provider_dirty(data, event.tick)
			end
		end
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_speed_cache()
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_turret_shields(event.research.force)
	end
end)

script.on_event(defines.events.on_force_created, function(event)
	rebuild_speed_cache()
end)

script.on_event(defines.events.on_forces_merged, function(event)
	rebuild_speed_cache()
end)

script.on_event(defines.events.on_force_reset, function(event)
	rebuild_speed_cache()
end)

script.on_event(defines.events.on_force_friends_changed, function(event)
	rebuild_speed_cache()
end)

function on_destroyed(index, from_dirty, tick)
	-- entity with internal shield destroyed
	if shields[index] then
		local tracked_data = shields[index]

		if tracked_data.shield and tracked_data.shield.valid then
			shield_to_self_map[tracked_data.shield.unit_number] = nil
		else
			report_error('Unexpected self shield deletion of now deleted unit ' .. index .. '. Getting around it is slow!')

			for key, value  in pairs(shield_to_self_map) do
				if value == tracked_data then
					shield_to_self_map[key] = nil
					break
				end
			end
		end

		tracked_data.shield.destroy()

		hide_self_shield_bars(tracked_data)

		if tracked_data.dirty then
			for i = 1, #shields_dirty do
				if shields_dirty[i] == tracked_data then
					table.remove(shields_dirty, i)
					break
				end
			end
		end

		lazy_unconnected_self_iter[index] = nil
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
	elseif shield_generators_bound[index] then -- entity under shield generator destroyed
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
end

script.on_event(defines.events.on_object_destroyed, function(event)
	if not destroy_remap[event.registration_number] then return end
	on_destroyed(destroy_remap[event.registration_number], false, event.tick)
	destroy_remap[event.registration_number] = nil
end)
