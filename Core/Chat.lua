local _, ns = ...

-- ==========================================
-- CHAT Y BOCADILLOS
-- ==========================================
-- El mensaje se cambia solo en la pantalla de quien tiene el addon: lo que se
-- envia sigue siendo texto (":joy:"), y quien no lo tenga lo vera asi.
--
-- Valores secretos: con restricciones activas el texto de un mensaje puede ser
-- secreto, y con un secreto no se puede ni comparar (tampoco con nil). El
-- filtro de chat de Blizzard ya no llama a los addons en ese caso
-- (canaccessvalue en ChatFrameFilters.lua); en los bocadillos se mira a mano.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local CanAccess = canaccessvalue or function() return true end

local CHAT_EVENTS = {
    "SAY", "YELL", "EMOTE", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
    "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "WHISPER", "WHISPER_INFORM",
    "BN_WHISPER", "BN_WHISPER_INFORM", "CHANNEL", "COMMUNITIES_CHANNEL",
}
-- Los mensajes que pueden salir en bocadillo
local BUBBLE_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }

local function ChatFilter(_, _, msg, ...)
    local db = ns.db
    if not db.chatEmojis then return false end
    local new = ns.Emojify(msg, db.chatSize, db.emoticons)
    if new ~= msg then return false, new, ... end
    return false
end

-- Dentro de mazmorras y bandas Blizzard no deja tocar los bocadillos:
-- GetAllChatBubbles() no los devuelve.
local function UpdateBubbles()
    local db = ns.db
    for _, bubble in pairs(C_ChatBubbles.GetAllChatBubbles()) do
        local frame = bubble:GetChildren()
        local fs = frame and frame.String
        local text = fs and fs:GetText()
        if CanAccess(text) and text then
            local new = ns.Emojify(text, db.bubbleSize, db.emoticons)
            if new ~= text then fs:SetText(new) end
        end
    end
end

-- ==========================================
-- CUADRICULA DE EMOJIS
-- ==========================================
-- Una sola ventana para todo: el boton de la caja de chat la usa para escribir
-- el emoji y las opciones para elegir el de cada hueco de la rueda.

local COLS, CELL = 8, 28
local grid = CreateFrame("Frame", "EmojiReactGrid", UIParent, "TooltipBackdropTemplate")
grid:SetSize(COLS * CELL + 12, math.ceil(#ns.EMOJIS / COLS) * CELL + 12)
grid:SetFrameStrata("FULLSCREEN_DIALOG")
grid:Hide()
tinsert(UISpecialFrames, "EmojiReactGrid") -- Esc la cierra

for i, e in ipairs(ns.EMOJIS) do
    local code = e[1]
    local b = CreateFrame("Button", nil, grid)
    b:SetSize(CELL - 2, CELL - 2)
    b:SetPoint("TOPLEFT", 6 + (i - 1) % COLS * CELL, -6 - math.floor((i - 1) / COLS) * CELL)
    b:SetNormalTexture(ns.EMOJI .. code)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function()
        grid:Hide()
        grid.onPick(code)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(":" .. code .. ":")
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Abre la cuadricula pegada a anchor; onPick(codigo) al elegir. Otro clic la cierra.
function ns.ToggleEmojiGrid(anchor, onPick)
    if grid:IsShown() and grid.anchor == anchor then
        grid:Hide()
        return
    end
    grid.anchor, grid.onPick = anchor, onPick
    grid:ClearAllPoints()
    grid:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 4)
    grid:Show()
end

local function InsertInChat(code)
    local text = ":" .. code .. ": "
    local editBox = ChatFrameUtil.GetActiveWindow()
    if editBox then editBox:Insert(text) else ChatFrameUtil.OpenChat(text) end
end

local pickerButton

function ns.ApplyPickerButton()
    pickerButton:SetShown(ns.db.pickerButton)
end

function ns.InitChat()
    for _, event in ipairs(CHAT_EVENTS) do
        ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_" .. event, ChatFilter)
    end

    local bubbles = CreateFrame("Frame")
    for _, event in ipairs(BUBBLE_EVENTS) do bubbles:RegisterEvent(event) end
    -- El bocadillo se crea en el fotograma siguiente al evento
    bubbles:SetScript("OnEvent", function()
        if ns.db.bubbleEmojis then C_Timer.After(0, UpdateBubbles) end
    end)

    local editBox = DEFAULT_CHAT_FRAME.editBox
    pickerButton = CreateFrame("Button", nil, editBox)
    pickerButton:SetSize(18, 18)
    pickerButton:SetPoint("RIGHT", -6, 0)
    pickerButton:SetNormalTexture(ns.EMOJI .. "smile")
    pickerButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    pickerButton:SetScript("OnClick", function(self) ns.ToggleEmojiGrid(self, InsertInChat) end)
    ns.ApplyPickerButton()
end
