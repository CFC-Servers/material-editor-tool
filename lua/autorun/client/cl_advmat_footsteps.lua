local string_find = string.find
local IsValid = IsValid

local entsMeta = FindMetaTable( "Entity" )
local GetGroundEntity = entsMeta.GetGroundEntity

local var = CreateClientConVar( "cl_advmat_overridefootsteps", "1", true, false, "Should player footsteps match the advanced material of the prop they're stepping on?" )
local enabledBool = var:GetBool()
cvars.AddChangeCallback( "cl_advmat_overridefootsteps", function( _, _, new ) 
    enabledBool = tobool( new )

end, "advmat_cachebool" )

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

hook.Add( "PlayerFootstep", "advmat_footsteps", function( ply, pos, foot, _, volume, filter )
    if not enabledBool then return end
    if infLoop then return end

    local data = getGroundEntMatData( ply )
    if not data then return end

    local theSound
    local override = data.StepOverride

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
    if not theSound then
        print( data.texture )

    end

    if not theSound then return end


    if string_find( theSound, "Step" ) then
        local footStr = "Left"
        if foot >= 1 then
            footStr = "Right"
        end

        theSound = theSound .. footStr

    end


    ply:EmitSound( theSound, 65, 100, volume, CHAN_BODY, SND_CHANGE_VOL, 0, filter )

    -- don't hog the hook!
    infLoop = true
    hook.Run( "PlayerFootstep", ply, pos, foot, theSound, volume, filter )
    infLoop = nil

    return true
end )