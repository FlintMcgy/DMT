--[[
Author: @FlintMcgee
Script: CaptureZone.lua
Date: 30-07-2025
Discord: https://discord.gg/fkRzUnazrC

Description:
    This script automatically manages zone ownership and contested status by detecting ground units within defined zones.
    It visually updates zone colors, contested overlays, progress bars, and optionally sends capture messages to players.
    Features progressive capture mechanics, optional persistence, and uses pure DCS scripting API without external frameworks.
    Requires properly named trigger zones in the Mission Editor to function.
    Keep in mind this Script only captures Trigger Zones and not Airbases - for that you'll need to utilize the native Capture Logic.
]]


-- [[ CONFIGURATION ]] --

local ZONE_NAMES = { "Alpha", "Bravo", "Charlie" }      -- Trigger zone names from Mission Editor
local CAPTURE_TIME = 180                                -- Time in seconds to capture a zone (3 minutes)
local CHECK_INTERVAL = 5                                -- Check interval in seconds
local SAVE_INTERVAL = 180                               -- Save persistence every 3 minutes
local CONTEST_FADE_TIME = 30                            -- Time contested overlay stays after contest ends
local SHOW_MESSAGES = true                              -- Enable/disable capture messages
local ENABLE_PERSISTENCE = false                        -- Enable/disable saving zone states to file

local COLOR_BLUE = { 0, 0, 1, 0.3 }                     -- Blue zone color (R, G, B, Alpha/Transparency)
local COLOR_RED = { 1, 0, 0, 0.3 }                      -- Red zone color (R, G, B, Alpha/Transparency)
local COLOR_NEUTRAL = { 1, 1, 1, 0.3 }                  -- Neutral zone color (R, G, B, Alpha/Transparency)
local COLOR_CONTESTED = { 1, 1, 0, 0.5 }                -- Contested zone overlay color (R, G, B, Alpha/Transparency)
local COLOR_PROGRESS = { 0, 1, 0, 0.8 }                 -- Capture progress bar color (R, G, B, Alpha/Transparency)

local CAPTURE_MESSAGES = {
    blue = {
        "Friendly forces have secured %s",
        "Blue team has established control of %s",
        "Friendly units report %s captured",
        "%s sector now under coalition control"
    },
    red = {
        "Enemy forces have taken %s",
        "Red team has seized control of %s",
        "Hostile units have captured %s",
        "%s sector lost to enemy forces"
    }
}

