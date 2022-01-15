--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local Centering = CreateFrame("ModelScene")

EnhancedModelScene = select(2, ...).self
EnhancedModelScene.Centering = Centering

local EMS = EnhancedModelScene

if not EMS then return end

local Matrix = EnhancedModelScene.Matrix

local cos, sin = math.cos, math.sin

Mixin(Centering, EnhancedModelScene.CameraMixin)


SLASH_MODELCENTERING1 = "/centermodel"
SLASH_MODELCENTERING2 = "/centering"


function SlashCmdList.MODELCENTERING(msg, editbox)
	local self = Centering
		
	if msg == "" then
		self:SetShown(not self:IsShown())
		return
	end
	
	cmd, remainder = msg:match("(%S+)%s*(.*)")
	
	print(cmd, remainder)
	
	if cmd == "set" or cmd == "change" then
		--local index, target = strsplit(" ", remainder)
		self:SetActorTo(self:GetActorAtIndex(1), remainder)
	elseif cmd == "anim" or cmd == "animation" then
		-- FIXME: arguments
		local index = 1
		local anim, variation, speed, offset = strsplit(" ", remainder)
		index, anim, variation = tonumber(index), tonumber(anim) or 0, tonumber(variation) or 0
		offset, speed = tonumber(offset) or 0, tonumber(speed) or 1
		
		local actor = self:GetActorAtIndex(index)
		actor:SetAnimation(anim, variation, speed, offset)
		actor.animation = anim
		actor.offset = offset
		actor.speed = speed
		actor.variation = variation
		
	elseif cmd == "hide" then
		local index = tonumber(remainder)
		print(index)
		self:GetActorAtIndex(index):Hide()
	elseif cmd == "show" then
		local index = tonumber(remainder)
		print(index)
		self:ShowModel(index)
	elseif cmd == "setglobal" then
		local index, name = strsplit(" ", remainder)
		if not name then name = "a" .. index end
		index = tonumber(index)
		
		print(index, name)
		
		_G[name] = self:GetActorAtIndex(index)
	elseif cmd == "backdrop" or cmd == "bd" then
		self:ToggleBackdrop()
	elseif cmd == "fov" then
		local degrees = tonumber(remainder)
		self:SetCameraFieldOfView(rad(degrees))
	elseif cmd == "undress" then
		self:GetActorAtIndex(tonumber(remainder)):Undress()
	elseif cmd == "equip" then
		local index, item = strsplit(" ", remainder)
		self:GetActorAtIndex(tonumber(index)):TryOn("item:" .. item)
	elseif cmd == "flash" then
		local index = tonumber(remainder)
		local model = self:GetActorAtIndex(index)
		if model:IsShown() then
			model:Hide()
			C_Timer.After(1, function() model:Show() end)
		else
			model:Show()
			C_Timer.After(1, function() model:Hide() end)
		end
	elseif cmd == "pos" or cmd == "position" then
		local index, x, y, z = strsplit(" ", remainder)
		local model = self:GetActorAtIndex(tonumber(index))
		model:SetScaledPosition(x, y, z)
	elseif cmd == "getpos" then
		local index = tonumber(remainder)
		local actor = self:GetActorAtIndex(index)
		print(actor:GetPosition())
		
		if self.fix_scale then
			local s = actor:GetScale()
			local x, y, z = actor:GetPosition()
			print(x*s, y*s, z*s)
		end
	elseif cmd == "x" then
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		x = v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "y" then
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		y = v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "z" then
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		z = v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "+x" then
		-- FIXME: adjust nudges by scale
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		x = x + v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "+y" then
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		y = y + v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "+z" then
		local index, v = strsplit(" ", remainder)
		local actor = self:GetActorAtIndex(tonumber(index))
		local x, y, z = actor:GetScaledPosition()
		z = z + v
		actor:SetScaledPosition(x, y, z)
	elseif cmd == "whois" then
		local index = tonumber(remainder)
		print(self:GetActorAtIndex(index).who)
	elseif cmd == "desat" then
		local index, value = strsplit(" ", remainder)
		self:GetActorAtIndex(tonumber(index)):SetDesaturation(tonumber(value))
	elseif cmd == "activecenter" or cmd == "current" or cmd == "currentcenter" then
		local x, y, z = self:GetActorAtIndex(1):GetPosition()
		local file = self:GetActorAtIndex(1):GetModelFileID()
		--print(-x)
		--print(-y)
		--print(-z)
		print(("currently showing %.3f %.3f %.3f for model %i"):format(-x, -y, -z, file))
	elseif cmd == "save" or cmd == "savecenter" then
		local file = self:GetActorAtIndex(1):GetModelFileID()
		local x, y, z = self:GetActorAtIndex(1):GetPosition()
		EMS.ModelCenters:SetCenter(file, -x, -y, -z)
		print(("set model %i center to %.3f %.3f %.3f"):format(file, -x, -y, -z))
		-- GetModelPath gives an empty result, so we can't use it to save the model name (although .m2 mapping would work)
	end
	
