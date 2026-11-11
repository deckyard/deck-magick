# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.26.0

# magick - the configuration, the checks every file name and argument passes,
# the resource limits, and running the `magick` program. Spliced into
# magick.j via include.

/** The `kind` of every error the deck throws. */
export def const ERROR_KIND as string init "magick";

/**
 * How to run ImageMagick, and what it may do. Build it with `config` and the
 * `with*` functions; each returns a changed copy.
 *
 * @field binary {string} the ImageMagick 7 program, `magick` or a full path
 * @field formats {list of string} the coders files may be read and written
 *   with, e.g. `PNG`, `JPEG`; see `defaultFormats`
 * @field memory {string} memory ImageMagick may use for pixels, e.g. `256MiB`
 * @field disk {string} disk it may use for pixel caches, e.g. `1GiB`
 * @field area {string} the largest image, in pixels, e.g. `128MP`
 * @field side {string} the widest or tallest image, e.g. `16KP`
 * @field timeoutMs {int} how long one command may run before it is killed
 */
export def struct Config {
    binary as string,
    formats as list of string,
    memory as string,
    disk as string,
    area as string,
    side as string,
    timeoutMs as int
};

/**
 * Raise a deck error.
 *
 * @param message {string} what went wrong
 * @throws {Error} always, with `kind` `"magick"`
 */
func fail(message as string) {
    throw Error{kind: ERROR_KIND, message: "magick: " + $message};
}

/**
 * The coders allowed by default: raster formats with self-contained
 * decoders. SVG, PDF, PostScript, EPS and the script formats (MVG, MSL) are
 * left out: they run external programs or read other files.
 *
 * @return {list of string} the coder names
 */
export func defaultFormats() {
    return [
        "PNG",
        "JPEG",
        "GIF",
        "WEBP",
        "TIFF",
        "BMP",
        "HEIC",
        "AVIF",
        "JXL",
        "ICO",
        "PPM",
        "PGM",
        "PBM",
        "PNM",
        "TGA",
        "QOI"
    ];
}

/**
 * The default configuration: `magick` from the `PATH`, the default formats,
 * 256 MiB of memory, 1 GiB of disk, images up to 128 megapixels and 16,000
 * pixels a side, one minute per command.
 *
 * @return {Config} the configuration
 */
export func config() {
    return Config{
        binary: "magick",
        formats: defaultFormats(),
        memory: "256MiB",
        disk: "1GiB",
        area: "128MP",
        side: "16KP",
        timeoutMs: 60000
    };
}

/**
 * Use another ImageMagick program, e.g. `/opt/im7/bin/magick`.
 *
 * @param c {Config} the configuration
 * @param binary {string} the program
 * @return {Config} the changed copy
 * @throws {Error} kind `"magick"` when the name is empty or starts with `-`
 */
export func withBinary(c as Config, binary as string) {
    if (strings.trim($binary) == "" or strings.startsWith($binary, "-")) {
        fail("the binary is a program name or path, got \"" + $binary + "\"");
    }
    $c.binary = $binary;
    return $c;
}

/**
 * Replace the allowed formats.
 *
 * @param c {Config} the configuration
 * @param formats {list of string} coder names, any case
 * @return {Config} the changed copy
 * @throws {Error} kind `"magick"` when a name is not a coder name
 */
export func withFormats(c as Config, formats as list of string) {
    def out as list of string init [];
    for (def f in $formats) {
        $out[] = coderName($f);
    }
    $c.formats = $out;
    return $c;
}

/**
 * Allow one more format, e.g. `SVG` for trusted files only.
 *
 * @param c {Config} the configuration
 * @param format {string} the coder name, any case
 * @return {Config} the changed copy
 * @throws {Error} kind `"magick"` when it is not a coder name
 */
export func allowFormat(c as Config, format as string) {
    def name as string init coderName($format);
    if (lists.contains($c.formats, $name)) {
        return $c;
    }
    def formats as list of string init $c.formats;
    $formats[] = $name;
    $c.formats = $formats;
    return $c;
}

/**
 * Set the resource limits ImageMagick enforces on every command.
 *
 * @param c {Config} the configuration
 * @param memory {string} pixel memory, e.g. `512MiB`
 * @param disk {string} pixel-cache disk, e.g. `2GiB`
 * @param area {string} the most pixels in one image, e.g. `64MP`
 * @param side {string} the widest or tallest image, e.g. `8KP`
 * @return {Config} the changed copy
 * @throws {Error} kind `"magick"` when a value is not an ImageMagick size
 */
