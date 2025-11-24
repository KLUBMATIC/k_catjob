local QBCore = exports['qb-core']:GetCoreObject()

-- Table to track which plates have already been stripped recently
local StrippedVehicles = {}
-- Table to track per-player cooldowns (by citizenid)
local PlayerCooldowns = {}

-- Ensure config tables exist with sane defaults
Config = Config or {}

Config.DB = Config.DB or {}
Config.DB.VehicleTable       = Config.DB.VehicleTable or 'player_vehicles'
Config.DB.OwnedVehicleCheck  = Config.DB.OwnedVehicleCheck ~= false  -- default true unless explicitly false

Config.StripCooldownSeconds  = Config.StripCooldownSeconds or (6 * 3600) -- 6 hours default
Config.BlacklistedClasses    = Config.BlacklistedClasses or { 18 }       -- emergency by default
Config.PlayerCooldownSeconds = Config.PlayerCooldownSeconds or 60        -- per-player "blade hot" cooldown in seconds

Config.Rewards = Config.Rewards or {}
Config.Rewards.ConverterItem = Config.Rewards.ConverterItem or 'catalytic_converter'
Config.Rewards.BaseMats      = Config.Rewards.BaseMats or 1
Config.Rewards.Materials     = Config.Rewards.Materials or { 'scrapmetal', 'copper', 'steel' }

Config.XP = Config.XP or {}
Config.XP.MinXPPerJob = Config.XP.MinXPPerJob or 10
Config.XP.MaxXPPerJob = Config.XP.MaxXPPerJob or 25
Config.XP.Levels      = Config.XP.Levels or {
    [1] = 0,
    [2] = 100,
    [3] = 250,
    [4] = 500,
    [5] = 800,
    [6] = 1200,
}
Config.XP.MaxLevel    = Config.XP.MaxLevel or 6

Config.ShopItems = Config.ShopItems or {}

Config.Sell = Config.Sell or {}
Config.Sell.Enabled       = Config.Sell.Enabled ~= false
Config.Sell.ConverterItem = Config.Sell.ConverterItem or Config.Rewards.ConverterItem or 'catalytic_converter'
Config.Sell.MinDirtyPer   = Config.Sell.MinDirtyPer or 1
Config.Sell.MaxDirtyPer   = Config.Sell.MaxDirtyPer or Config.Sell.MinDirtyPer
Config.Sell.DirtyItem     = Config.Sell.DirtyItem or 'inkedbills'

-- ========= XP HELPERS =========

local function GetXPFromMeta(Player)
    local meta = Player.PlayerData.metadata or {}
    local xp = meta['catjob_xp'] or 0
    return tonumber(xp) or 0
end

local function SetXP(Player, xp)
    xp = math.max(0, math.floor(xp))
    Player.Functions.SetMetaData('catjob_xp', xp)
end

local function GetLevelFromXP(xp)
    local level = 1
    local highest = 1
    for lvl, required in pairs(Config.XP.Levels) do
        if xp >= required and lvl > highest then
            highest = lvl
        end
    end
    level = highest
    return level
end

local function GetNextLevelXP(xp)
    local currentLevel = GetLevelFromXP(xp)
    local nextLevel = currentLevel + 1
    if not Config.XP.Levels[nextLevel] then
        return nil -- max level reached
    end
    return Config.XP.Levels[nextLevel]
end

-- ========= REWARD SCALING (BASED ON VEHICLE CLASS + LEVEL) =========

local function GetClassTier(vehClass)
    if vehClass == 6 or vehClass == 7 then
        return 3
    elseif vehClass == 4 or vehClass == 5 or vehClass == 2 or vehClass == 3 or vehClass == 1 then
        return 2
    else
        return 1
    end
end

local function GetRewardMultiplier(level, vehClass)
    level = level or 1
    vehClass = vehClass or 0

    local classTier = GetClassTier(vehClass)

    local levelBonus = 1.0 + ((level - 1) * 0.15)
    if levelBonus < 0.5 then levelBonus = 0.5 end

    local classBonus = 1.0
    if classTier == 2 then
        classBonus = 1.25
    elseif classTier == 3 then
        classBonus = 1.50
    end

    return levelBonus * classBonus
end

-- ========= ANTI-ABUSE HELPERS =========

local function IsClassBlacklisted(vehClass)
    for _, cls in ipairs(Config.BlacklistedClasses) do
        if vehClass == cls then
            return true
        end
    end
    return false
end

local function NormalizePlate(plate)
    plate = plate or ''
    plate = plate:gsub('%s+', '')
    return plate:upper()
end

local function IsPlateOnCooldown(plate)
    plate = NormalizePlate(plate)
    local ts = StrippedVehicles[plate]
    if not ts then return false end

    local now = os.time()
    if now - ts < Config.StripCooldownSeconds then
        return true
    else
        StrippedVehicles[plate] = nil
        return false
    end
