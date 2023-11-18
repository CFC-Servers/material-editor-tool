if SERVER then
	util.AddNetworkString( "Materialize" )
	util.AddNetworkString( "AdvMatInit" )
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

function advMat_Table:Set( ent, texture, data, filter )
	if not IsValid( ent ) then return end
	data.texture = texture

	if SERVER then
		local entsPos = ent:GetPos()
		net.Start( "Materialize" )
		net.WriteEntity( ent )
		net.WriteString( data.texture )
		net.WriteTable( data )

		if filter then
			net.Send( filter )
		else
			if not util.IsInWorld( entsPos ) then
				net.Broadcast()

			else
				net.SendPVS( entsPos )

			end
		end

		self:ResetAdvMaterial( ent )

		if data.texture == nil or data.texture == "" then
			return

		end

		local uid, dataValid = self:GetMaterialPathId( data )
		ent.MaterialData = dataValid

		ent:SetMaterial( "!" .. uid )

		duplicator.StoreEntityModifier( ent, "MaterialData", ent.MaterialData )
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
else
	local function SyncAdvmats()
		local progress = 0
		for _, ent in pairs( ents.GetAll() ) do
			if IsValid( ent ) and ent.MaterialData then
				coroutine.yield( progress )
				progress = progress + 1
				advMat_Table:Set( ent, ent.MaterialData.texture, ent.MaterialData )

			end
		end
	end

	local advmatSync_coroutine
	local maxSendsPerTick = 25 -- config
	local maxDone = 0 -- dynamic, used to determine when to break the below while loop 

	local function MaintainSyncingCoroutine()
		maxDone = maxDone + maxSendsPerTick
		if not advmatSync_coroutine then
			advmatSync_coroutine = coroutine.create( SyncAdvmats )

		elseif advmatSync_coroutine then
			local status = coroutine.status( advmatSync_coroutine )
			if status == "dead" then
				advmatSync_coroutine = nil
				hook.Remove( "Think", "advmat_maintainsyncing_coroutine" )

			else
				local noErrs = true
				local progress = 0
				while noErrs and progress and progress <= maxDone do
					noErrs, progress = coroutine.resume( advmatSync_coroutine )

				end
			end
		end
	end


	timer.Create( "AdvMatSync", 30, 0, function()
		maxDone = 0
		hook.Add( "Think", "advmat_maintainsyncing_coroutine", MaintainSyncingCoroutine )

	end )
end

duplicator.RegisterEntityModifier( "MaterialData", function( _, entity, data )
	advMat_Table:Set( entity, data.texture, data )

end )