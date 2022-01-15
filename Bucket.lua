--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local EMS = select(2, ...).self
local EnhancedModelScene = EMS

if not EMS then return end

local Bucket = {}
EMS.Bucket = Bucket

Bucket.buckets = {}

local BucketMixin = {}
Bucket.mixin = BucketMixin

--[[ Use case: certain inputs, eg. mouse rotation of model, would be too spammy to send in group comms,
so have that input start a bucket if one hasn't already been started, new inputs (of that type) go into 
the bucket. For now new inputs overwrite the prior inputs, but it may be useful to keep them, or perhaps 
the new state is dependent on the prior inputs (eg. incremental rotation)
The bucket will automatically trigger a clearing function after a set time. It might also be desirable 
to have earlier triggers, eg. movement beyond a range. Might need multiple tiers of timers (eg. never 
less than A, but possible early trigger before normal time B)

Want ability to reset a bucket's timer (forcibly clear, start another?)
]]

function Bucket:New(name, timeout_function, add_function)
	local bucket = CreateFromMixins(BucketMixin)
	self.buckets[name] = bucket
	bucket.name = name
	bucket.entries = {}
	
	bucket.on_timeout = timeout_function
	
	if add_function then
		bucket.AddEntry = add_function
	end
	
	return bucket
end


Bucket.default_interval = 1


function Bucket:SendToBucket(name, ...)
	--print("SendToBucket", name, ...)
	if not self.buckets[name] then
		error("There is no bucket with that name")
		return
	end
	
	local bucket = self.buckets[name]
	bucket:AddEntry(...)
end


function BucketMixin:AddEntry(...)
	print("adding entry to bucket via generic AddEntry")
	table.insert(self.entries, {...})
	
	print("bucket is ", self:IsRunning() and "" or "not ", "running")

	if not self:IsRunning() then
		-- run the timeout function to process this entry, and expect it to start a new interval
		self:OnTimeout()
		
		--self:Start()
	end
end


function BucketMixin:Start()
	self.start_time = GetTime()
	C_Timer.After(self.interval or Bucket.default_interval, function() self:OnTimeout() end)
	self.running = true
end


function BucketMixin:IsRunning()
	return self.running
end


function BucketMixin:OnTimeout()
	print("bucket", self.name, "timed out") -- or wasn't running
	self:on_timeout()
	
	-- if bucket isn't empty, it should run for another interval
	-- TODO: set based on whether timeout function gives certain return, to have a default
	-- or have the timeout do :Restart ?
	--self.running = false
end

function BucketMixin:SetAddFunction(func)
	self.AddEntry = func
end


function BucketMixin:SetEndFunction(func)
	self.on_timeout = func
end


function BucketMixin:SetInterval(duration)
	-- FIXME: if running
	self.interval = duration
end


function BucketMixin:Restart()
	self.entries = {}
	self:Start()
end


function BucketMixin:Finish()
	self.running = false
end


-- set up a bucket for use
do
	local function animation_bucket_add(self, ...)
		if not self:IsRunning() then
			self:Start()
			local command = ("anim %i %i %i %f %f"):format(...)
			EMS:SendSyncCommand(command)
			-- don't add the current actor - it might not change again
		else
			-- save a list of indices to send states of on bucket timeout
			self.entries[...] = true
		end
	end

	local function animation_bucket_end(self)
		if next(self.entries) then
			for index in pairs(self.entries) do
				local animation, variation, speed, offset = EMS:GetActorAtIndex(index):GetCurrentAnimation()
				local command = ("anim %i %i %i %f %f"):format(index, animation, variation, speed, offset)
				EMS:SendSyncCommand(command)
				self.entries[index] = nil
			end
			
			-- restart the timer so we don't immediately send a new command
			self:Start()
		else
			self.running = false
		end
	end


	local bucket = Bucket:New("animation")
	bucket:SetAddFunction(animation_bucket_add)
	bucket:SetEndFunction(animation_bucket_end)
	bucket:SetInterval(1)
	
	local backdrop_bucket = Bucket:New("backdrop")
	backdrop_bucket:SetInterval(5)
	backdrop_bucket:SetEndFunction(function(self)
		if next(self.entries) then
			-- send the color and the state
			EMS:SendSyncCommand(("backdrop %f %f %f"):format(EMS:GetBackdropColor()))
			
			self.entries = {}
			
			if not EMS.backdrop:IsShown() then
				EMS:SendSyncCommand("backdrop hide")
			end
			
			self:Restart()
		else
			self:Finish()
		end
	end)
end
