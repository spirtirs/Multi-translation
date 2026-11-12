# RuEn Translator

Traductor de chat **offline** para World of Warcraft **5.4.8 (Mists of Pandaria)**.
Traduce **ruso/inglés → español** y **inglés ↔ chino** con diccionarios locales, sin
conexión a internet ni dependencias. El destino se selecciona según el idioma del cliente:
español (esES/esMX), inglés (enUS/enGB) o chino (zhCN/zhTW).
El glosario chino adjunto está en chino simplificado, también para clientes zhTW.

## Instalación

1. Copia la carpeta `RuEnTranslator` a:
   `World of Warcraft\Interface\AddOns\`
   (debe quedar `...\AddOns\RuEnTranslator\RuEnTranslator.toc`).
2. Inicia el juego. En la pantalla de selección de personaje, pulsa **Addons** y comprueba
   que *RuEn Translator* está activado. Si aparece como "desactualizado", marca
   **Cargar addons desactualizados**.
3. Al entrar verás en el chat: `[RuEn] v1.0.0 cargado`.

## Uso rápido

El addon funciona solo. Cuando alguien escriba en ruso o inglés en un canal activado,
verás el mensaje original y, debajo, la traducción:

```
[Ledii]: Ищу танка и хила в рейд
[RU>ES] busco tanque y sanador en banda
```

Canales activados por defecto: Decir, Grupo, Banda, Hermandad, Susurros, Instancia y
canales numerados (World). Gritar y Oficiales están desactivados.

Ventana de opciones: `/ret ui`, o el botón junto al minimapa (también hay un acceso directo en
Menú > Interfaz > AddOns > RuEn Translator).

## Comandos (`/ret` o `/ruen`)

| Comando | Acción |
|---|---|
| `/ret ui` (o `config`) | Abre la ventana principal con todas las opciones |
| `/ret minimap <on\|off>` | Muestra/oculta el botón del minimapa (clic izq.: ventana, clic der.: activar/desactivar, arrastrar: mover) |
| `/ret on` · `off` · `toggle` | Activa/desactiva la traducción |
| `/ret status` | Muestra la configuración |
| `/ret lang <ru\|en\|zh> <on\|off>` | Idiomas de origen |
| `/ret channel <canal> <on\|off>` | Canales: say, yell, party, raid, guild, officer, whisper, instance, world |
| `/ret original <on\|off>` | Mostrar/ocultar el mensaje original |
| `/ret layout <below\|inline>` | Traducción debajo o en la misma línea |
| `/ret color RRGGBB` | Color de la traducción |
| `/ret fontsize <8-24\|off>` | Tamaño de fuente de las ventanas de chat |
| `/ret coverage <0-100>` | % mínimo de palabras reconocidas para mostrar una traducción |
| `/ret translate <texto>` | Prueba el traductor y muestra la cobertura |
| `/ret detect <texto>` | Prueba la detección de idioma |
| `/ret add <ru\|en\|zh> <origen> = <traducción>` | Añade una entrada para el idioma de destino actual |
| `/ret del <ru\|en\|zh> <origen>` | Elimina una entrada propia |
| `/ret list [ru\|en\|zh]` | Lista tus entradas propias |
| `/ret learn <on\|off>` | Registra las palabras que el diccionario no conoce |
| `/ret unknown [ru\|en\|zh] [n]` · `clear` | Muestra las desconocidas más frecuentes |
| `/ret stats` · `clearcache` | Estadísticas / vaciar caché |
| `/ret debug <on\|off>` | Muestra errores internos en el chat |
| `/ret reset` | Restablece ajustes (conserva tu diccionario propio) |

## Cómo funciona (y sus límites)

La traducción es **palabra por palabra con frases**, sin gramática. Los glosarios
adjuntos añaden vocabulario de WoW para inglés↔chino; no proporcionan traducción general
de conversación. Otros idiomas de cliente aún no tienen rutas de diccionario. Funciona muy bien con
jerga de WoW (LFM, tanque, sanador, banda, botín...) y de forma aceptable con frases
cortas; la conversación libre en ruso solo se traduce en parte. Para no mostrar resultados
confusos, si se reconoce menos del 50 % de las palabras no se muestra nada
(ajustable con `/ret coverage`).

## Ampliar el diccionario

1. **Dentro del juego**: `/ret add ru привет = hola`. Para declinaciones rusas usa una
   raíz con asterisco: `/ret add ru рейд* = banda`.
2. **Con datos reales**: `/ret learn on`, deja correr el chat y luego `/ret unknown`
   para ver qué palabras faltan con más frecuencia. Añade las más comunes con `/ret add`.
   Con `learn` activo también se guardan los últimos 300 mensajes ru/en. Al salir del juego
   (o `/reload`) quedan en `WTF\Account\<CUENTA>\SavedVariables\RuEnTranslator.lua`:
   ese archivo se puede analizar directamente, sin copiar nada del chat.
3. **Editando archivos**: añade líneas `origen = traducción` en `Dict\Custom.lua`
   (tuyas), o en `Dict\ru.lua` / `Dict\en.lua`.

## Problemas frecuentes

- **No traduce nada**: comprueba `/ret status` (¿activado? ¿canal e idioma activos?) y
  prueba `/ret translate <texto>`. Si la cobertura es baja, baja el umbral o amplía el diccionario.
- **Errores de Lua**: `/console scriptErrors 1` y envía el texto del error.
- **"Se desactivó para proteger el chat"**: tras 5 fallos seguidos el addon se apaga solo.
  `/ret debug on` y `/ret on` para reintentar.

## Traducción online (futuro, opcional)

El cliente 5.4.8 no puede hacer peticiones HTTP, por lo que no hay traducción online
integrada. Existe un gancho para quien quiera enchufar otra fuente:

```lua
ns:RegisterProvider("miProveedor", function(texto, origen, destino)
    return "texto traducido" -- o nil si no sabe
end)
```

Solo se consulta cuando el diccionario no alcanza la cobertura mínima.

## Ventana externa de traducción (DeepL)

El addon no puede comunicarse directamente con programas externos. Como alternativa sin
modificar ni inyectar código en WoW, `Bridge\wow_chat_overlay.py` observa el archivo de
registro de chat del cliente y muestra las traducciones en una ventana separada. No
escribe traducciones dentro del juego. Las líneas nuevas se envían a DeepL, así que su
contenido sale del equipo.

1. Instala Python 3.10 o posterior (con Tkinter) y obtén una clave de DeepL API.
2. Dentro del juego, escribe `/chatlog` para activar el registro. El archivo suele estar
   en `World of Warcraft\Logs\WoWChatLog.txt`.
3. En PowerShell, configura la clave solo para la sesión actual e inicia la ventana:

   ```powershell
   $env:DEEPL_AUTH_KEY = "tu-clave-de-DeepL"
   python .\Bridge\wow_chat_overlay.py --log "C:\ruta\de\WoW\Logs\WoWChatLog.txt"
   ```

4. Elige el idioma de destino en la ventana. Al iniciar, el programa comienza al final del
   registro y traduce solo los mensajes nuevos. Cierra la ventana para detenerlo.

La clave no se guarda en el repositorio ni en un archivo de configuración. Las claves
DeepL Free (terminadas en `:fx`) usan el endpoint gratuito; las demás usan el endpoint Pro.

## Estructura

```
RuEnTranslator.toc   Core.lua      Detect.lua    Chat.lua
Translator.lua       Options.lua   Locales\esES.lua
Dict\Dict.lua  Dict\ru.lua  Dict\en.lua  Dict\Custom.lua
Dict\WoWTranslate_OutGlossary.lua  Dict\WoWTranslate_Glossary.lua
Bridge\wow_chat_overlay.py
```
# Multi-translation
