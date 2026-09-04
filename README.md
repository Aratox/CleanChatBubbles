# Clean Chat Bubbles

Kleines Addon fuer den WoW Anniversary/Classic Client, das die **Sprechblasen-Grafik**
der Ingame-Chat-Bubbles ausblendet oder bearbeitet. Standardmaessig bleibt nur der
schwebende **Text** uebrig – ohne Rahmen, Hintergrund und Zeiger.

## Optionsmenue

`/ccb` (ohne Argument) oder **ESC → Optionen → AddOns → Clean Chat Bubbles**
oeffnet ein Menue mit allen Einstellungen (Dropdown fuer Modus/Kontur, Schieber
fuer Schriftgroesse und Lese-Hintergrund, Haken fuer Schatten, Button
„Standard wiederherstellen"). Aenderungen wirken sofort und werden pro Account
in `CleanChatBubblesDB` gespeichert. Die Chat-Befehle bleiben als Kurzweg
erhalten.

Ganz oben im Menue zeigt eine **Live-Vorschau** einen Beispieltext, der genauso
gestylt wird wie eine echte Bubble – so sieht man Schriftart, Schriftgroesse,
Kontur, Schatten und Lese-Hintergrund sofort.

### Schriftart

Dropdown **Schriftart**. Ist `LibSharedMedia-3.0` von irgendeinem anderen Addon
geladen (fast immer der Fall), erscheinen dort alle registrierten Schriften;
sonst eine kleine Auswahl der WoW-Standardfonts. Jeder Eintrag wird **in seiner
eigenen Schrift** dargestellt (via `info.fontObject`), ebenso der Text am
geschlossenen Dropdown. Per Befehl: `/ccb face list`, `/ccb face <Name>`,
`/ccb face default`.

### Schriftgroesse

Der Regler ist ein **Offset zum Blizzard-Standard**: `0` (Mitte) = unveraendert,
negative Werte machen die Schrift kleiner, positive groesser. Per Befehl:
`/ccb font -2`, `/ccb font 3`, `/ccb font 0`.

## Modi

| Befehl          | Wirkung                                                          |
|-----------------|----------------------------------------------------------------|
| `/ccb textonly` | Nur Text, komplette Sprechblasen-Grafik weg (Standard)         |
| `/ccb notail`   | Sprechblase bleibt, nur der Zeiger/„Schwanz" wird ausgeblendet |
| `/ccb default`  | Alles zurueck auf Blizzard-Standard                            |
| `/ccb` / `/ccb menu` | Optionsmenue oeffnen                                     |

Im Modus `textonly` wird nach `DisableDrawLayer("BORDER")` zusaetzlich jede
Textur der Bubble auf Alpha 0 gesetzt – sonst bleibt je nach Client ein Rest
des Zeigers als dunkler „Haken" sichtbar.

## Feineinstellung

| Befehl                        | Wirkung                                              |
|-------------------------------|-----------------------------------------------------|
| `/ccb face <name>\|list\|default` | Schriftart (LibSharedMedia oder Pfad; `list` zeigt alle) |
| `/ccb font <n>`               | Schriftgroesse als Offset zum Standard (`0` = Standard, `-3`, `+4` …) |
| `/ccb outline none\|outline\|thick` | Textkontur                                     |
| `/ccb shadow`                 | Textschatten an/aus                                 |
| `/ccb bg <0-1>`               | dezenter dunkler Lese-Hintergrund (nur `textonly`)  |
| `/ccb status`                 | aktuelle Einstellungen anzeigen                     |

Einstellungen werden pro Account in `CleanChatBubblesDB` gespeichert.

## Instanzen (Raid / Dungeon / BG)

| Was | offene Welt | Instanz |
|-----|:-:|:-:|
| Grafik ausblenden **per Lua** (`textonly` / `notail`) | ✅ | ❌ Frames gesperrt |
| Grafik ausblenden **per Textur-Ersatz** (`texture-replacement/`) | ✅ | ✅ |
| Schriftart / Groesse / Kontur / Schatten (`ChatBubbleFont`) | ✅ | ✅ |

Lua-Zugriff auf die Bubble-Frames ist in Instanzen gesperrt – das betrifft
**jedes** Addon (ElvUIs eigenes Wiki sagt das ausdruecklich). Um die Grafik
auch dort loszuwerden, die mitgelieferten transparenten Texturen installieren:
siehe [`texture-replacement/INSTALL.md`](texture-replacement/INSTALL.md).
Die Schrift-Einstellungen (`/ccb`) wirken ueber das globale Fontobjekt
`ChatBubbleFont` und greifen ohnehin ueberall, auch im Raid.

Gruppen-/Raidchat-Bubbles muessen in den WoW-Einstellungen aktiviert sein
(`/console chatBubblesParty 1`). `/ccb debug` zeigt, was
`C_ChatBubbles.GetAllChatBubbles()` gerade liefert.

## Wie es funktioniert

Abgeleitet aus den Loesungen von **ElvUI** (`Misc/ChatBubbles.lua` +
`General/Fonts.lua`) und **Prat** (`modules/Bubbles.lua`):

1. **Schrift** (Art/Groesse/Kontur/Schatten): einmalig auf `_G.ChatBubbleFont`
   angewandt. Weil jede Bubble ihren Text ueber dieses eine Fontobjekt rendert,
   greift die Aenderung sofort und ueberall. Groesse ist ein Offset zum
   gemerkten Blizzard-Ausgangswert (kein Aufaddieren).
2. **Grafik ausblenden**: Es gibt kein Event „Bubble erschienen", daher
   gedrosseltes `OnUpdate` (10×/Sek.) ueber `C_ChatBubbles.GetAllChatBubbles()`.
   Das zurueckgegebene Objekt ist ein Container; die eigentliche Bubble ist
   dessen erstes Child (`container:GetChildren()`).
3. Dieses Child zeichnet die Bubble-Grafik (Ecken, Kanten, Center) auf dem
   Draw-Layer **`BORDER`** -> `bubble:DisableDrawLayer("BORDER")`. Zusaetzlich
   wird jede Textur auf Alpha 0 gesetzt (Zeiger/Reste). Der Text bleibt.
4. „Nur Zeiger weg" setzt nur `bubble.Tail:SetAlpha(0)`.

Alles reversibel: `EnableDrawLayer` / `SetAlpha(1)` und `ChatBubbleFont` zurueck
auf die gemerkten Ausgangswerte.

## Hinweis zur Client-Version

Die `## Interface:`-Zeile in `CleanChatBubbles.toc` steht auf `11509`
(Vanilla Anniversary 1.15.9). Falls WoW das Addon als „veraltet" markiert, den
Wert an die aktuelle Client-Version anpassen (siehe eine andere `.toc` im
AddOns-Ordner, z. B. von ElvUI).
