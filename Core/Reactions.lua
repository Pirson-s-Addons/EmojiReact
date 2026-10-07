local _, ns = ...
local L = ns.L

-- ==========================================
-- REACCIONES
-- ==========================================
-- La rueda (UI/Wheel.lua) llama a ns.React: la reaccion se ve encima de tu
-- personaje y, en la pantalla de los jugadores cercanos que tengan el addon,
-- encima de ti.
--
-- Envio: mensaje de addon (invisible, sin pulsacion real) al grupo ("PARTY",
-- "RAID" o "INSTANCE_CHAT") y por susurro ("WHISPER") a cada jugador cercano
-- con placa visible que no este en el grupo: son justo los unicos sobre los que
-- se puede pintar. Probado en la beta (con un modo de depuracion ya quitado): por "SAY" no llega ni
-- la copia propia, y por un canal propio solo vuelve la propia, a los demas no.
-- Solo se pinta la reaccion si el que la envia tiene la placa visible.
--
-- Donde se pinta: sobre la placa de nombre (nameplate) del que reacciona. Por
-- eso, si el jugador no tiene las placas amistosas puestas, el addon las
-- enciende solo mientras dura la reaccion (ver PLACAS AL REACCIONAR), y por eso
-- no se ve en mazmorras y bandas: ahi Blizzard prohibe a los addons tocar las placas.
-- Tu propio personaje no tiene placa: tu reaccion va encima del centro de la
-- pantalla, a la altura que elijas.
--
-- Valores secretos: nombres y mensajes pueden ser secretos; se mira CanAccess
-- ANTES de comparar o preguntar si son nil.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

local PREFIX = "EmojiReact"
-- Canal de las primeras versiones (no repartia los mensajes): se abandona al entrar
local OLD_CHANNEL = "EmojiReactRX"
local WHISPER_MAX = 10 -- susurros por reaccion, por debajo del limite de mensajes
local BINDING = "EMOJIREACT_WHEEL"
local PAGE_BINDING = "EMOJIREACT_PAGE"
local CanAccess = canaccessvalue or function() return true end
local lastSent = 0

BINDING_HEADER_EMOJIREACT = "Emoji & React"
BINDING_NAME_EMOJIREACT_WHEEL = L.BINDING_WHEEL
BINDING_NAME_EMOJIREACT_PICKER = L.BINDING_PICKER
BINDING_NAME_EMOJIREACT_PAGE = L.BINDING_PAGE

-- ==========================================
-- PINTAR LA REACCION
-- ==========================================

local function Pop(anchor, code, point, relPoint, x, y)
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
    p:SetPoint(point, anchor, relPoint, x, y)
    p.tex:SetTexture(ns.REACTION .. code)
    p:Show()
    p.anim:Stop()
    p.anim:Play()
end

-- La placa se busca por unidad (nameplate1..40): la estructura interna de las
-- placas cambio en la API moderna y asi no depende de ella.
-- El que reacciona se identifica por su GUID, que va en el mensaje: los nombres
-- de Forever llevan espacio ("Davonna Davour") y el remitente de CHAT_MSG_ADDON
-- no viene escrito igual que UnitName (probado en la beta: ni se descartaban
-- las reacciones propias ni se encontraba la placa del otro).

local function ShowOnPlayer(guid, code)
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local unitGUID = UnitGUID(unit)
            if CanAccess(unitGUID) and unitGUID == guid then
                local plate = C_NamePlate.GetNamePlateForUnit(unit)
                -- Encima de la placa, sin tapar el nombre (probado en la beta)
                if plate then
                    Pop(plate, code, "BOTTOM", "TOP", 0, 2)
                    -- Con el nombre imitado, justo encima de el (la placa es mas alta)
                    local label = plate.emojiReactName
                    if label and label:IsShown() then
                        plate.emojiReactPop:ClearAllPoints()
                        plate.emojiReactPop:SetPoint("BOTTOM", label, "TOP", 0, 4)
                    end
                end
                return plate ~= nil
            end
        end
    end
    -- Sin placa visible: esta lejos o las placas amistosas estan apagadas
    return false
