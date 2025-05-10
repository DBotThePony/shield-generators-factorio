
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

require('__shield-generators__/values')

require('__shield-generators__/src/runtime/hook')
require('__shield-generators__/src/runtime/visual_functions')
require('__shield-generators__/src/runtime/runtime_utils')

-- derative globals
_G.shield_generators_bound = {}
_G.shield_generators_dirty = {}
_G.shields_dirty = {}

-- joules per hitpoint
_G.CONSUMPTION_PER_HITPOINT = settings.startup['shield-generators-joules-per-point'].value

require('__shield-generators__/src/runtime/shields_provider')
require('__shield-generators__/src/runtime/shields_self')
require('__shield-generators__/src/runtime/shields_common')
require('__shield-generators__/src/runtime/init')
