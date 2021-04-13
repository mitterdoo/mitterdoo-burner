--[[

	ENT:PostEntityPaste is called after a *single* entity is created.
	Currently, there is no hook that is called when a duplication has finished pasting.

	Advanced Duplicator 2 already has a hook for this, but vanilla duplicator doesn't.
	This fixes that.

]]
-- mitterdoo


if duplicator then

	local duplicator_Paste = duplicator.Paste

	-- This creates a new hook on entities:
	-- ENT:OnPasteComplete( Player, Ent, CreatedEntities )
	-- It's the same as ENT:PostEntityPaste(), but called after the dupe is finished instead

	function duplicator.Paste( Player, EntityList, ConstraintList )

		local CreatedEntities, CreatedConstraints = duplicator_Paste( Player, EntityList, ConstraintList )

		for k, ent in pairs( CreatedEntities ) do

			if ent.OnPasteComplete then
				ent:OnPasteComplete( Player, ent, CreatedEntities )
			end

		end
		return CreatedEntities, CreatedConstraints

	end

end

hook.Add( "AdvDupe_FinishPasting", "OnPasteComplete", function( TimedPasteData, TimedPasteDataCurrent )

	local CreatedEntities = TimedPasteData[TimedPasteDataCurrent].CreatedEntities
	if CreatedEntities then

		for k, ent in pairs( CreatedEntities ) do

			if ent.OnPasteComplete then
				ent:OnPasteComplete( Player, ent, CreatedEntities )
			end

		end

	end

end )
