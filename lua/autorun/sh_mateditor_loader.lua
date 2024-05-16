
if SERVER then
	AddCSLuaFile( "mateditor/sh_advmat_footsteps.lua" )
	AddCSLuaFile( "mateditor/sh_mateditor.lua" )
end

advMat_Table = advMat_Table or {}

include( "mateditor/sh_mateditor.lua" )
include( "mateditor/sh_advmat_footsteps.lua" )