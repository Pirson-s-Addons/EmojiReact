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
--
-- Tamano: el marco envuelve al texto (ChatBubbleTemplate: inset 16) y el cliente
-- fija el ancho del texto con el mensaje original, y lo vuelve a fijar mientras
-- el bocadillo se ve: ":heart_eyes:" deja un bocadillo enorme para un solo
-- emoji. El tamano nuevo se reaplica en cada fotograma hasta que el bocadillo
-- cambia de texto (otro mensaje) o desaparece.
--
-- El ancho no se puede calcular de antemano: al repartir lineas el cliente
-- cuenta cada textura |T|t mas ancha de lo que la dibuja (probado en la beta:
-- "hola que tal 😊 yo bien" partia aunque cabia de sobra, incluso con el ancho
-- del mensaje original). Asi que se corrige mirando el resultado: se apuntan las
-- lineas del mensaje original, se empieza por una estimacion y se ensancha
-- mientras salgan mas lineas, aunque pase del ancho original (con tope).
local GROW = 4
local resized = {} -- String -> { text, width, max, lines }
local resizer = CreateFrame("Frame")
resizer:Hide()
-- Un texto oculto no siempre se mide (da 0): se mide en uno visible y transparente
local measure = UIParent:CreateFontString(nil, "ARTWORK")
measure:SetAlpha(0)
measure:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)

resizer:SetScript("OnUpdate", function(self)
    for fs, want in pairs(resized) do
        local text = fs:GetText()
        if not fs:IsVisible() or not CanAccess(text) or text ~= want.text then
            resized[fs] = nil
        else
            -- Mas lineas de la cuenta, o recortado a "..." (un emoji solo no parte linea)
            local short = fs:GetNumLines() > want.lines or (fs.IsTruncated and fs:IsTruncated())
            if short and want.width < want.max then
                want.width = math.min(want.width + GROW, want.max)
            end
            if math.abs(fs:GetWidth() - want.width) > 0.5 then fs:SetWidth(want.width) end
            -- Nunca menos alto que un emoji: si no, el cliente lo recorta a "..."
            local height = math.max(fs:GetStringHeight(), ns.db.bubbleSize + 4)
            if math.abs(fs:GetHeight() - height) > 0.5 then fs:SetHeight(height) end
        end
    end
    if not next(resized) then self:Hide() end
end)

local function UpdateBubbles()
    local db = ns.db
    for _, bubble in pairs(C_ChatBubbles.GetAllChatBubbles()) do
        local frame = bubble:GetChildren()
        local fs = frame and frame.String
        local text = fs and fs:GetText()
        if CanAccess(text) and text then
            local new = ns.Emojify(text, db.bubbleSize, db.emoticons)
            if new ~= text then
                -- Estimacion de partida: el texto sin emojis mas lo que mide cada uno
                local plain, emojis = new:gsub("|T.-|t", "")
                measure:SetFont(fs:GetFont())
                measure:SetText(plain)
                local estimate = measure:GetUnboundedStringWidth() + emojis * (db.bubbleSize + 4)
                local original = fs:GetWidth()
                -- Las lineas del original, salvo que con emojis quepa en una: muchos
                -- :codigos: ocupan dos lineas y sus emojis caben de sobra en una
                local lines = estimate < original and 1 or math.max(1, fs:GetNumLines())
                fs:SetText(new)
                resized[fs] = {
                    text = new, lines = lines,
                    width = math.min(estimate, original),
                    -- Tope: el original mas lo que pudiera faltar por cada emoji
                    max = original + emojis * db.bubbleSize * 2,
                }
                fs:SetWidth(resized[fs].width)
                resizer:Show()
            end
        end
    end
end

local pickerButton

function ns.ChatEditBox()
    return ChatFrame1EditBox or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
end

function ns.ApplyPickerButton()
    pickerButton:SetShown(ns.db.pickerButton and not pickerButton.noEditBox)
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

    -- La caja de escribir del chat 1: la de Blizzard, que tambien usan Chattynator
    -- y otros addons de chat. Con ellos puede ocultarse al soltar el foco, asi que
    -- el boton responde al pulsar (no al soltar) y hay otras dos formas de abrir
    -- el panel: /emoji panel y su atajo de teclado (Bindings.xml).
    local editBox = ns.ChatEditBox()
    pickerButton = CreateFrame("Button", nil, editBox or UIParent)
    pickerButton:SetSize(18, 18)
    pickerButton:SetPoint("RIGHT", -6, 0)
    pickerButton:SetFrameLevel((editBox or UIParent):GetFrameLevel() + 10)
    pickerButton:SetNormalTexture(ns.EMOJI .. "1f604")
    pickerButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    pickerButton:RegisterForClicks("LeftButtonDown")
    pickerButton:SetScript("OnClick", function() ns.TogglePicker() end)
    pickerButton.noEditBox = not editBox
    ns.ApplyPickerButton()
end
