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

local Matrix = {}
EnhancedModelScene.Matrix = Matrix

local cos, sin = math.cos, math.sin


local MatrixMixin = {}
Matrix.mixin = MatrixMixin


-- TODO: maybe change internal element order to allow dump and tinspect to naturally
-- show elements in i j k order. Either change the New function order too or convert.
-- This would create consistency with the homogeneous translation column too.


function Matrix.New(...)
	return Mixin({...}, MatrixMixin)
end


Matrix.NewC = Matrix.New
Matrix.NewByColumns = Matrix.New


function Matrix.NewByRows(e11, e12, e13, e21, e22, e23, e31, e32, e33, x, y, z)
	return Matrix.NewByColumns(e11, e21, e31, e12, e22, e32, e13, e23, e33, x, y, z)
end


function Matrix.YPR(yaw, pitch, roll)
	local ca, cb, cc = cos(yaw), cos(pitch), cos(roll)
	local sa, sb, sc = sin(yaw), sin(pitch), sin(roll)
	
	local m = Matrix.NewByRows(ca*cb, ca*sb*sc - sa*cc, ca*sb*cc + sa*sc,
							   sa*cb, sa*sb*sc + ca*cc, sa*sb*cc - ca*sc,
							   -sb,          cb*sc,           cb*cc     )
	
	m.scale = 1
	
	return m
end


function Matrix.SetTranslation(m, x, y, z)
	m[10], m[11], m[12] = x, y, z
end


Matrix.MergeTranslation = Matrix.SetTranslation
MatrixMixin.SetTranslation = Matrix.SetTranslation


local function AddTranslation(m, x, y, z)
	local x0, y0, z0 = m[10], m[11], m[12]
	
	if not x0 then
		x0, y0, z0 = 0, 0, 0
	end
	
	m[10], m[11], m[12] = x+x0, y+y0, z+z0
	
	return m
end


MatrixMixin.AddTranslation = AddTranslation


function MatrixMixin:SubtractTranslation(x, y, z)
	self:AddTranslation(-x, -y, -z)
end


function Matrix.GetYPR(m)
	local s = m.scale or 1
	local m1, m2, m3, m6, m9 = m[1]/s, m[2]/s, m[3]/s, m[6]/s, m[9]/s
	
	-- TODO: check if only m3 needs scale fix (others are ratios anyway?)
	--return math.atan2(m2, m1), -math.asin(m3), math.atan2(m6, m9)
	return math.atan2(m2, m1), -math.asin(m[3]/(m.scale or 1)), math.atan2(m6, m9)
end


MatrixMixin.GetYPR = Matrix.GetYPR


function MatrixMixin:GetXYZ()
	return self[10] or 0, self[11] or 0, self[12] or 0
end


function MatrixMixin.PrintAxes(m)
	print("x:", m[1], m[2], m[3])
	print("y:", m[4], m[5], m[6])
	print("z:", m[7], m[8], m[9])
end


function Matrix:ProcessChain(chain)
	if #chain < 2 then
		return chain[1]
	end
	
	local m = Matrix.hmult(chain[2], chain[1])
	
	for i = 2, #chain do
		m:TransformBy(chain[i])
	end
	
	return m
end


function MatrixMixin:TransformBy(m2)
	
end


-- multiply homogeneous-coordinates matrices
function Matrix.hmult(left, right)
	local m = Matrix.R3Rotate(left, right)
	
	if left.scale and right.scale then
		m.scale = left.scale * right.scale
	end
	
	if not left[10] and not right[10] then
		-- neither is homogeneous
		return m
	end
	
	local rx, ry, rz = unpack(right, 10, 12)
	
	if not rx then
		rx, ry, rz = 0, 0, 0
	end
	
	m[10], m[11], m[12] = Matrix.TransformLooseVector(left, rx, ry, rz)
	
	
	return m
end


function MatrixMixin:Product(m2)
	local m1, m = self
end



function Matrix.TransformVector(m, x)
	return { Matrix.TransformLooseVector(m, unpack(x)) }
end


