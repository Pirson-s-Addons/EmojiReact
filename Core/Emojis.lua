local ADDON_NAME, ns = ...

-- ==========================================
-- EMOJIS
-- ==========================================
-- Lista de emojis y conversion de texto a texturas |T...|t. WoW no pinta
-- emojis Unicode: cada uno es una imagen del addon (img/emoji/<codigo>.tga,
-- 32 bits con alfa, 64x64). Imagenes de Twemoji (CC-BY 4.0), ver CREDITS.txt.

ns.IMG = "Interface\\AddOns\\" .. ADDON_NAME .. "\\img\\"
ns.EMOJI = ns.IMG .. "emoji\\"
-- Las reacciones son otro juego de imagenes: el mismo emoji en estilo pegatina
-- (borde blanco y sombra, 128x128), para que no se confundan con los del chat.
ns.REACTION = ns.IMG .. "reaction\\"

-- { codigo, codepoint de Twemoji }. Este orden es el de la cuadricula.
-- tools/make_textures.py lee esta lista para generar las imagenes (chat y reacciones).
ns.EMOJIS = {
    { "smile", "1f604" }, { "grin", "1f601" }, { "joy", "1f602" }, { "rofl", "1f923" },
    { "sweat_smile", "1f605" }, { "wink", "1f609" }, { "blush", "1f60a" }, { "heart_eyes", "1f60d" },
    { "kiss", "1f618" }, { "tongue", "1f61b" }, { "sunglasses", "1f60e" }, { "thinking", "1f914" },
    { "neutral", "1f610" }, { "roll_eyes", "1f644" }, { "open_mouth", "1f62e" }, { "flushed", "1f633" },
    { "cry", "1f622" }, { "sob", "1f62d" }, { "angry", "1f620" }, { "rage", "1f621" },
    { "scream", "1f631" }, { "sleeping", "1f634" }, { "partying", "1f973" }, { "skull", "1f480" },
    { "facepalm", "1f926" }, { "shrug", "1f937" }, { "eyes", "1f440" }, { "thumbsup", "1f44d" },
    { "thumbsdown", "1f44e" }, { "clap", "1f44f" }, { "wave", "1f44b" }, { "pray", "1f64f" },
    { "muscle", "1f4aa" }, { "ok_hand", "1f44c" }, { "heart", "2764" }, { "fire", "1f525" },
    { "100", "1f4af" }, { "tada", "1f389" }, { "poop", "1f4a9" },
}

-- Emoticonos clasicos. Solo se cambian si van entre espacios, para no tocar
-- enlaces ni URLs ("https://", "|Hitem:...").
local EMOTICONS = {
    [":)"] = "blush", [":-)"] = "blush", [":D"] = "grin", ["xD"] = "joy", ["XD"] = "joy",
    [";)"] = "wink", [":P"] = "tongue", [":p"] = "tongue", [":("] = "cry", [":'("] = "sob",
    [":O"] = "open_mouth", [":o"] = "open_mouth", [">:("] = "angry", ["<3"] = "heart", ["B)"] = "sunglasses",
}

local function Utf8Char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + bit.rshift(cp, 6), 0x80 + cp % 64) end
    if cp < 0x10000 then
        return string.char(0xE0 + bit.rshift(cp, 12), 0x80 + bit.rshift(cp, 6) % 64, 0x80 + cp % 64)
    end
    return string.char(0xF0 + bit.rshift(cp, 18), 0x80 + bit.rshift(cp, 12) % 64, 0x80 + bit.rshift(cp, 6) % 64, 0x80 + cp % 64)
end

ns.VALID = {}
local byUnicode = {}
for _, e in ipairs(ns.EMOJIS) do
    ns.VALID[e[1]] = true
    byUnicode[Utf8Char(tonumber(e[2], 16))] = e[1]
end

local emoticonPatterns = {}
for text, code in pairs(EMOTICONS) do
    emoticonPatterns["(%s)" .. text:gsub("%p", "%%%0") .. "%f[%s]"] = code
end

function ns.Texture(code, size)
    return ("|T%s%s:%d:%d|t"):format(ns.EMOJI, code, size, size)
end

-- :codigo:, emojis Unicode pegados (😂) y, si se pide, emoticonos :) -> texturas.
function ns.Emojify(msg, size, emoticons)
    local function Tex(code) return ns.Texture(code, size) end
    msg = msg:gsub(":([%w_]+):", function(code) if ns.VALID[code] then return Tex(code) end end)
    -- Bytes de inicio de los emojis en UTF-8 (U+2xxx y U+1Fxxx)
    if msg:find("[\226\240]") then
        msg = msg:gsub("\239\184\143", "") -- selector de variacion U+FE0F (❤️ -> ❤)
        for char, code in pairs(byUnicode) do msg = msg:gsub(char, Tex(code)) end
    end
    if not emoticons then return msg end
    local padded = " " .. msg .. " "
    for pattern, code in pairs(emoticonPatterns) do
        padded = padded:gsub(pattern, "%1" .. Tex(code))
    end
    return padded:sub(2, -2)
end
