set -euo pipefail
source "$GITHUB_ACTION_PATH/../release-common.sh"
verify_release_tag

package="$(node -e '
  const fs = require("node:fs");
  const { name, version } = JSON.parse(fs.readFileSync("package.json", "utf8"));
  if (typeof version !== "string" || `v${version}` !== process.env.GITHUB_REF_NAME) {
    throw new Error("The tag must match the package.json version.");
  }
  if (typeof name !== "string" || !/^(?:@[a-z0-9][a-z0-9._-]*\/)?[a-z0-9][a-z0-9._-]*$/.test(name)) {
    throw new Error("Expected a valid npm package name.");
  }
  process.stdout.write(name);
')"

release_dir="$(mktemp -d "$RUNNER_TEMP/sergeant-npm.XXXXXX")"
version="${GITHUB_REF_NAME#v}"
asset="${package#@}"
asset="${asset//\//-}-$version.tgz"
write_release_notes "$version" "$SGT_CHANGELOG" "$release_dir/notes.md"
bun pm pack --filename "$release_dir/$asset"

tarball="$release_dir/$asset"
(cd -- "$release_dir" && tar -tzf "$asset" > contents)
grep -Fxq 'package/package.json' "$release_dir/contents"
mkdir "$release_dir/smoke"

(
  cd -- "$release_dir/smoke"
  printf '%s\n' '{"private":true}' > package.json
  npm install --ignore-scripts --no-audit --no-fund --no-package-lock -- "$tarball"
  SGT_NPM_PACKAGE="$package" SGT_SMOKE_IMPORT="${SGT_SMOKE_IMPORT:-$package}" node --input-type=module -e '
    import { readFileSync } from "node:fs";
    const { SGT_NPM_PACKAGE: name, GITHUB_REF_NAME: tag, SGT_SMOKE_IMPORT: specifier } = process.env;
    const packed = JSON.parse(readFileSync(`node_modules/${name}/package.json`, "utf8"));
    if (packed.name !== name || `v${packed.version}` !== tag) {
      throw new Error("The packed package name or version differs from the release manifest.");
    }
    if (specifier !== name && !specifier.startsWith(`${name}/`)) {
      throw new Error("Smoke-test the packed package or one of its subpaths.");
    }
    await import(specifier);
  '
)
(cd -- "$release_dir" && write_checksums "$asset" > SHA256SUMS)
printf 'directory=%s\nasset=%s\n' "$release_dir" "$asset" >> "$GITHUB_OUTPUT"
