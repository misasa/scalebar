#!/bin/bash
# Download a public release without gh, an API token, or a Ruby installation.
set -euo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: download_release.sh [--version VERSION] [--output-dir DIR] [--deploy]
Default: download the latest stable public Release into the current directory.
VERSION: 1.1.1 or v1.1.1 (stable three-part versions only).
--deploy: also scp the verified files into a NEW vVERSION directory under
          SCALEBAR_DEPLOY_DEST=user@host:/absolute/path (SSH access required).
Existing local files or remote version directories are never replaced.
HELP
}

version=
output_dir=.
deploy=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|--output-dir)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$1 requires a value"
      case "$1" in
        --version)
          version=${2#v}
          [ -n "$version" ] || fail 'Expected a stable version such as 1.1.1' ;;
        --output-dir) output_dir=$2 ;;
      esac
      shift 2 ;;
    --deploy) deploy=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1 (see --help)" ;;
  esac
done

stable_version='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
if [ -n "$version" ]; then
  [[ "$version" =~ $stable_version ]] || fail 'Expected a stable version such as 1.1.1'
fi
if "$deploy"; then
  destination=${SCALEBAR_DEPLOY_DEST:-}
  # Restrict remote-shell input to a simple host and absolute path.
  destination_pattern='^[A-Za-z0-9_][A-Za-z0-9_.@-]*:/[A-Za-z0-9_./-]+$'
  [[ "$destination" =~ $destination_pattern ]] ||
    fail 'Set SCALEBAR_DEPLOY_DEST to user@host:/absolute/path (no spaces or shell syntax)'
  host=${destination%%:*}
  remote_root=${destination#*:}
fi

base=https://github.com/misasa/scalebar/releases
fetch() {
  curl --disable --fail --location --silent --show-error \
    --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 300 "$@"
}
if [ -z "$version" ]; then
  latest=$(fetch --output /dev/null --write-out '%{url_effective}' "$base/latest") ||
    fail 'Cannot find a public stable Release. None may exist yet, or GitHub/network access failed.'
  case "$latest" in
    "$base/tag/v"*) version=${latest#"$base/tag/v"} ;;
    *) fail 'No supported public stable Release was found.' ;;
  esac
  [[ "$version" =~ $stable_version ]] || fail 'The latest public Release has an unsupported version.'
fi
filename="scalebar-$version.gem"
checksum="$filename.sha256"
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd -P)
for name in "$filename" "$checksum"; do
  [ ! -e "$output_dir/$name" ] && [ ! -L "$output_dir/$name" ] ||
    fail "Destination already exists: $output_dir/$name"
done
work=$(mktemp -d "$output_dir/.scalebar-download.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for name in "$filename" "$checksum"; do
  fetch --output "$work/$name" "$base/download/v$version/$name" ||
    fail "Cannot download $name from public Release v$version; it may not exist yet."
done
# Comparing the complete manifest also rejects extra entries and unsafe filenames.
actual=$(cd "$work" && shasum -a 256 "$filename")
[ "$(cat "$work/$checksum")" = "$actual" ] || fail 'SHA-256 mismatch or invalid checksum manifest'
# Hard links fail if a file appeared after the existence check; no overwrite flag.
ln "$work/$filename" "$output_dir/$filename"
ln "$work/$checksum" "$output_dir/$checksum"
printf 'Verified: %s\n' "$output_dir/$filename"

if "$deploy"; then
  remote_dir="${remote_root%/}/v$version"
  # Atomic mkdir reserves a new version directory. Do not use mkdir -p here.
  ssh -oBatchMode=yes "$host" "mkdir '$remote_dir'" ||
    fail "Cannot create remote directory (it may already exist): $remote_dir"
  scp -oBatchMode=yes "$output_dir/$filename" "$output_dir/$checksum" "$host:$remote_dir/" ||
    fail "Transfer failed; inspect $remote_dir before retrying."
  printf 'Copied to: %s:%s/\n' "$host" "$remote_dir"
fi