end


function Centering:NewActor(remainder)
	-- TODO: override CreateActor so we always get the mixin

	local actor = Mixin(self:CreateActor(), EnhancedModelScene.ActorMixin)
	
	-- FIXME: print index
	print(self:GetNumActors())
	
	self:SetActorTo(actor, remainder)
	
	actor.SetAnimation = EnhancedModelScene.actorSetAnimation
	
	return actor
end


function Centering:ShowModel(index)
	self:GetActorAtIndex(index):Show()
end


function Centering:SetActorTo(actor, target)
	local n = tonumber(target)
	
	if n then
		actor:SetModelByCreatureDisplayID(n)
		local x, y, z = actor:GetActiveBoundingBoxCenter()
		-- FIXME: can't get the center until the model's been loaded - retrying works for now though
		actor:SetPosition(-x, -y, -z)
		--actor.who = n
	else
		if target == nil or target == "" then
			target = "player"
		end
		actor:SetModelByUnit(target)
		-- FIXME: don't save player name if in barbershop
		actor.who = GetUnitName(target)
	end
end


function Centering:OnFirstShow()
	print("OnFirstShow", "num actors:", self:GetNumActors())
	local a = self:GetActorAtIndex(1) or self:NewActor()
	a:SetModelByUnit("player")
	a:SetAnimation(0, 0)
	
	local x, y, z = a:GetActiveBoundingBoxCenter()
	
	a:SetPosition(-x, -y, -z)
	
	self:SetCameraNearClip(.01)
	self:SetCameraFieldOfView(rad(120))
	
	self:OnShow()
	self:SetScript("OnShow", self.OnShow)
end


function Centering:OnShow()
	self.px, self.py = GetCursorPosition()
end


do
	local self = Centering

	local super = getmetatable(self).__index
	
	function Centering:SetCameraFieldOfView(radians)
		if self.log then
			--self:Log("SetCameraFieldOfView", radians)
			tinsert(self.log, { GetTime(), "SetFOV", radians} )
		end
		
		return super.SetCameraFieldOfView(self, radians)
	end
end



function Centering:OnMouseWheel(delta)
	if IsAltKeyDown() then
		local actor = self:GetActorAtIndex(self.active_model or 1)
		if actor.animation then
			actor.offset = (actor.offset or 0) - (IsControlKeyDown() and .002 or .01) * delta
			actor:SetAnimation(actor.animation, actor.variation, 0, actor.offset)
		end
	elseif IsControlKeyDown() or self.scroll_animations then
		local actor = self:GetActorAtIndex(self.active_model or 1)
		local anim = (actor.animation or 0) - delta
		
		print(anim)
		
		-- FIXME
		actor:SetAnimation(anim, nil, 1)
		actor.animation = anim
		actor.offset = 0
		actor.speed = 1
		actor.variation = nil

	else
		self.r = self.r * .97 ^ (delta * (IsShiftKeyDown() and 3 or 1))
		self.r_changed = true
	end
end


function Centering:OnMouseDown(button)
	if button == "LeftButton" then
		self.rotate = true		
	elseif button == "RightButton" then
		self.pan_model = self.active_model or 1
	end
	
	self.px, self.py = GetCursorPosition()
end


function Centering:OnMouseUp(button)
	if button == "LeftButton" then
		self.rotate = false
		self.rotate_model = false
	elseif button == "RightButton" then
		self.pan = false
		self.pan_model = false
	end
end


