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

local ActorMixin = {}
EnhancedModelScene.ActorMixin = ActorMixin

-- make the mixin global to use in a template
EMS_ActorMixin = ActorMixin

-- FIXME: change to warn about unimplemented feature and show trace, but allow continuing
local warning = error


function ActorMixin:GetRelativeMatrix(reference)
	local inverse = reference:GetCenterMatrix():GetInverse()
	return EnhancedModelScene.Matrix.hmult(inverse, self:GetCenterMatrix())
end


function ActorMixin:GetScaledCenterOffset()
	local x, y, z = self:GetRawCenter()
	local s = self:GetScale()
	
	return s*x, s*y, s*z
end


function ActorMixin:GetAngles()
	return self:GetYaw(), self:GetPitch(), self:GetRoll()
end


function ActorMixin:GetRotationMatrix()
	-- TODO: maybe just return YPR and check if the matrix is actually needed
	return EnhancedModelScene.Matrix.YPR(self:GetYaw(), self:GetPitch(), self:GetRoll())
end


function ActorMixin:GetYPR()
	return self:GetYaw(), self:GetPitch(), self:GetRoll()
end


function ActorMixin:GetYPRDeg()
	return self:GetYPRDegrees()
end


function ActorMixin:GetYPRDegrees()
	return deg(self:GetYaw()), deg(self:GetPitch()), deg(self:GetRoll())
end


function ActorMixin:SetYPR(yaw, pitch, roll)
	self:SetYaw(yaw)
	self:SetPitch(pitch)
	self:SetRoll(roll)
end


function ActorMixin:SetYPRDegrees(yaw, pitch, roll)
	self:SetYaw(rad(yaw))
	self:SetPitch(rad(pitch))
	self:SetRoll(rad(roll))
end


function ActorMixin:GetCenterMatrix()
	local m = self:GetRotationMatrix()
	m:Scale(self:GetScale())
	m:SetTranslation(self:GetScaledPosition())
	return m:AddTranslation(self:GetScaledCenterOffset())
end


function ActorMixin:SetOrientation(m)
	local yaw, pitch, roll = m:GetYPR()
	
	self:SetYaw(yaw)
	self:SetPitch(pitch)
	self:SetRoll(roll)
end

--[[
function ActorMixin:SetYPR(yaw, pitch, roll)
	local y, p, r = self:GetYPR()
	
	-- allow omitting angles, to be filled in with current values
	yaw, pitch, roll = yaw or y, pitch or p, roll or r
	
	if yaw == y and pitch == p and roll == r then
		print("YPR unchanged")
		return
	end
	
	if self.pivot then
		-- check if we need to recalculate the anchor
		if self.pivot_last_ts ~= self:GetPosition() then
			
		
]]


function ActorMixin:SetCenterTransform(m)
	-- set scale first so the center can be placed correctly
	self:SetScale(m:GetScale())
	local x, y, z = m:GetXYZ()
	self:SetCenterPosition(x, y, z)
	
	self:SetOrientation(m)
end



function ActorMixin:GetScaledPosition()
	local x, y, z = self:GetPosition()
	local s = self:GetScale()
	return s*x, s*y, s*z
end


ActorMixin.GetXYZ = ActorMixin.GetScaledPosition


function ActorMixin:SetScaledPosition(x, y, z)
	local s = self:GetScale()
	self:SetPosition(x/s, y/s, z/s)
end


function ActorMixin:SetCenterPosition(x, y, z)
	local cx, cy, cz = self:GetScaledCenterOffset()
	self:SetScaledPosition(x - cx, y - cy, z - cz)
end


function ActorMixin:GetRawCenter()
	--return EnhancedModelScene:GetRawCenterFor(self:GetModelFileID(), self.animation)
	return self:GetActiveBoundingBoxCenter()
end


function ActorMixin:GetCenterPosition()
	-- appears to be affected by scale but not orientation
	local x, y, z = self:GetScaledPosition()
	local s = self:GetScale()
	
	local a, b, c = self:GetRawCenter()
	x, y, z = x+s*a, y+s*b, z+s*c
	
	return x, y, z
end


function ActorMixin:SlideOnAxis(axis, distance)
	local x, y, z = self:GetRotationMatrix():GetBasisVector(axis)
	self:Slide(x, y, z, distance)
