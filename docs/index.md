<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/magick

Image processing through the [ImageMagick™ 7](https://imagemagick.org/)
command line. Open a file or bytes, chain operations, write the result in
any format ImageMagick supports; `identify`, `compare` and `montage` cover
the other tools. Each chain runs as one `magick` process.

These are not bindings to ImageMagick's C library: Jennifer has no foreign
function interface. The deck builds a checked argument list and runs the
program, the way you would from a shell, minus the shell.

## Conventions

Snippets assume this import:

```jennifer
import "@deckyard/magick/" as magick;

def c as magick.Config init magick.config();
def img as magick.Image init magick.open($c, "upload.jpg");
$img = magick.strip(magick.thumbnail(magick.autoOrient($img), 320, 320));
magick.write($c, $img, "thumb.webp");
```

A `Config` says which program to run and what it may do; `config()` gives
safe defaults (see [Security](security.md)). An `Image` is a value: an input
plus a list of operations. Each operation returns a changed copy, and
nothing runs until `write`, `writeAs` or `encode`.

## Errors

Every failure is `Error{kind: "magick"}`, except a command the deck kills at
its timeout, which is kind `"timeout"`:

- a refused file name or format, a bad size, colour or gravity, before
  anything runs;
- ImageMagick's own error, its first line:
  `magick: write out.png: magick: improper image header 'evil.png' @ error/png.c/ReadPNGImage/3956.`;
- one of ImageMagick's `-limit` refusals: `width or height exceeds limit`;
- a command killed at its timeout, kind `"timeout"`:
  `magick: write out.png: killed after 60000 ms`;
- a missing program: `cannot run magick (is ImageMagick 7 installed?)`.

## Requirements

Jennifer 0.27.0 or newer, default `jennifer` binary: the deck needs the
`exec` capability, which `jennifer-tiny` lacks. ImageMagick 7 (the `magick`
program; ImageMagick 6's `convert` is not supported) on the `PATH`, or named
with `withBinary`. Formats beyond the built-in ones need ImageMagick's
delegates installed (libheif for HEIC and AVIF, libjxl for JPEG XL).
`magick -list format` shows what a host can do.

## Trademarks

ImageMagick™ is a trademark of ImageMagick Studio LLC. PostScript™ is a
trademark of Adobe Inc. Ghostscript™ is a trademark of Artifex Software,
Inc. Other product and company names may be trademarks of their respective
owners. They are used only to identify the products this deck works with.
This deck is an independent project, not affiliated with, sponsored or
endorsed by ImageMagick Studio LLC, Adobe Inc. or Artifex Software, Inc.
