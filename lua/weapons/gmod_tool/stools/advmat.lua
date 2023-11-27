AddCSLuaFile()

TOOL.Category = "Render"
TOOL.Name = "Advanced Material"
TOOL.ClientConVar["texture"] = ""
TOOL.ClientConVar["noisetexture"] = "concrete"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["roffset"] = "0"
TOOL.ClientConVar["usenoise"] = "0"
TOOL.ClientConVar["noisescalex"] = "1"
TOOL.ClientConVar["noisescaley"] = "1"
TOOL.ClientConVar["noiseoffsetx"] = "0"
TOOL.ClientConVar["noiseoffsety"] = "0"
TOOL.ClientConVar["alphatype"] = "0"

TOOL.DetailWhitelist = {
	"concrete",
	"plaster",
	"metal",
	"wood",
	"rock",
}
TOOL.DetailTranslation = {
	concrete = "detail/noise_detail_01",
	plaster = "detail/plaster_detail_01",
	metal = "detail/metal_detail_01",
	wood = "detail/wood_detail_01",
	rock = "detail/rock_detail_01",
}
TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" }
}

/*
	MATERIALIZE
*/

function TOOL:LeftClick( trace )
	if not IsValid( trace.Entity ) then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local texture = self:GetClientInfo( "texture" )
	local scalex = tonumber( self:GetClientInfo( "scalex" ) )
	local scaley = tonumber( self:GetClientInfo( "scaley" ) )
	local offsetx = tonumber( self:GetClientInfo( "offsetx" ) )
	local offsety = tonumber( self:GetClientInfo( "offsety" ) )
	local roffset = tonumber( self:GetClientInfo( "roffset" ) )
	local usenoise = tobool( self:GetClientInfo( "usenoise" ) )
	local noisetexture = self.DetailTranslation[self:GetClientInfo( "noisetexture" )] or "detail/noise_detail_01"
	local noisescalex = tonumber( self:GetClientInfo( "noisescalex" ) )
	local noisescaley = tonumber( self:GetClientInfo( "noisescaley" ) )
	local noiseoffsetx = tonumber( self:GetClientInfo( "noiseoffsetx" ) )
	local noiseoffsety = tonumber( self:GetClientInfo( "noiseoffsety" ) )
	local alphatype = tonumber( self:GetClientInfo( "alphatype" ) )

	advMat_Table:Set( trace.Entity, string.Trim( texture ):lower(), {
		ScaleX = scalex,
		ScaleY = scaley,
		OffsetX = offsetx,
		OffsetY = offsety,
		ROffset = roffset,
		UseNoise = usenoise,
		NoiseTexture = noisetexture,
		NoiseScaleX = noisescalex,
		NoiseScaleY = noisescaley,
		NoiseOffsetX = noiseoffsetx,
		NoiseOffsetY = noiseoffsety,
		AlphaType = alphatype,
	} )

	return true
end

-- copy mats
function TOOL:RightClick( trace )
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local bIsMat = false

	if IsValid( trace.Entity ) and trace.Entity:GetMaterial() ~= "" and trace.Entity:GetMaterial():sub( 1, 1 ) ~= "!" then
		bIsMat = true
	end

	if not bIsMat and trace.HitTexture[1] == "*" and not trace.Entity.MaterialData then
		return false
	end

	local tempMat = Material( trace.HitTexture )
	local hitNoise = tempMat:GetString( "$detail" )
	local noiseTexture = false

	for index, tex in pairs( self.DetailTranslation ) do
		if tex == hitNoise then
			noiseTexture = index
			break
		end
	end

	local data = trace.Entity.MaterialData or {
		texture = bIsMat and trace.Entity:GetMaterial() or trace.HitTexture,
		scalex = 1,
		scaley = 1,
		offsetx = 0,
		offsety = 0,
		roffset = 0,
		usenoise = noiseTexture and 1 or 0,
		noisetexture = noiseTexture
	}

	for index, var in pairs( data ) do
		if isbool( var ) then continue end

		self:GetOwner():ConCommand( "advmat_" .. index:lower() .. " " .. var )
	end

	return true
end

function TOOL:Reload( trace )
	if not IsValid( trace.Entity ) then return false end
	if CLIENT then return true end

	advMat_Table:Set( trace.Entity, "", {} )

	return true
end

