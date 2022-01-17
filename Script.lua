--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local addon_name, addon_table = ...
local EnhancedModelScene = addon_table.self
local EMS = EnhancedModelScene

if not EMS then return end

local Script = {}
EnhancedModelScene.Script = Script

Script.running_scripts = {}


function Script:Loop(script)
	for line in script:gmatch("[^\n]+") do
		-- FIXME: check for a comment character, and maybe add a rem command
		EMS:DispatchCommand(line)
	end
	
	print("done executing script")
end


function Script:Run(script)
	-- use coroutine.create rather than wrap, because we can 
	-- probably continue to the next line after an error
	-- Or maybe implement error catching in the loop function?
	local thread = coroutine.create(function() Script:Loop(script) end)
	tinsert(self.running_scripts, thread)
	
	-- FIXME: error handling
	function sleep_handler()
		local status, sleep_duration = coroutine.resume(thread)
		
		if status and sleep_duration then
			C_Timer.After(sleep_duration, sleep_handler)
		end
	end
	
	sleep_handler()
end


Script.test_script = [[
walk 1 1
sleep 1
turn 1 1
sleep 2
turn 1 0
walk 1 0
anim 1 60
sleep 2
anim 1 0
]]

Script.demo = [[
-- make sure there are at least three actors
minactors 3
hideall
set 1 player
undressslot 1 mainhand
setfile 2 3870811
setfile 3 3996870
OPS 1 0 0 0 -5.5 0 0 1
OPS 2 0 0 0 0 0 0 .9
OPS 3 90 0 0 -2.5 -6 .4 .5
show 1 2 3
setcamera 250 25 0 0 5 3 5
sleep 3
walk 1 1
sleep 1
-- this will need to be updated after working on the turn command
turn 1 1
sleep 1
turn 1 -1
sleep 1
turn 1 0
-- ending position will be affected by framerate with the current turn implementation
getpos 1
sleep .5
walk 1 0
sleep 1
-- sample first item
anim 1 61
sleep 2
anim 1 0
sleep 1
turn 1 -2
sleep 0.785
turn 1 0
-- should be close, but manually set the yaw
yaw 1 -90
walk 1 1
sleep 2.5
walk 1 0
turn 1 1.57
sleep 1
turn 1 0
sleep .5
-- pass on second item
anim 1 186
sleep 2
turn 1 -1.57
sleep 1
turn 1 0
yaw 1 -90
walk 1 1
sleep 2
walk 1 0
sleep 1
-- sample third item
anim 1 63
sleep 1
anim 1 61
sleep 2
anim 1 0
]]