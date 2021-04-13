include "shared.lua"
include "cl_drawing.lua"
include "cl_rings.lua"

local cvar_showDest = CreateClientConVar( "cl_teleporter_destination", "1" )

kl_teleporter = kl_teleporter or {}
kl_teleporter.isDrawingPeeks = false


local makeLookup = ENT.MakeLookup
local merge = ENT.Merge


local handleCount = 64
function ENT:Initialize()

	self.PixelHandles = {}
	for i = 1, handleCount do
		table.insert( self.PixelHandles, {
			Handle = util.GetPixelVisibleHandle(),
			LastValue = 0,
			Pos = Vector(),
			Radius = 0,
			Enabled = false
		} )
	end
	
	local hookName = "teleporter_temporary_" .. self:EntIndex()
	hook.Add( "RenderScene", hookName, function()


			for k, info in pairs( self.PixelHandles ) do
				util.PixelVisible( Vector(), 1, info.Handle )
			end
			hook.Remove( "RenderScene", hookName )
	end )

	self.CurrentHandle = 1
	self.AllowedEnts = {}

	self.RenderTarget = GetRenderTarget("teleporterPeek" .. self:EntIndex(),
			ScrW(),
			ScrH(),
			false
		)

	self:SpawnRings()

end




function ENT:OnRemove()

	self:RemoveRings()

end

local function dummy() return end

function ENT:Think()

	self:RingsThink()
	self:CoroutineThink()

	for i = 1, 8 do
		local ent = self["GetCollider" .. i ]( self )
		if IsValid( ent ) then

			ent:EnableCustomCollisions( true )
			ent.TestCollision = dummy

		end
	end

end

function ENT:Draw()

	self:DrawModel()

	self:UpdateRings()

	if kl_teleporter.isDrawingPeeks then return end


	self:DrawRings()

	if cvar_showDest:GetBool() and halo.RenderedEntity() ~= self then
		self:DrawDestination()
	end
	--[[
	
	-- Zone visualization

	for k,v in pairs( self:GetZones() ) do
		render.DrawWireframeBox(v.center, Angle(0,0,0) , v.min, v.max,Color(255,0,0),true)
	end
	--]]

end


-- TODO: add ring prediction so rings are already moving when active teleporter enters visleaf

net.Receive( "teleporter_net", function()

	local ent = net.ReadEntity()
	if not IsValid( ent ) or ent:GetClass() ~= "gmod_teleporter_platform" then return end
	local type = net.ReadUInt( 2 )

	if type == ent.Net.StartRings then
		ent:StartMovingRings()
	elseif type == ent.Net.StopRings then
		ent:StopMovingRings()
	elseif type == ent.Net.Allowed then

		local other = net.ReadEntity()
		local count = net.ReadUInt( 32 )
		local list = {}
		for i = 1, count do
			local allowedEnt = net.ReadEntity()
			if IsValid(allowedEnt) then
				table.insert( list, allowedEnt )
			end
		end
		ent.AllowedEnts = list
		other.AllowedEnts = list

	end

end )
--[[

net.Receive( "teleporter_net", function()
	local self = net.ReadEntity()
	if !IsValid( self ) or self:GetClass() != "gmod_teleporter_platform" then return end

	local count = net.ReadUInt( 32 )
	local list = {}
	for i = 1, count do
		local ent = net.ReadEntity()
		if IsValid(ent) then
			table.insert( list, ent )
		end
	end
	self.AllowedEnts = list
end )]]



