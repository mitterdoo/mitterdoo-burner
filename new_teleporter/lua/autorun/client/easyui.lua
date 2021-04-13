-- easyui by mitterdoo

easyui = easyui or {}

--local cursorOverride = false -- true whenever our cursor is hovering over a screen and left mouse should be disabled
local curColor = Color( 0, 0, 0 )
local function setColor( r, g, b, a )
	if r and not g then -- this is a color object
		local col = r
		curColor.r = col.r
		curColor.g = col.g
		curColor.b = col.b
		curColor.a = col.a
	else -- these are individual rgba values
		a = a or 255
		curColor.r = r
		curColor.g = g
		curColor.b = b
		curColor.a = a
	end
end
local function scaleColor( col, scale )
	col.r = col.r * scale
	col.g = col.g * scale
	col.b = col.b * scale
end

local hover_scale = 0.8
local click_scale = 0.9


local function inheritMerge( dest, source )

	for k, v in pairs( source ) do
		if ( type( v ) == "table" && type( dest[ k ] ) == "table" && !v.ToHSV ) then
			-- don't overwrite one table with another
			-- instead merge them recurisvely
			table.Merge( dest[ k ], v )
		elseif dest[k] == nil then
			dest[ k ] = v
		end
	end

	return dest

end


easyui.ScreenMT = easyui.ScreenMT or {}
local META = easyui.ScreenMT



local defaultStyle = {
	Font = "default",
	Color = color_white,

	HAlign = TEXT_ALIGN_CENTER,
	VAlign = TEXT_ALIGN_CENTER,

	PaddingL = 0,
	PaddingR = 0,
	PaddingU = 0,
	PaddingD = 0,
	PaddingIgnoreBorder = false,

	ShadowEnabled = false,
	ShadowColor = color_black,
	ShadowH = 0,
	ShadowV = 0,

	StrokeEnabled = false,
	StrokeColor = color_black,
	StrokeWidth = 0,
	StrokeSubdivision = 1
}

META.HandleError = function() end

function META:Init()

	self.mx = 0
	self.my = 0
	self.mv = false
	self.MouseDown = false
	self.MouseClicked = false -- only true on the frame that we clicked the button
	self.LastMouseDown = false
	self.w = 128
	self.h = 128
	self.Scale = 0.1
	self.OffsetVec = Vector()
	self.OffsetAng = Angle()

	self.CursorColor = Color( 255, 0, 0 )
	self.CursorSize = 4

	self.HandleError = function( err ) -- xpcall doesn't pass "self" into the error function, so pass it here
		self:HandleErrorInternal( err )
	end

	self.TranslationStack = 0

end

--[[
function META:PushTranslation( x, y )

	local mat = Matrix()
	mat:SetTranslation( Vector( x, y ) )

	cam.PushModelMatrix( mat )
	self.TranslationStack = self.TranslationStack + 1

end

function META:PopTranslation()

	if self.TranslationStack <= 0 then return end
	cam.PopModelMatrix()
	self.TranslationStack = self.TranslationStack - 1

end

function META:PopAllTranslations()

	for i = 1, self.TranslationStack do
		self:PopTranslation()
	end

end
]]


function META:Button( x, y, w, h, color, text, style, borderSize, borderColor, locked, callback, ... )

	local isOn = false
	if not locked then
		isOn = self:MouseOn( x, y, w, h )
	end

	setColor( color )

	if isOn then

		self.ButtonHovered = true

		if self.MouseDown then
			scaleColor( curColor, click_scale )
		else
			scaleColor( curColor, hover_scale )
		end

	end

	if text then
		style = style or defaultStyle
		self:TextBox( x, y, w, h, curColor, text, style, borderSize, borderColor, locked )
	end
	
	local clickedOn = isOn and self.MouseClicked
	if clickedOn then
		self.MouseClicked = false -- forget that there was a click until the next frame to avoid multiple buttons being clicked
		if callback then
			callback( self, ... )
		end
	end

	return clickedOn

end

