
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

local shields, shields_dirty, shield_generators, shield_generators_dirty, shield_generators_hash, shield_generators_bound, destroy_remap
-- shield entity -> entity it protect map
local shield_to_self_map
-- hash table to hold
local lazy_unconnected_self_iter
local on_destroyed, bind_shield

local speed_cache, turret_speed_cache

local values = require('__shield-generators__/values')
local shield_util = require('__shield-generators__/util')

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

local RANGE_DEF = {}
local SEARCH_RANGE

local function rebuild_cache()
	if not game then return end -- a

	speed_cache, turret_speed_cache = {}, {}

	local turret = settings.global['shield-generators-hitpoints-base-rate-turret'].value / 60
	local provider = settings.global['shield-generators-hitpoints-base-rate-provider'].value / 60

	for forcename, force in pairs(game.forces) do
		speed_cache[forcename] = shield_util.recovery_speed_modifier(force.technologies) * provider
		turret_speed_cache[forcename] = shield_util.turret_recovery_speed_modifier(force.technologies) * turret
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

	if global['shield-generators-provider-capacity'] ~= settings.global['shield-generators-provider-capacity'].value and game then
		local value = settings.global['shield-generators-provider-capacity'].value
		global['shield-generators-provider-capacity'] = value

		for i = 1, #shield_generators do
			if shield_generators[i].unit.valid and shield_generators[i].unit.prototype.electric_energy_source_prototype then
				shield_generators[i].unit.electric_buffer_size = shield_generators[i].unit.prototype.electric_energy_source_prototype.buffer_capacity * value
				shield_generators[i].max_energy = shield_generators[i].unit.electric_buffer_size
			end
		end
	end

	rebuild_cache()
end

local validate_self_bars, validate_provider_bars, validate_shielded_bars
local destroy_self_bars, destroy_provider_bars, destroy_shielded_bars

script.on_configuration_changed(function()
	global.shields = global.shields or {}
	global.destroy_remap = global.destroy_remap or {}
	global.shield_generators_bound = global.shield_generators_bound or {}
	global.shield_generators = global.shield_generators or {}

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	lazy_unconnected_self_iter = global.lazy_unconnected_self_iter

	if not lazy_unconnected_self_iter then
		global.lazy_unconnected_self_iter = {}
		lazy_unconnected_self_iter = global.lazy_unconnected_self_iter

		for unumber, data in pairs(shields) do
			if not data.shield.is_connected_to_electric_network() then
				lazy_unconnected_self_iter[unumber] = true
			end
		end
	end

	reload_values()

	if not global.migrated_98277 then
		for _, data in pairs(shield_generators) do
			if not data.tracked_dirty then
				destroy_provider_bars(data)
			end

			if data.tracked then
				for i, tracked_data in ipairs(data.tracked) do
					if not tracked_data.dirty then
						destroy_shielded_bars(tracked_data)
					end
				end
			end
		end

		for unumber, tracked_data in pairs(shields) do
			if not tracked_data.dirty and tracked_data.shield.valid and tracked_data.shield.is_connected_to_electric_network() then
				destroy_self_bars(tracked_data)
			end
		end

		global.migrated_98277 = true
	end

	if not global.delayed_bar_added then
		for unumber, data in pairs(shields) do
			data.shield_health_last = data.shield_health_last or data.shield_health
			data.shield_health_last_t = data.shield_health_last_t or data.shield_health

			if data.dirty then
				destroy_self_bars(data)
				validate_self_bars(data)
			end
		end

		for _, data in pairs(shield_generators) do
			if data.tracked then
				for i, tracked_data in ipairs(data.tracked) do
					tracked_data.shield_health_last = tracked_data.shield_health_last or tracked_data.shield_health
					tracked_data.shield_health_last_t = tracked_data.shield_health_last_t or tracked_data.shield_health

					if tracked_data.dirty then
						destroy_shielded_bars(tracked_data)
						validate_shielded_bars(tracked_data)
					end
				end
			end
		end
	end

	if not global.delayed_bar_added2 then
		for unumber, data in pairs(shields) do
			data.last_damage_bar = data.last_damage_bar or data.last_damage

			if data.dirty then
				destroy_self_bars(data)
				validate_self_bars(data)
			end
		end

		for _, data in pairs(shield_generators) do
			if data.tracked then
				for i, tracked_data in ipairs(data.tracked) do
					tracked_data.last_damage_bar = tracked_data.last_damage_bar or tracked_data.last_damage

					if tracked_data.dirty then
						destroy_shielded_bars(tracked_data)
						validate_shielded_bars(tracked_data)
					end
				end
			end
		end
	end
end)

