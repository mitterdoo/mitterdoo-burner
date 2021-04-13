local cvar_showDest = CreateClientConVar( "cl_teleporter_destination", "1" )
local cvar_screenspace = CreateClientConVar( "cl_teleporter_screenspace", "1" )
local cvar_sprRealistic = CreateClientConVar( "cl_teleporter_spr_realistic", "1" )
local cvar_sprRings = CreateClientConVar( "cl_teleporter_spr_rings", "1" )
local cvar_sprPlatform = CreateClientConVar( "cl_teleporter_spr_platform", "1" )
local cvar_sprFlash = CreateClientConVar( "cl_teleporter_spr_flash", "1" )

local brightGlow = CreateMaterial("teleport_glow_noz" .. os.time(), "UnlitGeneric", {
	["$basetexture"] = "sprites/light_glow02",
	["$spriterendermode"] = 9,
	["$ignorez"] = 1,
	["$illumfactor"] = 8,
	["$additive"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1})
local brightGlowNormal = CreateMaterial("teleport_glow" .. os.time(), "UnlitGeneric", {
	["$basetexture"] = "sprites/light_glow02",
	["$spriterendermode"] = 9,
	["$illumfactor"] = 8,
	["$additive"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1})


local sprite_color = Color(0,0,0,0)

-- keyframes to use in my own keyframing function
local fxKeyframes = {
	Flash = {
		{ 0.4, 0 },
		{ 0, 1 },
		{ -0.2, 0 }
	},
	BlindingFlash = {
		{ .1, 0 },
		{ 0, 1 },
		{ -.5, 0 }
	},
	LightGlow = {
		{ 8.63, 0 },
		{ 3, 1 },
		{ 0, 1 },
		{ -0.1, 0 },
	},

	PeekAlpha = {
		{ 8, 0 },
		{ 4, 200 },
		{ 0, 200 },
		{ -0.25, 0 }
	},

	FullPeek = {
		{ ENT.Times.Suck, 0 },
		{ 1, .7 },
		{ -0.2, .7 }, -- fade out a little later to compensate for lag
		{ -0.75, 0 }
	}
}

-- offsets for where each glowing light should be, as well as their brightnesses
local glowingLights = {
	{ Vector( 47, 0, -3 ), 1 },
	{ Vector( 43, -17, -3 ), 0.8 },
	{ Vector( 43, 17, -3 ), 0.8 },
	{ Vector( 10,- 23, -7.7 ), 1 },
	{ Vector( 10, 23, -7.7 ), 1 },
}
-- same as above, but relative to each ring and constant brightness
local ringLights = {
	Vector( 26, 14.5, 4 ),
	Vector( 26, -14.5, 4 ),
	Vector( 3, 29, 4 ),
	Vector( 3, -29, 4 )
}

-- now, because source is dumb, we can't use one pixel handle for multiple checks
-- so, we must create individual pixel handles for the checks to be done
-- it would be a lot harder to hardcode the exact number of handles to allow, so i
-- made this system that uses as many as we need in this frame.
-- if we go over, we can always set the number of handles higher
function ENT:GetPixelHandle( pos, rad )
	if self.CurrentHandle > #self.PixelHandles then
		error "ran out of usable pixel handles!"
	end

	local h = self.PixelHandles[ self.CurrentHandle ]
	h.Pos = pos
	h.Radius = rad
	h.Enabled = true

	self.CurrentHandle = self.CurrentHandle + 1
	return h.LastValue
end

-- don't waste memory by creating a similar table EVERY sprite draw
local traceInfo = {
	start = Vector(),
	endpos = Vector(),
	filter = LocalPlayer(),
	mask = MASK_VISIBLE_AND_NPCS
}

-- this lets us draw a sprite that doesn't ignore the z-buffer (technically this does) and yet still looks cool
function ENT:DrawSprite( pos, sx, sy, color, ignoreTeleporting, vis )

	if not cvar_sprRealistic:GetBool() then
		render.DrawSprite( pos, sx, sy, color )
		return 1
	end
	-- allow using an existing visibility percentage
	if !vis then

		local pixelPos = pos
		if not ignoreTeleporting then
			traceInfo.start = EyePos()
			traceInfo.endpos = pos
			local tr = util.TraceLine( traceInfo )
			pixelPos = tr.HitPos
			
			if ( IsValid( tr.Entity ) or tr.HitWorld ) and !table.HasValue( self.AllowedEnts, tr.Entity ) and !self.RingLookup[tr.Entity] then
				pixelPos = pos
			end
		end
		


		vis = self:GetPixelHandle( pixelPos, 1 )
	end

	sprite_color.r = color.r
	sprite_color.g = color.g
	sprite_color.b = color.b
	sprite_color.a = color.a * vis

	render.DrawSprite( pos, sx, sy, sprite_color )

	-- return the visibility percentage so we can save it for later and not have to use another pixel handle
	return vis

end


// individual keyframe structure: { time, value }
local function LerpKeyframes( curTime, keyframes, easein, easeout )
	
	if !keyframes.Sorted then
		table.sort( keyframes, function( a, b ) return a[1] < b[1] end )
		keyframes.Sorted = true
	end
	easein = easein or 0.5
	easeout = easeout or 0.5
	local keyCount = #keyframes
	if curTime < keyframes[1][1] then // we're before the first key; use first value
		return keyframes[1][2]
	elseif curTime >= keyframes[ keyCount ][1] then // we're after the last key; use last value
		return keyframes[ keyCount ][2]
	end
	
	// now find out what key we're on right now
	local keyA, keyB
	for i = 1, keyCount do
		if curTime >= keyframes[i][1] and curTime < keyframes[ i + 1 ][1] then
			keyA = i
			keyB = i + 1
			break
		end
	end
	
	// get progress through these keys
	local percent = math.TimeFraction( keyframes[ keyA ][1], keyframes[ keyB ][1], curTime )
	// ease
	percent = math.EaseInOut( percent, easein or 0, easeout or 0 )
	
	// finally lerp between the two values
	local lerped = Lerp( percent, keyframes[ keyA ][2], keyframes[ keyB ][2] )
	return lerped
	
end

-- memory mercy
local colorReference = Color(0,0,0)
local function SafeColor( r, g, b, a )
	a = a or 255
	colorReference.r = r
	colorReference.g = g
	colorReference.b = b
	colorReference.a = a
	return colorReference
end

local glowW, glowH = 400, 300
local flashW, flashH = 1600, 150
function ENT:DrawSprites()

	if not self:IsWithinTimeframe() then return end

	self.CurrentHandle = 1
	for k,handle in pairs( self.PixelHandles ) do
		handle.Enabled = false
	end


	local Until = self:GetTeleportTime() - CurTime()
	local vis -- cached visibility percentage to use in sprite rendering

	if cvar_sprRealistic:GetBool() then
		render.SetMaterial( brightGlow )
	else
		render.SetMaterial( brightGlowNormal )
	end


	if cvar_sprFlash:GetBool() then -- flash on platform

		local Fraction = LerpKeyframes( Until, fxKeyframes.Flash )
		local alpha = Fraction*255


		for i = 0, 72, 9 do
			local pos = self:GetPos() + self:GetUp() * i
			vis = self:DrawSprite( pos, glowW, glowH, SafeColor( 0, 200, 255, alpha ) )
			self:DrawSprite( pos, glowW, glowH, SafeColor( 255, 255, 255, alpha ), false, vis )
		end

		local lightPos = self:GetPos() + self:GetUp() * 36
		vis = self:DrawSprite( lightPos * 36, flashW, flashH, SafeColor( 0, 200, 255, alpha ) )
		self:DrawSprite( lightPos * 36, flashW, flashH, SafeColor( 255, 255, 255, alpha ), false, vis )

		self:DrawSprite( lightPos * 36, flashH, flashW, SafeColor( 0, 200, 255, alpha ), false, vis )
		self:DrawSprite( lightPos * 36, flashH, flashW, SafeColor( 255, 255, 255, alpha ), false, vis )
	end

	local Fraction = LerpKeyframes( Until, fxKeyframes.LightGlow )

	if cvar_sprPlatform:GetBool() then -- platform lights glowing

		for k,light in pairs( glowingLights ) do
			local pos = self:LocalToWorld( light[1] )
			local intensity = light[2] * Fraction
			vis = self:DrawSprite( pos, 32, 16, SafeColor( 0, 200, 255, 255 * intensity ), true )
			self:DrawSprite( pos, 32, 16, SafeColor( 255, 255, 255, 255 * intensity ), true, vis )

		end
	end


	if cvar_sprRings:GetBool() and self:RingsValid() then
		for _, ring in pairs( self.Rings ) do
			for k,light in pairs( ringLights ) do

				local pos = ring.Entity:LocalToWorld( light )
				local intensity = Fraction
				vis = self:DrawSprite( pos, 32, 32, SafeColor( 0, 200, 255, 255 * intensity ), true )
				self:DrawSprite( pos, 32, 32, SafeColor( 255, 255, 255, 255 * intensity ), true, vis )

			end
		end
	end

end


-- vectors + angles to draw the "peeks" on each ring
local ringPeekTransforms = {
	{ Vector( 30, 0, 4.6 ), Angle( 0, 90, 90 ) },
	{ Vector( 17.6, 24.3, 4.6 ), Angle( 0, 180-36, 90 ) },
	{ Vector( 17.6, -24.3, 4.6 ), Angle( 0, 36, 90 ) },
}

-- draws the peeks (this is to be used during stencil magic)
function ENT:DrawRingMask( ring )

	local scale = 4
	for k, transform in pairs( ringPeekTransforms ) do

		local pos = ring:LocalToWorld( transform[1] )
		local ang = ring:LocalToWorldAngles( transform[2] )

		local curPos = pos + ang:Forward() * 3.5
		local curAng = Angle( ang.p, ang.y, ang.r )
		curAng:RotateAroundAxis( ang:Right(), -9 )

		local w, h = 60, 18
			surface.SetDrawColor( 255, 255, 255, 1 )

		cam.Start3D2D( curPos, curAng, 1/scale )

			surface.DrawRect( w/-2, h/-2, w, h )

		cam.End3D2D()

		curPos = pos + ang:Forward() * -3.5
		curAng = Angle( ang.p, ang.y, ang.r )
		curAng:RotateAroundAxis( ang:Right(), 9 )

		cam.Start3D2D( curPos, curAng, 1/scale )

			surface.DrawRect( w/-2, h/-2, w, h )

		cam.End3D2D()

	end
end

-- we only want to render the cool magic on whichever is closest so we don't kill the frames
local function findNearestPlatform()

	local dist, closest = math.huge
	local pos = EyePos()
	for k,ent in pairs( ents.FindByClass( "gmod_teleporter_platform" ) ) do

		local newDist = pos:Distance( ent:GetPos() )
		if newDist < dist then
			dist = newDist
			closest = ent
		end

	end

	return closest

end

local rtTexture = CreateMaterial(
	"teleporter_rendertarget" .. os.time(),
	"GMODScreenspace",
	{
		["$basetexturetransform"] = "center .5 .5 scale -1 -1 rotate 0 translate 0 0",
		["$texturealpha"] = "0",
		["$vertexalpha"] = "1",
	}
)

-- don't waste time drawing cool stuff if we aren't doing cool stuff
function ENT:IsWithinTimeframe( timeFrame )

	timeFrame = timeFrame or self.Times.Windup


	local t = self:GetTeleportTime()
	local Until = t - CurTime()
	return t > 0 and Until <= timeFrame and Until >= -1

end

-- draws the "peeks" in the rings, showing a preview of the destination
function ENT:DrawDestination()

	if not self:IsWithinTimeframe( self.Times.PeekBegin ) then return end
	if not self:RingsValid() then return end
	if not IsValid( findNearestPlatform() ) then return end

	local Until = self:GetTeleportTime() - CurTime()

	local Alpha = LerpKeyframes( Until, fxKeyframes.PeekAlpha )


	render.ClearStencil()
	render.SetStencilEnable( true )

	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)

	render.SetStencilFailOperation( STENCILOPERATION_KEEP )
	render.SetStencilZFailOperation( STENCILOPERATION_KEEP )
	render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
	render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_ALWAYS )
	render.SetStencilReferenceValue( 1 )

	for k, info in pairs( self.Rings ) do

		local ring = info.Entity
		self:DrawRingMask( ring )

	end

	render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_EQUAL )
	render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
	render.SetStencilReferenceValue( 1 )

	self:DrawRenderTarget( Alpha ) -- draw this peek in the rings

	render.SetStencilEnable(false)

