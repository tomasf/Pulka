# Pulka!

Ett fartfyllt, lättsamt pulkaspel i en oändlig, procedurellt genererad backe. Byggt i Godot 4.7.

## Köra

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Eller öppna projektet i Godot-editorn och tryck F5.

## Webbversion

Bygg med Godot 4.7 och motsvarande exportmallar installerade:

```sh
sh tools/export_web.sh
python3 -m http.server 8060 --bind 127.0.0.1 --directory export/web
```

Öppna sedan <http://localhost:8060>. Klicka i spelet eller tryck på en tangent
för att aktivera ljudet. Tangentbord, handkontroll och pekstyrning fungerar
som i appen. Webbläsaren måste stödja WebAssembly och WebGL 2.
Knappen **Fullskärm** uppe till höger växlar till fullskärm. Tryck på
**Fönsterläge** eller Esc för att gå tillbaka. F växlar också mellan lägena.

Hela `export/web/` kan publiceras på en vanlig statisk webbserver med HTTPS.
Exporten kör utan trådar och behöver inga särskilda COOP/COEP-headers.
Öppna via en webbserver, inte genom att dubbelklicka på `index.html`.
Servera `.wasm` som `application/wasm` och aktivera gärna gzip/Brotli.
Rekord och inställningar sparas lokalt i webbläsaren när lagring tillåts.

Byggskriptet förbereder ljud och musik i `generated/web_audio/` före exporten,
så att spelet inte behöver syntetisera dem i webbläsaren. Webbversionen använder
WebGL-grafik med kortare sikt och färre snöflingor. Sätt miljövariabeln `GODOT`
om Godot ligger på en annan plats.

## Styrning

| | Tangentbord | Handkontroll |
|---|---|---|
| Styr | A/D, pilar | Vänster spak, styrkors |
| Luta fram (fart) | W / upp | RT |
| Broms | S / ner | LT |
| Hopp (luftspinn = styr i luften) | Space | A |
| Paus | Esc / P | Start |
| Inställningar (volym) | Tab / O | Y |
| Helskärm | F / F11 | |

## Testläge

```
Godot --path . -- --autopilot [--reckless] [--vehicle=N] [--start-region=town|river|park|woods] [--event=blizzard|snowballs|santa|aurora] [--mute] --screenshot=bild.png --shot-at=5,10,20
```

`--autopilot` stänger av ljudet och sparar inga rekord.