script.on_init(function()
	global.shields = {}
	global.destroy_remap = {}
	global.shield_generators_bound = {}
	global.shield_generators = {}
	global.lazy_unconnected_self_iter = {}

	global.migrated_98277 = true
	global.delayed_bar_added = true
	global.delayed_bar_added2 = true

	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	lazy_unconnected_self_iter = global.lazy_unconnected_self_iter

	shield_generators_hash = {}
	shield_to_self_map = {}

	shield_generators_dirty = {}
	shields_dirty = {}

	reload_values()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, reload_values)

script.on_load(function()
	-- i could assert these, but
	-- on_configuration_changed is executed *after* on_load
	-- meaning migrations are not yet applied
	shields = global.shields
	destroy_remap = global.destroy_remap
	shield_generators_bound = global.shield_generators_bound
	shield_generators = global.shield_generators
	lazy_unconnected_self_iter = global.lazy_unconnected_self_iter

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

	local nextindex = 1

	-- build dirty list for self shielding entities from savegame
	for unumber, data in pairs(shields) do
		if data.dirty or data.shield_health < data.max_health or data.shield.energy < data.max_energy then
			shields_dirty[nextindex] = data
			nextindex = nextindex + 1
		end
	end

	reload_values()
end)

local function fill_shield_to_self_map()
	shield_to_self_map = {}

	for unumber, data in pairs(shields) do
		if data.shield.valid then
			shield_to_self_map[data.shield.unit_number] = data
		end
	end
end

local function report_error(str)
	-- game.print('[Shield Generators] Reported managed error: ' .. str)
	log('Reporting managed error: ' .. str)
end

local function mark_shield_dirty(shield_generator, tick)
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

				tracked_data.dirty = true
				table_insert(shield_generator.tracked_dirty, i)

				--[[if rendering.is_valid(tracked_data.shield_bar) then
					rendering.set_visible(tracked_data.shield_bar, true)
					rendering.set_visible(tracked_data.shield_bar_bg, true)
				end]]

				destroy_shielded_bars(tracked_data)

				i = i + 1
			elseif tracked_data.dirty then
				--[[if rendering.is_valid(tracked_data.shield_bar) then
					rendering.set_visible(tracked_data.shield_bar, false)
					rendering.set_visible(tracked_data.shield_bar_bg, false)
				end]]

				destroy_shielded_bars(tracked_data)

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
		validate_provider_bars(shield_generator)

		rendering.set_visible(shield_generator.battery_bar_bg, true)
		rendering.set_visible(shield_generator.battery_bar, true)

		for i, _index in ipairs(shield_generator.tracked_dirty) do
			validate_shielded_bars(shield_generator.tracked[_index])
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
	else
		-- rendering.set_visible(shield_generator.battery_bar_bg, false)
		-- rendering.set_visible(shield_generator.battery_bar, false)

		destroy_provider_bars(shield_generator)

		for i, data in ipairs(shield_generators_dirty) do
			if data == shield_generator then
				table.remove(shield_generators_dirty, i)
				break
			end
		end
	end
end

local _position = {}
local VISUAL_DAMAGE_BAR_SHRINK_SPEED = values.VISUAL_DAMAGE_BAR_SHRINK_SPEED
local VISUAL_DAMAGE_BAR_WAIT_TICKS = values.VISUAL_DAMAGE_BAR_WAIT_TICKS
local VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX = values.VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX

