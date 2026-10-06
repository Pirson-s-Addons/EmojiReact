local _, ns = ...
local L = ns.L

-- ==========================================
-- PANEL DE EMOJIS (estilo WhatsApp, con aspecto de WoW)
-- ==========================================
-- Buscador arriba, pestanas de categoria, cuadricula con secciones y, abajo, la
-- vista previa del emoji senalado. Clic: lo escribe en el chat (":codigo: ") y
-- el panel sigue abierto. Clic derecho en uno con tonos de piel: elegir tono,
-- que se recuerda para ese emoji (como la pulsacion larga de WhatsApp).
--
-- La cuadricula es un ScrollBox (Blizzard_SharedXML/Shared/Scroll): solo existen
-- los marcos de las filas visibles, asi que ~1.900 emojis no cuestan nada.
-- Cada elemento de la lista es una fila: un titulo de seccion o COLS emojis.

local COLS, CELL, HEADER = 9, 34, 26
local WIDTH, HEIGHT = COLS * CELL + 48, 430
local MAX_RECENT = 2 * COLS
local GOLD = { 1, 0.82, 0 }

-- Pestanas en el orden de WhatsApp. La 1 son los recientes; el resto, las
-- categorias de Data/EmojiData.lua (numero de categoria = pestana - 1).
local TABS = {
    { "RECENT", "1f550" }, { "CAT_PEOPLE", "1f600" }, { "CAT_NATURE", "1f43b" },
    { "CAT_FOOD", "1f354" }, { "CAT_ACTIVITY", "26bd" }, { "CAT_TRAVEL", "1f697" },
    { "CAT_OBJECTS", "1f4a1" }, { "CAT_SYMBOLS", "1f523" }, { "CAT_FLAGS", "1f3f3" },
}

-- Emojis base de cada categoria, en el orden de los datos
local byTab = {}
for i = 1, #TABS do byTab[i] = {} end
for _, e in ipairs(ns.EMOJI_DATA) do
    table.insert(byTab[e[2] + 1], e[1])
end

-- ==========================================
-- BUSQUEDA
-- ==========================================
-- Texto de busqueda de cada emoji: sus codigos, el nombre y palabras clave en
-- ingles y en el idioma del cliente (Data/Search_*.lua), en minusculas y sin
-- tildes. Se monta la primera vez que se busca.

local ACCENTS = {
    ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["à"] = "a", ["è"] = "e",
    ["ì"] = "i", ["ò"] = "o", ["ù"] = "u", ["ä"] = "a", ["ë"] = "e", ["ï"] = "i", ["ö"] = "o",
    ["ü"] = "u", ["â"] = "a", ["ê"] = "e", ["î"] = "i", ["ô"] = "o", ["û"] = "u", ["ñ"] = "n",
    ["ç"] = "c", ["ã"] = "a", ["õ"] = "o", ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o",
    ["Ú"] = "u", ["Ñ"] = "n", ["Ü"] = "u", ["Ç"] = "c",
}

local function Fold(text)
    return (text:lower():gsub("\195[\128-\191]", ACCENTS))
end

local haystack

