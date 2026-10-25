# Pulka!

Ett fartfyllt, lättsamt pulkaspel i en oändlig, procedurellt genererad backe. Byggt i Godot 4.7.

## Köra

```
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Eller öppna projektet i Godot-editorn och tryck F5.

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
