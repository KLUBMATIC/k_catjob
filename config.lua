Config = {}

-- NPC that opens the Scrapper UI (Info / Shop / XP)
Config.NPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(-1145.52, -1995.64, 13.16, 135.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- Second NPC that buys catalytic converters for a small amount of materials
Config.SellNPC = {
    model = 's_m_y_dealer_01',
    coords = vector4(-467.76, -1715.25, 18.69, 104.0), -- near a scrapyard-style area
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- Item name of the tool required to cut converters
Config.RequiredToolItem = 'catsaw'

-- Dispatch settings (ps-dispatch)
Config.Dispatch = {
    Enabled     = true,
    AlertChance = 60,    -- % chance alert fires when cutting starts
}

-- Database / anti-abuse checks
Config.DB = {
    VehicleTable      = 'player_vehicles', -- table with owned vehicles (plate column)
    OwnedVehicleCheck = true,             -- set false to disable owned-vehicle protection
}

-- Per-plate cooldown: time before the same plate can be stripped again
Config.StripCooldownSeconds = 6 * 3600  -- 6 hours

-- Per-player cooldown: time before the same player can strip again
Config.PlayerCooldownSeconds = 60       -- seconds; "blade too hot" time

-- GTA vehicle classes that are not allowed to be stripped (e.g. 18 = emergency)
Config.BlacklistedClasses = { 18 }

-- Rewards for cutting a converter directly from a car
Config.Rewards = {
    ConverterItem = 'catalytic_converter', -- always 1 per successful strip
    BaseMats      = 1,                     -- base material count before scaling

    Materials = {
        'scrapmetal',
        'copper',
        'steel',
    }
}

-- Selling catalytic converters for Inkedbills (dirty item) at the second NPC
Config.Sell = {
    Enabled       = true,
    ConverterItem = 'catalytic_converter',

    -- Inkedbills payout per converter (treated as item count, not currency value)
    MinDirtyPer   = 1,        -- minimum Inkedbills per converter
    MaxDirtyPer   = 3,        -- maximum Inkedbills per converter

    -- Item used to represent dirty money as a physical item
    DirtyItem     = 'inkedbills',
}
-- XP / Leveling
Config.XP = {
    MinXPPerJob = 10,
    MaxXPPerJob = 25,

    Levels = {
        [1] = 0,
        [2] = 100,
        [3] = 250,
        [4] = 500,
        [5] = 800,
        [6] = 1200,
    },

    MaxLevel = 6,
}

-- Shop inventory (level-gated)
Config.ShopItems = {
    {
        name  = 'catsaw',
        label = 'Converter Saw',
        price = 1500,
        amount = 10,
        level = 1,
        image = 'catsaw.png',
    },
    {
        name  = 'scrapmetal',
        label = 'Scrap Metal',
        price = 50,
        amount = 50,
        level = 2,
        image = 'scrapmetal.png',
    },
    {
        name  = 'copper',
        label = 'Copper',
        price = 75,
        amount = 50,
        level = 3,
        image = 'copper.png',
    },
    {
        name  = 'steel',
        label = 'Steel',
        price = 100,
        amount = 50,
        level = 4,
        image = 'steel.png',
    },
}

-- Progressbar configuration for cutting time
Config.Progress = {
    MinTimeMs = 20000,              -- 20s
    MaxTimeMs = 30000,              -- 30s
    Label     = 'Cutting Converter...',
}
