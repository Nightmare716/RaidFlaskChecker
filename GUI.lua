-- ==========================================
-- MENU GRAFICO PARA RAID SCANNER (Iconos NATIVOS)
-- ==========================================

local frame = CreateFrame("Frame", "RaidScannerMenu", UIParent)
frame:SetWidth(180) -- Un poco más ancho para los iconos
frame:SetHeight(230)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:Hide() 

-- Lógica de posición guardada
frame:RegisterEvent("VARIABLES_LOADED")
frame:SetScript("OnEvent", function()
    if not RaidScannerDB then
        RaidScannerDB = { x = 0, y = 0, point = "CENTER" }
    end
    frame:ClearAllPoints()
    frame:SetPoint(RaidScannerDB.point, UIParent, RaidScannerDB.point, RaidScannerDB.x, RaidScannerDB.y)
end)

frame:SetScript("OnDragStart", function() frame:StartMoving() end)
frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    local point, _, _, x, y = frame:GetPoint()
    RaidScannerDB.point = point
    RaidScannerDB.x = x
    RaidScannerDB.y = y
end)

-- Título
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", frame, "TOP", 0, -15)
title:SetText("Raid Scanner")

-- Botón de Cerrar (X)
local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)

-- Función para crear botones con Icono
local function CreateMenuButton(text, yOffset, slashCmd, iconPath)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetWidth(110)
    btn:SetHeight(25)
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 45, yOffset) -- Movido a la derecha para el icono
    btn:SetText(text)
    
    -- Crear el Icono
    local icon = btn:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(22)
    icon:SetHeight(22)
    icon:SetPoint("LEFT", btn, "LEFT", -30, 0)
    icon:SetTexture(iconPath)
    
    btn:SetScript("OnClick", function()
        local editBox = DEFAULT_CHAT_FRAME.editBox
        editBox:SetText(slashCmd)
        ChatEdit_SendText(editBox)
    end)
    return btn
end

-- Lista de Botones con sus iconos originales del juego
CreateMenuButton("Flask", -40, "/rflask", "Interface\\Icons\\Inv_Potion_91")
CreateMenuButton("Fire", -70, "/rfire", "Interface\\Icons\\Spell_Fire_FireArmor")
CreateMenuButton("Nature", -100, "/rnature", "Interface\\Icons\\Spell_Nature_ResistNature")
CreateMenuButton("Shadow", -130, "/rshadow", "Interface\\Icons\\Spell_Shadow_AntiShadow")
CreateMenuButton("Frost", -160, "/rfrost", "Interface\\Icons\\Spell_Frost_FrostWard")
CreateMenuButton("Frost 105", -190, "/rfrost105", "Interface\\Icons\\Spell_Frost_WizardMark")

-- Registro del comando
SLASH_RSCAN1 = "/rscan"
SlashCmdList["RSCAN"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

DEFAULT_CHAT_FRAME:AddMessage("|cffff69b4Raid Scanner GUI cargado. Escribe /rscan.|r")