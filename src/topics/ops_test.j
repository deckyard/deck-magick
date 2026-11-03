# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# magick - white-box tests for the ops topic. Spliced into magick_test.j via
# include.

/**
 * An image of a file, with no operations.
 *
 * @return {Image} the image
 */
func photo() {
    return open(config(), "photo.jpg");
}

func noSize() {
    resize(photo(), 0, 0);
}

func badCrop() {
    crop(photo(), -1, 0, 10, 10);
}

func badQuality() {
    quality(photo(), 101);
}

func badColour() {
    border(photo(), 2, "red; rm -rf /");
}

func badGravity() {
    annotate(photo(), "hi", "Middle", 0, 0, 12, "white");
}

func fileText() {
    annotate(photo(), "@/etc/passwd", "Center", 0, 0, 12, "white");
}

func bytesOverlay() {
    overlay(
        photo(),
        fromBytes(config(), convert.bytesFromString("x", "utf-8"), "PNG"),
        "Center",
        0,
        0);
}

func hugeBlur() {
    blur(photo(), 101.0);
}

func hugeSharpen() {
    sharpen(photo(), 10.5);
}

func emptyBytes() {
    fromBytes(config(), convert.bytesFromString("", "utf-8"), "PNG");
}

func testOperationsBuildArguments() {
    testing.assertEqual(photo().input, "JPEG:photo.jpg");
    testing.assertEqual(openAs(config(), "upload.bin", "webp").input, "WEBP:upload.bin");
    testing.assertEqual(resize(photo(), 800, 0).ops, ["-resize", "800"]);
    testing.assertEqual(resize(photo(), 0, 600).ops, ["-resize", "x600"]);
    testing.assertEqual(shrinkOnly(photo(), 800, 600).ops, ["-resize", "800x600>"]);
    testing.assertEqual(resizeExact(photo(), 10, 20).ops, ["-resize", "10x20!"]);
    testing.assertEqual(thumbnail(photo(), 64, 64).ops, ["-thumbnail", "64x64"]);
    testing.assertEqual(
        cover(photo(), 100, 50).ops,
        ["-resize", "100x50^", "-gravity", "Center", "-extent", "100x50", "+repage"]);
    testing.assertEqual(
        crop(photo(), 5, 6, 10, 20).ops,
        ["+gravity", "-crop", "10x20+5+6", "+repage"]);
    testing.assertEqual(rotate(photo(), 90.0).ops, ["-rotate", "90.0"]);
    testing.assertEqual(rotate(photo(), -12.5).ops, ["-rotate", "-12.5"]);
    testing.assertEqual(autoOrient(photo()).ops, ["-auto-orient"]);
    testing.assertEqual(firstFrame(firstFrame(photo())).input, "JPEG:photo.jpg[0]");
    testing.assertEqual(flop(flip(photo())).ops, ["-flip", "-flop"]);
    testing.assertEqual(grayscale(photo()).ops, ["-colorspace", "Gray"]);
    testing.assertEqual(strip(photo()).ops, ["-strip"]);
    testing.assertEqual(quality(photo(), 82).ops, ["-quality", "82"]);
    testing.assertEqual(blur(photo(), 1.5).ops, ["-blur", "0x1.5"]);
    testing.assertEqual(sharpen(photo(), 0.8).ops, ["-sharpen", "0x0.8"]);
    testing.assertEqual(
        border(photo(), 4, "#202020").ops,
        ["-bordercolor", "#202020", "-border", "4"]);
    testing.assertEqual(
        pad(photo(), 300, 200, "none").ops,
        ["-background", "none", "-gravity", "Center", "-extent", "300x200"]);
}

func testTextIsLiteral() {
    def img as Image init annotate(
        photo(),
        "100% sure %[exif:*]",
        "SouthEast",
        10,
        -4,
        18,
        "rgba(255,255,255,0.8)");
    testing.assertEqual(
        $img.ops,
        [
            "-gravity",
            "SouthEast",
            "-pointsize",
            "18",
            "-fill",
            "rgba(255,255,255,0.8)",
            "-annotate",
            "+10-4",
            "100%% sure %%[exif:*]"
        ]);
    testing.assertThrows("fileText", ERROR_KIND);
}

func testOverlayRunsTheOverlaysOwnOperations() {
    def logo as Image init resize(open(config(), "logo.png"), 64, 0);
    def img as Image init overlay(photo(), $logo, "SouthEast", 8, 8);
    testing.assertEqual(
        $img.ops,
        [
            "-respect-parentheses",
            "(",
            "PNG:logo.png",
            "-resize",
            "64",
            ")",
            "-gravity",
            "SouthEast",
            "-geometry",
            "+8+8",
            "-composite"
        ]);
    testing.assertThrows("bytesOverlay", ERROR_KIND);
}

func testBadArgumentsAreRefused() {
    testing.assertThrows("noSize", ERROR_KIND);
    testing.assertThrows("badCrop", ERROR_KIND);
    testing.assertThrows("badQuality", ERROR_KIND);
    testing.assertThrows("badColour", ERROR_KIND);
    testing.assertThrows("badGravity", ERROR_KIND);
    testing.assertThrows("emptyBytes", ERROR_KIND);
    testing.assertThrows("hugeBlur", ERROR_KIND);
    testing.assertThrows("hugeSharpen", ERROR_KIND);
    testing.assertEqual(checkColor("#FFF"), "#FFF");
    testing.assertEqual(checkColor("gray(50%)"), "gray(50%)");
    testing.assertEqual(checkColor("SkyBlue1"), "SkyBlue1");
}

func testBytesGoThroughAFile() {
    def img as Image init fromBytes(config(), convert.bytesFromString("PNG data", "utf-8"), "png");
    testing.assertEqual($img.input, "PNG:-");
    testing.assertEqual($img.fromBytes, true);
    def text as Image init annotate(strip($img), "PNG:-", "Center", 0, 0, 12, "white");
    def args as list of string init swapInput(readArgs($text), $img.input, "/tmp/x.in");
    testing.assertEqual($args[0], "PNG:/tmp/x.in");
    testing.assertEqual($args[1], "-strip");
    testing.assertEqual($args[len($args) - 1], "PNG:-");
    def first as Image init firstFrame($img);
    testing.assertEqual(
        swapInput(readArgs($first), $first.input, "/tmp/x.in"),
        ["PNG:/tmp/x.in[0]"]);
}