end

function ns.ShowOnSelf(code)
    Pop(UIParent, code or ns.db.slots[1], "CENTER", "CENTER", 0, ns.db.selfHeight)
end

-- ==========================================
-- ENVIO Y RECEPCION
-- ==========================================

local function GroupChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

function ns.React(code)
    if not ns.db.reactions or not ns.REACTION_VALID[code] or GetTime() - lastSent < 1.5 then return end
    lastSent = GetTime()
    ns.ShowOnSelf(code)
    local msg = "R:" .. code .. ":" .. UnitGUID("player")
    local group = GroupChannel()
    if group then C_ChatInfo.SendAddonMessage(PREFIX, msg, group) end
    -- Jugadores cercanos con placa que no reciben por el grupo
    local whispers = 0
    for i = 1, 40 do
        if whispers >= WHISPER_MAX then break end
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
            and not (group and (UnitInParty(unit) or UnitInRaid(unit))) then
            local name = GetUnitName(unit, true)
            if CanAccess(name) and name then
                C_ChatInfo.SendAddonMessage(PREFIX, msg, "WHISPER", name)
                whispers = whispers + 1
            end
        end
    end
end

local seen = {} -- GUID -> momento de su ultima reaccion (copias repetidas)

local function Receive(text)
    if not ns.db.reactions or ns.db.hideReactions or not CanAccess(text) then return end
    local code, guid = text:match("^R:([%w_]+):(.+)$")
    if not code or guid == UnitGUID("player") or not ns.REACTION_VALID[code] then return end
    if seen[guid] and GetTime() - seen[guid] < 1 then return end
    seen[guid] = GetTime()
    if not ShowOnPlayer(guid, code) then ns.ShowWithTempPlates(guid, code) end
end

-- ==========================================
-- PLACAS AL REACCIONAR
-- ==========================================
-- Un addon no puede saber donde esta otro jugador en pantalla: solo su placa.
-- Con las placas amistosas apagadas, el cliente pinta el nombre normal y no hay
-- placa; con ellas encendidas, deja de pintar ese nombre (probado en la beta:
-- las placas transparentes dejaban a los jugadores sin nombre). Asi que no se
-- tocan: al llegar una reaccion de alguien sin placa se encienden las placas
-- (solo nombre) lo que dura la reaccion y luego se devuelven como estaban.
-- Su placa aparece unos fotogramas despues: la reaccion espera en `waiting`.

local FRIENDLY, ONLY_NAME = "nameplateShowFriendlyPlayers", "nameplateShowOnlyNameForFriendlyPlayerUnits"
local SHOW_TIME = 3.5   -- la animacion de la reaccion dura 3 s
local WAIT_PLATE = 1.5  -- lo que se espera a que aparezca la placa
local waiting = {}      -- GUID -> { code, hasta cuando }
local saved             -- CVars del jugador mientras las placas son del addon
local restoreAt = 0
local restorePending, combatFailed = false, false

local function SetPlateCVar(name, value)
    if C_CVar and C_CVar.SetCVar then return C_CVar.SetCVar(name, value) ~= false end
    SetCVar(name, value)
    return true
end

local function RestorePlates()
    if not saved then return end
    if InCombatLockdown() then
        restorePending = true
        return
    end
    SetPlateCVar(FRIENDLY, saved.friendly)
    SetPlateCVar(ONLY_NAME, saved.onlyName)
    saved = nil
end

