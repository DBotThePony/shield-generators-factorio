
-- handle the case when migration can be applied both by game and by our script (situation where mods get added to existing save)
if not is_migration_applied('2025_03_31-initial') then
	require('__shield-generators__/src/migrations/2025_03_31-initial')()
end

-- this is required for situation where mod is added to existing save, because in such case
-- when new migration is added, this must be moved to that, because this function must be called the last
setup_globals()
