# Development and regression testing

## Scope and baseline

The maintenance baseline is `192e966` (the merge of PR #2). Before this work,
Ruby 2.6.10 and 4.0.7 each passed 19 examples, gem builds, help, six CLI output
cases and existing-output protection. PDF compilation was not tested.

Changes in this maintenance work are limited to tests, development tooling,
package metadata, CI and English help/documentation. Calculations, option
precedence, scale-bar policy, grid generation and LaTeX rendering are unchanged.
The patch version advances from 1.1.0 to 1.1.1. Tagging and publication wait for
PR merge and successful CI. Do not silently fix behavior while strengthening tests.

On 2026-10-17, the remote Git tags were `1.0.5` and `1.1.0`, and the GitHub
Releases API returned no releases. RubyGems.org returned 404 for the `scalebar`
version-history endpoint, and its search API did not list this gem. No use of
1.1.1 was found in these sources. The former distribution server,
`dream.misasa.okayama-u.ac.jp/rubygems/`, timed out over both HTTP and HTTPS;
its historical distribution records could not be verified. Confirm those
records with the maintainers before publication if they are still available.
The package verification checks that source, archive metadata and installed
code versions agree, and that the installed code loads from the disposable gem
directory.

## Audit of the original 19 examples

The numbers below follow the original file's order. All used a shared relative
`tmp` directory, deleted before every example. That made concurrent processes
unsafe and made the suite depend on its working directory. The global output
collector could retain state between examples. Neither was needed to test the
public behavior. The replacement uses disposable per-example directories and
launches the CLI with the same interpreter as RSpec.

| # | Original example | Basis and ability to detect a regression | Replacement |
|---|---|---|---|
| 1 | Help raises `SystemExit` | Could pass on an error exit; did not inspect help or status | Real CLI, status 0, usage/options present, no files |
| 2 | `length_in_mm == 60` | Sound: JEOL's 120 mm reference at 2x spans 60 mm | Retained in independently derived conversion spec |
| 3 | `length_in_um == 60000` | Sound: 60 mm is 60,000 um | Retained; also checks factor-of-1000 conversions |
| 4 | `pixels_per_um == length / 60000` | Reused a measured value from the same object, so a bad image length could pass | Independent 1914-pixel JPEG and literal 0.0319 pixel/um |
| 5 | Stage position `[57.656, 15.152]` | Sound fixture values in mm; did not check conversion or extent | Retained plus um conversion and signed stage translation |
| 6 | Magnification `7.837` | Sound sidecar value; no precedence coverage | Retained plus sidecar/option precedence |
| 7 | Absolute ticks are not nil | An empty or numerically incorrect result would pass | Exact coordinates, counts and offsets for aligned, unaligned and negative fields |
| 8 | Image-only magnification is nil | Useful observation of the no-calibration path | Retained and paired with actual image-only output |
| 9 | Image-only TeX lacks `Magnification` and `line` | Broad substring `line` could reject harmless prose and did not validate structure | Full timestamp-normalized baseline output |
| 10 | `-m` sets magnification | Sound literal 2, but did not inspect resulting scale | Retained through conversion and generated 10 mm bar checks |
| 11 | `-m` TeX contains a magnification comment and `line` | Broad presence check; wrong numeric bar length would pass | Full baseline plus independent numeric bar-length assertion |
| 12 | `-w` sets `120 / width` | Repeated the implementation formula | Literal magnification 2 for the documented 60 mm field |
| 13 | `-w` TeX contains a magnification comment and `line` | Duplicated #11's weak text check for another input path | Separate CLI path protected by a baseline and shared numeric specification |
| 14 | Existing TeX is unchanged | Sound content assertion; no real CLI/status or mtime check | Real CLI, content and modification time unchanged |
| 15 | Image plus sidecar creates TeX | A blank or broken TeX file would pass | Full metadata baseline output |
| 16 | Grid path calls `generate_tex(1.0)` | Replaced the very renderer that should be verified | Real CLI and full calibrated-grid output |
| 17 | Calibrated grid contains `multiput` | Wrong spacing/count/coordinates would pass | Baseline plus independent square-field spacing/count/label specification |
| 18 | Uncalibrated grid path calls `generate_tex(1.0)` | Mocked away the observable behavior | Real CLI output confirms grid remains absent |
| 19 | Uncalibrated grid creates TeX without `multiput` | Useful current policy, but little structural coverage | Complete baseline image-only output for this option path |

None of the original examples required a fixed timestamp, but timestamp-bearing
output was barely inspected. The snapshots now normalize only date/time strings;
every other output byte remains significant. Numeric comparisons use explicit
small tolerances where floating-point roundoff is expected, not copied results
from another method under test. Old interaction-only tests were removed rather
than retained alongside stronger duplicates.

## Two kinds of tests

- **Specification tests** (`:specification`) derive expected values from the
  calibration convention, image dimensions, physical units or public CLI
  contracts. A failing specification is evidence to investigate, not permission
  to change production behavior within this maintenance task.
- **Characterization tests** (`:characterization`) preserve output and policy
  observed at the baseline, including known limitations. They do not certify
  those policies as scientifically correct. A later intentional behavior change
  must explicitly reconsider the relevant characterization.

The metadata specifications protect the requested packaging contract separately.
There are no product-method mocks. Malformed-input characterizations assert the
observable failure/success boundary without binding to Ruby's stack-trace text.
Optimist's current POSIX error status is 255; the error contract requires a
nonzero exit, not a specific upstream exit number.

## Test inventory and independent expectations

Every example has an English behavior description. The following rationale,
together with nearby comments, states its units, assumptions and regression
purpose. Table-driven rows exercise distinct inputs rather than inflate counts.

| Area / examples | Kind | Independent basis, assumptions and regression caught |
|---|---|---|
| JPEG dimensions, longest edge and normalized size | Specification | Real JPEG header: 1914 x 1537 pixels. Normalizing the longer edge gives 100 x 80.3030303 percent; detects swapped dimensions or incorrect normalization |
| Sidecar magnification, stage coordinates and um conversion | Specification | Fixture: 7.837x, `(57.656, 15.152)` mm = `(57656, 15152)` um; detects missing parsing, axes swapped or factor-of-1000 errors |
| Conflicting sidecar image dimensions | Characterization | Header continues to win over `CM_FULL_SIZE`; records current precedence rather than claiming header/sidecar conflicts are validated |
| 2x calibration, physical length, density and aspect ratio | Specification | A 120 mm JEOL reference at 2x spans 60 mm = 60,000 um. A 1914-pixel width is 31.9 pixel/mm. The 1537-pixel height spans 48,181.8181818 um; detects unit and aspect-ratio errors |
| Explicit width | Specification | A 60 mm field occupies half of the 120 mm reference and therefore has 2x magnification |
| Centered and translated extents | Specification | Centered 60 mm landscape field spans -30,000 to +30,000 um. A `(10, -20)` mm stage translates the origin by `(10000, -20000)` um; detects sign, origin and extent regressions |
| Bar sizing at 9.999, 10, 10.001 and 60 mm | Characterization | Existing decade policy gives 1000, 10000, 10000 and 10000 um; catches floor/round and decade-boundary changes |
| Bar pixel length | Characterization with independent arithmetic | Given the existing 10 mm bar policy, it occupies one sixth of a 60 mm field: 319 of 1914 pixels; catches wrong ratios |
| Portrait normalization and bar | Characterization | A real synthetic 60 x 120 pixel PNG normalizes to 50 x 100 percent. Current calibration gives a 30 mm horizontal extent but a 10-pixel bar; records the known inconsistency |
| Aligned, unaligned and negative tick ranges | Specification | 1000 pixels at 0.1 pixel/um span 10,000 um. A 2000 um pitch is 200 pixels or 20 percentage points. Floating-point ranges reflect the normal CLI pipeline; protects endpoints, outward rounding and offsets |
| 500 um tick pitch | Specification | A 1000 um field is split into two 500 um intervals, giving ticks at 0, 50 and 100 percent; catches pitch/density confusion |
| Direct integer tick inputs | Characterization | Integer division currently drops the outer tick at 12,000 um for `[1000, 11000]`; records the limitation without weakening the floating-point specification |
| Sidecar over options, magnification over width, missing calibration, incomplete sidecar | Characterization | Explicit baseline precedence; detects changed branches or silent new fallback policies |
| Help, missing argument, unknown option, malformed width/magnification/grid | Specification | Help succeeds without writing. Missing/invalid options fail without TeX output; catches accidental success or side effects |
| Options after the image path | Specification | Existing documented command-line parser supports this ordering; catches argument-consumption regressions |
| Existing-output preservation | Specification | User content and a fixed mtime must survive a CLI invocation; catches truncation or touching the file |
| Six complete LaTeX outputs and input preservation | Characterization | Baseline `192e966` outputs, independently captured before modifications: metadata, metadata+grid, manual width, manual magnification, image-only and uncalibrated-grid. Only time strings normalized; catches formatting and numeric drift as well as image/sidecar modification |
| LaTeX bar values and strokes | Specification | A 10 mm bar in 60 mm spans 16.666... percent, formatted as 16.7. Two strokes use 4pt/2pt; catches wrong geometry or missing strokes |
| Square-field LaTeX grid | Specification | Synthetic 100 x 100 pixel PNG spans 10 x 10 mm; 1 mm is 10 pixels / 10 percent. Ticks at -5 through +5 mm give nine interior lines; checks both axes, labels and printed coordinates |
| Missing/corrupt images and nonpositive numeric inputs | Characterization | Calibrated missing/corrupt images, width 0/-1, magnification 0 and pitch 0 fail; uncalibrated missing image currently succeeds. Records boundaries without blessing current diagnostics or partial files |
| Ruby floor, homepage and license | Packaging contract | Admit 2.6.10 and 4.0.7; exclude 2.5.9; identify the actual repository and existing GPL-3.0-or-later license |

The package smoke test (`script/verify_package.rb`) checks the actual archive,
required runtime files, absence of generated/private build files, executable and
license metadata, an isolated installation, help and all six baseline outputs.
It exercises the installed gem from an unrelated directory. It reuses Bundler's
resolved dependencies without downloading or changing user gems. Both RSpec and
the installed-gem checks run under the interpreter selected by the caller.
The smoke test shares dependency directories, rather than locking activation
inside its unbundled subprocesses. Multiple compatible versions in a reused
directory can therefore select a different version than the bundle lock.
Exact-set verification uses fresh directories, as in the documented checks and
CI. More restrictive dependency isolation is a possible later tooling improvement.

## Fixtures and time independence

`spec/fixtures/files` contains the original JPEG and JEOL sidecar.
`spec/fixtures/latex` contains outputs captured from the baseline by the earlier
Ruby 2.6/4.0 investigation. They are characterization fixtures, not physical
oracles. Do not regenerate them merely to make a failing test pass. Confirm an
intentional, separately approved behavior change before updating a snapshot.
A missing timestamp does not pass normalization: the baseline still requires
its surrounding timestamp-bearing text. The fixed existing-file mtime is
independent of the current clock. Every example cleans up only its own temporary
directory. The suite randomizes order to expose shared-state assumptions.

## Dependencies, CI and environment limits

The runtime constraints remain `optimist ~> 3.0` and `dimensions ~> 1.3`.
RubyGems lists 3.2.1 and 1.3.0 as their current releases at the time of this work;
both already passed the two-Ruby baseline, so no speculative upgrade is needed.
Development dependencies have upper bounds; RSpec now requires its verified
3.13 line. Runtime behavior is not changed by these development constraints.

CI uses Ubuntu 24.04 x64 for both exact Ruby versions. The official
[ruby-builder 2.6.10 release](https://github.com/ruby/ruby-builder/releases/tag/ruby-2.6.10)
provides a `ruby-2.6.10-ubuntu-24.04-x64.tar.gz` build. Thus no EOL Ubuntu runner
or EOL container is needed at present. CI pins Bundler 2.4.22 / RubyGems 3.4.22
for Ruby 2.6 and 4.0.20 / 4.0.20 for Ruby 4.0.7. It uses supported
[checkout](https://github.com/actions/checkout) and
[setup-ruby](https://github.com/ruby/setup-ruby) actions.

Prebuilt availability is an external constraint: check the release assets if
setup fails after a runner image change. Do not silently drop Ruby 2.6 or mark
an unexecuted job successful. If a compatible hosted build ceases to exist, a
separately maintained container or a dedicated runner is a possible fallback,
but would require an explicit environment review; neither has been executed
or claimed as verified here. The legacy Dockerfile is not the CI environment
and has not been modernized or validated in this work.

The local macOS system RubyGems 3.0.3.1 prints Bundler's warning about old
`required_ruby_version` handling. Do not modify the system installation to
silence it. Use the explicitly pinned, isolated Bundler described in the README.
The hosted Ruby 2.6 job selects RubyGems 3.4.22 independently of macOS.

## Deferred functional issues (no fixes in this change)

| Issue and evidence | Possible future correction, requiring separate review |
|---|---|
| Portrait images: a 60 x 120 pixel image calibrated to a 60 mm longest edge has a 30 mm horizontal extent, but the current horizontal bar formula uses the 60 mm reference | Define whether `--width` means horizontal width or longest-edge length, then make bar and field geometry use the same interpretation |
| Missing uncalibrated images can produce a successful `.tex` reference because that branch does not inspect dimensions | Validate input existence and image format before opening the output |
| Calibrated missing/corrupt images and invalid ranges can leave partial `.tex` output, which later non-overwrite behavior preserves | Validate before writing and/or write atomically; specify diagnostics and failure statuses |
| Width/magnification <= 0 and grid pitch <= 0 are not rejected at option parsing and can raise arithmetic/domain errors | Define and validate finite positive input ranges before creating output |
| An existing sidecar, even one without `CM_MAG`, prevents fallback to supplied calibration; malformed numeric metadata may become zero via `to_f` | Define metadata validity and precedence explicitly, then add validation or an intentional fallback |
| Direct integer tick arguments truncate before ceiling the upper endpoint | Convert operands before division; retain separate tests for integer and float callers |
| Reversed/degenerate tick ranges and grid labels beyond Z have no well-defined public policy; paths and labels are not fully escaped for LaTeX | Specify those domains before changing generated output |
| Generated output depends on document-specific macros/packages and is not a standalone document | Add a separately reviewed rendering contract and real TeX compilation tests; no PDF success is claimed |

These are existing limitations, not Ruby 4 regressions. The characterization
suite intentionally preserves them where stable and useful; the untested
policies above are not claims of correctness. Unit labels, grid redesign and
functional refactoring remain outside this maintenance change.

## License history

The initial 2015 license was MIT. Commit `9ddad61` by Yusuke Yachi on
2017-05-23 changed LICENSE.txt to GPLv3-or-later and the existing Okayama
University notice. Subsequent CLI help also states GPLv3-or-later. The gemspec's
MIT field was never updated. This change aligns package metadata and English
help with that recorded maintainer choice; it preserves both existing copyright
notices and appends the [official GPLv3 text](https://www.gnu.org/licenses/gpl-3.0.txt)
to LICENSE.txt. It does not change third-party dependencies' licenses.
