if SERVER then
	util.AddNetworkString( "AdvMatMaterialize" )
	util.AddNetworkString( "AdvMatDematerialize" )
	util.AddNetworkString( "AdvMatInit" )
	util.AddNetworkString( "AdvMatSync" )
end

local enabledVar = CreateConVar( "advmat_sv_overridefootsteps", "1", { FCVAR_ARCHIVE }, "Enables/disables the advmat clientside footstep sound system." )
SetGlobalBool( "advmat_sv_overridefootsteps", enabledVar:GetBool() )
cvars.AddChangeCallback( "advmat_sv_overridefootsteps", function( _, _, new )
	SetGlobalBool( "advmat_sv_overridefootsteps", tobool( new ) )
end, "advmat_cachebool" )

local IsValid = IsValid

advMat_Table.DetailTranslations = {
	concrete = "detail/noise_detail_01",
	plaster = "detail/plaster_detail_01",
	metal = "detail/metal_detail_01",
	wood = "detail/wood_detail_01",
	rock = "detail/rock_detail_01",
}

-- cache of built "UID"s so mats with the same stuff don't build twice 
advMat_Table.stored = advMat_Table.stored or {}

function advMat_Table:ResetAdvMaterial( ent )
	if ent.MaterialData then
		ent.MaterialData = nil
	end

	if SERVER then
		duplicator.ClearEntityModifier( ent, "material" )
		duplicator.ClearEntityModifier( ent, "MaterialData" )
	end

	ent:SetMaterial( "" )
end

function advMat_Table:ValidateAdvmatData( data )
	local useNoise = data.UseNoise
	if isbool( useNoise ) then
		if useNoise then
			useNoise = 1
		else
			useNoise = 0
		end
	end

	local noiseSetting = data.NoiseSetting
	local oldTexture = data.NoiseTexture
	if oldTexture then
		for setting, translation in pairs( advMat_Table.DetailTranslations ) do
			if translation == oldTexture then
				noiseSetting = setting
				break
			end
		end
	end

	local dataValid = {
		texture = data.texture:lower() or "",
		ScaleX = data.ScaleX or 1,
		ScaleY = data.ScaleY or 1,
		OffsetX = data.OffsetX or 0,
		OffsetY = data.OffsetY or 0,
		ROffset = data.ROffset or data.Rotate or 0, -- data.Rotate, catch advmat 2 rotation
		UseBump = data.UseBump or 1,
		UseNoise = useNoise or 0,
		NoiseSetting = noiseSetting or "",
		StepOverride = data.StepOverride or "auto",
		NoiseScaleX = data.NoiseScaleX or 1,
		NoiseScaleY = data.NoiseScaleY or 1,
		NoiseOffsetX = data.NoiseOffsetX or 0,
		NoiseOffsetY = data.NoiseOffsetY or 0,
		NoiseROffset = data.NoiseROffset or 0,
		AlphaType = data.AlphaType or 0,
	}
	return dataValid

end

function advMat_Table:GetMaterialPathId( data )
	local dataValid = self:ValidateAdvmatData( data )

	local texture = string.Trim( dataValid.texture )
	local uid = texture .. "+" .. dataValid.ScaleX .. "+" .. dataValid.ScaleY .. "+" .. dataValid.OffsetX .. "+" .. dataValid.OffsetY .. "+" .. dataValid.ROffset .. "+" .. dataValid.AlphaType

	if dataValid.UseNoise > 0 then
		uid = uid .. "+" .. dataValid.NoiseSetting .. "+" .. dataValid.NoiseScaleX .. "+" .. dataValid.NoiseScaleY .. "+" .. dataValid.NoiseOffsetX .. "+" .. dataValid.NoiseOffsetY .. "+" .. dataValid.NoiseROffset
	end

	if dataValid.UseBump > 0 then
		uid = uid .. "+" .. dataValid.UseBump
	end

	uid = uid:gsub( "%.", "-" )

	return uid, dataValid
end

function advMat_Table:GetStored()
	return self.stored
end

-- indexes are 1 2 3 to catch advmat 2'ed props.
local alphaTypes = {
	[1] = "$alphatest",
	[2] = "$vertexalpha",
	[3] = "$translucent"
}