script.on_event(defines.events.on_tick, function(event)
	if not speed_cache then
		rebuild_cache()
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
			local energy = data.unit.energy

			if energy > 0 then
				-- whenever there was any dirty shields
				local run_dirty = false

				local count = #data.tracked_dirty
				local health_per_tick = speed_cache[data.unit.force.name]

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

							local mult = 1

							-- first 1.5 seconds - base recharge rate
							-- then linearly increase to triple speed
							-- in next 3 seconds
							if tracked_data.last_damage and tick - tracked_data.last_damage > delay then
								mult = lerp((tick - tracked_data.last_damage - delay) / max_time, 1, max_speed)
							end

							local delta = math_min(energy / CONSUMPTION_PER_HITPOINT, health_per_tick * mult, tracked_data.max_health - tracked_data.shield_health)
							tracked_data.shield_health = tracked_data.shield_health + delta
							energy = energy - delta * CONSUMPTION_PER_HITPOINT

							if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
								tracked_data.shield_health_last_t = tracked_data.shield_health
								tracked_data.last_damage_bar = tick
							end

							tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

							_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health
							_position[2] = tracked_data.height

							rendering.set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, _position)

							_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
							-- _position[2] = tracked_data.height

							rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)

							if energy <= 0 then break end
						elseif tracked_data.shield_health_last > tracked_data.shield_health then

							if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
								tracked_data.shield_health_last_t = tracked_data.shield_health
								tracked_data.last_damage_bar = tick
							end

							tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

							_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health
							_position[2] = tracked_data.height

							rendering.set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, _position)

							_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
							-- _position[2] = tracked_data.height

							rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)
						else
							destroy_shielded_bars(tracked_data)

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

				_position[1] = -data.width + 2 * data.width * energy / data.max_energy
				_position[2] = data.height
				rendering.set_right_bottom(data.battery_bar, data.unit, _position)
			end

			data.unit.energy = energy
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

			if not data.unit.valid then
				table.remove(shield_generators_dirty, i)
			elseif not data.tracked_dirty then
				table.remove(shield_generators_dirty, i)

				-- rendering.set_visible(data.battery_bar_bg, false)
				-- rendering.set_visible(data.battery_bar, false)
				destroy_provider_bars(data)

				for i, tracked_data in ipairs(data.tracked) do
					if tracked_data.unit.valid then
						validate_shielded_bars(tracked_data)
						-- rendering.set_visible(tracked_data.shield_bar, false)
						-- rendering.set_visible(tracked_data.shield_bar_bg, false)
						destroy_shielded_bars(tracked_data)
					else
						mark_shield_dirty(data, event.tick)
						break
					end
				end
			end
		end
	end

	local _value

	for i = 1, 5 do
		if global.lazy_key ~= nil and not lazy_unconnected_self_iter[global.lazy_key] then
			global.lazy_key = nil
		end

		global.lazy_key, _value = next(lazy_unconnected_self_iter, global.lazy_key)

		if not _value then
			global.lazy_key, _value = next(lazy_unconnected_self_iter)
		end

		if _value then
			local _data = shields[global.lazy_key]

			if _data then
				local _shield = _data.shield

				if _shield.valid then
					if _shield.is_connected_to_electric_network() then
						_data.dirty = true
						table_insert(shields_dirty, _data)
						lazy_unconnected_self_iter[global.lazy_key] = nil
						-- global.lazy_key = nil
					end
				else
					lazy_unconnected_self_iter[global.lazy_key] = nil
					-- global.lazy_key = nil
					break
				end
			else
				lazy_unconnected_self_iter[global.lazy_key] = nil
				global.lazy_key = nil
				break
			end
		else
			break
		end
	end

	-- iterate dirty self shields
	for i = #shields_dirty, 1, -1 do
		local tracked_data = shields_dirty[i]

		if tracked_data.unit.valid and tracked_data.shield.valid then
			local energy = tracked_data.shield.energy

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
					tracked_data.shield.energy = energy

					if tracked_data.health ~= tracked_data.max_health then
						-- update hacky health counter if required
						tracked_data.health = tracked_data.unit.health
					end

					if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
						tracked_data.shield_health_last_t = tracked_data.shield_health
						tracked_data.last_damage_bar = tick
					end

					tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

					_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health
					_position[2] = tracked_data.height

					rendering.set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, _position)

					_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
					-- _position[2] = tracked_data.height

					rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)

					_position[1] = -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy
					_position[2] = tracked_data.height + BAR_HEIGHT

					rendering.set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, _position)
				-- we don't have any energy, but visual red bar is above current health, shrink it
				elseif tracked_data.shield_health_last > tracked_data.shield_health then
					if tick - tracked_data.last_damage > VISUAL_DAMAGE_BAR_WAIT_TICKS or tick - tracked_data.last_damage_bar > VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX then
						tracked_data.shield_health_last_t = tracked_data.shield_health
						tracked_data.last_damage_bar = tick
					end

					tracked_data.shield_health_last = math_max(tracked_data.shield_health_last_t, tracked_data.shield_health_last - tracked_data.max_health * VISUAL_DAMAGE_BAR_SHRINK_SPEED)

					_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health_last / tracked_data.max_health
					_position[2] = tracked_data.height

					rendering.set_right_bottom(tracked_data.shield_bar_visual, tracked_data.unit, _position)

					_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
					-- _position[2] = tracked_data.height

					rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)
				-- at least, we check connection to any electrical grid
				-- if we are not connected to any electrical grid, stop ticking
				elseif not tracked_data.shield.is_connected_to_electric_network() then
					-- update bars before untracking
					_position[1] = -tracked_data.width + 2 * tracked_data.width * tracked_data.shield_health / tracked_data.max_health
					_position[2] = tracked_data.height

					rendering.set_right_bottom(tracked_data.shield_bar, tracked_data.unit, _position)

					_position[1] = -tracked_data.width
					_position[2] = tracked_data.height + BAR_HEIGHT

					rendering.set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, _position)

					-- remove shield from dirty list if energy empty and is not connected to any power network
					tracked_data.dirty = false
					table.remove(shields_dirty, i)
					lazy_unconnected_self_iter[tracked_data.id] = true
				end
			elseif energy > 0 and energy < tracked_data.max_energy then
				_position[1] = -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy
				_position[2] = tracked_data.height + BAR_HEIGHT

				rendering.set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, _position)

				if not tracked_data.shield.is_connected_to_electric_network() then
					-- remove shield from dirty list if energy half-full/empty and is not connected to any power network
					tracked_data.dirty = false
					table.remove(shields_dirty, i)
					lazy_unconnected_self_iter[tracked_data.id] = true
				end
			else
				destroy_self_bars(tracked_data)

				tracked_data.dirty = false
				table.remove(shields_dirty, i)
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
					tracked_data.last_damage = event.tick
				end

				local health = tracked_data.health
				local shield_health = tracked_data.shield_health

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
					final_damage_amount = final_damage_amount - tracked_data.shield_health
					tracked_data.health = health - final_damage_amount
					final_health = math_max(0, tracked_data.health)
					entity.health = tracked_data.health
					tracked_data.shield_health = 0
				end

				-- not dirty? mark shield generator as dirty
				if not shield_generator.tracked_dirty then
					mark_shield_dirty(shield_generator, event.tick)

				-- shield is dirty but we are not?
				-- mark us as dirty
				elseif not tracked_data.dirty then
					tracked_data.dirty = true
					table_insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
					validate_shielded_bars(tracked_data)
					rendering.set_visible(tracked_data.shield_bar, true)
					rendering.set_visible(tracked_data.shield_bar_bg, true)
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
			lazy_unconnected_self_iter[unit_number] = nil
			validate_self_bars(shield)

			rendering.set_visible(shield.shield_bar, true)
			rendering.set_visible(shield.shield_bar_visual, true)
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

