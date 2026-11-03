<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Security

ImageMagick reads hundreds of formats, some of which are programs: MVG and
MSL draw and read other files, SVG and PostScript call external renderers.
A file name can also be an instruction: `@list.txt` reads a list of files,
`text:/etc/passwd` renders a file as an image, `https://...` fetches one.
In 2016 this combination became [ImageTragick](https://imagetragick.com/)
(CVE-2016-3714): an "image" upload that ran commands on the server. The deck
is built so that an image or a file name from a user cannot do any of that.

## What the deck does

- **No shell.** Every command is an argument list handed to the program, so
  quotes, `;` and `$(...)` in a name are just characters.
- **The format is pinned.** Every file is passed as `PNG:photo.png`, the
  coder taken from the extension (or named with `openAs` / `writeAs` /
  `fromBytes`). ImageMagick then decodes it as that format or fails; it never
  looks at the content to pick another one. An MVG script saved as `cat.png`
  fails with `improper image header`; it is not drawn.
- **An allow-list of formats.** Only the coders in `Config.formats` may be
  read or written. `defaultFormats()` is raster formats with self-contained
  decoders: PNG, JPEG, GIF, WebP, TIFF, BMP, HEIC, AVIF, JPEG XL, ICO,
  PNM/PPM/PGM/PBM, TGA, QOI. SVG, PDF, PostScript, EPS and PSD need
  `allowFormat`, which you should only do for files you trust.
- **File names are checked.** Refused: a leading `-` (an option), `@` (a
  file list), `|` (a pipe) or `~` (a home directory); a coder or URL prefix
  (`msl:`, `https://`); a `%` (ImageMagick expands it); `*`, `?`, `[`, `]`
  and an opening brace (ImageMagick expands globs, so `*.png` would read
  every image beside it, and `a.png[0]` selects a frame); control
  characters; and an extension the deck does not know.
- **Text is literal.** `annotate` doubles `%`, so `%[exif:*]` prints as
  written, and refuses text starting with `@`, which would read a file.
- **Arguments are typed.** Sizes and offsets are integers; colours and
  gravities are checked against what ImageMagick accepts. Blur sigmas stop
  at 100 and sharpen sigmas at 10: sharpening costs the square of its sigma,
  and a sigma of 30 takes half a minute on a 3-megapixel photo.
- **Every command has limits.** `-limit memory`, `map`, `disk`, `area`,
  `width`, `height` and `time` come first on every command line:

  | Setting | Default | Stops |
  |---|---|---|
  | `memory` | `256MiB` | pixel caches in memory (also `map`) |
  | `disk` | `1GiB` | pixel caches spilled to disk |
  | `area` | `128MP` | a decompression bomb: a tiny file declaring a huge image |
  | `side` | `16KP` | one absurd dimension |
  | `timeoutMs` | 60000 | a command that runs on; the deck kills it |

  Images opened from bytes go through a temporary file, so the deck's
  timeout covers them too.

  Change them with `withLimits` and `withTimeout`:

  ```jennifer
  import "@deckyard/magick/" as magick;

  def c as magick.Config init magick.withLimits(magick.config(), "128MiB", "512MiB", "40MP", "8KP");
  $c = magick.withTimeout($c, 15000);
  ```

## What it does not do

- **The timeout kills `magick`, not its children.** A delegate such as
  Ghostscript, which PDF and PostScript need, outlives it; ImageMagick's own
  `-limit time` and the delegate policy below are what stop it.
- **`run` is unchecked.** It passes your arguments as they are, after the
  limits. Never build them from user input.
- **Decoders still parse hostile bytes.** Pinning stops format confusion, not
  a bug in libpng or libheif. Keep ImageMagick and its delegates updated,
  and run image work with the least privilege you can: a dedicated user, a
  container, no access to secrets.
- **ImageMagick's `policy.xml` still applies**, and is the second wall. A
  strict one disables what the deck never needs:

  ```xml
  <policymap>
    <policy domain="delegate" rights="none" pattern="*" />
    <policy domain="coder" rights="none" pattern="{MVG,MSL,SVG,MSVG,TEXT,EPHEMERAL,URL,HTTP,HTTPS,FTP,PS,EPS,PDF,XPS}" />
    <policy domain="path" rights="none" pattern="@*" />
  </policymap>
  ```

  Install it as `/etc/ImageMagick-7/policy.xml` (the location varies; `magick
  -list policy` shows the one in use).
