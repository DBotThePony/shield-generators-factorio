
-- derative
local shields_dirty = {}

-- storage
local shields
local shield_generators_bound
local lazy_unconnected_self_iter

-- cahce
local turret_speed_cache

-- imports
local math_min = math.min
local math_max = math.max
local util = util

local CONSUMPTION_PER_HITPOINT = CONSUMPTION_PER_HITPOINT
local values = CONSTANTS

on_init_globals(function()
	storage.shields = {}
	storage.lazy_unconnected_self_iter = {}
	storage.keep_interfaces = settings.global['shield-generators-keep-interfaces'].value
end)

on_setup_globals(function()
	shields = assert(storage.shields)
	shield_generators_bound = assert(storage.shield_generators_bound)
	lazy_unconnected_self_iter = assert(storage.lazy_unconnected_self_iter)

	local nextindex = 1

	-- build dirty list for self shielding entities from savegame
	for unumber, data in pairs(shields) do
		if should_self_shield_tick(data) then
			-- data.dirty = true
			shields_dirty[nextindex] = data
			nextindex = nextindex + 1
		end
	end
end)

function should_self_shield_tick(data)
	return data.dirty or data.shield_health < data.max_health or data.shield.valid and data.shield.energy < data.max_energy
end

function rebuild_turret_shield_speed_cache()
	if not game then return end
	turret_speed_cache = {}

	local turret = settings.global['shield-generators-hitpoints-base-rate-turret'].value / 60

	for forcename, force in pairs(game.forces) do
		turret_speed_cache[forcename] = util.turret_recovery_speed_modifier(force.technologies) * turret
	end
end

script_hook({
	defines.events.on_force_created,
	defines.events.on_forces_merged,
	defines.events.on_force_reset,
	defines.events.on_force_friends_changed,
}, rebuild_turret_shield_speed_cache)

local selfMap

function shield_to_self_map()
	if not selfMap then
		selfMap = {}

		for unumber, data in pairs(shields) do
			if data.shield.valid then
				selfMap[data.shield.unit_number] = data
			end
		end
	end

	return selfMap
end

script_hook(defines.events.on_runtime_mod_setting_changed, function(event)
	if event.setting == 'shield-generators-hitpoints-base-rate-turret' then
		rebuild_turret_shield_speed_cache()
	end

	if event.setting == 'shield-generators-multiplier' then
		refresh_self_shields_max_health(nil, event.tick)
	end

	if storage.keep_interfaces ~= settings.global['shield-generators-keep-interfaces'].value then
		storage.keep_interfaces = settings.global['shield-generators-keep-interfaces'].value

		if storage.keep_interfaces then
			::RETRY::

			for unumber, data in pairs(shields) do
				if not data.unit.valid then
					report_error('Shielded entity ' .. unumber .. ' is no longer valid, but present in _G.shields... Removing! This might be a bug.')
					on_destroyed(unumber, 0)
					goto RETRY
				end

				if not data.shield.valid then
					local entity = data.unit

					data.shield = entity.surface.create_entity({
						name = util.turret_interface_name(entity.force.technologies),
						position = entity.position,
						force = entity.force,
					})

					if selfMap then
						selfMap[data.shield.unit_number] = data
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
					on_destroyed(unumber, 0)
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
							table.insert(shields_dirty, data)
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
end)

function refresh_self_shields_max_health(force, tick)
	local nextDirtyIndex = #shields_dirty + 1

	if force == nil then
		local mults = {}

		for name, force in pairs(game.forces) do
			mults[name] = util.max_capacity_modifier_self(force.technologies)
		end

		for _, data in pairs(shields) do
			local old = data.max_health
			data.max_health = data.unit.max_health * mults[data.unit.force.name]
			data.shield_health = math_min(data.shield_health, data.max_health)

			if old < data.max_health and not data.dirty then
				data.dirty = true
				shields_dirty[nextDirtyIndex] = data
				show_self_shield_bars(data)
				nextDirtyIndex = nextDirtyIndex + 1
			end
		end
	else
		local mult = util.max_capacity_modifier_self(force.technologies)

		for _, data in pairs(shields) do
			local old = data.max_health
			data.max_health = data.unit.max_health * mult
			data.shield_health = math_min(data.shield_health, data.max_health)

			if old < data.max_health and not data.dirty then
				data.dirty = true
				shields_dirty[nextDirtyIndex] = data
				show_self_shield_bars(data)
				nextDirtyIndex = nextDirtyIndex + 1
			end
		end
	end
