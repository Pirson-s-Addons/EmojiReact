local _, ns = ...
local L = ns.L

-- ==========================================
-- REACCIONES
-- ==========================================
-- La rueda (UI/Wheel.lua) llama a ns.React: la reaccion se ve encima de tu
-- personaje y, en la pantalla de los jugadores cercanos que tengan el addon,
-- encima de ti.
--
-- Envio: primero se prueba SendAddonMessage por "SAY" (alcance de /decir, lo
-- ideal). En la API moderna puede no estar permitido (InvalidChatType); en ese
-- caso todos los que tienen el addon comparten un canal de chat oculto y solo
-- se pinta la reaccion si el que la envia tiene la placa de nombre visible,
-- o sea, si esta cerca.
--
-- Donde se pinta: sobre la placa de nombre (nameplate) del que reacciona. Por
-- eso hace falta ver las placas de jugadores amistosos, y por eso no se ve en
-- mazmorras y bandas: ahi Blizzard prohibe a los addons tocar las placas.
-- Tu propio personaje no tiene placa: tu reaccion va encima del centro de la
-- pantalla, a la altura que elijas.
--
-- Valores secretos: nombres y mensajes pueden ser secretos; se mira CanAccess
-- ANTES de comparar o preguntar si son nil.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local PREFIX, CHANNEL = "EmojiReact", "EmojiReactRX"
local BINDING = "EMOJIREACT_WHEEL"
local CanAccess = canaccessvalue or function() return true end
local useChannel = false
local lastSent = 0

BINDING_HEADER_EMOJIREACT = "Emoji & React"
BINDING_NAME_EMOJIREACT_WHEEL = L.BINDING_WHEEL

-- ==========================================
-- PINTAR LA REACCION
-- ==========================================

local function Pop(anchor, code, point, x, y)
    local p = anchor.emojiReactPop
    if not p then
        p = CreateFrame("Frame", nil, anchor)
        p:SetFrameStrata("HIGH")
        p.tex = p:CreateTexture(nil, "ARTWORK")
        p.tex:SetAllPoints()
        p.anim = p:CreateAnimationGroup()
        local grow = p.anim:CreateAnimation("Scale")
        grow:SetScaleFrom(0.3, 0.3)
        grow:SetScaleTo(1, 1)
        grow:SetDuration(0.18)
        grow:SetSmoothing("OUT")
        local rise = p.anim:CreateAnimation("Translation")
        rise:SetOffset(0, 14)
        rise:SetDuration(3)
        local fade = p.anim:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetStartDelay(2.5)
        fade:SetDuration(0.5)
        p.anim:SetScript("OnFinished", function() p:Hide() end)
        anchor.emojiReactPop = p
    end
    p:SetSize(ns.db.reactionSize, ns.db.reactionSize)
    p:ClearAllPoints()
    p:SetPoint(point, anchor, point, x, y)
    p.tex:SetTexture(ns.REACTION .. code)
    p:Show()
    p.anim:Stop()
    p.anim:Play()
end

-- La placa se busca por unidad (nameplate1..40): la estructura interna de las
-- placas cambio en la API moderna y asi no depende de ella.
local function ShowOnPlayer(name, code)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitName = GetUnitName(unit, true)
            if CanAccess(unitName) and unitName == name then
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                if plate then Pop(plate, code, "BOTTOM", 0, 20) end
                return
            end
        end
    end
    -- Sin placa visible: esta lejos o las placas amistosas estan apagadas
end

function ns.ShowOnSelf(code)
    Pop(UIParent, code or ns.db.slots[1], "CENTER", 0, ns.db.selfHeight)
end

-- ==========================================
-- ENVIO Y RECEPCION
-- ==========================================

local function IsSuccess(result) return result == true or result == 0 end

function ns.React(code)
    if not ns.db.reactions or not ns.REACTION_VALID[code] or GetTime() - lastSent < 1.5 then return end
    lastSent = GetTime()
    ns.ShowOnSelf(code)
    local msg = "R:" .. code
    if not useChannel then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, "SAY")
    else
        -- Enviar a un canal pide una pulsacion real: llega desde la tecla o el clic
        local id = GetChannelName(CHANNEL)
        if id and id > 0 then C_ChatInfo.SendChatMessage(msg, "CHANNEL", nil, id) end
    end
end

