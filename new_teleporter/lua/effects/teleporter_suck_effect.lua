local AttachPos = Vector( 9, 0, 36 )
local TickRate = 1/60
local SpawnPerTick = 1

local cvar_fxSuck = CreateClientConVar( "cl_teleporter_fx_suck", "1" )

function EFFECT:Init( data )

	if not cvar_fxSuck:GetBool() then return end

	self.Entity = data:GetEntity()
	if !IsValid( self.Entity ) then return end
	self.Emitter = ParticleEmitter( self.Entity:GetPos() )
	self.Start = CurTime()
	self.Duration = data:GetMagnitude()
	self.LastTick = 0
end

function EFFECT:Think()
	
	if not cvar_fxSuck:GetBool() then
		if self.Emitter then self.Emitter:Finish() end
		return false
	end

	
	if !IsValid( self.Entity ) or CurTime() > self.Start + self.Duration then
		self.Emitter:Finish()
		return false
	end
	self:SetPos( self.Entity:LocalToWorld( AttachPos ) )
	
	-- if the player's in the center, shit's gonna get bright
	-- the closer they get, the more "hidden" the effect will be in the center

	local PlayerDist = EyePos():Distance( self:GetPos() )
	local HideDist = 80 -- the distance from the effect position at which HidePercent begins to increase
	local HidePercent = PlayerDist / HideDist
	HidePercent = 1 - math.Clamp( HidePercent, 0, 1 )
	local HideSphere = 8 * HidePercent -- radius of a sphere that defines the stopping point of the particles
	


	local MaxSpeed = 6
	local MinSpeed = 1
	local Fraction = ( CurTime() - self.Start ) / self.Duration
	Fraction = math.Clamp( Fraction, 0, 1 )
	
	local Speed = Fraction * ( MaxSpeed - MinSpeed ) + MinSpeed

	--[[
	if CurTime() - self.LastTick < TickRate/Speed then
		return true
	end
	self.LastTick = CurTime()
	]]

	local Distance = 64 + Fraction * 64 + HideSphere

	local ft = math.min( FrameTime(), 1 )
	local Passes = math.max( 1, math.ceil( ft / TickRate ) )
	for i = 1, Passes * SpawnPerTick do
		
		
		local pos = self:GetPos() + VectorRand():GetNormalized() * Distance
		
		local particle = self.Emitter:Add( "sprites/glow04_noz", pos )
		local Normal = ( self:GetPos() - pos ):GetNormalized()
		particle:SetVelocity( Normal * Distance * Speed + self.Entity:GetVelocity() );

		local distToParticle = self:GetPos():Distance( pos )
		distToParticle = math.max( 0, distToParticle - HideSphere )
		local time = distToParticle / Distance / Speed
		particle:SetDieTime( time );
		particle:SetStartAlpha( 255 * HidePercent );		-- 0 when away, 255 when near
		particle:SetEndAlpha( ( 1 - HidePercent ) * 255 );	-- 255 when away, 0 when near
		particle:SetStartSize( 0 );
		particle:SetEndSize( 8 + Fraction * 16 );
		particle:SetRoll( math.random() * math.pi );
		particle:SetRollDelta( math.random() * math.pi );
		particle:SetColor( 200, 255, 255 );
	
	end
	
	return true
	
end

function EFFECT:Render()
	
end
