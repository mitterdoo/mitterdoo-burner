local cvar_showDest = CreateClientConVar( "cl_teleporter_destination", "1" )
local cvar_fxEntity = CreateClientConVar( "cl_teleporter_fx_entity", "1" )
local cvar_fxSuck = CreateClientConVar( "cl_teleporter_fx_suck", "1" )
local cvar_screenspace = CreateClientConVar( "cl_teleporter_screenspace", "1" )
local cvar_sprRealistic = CreateClientConVar( "cl_teleporter_spr_realistic", "1" )
local cvar_sprRings = CreateClientConVar( "cl_teleporter_spr_rings", "1" )
local cvar_sprPlatform = CreateClientConVar( "cl_teleporter_spr_platform", "1" )
local cvar_sprFlash = CreateClientConVar( "cl_teleporter_spr_flash", "1" )

local function buildContextPanel( panel )


	panel:AddControl( "Header", {
		Description = "Determine which visual effects should be rendered on Kleiner's Teleporter. Turning off some of these settings may improve framerates."
	})

	panel:AddControl( "CheckBox", {
		Label = "Destination Rendering",
		Command = "cl_teleporter_destination",
	}):SetTooltip( "Shows a view of the teleporter's destination shortly before it teleports its contents.\nThis feature may cause FPS drops, as it renders the entire world from a different perspective." )

	panel:AddControl( "CheckBox", {
		Label = "Per-Entity Teleport Effects",
		Command = "cl_teleporter_fx_entity"
	}):SetTooltip( "The \"warp\" and \"poof\" effects that are rendered on any entity about to be teleported." )

	panel:AddControl( "CheckBox", {
		Label = "Particle Suck Effect",
		Command = "cl_teleporter_fx_suck",
	}):SetTooltip( "\"Sucking\" particles on teleporter." )

	panel:AddControl( "CheckBox", {
		Label = "Screenspace Effects",
		Command = "cl_teleporter_screenspace"
	}):SetTooltip( "\"Warp\" and flash effects drawn on the entire screen when teleporting." )


	panel:AddControl( "CheckBox", {
		Label = "Realistic Sprites",
		Command = "cl_teleporter_spr_realistic"
	}):SetTooltip( "When turned on, each sprite will be rendered in a way to appear more realistic.\nThe calculations that are run for each sprite may impact framerates." )

	panel:AddControl( "CheckBox", {
		Label = "Ring Sprites",
		Command = "cl_teleporter_spr_rings"
	})

	panel:AddControl( "CheckBox", {
		Label = "Platform Sprites",
		Command = "cl_teleporter_spr_platform"
	})

	panel:AddControl( "CheckBox", {
		Label = "Bright Flash",
		Command = "cl_teleporter_spr_flash"
	})

end

hook.Add( "PopulateToolMenu", "teleporter_ctxmenu", function()

	spawnmenu.AddToolMenuOption( "Utilities",
		"Visuals",
		"teleporter_ctxmenu",
		"Kleiner's Teleporter",
		"",
		"",
		buildContextPanel )

end )
