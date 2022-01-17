--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021-2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local self, addon_table

do
	local name
	name, addon_table = ...
	-- FIXME: don't want the model scene to be nameless, but probably shouldn't collide with addon (confusion retreiving by name)
	self = LibStub("AceAddon-3.0"):NewAddon(CreateFrame("ModelScene", name), name, "AceConsole-3.0", "AceComm-3.0", "AceSerializer-3.0")
	self.name = name
end

addon_table.self = self

local EnhancedModelScene = self

EnhancedModelScene.MAX_ARGS = 100

-- TODO: add key to save/restore camera position

local cos, sin = math.cos, math.sin

local SYNC_PREFIX = "ems_sync"
local AXISTESTOBJECT = 34715


SLASH_ENHANCEDMODELSCENE1 = "/enhancedmodelscene"
SLASH_ENHANCEDMODELSCENE2 = "/ems"

SLASH_ENHANCEDMODELSCENELOCAL1 = "/enhancedmodelscenelocal"
SLASH_ENHANCEDMODELSCENELOCAL2 = "/emslocal"
SLASH_ENHANCEDMODELSCENELOCAL3 = "/emsl"

SLASH_ENHANCEDMODELSCENEGROUP1 = "/enhancedmodelscenegroup"
SLASH_ENHANCEDMODELSCENEGROUP2 = "/emsgroup"
SLASH_ENHANCEDMODELSCENEGROUP3 = "/emsg"

function SlashCmdList.ENHANCEDMODELSCENE(msg, editbox)
	local self = EnhancedModelScene
	-- run the command locally first unless we're syncing and running through those messages
	if not self.sync or not self.run_via_sync then
		EnhancedModelScene:DoCommand(msg)
	end
	
	if self.sync then
		-- TODO: might need per-command property determining whether syncable
		self:SendSyncCommand(msg)
	end
end


function SlashCmdList.ENHANCEDMODELSCENELOCAL(msg, editbox)
	EnhancedModelScene:DoCommand(msg)
end


function SlashCmdList.ENHANCEDMODELSCENEGROUP(msg, editbox)
	local self = EnhancedModelScene
	
	if not self.run_via_sync then
		self:DoCommand(msg)
	end
	
	self:SendSyncCommand(msg)
end


-- run command locally, and send to group if enabled
function EnhancedModelScene:DispatchCommand(line)
	self:DoCommand(line, "local")
	self:SendSyncCommand(line)
end


function EnhancedModelScene:SendSyncCommand(message)
	if self.always_print_sync then
		print("SendSyncCommand", message)
	end
	
	local channel, who
	
	if not self.sync and not self.group_sync then return end
	
	if IsInRaid() and not IsTrialAccount() and not IsVeteranTrialAccount() then
		channel = "RAID"
	elseif IsInGroup() then
		-- TEST: will this return true for trials or should they be nested inside the above section?
		channel = "PARTY"
	else
		-- for testing
		channel, who = "WHISPER", UnitName("player")
	end

	if channel then
		if self.print_sent_comms then
			print("sending message via", channel, who, message)
		end
		
		self:SendCommMessage(SYNC_PREFIX, message, channel, who)
	end
end


function EnhancedModelScene:DoCommand(message, source)
	local msg = message
	
	if msg == "" then
		self:SetShown(not self:IsShown())
		return
	end
	
	self.Commands:Dispatch(message, source)
end


function EnhancedModelScene:NewActor(remainder)
	-- TODO: override CreateActor so we always get the mixin
	
	-- use a template to get scripts and the mixin
	local actor = self:CreateActor(nil, "EMS_ActorTemplate")
	--local actor = Mixin(self:CreateActor(), self.ActorMixin)

	self:SetActorTo(actor, remainder)
	
	--actor.SetAnimation = self.actorSetAnimation
	
	return actor
end

-- CreateBlankActor ?
function EnhancedModelScene:CreateNullActor()
	local actor = self:NewActor()
	actor:Hide()
	--actor.who = "null"
end


function EnhancedModelScene:EnsureActorCount(count)
	for i = self:GetNumActors() + 1, count do
		self:CreateNullActor()
	end
end


function EnhancedModelScene:ShowActor(index)
	self:GetActorAtIndex(index):Show()
end

--[[
function EnhancedModelScene.actorSetAnimation(actor, animation, variation, speed, offset)
	actor.animation, actor.variation, actor.speed, actor.offset = animation, variation, speed, offset
	-- TODO: switch from above to subtable
	actor.current_animation = { animation = animation, variation = variation, speed = speed, offset = offset }
	getmetatable(actor).__index.SetAnimation(actor, animation, variation, speed, offset)
end
]]

function EnhancedModelScene:SetActorTo(actor, target)
	if type(actor) == "number" then
		actor = self:GetActorAtIndex(actor)
	end

	local n = tonumber(target)
	
	if n then
		actor:SetModelByCreatureDisplayID(n)
		--actor.who = n
	else
		if target == nil or target == "" then
			target = "player"
		end
		actor:SetModelByUnit(target)
		-- FIXME: don't save player name if in barbershop
		-- FIXME: this will get fooled by Words of Akunda etc.
		actor.who = GetUnitName(target)
	end
