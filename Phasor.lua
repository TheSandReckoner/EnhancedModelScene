--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local _, addon_table = ...

local Phasor = {}
local PhasorMixin = {}

local EnhancedModelScene = addon_table.self

if not EnhancedModelScene then return end

EnhancedModelScene.Phasor = Phasor
Phasor.Mixin = PhasorMixin


function Phasor.New(rate, phase, action)
	rate, phase, action = rate or 1, phase or 0, action or function() end
	return Mixin({ phase = phase, rate = rate, action = action }, PhasorMixin)
end


function PhasorMixin:Update(elapsed)
	self.phase = self.phase + elapsed * self.rate
end


function PhasorMixin:Apply(...)
	self:action(...)
end


function PhasorMixin:SetPeriod(period)
	self.rate = 1 / period
end


function PhasorMixin:GetPeriod()
	if self.rate == 0 then
		return false
	else
		return 1 / self.rate
	end
end


function PhasorMixin:ResetPhase()
	self.phase = 0
end


function PhasorMixin:SetPhase(phase)
	self.phase = phase
end


function PhasorMixin:Pause()
	if not self.paused then
		self.paused = true
		self.paused_rate = self.rate
		self.rate = 0
	end
end


function PhasorMixin:Unpause()
	if self.paused then
		self.paused = false
		self.rate = self.paused_rate
		self.paused_rate = nil
	end
end
