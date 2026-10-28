# scalebar

`scalebar` generates LaTeX overlays that place scale bars or indexed grids on
microscope images. It reads JEOL JSM-7001F metadata from a sidecar file, or accepts
an explicit field width or magnification. The original image is never modified.
The command is `image-scalebar`; its output is a `.tex` fragment beside the image.

## Compatibility and dependencies

The gem allows installation on **Ruby >= 2.6.0**. The maintenance CI targets
**Ruby 2.6.10 and Ruby 4.0.7**; local checks of the 1.1.2 compatibility correction
passed on macOS Ruby 2.6.10 and Ruby 4.0.9. Ruby 2.6.0 itself has not been tested.
The installation requirement is distinct from the versions used for testing.
Ruby 2.6 is end-of-life; compatibility is retained for existing installations.

Runtime dependencies are `optimist` (~> 3.0) and `dimensions` (~> 1.3).
The verified versions are Optimist 3.2.1 and Dimensions 1.3.0. Both are pure Ruby.
Development also uses RSpec 3.13 and Rake. Use Bundler 2.4.22 with Ruby 2.6,
and Bundler 4.0.20 with Ruby 4.0.7. The gem contains only runtime Ruby files,
the executable, this README, and the license; development files are excluded.

Generating `.tex` files does not require a TeX installation. Rendering them does:
the output uses `overpic`, color, `pict2e`, URL commands, and the existing
`\sublabel` / `\subref` macros, which the containing document must provide.
It is not a standalone LaTeX document. PDF compilation has not been verified.

## Download a verified GitHub Release

Distribution is through the public [GitHub Releases](https://github.com/misasa/scalebar/releases)
for `misasa/scalebar`. This project does not publish to RubyGems.org.
Until the first Release is published, the download script exits with a clear
error; it does not fall back to an unverified source build.

From this checkout, use the script on macOS or Jenkins with Bash, curl and
`shasum` available. No `gh` login, GitHub token, Ruby, or gem installation is
needed to download. The default selects GitHub's latest stable Release; drafts
and prereleases are not selected.

```sh
# Download only, into a new directory of your choice.
bash script/download_release.sh --output-dir ./downloads

# Pin a stable version (an optional v prefix is accepted).
bash script/download_release.sh --version 1.1.1 --output-dir ./downloads-1.1.1
```

The script downloads `scalebar-VERSION.gem` and
`scalebar-VERSION.gem.sha256`, checks the SHA-256 and manifest filename, then
saves the verified files. It refuses existing files, including symlinks; use a
fresh output directory when repeating a download. All failures return a nonzero
exit status. Files are fetched from URLs of this form:

```text
https://github.com/misasa/scalebar/releases/download/vVERSION/scalebar-VERSION.gem
https://github.com/misasa/scalebar/releases/download/vVERSION/scalebar-VERSION.gem.sha256
```

For optional copying to the university Web server, set the destination in the
environment and explicitly supply `--deploy`:

```sh
export SCALEBAR_DEPLOY_DEST='user@server.example.edu:/absolute/web/path'
bash script/download_release.sh --version 1.1.1 --output-dir ./transfer-1.1.1 --deploy
```

Replace the example destination with the real server. The parent directory must
already exist. SSH authentication and a known host key must already be set up
for noninteractive `ssh` and `scp`. A simple `user@host:/absolute/path` is
supported (no spaces, shell syntax, IPv6 literals, or custom port syntax; use
an SSH config host alias for a custom port). A new `v1.1.1` directory is created
atomically below the destination, and both verified files are copied there.
An existing version directory stops deployment before `scp`; it is never reused.
A failed transfer can leave a partial directory. Inspect and explicitly remove
it before retrying with a fresh local output directory. The script does not
configure the Web server or a gem index.

## Install a downloaded gem on macOS with Homebrew Ruby 4

These commands assume Ruby 4 is already installed at
`/opt/homebrew/opt/ruby/bin/ruby`. They use a dedicated gem directory without
changing system Ruby or shell startup files. Replace the filename with the
version you downloaded and verified above.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  command -v ruby
  ruby -v
  gem install --no-document ./downloads/scalebar-1.1.1.gem
  "$GEM_HOME/bin/image-scalebar" --help
)
```

Runtime dependencies may be fetched from RubyGems.org during installation; the
`scalebar` gem itself comes from the verified Release file. Do not add the former
HTTP gem server to your RubyGems sources. To update, download another Release
into a fresh directory and install its local gem using the same environment.
`gem update scalebar` does not download GitHub Releases. Installing a newer
version retains older versions; reinstalling the same version replaces its
installed files.

To run the installed command later, select the same environment and replace
`--help` with the image path and options below. Check the interpreter again
when Homebrew upgrades Ruby; this gem directory is intended for Ruby 4.0.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  "$GEM_HOME/bin/image-scalebar" --help
)
```

### Uninstall

Use the same dedicated directory. This removes all installed versions of
`scalebar` and its executable
from that directory, while retaining dependency gems and the source checkout.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  gem uninstall scalebar --all --executables
)
```

## Usage

These are independent examples. Use the explicit macOS environment above for a
local installation, or prefix commands with `bundle exec` in a development
checkout. If `sample.tex` already exists, the command reports this and leaves it
unchanged. Rename or remove that output before intentionally regenerating it.

```sh
# Read calibration and stage coordinates from sample.txt beside sample.jpg.
image-scalebar sample.jpg

# Without a sidecar, specify a 60 mm reference field width.
image-scalebar --width=60 sample.jpg

# Alternatively, use JEOL magnification relative to a 120 mm reference.
image-scalebar --magnification=2 sample.jpg

