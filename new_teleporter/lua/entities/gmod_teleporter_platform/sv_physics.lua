-- URGENT: FIX WELD TO PLATFORM NOT BEING REMOVED WHEN DUPLICATING

local function hideConstraint( const )

	local ent1 = const.Ent1
	local ent2 = const.Ent2

	if IsValid( ent1 ) and ent1.Constraints then
		table.RemoveByValue( ent1.Constraints, const )
		if not ent1.HiddenConstraints then
			ent1.HiddenConstraints = {}
		end
		table.insert( ent1.HiddenConstraints, const )
	end

	if IsValid( ent2 ) and ent2.Constraints then
		table.RemoveByValue( ent2.Constraints, const )
		if not ent2.HiddenConstraints then
			ent2.HiddenConstraints = {}
		end
		table.insert( ent2.HiddenConstraints, const )
	end

end

function ENT:AttachToFrame()

	if not IsValid( self:GetFrame() ) then return end

	self:StopMotionController()
	local pos = self:GetTargetPos()
	local ang = self:GetTargetAngles()
	self:SetPos( pos )
	self:SetAngles( ang )
	self.WeldConstraint = constraint.Weld( self, self:GetFrame(), 0, 0, 0, false )
	hideConstraint( self.WeldConstraint )
	self.CustomPhysicsEnabled = false

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetMass( 128 )
	end

	for k, ent in pairs( self.Colliders ) do
		if IsValid( ent ) and IsValid( ent:GetPhysicsObject() ) then
			ent:GetPhysicsObject():SetMass( 4 )
		end
	end

end

function ENT:DetachFromFrame()

	self:StartMotionController()
	if IsValid( self.WeldConstraint ) then
		self.WeldConstraint:Remove()
	end
	self.CustomPhysicsEnabled = true

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:EnableMotion( true )
		phys:Wake()
		phys:SetMass( 15000 )
	end

	for k, ent in pairs( self.Colliders ) do
		if IsValid( ent ) and IsValid( ent:GetPhysicsObject() ) then
			ent:GetPhysicsObject():SetMass( 500 )
		end
	end

end

function ENT:PhysicsSimulate( phys, dt )

	if self.CustomPhysicsEnabled then

		phys:Wake()
		self:UpdatePosition( dt )

		local pos = self:GetTargetPos()
		local ang = self:GetTargetAngles()

		self.ShadowParams.secondstoarrive = 0.1
		self.ShadowParams.pos = pos
		self.ShadowParams.angle = ang
		self.ShadowParams.maxangular = 5000
		self.ShadowParams.maxangulardamp = 10000
		self.ShadowParams.maxspeed = 1000000
		self.ShadowParams.maxspeeddamp = 10000
		self.ShadowParams.dampfactor = 0.8
		self.ShadowParams.teleportdistance = 0
		self.ShadowParams.deltatime = dt

		phys:ComputeShadowControl( self.ShadowParams )


	end

end

local MaxHeight = 156
local MoveTime = 11 -- how long in seconds moving from the bottom to the top should be
function ENT:UpdatePosition( dt )

	local cur = self.CurrentHeight

	local rate = dt / MoveTime
	if CurTime() > self:GetTeleportTime() then -- if we're after the teleport time, go down.
		rate = rate * -1
	end

	cur = cur + rate
	cur = math.Clamp( cur, 0, 1 )
	self.CurrentHeight = cur

end

function ENT:GetTargetPos()

	local frame = self:GetFrame()
	if IsValid( frame ) then
		local Origin = self.PlatformOffset
		local Height = MaxHeight * self.CurrentHeight

		Origin = Origin + Vector( 0, 0, Height )

		return frame:LocalToWorld( Origin )
	else
		return self:GetPos()
	end

end

function ENT:GetTargetAngles()

	local frame = self:GetFrame()
	if IsValid( frame ) then
		return frame:GetAngles()
	else
		return self:GetAngles()
	end

end



local Sides = 8
local SideLength = 12.112500190735 * 2
local Extra = 2
local Radius = SideLength / 2 / math.tan( math.pi / Sides )
local ColliderModel = "models/hunter/plates/plate025x1.mdl" -- this used to use plate05x1, but i used 025 instead so it's easier to physgun stuff inside
local Origin = Vector( 9, 0, 32 )
local function dummy() return end


function ENT:SpawnRingColliders()

	local colliders = {}
	for i = 0, 7 do
		local ang = Angle( 0, i / Sides * 360, 0 )

		local lPos = Origin + ang:Forward() * ( Radius + Extra )
		local pos = self:LocalToWorld( lPos )

		ang = self:LocalToWorldAngles( ang )
		ang:RotateAroundAxis( ang:Forward(), 90 )
		ang:RotateAroundAxis( ang:Right(), 90 )
		
		local ent = ents.Create( "prop_physics" )
		ent:SetModel( ColliderModel )
		ent:Spawn()
		ent:SetPos( pos )
		ent:SetAngles( ang )

		ent:EnableCustomCollisions( true )
		ent.TestCollision = dummy
		ent.PhysgunDisabled = true
		ent.IsTeleporterCollider = true

		ent:SetNoDraw( true )

		local side = i + 1
		self["SetCollider" .. side]( self, ent )

		self:DeleteOnRemove( ent )
		table.insert( colliders, ent )

	end

	local lookupTable = {}
	for k, first in pairs( colliders ) do
		for k, second in pairs( colliders ) do
			-- don't make duplicate constraints
			if lookupTable[first] == second or lookupTable[second] == first or first == second then continue end

			lookupTable[first] = second
			lookupTable[second] = first
			constraint.NoCollide( first, second, 0, 0 )
		end
		constraint.Weld( first, self, 0, 0, 0, true )
	end
	for k, ent in pairs( colliders ) do
		-- prevent duplicator and tools from seeing this stuff
		-- is this a bad idea? i honestly don't know what else to do to keep some idiot from hitting reload with the weld tool on this platform
		ent.HiddenConstraints = ent.Constraints
		ent.Constraints = nil
	end

	-- this SHOULD only hide the constraints we made, and not constraints carried over from a dupe
	self.HiddenConstraints = self.Constraints
	self.Constraints = nil
	self.Colliders = colliders

	self:SetRingCollision(false)

end

function ENT:NoCollideCollidersWithFrame()

	if not IsValid( self:GetFrame() ) then return end

	local frame = self:GetFrame()
	for k, ent in pairs( self.Colliders ) do
		if IsValid( ent ) then
			local const = constraint.NoCollide( ent, frame, 0, 0 )
			hideConstraint( const )
		end
	end

end

function ENT:SetRingCollision( enabled )

	local colGroup = enabled and COLLISION_GROUP_NONE or COLLISION_GROUP_IN_VEHICLE
	for i = 1, 8 do
		local ent = self["GetCollider" .. i](self)
		if IsValid( ent ) then
			ent:SetCollisionGroup( colGroup )
		end
	end

end


hook.Add( "CanPlayerUnfreeze", "teleporter_unfreeze", function( ply, ent, phys )
	if ent.IsTeleporterCollider then
		return false
	end
end )
hook.Add( "CanProperty", "teleporter_prevent", function( ply, property, ent )

	if ent.IsTeleporterCollider then
		return false
	end

end )
hook.Add( "CanDrive", "teleporter_prevent", function( ply, ent )

	if ent.IsTeleporterCollider then
		return false
	end

end )
hook.Add( "CanTool", "teleporter_prevent", function( ply, tr, tool )

	if IsValid( tr.Entity ) and tr.Entity.IsTeleporterCollider then
		return false
	end

end )
