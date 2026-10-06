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
    reactionSize = 56,
    selfHeight = 170,
    wheelScale = 1,
    recent = {}, -- ultimos emojis escritos desde el panel (ficheros)
    tones = {},  -- tono de piel elegido para cada emoji base (1..5)
    page = 1,
}

-- Huecos de la rueda (ns.PAGES x ns.SLOTS; en cada pagina: arriba, izquierda,
-- abajo, derecha): las reacciones en orden, repitiendo si faltan
ns.DEFAULTS.slots = {}
for i = 1, ns.PAGES * ns.SLOTS do
    ns.DEFAULTS.slots[i] = ns.REACTIONS[(i - 1) % #ns.REACTIONS + 1]
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    EmojiReactDB = EmojiReactDB or {}
    local db = EmojiReactDB
    for key, value in pairs(ns.DEFAULTS) do
        if db[key] == nil then db[key] = type(value) == "table" and CopyTable(value) or value end
    end
    -- Huecos nuevos (la rueda empezo con 8) o con un emoji quitado de la lista
    for i, code in ipairs(ns.DEFAULTS.slots) do
        if not ns.REACTION_VALID[db.slots[i] or ""] then db.slots[i] = code end
    end
    if db.page > ns.PAGES then db.page = 1 end
    ns.db = db

    ns.InitChat()
    ns.InitReactions()
    ns.CreateOptions()
    self:UnregisterEvent("ADDON_LOADED")
end)
