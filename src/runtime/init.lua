
local migration_names = {
	'2025_03_31-initial'
}

local migrations = {}

for _, name in ipairs(migration_names) do
	table_insert(migrations, require('__shield-generators__/src/migrations/' .. name))
end

function are_mod_structures_up_to_date()
	if not storage.mod_structures_migrations then return false end

	for _, name in ipairs(migration_names) do
		if not storage.mod_structures_migrations[name] then return false end
	end

	return true
end

script.on_init(function()
	storage.mod_structures_migrations = {}

	for i, migrate in ipairs(migrations) do
		local name = migration_names[i]
		storage.mod_structures_migrations[name] = true
		log('Applying migration: ' .. name)
		migrate()
	end

	storage.keep_interfaces = settings.global['shield-generators-keep-interfaces'].value

	setup_globals()
end)

script.on_load(function()
	setup_globals()
end)

script.on_configuration_changed(function()
	storage.mod_structures_migrations = storage.mod_structures_migrations or {}

	for i, name in ipairs(migration_names) do
		if not storage.mod_structures_migrations[name] then
			log('Applying migration: ' .. name)
			local migrate = migrations[i]
			migrate()
		end
	end

	setup_globals()
end)
