-- =========================
-- LISTAS DE BUFFS
-- =========================

local FlaskBuffs = {
    ["Flask of the Titans"] = true,
    ["Supreme Power"] = true,
    ["Distilled Wisdom"] = true,
    ["Chromatic Resistance"] = true
}

-- Lista para el reporte detallado de /rall
local AllRaidConsumables = {
    ["Elixir of the Mongoose"] = true,
    ["Elixir of Giants"] = true,
    ["Brilliant Wizard Oil"] = true,
    ["Dreamshard Elixir"] = true,
    ["Brilliant Mana Oil"] = true,
    ["Mana Regeneration"] = true -- Buff de Mageblood Potion
}

local ShadowBuffs = { ["Shadow Protection"] = true }
local FrostBuffs  = { ["Frost Protection"]  = true }
local NatureBuffs = { ["Nature Protection"] = true }
local FireBuffs   = { ["Fire Protection"]   = true }

-- =========================
-- TOOLTIP SCANNERS
-- =========================

local scanTooltip = CreateFrame("GameTooltip", "RaidBuffScanner", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local frostTooltip = CreateFrame("GameTooltip", "FrostItemScanner", nil, "GameTooltipTemplate")
frostTooltip:SetOwner(UIParent, "ANCHOR_NONE")

-- =========================
-- FUNCIONES DE APOYO
-- =========================

local function CanSendRaidMessage()
    return IsRaidLeader() or IsRaidOfficer()
end

local function UnitHasBuffFromList(unit, buffList)
    for i = 1, 32 do
        scanTooltip:ClearLines()
        scanTooltip:SetUnitBuff(unit, i)

        local line = _G["RaidBuffScannerTextLeft1"]
        if not line then break end

        local buffName = line:GetText()
        if not buffName then break end

        if buffList[buffName] then
            return true
        end
    end
    return false
end

local function CheckRaidForBuff(buffList, label)
    if GetNumRaidMembers() == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("No estas en raid.")
        return
    end

    local missing = {}
    local totalChecked = 0

    for i = 1, GetNumRaidMembers() do
        local unit = "raid"..i

        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
            totalChecked = totalChecked + 1

            if not UnitHasBuffFromList(unit, buffList) then
                missing[table.getn(missing)+1] = UnitName(unit)
            end
        end
    end

    local message
    if totalChecked == 0 then
        message = "No hay jugadores validos."
    elseif table.getn(missing) == 0 then
        message = "Todos tienen "..label.."."
    else
        message = "Sin "..label.." ("..table.getn(missing).."/"..totalChecked.."): "..table.concat(missing, ", ")
    end

    if CanSendRaidMessage() then
        SendChatMessage(message, "RAID")
    else
        DEFAULT_CHAT_FRAME:AddMessage("["..label.."] "..message)
    end
end

-- ==========================================
-- LÓGICA /RALL (CONSUMIBLES GENERALES)
-- ==========================================

local allScanQueue = {}
local allScanResults = { ok = 0, missing = {} }
local currentAllUnit = nil
local scanningAll = false
local allScanStartTime = nil

local function FinishAllCheck()
    local total = allScanResults.ok + table.getn(allScanResults.missing)

    local header = "Reporte de consumibles basicos (Mongoose, Giants, Wizard/Mana Oil, Dreamshard, Mageblood): "
    local stats = allScanResults.ok .. "/" .. total .. " OK"
    local msg = header .. stats

    if table.getn(allScanResults.missing) > 0 then
        msg = msg .. ", sin buffos esenciales: " .. table.concat(allScanResults.missing, ", ")
    end

    if CanSendRaidMessage() then
        SendChatMessage(msg, "RAID")
    else
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
    scanningAll = false
end

local function AllScanNext()
    if table.getn(allScanQueue) == 0 then FinishAllCheck() return end

    currentAllUnit = allScanQueue[1]
    for i = 1, table.getn(allScanQueue)-1 do allScanQueue[i] = allScanQueue[i+1] end
    allScanQueue[table.getn(allScanQueue)] = nil

    if UnitExists(currentAllUnit) then
        NotifyInspect(currentAllUnit)
        allScanStartTime = GetTime()
    else
        AllScanNext()
    end
end

local allScanFrame = CreateFrame("Frame")
allScanFrame:SetScript("OnUpdate", function()
    if not scanningAll or not currentAllUnit or not allScanStartTime then return end
    if GetTime() - allScanStartTime < 1 then return end

    allScanStartTime = nil
    local name = UnitName(currentAllUnit)
    local found = false

    -- 1. Verificar Barra de Buffs
    if UnitHasBuffFromList(currentAllUnit, AllRaidConsumables) then
        found = true
    end

    -- 2. Verificar Aceites en armas (slots 16 y 17)
    if not found then
        for _, slot in pairs({16, 17}) do
            scanTooltip:ClearLines()
            scanTooltip:SetInventoryItem(currentAllUnit, slot)
            for j = 1, scanTooltip:NumLines() do
                local line = _G["RaidBuffScannerTextLeft"..j]
                if line and line:GetText() then
                    local text = line:GetText()
                    if string.find(text, "Wizard Oil") or string.find(text, "Mana Oil") then
                        found = true
                        break
                    end
                end
            end
            if found then break end
        end
    end

    if found then
        allScanResults.ok = allScanResults.ok + 1
    else
        allScanResults.missing[table.getn(allScanResults.missing) + 1] = name
    end

    ClearInspectPlayer()
    currentAllUnit = nil
    AllScanNext()
end)

function CheckRaidAll()
    if GetNumRaidMembers() == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("No estas en raid.")
        return
    end

    allScanQueue = {}
    allScanResults = { ok = 0, missing = {} }

    for i = 1, GetNumRaidMembers() do
        local unit = "raid"..i
        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
            allScanQueue[table.getn(allScanQueue) + 1] = unit
        end
    end

    local startMsg = "Analizando jugadores, porfavor no se muevan..."
    if CanSendRaidMessage() then
        SendChatMessage(startMsg, "RAID")
    else
        DEFAULT_CHAT_FRAME:AddMessage(startMsg)
    end

    scanningAll = true
    AllScanNext()
end

-- =========================
-- FROST 105 CHECK (GEAR + BUFF)
-- =========================
-- Bloque corregido por amigo: usa string.find en vez de strmatch,
-- compatible con Vanilla 1.12. FinishFrostCheck respeta CanSendRaidMessage.

local REQUIRED_FROST = 105
local FROST_BUFF_VALUE = 60

local inspectQueue = {}
local frostResults = {}
local currentUnit = nil
local scanning = false
local inspectStartTime = nil

local gearSlots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}

