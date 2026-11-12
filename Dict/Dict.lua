--[[
    RuEnTranslator - Dict\Dict.lua  (FASE 3: motor de diccionarios)

    Guarda diccionarios por ruta de traducción:
        ns.Dict.data[source] = ...       -- rutas antiguas a español
        ns.Dict.data[source_target] = ... -- rutas con destino explícito

      words : clave normalizada (palabra o frase de hasta 4 palabras) -> traducción
      stems : raíces (para ruso, que tiene muchas declinaciones) -> traducción

    FORMATO de las listas de texto (Dict:LoadString):
        # comentario
        origen = traducción            palabra o frase exacta
        raíz* = traducción             el asterisco final = raíz (stem): coincide con
                                       el inicio de la palabra (hasta 3 letras de más)
        origen =                       traducción vacía = la palabra se elimina

    Normalización de claves: minúsculas (incluye cirílico), "ё" -> "е",
    espacios colapsados. Así "Привет", "ПРИВЕТ" y "привет" son la misma clave.

    Para ampliar:
      - editar Dict\ru.lua / Dict\en.lua / Dict\Custom.lua (una línea por entrada), o
      - en el juego:  /ret add ru привет = hola
]]

local ADDON_NAME, ns = ...

local Dict = {
    data = {
        ru = { words = {}, stems = {}, count = 0 },
        en = { words = {}, stems = {}, count = 0 },
        en_zh = { words = {}, stems = {}, count = 0 },
        zh_en = { words = {}, stems = {}, count = 0 },
    },
}
ns.Dict = Dict

function Dict:GetData(sourceLang, targetLang)
    if not sourceLang or not targetLang then return nil end
    local route = self.data[sourceLang .. "_" .. targetLang]
    if route then return route end
    if targetLang == "es" then return self.data[sourceLang] end
    return nil
end

------------------------------------------------------------------------
-- Normalización (string.lower no entiende UTF-8, así que el cirílico se
-- convierte a mano: А-П = D0 90-9F -> D0 B0-BF ; Р-Я = D0 A0-AF -> D1 80-8F)
------------------------------------------------------------------------
local function Lower(s)
    s = s:lower()
    s = s:gsub("\226\128\153", "'")                      -- apóstrofo tipográfico
    s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
    s = s:gsub("\208\129", "\209\145")                   -- Ё -> ё
    s = s:gsub("\209\145", "\208\181")                   -- ё -> е
    return s
end

local function Normalize(s)
    s = Lower(s)
    s = s:gsub("%s+", " ")
    s = s:gsub("^ ", "")
    s = s:gsub(" $", "")
    return s
end

Dict.Lower     = Lower
Dict.Normalize = Normalize

------------------------------------------------------------------------
-- Altas y bajas
------------------------------------------------------------------------
local function InvalidateCache()
    if ns.Translator and ns.Translator.ClearCache then ns.Translator:ClearCache() end
end

-- Añade (o sobrescribe) una entrada. Devuelve true si se guardó.
function Dict:Add(lang, src, dst)
    local d = self.data[lang]
    if not d or type(src) ~= "string" then return false end

    local isStem = src:sub(-1) == "*"
    if isStem then src = src:sub(1, -2) end

    local key = Normalize(src)
    if key == "" then return false end

    local tbl = isStem and d.stems or d.words
    if tbl[key] == nil then d.count = d.count + 1 end
    tbl[key] = dst or ""
    d.keysByFirstByte = nil

    InvalidateCache()
    return true
end

-- Elimina una entrada del diccionario en memoria. Devuelve true si existía.
function Dict:Remove(lang, src)
    local d = self.data[lang]
    if not d or type(src) ~= "string" then return false end

    local isStem = src:sub(-1) == "*"
    if isStem then src = src:sub(1, -2) end

    local key = Normalize(src)
    local tbl = isStem and d.stems or d.words
    if tbl[key] == nil then return false end

    tbl[key] = nil
    d.count = d.count - 1
    d.keysByFirstByte = nil
    InvalidateCache()
    return true
end

function Dict:LoadGlossaries()
    for source, target in pairs(WoWTranslateOutGlossary or {}) do
        self:Add("en_zh", source, target)
    end
    for source, target in pairs(WoWTranslateGlossary or {}) do
        self:Add("zh_en", source, target)
    end
end

-- Carga un bloque de texto con líneas "origen = traducción".
function Dict:LoadString(lang, str)
    for line in str:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local src, dst = line:match("^(.-)%s*=%s*(.-)$")
            if src and src ~= "" then self:Add(lang, src, dst) end
        end
    end
end

-- Entradas del usuario guardadas en SavedVariables (ns.db.userDict). Se cargan
-- después de las incluidas, por lo que tienen prioridad sobre ellas.
function Dict:LoadUser()
    local u = ns.db and ns.db.userDict
    if type(u) ~= "table" then return end
    for lang, entries in pairs(u) do
        if type(entries) == "table" then
            for src, dst in pairs(entries) do
                self:Add(lang, src, dst)
            end
        end
    end
end
