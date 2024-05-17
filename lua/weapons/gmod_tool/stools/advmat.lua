AddCSLuaFile()

TOOL.Category = "Render"
TOOL.Name = "Advanced Material"
TOOL.ClientConVar["texture"] = ""
TOOL.ClientConVar["noisesetting"] = "concrete"
TOOL.ClientConVar["stepoverride"] = "auto"
TOOL.ClientConVar["scalex"] = "1"
TOOL.ClientConVar["scaley"] = "1"
TOOL.ClientConVar["offsetx"] = "0"
TOOL.ClientConVar["offsety"] = "0"
TOOL.ClientConVar["roffset"] = "0"
TOOL.ClientConVar["usebump"] = "1"
TOOL.ClientConVar["usenoise"] = "0"
TOOL.ClientConVar["noisescalex"] = "1"
TOOL.ClientConVar["noisescaley"] = "1"
TOOL.ClientConVar["noiseoffsetx"] = "0"
TOOL.ClientConVar["noiseoffsety"] = "0"
TOOL.ClientConVar["noiseroffset"] = "0"
TOOL.ClientConVar["alphatype"] = "0"

TOOL.PreviewMats = {}

TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" }
}

/*
	MATERIALIZE
*/

local canAdvmatPlayers = CreateConVar( "advmat_canmaterializeplayers", "1", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Can admins change the Advanced Material of players?", 0, 1 )

-- admins can advmat players
function TOOL:LegalMaterialize( trace )
	if trace.Entity:IsPlayer() then
		if self:GetOwner():IsAdmin() and canAdvmatPlayers:GetBool() then return true end
		return nil
	end

	return true
end


function TOOL:LeftClick( trace )
	if not IsValid( trace.Entity ) then return false end
	if not self:LegalMaterialize( trace ) then return false end
	if CLIENT then return true end

	local texture = self:GetClientInfo( "texture" )
	local scalex = tonumber( self:GetClientInfo( "scalex" ) )
	local scaley = tonumber( self:GetClientInfo( "scaley" ) )
	local offsetx = tonumber( self:GetClientInfo( "offsetx" ) )
	local offsety = tonumber( self:GetClientInfo( "offsety" ) )
	local roffset = tonumber( self:GetClientInfo( "roffset" ) )
	local usebump = tonumber( self:GetClientInfo( "usebump" ) )
	local usenoise = tonumber( self:GetClientInfo( "usenoise" ) )
	local noisesetting = self:GetClientInfo( "noisesetting" ) or "concrete"
	local stepoverride = self:GetClientInfo( "stepoverride" ) or "auto"
	local noisescalex = tonumber( self:GetClientInfo( "noisescalex" ) )
	local noisescaley = tonumber( self:GetClientInfo( "noisescaley" ) )
	local noiseoffsetx = tonumber( self:GetClientInfo( "noiseoffsetx" ) )
	local noiseoffsety = tonumber( self:GetClientInfo( "noiseoffsety" ) )
	local noiseroffset = tonumber( self:GetClientInfo( "noiseroffset" ) )
	local alphatype = tonumber( self:GetClientInfo( "alphatype" ) )

	advMat_Table:Set(
		trace.Entity,
		string.Trim( texture ):lower(),
		{
			ScaleX = scalex,
			ScaleY = scaley,
			OffsetX = offsetx,
			OffsetY = offsety,
			ROffset = roffset,
			UseBump = usebump,
			UseNoise = usenoise,
			NoiseSetting = noisesetting,
			StepOverride = stepoverride,
			NoiseScaleX = noisescalex,
			NoiseScaleY = noisescaley,
			NoiseOffsetX = noiseoffsetx,
			NoiseOffsetY = noiseoffsety,
			NoiseROffset = noiseroffset,
			AlphaType = alphatype,
		}
	)

	return true
end

local function isValidMaterial( matStr )
	if not matStr then return end
	if matStr[1] == "*" then return end -- **DISPLACEMENT**, **STUDIO**, etc
	if matStr == "" then return end

	return true
end

function TOOL:GetEntsMaterial( ent )
	local entsOverrideMat = ent:GetMaterial()
	if isValidMaterial( entsOverrideMat ) then return entsOverrideMat end

	local entsBaseMats = ent:GetMaterials()
	local primaryMat = entsBaseMats[1]

	if isValidMaterial( primaryMat ) then return primaryMat end
end

-- copy mats
function TOOL:RightClick( trace )
	if not self:LegalMaterialize( trace ) then return false end
	if CLIENT then return true end

	local matData = nil
	local validAdvMat = nil
	if IsValid( trace.Entity ) then
		matData = trace.Entity.MaterialData
		validAdvMat = matData and isValidMaterial( matData.texture )
	end

	local matString = ""

	-- building a new material
	if not validAdvMat then
		if IsValid( trace.Entity ) then
			matString = self:GetEntsMaterial( trace.Entity )
		elseif isValidMaterial( trace.HitTexture ) then
			matString = trace.HitTexture
		end
	else
		matString = matData.texture
	end

	if not isValidMaterial( matString ) then return false end -- displacement or smth

	local data = nil

	-- copy existing advmat
	if matData then
		local untranslatedNoise = matData.NoiseSetting
		data = matData

		-- translate the raw texture into what the commands expect, eg 'metal', 'concrete'
		for setting, translation in pairs( advMat_Table.DetailTranslations ) do
			if translation == untranslatedNoise then
				data.noisesetting = setting
				break
			end
		end
	-- build advmat data from scratch
	elseif isValidMaterial( matString ) then
		local tempMat = Material( matString )
		local usenoise = 0
		local noiseTexturePath = tempMat:GetString( "$detail" )
		local noiseSetting

		for setting, translation in pairs( advMat_Table.DetailTranslations ) do
			if translation == noiseTexturePath then
				noiseSetting = setting
				usenoise = 1
				break
			end
		end

		local hasBump = isstring( tempMat:GetString( "$bumpmap" ) ) and not tempMat:GetTexture( "$bumpmap" ):IsErrorTexture()

		data = {
			texture = matString,
			scalex = 1,
			scaley = 1,
			offsetx = 0,
			offsety = 0,
			roffset = 0,
			usebump = hasBump,
			usenoise = usenoise,
			noisesetting = noiseSetting,
			stepoverride = "auto",
		}
	else
		return false
	end

	for index, var in pairs( data ) do
		if isbool( var ) then continue end

		self:GetOwner():ConCommand( "advmat_" .. index:lower() .. " " .. var )
	end

	return true
end

function TOOL:Reload( trace )
	if not IsValid( trace.Entity ) then return false end
	if CLIENT then return true end

	advMat_Table:Set( trace.Entity, nil, {} )

	return true
end

function TOOL:PreviewMatShader()
	local shaderName = "VertexLitGeneric"

	return shaderName
end

function TOOL:GetPreviewMat( shaderName, usenoise, alphatype, usebump )
	usenoise = usenoise or self:GetClientNumber( "usenoise" )
	alphatype = alphatype or self:GetClientNumber( "alphatype" )
	usebump = usebump or self:GetClientNumber( "usebump" )

	local matName = shaderName or self:PreviewMatShader()
	matName = "AdvMatPreview" .. matName
	if usenoise > 0 then
		matName = matName .. "Noise"
	end
	if usebump > 0 then
		matName = matName .. "Bumpmap"
	end
	matName = matName .. "Alpha" .. tostring( alphatype )

	return self.PreviewMats[matName], matName
end

local alphaTypes = {
	[1] = "$alphatest",
	[2] = "$vertexalpha",
	[3] = "$translucent"
}

local translatorCache = {}

function TOOL:Think()
	if CLIENT then
		local texture = self:GetClientInfo( "texture" )
		if texture == "" then
			return
		end

		local scalex = self:GetClientNumber( "scalex", 1 )
		local scaley = self:GetClientNumber( "scaley", 1 )
		local offsetx = self:GetClientNumber( "offsetx" )
		local offsety = self:GetClientNumber( "offsety" )
		local roffset = self:GetClientNumber( "roffset" )

		local usebump = self:GetClientNumber( "usebump" )
		local usenoise = self:GetClientNumber( "usenoise" )
		local noisesetting = self:GetClientInfo( "noisesetting" )
		local noisescalex = self:GetClientNumber( "noisescalex", 1 )
		local noisescaley = self:GetClientNumber( "noisescaley", 1 )
		local noiseoffsetx = self:GetClientNumber( "noiseoffsetx", 0 )
		local noiseoffsety = self:GetClientNumber( "noiseoffsety", 0 )
		local noiseroffset = self:GetClientNumber( "noiseroffset" )

		local alphatype = tonumber( self:GetClientInfo( "alphatype" ) )

		local shaderName = self:PreviewMatShader()

		local mat, matName = self:GetPreviewMat( shaderName, usenoise, alphatype, usebump )
		if not mat then
			local previewMatTable = {}

			previewMatTable["$basetexture"] = texture
			previewMatTable["$basetexturetransform"] = "center .5 .5 scale " .. ( 1 / noisescalex ) .. " " .. ( 1 / noisescaley ) .. " rotate " .. roffset .. " translate " .. noiseoffsetx .. " " .. noiseoffsety
			previewMatTable["$vertexcolor"] = 1

			if alphatype > 0 then
				previewMatTable[alphaTypes[alphatype]] = 1
			end

			mat = CreateMaterial( matName, shaderName, previewMatTable )
			self.PreviewMats[matName] = mat
		end


		local iMat = translatorCache[texture]
		-- only try to fill the cache once
		if not iMat and not translatorCache[texture] then
			iMat = Material( texture )
			translatorCache[texture] = iMat or true
		end

		if not iMat then return end


		local baseTex = iMat:GetTexture( "$basetexture" )
		local baseTexName = baseTex:GetName()

		if mat:GetString( "$basetexture" ) ~= baseTexName and baseTex then
			mat:SetTexture( "$basetexture", baseTex )

			local bumpTex = iMat:GetTexture( "$bumpmap" )
			if usebump > 0 and not bumpTex:IsErrorTexture() then
				mat:SetTexture( "$bumpmap", bumpTex )
			elseif mat:GetString( "$bumpmap" ) then
				mat:SetUndefined( "$bumpmap" )
				mat:Recompute()
			end
		end


		local baseTexMatrix = Matrix()
		baseTexMatrix:Scale( Vector( 1 / scalex, 1 / scaley, 1 ) )
		baseTexMatrix:Translate( Vector( offsetx, offsety, 0 ) )
		baseTexMatrix:Rotate( Angle( 0, roffset, 0 ) )
		mat:SetMatrix( "$basetexturetransform", baseTexMatrix )
		mat:SetMatrix( "$bumptransform", baseTexMatrix )

		if usenoise > 0 then
			local desiredDetail = advMat_Table.DetailTranslations[ noisesetting ]
			local currentDetail = mat:GetString( "$detail" )

			if currentDetail ~= desiredDetail then
				mat:SetTexture( "$detail", desiredDetail )
			end

			local noiseMatrix = Matrix()
			noiseMatrix:Scale( Vector( 1 / noisescalex, 1 / noisescaley, 1 ) )
			noiseMatrix:Translate( Vector( noiseoffsetx, noiseoffsety, 0 ) )
			noiseMatrix:Rotate( Angle( 0, noiseroffset, 0 ) )

			mat:SetMatrix( "$detailtexturetransform", noiseMatrix )

		elseif currentDetail then
			mat:SetUndefined( "$detail" )
			mat:SetUndefined( "$detailtexturetransform" )
		end
	end
end

if CLIENT then
	function TOOL:DrawHUD()
	end

	hook.Add( "PostDrawTranslucentRenderables", "AdvMatPreview", function()
		local player = LocalPlayer()

		if not IsValid( player ) then return end

		local activeWep = player:GetActiveWeapon()

		if not IsValid( activeWep ) or player:GetActiveWeapon():GetClass() ~= "gmod_tool" then return end

		local toolObj = player:GetTool()

		if not toolObj then return end
		if toolObj.Name ~= "Advanced Material" then return end

		local eyeTr = player:GetEyeTrace()

		if not toolObj:LegalMaterialize( eyeTr ) then return end

		local ent = eyeTr.Entity

		if not IsValid( ent ) then return end
		local mat = toolObj:GetPreviewMat()

		if not mat then return end

		-- according to DrawModel on wiki this will fix a crash
		if ent:IsEffectActive( EF_BONEMERGE ) then return end
		if ent:IsEffectActive( EF_NODRAW ) then return end

		render.MaterialOverride( mat )
			ent:DrawModel()
		render.MaterialOverride()

		-- stops entity drawing next tick, allowing for transparency to actually be previewed
		if toolObj:GetClientNumber( "alphatype" ) <= 0 then return end
		if ent.RenderOverride then return end

		ent.RenderOverride = function( self )
			self.RenderOverride = nil
			return
		end
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
		CPanel:AddControl( "ComboBox", {
			Label = "#Presets",
			MenuButton = 1,
			Folder = "advmat_reborn",
			Options = {},
			CVars = {
				[0] = "advmat_texture",
				[1] = "advmat_scalex",
				[2] = "advmat_scaley",
				[3] = "advmat_offsetx",
				[4] = "advmat_offsety",
				[5] = "advmat_roffset",
				[6] = "advmat_usenoise",
				[7] = "advmat_noisescalex",
				[8] = "advmat_noisescaley",
				[9] = "advmat_noiseoffsetx",
				[10] = "advmat_noiseoffsety",
				[11] = "advmat_noiseroffset",
				[12] = "advmat_alphatype",
				[13] = "advmat_stepoverride",
			}
		} )

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

		CPanel:CheckBox( "#tool.advmat.usebump", "advmat_usebump" )
		CPanel:ControlHelp( "#tool.advmat.usebump.helptext" )

		CPanel:CheckBox( "#tool.advmat.usenoise", "advmat_usenoise" )
		CPanel:ControlHelp( "#tool.advmat.usenoise.helptext" )

		CPanel:AddControl( "ComboBox", {
			Label = "#tool.advmat.noisesetting",
			Options = list.Get( "tool.advmat.details" )
		} )

		CPanel:NumSlider( "#tool.advmat.scalex", "advmat_noisescalex", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.scaley", "advmat_noisescaley", 0.01, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsetx", "advmat_noiseoffsetx", 0, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.offsety", "advmat_noiseoffsety", 0, 8, 2 )
		CPanel:NumSlider( "#tool.advmat.roffset", "advmat_noiseroffset", -180, 180, 2 )

		local noiseReset = CPanel:Button( "#tool.advmat.reset.noise" )

		function noiseReset:DoClick()
			for k, v in pairs( transformData ) do
				LocalPlayer():ConCommand( "advmat_noise" .. k:lower() .. " " .. v )
			end
		end

		CPanel:AddControl( "Label", {
			Text = "#tool.advmat.advancedsettings"
		} )

		CPanel:AddControl( "ComboBox", {
			Label = "#tool.advmat.alphatype",
			Options = list.Get( "tool.advmat.alphatype" )
		} )
		CPanel:ControlHelp( "#tool.advmat.alphatype.helptext" )


		CPanel:AddControl( "ComboBox", {
			Label = "#tool.advmat.stepoverride",
			Options = list.Get( "tool.advmat.stepoverride" )
		} )
		CPanel:ControlHelp( "#tool.advmat.stepoverride.helptext" )

	end
end
/*
	Language strings
*/

if CLIENT then

	local function assembleList( preamble, command, stuff )
		for key, currOverride in pairs( stuff ) do
			local placeholder = preamble .. "." .. key
			local fullText = currOverride.name
			language.Add( placeholder, fullText )

			local listKey = "#" .. preamble .. "." .. key
			list.Set( preamble, listKey, { [command] = key } )

		end
	end

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

	language.Add( "tool.advmat.usebump", "Use bumpmap" )
	language.Add( "tool.advmat.usebump.helptext", "If a texture has a bump/normalmap, use it?" )

	language.Add( "tool.advmat.usenoise", "Use noise texture" )
	language.Add( "tool.advmat.usenoise.helptext", "If this box is checked, your material will be sharpened using an HD detail texture, controlled by the settings below." )

	language.Add( "tool.advmat.reset.base", "Reset Texture Transformations" )
	language.Add( "tool.advmat.reset.noise", "Reset Noise Transformations" )


	language.Add( "tool.advmat.noisesetting", "Detail type" )

	language.Add( "tool.advmat.details.concrete", "Concrete" )
	language.Add( "tool.advmat.details.plaster", "Plaster" )
	language.Add( "tool.advmat.details.metal", "Metal" )
	language.Add( "tool.advmat.details.wood", "Wood" )
	language.Add( "tool.advmat.details.rock", "Rock" )

	list.Set( "tool.advmat.details", "#tool.advmat.details.concrete", { advmat_noisesetting = "concrete" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.plaster", { advmat_noisesetting = "plaster" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.metal", { advmat_noisesetting = "metal" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.wood", { advmat_noisesetting = "wood" } )
	list.Set( "tool.advmat.details", "#tool.advmat.details.rock", { advmat_noisesetting = "rock" } )


	language.Add( "tool.advmat.advancedsettings", "Advanced Settings" )


	language.Add( "tool.advmat.alphatype", "Alpha Type" )

	local alphas = {
		[0] = { name = "None" },
		[1] = { name = "Alphatest" },
		[2] = { name = "Translucent" },
		[3] = { name = "Vertexalpha" },
	}

	assembleList( "tool.advmat.alphatype", "advmat_alphatype", alphas )

	language.Add( "tool.advmat.alphatype.helptext", "Texture-level transparency, for windows, foliage, etc. If unsure, set to None, or AlphaTest." )


	language.Add( "tool.advmat.stepoverride", "Advanced footstep sounds." )

	assembleList( "tool.advmat.stepoverride", "advmat_stepoverride", advMat_Table.stepOverrides )

	language.Add( "tool.advmat.stepoverride.helptext", "Overrides footstep sounds.\nAuto, footstep sounds are estimated from the material's texture, or from the detail texture.\nNone, don't override footstep sounds." )

end