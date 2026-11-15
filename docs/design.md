<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

Image processing by running the ImageMagick 7 `magick` program: open an
image from a file or bytes, collect operations (resize, crop, rotate, blur,
sharpen, annotate, overlay and more) in an immutable `Image` builder, then
write it to a file or encode it to bytes in one `magick` process.
`identify`, `compare`, `montage` and `version` cover the other tools.

The deck is built for images and file names that come from users, so most of
its code checks and pins arguments. [Security](security.md) is the
user-facing statement of the threat model.

Not in scope:

- **An image library in Jennifer.** Decoders and filters are ImageMagick's;
  the deck drives the installed program.
- **Remote images.** ImageMagick is never given a URL, and the deck declares
  no `net` capability.
- **Vector and document formats by default.** SVG, PDF, PostScript, EPS and
  PSD run external renderers or are scripts in disguise; they need
  `allowFormat`, for trusted files only.
- **ImageMagick 6.** Only the `magick` entry point of version 7 is driven.

## Decisions

- **Drive the program, never a shell.** Every command is an argument list for
  `os.spawn`, so quotes, `;` and `$(...)` in a name are plain characters.
  The cost is the `exec` capability and no `jennifer-tiny`.
- **The ImageTragick threat model.** An "image" upload once ran commands on
  servers (CVE-2016-3714) because ImageMagick sniffs formats, some formats
  are programs, and a file name can be an instruction. Each decision below
  closes one of those doors.
- **Formats are pinned.** Every file argument carries its coder
  (`PNG:photo.png`), taken from the extension or named with `openAs`,
  `writeAs` or `fromBytes`, so ImageMagick decodes it as that format or
  fails and never picks another one from the content. An MVG script named
  `.png` fails with "improper image header".
- **An allow-list of coders.** Only formats in `Config.formats` may be read
  or written. `defaultFormats` holds raster formats with self-contained
  decoders; the deck still knows the extensions of the excluded formats, so
  `allowFormat` can enable them.
- **File names are checked.** A leading `-`, `@`, `|` or `~`, a coder or URL
  prefix, `%`, glob and frame characters (`*`, `?`, `[`, `]`, an opening
  brace), control characters and unknown extensions are refused.
- **Text is literal.** `annotate` doubles `%` (so `%[exif:*]` prints as
  written) and refuses text starting with `@`, which would read a file.
- **Typed arguments.** Sizes and offsets are integers, colours and gravities
  are checked, blur sigmas stop at 100 and sharpen sigmas at 10 (sharpening
  costs the square of its sigma). A new operation validates every value the
  same way, because anything reaching ImageMagick as a string is an
  injection surface.
- **Limits on every command.** `-limit memory`, `map`, `disk`, `area`,
  `width`, `height` and `time` come first on every command line, from
  `Config` (`withLimits`, `withTimeout`). `version` is the only call without
  them.
- **One process per image.** Nothing runs until `write`, `writeAs` or
  `encode`; operations accumulate as arguments. `crop` resets gravity first,
  so a gravity left by an earlier `annotate` or `overlay` does not shift it,
  and `overlay` keeps the overlay's own settings in parentheses.
- **Bytes go through temporary files.** Input bytes are written to a
  temporary file instead of piped, so the deck's timeout covers them too;
  `encode` writes into a private temporary directory and reads the result
  back. Both are removed on every path, a kill included.
- **`compare` reads ImageMagick's exit codes**: 1 means "the images differ"
  and is a result; only a higher code is a failure. The metric is parsed from
  the error output.
- **Immutable configuration.** `Config` is built with `config` and the
  `with*` functions, each returning a changed copy.

## Errors

Every failure is an `Error` with a message starting `magick: `. Its kind is
`"magick"` for a refused argument or file name, a program that cannot start
and a non-zero exit (with ImageMagick's first error line, warnings skipped;
ImageMagick's own `-limit` refusals included). A command the deck kills at
its timeout is kind `"timeout"`, the generic kind every library shares.

## Security and limits

| Setting | Default | Stops |
|---|---|---|
| `memory` | `256MiB` | pixel caches in memory (also `map`) |
| `disk` | `1GiB` | pixel caches spilled to disk |
| `area` | `128MP` | a decompression bomb: a tiny file declaring a huge image |
| `side` | `16KP` | one absurd dimension |
| `timeoutMs` | 60000 | a command that runs on; the deck kills it |

ImageMagick's own `-limit time` gets the timeout rounded up to seconds, as a
second stop. `run` passes its arguments unchecked after the limits and is for
trusted callers only.

## Testing and validation

- Pure tests cover path checks, pinning, argument building, configuration
  validation and error-line picking, and run everywhere.
- Live tests run ImageMagick 7 on fixtures painted on the fly into a
  temporary directory; there is no `testdata/`. They return early where
  `magick` is not installed, which includes CI's container, so the suite
  must be run on a machine with ImageMagick 7 before a release. One test
  reports which case applies.
- Live tests assert that no temporary file is left behind (after a kill
  too), that runaway commands are stopped, bytes input included, and that a
  disguised MVG script is not drawn.
- CI parses the example but cannot run it.

## Known limitations and open questions

- The timeout kills `magick`, not delegates it started (Ghostscript for PDF
  and PostScript); `-limit time` and a strict `policy.xml` are the backstop.
- Decoders still parse hostile bytes: pinning stops format confusion, not a
  bug in a codec library. Keep ImageMagick updated and run image work with
  least privilege.
- Writing a multi-frame image to a single-frame format makes numbered files;
  `encode` detects this and asks for `firstFrame`.
- An overlay cannot come from bytes; only the base image uses the
  temporary-file swap.

## Dependencies on the interpreter

- Floor `>=0.26.0`, the default binary only (`exec` through `os.spawn`,
  `os.poll` and `os.kill`).
