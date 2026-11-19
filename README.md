Pulka! Ett fartfyllt pulkaspel i en oändlig, procedurellt genererad backe.

[Spela i webbläsaren](https://tomasf.github.io/Pulka/)

Styr med A/D eller vänster/höger och hoppa med Space. På handkontroll använder
du spaken och A. Farten kommer automatiskt från backen.

I luften ger ett nytt tryck på hoppknappen ett grepp så länge du håller den:
Stålmannen på pulkan, Frihetsgudinnan med stjärtlappen, Flaggan på snowracern
Karusellen med tefatet och Flygande Jakob med wokpannan. Det tar en stund
att komma in i tricket och tillbaka i sätet. Har du väl kommit hela vägen in
måste du släppa i god tid före landningen, annars kraschar du. Korta tryck
gör ingenting, och ett trick som inte hunnit bli klart avbryts utan krasch
när du landar. Poäng räknas bara medan tricket är helt utfört, och grepp och
snurr i samma hopp ger extra poäng.
Testa med `godot --headless --path . --script res://tools/grab_test.gd`, och
se poserna med `godot --path . --script res://tools/gallery.gd -- grab /tmp/pulka-grab.png 420`.

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

Åkmusiken är elva låtar, knappt 19 minuter: humppa, polska, schottis, vals,
boogie och storm, plus synthwave, drum'n'bass, chiptune och house. De spelas
en gång var i blandad ordning, och nästa åktur fortsätter där musiken var.
Musiken renderas i 44,1 kHz stereo med bandbegränsade oscillatorer.
Exportskripten bakar låtarna till Ogg Vorbis med `ffmpeg` (utan den blir de WAV).
Lyssna på dem utanför spelet med
`godot --headless --path . --script res://tools/render_music.gd -- /tmp`.

I delad skärm följer ljus, dimma och snö varje spelares egen region. Testa med
`godot --headless --path . --script res://tools/split_atmosphere_test.gd -- --autopilot`.
Kör utan `--headless` och lägg till `--capture` för spelbilder och en jämförelse
som kontrollerar att utomhusbildens ljus inte ändras när den andra går in.

Ett genomskinligt säkerhetsnät tonar fram nära osynliga sidogränser och följer
den faktiska gränsen längs terrängen. Nuddar man nätet i låg fart studsar man
tillbaka in på banan; en hårdare stöt får en att tappa balansen och bara en
riktigt hård träff blir en krasch. Nätet förvarnar även när man är på väg
mot en snävare region och tonar bort när man styr tillbaka. Varje spelare ser
sitt eget nät; synliga väggar och räcken behåller sina vanliga markeringar.
Testa gränser, toning och separata vyer med
`godot --headless --path . --script res://tools/boundary_net_test.gd -- --autopilot`.
Utelämna `--headless` och lägg till `--capture` efter `--` för granskningsbilder
och en kontroll av att nätet inte ändrar den andra spelarens bild.

Bland specialregionerna finns en hängbro med 7,6 meter bred träbana över en
ravin. Varningsskyltar för avsmalnande väg står på båda sidor före infarten.
Infarten smalnar av innan bron och räckena går att krascha i. Hoppar
man över räcket kan man falla ner. Provkör nära bron med
`godot --path . -- --start-region=bridge`, eller kör dess fysiktest med
`godot --headless --path . --script res://tools/bridge_test.gd`.

Taklandskapet har tre rader snötäckta hus: breda, flacka tak i mitten och
brantare taknockar på sidorna. Gränderna ligger under de riktiga mellanrummen
mellan husen. Vissa gränder är 14–16 meter breda och kräver ett aktivt hopp;
de mindre mellanrummen och förskjutna takraderna ger lättare alternativ.
Snökanter hjälper över små gap, skorstenar går att krascha i
och snöflingor visar möjliga landningar. Efter ett fall återkommer man på
ett helt tak. Provkör med `godot --path . -- --start-region=roofs`.
Kör `godot --headless --path . --script res://tools/roofs_test.gd` för tester,
eller ta bilder med den vanliga renderaren och `-- --capture`.

Isgrottan ligger inne i en bred snötäckt bergsrygg, med bruten klippa och
iskanter runt båda mynningarna. Den har ett slingrande, halt isgolv, blå glacierbelysning, istappar
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

Kloaken går in i en brant snötäckt slänt. Det begravda betongröret har mörk, matt
och smutsig insida, välvd botten, smutsvatten, rostiga galler,
skräphögar och springande råttor. Med tillräcklig fart kan man styra hela varvet
runt röret, även i taket, medan kamerans horisont hålls vågrät. För låg fart gör att man
tappar kontakten med taket och faller ned. Man kan välja
öppningar i gallren och hoppa över eller köra runt låga rör. Råttorna flyr
undan båda spelarna. Provkör med `godot --path . -- --start-region=sewer`.
Testa med `godot --headless --path . --script res://tools/sewer_test.gd -- --autopilot`.
Loopen och fartberoende väggkontakten testas med `tools/sewer_loop_test.gd`.
Lägg till `--capture` utan `--headless` för bilder i `/tmp`.

Sjön är en sammanhängande, cirka 200 meter bred vak med oregelbunden strand,
snövall, brutna iskanter, isflak och en brygga vid bastun. Vattenytan har
rörliga krusningar, ljusare vatten vid stranden och skum intill isen. Sjöbottnen ligger
under vattnet; terräng och fysik använder samma strandlinje. Med tillräcklig
fart studsar man över sjön och lämnar stänk och utdragna ringar. Sjön ligger
på en plan avsats med en mjuk utfart; höjden fortsätter nedströms utan att
terrängen faller tillbaka till den gamla backens nivå. Låg fart ger
ett plums. Provkör med `godot --path . -- --start-region=lake` och testa med
`godot --headless --path . --script res://tools/lake_test.gd -- --autopilot --mute`.
Utelämna `--headless` och lägg till `--capture` för en översiktsbild i `/tmp`.

Kråkor, skator och domherrar ger liv åt backen. De går och pickar i snön
eller sitter på riktiga grenar, stenar och stubbar. När någon av spelarna
kommer nära lyfter de och flyger bort med animerade vingslag. Fåglarna är
dekoration och orsakar inga krascher. Beteende och placering testas med
`godot --headless --path . --script res://tools/birds_test.gd -- --autopilot`.
Kör utan `--headless` och lägg till `--capture` efter `--` för granskningsbilder.

Rödrävar travar över backen i skogs- och vildmarksavsnitt. De har vinterpäls,
vit bringa, mörka tassar och en buskig svans med ljus spets. Provkör med
`godot --path . -- --spawn=fox --no-crash`. Kontrollera rörelse, kollisioner
och naturlig placering med `godot --headless --path . --script res://tools/fox_test.gd`.
Modellvyer: `godot --path . --rendering-method mobile --script res://tools/gallery.gd -- fox_review /tmp/pulka-fox.png 700`.

Grå, röda och svartvita katter håller till vid riktiga bostadshus: vid de
utspridda trähusen och längs stadens husfasader. De står och spanar eller går
korta sträckor kring sitt hus. Placeringen lottas separat och påverkar inte
andra hinder. Katter placeras aldrig fritt i djur- eller skogstabellerna.
Provkör med `godot --path . -- --start-region=town --spawn=cat --no-crash`;
`--spawn=cat` ökar antalet vid hus och behåller samma placeringsregler.
Testa med `godot --headless --path . --script res://tools/cat_test.gd`.
Kör utan `--headless` och lägg till `-- --capture` för bilder vid husen.

Trafiken har sju karossformer med olika proportioner: klassisk och modern
kombi, halvkombi, sedan, SUV, skåpbil och pickup. De har formade hjulhus,
fälgar, backspeglar, olika lyktor och grillar, vinterdetaljer och ibland skidor.
Kaross och lack lottas oberoende. Den ungefärliga svenska trafikblandningen
är viktad till 33 % kombi, 24 % halvkombi, 25 % SUV, 12 % sedan, 5 % skåpbil
och 1 % pickup; detta är spelvikter, inte officiell fordonsstatistik.
Vitt, svart och silver är vanligast. Alla 49 kombinationer förbereds i
modellcachen och varje bil använder en enda ogenomskinlig materialyta.
Hjulen roterar kring sina egna axlar efter körsträckan och hjulradien,
även när trafiken bromsar in. Parkerade bilar och pausad trafik står still.
Kontrollera geometri och fördelning med
`godot --headless --path . --script res://tools/car_test.gd` och köbildning med
`godot --headless --path . --script res://tools/traffic_test.gd -- --autopilot`.
En modellöversikt kan renderas med
`godot --path . --script res://tools/car_preview.gd -- /tmp/pulka-cars.png`.

Motorvägens asfalt, körfysik och trafik använder samma tvärplana vägbädd.
Snön formas till en mjuk skärning runt vägen, även där den svänger in och ut
från sidan av backen. Kontrollera höjder mot de faktiska asfalt- och snötrianglarna,
bilarnas hjulkontakt och alla åkdon med
`godot --headless --path . --script res://tools/motorway_test.gd`.
Kör utan `--headless` och lägg till `-- --capture` för granskningsbilder i `/tmp`.

## Apple TV

Godot saknar officiellt tvOS-stöd, så Apple TV-versionen byggs med en egen
Godot 4.7.2 med tvOS-plattformen från godotengine/godot#123885. Bygg den en gång
med `tools/tvos/build_godot.sh` (hamnar i `../godot-tvos`) och exportera sedan
med `tools/tvos/export.sh`, som skapar ett Xcode-projekt i `export/tvos`.

Exporten förbereder också delade modeller, publikens stillbilder och
stänkeffekter i `generated/world_meshes/cache.res`. Modellerna får enklare
detaljnivåer på avstånd och delade vertexar i skuggpasset. Närgeometrins form
och färger behålls. Publikens åtta poser delar geometri mellan klädfärger och
ritas med en materialyta per person. Förberedelsen flyttar arbete från
pågående åkning till bygget.
Kör `godot --headless --path . --script res://tools/bake_world_meshes.gd` igen
efter modelländringar, eller ta bort `generated/world_meshes` under utveckling
för att använda de vanliga byggarna. Saknad cache fungerar som tidigare.

Tyst profilering på en fysisk enhet aktiveras vid appstart med miljövariabeln
`PULKA_DEVICE_PROFILE=1`. Valfri `PULKA_PROFILE_ARGS` innehåller JSON, till
exempel `{"seconds":20,"cases":["sewer","woods/blizzard"],"modes":[1,2]}`.
Standardkörningen omfattar 19 miljö-/väderfall för en och två spelare, inklusive
övergångar mellan inne och ute. Den stänger av ljudet innan ljudspelare skapas.
Resultatet uppdateras efter varje fall i appens cachekatalog som
`pulka_device_profile.json`. Hämta det med `devicectl device copy from`,
`--domain-type appDataContainer`, `--domain-identifier se.tomasf.pulka` och
`--source Library/Caches/pulka_device_profile.json`. Skapa en tabell med
`python3 tools/tvos/profile_report.py resultat.json`. Stoppa appen efter testet;
tvOS avslutar inte processen när Godot anropar `quit()`.

`python3 tools/tvos/run_profile.py --label optimering --output /tmp/pulka-tv.json`
kör hela testet tyst på Apple TV Köket, hämtar färska resultat och stoppar
appens process även vid avbrott. `--config` tar samma JSON som ovan och
`--device` väljer en annan ansluten enhet.

Mätningar och begränsningar finns i [senaste Apple TV-profileringen](docs/profiling/apple-tv-2026-11-18.md)
och [den tidigare mätningen](docs/profiling/apple-tv-2026-11-17.md).
`tools/lod_test.gd` kontrollerar detaljnivåer, skuggor och importerade material.
`tools/crowd_test.gd` kontrollerar publikens geometri, färger och uppskjutna
cachemissar. Kör utan `--headless` och med `-- --capture` för bildjämförelser.
`tools/animation_visibility_test.gd` kontrollerar att synliga djur fortsätter
animera för endera kameran och pausas utanför båda. Apple TV använder en
skuggkaskad per vy i tvåspelarläget, med samma skuggräckvidd som för en spelare.
`tools/sky_budget_test.gd -- --shadows --capture` jämför skuggprecisionen
med TV:ns skuggatlasstorlek i Mobile-renderaren.
En Instruments-export av `time-profile` kan sammanställas med
`python3 tools/tvos/cpu_report.py cpu.xml --json cpu-summary.json`.
