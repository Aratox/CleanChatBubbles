# Textur-Ersatz (wirkt auch in Raids/Dungeons)

Das Lua-Skinning des Addons (`textonly` / `notail`) blendet die Sprechblasen-
Grafik nur **ausserhalb** von Instanzen aus – in Raids/Dungeons/BGs sind die
Bubble-Frames fuer Addons gesperrt (das gilt fuer ElvUI, Prat & Co. genauso).

Der einzige Weg, die Grafik **ueberall** loszuwerden, ist die eigentliche
Texturdatei durch eine leere zu ersetzen. Das passiert auf Datei-Ebene, nicht
per Lua, und funktioniert daher auch in geschuetzten Bereichen.

## Installation

1. Dateien aus `Tooltips\` in diesem Verzeichnis kopieren nach:

   ```
   World of Warcraft\_anniversary_\Interface\Tooltips\ChatBubble.tga
   World of Warcraft\_anniversary_\Interface\Tooltips\ChatBubbleVertical.tga
   ```

   (Ordner `Tooltips` ggf. anlegen. Windows-Dateiendungen einblenden, damit
   nicht `ChatBubble.tga.tga` entsteht.)

2. Liegt dort schon ein Ersatz (`ChatBubble.BLP` / `ChatBubbleVertical.BLP`),
   diese vorher aus dem Weg raeumen – z. B. umbenennen in `*.BLP.bak`.
   Sonst gewinnt evtl. die alte Datei.

3. WoW komplett neu starten.

Die beiden `.tga` sind 128×256 bzw. 128×32 (wie die Originale) und vollstaendig
transparent – die Sprechblase wird damit unsichtbar, nur der Text bleibt.
Schriftart/-groesse/Kontur/Schatten kommen weiterhin ueber `/ccb` (wirkt via
`ChatBubbleFont` auch im Raid).

## Rueckgaengig

`Tooltips\ChatBubble.tga` + `ChatBubbleVertical.tga` loeschen, ein evtl.
`*.BLP.bak` wieder zurueck-benennen, WoW neu starten.

## Alternative

[ChatBubbleReplacements](https://github.com/Luckyone961/ChatBubbleReplacements)
bietet dasselbe in mehreren Groessen samt Style „Invisible". Falls die
Bubble mit den Dateien hier nicht komplett verschwindet (andere Basis-Textur-
Groesse), von dort den „Invisible"-Satz nehmen.
