# Sergeant

Sergeant runs your repository's checks, tests, and builds from one CLI. It tracks which files and dependencies each result used, so a small edit can reuse work that is still valid. Start with one package and add plugins as you bring more of the repo under the same gate.

## Install & quick start

Linux and macOS (x86-64 or arm64):

```sh
curl -fsSL https://github.com/Braden1996/sergeant-releases/releases/download/v0.15.0/install.sh | SGT_VERSION=v0.15.0 sh
export PATH="$HOME/.local/bin:$PATH"
sgt --version
```

Windows (PowerShell, x86-64 binary):

```powershell
$env:SGT_VERSION = 'v0.15.0'
irm https://github.com/Braden1996/sergeant-releases/releases/download/v0.15.0/install.ps1 | iex
$env:Path = "$env:LOCALAPPDATA\sergeant\bin;$env:Path"
sgt --version
```

Add the displayed bin directory to your user PATH for future terminals. Both installers verify the release archive's SHA-256 before extracting it.

To pin Sergeant through mise, copy this cross-platform `mise.toml`, then run `mise trust`, `mise install`, and `mise exec -- sgt --version`. Keep Bun and Node if your project uses them. [mise HTTP backend](https://mise.jdx.dev/dev-tools/backends/http.html)

```toml
[tools]
bun = "1.4.4"
node = "24.14.0"

[tools."http:sgt"]
version = "0.15.0"
checksum_url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/SHA256SUMS"

[tools."http:sgt".platforms]
linux-x64 = { url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/sgt-x86_64-unknown-linux-musl.tar.gz" }
linux-arm64 = { url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/sgt-aarch64-unknown-linux-musl.tar.gz" }
macos-x64 = { url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/sgt-x86_64-apple-darwin.tar.gz" }
macos-arm64 = { url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/sgt-aarch64-apple-darwin.tar.gz" }
windows-x64 = { url = "https://github.com/Braden1996/sergeant-releases/releases/download/v{{ version }}/sgt-x86_64-pc-windows-msvc.tar.gz" }
```

From an existing Git checkout, initialize Sergeant and review the generated files. In an empty checkout, `sgt new library shared` scaffolds a TypeScript unit under `packages/shared`.

```sh
sgt init
sgt install
sgt sync
sgt check
sgt test
sgt build
```

Use `sgt graph units` to check that the intended package and runtime roots are discovered. On migration, `sgt doctor` reports missing tools and dependency mismatches. Use `sgt doctor --fix` and `sgt fix` when you are ready to review the changes they make.

## Minimal repo anatomy

A TypeScript/Bun workspace can start with seven root files.

| Commit | What it owns |
| --- | --- |
| `sergeant.jsonc` | Unit discovery, selected plugins, and shared tasks |
| `mise.toml` | CLI and runtime versions |
| `package.json` | Dependencies and workspace membership |
| `bun.lock` | Reproducible dependency resolution |
| `tsconfig.base.json` | Shared editor and compiler settings |
| `oxlint.config.ts` | Native lint rules |
| `.gitignore` | Ignore `.sergeant/`, `node_modules/`, and, for Luau, `luau_packages/` |

Add a `sergeant.jsonc` inside each unit that needs an explicit kind or dependencies. Commit source, unit manifests, and tool-native lockfiles. Sergeant recreates `.sergeant/`, including its schemas and build output.

For an existing repo, move Moon task dependencies and inputs into Sergeant and compare both CI gates before removing `.moon/`. Move formatting rules into the native formatters you still use before removing dprint. After porting any custom hook behavior, `sgt hooks install` can replace Lefthook for staged Sergeant checks. Package scripts that run your app, generate code, or ship infrastructure can stay where the team already runs them.

## Language setup playbooks

### TypeScript + Bun

Use the following root `sergeant.jsonc`. The package manager and Sergeant each need to know where the workspace units live.

```jsonc
{
  "$schema": "./.sergeant/schema.json",
  "plugins": ["ts", "bun", "oxlint"],
  "packages": ["packages/*", "runtimes/*"],
  "manager": "bun"
}
```

Root `package.json`:

```json
{
  "name": "example-workspace",
  "private": true,
  "packageManager": "bun@1.4.4",
  "workspaces": ["packages/*", "runtimes/*"],
  "devDependencies": {
    "@sgt-build/oxlint-config": "0.13.0",
    "@sgt-build/tsconfig": "0.13.0",
    "@types/bun": "1.4.5",
    "oxlint": "1.95.0",
    "oxlint-tsgolint": "7.0.2009"
  }
}
```

Root `tsconfig.base.json`:

```json
{
  "extends": "@sgt-build/tsconfig/base",
  "compilerOptions": { "noEmit": true }
}
```

Root `oxlint.config.ts`:

```ts
import { base, compose } from "@sgt-build/oxlint-config";
import { defineConfig } from "oxlint";

export default defineConfig(compose(base));
```

Put source in `packages/shared/src/` and add `packages/shared/sergeant.jsonc` with `{"name":"@example/shared","kind":"ts:pure"}`. Give Bun-managed units their own `package.json` with the matching name. Use `bun:service` for a Bun runtime. Run `sgt install`, `sgt sync`, and `sgt fmt`, then commit `bun.lock` and any unit editor configs you keep. Add `vitest` if your repo already uses it.

### Luau + Woof + WoW

Root `sergeant.jsonc`:

```jsonc
{
  "$schema": "./.sergeant/schema.json",
  "plugins": ["luau", "woof", "wow"],
  "packages": ["packages/*", "runtimes/*"]
}
```

For a WoW-targeted library, add this `woof.toml` in `packages/combat-log/`, put the entry file at `packages/combat-log/src/init.luau`, and set that unit's `sergeant.jsonc` to `{"name":"@example/combat-log","kind":"wow:lib"}`.

```toml
[package]
name = "combat-log"
version = "0.1.0"
kind = "library"
target = "wow"
entry = "src/init.luau"

[luaurc]
sync = true

[dependencies]
```

Add a root `woof.toml` to manage member packages together:

```toml
[workspace]
members = ["packages/*"]
```

Run `woof install` at the root and commit `woof.lock`. Choose `luau:lib` and `target = "luau"` for a standalone library, `wow:addon` for a runtime addon with its own addon metadata, or enable `lune` for Lune tests and runtimes.

Merge these entries into the mise tool table under Install & quick start for local development. Install LuaJIT from your platform's package manager or use the CI Luau setup action below.

```toml
[tools]
"github:Braden1996/woof" = "0.3.0"
"github:lune-org/lune" = "0.11.1"
"github:JohnnyMorganz/luau-lsp" = "1.70.1"
"github:seaofvoices/darklua" = "0.17.1"
```

### Rust

Keep `Cargo.toml`, `Cargo.lock`, and your `rust-toolchain.toml`. Add this root `sergeant.jsonc` and set `crates/core/sergeant.jsonc` to `{"name":"@example/core","kind":"rust:lib"}`. Use `rust:bin` for a binary crate. Install the rustfmt and Clippy components for the toolchain your repo pins.

```jsonc
{
  "$schema": "./.sergeant/schema.json",
  "plugins": ["rust"],
  "packages": ["crates/*"]
}
```

Run `sgt check`, `sgt test`, and `sgt build` alongside your regular Cargo development commands.

### Astro / Starlight docs runtime

Add `ts` and `astro` to the root plugin list. Include `runtimes/*` in both the Sergeant package globs and the Bun workspaces. A docs-only repo can use this root `sergeant.jsonc`.

```jsonc
{
  "$schema": "./.sergeant/schema.json",
  "plugins": ["ts", "astro"],
  "packages": ["runtimes/*"],
  "manager": "bun"
}
```

Set `runtimes/docs/sergeant.jsonc` to `{"name":"@example/docs","kind":"astro:app"}` and use this `runtimes/docs/package.json`:

```json
{
  "name": "@example/docs",
  "private": true,
  "type": "module",
  "scripts": { "build-starlight": "astro build" },
  "dependencies": {
    "astro": "7.4.13",
    "@astrojs/starlight": "0.43.2",
    "@astrojs/markdown-remark": "7.3.10"
  }
}
```

The Sergeant Astro builder generates its own Astro config. Use the package script above to build with Starlight integrations and Pages base settings. In `runtimes/docs/astro.config.mjs`, set `site` and `base` to the deployed URL and path. Replace the example owner and repository in both settings.

```js
import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://example.github.io",
  base: "/example-workspace",
  output: "static",
  integrations: [starlight({ title: "Example docs" })],
});
```

Set up a Starlight content collection in `runtimes/docs/src/content.config.ts` and add a `getting-started.md` with a `title` in its frontmatter under `runtimes/docs/src/content/docs/`.

```ts
import { defineCollection } from "astro:content";
import { docsLoader } from "@astrojs/starlight/loaders";
import { docsSchema } from "@astrojs/starlight/schema";

export const collections = { docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }) };
```

Sergeant discovers Astro pages under `src/pages/`. Add `runtimes/docs/src/pages/index.astro` as an entry page for the docs.

```astro
<!doctype html>
<html lang="en">
  <head><title>Example docs</title></head>
  <body><h1>Example docs</h1></body>
</html>
```

Run `sgt install` and `sgt build runtimes/docs` for the Sergeant build. Run `bun run --cwd runtimes/docs build-starlight` to generate the full Starlight site in `runtimes/docs/dist/`. For Luau API references, add `starlight-luau@0.3.0` to the docs package, register the plugin in your Starlight config, and enable `luau-ast: true` in CI. Follow the plugin's example for choosing which Luau source and modules to document. [starlight-luau](https://github.com/Braden1996/starlight-luau)

### Polyglot workspace

Combine the root globs, tools, and plugin lists from the language playbooks. Keep Bun, Cargo, and Woof workspace membership in their respective manifests and commit all three lockfiles when used. Add repository checks as you adopt the corresponding native tools.

```jsonc
{
  "$schema": "./.sergeant/schema.json",
  "plugins": ["ts", "bun", "oxlint", "astro", "luau", "woof", "wow", "rust", "actionlint", "rumdl"],
  "packages": ["packages/*", "runtimes/*", "crates/*"],
  "manager": "bun"
}
```

## Optional plugins catalog

Add plugin IDs to `plugins` in root `sergeant.jsonc`. Install the tools for the tasks you intend to run. Repository checks discover matching files and native binaries on PATH.

| Plugin | Use it for | External tools |
| --- | --- | --- |
| `ts` | TypeScript checks, declarations, and framework-neutral units | A supported TypeScript checker (`tsgo`, `tsc`, or `tsrs`) when the project selects one |
| `bun` | Bun tests, services, and JavaScript dependency installation | Bun |
| `vitest` | Existing Vitest suites, including DOM tests | Project-local Vitest and its Node or Bun runtime |
| `oxlint` | JavaScript and TypeScript lint rules | Native Oxlint for TypeScript configs or JS plugins |
| `astro` | Astro static-site builds and dev server | Project-local Astro and Node |
| `wxt` | Browser extension builds | Project-local WXT and its runtime |
| `vite` | Vite web builds or dev server | Project-local Vite and its runtime |
| `luau` | Luau source checks and library units | luau-lsp for type checks |
| `lune` | Lune tests and service runtimes | Lune |
| `woof` | Frozen Luau dependency installation and lockfile checks | Woof |
| `wow` | WoW libraries and Lua 5.1 addon output | darklua for bundles, LuaJIT for Lua 5.1 execution |
| `rust` | Rust crate checks, tests, and binaries | Cargo, rustc, rustfmt, and Clippy |
| `actionlint` | GitHub workflow syntax and expression checks | actionlint |
| `zizmor` | Offline GitHub Actions security checks | zizmor |
| `rumdl` | Markdown linting | rumdl |
| `lychee` | Offline Markdown link and fragment checks | lychee |
| `shellcheck` | Shell script diagnostics | ShellCheck |
| `secrets` | Offline secret scanning of the workspace | Kingfisher or Gitleaks |

## Composable GitHub Actions cookbook

These examples use the `v0.15.0` release ref for Sergeant's actions. Replace it with the commit SHA behind that tag if your organization requires SHA pins. The root `Braden1996/sergeant-releases@v0.15.0` setup action is still available for existing workflows.

### `.github/workflows/ci.yml`

Set the toolchain on PATH before running the gate. This example installs Bun from the workspace version in `package.json`. Add the Luau action before `ci` if your workspace uses Luau tools. For a Rust-only repo, use a runner with your pinned Rust toolchain and omit the Bun step.

```yaml
name: CI
on: [push, pull_request]
permissions:
  contents: read
jobs:
  gate:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: oven-sh/setup-bun@3d267786b128fe76c2f16a390aa2448b815359f3 # v2.1.2
        with:
          bun-version-file: package.json
      - uses: Braden1996/sergeant-releases/actions/setup@v0.15.0
      - uses: Braden1996/sergeant-releases/actions/ci@v0.15.0
```

All four gates are enabled by default. Set `install`, `check`, `test`, or `build` to `false` to skip that command. Use `working-directory` for a nested workspace and `extra-args: --jobs 4` to pass global CLI arguments. For a separate sealed Linux job, enable `seal-sysctl: true` and `github-cache: true` on `setup` to use the Actions cache. Run tests and builds in that job with `--sealed` so Sergeant can write their results.

### `.github/workflows/pages.yml`

Set your repository's Pages source to **GitHub Actions**. The example assumes a Bun-managed docs workspace. If your site uses `starlight-luau`, add `actions/setup-luau@v0.15.0` from this repository before the build, with `woof: false` and `luau-ast: true`.

```yaml
name: Pages
on:
  push:
    branches: [main]
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency:
  group: github-pages
  cancel-in-progress: false
jobs:
  docs:
    runs-on: ubuntu-24.04
    environment:
      name: github-pages
      url: ${{ steps.pages.outputs.page-url }}
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: actions/setup-node@6044e13b5dc448c55e2357c09f80417699197238 # v6.2.0
        with:
          node-version: '24'
      - uses: oven-sh/setup-bun@3d267786b128fe76c2f16a390aa2448b815359f3 # v2.1.2
        with:
          bun-version-file: package.json
      - uses: actions/configure-pages@983d7736d9b0ae728b81ab479565c72886d7745b # v5.0.0
      - uses: Braden1996/sergeant-releases/actions/setup@v0.15.0
      - run: sgt --no-daemon install --frozen
      - id: pages
        uses: Braden1996/sergeant-releases/actions/deploy-astro-pages@v0.15.0
        with:
          unit: runtimes/docs
          deploy: true
```

The action uses the build output Sergeant reports. With the scoped manifest above, that is `.sergeant/out/example/docs/`. For Starlight, add `- run: bun run --cwd runtimes/docs build-starlight` before the Pages action and set its `output-path: runtimes/docs/dist`. Override `output-path` the same way for another generated site. Omit `deploy` to upload for a separate deployment job.

### `.github/workflows/release.yml`

Use a `v1.2.3` tag that matches the manifest version `1.2.3`. In `CHANGELOG.md`, add a heading such as `## [1.2.3] - YYYY-MM-DD` and the release notes below it. For npm, configure trusted publishing for this workflow filename in npm and set the package's `repository.url` to this GitHub repository. Use a public package and public repository for provenance. [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/)

```yaml
name: Release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
  id-token: write
jobs:
  npm:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: actions/setup-node@6044e13b5dc448c55e2357c09f80417699197238 # v6.2.0
        with:
          node-version: '24'
          registry-url: https://registry.npmjs.org
          package-manager-cache: false
      - uses: oven-sh/setup-bun@3d267786b128fe76c2f16a390aa2448b815359f3 # v2.1.2
        with:
          bun-version: '1.4.4'
      - run: bun install --frozen-lockfile
      - run: bun run build
      - uses: Braden1996/sergeant-releases/actions/release-npm@v0.15.0
```

Keep the build step for a package whose tarball includes compiled sources. The action installs the packed tarball in a temporary directory and imports it with Node. Set `smoke-import` if consumers use an export subpath. Set `publish: false` for a GitHub-only release.

For a Woof package, use `contents: write` and substitute the following steps after checkout. The runner needs Python 3.11 or newer to read TOML. Set `working-directory` for a member package and adjust `changelog` relative to that directory. Set `archive-path` if `woof pack` puts the archive outside the package root or `dist/`.

```yaml
- uses: Braden1996/sergeant-releases/actions/setup-luau@v0.15.0
- uses: Braden1996/sergeant-releases/actions/release-woof@v0.15.0
```

Generate any extra Lua 5.1 bundle before the release action and pass its path in `extra-artifacts`, one file per line. Both release helpers create the GitHub release for the tag, so choose one helper per tag.

### `.github/workflows/pr-title.yml`

This job reads PR metadata, so it works for forked PRs without checking out their code. Use a comma-separated scope list, or omit it to allow any scope. `deps` and `deps-dev` are accepted with conventional prefixes, and plain Dependabot `Bump …` or `Update …` titles also pass.

```yaml
name: PR title
on:
  pull_request_target:
    types: [opened, edited, reopened, synchronize]
permissions:
  contents: read
jobs:
  title:
    runs-on: ubuntu-24.04
    steps:
      - uses: Braden1996/sergeant-releases/actions/pr-title@v0.15.0
        with:
          scopes: api, docs, web
```

## Benchmarks

In the historical 10,050-file, 250-unit Linux benchmark on two CPUs, Sergeant 0.3.0 reused an unchanged check in 126 ms versus 6.54 s for the direct incremental check pipeline. The unchanged test run took 136 ms versus 1.26 s with direct Bun. Cold checks took 1.01 s with Sergeant and 929 ms with the direct pipeline. [Benchmark chart](assets/benchmarks.png)

## Credits

Sergeant builds on Oxc, TypeScript, StyLua, Selene, Lune, Bun, Vitest, Playwright, Rsbuild, and pnpm, with ideas from Bazel and Buck2. This repository distributes the public binaries, installers, schemas, and actions.