end

-- the vanilla material doesn't allow alpha changing, so we must create our own to modify ourselves
local warpMat = CreateMaterial(
	"teleporter_warp_overlay" .. os.time(),
	"UnlitGeneric",
	{
		["$basetexture"] = "effects/tp_eyefx/3tpeyefx_",
		["$alpha"] = "1",
		["$additive"] = "1",
		["Proxies"] = {
			["AnimatedTexture"] = {
				["animatedtexturevar"] = "$basetexture",
				["animatedtextureframenumvar"] = "$frame",
				["animatedtextureframerate"] = "30"
			}
		}
	}
)
-- this renders the entire destination "fading" in as well as the warp overlay and screen-covering flash
function ENT:DrawTeleportingEffects()

	local Until = self:GetTeleportTime() - CurTime()
	if not self:IsWithinTimeframe( self.Times.Suck ) then return end -- don't waste time rendering this shit

	if cvar_showDest:GetBool() then

		local Fraction = LerpKeyframes( Until, fxKeyframes.FullPeek ) 
		Fraction = math.Clamp( Fraction, 0, 1 ) -- be sane

		-- this portion adds a "flashing" or "wobbly" effect to the destination fading in
		local Amplitude = 12
		local Frequency = 8

		Frequency = Frequency * math.pi * 2
		local Max = 225

		local Alpha = ( math.sqrt( Max ) * Fraction )^2 -- this is the actual fade
		Alpha = Alpha + math.sin( CurTime() * Frequency ) * Amplitude - Amplitude -- now add the wibbly wobbly stuff

		-- now draw it over the screen like we're "fading" into the place
		self:DrawRenderTarget( Alpha )

	end

	-- the flash carries on after the teleportation, but the warp overlay should only happen before and not after
	-- this variable is whether we should render the overlay
	local RenderLeadup = Until >= 0
	if RenderLeadup then

		-- we have to manually change the alpha of the material because alpha in surface.DrawTexturedRect doesn't work for this one
		local Alpha = math.TimeFraction( self.Times.Suck, 0, Until ) -- fade in
		Alpha = math.Clamp( Alpha, 0, 1 ) -- be sane

		warpMat:SetFloat( "$alpha", Alpha )

		-- now draw it
		render.SetMaterial( warpMat )
		render.SetColorModulation( 1,1,1 )
		render.DrawScreenQuad()

	end

