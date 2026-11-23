# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

# magick - reading facts about images (identify), comparing them, contact
# sheets (montage), the version, and the raw escape hatch. Spliced into
# magick.j via include.

/**
 * What `identify` reports about an image; for an animation, its first frame.
 *
 * @field format {string} the coder, e.g. `PNG`
 * @field width {int} width in pixels
 * @field height {int} height in pixels
 * @field colorspace {string} e.g. `sRGB`, `Gray`, `CMYK`
 * @field depth {int} bits per channel
 * @field frames {int} frames: 1, or more for an animation or a multi-page file
 * @field orientation {string} the EXIF orientation, e.g. `TopLeft`, `RightTop`;
 *   `Undefined` when the file has none
 * @field opaque {bool} whether no pixel is transparent
 */
export def struct Info {
    format as string,
    width as int,
    height as int,
    colorspace as string,
    depth as int,
    frames as int,
    orientation as string,
    opaque as bool
};

/**
 * How different two images are.
 *
 * @field value {float} the metric in ImageMagick's own units (e.g. the count
 *   of differing pixels for `AE`)
 * @field normalized {float} the metric scaled to 0 to 1; 0 means identical for
 *   every metric but `PSNR`, where 1 does. ImageMagick 7.1.2 reports `SSIM` and
 *   `NCC` as distances like `DSSIM`; older releases may report the similarity
 */
export def struct Comparison {
    value as float,
    normalized as float
};

def const INFO_FORMAT as string init "%m|%w|%h|%[colorspace]|%z|%[orientation]|%[opaque]|%n\\n";

/**
 * Read the facts about an image file.
 *
 * @param c {Config} the configuration
 * @param path {string} the file
 * @return {Info} the facts
 * @throws {Error} kind `"magick"` for a refused name or format, or when
 *   ImageMagick cannot read the file
 */
export func identify(c as Config, path as string) {
    def argv as list of string init commandLine(
        $c,
        "identify",
        ["-format", INFO_FORMAT, pinned($c, $path, "")]);
    return infoFrom(checked(execute($c, $argv, "identify " + $path), "identify " + $path).stdout);
}

/**
 * Read the facts about an image held in memory.
 *
 * @param c {Config} the configuration
 * @param data {bytes} the encoded image
 * @param format {string} its coder; it is never guessed
 * @return {Info} the facts
 * @throws {Error} kind `"magick"` as `identify`
 */
export func identifyBytes(c as Config, data as bytes, format as string) {
    def img as Image init fromBytes($c, $data, $format);
    return infoFrom(runOn($c, $img, "identify", ["-format", INFO_FORMAT, $img.input], "identify").stdout);
}

/**
 * Fold `identify`'s output, one line per frame.
 *
 * @param out {string} the output
 * @return {Info} the first frame's facts
 */
func infoFrom(out as string) {
    def lines as list of string init strings.split(strings.trim($out), "\n");
    def f as list of string init strings.split($lines[0], "|");
    if (len($f) < 8) {
        fail("identify gave an unexpected answer: " + $lines[0]);
    }
    return Info{
        format: $f[0],
        width: toInt($f[1]),
        height: toInt($f[2]),
        colorspace: $f[3],
        depth: toInt($f[4]),
        frames: toInt($f[7]),
        orientation: $f[5],
        opaque: $f[6] == "True"
    };
}

/**
 * Read an integer ImageMagick printed.
 *
 * @param s {string} the text
 * @return {int} the integer; 0 when it is none
 */
func toInt(s as string) {
    try {
        return convert.toInt(strings.trim($s));
    } catch (e) {
        return 0;
    }
}

/**
 * Compare two images of the same size with a metric.
 *
 * @param c {Config} the configuration
 * @param a {string} one image file
 * @param b {string} the other
 * @param metric {string} `AE` (differing pixels), `MAE`, `MSE`, `RMSE`,
 *   `PSNR`, `SSIM`, `DSSIM` or `NCC`
 * @return {Comparison} the difference
 * @throws {Error} kind `"magick"` for an unknown metric, a refused file, or
 *   images ImageMagick cannot compare
 */
