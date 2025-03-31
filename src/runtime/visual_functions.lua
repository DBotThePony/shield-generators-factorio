
local values = CONSTANTS
local BAR_HEIGHT = values.BAR_HEIGHT
local BACKGROUND_COLOR = values.BACKGROUND_COLOR
local SHIELD_COLOR_VISUAL = values.SHIELD_COLOR_VISUAL
local SHIELD_COLOR = values.SHIELD_COLOR
local SHIELD_BUFF_COLOR = values.SHIELD_BUFF_COLOR
local SHIELD_RADIUS_COLOR = values.SHIELD_RADIUS_COLOR

function show_self_shield_bars(data)
	if not data.shield_bar_bg or not data.shield_bar_bg.valid then
		data.shield_bar_bg = assert(rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {data.width, data.height + BAR_HEIGHT}},
		}), 'Unable to create renderable object')
	end

	if not data.shield_bar_visual or not data.shield_bar_visual.valid then
		data.shield_bar_visual = assert(rendering.draw_rectangle({
			color = SHIELD_COLOR_VISUAL,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {-data.width, data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.shield_bar or not data.shield_bar.valid then
		data.shield_bar = assert(rendering.draw_rectangle({
			color = SHIELD_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {data.width * (2 * data.shield_health / data.max_health - 1), data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.shield_bar_buffer or not data.shield_bar_buffer.valid then
		data.shield_bar_buffer = assert(rendering.draw_rectangle({
			color = SHIELD_BUFF_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height}},
			right_bottom = {
				entity = data.unit,
				offset = {
					data.width * (2 * (
					(data.disabled or not data.shield.valid) and data.shield_energy or data.shield.energy) /
					(data.max_energy or data.shield.valid and data.shield.electric_buffer_size > 0 and data.shield.electric_buffer_size or 0xFFFFFFFF) - 1),

					data.height + BAR_HEIGHT
				},
			},
		}), 'Unable to create renderable object')
	end
end

function hide_self_shield_bars(data)
	if data.shield_bar_bg then
		data.shield_bar_bg.destroy()
		data.shield_bar_bg = nil
	end

	if data.shield_bar then
		data.shield_bar.destroy()
		data.shield_bar = nil
	end

	if data.shield_bar_visual then
		data.shield_bar_visual.destroy()
		data.shield_bar_visual = nil
	end

	if data.shield_bar_buffer then
		data.shield_bar_buffer.destroy()
		data.shield_bar_buffer = nil
	end
end

function show_shield_provider_bars(data)
	if not data.battery_bar_bg or not data.battery_bar_bg.valid then
		data.battery_bar_bg = assert(rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {data.width, data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.battery_bar or not not data.battery_bar.valid then
		data.battery_bar = assert(rendering.draw_rectangle({
			color = SHIELD_BUFF_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {-data.width, data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.provider_radius or not data.provider_radius.valid then
		data.provider_radius = assert(rendering.draw_circle({
			color = SHIELD_RADIUS_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			target = data.unit,
			radius = RANGE_DEF[data.unit.name],
			draw_on_ground = true,
			only_in_alt_mode = true,
		}), 'Unable to create renderable object')
	end
end

function hide_shield_provider_bars(data)
	if data.battery_bar_bg then
		data.battery_bar_bg.destroy()
		data.battery_bar_bg = nil
	end

	if data.battery_bar then
		data.battery_bar.destroy()
		data.battery_bar = nil
	end
end

function show_delegated_shield_bars(data)
	if not data.shield_bar_bg or not data.shield_bar_bg.valid then
		data.shield_bar_bg = assert(rendering.draw_rectangle({
			color = BACKGROUND_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {data.width, data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.shield_bar_visual or not data.shield_bar_visual.valid then
		data.shield_bar_visual = assert(rendering.draw_rectangle({
			color = SHIELD_COLOR_VISUAL,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {-data.width, data.height}},
		}), 'Unable to create renderable object')
	end

	if not data.shield_bar or not data.shield_bar.valid then
		data.shield_bar = assert(rendering.draw_rectangle({
			color = SHIELD_COLOR,
			forces = {data.unit.force},
			filled = true,
			surface = data.unit.surface,
			left_top = {entity = data.unit, offset = {-data.width, data.height - BAR_HEIGHT}},
			right_bottom = {entity = data.unit, offset = {-data.width, data.height}},
		}), 'Unable to create renderable object')
	end
end

function hide_delegated_shield_bars(data)
	if data.shield_bar_bg then
		data.shield_bar_bg.destroy()
		data.shield_bar_bg = nil
	end

	if data.shield_bar then
		data.shield_bar.destroy()
		data.shield_bar = nil
	end

	if data.shield_bar_visual then
		data.shield_bar_visual.destroy()
		data.shield_bar_visual = nil
	end
end
