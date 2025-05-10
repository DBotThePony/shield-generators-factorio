
-- use local table for script listeners to avoid implementing multiple listeners as recursive call tree
local hooks = {}

local function dispatch2(events)
	local fn0 = events[1]
	local fn1 = events[2]

	return function(event)
		fn0(event)
		fn1(event)
	end
end

local function dispatch3(events)
	local fn0 = events[1]
	local fn1 = events[2]
	local fn2 = events[3]

	return function(event)
		fn0(event)
		fn1(event)
		fn2(event)
	end
end

local function dispatch4(events)
	local fn0 = events[1]
	local fn1 = events[2]
	local fn2 = events[3]
	local fn3 = events[4]

	return function(event)
		fn0(event)
		fn1(event)
		fn2(event)
		fn3(event)
	end
end

local function dispatchN(events)
	local n = #events

	return function(event)
		for i = 1, n do
			events[i](event)
		end
	end
end

local function createHookContext(callback)
	local hookTable = {}

	return function(fn)
		assert(
			type(fn) == 'function' or
			type(fn) == 'table' and getmetatable(fn) ~= nil and getmetatable(fn).__call ~= nil
		, 'Event listener must be something callable, ' .. type(fn) .. ' given')

		local events = #hookTable

		table.insert(hookTable, fn)

		if events == 0 then
			callback(fn)
		elseif events == 1 then
			callback(dispatch2(hookTable))
		elseif events == 2 then
			callback(dispatch3(hookTable))
		elseif events == 3 then
			callback(dispatch4(hookTable))
		else
			callback(dispatchN(hookTable))
		end
	end
end

local function doHook(event, fn)
	local context = hooks[event]

	if not context then
		context = createHookContext(function(dispatcher)
			script.on_event(event, dispatcher)
		end)

		hooks[event] = context
	end

	context(fn)
end

-- wrapper for allowing multiple event listeners to listen for event
-- generally for avoiding having separate file for "event listeners"
function script_hook(event, fn)
	if type(event) == 'table' then
		for _, e in ipairs(event) do
			doHook(e, fn)
		end
	else
		doHook(event, fn)
	end
end

do
	local globalSetupFuncs = {}
	local globalInitFuncs = {}

	function on_setup_globals(fn)
		assert(type(fn) == 'function', 'provided argument was not a function (' .. type(fn) .. ')')
		table.insert(globalSetupFuncs, fn)
	end

	function on_init_globals(fn)
		assert(type(fn) == 'function', 'provided argument was not a function (' .. type(fn) .. ')')
		table.insert(globalInitFuncs, fn)
	end

	function setup_globals()
		for _, fn in ipairs(globalSetupFuncs) do
			fn()
		end
	end

	function init_globals()
		for _, fn in ipairs(globalInitFuncs) do
			fn()
		end
	end
end

on_built_entity = createHookContext(function(dispatcher)
	script.on_event(defines.events.on_built_entity, dispatcher, CONSTANTS.filter_types)
	script.on_event(defines.events.script_raised_built, dispatcher, CONSTANTS.filter_types)
	script.on_event(defines.events.script_raised_revive, dispatcher, CONSTANTS.filter_types)
	script.on_event(defines.events.on_robot_built_entity, dispatcher, CONSTANTS.filter_types)
end)

-- on_destroyed hook table
do
	local callbacks = {}
	local destroy_remap
	local n = 0

	function listen_on_destroyed(fn)
		n = n + 1
		callbacks[n] = fn
	end

	function on_destroyed(index, tick)
		for i = 1, n do
			callbacks[i](index, tick)
		end
	end

	on_init_globals(function()
		storage.destroy_remap = {}
	end)

	on_setup_globals(function()
		destroy_remap = assert(storage.destroy_remap)
	end)

	script_hook(defines.events.on_object_destroyed, function(event)
		if not destroy_remap[event.registration_number] then return end
		on_destroyed(destroy_remap[event.registration_number], event.tick)
		destroy_remap[event.registration_number] = nil
	end)

	function track_entity_destruction(entity)
		destroy_remap[script.register_on_object_destroyed(entity)] = entity.unit_number
	end
end
