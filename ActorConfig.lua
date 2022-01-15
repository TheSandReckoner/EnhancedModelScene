-- for managing actor configurations that aren't currently associated with an actor

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

local ActorConfig = {}
EnhancedModelScene.ActorConfig = ActorConfig


function ActorConfig:GetCenterMatrixFromConfig(config)
	local yaw, pitch, roll = 0, 0, 0
	if config.ypr then
		yaw, pitch, roll = unpack(config.ypr)
	end

	local scale = 1
	if config.scale then
		scale = config.scale
	end
	
	local x, y, z = 0, 0, 0
	if config.pos then
		x, y, z = unpack(config.pos)
	end
	
	-- center coordinates, in model space
	local cx, cy, cz = 0, 0, 0
	if config.center then
		cx, cy, cz = unpack(config.center)
	end
	
	-- assume config and Matrix ypr are in the same angle units
	local m = EMS.Matrix.YPR(yaw, pitch, roll)
	m:Scale(scale)  	-- this will adjust the axis columns as needed
	m:SetTranslation(x, y, z)
	m:AddTranslation(scale * cx, scale * cy, scale * cz)
	
	return m
end
