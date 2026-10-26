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
