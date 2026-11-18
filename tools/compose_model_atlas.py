#!/usr/bin/env python3
"""Compose model_atlas.gd's native game renders into a numbered review sheet.

Usage: python3 tools/compose_model_atlas.py /absolute/render-directory
Requires Pillow. Never writes into the game's imported asset folders.
"""

from collections import OrderedDict
from pathlib import Path
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont


def compose(directory: Path) -> None:
    manifest = json.loads((directory / "manifest.json").read_text())
    entries = manifest["entries"]
    pixels = manifest["pixels"]
    columns, gap, caption, section_height = 8, 12, 82, 84
    card_width, card_height = 2 * pixels, pixels + caption
    width = columns * (card_width + gap) + gap
    groups: dict[str, list] = OrderedDict()
    for entry in entries:
        groups.setdefault(entry["group"], []).append(entry)
        for view in range(2):
            frame = directory / f"frames/{entry['number']:03}_{view}.png"
            if not frame.is_file():
                raise FileNotFoundError(frame)
            with Image.open(frame) as im:
                if im.size != (pixels, pixels):
                    raise ValueError(f"Unexpected render dimensions: {frame}: {im.size}")

    regular_path = "/System/Library/Fonts/Supplemental/Arial.ttf"
    bold_path = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
    font = ImageFont.truetype(regular_path, 23)
    bold = ImageFont.truetype(bold_path, 29)
    heading = ImageFont.truetype(bold_path, 43)
    title = ImageFont.truetype(bold_path, 72)
    top = 256
    height = top + sum(
        section_height + math.ceil(len(group) / columns) * (card_height + gap)
        for group in groups.values()
    ) + 72
    sheet = Image.new("RGB", (width, height), "#101b2b")
    draw = ImageDraw.Draw(sheet)
    draw.text((32, 22), "PULKA / MODELLGRANSKNING", font=title, fill="#ffffff")
    draw.text((36, 118), f"{len(entries)} numrerade rutor · {len(entries) * 2} vyer · faktiska spelmodeller · 18 november 2026", font=heading, fill="#a9cbe6")
    draw.text((36, 183), "Varje modell har egen skala. Vyer: två motsatta snedvinklar. Banutsnitt visar exempel från seed 4711. Återkoppla gärna med rutans nummer.", font=bold, fill="#b6c7d7")
    draw.text((36, 226), "Byggnadernas grunddelar är synliga här; i spelet ligger de normalt under snön.", font=font, fill="#b6c7d7")
    index = ["# Pulkas modellöversikt", "", f"{len(entries)} rutor och {len(entries) * 2} vyer. Två motstående vyer per ruta, individuellt anpassad skala.", "", "Regioner och takhus är faktiska genererade exempel från seed 4711; andra seeders oändliga terrängvarianter är inte separata modeller.", ""]
    y = top
    for group_name, group in groups.items():
        start_y = y
        draw.rectangle((gap, y, width - gap, y + section_height - gap), fill="#233a51")
        draw.text((32, y + 14), f"{group_name.upper()}  /  {group[0]['number']:03}–{group[-1]['number']:03}", font=heading, fill="#eef5fb")
        index.extend([f"## {group_name}", "", "| Nr | Modell / pose | Modellnyckel |", "|---|---|---|"])
        y += section_height
        for pos, entry in enumerate(group):
            x = gap + pos % columns * (card_width + gap)
            row_y = y + pos // columns * (card_height + gap)
            for view in range(2):
                with Image.open(directory / f"frames/{entry['number']:03}_{view}.png") as frame:
                    sheet.paste(frame.convert("RGB"), (x + view * pixels, row_y))
            draw.rectangle((x, row_y + pixels, x + card_width - 1, row_y + card_height - 1), fill="#f1f5fa")
            draw.rectangle((x, row_y + pixels, x + 92, row_y + card_height - 1), fill="#285b85")
            draw.text((x + 16, row_y + pixels + 24), f"{entry['number']:03}", font=bold, fill="white")
            draw.text((x + 110, row_y + pixels + 9), entry["label"], font=bold, fill="#192e42")
            draw.text((x + 110, row_y + pixels + 47), entry["key"], font=font, fill="#52677b")
            index.append(f"| {entry['number']:03} | {entry['label']} | `{entry['key']}` |")
        y += math.ceil(len(group) / columns) * (card_height + gap)
        # Section copies are useful when the full sheet is too large for a viewer.
        section = sheet.crop((0, start_y, width, y))
        section.save(directory / f"section-{group[0]['number']:03}-{group[-1]['number']:03}.jpg", quality=95, subsampling=0)
        if group_name == "Djur":
            sample = section.resize((2048, round(section.height * 2048 / width)), Image.Resampling.LANCZOS)
            sample.save(directory / "preview-animals.jpg", quality=94)
        index.append("")
    draw.text((32, height - 51), "Pulka · modellatlas · två vyer per ruta · skapas med tools/model_atlas.gd + tools/compose_model_atlas.py", font=bold, fill="#a9cbe6")
    sheet.save(directory / "Pulka-alla-modeller.png", compress_level=6)
    preview_width = 1600
    sheet.resize((preview_width, round(height * preview_width / width)), Image.Resampling.LANCZOS).save(directory / "Pulka-modelloversikt.jpg", quality=90)
    (directory / "modellindex.md").write_text("\n".join(index) + "\n")
    print(json.dumps({"entries": len(entries), "views": len(entries) * 2, "dimensions": [width, height], "bytes": (directory / "Pulka-alla-modeller.png").stat().st_size, "groups": {key: len(value) for key, value in groups.items()}}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    compose(Path(sys.argv[1]).resolve())
