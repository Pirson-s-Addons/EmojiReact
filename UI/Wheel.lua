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
-- Orden de la plantilla: 1 arriba, 2 izquierda, 3 abajo, 4 derecha.
-- Contrastado con Gethe/wow-ui-source, rama "forever".

ns.SLOTS, ns.PAGES = 4, 6

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
        wedges[i] = { type = code, text = (code:gsub("_", " ")) }
    end
    wheel:SelectionStart(wedges, false, nil)
    -- Sin atlas (icon = nil) la plantilla no toca el icono: se pone el emoji
    for _, wedge in ipairs(wheel.radialWheelWedgeButtons) do
        wedge.Icon:SetTexture(ns.REACTION .. wedge.type)
        wedge.Icon:SetSize(ICON, ICON)
    end
    pageText:SetText(L.PAGE_FMT:format(page, ns.PAGES))
end

wheel:SetScript("OnMouseWheel", function(_, delta)
    ns.db.page = (ns.db.page - delta - 1) % ns.PAGES + 1
    Show()
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
end)

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
