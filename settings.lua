
data:extend({
	{
		type = 'int-setting',
		name = 'shield-generators-joules-per-point',
		setting_type = 'startup',
		default_value = 20000,
		minimum_value = 1,
	},

	{
		type = 'double-setting',
		name = 'shield-generators-turret-charge-base-rate',
		setting_type = 'startup',
		default_value = 15,
		minimum_value = 1
	},

	{
		type = 'int-setting',
		name = 'shield-generators-turret-charge-base-capacity',
		setting_type = 'startup',
		default_value = 200,
		minimum_value = 1
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-basic',
		setting_type = 'runtime-global',
		default_value = 16,
		minimum_value = 1
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-advanced',
		setting_type = 'runtime-global',
		default_value = 32,
		minimum_value = 1
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-elite',
		setting_type = 'runtime-global',
		default_value = 64,
		minimum_value = 1
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-ultimate',
		setting_type = 'runtime-global',
		default_value = 128,
		minimum_value = 1
	},
})
