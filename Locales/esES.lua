--[[
    RuEnTranslator - Textos de interfaz (localización)
    Todos los textos visibles pasan por la tabla ns.L.
    Para añadir otro idioma de interfaz: crear Locales\xxXX.lua y
    sobrescribir claves dentro de un bloque `if GetLocale() == "xxXX" then`.
    Las claves que falten caen automáticamente en la clave misma (ver metatable).
]]

local ADDON_NAME, ns = ...

local L = setmetatable({}, { __index = function(t, k) return k end })
ns.L = L

-- General
L["ADDON_LOADED"]   = "cargado. Escribe |cffffff00/ret|r para ver los comandos."
L["ENABLED"]        = "Traducción |cff00ff00ACTIVADA|r."
L["DISABLED"]       = "Traducción |cffff0000DESACTIVADA|r."
L["RESET_DONE"]     = "Configuración restablecida a los valores por defecto."
L["UNKNOWN_CMD"]    = "Comando desconocido. Escribe |cffffff00/ret help|r."

-- Estado
L["STATUS_HEADER"]  = "Estado actual:"
L["STATUS_ENABLED"] = "Traducción"
L["STATUS_LANGS"]   = "Idiomas de origen"
L["STATUS_CHANNELS"]= "Canales"
L["STATUS_ORIGINAL"]= "Mostrar mensaje original"
L["ON"]             = "|cff00ff00sí|r"
L["OFF"]            = "|cffff0000no|r"

-- Idiomas
L["LANG_ru"]        = "Ruso"
L["LANG_en"]        = "Inglés"
L["LANG_zh"]        = "Chino"
L["LANG_SET"]       = "Idioma %s: %s"
L["LANG_INVALID"]   = "Idioma no válido. Usa: ru, en, zh."
L["STATUS_TARGET"]  = "Idioma de destino"
L["TARGET_en"]      = "Inglés"
L["TARGET_es"]      = "Español"
L["TARGET_zh"]      = "Chino"
L["TARGET_UNSUPPORTED"] = "No compatible con los diccionarios instalados"

-- Canales
L["CHAN_say"]       = "Decir"
L["CHAN_yell"]      = "Gritar"
L["CHAN_party"]     = "Grupo"
L["CHAN_raid"]      = "Banda"
L["CHAN_guild"]     = "Hermandad"
L["CHAN_officer"]   = "Oficiales"
L["CHAN_whisper"]   = "Susurros"
L["CHAN_instance"]  = "Instancia/BG"
L["CHAN_world"]     = "Canal World/público"
L["CHAN_SET"]       = "Canal %s: %s"
L["CHAN_INVALID"]   = "Canal no válido. Usa: say, yell, party, raid, guild, officer, whisper, instance, world."

-- Opciones
L["ORIGINAL_SET"]   = "Mostrar mensaje original: %s"

-- Fase 2
L["STATUS_LAYOUT"]   = "Disposición"
L["LAYOUT_SET"]      = "Disposición: %s"
L["LAYOUT_INVALID"]  = "Usa: /ret layout below|inline"
L["DEBUG_SET"]       = "Mostrar errores: %s"
L["DETECT_USAGE"]    = "Uso: /ret detect <texto>"
L["DETECT_RESULT"]   = "Idioma detectado: |cffffff00%s|r (cirílicas: %d, latinas: %d)"
L["HELP_LAYOUT"]     = "/ret layout <below|inline> - traducción debajo o en la misma línea"
L["HELP_DETECT"]     = "/ret detect <texto> - prueba la detección de idioma"
L["HELP_DEBUG"]      = "/ret debug <on|off> - muestra errores internos en el chat"

