local ADDON_NAME, ns = ...
local L = ns.L

-- ==========================================
-- OPCIONES
-- ==========================================
-- Raiz "Acerca de" (UI/About.lua) y, colgando de ella, "General" con los
-- ajustes: panel propio con la plantilla de todos los addons de Pirson
-- (titulo, logo con version, secciones en morado y "Valores por defecto").
-- Dos columnas: interruptores a la izquierda, deslizadores a la derecha.

local HEADER = "|cffC47FF3"
local X, X2 = 16, 340
local FRIENDLY_CVAR = "nameplateShowFriendlyPlayers"

local function AddTooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Header(panel, y, text)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", X, y)
    fs:SetText(HEADER .. text .. "|r")
end

local function Separator(panel, y)
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.1)
    line:SetSize(580, 1)
    line:SetPoint("TOPLEFT", X, y)
end

local function CreateGeneral()
    local db = ns.db
    local panel = CreateFrame("Frame")
    panel:Hide() -- nace oculto: si no, el Show() al abrir la categoria no dispara OnShow
    local widgets, reactionWidgets = {}, {}

    local function Checkbox(key, label, tooltip, y, onChange)
        local cb = CreateFrame("CheckButton", "EmojiReact_" .. key, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", X, y)
        _G[cb:GetName() .. "Text"]:SetText(label)
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            if onChange then onChange() end
        end)
        AddTooltip(cb, tooltip)
        cb.Refresh = function(self) self:SetChecked(db[key]) end
        widgets[#widgets + 1] = cb
        return cb
    end

    local function Slider(key, label, tooltip, y, min, max, step)
        local slider = CreateFrame("Slider", "EmojiReact_" .. key, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", X2, y)
        slider:SetWidth(240)
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        local name = slider:GetName()
        _G[name .. "Low"]:SetText(min)
        _G[name .. "High"]:SetText(max)
        local function Label() _G[name .. "Text"]:SetText(label .. ": " .. db[key]) end
        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / step + 0.5) * step
            if value == db[key] then return end
            db[key] = value
            Label()
        end)
        AddTooltip(slider, tooltip)
        slider.Refresh = function(self)
            self:SetValue(db[key])
            Label()
        end
        widgets[#widgets + 1] = slider
        return slider
    end

    local function Button(text, width, tooltip, onClick)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(width, 24)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        if tooltip then AddTooltip(b, tooltip) end
        return b
    end

    -- Las opciones de reacciones cuelgan del interruptor: apagado, se ven desactivadas
    local function UpdateReactionWidgets()
        for _, widget in ipairs(reactionWidgets) do
            widget:SetEnabled(db.reactions)
            widget:SetAlpha(db.reactions and 1 or 0.5)
        end
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", X, -16)
    title:SetText(L.OPTIONS_TITLE)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(110, 110)
    logo:SetPoint("TOPRIGHT", -38, -5)
    logo:SetTexture(ns.LOGO)

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOP", logo, "BOTTOM", 0, -2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))

    -- Chat
    Header(panel, -56, L.CHAT_HEADER)
    Checkbox("chatEmojis", L.CHAT_EMOJIS, L.CHAT_EMOJIS_TOOLTIP, -81)
    Checkbox("bubbleEmojis", L.BUBBLE_EMOJIS, L.BUBBLE_EMOJIS_TOOLTIP, -106)
    Checkbox("emoticons", L.EMOTICONS, L.EMOTICONS_TOOLTIP, -131)
    Checkbox("pickerButton", L.PICKER_BUTTON, L.PICKER_BUTTON_TOOLTIP, -156, ns.ApplyPickerButton)
    Slider("chatSize", L.CHAT_SIZE, L.CHAT_SIZE_TOOLTIP, -150, 10, 32, 1)
    Slider("bubbleSize", L.BUBBLE_SIZE, L.BUBBLE_SIZE_TOOLTIP, -198, 10, 40, 1)
    Separator(panel, -236)

    -- Reacciones
    Header(panel, -252, L.REACTIONS_HEADER)
    Checkbox("reactions", L.REACTIONS, L.REACTIONS_TOOLTIP, -277, UpdateReactionWidgets)

    local keyLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    keyLabel:SetPoint("TOPLEFT", X + 4, -318)
    keyLabel:SetText(L.KEY)
    local keyButton
    keyButton = Button("", 130, L.KEY_TOOLTIP, function()
        keyButton:SetText(L.KEY_WAITING)
        ns.PickKey(function() keyButton:SetText(ns.CurrentKey()) end)
    end)
    keyButton:SetPoint("LEFT", keyLabel, "RIGHT", 10, 0)
    local clearButton = Button(L.KEY_CLEAR, 70, nil, function()
        ns.ClearKey()
        keyButton:SetText(ns.CurrentKey())
    end)
    clearButton:SetPoint("LEFT", keyButton, "RIGHT", 4, 0)

    -- No es un ajuste del addon: es la opcion del juego "Placas de jugadores amistosos"
    local friendly = CreateFrame("CheckButton", "EmojiReact_friendlyPlates", panel, "InterfaceOptionsCheckButtonTemplate")
    friendly:SetPoint("TOPLEFT", X, -344)
    _G[friendly:GetName() .. "Text"]:SetText(L.FRIENDLY_PLATES)
    friendly:SetScript("OnClick", function(self)
        if InCombatLockdown() then
            self:SetChecked(GetCVarBool(FRIENDLY_CVAR))
            print(L.CHAT_PREFIX .. L.KEY_COMBAT)
            return
        end
        SetCVar(FRIENDLY_CVAR, self:GetChecked() and "1" or "0")
        -- Solo el nombre, sin barra de vida: molesta poco y basta para anclar la reaccion
        if self:GetChecked() then SetCVar("nameplateShowOnlyNameForFriendlyPlayerUnits", "1") end
    end)
    AddTooltip(friendly, L.FRIENDLY_PLATES_TOOLTIP)
    friendly.Refresh = function(self) self:SetChecked(GetCVarBool(FRIENDLY_CVAR)) end
    widgets[#widgets + 1] = friendly

    local size = Slider("reactionSize", L.REACTION_SIZE, L.REACTION_SIZE_TOOLTIP, -290, 24, 128, 4)
    local height = Slider("selfHeight", L.SELF_HEIGHT, L.SELF_HEIGHT_TOOLTIP, -338, 0, 500, 10)
    local wheelScale = Slider("wheelScale", L.WHEEL_SCALE, L.WHEEL_SCALE_TOOLTIP, -386, 0.6, 1.6, 0.1)
    local test = Button(L.TEST, 120, L.TEST_TOOLTIP, function() ns.ShowOnSelf() end)
    test:SetPoint("TOPLEFT", X2, -424)

    -- Huecos de la rueda: una pagina a la vista; clic en un hueco para elegir su emoji
    local page = 1
    local slotsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    slotsLabel:SetPoint("TOPLEFT", X + 4, -386)
    slotsLabel:SetText(L.SLOTS)
    local slots, tabs = {}, {}
    local function ShowPage(p)
        page = p
        for i, tab in ipairs(tabs) do
            if i == page then tab:LockHighlight() else tab:UnlockHighlight() end
        end
        for _, slot in ipairs(slots) do slot:Refresh() end
    end
    for p = 1, ns.PAGES do
        local tab = Button(p, 26, L.PAGE_TOOLTIP, function() ShowPage(p) end)
        tab:SetPoint("LEFT", slotsLabel, "RIGHT", 8 + (p - 1) * 28, 0)
        tabs[p] = tab
    end
    for i = 1, ns.SLOTS do
        local slot = CreateFrame("Button", nil, panel)
        slot:SetSize(36, 36)
        slot:SetPoint("TOPLEFT", X + 4 + (i - 1) * 40, -410)
        slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        local number = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        number:SetPoint("TOP", slot, "BOTTOM", 0, -2)
        number:SetText(i)
        local function Index() return (page - 1) * ns.SLOTS + i end
        slot:SetScript("OnClick", function(self)
            ns.ToggleEmojiGrid(self, function(code)
                db.slots[Index()] = code
                self:SetNormalTexture(ns.EMOJI .. code)
            end)
        end)
        AddTooltip(slot, L.SLOT_TOOLTIP)
        slot.Refresh = function(self) self:SetNormalTexture(ns.EMOJI .. db.slots[Index()]) end
        widgets[#widgets + 1] = slot
        slots[i] = slot
    end

    for _, widget in ipairs({ keyButton, clearButton, friendly, size, height, wheelScale, test, unpack(slots) }) do
        reactionWidgets[#reactionWidgets + 1] = widget
    end
    for _, tab in ipairs(tabs) do reactionWidgets[#reactionWidgets + 1] = tab end
    Separator(panel, -476)

    local function Refresh()
        for _, widget in ipairs(widgets) do widget:Refresh() end
        keyButton:SetText(ns.CurrentKey())
        ShowPage(page)
        UpdateReactionWidgets()
    end
    panel:SetScript("OnShow", Refresh)

    -- La tecla no se toca: es un atajo del juego y se quita con "Borrar"
    local reset = Button(L.DEFAULTS, 180, nil, function()
        for key, value in pairs(ns.DEFAULTS) do
            db[key] = type(value) == "table" and CopyTable(value) or value
        end
        ns.ApplyPickerButton()
        Refresh()
    end)
    reset:SetPoint("TOPLEFT", X, -492)

    return panel
end

function ns.CreateOptions()
    ns.LOGO = ns.IMG .. "logo_er"
    local root = ns.CreateAbout({
        name = "Emoji & React",
        logo = ns.LOGO,
        github = "https://github.com/Pirson-s-Addons/EmojiReact",
        curseforge = "https://www.curseforge.com/wow/addons/emoji-react",
        commands = {
            { "/emoji", L.CMD_OPEN },
            { "/emoji key", L.CMD_KEY },
            { "/emoji test", L.CMD_TEST },
            { "/emoji status", L.CMD_STATUS },
        },
    })
    local general = Settings.RegisterCanvasLayoutSubcategory(root, CreateGeneral(), L.GENERAL)

    SLASH_EMOJIREACT1 = "/emoji"
    SlashCmdList.EMOJIREACT = function(input)
        local cmd = strtrim(input or ""):lower()
        if cmd == "key" then
            ns.PickKey()
        elseif cmd == "test" then
            ns.ShowOnSelf()
        elseif cmd == "status" then
            ns.Status()
        else
            Settings.OpenToCategory(general:GetID())
        end
    end
end
