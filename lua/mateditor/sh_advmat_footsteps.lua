-- also used by language.add stuff in stools/advmat.lua
advMat_Table.stepOverrides = {
    none = { name = "None" },
    auto = { name = "Auto" },
    metal = { name = "Metal", snd = "SolidMetal.Step" },
    metalbox = { name = "Metal Box", snd = "Metal_Box.Step" },
    vent = { name = "Vent", snd = "MetalVent.Step" },
    grate = { name = "Grate", snd = "MetalGrate.Step" },
    ladder = { name = "Ladder", snd = "Ladder.Step" },
    weapon = { name = "Weapon", snd = "weapon.Step" },
    grenade = { name = "Grenade", snd = "Grenade.Step" },
    chainlink = { name = "Chain Link", snd = "ChainLink.Step" },

    snow = { name = "Snow", snd = "Snow.Step" },
    dirt = { name = "Dirt", snd = "Dirt.Step" },
    sand = { name = "Sand", snd = "Sand.Step" },
    grass = { name = "Grass", snd = "Grass.Step" },
    gravel = { name = "Gravel", snd = "Gravel.Step" },

    mud = { name = "Mud", snd = "Mud.Step" },
    slime = { name = "Slime", snd = "SlipperySlime.Step" },

    water = { name = "Water", snd = "Water.Step" },
    wade = { name = "Water ( Wade )", snd = "Wade.Step" },

    flesh = { name = "Flesh", snd = "Flesh.Step" },
    -- funny one
    fleshsquish = { name = "Flesh ( Squishy )", snd = "Flesh_Bloody.ImpactHard" },

    concrete = { name = "Concrete", snd = "Concrete.Step" },
    tile = { name = "Tile", snd = "Tile.Step" },
    glass = { name = "Glass", snd = "Glass.Step" },
    drywall = { name = "Drywall", snd = "drywall.Step" },
    celingtile = { name = "Ceiling Tile", snd = "ceiling_tile.Step" },
    glassbottle = { name = "Glass Bottle", snd = "GlassBottle.Step" },

    rubber = { name = "Rubber", snd = "Rubber.Step" },
    cardboard = { name = "Cardboard", snd = "Cardboard.Step" },
    plasticbox = { name = "Plastic Box", snd = "Plastic_Box.Step" },
    plasticbarrel = { name = "Plastic Barrel", snd = "Plastic_Barrel.Step" },

    wood = { name = "Wood", snd = "Wood.Step" },
    woodbox = { name = "Wood Box", snd = "Wood_Box.Step", },
    woodcrate = { name = "Wood Crate", snd = "Wood_Crate.Step" },
    woodpanel = { name = "Wood Panel", snd = "Wood_Panel.Step" },
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
local CLIENT = CLIENT

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
            theSound = advMat_Table.stepOverrides[override].snd
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
                    theSound = currOverride.snd
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