function Matrix.TransformLooseVector(m, x1, x2, x3, x4)
	local a, b, c = 
		m[1]*x1 + m[4]*x2 + m[7]*x3,
		m[2]*x1 + m[5]*x2 + m[8]*x3,
		m[3]*x1 + m[6]*x2 + m[9]*x3;
	
	if m[10] and x4 ~= 0 then -- homogeneous transform
		-- assume either (x in R3) or (x in R4 and x[4] is either 0 or 1)
		a, b, c = a + m[10], b + m[11], c + m[12]
	end
	
	return a, b, c, x4
end


MatrixMixin.TransformLooseVector = Matrix.TransformLooseVector

function Matrix.TransformMatrix(m1, m2)
	local m = {}
	
end


function Matrix.GetColumnVector(m, c)
end


-- Returns m1*m2, where both are assumed to be rotation matrices in R3
function Matrix.R3Rotate(a, b)
	-- This was written before internal order was changed to columns
	
	--local a1, a2, a3, a4, a5, a6, a7, a8, a9 = unpack(a)
	--local b1, b2, b3, b4, b5, b6, b7, b8, b9 = unpack(b)
	local a1, a4, a7, a2, a5, a8, a3, a6, a9 = unpack(a)
	local b1, b4, b7, b2, b5, b8, b3, b6, b9 = unpack(b)

	return Matrix.NewByRows(
		-- first row
		a1*b1 + a2*b4 + a3*b7, 
		a1*b2 + a2*b5 + a3*b8, 
		a1*b3 + a2*b6 + a3*b9, 
		
		-- second row
		a4*b1 + a5*b4 + a6*b7, 
		a4*b2 + a5*b5 + a6*b8, 
		a4*b3 + a5*b6 + a6*b9, 
		
		-- third row
		a7*b1 + a8*b4 + a9*b7, 
		a7*b2 + a8*b5 + a9*b8, 
		a7*b3 + a8*b6 + a9*b9)
end
		
		
function MatrixMixin:GetInverse(dest)
	if dest then
		dest[1], dest[2], dest[3], dest[4], dest[5], dest[6], dest[7], dest[8], dest[9] = 
			self[1], self[4], self[7], self[2], self[5], self[8], self[3], self[6], self[9]
	else
		-- TODO: could just extract saved order and pass to NewByRows
		dest = Matrix.New(self[1], self[4], self[7], self[2], self[5], self[8], self[3], self[6], self[9])
	end
	
	if self.scale then
		dest.scale = self.scale
		
		if self.scale ~= 1 then
			local s = self.scale
			dest:Scale(1/(s*s))
		end
	else
		-- FIXME: if scale unspecified and not 1
	end
	
		
	if self[10] then
		-- clear translation so we can use dest as the inverse rotation
		-- cache self's fields first - I think we can allow dest = self
		local x, y, z = self[10], self[11], self[12]
		
		dest[10], dest[11], dest[12] = 0, 0, 0
		dest[10], dest[11], dest[12] = dest:TransformLooseVector(-x, -y, -z)
	else
		dest[10], dest[11], dest[12] = nil, nil, nil
	end
	
	return dest
end


function Matrix.AngleAxis(theta, x, y, z)
	-- assume given a proper unit vector
	local c, s = cos(theta), sin(theta)
	
	return Matrix.NewByRows(
		c + x*x*(1-c),   x*y*(1-c)-z*s,  x*z*(1-c)+y*s, 
		y*x*(1-c) + z*s, c + y*y*(1-c),  y*z*(1-c) - x*s,
		z*x*(1-c) - y*s, z*y*(1-c) + x*s, c + z*z*(1-c))
end


function MatrixMixin:GetBasisVector(index)
	return unpack(self, 3 * index - 2, 3 * index)
end


function MatrixMixin:Scale(scalar)
	local last = 9
	
	--[[
	if self[10] then
		last = 12
	end
	]]
	
	for i = 1, last do
		self[i] = self[i] * scalar
	end
	
	if self.scale then
		self.scale = self.scale * scalar
	end
end


function MatrixMixin:GetScale()
	-- FIXME: if not set as field
	return self.scale
end