function META:Box( x, y, w, h, color, borderSize, borderColor )

	borderSize = borderSize or 0

	if borderSize > 0 then
		surface.SetDrawColor( borderColor )
		surface.DrawRect( x, y, w, h )
	end

	surface.SetDrawColor( color )
	surface.DrawRect( x + borderSize, y + borderSize, w - borderSize*2, h - borderSize*2 )

end

function META:TextBox( x, y, w, h, color, text, style, borderSize, borderColor, locked )

	self:Box( x, y, w, h, color, borderSize, borderColor )

	if text then
		borderSize = borderSize or 0
		if style and not style.PaddingIgnoreBorder then
			x = x + borderSize
			y = y + borderSize
			w = w - borderSize*2
			h = h - borderSize*2
		end
		self:Text( x, y, w, h, text, style )
	end

end

function META:Text( x, y, w, h, text, style )

	text = tostring( text )
	style = style or {}

	inheritMerge( style, defaultStyle )

	surface.SetFont( style.Font )
	local tw, th = surface.GetTextSize( text )

	local tx, ty = x, y
	if style.HAlign == TEXT_ALIGN_LEFT then
		tx = x + style.PaddingL
	elseif style.HAlign == TEXT_ALIGN_RIGHT then
		tx = x + w - tw - style.PaddingR
	else
		tx = x + w/2 - tw / 2
	end

	if style.VAlign == TEXT_ALIGN_TOP then
		ty = y + style.PaddingU
	elseif style.VAlign == TEXT_ALIGN_BOTTOM then
		ty = y + h - th - style.PaddingD
	else
		ty = y + h/2 - th/2
	end

	if style.ShadowEnabled then
		local ox, oy = style.ShadowH, style.ShadowV
		surface.SetTextColor( style.ShadowColor )
		surface.SetTextPos( tx + ox, ty + oy )
		surface.DrawText( text )
	end

	if style.StrokeEnabled then
		local wide = style.StrokeWidth
		surface.SetTextColor( style.StrokeColor )
		for ox = -1, 1, 2 / style.StrokeSubdivision do
			for oy = -1, 1, 2 / style.StrokeSubdivision do
				if ox == 0 and oy == 0 then continue end

				surface.SetTextPos( tx + ox * wide, ty + oy * wide )
				surface.DrawText( text )
			end
		end
	end

	surface.SetTextColor( style.Color )
	surface.SetTextPos( tx, ty )
	surface.DrawText( text )

end






local function isUseButtonPressed()
	return LocalPlayer():KeyDown( IN_USE )-- or input.IsMouseDown( MOUSE_LEFT )
end

function META:MouseOn( x, y, w, h ) -- pass w and h for rect, pass w only for radius of a circle

	local mx, my, visible, mouseDown = self.mx, self.my, self.mv, self.MouseDown

	if not visible then return false end
	if not h and w then -- circle args
		return math.Distance( x, y, mx, my ) <= w
	end
	local x2, y2 = x + w, y + h
	return mx > x and mx < x2 and my > y and my < y2

end


local function RayQuadIntersect(vOrigin, vDirection, vPlane, vX, vY)
	local vp = vDirection:Cross(vY)

	local d = vX:DotProduct(vp)

	if (d <= 0.0) then return end

	local vt = vOrigin - vPlane
	local u = vt:DotProduct(vp)
	if (u < 0.0 or u > d) then return end

	local v = vDirection:DotProduct(vt:Cross(vX))
	if (v < 0.0 or v > d) then return end

	return Vector(u / d, v / d, 0)
end

function META:MouseRayInteresct( pos, ang, width, height, eyepos, eyeang )
	local plane = pos + ( ang:Forward() * ( width / 2 ) ) + ( ang:Right() * ( height / -2 ) )

	local x = ( ang:Forward() * -( width ) )
	local y = ( ang:Right() * ( height ) )

	if type( eyeang ) == "Angle" then
		eyeang = eyeang:Forward()
	end

	return RayQuadIntersect( eyepos, eyeang, plane, x, y )
end

