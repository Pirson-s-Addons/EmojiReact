local _, ns = ...
local L = ns.L

-- ==========================================
-- RUEDA DE REACCIONES (la del juego: Ping Wheel)
-- ==========================================
-- Usa la misma plantilla que la rueda de avisos (ping) de Blizzard,
-- RadialWheelFrameTemplate (Blizzard_SharedXML/Blizzard_RadialWheel.xml): fondo,
-- marco en X, puntero que gira con el raton, "X" central para cancelar y sus
-- animaciones. Solo cambian los iconos: emojis en vez de los atlas del ping.
--
-- El juego solo trae el marco para 4 porciones (Radial_Wheel_Frame_Count_4),
-- asi que son 4 reacciones por pagina y la rueda del raton pasa de pagina.
-- El numero de paginas lo elige el jugador (db.pages).
-- Orden de la plantilla: 1 arriba, 2 izquierda, 3 abajo, 4 derecha.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

ns.SLOTS = 4
-- Paginas por defecto: las justas para todas las reacciones. El jugador anade
-- o quita paginas en Opciones > Reacciones (ns.AddPage / ns.RemovePage).
ns.PAGES = math.max(1, math.ceil(#ns.REACTIONS / ns.SLOTS))
ns.MAX_PAGES = 10

-- Reaccion por defecto del hueco i: las reacciones en orden, repitiendo
function ns.DefaultSlot(i)
    return ns.REACTIONS[(i - 1) % #ns.REACTIONS + 1]
end

function ns.AddPage()
    local db = ns.db
    if db.pages >= ns.MAX_PAGES then return end
    db.pages = db.pages + 1
    for i = (db.pages - 1) * ns.SLOTS + 1, db.pages * ns.SLOTS do db.slots[i] = ns.DefaultSlot(i) end
end

function ns.RemovePage(p)
    local db = ns.db
    if db.pages <= 1 then return end
    for _ = 1, ns.SLOTS do table.remove(db.slots, (p - 1) * ns.SLOTS + 1) end
    db.pages = db.pages - 1
    if db.page > db.pages then db.page = db.pages end
end

local ICON = 48

-- La plantilla calcula la porcion con el centro de radialParent: un punto que
-- se coloca donde esta el raton al abrir (igual que hace PingFrame)
local anchor = CreateFrame("Frame", nil, UIParent)
anchor:SetSize(1, 1)

local wheel = CreateFrame("Frame", "EmojiReactWheel", UIParent, "RadialWheelFrameTemplate")
wheel.radialParent = anchor
wheel:SetPoint("CENTER", anchor)
wheel:SetFrameStrata("FULLSCREEN_DIALOG")
wheel:EnableMouseWheel(true)

local pageText = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
pageText:SetPoint("TOP", wheel, "BOTTOM", 0, 10)

local function Show()
    local page, wedges = ns.db.page, {}
    for i = 1, ns.SLOTS do
        local code = ns.db.slots[(page - 1) * ns.SLOTS + i]
        wedges[i] = { type = code, text = ns.ReactionName(code) }
    end
    wheel:SelectionStart(wedges, false, nil)
    -- Sin atlas (icon = nil) la plantilla no toca el icono: se pone el emoji
    for _, wedge in ipairs(wheel.radialWheelWedgeButtons) do
        wedge.Icon:SetTexture(ns.REACTION .. wedge.type)
        wedge.Icon:SetSize(ICON, ICON)
    end
    pageText:SetText(L.PAGE_FMT:format(page, ns.db.pages))
end

local function Turn(delta)
    ns.db.page = (ns.db.page - delta - 1) % ns.db.pages + 1
    Show()
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
end
wheel:SetScript("OnMouseWheel", function(_, delta) Turn(delta) end)

-- Atajo "pagina siguiente" de Bindings.xml: solo con la rueda abierta
function EmojiReact_NextPage()
    if wheel:IsShown() and not wheel.isWheelClosing then Turn(-1) end
end

-- Lo llama el atajo de Bindings.xml: pulsar abre en el raton, soltar elige
function EmojiReact_Wheel(keystate)
    if not ns.db.reactions then return end
    if keystate == "down" then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        wheel:SetScale(ns.db.wheelScale)
        Show()
    elseif wheel:IsShown() and not wheel.isWheelClosing then
        local selected = wheel:SelectionEnd() -- nil si se suelta en la "X" del centro
        wheel:AnimateOutro()
        if selected then ns.React(selected.type) end
    end
end