local function Search(query)
    if not haystack then
        haystack = {}
        local en, loc = ns.EMOJI_TEXT_EN or {}, ns.EMOJI_TEXT_LOCAL or {}
        for _, e in ipairs(ns.EMOJI_DATA) do
            local file = e[1]
            local parts = { table.concat(e, " ", 3) }
            if en[file] then parts[#parts + 1] = en[file][2] end
            if loc[file] then parts[#parts + 1] = loc[file][2] end
            haystack[#haystack + 1] = { file, (table.concat(parts, " "):gsub("_", " ")) }
        end
    end
    local words = {}
    for w in Fold(query):gsub("[:_]", " "):gmatch("%S+") do words[#words + 1] = w end
    local found = {}
    for _, h in ipairs(haystack) do
        local ok = true
        for _, w in ipairs(words) do
            if not h[2]:find(w, 1, true) then ok = false break end
        end
        if ok then found[#found + 1] = h[1] end
    end
    return found
end

ns.SearchEmoji = Search -- para tools/smoke_load.lua

-- Nombre del emoji en el idioma del cliente (o en ingles)
local function NameOf(file)
    local base = ns.BaseOf(file)
    local t = (ns.EMOJI_TEXT_LOCAL or {})[base] or (ns.EMOJI_TEXT_EN or {})[base]
    return t and t[1] or ns.CodeOf(file)
end

-- ==========================================
-- VENTANA
-- ==========================================

local picker = CreateFrame("Frame", "EmojiReactPicker", UIParent, "BasicFrameTemplateWithInset")
picker:SetSize(WIDTH, HEIGHT)
picker:SetFrameStrata("DIALOG")
picker:SetClampedToScreen(true)
picker:EnableMouse(true)
picker:Hide()
tinsert(UISpecialFrames, "EmojiReactPicker") -- Esc lo cierra

picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
picker.title:SetPoint("TOP", picker.TitleBg, "TOP", 0, -3)
picker.title:SetText("|cffd597ffEmoji & React|r")

local search = CreateFrame("EditBox", nil, picker, "SearchBoxTemplate")
search:SetSize(WIDTH - 36, 20)
search:SetPoint("TOPLEFT", 20, -30)
search:SetAutoFocus(false)
search.Instructions:SetText(L.SEARCH)

-- Pestanas: icono en gris; la activa en color y subrayada en dorado
local tabs = {}
local TAB = (WIDTH - 24) / #TABS
for i, t in ipairs(TABS) do
    local tab = CreateFrame("Button", nil, picker)
    tab:SetSize(TAB, 28)
    tab:SetPoint("TOPLEFT", 12 + (i - 1) * TAB, -54)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetSize(20, 20)
    tab.icon:SetPoint("CENTER", 0, 1)
    tab.icon:SetTexture(ns.EMOJI .. t[2])
    tab.bar = tab:CreateTexture(nil, "OVERLAY")
    tab.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
    tab.bar:SetSize(TAB - 8, 2)
    tab.bar:SetPoint("BOTTOM")
    tab:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L[t[1]])
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tabs[i] = tab
end

local divider = picker:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.1)
divider:SetPoint("TOPLEFT", 12, -83)
divider:SetPoint("TOPRIGHT", -12, -83)

local scrollBox = CreateFrame("Frame", nil, picker, "WowScrollBoxList")
scrollBox:SetPoint("TOPLEFT", 14, -88)
scrollBox:SetPoint("BOTTOMRIGHT", -26, 44)
local scrollBar = CreateFrame("EventFrame", nil, picker, "MinimalScrollBar")
scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)

-- Pie: vista previa del emoji senalado, o la ayuda
local footer = picker:CreateTexture(nil, "ARTWORK")
footer:SetColorTexture(1, 1, 1, 0.1)
footer:SetPoint("BOTTOMLEFT", 12, 40)
footer:SetPoint("BOTTOMRIGHT", -12, 40)
local preview = picker:CreateTexture(nil, "ARTWORK")
preview:SetSize(26, 26)
preview:SetPoint("BOTTOMLEFT", 16, 10)
local previewName = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
previewName:SetPoint("TOPLEFT", preview, "TOPRIGHT", 8, 0)
previewName:SetPoint("RIGHT", -12, 0)
previewName:SetJustifyH("LEFT")
previewName:SetWordWrap(false)
local previewCode = picker:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
previewCode:SetPoint("BOTTOMLEFT", preview, "BOTTOMRIGHT", 8, 0)
previewCode:SetPoint("RIGHT", -12, 0)
previewCode:SetJustifyH("LEFT")

local function ShowPreview(file)
    if file then
        preview:SetTexture(ns.EMOJI .. file)
        preview:Show()
        previewName:SetText(NameOf(file))
        local hint = ns.EMOJI_TONES[ns.BaseOf(file)] and ("  |cff888888" .. L.TONE_HINT .. "|r") or ""
        previewCode:SetText(":" .. ns.CodeOf(file) .. ":" .. hint)
    else
        preview:Hide()
        previewName:SetText("")
        previewCode:SetText(L.PICKER_HINT)
    end
end

-- ==========================================
-- ESCRIBIR, RECIENTES Y TONOS
-- ==========================================

local Refresh

-- Emoji que se ve para un emoji base: con el tono que se eligio para el
local function Shown(base)
    local tone = ns.db.tones[base]
    local tones = ns.EMOJI_TONES[base]
    return tone and tones and tones[tone] or base
end

local function Insert(file)
    local text = ":" .. ns.CodeOf(file) .. ": "
    local editBox = ChatFrameUtil.GetActiveWindow()
    if editBox then editBox:Insert(text) else ChatFrameUtil.OpenChat(text) end
    local recent = ns.db.recent
    for i = #recent, 1, -1 do
        if recent[i] == file then table.remove(recent, i) end
    end
    table.insert(recent, 1, file)
    recent[MAX_RECENT + 1] = nil
end

-- Selector de tono: el emoji sin tono y sus 5 tonos, encima del emoji
local tonePopup = CreateFrame("Frame", nil, picker, "TooltipBackdropTemplate")
tonePopup:SetSize(6 * CELL + 12, CELL + 12)
tonePopup:SetFrameStrata("FULLSCREEN_DIALOG")
tonePopup:Hide()
tonePopup.buttons = {}
for i = 1, 6 do
    local b = CreateFrame("Button", nil, tonePopup)
    b:SetSize(CELL - 4, CELL - 4)
    b:SetPoint("LEFT", 6 + (i - 1) * CELL, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(26, 26)
    b.icon:SetPoint("CENTER")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self)
        ns.db.tones[tonePopup.base] = self.tone -- nil = sin tono
        tonePopup:Hide()
        Insert(self.file)
        Refresh(true)
    end)
    b:SetScript("OnEnter", function(self) ShowPreview(self.file) end)
    tonePopup.buttons[i] = b
end

local function ShowTones(cell, base)
    local tones = ns.EMOJI_TONES[base]
    for i, b in ipairs(tonePopup.buttons) do
        b.tone = i > 1 and (i - 1) or nil
        b.file = i == 1 and base or tones[i - 1]
        b.icon:SetTexture(ns.EMOJI .. b.file)
    end
    tonePopup.base = base
    tonePopup:ClearAllPoints()
    tonePopup:SetPoint("BOTTOM", cell, "TOP", 0, 2)
    tonePopup:Show()
end

-- ==========================================
-- FILAS DE LA CUADRICULA
-- ==========================================

local function CellOnClick(self, button)
    if button == "RightButton" and ns.EMOJI_TONES[self.base] then
        ShowTones(self, self.base)
    else
        tonePopup:Hide()
        Insert(self.file)
    end
end

local function InitRow(frame, data)
    if not frame.cells then
        frame.header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.header:SetPoint("BOTTOMLEFT", 4, 6)
        frame.line = frame:CreateTexture(nil, "ARTWORK")
        frame.line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
        frame.line:SetHeight(1)
        frame.line:SetPoint("LEFT", frame.header, "RIGHT", 8, 0)
        frame.line:SetPoint("RIGHT", -4, 0)
        frame.cells = {}
        for i = 1, COLS do
            local c = CreateFrame("Button", nil, frame)
            c:SetSize(CELL, CELL)
            c:SetPoint("LEFT", (i - 1) * CELL, 0)
            c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            c.icon = c:CreateTexture(nil, "ARTWORK")
            c.icon:SetSize(26, 26)
            c.icon:SetPoint("CENTER")
            c:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            c:SetScript("OnClick", CellOnClick)
            c:SetScript("OnEnter", function(self) ShowPreview(self.file) end)
            c:SetScript("OnLeave", function() ShowPreview(nil) end)
            frame.cells[i] = c
        end
    end
    frame.header:SetShown(data.header ~= nil)
    frame.line:SetShown(data.header ~= nil)
    if data.header then frame.header:SetText(data.header) end
    for i, c in ipairs(frame.cells) do
        local file = data.files and data.files[i]
        c:SetShown(file ~= nil)
        if file then
            c.file, c.base = file, ns.BaseOf(file)
            c.icon:SetTexture(ns.EMOJI .. file)
        end
    end
end

local view = CreateScrollBoxListLinearView()
view:SetElementInitializer("Frame", InitRow)
view:SetElementExtentCalculator(function(_, data) return data.header and HEADER or CELL end)
ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

local headerIndex = {} -- pestana -> posicion de su titulo en la lista

local function AddSection(list, tab, title, files, shown)
    if #files == 0 then return end
    list[#list + 1] = { header = title, tab = tab }
    headerIndex[tab] = #list
    for i = 1, #files, COLS do
        local row = {}
        for j = i, math.min(i + COLS - 1, #files) do row[#row + 1] = shown and shown(files[j]) or files[j] end
        list[#list + 1] = { files = row, tab = tab }
    end
end

local function SetActiveTab(active)
    for i, tab in ipairs(tabs) do
        local on = i == active
        tab.icon:SetDesaturated(not on)
        tab.icon:SetAlpha(on and 1 or 0.55)
        tab.bar:SetShown(on)
    end
end

-- Vuelve a montar la lista (todas las categorias o el resultado de la busqueda)
function Refresh(keepScroll)
    local list, query = {}, search:GetText()
    wipe(headerIndex)
    if query ~= "" then
        local found = Search(query)
        if #found > 0 then
            AddSection(list, 0, L.RESULTS, found, Shown)
        else
            list[1] = { header = L.NO_RESULTS, tab = 0 }
        end
        SetActiveTab(0)
    else
        AddSection(list, 1, L.RECENT, ns.db.recent)
        for tab = 2, #TABS do AddSection(list, tab, L[TABS[tab][1]], byTab[tab], Shown) end
    end
    scrollBox:SetDataProvider(CreateDataProvider(list),
        keepScroll and ScrollBoxConstants.RetainScrollPosition or ScrollBoxConstants.DiscardScrollPosition)
end

-- La pestana activa sigue a la seccion que esta arriba del todo
scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
    if search:GetText() ~= "" then return end
    local data = scrollBox:GetDataProvider() and scrollBox:GetDataProvider():Find(scrollBox:GetDataIndexBegin())
    if data then SetActiveTab(data.tab) end
end)

for i, tab in ipairs(tabs) do
    tab:SetScript("OnClick", function()
        if search:GetText() ~= "" then search:SetText("") end
        if headerIndex[i] then
            scrollBox:ScrollToElementDataIndex(headerIndex[i], ScrollBoxConstants.AlignBegin)
            SetActiveTab(i)
        end
    end)
end

search:HookScript("OnTextChanged", function()
    tonePopup:Hide()
    Refresh(false)
    if search:GetText() == "" then SetActiveTab(#ns.db.recent > 0 and 1 or 2) end
end)

picker:SetScript("OnHide", function() tonePopup:Hide() end)

-- Abre/cierra el panel encima de la caja del chat
function ns.TogglePicker()
    if picker:IsShown() then
        picker:Hide()
        return
    end
    local editBox = DEFAULT_CHAT_FRAME.editBox
    picker:ClearAllPoints()
    if editBox and editBox:IsShown() then
        picker:SetPoint("BOTTOMRIGHT", editBox, "TOPRIGHT", 0, 4)
    else
        picker:SetPoint("BOTTOMLEFT", DEFAULT_CHAT_FRAME, "TOPLEFT", 0, 30)
    end
    search:SetText("")
    Refresh(false)
    SetActiveTab(#ns.db.recent > 0 and 1 or 2)
    ShowPreview(nil)
    picker:Show()
end
