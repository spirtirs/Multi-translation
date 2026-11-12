--[[
    RuEnTranslator - Translator.lua  (FASE 3: traducción offline)

    ns.Translator:Translate(texto, idiomaOrigen) -> string | nil
      nil = "no sé traducirlo": el chat queda intacto.

    Algoritmo (palabra a palabra con frases, sin gramática):
      1. Protege lo que no se debe tocar (enlaces, colores, iconos {rt1}, URLs).
      2. Divide en palabras y separadores.
      3. En cada palabra prueba primero la FRASE más larga (hasta 4 palabras),
         luego la palabra exacta, el plural inglés (-s/-es) y las raíces rusas (stem*).
      4. Lo que no se conoce se deja tal cual. Números, SIGLAS y nombres propios
         no cuentan como "fallo".
      5. Si la cobertura (palabras traducidas / palabras con significado) es menor
         que MIN_COVERAGE, devuelve nil para no mostrar traducciones basura.

    Caché: resultado por (idioma + texto). Se vacía al editar el diccionario.
]]

local ADDON_NAME, ns = ...
local L = ns.L

local Translator = {}
ns.Translator = Translator

local MAX_PHRASE   = 4      -- palabras máximas por frase del diccionario
-- Cobertura mínima para mostrar la traducción (configurable: /ret coverage <0-100>)
local function MinCoverage()
    return (ns.db and ns.db.minCoverage) or 0.5
end
local CACHE_LIMIT  = 500

local Normalize = function(s) return ns.Dict.Normalize(s) end

-- Una palabra empieza por letra/dígito ASCII o byte inicial cirílico (D0-D2) y puede
-- seguir con apóstrofos y bytes de continuación UTF-8.
local WORD_START = "^[%w\208-\210][%w'\208-\210\128-\191]*"
local SEP_NEXT   = "[%w\208-\210]"

------------------------------------------------------------------------
-- Caché
------------------------------------------------------------------------
local cache, cacheSize = {}, 0

function Translator:ClearCache()
    cache, cacheSize = {}, 0
end

function Translator:CacheSize()
    return cacheSize
end

