--[[
    RuEnTranslator - Dict\Custom.lua : TUS PROPIAS ENTRADAS

    Edita este archivo para añadir términos (se carga después de los diccionarios
    incluidos, así que sobrescribe cualquier entrada repetida). Una línea por entrada:

        origen = traducción
        raíz* = traducción         (el * final = raíz, útil para ruso)

    También puedes añadirlas dentro del juego sin editar archivos:
        /ret add ru привет = hola
        /ret add en wipe = desastre

    Nota: este archivo se mantiene en las actualizaciones de forma manual; las entradas
    de /ret add se guardan aparte, en SavedVariables.
]]

local ADDON_NAME, ns = ...

-- Descomenta y adapta:
-- ns.Dict:LoadString("ru", [[
-- привет = hola
-- ]])

-- ns.Dict:LoadString("en", [[
-- wipe = desastre
-- ]])
