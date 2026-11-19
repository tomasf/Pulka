"""Rebuild the boot splash using the menu's existing PULKA! typeface."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent


def main():
    # A full canvas keeps the logo's proportions consistent on desktop,
    # the web loading screen and Apple launch storyboards.
    image = Image.new("RGB", (3200, 1800), "#101329")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(ROOT / "fonts/FugazOne-Regular.ttf"), 300)
    text = "PULKA!"
    left, top, right, bottom = draw.textbbox((0, 0), text, font=font)
    position = (
        (image.width - (right - left)) / 2 - left,
        (image.height - (bottom - top)) / 2 - top,
    )
    draw.text(position, text, font=font, fill="#f6f8ff")
    destination = ROOT / "boot_splash.png"
    image.save(destination, optimize=True)
    print(destination)


if __name__ == "__main__":
    main()
