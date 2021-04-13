ENT.PrintName		= "Teleporter"

ENT.Type 			= "anim"
ENT.Base 			= "base_anim"
ENT.Spawnable		= true
ENT.AdminSpawnable  = true
ENT.AdminOnly		= true
ENT.Category 		= "Fun + Games"
ENT.Model			= "models/props_lab/teleportframe.mdl"

function ENT:SetupDataTables()
	
	self:NetworkVar( "Entity", 0, "Platform" )

end
