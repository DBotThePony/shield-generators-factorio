
-- derative
local shield_generators_hash = shield_generators_hash

-- storage
local shields
local shield_generators_bound

-- imports
local tick_self_shields = tick_self_shields
local tick_shield_providers = tick_shield_providers
local report_error = report_error
local math_min = math.min
local math_max = math.max

on_setup_globals(function()
	shields = assert(storage.shields)
	shield_generators_bound = assert(storage.shield_generators_bound)
end)

script_hook(defines.events.on_tick, function(event)
	local tick = event.tick

	local delay = settings.global['shield-generators-delay'].value * 60
	local max_time = settings.global['shield-generators-max-time'].value * 60
	local max_speed = settings.global['shield-generators-max-speed'].value

	tick_shield_providers(tick, delay, max_time, max_speed)
	tick_self_shields(tick, delay, max_time, max_speed)
end)

local function player_select_area(event)
	if event.item ~= 'shield-generator-switch' then return end
	local shield_to_self_map = shield_to_self_map()

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
				table.insert(shields_dirty, shield)
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
				table.insert(shield_generators_dirty, shield)
			end
		end
	end
end

script_hook(defines.events.on_player_selected_area, player_select_area)
script_hook(defines.events.on_player_alt_selected_area, player_select_area)

script.on_event(defines.events.on_entity_damaged, function(event)
	local entity, final_damage_amount = event.entity, event.final_damage_amount
	local final_health

	local unit_number = entity.unit_number

	-- bound shield generator provider
	-- process it before self shield
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
					table.insert(shield_generator.tracked_dirty, shield_generator.tracked_hash[unit_number])
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

		begin_ticking_self_shield(shield)
	end
end, CONSTANTS.filter_types)
