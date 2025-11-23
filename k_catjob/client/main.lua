local QBCore = exports['qb-core']:GetCoreObject()

local npcPed = nil
local CurrentJob = nil   -- { coords, spotIndex, targetModel, tierIndex, tierLabel, heading, vehicle }
local jobBlip = nil

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

-- Helper to push live job update into NUI (if it's open)
local function PushJobUpdateToNUI()
    local jobPayload = { hasJob = false }

    if CurrentJob and CurrentJob.coords then
        jobPayload = {
            hasJob      = true,
            targetModel = CurrentJob.targetModel,
            tierIndex   = CurrentJob.tierIndex,
            tierLabel   = CurrentJob.tierLabel,
        }
    end

    SendNUIMessage({
        action = "jobUpdate",
        job    = jobPayload
    })
end

-- ========== NPC SPAWN + QB-TARGET ==========

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

-- ========== JOB VEHICLE SPAWN / CLEANUP ==========

local function SpawnJobVehicle()
    if not CurrentJob or not CurrentJob.coords or not CurrentJob.targetModel then return end

    if CurrentJob.vehicle and DoesEntityExist(CurrentJob.vehicle) then return end

    local model = CurrentJob.targetModel
    local hash = GetHashKey(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        print('[k-catjob] Invalid job vehicle model: ' .. tostring(model))
        return
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(hash) then
        print('[k-catjob] Failed to load vehicle model: ' .. tostring(model))
        return
    end

    local coords = CurrentJob.coords
    local heading = CurrentJob.heading or 0.0

    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, true)
    if not veh or veh == 0 then
        print('[k-catjob] Failed to spawn job vehicle')
        SetModelAsNoLongerNeeded(hash)
        return
    end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    -- keep car locked so players cannot just steal it
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDoorsLockedForAllPlayers(veh, true)

    CurrentJob.vehicle = veh
    SetModelAsNoLongerNeeded(hash)
end

local function CleanupJobVehicle()
    -- Do NOT delete the vehicle anymore; just clear our reference so it can fade naturally with game cleanup
    if CurrentJob then
        CurrentJob.vehicle = nil
    end
end

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

RegisterNetEvent('k-catjob:client:RequestJob', function()
    if CurrentJob then
        QBCore.Functions.Notify("You already have a job active.", "error")
        return
    end
    TriggerServerEvent('k-catjob:server:RequestJob')
end)

-- ========== JOB ASSIGNMENT (ZONE RADIUS) ==========

RegisterNetEvent('k-catjob:client:AssignJob', function(jobData)
    if CurrentJob then
        QBCore.Functions.Notify("You already have an active job.", "error")
        return
    end

    local coords = vector3(jobData.coords.x, jobData.coords.y, jobData.coords.z)
    local heading = jobData.coords.w or 0.0

    CurrentJob = {
        coords      = coords,
        heading     = heading,
        spotIndex   = jobData.spotIndex,
        targetModel = jobData.targetModel,
        tierIndex   = jobData.tierIndex,
        tierLabel   = jobData.tierLabel,
        vehicle     = nil,
    }

    if DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end

    -- Use a radius blip to show a search zone instead of a direct marker + GPS route
    local radius = Config.Job.SearchRadius or 75.0
    jobBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(jobBlip, Config.Job.BlipColor or 5)
    SetBlipAlpha(jobBlip, 90)

    -- No notify here, the radius on the map is the hint

    SpawnJobVehicle()
    PushJobUpdateToNUI()
end)

RegisterNetEvent('k-catjob:client:ClearJob', function()
    CleanupJobVehicle()
    CurrentJob = nil
    if DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end
    PushJobUpdateToNUI()
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

-- ========== TOOL USAGE / CUTTING CONVERTER (PROGRESSBAR) ==========

RegisterNetEvent('k-catjob:client:UseSaw', function()
    if not CurrentJob or not CurrentJob.coords then
        QBCore.Functions.Notify("You do not have an active converter job.", "error")
        return
    end

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local dist = #(pCoords - CurrentJob.coords)

    if dist > 6.0 then
        QBCore.Functions.Notify("You must be near the target vehicle.", "error")
        return
    end

    local vehicle = 0
    if CurrentJob.vehicle and DoesEntityExist(CurrentJob.vehicle) then
        vehicle = CurrentJob.vehicle
    else
        vehicle = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 6.0, 0, 70)
    end

    if vehicle == 0 then
        QBCore.Functions.Notify("No vehicle nearby to cut.", "error")
        return
    end

    -- As soon as the player starts messing with the car, fire the police alert (subject to chance)
    TriggerConverterDispatch(vehicle)

    local duration = math.random(Config.Progress.MinTimeMs, Config.Progress.MaxTimeMs)
    local label = Config.Progress.Label or "Cutting Converter..."

    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_WELDING", 0, true)

    QBCore.Functions.Progressbar("catjob_cut", label, duration, false, true, {
        disableMovement    = true,
        disableCarMovement = true,
        disableMouse       = false,
        disableCombat      = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(ped)

        local vehClass = GetVehicleClass(vehicle)
        TriggerServerEvent('k-catjob:server:FinishJob', CurrentJob.spotIndex, GetEntityCoords(vehicle), vehClass)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("You stopped cutting the converter.", "error")
        TriggerServerEvent('k-catjob:server:FailJob')
    end)
end)

-- ========== REWARD SUMMARY FROM SERVER (NUI TOAST) ==========

RegisterNetEvent('k-catjob:client:ShowJobRewards', function(data)
    local rewardsArr = {}

    if data and data.rewards then
        for itemName, count in pairs(data.rewards) do
            rewardsArr[#rewardsArr+1] = {
                name  = itemName,
                count = count,
            }
        end
    end

    SendNUIMessage({
        action = "jobRewards",
        data   = {
            items    = rewardsArr,
            xpGained = data and data.xpGained or 0,
            oldLevel = data and data.oldLevel,
            newLevel = data and data.newLevel,
        }
    })
end)

-- ========== NUI CALLBACKS ==========

RegisterNUICallback('nui_close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('nui_startJob', function(_, cb)
    TriggerEvent('k-catjob:client:RequestJob')
    cb('ok')
end)

RegisterNUICallback('nui_buyItem', function(data, cb)
    if data and data.name then
        TriggerServerEvent('k-catjob:server:BuyItem', data.name)
    end
    cb('ok')
end)