local function GetFrostFromItem(unit, slot)
    local total = 0

    frostTooltip:ClearLines()
    frostTooltip:SetInventoryItem(unit, slot)

    local inSetSection = false

    for i = 1, frostTooltip:NumLines() do
        local line = _G["FrostItemScannerTextLeft"..i]
        if line then
            local text = line:GetText()
            if text then
                -- Detectar inicio de sección de set por contenido
                if string.find(text, "%) Set:") then
                    inSetSection = true
                end

                local shouldRead = false

                if not inSetSection then
                    -- Stats normales del ítem: siempre leer
                    shouldRead = true
                else
                    -- Set bonus: solo leer si está ACTIVO (color dorado R>0.9, G~0.82, B<0.1)
                    local r, g, b = line:GetTextColor()
                    if r and r > 0.9 and g > 0.7 and g < 0.95 and b < 0.1 then
                        shouldRead = true
                    end
                end

                if shouldRead then
                    local _,_,value

                    _,_,value = string.find(text, "Frost Resistance %+?(%d+)")
                    if value then total = total + tonumber(value) end

                    _,_,value = string.find(text, "%+(%d+) Frost Resistance")
                    if value then total = total + tonumber(value) end

                    _,_,value = string.find(text, "All Resistances %+?(%d+)")
                    if value then total = total + tonumber(value) end

                    _,_,value = string.find(text, "%+(%d+) All Resistances")
                    if value then total = total + tonumber(value) end
                end
            end
        end
    end

    return total
end

local function UnitHasFrostAura(unit)
    local list = {
        ["Frost Resistance Aura"] = true,
        ["Frost Resistance Totem"] = true
    }
    return UnitHasBuffFromList(unit, list)