function TOOL:Think()
	if CLIENT then
		local texture = self:GetClientInfo( "texture" )
		local scalex = self:GetClientNumber( "scalex", 1 )
		local scaley = self:GetClientNumber( "scaley", 1 )
		local offsetx = self:GetClientNumber( "offsetx" )
		local offsety = self:GetClientNumber( "offsety" )
		local roffset = self:GetClientNumber( "roffset" )

		local bUseNoise = tobool( self:GetClientInfo( "usenoise" ) )
		local noisescalex = self:GetClientNumber( "noisescalex", 1 )
		local noisescaley = self:GetClientNumber( "noisescaley", 1 )
		local noiseoffsetx = self:GetClientNumber( "noiseoffsetx", 0 )
		local noiseoffsety = self:GetClientNumber( "noiseoffsety", 0 )

		if texture == "" then
			return
		end

		if not self.PreviewMat or not self.PreviewNoisedMats then
			self.PreviewMat = CreateMaterial( "AdvMatPreview", "VertexLitGeneric", {
				["$basetexture"] = texture,
				["$basetexturetransform"] = "center .5 .5 scale " .. ( 1 / scalex ) .. " " .. ( 1 / scaley ) .. " rotate " .. roffset .. " translate " .. offsetx .. " " .. offsety,
				["$vertexalpha"] = 0,
				["$vertexcolor"] = 1,
			} )

			local previewNoisedMats = {}

			local previewMatTable = {
				["$basetexture"] = texture,
				["$basetexturetransform"] = "center .5 .5 scale " .. ( 1 / noisescalex ) .. " " .. ( 1 / noisescaley ) .. " rotate " .. roffset .. " translate " .. noiseoffsetx .. " " .. noiseoffsety,
				["$vertexalpha"] = 0,
				["$vertexcolor"] = 1,
				["$detailtexturetransform"] = "center .5 .5 scale 1 1 rotate 0 translate 0 0",
				["$detailblendmode"] = 0,
			}

			previewMatTable["$detail"] = self.DetailTranslation[ "concrete" ]
			previewNoisedMats.concrete = CreateMaterial( "AdvMatPreviewNoiseConcrete", "VertexLitGeneric", previewMatTable )

			previewMatTable["$detail"] = self.DetailTranslation[ "plaster" ]
			previewNoisedMats.plaster = CreateMaterial( "AdvMatPreviewNoisePlaster", "VertexLitGeneric", previewMatTable )

			previewMatTable["$detail"] = self.DetailTranslation[ "metal" ]
			previewNoisedMats.metal = CreateMaterial( "AdvMatPreviewNoiseMetal", "VertexLitGeneric", previewMatTable )

			previewMatTable["$detail"] = self.DetailTranslation[ "wood" ]
			previewNoisedMats.wood = CreateMaterial( "AdvMatPreviewNoiseWood", "VertexLitGeneric", previewMatTable )

			previewMatTable["$detail"] = self.DetailTranslation[ "rock" ]
			previewNoisedMats.rock = CreateMaterial( "AdvMatPreviewNoiseRock", "VertexLitGeneric", previewMatTable )

			self.PreviewNoisedMats = previewNoisedMats

		end

		if bUseNoise then
			local noiseMatrix = Matrix()
			noiseMatrix:Scale( Vector( 1 / noisescalex, 1 / noisescaley, 1 ) )
			noiseMatrix:Translate( Vector( noiseoffsetx, noiseoffsety, 0 ) )
			noiseMatrix:Rotate( Angle( 0, roffset, 0 ) )

			local noiseTexture = self:GetClientInfo( "noisetexture" )

			if not table.HasValue( self.DetailWhitelist, noiseTexture:lower() ) then
				noiseTexture = "concrete"
			end

			self.PreviewNoisedMats[noiseTexture]:SetMatrix( "$detailtexturetransform", noiseMatrix )

			if self.noise ~= self:GetClientInfo( "noisetexture" ) then
				self.noise = noiseTexture

				self.Preview = self.PreviewNoisedMats[noiseTexture]
			end
		end

		local mat = bUseNoise and self.Preview or self.PreviewMat

		local matrix = Matrix()
		matrix:Scale( Vector( 1 / scalex, 1 / scaley, 1 ) )
		matrix:Translate( Vector( offsetx, offsety, 0 ) )
		matrix:Rotate( Angle( 0, roffset, 0 ) )

		if mat:GetString( "$basetexture" ) ~= texture then
			local iMaterial = Material( texture ):GetTexture( "$basetexture" )
			if iMaterial then
				mat:SetTexture( "$basetexture", iMaterial )
			end
		end

		mat:SetMatrix( "$basetexturetransform", matrix )
	end
end

if CLIENT then
	function TOOL:DrawHUD()

	end

	hook.Add( "PostDrawOpaqueRenderables", "AdvMatPreview", function()
		local player = LocalPlayer()

		if not IsValid( player ) then return end

		local activeWep = player:GetActiveWeapon()

		if not IsValid( activeWep ) or player:GetActiveWeapon():GetClass() ~= "gmod_tool" then return end

		local toolObj = player:GetTool()

		if not toolObj then return end
		if toolObj.Name ~= "Advanced Material" then return end

		local ent = player:GetEyeTrace().Entity

		if not IsValid( ent ) then return end
		local mat = tobool( toolObj:GetClientInfo( "usenoise" ) ) and toolObj.Preview or toolObj.PreviewMat

		render.MaterialOverride( mat )
			ent:DrawModel()
		render.MaterialOverride()

	end )
end