end

function create_self_shield(entity, tick)
	if values.self_blacklist[entity.name] then return end
	local index = entity.unit_number
	if shields[index] or entity.max_health <= 0 then return end -- wut
	track_entity_destruction(entity)

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
	table.insert(shields_dirty, tracked_data)

	shield_to_self_map()[tracked_data.shield.unit_number] = tracked_data

	-- case: we got self shield after getting shield from shield provider
	-- update bars for them to not overlap with ours
	if shield_generators_bound[index] then -- entity under shield generator destroyed
		local shield_generator = shield_generators_bound[index]

		if shield_generator then
			local tracked_data = shield_generator.tracked[index]

			if tracked_data then
				tracked_data.height = tracked_data.height + values.BAR_HEIGHT * 2

				if tracked_data.shield_bar then
					hide_delegated_shield_bars(tracked_data)
					show_delegated_shield_bars(tracked_data)
				end
			end
		end
	end

	return tracked_data
end

function begin_ticking_self_shield(shield)
	if shield.dirty then return end

	shield.dirty = true
	table.insert(shields_dirty, shield)

	if not shield.shield.valid then
		local entity = shield.unit

		shield.shield = entity.surface.create_entity({
			name = util.turret_interface_name(entity.force.technologies),
			position = entity.position,
			force = entity.force,
		})

		if selfMap then
			selfMap[shield.shield.unit_number] = shield
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

	lazy_unconnected_self_iter[shield.id] = nil
	show_self_shield_bars(shield)
end

function refresh_turret_shields(force)
	local classname = util.turret_interface_name(force.technologies)
	local modif = util.turret_capacity_modifier(force.technologies)

	local nextindex = #shields_dirty + 1

	for index, tracked_data in pairs(shields) do
		if tracked_data.unit.force ~= force then goto CONTINUE end

		if not tracked_data.shield.valid or tracked_data.shield.name ~= classname then
			local energy =
				tracked_data.disabled and tracked_data.energy or
				tracked_data.shield.valid and tracked_data.shield.energy or
				tracked_data.shield_energy or 0

			if selfMap and tracked_data.shield.valid then
				selfMap[tracked_data.shield.unit_number] = nil
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

			if selfMap then
				selfMap[shield.unit_number] = tracked_data
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

		::CONTINUE::
	end
end

-- BUILDING
on_built_entity(function(event)
	local created_entity, tick = event.entity, event.tick

	if
		values.allowed_types_self[created_entity.type] and
		(not created_entity.force or created_entity.force.technologies['shield-generators-turret-shields-basics'].researched)
	then
		-- create turret shield first
		create_self_shield(created_entity, tick)
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

		local shield_to_self_map = shield_to_self_map()

		for i, ent in ipairs(found) do
			local tracked_data = shield_to_self_map[ent.unit_number]

			-- if we hit a self-shield that is idle and not energy full, wake it up
			if tracked_data and not tracked_data.dirty and tracked_data.unit.valid and ent.energy < tracked_data.max_energy then
				tracked_data.dirty = true
				table.insert(shields_dirty, tracked_data)
				lazy_unconnected_self_iter[tracked_data.id] = nil
				show_self_shield_bars(tracked_data)
			end
		end
	end
end)

-- CLONING
local iface_name_length = #'shield-generators-interface'

local function destroy_shield(index, tick)
	-- entity with internal shield destroyed
	if shields[index] then
		local tracked_data = shields[index]

		if tracked_data.shield and tracked_data.shield.valid then
			shield_to_self_map()[tracked_data.shield.unit_number] = nil
		else
			report_error('Unexpected self shield deletion of now deleted unit ' .. index .. '. Getting around it is slow!')

			local shield_to_self_map = shield_to_self_map()

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

		if shield_generators_bound[index] then
			local child = shield_generators_bound[index].tracked[index]

			if child then
				child.height = child.height - values.BAR_HEIGHT * 2

				if child.shield_bar then
					hide_delegated_shield_bars(child)
					show_delegated_shield_bars(child)
				end
			end
		end
	end
