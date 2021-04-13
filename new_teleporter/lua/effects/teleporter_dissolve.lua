local matRefract = CreateMaterial( "teleport_dissolve", "Refract", util.KeyValuesToTable[[
"Refract"
{
	
	"$model" "1"

 	"$refractamount" ".2"
 	"$bluramount" "0"
	"$REFRACTTINT" "{255 255 255}"
	"$dudvmap" 	"models/shadertest/shader3_dudv"
 	"$normalmap" "models/shadertest/shader3_normal"
	"$dudvframe" "0"
	"$bumpframe" "1"
	
	"$masked" "1"
	
	"Proxies"
	{
		"AnimatedTexture"
		{
			"animatedtexturevar" "$dudvmap"
			"animatedtextureframenumvar" "$dudvframe"
			"animatedtextureframerate" 100.00
		}

		"AnimatedTexture"
		{
			"animatedtexturevar" "$normalmap"
			"animatedtextureframenumvar" "$bumpframe"
			"animatedtextureframerate" 100.00
		}

		"TextureScroll"
		{
			"texturescrollvar" "$bumptransform"
			"texturescrollrate" -0.8
			"texturescrollangle" 90
		}

	}
}
]] )


local cvar_fxEntity = CreateClientConVar( "cl_teleporter_fx_entity", "1" )

