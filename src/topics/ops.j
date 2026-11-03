# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# magick - the image builder: open a file or bytes, chain operations, write
# the result. Every chain runs as one `magick` command. Spliced into magick.j
# via include.

/**
 * An image and the operations to apply to it. Nothing runs until `write` or
 * `encode`; each operation returns a changed copy.
 *
 * @field input {string} the pinned input, `PNG:photo.png`, or `PNG:-` for
 *   bytes; `[0]` follows after `firstFrame`
 * @field data {bytes} the image bytes, when it was opened from bytes; they
 *   reach ImageMagick through a temporary file
 * @field fromBytes {bool} whether `data` is the input
 * @field ops {list of string} the ImageMagick arguments for the operations
 */
export def struct Image {
    input as string,
    data as bytes,
    fromBytes as bool,
    ops as list of string
};

/**
 * Open an image file. The format comes from the extension and must be
 * allowed by the configuration.
 *
 * @param c {Config} the configuration
 * @param path {string} the file
 * @return {Image} the image, no operations yet
 * @throws {Error} kind `"magick"` for a refused name or format
 */
export func open(c as Config, path as string) {
    return openAs($c, $path, "");
}

/**
 * Open an image file in a named format, whatever its extension.
 *
 * @param c {Config} the configuration
 * @param path {string} the file
 * @param format {string} the coder, e.g. `JPEG`; "" for the extension's
 * @return {Image} the image
 * @throws {Error} kind `"magick"` for a refused name or format
 */
export func openAs(c as Config, path as string, format as string) {
    def img as Image;
    $img.input = pinned($c, $path, $format);
    return $img;
}

/**
 * Open an image held in memory, e.g. an upload or a download.
 *
 * @param c {Config} the configuration
 * @param data {bytes} the encoded image
 * @param format {string} its coder, e.g. `PNG`; it is never guessed
 * @return {Image} the image
 * @throws {Error} kind `"magick"` for an empty image or a refused format
 */
export func fromBytes(c as Config, data as bytes, format as string) {
    if (len($data) == 0) {
        fail("the image is empty");
    }
    def img as Image;
    $img.input = checkedCoder($c, coderName($format)) + ":-";
    $img.data = $data;
    $img.fromBytes = true;
    return $img;
}

/**
 * Add arguments to an image's operations.
 *
 * @param img {Image} the image
 * @param args {list of string} the arguments
 * @return {Image} the changed copy
 */
func addOps(img as Image, args as list of string) {
    $img.ops = lists.concat($img.ops, $args);
    return $img;
}

/**
 * An ImageMagick geometry for a box: `800x600`, `800` or `x600`.
 *
 * @param width {int} the width; 0 to leave it to the aspect ratio
 * @param height {int} the height; 0 to leave it to the aspect ratio
 * @return {string} the geometry
 */
func box(width as int, height as int) {
    if ($width < 0 or $height < 0 or ($width == 0 and $height == 0)) {
        fail("a size needs a positive width or height");
    }
    if ($height == 0) {
        return convert.toString($width);
    }
    if ($width == 0) {
        return "x" + convert.toString($height);
    }
    return convert.toString($width) + "x" + convert.toString($height);
}

/**
 * Check a colour: a name, `#rgb` to `#rrrrggggbbbbaaaa`, or `rgb(...)`,
 * `rgba(...)`, `hsl(...)`, `gray(...)`.
 *
 * @param color {string} the colour
 * @return {string} the colour
 */
func checkColor(color as string) {
    def pattern as string init "^(#[0-9A-Fa-f]+|[A-Za-z]+[0-9]*|(rgb|rgba|srgb|srgba|hsl|hsla|gray|graya|cmyk)\\([0-9., %]+\\))$";
    def hex as bool init strings.startsWith($color, "#");
    if (not regex.matches($pattern, $color) or ($hex and (len($color) < 4 or len($color) > 17))) {
        fail("not a colour: \"" + $color + "\"");
    }
    return $color;
}

/**
 * Check a gravity.
 *
 * @param gravity {string} the gravity
 * @return {string} the gravity
 */
func checkGravity(gravity as string) {
    def all as list of string init [
        "NorthWest",
        "North",
        "NorthEast",
        "West",
        "Center",
        "East",
        "SouthWest",
        "South",
        "SouthEast"
    ];
    if (not lists.contains($all, $gravity)) {
        fail("a gravity is one of " + strings.join($all, ", ") + "; got \"" + $gravity + "\"");
    }
    return $gravity;
}

/**
 * An offset `+x+y` or `-x-y`.
 *
 * @param x {int} the horizontal offset
 * @param y {int} the vertical offset
 * @return {string} the geometry
 */
