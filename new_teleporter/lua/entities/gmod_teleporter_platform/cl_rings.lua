local FullSpeed = 1500
local Accel = 100
local Decel = 150
-- when acceleration is 100 degrees/second^2, it will take 15 seconds exactly to reach full speed

local function math_ApproachSingleDirection( cur, target, inc )

	--inc = math.abs( inc )

	if ( cur < target ) then

		return math.min( cur + inc, target )

	elseif ( cur > target ) then

		return math.max( cur - inc, target )

	end

	return target

end

local function math_ApproachAngleSingleDirection( cur, target, inc )

	local diff = math.AngleDifference( target, cur )

	return math_ApproachSingleDirection( cur, cur + diff, inc )

end

local function SlowdownToAngle( self, target, slowspeed )

	local positive = self.TargetSpeed > 0 and 1 or -1
	self.TargetSpeed = positive * slowspeed
	self.TargetAngle = target
	self.SlowingToAngle = true

end

function ENT:GetTransformForRing( ring )

	local StartHeight = 10
	local Spacing = 12
	local Height = ( ring - 1 ) * Spacing + StartHeight
	local pos = self:LocalToWorld( Vector( 9, 0, Height ) )

	local ang = self:GetAngles()
	ang:RotateAroundAxis( self:GetUp(), 180 )

	return pos, ang

end

function ENT:SpawnRings()

	self.Rings = {}
	self.RingLookup = {}


	for i = 1, 4 do
		local e = ClientsideModel( "models/props_lab/teleportring.mdl", RENDERGROUP_TRANSLUCENT )

		local pos, ang = self:GetTransformForRing( i )
		e:SetPos( pos )
		e:SetAngles( ang )
		e:SetParent( self )
		e:SetNoDraw(true)

		self.RingLookup[e] = true

		local data = {
			Entity = e,
			Index = i,
			Platform = self,
			Rotation = 0,
			TargetSpeed = 0,
			CurrentSpeed = 0,
			Acceleration = Accel, -- degrees/second^2
			SlowdownToAngle = SlowdownToAngle, -- call this to slow it down

			TargetAngle = 0,
			ApproachTargetAngle = false,
			LastDiff = 0,
			SlowingToAngle = false
		}
		table.insert( self.Rings, data )
	end


end

function ENT:RemoveRings()

	if self:RingsValid() then

		for k,v in pairs( self.Rings ) do
			if IsValid(v.Entity) then v.Entity:Remove() end
		end
		self.Rings = {}

	end

end

function ENT:RingsValid()

	return IsValid( self ) and istable( self.Rings ) and #self.Rings == 4

end

-- when they'll be drawn
function ENT:UpdateRings()

	if !self:RingsValid() then return end

	for k, ring in pairs( self.Rings ) do

		-- when the visleaf we're in is no longer in use, garry decided for us to not exist anymore. that means these rings have no parents anymore. GARRY IS TAKING PARENTS AWAY FROM INNOCENT RINGS
		-- never fear for dumb checks like this one..
		if ring.Entity:GetParent() ~= self then
			local pos, ang = self:GetTransformForRing( ring.Index )
			ring.Entity:SetPos( pos )
			ring.Entity:SetAngles( ang )
			ring.Entity:SetParent( self )
		end


		ring.Rotation = ring.Rotation % 360 -- be sane
		local ang = self:GetAngles()
		ang:RotateAroundAxis( ang:Up(), ring.Rotation + 180 )
		ring.Entity:SetAngles( ang )

		-- if we're 2fast4u, look like it
		if math.abs( ring.CurrentSpeed ) >= 540 and ring.Entity:GetSkin() == 0 then
			ring.Entity:SetSkin(1)
		elseif math.abs( ring.CurrentSpeed ) < 540 and ring.Entity:GetSkin() == 1 then
			ring.Entity:SetSkin(0)
		end

	end

end

function ENT:DrawRings()

	if not self:RingsValid() then return end
	for k, info in pairs( self.Rings ) do

		local ring = info.Entity
		ring:DrawModel()

	end

end


function ENT:RingThink( ring )

	local ft = FrameTime()
	local delta = ft * ring.Acceleration -- how much to add to the current speed

	ring.CurrentSpeed = math.Approach( ring.CurrentSpeed, ring.TargetSpeed, delta )

	if ring.SlowingToAngle and ring.CurrentSpeed == ring.TargetSpeed then -- we're slow enough; stop decelerating
		ring.SlowingToAngle = false
		ring.ApproachTargetAngle = true
	end

	if ring.ApproachTargetAngle and ring.CurrentSpeed != 0 then -- we're approaching the angle

		-- i don't even remember how this works i just remember angle logic hurting by brain for 3 hours when i wrote this

		ring.LastDiff = ( ring.TargetAngle - ring.Rotation ) % 360
		ring.Rotation = ring.Rotation + ring.CurrentSpeed * ft

		local diff = ( ring.TargetAngle - ring.Rotation ) % 360

		if ring.CurrentSpeed > 0 and diff % 360 > ring.LastDiff or
			ring.CurrentSpeed < 0 and diff % 360 < ring.LastDiff then

			ring.Rotation = ring.TargetAngle
		end


		if ring.Rotation == ring.TargetAngle then
			ring.ApproachTargetAngle = false
			ring.CurrentSpeed = 0
			ring.TargetSpeed = 0
		end

	else

		ring.Rotation = ring.Rotation + ring.CurrentSpeed * ft
		ring.ApproachTargetAngle = false
	end


end
function ENT:RingsThink()

	if !self:RingsValid() then return end

	local ft = FrameTime()
	for k, ring in pairs( self.Rings ) do

		self:RingThink( ring )

	end

end

local function _startMovingRings( self )
	for i = 1, 4 do

		self.Rings[i].Acceleration = Accel
		self.Rings[i].TargetSpeed = FullSpeed
		self.Rings[i].SlowingToAngle = false
		self.Rings[i].ApproachTargetAngle = false
		sleep(1)

	end
end
local function _slowdownRings( self, slowspeed )

	slowspeed = slowspeed or 90
	for i = 4, 1, -1 do

		self.Rings[i].Acceleration = Decel
		self.Rings[i]:SlowdownToAngle( 0, slowspeed )
		sleep(0)

	end

end

function ENT:StartMovingRings()

	self:co( _startMovingRings )

end
function ENT:StopMovingRings( slowspeed )


	self:co( _slowdownRings, slowspeed )

end

