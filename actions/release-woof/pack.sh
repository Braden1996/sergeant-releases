set -euo pipefail
source "$GITHUB_ACTION_PATH/../release-common.sh"
verify_release_tag

package="$(python3 - <<'PY'
import os
import re
import tomllib

with open("woof.toml", "rb") as manifest:
    package = tomllib.load(manifest)["package"]
if "v" + package["version"] != os.environ["GITHUB_REF_NAME"]:
    raise SystemExit("The tag must match the woof.toml package version.")
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", package["name"]):
    raise SystemExit("Expected a Woof package name usable in a release asset filename.")
print(package["name"])
PY
)"

release_dir="$(mktemp -d "$RUNNER_TEMP/sergeant-woof.XXXXXX")"
mkdir "$release_dir/assets"
version="${GITHUB_REF_NAME#v}"
write_release_notes "$version" "$SGT_CHANGELOG" "$release_dir/notes.md"
woof pack

archive="${SGT_WOOF_ARCHIVE:-}"
if [[ -z "$archive" ]]; then
  candidates=()
  for stem in "$package-$version" "$package-v$version" "dist/$package-$version" "dist/$package-v$version"; do
    for ext in zip tar.gz tgz; do
      if [[ -f "$stem.$ext" ]]; then candidates+=("$stem.$ext"); fi
    done
  done
  if [[ -z "${candidates[0]-}" || -n "${candidates[1]-}" ]]; then
    echo 'Set archive-path to the single archive produced by woof pack.' >&2
    exit 1
  fi
  archive="${candidates[0]}"
fi

stage_asset() {
  local path="$1" filename="${1##*/}"
  if [[ ! -f "$path" || ! "$filename" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ||
    "$filename" == SHA256SUMS || -e "$release_dir/assets/$filename" ]]; then
    echo 'Release assets must be files with unique archive-safe names. SHA256SUMS is reserved.' >&2
    return 1
  fi
  cp -- "$path" "$release_dir/assets/$filename"
}

stage_asset "$archive"
while IFS= read -r artifact; do
  if [[ -n "$artifact" ]]; then stage_asset "$artifact"; fi
done <<< "${SGT_EXTRA_ARTIFACTS:-}"

if [[ "$SGT_CHECKSUMS" == true ]]; then
  (cd -- "$release_dir/assets" && write_checksums * > SHA256SUMS)
fi
printf 'directory=%s\n' "$release_dir" >> "$GITHUB_OUTPUT"
