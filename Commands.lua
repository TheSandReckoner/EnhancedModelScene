--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021-2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local _, addon_table = ...
local EnhancedModelScene = addon_table.self
local EMS = EnhancedModelScene

if not EMS then return end

local Commands = {}
EnhancedModelScene.Commands = Commands

local Splitter = {}
Commands.Splitter = Splitter
--[[ Design considerations:
Splitter is a stateful convenience for retrieving arguments as needed.
Although I plan to add a batching command (primarily to group simultaneous 
commands in synced scripts), it might still work as a singleton.
]]

-- FIXME: in batch command, protect against malformed batched commands causing wrong splits

-- converts each argument to a number, if possible (leaves intact otherwise)
local function tonumberall(...)
	local list = {...}
	
	-- list might have a hole that would break ipairs
	for k, v in pairs(list) do
		list[k] = tonumber(v) or v
	end
	
	return unpack(list, 1, select("#", ...))
end
	

--[[
need flag for how command should be synced
as-is, revise, don't-sync
]]


Commands.commands = {}

function Commands:Dispatch(input, source)
	Splitter:SetInput(input)
	local command = Splitter:GetArgs(1)
	
	local handler = self:GetHandler(command)
	
	-- TODO: convert everything to use Splitter instead
	local resume_at = Splitter.index
	
	if handler then
		if type(handler) == "string" then
			handler = self.commmands[handler]
		end
		
		if not handler then
			error("Alias pointed to invalid handler")
		end
		
		if type(handler) == "function" then
			handler(command, input, resume_at)
		elseif type(handler) == "table" then
			handler.func(command, input, resume_at)
		else
			error("invalid handler type")
		end
	else
		-- try the old command block
		
		local no_match

		local cmd, remainder = input:match("(%S+)%s*(.*)")
		cmd = cmd:lower()
		
		local self = EnhancedModelScene
		
		--print("trying old command block")
		print(cmd, remainder)
		
		if cmd == "new" or cmd == "newactor" then
			self:NewActor(remainder)
			
			print("changing active model from", self.active_model, "to", self:GetNumActors())
			self.active_model = self:GetNumActors()
		elseif cmd == "set" or cmd == "change" then
			local index, target = strsplit(" ", remainder)
			self:SetActorTo(self:GetActorAtIndex(tonumber(index)), target)
		elseif cmd == "setfile" or cmd == "setf" then
			local index, target = strsplit(" ", remainder)
			-- FIXME: warn and require SV flag, also could check a database
			local actor = self:GetActorAtIndex(tonumber(index))
			actor:SetModelByFileID(tonumber(target))
			actor.who = nil
		elseif cmd == "setunit" then
			local index, unit = strsplit(" ", remainder)
			print(("unit '%s' is %s"):format(unit, UnitGUID(unit)))
		elseif cmd == "setbyguid" then
			local index, GUID = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)):SetByGUID(GUID)
		elseif cmd == "store" then
			-- store to a variable
		elseif cmd == "anim" or cmd == "animation" then
			-- FIXME: arguments
			local index, anim, variation, speed, offset = strsplit(" ", remainder)
			index, anim, variation = tonumber(index), tonumber(anim) or 0, tonumber(variation) or 0
			offset, speed = tonumber(offset) or 0, tonumber(speed) or 1
			
			local actor = self:GetActorAtIndex(index)
			actor:SetAnimation(anim, variation, speed, offset)
			actor.animation = anim
			actor.offset = offset
			actor.speed = speed
			actor.variation = variation
			
			if self.log then
				tinsert(self.log, { GetTime(), "SetAnimation", index, anim, variation, speed, offset} )
			end
		elseif cmd == "scale" then
			local index, scale = strsplit(" ", remainder)
			
			local actor = self:GetActorAtIndex(tonumber(index))
			
			if self.fix_scale then
				local old_scale = actor:GetScale()
				local x, y, z = actor:GetPosition()
				local k = old_scale / scale
				x, y, z = k*x, k*y, k*z
				actor:SetPosition(x, y, z)
			end
			
			actor:SetScale(tonumber(scale))
			
			if self.log then
				tinsert(self.log, { GetTime(), "SetScale", index, scale} )
			end
		elseif cmd == "move" or cmd == "adjust" or cmd == "active" or cmd == "setcurrent" then
			-- set the model at the index for individual adjustment
			self.active_model = tonumber(remainder)
		elseif cmd == "getcurrent" then
			print(self.active_model)
		elseif cmd == "hide" then
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):Hide()
		--[[elseif cmd == "show" then
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):Show()]]
		elseif cmd == "hideall" then
			for i = 1, self:GetNumActors() do
				self:GetActorAtIndex(i):Hide()
			end
		elseif cmd == "showall" then
			for i = 1, self:GetNumActors() do
				self:GetActorAtIndex(i):Show()
			end
		elseif cmd == "setglobal" then
			local index, name = strsplit(" ", remainder)
			if not name then name = "a" .. index end
			index = tonumber(index)
			
			print(index, name)
			
			_G[name] = self:GetActorAtIndex(index)
		elseif cmd == "backdrop" or cmd == "bd" then
			local r, g, b = strsplit(" ", remainder)
			
			r = r:lower()
			
			if r == "" then
				self:ToggleBackdrop()
			elseif r == "show" then
				self.backdrop:Show()
			elseif r == "hide" then
				self.backdrop:Hide()
			else
				-- set to a color and show
				if tonumber(r) then
					r, g, b = tonumber(r), tonumber(g), tonumber(b)
				else
					local colors = {
						red = {1, 0, 0},
						green = {0, 1, 0},
						blue = {0, 0, 1},
						grey = {.5, .5, .5},
						gray = {.5, .5, .5},
						white = {1, 1, 1},
						black = {0, 0, 0},
					}
						
					local t = colors[r:lower()]
					
					if t then
						r, g, b = unpack(t)
					else
						print("unrecognized color")
					end
				end
				
				if type(r) == "number" then
					self:SetBackdropColor(r, g, b)
					self.backdrop:Show()
				end
			end
			
			if source ~= "sync" then
				self.Bucket:SendToBucket("backdrop")
			end
		elseif cmd == "greenscreen" or cmd == "gs" then
			Commands:Dispatch("backdrop green")
		elseif cmd == "fov" then
			local degrees = tonumber(remainder)
			self:SetCameraFieldOfView(rad(degrees))
		elseif cmd == "undress" then
			self:GetActorAtIndex(tonumber(remainder)):Undress()
		elseif cmd == "clearslot" or cmd == "undressslot" then
			local index, slot = strsplit(" ", remainder)
			
			if not index or index == "" then
				-- TODO: print slot IDs if no arg?
				print("slot list NYI")
				return
			end
			
			if tonumber(slot) then
				slot = tonumber(slot)
				self:GetActorAtIndex(tonumber(index)):UndressSlot(slot)
			else
				local slot_names = {
					"head",
					{"shoulder", "shoulders",},
					"back",
					"chest",
					{"body", "shirt",},
					"tabard",
					{"wrist", "wrists",},
					{"hand", "hands",},
					"waist",
					"legs",
					"feet",
					"mainhand",
					"offhand",
				}
				
				local slot_map = {}
				
				for _, names in pairs(slot_names) do
					local main_name = names
					if type(names) == "table" then
						main_name = names[1]
					end
					local slot_constant = "INVSLOT_" .. main_name:upper()
					local slotID = _G[slot_constant]
					--print(slot_constant)
					if type(names) == "table" then
						for _, name in pairs(names) do
							slot_map[name] = slotID
						end
					else
						slot_map[names] = slotID
					end
				end
				
				local slotID = slot_map[slot:lower()]
				
				if slotID then
					self:GetActorAtIndex(tonumber(index)):UndressSlot(slotID)
				else
					print("unrecognized slot")
				end
			end
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
		elseif cmd == "pos" or cmd == "position" or cmd == "xyz" then
			local index, x, y, z = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetScaledPosition(x, y, z)
		elseif cmd == "rawpos" or cmd == "rawposition" then
			local index, x, y, z = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetPosition(x, y, z)
		elseif cmd == "getpos" then
			local index = tonumber(remainder)
			local actor = self:GetActorAtIndex(index)
			
			if self.fix_scale then
				local s = actor:GetScale()
				local x, y, z = actor:GetPosition()
				print(x*s, y*s, z*s)
			else
				print(actor:GetPosition())
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
		elseif cmd == "yaw" then
			local index, degrees = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetYaw(rad(degrees))
		elseif cmd == "pitch" then
			local index, degrees = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetPitch(rad(degrees))
		elseif cmd == "roll" then
			local index, degrees = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetRoll(rad(degrees))
		elseif cmd == "ryaw" or cmd == "yawr" then
			local index, radians = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetYaw(radians)
		elseif cmd == "rpitch" or cmd == "pitchr" then
			local index, radians = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetPitch(radians)
		elseif cmd == "rroll" or cmd == "rollr" then
			local index, radians = strsplit(" ", remainder)
			local model = self:GetActorAtIndex(tonumber(index))
			model:SetRoll(radians)
		elseif cmd == "orientation" or cmd == "ori" or 
		cmd == "ypr" or cmd == "yprd" or cmd == "yprdeg" or cmd == "yprdegrees" then
			local index, yaw, pitch, roll = strsplit(" ", remainder)
			local actor = self:GetActorAtIndex(tonumber(index))
			actor:SetYaw(rad(tonumber(yaw)))
			actor:SetPitch(rad(tonumber(pitch)))
			actor:SetRoll(rad(tonumber(roll)))
		elseif cmd == "yprr" or cmd == "yprrad" or cmd == "yprradians" then
			local index, yaw, pitch, roll = strsplit(" ", remainder)
			local actor = self:GetActorAtIndex(tonumber(index))
			actor:SetYaw(tonumber(yaw))
			actor:SetPitch(tonumber(pitch))
			actor:SetRoll(tonumber(roll))
		elseif cmd == "whois" then
			local index = tonumber(remainder)
			print(self:GetActorAtIndex(index).who)
		elseif cmd == "input" then
			if not self.input_frame then
				self:MakeInputFrame()
			end
			C_Timer.After(1, function() self.input_frame:Show() end)
		elseif cmd == "relpos" then
		elseif cmd == "copypos" then
		elseif cmd == "lockmodel" then
			local a = self:GetActorAtIndex(tonumber(remainder))
			a.lock_model = true
		elseif cmd == "unlockmodel" then
			local a = self:GetActorAtIndex(tonumber(remainder))
			a.lock_model = false
		elseif cmd == "alpha" then
			local index, value = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)):SetAlpha(tonumber(value) or 1)	
		elseif cmd == "desat" then
			local index, value = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)):SetDesaturation(tonumber(value) or 1)
		elseif cmd == "getfile" then
			print(self:GetActorAtIndex(tonumber(remainder)):GetModelFileID())
		elseif cmd == "rotatemodel" or cmd == "rotate" then
			
			-- rotate actor around its internal axis
			local index, axis, angle = strsplit(" ", remainder)
			-- FIXME: might need to adjust angle value if the actor is scaled
			
			local a = self:GetActorAtIndex(tonumber(index))
			a:RotateDegreesAroundAxis(tonumber(angle), tonumber(axis))
		elseif cmd == "rotaterel" or cmd == "rotateref" then
			-- rotate actor around a different actor's axis
			local target, reference, axis, angle = strsplit(" ", remainder)
			target = self:GetActorAtIndex(tonumber(target))
			reference = self:GetActorAtIndex(tonumber(reference))

			-- FIXME: might need to adjust angle value if the actor is scaled
			
			target:RotateDegrees(tonumber(angle), reference:GetBasisVector(tonumber(axis)))
			--[[
			local initial = target:GetRotationMatrix()
			local rotation = self.Matrix.AngleAxis(rad(tonumber(angle)), reference:GetBasisVector(tonumber(axis)))
			
			target:SetOrientation(self.Matrix.hmult(rotation, initial))
			]]
		elseif cmd == "slide" then
			-- shift a model along an internal axis
			local index, axis, distance = strsplit(" ", remainder)
			local a = self:GetActorAtIndex(tonumber(index))
			a:SlideOnAxis(tonumber(axis), tonumber(distance))
		elseif cmd == "slideother" or cmd == "slideo" or cmd == "slideby" then
			local x, y, z = reference:GetRotationMatrix():GetBasisVector(tonumber(axis))
			target:Slide(x, y, z, tonumber(distance))
		elseif cmd == "showtarget" then
			if not self.camera_target then
				self.camera_target = self:NewActor(34715)
				self.camera_target:SetScaledPosition(self:GetCameraTarget())
			end
		elseif cmd == "listsessions" then
			self:PrintSessionSpans()
		elseif cmd == "loadlastsession" or cmd == "lastsession" then
			self:LoadLastSession()
		elseif cmd == "loadsession" then
			local index = tonumber(remainder)
			self:LoadSession(index)
		elseif cmd == "rebuild" then
			local index = tonumber(remainder) or #self.sv.sessions
			self:RebuildActorsFromScene(self.sv.sessions[index])
		elseif cmd == "continue" then
			self:ContinueLastSession()
		elseif cmd == "name" then
			local index, name = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)).who = name
		elseif cmd == "allowsync" then
			self.allow_sync = true
		elseif cmd == "stopsync" then
			self.allow_sync = false
		elseif cmd == "fullsync" then
			self.sync = true
			self.allow_sync = true
			self.group_sync = true
		elseif cmd == "getscale" then
			print(self:GetActorAtIndex(tonumber(remainder)):GetScale())
		elseif cmd == "copy" then
			local source, target = strsplit(" ", remainder)
			source, target = tonumber(source), tonumber(target)
			self.active_model = target
			source, target = self:GetActorAtIndex(source), self:GetActorAtIndex(target)
			-- let a dedicated function track what to copy
			target:CopyFrom(source)
		elseif cmd == "link" then
			local leader, nextposition = self:GetArgs(remainder)
			local followers = {self:GetArgs(remainder, self.MAX_ARGS, nextposition)}
			leader = tonumber(leader)
			-- as long as MAX_ARGS is greater than the actual number of arguments,
			-- ipairs should stop before reading the next position return, but 
			-- fix the table to prevent a hard-to-track error.
			-- (Note the reference manual suggests ipairs will not fall into the same
			-- trap that # can with a non-continuous array
			followers[self.MAX_ARGS+1] = nil
			for i, index in ipairs(followers) do
				self:LinkActorTo(tonumber(index), leader)
			end
		elseif cmd == "unlink" then
			-- TODO: allow a list of indices to unlink
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):Unlink()
		elseif cmd == "searchfiles" then
			self:ScrollMatchingFiles(remainder)
		elseif cmd == "walk" or cmd == "walkspeed" then
			local index, speed = strsplit(" ", remainder)
			index, speed = tonumber(index), tonumber(speed)
			local actor = self:GetActorAtIndex(index)
			actor.move_speed = speed
			actor:PickAnimation()
		elseif cmd == "turn" or cmd == "turnspeed" then
			local index, speed = strsplit(" ", remainder)
			index, speed = tonumber(index), tonumber(speed)
			local actor = self:GetActorAtIndex(index)
			actor.turn_speed = speed			
			actor:PickAnimation()
		elseif cmd == "immersion" then
			self.Immersion:SetShown(not self.Immersion:IsShown())
		elseif cmd == "resetcamera" then
			self:ResetCamera()
		elseif cmd == "dev" then
			self.always_print_sync = true
			self.print_comm_received = true
			self.print_sent_comms = true
		elseif cmd == "equiplink" then
			local index, link = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)):DressFromLink(link)
		elseif cmd == "pivot" or cmd == "setpivot" then
			local index, space, x, y, z = strsplit(" ", remainder)
			self:GetActorAtIndex(tonumber(index)):SetPivot(space, tonumber(x), tonumber(y), tonumber(z))
		elseif cmd == "clearpivot" then
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):ClearPivot()
		elseif cmd == "disablepivot" then
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):DisablePivot()
		elseif cmd == "enablepivot" then
			local index = tonumber(remainder)
			self:GetActorAtIndex(index):EnablePivot()
		elseif cmd == "getpoint" then
			local index, space, point = strsplit(" ", remainder)
			print(self:GetActorAtIndex(tonumber(index)):GetPoint(space, point))
		elseif cmd == "importconfig" then
			print("config received for import")
			self.last_config_received = remainder
			-- FIXME: differentiate between locally imported vs received via sync, 
			-- and only apply via sync if set to accept
			self:ApplySerializedConfig(remainder)
		elseif cmd == "demo" then
			ems.Script:Run(ems.Script.demo)
		elseif cmd == "testscript" or cmd == "scripttest" then
			-- for scripts that are more experimental than demos
			-- TODO: index a list
			EMS.Script:Run(EMS.Script.test_script)
		else
			no_match = true
		end
		
		if no_match then
			print("unrecognized command")
		end
	end
