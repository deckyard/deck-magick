<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# magick cheatsheet

Every export of `@deckyard/magick`. Guides are listed in
[the introduction](index.md).

```jennifer
import "@deckyard/magick/" as magick;
```

Every failure is `Error{kind: "magick"}`. A `c` argument is a `Config`, an
`img` an `Image`.

## Constants

| Constant | Value | Meaning |
|---|---|---|
| `ERROR_KIND` | `"magick"` | the `kind` of every error the deck throws |

## Types

### `Config`

| Field | Meaning |
|---|---|
| `binary as string` | the ImageMagick 7 program |
| `formats as list of string` | the coders files may be read and written with |
| `memory as string` | pixel memory limit, e.g. `256MiB` |
| `disk as string` | pixel-cache disk limit, e.g. `1GiB` |
| `area as string` | the largest image in pixels, e.g. `128MP` |
| `side as string` | the widest or tallest image, e.g. `16KP` |
| `timeoutMs as int` | how long one command may run |

### `Image`

| Field | Meaning |
|---|---|
| `input as string` | the pinned input, `PNG:photo.png` or `PNG:-` |
| `data as bytes` | the image bytes, when opened from bytes |
| `fromBytes as bool` | whether `data` is the input |
| `ops as list of string` | the operations' arguments |

### `Info`

| Field | Meaning |
|---|---|
| `format as string` | the coder, e.g. `PNG` |
| `width as int` | width in pixels |
| `height as int` | height in pixels |
| `colorspace as string` | e.g. `sRGB`, `Gray`, `CMYK` |
| `depth as int` | bits per channel |
| `frames as int` | frames or pages |
| `orientation as string` | EXIF orientation; `Undefined` for none |
| `opaque as bool` | no pixel is transparent |

### `Comparison`

| Field | Meaning |
|---|---|
| `value as float` | the metric in ImageMagick's units |
| `normalized as float` | the metric on a 0 to 1 scale |

## Configuration

| Function | Returns | Does |
|---|---|---|
| `magick.config()` | `Config` | safe defaults |
| `magick.defaultFormats()` | `list of string` | the raster formats allowed by default |
| `magick.withBinary(c, binary)` | `Config` | another `magick` program |
| `magick.withFormats(c, formats)` | `Config` | replace the allowed formats |
| `magick.allowFormat(c, format)` | `Config` | allow one more, e.g. `SVG` for trusted files |
| `magick.withLimits(c, memory, disk, area, side)` | `Config` | resource limits |
| `magick.withTimeout(c, ms)` | `Config` | per-command timeout, at least 1000 |
| `magick.version(c)` | `string` | the ImageMagick version line |
| `magick.available(c)` | `bool` | whether ImageMagick 7 runs |

## Opening and writing

| Function | Returns | Does |
|---|---|---|
| `magick.open(c, path)` | `Image` | a file, format from the extension |
| `magick.openAs(c, path, format)` | `Image` | a file in a named format |
| `magick.fromBytes(c, data, format)` | `Image` | bytes in a named format |
| `magick.write(c, img, path)` | `null` | run the operations, write; format from the extension |
| `magick.writeAs(c, img, path, format)` | `null` | the same, in a named format |
| `magick.encode(c, img, format)` | `bytes` | run the operations, return the bytes |

## Operations

| Function | Returns | Does |
|---|---|---|
| `magick.resize(img, width, height)` | `Image` | fit in a box; 0 for any |
| `magick.shrinkOnly(img, width, height)` | `Image` | fit, never enlarge |
| `magick.resizeExact(img, width, height)` | `Image` | exactly this size |
| `magick.thumbnail(img, width, height)` | `Image` | fit and drop metadata |
| `magick.cover(img, width, height)` | `Image` | fill the box, cut the overflow |
| `magick.crop(img, x, y, width, height)` | `Image` | cut out a rectangle |
| `magick.pad(img, width, height, fill)` | `Image` | centre on a canvas |
| `magick.rotate(img, degrees)` | `Image` | rotate clockwise |
| `magick.firstFrame(img)` | `Image` | read only the first frame |
| `magick.autoOrient(img)` | `Image` | upright by EXIF orientation |
| `magick.flip(img)` | `Image` | mirror top to bottom |
| `magick.flop(img)` | `Image` | mirror left to right |
| `magick.grayscale(img)` | `Image` | shades of grey |
| `magick.strip(img)` | `Image` | remove metadata |
| `magick.quality(img, quality)` | `Image` | lossy quality, 1 to 100 |
| `magick.blur(img, sigma)` | `Image` | Gaussian blur |
| `magick.sharpen(img, sigma)` | `Image` | sharpen |
| `magick.border(img, pixels, fill)` | `Image` | a border |
| `magick.annotate(img, text, where, x, y, size, fill)` | `Image` | literal text |
| `magick.overlay(img, over, where, x, y)` | `Image` | another image on top |

## Inspecting

| Function | Returns | Does |
|---|---|---|
| `magick.identify(c, path)` | `Info` | facts about a file |
| `magick.identifyBytes(c, data, format)` | `Info` | facts about bytes |
| `magick.compare(c, a, b, metric)` | `Comparison` | difference of two images |
| `magick.montage(c, inputs, path, columns, tileWidth, tileHeight)` | `null` | a contact sheet |
| `magick.run(c, args)` | `string` | `magick` with your own, unchecked arguments |