-- Fase 3
L["TR_USAGE"]        = "Uso: /ret translate <texto>"
L["TR_UNKNOWN"]      = "No se pudo determinar el idioma del texto."
L["TR_ALREADY_ES"]   = "El texto ya parece estar en español."
L["TR_NONE"]         = "Sin traducción: el diccionario %s no reconoce ninguna palabra."
L["TR_COVERAGE"]     = "Cobertura: %d%% (%d de %d palabras) - %s"
L["TR_SHOWN"]        = "se mostraría en el chat"
L["TR_HIDDEN"]       = "|cffff8800cobertura baja, NO se mostraría en el chat|r"
L["ADD_USAGE"]       = "Uso: /ret add <ru|en|zh> <origen> = <traducción>   (raíz rusa: origen*)"
L["ADD_OK"]          = "Añadido [%s]: %s = %s"
L["DEL_USAGE"]       = "Uso: /ret del <ru|en|zh> <origen>"
L["DEL_OK"]          = "Eliminado [%s]: %s"
L["DEL_NONE"]        = "No existe [%s]: %s"
L["LIST_EMPTY"]      = "No tienes entradas propias. Usa /ret add."
L["LIST_MORE"]       = "... y %d más."
L["STATS_DICT"]      = "Diccionario %s: %d entradas"
L["STATS_CACHE"]     = "Caché de traducciones: %d / %d"
L["CACHE_CLEARED"]   = "Caché vaciada."
L["HELP_TRANSLATE"]  = "/ret translate <texto> - prueba el traductor y muestra la cobertura"
L["HELP_ADD"]        = "/ret add <ru|en|zh> <origen> = <traducción> - añade una entrada al idioma de destino actual"
L["HELP_DEL"]        = "/ret del <ru|en|zh> <origen> - elimina una entrada propia"
L["HELP_LIST"]       = "/ret list [ru|en|zh] - muestra tus entradas propias"
-- Fase 5
L["FAILED"]          = "|cffff0000Se produjeron errores repetidos y la traducción se desactivó para proteger el chat.|r Activa |cffffff00/ret debug on|r, usa |cffffff00/ret on|r para reintentar y comunica el error."
L["INIT_ERROR"]      = "|cffff0000Error al iniciar el módulo %s:|r %s"
L["LEARN_SET"]       = "Registrar palabras desconocidas: %s"
L["UNKNOWN_EMPTY"]   = "Sin datos. Activa |cffffff00/ret learn on|r y deja correr el chat un rato."
L["UNKNOWN_CLEARED"] = "Lista de palabras desconocidas vaciada."
L["HELP_LEARN"]      = "/ret learn <on|off> - registra las palabras que el diccionario no conoce"
L["HELP_UNKNOWN"]    = "/ret unknown [ru|en|zh] [n] | clear - palabras desconocidas más frecuentes"

-- Fase 4: panel de opciones
L["OPT_DESC"]            = "Traductor offline Ruso/Inglés -> Español. Los cambios se aplican al instante."
L["OPT_ENABLED"]         = "Activar traducción"
L["OPT_SHOW_ORIGINAL"]   = "Mostrar el mensaje original"
L["OPT_SHOW_ORIGINAL_TIP"] = "Si lo desactivas, solo verás la traducción (cuando exista)."
L["OPT_LAYOUT"]          = "Disposición:"
L["LAYOUT_below"]        = "Traducción debajo del original"
L["LAYOUT_inline"]       = "Misma línea"
L["OPT_COLOR"]           = "Color de la traducción:"
L["OPT_PREVIEW"]         = "[RU>ES] Hola, busco tanque y sanador para la banda"
L["OPT_COVERAGE"]        = "Palabras reconocidas mínimas"
L["OPT_APPLY_FONT"]      = "Cambiar el tamaño de fuente del chat"
L["OPT_APPLY_FONT_TIP"]  = "WoW no permite un tamaño distinto por mensaje: esto cambia el tamaño de TODAS las ventanas de chat."
L["OPT_FONT"]            = "Tamaño de fuente"
L["OPT_LANGS"]           = "Idiomas de origen a traducir"
L["OPT_CHANNELS"]        = "Canales a traducir"
L["OPT_RESET"]           = "Restablecer valores"
L["COLOR_USAGE"]         = "Uso: /ret color RRGGBB   (ejemplo: /ret color 66CCFF)"
L["COLOR_SET"]           = "Color de la traducción: |cff%s%s|r"
L["FONT_USAGE"]          = "Uso: /ret fontsize <8-24> | off"
L["FONT_SET"]            = "Tamaño de fuente del chat: %d"
L["FONT_OFF"]            = "Ya no se modifica el tamaño de fuente del chat."
L["HELP_CONFIG"]         = "/ret ui (o config) - abre la ventana principal"
L["HELP_MINIMAP"]        = "/ret minimap <on|off> - muestra u oculta el botón del minimapa"
L["MINIMAP_SET"]         = "Botón del minimapa visible: %s"

