<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Working with images

## Opening

```jennifer
import "@deckyard/magick/" as magick;

def c as magick.Config init magick.config();
def a as magick.Image init magick.open($c, "photo.jpg");              # format from the extension
def b as magick.Image init magick.openAs($c, "upload.tmp", "PNG");    # named format
def u as magick.Image init magick.fromBytes($c, $body, "JPEG");       # bytes, e.g. an HTTP upload
```

Bytes reach ImageMagick™ through a temporary file, removed afterwards, so the
timeout covers them as it covers files; their format is never guessed, so
name it.

## Operations

Each returns a changed copy; they run in order.

| Function | Does |
|---|---|
| `resize(img, w, h)` | fit in `w`x`h`, keeping the aspect ratio; 0 for "any" |
| `shrinkOnly(img, w, h)` | the same, but never enlarge |
| `resizeExact(img, w, h)` | exactly `w`x`h`, distorting if needed |
| `thumbnail(img, w, h)` | fit, and drop metadata and profiles |
| `cover(img, w, h)` | fill `w`x`h` exactly, cutting the overflow around the centre |
| `crop(img, x, y, w, h)` | cut out a rectangle |
| `pad(img, w, h, fill)` | centre on a canvas of that size |
| `rotate(img, degrees)` | rotate clockwise |
| `firstFrame(img)` | read only the first frame of an animation or a multi-page file |
| `autoOrient(img)` | turn upright as the EXIF orientation says |
| `flip(img)`, `flop(img)` | mirror vertically, horizontally |
| `grayscale(img)` | shades of grey |
| `strip(img)` | remove EXIF (GPS included), comments, profiles |
| `quality(img, q)` | 1 to 100, for JPEG, WebP, AVIF ... |
| `blur(img, sigma)`, `sharpen(img, sigma)` | Gaussian blur, sharpening |
| `border(img, px, fill)` | a border |
| `annotate(img, text, gravity, x, y, size, fill)` | text, taken literally |
| `overlay(img, over, gravity, x, y)` | another image on top, e.g. a watermark |

Gravity is one of `NorthWest`, `North`, `NorthEast`, `West`, `Center`,
`East`, `SouthWest`, `South`, `SouthEast`. Colours are names (`white`,
`none`), `#rrggbb`, or `rgb(...)` / `rgba(...)` / `hsl(...)` / `gray(...)`.

```jennifer
def logo as magick.Image init magick.resize(magick.open($c, "logo.png"), 96, 0);
def img as magick.Image init magick.cover(magick.autoOrient(magick.open($c, "photo.jpg")), 1200, 630);
$img = magick.overlay($img, $logo, "SouthEast", 24, 24);
$img = magick.annotate($img, "Summer 2026", "SouthWest", 24, 24, 36, "white");
magick.write($c, magick.quality(magick.strip($img), 82), "card.jpg");
```

## Writing

`write` takes the format from the output extension, `writeAs` names it.
`encode` returns the bytes instead, for an HTTP response or a database;
it passes through a temporary file, removed afterwards.

```jennifer
def webp as bytes init magick.encode($c, magick.thumbnail($img, 320, 320), "WEBP");
```

## Inspecting and comparing

`identify` reads the format, size, colour space, depth, frame count, EXIF
orientation and transparency; `identifyBytes` does the same for bytes.

```jennifer
def info as magick.Info init magick.identify($c, "photo.jpg");
if ($info.width * $info.height > 50000000) {
    io.printf("too large\n");
}
```

`compare` measures how different two images of the same size are, for
visual regression tests: `AE` counts differing pixels, `RMSE` is a
root-mean-square error, `PSNR`, `SSIM`, `DSSIM`, `MAE`, `MSE` and `NCC` are
there too. `normalized` is on a 0 to 1 scale where 0 means identical, except
for `PSNR`, where 1 does. ImageMagick 7.1.2 reports `SSIM` and `NCC` as
distances, like `DSSIM`; older releases may report the similarity.

```jennifer
def d as magick.Comparison init magick.compare($c, "expected.png", "actual.png", "RMSE");
if ($d.normalized > 0.01) {
    io.printf("screenshots differ\n");
}
```

`montage` makes a contact sheet: `montage($c, files, "sheet.jpg", 4, 160,
160)` lays the files out four to a row in 160x160 tiles.

## Anything else

`run($c, args)` runs `magick` with arguments of your own after the limits,
and returns what it printed. It is the escape hatch for the hundreds of
options the deck does not wrap; it checks nothing, so never feed it user
input.