-- Devuelve true si la reaccion se pintara en cuanto aparezca su placa
function ns.ShowWithTempPlates(guid, code)
    -- Ya tiene las placas puestas (por su cuenta): el otro esta lejos
    if not saved and GetCVarBool(FRIENDLY) then return false end
    if not saved then
        -- En combate el cliente puede no dejar cambiarlas: un intento por combate
        if combatFailed then return false end
        local before = { friendly = GetCVar(FRIENDLY), onlyName = GetCVar(ONLY_NAME) }
        if not (SetPlateCVar(FRIENDLY, "1") and GetCVarBool(FRIENDLY)) then
            combatFailed = InCombatLockdown()
            return false
        end
        SetPlateCVar(ONLY_NAME, "1") -- solo el nombre: lo minimo para anclarla
        saved = before
    end
    waiting[guid] = { code, GetTime() + WAIT_PLATE }
    restoreAt = GetTime() + WAIT_PLATE + SHOW_TIME
    C_Timer.After(WAIT_PLATE + SHOW_TIME + 0.1, function()
        if GetTime() >= restoreAt then RestorePlates() end
    end)
    return true
end

-- Mientras las placas son del addon, imitan el nombre normal del juego: se
-- oculta lo que pintan (Blizzard o un addon de placas) y se pone el nombre con
-- su hermandad debajo, en letra pequena con contorno y el color de los
-- jugadores amistosos. Todo vuelve a su estado al quitar la placa (se reciclan).
local NAME_COLOR = { 0.55, 0.55, 1 }

local function HookAlpha(child)
    if child.emojiReactHooked then return end
    child.emojiReactHooked = true
    hooksecurefunc(child, "SetAlpha", function(self, alpha)
        if self.emojiReactHide and alpha > 0 then self:SetAlpha(0) end
    end)
end

local function MimicName(plate, unit)
    for _, child in ipairs({ plate:GetChildren() }) do
        if child ~= plate.emojiReactPop then
            HookAlpha(child)
            child.emojiReactHide = true
            child:SetAlpha(0)
        end
    end
    local label = plate.emojiReactName
    if not label then
        label = plate:CreateFontString(nil, "OVERLAY")
        label:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        label:SetPoint("BOTTOM", plate, "BOTTOM", 0, 4)
        label:SetJustifyH("CENTER")
        plate.emojiReactName = label
    end
    -- GetUnitName como las placas de Blizzard: en Forever trae el apellido
    -- ("Tengo Fimosis"); UnitName solo da el nombre ("Tengo")
    local name, guild = GetUnitName(unit, false), GetGuildInfo(unit)
    if not CanAccess(name, guild) or not name then return end
    label:SetText(guild and (name .. "\n<" .. guild .. ">") or name)
    label:SetTextColor(NAME_COLOR[1], NAME_COLOR[2], NAME_COLOR[3])
    label:Show()
end

local function UnmimicName(plate)
    if plate.emojiReactName then plate.emojiReactName:Hide() end
    for _, child in ipairs({ plate:GetChildren() }) do
        if child.emojiReactHide then
            child.emojiReactHide = false
            child:SetAlpha(1)
        end
    end
end

local function OnPlateAdded(unit)
    local guid = UnitGUID(unit)
    if not CanAccess(guid) or not guid then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if saved and plate and UnitIsPlayer(unit) and UnitIsFriend("player", unit) then
        MimicName(plate, unit)
        -- Los addons de placas montan lo suyo despues del evento
        C_Timer.After(0, function()
            if saved and C_NamePlate.GetNamePlateForUnit(unit) == plate then MimicName(plate, unit) end
        end)
    end
    local wait = waiting[guid]
    if not wait then return end
    waiting[guid] = nil
    if GetTime() <= wait[2] then ShowOnPlayer(guid, wait[1]) end
end

-- Version anterior (placas invisibles siempre): devolver los ajustes del jugador
local function RestoreOldVersion()
    local old = ns.db.savedCVars
    if not old or InCombatLockdown() then return end
    SetPlateCVar(FRIENDLY, old.friendly)
    SetPlateCVar(ONLY_NAME, old.onlyName)
    ns.db.savedCVars = nil
end

-- El aviso de abandonar el canal antiguo no sale en ninguna ventana de chat
local function IsOldChannel(_, _, ...)
    if not CanAccess(...) then return false end
    local channelString, baseName = select(4, ...), select(9, ...)
    return baseName == OLD_CHANNEL or (channelString or ""):find(OLD_CHANNEL, 1, true) ~= nil
