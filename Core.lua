--[[
    RuEnTranslator - Core.lua  (FASE 1: estructura base)
    Cliente objetivo: WoW 5.4.8 (Mists of Pandaria) - Interface 50400, Lua 5.1

    Contenido:
      1. Namespace y valores por defecto
      2. Utilidades (print, copia profunda, on/off)
      3. Base de datos (SavedVariables) con migración de claves nuevas
      4. Frame principal + manejo de eventos
      5. Slash commands (/ret, /ruen)

    Las fases siguientes se enchufan aquí:
      - Fase 2: ns:RegisterChatEvents() (hook de CHAT_MSG_*)
      - Fase 3: ns.Translator (diccionarios + caché)
      - Fase 4: panel de opciones
]]

local ADDON_NAME, ns = ...   -- ns: tabla privada compartida entre los archivos del addon
local L = ns.L

ns.name    = ADDON_NAME
ns.version = "1.0.0"

------------------------------------------------------------------------
-- 1. Valores por defecto
------------------------------------------------------------------------
-- Claves de canal -> usadas en la fase 2 para mapear eventos CHAT_MSG_*.
ns.CHANNEL_ORDER = { "say", "yell", "party", "raid", "guild", "officer", "whisper", "instance", "world" }
ns.LANG_ORDER    = { "ru", "en", "zh" }

local TARGET_BY_LOCALE = {
    enGB = "en",
    enUS = "en",
    esES = "es",
    esMX = "es",
    zhCN = "zh",
    zhTW = "zh",
}

function ns:GetTargetLanguage()
    return TARGET_BY_LOCALE[GetLocale()]
end

ns.defaults = {
    enabled = true,
    languages = {                  -- idiomas de ORIGEN que se traducen
        ru = true,
        en = true,
        zh = true,
    },
    channels = {                   -- canales prioritarios activados por defecto
        say      = true,
        yell     = false,
        party    = true,
        raid     = true,
        guild    = true,
        officer  = false,
        whisper  = true,
        instance = true,
        world    = true,
    },
    showOriginal = true,           -- mostrar el mensaje original junto a la traducción
    minimap = { hide = false, angle = 215 },   -- botón del minimapa
    learn = false,                    -- registrar palabras desconocidas (/ret learn)
    unknown = { ru = {}, en = {}, zh = {} }, -- palabras desconocidas y su frecuencia
    samples = {},                      -- últimos mensajes vistos con learn activo
    minCoverage = 0.5,                -- % mínimo de palabras reconocidas para mostrar traducción
    userDict = { ru = {}, en = {}, en_zh = {}, zh_en = {} }, -- entradas añadidas con /ret add
    layout = "below",            -- "below" (traducción debajo) | "inline" (misma línea)
    debug = false,                 -- modo prueba / errores visibles
    color = { r = 0.40, g = 0.80, b = 1.00 },  -- color de la traducción (Fase 4)
    fontSize = 14,                 -- tamaño de fuente de las ventanas de chat
    applyFontSize = false,         -- ¿aplicar fontSize a las ventanas de chat?
}

------------------------------------------------------------------------
-- 2. Utilidades
------------------------------------------------------------------------
local PREFIX = "|cff33ccff[RuEn]|r "

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- Copia profunda de una tabla (para los defaults).
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = DeepCopy(v) end
    return dst
end

-- Rellena en `db` las claves que falten respecto a `defaults` (no pisa valores del usuario).
local function MergeDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = DeepCopy(v)
        elseif type(v) == "table" and type(db[k]) == "table" then
            MergeDefaults(db[k], v)
        end
    end
end

-- Interpreta "on/off/1/0/si/no..." -> true/false, o nil si no es válido.
local function ParseBool(arg)
    arg = arg and arg:lower()
    if arg == "on" or arg == "1" or arg == "si" or arg == "sí" or arg == "true" then return true end
    if arg == "off" or arg == "0" or arg == "no" or arg == "false" then return false end
    return nil
end

local function YesNo(v) return v and L["ON"] or L["OFF"] end