function advMat_Table:Set( ent, texture, data )
	if not IsValid( ent ) then return end
	data.texture = texture

	if SERVER then
		self:ResetAdvMaterial( ent )
		ent:SetNW2String( "AdvMaterialCRC", util.CRC( tostring( {} ) ) )

		if data.texture == nil or data.texture == "" then
			return
		end

		local uid, dataValid = self:GetMaterialPathId( data )
		ent.MaterialData = dataValid
		duplicator.StoreEntityModifier( ent, "MaterialData", ent.MaterialData )
		duplicator.ClearEntityModifier( ent, "material" )

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
				["$vertexcolor"] = 1
			}

			local iTexture = tempMat:GetTexture( "$basetexture" )
			if not iTexture then return end

			if dataV.AlphaType > 0 then
				matTable[alphaTypes[data.AlphaType]] = 1
			end

			for index, currData in pairs( dataV ) do
				if ( index:sub( 1, 1 ) == "$" ) then
					matTable[k] = currData
				end
			end

			if dataV.UseNoise > 0 and advMat_Table.DetailTranslations[dataV.NoiseSetting] then
				matTable["$detail"] = advMat_Table.DetailTranslations[dataV.NoiseSetting]
			end

			local matrix = Matrix()
			matrix:Scale( Vector( 1 / dataV.ScaleX, 1 / dataV.ScaleY, 1 ) )
			matrix:Translate( Vector( dataV.OffsetX, dataV.OffsetY, 0 ) )
			matrix:Rotate( Angle( 0, dataV.ROffset, 0 ) )

			local noiseMatrix = Matrix()
			noiseMatrix:Scale( Vector( 1 / dataV.NoiseScaleX, 1 / dataV.NoiseScaleY, 1 ) )
			noiseMatrix:Translate( Vector( dataV.NoiseOffsetX, dataV.NoiseOffsetY, 0 ) )
			noiseMatrix:Rotate( Angle( 0, dataV.NoiseROffset, 0 ) )

			self.stored[uid] = CreateMaterial( uid, "VertexLitGeneric", matTable )
			self.stored[uid]:SetTexture( "$basetexture", iTexture )
			self.stored[uid]:SetMatrix( "$basetexturetransform", matrix )
			self.stored[uid]:SetMatrix( "$detailtexturetransform", noiseMatrix )

			local bumpTex = tempMat:GetTexture( "$bumpmap" )
			if bumpTex and dataV.UseBump > 0 then
				self.stored[uid]:SetTexture( "$bumpmap", bumpTex )
				self.stored[uid]:SetMatrix( "$bumptransform", matrix )
			else
				self.stored[uid]:SetUndefined( "$bumpmap" )
			end
		end

		ent.MaterialData = dataV

		ent:SetMaterial( "!" .. uid )
	end
end

local requestQueueBatchSize = 50

if CLIENT then
	local function readDecimal()
		return net.ReadUInt( 16 ) / 100
	end

	net.Receive( "AdvMatMaterialize", function()
		local ent = net.ReadEntity()
		if not IsValid( ent ) then return end

		local texture = net.ReadString()
		local data = {
			texture = texture,
			AlphaType = net.ReadUInt( 3 ),
			NoiseOffsetX = readDecimal(),
			NoiseOffsetY = readDecimal(),
			NoiseROffset = readDecimal(),
			NoiseScaleX = readDecimal(),
			NoiseScaleY = readDecimal(),
			NoiseSetting = net.ReadString(),
			OffsetX = readDecimal(),
			OffsetY = readDecimal(),
			ROffset = readDecimal(),
			ScaleX = readDecimal(),
			ScaleY = readDecimal(),
			StepOverride = net.ReadString(),
			UseBump = net.ReadBool() and 1 or 0,
			UseNoise = net.ReadBool() and 1 or 0,
		}

		advMat_Table:Set( ent, texture, data )
	end )

	net.Receive( "AdvMatDematerialize", function()
		local ent = net.ReadEntity()
		if not IsValid( ent ) then return end
		advMat_Table:ResetAdvMaterial( ent )
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
		if name ~= "AdvMaterialCRC" then return end
		if old == new then return end

		table.insert( requestQueue, ent )

		if #requestQueue >= requestQueueBatchSize then
			sendRequestQueue()
			return
		end

		timer.Create( "AdvMatSyncTimer", 0.05, 1, sendRequestQueue )
	end )
else
	local function writeDecimal( num )
		local mult = math.floor( num * 100 )
		net.WriteUInt( mult, 16 )
	end

	function advMat_Table:Sync( ent, ply )
		local data = ent.MaterialData

		if data then
			net.Start( "AdvMatMaterialize" )
			net.WriteEntity( ent )
			net.WriteString( data.texture )
			net.WriteUInt( data.AlphaType, 3 )
			writeDecimal( data.NoiseOffsetX )
			writeDecimal( data.NoiseOffsetY )
			writeDecimal( data.NoiseROffset )
			writeDecimal( data.NoiseScaleX )
			writeDecimal( data.NoiseScaleY )
			net.WriteString( data.NoiseSetting )
			writeDecimal( data.OffsetX )
			writeDecimal( data.OffsetY )
			writeDecimal( data.ROffset )
			writeDecimal( data.ScaleX )
			writeDecimal( data.ScaleY )
			net.WriteString( data.StepOverride )
			net.WriteBool( data.UseBump > 0 )
			net.WriteBool( data.UseNoise > 0 )
			net.Send( ply )
		else
			net.Start( "AdvMatDematerialize" )
			net.WriteEntity( ent )
			net.Send( ply )
		end
	end

	local syncTable = {}
	local sendCount = 0
	local wait = 0

	local function runSync()
		if table.IsEmpty( syncTable ) then
			timer.Remove( "AdvMatSyncTimer" )
			return
		end

		if wait > CurTime() then return end

		for ply, entTable in pairs( syncTable ) do
			if IsValid( ply ) and not table.IsEmpty( entTable ) then
				for i, ent in pairs( entTable ) do
					if IsValid( ent ) then
						advMat_Table:Sync( ent, ply )
						sendCount = sendCount + 1
					end

					if sendCount >= requestQueueBatchSize then
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

		for _ = 1, requestQueueBatchSize do
			if not net.ReadBit() then break end
			table.insert( requestQueue, net.ReadEntity() )
		end

		for _, ent in ipairs( requestQueue ) do
			if IsValid( ent ) then
				syncTable[ply] = syncTable[ply] or {}
				table.insert( syncTable[ply], ent )

				createSyncTimer()
			end
		end
	end )

	hook.Add( "LoadGModSave", "advmat_reborn_waitaftersaveload", function() -- even less chance of client 0 overload reliable buffer
		wait = CurTime() + 1

	end )

end

duplicator.RegisterEntityModifier( "MaterialData", function( _, entity, data )
	advMat_Table:Set( entity, data.texture, data )
end )
