
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

data:extend({
	{
		type = 'int-setting',
		name = 'shield-generators-joules-per-point',
		setting_type = 'startup',
		default_value = 20000,
		minimum_value = 1,
		order = 'a',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-superconducting-percent',
		setting_type = 'startup',
		default_value = 100.0,
		minimum_value = 1.0,
		order = 'b',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-multiplier',
		setting_type = 'runtime-global',
		default_value = 100.0,
		minimum_value = 1.0,
		order = 'aab',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-hitpoints-base-rate-turret',
		setting_type = 'runtime-global',
		default_value = 10,
		minimum_value = 1,
		order = 'aa',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-hitpoints-base-rate-provider',
		setting_type = 'runtime-global',
		default_value = 15,
		minimum_value = 1,
		order = 'ab',
	},

	{
		type = 'int-setting',
		name = 'shield-generators-turret-charge-base-capacity',
		setting_type = 'startup',
		default_value = 400,
		minimum_value = 1,
		order = 'ac',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-provider-capacity',
		setting_type = 'runtime-global',
		default_value = 1,
		minimum_value = 0.01,
		order = 'ad',
	},

	{
		type = 'bool-setting',
		name = 'shield-generators-keep-interfaces',
		localised_description = {'mod-setting-description.shield-generators-keep-interfaces'},
		setting_type = 'runtime-global',
		default_value = true,
		order = 'b0',
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-basic',
		setting_type = 'runtime-global',
		default_value = 16,
		minimum_value = 1,
		order = 'ba',
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-advanced',
		setting_type = 'runtime-global',
		default_value = 32,
		minimum_value = 1,
		order = 'bb',
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-elite',
		setting_type = 'runtime-global',
		default_value = 64,
		minimum_value = 1,
		order = 'bc',
	},

	{
		type = 'int-setting',
		name = 'shield-generators-provider-range-ultimate',
		setting_type = 'runtime-global',
		default_value = 128,
		minimum_value = 1,
		order = 'bd',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-delay',
		localised_description = {'mod-setting-description.shield-generators-delay'},
		setting_type = 'runtime-global',
		default_value = 2,
		minimum_value = 0.01,
		order = 'ca',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-max-time',
		localised_description = {'mod-setting-description.shield-generators-max-time'},
		setting_type = 'runtime-global',
		default_value = 3,
		minimum_value = 0.01,
		order = 'cb',
	},

	{
		type = 'double-setting',
		name = 'shield-generators-max-speed',
		localised_description = {'mod-setting-description.shield-generators-max-speed'},
		setting_type = 'runtime-global',
		default_value = 3,
		minimum_value = 1,
		order = 'cc',
	},
})