function validate_shielded_bars(data)
	if not data.shield_bar_bg or not rendering.is_valid(data.shield_bar_bg) then
		data.shield_bar_bg = rendering.draw_rectangle({
			color = values.BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {data.width, data.height},
		})
	end

	if not data.shield_bar_visual or not rendering.is_valid(data.shield_bar_visual) then
		data.shield_bar_visual = rendering.draw_rectangle({
			color = values.SHIELD_COLOR_VISUAL,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height},
		})
	end

	if not data.shield_bar or not rendering.is_valid(data.shield_bar) then
		data.shield_bar = rendering.draw_rectangle({
			color = values.SHIELD_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height},
		})
	end
end

function destroy_shielded_bars(data)
	if data.shield_bar_bg and rendering.is_valid(data.shield_bar_bg) then
		rendering.destroy(data.shield_bar_bg)
		data.shield_bar_bg = nil
	end

	if data.shield_bar and rendering.is_valid(data.shield_bar) then
		rendering.destroy(data.shield_bar)
		data.shield_bar = nil
	end

	if data.shield_bar_visual and rendering.is_valid(data.shield_bar_visual) then
		rendering.destroy(data.shield_bar_visual)
		data.shield_bar_visual = nil
	end
end

function bind_shield(entity, shield_provider, tick)
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
		max_health = entity.prototype.max_health * shield_util.max_capacity_modifier(shield_provider.unit.force.technologies),
		unit = entity,
		shield_health = 0, -- how much hitpoints this shield has
		shield_health_last = 0,
		shield_health_last_t = 0,
		-- upper bound by max_health
		unit_number = entity.unit_number,
		dirty = true,

		width = width,
		height = height,

		last_damage = tick,
		last_damage_bar = tick,
	}

	validate_shielded_bars(tracked_data)

	-- tell globally that this entity has it's shield provider
	-- which we can later lookup in shield_generators_hash[shield_provider.id]
	shield_generators_bound[unit_number] = shield_provider.id

	-- register
	-- set tracked_hash index value to index in shield_provider.tracked
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	destroy_remap[script.register_on_entity_destroyed(entity)] = unit_number

	return true
