# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# magick - white-box tests for the inspect topic. Spliced into magick_test.j via
# include.

func testImageMagickRunsHere() {
    if (not $hasMagick) {
        return;
    }
    testing.assertTrue(strings.startsWith(version(config()), "ImageMagick 7"));
}

func testWriteAndIdentify() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init scratch("red.png", "64x48", "red");
    def img as Image init open($c, $dir + "/red.png");
    write($c, resize($img, 32, 0), $dir + "/small.jpg");
    def small as Info init identify($c, $dir + "/small.jpg");
    testing.assertEqual($small.format, "JPEG");
    testing.assertEqual([$small.width, $small.height, $small.frames], [32, 24, 1]);
    testing.assertEqual($small.opaque, true);
    write($c, cover($img, 20, 20), $dir + "/square.png");
    testing.assertEqual(identify($c, $dir + "/square.png").width, 20);
    writeAs($c, crop($img, 4, 4, 10, 5), $dir + "/crop.dat", "PNG");
    def cropped as Info init identifyBytes($c, fs.readBytes($dir + "/crop.dat"), "PNG");
    fs.removeAll($dir);
    testing.assertEqual([$cropped.width, $cropped.height], [10, 5]);
}

func testBytesInAndOut() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init scratch("blue.png", "40x30", "blue");
    def data as bytes init fs.readBytes($dir + "/blue.png");
    def webp as bytes init encode($c, grayscale(fromBytes($c, $data, "PNG")), "WEBP");
    def info as Info init identifyBytes($c, $webp, "WEBP");
    testing.assertEqual($info.format, "WEBP");
    testing.assertEqual([$info.width, $info.height], [40, 30]);
    fs.removeAll($dir);
}

func testCompare() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init scratch("a.png", "16x16", "red");
    paint($dir, "b.png", "16x16", "red");
    paint($dir, "c.png", "16x16", "blue");
    def same as Comparison init compare($c, $dir + "/a.png", $dir + "/b.png", "rmse");
    def other as Comparison init compare($c, $dir + "/a.png", $dir + "/c.png", "AE");
    fs.removeAll($dir);
    testing.assertEqual($same.normalized, 0.0);
    testing.assertTrue($other.value > 100.0);
    testing.assertTrue($other.normalized > 0.6 and $other.normalized < 0.7);
    testing.assertEqual(
        comparisonFrom("53509.1 (0.816497)"),
        Comparison{value: 53509.1, normalized: 0.816497});
    testing.assertEqual(comparisonFrom("warn\n2.5e-05 (1e-07)").normalized, 0.0000001);
}

func unknownMetric() {
    compare(config(), "a.png", "b.png", "LPIPS");
}

func testMontageAnnotateOverlay() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init scratch("a.png", "50x50", "red");
    paint($dir, "b.png", "50x50", "green");
    paint($dir, "c.png", "50x50", "blue");
    montage(
        $c,
        [$dir + "/a.png", $dir + "/b.png", $dir + "/c.png"],
        $dir + "/sheet.png",
        2,
        40,
        40);
    def sheet as Info init identify($c, $dir + "/sheet.png");
    testing.assertEqual([$sheet.width, $sheet.height], [96, 96]);
    def marked as Image init annotate(
        open($c, $dir + "/a.png"),
        "100% %[w] @x",
        "Center",
        0,
        0,
        10,
        "white");
    $marked = overlay($marked, resize(open($c, $dir + "/b.png"), 10, 10), "SouthEast", 2, 2);
    write($c, $marked, $dir + "/marked.png");
    testing.assertEqual(identify($c, $dir + "/marked.png").width, 50);
    fs.removeAll($dir);
    testing.assertThrows("unknownMetric", ERROR_KIND);
}

func testDisguisedScriptsAreNotRun() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init fs.makeTempDir(os.tempDir(), "magick-test-");
    def mvg as string init "push graphic-context\nviewbox 0 0 8 8\nfill red\nrectangle 0,0 7,7\npop graphic-context\n";
    fs.writeString($dir + "/evil.png", $mvg);
    try {
        write($c, open($c, $dir + "/evil.png"), $dir + "/out.png");
        missed("an MVG script named .png was drawn");
    } catch (e) {
        testing.assertTrue(strings.contains($e.message, "improper image header"));
    }
    testing.assertEqual(fs.exists($dir + "/out.png"), false);
    fs.removeAll($dir);
}

