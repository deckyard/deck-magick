#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

/**
 * thumbnails example: make web thumbnails of the images in a directory.
 *
 * Needs ImageMagick 7. Run with:
 *   jennifer run examples/thumbnails.j photos/ thumbs/
 * Each image is turned upright, stripped of its metadata (GPS included),
 * fitted into 320x320 and written as WebP; a contact sheet goes beside them.
 */

use fs;
use io;
use os;

import "../src/magick.j" as magick;

if (len(os.ARGS) < 3) {
    io.printf("usage: jennifer run examples/thumbnails.j <from-dir> <to-dir>\n");
    exit 1;
}
def srcDir as string init os.ARGS[1];
def outDir as string init os.ARGS[2];

def c as magick.Config init magick.config();
if (not magick.available($c)) {
    io.printf("ImageMagick 7 is not installed\n");
    exit 1;
}
io.printf("%s\n", magick.version($c));
fs.mkdirAll($outDir);

def made as list of string init [];
for (def name in fs.list($srcDir)) {
    def source as string init $srcDir + "/" + $name;
    def img as magick.Image;
    try {
        $img = magick.open($c, $source);
    } catch (e) {
        io.printf("skip %s: %s\n", $name, $e.message);
        continue;
    }
    def info as magick.Info init magick.identify($c, $source);
    $img = magick.strip(magick.shrinkOnly(magick.autoOrient($img), 320, 320));
    def out as string init $outDir + "/" + $name + ".webp";
    magick.write($c, magick.quality($img, 80), $out);
    $made[] = $out;
    io.printf("%s %dx%d %s -> %s\n", $name, $info.width, $info.height, $info.format, $out);
}

if (len($made) > 0) {
    magick.montage($c, $made, $outDir + "/sheet.jpg", 4, 160, 160);
    io.printf("contact sheet: %s/sheet.jpg\n", $outDir);
}