function EFFECT:Init( data )

	if not cvar_fxEntity:GetBool() then return end
	local ent = data:GetEntity()
	if ent._RenderOverride then return end
	-- This is how long the spawn effect
	-- takes from start to finish.
	self.Time = data:GetMagnitude() -- magnitude because networking shit into effects is stupid as hell (it's being used as the duration of the effect)
	self.Time = math.max( 1, self.Time )
	
	self.DieTime = CurTime() + self.Time


	if ( !IsValid( ent ) ) then return end
	if ( !ent:GetModel() ) then return end

	self.ParentEntity = ent
	self:SetModel( ent:GetModel() )
	self:SetPos( ent:GetPos() )
	self:SetAngles( ent:GetAngles() )
	self:SetParent( ent )
	local em = ParticleEmitter( ent:GetPos() )
	self.Emitter = em
	self.ResidueAng = ent:GetAngles()
	self.ResiduePos = ent:GetPos()


	self.ParentEntity._RenderOverride = self.ParentEntity.RenderOverride
	self.ParentEntity.RenderOverride = self.RenderParent
	self.ParentEntity.SpawnEffect = self


end

function EFFECT:Finish()

	if IsValid( self.ParentEntity ) then
		self.ParentEntity.RenderOverride = self.ParentEntity._RenderOverride
		self.ParentEntity._RenderOverride = nil
		self.ParentEntity.SpawnEffect = nil
	end

end

local fadeOutTime = 0.25

function EFFECT:Think()

	if not cvar_fxEntity:GetBool() then self:Finish() return end
	if !IsValid( self.ParentEntity ) then return false end

	local PPos = self.ParentEntity:GetPos()
	self:SetPos( PPos + ( EyePos() - PPos ):GetNormal() )


	if self.DieTime < CurTime() and not self.SpawnedParticles then
		self.SpawnedParticles = true
		self:CreateResidualParticles()
	end

	if ( self.DieTime + fadeOutTime > CurTime() ) then
		self.ParentEntity.RenderOverride = self.RenderParent
		return true
	end
	
	self:Finish()

	return false

end

local function volumeOfBounds( min, max )
	
	local size = max - min
	return math.abs( size.x * size.y * size.z )
	
end

function EFFECT:CreateResidualParticles()
	
	local ent = self.ParentEntity
	local em = self.Emitter
	local min, max = ent:OBBMins(), ent:OBBMaxs()
	
	local vol = volumeOfBounds( min, max )
	local size = max - min
	local count = math.ceil( vol / 500 )
	
	for i = 1, count do
		
		local locPos = min + Vector( math.random() * size.x, math.random() * size.y, math.random() * size.z )
		local randPos = LocalToWorld( locPos, Angle(), self.ResiduePos, self.ResidueAng )--ent:LocalToWorld( locPos )
		
		local p = em:Add( "sprites/glow04_noz", randPos )
		local speed = math.random()*16
		p:SetVelocity( VectorRand():GetNormalized() * speed )
		p:SetDieTime( (math.random()*2^ (1/2) )^2 )
		p:SetStartAlpha( 255 )
		p:SetEndAlpha( 0 )
		p:SetStartSize( math.Rand( 6, 12 ) )
		p:SetEndSize( 0 )
		p:SetRoll( math.random() * math.pi )
		p:SetRollDelta( math.random() * math.pi )
		p:SetColor( 200, 255, 255 )
		p:SetGravity( Vector( 0, 0, 50 ) )
		
	end
	em:Finish()
	
	
end

local StoreTime = 0.5
-- this entity is probably gonna be teleported by the time we're finished, so save the bounds at a reasonable point prior to teleporting
function EFFECT:StoreResidueOffsets()

	local when = self.DieTime - StoreTime
	if IsValid( self.ParentEntity ) and CurTime() > when and not self.StoredResidue then
		local ent = self.ParentEntity

		self.ResidueAng = ent:GetAngles()
		self.ResiduePos = ent:GetPos()
	end

end

function EFFECT:Render()
end

function EFFECT:DrawEntity( entity )

	if isfunction( entity._RenderOverride ) then
		entity:_RenderOverride()
	else
		entity:DrawModel()
	end
end

function EFFECT:DrawStencil( entity )
	
	local Fraction = ( self.DieTime - CurTime() ) / self.Time
	if self.DieTime < CurTime() then
		Fraction = ( CurTime() - self.DieTime ) / fadeOutTime
	end
	Fraction = 1 - math.Clamp( Fraction, 0, 1 )
	render.SetStencilEnable(true)
	render.ClearStencil()
	
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilCompareFunction( STENCIL_ALWAYS )
	render.SetStencilPassOperation( STENCIL_REPLACE )
	render.SetStencilFailOperation( STENCIL_KEEP )
	render.SetStencilZFailOperation( STENCIL_KEEP )
	render.SetStencilReferenceValue( 1 )
	
	self:DrawEntity( entity )
	
	render.SetStencilCompareFunction( STENCIL_EQUAL )
	render.SetStencilPassOperation( STENCIL_REPLACE )
	render.SetStencilReferenceValue( 1 )
	render.SetBlend(1)
	
	cam.Start2D()
	
		surface.SetDrawColor( 200, 255, 255, Fraction^2 * 255 )
		surface.DrawRect(0,0,ScrW(),ScrH())
	
	cam.End2D()
	
	
	render.SetStencilEnable( false )
	
end

function EFFECT:RenderOverlay( entity )

	local Fraction = ( self.DieTime - CurTime() ) / self.Time
	if self.DieTime < CurTime() then
		Fraction = ( CurTime() - self.DieTime ) / fadeOutTime
	end

	Fraction = 1 - math.Clamp( Fraction, 0, 1 )
	local ColFrac = ( Fraction - 0.5 ) * 2
	ColFrac = math.Clamp( ColFrac, 0, 1 )
	
	
	

	-- Change our model's alpha so the texture will fade out
	--entity:SetColor( 255, 255, 255, 1 + 254 * (ColFrac) )

	-- Place the camera a tiny bit closer to the entity.
	-- It will draw a big bigger and we will skip any z buffer problems
	local EyeNormal = entity:GetPos() - EyePos()
	local Distance = EyeNormal:Length()
	EyeNormal:Normalize()

	local Pos = EyePos() + EyeNormal * Distance * 0.01
	

	-- Start the new 3d camera position
	--local bClipping = self:StartClip( entity, 1.2 )
	cam.Start3D( Pos, EyeAngles() )


		-- If our card is DX8 or above draw the refraction effect
		if ( render.GetDXLevel() >= 80 ) then

			-- Update the refraction texture with whatever is drawn right now
			render.UpdateRefractTexture()

			matRefract:SetFloat( "$refractamount", Fraction^4 * 0.5 )

			-- Draw model with refraction texture
			render.MaterialOverride( matRefract )
				self:DrawEntity( entity )
			render.MaterialOverride( 0 )

		end

	-- Set the camera back to how it was
	cam.End3D()
	--render.PopCustomClipPlane()
	--render.EnableClipping( bClipping )

end

function EFFECT:RenderParent()

	--local bClipping = self.SpawnEffect:StartClip( self, 1 )

	--self:DrawModel()

	if halo.RenderedEntity() ~= self then
		self.SpawnEffect:DrawStencil( self )
	end

	--render.PopCustomClipPlane()
	--render.EnableClipping( bClipping )

	self.SpawnEffect:RenderOverlay( self )

end

function EFFECT:StartClip( model, spd )

	local mn, mx = model:GetRenderBounds()
	local Up = ( mx - mn ):GetNormal()
	local Bottom = model:GetPos() + mn
	local Top = model:GetPos() + mx

	local Fraction = (self.DieTime - CurTime()) / self.Time
	Fraction = math.Clamp( Fraction / spd, 0, 1 )

	local Lerped = LerpVector( Fraction, Bottom, Top )

	local normal = Up
	local distance = normal:Dot( Lerped )

	local bEnabled = render.EnableClipping( true )
	render.PushCustomClipPlane( normal, distance )

	return bEnabled

end
