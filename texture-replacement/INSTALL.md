# Textur-Ersatz (wirkt auch in Raids/Dungeons)

Das Lua-Skinning des Addons (`textonly` / `notail`) blendet die Sprechblasen-
Grafik nur **ausserhalb** von Instanzen aus – in Raids/Dungeons/BGs sind die
Bubble-Frames fuer Addons gesperrt (das gilt fuer ElvUI, Prat & Co. genauso).

Der einzige Weg, die Grafik **ueberall** loszuwerden, ist die eigentliche
Texturdatei durch eine leere zu ersetzen. Das passiert auf Datei-Ebene, nicht
per Lua, und funktioniert daher auch in geschuetzten Bereichen.

## Installation

1. Ordner `Tooltips` aus diesem Verzeichnis kopieren nach:

   ```
   World of Warcraft\_anniversary_\Interface\
   ```

   Ergebnis:

   ```
   World of Warcraft\_anniversary_\Interface\Tooltips\ChatBubble.tga
   World of Warcraft\_anniversary_\Interface\Tooltips\ChatBubbleVertical.tga
   ```

   (Der Ordner `Interface` existiert bereits – nur `Tooltips` hineinlegen.
   Windows-Dateiendungen einblenden, damit nicht `ChatBubble.tga.tga` entsteht.)

2. WoW komplett neu starten.

Die beiden `.tga` sind 64×64 und vollstaendig transparent – die Sprechblase
wird damit unsichtbar, nur der Text bleibt. Kombiniert mit dem Addon:
Schriftart/-groesse/Kontur/Schatten kommen weiterhin ueber `/ccb` (wirkt via
`ChatBubbleFont` auch im Raid).

## Rueckgaengig

`Tooltips\ChatBubble.tga` und `ChatBubbleVertical.tga` wieder loeschen,
WoW neu starten.

## Alternative

[ChatBubbleReplacements](https://github.com/Luckyone961/ChatBubbleReplacements)
bietet dasselbe in mehreren Groessen samt Style „Invisible". Falls die
Bubble mit den Dateien hier nicht komplett verschwindet (andere Basis-Textur-
Groesse), von dort den „Invisible"-Satz nehmen.