end

local function rebind_shield(tracked_data, shield_provider)
	local unit_number = tracked_data.unit.unit_number

	-- just remap data from one to another
	shield_generators_bound[unit_number] = shield_provider.id
	shield_provider.tracked_hash[unit_number] = table_insert(shield_provider.tracked, tracked_data)

	return true
end

function validate_provider_bars(data)
	if not data.battery_bar_bg or not rendering.is_valid(data.battery_bar_bg) then
		data.battery_bar_bg = rendering.draw_rectangle({
			color = values.BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {data.width, data.height},
		})
	end

	if not data.battery_bar or not rendering.is_valid(data.battery_bar) then
		data.battery_bar = rendering.draw_rectangle({
			color = values.SHIELD_BUFF_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height},
		})
	end

	if not data.provider_radius or not rendering.is_valid(data.provider_radius) then
		data.provider_radius = rendering.draw_circle({
			color = values.SHIELD_RADIUS_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			target = data.unit,
			radius = RANGE_DEF[data.unit.name],
			draw_on_ground = true,
			only_in_alt_mode = true,
		})
	end
end

function destroy_provider_bars(data)
	if data.battery_bar_bg and rendering.is_valid(data.battery_bar_bg) then
		rendering.destroy(data.battery_bar_bg)
		data.battery_bar_bg = nil
	end

	if data.battery_bar and rendering.is_valid(data.battery_bar) then
		rendering.destroy(data.battery_bar)
		data.battery_bar = nil
	end
end

local function on_built_shield_provider(entity, tick)
	if shield_generators_hash[entity.unit_number] then return end -- wut

	destroy_remap[script.register_on_entity_destroyed(entity)] = entity.unit_number

	local width, height = determineDimensions(entity)
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

		-- to be set to dynamic value later
		max_energy = entity.electric_buffer_size,
	}

	validate_provider_bars(data)

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
	mark_shield_dirty(data, tick)
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

local function on_built_shieldable_entity(entity, tick)
	if values.blacklist[entity.name] then return end

	local provider_data = find_closest_provider(entity.force, entity.position, entity.surface)
	if not provider_data then return end

	if bind_shield(entity, provider_data, tick) then
		mark_shield_dirty(provider_data, tick)
	end
end

function validate_self_bars(data)
	if not data.shield_bar_bg or not rendering.is_valid(data.shield_bar_bg) then
		data.shield_bar_bg = rendering.draw_rectangle({
			color = values.BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {data.width, data.height + BAR_HEIGHT},
		})
	end

	if not data.shield_bar_visual or not rendering.is_valid(data.shield_bar_visual) then
		data.shield_bar_visual = rendering.draw_rectangle({
			color = values.SHIELD_COLOR_VISUAL,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height},
		})
	end

	if not data.shield_bar or not rendering.is_valid(data.shield_bar) then
		data.shield_bar = rendering.draw_rectangle({
			color = values.SHIELD_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height - BAR_HEIGHT},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height},
		})
	end

	if not data.shield_bar_buffer or not rendering.is_valid(data.shield_bar_buffer) then
		data.shield_bar_buffer = rendering.draw_rectangle({
			color = values.SHIELD_BUFF_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = data.unit,
			left_top_offset = {-data.width, data.height},
			right_bottom = data.unit,
			right_bottom_offset = {-data.width, data.height + BAR_HEIGHT},
		})
	end
end