end


function EnhancedModelScene:OnFirstShow()
	print("OnFirstShow", "num actors:", self:GetNumActors())
	local a = self:GetActorAtIndex(1) or self:NewActor()
	
	-- TODO: don't set if another unit was set before opening the addon
	a:SetModelByUnit("player")
	--self.a1 = a
	
	self:SetCameraNearClip(.01)
	self:SetCameraFieldOfView(rad(120))
	
	self:OnShow()
	self:SetScript("OnShow", self.OnShow)
end


function EnhancedModelScene:OnShow()
	self.px, self.py = GetCursorPosition()
end


do
	local super = getmetatable(self).__index
	
	function EnhancedModelScene:SetCameraFieldOfView(radians)
		if self.log then
			--self:Log("SetCameraFieldOfView", radians)
			tinsert(self.log, { GetTime(), "SetFOV", radians} )
		end
		
		return super.SetCameraFieldOfView(self, radians)
	end
end


function EnhancedModelScene:Log(method, ...)
	--if not self.log then return end
	
	-- FIXME
	if true then return end
	
	local last = self.log.last
	
	if last and last.method == method then
		-- same call as previous; stack arguments
		
		local t = GetTime()
		local dt = t - last.time
		
		last.entry[last.next_field] = dt
		last.time = t
		
		for i = 1, select("#", ...) do
			-- TODO: deltas and rounding? how to handle possibly different allowable rounding?
			last.entry[last.next_field + i] = select(i, ...)
		end
		
		last.next_field = last.next_field + 1 + select("#", ...)
	else
		-- first entry or different call
		
		if last then
			wipe(last)
		else
			last = {}
			self.log.last = last
		end
		
		last.method = method
		
		local time = GetTime()
		
		last.time = time
		
		-- use system time for new methods, at least for now
		last.entry = { method, time, ... }
		
		tinsert(self.log.session, last.entry)
		
		last.next_field = 3 + select("#", ...)
	end
end


function EnhancedModelScene:OnUpdate(elapsed)
	local cx, cy = GetCursorPosition()
	local dx, dy = cx - self.px, cy - self.py
	
	if self.pan then
		local factor = -.0005 * self.r
		
		local a, b = self.yaw, self.pitch
		local ca, cb = cos(a), cos(b)
		local sa, sb = sin(a), sin(b)
		
		local x, y, z = self:GetCameraPosition()
		
		-- increment by the y and z vectors of a yaw-pitch-roll rotation
		x, y = x + sa*dx*factor, y - ca*dx*factor
		x, y, z = x + ca*sb*dy*factor, y + sa*sb*dy*factor, z + cb*dy*factor
		
		self.update_target = true
		self:SetCameraPosition(x, y, z)
		
		if self.log then
			tinsert(self.log, { GetTime(), "SetCameraPosition", x, y, z })
			self:Log("SetCameraPosition", x, y, z)
		end
	end
	
	if self.pan or self.rotate or self.r_changed then
		if self.rotate then
			self.yaw = self.yaw - .005 * dx
			self.pitch = self.pitch - .005 * dy
		end
		
		self:UpdateCamera()
	end
	
	if self.pan_model then
		local actor = self:GetActorAtIndex(self.pan_model)
		
		local factor = .0005 * self.r * (actor.pan_factor or 1)
		
		local a, b = self.yaw, self.pitch
		local ca, cb = cos(a), cos(b)
		local sa, sb = sin(a), sin(b)
		
		-- TODO: maybe change this to use scaled position, remove scale factor?
		local x, y, z = actor:GetScaledPosition()
		
		-- increment by the y and z vectors of a yaw-pitch-roll rotation
		x, y = x + sa*dx*factor, y - ca*dx*factor
		x, y, z = x + ca*sb*dy*factor, y + sa*sb*dy*factor, z + cb*dy*factor
		
		actor:SetScaledPosition(x, y, z)
		
		if self.log then
			tinsert(self.log, { GetTime(), "SetModelPosition", self.pan_model, x, y, z })
			--self:Log("SetModelPosition", self.pan_model, x, y, z)
		end
		
	end
	
	if self.rotate_model then
		local m = self:GetActorAtIndex(self.rotate_model)
		
		local pitch = m:GetPitch()
		local yaw = m:GetYaw()
		
		m:SetYaw(yaw + .003 * dx)
		m:SetPitch(pitch - .003 * dy)
		m:UpdatePivot()
		
		if self.log then
			tinsert(self.log, { GetTime(), "SetModelYPR", self.rotate_model, yaw + .003 * dx, pitch - .003 * dy })
			self:Log("SetModelYPR", self.rotate_model, yaw + .003 * dx, pitch - .003 * dy)
		end

	end
	
	self:UpdateActorPhasors(elapsed)
	
	self:UpdateActors(elapsed)
	
	if self.camera_transform then
		self:ApplyCameraTransform()
	end
	
	-- TODO: finish migration
	if self.crosshairs_follow_cursor then
		self.crosshairs[1]:SetLocation(GetCursorPosition())
	elseif self.crosshairs_follow_current_actor then
		local actor = self:GetCurrentActor()
		local wx, wy, wz = actor:GetScaledPosition()
		local sx, sy = self:Project3DPointTo2D(wx, wy, wz)
		self.crosshairs[1]:SetLocation(sx, sy)
	elseif self.crosshairs_follow_index then
		local actor = self:GetActorAtIndex(self.crosshairs_follow_index)
		local wx, wy, wz = actor:GetScaledPosition()
		local sx, sy = self:Project3DPointTo2D(wx, wy, wz)
		self.crosshairs[1]:SetLocation(sx, sy)
	end
	
	self.Reticle:UpdateAll(elapsed)
	
	self.px, self.py = cx, cy