end

-- ==========================================
-- TECLA DE LA RUEDA
-- ==========================================
-- Ventana "pulsa la tecla que quieras". Se guarda como un atajo normal del
-- juego, asi que tambien sale en Opciones > Atajos de teclado > AddOns.
-- Dos atajos: abrir la rueda y pasar de pagina (ademas de la rueda del raton).

local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, UNKNOWN = true }
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
local KEYS = {
    wheel = { binding = BINDING, capture = L.KEY_CAPTURE, set = L.KEY_SET },
    page = { binding = PAGE_BINDING, capture = L.PAGE_KEY_CAPTURE, set = L.PAGE_KEY_SET },
}

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

-- which: "wheel" (por defecto) o "page"
function ns.CurrentKey(which)
    local key = GetBindingKey(KEYS[which or "wheel"].binding)
    return key and GetBindingText(key) or L.KEY_NONE
end

local function Unbind(binding)
    for _, old in ipairs({ GetBindingKey(binding) }) do SetBinding(old) end
end

local function Bind(key)
    capture:Hide()
    if key == "ESCAPE" then return end
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    local info = KEYS[capture.which]
    -- Orden de modificadores que espera el juego: ALT-CTRL-SHIFT-
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    local previous = GetBindingAction(combo)
    Unbind(info.binding)
    SetBinding(combo, info.binding)
    SaveBindings(GetCurrentBindingSet())
    local msg = L.CHAT_PREFIX .. info.set:format(ns.CurrentKey(capture.which))
    if previous ~= "" and previous ~= info.binding then
        msg = msg .. " |cffff8800" .. L.KEY_REPLACED:format(_G["BINDING_NAME_" .. previous] or previous) .. "|r"
    end
    print(msg)
    if capture.onDone then capture.onDone() end
end

capture:SetScript("OnKeyDown", function(_, key) if not MODIFIERS[key] then Bind(key) end end)
capture:SetScript("OnMouseDown", function(_, button) if MOUSE[button] then Bind(MOUSE[button]) end end)

function ns.PickKey(onDone, which)
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    capture.which, capture.onDone = which or "wheel", onDone
    captureText:SetText(KEYS[capture.which].capture)
    capture:Show()
end

function ns.ClearKey(which)
    if InCombatLockdown() then print(L.CHAT_PREFIX .. L.KEY_COMBAT) return end
    Unbind(KEYS[which or "wheel"].binding)
    SaveBindings(GetCurrentBindingSet())
end

-- ==========================================
-- ARRANQUE
-- ==========================================

function ns.InitReactions()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", IsOldChannel)

    local hinted = false
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_ENTERING_WORLD" then
            if GetChannelName(OLD_CHANNEL) > 0 then LeaveChannelByName(OLD_CHANNEL) end
            RestoreOldVersion()
            if ns.db.reactions and not GetBindingKey(BINDING) and not hinted then
                hinted = true
                print(L.CHAT_PREFIX .. L.KEY_HINT)
            end
        elseif event == "CHAT_MSG_ADDON" then
            local prefix, text = ...
            if CanAccess(prefix) and prefix == PREFIX then Receive(text) end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            -- Las placas se reciclan: que la reaccion no se quede sobre otra unidad
            local plate = C_NamePlate.GetNamePlateForUnit(...)
            if plate and plate.emojiReactPop then plate.emojiReactPop:Hide() end
            if plate then UnmimicName(plate) end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            OnPlateAdded(...)
        elseif event == "PLAYER_REGEN_ENABLED" then
            combatFailed = false
            if restorePending then
                restorePending = false
                RestorePlates()
            end
        elseif event == "PLAYER_LOGOUT" and saved then
            -- Que no se queden encendidas si se sale a mitad de una reaccion
            SetCVar(FRIENDLY, saved.friendly)
            SetCVar(ONLY_NAME, saved.onlyName)
        end
    end)
end