function META:GetCursorPos( pos, ang, scale, eyepos, eyeang )

	local w, h = self.w, self.h
	--local size = self.ActiveModule and self.ActiveModule.ScreenSize or self.ModuleSize
	--local scale = self.SegmentSpacing / size

	local uv = self:MouseRayInteresct( pos, ang, w, h, eyepos, eyeang )
	
	if uv then
		local x,y = (( 0.5 - uv.x ) * w), (( uv.y - 0.5 ) * h)
		x = x / scale
		y = y / scale

		if x < 0 or y < 0 or x > w or y > h then
			self.mv = false
			return
		end
		self.mv = true
		return (x), (y)
	end
end

function META:UpdateMouseInfo( pos, ang, scale )

	local x, y = self:GetCursorPos( pos, ang, scale, EyePos(), LocalPlayer():GetAimVector() )
	if not x then
		return
	end
	self.mx = x
	self.my = y

	self.MouseClicked = false
	self.MouseDown = isUseButtonPressed()

	if self.MouseDown ~= self.LastMouseDown then
		self.LastMouseDown = self.MouseDown
		if self.MouseDown then
			self.MouseClicked = true
		end
	end

end

local function wrap(str, limit)
	local here = 1
	return str:gsub("([ ]+)()([^ ]+)()",
	function(sp, st, word, fi)
		local w,h = surface.GetTextSize( str:sub( here, fi ) )
		--if fi-here > limit then
		if w > limit then
			here = st
			return "\n"..word
		end
	end)
end

function META:HandleErrorInternal( err )

	local w, h = self.w, self.h
	--self:PopAllTranslations()

	surface.SetDrawColor( 0, 0, 128, 64 )
	surface.DrawRect( 0, 0, w, h )

	local stack = debug.traceback( err, 3 )
	local text = "ERROR: " .. stack

	surface.SetFont( "default" )

	text = wrap( text, w )

	surface.SetTextColor( 255, 255, 255 )
	local tw, th = surface.GetTextSize( "a" )

	text = text:gsub( "\t", "    " )
	text = string.Split( text, "\n" )
	for i = 1, #text do
		surface.SetTextPos( 0, ( i - 1 ) * th )
		surface.DrawText( text[i] )
	end


end

local function internalDrawingFailed( err )

	local stack = debug.traceback( err, 2 )
	local text = "ERROR: " .. stack
	ErrorNoHalt( text .. "\n" )

end

function META:Cam3D2DStuff( pos, ang, scale, w, h, ent )

	self:UpdateMouseInfo( pos, ang, scale, w, h )

	if self.Paint then
		local ok = xpcall( self.Paint, self.HandleError, self, w, h, ent )

		--self:PopAllTranslations()
	end

	--[[
	if self.mv and not self.DisableInputSuppression and self.ButtonHovered then
		cursorOverride = true
	end
	]]

	self:DrawCursor()

end

function META:Draw( ent )

	assert( IsValid( ent ), "attempt to start easyui on a NULL entity!" )
	local pos = ent:LocalToWorld( self.OffsetVec )
	local ang = ent:LocalToWorldAngles( self.OffsetAng )
	local scale = self.Scale
	local w, h = self.w, self.h

	self.ButtonHovered = false


	pos = pos + ang:Forward() * w/-2 * scale
	pos = pos + ang:Right() * h/-2 * scale

	cam.Start3D2D( pos, ang, scale )

	-- xpcall all of this JUST to make sure it's okay
	xpcall( self.Cam3D2DStuff, internalDrawingFailed, self, pos, ang, scale, w, h, ent )

	cam.End3D2D()

end

function META:DrawCursor()

	if not self.mv or self.HideCursor then return end
	local size = self.CursorSize
	local x, y = self.mx, self.my
	surface.SetDrawColor( self.CursorColor )
	surface.DrawRect( x - size/2, y - size/2, size, size )

end

function easyui.Create()

	META.__index = META
	local obj = setmetatable( {}, META )
	obj:Init()
	return obj

end

--[[
hook.Add( "PreRender", "easyui_cursorOverride", function()

	cursorOverride = false

end )
hook.Add( "StartCommand", "easyui_cursorOverride", function( ply, ucmd )

	if cursorOverride then
		ucmd:RemoveKey( IN_ATTACK )
	end

end )
]]