end



function EnhancedModelScene:OnMouseDown(button)
	if button == "LeftButton" then
		if IsAltKeyDown() then
			self.rotate_model = self.active_model or 1
		else
			self.rotate = true
		end
		
		self.px, self.py = GetCursorPosition()
	elseif button == "RightButton" then
		if IsAltKeyDown() then
			self.pan_model = self.active_model or 1
		else
			self.pan = true
		end
		
		self.px, self.py = GetCursorPosition()
	end
end


function EnhancedModelScene:OnMouseUp(button)
	local status, error_message
	
	if self.group_sync then
		-- FIXME: use xpcall?
		status, error_message = pcall(self.ShareMouseAction, self)
	end
	
	if button == "LeftButton" then
		self.rotate = false
		self.rotate_model = false
	elseif button == "RightButton" then
		self.pan = false
		self.pan_model = false
	end
	
	if self.group_sync and not status then
		-- FIXME: show error
		print("Error in EMS ShareMouseAction:", error_message)
	end
end


-- check what resulted from mouse movement and share to group
function EnhancedModelScene:ShareMouseAction()
	-- TODO: check if no substantial change
	
	if not self.share then
		self.share = {}
	end
	
	if self.rotate and self.share.camera then
		-- FIXME: share new camera angles
	end
	
	if self.pan and self.share.camera then
		-- FIXME: share camera location
	end
	
	if self.rotate_model then
		local i = self.active_model or 1
		local command = ("ypr %i %f %f %f"):format(i, self:GetActorAtIndex(i):GetYPRDeg())
		self:SendSyncCommand(command)
	end
	
	if self.pan_model then
		local i = self.active_model or 1
		local command = ("xyz %i %f %f %f"):format(i, self:GetActorAtIndex(i):GetXYZ())
		self:SendSyncCommand(command)
	end
end


function EnhancedModelScene:OnMouseWheel(delta)
	if self.wheel_func then
		self:wheel_func(delta)
		return
	end
	
	if IsAltKeyDown() then
		local actor = self:GetActorAtIndex(self.active_model or 1)
		
		-- FIXME: use function
		if not actor.animation then
			actor:SetAnimation(0, 0)
			-- looks like omitting the variation can cause alternation
			-- between main variant and alternative when scrolling
		end
		
		if actor.animation then
			local step = .01
			
			if IsShiftKeyDown() then
				step = step * 10
			elseif IsControlKeyDown() then
				step = step / 10
			end
			
			actor.offset = (actor.offset or 0) - step * delta
			actor:SetAnimation(actor.animation, actor.variation, 0, actor.offset)
			-- FIXME: throttle
			--self:SendSyncCommand(("anim %i %i %i 0 %f"):format(self.active_model or 1, actor.animation, actor.variation, actor.offset))
			self.Bucket:SendToBucket("animation", self:GetCurrentActorIndex(), actor.animation, actor.variation, 0, actor.offset)
		end
	elseif self:ShouldScrollFiles() then
		self:ScrollFileList(-delta)
	elseif IsControlKeyDown() and self.pose_list then
		self.pose_index = (self.pose_index or 0)- delta
		--local pose = self.sv.scenes[self.pose_index]
		print("pose", self.pose_index)
		local pose = self.pose_list[self.pose_index]
		if not pose then
			print("invalid pose")
		else
			self:ApplyConfig(pose)
		end
	elseif IsControlKeyDown() or self.scroll_animations then
		local actor = self:GetActorAtIndex(self.active_model or 1)
		local anim = max(0, (actor.animation or 0) - delta)
		
		print(anim)
		
		-- FIXME
		actor:SetAnimation(anim, nil, 1)
		actor.animation = anim
		actor.offset = 0
		actor.speed = 1
		actor.variation = nil
		
		self:SendSyncCommand(("anim %i %i 0 0 0"):format(self.active_model or 1, anim))

	else
		self.r = self.r * .97 ^ (delta * (IsShiftKeyDown() and 3 or 1))
		self.r_changed = true
	end
end


function EnhancedModelScene:ShouldScrollFiles()
	return IsControlKeyDown() and self.file_list
end


function EnhancedModelScene:ScrollFileList(steps)
	self.file_list_index = (self.file_list_index or 0) + (steps or 1)
	
	local file_table = self.file_list[self.file_list_index]
	
	if file_table then
		print(unpack(file_table))
		local model = self.active_model or 1
		local file, name = unpack(file_table)
		local command = ("setfile %i %i"):format(model, file)
		self:DoCommand(command)
		self:SendSyncCommand(command)
	end
end