end


function Commands:GetHandler(command)
	assert(command)
	
	local handler = self.commands[command]
	
	while type(handler) == "string" do
		local h = self.commands[handler]
		
		if not h then
			error(("Alias '%s' pointed to missing command"):format(handler))
		end
		
		handler = h
	end
	
	return handler
end


function Commands.commands.moveto(command, input, resume_at)
	print(command, input, resume_at)
	
	local point_source, point, object = EMS:GetArgs(input, 3, resume_at)
	print(point_source, point, object)
	
	local x, y, z
	
	if point_source == "camera" then
		print("NYI")
	elseif tonumber(point_source) then
		point_source = tonumber(point_source)
		x, y, z = EMS:GetActorAtIndex(point_source):GetPoint("world", point)
		print(x, y, z)
	else
		print("unrecognized source")
		return
	end
	
	if object == "camera" then
		EMS:SetCameraPosition(x, y, z)
	elseif object == "camera_target" or object == "cameratarget" then
		EMS:SetCameraTarget(x, y, z)
		-- TODO: turn camera in place, or shift based on orientation & distance?
	elseif tonumber(object) then
		object = tonumber(object)
		EMS:GetActorAtIndex(object):SetScaledPosition(x, y, z)
	else
		print("unrecognized object")
	end
end


