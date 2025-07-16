--[[
Author: @FlintMcgee
Script: CaptureZone
Date: 16-07-2025
Discord: https://discord.gg/fkRzUnazrC

Description:
    This script automatically manages zone ownership and contested status by detecting ground units within defined zones.
    It visually updates zone colors and contested overlays, and optionally sends capture messages to players.
    It requires properly named zones in the Mission Editor and the MOOSE framework to function.
    Keep in mind this Script only Captures Trigger Zones and not Airbases for that you'll need to utilize the native Capture Logic
]]


--[[ CONFIGURATION ]] --
local CaptureZoneNames   = { "Alpha", "Bravo", "Charlie" }              -- List of main capture zone names (from Mission Editor)
local ContestedZoneNames = { "Alpha:CZ", "Bravo:CZ", "Charlie:CZ" }     -- Matching contested zone names for yellow overlay display
local CHECK_INTERVAL     = 60                                           -- Interval (seconds) to check zone state and update ownership
local CONTEST_DELAY      = 15                                           -- Delay (seconds) before contested overlay appears when both sides are present
local CONTEST_FADE       = 30                                           -- Time (seconds) the contested overlay stays after contest ends
local messageDuration    = 15                                           -- Duration (seconds) capture message is displayed on screen
local messageOutput      = true                                         -- true = show capture messages, false = don't show any


--[[ DON'T MAKE CHANGES BELOW THIS LINE ]] --

local COLOR_BLUE      = { 0, 0, 1 }
local COLOR_RED       = { 1, 0, 0 }
local COLOR_NEUTRAL   = { 1, 1, 1 }
local COLOR_CONTESTED = { 1, 1, 0 }

local CaptureZones    = {}
local ContestedZones  = {}
local Owners          = {}
local ContestedStates = {}
local ContestTimers   = {}
local RemoveTimers    = {}

for i, name in ipairs(CaptureZoneNames) do
    CaptureZones[i]    = ZONE:FindByName(name)
    Owners[i]          = coalition.side.NEUTRAL
    ContestedStates[i] = false
    ContestTimers[i]   = 0
    RemoveTimers[i]    = 0
end

for i, name in ipairs(ContestedZoneNames) do
    ContestedZones[i] = ZONE:FindByName(name)
end

local function DrawZoneWithColor(zone, color)
    zone:UndrawZone()
    zone:DrawZone(-1, color, 2, color, 0.2)
end

local function DrawContestedOverlay(idx)
    ContestedZones[idx]:UndrawZone()
    ContestedZones[idx]:DrawZone(-1, COLOR_CONTESTED, 4, COLOR_CONTESTED, 0.3)
    ContestedStates[idx] = true
end

local function RemoveContestedOverlay(idx)
    ContestedZones[idx]:UndrawZone()
    ContestedStates[idx] = false
end

local function SendCaptureMessage(idx, coalitionSide)
    if not messageOutput then return end
    local side = coalitionSide == coalition.side.BLUE and "BLUE" or coalitionSide == coalition.side.RED and "RED" or
        "UNKNOWN"
    local zoneName = CaptureZoneNames[idx]
    MESSAGE:New(side .. " HAS CAPTURED ZONE: " .. zoneName, messageDuration):ToAll()
end

local function UpdateZones()
    for idx = 1, #CaptureZones do
        local zone    = CaptureZones[idx]
        local owner   = Owners[idx]

        local blueSet = SET_GROUP:New():FilterCategoryGround():FilterCoalitions("blue"):FilterZones({ zone }):FilterOnce()
        local redSet  = SET_GROUP:New():FilterCategoryGround():FilterCoalitions("red"):FilterZones({ zone }):FilterOnce()
        local nBlue   = blueSet:CountAlive()
        local nRed    = redSet:CountAlive()

        if nBlue > 0 and nRed > 0 then
            ContestTimers[idx] = ContestTimers[idx] + CHECK_INTERVAL
            RemoveTimers[idx]  = 0
            if not ContestedStates[idx] and ContestTimers[idx] >= CONTEST_DELAY then
                DrawContestedOverlay(idx)
            end
        else
            ContestTimers[idx] = 0
            if ContestedStates[idx] then
                RemoveTimers[idx] = RemoveTimers[idx] + CHECK_INTERVAL
                if RemoveTimers[idx] >= CONTEST_FADE then
                    RemoveContestedOverlay(idx)
                    RemoveTimers[idx] = 0
                end
            end
        end

        if nBlue > 0 and nRed > 0 then
        elseif owner == coalition.side.BLUE then
            if nBlue == 0 and nRed > 0 then
                Owners[idx] = coalition.side.NEUTRAL
                DrawZoneWithColor(zone, COLOR_NEUTRAL)
            elseif nBlue == 0 and nRed == 0 then
                Owners[idx] = coalition.side.NEUTRAL
                DrawZoneWithColor(zone, COLOR_NEUTRAL)
            end
        elseif owner == coalition.side.RED then
            if nRed == 0 and nBlue > 0 then
                Owners[idx] = coalition.side.NEUTRAL
                DrawZoneWithColor(zone, COLOR_NEUTRAL)
            elseif nRed == 0 and nBlue == 0 then
                Owners[idx] = coalition.side.NEUTRAL
                DrawZoneWithColor(zone, COLOR_NEUTRAL)
            end
        elseif owner == coalition.side.NEUTRAL then
            if nBlue > 0 and nRed == 0 then
                Owners[idx] = coalition.side.BLUE
                DrawZoneWithColor(zone, COLOR_BLUE)
                SendCaptureMessage(idx, coalition.side.BLUE)
            elseif nRed > 0 and nBlue == 0 then
                Owners[idx] = coalition.side.RED
                DrawZoneWithColor(zone, COLOR_RED)
                SendCaptureMessage(idx, coalition.side.RED)
            end
        end
    end
end

for idx = 1, #CaptureZones do
    DrawZoneWithColor(CaptureZones[idx], COLOR_NEUTRAL)
end

SCHEDULER:New(nil, UpdateZones, {}, 1, CHECK_INTERVAL)
