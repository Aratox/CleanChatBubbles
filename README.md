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

## Bekannte Einschraenkung: Instanzen

In **Raids, Dungeons und Battlegrounds** werden die Chat-Bubbles fuer
Gruppen- und Raidchat von Blizzard als *forbidden* markiert. Kein Addon
(auch nicht ElvUI, Prat oder Plater) darf diese Frames anfassen -
`C_ChatBubbles.GetAllChatBubbles()` gibt sie nicht heraus, und jeder
Zugriffsversuch wuerde einen Fehler werfen. Dort bleiben die Bubbles daher
im Blizzard-Standard.

`/say`- und `/yell`-Bubbles funktionieren ueberall. Gruppen-/Raidchat-Bubbles
werden **ausserhalb** von Instanzen (offene Welt) mitbearbeitet, sofern in den
WoW-Einstellungen aktiviert (`/console chatBubblesParty 1`).

## Wie es funktioniert

Abgeleitet aus den Loesungen von **ElvUI** (`Misc/ChatBubbles.lua`) und **Prat**
(`modules/Bubbles.lua`):

1. Es gibt kein Event „Chat-Bubble erschienen". Deshalb wird per gedrosseltem
   `OnUpdate` (10×/Sek.) ueber `C_ChatBubbles.GetAllChatBubbles()` iteriert.
2. Im Classic-Client ist das zurueckgegebene Objekt ein Container-Frame; die
   eigentliche Bubble ist dessen erstes Child (`container:GetChildren()`).
3. Dieses Child zeichnet die gesamte Bubble-Grafik (Ecken, Kanten, Center, Tail)
   auf dem Draw-Layer **`BORDER`**. Ein einziges `bubble:DisableDrawLayer("BORDER")`
   entfernt die komplette Sprechblase; der Text-FontString (`bubble.String`) liegt
   auf einem anderen Layer und bleibt sichtbar.
4. „Nur Zeiger weg" setzt stattdessen `bubble.Tail:SetAlpha(0)`.

Alle Aenderungen sind reversibel (`EnableDrawLayer` / `SetAlpha(1)`), es werden
keine Texturen dauerhaft ueberschrieben.

## Hinweis zur Client-Version

Die `## Interface:`-Zeile in `CleanChatBubbles.toc` steht auf `11509`
(Vanilla Anniversary 1.15.9). Falls WoW das Addon als „veraltet" markiert, den
Wert an die aktuelle Client-Version anpassen (siehe eine andere `.toc` im
AddOns-Ordner, z. B. von ElvUI).
