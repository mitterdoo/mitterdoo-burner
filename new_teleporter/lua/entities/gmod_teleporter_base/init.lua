AddCSLuaFile "shared.lua"
AddCSLuaFile "cl_init.lua"
include "shared.lua"

function ENT:Initialize()
	
	self:SetModel( self.Model )
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
	end

end

function ENT:Think()

	if not IsValid( self:GetPlatform() ) then
		self:SpawnPlatform()
	end

end

function ENT:PreEntityCopy()

	entlookup.ApplyToDupe( self )

end


function ENT:PostEntityPaste( ply, ent, createdEnts )

	entlookup.ApplyToPaste( ent, createdEnts )

end

-- calling this after PostEntityPaste to ensure the platform exists
function ENT:OnPasteComplete( ply, ent, createdEnts )

	self:SetupPlatform()

end

function ENT:SpawnPlatform()

	local ent = ents.Create( "gmod_teleporter_platform" )
	local pos = self:LocalToWorld( ent.PlatformOffset )
	ent:SetPos( pos )
	ent:SetAngles( self:GetAngles() )
	ent:Spawn()
	ent:Activate()
	ent:SetFrame( self )
	self:SetPlatform( ent )

	self:SetupPlatform()

end

function ENT:SetupPlatform()

	local ent = self:GetPlatform()
	if not IsValid( ent ) then return end

	self:DeleteOnRemove( ent )
	ent:NoCollideCollidersWithFrame()

	constraint.NoCollide( self, ent, 0, 0 )

	ent:SetFrame( self )
	ent:AttachToFrame()

end