function Centering:OnUpdate(elapsed)
	local cx, cy = GetCursorPosition()
	local dx, dy = cx - self.px, cy - self.py

	if self.pan or self.rotate or self.r_changed then
		if self.rotate then
			self.yaw = self.yaw - .005 * dx
			self.pitch = self.pitch - .005 * dy
		end
		
		self:UpdateCamera()
	end
	
	if self.pan_model then
		local m = self:GetActorAtIndex(self.pan_model)
		
		local factor = .0005 * self.r * (m.pan_factor or 1) / m:GetScale()
		
		local a, b = self.yaw, self.pitch
		local ca, cb = cos(a), cos(b)
		local sa, sb = sin(a), sin(b)
		
		local x, y, z = m:GetPosition()
		
		-- increment by the y and z vectors of a yaw-pitch-roll rotation
		x, y = x + sa*dx*factor, y - ca*dx*factor
		x, y, z = x + ca*sb*dy*factor, y + sa*sb*dy*factor, z + cb*dy*factor
		
		m:SetPosition(x, y, z)
	end

	self.px, self.py = cx, cy
	
	self:UpdateCamera()
	
	self:UpdateFollower()
end


function Centering:UpdateFollower()
	local a = self:GetActorAtIndex(1)

	-- TODO: cache a temporary position, so we don't save unfinished calibrations + have something to revert to
	
	-- negatives of guessed center, derived from model's current position
	local nx, ny, nz = a:GetPosition()

	local target_scene = self.flipped
	local target_actor = target_scene:GetActorAtIndex(self.link_to or 1)
	local s = self:GetActorAtIndex(1)
	
	local a, b = self.yaw, self.pitch
	
	-- components of x unit vector for the camera
	local x, y, z = cos(a) * cos(b), sin(a) * cos(b), -sin(b)
	
	local rotation = Matrix.AngleAxis(math.pi, x, y, z)
	
	-- since the reference model starts in null orientation, we can use m directly for the model
	local yaw, pitch, roll = rotation:GetYPR()
	
	target_actor:SetYaw(yaw)
	target_actor:SetPitch(pitch)
	target_actor:SetRoll(roll)
	
	target_actor:SetScale(1)

	target_actor:SetPosition(nx, ny, nz)
	
	target_scene.yaw, target_scene.pitch, target_scene.roll = self.yaw, self.pitch, self.roll + math.pi
	target_scene.r = self.r
	target_scene.tx, target_scene.ty, target_scene.tz = self.tx, self.ty, self.tz
	target_scene.r_changed = true
	target_scene.target_changed = true
	target_scene:UpdateCamera()
end



function Centering:ypr()
	return self:GetFacing(), self:GetPitch(), self:GetRoll()
end



function Centering:GetCurrentConfig()
	local config = {}
	
	config.camera = {}
	config.camera.pos = { self:GetCameraPosition() }
	config.camera.ypr = { self.yaw, self.pitch, self.roll }
	config.camera.fov = self:GetCameraFieldOfView()
	config.camera.distance = self.r
	
			-- FIXME: save camera orbit distance
			
	config.actors = {}
	
			
			
	for i = 1, self:GetNumActors() do
		local actor = self:GetActorAtIndex(i)
		
		if actor:IsVisible() then
			local a = {}
			a.index = i
			a.model = actor:GetModelFileID()
			a.who = actor.who -- FIXME: may be out of date
			a.scale = actor:GetScale()
			a.pos = { actor:GetPosition() }
			a.ypr = { actor:GetYaw(), actor:GetPitch(), actor:GetRoll() }
			a.animation = actor:GetAnimation() or actor.animation	-- GetAnimation seems broken
			a.variation = actor.variation
			-- TODO: add time field on setanimation and determine scaled elapsed time
			if not actor.speed or actor.speed == 0 then
				a.offset = actor.offset
			end
			--FIXME: variation,determine current offset
			
			tinsert(config.actors, a)
			
		end
	end
	
	return config
end


function Centering:GetActorConfig(index)
end


function Centering:SetActorConfig(actor, config)
end


