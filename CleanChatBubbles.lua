--[[--------------------------------------------------------------------------
	Clean Chat Bubbles
	------------------

	Blendet die Sprechblasen-Grafik (Rahmen, Hintergrund, "Schwanz"/Zeiger) der
	Ingame-Chat-Bubbles aus, sodass nur noch der Text schwebt - oder entfernt
	wahlweise nur den Zeiger. Zusaetzlich laesst sich Schriftgroesse, Kontur und
	ein Lese-Hintergrund einstellen.

	Funktionsweise (abgeleitet aus ElvUI "ChatBubbles" und Prat "Bubbles"):

	  * Es gibt KEIN Event fuer "eine Chat-Bubble ist aufgetaucht". Deshalb wird
	    per gedrosseltem OnUpdate (10x/Sek) ueber C_ChatBubbles.GetAllChatBubbles()
	    iteriert.
	  * Im Classic/Anniversary-Client ist das zurueckgegebene Objekt ein
	    Container-Frame. Die eigentliche Bubble ist dessen erstes Child
	    (container:GetChildren()).
	  * Der Grossteil der Bubble-Grafik (Ecken, Kanten, Center) liegt auf dem
	    Draw-Layer "BORDER" -> bubble:DisableDrawLayer("BORDER"). Der Zeiger
	    ("Tail") und je nach Client einzelne Reste liegen woanders, daher wird
	    im Modus "textonly" zusaetzlich jede Textur der Bubble auf Alpha 0
	    gesetzt. Der Text (FontString "bubble.String") bleibt stehen.
	  * "Nur Zeiger weg" nutzt bubble.Tail:SetAlpha(0) und laesst den Rest.
	  * Alles reversibel (EnableDrawLayer / SetAlpha(1)).

	Alles ist reversibel (EnableDrawLayer / SetAlpha(1)), es werden keine
	Texturen dauerhaft zerstoert.
----------------------------------------------------------------------------]]

local _, ns = ...

local DB -- wird in PLAYER_LOGIN gesetzt (SavedVariable CleanChatBubblesDB)

local DEFAULTS = {
	mode        = "textonly",  -- "default" | "notail" | "textonly"
	font        = "",          -- "" = Blizzard-Bubble-Schrift; sonst LibSharedMedia-Name oder direkter Pfad
	fontDelta   = 0,           -- Punkte relativ zur Blizzard-Groesse: 0 = Standard, negativ = kleiner
	fontOutline = "OUTLINE",   -- "NONE" | "OUTLINE" | "THICKOUTLINE"
	shadow      = true,        -- Textschatten (Lesbarkeit ohne Rahmen)
	bgAlpha     = 0,           -- 0..1: dezenter dunkler Hintergrund hinter dem Text (nur "textonly")
}

ns.DEFAULTS = DEFAULTS

local THROTTLE = 0.1
local MIN_FONT_SIZE = 6
local BUBBLE_FONT = _G.ChatBubbleFont -- Blizzard-Standard-Fontobjekt zum Zuruecksetzen

-- Basis-Schrift der Chat-Bubbles (Pfad + Groesse). Dient als fixer Nullpunkt,
-- damit fontDelta nicht bei jedem Durchlauf auf sich selbst aufaddiert.
local function BubbleFontBase()
	local f = _G.ChatBubbleFont
	if f and f.GetFont then
		local path, size = f:GetFont()
		if path and size then return path, size end
	end
	return STANDARD_TEXT_FONT, 13
end
ns.BubbleFontBase = BubbleFontBase

-- LibSharedMedia (falls von irgendeinem anderen Addon geladen)
local function GetLSM()
	return _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
end
ns.GetLSM = GetLSM

-- Ein gespeicherter font-Wert ("" | LibSharedMedia-Name | Pfad) -> Schriftdatei-Pfad
-- oder nil, wenn nicht aufloesbar.
local function FontValueToPath(want)
	if not want or want == "" then return nil end
	local LSM = GetLSM()
	if LSM and LSM:IsValid("font", want) then
		return LSM:Fetch("font", want)
	end
	local lower = want:lower()
	if want:find("[\\/]") or lower:find("%.ttf$") or lower:find("%.otf$") then
		return want
	end
	return nil
end
ns.FontValueToPath = FontValueToPath

-- DB.font -> tatsaechlicher Schriftdatei-Pfad. Faellt immer auf die Bubble-Schrift zurueck.
local function ResolveFontPath()
	return FontValueToPath(DB and DB.font) or (BubbleFontBase())
end
ns.ResolveFontPath = ResolveFontPath

----------------------------------------------------------------------
-- Hilfsfunktionen
----------------------------------------------------------------------