end


function ActorMixin:Slide(x, y, z, scale)
	local xi, yi, zi = self:GetScaledPosition()
	self:SetScaledPosition(xi + x * scale, yi + y * scale, zi + z * scale)
end


function ActorMixin:ConvertToTransform(relative_to)
end


function ActorMixin:GetKey()
	-- FIXME
	--return self.key
	
end


-- Sets the model to pivot around a point.
function ActorMixin:SetPivot(space, x, y, z)
	if space == "center" then
		self.pivot = {x, y, z}
	elseif space == "shift" or space == "model" then
		local cx, cy, cz = self:GetRawCenter()
		self.pivot = {x - cx, y - cy, z - cz}
	elseif space == "world" then
		warning("NYI")
	end
	
	self.pivot_last_p = {}
	self.pivot_last_R = self:GetRotationMatrix()
end


function ActorMixin:ClearPivot()
	self.pivot = nil
	self.use_pivot = false
end


function ActorMixin:EnablePivot()
	self.use_pivot = true
end


function ActorMixin:DisablePivot()
	self.use_pivot = false
end


-- Returns the pivot coordinates in center-space
function ActorMixin:GetPivotCS()
	if self.pivot then
		return unpack(self.pivot)
	else
		-- FIXME: warn or log
		return nil
	end
end


function ActorMixin:UpdatePivot()
	if not self:GetPivotCS() then
		return
	end
	
	local lx, ly, lz = unpack(self.pivot_last_p)
	local px, py, pz = self:GetPosition()
	
	local cx, cy, cz = self:GetRawCenter()
	
	local ax, ay, az
	
	-- FIXME: tolerance?
	if not self.anchor or lx ~= px or ly ~= py or lz ~= pz then
		--print("recalculating anchor")
		--print("old position:", lx, ly, lz)
		--print("new position:", px, py, pz)
		-- model has been moved; need to recalculate
		-- p_w = t + s*c + s*R*p_c
		-- p_w/s = a = t/s + c + R*p_c
		
		-- get pivot in shift-space in the previous rotation
		local rx, ry, rz = self.pivot_last_R:TransformLooseVector(self:GetPivotCS())

		-- calculate the anchor based on the old orientation but new position
		ax, ay, az = px + cx + rx, py + cy + ry, pz + cz + rz
		self.anchor = {ax, ay, az}
	end
	
	-- assume this has only been called if a recalculation is appropriate
	-- calculate the new position needed to hold the anchor in place
	ax, ay, az = self:GetAnchor()
	
	local R = self:GetRotationMatrix()
	
	local rx, ry, rz = R:TransformLooseVector(self:GetPivotCS())
	
	local tx, ty, tz = ax-cx-rx, ay-cy-ry, az-cz-rz
	
	-- save the calculated position, to check if anchor stays valid
	-- GetPosition will return slightly different values from what we used in SetPosition, so call it instead of using our values
	--self.pivot_last_p = {tx, ty, tz}
	self.pivot_last_R = R
	
	self:SetPosition(tx, ty, tz)
	self.pivot_last_p = {self:GetPosition()}
end


function ActorMixin:GetAnchor()
	if not self.anchor then
		return nil
	end
	
	--[[
	if self.anchor_reference then
		-- the model was moved while an anchor was set, so translate the anchor
		local ax, ay, az = unpack(self.anchor)
		local bx, by, bz = unpack(self.anchor_reference)
		local cx, cy, cz = self:GetPosition()
		print(("recalculating anchor: model moved from %f %f %f to %f %f %f"):format(bx, by, bz, cx, cy, cz))
		self.anchor = { ax - bx + cx, ay - by + cy, az - bz + cz }
	end]]
	
	return unpack(self.anchor)
end


-- TODO: maybe add function to directly get axis unit vectors


function ActorMixin:AddPhasor(phasor)
	if not self.phasors then self.phasors = {} end
	tinsert(self.phasors, phasor)
end


function ActorMixin:NewPhasor(...)
	self:AddPhasor(EnhancedModelScene.Phasor.New(...))
end


function ActorMixin:UpdatePhasors(elapsed)
	if self.phasors then
		for i = 1, #self.phasors do
			self.phasors[i]:Update(elapsed)
			self.phasors[1]:Apply()
		end
	end
