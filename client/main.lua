local QBCore = exports['qb-core']:GetCoreObject()

local npcPed = nil
local sellNpcPed = nil

-- Small helper to open our custom NUI
local function OpenScrapperUI(defaultTab)
    defaultTab = defaultTab or "main"

    QBCore.Functions.TriggerCallback('k-catjob:server:GetUIData', function(data)
        if not data then
            QBCore.Functions.Notify("Scrapper UI unavailable.", "error")
            return
        end

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "open",
            tab    = defaultTab,
            data   = data
        })
    end)
end

-- ========== NPC SPAWN + QB-TARGET (MAIN SCRAPPER) ==========

local function LoadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        print('[k-catjob] Invalid NPC model: ' .. model)
        return false
    end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end
    return hash
end

CreateThread(function()
    local modelHash = LoadModel(Config.NPC.model)
    if not modelHash then return end

    local c = Config.NPC.coords
    npcPed = CreatePed(0, modelHash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    FreezeEntityPosition(npcPed, true)

    if Config.NPC.scenario and Config.NPC.scenario ~= '' then
        TaskStartScenarioInPlace(npcPed, Config.NPC.scenario, 0, true)
    end

    -- qb-target -> open custom NUI
    exports['qb-target']:AddTargetEntity(npcPed, {
        options = {
            {
                type = "client",
                event = "k-catjob:client:OpenMainMenu",
                icon = "fa-solid fa-wrench",
                label = "Talk to Scrapper",
            },
        },
        distance = 2.5
    })
end)

-- ========== SECOND NPC: CONVERTER BUYER ==========

CreateThread(function()
    if not Config.SellNPC or not Config.SellNPC.coords then return end

    local model = Config.SellNPC.model or 's_m_y_dealer_01'
    local modelHash = LoadModel(model)
    if not modelHash then return end

    local c = Config.SellNPC.coords
    sellNpcPed = CreatePed(0, modelHash, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(sellNpcPed, true)
    SetBlockingOfNonTemporaryEvents(sellNpcPed, true)
    FreezeEntityPosition(sellNpcPed, true)

    if Config.SellNPC.scenario and Config.SellNPC.scenario ~= '' then
        TaskStartScenarioInPlace(sellNpcPed, Config.SellNPC.scenario, 0, true)
    end

    exports['qb-target']:AddTargetEntity(sellNpcPed, {
        options = {
            {
                type = "client",
                event = "k-catjob:client:SellConverters",
                icon = "fa-solid fa-money-bill",
                label = "Sell Converters",
            },
        },
        distance = 2.5
    })
end)

-- ========== UI OPEN EVENTS ==========

RegisterNetEvent('k-catjob:client:OpenMainMenu', function()
    OpenScrapperUI("main")
end)

RegisterNetEvent('k-catjob:client:OpenShop', function()
    OpenScrapperUI("shop")
end)

RegisterNetEvent('k-catjob:client:ShowXP', function()
    OpenScrapperUI("xp")
end)

-- ========== SELL CONVERTERS (CLIENT -> SERVER) ==========

RegisterNetEvent('k-catjob:client:SellConverters', function()
    TriggerServerEvent('k-catjob:server:SellConverters')
end)

-- ========== DISPATCH HELPER (ps-dispatch + ps-mdt) ==========

local function TriggerConverterDispatch(vehicle)
    if not Config.Dispatch or not Config.Dispatch.Enabled then return end

    local chance = Config.Dispatch.AlertChance or 100
    if chance < 100 and math.random(1, 100) > chance then
        return
    end

    if not GetResourceState or GetResourceState('ps-dispatch') ~= 'started' then
        print('[k-catjob] ps-dispatch not started, skipping dispatch / ps-mdt alert')
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local plate

    if vehicle and vehicle ~= 0 then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["ps-dispatch"]:CustomAlert({
        coords       = coords,
        message      = "Possible catalytic converter theft in progress",
        dispatchCode = "10-60",
        description  = "Catalytic Converter Theft",
        radius       = 25.0,
        plate        = plate,
        priority     = 2,
        sprite       = 523,
        color        = 5,
        scale        = 1.2,
        length       = 3,
    })
end

-- ========== TOOL USAGE / CUTTING CONVERTER ON ANY PARKED CAR ==========

RegisterNetEvent('k-catjob:client:UseSaw', function()
    -- Ask server if our blade is cooled down before we even start
    QBCore.Functions.TriggerCallback('k-catjob:server:CanStrip', function(canStrip, reason)
        if not canStrip then
            QBCore.Functions.Notify(
                reason or "Your blade is too hot to cut right now. Let it cool down.",
                "error"
            )
            return
        end

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            QBCore.Functions.Notify("You need to be out of the vehicle to do this.", "error")
            return
        end

        local pCoords = GetEntityCoords(ped)
        local vehicle = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 6.0, 0, 70)

        if vehicle == 0 or not DoesEntityExist(vehicle) then
            QBCore.Functions.Notify("No vehicle nearby to cut.", "error")
            return
        end

        -- Must be reasonably parked (no driver)
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver ~= 0 then
            QBCore.Functions.Notify("The vehicle must be parked and unoccupied.", "error")
            return
        end

        -- Ensure it's not moving
        local speed = GetEntitySpeed(vehicle)
        if speed > 1.0 then
            QBCore.Functions.Notify("The vehicle must be stationary.", "error")
            return
        end

        local plate = GetVehicleNumberPlateText(vehicle) or ""
        local vehClass = GetVehicleClass(vehicle)

        -- Ensure the vehicle is treated as a mission entity so it doesn't despawn
        NetworkRequestControlOfEntity(vehicle)
        local attempt = 0
        while not NetworkHasControlOfEntity(vehicle) and attempt < 20 do
            Wait(0)
            NetworkRequestControlOfEntity(vehicle)
            attempt = attempt + 1
        end
        SetEntityAsMissionEntity(vehicle, true, false)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)

        -- Move the player to a position under / beside the vehicle and play a mechanic animation
        local vehHeading = GetEntityHeading(vehicle)
        local underPos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -1.2, -0.5)
        SetEntityCoords(ped, underPos.x, underPos.y, underPos.z, false, false, false, true)
        SetEntityHeading(ped, vehHeading + 90.0)

        -- As soon as the player starts messing with the car, fire the police alert (subject to chance)
        TriggerConverterDispatch(vehicle)

        local duration = math.random(Config.Progress.MinTimeMs, Config.Progress.MaxTimeMs)
        local label = Config.Progress.Label or "Cutting Converter..."

        -- Mechanic-style animation: lying / working under a car
        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_VEHICLE_MECHANIC", 0, true)

        QBCore.Functions.Progressbar("catjob_cut", label, duration, false, true, {
            disableMovement    = true,
            disableCarMovement = true,
            disableMouse       = false,
            disableCombat      = true,
        }, {}, {}, {}, function() -- Done
            ClearPedTasks(ped)
            -- Kill and lock the engine so the car is undriveable after the cut
            SetVehicleEngineHealth(vehicle, 0.0)
            SetVehiclePetrolTankHealth(vehicle, 0.0)
            SetVehicleEngineOn(vehicle, false, true, true)
            SetVehicleUndriveable(vehicle, true)
            SetVehicleDoorsLocked(vehicle, 2)
            TriggerServerEvent('k-catjob:server:StripVehicle', plate, vehClass)
        end, function() -- Cancel
            ClearPedTasks(ped)
            QBCore.Functions.Notify("You stopped cutting the converter.", "error")
        end)
    end)
end)

-- ========== REWARD SUMMARY FROM SERVER (NUI TOAST - UNUSED NOW) ==========

RegisterNetEvent('k-catjob:client:ShowJobRewards', function(data)
    -- This event is left in place for compatibility but does nothing visually now,
    -- since the XP popup was removed at your request.
end)

-- ========== NUI CALLBACKS ==========

RegisterNUICallback('nui_close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('nui_buyItem', function(data, cb)
    if data and data.name then
        TriggerServerEvent('k-catjob:server:BuyItem', data.name)
    end
    cb('ok')
end)
