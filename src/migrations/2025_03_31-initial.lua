
-- kind of initial state, since i was doing migrations, roughly speaking, wrong.
-- This code basically does what original migration code did,
-- but since it will be run on worlds with mod already installed, we have to assume there may already be data laying around

return function()
	storage.shields = storage.shields or {}
	storage.destroy_remap = storage.destroy_remap or {}
	storage.shield_generators_bound = storage.shield_generators_bound or {}
	storage.shield_generators = storage.shield_generators or {}

	for unumber, data in pairs(shields) do
		if data.unit.valid and data.shield.valid and should_self_shield_tick(data) then
			show_self_shield_bars(data)
		end
	end

	if storage.keep_interfaces == nil then
		storage.keep_interfaces = true
	end

	if not storage.lazy_unconnected_self_iter then
		storage.lazy_unconnected_self_iter = {}

		local lazy_unconnected_self_iter = storage.lazy_unconnected_self_iter

		for unumber, data in pairs(storage.shields) do
			if not data.shield.is_connected_to_electric_network() then
				lazy_unconnected_self_iter[unumber] = true
			end
		end
	end

	if not storage.migrated_98277 then
		for _, data in pairs(storage.shield_generators) do
			if not data.tracked_dirty then
				hide_shield_provider_bars(data)
			end

			if data.tracked then
				for i, tracked_data in ipairs(data.tracked) do
					if not tracked_data.dirty then
						hide_delegated_shield_bars(tracked_data)
					end
				end
			end
		end

		for unumber, tracked_data in pairs(storage.shields) do
			if not tracked_data.dirty and tracked_data.shield.valid and tracked_data.shield.is_connected_to_electric_network() then
				hide_self_shield_bars(tracked_data)
			end
		end

		storage.migrated_98277 = true
	end

	if not storage.delayed_bar_added then
		::RETRY::

		for unumber, data in pairs(storage.shields) do
			if not data.unit.valid then
				report_error('Shielded entity ' .. unumber .. ' is no longer valid, but present in _G.shields... Removing! This might be a bug.')
				on_destroyed(unumber, 0)
				goto RETRY
			end

			data.shield_health_last = data.shield_health_last or data.shield_health
			data.shield_health_last_t = data.shield_health_last_t or data.shield_health

			if data.dirty then
				hide_self_shield_bars(data)
				show_self_shield_bars(data)
			end
		end

		::RETRY2::

		for _, data in pairs(storage.shield_generators) do
			if not data.unit.valid then
				report_error('Shield provider ' .. data.id .. ' is no longer valid, but present in _G.shield_generators... Removing! This might be a bug.')
				on_destroyed(data.id, 0)
				goto RETRY2
			end

			if data.tracked then
				::RETRY3::

				for i, tracked_data in ipairs(data.tracked) do
					if not tracked_data.unit.valid then
						report_error('Shielded entity ' .. tracked_data.unit_number .. ' in provider ' .. data.id .. ' is no longer valid, but present in tracked_data... Removing! This might be a bug.')
						on_destroyed(tracked_data.unit_number, 0)
						goto RETRY3
					end

					tracked_data.shield_health_last = tracked_data.shield_health_last or tracked_data.shield_health
					tracked_data.shield_health_last_t = tracked_data.shield_health_last_t or tracked_data.shield_health

					if tracked_data.dirty then
						hide_delegated_shield_bars(tracked_data)
						show_delegated_shield_bars(tracked_data)
					end
				end
			end
		end
	end

	if not storage.delayed_bar_added2 or not storage.delayed_bar_added3 or not storage.migrated_tick_check then
		storage.delayed_bar_added2 = true
		storage.delayed_bar_added3 = true
		storage.migrated_tick_check = true
		::RETRY::

		for unumber, data in pairs(storage.shields) do
			if not data.unit.valid then
				report_error('Shielded entity ' .. unumber .. ' is no longer valid, but present in _G.shields... Removing! This might be a bug.')
				on_destroyed(unumber, 0)
				goto RETRY
			end

			data.last_damage_bar = data.last_damage_bar or data.last_damage or 0
			data.last_damage = data.last_damage or 0

			if data.dirty then
				hide_self_shield_bars(data)
				show_self_shield_bars(data)
			end
		end

		::RETRY2::

		for _, data in pairs(storage.shield_generators) do
			if not data.unit.valid then
				report_error('Shield provider ' .. data.id .. ' is no longer valid, but present in _G.shield_generators... Removing! This might be a bug.')
				on_destroyed(data.id, 0)
				goto RETRY2
			end

			if data.tracked then
				::RETRY3::

				for i, tracked_data in ipairs(data.tracked) do
					if not tracked_data.unit.valid then
						report_error('Shielded entity ' .. tracked_data.unit_number .. ' in provider ' .. data.id .. ' is no longer valid, but present in tracked_data... Removing! This might be a bug.')
						on_destroyed(tracked_data.unit_number, 0)
						goto RETRY3
					end

					tracked_data.last_damage_bar = tracked_data.last_damage_bar or tracked_data.last_damage or 0
					tracked_data.last_damage = tracked_data.last_damage or 0

					if tracked_data.dirty then
						hide_delegated_shield_bars(tracked_data)
						show_delegated_shield_bars(tracked_data)
					end
				end
			end
		end
	end
end
