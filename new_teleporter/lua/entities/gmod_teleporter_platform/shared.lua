ENT.PrintName		= "Teleporter Platform"

ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.Spawnable		= true
ENT.Category 		= "Fun + Games"
ENT.Model			= "models/props_lab/teleplatform.mdl"


ENT.ZoneOrigin = Vector( 9, 0, 0 )
if SERVER then
	ENT.ZoneHeight = 80
else
	ENT.ZoneHeight = 102 -- compensate for jump height
end
ENT.ZoneSize = 48

ENT.PlatformOffset = Vector( 32, 0, 16 ) -- position relative to teleportframe model

ENT.Net = {
	Allowed = 0,
	StartRings = 1,
	StopRings = 2,
	
}

ENT.Times = { -- all of these times represent how much time before the teleport time
	Suck = 4.366,
	Windup = 8.63,

	PeekBegin = 8, -- how long before the teleport should the peeks begin fading in?
}

local snd_hum = sound.Add {
	name = "teleporter_hum",
	channel = CHAN_AUTO,
	volume = 1,
	pitch = 100,
	level = 85,
	sound = "ambient/levels/labs/teleport_active_loop1.wav"
}

local snd_wind = sound.Add {
	name = "teleporter_wind",
	channel = CHAN_AUTO,
	volume = 1,
	pitch = 100,
	level = 85,
	sound = "ambient/levels/labs/teleport_rings_loop2.wav"
}

local snd_alarm = sound.Add {
	name = "teleporter_alarm",
	channel = CHAN_AUTO,
	volume = 1,
	pitch = 100,
	level = 85,
	sound = "ambient/levels/labs/teleport_alarm_loop1.wav"
}



ENT.Sounds = {

	Teleport = "ambient/machines/teleport4.wav",
	Suck = "hl1/ambience/particle_suck2.wav",
	Start = "ambient/levels/labs/teleport_mechanism_windup2.wav",
	Windup = "ambient/levels/labs/teleport_mechanism_windup3.wav",
	Hum = "teleporter_hum",
	Wind = "teleporter_wind",
	Thunder = "ambient/levels/labs/teleport_postblast_thunder1.wav",
	Winddown = "ambient/levels/labs/teleport_winddown1.wav",
	Alarm = "teleporter_alarm"

}


--[[-------------------------------------------------------------------------

notes:

make sure both teleporters receive tables that signify which ents the glows should overlap


NetworkVar Destination (Entity)
NetworkVar TeleportTime (Float)

*Trigger Start
SERVER: verify destination exists
SERVER: us:SetDestination( ↑ )
SERVER: dest:SetDestination( us )

SERVER: us+dest:SetTeleportTime( CurTime() + 20 )

		SERVER → CLIENTS (all): start moving rings on us and dest


y SERVER: wait until ENT.Times.Windup should be triggered
		SERVER → CLIENTS (all):	RunTeleportEffect
						send ents on both us and dest

y SERVER: wait until teleport time
SERVER: perform teleport
CLIENTS: forget list of entities on platform
SERVER: us+dest:SetTeleportTime( 0 )
		SERVER → CLIENTS (all): SlowdownRings

done holy shit


---------------------------------------------------------------------------]]


local function makeLookup( tab )

	local lookup = {}
	for k,v in pairs( tab ) do
		lookup[v] = true
	end

	return lookup

end

--[[-------------------------------------------------------------------------
Takes each object in the source table and adds it to the destination table
if it isn't in there already
---------------------------------------------------------------------------]]
local function merge( dest, from )

	local lookup = makeLookup( dest )

	for k,v in pairs( from ) do
		if !lookup[v] then
			table.insert( dest, v )
			lookup[v] = true
		end
	end

end

ENT.MakeLookup = makeLookup
ENT.Merge = merge




--[[-------------------------------------------------------------------------
coroutine stuff
---------------------------------------------------------------------------]]
ENT.Coroutines = {}

local y_None = 0
local y_Sleep = 1
local y_Condition = 2

local META = {}
function META:Think( ... )
	
	if self.Halted then return end
	
	local co = self.Coroutine
	if type( co ) ~= "thread" or coroutine.status( co ) == "dead" then
		self.Halted = true
		return
	end
	
	
	-- should we even resume?
	
	local param = {...}
	
	if self.YieldingTo == y_Sleep then
		if CurTime() < self.ResumeTime then return end
	elseif self.YieldingTo == y_Condition and type( self.ConditionFunction ) == "function" then
		param = { self.ConditionFunction( self.Entity, unpack( self.ConditionArgs ) ) }
		
		if #param == 0 or not param[1] then return end
		
	end
		
	self.YieldingTo = 0
	
	
	-- guess so
	
	local returned = { coroutine.resume( co, unpack( param ) ) }
	local success, yieldTo, arg = returned[1], returned[2], returned[3]

	table.remove( returned, 1 )
	table.remove( returned, 1 )
	table.remove( returned, 1 )

	local status = coroutine.status( co )
	if not success then
		
		-- second return value from coroutine.resume() is the error if something fucks up
		error( "error in coroutine!\n" .. tostring( yieldTo ) )
		return
		
	elseif yieldTo == y_Sleep then
		
		local Time = tonumber( arg ) or 0
		local EndTime = CurTime() + Time
		
		self.YieldingTo = y_Sleep
		self.ResumeTime = EndTime
		
	elseif yieldTo == y_Condition then
		
		self.YieldingTo = y_Condition
		self.ConditionFunction = arg
		self.ConditionArgs = returned
		
	end
		
	
