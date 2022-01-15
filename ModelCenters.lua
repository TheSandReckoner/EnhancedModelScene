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

local ModelCenters = {}
EnhancedModelScene.ModelCenters = ModelCenters

local self = ModelCenters

-- manually determined centers
self.model_centers = {
	[397940] = {.5, -.5, .5}, -- axis test object
	[1100258] = {-.060, -.034, 1.034}, 	-- female blood elf
	[1022598] = {-.139, .026, 1.264}, 	-- female draenei
	[1630402] = {-.334, .010, 1.454}, 	-- female highmountain tauren
	[1593999] = {-.137, .028, 1.277}, 	-- female lightforged draenei
	[986648] = {-.359, .007, 1.393}, 	-- female tauren
	[1890759] = {-.264, -.027, .733}, 	-- female vulpera
	[307453] = {-.080, -.043, 1.251}, 	-- female worgen
	[1100087] = {-.043, -.040, 1.090}, 	-- male blood elf
	[1005887] = {-.277, -.112, 1.322}, 	-- male draenei
	[1630218] = {-0.181, -.014, 1.731}, -- male highmountain tauren
	[1620605] = {-.277, -.112, 1.341}, 	-- male lightforged draenei
	[968705] = {-.135, -.013, 1.715}, 	-- male tauren
	[1890761] = {-.260, -.025, .779}, 	-- male vulpera
	[307454] = {.061, .018, 1.213}, 	-- male worgen
}

--	the ADDON_LOADED handler will take care of self.saved_centers

-- TODO: checking if if the defaults gain a center listing that the user already had, and estimate accuracy


function ModelCenters:SetCenter(file, x, y, z)
	--self.saved_centers = self.saved_centers or {}
	self.saved_centers[file] = {x, y, z}
end

-- FIXME:
--EnhancedModelScene.model_centers = EnhancedModelScene.ModelCenters.model_centers


function ModelCenters:GetCenterFor(file)
	local x, y, z = 0, 0, 0
	
	local m = self.saved_centers[file] or self.model_centers[file]

	if m then
		x, y, z = m[1] or x, m[2] or y, m[3] or z
		
		--[[local a = m[animation]
		
		if a then
			x, y, z = a.x or x, a.y or y, a.z or z
		end]]
	end
	
	return x, y, z
end

--[[
function EnhancedModelScene:SetCenterGuess(actor, x, y, z)
	local file, animation = actor:GetModelFileID(), actor:GetAnimation()
	print("SCG", file, animation, x, y, z)
	
	self.model_centers[file][animation or 0] = { x = x, y = y, z = z}
end
]]
