local ADDON_NAME, ns = ...

-- ==========================================
-- EMOJIS
-- ==========================================
-- WoW no pinta emojis Unicode: cada emoji es una imagen del addon y el texto
-- se cambia por su textura |T...|t.
--   * Chat: TODOS los emojis de Twemoji con sus tonos de piel (Data/EmojiData.lua,
--     img/emoji/<fichero>.tga, 32x32). Se escriben como :codigo: (los de
--     Discord/Slack) o pegando el emoji Unicode.
--   * Reacciones: otra coleccion, la lista corta ns.REACTIONS de imagenes propias
--     (img/reaction/<nombre>.tga, 128x128).
-- Imagenes de Twemoji (CC-BY 4.0), ver CREDITS.txt. Datos de emojibase (MIT).

ns.IMG = "Interface\\AddOns\\" .. ADDON_NAME .. "\\img\\"
ns.EMOJI = ns.IMG .. "emoji\\"
ns.REACTION = ns.IMG .. "reaction\\"

-- Reacciones: nombre de cada imagen de img/reaction/<nombre>.tga, en el orden de
-- la cuadricula con la que se eligen en Opciones. Para anadir una: poner la
-- imagen (128x128, ver tools/png_to_reaction.py) y su nombre en esta lista.
-- Las de texto (gg, wp...) salen de _project/tools/emojireact_text_reactions.py.
-- Cada una necesita su etiqueta L["REACTION_<nombre>"] en los 20 idiomas.
-- La rueda tiene por defecto tantas paginas de 4 como hagan falta para todas.
ns.REACTIONS = {
    "joy", "heart_eyes", "thumbsup", "heart", "clap", "cry", "angry", "fire",
    "gg", "wp", "ez", "1v1", "rip", "lol",
}
ns.REACTION_VALID = {}
for _, name in ipairs(ns.REACTIONS) do ns.REACTION_VALID[name] = true end

-- Emoticonos clasicos -> fichero. Solo se cambian si van entre espacios, para
-- no tocar enlaces ni URLs ("https://", "|Hitem:...").
local EMOTICONS = {
    [":)"] = "1f60a", [":-)"] = "1f60a", [":D"] = "1f601", ["xD"] = "1f602", ["XD"] = "1f602",
    [";)"] = "1f609", [":P"] = "1f61b", [":p"] = "1f61b", [":("] = "1f622", [":'("] = "1f62d",
    [":O"] = "1f62e", [":o"] = "1f62e", [">:("] = "1f620", ["<3"] = "2764", ["B)"] = "1f60e",
}

local function Utf8Char(cp)
    if cp < 0x80 then return string.char(cp) end
    if cp < 0x800 then return string.char(0xC0 + bit.rshift(cp, 6), 0x80 + cp % 64) end
    if cp < 0x10000 then
        return string.char(0xE0 + bit.rshift(cp, 12), 0x80 + bit.rshift(cp, 6) % 64, 0x80 + cp % 64)
    end
    return string.char(0xF0 + bit.rshift(cp, 18), 0x80 + bit.rshift(cp, 12) % 64, 0x80 + bit.rshift(cp, 6) % 64, 0x80 + cp % 64)
end

-- Indices: :codigo: -> fichero, secuencia UTF-8 (sin U+FE0F) -> fichero,
-- fichero -> codigo para escribirlo. Los tonos son "codigo_toneN".
local BY_CODE, BY_SEQ, CODE_OF, BASE_OF = {}, {}, {}, {}
local MAX_CODEPOINTS = 1

local function AddSequence(file)
    local seq, n = {}, 0
    for hex in file:gmatch("[^-]+") do
        if hex ~= "fe0f" then
            n = n + 1
            seq[n] = Utf8Char(tonumber(hex, 16))
        end
    end
    BY_SEQ[table.concat(seq)] = file
    if n > MAX_CODEPOINTS then MAX_CODEPOINTS = n end
end

for _, e in ipairs(ns.EMOJI_DATA) do
    local file = e[1]
    for i = 3, #e do BY_CODE[e[i]] = BY_CODE[e[i]] or file end
    CODE_OF[file] = e[3]
    AddSequence(file)
    local tones = ns.EMOJI_TONES[file]
    if tones then
        for t, toneFile in ipairs(tones) do
            for i = 3, #e do
                local code = e[i] .. "_tone" .. t
                BY_CODE[code] = BY_CODE[code] or toneFile
            end
            CODE_OF[toneFile] = e[3] .. "_tone" .. t
            BASE_OF[toneFile] = file
            AddSequence(toneFile)
        end
    end
