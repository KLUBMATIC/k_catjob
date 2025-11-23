Config = {}

-- NPC that gives the job & shop
Config.NPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(-624.63, -1670.04, 20.06, 190.03), -- CHANGE THIS TO YOUR NPC LOCATION
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- Item required to cut the converter
Config.RequiredToolItem = 'catsaw'    -- must exist in qb-core/shared/items.lua

-- XP / Leveling
Config.XP = {
    MinXPPerJob = 10,
    MaxXPPerJob = 25,

    -- XP required for each level (index = level)
    -- Level 1 is default (0+ XP)
    Levels = {
        [1] = 0,    -- level 1 starts at 0
        [2] = 100,
        [3] = 250,
        [4] = 500,
        [5] = 800,
        [6] = 1200,
    },

    MaxLevel = 6,
}

-- Vehicle models for contracts are now defined in: data/vehicles.lua
-- This config only holds the potential SPOTS (locations) for the parked car + search radius.
Config.Job = {
    BlipSprite   = 1,
    BlipColor    = 5,
    BlipText     = 'Target Area',
    SearchRadius = 75.0,  -- radius (in meters) of the search zone shown on the map

    -- Specific car spawn locations around the city (vector4: x, y, z, heading)
    Spots = {
        vector4(368.28, -1116.43, 28.99, 182.21),
        vector4(878.75, -37.59, 78.35, 56.15),
        vector4(68.45, 258.71, 108.84, 68.51),
        vector4(-1659.38, -252.1, 54.51, 157.93),
        vector4(-2135.69, -397.88, 12.8, 236.96),
        vector4(-1670.17, -913.55, 7.82, 139.72),
        vector4(64.42, -1563.4, 29.05, 229.48),
    },
}

-- Reward configuration
Config.Rewards = {
    ConverterItem = 'catalytic_converter',

    -- converters are forced to 1x in server logic, these remain for compatibility / future use
    MinConverters = 1,
    MaxConverters = 1,

    -- base materials count (added to level, then scaled)
    BaseMats = 1,

    Materials = {
        'scrapmetal',
        'copper',
        'steel',
    }
}

-- Shop items (locked behind level)
Config.ShopItems = {
    {
        name = 'catsaw',
        price = 1500,
        amount = 10,
        level = 1,
        label = 'Converter Saw',
    },
    {
        name = 'lockpick',
        price = 300,
        amount = 50,
        level = 2,
        label = 'Lockpick',
    },
    {
        name = 'advancedlockpick',
        price = 900,
        amount = 25,
        level = 3,
        label = 'Advanced Lockpick',
    },
    {
        name = 'scrapmetal',
        price = 50,
        amount = 100,
        level = 2,
        label = 'Scrap Metal',
    },
}

-- Police dispatch (ps-dispatch + ps-mdt)
Config.Dispatch = {
    Enabled        = true,   -- master switch
    AlertOnFail    = true,   -- alert cops when player cancels / fails
    AlertOnSuccess = false,  -- optional: alert on success too
    AlertChance    = 50,     -- percent chance to actually send an alert
}

-- Progressbar configuration
Config.Progress = {
    MinTimeMs = 15000,   -- 15 seconds minimum
    MaxTimeMs = 25000,   -- up to 25 seconds
    Label     = 'Cutting Converter...',
}
