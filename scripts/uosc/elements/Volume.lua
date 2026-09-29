-- Modified 2026-09-29 by StatIndet: Cupertino volume panel.
-- Derived from uosc 5.13.0; retains its LGPL license (see LICENSES/).
local Element = require('elements/Element')

-- The slider keeps a generous hit area; only its central capsule is painted.
local VolumeSlider = class(Element)
function VolumeSlider:new(props) return Class.new(self, props) end
function VolumeSlider:init(props)
	Element.init(self, 'volume_slider', props)
	self.pressed = false
end

function VolumeSlider:get_visibility() return Elements.volume:get_visibility() end

function VolumeSlider:set_volume(volume)
	volume = round(volume / options.volume_step) * options.volume_step
	volume = clamp(0, volume, state.volume_max)
	if state.volume ~= volume then mp.commandv('set', 'volume', volume) end
end

function VolumeSlider:set_from_cursor()
	local height = self.by - self.ay
	if height <= 0 then return end
	self:set_volume((self.by - cursor.y) / height * state.volume_max)
end

function VolumeSlider:on_global_mouse_move()
	if self.pressed then self:set_from_cursor() end
end
function VolumeSlider:on_global_mouse_leave() self.pressed = false end
function VolumeSlider:handle_wheel_up() self:set_volume(state.volume + options.volume_step) end
function VolumeSlider:handle_wheel_down() self:set_volume(state.volume - options.volume_step) end

function VolumeSlider:render()
	local visibility = self:get_visibility()
	local height = self.by - self.ay
	if visibility <= 0 or height <= 0 or state.volume_max <= 0 then return end

	cursor:zone('primary_down', self, function()
		self.pressed = true
		self:set_from_cursor()
		cursor:once('primary_up', function() self.pressed = false end)
	end)

	local ass = assdraw.ass_new()
	local scale = state.scale
	local cx = (self.ax + self.bx) / 2
	local width = math.min(26 * scale, (self.bx - self.ax) * 0.5)
	local ax, bx = cx - width / 2, cx + width / 2
	local radius = width / 2
	local volume_y = self.by - height * clamp(0, state.volume / state.volume_max, 1)
	local normal_y = self.by - height * math.min(100 / state.volume_max, 1)
	local opacity = visibility * (state.mute and 0.38 or 1)

	-- A continuous capsule, with the same silhouette at every volume.
	ass:rect(ax, self.ay, bx, self.by, {
		color = 'FFFFFF', opacity = visibility * 0.12, radius = radius,
	})
	local function fill(top, bottom, color)
		if bottom <= top then return end
		ass:rect(ax, self.ay, bx, self.by, {
			color = color, opacity = opacity, radius = radius,
			clip = string.format('\\clip(%f,%f,%f,%f)', ax, top, bx, bottom),
		})
	end
	fill(math.max(volume_y, normal_y), self.by, 'F7F3F1')
	fill(volume_y, normal_y, 'FFCA99') -- ASS uses BGR: soft macOS blue.

	-- Small ticks outside the capsule mark unity gain without cutting into it.
	if state.volume_max > 100 then
		local tick_color = state.volume > 100 and not state.mute and 'FFCA99' or 'FFFFFF'
		for _, x in ipairs({ax - 5 * scale, bx + 2 * scale}) do
			ass:rect(x, normal_y - 0.5 * scale, x + 3 * scale, normal_y + 0.5 * scale, {
				color = tick_color, opacity = visibility * 0.55, radius = 0.5 * scale,
			})
		end
	end
	return ass
end

local Volume = class(Element)
function Volume:new() return Class.new(self) end
function Volume:init()
	Element.init(self, 'volume', {render_order = 7})
	-- Paint above the panel explicitly; equal render orders are not stable.
	self.slider = VolumeSlider:new({anchor_id = 'volume', render_order = 7.1})
	self:update_dimensions()
end

function Volume:destroy()
	self.slider:destroy()
	Element.destroy(self)
end

function Volume:get_visibility()
	if not state.is_idle and not state.has_audio then return 0 end
	return self.slider.pressed and 1 or Elements:maybe('timeline', 'get_is_hovered') and -1
		or Element.get_visibility(self)