func offset(x as int, y as int) {
    def sx as string init "+" + convert.toString($x);
    if ($x < 0) {
        $sx = convert.toString($x);
    }
    def sy as string init "+" + convert.toString($y);
    if ($y < 0) {
        $sy = convert.toString($y);
    }
    return $sx + $sy;
}

/**
 * A float as ImageMagick reads it.
 *
 * @param x {float} the number
 * @return {string} the number
 */
func decimal(x as float) {
    return convert.toString($x);
}

/**
 * Resize to fit in a box, keeping the aspect ratio. Only shrinks with
 * `shrinkOnly`.
 *
 * @param img {Image} the image
 * @param width {int} the box width; 0 for any
 * @param height {int} the box height; 0 for any
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` when both sides are 0 or one is negative
 */
export func resize(img as Image, width as int, height as int) {
    return addOps($img, ["-resize", box($width, $height)]);
}

/**
 * Resize to fit in a box, but never enlarge.
 *
 * @param img {Image} the image
 * @param width {int} the box width; 0 for any
 * @param height {int} the box height; 0 for any
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` when both sides are 0 or one is negative
 */
export func shrinkOnly(img as Image, width as int, height as int) {
    return addOps($img, ["-resize", box($width, $height) + ">"]);
}

/**
 * Resize to exactly this size, distorting the aspect ratio if needed.
 *
 * @param img {Image} the image
 * @param width {int} the width
 * @param height {int} the height
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` unless both are positive
 */
export func resizeExact(img as Image, width as int, height as int) {
    if ($width <= 0 or $height <= 0) {
        fail("resizeExact needs a positive width and height");
    }
    return addOps($img, ["-resize", box($width, $height) + "!"]);
}

/**
 * Make a thumbnail: resize to fit and drop the metadata and colour profile.
 *
 * @param img {Image} the image
 * @param width {int} the box width; 0 for any
 * @param height {int} the box height; 0 for any
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` when both sides are 0 or one is negative
 */
export func thumbnail(img as Image, width as int, height as int) {
    return addOps($img, ["-thumbnail", box($width, $height)]);
}

/**
 * Fill a box exactly: resize to cover it, then cut the overflow around the
 * centre.
 *
 * @param img {Image} the image
 * @param width {int} the width
 * @param height {int} the height
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` unless both are positive
 */
export func cover(img as Image, width as int, height as int) {
    if ($width <= 0 or $height <= 0) {
        fail("cover needs a positive width and height");
    }
    def size as string init box($width, $height);
    return addOps(
        $img,
        ["-resize", $size + "^", "-gravity", "Center", "-extent", $size, "+repage"]);
}

/**
 * Cut out a rectangle.
 *
 * @param img {Image} the image
 * @param x {int} its left edge
 * @param y {int} its top edge
 * @param width {int} its width
 * @param height {int} its height
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for a negative position or an empty size
 */
export func crop(img as Image, x as int, y as int, width as int, height as int) {
    if ($x < 0 or $y < 0 or $width <= 0 or $height <= 0) {
        fail("crop needs a position of at least 0 and a positive size");
    }
    return addOps($img, ["+gravity", "-crop", box($width, $height) + offset($x, $y), "+repage"]);
}

/**
 * Rotate clockwise; the corners are filled with the background colour.
 *
 * @param img {Image} the image
 * @param degrees {float} the angle
 * @return {Image} the changed copy
 */
export func rotate(img as Image, degrees as float) {
    return addOps($img, ["-rotate", decimal($degrees)]);
}

/**
 * Read only the first frame of an animation or a multi-page file. The other
 * frames are never decoded, and formats that hold one frame (PNG, JPEG) can
 * then be written without splitting the result into numbered files.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func firstFrame(img as Image) {
    if (not strings.endsWith($img.input, "[0]")) {
        $img.input = $img.input + "[0]";
    }
    return $img;
}

/**
 * Turn the image upright as its EXIF orientation says, as a camera meant it.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func autoOrient(img as Image) {
    return addOps($img, ["-auto-orient"]);
}

/**
 * Mirror top to bottom.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func flip(img as Image) {
    return addOps($img, ["-flip"]);
}

/**
 * Mirror left to right.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func flop(img as Image) {
    return addOps($img, ["-flop"]);
}

/**
 * Convert to shades of grey.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func grayscale(img as Image) {
    return addOps($img, ["-colorspace", "Gray"]);
}

/**
 * Remove metadata: EXIF (with any GPS position), comments, profiles.
 *
 * @param img {Image} the image
 * @return {Image} the changed copy
 */
export func strip(img as Image) {
    return addOps($img, ["-strip"]);
}