function destroy_self_bars(data)
	if data.shield_bar_bg and rendering.is_valid(data.shield_bar_bg) then
		rendering.destroy(data.shield_bar_bg)
		data.shield_bar_bg = nil
	end

	if data.shield_bar and rendering.is_valid(data.shield_bar) then
		rendering.destroy(data.shield_bar)
		data.shield_bar = nil
	end

	if data.shield_bar_visual and rendering.is_valid(data.shield_bar_visual) then
		rendering.destroy(data.shield_bar_visual)
		data.shield_bar_visual = nil
	end

	if data.shield_bar_buffer and rendering.is_valid(data.shield_bar_buffer) then
		rendering.destroy(data.shield_bar_buffer)
		data.shield_bar_buffer = nil
	end
end

local function on_built_shieldable_self(entity, tick)
	local index = entity.unit_number
	if shields[index] then return end -- wut

	destroy_remap[script.register_on_entity_destroyed(entity)] = index

	local width, height = determineDimensions(entity)

	local tracked_data = {
		shield = entity.surface.create_entity({
			-- name = 'shield-generators-interface',
			name = shield_util.turret_interface_name(entity.force.technologies),
			position = entity.position,
			force = entity.force,
		}),

		max_health = entity.prototype.max_health,
		shield_health = 0,
		shield_health_last = 0,
		shield_health_last_t = 0,

		width = width,
		height = height,

		last_damage = tick,
		last_damage_bar = tick,

		health = entity.health,
		unit = entity,
		id = index,

		dirty = true
	}

	validate_self_bars(tracked_data)

	tracked_data.shield.destructible = false
	tracked_data.shield.minable = false
	tracked_data.shield.rotatable = false
	tracked_data.shield.electric_buffer_size = tracked_data.shield.electric_buffer_size * shield_util.turret_capacity_modifier(entity.force.technologies)
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
					destroy_shielded_bars(tracked_data)
					validate_shielded_bars(tracked_data)
				end
			end
		end
	end

	return tracked_data
end

local function on_built(created_entity, tick)
	if RANGE_DEF[created_entity.name] then
		on_built_shield_provider(created_entity, tick)
		return
	end

	if values.allowed_types_self[created_entity.type] and (not created_entity.force or created_entity.force.technologies['shield-generators-turret-shields-basics'].researched) then
		-- create turret shield first
		on_built_shieldable_self(created_entity, tick)
	end

	if values.allowed_types[created_entity.type] then
		-- create provider shield second
		on_built_shieldable_entity(created_entity, tick)
	end

	-- check for poles
	if created_entity.type == 'electric-pole' then
		local pos = created_entity.position
		local area = created_entity.prototype.supply_area_distance

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
				validate_self_bars(tracked_data)
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
		local new_data = on_built_shieldable_self(destination, event.tick)

		new_data.dirty = true
		-- new_data.max_health = old_data.max_health
		new_data.shield_health = old_data.shield_health
		new_data.shield_health_last = old_data.shield_health_last
		new_data.shield_health_last_t = old_data.shield_health_last_t
		new_data.last_damage = old_data.last_damage
		new_data.last_damage_bar = old_data.last_damage_bar
		-- new_data.health = old_data.health

		if old_data.shield.valid then
			new_data.shield.energy = old_data.shield.energy
			new_data.shield.electric_buffer_size = old_data.shield.electric_buffer_size
		end
	elseif RANGE_DEF[destination.name] then
		on_built_shield_provider(destination, event.tick)
	end
end

script.on_event(defines.events.on_entity_cloned, on_entity_cloned)

script.on_event(defines.events.on_built_entity, function(event)
	on_built(event.created_entity, event.tick)
end)

script.on_event(defines.events.script_raised_built, function(event)
	on_built(event.entity, event.tick)
end)

script.on_event(defines.events.script_raised_revive, function(event)
	on_built(event.entity, event.tick)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	on_built(event.created_entity, event.tick)
end)

