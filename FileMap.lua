--[[
This Source Code Form is subject to the terms of 
the Mozilla Public License, v. 2.0. If a copy of 
the MPL was not distributed with this file, You 
can obtain one at https://mozilla.org/MPL/2.0/.

Copyright © 2021 The Sand Reckoner
Gmail: sandreckoner1063
]]

local EnhancedModelScene = select(2, ...).self

if not EnhancedModelScene then return end

local FileMap = {}
EnhancedModelScene.FileMap = FileMap

FileMap.modelfiles = select(2, ...).modelfiles


-- TODO: search for files containing query, ignoring matches specified to exclude
function FileMap:GetMatchingFiles(query, exclude)
	local files = {}

	for line in self.modelfiles:gmatch("[^\n]+") do
		if line:match(query) and (not exclude or not line:match(exclude)) then
			local file, name = strsplit(";", line)
			tinsert(files, {tonumber(file), name})
		end
	end
	
	return files
end


function FileMap:RemoveMatches(t, query)
end