end

listen_on_destroyed(destroy_shield)

script_hook(defines.events.on_entity_cloned, function(event)
	local source = event.source
	local destination = event.destination

	if string.sub(source.name, 1, iface_name_length) == 'shield-generators-interface' then
		destination.destroy()
	elseif shields[source.unit_number] then
		local old_data = shields[source.unit_number]
		local new_data = create_self_shield(destination, event.tick)

		if not new_data then return end

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
	end
end)

-- RESEARCH
script_hook(defines.events.on_research_finished, function(event)
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
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_turret_shields(event.research.force)
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_turret_shield_speed_cache()
	end
end)

script_hook(defines.events.on_research_reversed, function(event)
	if event.research.name == 'shield-generators-turret-shields-basics' then
		for name, surface in pairs(game.surfaces) do
			local found = surface.find_entities_filtered({
				force = event.research.force,
				type = values._allowed_types_self,
			})

			local tick = event.tick

			for i, ent in ipairs(found) do
				destroy_shield(ent.unit_number, tick)
			end
		end
	end

	if values.SENTRY_REBUILD_TRIGGERS[event.research.name] then
		refresh_turret_shields(event.research.force)
	end

	if values.TECH_REBUILD_TRIGGERS[event.research.name] then
		rebuild_turret_shield_speed_cache()
	end
end)

local VISUAL_DAMAGE_BAR_SHRINK_SPEED = values.VISUAL_DAMAGE_BAR_SHRINK_SPEED
local VISUAL_DAMAGE_BAR_WAIT_TICKS = values.VISUAL_DAMAGE_BAR_WAIT_TICKS
local VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX = values.VISUAL_DAMAGE_BAR_WAIT_TICKS_MAX
local set_right_bottom = set_right_bottom
local lerp = util.lerp

-- TICK
function tick_self_shields(tick, delay, max_time, max_speed)
	-- since inside on_load LuaEntities are invalid
	-- we have to do this on next game tick
	local shield_to_self_map = shield_to_self_map()

	if not turret_speed_cache then
		rebuild_turret_shield_speed_cache()
	end

	do
		local _value

		if storage.lazy_key ~= nil and not lazy_unconnected_self_iter[storage.lazy_key] then
			storage.lazy_key = nil
		end

		storage.lazy_key, _value = next(lazy_unconnected_self_iter, storage.lazy_key)

		if not _value then
			storage.lazy_key, _value = next(lazy_unconnected_self_iter)
		end

		local i = 0

		while i < 5 and _value do
			i = i + 1
			local _data = shields[storage.lazy_key]

			if _data then
				local _shield = _data.shield

				if _shield.valid then
					if _shield.is_connected_to_electric_network() then
						_data.dirty = true
						show_self_shield_bars(_data)
						table.insert(shields_dirty, _data)
						local currnet = storage.lazy_key
						storage.lazy_key, _value = next(lazy_unconnected_self_iter, storage.lazy_key)
						lazy_unconnected_self_iter[currnet] = nil
					end
				else
					local currnet = storage.lazy_key
					storage.lazy_key, _value = next(lazy_unconnected_self_iter, storage.lazy_key)
					lazy_unconnected_self_iter[currnet] = nil
					break
				end
			else
				local currnet = storage.lazy_key
				storage.lazy_key, _value = next(lazy_unconnected_self_iter, storage.lazy_key)
				lazy_unconnected_self_iter[currnet] = nil
				break
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
					set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy, tracked_data.height + values.BAR_HEIGHT)
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
					set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width, tracked_data.height + values.BAR_HEIGHT)

					-- remove shield from dirty list if energy empty and is not connected to any power network
					tracked_data.dirty = false
					table.remove(shields_dirty, i)

					if not tracked_data.disabled then
						lazy_unconnected_self_iter[tracked_data.id] = true
					end
				end
			elseif energy < tracked_data.max_energy then
				set_right_bottom(tracked_data.shield_bar_buffer, tracked_data.unit, -tracked_data.width + 2 * tracked_data.width * energy / tracked_data.max_energy, tracked_data.height + values.BAR_HEIGHT)

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
			on_destroyed(tracked_data.id, tick)

			if shields_dirty[i] == tracked_data then
				table.remove(shields_dirty, i)
			end
		end
	end
end
