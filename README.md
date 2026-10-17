# scalebar

`scalebar` generates LaTeX overlays that place scale bars or indexed grids on
microscope images. It reads JEOL JSM-7001F metadata from a sidecar file, or accepts
an explicit field width or magnification. The original image is never modified.
The command is `image-scalebar`; its output is a `.tex` fragment beside the image.

## Compatibility and dependencies

The maintenance checks target **Ruby 2.6.10 and Ruby 4.0.7**. Ruby 2.6 is
end-of-life; compatibility is retained for existing installations. Other Ruby
versions have not been verified. The gem requires Ruby >= 2.6.10.

Runtime dependencies are `optimist` (~> 3.0) and `dimensions` (~> 1.3).
The verified versions are Optimist 3.2.1 and Dimensions 1.3.0. Both are pure Ruby.
Development also uses RSpec 3.13 and Rake. Use Bundler 2.4.22 with Ruby 2.6,
and Bundler 4.0.20 with Ruby 4.0.7. Git is required to build from a checkout,
because the gemspec obtains its file list from Git.

Generating `.tex` files does not require a TeX installation. Rendering them does:
the output uses `overpic`, color, `pict2e`, URL commands, and the existing
`\sublabel` / `\subref` macros, which the containing document must provide.
It is not a standalone LaTeX document. PDF compilation has not been verified.

## Install from GitHub on macOS with Homebrew Ruby 4

These commands assume Ruby 4 is already installed at
`/opt/homebrew/opt/ruby/bin/ruby`. They do not install or upgrade Ruby, edit shell
startup files, or change your global PATH. They use a dedicated gem directory,
separate from system Ruby 2.6 and other Ruby installations. No `sudo` is needed.

The parentheses create a temporary shell environment. Check the printed Ruby
path and version before using the installation. The default checkout location is
`$HOME/src/scalebar`; it must not already exist. If you already have a checkout,
use the rebuild instructions below instead. You can set `SCALEBAR_CHECKOUT` and
`SCALEBAR_GEM_HOME` to choose different directories.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  command -v ruby
  ruby -v
  checkout="${SCALEBAR_CHECKOUT:-$HOME/src/scalebar}"
  mkdir -p "$(dirname "$checkout")"
  git clone https://github.com/misasa/scalebar.git "$checkout"
  cd "$checkout"
  gem build scalebar.gemspec
  version="$(ruby -Ilib -rscalebar/version -e 'puts Scalebar::VERSION')"
  gem install --no-document "./scalebar-$version.gem"
  "$GEM_HOME/bin/image-scalebar" --help
)
```

This installs the source from GitHub's default branch, including its runtime
dependencies. Pending local changes are available there only after they have
been reviewed and merged. This maintenance update prepares version **1.1.1**;
it preserves the existing API and rendering behavior. The installation commands
read the package version from the checkout, so they also work before the update
is merged. Tagging and publication are deferred until after PR merge and a
successful CI run.
Do not add the former HTTP gem server to your RubyGems sources.

To run the installed command later, select the same environment explicitly:

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  "$GEM_HOME/bin/image-scalebar" --help
)
```

Replace `--help` with the image path and options from the examples below. The
executable is outside your default PATH unless you choose to add it yourself.
Homebrew may change its Ruby installation when upgraded: check the interpreter
again and rebuild the dedicated installation when moving to a different Ruby
minor version. This directory is intended for Ruby 4.0.

### Update or reinstall a local installation

`gem update scalebar` does not retrieve source changes from GitHub. To install
new source, update a clean checkout, rebuild the package, and reinstall it using
the same Ruby and gem directory. Reinstalling the same gem version replaces the
installed files. If you have uncommitted changes or use a review branch, inspect
them before updating; omit `git pull` when installing your current local changes.
Installing 1.1.1 alongside 1.1.0 retains the older gem; the executable normally
selects the newest installed version. The uninstall command below removes both.

```sh
(
  set -eu
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
  export GEM_HOME="${SCALEBAR_GEM_HOME:-$HOME/.local/share/scalebar/ruby-4.0}"
  export GEM_PATH="$GEM_HOME"
  cd "${SCALEBAR_CHECKOUT:-$HOME/src/scalebar}"
  git pull --ff-only
  gem build scalebar.gemspec
  version="$(ruby -Ilib -rscalebar/version -e 'puts Scalebar::VERSION')"
  gem install --no-document "./scalebar-$version.gem"
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
RubyGems for each Ruby. The workflow runs `rake verify` and a strict gem build.
A local macOS pass does not establish that the hosted workflow has passed;
check the actual Actions run after the branch is pushed with approval.
See [DEVELOPMENT.md](DEVELOPMENT.md) for test rationale, the original test audit,
CI constraints, and deferred behavior issues.

## License

GPL-3.0-or-later. See [LICENSE.txt](LICENSE.txt), which retains the existing
Okayama University copyright notice and includes the GPL version 3 text.
The CLI retains its existing copyright notice. The gemspec now matches the
GPLv3-or-later license selected in the repository in 2017; this maintenance work
does not introduce a new license choice.