/**
 * Set the quality of a lossy output format (JPEG, WebP, AVIF ...).
 *
 * @param img {Image} the image
 * @param quality {int} 1 to 100
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` outside 1 to 100
 */
export func quality(img as Image, quality as int) {
    if ($quality < 1 or $quality > 100) {
        fail("quality is 1 to 100");
    }
    return addOps($img, ["-quality", convert.toString($quality)]);
}

/**
 * Blur with a Gaussian.
 *
 * @param img {Image} the image
 * @param sigma {float} its strength in pixels, above 0 and at most 100
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for a sigma outside that range
 */
export func blur(img as Image, sigma as float) {
    if ($sigma <= 0.0 or $sigma > 100.0) {
        fail("blur needs a sigma above 0 and at most 100");
    }
    return addOps($img, ["-blur", "0x" + decimal($sigma)]);
}

/**
 * Sharpen. Its cost grows with the square of the sigma, hence the low cap.
 *
 * @param img {Image} the image
 * @param sigma {float} its strength in pixels, above 0 and at most 10
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for a sigma outside that range
 */
export func sharpen(img as Image, sigma as float) {
    if ($sigma <= 0.0 or $sigma > 10.0) {
        fail("sharpen needs a sigma above 0 and at most 10");
    }
    return addOps($img, ["-sharpen", "0x" + decimal($sigma)]);
}

/**
 * Add a border around the image.
 *
 * @param img {Image} the image
 * @param pixels {int} its width
 * @param fill {string} its colour, e.g. `white` or `#202020`
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for a negative width or a bad colour
 */
export func border(img as Image, pixels as int, fill as string) {
    if ($pixels < 0) {
        fail("a border is at least 0 pixels");
    }
    return addOps($img, ["-bordercolor", checkColor($fill), "-border", convert.toString($pixels)]);
}

/**
 * Place the image in the centre of a canvas of this size, filling the rest.
 *
 * @param img {Image} the image
 * @param width {int} the canvas width
 * @param height {int} the canvas height
 * @param fill {string} the canvas colour, e.g. `white` or `none`
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for an empty size or a bad colour
 */
export func pad(img as Image, width as int, height as int, fill as string) {
    if ($width <= 0 or $height <= 0) {
        fail("pad needs a positive width and height");
    }
    return addOps(
        $img,
        ["-background", checkColor($fill), "-gravity", "Center", "-extent", box($width, $height)]);
}

/**
 * Write text on the image. The text is literal: ImageMagick's `%` escapes are
 * doubled, and a leading `@`, which would read a file, is refused.
 *
 * @param img {Image} the image
 * @param text {string} the text; `\n` breaks lines
 * @param where {string} the gravity, e.g. `SouthEast`
 * @param x {int} the offset from that edge
 * @param y {int} the offset from that edge
 * @param size {int} the font size in points
 * @param fill {string} the text colour
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` for empty text, a leading `@`, a bad gravity,
 *   size or colour
 */
export func annotate(
    img as Image,
    text as string,
    where as string,
    x as int,
    y as int,
    size as int,
    fill as string) {
    if ($size <= 0) {
        fail("a font size is positive");
    }
    def args as list of string init [
        "-gravity",
        checkGravity($where),
        "-pointsize",
        convert.toString($size)
    ];
    $args = lists.concat(
        $args,
        ["-fill", checkColor($fill), "-annotate", offset($x, $y), literalText($text)]);
    return addOps($img, $args);
}

/**
 * Text ImageMagick takes literally.
 *
 * @param text {string} the text
 * @return {string} the text with `%` doubled
 * @throws {Error} kind `"magick"` for empty text or a leading `@`
 */
func literalText(text as string) {
    if ($text == "") {
        fail("the text is empty");
    }
    if (strings.startsWith($text, "@")) {
        fail("text may not start with @, which makes ImageMagick read a file");
    }
    return strings.replace($text, "%", "%%");
}

/**
 * Lay another image over this one, e.g. a watermark. Its own operations run
 * on it first, and their settings (gravity, colours) stay with it.
 *
 * @param img {Image} the image
 * @param over {Image} the image to lay on top, from a file
 * @param where {string} the gravity, e.g. `SouthEast`
 * @param x {int} the offset from that edge
 * @param y {int} the offset from that edge
 * @return {Image} the changed copy
 * @throws {Error} kind `"magick"` when `over` came from bytes or for a bad gravity
 */
export func overlay(img as Image, over as Image, where as string, x as int, y as int) {
    if ($over.fromBytes) {
        fail("an overlay comes from a file; only the base image can come from bytes");
    }
    def args as list of string init lists.concat(
        lists.concat(["-respect-parentheses", "(", $over.input], $over.ops),
        [")"]);
    $args = lists.concat(
        $args,
        ["-gravity", checkGravity($where), "-geometry", offset($x, $y), "-composite"]);
    return addOps($img, $args);
}

