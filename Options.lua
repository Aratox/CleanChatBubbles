--[[--------------------------------------------------------------------------
	Clean Chat Bubbles - Optionsmenue

	Baut eine Canvas-Seite und haengt sie in das Interface-/AddOn-Optionsfenster
	(ESC > Optionen > AddOns  bzw.  Interface > AddOns). Aenderungen wirken
	sofort - jeder Regler ruft ns.Apply() im Kernmodul auf.

	Lib-frei. Registrierung ueber die moderne Settings-API mit Fallback auf
	InterfaceOptions_AddCategory. Widgets nur aus Basis-Templates
	(UIDropDownMenuTemplate, UISliderTemplate, UICheckButtonTemplate).
----------------------------------------------------------------------------]]

local _, ns = ...

local RefreshPreview           -- forward-declared, in BuildOptions befuellt
local previewText, previewReadBG

local MODES = {
	{ value = "textonly", text = "Nur Text (keine Sprechblase)" },
	{ value = "notail",   text = "Sprechblase, aber ohne Zeiger" },
	{ value = "default",  text = "Blizzard-Standard" },
}

local OUTLINES = {
	{ value = "NONE",         text = "Keine" },
	{ value = "OUTLINE",      text = "Duenn" },
	{ value = "THICKOUTLINE", text = "Dick" },
}

-- Fallback-Schriftliste, wenn LibSharedMedia nicht geladen ist
local BUILTIN_FONTS = {
	{ value = "Fonts\\FRIZQT__.TTF", text = "Friz Quadrata" },
	{ value = "Fonts\\ARIALN.TTF",   text = "Arial Narrow" },
	{ value = "Fonts\\MORPHEUS.TTF", text = "Morpheus" },
	{ value = "Fonts\\SKURRI.TTF",   text = "Skurri" },
}

local function BuildFontList()
	local list = { { value = "", text = "Standard (Chat-Bubble)" } }
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM then
		for _, name in ipairs(LSM:List("font")) do
			list[#list + 1] = { value = name, text = name }
		end
	else
		for _, f in ipairs(BUILTIN_FONTS) do
			list[#list + 1] = f
		end
	end
	return list
end

-- Fuer jeden Schriftwert ein Font-Objekt (fuer die Darstellung im Dropdown) - gecacht.
local fontObjCache, fontObjCount = {}, 0
local function FontObjectFor(value)
	local path = ns.FontValueToPath and ns.FontValueToPath(value)
	if not path then return nil end
	if fontObjCache[path] ~= nil then
		return fontObjCache[path] or nil
	end
	fontObjCount = fontObjCount + 1
	local fo = CreateFont("CCBFontMenu" .. fontObjCount)
	if fo:SetFont(path, 14, "") == false then
		fontObjCache[path] = false -- Pfad taugt nicht -> nicht erneut versuchen
		return nil
	end
	fo:SetTextColor(1, 1, 1)
	fontObjCache[path] = fo
	return fo
end

local function TextFor(list, value)
	for _, item in ipairs(list) do
		if item.value == value then return item.text end
	end
	return value
end

----------------------------------------------------------------------
-- Widget-Helfer
----------------------------------------------------------------------

local function MakeDropdown(parent, id, label, list, get, set, width, itemFont)
	local dd = CreateFrame("Frame", "CCBOpt_" .. id, parent, "UIDropDownMenuTemplate")

	local title = dd:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 18, 3)
	title:SetText(label)

	-- Text am geschlossenen Dropdown in der gewaehlten Schrift zeigen
	local function applyButtonFont()
		if not itemFont then return end
		local fs = _G[dd:GetName() .. "Text"]
		if fs then fs:SetFontObject(itemFont(get()) or GameFontHighlightSmall) end
	end

	UIDropDownMenu_SetWidth(dd, width or 220)
	UIDropDownMenu_JustifyText(dd, "LEFT")
	UIDropDownMenu_Initialize(dd, function()
		for _, item in ipairs(list) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = item.text
			info.checked = (get() == item.value)
			if itemFont then info.fontObject = itemFont(item.value) end -- Eintrag in seiner Schrift
			info.func = function()
				set(item.value)
				UIDropDownMenu_SetText(dd, item.text)
				applyButtonFont()
				if ns.Apply then ns.Apply() end
				if RefreshPreview then RefreshPreview() end
			end
			UIDropDownMenu_AddButton(info)
		end
	end)

	function dd.Refresh()
		UIDropDownMenu_SetText(dd, TextFor(list, get()))
		applyButtonFont()
	end

	return dd
end

-- Bewusst nur Basis-Templates (UISliderTemplate / UICheckButtonTemplate), die
-- es in jedem Client gibt; Beschriftungen bauen wir selbst, damit nichts von
-- optionalen "OptionsSlider"-/"InterfaceOptions"-Templates abhaengt.
local function MakeSlider(parent, id, label, minV, maxV, step, get, set, fmt)
	local s = CreateFrame("Slider", "CCBOpt_" .. id, parent, "UISliderTemplate")
	s:SetOrientation("HORIZONTAL")
	s:SetSize(320, 17)
	s:SetMinMaxValues(minV, maxV)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end

	local caption = s:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	caption:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 3)

	local low = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	low:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)
	low:SetText(fmt(minV))
	local high = s:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	high:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)
	high:SetText(fmt(maxV))

	local applying = false
	s:SetScript("OnValueChanged", function(_, v)
		v = math.floor((v - minV) / step + 0.5) * step + minV -- auf Raster runden
		caption:SetText(label .. ": " .. fmt(v))
		if not applying then
			set(v)
			if ns.Apply then ns.Apply() end
			if RefreshPreview then RefreshPreview() end
		end
	end)

	function s.Refresh()
		applying = true
		local v = get()
		s:SetValue(v)
		caption:SetText(label .. ": " .. fmt(v))
		applying = false
	end

	return s
