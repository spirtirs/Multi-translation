--[[
    RuEnTranslator - Options.lua  (interfaz visual)

    - Ventana propia con pestañas (General / Canales / Apariencia) y vista previa en vivo
    - Botón del minimapa:  clic izq. = ventana,  clic der. = activar/desactivar,
      arrastrar = mover.   (/ret minimap para ocultarlo)
    - Panel de "Opciones de Interfaz" reducido a un acceso directo a la ventana

    Abrir:  /ret ui   (o /ret config)

    Todo se aplica al instante sobre ns.db. Sin librerías externas: solo API de 5.4.8
    (SetBackdrop con WHITE8X8, OptionsSliderTemplate, ColorPickerFrame, Minimap).

    Tamaño de fuente: WoW no permite un tamaño distinto por mensaje de chat, así que la
    opción cambia el tamaño de TODAS las ventanas de chat (y es opcional).
]]

local ADDON_NAME, ns = ...
local L = ns.L

local win, previewFS, statsFS, minimapBtn, launcher
local widgets = {}                 -- controles de la ventana con refresh()

------------------------------------------------------------------------
-- Estilo
------------------------------------------------------------------------
local FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local C = {
    bg     = { 0.07, 0.08, 0.10, 0.97 },
    panel  = { 0.11, 0.13, 0.16, 1 },
    line   = { 0.27, 0.30, 0.36, 1 },
    on     = { 0.14, 0.42, 0.26, 1 },
    off    = { 0.16, 0.17, 0.21, 1 },
    accent = { 0.40, 0.80, 1.00, 1 },
}
local PRESET_COLORS = { "66CCFF", "66FF99", "FFD966", "FFA64D", "FF80BF", "B380FF", "FFFFFF", "AAAAAA" }

local function Paint(frame, bg, border)
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function Box(parent, w, h, bg, border)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(w); f:SetHeight(h)
    f:SetBackdrop(FLAT)
    Paint(f, bg, border)
    return f
end

