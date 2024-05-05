local string_find = string.find
local math_random = math.random
local istable = istable
local IsValid = IsValid

local entsMeta = FindMetaTable( "Entity" )
local GetGroundEntity = entsMeta.GetGroundEntity


local var = CreateClientConVar( "advmat_cl_overridefootsteps", "1", true, false, "Should player footsteps match the advanced material of the prop they're stepping on?" )
local enabledBool = var:GetBool()
cvars.AddChangeCallback( "advmat_cl_overridefootsteps", function( _, _, new )
    enabledBool = tobool( new )
end, "advmat_cachebool" )

local cachedNames = {}

-- footstep overrides
local stepOverrides = {
    none = nil,
    metal = "SolidMetal.Step",
    metalbox = "Metal_Box.Step",
    vent = "MetalVent.Step",
    grate = "MetalGrate.Step",
    ladder = "Ladder.Step",
    weapon = "weapon.Step",
    grenade = "Grenade.Step",
    chainlink = "ChainLink.Step",

    snow = "Snow.Step",
    dirt = "Dirt.Step",
    sand = "Sand.Step",
    grass = "Grass.Step",
    gravel = "Gravel.Step",

    mud = "Mud.Step",
    slime = "SlipperySlime.Step",

    water = "Water.Step",
    wade = "Wade.Step",

    flesh = "Flesh.Step",
    -- funny one
    fleshsquish = "Flesh_Bloody.ImpactHard",

    concrete = "Concrete.Step",
    tile = "Tile.Step",
    glass = "Glass.Step",
    drywall = "drywall.Step",
    celingtile = "ceiling_tile.Step",
    glassbottle = "GlassBottle.Step",

    rubber = "Rubber.Step",
    cardboard = "Cardboard.Step",
    plasticbox = "Plastic_Box.Step",
    plasticbarrel = "Plastic_Barrel.Step",

    wood = "Wood.Step",
    woodbox = "Wood_Box.Step",
    woodcrate = "Wood_Crate.Step",
    woodpanel = "Wood_Panel.Step",
}

-- backup sounds, using noise textures
local noiseSounds = {
    concrete = "Concrete.Step",
    plaster = "drywall.Step",
    metal = "SolidMetal.Step",
    wood = "Wood_Panel.Step",
    rock = "Concrete.Step",
}

local oldGroundEnt

local function getGroundEntMatData( ply )
    -- this will never work for other players
    -- other players dont have ground ents on client
    -- thankfully if they're on props they don't play step sounds by default, so this mirrors base behaviour
    if ply ~= LocalPlayer() then return end

    local groundEnt = GetGroundEntity( ply )
    local wasGrace

    if not IsValid( groundEnt ) then
        -- jumping.....
        if not oldGroundEnt then return end
        groundEnt = oldGroundEnt
        oldGroundEnt = nil
        wasGrace = true

    end

    local data = groundEnt.MaterialData
    if not data then return end

    if not wasGrace then
        oldGroundEnt = groundEnt

    end

    return data
end

-- more jumping....
hook.Add( "OnPlayerHitGround", "advmat_footsteps", function( ply )
    if not enabledBool then return end
    getGroundEntMatData( ply )

end )

local infLoop

hook.Add( "PlayerFootstep", "advmat_footsteps", function( ply, _, foot, _, volume, _ )
    if not enabledBool then return end
    if not GetGlobalBool( "advmat_sv_overridefootsteps", false ) then return end
    if infLoop then return end

    local data = getGroundEntMatData( ply )
    if not data then return end

    local theSound
    local override = data.StepOverride
    local texture = data.texture

    -- find the sound!
    if override then
        if override == "none" then return end
        if override ~= "auto" then
            theSound = stepOverrides[override]
        end
    end
    if not theSound and data.UseNoise >= 1 and data.NoiseSetting then
        theSound = noiseSounds[ data.NoiseSetting ]

    end
    if not theSound and texture then
        -- found no sound
        if data.NoFallbackFootstepSound then return end
        -- find footstep from the material's texture, then cache it in the ent's MaterialData, this way stepsound is wiped for new materials
        local cachedSound = data.CachedFootstepSound
        if cachedSound then
            theSound = cachedSound
        else
            for needle, currOverride in pairs( stepOverrides ) do
                if string_find( texture, needle ) then
                    theSound = currOverride
                    data.CachedFootstepSound = theSound
                    break

                end
            end
            if not theSound then
                data.NoFallbackFootstepSound = true
            end
        end
    end

    if not theSound then return end


    if string_find( theSound, "Step" ) then
        local footStr = "Left"
        if foot >= 1 then
            footStr = "Right"
        end

        theSound = theSound .. footStr

    end

    -- shenanigans
    -- needed because the alternative, EmitSound(ing) the raw sound property, needed the "change volume" soundflag, which didn't play sounds on some steps, for seemingly no reason
    local realPath = cachedNames[theSound]
    if not realPath then
        realPath = sound.GetProperties( theSound ).sound
        cachedNames[theSound] = realPath
    end

    if istable( realPath ) then
        realPath = realPath[math_random( 1, #realPath )]
    end

    ply:EmitSound( realPath, 65, 100, volume, CHAN_BODY )

    return true
end )