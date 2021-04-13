AddCSLuaFile "shared.lua"
AddCSLuaFile "cl_init.lua"
AddCSLuaFile "cl_rings.lua"
AddCSLuaFile "cl_drawing.lua"
include "shared.lua"
include "sv_networking.lua"
include "sv_wire.lua"
include "sv_logic.lua"
include "sv_physics.lua"

local makeLookup = ENT.MakeLookup
local merge = ENT.Merge

local Tag = "teleporter_net"
util.AddNetworkString( Tag )



function ENT:Initialize()
	
	self:SetModel( self.Model )
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
		phys:SetMass( 15000 )
	end


	self.Memory = {}
	for i = 1, 4096 do -- 4 kb
		self.Memory[i] = 0
	end

	if WireLib then
		self.Outputs = WireLib.CreateOutputs( self, { "Memory" } )
	end

	self:SpawnRingColliders()
	self.ShadowParams = {}
	self.CurrentHeight = 0
	self.PhysgunDisabled = true
	
end

function ENT:Think()

	self:CoroutineThink()

	self:NextThink( CurTime() + 1/60 )
	return true

end

function ENT:OnRemove()

	self:StopSound( self.Sounds.Hum )
	self:StopSound( self.Sounds.Wind )

end

function ENT:DestValid()
	return IsValid( self:GetDestination() ) and self:GetDestination():GetDestination() == self
end

--[[-------------------------------------------------------------------------
Gets all of the entities in the "teleport zone" that can be teleported, including
entities that are constrained to them
---------------------------------------------------------------------------]]
function ENT:GetEnts()

	-- First, get every entity found in every single zone
	local list = self:GetEntsInZone()

	-- Next, remember every entity we're constrained to
	local constrained = constraint.GetAllConstrainedEntities( self )
	local lookup = makeLookup( constrained ) -- Lookup tables make it a whole lot easier to determine if a table contains a value

	-- Now make sure there aren't any weird entities (like gmod_hands or other stuff) or constrained entities in this list, as well as no currently-being-teleported ents
	local i = 0
	while i < #list do
		i = i + 1

		local v = list[i]
		if --[[!IsValid( v:GetPhysicsObject() ) or]] lookup[v] or v.BeingTeleported or v.IsTeleporterCollider then
			table.remove( list, i )
			i = i - 1

		end

	end

	
	-- Finally, recursively look through the entities in this zone and add their constrained entities
	local allConstrained = {}
	local lookup = {}

	for k,v in pairs( list ) do
		if lookup[v] then continue end -- if we already know about this entity then don't fucking do anything with it and waste time
		local tab = constraint.GetAllConstrainedEntities( v )
		merge( allConstrained, tab )
		for _, ent in pairs( allConstrained ) do
			if !lookup[ent] then
				lookup[ent] = true
			end
		end
	end
	merge( list, allConstrained )

	return list

end

--[[-------------------------------------------------------------------------
Creates a list of entities and their relative positions and angles to this
teleporter platform
---------------------------------------------------------------------------]]
function ENT:SendEnts( tab )

	local list = {}
	for k, ent in pairs( tab ) do


		local item = {}
		item.ent = ent

		if IsValid( ent:GetParent() ) or not IsValid( ent:GetPhysicsObject() ) then
			item.ignore = true
		else

			local objCount = ent:GetPhysicsObjectCount()
			if objCount > 1 then

				item.physobjs = {}
				for i = 0, objCount - 1 do

					local phys = ent:GetPhysicsObjectNum( i )

					if IsValid( phys ) then

						local physItem = {
							pos = self:WorldToLocal( phys:GetPos() ),
							ang = self:WorldToLocalAngles( phys:GetAngles() ),
							vel = WorldToLocal( phys:GetVelocity(), Angle(), Vector(), self:GetAngles() ),
						}
						table.insert( item.physobjs, physItem )

					end

				end

			else

				item.pos = self:WorldToLocal( ent:GetPos() )
				if ent:IsPlayer() then
					item.ang = self:WorldToLocalAngles( ent:EyeAngles() )
				else
					item.ang = self:WorldToLocalAngles( ent:GetAngles() )
				end

				local relVel, _ = WorldToLocal( ent:GetVelocity(), Angle(), Vector(), self:GetAngles() )

				item.vel = relVel

			end

		end

		table.insert( list, item )
		ent.BeingTeleported = true -- don't let other teleporters "see" this entity

	end

	return list

end
--[[-------------------------------------------------------------------------
Does the reverse of ENT:SendEnts()
---------------------------------------------------------------------------]]
function ENT:BringEnts( tab )

	for k, item in pairs( tab ) do

		local ent = item.ent
		if !IsValid( ent ) or item.ignore then continue end

		if item.physobjs then

			for k, physItem in pairs( item.physobjs ) do

				local phys = ent:GetPhysicsObjectNum( k - 1 )
				if IsValid( phys ) then

					phys:SetPos( self:LocalToWorld( physItem.pos ) )
					phys:SetAngles( self:LocalToWorldAngles( physItem.ang ) )
					phys:SetVelocityInstantaneous( LocalToWorld( physItem.vel, Angle(), Vector(), self:GetAngles() ) )

				end

			end

		else

			ent:SetPos( self:LocalToWorld( item.pos ) )

			local vel, _ = LocalToWorld( item.vel, Angle(), Vector(), self:GetAngles() )
			if ent:IsPlayer() then

				ent:SetEyeAngles( self:LocalToWorldAngles( item.ang ) )

				-- thanks to the amazing engine this game runs, Entity:SetVelocity() ADDS velocity to players instead of setting it
				-- so cancel this fucker out first
				local cur = ent:GetVelocity()
				ent:SetVelocity( -cur )
				ent:SetVelocity( vel )
			else

				ent:SetAngles( self:LocalToWorldAngles( item.ang ) )
				ent:GetPhysicsObject():SetVelocityInstantaneous( vel )

			end

		end

		ent.BeingTeleported = nil

	end

end




function ENT:PreEntityCopy()

	entlookup.ApplyToDupe( self )

end


function ENT:PostEntityPaste( ply, ent, createdEnts )

	entlookup.ApplyToPaste( ent, createdEnts )

end