end

local function MarkPlateStripped(plate)
    plate = NormalizePlate(plate)
    StrippedVehicles[plate] = os.time()
end

local function IsVehicleOwned(plate)
    if not Config.DB.OwnedVehicleCheck then return false end
    if not MySQL or not MySQL.scalar then return false end

    plate = NormalizePlate(plate)
    local query = ('SELECT 1 FROM %s WHERE plate = ? LIMIT 1'):format(Config.DB.VehicleTable)
    local result = nil

    local ok, err = pcall(function()
        result = MySQL.scalar.await(query, { plate })
    end)

    if not ok then
        print('[k_catjob] DB error when checking owned vehicle: ' .. tostring(err))
        return false
    end

    return result ~= nil
end

-- Per-player cooldown helpers (by citizenid)
local function IsPlayerOnCooldown(citizenid)
    if not citizenid then return false end
    local ts = PlayerCooldowns[citizenid]
    if not ts then return false end

    local now = os.time()
    if now - ts < Config.PlayerCooldownSeconds then
        return true
    else
        PlayerCooldowns[citizenid] = nil
        return false
    end
end

local function SetPlayerCooldown(citizenid)
    if not citizenid then return end
    PlayerCooldowns[citizenid] = os.time()
end

-- ========= SERVER CALLBACK: CAN STRIP? (BLADE HEAT) =========

QBCore.Functions.CreateCallback('k-catjob:server:CanStrip', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(false, "Something went wrong.")
        return
    end

    local citizenid = Player.PlayerData.citizenid
    if IsPlayerOnCooldown(citizenid) then
        cb(false, "Your blade is too hot to cut right now. Let it cool down.")
        return
    end

    cb(true)
end)

-- ========= STRIP VEHICLE EVENT =========

RegisterNetEvent('k-catjob:server:StripVehicle', function(plate, vehClass)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    plate = plate or ''
    vehClass = vehClass or 0

    local citizenid = Player.PlayerData.citizenid

    -- 0) Per-player cooldown check (double-check in case someone bypassed the callback)
    if IsPlayerOnCooldown(citizenid) then
        TriggerClientEvent('QBCore:Notify', src, "Your blade is too hot to cut right now. Let it cool down.", 'error')
        return
    end

    -- 1) Basic sanity
    if plate == '' then
        TriggerClientEvent('QBCore:Notify', src, "Unable to identify vehicle plate.", 'error')
        return
    end

    -- 2) Disallow emergency / blacklisted classes
    if IsClassBlacklisted(vehClass) then
        TriggerClientEvent('QBCore:Notify', src, "You can't strip this kind of vehicle.", 'error')
        return
    end

    -- 3) Disallow owned vehicles (optional DB-backed check)
    if IsVehicleOwned(plate) then
        TriggerClientEvent('QBCore:Notify', src, "You can't strip converters from owned vehicles.", 'error')
        return
    end

    -- 4) Per-plate cooldown to avoid farming the same vehicle
    if IsPlateOnCooldown(plate) then
        TriggerClientEvent('QBCore:Notify', src, "This vehicle's converter has already been removed.", 'error')
        return
    end

    MarkPlateStripped(plate)

    -- 5) Calculate rewards & XP
    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)
    local mult = GetRewardMultiplier(level, vehClass)

    -- Converters: always exactly 1 per vehicle
    local converterItem = Config.Rewards.ConverterItem
    if converterItem then
        local converterCount = 1
        Player.Functions.AddItem(converterItem, converterCount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[converterItem], 'add')
    end

    -- Materials (scale with level + vehicle class)
    local materialCount = (Config.Rewards.BaseMats or 1) + level
    materialCount = math.max(1, math.floor(materialCount * mult))

    for _ = 1, materialCount, 1 do
        local matName = Config.Rewards.Materials[math.random(1, #Config.Rewards.Materials)]
        Player.Functions.AddItem(matName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[matName], 'add')
    end

    -- XP gain (scaled by level + vehicle class)
    local baseXP   = math.random(Config.XP.MinXPPerJob, Config.XP.MaxXPPerJob)
    local gainedXP = math.max(1, math.floor(baseXP * mult))

    local newXP = xp + gainedXP
    local oldLevel = level
    SetXP(Player, newXP)
    local newLevel = GetLevelFromXP(newXP)

    -- Put player on cooldown after a successful cut
    SetPlayerCooldown(citizenid)

    -- Optionally you could notify XP gain here, but you requested no popup.
    -- You can inspect metadata or shop unlocks to feel progression.
end)

-- ========= SELL CONVERTERS FOR INKEDBILLS =========

RegisterNetEvent('k-catjob:server:SellConverters', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.Sell or not Config.Sell.Enabled then
        TriggerClientEvent('QBCore:Notify', src, "This buyer is currently closed.", 'error')
        return
    end

    local itemName = Config.Sell.ConverterItem or Config.Rewards.ConverterItem or 'catalytic_converter'
    local item = Player.Functions.GetItemByName(itemName)
    if not item or (item.amount or 0) <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "You don't have any converters to sell.", 'error')
        return
    end

    local sellCount     = item.amount
    local billsMin      = Config.Sell.MinDirtyPer or 1
    local billsMax      = Config.Sell.MaxDirtyPer or billsMin
    local dirtyItemName = Config.Sell.DirtyItem or 'inkedbills'

    if billsMin < 0 then billsMin = 0 end
    if billsMax < billsMin then billsMax = billsMin end

    -- Calculate total Inkedbills payout as item count
    local totalBills = 0
    for _ = 1, sellCount, 1 do
        totalBills = totalBills + math.random(billsMin, billsMax)
    end

    if totalBills <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "No payout calculated for this sale.", 'error')
        return
    end

    -- Try to give Inkedbills first
    if not Player.Functions.AddItem(dirtyItemName, totalBills) then
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough space to hold the Inkedbills.", 'error')
        return
    end

    -- Remove all converters being sold after we successfully added Inkedbills
    Player.Functions.RemoveItem(itemName, sellCount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[dirtyItemName], 'add')

    TriggerClientEvent(
        'QBCore:Notify',
        src,
        ("You sold %d converters and received %d Inkedbills."):format(sellCount, totalBills),
        'success'
    )
