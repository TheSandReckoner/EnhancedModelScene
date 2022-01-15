--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local addon_name, addon_table = ...
local EMS = addon_table.self
local EnhancedModelScene = EMS

if not EMS then return end

local self = {}
local ModelDB = self
EnhancedModelScene.ModelDB = self

self.files = {}

for line in addon_table.modelfiles:gmatch("[^\n]+") do
	local index, file = line:match("(%d+);(.+)")
	
	self.files[tonumber(index)] = { fullname = file }
end