export func compare(c as Config, a as string, b as string, metric as string) {
    def m as string init strings.upper($metric);
    if (not lists.contains(["AE", "MAE", "MSE", "RMSE", "PSNR", "SSIM", "DSSIM", "NCC"], $m)) {
        fail("unknown metric " + $metric);
    }
    def args as list of string init [
        "-metric",
        $m,
        pinned($c, $a, ""),
        pinned($c, $b, ""),
        "null:"
    ];
    def r as os.Result init execute($c, commandLine($c, "compare", $args), "compare");
    if ($r.exitCode > 1) {
        fail("compare: " + firstError($r.stderr));
    }
    return comparisonFrom($r.stderr);
}

/**
 * Read `compare`'s answer, `53509.1 (0.816497)`.
 *
 * @param out {string} its error output, where it writes the metric
 * @return {Comparison} the two numbers
 */
func comparisonFrom(out as string) {
    def lines as list of string init strings.split(strings.trim($out), "\n");
    def last as string init strings.trim($lines[len($lines) - 1]);
    def nums as list of string init [];
    for (def m in regex.findAll("-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?", $last)) {
        $nums[] = $m.text;
    }
    if (len($nums) == 0) {
        fail("compare gave an unexpected answer: " + $last);
    }
    def value as float init convert.toFloat($nums[0]);
    def normalized as float init $value;
    if (len($nums) > 1) {
        $normalized = convert.toFloat($nums[1]);
    }
    return Comparison{value: $value, normalized: $normalized};
}

/**
 * Make a contact sheet: the images in a grid, scaled into tiles.
 *
 * @param c {Config} the configuration
 * @param inputs {list of string} the image files
 * @param path {string} the output file
 * @param columns {int} tiles per row
 * @param tileWidth {int} the tile width
 * @param tileHeight {int} the tile height
 * @return {null} nothing
 * @throws {Error} kind `"magick"` for no inputs, a refused file or size, or when
 *   ImageMagick fails
 */
export func montage(
    c as Config,
    inputs as list of string,
    path as string,
    columns as int,
    tileWidth as int,
    tileHeight as int) {
    if (len($inputs) == 0 or $columns <= 0) {
        fail("montage needs inputs and at least one column");
    }
    def args as list of string init [];
    for (def input in $inputs) {
        $args[] = pinned($c, $input, "");
    }
    def layout as list of string init [
        "-tile",
        convert.toString($columns) + "x",
        "-geometry",
        box($tileWidth, $tileHeight) + "+4+4"
    ];
    $args = lists.concat(lists.concat($args, $layout), [pinned($c, $path, "")]);
    checked(execute($c, commandLine($c, "montage", $args), "montage"), "montage");
    return null;
}

/**
 * The ImageMagick version line, e.g. `ImageMagick 7.1.2-34 Q16-HDRI x86_64`.
 *
 * @param c {Config} the configuration
 * @return {string} the version
 * @throws {Error} kind `"magick"` when the program cannot run
 */
export func version(c as Config) {
    def r as os.Result init checked(execute($c, [$c.binary, "-version"], "version"), "version");
    def first as string init strings.split($r.stdout, "\n")[0];
    return strings.trim(strings.replace($first, "Version:", ""));
}

/**
 * Whether ImageMagick 7 can run with this configuration.
 *
 * @param c {Config} the configuration
 * @return {bool} true when `version` works and reports ImageMagick 7
 */
export func available(c as Config) {
    try {
        return strings.startsWith(version($c), "ImageMagick 7");
    } catch (e) {
        return false;
    }
}

/**
 * Run `magick` with arguments of your own, after the resource limits. The
 * arguments are **not checked**: never put untrusted input in them; use the
 * typed functions instead.
 *
 * @param c {Config} the configuration
 * @param args {list of string} the arguments
 * @return {string} what it printed
 * @throws {Error} kind `"magick"` when it fails
 */
export func run(c as Config, args as list of string) {
    return checked(execute($c, commandLine($c, "", $args), "run"), "run").stdout;
}
