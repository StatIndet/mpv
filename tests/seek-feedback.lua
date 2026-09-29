-- Run from repository root: lua tests/seek-feedback.lua
local time, timer, seek, bindings, events = 0, nil, nil, {}, {}
local overlay = {update=function() end, remove=function(self) self.data='' end}
local fake = {
 create_osd_overlay=function() return overlay end,
 get_time=function() return time end,
 get_osd_size=function() return 1280,720 end,
 get_property_bool=function() return false end,
 command=function(command) assert(command:match('^no%-osd seek .+ relative%+exact$')) end,
 add_periodic_timer=function(_,cb) timer={tick=cb,kill=function(self) self.killed=true end}; return timer end,
 register_script_message=function(_,cb) seek=cb end,
 add_key_binding=function(_,name,cb) bindings[name]=cb end,
 register_event=function(name,cb) events[name]=cb end,
}
package.preload.mp=function() return fake end
package.preload['mp.assdraw']=function() return {ass_new=function()
 return setmetatable({text=''}, {__index=function(_,key)
  if key=='append' then return function(self,s) self.text=self.text..s end end
  return function() end
 end})
end} end
 dofile('scripts/seek_feedback.lua')
seek('5');time=.1;seek('5');time=.2;seek('5');time=.3;timer.tick()
assert(overlay.data:find('+15',1,true), 'same-direction seeks must accumulate')
bindings.back10();time=.4;timer.tick()
assert(overlay.data:find('−10',1,true), 'reversing direction must reset accumulation')
time=1.3;timer.tick();assert(overlay.data=='' and timer.killed)
bindings.forward5();events['end-file']();assert(overlay.data=='')
print('PASS: accumulation, reversal, silent seek, timed dismissal and end-file cleanup')
