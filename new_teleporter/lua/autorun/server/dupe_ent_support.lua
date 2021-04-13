--[[

	When somebody dupes a contraption, entity references aren't able to be saved.
	This is because each reference is (most likely) the entity index, instead of the entity itself.
	Then, when the contraption is pasted, everything has a different ent index, and shit gets fucked.

	To fix this, I made this small library that allows entities to encode ent references into duplications

	Feel free to use this yourself, just be sure to leave my name in it!

]]

-- mitterdoo

entlookup = entlookup or {}

local function saveEntity( ent )

	if not IsValid( ent ) then return end
	local idx = ent:EntIndex()
	if idx == 0 and ent ~= game.GetWorld() then return end -- can't do anything with weird ents like this
	return idx

end

-- From Wiremod's base_wire_entity.lua
local function getLookupFunction(CreatedEntities)
	return function(id, default)
		if id == nil then return default end
		if id == 0 then return game.GetWorld() end
		local ent = CreatedEntities[id]-- or (isnumber(id) and ents.GetByIndex(id))
		if IsValid(ent) then return ent else return default end
	end
end



-- This should be called in ENT:PreEntityCopy()
function entlookup.ApplyToDupe( ent )

	if not IsValid( ent ) then return end
	local data = {
		Table = {},
		DT = {}
	}

	-- First, store all of the entities we can find on the entity
	-- NOTE: This does not scan tables recursively. Any entity references nested inside of a table variable stored on "ent" will not work.

	local tab = ent:GetTable()
	for key, value in pairs( tab ) do
		if type( value ) == "Entity" and key ~= "Entity" then
			data.Table[ key ] = saveEntity( value )
		end
	end

	-- Next, try to store the network vars

	if ent.GetNetworkVars then
		--[[
			garry didn't want to break dupes, so he decided to filter out entities in :GetNetworkVars()
			unfortunately, that function is the only easy way to access the network vars of an entity
			so now, we have to find them the ugly way
		]]
		local varname, datatable = debug.getupvalue( ent.GetNetworkVars, 1 )
		if varname == "datatable" and type( datatable ) == "table" then -- just in case

			for name, dt in pairs( datatable ) do
				if dt.typename == "Entity" then
					data.DT[ name ] = saveEntity( dt.GetFunc( ent, dt.index ) )
				end
			end

		end

	end

	duplicator.StoreEntityModifier( ent, "DuplicatorEntitySupport", data )

end

-- This should be called in ENT:PostEntityPaste( ply, ent, createdEntities )
function entlookup.ApplyToPaste( ent, createdEntities )

	local lookup = getLookupFunction( createdEntities )
	if ent.EntityMods and ent.EntityMods.DuplicatorEntitySupport then

		local data = ent.EntityMods.DuplicatorEntitySupport
		for key, idx in pairs( data.Table ) do

			if ent[ key ] == nil then -- this SHOULD be nil because this key had an entity, and it didn't get carried over. if it isn't nil, some sketchy shit is about to happen, so don't let it.
				ent[ key ] = lookup( idx )
			end

		end

		-- :RestoreNetworkVars() doesn't do any checks with Entity types, so we don't have to do a hacky workaround to do this
		if ent.RestoreNetworkVars then

			for key, idx in pairs( data.DT ) do

				data.DT[ key ] = lookup( idx )

			end

			ent:RestoreNetworkVars( data.DT )

		end


	end

end

duplicator.RegisterEntityModifier( "DuplicatorEntitySupport", function() end ) -- blank function because RegisterEntityModifier requires one
