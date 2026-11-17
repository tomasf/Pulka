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

Taklandskapet har tre rader snötäckta hus: breda, flacka tak i mitten och
brantare taknockar på sidorna. Gränderna ligger under de riktiga mellanrummen
mellan husen. Vissa gränder är 14–16 meter breda och kräver ett aktivt hopp;
de mindre mellanrummen och förskjutna takraderna ger lättare alternativ.
Snökanter hjälper över små gap, skorstenar går att krascha i
och pepparkakor visar möjliga landningar. Efter ett fall återkommer man på
ett helt tak. Provkör med `godot --path . -- --start-region=roofs`.
Kör `godot --headless --path . --script res://tools/roofs_test.gd` för tester,
eller ta bilder med den vanliga renderaren och `-- --capture`.

Isgrottan har ett slingrande, halt isgolv, blå glacierbelysning, istappar
och fasta ispelare. Väggar och valv har kollision och snöfallet stannar
utanför portalerna. Provkör med `godot --path . -- --start-region=cave`.

Containerhamnen har staplad frakt, öppna containertunnlar, kaj och vatten.
En ramp leder upp över containertak med ett riktigt mellanrum, och en smal
landgång ger en alternativ väg över vattnet. Kranens last rör sig över banan
och delas av båda spelarna. Provkör med
`godot --path . -- --start-region=harbor`.

Testa båda med
`godot --headless --path . --script res://tools/cave_harbor_test.gd -- --autopilot`.
Utelämna `--headless` och lägg till `--capture` efter `--` för spelbilder i `/tmp`.
Streaming kan profileras separat med
`godot --headless --path . --script res://tools/region_stream_profile.gd -- cave`
(eller `harbor`).

Kråkor, skator och domherrar ger liv åt backen. De går och pickar i snön
eller sitter på riktiga grenar, stenar och stubbar. När någon av spelarna
kommer nära lyfter de och flyger bort med animerade vingslag. Fåglarna är
dekoration och orsakar inga krascher. Beteende och placering testas med
`godot --headless --path . --script res://tools/birds_test.gd -- --autopilot`.
Kör utan `--headless` och lägg till `--capture` efter `--` för granskningsbilder.

## Apple TV

Godot saknar officiellt tvOS-stöd, så Apple TV-versionen byggs med en egen
Godot 4.7.2 med tvOS-plattformen från godotengine/godot#123885. Bygg den en gång
med `tools/tvos/build_godot.sh` (hamnar i `../godot-tvos`) och exportera sedan
med `tools/tvos/export.sh`, som skapar ett Xcode-projekt i `export/tvos`.
