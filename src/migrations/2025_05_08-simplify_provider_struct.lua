
-- initial iteration of shield structures was me coming from LuaJIT land
-- but after checking sources for PUC Lua, i think my optimizations here are overkill
-- and actually evil.
-- so, let's fix that
return function()
	-- get rid of shield_generators / shield_generators_hash separation (always use unit number as index)
	-- this is because, as it appears, Wube Lua uses linked hash map, so pairs() iteration order is as same as
	-- insertion order
	local copy = assert(storage.shield_generators, 'Panic: missing storage.shield_generators')
	storage.shields_generators = {}

	-- build dirty list from savegame
	for i = 1, #copy do
		local data = copy[i]
		storage.shields_generators[data.id] = data
	end

	for index, data in pairs(storage.shields_generators) do
		if not data.tracked then
			report_error(string.format('Unable to migrate shield generator with index %d due to missing vital structures', index))
			goto CONTINUE
		end

		data.unit_number = data.id
		data.id = nil
		data.ticking = data.tracked_dirty ~= nil
		local copy = data.tracked
		data.tracked = {}
		data.tracked_hash = nil -- кыш отсюдова

		-- transform "tracked" into hashtable
		for _, child in ipairs(copy) do
			data.tracked[child.unit_number] = child
			child.ticking = child.dirty
			child.dirty = nil
		end

		local dirty = data.tracked_dirty
		data.tracked_dirty = {}

		if dirty then
			-- transform "tracked_dirty" from index list to hashtable
			for _, index in ipairs(dirty) do
				local child = copy[index]
				data.tracked_dirty[child.unit_number] = child
			end
		end

		data.tracked_dirty_num = table_size(data.tracked_dirty)
		::CONTINUE::
	end

	-- get rid of "pointer indices" of shield_generators_bound and use references directly
	copy = assert(storage.shield_generators_bound, 'Panic: missing storage.shield_generators_bound')
	storage.shield_generators_bound = {}

	for unumber, id in pairs(copy) do
		storage.shield_generators_bound[unumber] = assert(storage.shields_generators[id], 'Panic: Save is missing shield generator with ID ' .. id)
	end
end
