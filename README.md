Pulka! Ett fartfyllt pulkaspel i en oändlig, procedurellt genererad backe.

[Spela i webbläsaren](https://tomasf.github.io/Pulka/)

För testkörning utan krascher, starta med `godot --path . -- --no-crash`.
Hopp, studsar mot biltak och stockar samt vanliga markfysiken fungerar som vanligt,
men hinder som annars orsakar en krasch passeras utan påverkan. Flaggan förhindrar
även krascher vid banans kanter och i vatten.

Skala åkdonets fart med `--speed-multiplier=2` (dubbel fart) eller
`--speed-multiplier=0.5` (halv fart). Standard är `1`. Multiplikatorn gäller
förflyttningen längs marken; hoppens kraft och tyngdkraften är oförändrade.
Flaggorna kan kombineras: `godot --path . -- --no-crash --speed-multiplier=2`.

Förbered ljudet med `godot --headless --path . --script res://tools/bake_web_audio.gd`
vid en ny källkodsutcheckning eller efter ändringar i musik/ljud. Då slipper
spelet syntetisera musiken i bakgrunden under åkturen. Exportskripten för
macOS, webb och Apple TV gör detta automatiskt. Utan färdigt ljud använder
skrivbordsversionen syntes som reserv.

Menyn börjar med spelarval och sedan åkdon på den riktiga banan. Starten går
vidare med en kamerarörelse och 3–2–1. Menylåten **Snödag** är separat från
åkmusiken. [Menyflöde, musik och tester](tools/MENU_REVIEW.md).

Bland specialregionerna finns en hängbro med 7,6 meter bred träbana över en
ravin. Infarten smalnar av innan bron och räckena går att krascha i. Hoppar
man över räcket kan man falla ner. Provkör nära bron med
`godot --path . -- --start-region=bridge`, eller kör dess fysiktest med
`godot --headless --path . --script res://tools/bridge_test.gd`.

## Apple TV

Godot saknar officiellt tvOS-stöd, så Apple TV-versionen byggs med en egen
Godot 4.7.2 med tvOS-plattformen från godotengine/godot#123885. Bygg den en gång
med `tools/tvos/build_godot.sh` (hamnar i `../godot-tvos`) och exportera sedan
med `tools/tvos/export.sh`, som skapar ett Xcode-projekt i `export/tvos`.