export func withLimits(
    c as Config,
    memory as string,
    disk as string,
    area as string,
    side as string) {
    for (def v in [$memory, $disk, $area, $side]) {
        if (not regex.matches(
            "^[0-9]+(\\.[0-9]+)?(B|KiB|MiB|GiB|TiB|KB|MB|GB|TB|KP|MP|GP|P)?$",
            $v)) {
            fail("a limit is a number with a unit such as 256MiB or 64MP, got \"" + $v + "\"");
        }
    }
    $c.memory = $memory;
    $c.disk = $disk;
    $c.area = $area;
    $c.side = $side;
    return $c;
}

/**
 * Set how long one command may run.
 *
 * @param c {Config} the configuration
 * @param ms {int} milliseconds, at least 1000
 * @return {Config} the changed copy
 * @throws {Error} kind `"magick"` below one second
 */
export func withTimeout(c as Config, ms as int) {
    if ($ms < 1000) {
        fail("the timeout is at least 1000 ms");
    }
    $c.timeoutMs = $ms;
    return $c;
}

/**
 * A coder name, checked and in upper case.
 *
 * @param format {string} the name
 * @return {string} the name in upper case
 */
func coderName(format as string) {
    if (len($format) < 2 or len($format) > 16 or
        not regex.matches("^[A-Za-z][A-Za-z0-9]+$", $format)) {
        fail("a format is a coder name such as PNG, got \"" + $format + "\"");
    }
    return strings.upper($format);
}

/**
 * The coder for a file name's extension.
 *
 * @param path {string} the file name
 * @return {string} the coder name; "" for an unknown extension
 */
func coderFor(path as string) {
    def dot as int init strings.lastIndexOf($path, ".");
    def slash as int init strings.lastIndexOf($path, "/");
    if ($dot < 0 or $dot < $slash) {
        return "";
    }
    def ext as string init strings.lower(strings.substring($path, $dot + 1));
    def coders as map of string to string init {
        "png": "PNG",
        "jpg": "JPEG",
        "jpeg": "JPEG",
        "jpe": "JPEG",
        "gif": "GIF",
        "webp": "WEBP",
        "tif": "TIFF",
        "tiff": "TIFF",
        "bmp": "BMP",
        "heic": "HEIC",
        "heif": "HEIC",
        "avif": "AVIF",
        "jxl": "JXL",
        "ico": "ICO",
        "ppm": "PPM",
        "pgm": "PGM",
        "pbm": "PBM",
        "pnm": "PNM",
        "tga": "TGA",
        "qoi": "QOI",
        "svg": "SVG",
        "pdf": "PDF",
        "ps": "PS",
        "eps": "EPS",
        "psd": "PSD"
    };
    if (maps.has($coders, $ext)) {
        return $coders[$ext];
    }
    return "";
}

/**
 * Refuse a file name ImageMagick would read as something else: an option
 * (`-x`), a file list (`@list`), a pipe (`|cmd`), a home directory (`~`), a
 * coder or URL prefix (`msl:`, `https://`), a frame or size suffix
 * (`a.png[0]`), a glob (`*`, `?`, `[`, a brace), a `%` escape, or control
 * characters.
 *
 * @param path {string} the file name
 * @throws {Error} kind `"magick"` naming the problem
 */
func checkPath(path as string) {
    if ($path == "") {
        fail("the file name is empty");
    }
    for (def lead in ["-", "@", "|", "~"]) {
        if (strings.startsWith($path, $lead)) {
            fail("a file name may not start with " + $lead + ": " + $path);
        }
    }
    if (strings.contains($path, "%")) {
        fail("a file name may not hold %, which ImageMagick expands: " + $path);
    }
    for (def glob in ["*", "?", "[", "]", convert.fromCodepoint(123)]) {
        if (strings.contains($path, $glob)) {
            fail("a file name may not hold " + $glob +
                ", which ImageMagick reads as a glob, frame or size: " + $path);
        }
    }
    if (regex.matches("^[A-Za-z][A-Za-z0-9+.-]+:", $path)) {
        fail("a file name may not start with a coder or URL prefix: " + $path);
    }
    if (regex.matches("[\\x00-\\x1f\\x7f]", $path)) {
        fail("a file name may not hold control characters");
    }
}

/**
 * A file name with its coder pinned, `PNG:photo.png`, so ImageMagick never
 * guesses the format from the content.
 *
 * @param c {Config} the configuration
 * @param path {string} the file name
 * @param format {string} the coder; "" to take it from the extension
 * @return {string} the argument for ImageMagick
 * @throws {Error} kind `"magick"` for a refused name, an unknown extension or
 *   a format the configuration does not allow
 */