end

local function MakeCheck(parent, id, label, get, set)
	local c = CreateFrame("CheckButton", "CCBOpt_" .. id, parent, "UICheckButtonTemplate")
	c:SetSize(26, 26)

	local text = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", c, "RIGHT", 2, 1)
	text:SetText(label)

	c:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		if ns.Apply then ns.Apply() end
		if RefreshPreview then RefreshPreview() end
	end)

	function c.Refresh()
		c:SetChecked(get() and true or false)
	end

	return c
end

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------

local panel = CreateFrame("Frame")
panel.name = "Clean Chat Bubbles"

local widgets = {}
local built = false
local category
local RegisterPanel -- forward-declared, weiter unten definiert

local function db() return ns.db or ns.DEFAULTS end

function panel.refresh()
	for _, w in ipairs(widgets) do
		if w.Refresh then w.Refresh() end
	end
	if RefreshPreview then RefreshPreview() end
end

function ns.BuildOptions()
	if built then return end
	built = true

	panel:SetScript("OnShow", panel.refresh) -- Werte beim OEffnen synchronisieren

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Clean Chat Bubbles")

	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText("Sprechblasen-Grafik der Chat-Bubbles ausblenden oder bearbeiten. Aenderungen wirken sofort.")

	-- Live-Vorschau
	local pvLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	pvLabel:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
	pvLabel:SetText("Vorschau")

	local pv = CreateFrame("Frame", nil, panel)
	pv:SetSize(380, 58)
	pv:SetPoint("TOPLEFT", pvLabel, "BOTTOMLEFT", 0, -4)

	-- heller 1px-Rahmen (liegt hinter dem Grund)
	local frame = pv:CreateTexture(nil, "BACKGROUND", nil, -2)
	frame:SetPoint("TOPLEFT", pv, "TOPLEFT", -1, 1)
	frame:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", 1, -1)
	frame:SetColorTexture(1, 1, 1, 0.18)

	local ground = pv:CreateTexture(nil, "BACKGROUND", nil, -1)
	ground:SetAllPoints(pv)
	ground:SetColorTexture(0.24, 0.27, 0.31, 1) -- neutraler "Gelaende"-Ton, damit Kontur/Schatten sichtbar sind

	local readBG = pv:CreateTexture(nil, "BORDER")
	readBG:SetColorTexture(0, 0, 0, 1)
	readBG:Hide()

	-- Startschrift ueber ein garantiert vorhandenes Fontobjekt, damit der Text
	-- auf jeden Fall sichtbar ist; RefreshPreview stellt danach die echten Werte ein.
	local sample = pv:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	sample:SetTextColor(1, 1, 1, 1)
	sample:SetPoint("CENTER")
	sample:SetWidth(350)
	sample:SetJustifyH("CENTER")
	sample:SetWordWrap(true)
	sample:SetText("Beispieltext:  |cffffd100Hallo Azeroth!|r  So wirkt sich die Einstellung aus.")

	readBG:SetPoint("TOPLEFT", sample, "TOPLEFT", -6, 4)
	readBG:SetPoint("BOTTOMRIGHT", sample, "BOTTOMRIGHT", 6, -4)

	previewText, previewReadBG = sample, readBG

	-- Modus
	local mode = MakeDropdown(panel, "Mode", "Modus", MODES,
		function() return db().mode end,
		function(v) db().mode = v end)
	mode:SetPoint("TOPLEFT", pv, "BOTTOMLEFT", -2, -22)
	widgets[#widgets + 1] = mode

	-- Schriftart (rechts neben Modus) - Eintraege werden in ihrer eigenen Schrift dargestellt
	local face = MakeDropdown(panel, "Face", "Schriftart", BuildFontList(),
		function() return db().font or "" end,
		function(v) db().font = v end, 220, FontObjectFor)
	face:SetPoint("TOPLEFT", mode, "TOPLEFT", 250, 0)
	widgets[#widgets + 1] = face

	-- Schriftgroesse: Offset zum Standard; 0 liegt in der Mitte des Reglers
	local size = MakeSlider(panel, "FontDelta", "Schriftgroesse", -10, 10, 1,
		function() return db().fontDelta or 0 end,
		function(v) db().fontDelta = v end,
		function(v) return v == 0 and "Standard" or string.format("%+d", v) end)
	size:SetPoint("TOPLEFT", mode, "BOTTOMLEFT", 16, -34)
	widgets[#widgets + 1] = size

	-- Kontur
	local outline = MakeDropdown(panel, "Outline", "Textkontur", OUTLINES,
		function() return db().fontOutline end,
		function(v) db().fontOutline = v end)
	outline:SetPoint("TOPLEFT", size, "BOTTOMLEFT", -16, -32)
	widgets[#widgets + 1] = outline

	-- Schatten
	local shadow = MakeCheck(panel, "Shadow", "Textschatten (bessere Lesbarkeit ohne Rahmen)",
		function() return db().shadow end,
		function(v) db().shadow = v end)
	shadow:SetPoint("TOPLEFT", outline, "BOTTOMLEFT", 2, -12)
	widgets[#widgets + 1] = shadow

	-- Lese-Hintergrund
	local bg = MakeSlider(panel, "BgAlpha", "Lese-Hintergrund (nur \"Nur Text\")", 0, 1, 0.05,
		function() return db().bgAlpha or 0 end,
		function(v) db().bgAlpha = v end,
		function(v) return v <= 0 and "aus" or string.format("%.0f%%", v * 100) end)
	bg:SetPoint("TOPLEFT", shadow, "BOTTOMLEFT", 4, -28)
	widgets[#widgets + 1] = bg

	-- Zuruecksetzen
	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetSize(160, 22)
	reset:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", -4, -28)
	reset:SetText("Standard wiederherstellen")
	reset:SetScript("OnClick", function()
		for k, v in pairs(ns.DEFAULTS) do db()[k] = v end
		if ns.Apply then ns.Apply() end
		panel.refresh()
	end)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", reset, "BOTTOMLEFT", 4, -14)
	hint:SetText("Chat-Befehle weiterhin verfuegbar: /ccb help")

	panel.refresh()
	RegisterPanel()
end

-- Vorschautext exakt so stylen, wie es das Kernmodul mit einer echten Bubble tut.
function RefreshPreview()
	if not previewText then return end

	previewText:SetTextColor(1, 1, 1, 1)

	local _, base = STANDARD_TEXT_FONT, 13
	if ns.BubbleFontBase then _, base = ns.BubbleFontBase() end
	base = base or 13

	-- gewaehlte Schriftart (LibSharedMedia-Name oder Pfad) aufloesen
	local path = ns.ResolveFontPath and ns.ResolveFontPath() or STANDARD_TEXT_FONT

	-- Im Modus "Blizzard-Standard" ruehrt das Addon die Bubbles nicht an -
	-- also zeigt die Vorschau die unveraenderte Standardschrift ohne Kontur/Schatten.
	if db().mode == "default" then
		if ns.BubbleFontBase then path = (ns.BubbleFontBase()) end
		if previewText:SetFont(path, base, "") == false then previewText:SetFontObject(GameFontNormal) end
		previewText:SetShadowOffset(0, 0)
		if previewReadBG then previewReadBG:Hide() end
		return
	end

	local size = base + (db().fontDelta or 0)
	if size < 6 then size = 6 end
	local flags = (db().fontOutline and db().fontOutline ~= "NONE") and db().fontOutline or ""
	if previewText:SetFont(path, size, flags) == false then
		if previewText:SetFont((ns.BubbleFontBase and ns.BubbleFontBase() or STANDARD_TEXT_FONT), size, flags) == false then
			previewText:SetFontObject(GameFontNormal)
		end
	end

	if db().shadow then
		previewText:SetShadowColor(0, 0, 0, 1)
		previewText:SetShadowOffset(1, -1)
	else
		previewText:SetShadowOffset(0, 0)
	end

	if previewReadBG then
		if (db().bgAlpha or 0) > 0 and db().mode == "textonly" then
			previewReadBG:SetAlpha(db().bgAlpha)
			previewReadBG:Show()
		else
			previewReadBG:Hide()
		end
	end
end

-- Werte werden sofort gespeichert; diese Hooks bedienen nur die beiden APIs.
panel.okay = function() end
panel.cancel = function() end
panel.default = function()
	for k, v in pairs(ns.DEFAULTS) do db()[k] = v end
	if ns.Apply then ns.Apply() end
	panel.refresh()
end
panel.OnRefresh = panel.refresh   -- moderne Settings-API
panel.OnDefault = panel.default
panel.OnCommit  = panel.okay

----------------------------------------------------------------------
-- Registrierung / OEffnen (neue Settings-API mit Fallback)
----------------------------------------------------------------------

function RegisterPanel()
	if category then return end
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		-- moderne Settings-API (aktueller Anniversary-Client)
		category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		if not (C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel) then
			category.ID = panel.name -- damit der Name an OpenToCategory uebergeben werden kann
		end
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		-- aeltere API als Fallback
		InterfaceOptions_AddCategory(panel)
		category = panel
	end
end

function ns.OpenOptions()
	if not built then ns.BuildOptions() end
	panel.refresh()

	if category and Settings and Settings.OpenToCategory then
		local id = category.ID or (category.GetID and category:GetID()) or panel.name
		Settings.OpenToCategory(id)
	elseif InterfaceOptionsFrame_OpenToCategory then
		-- Classic-Eigenart: zweimal aufrufen, damit die richtige Seite oeffnet
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	else
		print("|cff88ff88Clean Chat Bubbles:|r Optionsfenster nicht verfuegbar - nutze /ccb help")
	end
end