------------------------------------------------------------------------
-- Utilidades de texto
------------------------------------------------------------------------
-- Sustituye por "\1" todo lo que no debe traducirse y lo guarda en `saved`.
local function Protect(text, saved)
    local function save(s)
        saved[#saved + 1] = s
        return "\1"
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x|H.-|h.-|h|r", save)   -- enlace completo
    text = text:gsub("|H.-|h.-|h", save)                        -- enlace sin color
    text = text:gsub("|c%x%x%x%x%x%x%x%x", save)
    text = text:gsub("|r", save)
    text = text:gsub("{[%a%d]+}", save)                         -- iconos de banda
    text = text:gsub("[Hh][Tt][Tt][Pp][Ss]?://%S+", save)
    text = text:gsub("[Ww][Ww][Ww]%.%S+", save)
    return text
end

local function Tokenize(text)
    local parts, pos, len = {}, 1, #text
    while pos <= len do
        local s, e = text:find(WORD_START, pos)
        if s == pos then
            parts[#parts + 1] = { text:sub(pos, e), true }
            pos = e + 1
        else
            local nxt = text:find(SEP_NEXT, pos + 1) or (len + 1)
            parts[#parts + 1] = { text:sub(pos, nxt - 1), false }
            pos = nxt
        end
    end
    return parts
end

local function HasLower(w) return w:find("[a-z]") or w:find("\208[\176-\191]") or w:find("\209[\128-\145]") end
local function HasUpper(w) return w:find("[A-Z]") or w:find("\208[\129\144-\175]") end

local function IsCapitalized(w)
    return w:find("^[A-Z]") or w:find("^\208[\129\144-\175]")
end

-- SIGLAS / números / nombres propios: si no están en el diccionario no cuentan como fallo.
local function IsNeutral(w, isFirst, lang)
    if w:find("^%d") then return true end
    -- Palabra latina dentro de un mensaje ruso: casi siempre un nombre de jugador.
    if lang == "ru" and w:find("^[A-Za-z]") then return true end
    if #w >= 2 and HasUpper(w) and not HasLower(w) then return true end
    -- Nombre propio: solo en alfabeto latino. En ruso la mayúscula inicial es
    -- habitual (inicio de frase) y no indica nada.
    if not isFirst and w:find("^[A-Z]") then return true end
    return false
end

-- Pone en mayúscula la primera letra de la traducción (ASCII y vocales acentuadas/ñ).
local function Capitalize(s)
    local b = s:byte(1)
    if b and b >= 97 and b <= 122 then
        return string.char(b - 32) .. s:sub(2)
    end
    if b == 195 then
        local c = s:byte(2)
        if c and (c == 161 or c == 169 or c == 173 or c == 179 or c == 186 or c == 177) then
            return "\195" .. string.char(c - 32) .. s:sub(3)
        end
    end
    return s
end

local function ChopLast(w)
    local b = w:byte(#w)
    if b and b >= 128 and b <= 191 then return w:sub(1, #w - 2) end
    return w:sub(1, #w - 1)
end

local function CharLen(w)
    local _, n = w:gsub("[^\128-\191]", "")
    return n
end

------------------------------------------------------------------------
-- Búsqueda en el diccionario
------------------------------------------------------------------------
-- Palabra suelta (clave ya normalizada). Devuelve la traducción o nil.
local function LookupWord(d, key, lang)
    local t = d.words[key]
    if t ~= nil then return t end

    if lang == "en" and #key >= 4 then
        if key:sub(-2) == "es" then
            t = d.words[key:sub(1, -3)]
            if t ~= nil then return t end
        end
        if key:sub(-2) == "'s" then
            t = d.words[key:sub(1, -3)]
            if t ~= nil then return t end
        end
        if key:sub(-1) == "s" then
            t = d.words[key:sub(1, -2)]
            if t ~= nil then return t end
        end
    end

    -- Raíces (ruso): exacta y luego quitando hasta 3 letras finales (mínimo 3 de raíz).
    t = d.stems[key]
    if t ~= nil then return t end
    local cur = key
    for _ = 1, 3 do
        cur = ChopLast(cur)
        if CharLen(cur) < 3 then break end
        t = d.stems[cur]
        if t ~= nil then return t end
    end
    return nil
end

-- Frase de 2..MAX_PHRASE palabras empezando en parts[i]; solo si entre palabras
-- hay únicamente espacios. Devuelve traducción y nº de palabras usadas.
local function MatchPhrase(d, parts, i, nparts)
    for n = MAX_PHRASE, 2, -1 do
        if i + 2 * (n - 1) <= nparts then
            local ok, keys = true, {}
            for k = 0, n - 1 do
                local w = parts[i + 2 * k]
                if not w[2] then ok = false; break end
                keys[#keys + 1] = w[1]
                if k < n - 1 then
                    local sep = parts[i + 2 * k + 1]
                    if sep[2] or not sep[1]:find("^%s+$") then ok = false; break end
                end
            end
            if ok then
                local t = d.words[Normalize(table.concat(keys, " "))]
                if t ~= nil then return t, n end
            end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Traducción
------------------------------------------------------------------------
-- Ejecuta el algoritmo. Devuelve texto|nil, aciertos, fallos.
function Translator:Run(text, lang, collect)
    local d = ns.Dict.data[lang]
    if not d or type(text) ~= "string" or text == "" then return nil, 0, 0 end

    local saved = {}
    text = text:gsub("\226\128\153", "'")
    text = Protect(text, saved)

    local parts = Tokenize(text)
    local nparts = #parts
    local out, hit, miss = {}, 0, 0
    local missed = collect and {} or nil     -- palabras desconocidas (para /ret learn)
    local isFirstWord, capFirst, skipSpace = true, false, false

    local i = 1
    while i <= nparts do
        local p = parts[i]
        if not p[2] then
            -- separador: se omite el espacio que sigue a una palabra eliminada
            if not (skipSpace and p[1]:find("^%s+$")) then out[#out + 1] = p[1] end
            skipSpace = false
            i = i + 1
        else
            local word = p[1]
            if isFirstWord then capFirst = IsCapitalized(word) and true or false end

            local trans, used = MatchPhrase(d, parts, i, nparts)
            if not trans then
                trans = LookupWord(d, Normalize(word), lang)
                used = 1
            end

            if trans ~= nil then
                hit = hit + used
                if trans == "" then
                    skipSpace = true
                else
                    if isFirstWord and capFirst then trans = Capitalize(trans) end
                    out[#out + 1] = trans
                    skipSpace = false
                    isFirstWord = false
                end
                i = i + (2 * used - 2)   -- salta palabras y separadores internos de la frase
            else
                if not IsNeutral(word, isFirstWord, lang) then
                    miss = miss + 1
                    if missed then missed[#missed + 1] = Normalize(word) end
                end
                out[#out + 1] = word
                skipSpace = false
                isFirstWord = false
            end
            i = i + 1
        end
    end

    if hit == 0 then return nil, hit, miss, missed end

    local result = table.concat(out)
    local idx = 0
    result = result:gsub("\1", function()
        idx = idx + 1
        return saved[idx]
    end)
    result = result:match("^%s*(.-)%s*$")
    if result == "" then return nil, hit, miss, missed end
    return result, hit, miss, missed
end

------------------------------------------------------------------------
-- Aprendizaje: palabras desconocidas más frecuentes (/ret learn, /ret unknown)
-- Se guardan en SavedVariables con un tope para no crecer sin límite.
------------------------------------------------------------------------
local UNKNOWN_LIMIT = 500
local unknownCounts = {}

function Translator:RecordUnknown(lang, words)
    local u = ns.db and ns.db.unknown
    local t = u and u[lang]
    if not t then return end

    if not unknownCounts[lang] then
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        unknownCounts[lang] = n
    end

    for _, w in ipairs(words) do
        if #w >= 2 then
            local c = t[w]
            if c then
                t[w] = c + 1
            elseif unknownCounts[lang] < UNKNOWN_LIMIT then
                t[w] = 1
                unknownCounts[lang] = unknownCounts[lang] + 1
            end
        end
    end
end

-- Con /ret learn on también se guardan los últimos mensajes ru/en (formato "ru|texto")
-- en SavedVariables, para poder analizarlos sin copiar nada del chat.
local SAMPLE_LIMIT = 300

function Translator:RecordSample(lang, text)
    local s = ns.db.samples
    if type(s) ~= "table" then s = {}; ns.db.samples = s end
    local line = lang .. "|" .. text
    if s[#s] == line then return end          -- evita el spam repetido seguido
    s[#s + 1] = line
    if #s > SAMPLE_LIMIT then table.remove(s, 1) end
end

function Translator:ClearUnknown()
    ns.db.unknown = { ru = {}, en = {} }
    ns.db.samples = {}
    unknownCounts = {}
end

------------------------------------------------------------------------
-- Proveedores externos (opcional, futuro)
-- WoW 5.4.8 no puede hacer peticiones HTTP, pero otro addon o un módulo propio
-- puede registrar una función que traduzca de otra forma:
--     ns:RegisterProvider("miProveedor", function(texto, idioma) return "..." or nil end)
-- Solo se consulta cuando el diccionario no alcanza la cobertura mínima.
------------------------------------------------------------------------
local providers = {}

function ns:RegisterProvider(name, fn)
    if type(fn) == "function" then providers[#providers + 1] = { name = name, fn = fn } end
end

local function TryProviders(text, lang)
    for _, p in ipairs(providers) do
        local ok, r = pcall(p.fn, text, lang)
        if ok and type(r) == "string" and r ~= "" then return r end
    end
    return nil
end

function Translator:Translate(text, lang)
    if type(text) ~= "string" or text == "" then return nil end

    local key = lang .. ":" .. text
    local c = cache[key]
    if c ~= nil then return c or nil end

    local result, hit, miss, missed = self:Run(text, lang, ns.db and ns.db.learn)
    if missed and #missed > 0 then self:RecordUnknown(lang, missed) end
    if ns.db.learn then self:RecordSample(lang, text) end
    if result and hit / (hit + miss) < MinCoverage() then result = nil end
    if not result and #providers > 0 then result = TryProviders(text, lang) end

    if cacheSize >= CACHE_LIMIT then self:ClearCache() end
    cache[key] = result or false
    cacheSize = cacheSize + 1
    return result
end

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------
local commands = ns.commands

local function ValidLang(lang)
    return lang == "ru" or lang == "en"
end

-- /ret translate <texto>  -> prueba el traductor sin necesitar a otros jugadores
function commands.translate(args)
    if args == "" then ns:Print(L["TR_USAGE"]); return end
    local lang = ns.Detect:Guess(args)
    if not lang then ns:Print(L["TR_UNKNOWN"]); return end
    if lang == "es" then ns:Print(L["TR_ALREADY_ES"]); return end

    local result, hit, miss = Translator:Run(args, lang)
    if not result then ns:Print(L["TR_NONE"]:format(lang)); return end

    local cov = hit / (hit + miss)
    ns:Print(("[%s>ES] %s"):format(lang:upper(), result))
    ns:Print(L["TR_COVERAGE"]:format(math.floor(cov * 100 + 0.5), hit, hit + miss,
        cov >= MinCoverage() and L["TR_SHOWN"] or L["TR_HIDDEN"]))
end

-- /ret coverage <0-100>  -> % mínimo de palabras reconocidas para mostrar la traducción
function commands.coverage(args)
    local n = tonumber(args:match("^(%d+)"))
    if not n or n > 100 then
        ns:Print(L["COVERAGE_USAGE"]:format(math.floor(MinCoverage() * 100 + 0.5)))
        return
    end
    ns.db.minCoverage = n / 100
    Translator:ClearCache()
    ns:Print(L["COVERAGE_SET"]:format(n))
end

-- /ret add <ru|en> <origen> = <traducción>
function commands.add(args)
    local lang, rest = args:match("^(%S+)%s+(.+)$")
    lang = lang and lang:lower()
    local src, dst = rest and rest:match("^(.-)%s*=%s*(.+)$")
    if not ValidLang(lang) or not src or src == "" then ns:Print(L["ADD_USAGE"]); return end

    ns.db.userDict[lang][src] = dst
    ns.Dict:Add(lang, src, dst)
    ns:Print(L["ADD_OK"]:format(lang, src, dst))
end

-- /ret del <ru|en> <origen>
function commands.del(args)
    local lang, src = args:match("^(%S+)%s+(.+)$")
    lang = lang and lang:lower()
    if not ValidLang(lang) or not src then ns:Print(L["DEL_USAGE"]); return end

    local inUser = ns.db.userDict[lang][src] ~= nil
    ns.db.userDict[lang][src] = nil
    local inMemory = ns.Dict:Remove(lang, src)
    if inUser or inMemory then
        ns:Print(L["DEL_OK"]:format(lang, src))
    else
        ns:Print(L["DEL_NONE"]:format(lang, src))
    end
end

-- /ret list [ru|en]  -> entradas propias
function commands.list(args)
    local lang = args:match("^(%S+)")
    lang = lang and lang:lower()
    local langs = ValidLang(lang) and { lang } or { "ru", "en" }

    local shown = 0
    for _, lg in ipairs(langs) do
        for src, dst in pairs(ns.db.userDict[lg]) do
            shown = shown + 1
            if shown <= 25 then ns:Print(("  [%s] %s = %s"):format(lg, src, dst)) end
        end
    end
    if shown == 0 then ns:Print(L["LIST_EMPTY"])
    elseif shown > 25 then ns:Print(L["LIST_MORE"]:format(shown - 25)) end
end

function commands.stats()
    local D = ns.Dict.data
    ns:Print(L["STATS_DICT"]:format("ru", D.ru.count))
    ns:Print(L["STATS_DICT"]:format("en", D.en.count))
    ns:Print(L["STATS_CACHE"]:format(Translator:CacheSize(), CACHE_LIMIT))
end

function commands.clearcache()
    Translator:ClearCache()
    ns:Print(L["CACHE_CLEARED"])
end

-- /ret learn on|off  -> registra las palabras que el diccionario no conoce
function commands.learn(args)
    local state = ns.ParseBool(args:match("^(%S+)"))
    if state == nil then state = not ns.db.learn end
    ns.db.learn = state
    Translator:ClearCache()   -- para que los mensajes ya vistos se vuelvan a analizar
    ns:Print(L["LEARN_SET"]:format(ns.YesNo(state)))
end

-- /ret unknown [ru|en] [n]  |  /ret unknown clear
function commands.unknown(args)
    local first = args:match("^(%S+)")
    if first and first:lower() == "clear" then
        Translator:ClearUnknown()
        ns:Print(L["UNKNOWN_CLEARED"])
        return
    end

    local lang = first and first:lower()
    local langs = ValidLang(lang) and { lang } or { "ru", "en" }
    local n = tonumber(args:match("(%d+)%s*$")) or 15

    local shown = 0
    for _, lg in ipairs(langs) do
        local list = {}
        for w, c in pairs(ns.db.unknown[lg]) do list[#list + 1] = { w, c } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i = 1, math.min(n, #list) do
            shown = shown + 1
            ns:Print(("  [%s] %s  (x%d)"):format(lg, list[i][1], list[i][2]))
        end
    end
    if shown == 0 then ns:Print(L["UNKNOWN_EMPTY"]) end
end