--[[ DON'T MAKE CHANGES BELOW THIS LINE ]] --

local zones = {}
local zoneStates = {}
local captureProgress = {}
local contestedOverlays = {}
local progressBars = {}
local lastSaveTime = 0

local BLUE = coalition.side.BLUE
local RED = coalition.side.RED
local NEUTRAL = coalition.side.NEUTRAL

local function tableToString(t)
    local result = "{"
    for k, v in pairs(t) do
        local key = type(k) == "number" and "[" .. k .. "]" or '["' .. k .. '"]'
        if type(v) == "table" then
            result = result .. key .. "=" .. tableToString(v) .. ","
        elseif type(v) == "string" then
            result = result .. key .. '="' .. v .. '",'
        elseif v == nil then
        else
            result = result .. key .. "=" .. tostring(v) .. ","
        end
    end
    result = result .. "}"
    return result
end

local function getCoalitionStrength(zone, coalitionSide)
    local strength = 0
    local groups = coalition.getGroups(coalitionSide, Group.Category.GROUND)

    for _, group in pairs(groups) do
        if group and group:isExist() then
            local units = group:getUnits()
            if units then
                for _, unit in pairs(units) do
                    if unit and unit:isExist() and unit:getLife() > 0 and unit:isActive() then
                        local unitPos = unit:getPoint()
                        local distance = math.sqrt((unitPos.x - zone.point.x) ^ 2 + (unitPos.z - zone.point.z) ^ 2)

                        if distance <= zone.radius then
                            strength = strength + 1
                        end
                    end
                end
            end
        end
    end
    return strength
end

local function drawZone(zoneIndex, color)
    local zone = zones[zoneIndex]
    if not zone then
        env.info("ERROR: Cannot draw zone " .. zoneIndex .. " - zone is nil")
        return
    end

    if zone.markId then
        trigger.action.removeMark(zone.markId)
        env.info("Removed old mark " .. zone.markId .. " for zone " .. zoneIndex)
    end

    zone.markId = math.floor(timer.getTime() * 10000) + (zoneIndex * 100) + math.random(1, 99)

    -- Debug info
    local zoneName = ZONE_NAMES[zoneIndex] or "Unknown"
    env.info("Drawing zone " ..
        zoneIndex ..
        " (" ..
        zoneName ..
        ") at (" .. zone.point.x .. ", " .. zone.point.z .. ") radius: " .. zone.radius .. " markId: " .. zone.markId)

    local success = pcall(function()
        trigger.action.circleToAll(-1, zone.markId, zone.point, zone.radius, color, color, 2, true)
    end)

    if success then
        env.info("Successfully drew zone " .. zoneIndex .. " (" .. zoneName .. ")")
    else
        env.info("FAILED to draw zone " .. zoneIndex .. " (" .. zoneName .. ")")
    end
end

local function drawContestedOverlay(zoneIndex)
    local zone = zones[zoneIndex]
    if not zone then return end

    local contestRadius = zone.radius * 0.25
    local markId = math.floor(timer.getTime() * 1000) + zoneIndex + 1000

    contestedOverlays[zoneIndex] = markId
    trigger.action.circleToAll(-1, markId, zone.point, contestRadius, COLOR_CONTESTED, COLOR_CONTESTED, 3, true)
end

local function removeContestedOverlay(zoneIndex)
    if contestedOverlays[zoneIndex] then
        trigger.action.removeMark(contestedOverlays[zoneIndex])
        contestedOverlays[zoneIndex] = nil
    end
end

local function drawProgressBar(zoneIndex, progress)
    local zone = zones[zoneIndex]
    if not zone then return end

    if progressBars[zoneIndex] then
        for _, markId in pairs(progressBars[zoneIndex]) do
            trigger.action.removeMark(markId)
        end
        progressBars[zoneIndex] = nil
    end

    if progress <= 0 then return end

    local barLength = zone.radius * 1.0
    local barWidth = zone.radius * 0.05
    local barX = zone.point.x + zone.radius + barWidth + 20
    local barY = zone.point.z

    progressBars[zoneIndex] = {}

    local backgroundId = math.floor(timer.getTime() * 1000) + zoneIndex + 2000
    trigger.action.rectToAll(-1, backgroundId,
        { x = barX, y = 0, z = barY - barLength / 2 },
        { x = barX + barWidth, y = 0, z = barY + barLength / 2 },
        { 0.2, 0.2, 0.2, 0.8 }, { 0.2, 0.2, 0.2, 0.8 }, 1, true)
    table.insert(progressBars[zoneIndex], backgroundId)

    local progressLength = barLength * (progress / 100)
    local progressId = math.floor(timer.getTime() * 1000) + zoneIndex + 3000
    trigger.action.rectToAll(-1, progressId,
        { x = barX + 1, y = 0, z = barY - barLength / 2 + 1 },
        { x = barX + barWidth - 1, y = 0, z = barY - barLength / 2 + progressLength - 1 },
        COLOR_PROGRESS, COLOR_PROGRESS, 2, true)
    table.insert(progressBars[zoneIndex], progressId)
end

local function sendCaptureMessage(zoneIndex, coalitionSide)
    if not SHOW_MESSAGES then return end

    local zoneName = ZONE_NAMES[zoneIndex]
    local messages = coalitionSide == BLUE and CAPTURE_MESSAGES.blue or CAPTURE_MESSAGES.red
    local messageTemplate = messages[math.random(#messages)]
    local message = string.format(messageTemplate, zoneName)

    trigger.action.outText(message, 15)
end

local function savePersistence()
    if not ENABLE_PERSISTENCE then return end

    local saveData = {}
    for i = 1, #zones do
        if zoneStates[i] then
            saveData[i] = {
                owner = zoneStates[i].owner,
                captureTimer = zoneStates[i].captureTimer,
                capturingCoalition = zoneStates[i].capturingCoalition or "nil"
            }
        end
    end

    local saveString = "return " .. tableToString(saveData)
    local file = io.open(lfs.writedir() .. "capture_zones_save.lua", "w")
    if file then
        file:write(saveString)
        file:close()
        env.info("Zone states saved successfully")
    else
        env.info("Failed to save zone states")
    end
end

local function loadPersistence()
    if not ENABLE_PERSISTENCE then
        env.info("Persistence disabled - starting with neutral zones")
        return
    end

    local file = io.open(lfs.writedir() .. "capture_zones_save.lua", "r")
    if file then
        local content = file:read("*all")
        file:close()

        local success, saveData = pcall(loadstring(content))
        if success and saveData then
            for i, data in pairs(saveData) do
                if zoneStates[i] then
                    zoneStates[i].owner = data.owner or NEUTRAL
                    zoneStates[i].captureTimer = data.captureTimer or 0
                    zoneStates[i].capturingCoalition = (data.capturingCoalition == "nil") and nil or
                        data.capturingCoalition

                    if data.owner == BLUE then
                        drawZone(i, COLOR_BLUE)
                    elseif data.owner == RED then
                        drawZone(i, COLOR_RED)
                    else
                        drawZone(i, COLOR_NEUTRAL)
                    end
                end
            end
            env.info("Zone states loaded successfully")
        else
            env.info("Failed to load zone states - using defaults")
        end
    else
        env.info("No save file found - starting with neutral zones")
    end
end

local function initializeZones()
    env.info("=== INITIALIZING CAPTURE ZONES ===")
    env.info("Looking for zones: " .. table.concat(ZONE_NAMES, ", "))
    env.info("Persistence: " .. (ENABLE_PERSISTENCE and "ENABLED" or "DISABLED"))

    env.info("Checking all available zones in mission...")

    for i, zoneName in ipairs(ZONE_NAMES) do
        env.info("Searching for zone: " .. zoneName)
        local zone = trigger.misc.getZone(zoneName)
        if zone then
            zones[i] = zone
            zoneStates[i] = {
                owner = NEUTRAL,
                captureTimer = 0,
                capturingCoalition = nil,
                contested = false,
                contestFadeTimer = 0
            }
            captureProgress[i] = 0

            env.info("✓ FOUND zone: " ..
                zoneName .. " at (" .. zone.point.x .. ", " .. zone.point.z .. ") radius: " .. zone.radius)

            timer.scheduleFunction(function()
                drawZone(i, COLOR_NEUTRAL)
                return nil
            end, nil, timer.getTime() + (i * 0.5))
        else
            env.info("✗ ERROR: Zone " .. zoneName .. " NOT FOUND in mission!")
            env.info("Make sure you have a trigger zone named exactly '" .. zoneName .. "' in the Mission Editor")
        end
    end

    local foundZones = #zones
    env.info("=== ZONE INITIALIZATION COMPLETE ===")
    env.info("Found " .. foundZones .. " out of " .. #ZONE_NAMES .. " zones")

    if foundZones == 0 then
        env.info("WARNING: No zones found! Check your zone names in Mission Editor")
    end

    timer.scheduleFunction(function()
        loadPersistence()
        return nil
    end, nil, timer.getTime() + 2)
end

local function updateZones()
    local currentTime = timer.getTime()

    for i = 1, #zones do
        if zones[i] and zoneStates[i] then
            local blueStrength = getCoalitionStrength(zones[i], BLUE)
            local redStrength = getCoalitionStrength(zones[i], RED)
            local state = zoneStates[i]

            local contested = (blueStrength > 0 and redStrength > 0)
            local capturingCoalition = nil

            if not contested then
                if blueStrength > 0 then
                    capturingCoalition = BLUE
                elseif redStrength > 0 then
                    capturingCoalition = RED
                end
            end

            if contested and not state.contested then
                state.contested = true
                drawContestedOverlay(i)
                state.captureTimer = 0
                captureProgress[i] = 0
                drawProgressBar(i, 0)
            elseif not contested and state.contested then
                state.contested = false
                state.contestFadeTimer = CONTEST_FADE_TIME
            end

            if state.contestFadeTimer > 0 then
                state.contestFadeTimer = state.contestFadeTimer - CHECK_INTERVAL
                if state.contestFadeTimer <= 0 then
                    removeContestedOverlay(i)
                end
            end

            if not contested and capturingCoalition and capturingCoalition ~= state.owner then
                if state.capturingCoalition == capturingCoalition then
                    state.captureTimer = state.captureTimer + CHECK_INTERVAL
                else
                    state.captureTimer = CHECK_INTERVAL
                    state.capturingCoalition = capturingCoalition
                end

                captureProgress[i] = math.min(100, (state.captureTimer / CAPTURE_TIME) * 100)
                drawProgressBar(i, captureProgress[i])

                if state.captureTimer >= CAPTURE_TIME then
                    state.owner = capturingCoalition
                    state.captureTimer = 0
                    state.capturingCoalition = nil
                    captureProgress[i] = 0
                    drawProgressBar(i, 0)

                    if capturingCoalition == BLUE then
                        drawZone(i, COLOR_BLUE)
                    else
                        drawZone(i, COLOR_RED)
                    end
                    sendCaptureMessage(i, capturingCoalition)
                end
            elseif not contested and capturingCoalition == nil and state.owner ~= NEUTRAL then
                state.owner = NEUTRAL
                state.captureTimer = 0
                state.capturingCoalition = nil
                captureProgress[i] = 0
                drawProgressBar(i, 0)
                drawZone(i, COLOR_NEUTRAL)
            elseif contested or (capturingCoalition and capturingCoalition == state.owner) then
                state.captureTimer = 0
                state.capturingCoalition = nil
                captureProgress[i] = 0
                drawProgressBar(i, 0)
            end
        end
    end

    if ENABLE_PERSISTENCE and currentTime - lastSaveTime > SAVE_INTERVAL then
        savePersistence()
        lastSaveTime = currentTime
    end
end

local function startSystem()
    initializeZones()
    env.info("DCS Capture Zone System initialized")

    local function updateLoop()
        updateZones()
        return timer.getTime() + CHECK_INTERVAL
    end

    timer.scheduleFunction(updateLoop, nil, timer.getTime() + CHECK_INTERVAL)
end

timer.scheduleFunction(startSystem, nil, timer.getTime() + 1)