end


function ActorMixin:PickAnimation()
	local animation
	
	if self.move_speed and self.move_speed ~= 0 then
		if self.move_speed > 0 then
			animation = 4
		else
			animation = 13
		end
	elseif self.turn_speed and self.turn_speed ~= 0 then
		if self.turn_speed > 0 then
			animation = 11
		else
			animation = 12
		end
	else
		--print("move speed is 0, strafing is", EMS.Immersion.strafing)
		
		-- FIXME: change to property of actor, for encapsulation and multi-user
		if EMS.Immersion and EMS.Immersion.strafing then
			if EMS.Immersion.strafing == "left" then
				-- briefly show the turning-right animation
				-- TODO: set animations by name for clarity
				animation = 11
			else
				animation = 12
			end
			
			C_Timer.After(.5, function() self:PickAnimation() end)
		else
			animation = 0
		end
	end
	
	if animation ~= self.animation then
		self:SetAnimation(animation)
	end
end


function ActorMixin.SetAnimation(actor, animation, variation, speed, offset)
	actor.animation, actor.variation, actor.speed, actor.offset = animation, variation, speed, offset
	-- TODO: switch from above to subtable
	actor.current_animation = { animation = animation, variation = variation, speed = speed, offset = offset }
	getmetatable(actor).__index.SetAnimation(actor, animation, variation, speed, offset)
end


function ActorMixin:GetCurrentAnimation()
	local t = self.current_animation or {}
	return t.animation, t.variation, t.speed, t.offset
end


-- probably don't need this anymore...
function ActorMixin:SetPosition(...)
	-- if the model is moved while an anchor is set, save information to recalculate later
	if self.anchor and not self.anchor_reference then
		self.anchor_reference = {self:GetPosition()}
	end
	
	getmetatable(self).__index.SetPosition(self, ...)
end


function ActorMixin:DressFromLink(link)
	local items = C_TransmogCollection.GetItemTransmogInfoListFromOutfitHyperlink(link)
	
	for slot, t in ipairs(items) do
		self:TryOn(t.appearanceID, slot)
	end
end


function ActorMixin:GetMaxBoundingBoxCenter()
	local x1, y1, z1, x2, y2, z2 = self:GetMaxBoundingBox()
	
	return (x1+x2)/2, (y1+y2)/2, (z1+z2)/2
end


function ActorMixin:GetActiveBoundingBoxCenter()
	local x1, y1, z1, x2, y2, z2 = self:GetActiveBoundingBox()
	
	return (x1+x2)/2, (y1+y2)/2, (z1+z2)/2
end



function ActorMixin:GetPointInModelSpace(point)
	point = point:lower()
	
	if point == "maxbound1" then
		local x, y, z = self:GetMaxBoundingBox()
		return x, y, z
	elseif point == "maxbound2" then
		return select(4, self:GetMaxBoundingBox())
	elseif point == "activebound1" then
		local x, y, z = self:GetActiveBoundingBox()
		return x, y, z
	elseif point == "activebound2" then
		return select(4, self:GetActiveBoundingBox())
	elseif point == "max_bound_center" or point == "maxboundcenter" then
		return self:GetMaxBoundingBoxCenter()
	elseif point == "active_bound_center" or point == "activeboundcenter" then
		return self:GetActiveBoundingBoxCenter()
	elseif point == "center" then
		return self:GetRawCenter()
	end
end


function ActorMixin:GetPoint(space, point)
	if space == "model" then
		return self:GetPointInModelSpace(point)
	elseif space == "center" then
		local x, y, z = self:GetPointInModelSpace(point)
		local cx, cy, cz = self:GetRawCenter()
		return x-cx, y-cy, z-cz
	elseif space == "world" then
		-- get the point in center-space
		local cx, cy, cz = self:GetPoint("center", point)
		
		-- and transform it to world coordinates
		return self:GetCenterMatrix():TransformLooseVector(cx, cy, cz)
	end
end


function ActorMixin:FromCenterSpaceToWorld(x, y, z)
	return self:GetCenterMatrix():TransformLooseVector(x, y, z)
end


