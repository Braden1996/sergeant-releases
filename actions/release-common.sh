# Shared by the npm and Woof release actions.
verify_release_tag() {
  local tagged_commit
  if [[ "$GITHUB_REF_TYPE" != tag ||
    ! "$GITHUB_REF_NAME" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
    echo 'Run releases on a version tag such as v1.2.3.' >&2
    return 1
  fi
  tagged_commit="$(git rev-parse --verify "refs/tags/$GITHUB_REF_NAME^{commit}")"
  if [[ "$tagged_commit" != "$(git rev-parse HEAD)" ]]; then
    echo 'Check out the tagged commit before releasing.' >&2
    return 1
  fi
}

write_release_notes() {
  local version="$1" changelog="$2" notes="$3"
  if ! awk -v version="$version" '
    /^##[ \t]+/ {
      if (selected) exit
      heading = $0
      sub(/^##[ \t]+/, "", heading)
      sub(/\r$/, "", heading)
      split(heading, words, /[ \t]+/)
      token = words[1]
      if (token ~ /^\[.*\]$/) token = substr(token, 2, length(token) - 2)
      sub(/^v/, "", token)
      selected = (token == version)
      next
    }
    selected {
      sub(/\r$/, "")
      print
      if ($0 ~ /[^ \t]/) has_notes = 1
    }
    END { if (!has_notes) exit 1 }
  ' < "$changelog" > "$notes"; then
    echo 'Add a nonempty level-two heading and notes for this version to the changelog.' >&2
    return 1
  fi
}

write_checksums() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$@"
  else
    shasum -a 256 -- "$@"
  fi
}