function Centering:ApplyConfig(config)
	for i = 1, #config.actors do
		local a = config.actors[i]
		local actor = self:GetActorAtIndex(a.index)
		
		-- FIXME: allow remapping actors
		
		if actor then
			actor:SetScale(a.scale)
			actor:SetPosition(unpack(a.pos))
			
			local y, p, r = unpack(a.ypr)
			actor:SetYaw(y); actor:SetPitch(p); actor:SetRoll(r)
			
			-- FIXME: variation, speed, offset
			-- TODO: fix inability to immediately shift offset after applying pose
			local speed
			if a.offset then speed = 0 end
			actor:SetAnimation(a.animation or 0, a.variation, speed, a.offset)
		end
	end
	
	self:SetCameraFieldOfView(config.camera.fov)
	self:SetCameraPosition(unpack(config.camera.pos))
	self.r = config.camera.distance
	self.update_target = true
	self.yaw, self.pitch, self.roll = unpack(config.camera.ypr)
	self:UpdateCamera()
end



function Centering:PrintCurrentConfig()
	print("camera position", self:GetCameraPosition())
	print("camera YPR", self.yaw, self.pitch, self.roll)
	
	print(self:GetNumActors(), "actors")
	
	for i = 1, self:GetNumActors() do
		local actor = self:GetActorAtIndex(i)
		
		if actor:IsVisible() then
			print("actor", i)
			print("model", actor:GetModelFileID())
			print("scale", actor:GetScale())
			print("position", actor:GetPosition())
			print("YPR", actor:GetYaw(), actor:GetPitch(), actor:GetRoll())
			print("animation", actor:GetAnimation())
		end
	end
end


function Centering:SwapActors(a, b)
	
end


function Centering:ListPoseModels(index)
	index = index or self.pose_index
	
	local config = nil
end


function Centering:ApplyBarbershopToActive()
	self:GetActorAtIndex(self.active_model or 1):SetModelByUnit("player")
end


function Centering:NewModelFromBarbershop()
	self:NewActor()
end


function Centering:ListConfigActors(config)
	if not config then
		config = self.pose_list[self.pose_index or 0]
	end
	
	for i = 1, #config.actors do
		local a = config.actors[i]
		print(a.index, a.who)
	end
end


function Centering:LoadSession(n)
	-- allow eg. -4
	if n < 1 then
		n = n + #self.sv.sessions
	end
	
	
	self.pose_list = self.sv.sessions[n]
	self.pose_index = 1
end


