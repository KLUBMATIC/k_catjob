local QBCore = exports['qb-core']:GetCoreObject()

local ActiveJobs = {}  -- [citizenid] = { spotIndex, coords (vector3), targetModel, tierIndex, tierLabel }

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
        return nil -- max level
    end
    return Config.XP.Levels[nextLevel]
end

-- ========= VEHICLE LIST / TIERS =========
local VehicleTiers = CatJobVehicles or {}

local function GetTierForLevel(level)
    if level >= 5 then
        return 3
    elseif level >= 3 then
        return 2
    else
        return 1
    end
end

local function PickVehicleModelForLevel(level)
    local tierIndex = GetTierForLevel(level)
    local tier = VehicleTiers[tierIndex]
    if not tier or not tier.models or #tier.models == 0 then
        return nil, tierIndex
    end
    local idx = math.random(1, #tier.models)
    return tier.models[idx], tierIndex
end

-- ========= VEHICLE CLASS / REWARD SCALING =========

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

-- ========= JOB LOGIC =========

RegisterNetEvent('k-catjob:server:RequestJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    if ActiveJobs[cid] then
        TriggerClientEvent('QBCore:Notify', src, "You already have a job.", 'error')
        return
    end

    if not Config.Job or not Config.Job.Spots or #Config.Job.Spots == 0 then
        TriggerClientEvent('QBCore:Notify', src, "No job spots configured.", 'error')
        return
    end

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)
    local targetModel, tierIndex = PickVehicleModelForLevel(level)

    local tierLabel
    if VehicleTiers[tierIndex] and VehicleTiers[tierIndex].label then
        tierLabel = VehicleTiers[tierIndex].label
    else
        tierLabel = ("Tier %s"):format(tostring(tierIndex or "?"))
    end

    local spotIndex = math.random(1, #Config.Job.Spots)
    local spot = Config.Job.Spots[spotIndex]
    local coords = vector3(spot.x, spot.y, spot.z)

    ActiveJobs[cid] = {
        spotIndex   = spotIndex,
        coords      = coords,
        targetModel = targetModel,
        tierIndex   = tierIndex,
        tierLabel   = tierLabel,
    }

    TriggerClientEvent('k-catjob:client:AssignJob', src, {
        coords      = { x = spot.x, y = spot.y, z = spot.z, w = spot.w },
        spotIndex   = spotIndex,
        targetModel = targetModel,
        tierIndex   = tierIndex,
        tierLabel   = tierLabel,
    })
end)

RegisterNetEvent('k-catjob:server:FailJob', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid
    if not ActiveJobs[cid] then return end

    ActiveJobs[cid] = nil
    TriggerClientEvent('k-catjob:client:ClearJob', src)
    TriggerClientEvent('QBCore:Notify', src, "You failed to steal the converter.", 'error')
end)

RegisterNetEvent('k-catjob:server:FinishJob', function(spotIndex, vehCoords, vehClass)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    vehClass = vehClass or 0

    local cid = Player.PlayerData.citizenid
    local jobData = ActiveJobs[cid]
    if not jobData then
        TriggerClientEvent('QBCore:Notify', src, "You do not have an active job.", 'error')
        return
    end

    if jobData.spotIndex ~= spotIndex then
        TriggerClientEvent('QBCore:Notify', src, "This is not the correct car.", 'error')
        return
    end

    local jobCoords = jobData.coords
    local dist = #(jobCoords - vector3(vehCoords.x, vehCoords.y, vehCoords.z))
    if dist > 10.0 then
        TriggerClientEvent('QBCore:Notify', src, "You are too far from the target vehicle.", 'error')
        return
    end

    ActiveJobs[cid] = nil
    TriggerClientEvent('k-catjob:client:ClearJob', src)

    local xp = GetXPFromMeta(Player)
    local level = GetLevelFromXP(xp)
    local mult = GetRewardMultiplier(level, vehClass)

    -- Track rewards for UI summary
    local rewardsSummary = {}

    local function addReward(name, amount)
        if not name or amount <= 0 then return end
        rewardsSummary[name] = (rewardsSummary[name] or 0) + amount
    end

    -- Converters: always exactly 1 per car
    local converterItem = Config.Rewards.ConverterItem
    if converterItem then
        local converterCount = 1
        Player.Functions.AddItem(converterItem, converterCount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[converterItem], 'add')
        addReward(converterItem, converterCount)
    end

    -- Materials (scale with level + vehicle class)
    local materialCount = (Config.Rewards.BaseMats or 1) + level
    materialCount = math.max(1, math.floor(materialCount * mult))

    for _ = 1, materialCount, 1 do
        local matName = Config.Rewards.Materials[math.random(1, #Config.Rewards.Materials)]
        Player.Functions.AddItem(matName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[matName], 'add')
        addReward(matName, 1)
    end

    -- XP gain (scaled by level + vehicle class)
    local baseXP   = math.random(Config.XP.MinXPPerJob, Config.XP.MaxXPPerJob)
    local gainedXP = math.max(1, math.floor(baseXP * mult))

    local newXP = xp + gainedXP
    local oldLevel = level
    SetXP(Player, newXP)
    local newLevel = GetLevelFromXP(newXP)

    -- Instead of QBCore notifications, show an NUI toast with items + XP summary
    TriggerClientEvent('k-catjob:client:ShowJobRewards', src, {
        rewards  = rewardsSummary,
        xpGained = gainedXP,
        oldLevel = oldLevel,
        newLevel = newLevel,
    })
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
        if level >= item.level then
            local itemDef = QBCore.Shared.Items[item.name]
            local img = itemDef and itemDef.image or (item.image or (item.name .. ".png"))

            visibleItems[#visibleItems+1] = {
                name  = item.name,
                label = item.label or item.name,
                price = item.price,
                level = item.level,
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

    if level < shopItem.level then
        TriggerClientEvent('QBCore:Notify', src, "You are not a high enough level to buy this.", 'error')
        return
    end

    if Player.PlayerData.money['cash'] < shopItem.price then
        TriggerClientEvent('QBCore:Notify', src, "You do not have enough cash.", 'error')
        return
    end

    if not Player.Functions.AddItem(shopItem.name, 1) then
        TriggerClientEvent('QBCore:Notify', src, "You do not have enough inventory space.", 'error')
        return
    end

    Player.Functions.RemoveMoney('cash', shopItem.price, 'scrapper-shop-purchase')
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
        if level >= item.level then
            local itemDef = QBCore.Shared.Items[item.name]
            local img = itemDef and itemDef.image or (item.image or (item.name .. ".png"))

            visibleItems[#visibleItems+1] = {
                name  = item.name,
                label = item.label or item.name,
                price = item.price,
                level = item.level,
                image = img,
            }
        end
    end

    local cid = Player.PlayerData.citizenid
    local jobData = ActiveJobs[cid]
    local jobInfo

    if jobData then
        jobInfo = {
            hasJob      = true,
            targetModel = jobData.targetModel,
            tierIndex   = jobData.tierIndex,
            tierLabel   = jobData.tierLabel,
        }
    else
        jobInfo = { hasJob = false }
    end

    cb({
        xp        = xp,
        level     = level,
        nextXP    = nextXP,
        shopItems = visibleItems,
        job       = jobInfo,
    })
end)

-- ========= USEABLE ITEM =========

CreateThread(function()
    QBCore.Functions.CreateUseableItem(Config.RequiredToolItem, function(source, item)
        local Player = QBCore.Functions.GetPlayer(source)
        if not Player then return end

        TriggerClientEvent('k-catjob:client:UseSaw', source)
    end)
end)
