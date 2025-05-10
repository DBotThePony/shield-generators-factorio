
local initial_version = 0
local migration_names = {
	'2025_04_08-migrate_drawables',
	'2025_03_31-initial',
	'',
	'2025_05_08-simplify_provider_struct',
}

local migrations = require('__migratus-orchestrus__/init.lua')()

for i, name in ipairs(migration_names) do
	if name == '' then
		migrations.add_migration_function(i + initial_version, function() end)
	else
		migrations.add_migration_path(i + initial_version, '__shield-generators__/src/migrations/' .. name)
	end
end

migrations.on_setup_globals(setup_globals)

script.on_init(function()
	init_globals()
	migrations.on_init()
end)

script.on_load(function()
	migrations.on_load()
end)

script.on_configuration_changed(function()
	if storage.mod_structures_migrations then
		for i, name in ipairs(migration_names) do
			if storage.mod_structures_migrations[name] then
				migrations.bump_version(i + initial_version)
			end
		end

		storage.mod_structures_migrations = nil
	end

	migrations.on_configuration_changed()
end)