end

function Volume:update_dimensions()
	local scale = state.scale
	self.size = round(options.volume_size * scale)
	local min_y = Elements:v('top_bar', 'by') or Elements:v('window_border', 'size', 0)
	local max_y = Elements:v('controls', 'ay') or Elements:v('timeline', 'ay')
		or display.height - Elements:v('window_border', 'size', 0)
	local available_height = max_y - min_y
	local height = round(math.min(236 * scale, available_height * 0.8))
	self.enabled = self.size >= 40 * scale and height >= 140 * scale
	local margin = 12 * scale + Elements:v('window_border', 'size', 0)
	self.ax = round(options.volume == 'left' and margin or display.width - margin - self.size)
	self.ay = round(min_y + (available_height - height) / 2)
	self.bx, self.by = self.ax + self.size, self.ay + height
	self.mute_ay = self.by - 40 * scale
	self.slider.enabled = self.enabled
	self.slider:set_coordinates(self.ax + 6 * scale, self.ay + 40 * scale,
		self.bx - 6 * scale, self.mute_ay - 8 * scale)
end

function Volume:on_display() self:update_dimensions() end
function Volume:on_prop_border() self:update_dimensions() end
function Volume:on_prop_title_bar() self:update_dimensions() end
function Volume:on_prop_volume_max() self:update_dimensions() end
function Volume:on_controls_reflow() self:update_dimensions() end
function Volume:on_options() self:update_dimensions() end

function Volume:render()
	local visibility = self:get_visibility()
	if visibility <= 0 then return end
	local scale = state.scale
	cursor:zone('secondary_click', self, function()
		mp.set_property_native('mute', false)
		mp.set_property_native('volume', math.min(100, state.volume_max))
	end)
	cursor:zone('wheel_down', self, function() self.slider:handle_wheel_down() end)
	cursor:zone('wheel_up', self, function() self.slider:handle_wheel_up() end)
	local mute_rect = {ax = self.ax, ay = self.mute_ay, bx = self.bx, by = self.by}
	cursor:zone('primary_down', mute_rect, function() mp.commandv('cycle', 'mute') end)

	local ass = assdraw.ass_new()
	local cx, radius = (self.ax + self.bx) / 2, 20 * scale
	-- A restrained translucent shell; no blur is applied to the video itself.
	ass:rect(self.ax - scale, self.ay, self.bx + scale, self.by + 2 * scale, {
		color = '000000', opacity = visibility * 0.16, radius = radius + scale,
	})
	ass:rect(self.ax, self.ay, self.bx, self.by, {
		color = 'FFFFFF', opacity = visibility * 0.18, radius = radius,
	})
	ass:rect(self.ax + scale, self.ay + scale, self.bx - scale, self.by - scale, {
		color = '202020', opacity = visibility * 0.9, radius = radius - scale,
	})

	local boosted = state.volume > 100 and not state.mute
	local label = tostring(round(state.volume)) .. '%'
	ass:txt(cx, self.ay + 21 * scale, 5, label, {
		font = 'Noto Sans', size = math.min(14 * scale * options.font_scale, self.size / (#label * 0.65)),
		color = boosted and 'FFCA99' or 'F7F3F1', opacity = visibility * (state.mute and 0.5 or 1),
		bold = false,
	})
	local icon = state.mute and 'speaker_slash_fill' or state.volume <= 0 and 'speaker_fill'
		or state.volume <= 60 and 'speaker_1_fill' or 'speaker_3_fill'
	local hovered = not cursor.hidden and cursor.x >= self.ax and cursor.x <= self.bx
		and cursor.y >= self.mute_ay and cursor.y <= self.by
	local icon_y = self.mute_ay + 18 * scale
	if hovered or state.mute then
		ass:circle(cx, icon_y, 15 * scale, {color = 'FFFFFF', opacity = visibility * (hovered and 0.12 or 0.06)})
	end
	ass:icon(cx, icon_y, 21 * scale, icon, {
		color = 'F7F3F1', opacity = visibility * (state.mute and 0.65 or 1),
	})
	return ass
end

return Volume
