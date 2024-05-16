advMat_Table.stepOverrides = {
    none = { "None" },
    auto = { "Auto" },
    metal = { "Metal", "SolidMetal.Step" },
    metalbox = { "Metal Box", "Metal_Box.Step" },
    vent = { "Vent", "MetalVent.Step" },
    grate = { "Grate", "MetalGrate.Step" },
    ladder = { "Ladder", "Ladder.Step" },
    weapon = { "Weapon", "weapon.Step" },
    grenade = { "Grenade", "Grenade.Step" },
    chainlink = { "Chain Link", "ChainLink.Step" },

    snow = { "Snow", "Snow.Step" },
    dirt = { "Dirt", "Dirt.Step" },
    sand = { "Sand", "Sand.Step" },
    grass = { "Grass", "Grass.Step" },
    gravel = { "Gravel", "Gravel.Step" },

    mud = { "Mud", "Mud.Step" },
    slime = { "Slime", "SlipperySlime.Step" },

    water = { "Water", "Water.Step" },
    wade = { "Water ( Wade )", "Wade.Step" },

    flesh = { "Flesh", "Flesh.Step" },
    -- funny one
    fleshsquish = { "Flesh ( Squishy )", "Flesh_Bloody.ImpactHard" },

    concrete = { "Concrete", "Concrete.Step" },
    tile = { "Tile", "Tile.Step" },
    glass = { "Glass", "Glass.Step" },
    drywall = { "Drywall", "drywall.Step" },
    celingtile = { "Ceiling Tile", "ceiling_tile.Step" },
    glassbottle = { "Glass Bottle", "GlassBottle.Step" },

    rubber = { "Rubber", "Rubber.Step" },
    cardboard = { "Cardboard", "Cardboard.Step" },
    plasticbox = { "Plastic Box", "Plastic_Box.Step" },
    plasticbarrel = { "Plastic Barrel", "Plastic_Barrel.Step" },

    wood = { "Wood", "Wood.Step" },
    woodbox = { "Wood Box", "Wood_Box.Step", },
    woodcrate = { "Wood Crate", "Wood_Crate.Step" },
    woodpanel = { "Wood Panel", "Wood_Panel.Step" },

}

-- best code ever written!
-- PlayerFootstep does not exist on client, in singleplayer!
local singlePlayer = game.SinglePlayer()

if singlePlayer then
    if not SERVER then return end
else
    if not CLIENT then return end
end

local string_find = string.find
local math_random = math.random
local istable = istable
local IsValid = IsValid

local entsMeta = FindMetaTable( "Entity" )
local GetGroundEntity = entsMeta.GetGroundEntity
local GetGlobalBool = GetGlobalBool


local var = CreateClientConVar( "advmat_cl_overridefootsteps", "1", true, false, "Should player footsteps match the advanced material of the prop they're stepping on?" )
local enabledBool = var:GetBool()
cvars.AddChangeCallback( "advmat_cl_overridefootsteps", function( _, _, new )
    enabledBool = tobool( new )
end, "advmat_cachebool" )

local cachedNames = {}

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
    if CLIENT and ply ~= LocalPlayer() then return end

    local groundEnt = GetGroundEntity( ply )
    local wasGrace

    if not IsValid( groundEnt ) then
        -- jumping hacks.....
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

-- jumping hack
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
            theSound = advMat_Table.stepOverrides[override][2]
        end
    end

    -- find sound from texture?
    if not theSound and texture then
        -- we already checked, no sound
        if data.NoFallbackFootstepSound then return end
        -- find footstep from the material's texture, then cache it in the ent's MaterialData, this way stepsound is wiped for new materials
        local cachedSound = data.CachedFootstepSound
        if cachedSound then
            theSound = cachedSound
        else
            for needle, currOverride in pairs( advMat_Table.stepOverrides ) do
                if string_find( texture, needle ) then
                    theSound = currOverride[2]
                    data.CachedFootstepSound = theSound
                    break

                end
            end
            if not theSound then
                -- no sound
                data.NoFallbackFootstepSound = true
            end
        end
    end

    -- okay find sound from the noise texture?
    if not theSound and data.UseNoise >= 1 and data.NoiseSetting then
        theSound = noiseSounds[ data.NoiseSetting ]

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