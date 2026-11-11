# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0
# pragma-jennifer-capability: exec

/**
 * Image processing through the ImageMagick 7 command line.
 *
 * Open a file or bytes, chain operations (resize, crop, rotate, strip,
 * annotate, overlay ...), and write the result in any format ImageMagick
 * supports; `identify`, `compare` and `montage` cover the other tools. Every
 * chain runs as one `magick` process.
 *
 * Built for input you do not control. File names are checked and every file
 * is read with its format pinned (`PNG:photo.png`), so ImageMagick never
 * guesses a format from the content; only the formats in `Config.formats`
 * may be read or written, and the default set leaves out SVG, PDF,
 * PostScript and the script formats. Every command carries memory, disk,
 * size and time limits, and is killed when it runs too long. Every failure
 * is `Error{kind: "magick"}`.
 *
 * | topic | covers |
 * | --- | --- |
 * | `core` | the configuration, the checks, the limits, running `magick` |
 * | `ops` | the image builder, its operations, writing |
 * | `inspect` | identify, compare, montage, version, the raw `run` |
 *
 * @module magick
 * @see https://imagemagick.org/script/command-line-processing.php
 * @example
 *   def c as magick.Config init magick.config();
 *   def img as magick.Image init magick.open($c, "upload.jpg");
 *   $img = magick.strip(magick.thumbnail(magick.autoOrient($img), 320, 320));
 *   magick.write($c, $img, "thumb.webp");
 */
use convert;
use fs;
use lists;
use maps;
use os;
use regex;
use strings;
use time;

include "topics/core.j";
include "topics/ops.j";
include "topics/inspect.j";