end

-- Codigo con el que se escribe un emoji (":joy:")
function ns.CodeOf(file)
    return CODE_OF[file]
end

-- Emoji sin tono de piel del que sale un fichero con tono (o el mismo)
function ns.BaseOf(file)
    return BASE_OF[file] or file
end

-- Nombre del emoji en el idioma del cliente (o en ingles), de Data/Search_*.lua
function ns.NameOf(file)
    local base = ns.BaseOf(file)
    local t = (ns.EMOJI_TEXT_LOCAL or {})[base] or (ns.EMOJI_TEXT_EN or {})[base]
    return t and t[1] or ns.CodeOf(file)
end

-- Nombre de una reaccion: su etiqueta corta (L["REACTION_<codigo>"], "Risa",
-- "Me encanta"...) o, si no tiene, el nombre de su emoji (las reacciones se
-- llaman como su :codigo:). Los de emoji son largos para la rueda.
function ns.ReactionName(code)
    local label = ns.L["REACTION_" .. code]
    if label then return label end
    local file = BY_CODE[code]
    return file and ns.NameOf(file) or code
end

local emoticonPatterns = {}
for text, file in pairs(EMOTICONS) do
    emoticonPatterns["(%s)" .. text:gsub("%p", "%%%0") .. "%f[%s]"] = file
end

function ns.Texture(file, size)
    return ("|T%s%s:%d:%d|t"):format(ns.EMOJI, file, size, size)
end

-- Emojis Unicode pegados: en cada caracter que puede empezar un emoji se busca
-- la secuencia mas larga conocida (familias, profesiones, banderas, tonos...).
local function ReplaceUnicode(msg, Tex)
    local out, n, i, len = {}, 0, 1, #msg
    while i <= len do
        local b = msg:byte(i)
        local size = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
        local matched
        if b == 0xE2 or b == 0xE3 or b == 0xF0 then
            local ends, j = {}, i
            for k = 1, MAX_CODEPOINTS do
                local c = msg:byte(j)
                if not c then break end
                j = j + (c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or 1)
                ends[k] = j - 1
            end
            for k = #ends, 1, -1 do
                local file = BY_SEQ[msg:sub(i, ends[k])]
                if file then
                    n = n + 1
                    out[n] = Tex(file)
                    i = ends[k] + 1
                    matched = true
                    break
                end
            end
        end
        if not matched then
            n = n + 1
            out[n] = msg:sub(i, i + size - 1)
            i = i + size
        end
    end
    return table.concat(out)
end

local function EmojifyText(msg, Tex, emoticons)
    msg = msg:gsub(":([%w_+%-]+):", function(code)
        local file = BY_CODE[code:lower()]
        if file then return Tex(file) end
    end)
    if msg:find("[\226\227\240]") then
        msg = ReplaceUnicode(msg:gsub("\239\184\143", ""), Tex) -- sin U+FE0F (❤️ -> ❤)
    end
    if not emoticons then return msg end
    local padded = " " .. msg .. " "
    for pattern, file in pairs(emoticonPatterns) do
        padded = padded:gsub(pattern, "%1" .. Tex(file))
    end
    return padded:sub(2, -2)
end

-- :codigo:, emojis Unicode pegados (😂) y, si se pide, emoticonos :) -> texturas.
-- Los enlaces (|H...|h...|h) y texturas (|T...|t) se apartan antes: dentro
-- llevan cosas como ":100:" o ":-1:", que tambien son codigos de emoji.
function ns.Emojify(msg, size, emoticons)
    local function Tex(file) return ns.Texture(file, size) end
    local kept = {}
    local function Keep(s)
        kept[#kept + 1] = s
        return "\1" .. #kept .. "\1"
    end
    msg = msg:gsub("|H.-|h.-|h", Keep):gsub("|T.-|t", Keep)
    msg = EmojifyText(msg, Tex, emoticons)
    return (msg:gsub("\1(%d+)\1", function(i) return kept[tonumber(i)] end))
end
