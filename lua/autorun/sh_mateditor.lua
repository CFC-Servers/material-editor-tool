if SERVER then
	util.AddNetworkString( "Materialize" )
	util.AddNetworkString( "AdvMatInit" )
	util.AddNetworkString( "AdvMatSync" )
end

advMat_Table = advMat_Table or {}

-- cache of built "UID"s so mats with the same stuff don't build twice 
advMat_Table.stored = advMat_Table.stored or {}

function advMat_Table:ResetAdvMaterial( ent )
	if ent.MaterialData then
		ent.MaterialData = nil

	end

	ent:SetMaterial( "" )

end

function advMat_Table:ValidateAdvmatData( data )
	local dataValid = {
		texture = data.texture:lower() or "",
		ScaleX = data.ScaleX or 1,
		ScaleY = data.ScaleY or 1,
		OffsetX = data.OffsetX or 0,
		OffsetY = data.OffsetY or 0,
		ROffset = data.ROffset or 0,
		UseNoise = data.UseNoise or false,
		NoiseTexture = data.NoiseTexture or "detail/noise_detail_01",
		NoiseScaleX = data.NoiseScaleX or 1,
		NoiseScaleY = data.NoiseScaleY or 1,
		NoiseOffsetX = data.NoiseOffsetX or 0,
		NoiseOffsetY = data.NoiseOffsetY or 0,
	}
	return dataValid

end

function advMat_Table:GetMaterialPathId( data )
	local dataValid = self:ValidateAdvmatData( data )

	local texture = string.Trim( dataValid.texture )
	local uid = texture .. "+" .. dataValid.ScaleX .. "+" .. dataValid.ScaleY .. "+" .. dataValid.OffsetX .. "+" .. data.OffsetY .. "+" .. dataValid.ROffset

	if dataValid.UseNoise then
		uid = uid .. dataValid.NoiseTexture .. "+" .. dataValid.NoiseScaleX .. "+" .. dataValid.NoiseScaleY .. "+" .. dataValid.NoiseOffsetX .. "+" .. dataValid.NoiseOffsetY
	end

	uid = uid:gsub( "%.", "-" )

	return uid, dataValid
end

function advMat_Table:GetStored()
	return self.stored
end

function advMat_Table:Set( ent, texture, data )
	if not IsValid( ent ) then return end
	data.texture = texture

	if SERVER then
		ent:SetNW2String( "MaterialData", util.CRC( tostring( {} ) ) )

		self:ResetAdvMaterial( ent )

		if data.texture == nil or data.texture == "" then
			return

		end

		local uid, dataValid = self:GetMaterialPathId( data )
		ent.MaterialData = dataValid
		duplicator.StoreEntityModifier( ent, "MaterialData", ent.MaterialData )

		timer.Simple( 0, function() -- fix for submaterial tool conflict
			if not IsValid( ent ) then return end
			ent:SetMaterial( "!" .. uid )
		end )
	else
		-- wipe old material
		self:ResetAdvMaterial( ent )

		data = data or {}

		if data.texture == nil or data.texture == "" then
			return
		end

		local uid, dataV = self:GetMaterialPathId( data )

		if not self.stored[uid] then
			local tempMat = Material( dataV.texture )

			local matTable = {
				["$basetexture"] = tempMat:GetName(),
				["$basetexturetransform"] = "center .5 .5 scale " .. ( 1 / dataV.ScaleX ) .. " " .. ( 1 / dataV.ScaleY ) .. " rotate " .. dataV.ROffset .. " translate " .. dataV.OffsetX .. " " .. dataV.OffsetY,
				["$vertexalpha"] = 0,
				["$vertexcolor"] = 1
			}

			local iTexture = tempMat:GetTexture( "$basetexture" )
			if not iTexture then return end

			for index, currData in pairs( dataV ) do
				if ( index:sub( 1, 1 ) == "$" ) then
					matTable[k] = currData
				end
			end

			if ( dataV.UseNoise ) then
				matTable["$detail"] = dataV.NoiseTexture
			end

			if ( file.Exists( "materials/" .. texture .. "_normal.vtf", "GAME" ) ) then
				matTable["$bumpmap"] = texture .. "_normal"
				matTable["$bumptransform"] = "center .5 .5 scale " .. ( 1 / dataV.ScaleX ) .. " " .. ( 1 / dataV.ScaleY ) .. " rotate " .. dataV.ROffset .. " translate " .. dataV.OffsetX .. " " .. dataV.OffsetY
			end

			local matrix = Matrix()
			matrix:Scale( Vector( 1 / dataV.ScaleX, 1 / dataV.ScaleY, 1 ) )
			matrix:Translate( Vector( dataV.OffsetX, dataV.OffsetY, 0 ) )
			matrix:Rotate( Angle( 0, dataV.ROffset, 0 ) )

			local noiseMatrix = Matrix()
			noiseMatrix:Scale( Vector( 1 / dataV.NoiseScaleX, 1 / dataV.NoiseScaleY, 1 ) )
			noiseMatrix:Translate( Vector( dataV.NoiseOffsetX, dataV.NoiseOffsetY, 0 ) )
			noiseMatrix:Rotate( Angle( 0, dataV.ROffset, 0 ) )

			self.stored[uid] = CreateMaterial( uid, "VertexLitGeneric", matTable )
			self.stored[uid]:SetTexture( "$basetexture", iTexture )
			self.stored[uid]:SetMatrix( "$basetexturetransform", matrix )
			self.stored[uid]:SetMatrix( "$detailtexturetransform", noiseMatrix )
		end

		ent.MaterialData = dataV

		ent:SetMaterial( "!" .. uid )
	end
