-- The Immersion module handles functionality involving player involvement in a scene, eg. movement, camera, collision.

--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021-2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local EnhancedModelScene = select(2, ...).self
local EMS = EnhancedModelScene

if not EMS then return end

local Immersion = CreateFrame("Frame", nil, EnhancedModelScene)
EnhancedModelScene.Immersion = Immersion

Immersion:SetAllPoints(EnhancedModelScene)


function Immersion:OnShow()
	--self:SetAllPoints(EnhancedModelScene)
	print("setting EMS Immersion bindings")
	self:SetBindings()
end


function Immersion:OnHide()
	self:ClearBindings()
end


function Immersion:SetBindings()
	if UnitAffectingCombat("player") then
		-- FIXME: queue to set after combat, but allow canceling
		print("can't set Immersion bindings in combat")
		return
	end
	
	-- NOTE: commands must also be added to Bindings.xml
	-- TODO: maybe warn when a copy is requested for an absent binding
	self:CopyBindings("MOVEFORWARD")
	self:CopyBindings("MOVEBACKWARD")
	self:CopyBindings("TURNLEFT")
	self:CopyBindings("TURNRIGHT")
	self:CopyBindings("STRAFELEFT")
	self:CopyBindings("STRAFERIGHT")
end


function Immersion:ClearBindings()
	ClearOverrideBindings(self)
end


-- set an override binding on this frame matching the assigned keys for command
-- TODO: allow list?
function Immersion:CopyBindings(command)
	local keys = {GetBindingKey(command)}
	
	for _, key in pairs(keys) do
		SetOverrideBinding(self, false, key, "EMS_" .. command)
		--print("SetOverrideBinding", key, "EMS_" .. command)
	end
end


function Immersion:RunCommand(...)
	--print("received command", ...)
	local command, keystate = ...
	
	local index = EMS:GetCurrentActorIndex()
	local actor = EMS:GetCurrentActor()
	
	if command == "MOVEFORWARD" or command == "MOVEBACKWARD" then
		if keystate == "down" then
			local speed = 2
			
			if command == "MOVEBACKWARD" then
				speed = -1
			end
			
			self.moving = true
			
			-- Send current position to ensure in sync
			-- TODO: lower bandwidth option when position already synced?
			EMS:SendSyncCommand(("pos %i %f %f %f"):format(index, actor:GetScaledPosition()))
			EMS:DispatchCommand(("walk %i %f"):format(index, speed))
		elseif keystate == "up" then
			self.moving = false
			
			EMS:DispatchCommand(("walk %i 0"):format(index))
			-- send the final position directly since timing won't be perfect
			EMS:SendSyncCommand(("pos %i %f %f %f"):format(index, actor:GetScaledPosition()))
		end
	elseif command == "STRAFELEFT" or command == "STRAFERIGHT" then
		local a = EMS:GetCurrentActor()
		local v = {0, 0, 1}  -- rotate around world Z
		local angle = 0
		
		-- FIXME: send sync commands
			
		if keystate == "down" then
			speed = 1
			self.moving = true
			
			-- undo current strafing
			if self.strafing then
				angle = 90
				
				if self.strafing == "left" then
					angle = -90
				end
			end
			
			if command == "STRAFELEFT" then
				self.strafing = "left"
				angle = angle + 90
			else
				self.strafing = "right"
				angle = angle - 90
			end
			
			if angle ~= 0 then
				a:RotateDegrees(angle, unpack(v))
			end
			
			EMS:DispatchCommand(("walk %i %f"):format(index, speed))
		elseif keystate == "up" then
			self.moving = false -- FIXME: if also moving forward/back
			
			EMS:DispatchCommand(("walk %i 0"):format(index))
			
			-- undo current strafing
			if self.strafing then
				angle = 90
				
				if self.strafing == "left" then
					angle = -90
				end
				
				self.strafing = nil
				a:RotateDegrees(angle, unpack(v))
			end
		end
	elseif command == "TURNLEFT" or command == "TURNRIGHT" then
		if keystate == "down" then
			local speed = 2
			
			if command == "TURNRIGHT" then
				speed = -speed
			end
			
			self.turning = true
			
			EMS:SendSyncCommand(("ypr %i %f %f %f"):format(index, actor:GetYPRDeg()))
			EMS:DispatchCommand(("turn %i %f"):format(index, speed))
		elseif keystate == "up" then
			self.turning = false
			EMS:DispatchCommand(("turn %i 0"):format(index))
			EMS:SendSyncCommand(("ypr %i %f %f %f"):format(index, actor:GetYPRDeg()))
		end
	end
end


-- is this not needed anymore?
function Immersion:OnUpdate(elapsed)
	if self.moving then
		local actor = EMS:GetCurrentActor()
		actor:SlideOnAxis(1, elapsed * actor.move_speed)
	end
	
	if self.turning then
		-- FIXME:
		local a = EMS:GetCurrentActor()
		local initial = a:GetRotationMatrix()
		local rotation = EMS.Matrix.AngleAxis(elapsed * a.turn_speed, initial:GetBasisVector(tonumber(3)))
		
		a:SetOrientation(EMS.Matrix.hmult(rotation, initial))
	end
end


function Immersion:UpdateActorAnimation()
	local actor = EMS:GetCurrentActor()
	
	if self.moving then
		if actor.move_speed > 0 then
			actor:SetAnimation(4)
		else
			actor:SetAnimation(13)
		end
	elseif self.turning then
		if actor.turn_speed > 0 then
			actor:SetAnimation(11)
		else
			actor:SetAnimation(12)
		end
	else
		actor:SetAnimation(0)
	end
end


do
	local self = Immersion
	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)
	--self:SetScript("OnUpdate", self.OnUpdate)
	
	self:Hide() -- start hidden
end