/*
	Holster
	Clear stored objects and reset state
*/

function TOOL:Holster()
	self:ClearObjects()
	self:SetStage( 0 )
	self:ReleaseGhostEntity()
end

/*
	Control Panel
*/
do
	local transformData = {
		scalex = 1,
		scaley = 1,
		offsetx = 0,
		offsety = 0,
		roffset = 0,
	}

	function TOOL.BuildCPanel( CPanel )
		CPanel:AddControl( "Header", {
			Description = "#tool.advmat.desc"
		} )

		CPanel:TextEntry( "#tool.advmat.texture", "advmat_texture" )

		CPanel:NumSlider( "#tool.advmat.scalex", "advmat_scalex", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.scaley", "advmat_scaley", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsetx", "advmat_offsetx", 0, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsety", "advmat_offsety", 0, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.roffset", "advmat_roffset", -180, 180, 2 )

		local baseTextureReset = CPanel:Button( "#tool.advmat.reset.base" )

		function baseTextureReset:DoClick()
			for k, v in pairs( transformData ) do
				LocalPlayer():ConCommand( "advmat_" .. k:lower() .. " " .. v )
			end
		end

		CPanel:CheckBox( "#tool.advmat.usenoise", "advmat_usenoise" )
		CPanel:ControlHelp( "#tool.advmat.usenoise.helptext" )

		CPanel:AddControl( "ComboBox", {
			Label = "#tool.advmat.noisetexture",
			Options = list.Get( "tool.advmat.details" )
		} )

		CPanel:NumSlider( "#tool.advmat.scalex", "advmat_noisescalex", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.scaley", "advmat_noisescaley", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsetx", "advmat_noiseoffsetx", 0, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsety", "advmat_noiseoffsety", 0, 8, 2 )

		local noiseTextureReset = CPanel:Button( "#tool.advmat.reset.noise" )

		function noiseTextureReset:DoClick()
			for k, v in pairs( transformData ) do
				LocalPlayer():ConCommand( "advmat_noise" .. k:lower() .. " " .. v )
			end
		end

		local alphabox = CPanel:ComboBox( "#tool.advmat.alphatype", "advmat_alphatype" )
		alphabox:AddChoice( "#tool.advmat.alphatype.none", 0 )
		alphabox:AddChoice( "#tool.advmat.alphatype.alphatest", 1 )
		alphabox:AddChoice( "#tool.advmat.alphatype.translucent", 3 )
		CPanel:ControlHelp( "#tool.advmat.alphatype.helptext" )

	end
end
/*
	Language strings
*/

if CLIENT then
	language.Add( "tool.advmat.name", "Advanced Material" )
	language.Add( "tool.advmat.left", "Set material" )
	language.Add( "tool.advmat.right", "Copy material" )
	language.Add( "tool.advmat.reload", "Remove material" )
	language.Add( "tool.advmat.desc", "Use any material on any prop, with the ability to copy materials from the map." )
	language.Add( "tool.advmat.texture", "Material to use" )
	language.Add( "tool.advmat.scalex", "Width Magnification" )
	language.Add( "tool.advmat.scaley", "Height Magnification" )
	language.Add( "tool.advmat.offsetx", "Horizontal Translation" )
	language.Add( "tool.advmat.offsety", "Vertical Translation" )
	language.Add( "tool.advmat.roffset", "Rotation" )

	language.Add( "tool.advmat.usenoise", "Use noise texture" )
	language.Add( "tool.advmat.usenoise.helptext", "If this box is checked, your material will be sharpened using an HD detail texture, controlled by the settings below." )

	language.Add( "tool.advmat.noisetexture", "Detail type" )

	language.Add( "tool.advmat.reset.base", "Reset Texture Transformations" )
	language.Add( "tool.advmat.reset.noise", "Reset Noise Transformations" )

	language.Add( "tool.advmat.details.concrete", "Concrete" )
	language.Add( "tool.advmat.details.plaster", "Plaster" )
	language.Add( "tool.advmat.details.metal", "Metal" )
	language.Add( "tool.advmat.details.wood", "Wood" )
	language.Add( "tool.advmat.details.rock", "Rock" )

	language.Add( "tool.advmat.alphatype", "Alpha Type" )
	language.Add( "tool.advmat.alphatype.none", "None" )
	language.Add( "tool.advmat.alphatype.alphatest", "Alphatest" )
	language.Add( "tool.advmat.alphatype.translucent", "Translucent" )
	language.Add( "tool.advmat.alphatype.helptext", "Texture-level transparency, for windows, foliage, etc. If unsure, set to None, or AlphaTest." )

	list.Set( "tool.advmat.details", "#tool.advmat.details.concrete", { advmat_noisetexture = "concrete" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.plaster", { advmat_noisetexture = "plaster" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.metal", { advmat_noisetexture = "metal" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.wood", { advmat_noisetexture = "wood" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.rock", { advmat_noisetexture = "rock" } )
end