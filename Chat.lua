--[[
    RuEnTranslator - Chat.lua  (FASE 2: intercepción de mensajes)

    Usa ChatFrame_AddMessageEventFilter, la vía oficial de Blizzard: el filtro
    recibe cada mensaje ANTES de dibujarse y puede devolverlo modificado.
    Así la traducción queda en el orden correcto, sin tocar los marcos de chat
    ni usar hooks frágiles.

    Flujo por mensaje:
      evento -> clave de canal -> ¿es mío? -> detectar idioma -> ¿debo traducir?
             -> Translator:Translate -> componer texto final -> devolver al chat

    Nota: cada ventana de chat ejecuta el filtro, por eso se cachea el
    resultado por lineID (identificador único de línea de chat).
]]

local ADDON_NAME, ns = ...
local L = ns.L

------------------------------------------------------------------------
-- Evento de chat -> clave de canal (las mismas que ns.CHANNEL_ORDER)
------------------------------------------------------------------------
local EVENT_TO_CHANNEL = {
    CHAT_MSG_SAY                    = "say",
    CHAT_MSG_YELL                   = "yell",
    CHAT_MSG_PARTY                  = "party",
    CHAT_MSG_PARTY_LEADER           = "party",
    CHAT_MSG_RAID                   = "raid",
    CHAT_MSG_RAID_LEADER            = "raid",
    CHAT_MSG_RAID_WARNING           = "raid",
    CHAT_MSG_GUILD                  = "guild",
    CHAT_MSG_OFFICER                = "officer",
    CHAT_MSG_WHISPER                = "whisper",
    -- Instancia / campo de batalla (según la build el evento se llama de una u otra forma;
    -- registrar un evento inexistente es inofensivo).
    CHAT_MSG_INSTANCE_CHAT          = "instance",
    CHAT_MSG_INSTANCE_CHAT_LEADER   = "instance",
    CHAT_MSG_BATTLEGROUND           = "instance",
    CHAT_MSG_BATTLEGROUND_LEADER    = "instance",
    -- Canales numerados (World, General, Comercio...). En Fase 4 se podrá afinar por nombre.
    CHAT_MSG_CHANNEL                = "world",
}

------------------------------------------------------------------------
-- Caché por lineID (evita recalcular para cada ventana de chat)
------------------------------------------------------------------------
local lineCache, lineCacheSize = {}, 0
local CACHE_LIMIT = 200

local function CachePut(lineID, value)
    if not lineID then return end
    if lineCacheSize >= CACHE_LIMIT then
        lineCache, lineCacheSize = {}, 0
    end
    lineCache[lineID] = value
    lineCacheSize = lineCacheSize + 1
end

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------
-- ¿El autor soy yo? (el autor puede venir como "Nombre-Reino")
local function IsOwnMessage(author)
    if not author or author == "" then return false end
    return (strsplit("-", author)) == UnitName("player")
end

local function ColorHex()
    local c = ns.db.color
    return string.format("|cff%02x%02x%02x",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- Compone el texto final según las opciones (showOriginal / layout).
-- Devuelve nil si no hay nada que cambiar.
function ns:BuildMessage(channelKey, msg)
    local lang = ns.Detect:Guess(msg)
    if not lang or lang == "es" then return nil end           -- ya es español / desconocido
    if not ns:ShouldTranslate(channelKey, lang) then return nil end

    local translated = ns.Translator:Translate(msg, lang)
    if not translated or translated == "" then return nil end

    local db = ns.db
    local line = ColorHex() .. "[" .. lang:upper() .. ">ES] " .. translated .. "|r"

    if not db.showOriginal then
        return line                                  -- solo la traducción
    elseif db.layout == "inline" then
        return msg .. " " .. line                    -- original + traducción en la misma línea
    else
        return msg .. "\n" .. line                   -- traducción debajo del original
    end
end

------------------------------------------------------------------------
-- Filtro de chat
------------------------------------------------------------------------
-- Firma de Blizzard: (self, event, msg, author, ...) -> bloquear?, msg, author, ...
-- Si se modifica algo hay que devolver TODOS los argumentos.
local function ChatFilter(self, event, msg, author, ...)
    if not ns.db or not ns.db.enabled or ns.failed then return false end

    local channelKey = EVENT_TO_CHANNEL[event]
    if not channelKey or IsOwnMessage(author) then return false end

    -- args tras author: lang, chanString, target, flags, zoneChanID, chanNum, chanName, _, lineID
    local lineID = select(9, ...)
    if lineID then
        local cached = lineCache[lineID]
        if cached ~= nil then
            if cached then return false, cached, author, ... end
            return false
        end
    end

    -- pcall: un fallo en la traducción NUNCA debe romper el chat.
    local ok, newMsg = pcall(ns.BuildMessage, ns, channelKey, msg)
    if not ok then
        if ns.db.debug then ns:Print("|cffff0000Error:|r " .. tostring(newMsg)) end
        newMsg = nil
        -- Cortafuegos: si falla repetidamente, se apaga solo para no ensuciar el chat.
        ns.failures = (ns.failures or 0) + 1
        if ns.failures >= 5 and not ns.failed then
            ns.failed = true
            ns:Print(L["FAILED"])
        end
    end

    CachePut(lineID, newMsg or false)
    if newMsg then return false, newMsg, author, ... end
    return false
end

local registered = false
function ns:RegisterChatEvents()
    if registered then return end
    registered = true
    for event in pairs(EVENT_TO_CHANNEL) do
        ChatFrame_AddMessageEventFilter(event, ChatFilter)
    end
end

------------------------------------------------------------------------
-- Comandos propios de esta fase (se añaden a la tabla de Core.lua)
------------------------------------------------------------------------
local commands = ns.commands

-- /ret detect <texto>  -> prueba el detector sin necesitar a otros jugadores
function commands.detect(args)
    if args == "" then ns:Print(L["DETECT_USAGE"]); return end
    local lang, cyr, latin = ns.Detect:Guess(args)
    ns:Print(L["DETECT_RESULT"]:format(lang or "?", cyr, latin))
end

function commands.debug(args)
    local state = ns.ParseBool(args:match("^(%S+)"))
    if state == nil then state = not ns.db.debug end
    ns.db.debug = state
    ns:Print(L["DEBUG_SET"]:format(ns.YesNo(state)))
end

function commands.layout(args)
    local v = args:match("^(%S+)")
    v = v and v:lower()
    if v ~= "below" and v ~= "inline" then ns:Print(L["LAYOUT_INVALID"]); return end
    ns.db.layout = v
    ns:Print(L["LAYOUT_SET"]:format(v))
end