local function Text(parent, str, x, y, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(str)
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function Tip(frame, title, body)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

local function HexToRGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

------------------------------------------------------------------------
-- Acciones con efecto fuera de la ventana
------------------------------------------------------------------------
-- Cambia el tamaño de fuente de todas las ventanas de chat (si la opción está activa).
function ns:ApplyFontSize()
    local db = ns.db
    if not db or not db.applyFontSize then return end
    if not FCF_SetChatWindowFontSize then return end
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local cf = _G["ChatFrame" .. i]
        if cf then FCF_SetChatWindowFontSize(nil, cf, db.fontSize) end
    end
end

------------------------------------------------------------------------
-- Controles
------------------------------------------------------------------------
-- Interruptor tipo botón: punto verde + fondo verde cuando está activo.
local function NewToggle(parent, label, x, y, w, h, get, set, tipTitle, tipBody)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetBackdrop(FLAT)

    local dot = b:CreateTexture(nil, "ARTWORK")
    dot:SetWidth(10); dot:SetHeight(10)
    dot:SetPoint("LEFT", b, "LEFT", 10, 0)
    dot:SetTexture(1, 1, 1)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "LEFT", 28, 0)
    fs:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)

    local hover = false
    local function Repaint()
        local on = get() and true or false
        Paint(b, on and C.on or C.off, hover and C.accent or C.line)
        if on then dot:SetTexture(0.35, 1, 0.55) else dot:SetTexture(0.45, 0.45, 0.50) end
    end

    b:SetScript("OnClick", function() set(not get()); ns:RefreshOptions() end)
    b:SetScript("OnEnter", function(self)
        hover = true; Repaint()
        if tipTitle then Tip(self, tipTitle, tipBody) end
    end)
    b:SetScript("OnLeave", function() hover = false; Repaint(); GameTooltip:Hide() end)
    b.refresh = Repaint
    widgets[#widgets + 1] = b
    return b
end

local function NewButton(parent, label, x, y, w, h, onclick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetBackdrop(FLAT)
    Paint(b, C.off, C.line)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    b:SetScript("OnEnter", function() Paint(b, C.panel, C.accent) end)
    b:SetScript("OnLeave", function() Paint(b, C.off, C.line) end)
    b:SetScript("OnClick", onclick)
    return b
end

-- Tarjeta de selección (disposición): borde azul cuando está elegida.
local function NewCard(parent, key, title, sample, x, y, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetBackdrop(FLAT)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    t:SetText(title)
    local s = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -28)
    s:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    s:SetJustifyH("LEFT")
    s:SetText(sample)
    b:SetScript("OnClick", function() ns.db.layout = key; ns:RefreshOptions() end)
    b.refresh = function()
        local sel = ns.db.layout == key
        Paint(b, sel and C.panel or C.off, sel and C.accent or C.line)
    end
    widgets[#widgets + 1] = b
    return b
end

local function NewSlider(parent, name, text, minV, maxV, step, fmt, x, y, w, get, set)
    local sname = "RuEnUI" .. name
    local s = CreateFrame("Slider", sname, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetWidth(w)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[sname .. "Low"]:SetText(minV)
    _G[sname .. "High"]:SetText(maxV)

    local function UpdateText(v) _G[sname .. "Text"]:SetText(text .. ": " .. fmt:format(v)) end

    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        UpdateText(v)
        if not self.updating then set(v); ns:RefreshPreview() end
    end)
    s.refresh = function()
        s.updating = true
        local v = get()
        s:SetValue(v)
        UpdateText(v)
        s.updating = false
    end
    widgets[#widgets + 1] = s
    return s
end

------------------------------------------------------------------------
-- Vista previa y estadísticas
------------------------------------------------------------------------
local PREVIEW_ORIGINAL = "|cffffd100[Ledii]:|r Ищу танка и хила в рейд"
local PREVIEW_TRANSLATION = "[RU>ES] busco tanque y sanador en banda"

function ns:RefreshPreview()
    if not previewFS or not ns.db then return end
    local db = ns.db
    local c = db.color
    local hex = string.format("|cff%02x%02x%02x",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
    local tr = hex .. PREVIEW_TRANSLATION .. "|r"

    local text
    if not db.showOriginal then
        text = "|cffffd100[Ledii]:|r " .. tr
    elseif db.layout == "inline" then
        text = PREVIEW_ORIGINAL .. " " .. tr
    else
        text = PREVIEW_ORIGINAL .. "\n" .. tr
    end

    local path, _, flags = ChatFontNormal:GetFont()
    previewFS:SetFont(path, (db.applyFontSize and db.fontSize) or 14, flags)
    previewFS:SetText(text)
end

local function RefreshStats()
    if not statsFS or not ns.Dict then return end
    local D = ns.Dict.data
    statsFS:SetText(L["UI_STATS"]:format(D.ru.count, D.en.count,
        ns.Translator and ns.Translator:CacheSize() or 0))
end

------------------------------------------------------------------------
-- Botón del minimapa
------------------------------------------------------------------------
local function PlaceMinimapButton()
    local a = math.rad(ns.db.minimap.angle or 215)
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

local function RefreshMinimapButton()
    if not minimapBtn or not ns.db then return end
    if ns.db.minimap.hide then minimapBtn:Hide() else minimapBtn:Show() end
    PlaceMinimapButton()
    minimapBtn.icon:SetDesaturated(not ns.db.enabled)
end

local function BuildMinimapButton()
    local btn = CreateFrame("Button", "RuEnMinimapButton", Minimap)
    minimapBtn = btn
    btn:SetWidth(31); btn:SetHeight(31)
    btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetWidth(20); bg:SetHeight(20)
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(18); icon:SetHeight(18)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53); border:SetHeight(53)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            ns:SetEnabled(not ns.db.enabled)
            ns:RefreshOptions()
        else
            ns:ToggleWindow()
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
            PlaceMinimapButton()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("RuEn Translator", 0.4, 0.8, 1)
        GameTooltip:AddLine(ns.db.enabled and L["ENABLED"] or L["DISABLED"])
        GameTooltip:AddLine(L["UI_TIP_LEFT"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["UI_TIP_RIGHT"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["UI_TIP_DRAG"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    RefreshMinimapButton()
end

------------------------------------------------------------------------
-- Ventana principal
------------------------------------------------------------------------
local function BuildWindow()
    win = CreateFrame("Frame", "RuEnTranslatorWindow", UIParent)
    win:SetWidth(460); win:SetHeight(548)
    win:SetPoint("CENTER")
    win:SetFrameStrata("HIGH")                 -- por debajo del selector de color (DIALOG)
    win:SetMovable(true); win:EnableMouse(true); win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetBackdrop(FLAT)
    Paint(win, C.bg, C.line)
    win:Hide()
    tinsert(UISpecialFrames, "RuEnTranslatorWindow")   -- se cierra con ESC

    -- Cabecera ---------------------------------------------------------
    Text(win, "RuEn Translator", 16, -12, "GameFontNormalLarge", C.accent[1], C.accent[2], C.accent[3])
    Text(win, "v" .. ns.version .. "  -  " .. L["UI_SUBTITLE"], 16, -34, "GameFontHighlightSmall", 0.6, 0.62, 0.68)

    local line = win:CreateTexture(nil, "ARTWORK")
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", win, "TOPLEFT", 1, -54)
    line:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -54)
    line:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)

    -- Interruptor general
    local master = CreateFrame("Button", nil, win)
    master:SetWidth(120); master:SetHeight(26)
    master:SetPoint("TOPRIGHT", win, "TOPRIGHT", -40, -14)
    master:SetBackdrop(FLAT)
    local mfs = master:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mfs:SetPoint("CENTER")
    master:SetScript("OnClick", function() ns:SetEnabled(not ns.db.enabled, true); ns:RefreshOptions() end)
    master.refresh = function()
        local on = ns.db.enabled
        Paint(master, on and C.on or { 0.45, 0.14, 0.14, 1 }, C.line)
        mfs:SetText(on and L["UI_ON"] or L["UI_OFF"])
    end
    widgets[#widgets + 1] = master

    -- Pestañas -----------------------------------------------------------
    local tabNames = { L["UI_TAB_GENERAL"], L["UI_TAB_CHANNELS"], L["UI_TAB_LOOK"] }
    local tabButtons, contents = {}, {}

    local function SelectTab(index)
        for i, content in ipairs(contents) do
            if i == index then content:Show() else content:Hide() end
            local sel = (i == index)
            Paint(tabButtons[i], sel and C.panel or C.off, sel and C.accent or C.line)
        end
        win.activeTab = index
    end

    for i, name in ipairs(tabNames) do
        local tb = CreateFrame("Button", nil, win)
        tb:SetWidth(140); tb:SetHeight(26)
        tb:SetPoint("TOPLEFT", win, "TOPLEFT", 12 + (i - 1) * 146, -64)
        tb:SetBackdrop(FLAT)
        local fs = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(name)
        tb:SetScript("OnClick", function() SelectTab(i) end)
        tabButtons[i] = tb

        local content = CreateFrame("Frame", nil, win)
        content:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -98)
        content:SetWidth(436); content:SetHeight(290)
        contents[i] = content
    end

    -- Pestaña 1: General -------------------------------------------------
    local g = contents[1]
    NewToggle(g, L["OPT_SHOW_ORIGINAL"], 0, -4, 436, 30,
        function() return ns.db.showOriginal end,
        function(v) ns.db.showOriginal = v end,
        L["OPT_SHOW_ORIGINAL"], L["OPT_SHOW_ORIGINAL_TIP"])

    Text(g, L["UI_LAYOUT"], 2, -46, "GameFontNormal")
    NewCard(g, "below", L["UI_CARD_BELOW"], L["UI_CARD_BELOW_SAMPLE"], 0, -66, 214, 64)
    NewCard(g, "inline", L["UI_CARD_INLINE"], L["UI_CARD_INLINE_SAMPLE"], 222, -66, 214, 64)

    Text(g, L["OPT_LANGS"], 2, -146, "GameFontNormal")
    for i, key in ipairs(ns.LANG_ORDER) do
        NewToggle(g, L["LANG_" .. key], (i - 1) * 222, -166, 214, 30,
            function() return ns.db.languages[key] end,
            function(v) ns.db.languages[key] = v end)
    end

    NewSlider(g, "Coverage", L["OPT_COVERAGE"], 10, 100, 5, "%d%%", 12, -230, 410,
        function() return math.floor(ns.db.minCoverage * 100 + 0.5) end,
        function(v)
            ns.db.minCoverage = v / 100
            if ns.Translator then ns.Translator:ClearCache() end
        end)
    Text(g, L["UI_COVERAGE_HINT"], 2, -258, "GameFontHighlightSmall", 0.6, 0.62, 0.68)

    -- Pestaña 2: Canales ---------------------------------------------------
    local ch = contents[2]
    Text(ch, L["OPT_CHANNELS"], 2, -4, "GameFontNormal")
    for i, key in ipairs(ns.CHANNEL_ORDER) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        NewToggle(ch, L["CHAN_" .. key], col * 148, -26 - row * 40, 140, 32,
            function() return ns.db.channels[key] end,
            function(v) ns.db.channels[key] = v end)
    end

    local function SetAllChannels(fn)
        for _, key in ipairs(ns.CHANNEL_ORDER) do ns.db.channels[key] = fn(key) end
        ns:RefreshOptions()
    end
    NewButton(ch, L["UI_ALL"], 0, -156, 100, 24, function() SetAllChannels(function() return true end) end)
    NewButton(ch, L["UI_NONE"], 108, -156, 100, 24, function() SetAllChannels(function() return false end) end)
    NewButton(ch, L["UI_RECOMMENDED"], 216, -156, 140, 24,
        function() SetAllChannels(function(k) return ns.defaults.channels[k] end) end)
    Text(ch, L["UI_CHANNELS_HINT"], 2, -194, "GameFontHighlightSmall", 0.6, 0.62, 0.68)
    ch.hint = nil

    -- Pestaña 3: Apariencia --------------------------------------------------
    local lk = contents[3]
    Text(lk, L["OPT_COLOR"], 2, -4, "GameFontNormal")

    local sw = CreateFrame("Button", nil, lk)
    sw:SetWidth(30); sw:SetHeight(30)
    sw:SetPoint("TOPLEFT", lk, "TOPLEFT", 0, -26)
    sw:SetBackdrop(FLAT)

    local function SetColor(r, g2, b)
        ns.db.color.r, ns.db.color.g, ns.db.color.b = r, g2, b
        ns:RefreshOptions()
    end

    sw:SetScript("OnClick", function()
        local c = ns.db.color
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r = c.r, g = c.g, b = c.b }
        ColorPickerFrame.func = function() SetColor(ColorPickerFrame:GetColorRGB()) end
        ColorPickerFrame.cancelFunc = function(prev) SetColor(prev.r, prev.g, prev.b) end
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorPickerFrame:Hide()   -- Hide+Show fuerza que el selector lea los valores nuevos
        ColorPickerFrame:Show()
    end)
    sw:SetScript("OnEnter", function(self) Tip(self, L["UI_COLOR_CUSTOM"], L["UI_COLOR_HINT"]) end)
    sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sw.refresh = function()
        local c = ns.db.color
        sw:SetBackdropColor(c.r, c.g, c.b, 1)
        sw:SetBackdropBorderColor(1, 1, 1, 1)
    end
    widgets[#widgets + 1] = sw

    for i, hex in ipairs(PRESET_COLORS) do
        local p = CreateFrame("Button", nil, lk)
        p:SetWidth(24); p:SetHeight(24)
        p:SetPoint("TOPLEFT", lk, "TOPLEFT", 44 + (i - 1) * 30, -29)
        p:SetBackdrop(FLAT)
        local r, g2, b = HexToRGB(hex)
        p:SetBackdropColor(r, g2, b, 1)
        p:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
        p:SetScript("OnClick", function() SetColor(r, g2, b) end)
        p:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1, 1) end)
        p:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1) end)
    end
    Text(lk, L["UI_COLOR_HINT"], 2, -64, "GameFontHighlightSmall", 0.6, 0.62, 0.68)

    NewToggle(lk, L["OPT_APPLY_FONT"], 0, -96, 436, 30,
        function() return ns.db.applyFontSize end,
        function(v) ns.db.applyFontSize = v; ns:ApplyFontSize() end,
        L["OPT_APPLY_FONT"], L["OPT_APPLY_FONT_TIP"])
    NewSlider(lk, "Font", L["OPT_FONT"], 8, 24, 1, "%d", 12, -156, 410,
        function() return ns.db.fontSize end,
        function(v) ns.db.fontSize = v; ns:ApplyFontSize() end)
    Text(lk, L["UI_FONT_HINT"], 2, -184, "GameFontHighlightSmall", 0.6, 0.62, 0.68)

    -- Vista previa (visible en todas las pestañas) ---------------------------------
    Text(win, L["UI_PREVIEW"], 14, -396, "GameFontNormalSmall", 0.6, 0.62, 0.68)
    local box = Box(win, 436, 92, C.panel, C.line)
    box:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -412)
    previewFS = box:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    previewFS:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -10)
    previewFS:SetWidth(416)
    previewFS:SetJustifyH("LEFT")
    previewFS:SetJustifyV("TOP")

    -- Pie ------------------------------------------------------------------------------
    NewButton(win, L["OPT_RESET"], 12, -516, 150, 24, function()
        ns:ResetDB()
        ns:RefreshOptions()
        ns:ApplyFontSize()
        ns:Print(L["RESET_DONE"])
    end)
    statsFS = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statsFS:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 16)
    statsFS:SetTextColor(0.6, 0.62, 0.68)

    win:SetScript("OnShow", function() ns:RefreshOptions() end)
    SelectTab(1)
