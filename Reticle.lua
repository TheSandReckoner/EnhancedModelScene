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

local Reticle = {}
EnhancedModelScene.Reticle = Reticle


function Reticle:NewCrosshairs(x, y)
	local crosshairs = EMS:CreateTexture(nil, "BACKGROUND")
	crosshairs:SetAllPoints()
	crosshairs:SetColorTexture(0, 0, 0, 0)
	-- FIXME: idea is to have a Hide etc on this to use

	tinsert(self, crosshairs)
	
	local thickness = 2 -- 	TODO: figure out appropriate thicktness. 1 disappears sometimes for me (small laptop screen)
	
	crosshairs.horizontal = EMS:CreateTexture(nil, "BACKGROUND", nil, 1)
	crosshairs.horizontal:SetSize(GetScreenWidth(), thickness)
	crosshairs.horizontal:SetColorTexture(0, 0, 1)
	
	crosshairs.vertical = EMS:CreateTexture(nil, "BACKGROUND", nil, 1)
	crosshairs.vertical:SetSize(thickness, GetScreenHeight())
	crosshairs.vertical:SetColorTexture(0, 0, 1)
	
	function crosshairs:SetPosition(x, y)
		crosshairs.vertical:SetPoint("BOTTOM", nil, "BOTTOMLEFT", x, 0)
		crosshairs.horizontal:SetPoint("LEFT", nil, "BOTTOMLEFT", 0, y)
	end
	
	function crosshairs:SetColor(r, g, b, a)
		self.vertical:SetColorTexture(r, g, b, a)
		self.horizontal:SetColorTexture(r, g, b, a)
	end
	
	function crosshairs:Hide()
		self.vertical:Hide()
		self.horizontal:Hide()
	end
	
	function crosshairs:Show()
		self.vertical:Show()
		self.horizontal:Show()
	end
	
	function crosshairs:Update(elapsed)
		if self.follow then
			local t = self.follow
			local ftype, subtype = t.type, t.subtype
			local wx, wy, wz, sx, sy
			
			if ftype == "cursor" then
				sx, sy = GetCursorPosition()
			elseif ftype == "camera" then
				if subtype == "target" then
					wx, wy, wz = EMS:GetCameraTarget()
				else
					print(("unrecognized subtype '%s' for reticle follow type 'camera'"):format(subtype))
				end
			elseif ftype == "actor" then
				local actor = EMS:GetActorAtIndex(t.index)
				
				-- TODO: make this something we can just pass to ActorMixin to handle the logic
				if subtype == "position" then
					wx, wy, wz = actor:GetScaledPosition()
				elseif subtype == "center" then
					wx, wy, wz = actor:GetCenterPosition()
				elseif subtype == "point" then
					wx, wy, wz = actor:GetPoint("world", t.point)
				else
					-- TODO: support coordinates in model space
					print(("unrecognized subtype '%s' for reticle follow type 'actor'"):format(subtype))
				end
			end
					
			if wx then
				sx, sy = EMS:Project3DPointTo2D(wx, wy, wz)
			end
			
			if sx then
				self:SetPosition(sx, sy)
			end
		end
	end
	
	if x and y then
		crosshairs:SetPosition(x, y)
	end
	
	return crosshairs
end


function Reticle:UpdateAll(elapsed)
	for i, reticle in ipairs(self) do
		reticle:Update(elapsed)
	end
end