-- Compartidas con los demás archivos del addon
ns.ParseBool = ParseBool
ns.YesNo     = YesNo

local function Contains(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

------------------------------------------------------------------------
-- 3. Base de datos
------------------------------------------------------------------------
function ns:InitDB()
    if type(RuEnTranslatorDB) ~= "table" then
        RuEnTranslatorDB = {}
    end
    MergeDefaults(RuEnTranslatorDB, ns.defaults)
    ns.db = RuEnTranslatorDB
end

-- Restablece los ajustes. El diccionario propio (userDict) NO se borra.
function ns:ResetDB()
    local keep = ns.db and ns.db.userDict
    RuEnTranslatorDB = DeepCopy(ns.defaults)
    if keep then RuEnTranslatorDB.userDict = keep end
    ns.db = RuEnTranslatorDB
end

-- Ejecuta fn protegida: un fallo al iniciar una parte no tumba el resto del addon.
function ns:SafeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns:Print(L["INIT_ERROR"]:format(name, tostring(err))) end
    return ok
end

function ns:SetEnabled(state, silent)
    ns.db.enabled = state and true or false
    if ns.db.enabled then ns.failed, ns.failures = false, 0 end   -- rearma el cortafuegos
    if not silent then ns:Print(ns.db.enabled and L["ENABLED"] or L["DISABLED"]) end
end

-- Consulta usada por la fase 2: ¿debo traducir este idioma/canal?
function ns:ShouldTranslate(channelKey, langKey)
    local db = ns.db
    if not db or not db.enabled then return false end
    if channelKey and not db.channels[channelKey] then return false end
    if langKey and not db.languages[langKey] then return false end
    if langKey and not ns.Dict:GetData(langKey, ns:GetTargetLanguage()) then return false end
    return true
end

------------------------------------------------------------------------
-- 4. Frame principal y eventos
------------------------------------------------------------------------
local frame = CreateFrame("Frame", "RuEnTranslatorFrame", UIParent)
ns.frame = frame

local handlers = {}   -- handlers[evento] = function(self, ...)
ns.handlers = handlers

function handlers.ADDON_LOADED(loadedName)
    if loadedName ~= ADDON_NAME then return end
    ns:InitDB()
    frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
    ns:Print("v" .. ns.version .. " " .. L["ADDON_LOADED"])
    ns:SafeCall("Dict",    function()
        ns.Dict:LoadGlossaries()
        ns.Dict:LoadUser()
    end)
    ns:SafeCall("Chat",    function() ns:RegisterChatEvents() end) -- Chat.lua
    ns:SafeCall("Options", function() ns:BuildOptions() end)       -- Options.lua
    ns:SafeCall("Fuente",  function() ns:ApplyFontSize() end)
end

frame:SetScript("OnEvent", function(self, event, ...)
    local handler = handlers[event]
    if handler then handler(...) end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

------------------------------------------------------------------------
-- 5. Slash commands
------------------------------------------------------------------------
local function PrintHelp()
    ns:Print(L["HELP_HEADER"])
    ns:Print("  " .. L["HELP_CONFIG"])
    ns:Print("  " .. L["HELP_MINIMAP"])
    ns:Print("  " .. L["HELP_TOGGLE"])
    ns:Print("  " .. L["HELP_STATUS"])
    ns:Print("  " .. L["HELP_LANG"])
    ns:Print("  " .. L["HELP_CHANNEL"])
    ns:Print("  " .. L["HELP_ORIGINAL"])
    ns:Print("  " .. L["HELP_LAYOUT"])
    ns:Print("  " .. L["HELP_COLOR"])
    ns:Print("  " .. L["HELP_FONT"])
    ns:Print("  " .. L["HELP_DETECT"])
    ns:Print("  " .. L["HELP_TRANSLATE"])
    ns:Print("  " .. L["HELP_ADD"])
    ns:Print("  " .. L["HELP_DEL"])
    ns:Print("  " .. L["HELP_LIST"])
    ns:Print("  " .. L["HELP_COVERAGE"])
    ns:Print("  " .. L["HELP_LEARN"])
    ns:Print("  " .. L["HELP_UNKNOWN"])
    ns:Print("  " .. L["HELP_STATS"])
    ns:Print("  " .. L["HELP_DEBUG"])
    ns:Print("  " .. L["HELP_RESET"])
end

local function PrintStatus()
    local db = ns.db
    ns:Print(L["STATUS_HEADER"])
    ns:Print("  " .. L["STATUS_ENABLED"] .. ": " .. YesNo(db.enabled))

    local langs = {}
    for _, k in ipairs(ns.LANG_ORDER) do
        langs[#langs + 1] = L["LANG_" .. k] .. "=" .. YesNo(db.languages[k])
    end
    ns:Print("  " .. L["STATUS_LANGS"] .. ": " .. table.concat(langs, ", "))
    ns:Print("  " .. L["STATUS_TARGET"] .. ": " .. (L["TARGET_" .. tostring(ns:GetTargetLanguage())] or L["TARGET_UNSUPPORTED"]))

    local chans = {}
    for _, k in ipairs(ns.CHANNEL_ORDER) do
        chans[#chans + 1] = L["CHAN_" .. k] .. "=" .. YesNo(db.channels[k])
    end
    ns:Print("  " .. L["STATUS_CHANNELS"] .. ": " .. table.concat(chans, ", "))
    ns:Print("  " .. L["STATUS_ORIGINAL"] .. ": " .. YesNo(db.showOriginal))
    ns:Print("  " .. L["STATUS_LAYOUT"] .. ": " .. db.layout)
end

local commands = {}
ns.commands = commands   -- otros archivos (Chat.lua...) añaden sus comandos aquí

function commands.on()     ns:SetEnabled(true)  end
function commands.off()    ns:SetEnabled(false) end
function commands.toggle() ns:SetEnabled(not ns.db.enabled) end
function commands.status() PrintStatus() end
function commands.help()   PrintHelp() end

function commands.reset()
    ns:ResetDB()
    ns:RefreshOptions()
    ns:Print(L["RESET_DONE"])
end

function commands.lang(args)
    local key, state = args:match("^(%S+)%s+(%S+)")
    key = key and key:lower()
    if not key or not Contains(ns.LANG_ORDER, key) then
        ns:Print(L["LANG_INVALID"]); return
    end
    state = ParseBool(state)
    if state == nil then state = not ns.db.languages[key] end  -- sin on/off: alterna
    ns.db.languages[key] = state
    ns:Print(L["LANG_SET"]:format(L["LANG_" .. key], YesNo(state)))
end

function commands.channel(args)
    local key, state = args:match("^(%S+)%s*(%S*)")
    key = key and key:lower()
    if not key or not Contains(ns.CHANNEL_ORDER, key) then
        ns:Print(L["CHAN_INVALID"]); return
    end
    state = ParseBool(state)
    if state == nil then state = not ns.db.channels[key] end
    ns.db.channels[key] = state
    ns:Print(L["CHAN_SET"]:format(L["CHAN_" .. key], YesNo(state)))
end

function commands.original(args)
    local state = ParseBool(args:match("^(%S+)"))
    if state == nil then state = not ns.db.showOriginal end
    ns.db.showOriginal = state
    ns:Print(L["ORIGINAL_SET"]:format(YesNo(state)))
end

SLASH_RUENTRANSLATOR1 = "/ret"
SLASH_RUENTRANSLATOR2 = "/ruen"
SlashCmdList["RUENTRANSLATOR"] = function(input)
    if not ns.db then return end   -- aún no cargó la DB
    input = (input or ""):match("^%s*(.-)%s*$")
    local cmd, rest = input:match("^(%S+)%s*(.*)$")
    if not cmd then PrintHelp(); return end
    local fn = commands[cmd:lower()]
    if fn then
        fn(rest or "")
    else
        ns:Print(L["UNKNOWN_CMD"])
    end
end