function EnhancedModelScene:ScrollMatchingFiles(query)
	self.file_list_index = 0
	self.file_list = self.FileMap:GetMatchingFiles(query)
	print("found", #self.file_list, "matches")
end


function EnhancedModelScene:ypr()
	return self:GetFacing(), self:GetPitch(), self:GetRoll()
end


function EnhancedModelScene:GetCurrentActorIndex()
	return self.active_model or 1
end


function EnhancedModelScene:GetCurrentActor()
	return self:GetActorAtIndex(self:GetCurrentActorIndex())
end


function EnhancedModelScene:GetCurrentConfig()
	local config = { version = 4, }
	
	config.camera = {}
	config.camera.pos = { self:GetCameraPosition() }
	config.camera.ypr = { deg(self.yaw), deg(self.pitch), deg(self.roll) }
	config.camera.fov = deg(self:GetCameraFieldOfView())
	config.camera.distance = self.r
	
	config.actors = {}
	
	for i = 1, self:GetNumActors() do
		local actor = self:GetActorAtIndex(i)
		
		-- 	FIXME: check for hidden but needed references
		if actor:IsVisible() then
			--[[
			local a = {}
			a.index = i
			a.file = actor:GetModelFileID()
			a.who = actor.who -- FIXME: may be out of date
			a.scale = actor:GetScale()
			a.pos = { actor:GetScaledPosition() }
			a.ypr = { deg(actor:GetYaw()), deg(actor:GetPitch()), deg(actor:GetRoll()) }
			
			a.anim = {
				animation = actor:GetAnimation() or actor.animation,	-- GetAnimation seems broken
				variation = actor.variation,
			}
			
			-- TODO: add time field on setanimation and determine scaled elapsed time
			if not actor.speed or actor.speed == 0 then
				a.anim.offset = actor.offset
			end
			--FIXME: variation,determine current offset
			]]
			
			local a = actor:GetConfig()
			a.index = i
			
			tinsert(config.actors, a)
			
		end
	end
	
	return config
end


function EnhancedModelScene:GetConfigForActors(...)
	local config = { version = 4, }
	
	config.actors = {}
	
	local indices = {...}
	
	for i, index in ipairs(indices) do
		print(index, type(index))
		local actor = self:GetActorAtIndex(tonumber(index))
		
		tinsert(config.actors, actor:GetConfig())
	end
	
	return config
end


function EnhancedModelScene:PrintActorConfigSummary(config)
	local c = config
	
	if config.hidden then
		print("actor is hidden")
	end
	
	local line1 = "file %s, who %s, scale %.4f, position %.3f %.3f %.3f, orientation %.3f %.3f %.3f"
	print(line1:format(config.file, config.who, c.scale, unpack(config.pos), "orientation", unpack(c.ypr)))
	
	local animation_line = "Animation %i, variant %i, speed %.3f, offset %.3f"
	local anim = config.anim
	print(animation_line:format(anim.animation, anim.variation, anim.speed, anim.offset))
end


function EnhancedModelScene:SendCurrentConfig(to, to_arg)
	local str = self:Serialize(self:GetCurrentConfig())
	self.last_config_sent = str
	self:SendCommMessage(SYNC_PREFIX, "importconfig " .. str, to, to_arg)
end


function EnhancedModelScene:ApplySerializedConfig(str)
	print("EMS:ASC")
	local success, config = self:Deserialize(str)
	
	if not success then
		-- FIXME
		print("error deserializing")
		return
	end
	
	self:RebuildActors(config)
	self:ApplyConfig(config)
end


function EnhancedModelScene:GetActorConfig(index)
end


function EnhancedModelScene:SetActorConfig(actor, config)
end


function EnhancedModelScene:ApplyConfig(config)
	for i = 1, #config.actors do
		local a = config.actors[i]
		local actor = self:GetActorAtIndex(a.index)
		
		-- FIXME: allow remapping actors
		
		if actor then
			actor:SetScale(a.scale)
			actor:SetScaledPosition(unpack(a.pos))
			
			local y, p, r = unpack(a.ypr)
			actor:SetYaw(rad(y)); actor:SetPitch(rad(p)); actor:SetRoll(rad(r))
			
			-- FIXME: variation, speed, offset
			-- TODO: fix inability to immediately shift offset after applying pose
			local speed
			
			local animation = 0
			if a.anim then
				animation = a.anim.animation
				if a.anim.offset then speed = 0 end
			end
			
			if a.anim then
				-- FIXME
				actor:SetAnimation(animation or 0, a.anim.variation, speed, a.anim.offset)
			end
		end
	end
	
	self:SetCameraFieldOfView(rad(config.camera.fov))
	self:SetCameraPosition(unpack(config.camera.pos))
	self.r = config.camera.distance
	self.update_target = true
	local y, p, r = unpack(config.camera.ypr)
	self.yaw, self.pitch, self.roll = rad(y), rad(p), rad(r)
	self:UpdateCamera()
end


function EnhancedModelScene:SaveCurrentConfig(notes)
	--[[
	self.sv.scenes = self.sv.scenes or {}
	
	local index = #self.sv.scenes + 1
	local config = self:GetCurrentConfig()
	config.notes = notes
	self.sv.scenes[index] = config
	
	print("saved config to index", index)
	]]
	
	self.sv.sessions = self.sv.sessions or {}
	
	if not self.session then
		self.session = { time = time() }
		tinsert(self.sv.sessions, self.session)
	end
	
	local config = self:GetCurrentConfig()
	config.notes = notes
	
	tinsert(self.session, config)
	
end


function EnhancedModelScene:PrintCurrentConfig()
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


function EnhancedModelScene:SaveMethods()
	local t = { ModelScene = {}, ModelSceneActor = {}, build = {GetBuildInfo()} }
	
	for key in pairs(getmetatable(self).__index) do
		tinsert(t.ModelScene, key)
	end
	
	for key in pairs(getmetatable(self.a1 or self:CreateActor()).__index) do
		tinsert(t.ModelSceneActor, key)
	end
	
	self.sv.methods = t
end


function EnhancedModelScene:OnEvent(event, ...)
	if event == "ADDON_LOADED" and ... == self.name then
		local key = self.name .. "SV"
		local sv = _G[key] or {}
		_G[key] = sv
		self.sv = sv
		
		-- FIXME
		self.ModelCenters.saved_centers = self.sv.saved_centers
		--local saved_centers = self.sv.saved_centers or {}
		--self.sv.saved_centers = saved_centers
		--self.ModelCenters.saved_centers = saved_centers
	elseif event == "PLAYER_LOGIN" then
		--SlashCmdList.EVENTTRACE()
		-- logging in with a disguise (eg. turkey) appears to interfere with checking now
		--[[
		C_Timer.After(60, function()
			print("delayed actor check")
			local actor = self:NewActor()
			actor:SetModelByUnit("player")
			self.player_file = actor:GetModelFileID() -- this works for reloads but not normal logins
		end)
		]]
	elseif event == "BARBER_SHOP_OPEN" and not self.button1 then
		self:MakeBarbershopButtons()
		
		if self.not_shown_yet then
			self.not_shown_yet = nil
			self:Show()
			self:Hide()
		end
	elseif event == "SCREENSHOT_STARTED" and self:IsShown() then
		-- FIXME: log screenshot (but differently) because screenshots take so long now 
		-- and sometimes the success event stops firing
	elseif event == "SCREENSHOT_SUCCEEDED" and self:IsShown() then
		self:SaveCurrentConfig({type = "screenshot", time = time()})
		print("screenshot taken")
		PlaySound(850)
	end
end


function EnhancedModelScene:SwapActors(a, b)
	
end


function EnhancedModelScene:ListModelsInPose(index)
	index = index or self.pose_index
	
	local config = nil
end


function EnhancedModelScene:CreateBackdrop()
	if not self.backdrop then
		self.backdrop = self:CreateTexture(nil, "BACKGROUND", nil, -8)
		self.backdrop:SetAllPoints()
		self.backdrop:SetColorTexture(.5, .5, .5)
		self.backdrop.color = {.5, .5, .5}
		
		-- if re-enabling these, parent them to backdrop so they also show/hide automatically
		
		--[[
		self.backdrop.horizontal = self:CreateTexture(nil, "BACKGROUND", 2)
		self.backdrop.horizontal:SetSize(GetScreenWidth(), 1)
		self.backdrop.horizontal:SetPoint("CENTER")
		self.backdrop.horizontal:SetColorTexture(0, 0, 1)
		self.backdrop.horizontal:Hide()
		
		self.backdrop.vertical = self:CreateTexture(nil, "BACKGROUND", 2)
		self.backdrop.vertical:SetSize(2, GetScreenHeight())
		self.backdrop.vertical:SetPoint("CENTER")
		self.backdrop.vertical:SetColorTexture(0, 0, 1)
		self.backdrop.vertical:Hide()
		]]
		
		self.backdrop:Hide()
	end
end


function EnhancedModelScene:ToggleBackdrop()
	self:CreateBackdrop()
	self.backdrop:SetShown(not self.backdrop:IsShown())
end


function EnhancedModelScene:SetBackdropColor(r, g, b)
	self:CreateBackdrop()
	self.backdrop:SetColorTexture(r, g, b)
	self.backdrop.color = {r, g, b}
end


function EnhancedModelScene:GetBackdropColor()
	return unpack(self.backdrop.color)
end


function EnhancedModelScene:CreateCrosshairs(x, y)
	local crosshairs = self:CreateTexture(nil, "BACKGROUND")
	crosshairs:SetAllPoints()
	crosshairs:SetColorTexture(0, 0, 0, 0)

	self.crosshairs = self.crosshairs or {}
	tinsert(self.crosshairs, crosshairs)
	
	local thickness = 2 -- 	TODO: figure out appropriate thicktness. 1 disappears sometimes for me.
	
	crosshairs.horizontal = self:CreateTexture(nil, "BACKGROUND", 2)
	crosshairs.horizontal:SetSize(GetScreenWidth(), thickness)
	crosshairs.horizontal:SetColorTexture(0, 0, 1)
	
	crosshairs.vertical = self:CreateTexture(nil, "BACKGROUND", 2)
	crosshairs.vertical:SetSize(thickness, GetScreenHeight())
	crosshairs.vertical:SetColorTexture(0, 0, 1)
	
	function crosshairs:SetLocation(x, y)
		crosshairs.vertical:SetPoint("BOTTOM", nil, "BOTTOMLEFT", x, 0)
		crosshairs.horizontal:SetPoint("LEFT", nil, "BOTTOMLEFT", 0, y)
	end
	
	if x and y then
		crosshairs:SetLocation(x, y)
	end
end


function EnhancedModelScene:ApplyBarbershopToActive()
	local actor = self:GetActorAtIndex(self.active_model or 1)
	actor:SetModelByUnit("player")
	actor.who = nil
end


function EnhancedModelScene:NewModelFromBarbershop()
	self:NewActor()
end


function EnhancedModelScene:MakeBarbershopButtons()
	local button = CreateFrame("Button", nil, BarberShopFrame.AcceptButton, "UIPanelButtonTemplate")
	button:SetSize(200, 50)
	--button:SetPoint("CENTER", nil, nil, -100)
	button:SetPoint("TOPRIGHT", BarberShopFrame.AcceptButton, "TOPLEFT")
	button:SetText("set active model")
	
	self.button1 = button
	
	button:SetScript("OnClick", function() self:ApplyBarbershopToActive() end)
	
	button = CreateFrame("Button", nil, BarberShopFrame.AcceptButton, "UIPanelButtonTemplate")
	button:SetSize(200, 50)
	--button:SetPoint("CENTER", nil, nil, -100)
	button:SetPoint("TOPRIGHT", self.button1, "TOPLEFT")
	button:SetText("new model")
	self.button2 = button
	
	button:SetScript("OnClick", function() self:NewModelFromBarbershop() end)
end


function EnhancedModelScene:MakeInputFrame()
	local f = CreateFrame("Frame", nil, self)
	self.input_frame = f
	
	local sendself = SlashCmdList.ENHANCEDMODELSCENE
	
	-- FIMXE
	f.active_model = 1
	
	f:SetAllPoints(true)
	function EnhancedModelScene.input_frame:OnKeyDown(...)
		print("ems input OKD", ...)
		
		if ... == "ESCAPE" then
			self:Hide()
		elseif ... == "A" then
			sendself("+z " .. (f.active_model) .. " .001")
		elseif ... == "Z" then
			sendself("+z " .. (f.active_model) .. " -.001")
		elseif ... == "S" then
			sendself("+z " .. (f.active_model) .. " .01")
		elseif ... == "X" then
			sendself("+z " .. (f.active_model) .. " -.01")
		elseif ... == "D" then
			sendself("+z " .. (f.active_model) .. " .1")
		elseif ... == "C" then
			sendself("+z " .. (f.active_model) .. " -.1")
		elseif ... == "J" then
			EnhancedModelScene:OnMouseWheel(1)
		elseif ... == "M" then
			EnhancedModelScene:OnMouseWheel(-1)
		elseif tonumber(...) then
			
		else
			local keybind = GetBindingFromClick(...);
			print("bind was", keybind)
			
			if keybind == "SCREENSHOT" then
				Screenshot()
			end
		end
	end
	f:EnableKeyboard(true)
	
	f:SetScript("OnKeyDown", f.OnKeyDown)
	
	function f:OnShow()
		ems:SetFrameStrata("HIGH")
	end
	
	function f:OnHide()
		ems:SetFrameStrata("BACKGROUND")
	end
	
	f:SetScript("OnShow", f.OnShow)
	f:SetScript("OnHide", f.OnHide)
	
end


function EnhancedModelScene:ListConfigActors(config)
	if not config then
		config = self.pose_list[self.pose_index or 0]
	end
	
	for i = 1, #config.actors do
		local a = config.actors[i]
		print(a.index, a.who)
	end
end


function EnhancedModelScene:LoadSession(n)
	-- allow eg. -4
	if n < 1 then
		n = n + #self.sv.sessions
	end
	
	self:RebuildActorsFromScene(n)
	
	self.pose_list = self.sv.sessions[n]
	self.pose_index = 1
end


function EnhancedModelScene:LoadLastSession()
	self:LoadSession(#self.sv.sessions)
end


function EnhancedModelScene:LoadLastPose()
	self:LoadLastSession()
	self.pose_index = #self.pose_list
	-- TODO: actually create the actors and apply the pose
end


function EnhancedModelScene:ContinueLastSession()
end


-- This function should only set actors, not handle config or hiding
function EnhancedModelScene:RebuildActors(config, full)
	local actors = config.actors
	
	for i, actor in pairs(actors) do
		-- TODO: add hidden models too if available and full is set
	
		local index = actor.index
		
		self:EnsureActorCount(index)
		--[[
		for i = self:GetNumActors() + 1, index do
			self:CreateNullActor()
		end
		]]
		
		local target = self:GetActorAtIndex(index)
		
		--[[
		-- TODO: check if who is a string and an available unit
		--if type(actor.who) == "string" then
		
		local target = self:GetActorAtIndex(index)
		
		if type(actor.who) == "number" and actor.who ~= target.who then
			self:SetActorTo(index, actor.who)
		elseif actor.model == self.player_model and actor.model ~= target.model then
			-- FIXME: condition above - trying to check if player model can be used
			print("using player model as stand-in for actor", actor.index)
			self:SetActorTo(index, "player")
		end
		]]
		
		local t = actor.model_source or {}
		
		local source = t.type
		local value = t.value
		
		if source == nil then
			if actor.who then
				target:SetModelByUnit(actor.who)
			end
			
			if actor.file and actor.file ~= target:GetModelFileID() then
				target:SetModelByFileID(actor.file)
			end
		elseif source == "creatureID" then
			target:SetModelByCreatureDisplayID(value)
		elseif source == "file" then
			target:SetModelByFileID(value)
		elseif source == "unit" then
			if actor.who then
				-- try setting by name
				target:SetModelByUnit(actor.who)
				-- TODO: figure out how to check if it worked, vs 
				-- already had a different unit with the same file id
			end
			
			if target:GetModelFileID() ~= actor.file then
				-- For now, check if we can substitute the current player
				target:SetModelByUnit("player")
				-- FIXME: if player is a stand-in, this will make config different from the source
				
				if target:GetModelFileID() ~= actor.file then
					--target:SetModelByCreatureDisplayID(AXISTESTOBJECT)
					print("don't have reference for actor", i)
					target:SetModelByFileID(actor.file)
				end
			end
		end
		
		target:Show() -- TODO: unless rebuilding a hidden actor
	end
end


-- TODO: how should we handle when model at an index changes?
function EnhancedModelScene:RebuildActorsFromScene(scene)
	if not scene then
		scene = self.sv.sessions[#self.sv.sessions]
	elseif type(scene) == "number" then
		scene = self.sv.sessions[scene]
	end
	
	for i, config in ipairs(scene) do
		self:RebuildActors(config)
	end
end


function EnhancedModelScene:GetConfig(session, index)
	return self.sv.sessions[session][index]
end


--[[
function EnhancedModelScene:AddPhasorToActor(n, period, phase, action)
	local actor = self:GetActorAtIndex(n)
	period, phase, action = period or 1, phase or 0, action or function() end
	actor.phasor = { phase = phase, period = period, action = action }
end
]]


function EnhancedModelScene:UpdateActorPhasors(elapsed)
	for i = 1, self:GetNumActors() do
		local actor = self:GetActorAtIndex(i)
		actor:UpdatePhasors(elapsed)
		
		--[[
		local phasor = actor.phasor
		
		if phasor then
			
			phasor.phase = phasor.phase + elapsed / phasor.period
			
			if actor:IsVisible() then
				phasor:action(actor)
			end
		end
		]]
	end
end


function EnhancedModelScene:UpdateActors(elapsed)
	for i = 1, self:GetNumActors() do
		local a = self:GetActorAtIndex(i)
		local actor = a
		
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
		
		if actor.move_speed then
			actor:SlideOnAxis(1, elapsed * actor.move_speed)
		end
	
		if actor.turn_speed then
			-- FIXME:
			local initial = a:GetRotationMatrix()
			local rotation = self.Matrix.AngleAxis(elapsed * a.turn_speed, initial:GetBasisVector(3))
			
			a:SetOrientation(self.Matrix.hmult(rotation, initial))
		end

	end
end


function EnhancedModelScene:GetActorMatrix(n)
	local a = self:GetActorAtIndex(n)
	
	local m = self.Matrix.YPR(a:GetYaw(), a:GetPitch(), a:GetRoll())
	self.Matrix.MergeTranslation(m, self:GetScaledPosition(n))
	
	return m
end


function EnhancedModelScene:ApplyActorMatrix(m, n)
	local yaw, pitch, roll = self.Matrix.GetYPR(m)
	local x, y, z = self.Matrix.GetXYZ(m)

	local a = self:GetActorAtIndex(n)
	
	self:SetScaledPosition(n, x, y, z)
	a:SetYaw(yaw)
	a:SetPitch(pitch)
	a:SetRoll(roll)
end


--local ActorMixin = EnhancedModelScene.ActorMixin


function EnhancedModelScene:GetScaledPosition(n)
	local actor = self:GetActorAtIndex(n)
	local s = actor:GetScale()
	local x, y, z = actor:GetPosition()
	return s*x, s*y, s*z
end


function EnhancedModelScene:SetScaledPosition(n, x, y, z)
	local actor = self:GetActorAtIndex(n)
	local s = actor:GetScale()
	actor:SetPosition(x/s, y/s, z/s)
end


function EnhancedModelScene:LinkActorTo(follower, leader)
	local f = self:GetActorAtIndex(follower)
	local l = self:GetActorAtIndex(leader)
	
	f.relative_to = leader
	f.transform = f:GetRelativeMatrix(l)
end

--[[
function EnhancedModelScene:UnlinkActor(n)
	local a = self:GetActorAtIndex(n)
	a.transform = nil
	a.relative_to = nil
end
]]

function EnhancedModelScene:GetScaledCenterOffset(n)
	local a = self:GetActorAtIndex(n)
	
	local x, y, z = a:GetRawCenter()
	local s = a:GetScale()
	
	return s*x, s*y, s*z
end


function EnhancedModelScene:GetRawCenterFor(file) --, animation)
	return self.ModelCenters:GetCenterFor(file)
	--[[
	local x, y, z = 0, 0, 0
	
	local m = self.model_centers[file]

	if m then
		x, y, z = m.x or x, m.y or y, m.z or z
		
		local a = m[animation]
		
		if a then
			x, y, z = a.x or x, a.y or y, a.z or z
		end
	end
	
	return x, y, z]]
end

--[[
function EnhancedModelScene:SetCenterGuess(actor, x, y, z)
	local file, animation = actor:GetModelFileID(), actor:GetAnimation()
	print("SCG", file, animation, x, y, z)
	
	self.model_centers[file][animation or 0] = { x = x, y = y, z = z}
end
]]

function EnhancedModelScene:GetScaledCenter()
end


function EnhancedModelScene:PrintSessionSpans(start, stop)
	for i = start or 1, stop or #self.sv.sessions do
		local session = self.sv.sessions[i]
		local start_time = session.time
		local end_time = session[#session].notes.time
		
		print(i, date("%m/%d/%y %H:%M:%S", start_time), "to", date("%m/%d/%y %H:%M:%S", end_time))
	end
end


function EnhancedModelScene:ChangeOriginTo()
end


-- Tile new models, starting at sx sy sz, with grid spacing dx dy dz, quantity nx ny nz, of model with given orientation
function EnhancedModelScene:NewTiling(sx, sy, sz, dx, dy, dz, nx, ny, nz, model, y, p, r)
	-- allow/correct specifying 0 entries in a dimension
	-- maybe have the input command accept eg. #4 +3 syntaxes
	nx, ny, nz = max(1, nx), max(1, ny), max(1, nz)
	
	local x, y, z = sx, sy, sz
	
	for k = 1, nz do
		for j = 1, ny do
			for i = 1, nx do
				local a = self:NewActor(model)
				a:SetScaledPosition(x, y, z)
				a:SetYPRDegrees(y, p, r)
				x = x + dx
			end
			
			x = sx
			y = y + dy
		end
		
		y = sy
		z = z + dz
	end
end


function EnhancedModelScene:AdvancedTiling(config)
	local ox, oy, oz = unpack(config.origin)
	local dx, dy, dz = unpack(config.deltas)
	local nx, ny, nz = unpack(config.counts)
	print(config.random)
	local rx, ry, rz = unpack(config["random"])
	local y, p, r = unpack(config.ypr)
	local yr, pr, rr = unpack(config.yprrnd)
	
	local models = config.models
	if type(models) ~= "table" then
		models = {models}
	end
	
	local x, y, z = ox, oy, oz
	
	for k = 1, nz do
		for j = 1, ny do
			for i = 1, nx do
				local model = models[math.random(#models)]
				
				local u = x + RandomFloatInRange(-rx, rx)
				local v = y + RandomFloatInRange(-ry, ry)
				local w = z + RandomFloatInRange(-rz, rz)
				
				local a = y + RandomFloatInRange(-yr, yr)
				local b = p + RandomFloatInRange(-pr, pr)
				local c = r + RandomFloatInRange(-rr, rr)
				
				local actor = self:NewActor(model)
				actor:SetScaledPosition(u, v, w)
				actor:SetYPRDegrees(a, b, c)
				x = x + dx
			end
			
			x = ox
			y = y + dy
		end
		
		y = oy
		z = z + dz
	end
end


function EnhancedModelScene:OnCommReceived(prefix, message, channel, who)
	if self.print_comm_received then
		print("ems comm received", prefix, message, channel, who)
	end
	
	if prefix == SYNC_PREFIX and self.allow_sync then
		-- FIXME: may want to test commands by whispering to self, but not the normal intent of run_via_sync
		if who ~= UnitName("player") or self.run_via_sync then
			self:DoCommand(message, "sync")
		end
	end
end


do
	self:Hide()
	
	self.not_shown_yet = true

	self:SetScript("OnShow", self.OnFirstShow)
	self:SetScript("OnUpdate", self.OnUpdate)
	self:SetScript("OnMouseWheel", self.OnMouseWheel)
	self:SetScript("OnMouseDown", self.OnMouseDown)
	self:SetScript("OnMouseUp", self.OnMouseUp)
	self:SetScript("OnEvent", self.OnEvent)

	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("PLAYER_LOGIN")
	self:RegisterEvent("SCREENSHOT_STARTED")
	self:RegisterEvent("SCREENSHOT_SUCCEEDED")
	self:RegisterEvent("BARBER_SHOP_OPEN")

	self:SetAllPoints(WorldFrame)
	self:SetFrameStrata("BACKGROUND")

	--self:ResetCamera()
	--self:SetCameraFieldOfView(rad(90))	-- this gets changed OnFirstShow

	getmetatable(self).__call = function(self, ...)
		if type(...) == "number" then
			return self:GetActorAtIndex(...)
		end
	end

	self.fix_scale = true
	
	ems = self	-- TODO: only do this if a savedvar flag is set?

	--LibStub("AceComm-3.0"):Embed(self)

	self:RegisterComm(SYNC_PREFIX)
end
