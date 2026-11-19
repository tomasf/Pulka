# Interface languages

The game's source language is Swedish. `en.po` contains the English catalog,
registered in `project.godot` and included by Godot in exports. Settings offers
**Svenska** and **English**. `SaveData.language` remembers the selection; older
saves and unsupported language codes default to `sv`.

Godot translates ordinary labels, buttons, tooltips and rich text automatically.
Their `text` property keeps the source message. Use `tr(message)` **before**
formatting values into a sentence, such as `tr("%s m kvar") % distance`.
Changing the locale refreshes formatted menu records, the score/race readouts
and accessible control hints without rebuilding the world or interrupting a run.

Keep PULKA!, ride names, trick names, people's names, song titles and original
license notices unchanged. The world root disables automatic translation, so
Swedish shop signs, advertising, place names and the MÅL banner keep the setting
in Sweden. Translate interface instructions and commentary around those names.

When adding a message, add its Swedish source and English translation to
`en.po`, preserving formatting placeholders and BBCode tags. A separate Swedish
catalog is unnecessary because its source strings already are Swedish.

```sh
godot --headless --path . --fixed-fps 60 --script res://tools/localization_test.gd -- --mute
godot --path . --fixed-fps 60 --script res://tools/localization_test.gd -- --capture --mute
godot --path . --fixed-fps 60 --script res://tools/localization_test.gd -- --compact --mobile-preview --capture --mute
```

The test switches the actual settings buttons with keyboard navigation, uses
an isolated temporary save, checks language persistence, formatting, preserved
names, live switching while paused and both solo/race output. Native screenshots
are written to `/tmp/pulka-language-*.png`.
