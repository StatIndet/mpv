-- SPDX-License-Identifier: MIT
-- Compact directional seek feedback with cumulative seconds and flowing chevrons.
local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local overlay = mp.create_osd_overlay('ass-events')
local direction, total, started, last = 1, 0, 0, -math.huge
local timer
local function clear()
    if timer then timer:kill(); timer = nil end
    overlay:remove()
    total, last = 0, -math.huge
end
local function render()
    local now = mp.get_time()
    local age = now - last
    if age >= 0.85 then clear(); return end
    local w, h = mp.get_osd_size()
    if w <= 0 or h <= 0 then return end
    local scale = math.max(0.75, math.min(h / 720, 1.5))
    local enter = 1 - (1 - math.min((now - started) / 0.16, 1)) ^ 3
    local leave = 1 - math.max(0, (age - 0.5) / 0.35) ^ 2
    local opacity = enter * leave
    local x = direction > 0 and w - 36 * scale or 36 * scale
    x = x - direction * (1 - enter) * 9 * scale
    local y = h / 2
    local ass = assdraw.ass_new()
    local function style(alpha)
        ass:new_event()
        ass:append(string.format('{\\an7\\pos(0,0)\\bord0\\shad0\\1c&HFFFFFF&\\1a&H%02X&}', math.floor(255 * (1-alpha))))
    end
    -- Three narrow chevrons light in sequence toward the seek direction.
    for i = 0, 2 do
        local phase = ((now - started) / 0.42 - i * 0.18) % 1
        local light = 0.2 + 0.8 * math.sin(phase * math.pi) ^ 4
        local cx = x + direction * (i - 1) * 6 * scale
        style(opacity * light)
        ass:draw_start()
        ass:move_to(cx - direction*3*scale, y - 6*scale)
        ass:line_to(cx + direction*2*scale, y)
        ass:line_to(cx - direction*3*scale, y + 6*scale)
        ass:line_to(cx - direction*5*scale, y + 4.5*scale)
        ass:line_to(cx - direction*1*scale, y)
        ass:line_to(cx - direction*5*scale, y - 4.5*scale)
        ass:draw_stop()
    end
    ass:new_event()
    local tx = x - direction * 23 * scale
    ass:append(string.format('{\\an%d\\pos(%f,%f)\\fnNoto Sans\\fs%f\\bord0.5\\3c&H303030&\\shad0\\1c&HFFFFFF&\\alpha&H%02X&}%s%d',
        direction > 0 and 6 or 4, tx, y, 20*scale, math.floor(255*(1-opacity)), direction > 0 and '+' or '−', total))
    overlay.res_x, overlay.res_y, overlay.data = w, h, ass.text
    overlay:update()
end
local function seek(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds == 0 or mp.get_property_bool('idle-active') then return end
    local now, dir = mp.get_time(), seconds > 0 and 1 or -1
    if now - last > 0.5 or dir ~= direction then total, started = 0, now end
    direction, total, last = dir, total + math.abs(seconds), now
    mp.command('no-osd seek ' .. seconds .. ' relative+exact')
    if not timer then timer = mp.add_periodic_timer(1/60, render) end
    render()
end
mp.register_script_message('seek', seek)
for name, seconds in pairs({back5=-5, forward5=5, back10=-10, forward10=10}) do
    local amount = seconds
    mp.add_key_binding(nil, name, function() seek(amount) end, {repeatable=true})
end
mp.register_event('end-file', clear)
mp.register_event('shutdown', clear)
