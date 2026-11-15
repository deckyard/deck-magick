# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# magick - white-box tests for the core topic, and the helpers the live
# tests share. Spliced into magick_test.j via include.

# Whether ImageMagick 7 runs here; the live tests return early without it.
def hasMagick as bool init available(config());

/**
 * Mark a call that should have thrown. The error reaches the test's own
 * `catch`, whose assertions on kind and message then fail.
 *
 * @param what {string} what got through
 * @throws {Error} always, with `kind` `"missed"`
 */
func missed(what as string) {
    throw Error{kind: "missed", message: $what};
}

/**
 * The message a pinned file name fails with.
 *
 * @param path {string} the file name
 * @return {string} the message; "" when it passes
 */
func refusal(path as string) {
    try {
        pinned(config(), $path, "");
    } catch (e) {
        testing.assertEqual($e.kind, ERROR_KIND);
        return $e.message;
    }
    return "";
}

/**
 * A fresh directory for a live test, and an image in it made by ImageMagick
 * directly: `w`x`h` of one colour.
 *
 * @param name {string} the image's file name
 * @param size {string} e.g. `64x48`
 * @param fill {string} the colour
 * @return {string} the directory
 */
func scratch(name as string, size as string, fill as string) {
    def dir as string init fs.makeTempDir(os.tempDir(), "magick-test-");
    paint($dir, $name, $size, $fill);
    return $dir;
}

/**
 * Make an image of one colour with ImageMagick directly.
 *
 * @param dir {string} the directory
 * @param name {string} the file name
 * @param size {string} e.g. `64x48`
 * @param fill {string} the colour
 */
func paint(dir as string, name as string, size as string, fill as string) {
    def r as os.Result init os.run(["magick", "-size", $size, "xc:" + $fill, $dir + "/" + $name]);
    testing.assertEqual($r.exitCode, 0);
}

# A command past its timeout is killed and raises kind "timeout". `sleep`
# stands in for a hanging magick, so this runs without ImageMagick too.
func testACommandPastItsTimeoutIsKindTimeout() {
    def c as Config init withTimeout(config(), 1000);
    try {
        execute($c, ["sleep", "5"], "sleep");
        missed("a hanging command");
    } catch (e) {
        testing.assertEqual($e.kind, "timeout");
        testing.assertEqual($e.message, "magick: sleep: killed after 1000 ms");
    }
}

func testFileNamesAreChecked() {
    testing.assertEqual(refusal("photo.png"), "");
    testing.assertEqual(refusal("/srv/up/IMG_0001.JPG"), "");
    testing.assertEqual(refusal("C:/a.png"), "");
    for (def bad in [
        "",
        "-write.png",
        "@list.png",
        "|cat x.png",
        "msl:x.png",
        "https://evil/x.png",
        "x.png[0]",
        "frame%d.png",
        "a\nb.png",
        "ephemeral:x.png",
        "text:x.png",
        "*.png",
        "?.png",
        "x[ab].png",
        convert.fromCodepoint(123) + "a,b" + convert.fromCodepoint(125) + ".png",
        "~/x.png"
    ]) {
        testing.assertTrue(refusal($bad) != "");
    }
    testing.assertTrue(strings.contains(refusal("notes.txt"), "cannot tell the format"));
    testing.assertTrue(strings.contains(refusal("logo.svg"), "SVG is not allowed"));
    testing.assertTrue(strings.contains(refusal("doc.pdf"), "PDF is not allowed"));
}

func testFormatsArePinned() {
    def c as Config init config();
    testing.assertEqual(pinned($c, "a.jpg", ""), "JPEG:a.jpg");
    testing.assertEqual(pinned($c, "dir.v2/a.TIFF", ""), "TIFF:dir.v2/a.TIFF");
    testing.assertEqual(pinned($c, "blob", "png"), "PNG:blob");
    testing.assertEqual(pinned(allowFormat($c, "svg"), "logo.svg", ""), "SVG:logo.svg");
    testing.assertEqual(coderFor("noext"), "");
    testing.assertEqual(coderFor("a.b/noext"), "");
    def only as Config init withFormats($c, ["png", "webp"]);
    testing.assertEqual($only.formats, ["PNG", "WEBP"]);
    testing.assertEqual(lists.contains(defaultFormats(), "SVG"), false);
}

func badFormatName() {
    withFormats(config(), ["PNG:"]);
}

func badLimit() {
    withLimits(config(), "lots", "1GiB", "64MP", "8KP");
}

func shortTimeout() {
    withTimeout(config(), 10);
}

func optionAsBinary() {
    withBinary(config(), "-version");
}

func testConfiguration() {
    def c as Config init config();
    testing.assertEqual($c.binary, "magick");
    testing.assertEqual(withBinary($c, "/opt/im7/bin/magick").binary, "/opt/im7/bin/magick");
    def l as Config init withLimits($c, "512MiB", "2GiB", "64MP", "8KP");
    testing.assertEqual([$l.memory, $l.disk, $l.area, $l.side], ["512MiB", "2GiB", "64MP", "8KP"]);
    testing.assertEqual(withTimeout($c, 5000).timeoutMs, 5000);
    testing.assertThrows("badFormatName", ERROR_KIND);
    testing.assertThrows("badLimit", ERROR_KIND);
    testing.assertThrows("shortTimeout", ERROR_KIND);
    testing.assertThrows("optionAsBinary", ERROR_KIND);
}

func testEveryCommandCarriesTheLimits() {
    def c as Config init withTimeout(config(), 2500);
    def argv as list of string init commandLine($c, "identify", ["PNG:a.png"]);
    testing.assertEqual($argv[0], "magick");
    testing.assertEqual($argv[1], "identify");
    testing.assertEqual(lists.slice($argv, 2, 5), ["-limit", "memory", "256MiB"]);
    testing.assertTrue(lists.contains($argv, "area"));
    testing.assertEqual(lists.slice($argv, len($argv) - 4), ["-limit", "time", "3", "PNG:a.png"]);
}

func testErrorLines() {
    def err as string init "magick: unknown property @ warning/property.c/x\nmagick: improper image header `a.png' @ error/png.c/ReadPNGImage/3956.\n";
    testing.assertTrue(strings.contains(firstError($err), "improper image header"));
    testing.assertTrue(strings.contains(firstError("magick: only a warning/x\n"), "only a warning"));
    testing.assertEqual(firstError(""), "failed without a message");
    try {
        checked(os.Result{exitCode: 1, stdout: "", stderr: "magick: boom\n"}, "write x.png");
        missed("a failed command passed");
    } catch (e) {
        testing.assertEqual($e.message, "magick: write x.png: magick: boom");
    }
}

func testAMissingBinaryIsADeckError() {
    def c as Config init withBinary(config(), "/nonexistent/magick");
    testing.assertEqual(available($c), false);
    try {
        version($c);
        missed("a missing binary ran");
    } catch (e) {
        testing.assertEqual($e.kind, ERROR_KIND);
        testing.assertTrue(strings.contains($e.message, "is ImageMagick 7 installed"));
    }
}
