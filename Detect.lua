--[[
    RuEnTranslator - Detect.lua  (FASE 2: detección de idioma)

    ns.Detect:Guess(texto) -> "ru" | "en" | "es" | "zh" | nil

    Método (rápido, sin librerías):
      1. Limpia el texto: colores, enlaces de objetos/hechizos, iconos {rt1}, URLs.
      2. Cuenta letras cirílicas (UTF-8: bytes iniciales 0xD0-0xD2 = \208-\210)
         y letras latinas.
      3. Si hay cirílico suficiente -> ruso.
      4. Si es latino, puntúa palabras vacías (stopwords) de inglés vs español,
         más un bonus por tildes/ñ/¿/¡. Sin evidencia -> "en" (la jerga de WoW
         es mayoritariamente inglesa).
]]

local ADDON_NAME, ns = ...

local Detect = {}
ns.Detect = Detect

-- Proporción mínima: el ruso gana si cirílicas >= latinas * CYR_RATIO.
-- (0.5 permite mensajes mixtos tipo "need tank для рейда").
local CYR_RATIO = 0.5

------------------------------------------------------------------------
-- Palabras vacías (en minúsculas, solo ASCII). Evitar jerga ambigua
-- (lfm, dps, tank...) porque la usan ambos idiomas.
------------------------------------------------------------------------
local EN_WORDS, ES_WORDS = {}, {}

local function Fill(set, str)
    for w in str:gmatch("%S+") do set[w] = true end
end

Fill(EN_WORDS, [[
    the and you your for with are is was were it this that these those have has had
    not what when where who why how need can could just please thanks thank pls plz
    i im ive id dont cant wont didnt we they he she will would do does did my to of
    in on at up go come wait ready sorry yes hello hi bye good nice want
    anyone someone everyone who're from about but or if so then there here
    now got get let lets let's gonna wanna
]])

Fill(ES_WORDS, [[
    el la los las un una unos unas de del que y en es por para con se lo le les su
    mi tu yo vos nos me te si pero como mas muy bien hola gracias vamos esperen espera
    listo lista ya esta estoy estamos tengo hay aqui donde cuando quiero necesito
    alguien todos todo nada quien porque pq q xq al soy eres somos son voy vas
    ayuda favor buenas buenos dale ahora sin sobre tambien
]])

-- Español con jerga de WoW: evita traducir como "inglés" mensajes como "tanq para celestiales"
Fill(ES_WORDS, [[
    busco necesito necesitamos falta faltan banda hermandad mazmorra tanque tanq sanador
    sanadores dps gracias saludos quien quiere quieres puedo puedes pueden vengan vamos
    entra entren espero esperen aviso avisen invita invitar invitame susurra
    cuanto cuesta vendo compro cambio oro precio listos listo hacer hacemos
    hoy manana noche tarde dia jefe jefes cae caen botin tirada
    cele celestiales celestial anote anota apuntame inviten
]])

------------------------------------------------------------------------
-- Limpieza del texto
------------------------------------------------------------------------
local function Clean(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")      -- códigos de color
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h.-|h", "")              -- enlaces (objetos, hechizos...)
    text = text:gsub("{[%a%d]+}", "")               -- iconos de banda {rt1}, {skull}
    text = text:gsub("[Hh][Tt][Tt][Pp][Ss]?://%S+", "")
    text = text:gsub("[Ww][Ww][Ww]%.%S+", "")
    return text
end
Detect.Clean = Clean

local function Count(text, pattern)
    local _, n = text:gsub(pattern, "")
    return n
end

------------------------------------------------------------------------
-- API pública
------------------------------------------------------------------------
-- Devuelve idioma, cirílicas, latinas (los dos últimos útiles para /ret detect).
function Detect:Guess(text)
    if type(text) ~= "string" or text == "" then return nil, 0, 0 end

    text = Clean(text)
    local cyr   = Count(text, "[\208-\210][\128-\191]")
    local latin = Count(text, "[A-Za-z]")
    local han   = Count(text, "[\228-\233][\128-\191][\128-\191]")

    -- Ruso
    if cyr > 0 and cyr >= latin * CYR_RATIO then
        return "ru", cyr, latin
    end
    if han > 0 and han >= latin * CYR_RATIO then
        return "zh", cyr, latin
    end

    -- Sin letras suficientes (solo números, símbolos, "k", "x"...)
    if latin < 2 then return nil, cyr, latin end

    -- Inglés vs español
    local en, es = 0, 0
    for w in text:lower():gmatch("[a-z']+") do
        if EN_WORDS[w] then en = en + 1 end
        if ES_WORDS[w] then es = es + 1 end
    end
    -- Tildes, ñ (\195 + byte) y signos ¿ ¡ (\194\191 / \194\161) => muy probable español
    es = es + 2 * Count(text, "\195[\128-\191]") + 2 * Count(text, "\194[\161\191]")

    if es > en then return "es", cyr, latin end
    return "en", cyr, latin
end