function ActorMixin:FromWorldToCenterSpace(x, y, z)
	return self:GetCenterMatrix():GetInverse():TransformLooseVector(x, y, z)
end





--[[
-- Change a coordinate from one basis to another.
function ActorMixin:ChangeOfBasis(old_space, new_space, x, y, z)
	
end
]]


function ActorMixin:SetByName(name)
	if UnitName("player") == name then
		self:SetModelByUnit("player")
	elseif UnitName("target") == name then
		self:SetModelByUnit("target")
	elseif UnitName("mouseover") == name then
		self:SetModelByUnit("mouseover")
	else
		-- TODO: check player and group targets (for matching unit not in group)
	end
end


function ActorMixin:SetByGUID(GUID)
	if UnitGUID("player") == GUID then
		self:SetModelByUnit("player")
	elseif UnitGUID("target") == GUID then
		self:SetModelByUnit("target")
	elseif UnitGUID("mouseover") == GUID then
		self:SetModelByUnit("mouseover")
	else
		-- TODO: check player and group targets (for matching unit not in group)
	end
end


function ActorMixin:CopyFrom(source)
	-- FIXME: copy model?
	self:SetScale(source:GetScale())
	self:SetPosition(source:GetPosition())
	self:SetYPR(source:GetYPR())
	self.who = source.who
end


function ActorMixin:Unlink()
	-- TODO: after implementing a list in the leader of its followers, remove the entry here
	self.transform = nil
	self.relative_to = nil
end


function ActorMixin:GetConfig()
	local actor = self
	local config = { version = 4, }
	--config.index = i
	config.file = actor:GetModelFileID()
	config.who = actor.who -- FIXME: may be out of date
	config.scale = actor:GetScale()
	config.pos = { actor:GetScaledPosition() }
	config.ypr = { deg(actor:GetYaw()), deg(actor:GetPitch()), deg(actor:GetRoll()) }
	
	-- save the unscaled model center, so matrix manipulations can be done on configs without needing the model loaded
	config.center = {self:GetRawCenter()}
	
	if actor.animation or actor.anim then	
		config.anim = {
			animation = actor:GetAnimation() or actor.animation,	-- GetAnimation seems broken
			variation = actor.variation,
		}
		
		-- TODO: add time field on setanimation and determine scaled elapsed time
		if not actor.speed or actor.speed == 0 then
			config.anim.offset = actor.offset
		end
		--FIXME: variation,determine current offset
	end
	
	config.model_source = self.model_source
	
	return config
end


function ActorMixin:SetModelByCreatureDisplayID(...)
	self:SetModelSource("creatureID", ...)
	return getmetatable(self).__index.SetModelByCreatureDisplayID(self, ...)
end


function ActorMixin:SetModelByUnit(...)
	self:SetModelSource("unit", ...)
	return getmetatable(self).__index.SetModelByUnit(self, ...)
end


function ActorMixin:SetModelByFileID(...)
	self:SetModelSource("file", ...)
	return getmetatable(self).__index.SetModelByFileID(self, ...)
end


function ActorMixin:ClearModel(...)
	self:ClearModelSource()
	return getmetatable(self).__index.ClearModel(self, ...)
end


function ActorMixin:SetModelSource(source_type, value)
	self.model_source = {type = source_type, value = value}
end


-- rotate the actor around the specified vector. Probably requires unit vector
function ActorMixin:RotateDegrees(angle, x, y, z)
	local rotation = EMS.Matrix.AngleAxis(rad(angle), x, y, z)
	self:SetOrientation(EMS.Matrix.hmult(rotation, self:GetRotationMatrix()))
end


function ActorMixin:RotateDegreesAroundAxis(angle, axis)
	local initial = self:GetRotationMatrix()
	local rotation = EMS.Matrix.AngleAxis(rad(angle), initial:GetBasisVector(axis))
	self:SetOrientation(EMS.Matrix.hmult(rotation, initial))
end


-- Through ActorTemplate.xml, imitation script handlers can be implemented for the 
-- following actor events by adding a method to the mixin or to the actor with the 
-- matching name: OnLoad OnUpdate OnModelLoading OnModelLoaded OnAnimFinished
-- Example:
--[[
function ActorMixin:OnLoad()
	print("templated actor OnLoad")
end
]]