/**
 * The arguments that read the image and apply its operations.
 *
 * @param img {Image} the image
 * @return {list of string} the arguments
 */
func readArgs(img as Image) {
    return lists.concat([$img.input], $img.ops);
}

/**
 * Run the operations and write the result. The format comes from the
 * extension. An image with several frames, written in a format that holds
 * one, becomes numbered files (`out-0.png`, `out-1.png` ...); `firstFrame`
 * avoids that.
 *
 * @param c {Config} the configuration
 * @param img {Image} the image
 * @param path {string} the output file
 * @return {null} nothing
 * @throws {Error} kind `"magick"` for a refused name or format, or when
 *   ImageMagick fails
 */
export func write(c as Config, img as Image, path as string) {
    return writeAs($c, $img, $path, "");
}

/**
 * Run the operations and write the result in a named format.
 *
 * @param c {Config} the configuration
 * @param img {Image} the image
 * @param path {string} the output file
 * @param format {string} the coder; "" for the extension's
 * @return {null} nothing
 * @throws {Error} kind `"magick"` as `write`
 */
export func writeAs(c as Config, img as Image, path as string, format as string) {
    def out as string init pinned($c, $path, $format);
    runOn($c, $img, "", lists.concat(readArgs($img), [$out]), "write " + $path);
    return null;
}

/**
 * Run a command that reads an image. An image from bytes is written to a
 * temporary file first, removed afterwards, so the timeout covers it too.
 *
 * @param c {Config} the configuration
 * @param img {Image} the image
 * @param tool {string} as `commandLine`
 * @param args {list of string} the arguments, holding `img.input` once
 * @param what {string} the operation, for error messages
 * @return {os.Result} the result
 * @throws {Error} kind `"magick"` when ImageMagick fails or runs too long
 */
func runOn(c as Config, img as Image, tool as string, args as list of string, what as string) {
    if (not $img.fromBytes) {
        return checked(execute($c, commandLine($c, $tool, $args), $what), $what);
    }
    def tmp as string init fs.makeTempFile(os.tempDir(), "jennifer-magick-", ".in");
    def r as os.Result;
    try {
        checkPath($tmp);
        fs.writeBytes($tmp, $img.data);
        $r = checked(
            execute($c, commandLine($c, $tool, swapInput($args, $img.input, $tmp)), $what),
            $what);
    } catch (e) {
        fs.remove($tmp);
        throw $e;
    }
    fs.remove($tmp);
    return $r;
}

/**
 * Point the `CODER:-` argument at a file.
 *
 * @param args {list of string} the arguments
 * @param input {string} the bytes input, `PNG:-` or `PNG:-[0]`
 * @param path {string} the file holding the bytes
 * @return {list of string} the arguments with the first `input` replaced
 */
func swapInput(args as list of string, input as string, path as string) {
    def out as list of string init [];
    def done as bool init false;
    for (def a in $args) {
        if (not $done and $a == $input) {
            $out[] = strings.replace($input, ":-", ":" + $path);
            $done = true;
        } else {
            $out[] = $a;
        }
    }
    return $out;
}

/**
 * Run the operations and return the result as bytes, e.g. for an HTTP
 * response. It passes through a private temporary directory, removed
 * afterwards.
 *
 * @param c {Config} the configuration
 * @param img {Image} the image
 * @param format {string} the output coder, e.g. `WEBP`
 * @return {bytes} the encoded image
 * @throws {Error} kind `"magick"` for a refused format, when ImageMagick
 *   fails, or when the image has several frames and the format holds one
 *   (`firstFrame` keeps one)
 */
export func encode(c as Config, img as Image, format as string) {
    def coder as string init checkedCoder($c, coderName($format));
    def dir as string init fs.makeTempDir(os.tempDir(), "jennifer-magick-");
    def data as bytes;
    try {
        writeAs($c, $img, $dir + "/out.img", $coder);
        if (not fs.exists($dir + "/out.img")) {
            fail("the image has several frames and " + $coder + " holds one; use firstFrame");
        }
        $data = fs.readBytes($dir + "/out.img");
    } catch (e) {
        clearDir($dir);
        throw $e;
    }
    clearDir($dir);
    return $data;
}

/**
 * Remove a temporary directory of `encode`'s and the files in it.
 *
 * @param dir {string} the directory
 */
func clearDir(dir as string) {
    for (def name in fs.list($dir)) {
        fs.remove($dir + "/" + $name);
    }
    fs.remove($dir);
}