func testRunawayCommandsAreStopped() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init withTimeout(config(), 1000);
    def started as time.Time init time.now();
    try {
        run($c, ["-size", "6000x6000", "plasma:", "-blur", "0x40", "-blur", "0x40", "null:"]);
        missed("a long command finished within a second");
    } catch (e) {
        testing.assertEqual($e.kind, ERROR_KIND);
    }
    testing.assertTrue(time.milliseconds(time.sub(time.now(), $started)) < 8000);
    try {
        run(config(), ["-size", "20000x20000", "xc:red", "null:"]);
        missed("a 400 megapixel image passed a 128 megapixel limit");
    } catch (e) {
        testing.assertTrue(strings.contains($e.message, "limit"));
    }
}

func testCropIgnoresAnEarlierGravity() {
    if (not $hasMagick) {
        return;
    }
    def c as Config init config();
    def dir as string init scratch("red.png", "10x10", "red");
    def r as os.Result init os.run([
        "magick",
        "-size",
        "50x50",
        "xc:red",
        "-fill",
        "blue",
        "-draw",
        "rectangle 30,30 49,49",
        $dir + "/corner.png"
    ]);
    testing.assertEqual($r.exitCode, 0);
    def img as Image init annotate(
        open($c, $dir + "/corner.png"),
        ".",
        "SouthEast",
        0,
        0,
        8,
        "blue");
    write($c, crop($img, 0, 0, 10, 10), $dir + "/out.png");
    def d as Comparison init compare($c, $dir + "/out.png", $dir + "/red.png", "AE");
    fs.removeAll($dir);
    testing.assertEqual($d.value, 0.0);
}

/**
 * The deck's temporary files left in the temp directory.
 *
 * @return {int} how many there are
 */
func leftovers() {
    def n as int init 0;
    for (def name in fs.list(os.tempDir())) {
        if (strings.contains($name, "jennifer-magick-")) {
            $n = $n + 1;
        }
    }
    return $n;
}

func testBytesInputIsKilledToo() {
    if (not $hasMagick) {
        return;
    }
    def before as int init leftovers();
    def dir as string init scratch("red.png", "40x30", "red");
    def data as bytes init fs.readBytes($dir + "/red.png");
    fs.removeAll($dir);
    def c as Config init withTimeout(config(), 1000);
    def img as Image init blur(
        blur(resizeExact(fromBytes($c, $data, "PNG"), 6000, 6000), 100.0),
        100.0);
    def started as time.Time init time.now();
    try {
        encode($c, $img, "PNG");
        missed("a long command from bytes finished within a second");
    } catch (e) {
        testing.assertTrue(strings.contains($e.message, "killed after 1000 ms"));
    }
    testing.assertTrue(time.milliseconds(time.sub(time.now(), $started)) < 8000);
    testing.assertEqual(leftovers(), $before);
}

func testAnimationsNeedAFrameForOneFrameFormats() {
    if (not $hasMagick) {
        return;
    }
    def before as int init leftovers();
    def c as Config init config();
    def dir as string init fs.makeTempDir(os.tempDir(), "magick-test-");
    def r as os.Result init os.run([
        "magick",
        "-size",
        "20x20",
        "xc:red",
        "xc:blue",
        "xc:green",
        $dir + "/anim.gif"
    ]);
    testing.assertEqual($r.exitCode, 0);
    testing.assertEqual(identify($c, $dir + "/anim.gif").frames, 3);
    try {
        encode($c, open($c, $dir + "/anim.gif"), "PNG");
        missed("three frames encoded as one PNG");
    } catch (e) {
        testing.assertTrue(strings.contains($e.message, "use firstFrame"));
    }
    testing.assertEqual(leftovers(), $before);
    def png as bytes init encode($c, firstFrame(open($c, $dir + "/anim.gif")), "PNG");
    def gif as bytes init fs.readBytes($dir + "/anim.gif");
    def one as Info init identifyBytes(
        $c,
        encode($c, firstFrame(fromBytes($c, $gif, "GIF")), "JPEG"),
        "JPEG");
    fs.removeAll($dir);
    testing.assertEqual(identifyBytes($c, $png, "PNG").frames, 1);
    testing.assertEqual([$one.width, $one.frames], [20, 1]);
    testing.assertEqual(leftovers(), $before);
}
