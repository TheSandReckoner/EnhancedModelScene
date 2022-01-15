--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021-2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local EnhancedModelScene = select(2, ...).self

if not EnhancedModelScene then return end

local cos, sin = math.cos, math.sin


local CameraMixin = {}
EnhancedModelScene.CameraMixin = CameraMixin

function CameraMixin:LockCameraTo(n, transform)
	local a = self:GetActorAtIndex(n)
	self:SetCameraTarget(a:GetCenterPosition())
	local inverse = a:GetCenterMatrix():GetInverse()
	self.camera_transform = self.Matrix.hmult(inverse, transform or self:GetCameraMatrix())
	self.camera_relative_to = n
end


function CameraMixin:UnlockCamera(n)
end


function CameraMixin:GetCameraOrientation()
	return EnhancedModelScene.Matrix.YPR(self.yaw, self.pitch, self.roll)
end


function CameraMixin:GetCameraMatrix()
	local m = self:GetCameraOrientation()
	m:SetTranslation(self:GetCameraPosition())
	return m
end


function CameraMixin:GetCameraTransformFromTarget()
	local m = self:GetCameraMatrix()
	local tx, ty, tz = self:GetCameraTarget()
	m:SubtractTranslation(self:GetCameraTarget())
end


function CameraMixin:ApplyMatrixToCameraFromTarget(m)
	local tx, ty, tz = self:GetCameraTarget()
	self.yaw, self.pitch, self.roll = m:GetYPR()
	local x, y, z = m[10], m[11], m[12]
	self:SetCameraPosition(tx + m[10], ty + m[11], tz + m[12])
	self.r = math.sqrt(x*x + y*y + z*z)
	-- TODO: clear update flags
	self:UpdateCamera()
end


function CameraMixin:ApplyMatrixToCamera(m)
	self.yaw, self.pitch, self.roll = m:GetYPR()
	local x, y, z = m[10], m[11], m[12]
	self:SetCameraPosition(x, y, z)
	self.r = math.sqrt(x*x + y*y + z*z)
	-- TODO: clear update flags
	self:UpdateCamera()
end


function CameraMixin:ApplyCameraTransform()
	local a = self:GetActorAtIndex(self.camera_relative_to)
	self:SetCameraTarget(a:GetCenterPosition()) -- in case it has moved
	local m = a:GetCenterMatrix()
	
	local out = self.Matrix.hmult(m, self.camera_transform)
	self:ApplyMatrixToCamera(out)
end

-- keep camera position, change orientation and target (including r)
function CameraMixin:TurnCameraTowardPoint(x, y, z)
end


-- TODO: maybe add a function to keep camera orientiation and target offset, 
-- but relative to a new point. Get and pass the matrix?



function CameraMixin:ApplyCameraPreset(i)
	-- FIXME: change from temp hardcoding to configurable per set
	
	-- r, yaw, pitch, [roll]
	local presets = {
		}
	
end


function CameraMixin:FocusActor(actor)
	-- convenience function
	-- maybe add offset option later
	
	self.active_model = actor
	
	-- move camera
	self.update_target = true
	self.tx, self.ty, self.tz = self:GetActorAtIndex(actor):GetPosition()
end


function CameraMixin:SaveCamera(index)
	local s = self.saved_cameras or {}
	self.saved_cameras = s
	
	local c = {}
	c.pos = { self:GetCameraPosition() }
	c.ori = { self.yaw, self.pitch, self.roll }
	
	s[index or 1] = c
	
	print("saved to camera", index)
end


function CameraMixin:RestoreCamera(index)
	local c = self.saved_cameras[index]
	
	if not c then return end
	
	self:SetCameraPosition(unpack(c.pos))
	self:SetCameraOrientationByYawPitchRoll(unpack(c.ori))
	-- FIXME: don't the fields need to be updated to stay in sync?
	
	print("restored camera", index)
end


function CameraMixin:ClearCamera(index)
	self.saved_cameras[index] = nil
end


function CameraMixin:SwapCamera(index)
	local c = self.saved_cameras[index]
	
	self:SaveCamera(index)
	
	self:SetCameraPosition(unpack(c.pos))
	self:SetCameraOrientationByYawPitchRoll(unpack(c.ori))
	
	print("swapped camera", index)
end


function CameraMixin:UpdateCamera()
	local x, y, z = self:GetCameraTarget()

	local r = self.r
	
	local a, b = self.yaw, self.pitch
	local ca, cb = cos(a), cos(b)
	local sa, sb = sin(a), sin(b)
	
	x, y, z = x - r*ca*cb, y - r*sa*cb, z + r*sb
	self:SetCameraPosition(x, y, z)
	self:SetCameraOrientationByYawPitchRoll(a, b, self.roll or 0)
	
	self.r_changed = false
	
	if self.camera_target then
		-- update the camera target marker
		self.camera_target:SetScaledPosition(self:GetCameraTarget())
	end
end


function CameraMixin:GetCameraTarget()
	if self.update_target then
		local x, y, z = self:GetCameraPosition()
		local r = self.r
		
		local a, b = self.yaw, self.pitch
		local ca, cb = cos(a), cos(b)
		local sa, sb = sin(a), sin(b)
		
		self.update_target = false
		self.tx, self.ty, self.tz = x + r * ca*cb, y + r*sa*cb, z - r*sb
	end
	
	return self.tx, self.ty, self.tz
end


function CameraMixin:SetCameraTarget(x, y, z)
	self.update_r = true
	self.tx, self.ty, self.tz = x, y, z
	self.update_target = nil
	-- FIXME: update camera position / orientation?
end


-- Change the camera's target while keeping the current orientation and orbit distance
function CameraMixin:ShiftCameraTarget(x, y, z)
end


function CameraMixin:ResetCamera()
	self.tx, self.ty, self.tz = 0, 0, 1
	self.yaw, self.pitch, self.roll = math.pi, 0, 0
	self.r = 4
	self.r_changed = true
	self:UpdateCamera()
end


-- position the camera to look down the x-axis (but don't change target)
function CameraMixin:LookDownX()
	self.yaw, self.pitch, self.roll = math.pi, 0, 0
	self:UpdateCamera()
end


function CameraMixin:LookDownY()
	self.yaw, self.pitch, self.roll = -math.pi/2, 0, 0
	self:UpdateCamera()
end


function CameraMixin:LookDownZ()
	self.yaw, self.pitch, self.roll = 0, math.pi/2, 0
	self:UpdateCamera()
end


function CameraMixin:GetCameraYPRDegrees()
	return deg(self.yaw), deg(self.pitch), deg(self.roll)
end


function CameraMixin:GetCameraDistance()
	return self.r
end