end

------------------------------------------------------------------------
-- Panel de Opciones de Interfaz (acceso directo)
------------------------------------------------------------------------
local function BuildLauncher()
    launcher = CreateFrame("Frame", "RuEnTranslatorOptions", UIParent)
    launcher.name = "RuEn Translator"
    ns.optionsPanel = launcher

    local title = launcher:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", launcher, "TOPLEFT", 16, -16)
    title:SetText("RuEn Translator")
    local desc = launcher:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", launcher, "TOPLEFT", 16, -44)
    desc:SetText(L["UI_LAUNCHER_DESC"])

    local btn = CreateFrame("Button", "RuEnOptOpen", launcher, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", launcher, "TOPLEFT", 16, -76)
    btn:SetWidth(220); btn:SetHeight(26)
    btn:SetText(L["UI_OPEN"])
    btn:SetScript("OnClick", function()
        if InterfaceOptionsFrame then InterfaceOptionsFrame:Hide() end
        if HideUIPanel and GameMenuFrame then HideUIPanel(GameMenuFrame) end
        ns:ShowWindow()
    end)

    launcher.refresh, launcher.okay, launcher.cancel, launcher.default = function() end, function() end, function() end, function() end
    InterfaceOptions_AddCategory(launcher)
end

------------------------------------------------------------------------
-- API pública
------------------------------------------------------------------------
function ns:RefreshOptions()
    if not ns.db then return end
    for _, w in ipairs(widgets) do w.refresh() end
    ns:RefreshPreview()
    RefreshStats()
    RefreshMinimapButton()
end

function ns:ShowWindow()
    if win then win:Show(); win:Raise() end
end

function ns:ToggleWindow()
    if not win then return end
    if win:IsShown() then win:Hide() else win:Show(); win:Raise() end
end

ns.OpenOptions = ns.ShowWindow

-- Construye todo; cada pieza va protegida para que un fallo no tumbe a las demás.
function ns:BuildOptions()
    if win then return end
    ns:SafeCall("Ventana",    BuildWindow)
    ns:SafeCall("Minimapa",   BuildMinimapButton)
    ns:SafeCall("Opciones UI", BuildLauncher)
    ns:RefreshOptions()
end

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------
local commands = ns.commands

function commands.ui() ns:ToggleWindow() end
commands.config  = commands.ui
commands.options = commands.ui

-- /ret minimap  -> muestra/oculta el botón del minimapa
function commands.minimap(args)
    local state = ns.ParseBool(args:match("^(%S+)"))
    if state == nil then state = ns.db.minimap.hide end   -- alterna
    ns.db.minimap.hide = not state
    ns:RefreshOptions()
    ns:Print(L["MINIMAP_SET"]:format(ns.YesNo(state)))
end

-- /ret color RRGGBB
function commands.color(args)
    local hex = args:match("^#?(%x%x%x%x%x%x)")
    if not hex then ns:Print(L["COLOR_USAGE"]); return end
    local c = ns.db.color
    c.r, c.g, c.b = HexToRGB(hex)
    ns:RefreshOptions()
    ns:Print(L["COLOR_SET"]:format(hex:upper()))
end

-- /ret fontsize <8-24 | off>
function commands.fontsize(args)
    local arg = args:match("^(%S+)")
    if arg and arg:lower() == "off" then
        ns.db.applyFontSize = false
        ns:RefreshOptions()
        ns:Print(L["FONT_OFF"])
        return
    end
    local n = tonumber(arg)
    if not n or n < 8 or n > 24 then ns:Print(L["FONT_USAGE"]); return end
    ns.db.fontSize = math.floor(n)
    ns.db.applyFontSize = true
    ns:ApplyFontSize()
    ns:RefreshOptions()
    ns:Print(L["FONT_SET"]:format(ns.db.fontSize))
end
