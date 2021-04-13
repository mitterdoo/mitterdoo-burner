local Tag = "teleporter_net"
local makeLookup = ENT.MakeLookup
local merge = ENT.Merge
function ENT:StartNet( type )

	net.Start( Tag )
	net.WriteEntity( self )
	net.WriteUInt( type, 2 )

end

function ENT:WriteEnts( ents )

	net.WriteUInt( #ents, 32 )
	for k,v in pairs( ents ) do
		net.WriteEntity( v )
	end

end


function ENT:BroadcastEnts()

	local list = self:GetEnts()
	local theirs = {}

	local valid = self:DestValid()
	local dest = self:GetDestination()
	if valid then
		theirs = dest:GetEnts()
	end

	merge( list, theirs )

	self:StartNet( self.Net.Allowed )
	net.WriteEntity( dest )
	self:WriteEnts( list )
	net.Broadcast()

end

