# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.27.0

/**
 * White-box tests: jennifer test src/magick_test.j
 *
 * The checks and the argument building are tested everywhere. The tests that
 * run ImageMagick return early where `magick` 7 is not installed (CI's
 * container, jvc's publish gate); `testImageMagickRunsHere` says so.
 */
use encoding;
use testing;

include "topics/core_test.j";
include "topics/ops_test.j";
include "topics/inspect_test.j";