end)

-- ========= SHOP CALLBACKS / XP CALLBACK =========

QBCore.Functions.CreateCallback('k-catjob:server:GetShopItems', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(nil)
        return
    end

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)

    local visibleItems = {}
    for _, item in ipairs(Config.ShopItems) do
        if level >= (item.level or 1) then
            local itemDef = QBCore.Shared.Items[item.name]
            local img = itemDef and itemDef.image or (item.image or (item.name .. ".png"))

            visibleItems[#visibleItems+1] = {
                name  = item.name,
                label = item.label or item.name,
                price = item.price or 0,
                level = item.level or 1,
                image = img,
            }
        end
    end

    cb(visibleItems, xp, level)
end)

RegisterNetEvent('k-catjob:server:BuyItem', function(itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)

    local shopItem = nil
    for _, item in ipairs(Config.ShopItems) do
        if item.name == itemName then
            shopItem = item
            break
        end
    end

    if not shopItem then
        TriggerClientEvent('QBCore:Notify', src, "Item not sold here.", 'error')
        return
    end

    if level < (shopItem.level or 1) then
        TriggerClientEvent('QBCore:Notify', src, "You are not a high enough level to buy this.", 'error')
        return
    end

    local price = shopItem.price or 0
    if price > 0 and Player.PlayerData.money['cash'] < price then
        TriggerClientEvent('QBCore:Notify', src, "You do not have enough cash.", 'error')
        return
    end

    if not Player.Functions.AddItem(shopItem.name, 1) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have enough inventory space.", 'error')
        return
    end

    if price > 0 then
        Player.Functions.RemoveMoney('cash', price, 'scrapper-shop-purchase')
    end

    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[shopItem.name], 'add')
    TriggerClientEvent('QBCore:Notify', src, "Purchase successful.", 'success')
end)

QBCore.Functions.CreateCallback('k-catjob:server:GetXP', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(nil)
        return
    end

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)
    local nextXP = GetNextLevelXP(xp)
    cb(xp, level, nextXP)
end)

QBCore.Functions.CreateCallback('k-catjob:server:GetUIData', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        cb(nil)
        return
    end

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)
    local nextXP = GetNextLevelXP(xp)

    local visibleItems = {}
    for _, item in ipairs(Config.ShopItems) do
        if level >= (item.level or 1) then
            local itemDef = QBCore.Shared.Items[item.name]
            local img = itemDef and itemDef.image or (item.image or (item.name .. ".png"))

            visibleItems[#visibleItems+1] = {
                name  = item.name,
                label = item.label or item.name,
                price = item.price or 0,
                level = item.level or 1,
                image = img,
            }
        end
    end

    cb({
        xp        = xp,
        level     = level,
        nextXP    = nextXP,
        shopItems = visibleItems,
    })
end)

-- ========= USEABLE ITEM =========

CreateThread(function()
    local toolItem = Config.RequiredToolItem or 'catsaw'
    QBCore.Functions.CreateUseableItem(toolItem, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end

        TriggerClientEvent('k-catjob:client:UseSaw', source)
    end)
end)
