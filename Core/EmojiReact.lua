-- Emoji & React: emojis en el chat y en los bocadillos, y una rueda de
-- reacciones (como la Ping Wheel del juego) que se ven encima de tu personaje.
-- Solo WoW Forever.
--
-- Core/Emojis.lua    lista de emojis y conversion de texto a texturas
-- Core/Chat.lua      filtro de chat, bocadillos y cuadricula de emojis
-- Core/Reactions.lua envio/recepcion, pintar la reaccion y tecla de la rueda
-- UI/Wheel.lua       la rueda (plantilla de la Ping Wheel del juego)
-- UI/Options.lua     panel de opciones (Opciones > AddOns)

local ADDON_NAME, ns = ...

ns.DEFAULTS = {
    chatEmojis = true,
    bubbleEmojis = true,
    emoticons = true,
    pickerButton = true,
    chatSize = 16,
    bubbleSize = 22,
    reactions = true,
    hideReactions = false, -- no mostrar las reacciones de los demas
    reactionSize = 56,
    selfHeight = 170,
    wheelScale = 1,
    recent = {}, -- ultimos emojis escritos desde el panel (ficheros)
    tones = {},  -- tono de piel elegido para cada emoji base (1..5)
    page = 1,
}

-- Huecos de la rueda (db.pages x ns.SLOTS; en cada pagina: arriba, izquierda,
-- abajo, derecha): las reacciones en orden, repitiendo si faltan
ns.DEFAULTS.pages = ns.PAGES
ns.DEFAULTS.slots = {}
for i = 1, ns.PAGES * ns.SLOTS do ns.DEFAULTS.slots[i] = ns.DefaultSlot(i) end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    EmojiReactDB = EmojiReactDB or {}
    local db = EmojiReactDB
    for key, value in pairs(ns.DEFAULTS) do
        if db[key] == nil then db[key] = type(value) == "table" and CopyTable(value) or value end
    end
    -- Paginas fuera de rango, huecos que faltan o con una reaccion quitada de la
    -- lista, y huecos de mas
    if type(db.pages) ~= "number" or db.pages < 1 then db.pages = ns.PAGES end
    db.pages = math.min(math.floor(db.pages), ns.MAX_PAGES)
    for i = 1, db.pages * ns.SLOTS do
        if not ns.REACTION_VALID[db.slots[i] or ""] then db.slots[i] = ns.DefaultSlot(i) end
    end
    for i = #db.slots, db.pages * ns.SLOTS + 1, -1 do db.slots[i] = nil end
    if db.page > db.pages then db.page = 1 end
    ns.db = db

    ns.InitChat()
    ns.InitReactions()
    ns.CreateOptions()
    self:UnregisterEvent("ADDON_LOADED")
end)