-- Para /emoji status: por donde viajan las reacciones en este cliente
function ns.Status()
    local mode = useChannel and L.STATUS_CHANNEL:format(CHANNEL, GetChannelName(CHANNEL)) or L.STATUS_SAY
    print(L.CHAT_PREFIX .. L.STATUS:format(mode, ns.CurrentKey(), GetCVarBool("nameplateShowFriendlyPlayers") and YES or NO))
end

local function Receive(text, sender)
    if not ns.db.reactions or not CanAccess(text, sender) then return end
    local name = Ambiguate(sender, "none")
    if name == UnitName("player") then return end
    local code = text:match("^R:([%w_]+)$")
    if code and ns.REACTION_VALID[code] then ShowOnPlayer(name, code) end
end

-- El canal oculto no sale en ninguna ventana de chat, ni sus avisos de entrada
local function IsOurChannel(_, _, ...)
    if not CanAccess(...) then return false end
    local channelString, baseName = select(4, ...), select(9, ...)
    return baseName == CHANNEL or (channelString or ""):find(CHANNEL, 1, true) ~= nil
end

-- ==========================================
-- TECLA DE LA RUEDA
-- ==========================================
-- Ventana "pulsa la tecla que quieras". Se guarda como un atajo normal del
-- juego, asi que tambien sale en Opciones > Atajos de teclado > AddOns.

local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local capture = CreateFrame("Frame", nil, UIParent, "TooltipBackdropTemplate")
capture:SetSize(400, 84)
capture:SetPoint("CENTER", 0, 150)
capture:SetFrameStrata("TOOLTIP")
capture:EnableKeyboard(true)
capture:SetPropagateKeyboardInput(false)
capture:EnableMouse(true)
capture:Hide()
local captureText = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
captureText:SetPoint("CENTER")
captureText:SetText(L.KEY_CAPTURE)

function ns.CurrentKey()
    local key = GetBindingKey(BINDING)
    return key and GetBindingText(key) or L.KEY_NONE
end

local function Unbind()
    for _, old in ipairs({ GetBindingKey(BINDING) }) do SetBinding(old) end
end

local function Bind(key)
    capture:Hide()
    if key == "ESCAPE" then return end
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    -- Orden de modificadores que espera el juego: ALT-CTRL-SHIFT-
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    local previous = GetBindingAction(combo)
    Unbind()
    SetBinding(combo, BINDING)
    SaveBindings(GetCurrentBindingSet())
    local msg = L.CHAT_PREFIX .. L.KEY_SET:format(ns.CurrentKey())
    if previous ~= "" and previous ~= BINDING then
        msg = msg .. " |cffff8800" .. L.KEY_REPLACED:format(_G["BINDING_NAME_" .. previous] or previous) .. "|r"
    end
    print(msg)
    if capture.onDone then capture.onDone() end
end

capture:SetScript("OnKeyDown", function(_, key) if not MODIFIERS[key] then Bind(key) end end)
capture:SetScript("OnMouseDown", function(_, button) if MOUSE[button] then Bind(MOUSE[button]) end end)

function ns.PickKey(onDone)
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    capture.onDone = onDone
    capture:Show()
end

function ns.ClearKey()
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    Unbind()
    SaveBindings(GetCurrentBindingSet())
end

-- ==========================================
-- ARRANQUE
-- ==========================================

function ns.InitReactions()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL", IsOurChannel)
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", IsOurChannel)

    local hinted = false
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Prueba si este cliente deja mensajes de addon por "SAY"; si no, canal oculto
            local result = C_ChatInfo.SendAddonMessage(PREFIX, "P", "SAY")
            useChannel = not IsSuccess(result) and result ~= Enum.SendAddonMessageResult.AddonMessageThrottle
            if useChannel and GetChannelName(CHANNEL) == 0 then
                (JoinTemporaryChannel or JoinPermanentChannel)(CHANNEL)
            end
            if ns.db.reactions and not GetBindingKey(BINDING) and not hinted then
                hinted = true
                print(L.CHAT_PREFIX .. L.KEY_HINT)
            end
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, text, _, sender = ...
            if CanAccess(prefix) and prefix == PREFIX then Receive(text, sender) end
        elseif event == "CHAT_MSG_CHANNEL" then
            local text, sender = ...
            local baseName = select(9, ...)
            if CanAccess(baseName) and baseName == CHANNEL then Receive(text, sender) end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            -- Las placas se reciclan: que la reaccion no se quede sobre otra unidad
            local plate = C_NamePlate.GetNamePlateForUnit(...)
            if plate and plate.emojiReactPop then plate.emojiReactPop:Hide() end
        end
    end)
end
