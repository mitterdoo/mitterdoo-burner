function ENT:DissolveEntsOnPlatform()

	local tab = self:GetEnts()

	for k, ent in pairs( tab ) do
		local ed = EffectData()
		ed:SetEntity( ent )
		ed:SetOrigin( ent:GetPos() )
		ed:SetMagnitude( self.Times.Suck )
		util.Effect( "teleporter_dissolve", ed, true, true )
	end

end


function ENT:DoSuckEffect()

	local ed = EffectData()
	ed:SetEntity( self )
	ed:SetOrigin( self:GetPos() )
	ed:SetMagnitude( self.Times.Suck )
	util.Effect( "teleporter_suck_effect", ed, true, true )

end

function ENT:CheckForTime( Until )

	return CurTime() > self:GetTeleportTime() - ( Until or 0 ) and self:GetTeleportTime() > 0

end

function ENT:DoTeleportEffect( isCoroutine, isOriginal )

	if not isCoroutine then
		self:co( self.DoTeleportEffect, true, isOriginal )
		return
	end

	coroutine.yield( 2, self.CheckForTime, self.Times.Windup )

	self:EmitSound( self.Sounds.Windup, 85 )

	coroutine.yield( 1, self.Times.Windup - self.Times.Suck )

	if isOriginal then
		self:BroadcastEnts()
	end
	self:EmitSound( self.Sounds.Suck, 85 )
	self:IntensifyHumSound()

	self:DissolveEntsOnPlatform()
	self:DoSuckEffect()

	coroutine.yield( 2, self.CheckForTime, 0 ) -- wait until teleport

end

function ENT:Teleport( nosound )

	if not IsValid( self:GetDestination() ) then return end

	local dest = self:GetDestination()
	local ourEnts = self:SendEnts( self:GetEnts() )
	local theirEnts = dest:SendEnts( dest:GetEnts() )

	self:BringEnts( theirEnts )
	dest:BringEnts( ourEnts )

	if not nosound then
		timer.Simple( 0.1, function()
			-- even after a tenth of a second these ents can still be invalid
			if IsValid( self ) then self:EmitSound( self.Sounds.Teleport, 85 ) end
			if IsValid( dest ) then dest:EmitSound( dest.Sounds.Teleport, 85 ) end
		end )
	end

end

--[[-------------------------------------------------------------------------
NOTE: only call this ONCE on a pair of teleporters. it will handle the rest
---------------------------------------------------------------------------]]
function ENT:MainSequence( noRecursion, isCoroutine )

	local dest = self:GetDestination()
	local valid = self:DestValid()

	noRecursion = noRecursion or false

	if not isCoroutine then -- start running this function as a coroutine if we aren't in one

		self:co( self.MainSequence, noRecursion, true )

		if not noRecursion and valid then -- make sure we don't endlessly call this function
			dest:MainSequence( true )
		end
		return
	end

	self:SetRingCollision(true)
	self:DetachFromFrame()
	self:SetTeleportTime( CurTime() + 20 )

	-- start movin those rings
	self:StartNet( self.Net.StartRings )
	net.Broadcast()

	self:EmitSound( self.Sounds.Start, 85 )
	self:StartHumSound()
	--self:EmitSound( self.Sounds.Hum )
	coroutine.yield( 1, 5 ) -- wait a little bit
	self:EmitSound( self.Sounds.Wind )

	self:DoTeleportEffect( true, not noRecursion )

	if not noRecursion then
		self:Teleport() -- Teleport does stuff to both teleporters; call it once
	end
	coroutine.yield( 1, 0.1 ) -- let players teleport, then play sounds

	--self:StopSound( self.Sounds.Hum )
	self:StopHumSound()
	self:StopSound( self.Sounds.Wind )
	self:EmitSound( self.Sounds.Winddown, 85 )

	-- slow it down
	self:StartNet( self.Net.StopRings )
	net.Broadcast()

	coroutine.yield( 1, 10 ) -- wait for the rings to stop
	self:SetRingCollision(false) -- now we can move through them again
	coroutine.yield( 1, 2 ) -- it takes 11 seconds to move back down after teleport, and one more to make sure the platform is in place
	self:AttachToFrame()

end


function ENT:StartHumSound()

	if self.HumSound and self.HumSound:IsPlaying() then
		self.HumSound:Stop()
	end

	self.HumSound = CreateSound( self, self.Sounds.Hum )
	self.HumSound:PlayEx( 0, 75 )
	self.HumSound:ChangeVolume( 1, 4 )
	self.HumSound:ChangePitch( 100, 8 )

end

function ENT:IntensifyHumSound()

	if self.HumSound and self.HumSound:IsPlaying() then
		self.HumSound:ChangePitch( 110, self.Times.Suck )
	end
end

function ENT:StopHumSound()

	if self.HumSound and self.HumSound:IsPlaying() then
		--self.HumSound:FadeOut(11)
		--self.HumSound:ChangePitch( 75, 8 )
		self.HumSound:Stop()
	end

end