end


function ENT:DrawTeleportingScreenspace()

	local Until = self:GetTeleportTime() - CurTime()
	if not self:IsWithinTimeframe( self.Times.Suck ) then return end -- don't waste time rendering this shit

	local Alpha = math.abs( Until ) / 0.25
	Alpha = 1 - math.Clamp( Alpha, 0, 1 )

	local Max = 255

	Alpha = ( math.sqrt( Max ) * Alpha )^2

	surface.SetDrawColor( 255, 255, 255, Alpha )
	surface.DrawRect( 0, 0, ScrW(), ScrH() )
end

local TEX_COORD_FIX = 0.016

function ENT:DrawRenderTarget( Alpha )

	rtTexture:SetTexture( "$basetexture", self.RenderTarget )

	cam.Start2D()
	surface.SetMaterial( rtTexture )
	surface.SetDrawColor( 255, 255, 255, Alpha )

	surface.DrawTexturedRectUV( 0, 0, ScrW(), ScrH(),
		-TEX_COORD_FIX,
		-TEX_COORD_FIX,
		1.0 + TEX_COORD_FIX,
		1.0 + TEX_COORD_FIX
	)
	cam.End2D()

end
hook.Add( "RenderScene", "teleporter_peeking", function( plyOrigin, plyAngles )

	if not cvar_showDest:GetBool() then return end

	if not IsValid( findNearestPlatform() ) then return end
	kl_teleporter.isDrawingPeeks = true

	local oldWepColor = LocalPlayer():GetWeaponColor()
	LocalPlayer():SetWeaponColor( Vector(0, 0, 0) )

	for k,ent in pairs( ents.FindByClass( "gmod_teleporter_platform" ) ) do

		if not ent:IsWithinTimeframe() then continue end
		local pos, ang = ent:GetCameraTransform( plyOrigin, plyAngles )

		render.PushRenderTarget( ent.RenderTarget )

			render.Clear( 0,0,0, 255 )
			render.ClearDepth()
			render.ClearStencil()

				render.RenderView( {
					x = 0, y = 0,
					w = ScrW(), h = ScrH(),
					origin = pos,
					angles = ang,
					drawpostprocess = false,
					drawhud = false,
					drawmonitors = false,
					drawviewmodel = false
				})

		render.PopRenderTarget()

	end

	kl_teleporter.isDrawingPeeks = false
	LocalPlayer():SetWeaponColor( oldWepColor )


end )
hook.Add( "CalcView", "teleporter_pixelvis", function()

	if not cvar_sprRealistic:GetBool() then return end

	for k,ent in pairs( ents.FindByClass( "gmod_teleporter_platform" ) ) do
		if not ent.PixelHandles then return end
		for k, handle in pairs( ent.PixelHandles ) do

			if handle.Enabled then
				handle.LastValue = util.PixelVisible( handle.Pos, handle.Radius, handle.Handle )
			end

		end

	end

end )

