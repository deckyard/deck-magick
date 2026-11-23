# @deckyard/magick

[![test](https://github.com/deckyard/deck-magick/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-magick/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-magick/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-magick)](https://github.com/deckyard/deck-magick/releases/latest)

Image processing for [Jennifer](https://jennifer-lang.dev/) through the
[ImageMagick 7](https://imagemagick.org/) command line: resize, crop,
thumbnail, rotate, strip metadata, annotate, watermark, convert between
formats, identify, compare and montage. Built for images and file names you
do not control: no shell, formats pinned and allow-listed, file names and
text checked, memory, size and time limits on every command.

**[Documentation](https://deckyard.github.io/deck-magick/)**

## Install

```sh
jvc add @deckyard/magick
```

Or unpack `src/` from a release archive (`deckyard-magick-<version>.tar.gz`)
into `vendor/deckyard/magick/`.

## Usage

```jennifer
import "@deckyard/magick/" as magick;

def c as magick.Config init magick.config();
def img as magick.Image init magick.open($c, "upload.jpg");
$img = magick.strip(magick.shrinkOnly(magick.autoOrient($img), 1600, 1600));
magick.write($c, magick.quality($img, 82), "photo.webp");

def info as magick.Info init magick.identify($c, "photo.webp");
io.printf("%dx%d %s\n", $info.width, $info.height, $info.format);
```

## Requirements

Jennifer 0.27.0 or newer and the default `jennifer` binary (the deck needs
the `exec` capability); ImageMagick 7 (`magick`) on the host.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/magick_test.j      # tests; the live ones need ImageMagick 7
tools/check-docs.sh                  # docs against the code
```

The tests that run ImageMagick return early where it is not installed, as in
CI's container; run the suite on a machine with ImageMagick 7 before a release.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

ImageMagick is a trademark of ImageMagick Studio LLC. This deck is not
affiliated with or endorsed by it.