function Commands:Add(data)
	self.commands[data.name] = data
	
	self:AddMappings(data.name, data)
	
	-- order doesn't matter
	if data.aliases then
		for i, alias in pairs(data.aliases) do
			self:AddMappings(alias, data)
		end
	end
end


function Commands:AddMappings(name, handler)
	self.commands[name] = handler
	self.commands[name:lower()] = handler
end


function Splitter:Reset()
	self.input = nil
	self.index = 1
end


function Splitter:SetInput(input)
	self:Reset()
	self.input = input
end


local function pack(...)
	return {...}, select('#', ...)
end


function Splitter:GetArgs(count)
	local returns = { EMS:GetArgs(self.input, count, self.index) }
	self.index = returns[count+1]
	return unpack(returns, 1, count)
end
	

--[[
function Splitter:GetRemainingArgs()
	-- use the length of the input string as 
	-- the expected maximum number of arguments
	local returns, count = pack(EMS:GetArgs(self.input, #(self.input), self.index))
	assert()
	returns[count] = nil
	return returns, count-1
end]]


local GetArgs = EMS.GetArgs

-- AceConsole's GetArgs implementation doesn't work well
-- for getting lists, but since it's recursive anyway, 
-- reimplement the recursion.
local function GetAllArgs(str, pos)
	local arg
	pos = pos or 1
	arg, pos = GetArgs(nil, str, 1, pos)

	if pos == 1e9 then
		return arg
	else
		return arg, GetAllArgs(str, pos)
	end
end


function Splitter:GetRemainingArgs()
	local index = self.index
	self.index = 1e9
	return GetAllArgs(self.input, index)
end


function Commands.commands.getpointfrompoint(command, input, resume_at)
	local basis_index, basis_space, query_index, query_point = EMS:GetArgs(input, 4, resume_at)
	
	basis_index, query_index = tonumber(basis_index), tonumber(query_index)
	local wx, wy, wz = EMS:GetActorAtIndex(query_index):GetPoint(query_point)
	--local rel = self:GetActorAtIndex(basis_index):GetRelativeMatrix(self:GetActorAtIndex(query_index))
	-- FIXME: respect basis_space
	local sx, sy, sz = EMS:GetActorAtIndex(basis_index):FromWorldToCenterSpace(wx, wy, wz)
	print(sx, sy, sz)
end


Commands:Add({
	name = "SaveBundle",
	aliases = {"Bundle"},
	sync = false,
	func = function(command, input, resume_at)
		local name, primary, resume_at = EMS:GetArgs(input, 2, resume_at)
		local followers = { EMS:GetArgs(input, EMS.MAX_ARGS, resume_at) }
		
		--print("name '", name, "' primary", primary, "resume_at", resume_at)
		local config = EMS:GetConfigForActors(primary, unpack(followers))
		config.name = name
		
		-- FIXME: change config origin to primary model. Leave orientation.
		
		EMS.sv.model_bundles = EMS.sv.model_bundles or {}
		EMS.sv.model_bundles[name] = config
	end,
})

Commands:Add({
	name = "LoadBundle",
	aliases = {"ApplyBundle"},
	sync = false, -- FIXME: need to propagate configuration on the modified actors
	func = function(command, input, resume_at)
		local bundle_name, primary_index
		bundle_name, primary_index, resume_at = EMS:GetArgs(input, 2, resume_at)
		local bundle = EMS.sv.model_bundles[bundle_name]
		
		if not bundle then
			print(("couldn't find bundle \"%s\""):format(bundle_name))
			return
		end
		
		primary_index = tonumber(primary_index)
		
		-- We need the matrix of the primary actor in its current 
		-- position, to place the other actors relative to it.
		local base_matrix = EMS:GetActorAtIndex(primary_index):GetCenterMatrix()
		
		-- The saved primary model might not be in default configuration, so we will need 
		-- to adjust the follower matrices.
		local primary_matrix = EMS.ActorConfig:GetCenterMatrixFromConfig(bundle.actors[1])
		local inverse = primary_matrix:GetInverse()
		
		-- get the list of actors to apply the configs to
		local indices = { EMS:GetArgs(input, #(bundle.actors) - 1, resume_at) }
		resume_at = indices[#indices]
		indices[#indices] = nil
		
		for i, index in ipairs(indices) do
			local actor = EMS:GetActorAtIndex(tonumber(index))
			local config = bundle.actors[i+1]
			
			local follower_matrix = EMS.ActorConfig:GetCenterMatrixFromConfig(config)
			local rel_matrix = EMS.Matrix.hmult(inverse, follower_matrix)

			-- now apply the relative transformation to the base 
			-- matrix to get the desired configuration for this actor
			local actor_matrix = EMS.Matrix.hmult(base_matrix, rel_matrix)
			
			actor:SetCenterTransform(actor_matrix)
			
			-- send sync information
			-- FIXME: skip calculations if don't need to send sync info
			if true then
				EMS:SendSyncCommand(("scale %s %f"):format(index, actor:GetScale()))
				EMS:SendSyncCommand(("pos %s %f %f %f"):format(index, actor:GetScaledPosition()))
				EMS:SendSyncCommand(("ypr %s %f %f %f"):format(index, actor:GetYPRDegrees()))
			end
			
			EMS:LinkActorTo(index, primary_index)
			-- FIXME: send sync info here
		end
		
		--EMS:SendSyncCommand(("link %i 
	end,
})

--[[
Commands:Add({
	name = "SetCenterTransform",
	aliases = {"ApplyMatrix", "SetCenterMatrix", "ApplyTransform"}
	sync = true,
	func = function(command, input, resume_at)
]]

Commands:Add({
	name = "Sleep",
	sync = false,
	func = function(command, input, resume_at)
		local duration = EMS:GetArgs(input, 1, resume_at)
		coroutine.yield(tonumber(duration))
	end
})

Commands:Add({
	name = "SetAmbientColor",
	sync = true,
	func = function(command, input, resume_at)
		local r, g, b = EMS:GetArgs(input, 3, resume_at)
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		EMS:SetLightAmbientColor(r, g, b)
	end,
})

Commands:Add({
	name = "SetDiffuseColor",
	sync = true,
	func = function()
		local r, g, b = tonumberall(Splitter:GetArgs(3))
		EMS:SetLightDiffuseColor(r, g, b)
	end,
})

Commands:Add({
	name = "SetLightDirection",
	sync = true,
	func = function()
		local x, y, z = tonumberall(Splitter:GetArgs(3))
		EMS:SetLightDirection(x, y, z)
	end,
})

Commands:Add({
	name = "SetLightPosition",
	sync = true,
	func = function()
		local x, y, z = tonumberall(Splitter:GetArgs(3))
		EMS:SetLightPosition(x, y, z)
	end,
})

		
-- FIXME: add light settings to SceneState

Commands:Add({
	name = "SetOPS",
	aliases = {"OPS"},
	sync = true,
	func = function(command, input, resume_at)
		local index, yaw, pitch, roll, x, y, z, scale = EMS:GetArgs(input, 8, resume_at)
		local actor = EMS:GetActorAtIndex(tonumber(index))
		
		if scale then
			actor:SetScale(tonumber(scale))
		end
		
		actor:SetYPRDegrees(tonumber(yaw), tonumber(pitch), tonumber(roll))
		actor:SetScaledPosition(tonumber(x), tonumber(y), tonumber(z))
	end,
})

Commands:Add({
	name = "Tile1",
	sync = true,
	func = function(command, input, resume_at)
		local sx, sy, sz, dx, dy, dz, nx, ny, nz, model, y, p, r = EMS:GetArgs(input, 13, resume_at)
		sx, sy, sz = tonumber(sx), tonumber(sy), tonumber(sz)
		dx, dy, dz = tonumber(dx), tonumber(dy), tonumber(dz)
		nx, ny, nz = tonumber(nx), tonumber(ny), tonumber(nz)
		y, p, r = tonumber(y), tonumber(p), tonumber(r)
		
		EMS:NewTiling(sx, sy, sz, dx, dy, dz, nx, ny, nz, model, y, p, r)
	end
})

Commands:Add({
	name = "Reticle",
	aliases = {"Crosshairs"},
	sync = false,
	func = function(command, input, resume_at)
		local subcommand
		subcommand, resume_at = EMS:GetArgs(input, 1, resume_at)
		
		if subcommand == "new" then
			EMS.Reticle:NewCrosshairs()
			print("New reticle at index", #EMS.Reticle)
		elseif subcommand == "hide" then
			local index = EMS:GetArgs(input, 1, resume_at)
			EMS.Reticle[tonumber(index)]:Hide()
		elseif subcommand == "show" then
			local index = EMS:GetArgs(input, 1, resume_at)
			EMS.Reticle[tonumber(index)]:Show()
		elseif subcommand == "color" then
			local index, r, g, b, a = EMS:GetArgs(input, 5, resume_at)
			EMS.Reticle[tonumber(index)]:SetColor(r, g, b, a)
		elseif subcommand == "follow" then
			local index, target
			index, target, resume_at = EMS:GetArgs(input, 2, resume_at)
			
			local reticle = EMS.Reticle[tonumber(index)]
			
			if target == "cursor" then
				reticle.follow = {type = "cursor"}
			elseif target == "actor" or target == "model" then
				local index, point
				index, point, resume_at = EMS:GetArgs(input, 2, resume_at)
				
				reticle.follow = {type = "actor", index = tonumber(index), subtype = point}
			end
		end
	end,
})

--[[
Commands:Add({
	name = "Comment",
	aliases = {"Rem", "--"},
	sync = false,
	func = function(command, input, resume_at)
]]

Commands:Add({
	name = "SetCameraParameters",
	aliases = {"SetCamera"},
	func = function(command, input, resume_at)
		local yaw, pitch, roll, x, y, z, distance = EMS:GetArgs(input, 7, resume_at)
		yaw, pitch, roll = tonumberall(yaw, pitch, roll)
		x, y, z = tonumberall(x, y, z)
		distance = tonumber(distance)
		
		-- similar steps to loading a saved scene's camera
		print(x, y, z)
		EMS:SetCameraPosition(x, y, z)
		EMS.r = distance
		EMS.update_target = true
		EMS.yaw, EMS.pitch, EMS.roll = rad(yaw), rad(pitch), rad(roll)
		EMS:UpdateCamera()
	end,
})

Commands:Add({
	name = "GetCameraParameters",
	aliases = {"GetCamera"},
	sync = false,
	func = function(command, input, resume_at)
		local yaw, pitch, roll = EMS:GetCameraYPRDegrees()
		local x, y, z = EMS:GetCameraPosition()
		local distance = EMS:GetCameraDistance()
		print("ypr, xyz, d:", yaw, pitch, roll, x, y, z, distance)
	end
})

Commands:Add({
	name = "Show",
	aliases = {"ShowActor", "ShowActors"},
	sync = true,
	func = function()
		local list, count = pack(Splitter:GetRemainingArgs())
		
		for i = 1, count do
			local index = tonumber(list[i])
			EMS:GetActorAtIndex(index):Show()
		end
	end,
})

-- Ensure that at least the specified number of actors exist.
-- Intended for scripting
Commands:Add({
	name = "MinActors",
	sync = true,
	func = function()
		local count = Splitter:GetArgs(1)
		
		EMS:EnsureActorCount(tonumber(count))
	end,
})
