#!/bin/sh
# Installs a released `sgt`, so a new machine has it in seconds and builds nothing.
#
#   curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | sh
#
# The releases are in a repository of their own that anyone can read, with a copy of this
# file, so nothing here needs a token. A repository named in `SGT_REPO` that is private is
# read with the token in `GH_TOKEN` or `GITHUB_TOKEN`.
#
# What it reads from the environment:
#
#   SGT_VERSION   The release to install, as its tag: `v0.1.0`. Left out, the latest.
#   SGT_INSTALL   The directory `sgt` goes in. Left out, `~/.local/bin`.
#   SGT_FROM      An address that holds the archives, in place of GitHub: a mirror, a
#                 bucket, or `file:///a/directory`. The names under it are a release's.
#   SGT_REPO      The repository that holds the releases, as `owner/name`, when it is
#                 another.
#
# The archive is checked against the hash published beside it before anything is installed.
set -eu

repository="${SGT_REPO:-Braden1996/sergeant-releases}"
version="${SGT_VERSION:-latest}"
into="${SGT_INSTALL:-$HOME/.local/bin}"
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
api="${GITHUB_API_URL:-https://api.github.com}"

fail() {
  echo "install: $*" >&2
  exit 1
}

for program in curl tar sha256sum; do
  command -v "$program" >/dev/null 2>&1 || fail "\`$program\` is needed and was not found"
done

case "$(uname -s) $(uname -m)" in
  "Linux x86_64") target=x86_64-unknown-linux-musl ;;
  "Linux aarch64" | "Linux arm64") target=aarch64-unknown-linux-musl ;;
  MINGW* | MSYS* | CYGWIN*) fail "on Windows, install with PowerShell: irm https://github.com/$repository/releases/latest/download/install.ps1 | iex" ;;
  *) fail "no release is built for $(uname -s) on $(uname -m). Build it from source: cargo build --release -p sgt" ;;
esac
archive="sgt-$target.tar.gz"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The address of a release's file as the API names it, which is the only one a private
# repository answers at. A release lists each file as an object whose `url` comes before
# its `name`.
asset() {
  tr ',' '\n' < "$work/release.json" | tr '{' '\n' | awk -v wanted="$1" '
    /"url": *"[^"]*\/releases\/assets\/[0-9]+"/ { split($0, part, "\""); address = part[4] }
    /"name": *"/ { split($0, part, "\""); if (part[4] == wanted) { print address; exit } }'
}

# Fetches the release's file `$1` into the work directory.
fetch() {
  if [ -n "${SGT_FROM:-}" ]; then
    curl -fsSL -o "$work/$1" "${SGT_FROM%/}/$1"
  elif [ -n "$token" ]; then
    address="$(asset "$1")"
    [ -n "$address" ] || fail "the release $version has no file named $1"
    curl -fsSL -o "$work/$1" -H "Authorization: Bearer $token" \
      -H "Accept: application/octet-stream" "$address"
  elif [ "$version" = latest ]; then
    curl -fsSL -o "$work/$1" "https://github.com/$repository/releases/latest/download/$1"
  else
    curl -fsSL -o "$work/$1" "https://github.com/$repository/releases/download/$version/$1"
  fi
}

if [ -z "${SGT_FROM:-}" ] && [ -n "$token" ]; then
  if [ "$version" = latest ]; then
    listed="$api/repos/$repository/releases/latest"
  else
    listed="$api/repos/$repository/releases/tags/$version"
  fi
  curl -fsSL -o "$work/release.json" -H "Authorization: Bearer $token" \
    -H "Accept: application/vnd.github+json" "$listed" ||
    fail "the release $version of $repository could not be read. Is there one, and can the token read it?"
fi

fetch "$archive" || fail "$archive could not be fetched. A private repository needs \`GH_TOKEN\`"
fetch "$archive.sha256" || fail "the hash of $archive could not be fetched"
(cd "$work" && sha256sum --check --quiet "$archive.sha256") ||
  fail "$archive is not the file its release published. Nothing was installed"

tar -xzf "$work/$archive" -C "$work"
mkdir -p "$into"
# Moved into place in one step, so a `sgt` that is running is never half of each.
cp "$work/sgt" "$into/.sgt.new"
chmod 755 "$into/.sgt.new"
mv -f "$into/.sgt.new" "$into/sgt"

echo "installed: $("$into/sgt" --version) at $into/sgt"
case ":$PATH:" in
  *":$into:"*) ;;
  *) echo "$into is not on PATH. Add it: export PATH=\"$into:\$PATH\"" ;;
esac