end

local function CalculateGearFrost(unit)
    local total = 0
    for i = 1, table.getn(gearSlots) do
        total = total + GetFrostFromItem(unit, gearSlots[i])
    end
    return total
end

local function FinishFrostCheck()
    local low = {}

    for name, value in pairs(frostResults) do
        if value < REQUIRED_FROST then
            low[table.getn(low)+1] = name.." ("..value..")"
        end
    end

    local msg
    if table.getn(low) == 0 then
        msg = "Todos llegan a "..REQUIRED_FROST.." Frost Resist con aura."
    else
        msg = "No llegan a "..REQUIRED_FROST..": "..table.concat(low, ", ")
    end

    if CanSendRaidMessage() then
        SendChatMessage(msg, "RAID")
    else
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end

    scanning = false
end

local function InspectNext()
    if table.getn(inspectQueue) == 0 then
        FinishFrostCheck()
        return
    end

    currentUnit = inspectQueue[1]

    for i = 1, table.getn(inspectQueue)-1 do
        inspectQueue[i] = inspectQueue[i+1]
    end
    inspectQueue[table.getn(inspectQueue)] = nil

    if UnitExists(currentUnit) then
        NotifyInspect(currentUnit)
        inspectStartTime = GetTime()
    else
        InspectNext()
    end
end

local inspectFrame = CreateFrame("Frame")
inspectFrame:SetScript("OnUpdate", function()
    if not scanning or not currentUnit then return end
    if not inspectStartTime then return end

    if GetTime() - inspectStartTime < 1 then return end

    inspectStartTime = nil

    local name = UnitName(currentUnit)
    local gearFR = CalculateGearFrost(currentUnit)
    local total = gearFR

    -- Aura de Paladin o Totem de Shaman: +60
    if UnitHasFrostAura(currentUnit) then
        total = total + FROST_BUFF_VALUE
    end

    -- Mark of the Wild / Gift of the Wild: +20 a todas las resistencias
    local motwList = {
        ["Mark of the Wild"] = true,
        ["Gift of the Wild"]  = true
    }
    if UnitHasBuffFromList(currentUnit, motwList) then
        total = total + 20
    end

    frostResults[name] = total

    ClearInspectPlayer()
    currentUnit = nil

    InspectNext()
end)

function CheckRaidFrost105()
    inspectQueue = {}
    frostResults = {}

    if GetNumRaidMembers() == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("No estas en raid.")
        return
    end

    for i = 1, GetNumRaidMembers() do
        local unit = "raid"..i
        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
            inspectQueue[table.getn(inspectQueue)+1] = unit
        end
    end

    if table.getn(inspectQueue) == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("No hay jugadores validos.")
        return
    end

    local startMsg = "Chequeando Frost 105 (gear + aura)..."
    if CanSendRaidMessage() then
        SendChatMessage(startMsg, "RAID")
    else
        DEFAULT_CHAT_FRAME:AddMessage(startMsg)
    end

    scanning = true
    InspectNext()
end

-- =========================
-- COMANDOS
-- =========================

SLASH_RALL1 = "/rall"
SlashCmdList["RALL"] = CheckRaidAll

SLASH_RAIDFLASK1 = "/rflask"
SlashCmdList["RAIDFLASK"] = function()
    CheckRaidForBuff(FlaskBuffs, "Flask")
end

SLASH_RSHADOW1 = "/rshadow"
SlashCmdList["RSHADOW"] = function()
    CheckRaidForBuff(ShadowBuffs, "Shadow Protection")
end

SLASH_RFROST1 = "/rfrost"
SlashCmdList["RFROST"] = function()
    CheckRaidForBuff(FrostBuffs, "Frost Protection")
end

SLASH_RNATURE1 = "/rnature"
SlashCmdList["RNATURE"] = function()
    CheckRaidForBuff(NatureBuffs, "Nature Protection")
end

SLASH_RFIRE1 = "/rfire"
SlashCmdList["RFIRE"] = function()
    CheckRaidForBuff(FireBuffs, "Fire Protection")
end

SLASH_RFROST1051 = "/rfrost105"
SlashCmdList["RFROST105"] = CheckRaidFrost105
