--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021-2022 The Sand Reckoner
Gmail: sandreckoner1063
]]

local self = EnhancedModelScene
local EMS = self

assert(EnhancedModelScene)
assert(self.CameraMixin)

Mixin(self, self.CameraMixin)

self:ResetCamera()
self:SetCameraFieldOfView(rad(90))	-- this gets changed OnFirstShow

-- create an actor now so some actions can be done without needing to show the frame first
-- this needs to be done at the end of loading so that the actor mixins are loaded
self:NewActor()

-- trying to set and check the player model file here works for reloads but not normal logins

ems = self
