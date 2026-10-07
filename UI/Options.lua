local ADDON_NAME, ns = ...
local L = ns.L

-- ==========================================
-- OPCIONES
-- ==========================================
-- Raiz "Acerca de" (UI/About.lua) y, colgando de ella, dos paneles propios con
-- la plantilla de todos los addons de Pirson (titulo, logo con version,
-- secciones en morado y "Valores por defecto"):
--   * General: el chat.
--   * Reacciones: la rueda a la vista para elegir la reaccion de cada hueco,
--     paginas que se anaden y se quitan, y el resto de ajustes de reacciones.

local HEADER = "|cffC47FF3"
local GOLD = "|cffffff00"
-- Margen izquierdo y derecho iguales (el del logo); la columna de la derecha va
-- pegada al borde derecho y todo se reajusta al cambiar el ancho de la ventana.
local X, RIGHT = 16, 38
local SLIDER_W = 240

local function AddTooltip(widget, text)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Panel vacio con titulo, logo y version, y los controles de la plantilla.
-- Cada control se apunta en ui.widgets y se refresca en OnShow.
local function NewPanel(titleText)
    local db = ns.db
    local panel = CreateFrame("Frame")
    panel:Hide() -- nace oculto: si no, el Show() al abrir la categoria no dispara OnShow
    local ui = { panel = panel, widgets = {}, labels = {} }

    -- Los textos de la columna izquierda no pueden meterse bajo los deslizadores
    local function FitLabels()
        local width = math.max(120, panel:GetWidth() - X - RIGHT - SLIDER_W - 60)
        for _, label in ipairs(ui.labels) do label:SetWidth(width) end
    end
    panel:SetScript("OnSizeChanged", FitLabels)

    function ui.Header(y, text)
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("TOPLEFT", X, y)
        fs:SetText(HEADER .. text .. "|r")
        return fs
    end

    function ui.Separator(y)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.1)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", X, y)
        line:SetPoint("TOPRIGHT", -RIGHT, y)
    end

    function ui.Checkbox(key, label, tooltip, y, onChange)
        local cb = CreateFrame("CheckButton", "EmojiReact_" .. key, panel, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", X, y)
        local text = _G[cb:GetName() .. "Text"]
        text:SetText(label)
        text:SetJustifyH("LEFT")
        ui.labels[#ui.labels + 1] = text
        cb:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            if onChange then onChange() end
        end)
        AddTooltip(cb, tooltip)
        cb.Refresh = function(self) self:SetChecked(db[key]) end
        ui.widgets[#ui.widgets + 1] = cb
        return cb
    end

    -- En la columna de la derecha, o en la izquierda con left = true
    function ui.Slider(key, label, tooltip, y, min, max, step, onChange, left)
        local slider = CreateFrame("Slider", "EmojiReact_" .. key, panel, "OptionsSliderTemplate")
        if left then slider:SetPoint("TOPLEFT", X + 10, y) else slider:SetPoint("TOPRIGHT", -RIGHT, y) end
        slider:SetWidth(SLIDER_W)
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
            if onChange then onChange() end
        end)
        AddTooltip(slider, tooltip)
        slider.Refresh = function(self)
            self:SetValue(db[key])
            Label()
            if onChange then onChange() end
        end
        ui.widgets[#ui.widgets + 1] = slider
        return slider
    end

    function ui.Button(text, width, tooltip, onClick, parent)
        local b = CreateFrame("Button", nil, parent or panel, "UIPanelButtonTemplate")
        b:SetSize(width, 26)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        if tooltip then AddTooltip(b, tooltip) end
        return b
    end

    function ui.Refresh()
        FitLabels()
        for _, widget in ipairs(ui.widgets) do widget:Refresh() end
        if ui.OnRefresh then ui.OnRefresh() end
    end
    panel:SetScript("OnShow", ui.Refresh)

    -- "Valores por defecto" de los ajustes de este panel
    function ui.ResetButton(keys, y, after)
        local reset = ui.Button(L.DEFAULTS, 180, nil, function()
            for _, key in ipairs(keys) do
                local value = ns.DEFAULTS[key]
                db[key] = type(value) == "table" and CopyTable(value) or value
            end
            if after then after() end
            ui.Refresh()
        end)
        reset:SetPoint("TOPLEFT", X, y)
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", X, -16)
    title:SetText(titleText)

    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(110, 110)
    logo:SetPoint("TOPRIGHT", -RIGHT, -5)
    logo:SetTexture(ns.LOGO)
    ui.logo = logo

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    version:SetPoint("TOP", logo, "BOTTOM", 0, -2)
    version:SetText("v" .. (C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"))

    return ui
end

-- ==========================================
-- GENERAL (CHAT)
-- ==========================================

local function CreateGeneral()
    local db = ns.db
    local ui = NewPanel(L.OPTIONS_TITLE)
    ui.Header(-60, L.CHAT_HEADER)
    ui.Checkbox("chatEmojis", L.CHAT_EMOJIS, L.CHAT_EMOJIS_TOOLTIP, -88)
    ui.Checkbox("bubbleEmojis", L.BUBBLE_EMOJIS, L.BUBBLE_EMOJIS_TOOLTIP, -120)
    ui.Checkbox("emoticons", L.EMOTICONS, L.EMOTICONS_TOOLTIP, -152)
    ui.Checkbox("pickerButton", L.PICKER_BUTTON, L.PICKER_BUTTON_TOOLTIP, -184, ns.ApplyPickerButton)
    ui.Separator(-226)

    -- Tamanos, cada uno con una muestra de como se veran los emojis
    ui.Header(-242, L.SIZES_HEADER)
    local SAMPLE = ":joy: :heart_eyes: :thumbsup: :fire:"
    local function Preview(slider, key)
        local fs = ui.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("TOP", slider, "BOTTOM", 0, -24)
        return function() fs:SetText(ns.Emojify(SAMPLE, db[key], false)) end
    end
    local chatPreview, bubblePreview
    local chat = ui.Slider("chatSize", L.CHAT_SIZE, L.CHAT_SIZE_TOOLTIP, -290, 10, 32, 1,
        function() if chatPreview then chatPreview() end end, true)
    local bubble = ui.Slider("bubbleSize", L.BUBBLE_SIZE, L.BUBBLE_SIZE_TOOLTIP, -290, 10, 40, 1,
        function() if bubblePreview then bubblePreview() end end)
    chatPreview, bubblePreview = Preview(chat, "chatSize"), Preview(bubble, "bubbleSize")
    ui.Separator(-390)
    ui.ResetButton({ "chatEmojis", "bubbleEmojis", "emoticons", "pickerButton", "chatSize", "bubbleSize" },
        -406, ns.ApplyPickerButton)
    return ui.panel
end

-- ==========================================
-- REACCIONES
-- ==========================================
-- Arriba la rueda como se ve en el juego (fondo y marco de la Ping Wheel) con
-- los 4 huecos de la pagina elegida: clic en un hueco y luego en una reaccion
-- de la cuadricula. Debajo, las paginas: ver, anadir (+) y quitar la actual (-).

local WHEEL, SLOT, RADIUS = 210, 52, 70
-- Orden de la rueda del juego: 1 arriba, 2 izquierda, 3 abajo, 4 derecha
local SLOT_OFFSETS = { { 0, RADIUS }, { -RADIUS, 0 }, { 0, -RADIUS }, { RADIUS, 0 } }
local GRID_COLS, GRID_CELL = 5, 48

local function CreateReactions()
    local db = ns.db
    local ui = NewPanel(L.REACTIONS_TITLE)
    local panel = ui.panel
    local reactionWidgets = {}
    local page, selected = 1, 1

    -- Todo lo de este panel cuelga de "Activar reacciones"
    local function UpdateEnabled()
        for _, widget in ipairs(reactionWidgets) do
            widget:SetEnabled(db.reactions)
            widget:SetAlpha(db.reactions and 1 or 0.5)
        end
    end

    ui.Header(-56, L.WHEEL_HEADER)

    -- Vista previa de la rueda
    local wheel = CreateFrame("Frame", nil, panel)
    wheel:SetSize(WHEEL, WHEEL)
    wheel:SetPoint("TOPLEFT", X + 6, -76)
    local bg = wheel:CreateTexture(nil, "BACKGROUND")
    bg:SetAtlas("Radial_Wheel_BG")
    bg:SetAllPoints()
    local ring = wheel:CreateTexture(nil, "BORDER")
    ring:SetAtlas("Radial_Wheel_Frame_Count_" .. ns.SLOTS)
    ring:SetAllPoints()
    local pageLabel = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    pageLabel:SetPoint("CENTER")

    -- Cuadricula con todas las reacciones, a la derecha de la rueda
    local pick = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pick:SetPoint("TOPLEFT", wheel, "TOPRIGHT", 24, -4)
    pick:SetText(GOLD .. L.PICK_HEADER .. "|r")
    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", ui.logo, "LEFT", -10, 0) -- sin meterse bajo el logo
    hint:SetJustifyH("LEFT")
    hint:SetText(L.PICK_HINT)
    local selectedText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    selectedText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
    selectedText:SetPoint("RIGHT", ui.logo, "LEFT", -10, 0)
    selectedText:SetJustifyH("LEFT")

    local slots, cells, tabs = {}, {}, {}
    local Refresh

    local function Index(i) return (page - 1) * ns.SLOTS + (i or selected) end

    local function Mark(button, on)
        button.mark:SetShown(on)
    end

    local function NewMark(button, size)
        button.mark = button:CreateTexture(nil, "OVERLAY")
        button.mark:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        button.mark:SetBlendMode("ADD")
        button.mark:SetSize(size, size)
        button.mark:SetPoint("CENTER")
        button.mark:Hide()
    end

    for i = 1, ns.SLOTS do
        local slot = CreateFrame("Button", nil, wheel)
        slot:SetSize(SLOT, SLOT)
        slot:SetPoint("CENTER", SLOT_OFFSETS[i][1], SLOT_OFFSETS[i][2])
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        NewMark(slot, SLOT * 1.8)
        slot:SetScript("OnClick", function()
            selected = i
            Refresh()
        end)
        AddTooltip(slot, L.SLOT_TOOLTIP)
        slots[i] = slot
        reactionWidgets[#reactionWidgets + 1] = slot
    end

    for i, code in ipairs(ns.REACTIONS) do
        local cell = CreateFrame("Button", nil, panel)
        cell:SetSize(GRID_CELL - 6, GRID_CELL - 6)
        cell:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT",
            (i - 1) % GRID_COLS * GRID_CELL, -10 - math.floor((i - 1) / GRID_COLS) * GRID_CELL)
        cell:SetNormalTexture(ns.REACTION .. code)
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        NewMark(cell, GRID_CELL * 1.7)
        cell:SetScript("OnClick", function()
            db.slots[Index()] = code
            Refresh()
        end)
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns.ReactionName(code))
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cell.code = code
        cells[i] = cell
        reactionWidgets[#reactionWidgets + 1] = cell
    end

    -- Paginas: una pestana por pagina, "+" anade una al final, "-" quita la actual
    local pagesLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    pagesLabel:SetPoint("TOPLEFT", wheel, "BOTTOMLEFT", -2, -12)
    pagesLabel:SetText(L.SLOTS)

    for p = 1, ns.MAX_PAGES do
        local tab = ui.Button(p, 26, L.PAGE_TOOLTIP, function()
            page = p
            Refresh()
        end)
        tab:SetPoint("LEFT", pagesLabel, "RIGHT", 8 + (p - 1) * 28, 0)
        tabs[p] = tab
        reactionWidgets[#reactionWidgets + 1] = tab
    end
    local add = ui.Button("+", 26, L.ADD_PAGE_TOOLTIP, function()
        ns.AddPage()
        page = db.pages
        Refresh()
    end)
    local remove = ui.Button("-", 26, L.REMOVE_PAGE_TOOLTIP, function()
        ns.RemovePage(page)
        page = math.min(page, db.pages)
        Refresh()
    end)
    reactionWidgets[#reactionWidgets + 1] = add
    reactionWidgets[#reactionWidgets + 1] = remove

    function Refresh()
        page = math.min(page, db.pages)
        pageLabel:SetText(page .. "/" .. db.pages)
        local current = db.slots[Index()]
        for i, slot in ipairs(slots) do
            slot.icon:SetTexture(ns.REACTION .. db.slots[Index(i)])
            Mark(slot, i == selected)
        end
        for _, cell in ipairs(cells) do Mark(cell, cell.code == current) end
        selectedText:SetText(L.SLOT_SELECTED:format(selected, ns.ReactionName(current)))
        -- Pestanas de las paginas que hay, y +/- detras de la ultima
        for p, tab in ipairs(tabs) do
            tab:SetShown(p <= db.pages)
            if p == page then tab:LockHighlight() else tab:UnlockHighlight() end
        end
        add:SetPoint("LEFT", tabs[db.pages], "RIGHT", 8, 0)
        remove:SetPoint("LEFT", add, "RIGHT", 2, 0)
        UpdateEnabled()
        add:SetEnabled(db.reactions and db.pages < ns.MAX_PAGES)
        remove:SetEnabled(db.reactions and db.pages > 1)
    end
    ui.OnRefresh = Refresh

    -- Opciones
    ui.Separator(-332)
    ui.Header(-346, L.OPTIONS_HEADER)
    ui.Checkbox("reactions", L.REACTIONS, L.REACTIONS_TOOLTIP, -368, function() Refresh() end)
    -- Las de los demas; las tuyas se siguen enviando
    reactionWidgets[#reactionWidgets + 1] =
        ui.Checkbox("hideReactions", L.HIDE_REACTIONS, L.HIDE_REACTIONS_TOOLTIP, -394)

    -- Fila "etiqueta + tecla + Borrar" de un atajo (which: "wheel" o "page")
    local function KeyRow(y, label, tooltip, which)
        local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("TOPLEFT", X + 4, y)
        text:SetText(label)
        local button
        button = ui.Button("", 130, tooltip, function()
            button:SetText(L.KEY_WAITING)
            ns.PickKey(function() button:SetText(ns.CurrentKey(which)) end, which)
        end)
        button:SetPoint("LEFT", text, "RIGHT", 10, 0)
        button.Refresh = function(self) self:SetText(ns.CurrentKey(which)) end
        ui.widgets[#ui.widgets + 1] = button
        local clear = ui.Button(L.KEY_CLEAR, 70, nil, function()
            ns.ClearKey(which)
            button:SetText(ns.CurrentKey(which))
        end)
        clear:SetPoint("LEFT", button, "RIGHT", 4, 0)
        reactionWidgets[#reactionWidgets + 1] = button
        reactionWidgets[#reactionWidgets + 1] = clear
    end
    KeyRow(-436, L.KEY, L.KEY_TOOLTIP, "wheel")
    KeyRow(-466, L.PAGE_KEY, L.PAGE_KEY_TOOLTIP, "page")
    local test = ui.Button(L.TEST, 120, L.TEST_TOOLTIP, function() ns.ShowOnSelf(db.slots[Index()]) end)
    test:SetPoint("TOPLEFT", X + 4, -498)

    for _, widget in ipairs({ test,
        ui.Slider("reactionSize", L.REACTION_SIZE, L.REACTION_SIZE_TOOLTIP, -380, 24, 128, 4),
        ui.Slider("selfHeight", L.SELF_HEIGHT, L.SELF_HEIGHT_TOOLTIP, -428, 0, 500, 10),
        ui.Slider("wheelScale", L.WHEEL_SCALE, L.WHEEL_SCALE_TOOLTIP, -476, 0.6, 1.6, 0.1) }) do
        reactionWidgets[#reactionWidgets + 1] = widget
    end

    -- Las teclas no se tocan: son atajos del juego y se quitan con "Borrar"
    ui.Separator(-534)
    ui.ResetButton({ "reactions", "hideReactions", "reactionSize", "selfHeight", "wheelScale", "slots", "pages", "page" },
        -548, function() page, selected = 1, 1 end)
    return ui.panel
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
            { "/emoji wheel", L.CMD_WHEEL },
            { "/emoji panel", L.CMD_PICKER },
            { "/emoji key", L.CMD_KEY },
            { "/emoji test", L.CMD_TEST },
        },
    })
    local general = Settings.RegisterCanvasLayoutSubcategory(root, CreateGeneral(), L.GENERAL)
    local reactions = Settings.RegisterCanvasLayoutSubcategory(root, CreateReactions(), L.REACTIONS_TAB)

    SLASH_EMOJIREACT1 = "/emoji"
    SlashCmdList.EMOJIREACT = function(input)
        local cmd = strtrim(input or ""):lower()
        if cmd == "key" then
            ns.PickKey()
        elseif cmd == "test" then
            ns.ShowOnSelf()
        elseif cmd == "panel" then
            ns.TogglePicker()
        elseif cmd == "wheel" then
            Settings.OpenToCategory(reactions:GetID())
        else
            Settings.OpenToCategory(general:GetID())
        end
    end
end
