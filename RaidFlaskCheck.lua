-- =========================
-- LISTAS DE BUFFS
-- =========================

local FlaskBuffs = {
    ["Flask of the Titans"] = true,
    ["Supreme Power"] = true,
    ["Distilled Wisdom"] = true,
    ["Chromatic Resistance"] = true
}

local ShadowBuffs = { ["Shadow Protection"] = true }
local FrostBuffs  = { ["Frost Protection"]  = true }
local NatureBuffs = { ["Nature Protection"] = true }
local FireBuffs   = { ["Fire Protection"]   = true }

-- =========================
-- TOOLTIP SCANNER BUFFS
-- =========================

local scanTooltip = CreateFrame("GameTooltip", "RaidBuffScanner", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

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

local function CanSendRaidMessage()
    return IsRaidLeader() or IsRaidOfficer()
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

-- =========================
-- FROST 105 CHECK (GEAR + BUFF)
-- =========================

local REQUIRED_FROST = 105
local FROST_BUFF_VALUE = 60

local inspectQueue = {}
local frostResults = {}
local currentUnit = nil
local scanning = false
local inspectStartTime = nil

local frostTooltip = CreateFrame("GameTooltip", "FrostItemScanner", nil, "GameTooltipTemplate")
frostTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local gearSlots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}

local function GetFrostFromItem(unit, slot)
    local total = 0

    frostTooltip:ClearLines()
    frostTooltip:SetInventoryItem(unit, slot)

    for i = 1, frostTooltip:NumLines() do
        local line = _G["FrostItemScannerTextLeft"..i]
        if line then
            local text = line:GetText()
            if text then
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

    if table.getn(low) == 0 then
        SendChatMessage("Todos llegan a "..REQUIRED_FROST.." Frost Resist con aura.", "RAID")
    else
        SendChatMessage("No llegan a "..REQUIRED_FROST..": "..table.concat(low, ", "), "RAID")
    end

    scanning = false
end

local function InspectNext()
    if table.getn(inspectQueue) == 0 then
        FinishFrostCheck()
        return
    end

    currentUnit = inspectQueue[1]

    -- shift manual
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

    if UnitHasFrostAura(currentUnit) then
        total = total + FROST_BUFF_VALUE
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

    SendChatMessage("Chequeando Frost 105 (gear + aura)...", "RAID")

    scanning = true
    InspectNext()
end

-- =========================
-- COMANDOS
-- =========================

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