func pinned(c as Config, path as string, format as string) {
    checkPath($path);
    def coder as string init "";
    if ($format != "") {
        $coder = coderName($format);
    } else {
        $coder = coderFor($path);
        if ($coder == "") {
            fail("cannot tell the format of " + $path + "; name it");
        }
    }
    return checkedCoder($c, $coder) + ":" + $path;
}

/**
 * A coder the configuration allows.
 *
 * @param c {Config} the configuration
 * @param coder {string} the coder name, upper case
 * @return {string} the coder name
 * @throws {Error} kind `"magick"` when it is not allowed
 */
func checkedCoder(c as Config, coder as string) {
    if (not lists.contains($c.formats, $coder)) {
        fail("the format " + $coder + " is not allowed; allowFormat enables it");
    }
    return $coder;
}

/**
 * The `-limit` options every command starts with.
 *
 * @param c {Config} the configuration
 * @return {list of string} the arguments
 */
func limitArgs(c as Config) {
    def seconds as int init ($c.timeoutMs + 999) // 1000;
    return [
        "-limit",
        "memory",
        $c.memory,
        "-limit",
        "map",
        $c.memory,
        "-limit",
        "disk",
        $c.disk,
        "-limit",
        "area",
        $c.area,
        "-limit",
        "width",
        $c.side,
        "-limit",
        "height",
        $c.side,
        "-limit",
        "time",
        convert.toString($seconds)
    ];
}

/**
 * The full command line.
 *
 * @param c {Config} the configuration
 * @param tool {string} `identify`, `compare`, `montage`, or "" for the main tool
 * @param args {list of string} the arguments after the limits
 * @return {list of string} the argument vector
 */
func commandLine(c as Config, tool as string, args as list of string) {
    def argv as list of string init [$c.binary];
    if ($tool != "") {
        $argv[] = $tool;
    }
    return lists.concat(lists.concat($argv, limitArgs($c)), $args);
}

/**
 * Run ImageMagick and wait for it, killing it after `timeoutMs`. The poll
 * interval grows from 1 ms to 32 ms: short commands return quickly, long
 * ones wake the interpreter rarely.
 *
 * @param c {Config} the configuration
 * @param argv {list of string} the command line
 * @param what {string} the operation, for error messages
 * @return {os.Result} the exit code and output
 * @throws {Error} kind `"magick"` when the program cannot start or runs too long
 */
func execute(c as Config, argv as list of string, what as string) {
    def p as os.Process init start($c, $argv);
    def started as time.Time init time.now();
    def pause as int init 1;
    while (not os.poll($p)) {
        if (time.milliseconds(time.sub(time.now(), $started)) > $c.timeoutMs) {
            os.kill($p);
            os.wait($p);
            os.release($p);
            fail($what + ": killed after " + convert.toString($c.timeoutMs) + " ms");
        }
        time.sleep(time.fromMilliseconds($pause));
        if ($pause < 20) {
            $pause = $pause * 2;
        }
    }
    def r as os.Result init os.wait($p);
    os.release($p);
    return $r;
}

/**
 * Start ImageMagick.
 *
 * @param c {Config} the configuration
 * @param argv {list of string} the command line
 * @return {os.Process} the running process
 * @throws {Error} kind `"magick"` when the program cannot start
 */
func start(c as Config, argv as list of string) {
    try {
        return os.spawn($argv);
    } catch (e) {
        fail("cannot run " + $c.binary + " (is ImageMagick 7 installed?): " + $e.message);
    }
}

/**
 * Check a finished command.
 *
 * @param r {os.Result} the result
 * @param what {string} the operation, for the error message
 * @return {os.Result} the result, when the exit code is 0
 * @throws {Error} kind `"magick"` with ImageMagick's first error line otherwise
 */
func checked(r as os.Result, what as string) {
    if ($r.exitCode != 0) {
        fail($what + ": " + firstError($r.stderr));
    }
    return $r;
}

/**
 * The line of ImageMagick's error output that explains a failure.
 *
 * @param stderr {string} the error output
 * @return {string} the first line that is not a warning, else the first line
 */
func firstError(stderr as string) {
    def first as string init "";
    for (def line in strings.split($stderr, "\n")) {
        def t as string init strings.trim($line);
        if ($t == "") {
            continue;
        }
        if ($first == "") {
            $first = $t;
        }
        if (not strings.contains($t, "warning/")) {
            return $t;
        }
    }
    if ($first == "") {
        return "failed without a message";
    }
    return $first;
}