-- when the player teleports, the post-teleport effects are visible on the other teleporter
-- so, i have to force it to be the old one for a short time
local teleporterOverride
local unlockTime = 0



-- gets the position and angles our eyes WOULD be at if we teleported
-- this is the transform the "peeks" will be rendering from
function ENT:GetCameraTransform( pPos, pAng )

	local dest 
	if teleporterOverride then
		dest = teleporterOverride
	else
		dest = self:GetDestination()
	end
	if not IsValid( dest ) then
		return LocalToWorld( 
			self:WorldToLocal( pPos ), self:WorldToLocalAngles( pAng ),
			Vector(), Angle()
		)
	end

	local lPos, lAng = self:WorldToLocal( pPos ), self:WorldToLocalAngles( pAng )

	return dest:LocalToWorld( lPos ), dest:LocalToWorldAngles( lAng )

end


function ENT:ShouldDrawTeleportFX()

	return cvar_screenspace:GetBool() and self:IsWithinTimeframe() and self:IsVectorInZone( EyePos() )

end

function ENT:LockCheck()

	if teleporterOverride then return end
	local Until = self:GetTeleportTime() - CurTime()
	if Until < 4 and Until > 0 then
		teleporterOverride = self:GetDestination()
		unlockTime = self:GetTeleportTime() + 2
	end

end

hook.Add( "PostDrawTranslucentRenderables", "teleport_glow", function( sky )
	
	if sky or kl_teleporter.isDrawingPeeks then return end

	if teleporterOverride and CurTime() > unlockTime then
		teleporterOverride = nil
	end
	
	for k,ent in pairs( ents.FindByClass( "gmod_teleporter_platform" ) ) do
		ent:DrawSprites()

		if ent:ShouldDrawTeleportFX() then
			ent:DrawTeleportingEffects()

			ent:LockCheck()

		end
	end

end )
-- RenderScreenspaceEffects has some weird colors going on with it, aka pure white doesn't appear pure white, so i gotta use something else
hook.Add( "PostDrawViewModel", "teleport_effects", function()

	cam.Start2D()
	for k,ent in pairs( ents.FindByClass( "gmod_teleporter_platform" ) ) do
		if ent:ShouldDrawTeleportFX() then
			ent:DrawTeleportingScreenspace()
			ent:LockCheck()
		end
	end
	cam.End2D()
end )