function Centering:LoadLastSession()
	self:LoadSession(#self.sv.sessions)
end

function Centering:LoadLastPose()
	self:LoadLastSession()
	self.pose_index = #self.pose_list
	-- TODO: actually create the actors and apply the pose
end

function Centering:RebuildActors(config)
end


function Centering:AddPhasorToActor(n, period, phase, action)
	local actor = self:GetActorAtIndex(n)
	period, phase, action = period or 1, phase or 0, action or function() end
	actor.phasor = { phase = phase, period = period, action = action }
end


function Centering:UpdateActorPhasors(elapsed)
	for i = 1, self:GetNumActors() do
		local actor = self:GetActorAtIndex(i)
		local phasor = actor.phasor
		
		if phasor then
			
			phasor.phase = phasor.phase + elapsed / phasor.period
			
			if actor:IsVisible() then
				phasor:action(actor)
			end
		end
	end
end


function Centering:UpdateActors()
	for i = 1, self:GetNumActors() do
		local a = self:GetActorAtIndex(i)
		
		if a.transform and a:IsVisible() then
			-- FIXME: a visible actor may depend on a hidden one, itself relative to a shown third (use a flag and check parents?)
			local p = self:GetActorAtIndex(a.relative_to)
			--local m1 = self:GetActorMatrix(a.relative_to)
			
			local out = self.Matrix.hmult(p:GetCenterMatrix(), a.transform)
			
			--[[
			local out = self.Matrix.hmult(self:GetActorMatrix(a.relative_to), a.transform)
			
			-- adjust for model centers
			local c1x, c1y, c1z = self:GetScaledCenterOffset(a.relative_to)
			local c2x, c2y, c2z = self:GetScaledCenterOffset(i)
			
			local x, y, z = out[10], out[11], out[12]
			x, y, z = x + c1x - c2x, y + c1y - c2y, z + c1z - c2z
			
			out[10], out[11], out[12] = x, y, z
	
			self:ApplyActorMatrix(out, i)
			]]
			
			a:SetCenterTransform(out)
		end
	end
end


function Centering:GetActorMatrix(n)
	local a = self:GetActorAtIndex(n)
	
	local m = self.Matrix.YPR(a:GetYaw(), a:GetPitch(), a:GetRoll())
	self.Matrix.MergeTranslation(m, self:GetScaledPosition(n))
	
	return m
end


function Centering:ApplyActorMatrix(m, n)
	local yaw, pitch, roll = self.Matrix.GetYPR(m)
	local x, y, z = self.Matrix.GetXYZ(m)

	local a = self:GetActorAtIndex(n)
	
	self:SetScaledPosition(n, x, y, z)
	a:SetYaw(yaw)
	a:SetPitch(pitch)
	a:SetRoll(roll)
end


--local ActorMixin = EnhancedModelScene.ActorMixin




function Centering:GetScaledPosition(n)
	local actor = self:GetActorAtIndex(n)
	local s = actor:GetScale()
	local x, y, z = actor:GetPosition()
	return s*x, s*y, s*z
end


function Centering:LockActorTo(follower, leader)
	local f = self:GetActorAtIndex(follower)
	local l = self:GetActorAtIndex(leader)
	
	f.relative_to = leader
	f.transform = f:GetRelativeMatrix(l)
end


function Centering:UnlockActor(n)
	local a = self:GetActorAtIndex(n)
	a.transform = nil
	a.relative_to = nil
end



function Centering:GetScaledCenterOffset(n)
	local a = self:GetActorAtIndex(n)
	
	local x, y, z = a:GetRawCenter()
	local s = a:GetScale()
	
	return s*x, s*y, s*z
end


function Centering:GetRawCenterFor(...)
	return EnhancedModelScene:GetRawCenterFor(...)
end


function Centering:GetScaledCenter()
end



function Centering:SetScaledPosition(n, x, y, z)
	local actor = self:GetActorAtIndex(n)
	local s = actor:GetScale()
	actor:SetPosition(x/s, y/s, z/s)
end


function Centering:ChangeOriginTo()
end


function Centering:ResetCamera()
	EnhancedModelScene.CameraMixin.ResetCamera(self)
	self:SetCameraTarget(0, 0, 0)
	self:UpdateCamera()
end


do
	local self = Centering
	
	self.half_roll = Matrix.New(1, 0, 0,
	                            0, -1, 0,
								0, 0, -1)
	
	self:Hide()

	self:SetScript("OnShow", self.OnFirstShow)
	self:SetScript("OnUpdate", self.OnUpdate)
	self:SetScript("OnMouseWheel", self.OnMouseWheel)
	self:SetScript("OnMouseDown", self.OnMouseDown)
	self:SetScript("OnMouseUp", self.OnMouseUp)
	self:SetScript("OnEvent", self.OnEvent)

	--self:RegisterEvent("ADDON_LOADED")
	--self:RegisterEvent("SCREENSHOT_STARTED")
	--self:RegisterEvent("SCREENSHOT_SUCCEEDED")
	--self:RegisterEvent("BARBER_SHOP_OPEN")

	getmetatable(self).__call = function(self, ...)
		if type(...) == "number" then
			return self:GetActorAtIndex(...)
		end
	end

	self.fix_scale = true
	
	Mixin(self:CreateActor(), EnhancedModelScene.ActorMixin)
	
	local f = CreateFrame("ModelScene", nil, self)
	self.flipped = f
	Mixin(f, EnhancedModelScene.CameraMixin)
	Mixin(f:CreateActor(), EnhancedModelScene.ActorMixin)
		
	local propogate_on_scenes = [[
		SetCameraNearClip
		SetCameraFieldOfView
	]]
	
	local propogate_on_actors = [[
		SetAnimation
		SetDesaturation
		SetModelByCreatureDisplayID
		SetModelByUnit
	]]
	
	for key in propogate_on_scenes:gmatch("%S+") do
		hooksecurefunc(self, key, function(_, ...) print(key, ...); self.flipped[key](self.flipped, ...) end)
	end
	
	local leader = self:GetActorAtIndex(1)
	local follower = self.flipped:GetActorAtIndex(1)
	
	for key in propogate_on_actors:gmatch("%S+") do
		hooksecurefunc(leader, key, function(_, ...) follower[key](follower, ...) end)
	end
	
	self:SetAllPoints(WorldFrame)	-- TOOD: set flipped frames as followers with all points to parent?
	self.flipped:SetAllPoints(self)
	self:SetFrameStrata("BACKGROUND")

	self:ResetCamera()
	--self:SetCameraFieldOfView(rad(90))	-- this gets changed OnFirstShow


end