-- Liefert den FontString einer Bubble. Classic legt ihn als .String an;
-- als Absicherung wird sonst ueber die Regionen gesucht.
local function GetBubbleText(bubble)
	if bubble.String and bubble.String.GetObjectType and bubble.String:GetObjectType() == "FontString" then
		return bubble.String
	end
	for i = 1, bubble:GetNumRegions() do
		local region = select(i, bubble:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			return region
		end
	end
end

-- Schrift auf den FontString anwenden (nur bei geaenderten Werten sinnvoll aufrufen)
local function StyleText(fs)
	local _, baseSize = BubbleFontBase()
	local path = ResolveFontPath()

	local newSize = baseSize + (DB.fontDelta or 0)
	if newSize < MIN_FONT_SIZE then newSize = MIN_FONT_SIZE end
	local newFlags = (DB.fontOutline and DB.fontOutline ~= "NONE") and DB.fontOutline or ""
	if fs:SetFont(path, newSize, newFlags) == false then
		-- ungueltiger Pfad -> auf Bubble-Standardschrift zurueck
		fs:SetFont((BubbleFontBase()), newSize, newFlags)
	end

	if DB.shadow then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowOffset(0, 0)
	end

	-- Nach einer Groessenaenderung die Breite an den tatsaechlich gerenderten
	-- Text anpassen, damit nichts abgeschnitten wird / umbricht.
	local wrapped = fs:GetWrappedWidth()
	if wrapped and wrapped > 0 then
		fs:SetWidth(wrapped + 2)
	end
end

-- Optionaler Lese-Hintergrund hinter dem Text (nur "textonly", bgAlpha > 0)
local function UpdateBackground(bubble, fs)
	if DB.mode == "textonly" and DB.bgAlpha and DB.bgAlpha > 0 then
		if not bubble.__ccbBG then
			local t = bubble:CreateTexture(nil, "BACKGROUND")
			t:SetColorTexture(0, 0, 0, 1)
			t:SetPoint("TOPLEFT", fs, "TOPLEFT", -6, 4)
			t:SetPoint("BOTTOMRIGHT", fs, "BOTTOMRIGHT", 6, -4)
			bubble.__ccbBG = t
		end
		bubble.__ccbBG:SetAlpha(DB.bgAlpha)
		bubble.__ccbBG:Show()
	elseif bubble.__ccbBG then
		bubble.__ccbBG:Hide()
	end
end

----------------------------------------------------------------------
-- Anwenden / Zuruecksetzen einer einzelnen Bubble
----------------------------------------------------------------------

local function ProcessBubble(bubble)
	local fs = GetBubbleText(bubble)
	if not fs then return end

	if DB.mode == "textonly" then
		if not bubble.__ccbStripped then
			-- Der Grossteil der Bubble-Grafik liegt auf "BORDER"...
			bubble:DisableDrawLayer("BORDER")
			-- ...der Zeiger ("Tail") und je nach Client einzelne Reste aber
			-- nicht. Deshalb zusaetzlich JEDE Textur der Bubble unsichtbar
			-- machen (Alpha 0, damit reversibel) - FontStrings bleiben.
			for i = 1, bubble:GetNumRegions() do
				local region = select(i, bubble:GetRegions())
				if region and region.GetObjectType and region:GetObjectType() == "Texture" then
					region:SetAlpha(0)
				end
			end
			if bubble.Tail and bubble.Tail.SetAlpha then bubble.Tail:SetAlpha(0) end
			bubble.__ccbStripped = true
		end
	elseif DB.mode == "notail" then
		-- Bubble bleibt, nur der Zeiger verschwindet. Jeden Tick neu setzen,
		-- da Blizzard das Frame recycelt und den Alpha zuruecksetzen kann.
		if bubble.Tail then bubble.Tail:SetAlpha(0) end
		if bubble.__ccbStripped then
			bubble:EnableDrawLayer("BORDER")
			bubble.__ccbStripped = nil
		end
	end

	-- Schrift nur neu anwenden, wenn sich der Text geaendert hat (spart Arbeit).
	local text = fs:GetText()
	if text and text ~= bubble.__ccbText then
		StyleText(fs)
		bubble.__ccbText = text
	end

	UpdateBackground(bubble, fs)
	bubble.__ccbTouched = true
end

local function RestoreBubble(bubble)
	if bubble.__ccbStripped then
		bubble:EnableDrawLayer("BORDER")
		for i = 1, bubble:GetNumRegions() do
			local region = select(i, bubble:GetRegions())
			if region and region.GetObjectType and region:GetObjectType() == "Texture" then
				region:SetAlpha(1)
			end
		end
		bubble.__ccbStripped = nil
	end
	if bubble.Tail then bubble.Tail:SetAlpha(1) end
	if bubble.__ccbBG then bubble.__ccbBG:Hide() end

	local fs = GetBubbleText(bubble)
	if fs then
		if BUBBLE_FONT then
			fs:SetFontObject(BUBBLE_FONT)
		end
		fs:SetShadowOffset(0, 0)
		fs:SetWidth(0) -- 0 = automatische Breite wie von Blizzard vorgesehen
	end
	bubble.__ccbText = nil
	bubble.__ccbTouched = nil
end

----------------------------------------------------------------------
-- Iteration ueber alle aktuell sichtbaren Bubbles
----------------------------------------------------------------------

-- Hinweis: In Instanzen (Raid/Dungeon/BG) sind die Chat-Bubbles fuer
-- Gruppen-/Raidchat "forbidden" - Blizzard laesst dort keinerlei Zugriff
-- durch Addons zu. GetAllChatBubbles(false) liefert sie gar nicht erst,
-- und selbst mit true wuerde jeder Methodenaufruf einen Fehler werfen.
-- Betrifft alle Chat-Bubble-Addons gleichermassen (ElvUI, Prat, ...).
local function ForEachBubble(callback)
	local bubbles = C_ChatBubbles.GetAllChatBubbles(false)
	if not bubbles then return end
	for _, container in pairs(bubbles) do
		if container and not container:IsForbidden() then
			local bubble = container:GetChildren()
			if not bubble then bubble = container end
			if bubble and not bubble:IsForbidden() then
				-- geschuetzt: falls ein Frame zwischen Pruefung und Zugriff
				-- doch "forbidden" wird, keinen Lua-Fehler im Raid ausloesen
				pcall(callback, bubble)
			end
		end
	end
end

-- Einmaliger Full-Sweep nach Optionsaenderung: erst alles zuruecksetzen,
-- der laufende OnUpdate wendet danach den neuen Modus wieder an.
local function ApplyNow()
	ForEachBubble(RestoreBubble)
end

----------------------------------------------------------------------
-- Poll-Frame
----------------------------------------------------------------------

local poller = CreateFrame("Frame")
poller:Hide()
poller.elapsed = 0
poller:SetScript("OnUpdate", function(self, e)
	self.elapsed = self.elapsed + e
	if self.elapsed < THROTTLE then return end
	self.elapsed = 0

	if DB.mode == "default" then
		-- Nur noch aufraeumen, was wir frueher angefasst haben, dann anhalten.
		ForEachBubble(function(bubble)
			if bubble.__ccbTouched then RestoreBubble(bubble) end
		end)
		self:Hide()
		return
	end

	ForEachBubble(ProcessBubble)
end)

local function UpdateEnabled()
	-- Auch im "default"-Modus einmal laufen lassen, damit bereits sichtbare
	-- Bubbles zurueckgesetzt werden; der OnUpdate haelt sich dann selbst an.
	poller.elapsed = THROTTLE
	poller:Show()
end

-- Von der Optionsoberflaeche (Options.lua) aufgerufen, wenn sich ein Wert aendert.
function ns.Apply()
	ApplyNow()
	UpdateEnabled()
end

----------------------------------------------------------------------
-- Slash-Kommandos
----------------------------------------------------------------------

local function pr(msg)
	print("|cff88ff88Clean Chat Bubbles:|r " .. msg)
end

local function FontDeltaLabel()
	local d = DB.fontDelta or 0
	if d == 0 then return "Standard" end
	return ("%+d"):format(d)
end

local function PrintStatus()
	pr(("Modus: |cffffd100%s|r  |  Schriftart: |cffffd100%s|r  |  Groesse: |cffffd100%s|r  |  Kontur: |cffffd100%s|r  |  Schatten: |cffffd100%s|r  |  BG-Alpha: |cffffd100%.2f|r")
		:format(DB.mode,
			(DB.font ~= nil and DB.font ~= "") and DB.font or "Standard",
			FontDeltaLabel(),
			DB.fontOutline,
			DB.shadow and "an" or "aus",
			DB.bgAlpha or 0))
end

local function ListFonts()
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM then
		pr("Verfuegbare Schriftarten (LibSharedMedia):")
		for _, name in ipairs(LSM:List("font")) do
			print("  " .. name)
		end
	else
		pr("LibSharedMedia nicht geladen. Nutzbare Werte:")
		print("  default  (Blizzard-Bubble-Schrift)")
		print("  Fonts\\FRIZQT__.TTF   Fonts\\ARIALN.TTF   Fonts\\MORPHEUS.TTF   Fonts\\SKURRI.TTF")
		print("  ...oder ein direkter Pfad zu einer .ttf/.otf-Datei")
	end
end

local function Help()
	pr("Optionsmenue: |cffffd100/ccb|r (ohne Argument) oder ESC > Interface > AddOns > Clean Chat Bubbles")
	pr("Befehle:")
	print("  /ccb textonly   - nur Text, keine Sprechblasen-Grafik")
	print("  /ccb notail     - Sprechblase behalten, nur den Zeiger ausblenden")
	print("  /ccb default    - alles auf Blizzard-Standard zuruecksetzen")
	print("  /ccb face <name>|list|default - Schriftart (list zeigt verfuegbare)")
	print("  /ccb font <n>   - Schriftgroesse relativ zum Standard, z.B. /ccb font -2 oder /ccb font 3 (0 = Standard)")
	print("  /ccb outline none|outline|thick")
	print("  /ccb shadow     - Textschatten an/aus")
	print("  /ccb bg <0-1>   - dunkler Lese-Hintergrund hinter dem Text (nur textonly)")
	print("  /ccb status     - aktuelle Einstellungen anzeigen")
end

SLASH_CLEANCHATBUBBLES1 = "/ccb"
SLASH_CLEANCHATBUBBLES2 = "/cleanbubbles"
SlashCmdList.CLEANCHATBUBBLES = function(msg)
	msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, arg = msg:match("^(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()          -- Befehl case-insensitiv
	arg = arg or ""                    -- Argument in Originalschreibweise (Schriftnamen!)
	local larg = arg:lower()

	if cmd == "" or cmd == "options" or cmd == "config" or cmd == "menu" then
		if ns.OpenOptions then
			ns.OpenOptions()
		else
			Help()
		end
		return
	elseif cmd == "help" then
		Help()
		return
	elseif cmd == "textonly" or cmd == "text" then
		DB.mode = "textonly"
	elseif cmd == "notail" or cmd == "tail" then
		DB.mode = "notail"
	elseif cmd == "default" or cmd == "off" or cmd == "disable" then
		DB.mode = "default"
	elseif cmd == "face" or cmd == "typeface" or cmd == "fontface" then
		if larg == "" or larg == "list" then
			ListFonts()
			return
		elseif larg == "default" or larg == "standard" or larg == "reset" then
			DB.font = ""
		else
			local LSM = ns.GetLSM and ns.GetLSM()
			local lower = larg
			if LSM and LSM:IsValid("font", arg) then
				DB.font = arg
			elseif arg:find("[\\/]") or lower:find("%.ttf$") or lower:find("%.otf$") then
				DB.font = arg
			else
				pr("Unbekannte Schriftart |cffffd100" .. arg .. "|r. |cffffd100/ccb face list|r zeigt verfuegbare.")
				return
			end
		end
	elseif cmd == "font" or cmd == "size" then
		local n = tonumber(arg)
		if not n or n < -20 or n > 20 then pr("Bitte eine Zahl von -20 bis 20 angeben (0 = Standard).") return end
		DB.fontDelta = math.floor(n + 0.5)
	elseif cmd == "outline" then
		if larg == "none" or larg == "" then DB.fontOutline = "NONE"
		elseif larg == "outline" then DB.fontOutline = "OUTLINE"
		elseif larg == "thick" or larg == "thickoutline" then DB.fontOutline = "THICKOUTLINE"
		else pr("outline: none | outline | thick") return end
	elseif cmd == "shadow" then
		DB.shadow = not DB.shadow
	elseif cmd == "bg" or cmd == "background" then
		local n = tonumber(arg)
		if not n or n < 0 or n > 1 then pr("Bitte einen Wert 0.0 - 1.0 angeben.") return end
		DB.bgAlpha = n
	elseif cmd == "status" then
		PrintStatus()
		return
	else
		pr("Unbekannter Befehl.")
		Help()
		return
	end

	ApplyNow()
	UpdateEnabled()
	PrintStatus()
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	CleanChatBubblesDB = CleanChatBubblesDB or {}
	DB = CleanChatBubblesDB

	-- Migration: fruehere absolute Schriftgroesse -> Offset zum Standard
	if DB.fontSize ~= nil then
		if DB.fontDelta == nil and DB.fontSize > 0 then
			local _, base = BubbleFontBase()
			DB.fontDelta = DB.fontSize - base
		end
		DB.fontSize = nil
	end

	for k, v in pairs(DEFAULTS) do
		if DB[k] == nil then DB[k] = v end
	end
	ns.db = DB -- fuer Options.lua

	if ns.BuildOptions then ns.BuildOptions() end

	UpdateEnabled()
	pr(("geladen. Modus |cffffd100%s|r - |cffffd100/ccb|r oeffnet das Optionsmenue."):format(DB.mode))
end)