end

local function co_sleep( time )
	coroutine.yield( y_Sleep, time )
end
local function co_yield( condition )
	return coroutine.yield( y_Condition, condition )
end


--[[-------------------------------------------------------------------------
Creates and starts a coroutine for the entity. A reference to the entity
will be passed as an argument to the function call. Arguments can be passed
into the function with extra args
If the entity is removed, a suspended coroutine will not resume

The function passed into ENT:co() will be given access to the following functions
	that can be called globally:

-	sleep( seconds )	Suspends the coroutine for the amount of seconds
-	yield( condition function )	Suspends the coroutine until the given function
		returns a non-nil and non-false value (the function will be given a
		reference to the entity as an argument)
		If the function returns a non-nil and non-false value, the
		yield() call will return all return values from the function

WARNING: DO NOT HAVE NIL VALUES BETWEEN ARGUMENTS IN THE VARARGS!! THE REST OF
	THEM WILL NOT BE PASSED ONTO THE FUNCTION

---------------------------------------------------------------------------]]
function ENT:co( func, ... )

	-- expose some sick functions
	local env = getfenv( func )
	env.sleep = co_sleep
	env.yield = co_yield
	

	local thread = coroutine.create( func )
	local info = {
		
		Coroutine = thread,
		YieldingTo = 0,
		Entity = self
		
		--ConditionFunction
		--ResumeTime
		--Halted
		
	}
	
	META.__index = META
	setmetatable( info, META )
	table.insert( self.Coroutines, info )
	
	info:Think( self, ... ) -- start it off
end
function ENT:CoroutineThink()

	for k, thread in pairs( self.Coroutines ) do
		thread:Think()
	end

end







function ENT:SetupDataTables()
	
	self:NetworkVar( "Float", 0, "TeleportTime" )
	self:NetworkVar( "Entity", 0, "Destination" )
	self:NetworkVar( "Entity", 1, "Frame" )

	for i = 1, 8 do
		self:NetworkVar( "Entity", i+1, "Collider" .. i )
	end

end


--[[-------------------------------------------------------------------------
The reason why there is more than one trigger zone is because the teleport
area on the platform is cylindrical. Not only is there not an ents.FindInCylinder
function, but ents.FindInBox does not support rotation.
Multiple zones fill up the nooks and crannies in this cylinder.
If you want to see what these zones look like, see the commented out code
in ENT:Draw() (cl_init.lua)
---------------------------------------------------------------------------]]

function ENT:GetZone( center, size )

	local min = Vector( size / -2, size / -2, self.ZoneHeight / -2 )
	local max = Vector( size / 2, size / 2, self.ZoneHeight / 2 )

	return {
			center = center,
			min = min,
			max = max
		}

end

function ENT:GetZones()

	local subdivisions = 2
	local zones = {}

	local x = Vector( 1, 0, 0 ) --self:GetForward()
	local y = Vector( 0, 1, 0 ) --self:GetRight()
	local z = self:GetUp()

	local origin = self:LocalToWorld( self.ZoneOrigin )
	local center = origin + self.ZoneHeight * z/2
	local size = self.ZoneSize
	local begin = center - size*x/2 - size*y/2

	local smallSize = self.ZoneSize / subdivisions
	local distance = smallSize

	for ox = 0, subdivisions-1 do
		for oy = 0, subdivisions-1 do

			local zoneCenter = begin
				+ ( smallSize/2 + ox * distance ) * x
				+ ( smallSize/2 + oy * distance ) * y

			table.insert( zones, self:GetZone( zoneCenter, smallSize ) )

		end
	end

	smallSize = smallSize * 0.414175

	for ox = 0, subdivisions do
		for oy = 0, subdivisions do

			// no corners please
			if ox == 0 and oy == 0 or
				ox == 0 and oy == subdivisions or
				ox == subdivisions and oy == 0 or
				ox == subdivisions and oy == subdivisions then
				continue
			end

			local zoneCenter = begin
				+ ( ox * distance ) * x
				+ ( oy * distance ) * y

			table.insert( zones, self:GetZone( zoneCenter, smallSize ) )

		end
	end

	return zones


end

function ENT:GetEntsInZone()

	local list = {}
	for k, zone in pairs( self:GetZones() ) do

		local found = ents.FindInBox( zone.center + zone.min, zone.center + zone.max )
		merge( list, found )

	end

	return list

end

function ENT:IsVectorInZone( vec )

	for k, zone in pairs( self:GetZones() ) do

		if vec:WithinAABox( zone.center + zone.min, zone.center + zone.max ) then
			return true
		end

	end
	return false

end