-- Ventana visual
L["UI_SUBTITLE"]         = "Traductor offline Ruso/Inglés -> Español"
L["UI_ON"]               = "ACTIVADA"
L["UI_OFF"]              = "DESACTIVADA"
L["UI_TAB_GENERAL"]      = "General"
L["UI_TAB_CHANNELS"]     = "Canales"
L["UI_TAB_LOOK"]         = "Apariencia"
L["UI_LAYOUT"]           = "Disposición de la traducción"
L["UI_CARD_BELOW"]       = "Debajo del original"
L["UI_CARD_BELOW_SAMPLE"]  = "Mensaje original\n|cff66ccff[RU>ES] traducción|r"
L["UI_CARD_INLINE"]      = "En la misma línea"
L["UI_CARD_INLINE_SAMPLE"] = "Mensaje original |cff66ccff[RU>ES] traducción|r"
L["UI_COVERAGE_HINT"]    = "Más bajo = más traducciones parciales. Más alto = solo las más fiables."
L["UI_ALL"]              = "Todos"
L["UI_NONE"]             = "Ninguno"
L["UI_RECOMMENDED"]      = "Recomendado"
L["UI_CHANNELS_HINT"]    = "World incluye todos los canales numerados (General, Comercio, World...)."
L["UI_COLOR_CUSTOM"]     = "Color personalizado"
L["UI_COLOR_HINT"]       = "Elige un color predefinido, o pulsa el cuadro grande para el selector. También: /ret color RRGGBB"
L["UI_FONT_HINT"]        = "WoW no permite un tamaño distinto por mensaje: afecta a TODAS las ventanas de chat."
L["UI_PREVIEW"]          = "VISTA PREVIA"
L["UI_STATS"]            = "Diccionarios: ru %d - en>es %d - en>zh %d - zh>en %d - caché %d"
L["UI_TIP_LEFT"]         = "Clic izquierdo: abrir la ventana"
L["UI_TIP_RIGHT"]        = "Clic derecho: activar/desactivar"
L["UI_TIP_DRAG"]         = "Arrastrar: mover el botón"
L["UI_OPEN"]             = "Abrir ventana de RuEn Translator"
L["UI_LAUNCHER_DESC"]    = "Todas las opciones están en la ventana propia del addon (también: /ret ui)."
L["HELP_COLOR"]          = "/ret color <RRGGBB> - color de la traducción"
L["HELP_FONT"]           = "/ret fontsize <8-24|off> - tamaño de fuente de las ventanas de chat"

L["COVERAGE_USAGE"]  = "Uso: /ret coverage <0-100>. Valor actual: %d%%"
L["COVERAGE_SET"]    = "Cobertura mínima: %d%% (menos = muestra más traducciones parciales)"
L["HELP_COVERAGE"]   = "/ret coverage <0-100> - % mínimo de palabras reconocidas para traducir"
L["HELP_STATS"]      = "/ret stats | clearcache - estadísticas / vaciar caché"

-- Ayuda
L["HELP_HEADER"]    = "Comandos (|cffffff00/ret|r o |cffffff00/ruen|r):"
L["HELP_TOGGLE"]    = "/ret on | off | toggle - activa/desactiva la traducción"
L["HELP_STATUS"]    = "/ret status - muestra la configuración actual"
L["HELP_LANG"]      = "/ret lang <ru|en|zh> <on|off> - idiomas de origen a traducir"
L["HELP_CHANNEL"]   = "/ret channel <canal> <on|off> - canales a traducir"
L["HELP_ORIGINAL"]  = "/ret original <on|off> - mostrar/ocultar el mensaje original"
L["HELP_RESET"]     = "/ret reset - restablece la configuración"