end

if CLIENT then
	net.Receive( "Materialize", function()
		local ent = net.ReadEntity()
		local texture = net.ReadString()
		local data = net.ReadTable()

		if IsValid( ent ) then
			advMat_Table:Set( ent, texture, data )
		end
	end )

	local requestQueue = {}

	local function sendRequestQueue()
		net.Start( "AdvMatSync" )
		for _, netEnt in ipairs( requestQueue ) do
			net.WriteBit( true )
			net.WriteEntity( netEnt )
		end
		net.SendToServer()

		requestQueue = {}
	end

	hook.Add( "EntityNetworkedVarChanged", "AdvMatSync", function( ent, name, old, new )
		if name ~= "MaterialData" then return end
		if old == new then return end

		table.insert( requestQueue, ent )

		if #requestQueue >= 200 then
			sendRequestQueue()
			return
		end

		timer.Create( "AdvMatSyncTimer", 0.05, 1, sendRequestQueue )
	end )
else
	function advMat_Table:Sync( ent, ply )
		local data = ent.MaterialData
		if not data then return end

		net.Start( "Materialize" )
		net.WriteEntity( ent )
		net.WriteString( data.texture )
		net.WriteTable( data )
		net.Send( ply )
	end

	local syncTable = {}
	local sendCount = 0

	local function runSync()
		if table.IsEmpty( syncTable ) then
			timer.Remove( "AdvMatSyncTimer" )
			return
		end

		for ply, entTable in pairs( syncTable ) do
			if IsValid( ply ) then
				for i, ent in pairs( entTable ) do
					if IsValid( ent ) and ent.MaterialData then
						advMat_Table:Sync( ent, ply )
						sendCount = sendCount + 1
					end

					if sendCount >= 200 then
						sendCount = 0
						return
					end

					entTable[i] = nil
				end
			else
				syncTable[ply] = nil
			end
		end
	end

	local function createSyncTimer()
		timer.Create( "AdvMatSyncTimer", 0.1, 0, runSync )
	end

	net.Receive( "AdvMatSync", function( _, ply )
		local requestQueue = {}

		for _ = 1, 200 do
			if not net.ReadBit() then break end
			table.insert( requestQueue, net.ReadEntity() )
		end

		for _, ent in pairs( requestQueue ) do
			if IsValid( ent ) and ent.MaterialData then
				syncTable[ply] = syncTable[ply] or {}
				table.insert( syncTable[ply], ent )

				createSyncTimer()
			end
		end
	end )
end

duplicator.RegisterEntityModifier( "MaterialData", function( _, entity, data )
	advMat_Table:Set( entity, data.texture, data )
end )