local function refresh_sentry_shields(force)
	local classname = shield_util.turret_interface_name(force.technologies)
	local modif = shield_util.turret_capacity_modifier(force.technologies)

	local nextindex = #shields_dirty + 1

	for index, tracked_data in pairs(shields) do
		if tracked_data.unit.force == force then
			if tracked_data.shield.name ~= classname then
				local energy = tracked_data.shield.energy
				tracked_data.shield.destroy()

				local shield = tracked_data.unit.surface.create_entity({
					-- name = 'shield-generators-interface',
					name = classname,
					position = tracked_data.unit.position,
					force = tracked_data.unit.force,
				})

				tracked_data.shield = shield

				shield.destructible = false
				shield.minable = false
				shield.rotatable = false
				shield.electric_buffer_size = shield.electric_buffer_size * modif
				tracked_data.max_energy = shield.electric_buffer_size - 1

				shield.energy = energy

				if not tracked_data.dirty then
					tracked_data.dirty = true
					validate_self_bars(tracked_data)
					shields_dirty[nextindex] = tracked_data
					nextindex = nextindex + 1

					rendering.set_visible(tracked_data.shield_bar, true)
					rendering.set_visible(tracked_data.shield_bar_bg, true)
					rendering.set_visible(tracked_data.shield_bar_buffer, true)
				end
			else
				local iface = tracked_data.shield.prototype.electric_energy_source_prototype

				if iface then
					tracked_data.shield.electric_buffer_size = iface.buffer_capacity * modif
					tracked_data.max_energy = tracked_data.shield.electric_buffer_size - 1

					if not tracked_data.dirty then
						tracked_data.dirty = true
						validate_self_bars(tracked_data)
						shields_dirty[nextindex] = tracked_data
						nextindex = nextindex + 1

						rendering.set_visible(tracked_data.shield_bar, true)
						rendering.set_visible(tracked_data.shield_bar_bg, true)
						rendering.set_visible(tracked_data.shield_bar_buffer, true)
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
				on_built_shieldable_self(ent, event.tick)
			end
		end
	elseif event.research.name == 'shield-generators-superconducting-shields' then
		-- this way because i plan expanding it (adding more HP techs)
		local mult = shield_util.max_capacity_modifier(event.research.force.technologies)
		local force = event.research.force

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, event.tick)
			elseif data.unit.force == force then
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.prototype.max_health * mult
				end

				mark_shield_dirty(data, event.tick)
			end
		end
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_cache()
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_sentry_shields(event.research.force)
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
		local mult = shield_util.max_capacity_modifier(event.research.force.technologies)
		local force = event.research.force

		for i = #shield_generators, 1, -1 do
			local data = shield_generators[i]

			if not data.unit.valid then
				on_destroyed(data.id, false, event.tick)
			elseif data.unit.force == force then
				for i2 = 1, #data.tracked do
					data.tracked[i2].max_health = data.tracked[i2].unit.prototype.max_health * mult
					data.tracked[i2].shield_health = math_min(data.tracked[i2].max_health, data.tracked[i2].shield_health)
				end

				mark_shield_dirty(data, event.tick)
			end
		end
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_cache()
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_sentry_shields(event.research.force)
	end
end)

script.on_event(defines.events.on_force_created, function(event)
	rebuild_cache()
end)

script.on_event(defines.events.on_forces_merged, function(event)
	rebuild_cache()
end)

script.on_event(defines.events.on_force_reset, function(event)
	rebuild_cache()
end)

script.on_event(defines.events.on_force_friends_changed, function(event)
	rebuild_cache()
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

		destroy_self_bars(tracked_data)

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

				destroy_shielded_bars(tracked_data)
			end
		end

		for uid, data in pairs(rebound_uids) do
			mark_shield_dirty(data, tick)
		end

		-- destroy tracked data in sequential table
		for i, _data in ipairs(shield_generators) do
			if _data == data then
				table.remove(shield_generators, i)
				break
			end
		end

		destroy_provider_bars(data)

		shield_generators_hash[index] = nil
	elseif shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators_hash[shield_generators_bound[index]]

		if shield_generator then
			-- we got our shield generator data
			-- let's remove us from tracked entities
			local tracked_data = shield_generator.tracked[shield_generator.tracked_hash[index]]

			destroy_shielded_bars(tracked_data)

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
				mark_shield_dirty(shield_generator, tick)
			end
		end

		shield_generators_bound[index] = nil
	end
end

script.on_event(defines.events.on_entity_destroyed, function(event)
	if not destroy_remap[event.registration_number] then return end
	on_destroyed(destroy_remap[event.registration_number], false, event.tick)
	destroy_remap[event.registration_number] = nil
end)
