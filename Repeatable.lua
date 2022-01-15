--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local _, addon_table = ...
local EnhancedModelScene = addon_table.self

if not EnhancedModelScene then return end

local Repeatable = {}
EnhancedModelScene.Repeatable = Repeatable


function Repeatable.Slide(self, steps)
	steps = steps or 1
	
	self.actor:SlideOnAxis(self.axis, steps * self.distance)
end


function Repeatable.New(func)
	local repeatable = {}
	
	repeatable.func = func
	
	function repeatable:Do(...)
		self:func(...)
	end
	
	return repeatable
end