# Add an indexed grid with a 1 mm pitch to a calibrated image.
image-scalebar --width=60 --grid=1 sample.jpg
```

Calibration precedence is: an existing sidecar, then `--magnification`, then
`--width`. Even a sidecar without a usable magnification prevents fallback to
command-line calibration. With no calibration, the program writes an image-only
overlay, without a scale bar or grid. `--grid` does not supply calibration.

Width and grid pitch are in **millimeters**; stage positions in the JEOL sidecar
are also in millimeters. Scale-bar lengths in generated comments are in
**micrometers**. The current scale-bar policy selects the largest power of ten
micrometers that fits the reference field. No physical-unit label is drawn.
Use positive calibration and grid values, valid images, and landscape images
for field-width calibration. Portrait scaling and invalid-input handling have
known limitations documented in [DEVELOPMENT.md](DEVELOPMENT.md).

## Development and verification

Use separate checkouts and dependency directories for Ruby 2.6 and 4.0. A
`Gemfile.lock` generated by Bundler 4 must not be reused with Bundler 2.4.
The lockfile is intentionally ignored for this gem; it is not packaged.

For Ruby 4 on this Mac, run the following from a development checkout. All
PATH changes are confined to the subshell; dependencies go into ignored
`vendor/bundle`, not system Ruby's gem directory.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  command -v ruby
  ruby -v
  export BUNDLE_PATH="$PWD/vendor/bundle"
  bundle install
  bundle exec rspec
  bundle exec rake verify
  gem build scalebar.gemspec --strict --output pkg/scalebar-strict.gem
)
```

`rake verify` runs RSpec, builds the gem, validates its archive, installs it into
a disposable directory, and checks help, six fixture-based LaTeX outputs, and
non-overwrite behavior through the installed executable. It reuses dependency
gem directories populated by Bundler; the package smoke test does not modify
user gems. Use a fresh dependency directory when checking an exact dependency
set: an unbundled CLI can select another compatible version if multiple versions
are present in those directories.
The `.gem` packages are written to the ignored `pkg` directory.

To test system Ruby 2.6 without modifying it, use a separate checkout and an
isolated Bundler installation. Do not upgrade the system RubyGems installation.
The old macOS RubyGems may print a compatibility warning when starting Bundler
2.4; pinning Bundler explicitly avoids selecting an incompatible Bundler.

```sh
(
  set -eu
  export PATH="/usr/bin:/bin:$PATH"
  command -v ruby
  /usr/bin/ruby -v
  ruby2_tools="$(mktemp -d)"
  export GEM_HOME="$ruby2_tools"
  export GEM_PATH="$GEM_HOME"
  /usr/bin/ruby /usr/bin/gem install bundler --version 2.4.22 --no-document
  export BUNDLE_PATH="$PWD/vendor/bundle"
  /usr/bin/ruby "$GEM_HOME/bin/bundle" _2.4.22_ install
  /usr/bin/ruby "$GEM_HOME/bin/bundle" _2.4.22_ exec rake verify
  /usr/bin/ruby /usr/bin/gem build scalebar.gemspec --strict --output pkg/scalebar-strict.gem
)
```

GitHub Actions is configured to run both exact Ruby versions on Ubuntu 24.04
using `actions/checkout@v6` and `ruby/setup-ruby@v1`, with a compatible Bundler and
RubyGems for each Ruby. Ordinary master pushes and PRs run only the tests.
Tag pushes also run the tests, then build and verify the release gem only after
both Ruby jobs succeed.
A local macOS pass does not establish that the hosted workflow has passed;
check the actual Actions run after the branch is pushed with approval.
See [DEVELOPMENT.md](DEVELOPMENT.md) for test rationale, the original test audit,
CI constraints, and deferred behavior issues.

## Publishing a Release (maintainers)

1. Review and merge the changes into `master`, then confirm the actual Actions
   tests pass on Ruby 2.6.10 and 4.0.7. Local tests alone do not verify hosted CI.
2. Choose an unused stable three-part version in `lib/scalebar/version.rb` and
   merge it into master. Check remote tags and Releases, including drafts, for
   both `VERSION` and `vVERSION`. At migration time the existing tags were
   `1.0.5` and `1.1.0`, no public Releases existed, and the source version was
   `1.1.1`; recheck before publishing.
3. Create an annotated `vVERSION` tag on the intended master commit and push
   that tag. For the current source version this would be `v1.1.1`. Creating or
   pushing a tag is an explicit release action; ordinary master pushes and PRs
   never create a Release.
4. Check the tag workflow. Both test jobs must pass. The release job checks tag,
   event commit, master ancestry, gemspec version, archive filename, existing
   tags and Releases, then performs a strict build and isolated installed-CLI
   verification. Only this job receives `contents: write`.
5. The job uploads the gem and its SHA-256 file to a draft, downloads both again
   and verifies their bytes before publishing. It never overwrites an existing
   Release or asset. If upload/verification fails, a draft may remain unpublished;
   inspect it and resolve it explicitly before rerunning. A successful release
   cannot be republished by rerunning its job.
6. Confirm both assets can be downloaded without authentication using
   `script/download_release.sh`. University server copying is a separate,
   explicitly requested `--deploy` operation.

The workflow does not publish to RubyGems.org and does not create tags. Keep the
repository public so Mac and Jenkins downloads can remain unauthenticated.

For the same-version 1.1.2 Ruby requirement correction, see the
[replacement investigation in DEVELOPMENT.md](DEVELOPMENT.md#same-version-112-distribution-investigation).
The ordinary release workflow refuses replacement of existing Releases/assets.
Rebuilding locally does not update a published gem or an existing installation.

## License

GPL-3.0-or-later. See [LICENSE.txt](LICENSE.txt) for the copyright notice and
full GNU General Public License version 3 text.
