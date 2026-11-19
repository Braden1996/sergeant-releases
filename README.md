<h3 align="center">The build system that knows every file.</h3>

<p align="center">
  Check, test and build a TypeScript, Luau or Rust workspace, and redo only what each edit can change.<br>
  A Luau program is built into one file of Lua 5.1. One binary. No config per package.
</p>

<p align="center">
  <a href="https://github.com/Braden1996/sergeant-releases/releases/latest"><img src="https://img.shields.io/github/v/release/Braden1996/sergeant-releases?label=release&color=3dd6c4" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/linux-x86--64%20%7C%20arm64-1a2343" alt="Linux x86-64 and arm64">
  <img src="https://img.shields.io/badge/windows-x86--64-1a2343" alt="Windows x86-64">
  <img src="https://img.shields.io/badge/status-early-f5b544" alt="Early">
</p>

<p align="center">
  <a href="#why-sergeant"><b>Why</b></a> ·
  <a href="#benchmarks">Benchmarks</a> ·
  <a href="#install">Install</a>
</p>

```console
$ sgt check
ok: fmt, lint, decl, types and boundaries on 11 files

$ sgt test                      # after editing price.ts
ok: test on 2 files, 1 run and 1 already passed
```

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | sh
```

## Why Sergeant

In the Turborepo and Nx configurations benchmarked here, each package has a check task and
a test task. Changing one source file can invalidate a whole package task. Sergeant follows
imports to cache individual checks and test files. A test whose inputs are unchanged can
reuse its previous pass, even inside the edited package.

That is the build system AI agents need. They edit dozens of times a minute, often in parallel,
and they believe whatever the tools tell them.

## Features

**File-level reuse.** A change inside a function can preserve its exported type. Sergeant
can reuse downstream type checks while rerunning tests that depend on the implementation.

**Captured test inputs.** Cacheable Bun tests run against captured source, packages and
fixtures. Sealed runs also enforce filesystem and network restrictions in the kernel.
A pass is replayed only for the Bun executable that earned it. When `bun` is a shell
script, the tests that need it run on every invocation. A symlink to the native binary
keeps the reuse.

**Lua 5.1.** `sgt build` turns a program that starts at `src/main.luau` into
`.sergeant/out/<unit>/main.lua`, one file of Lua 5.1. A function Luau has and Lua 5.1 has
not is stood in for when the behaviour can be the same, and the build fails with a place
when it cannot. A World of Warcraft addon, a `.toc` at the unit's root, is built into the
directory the game is given.

**A linter of the workspace's own.** `.sergeant/config.toml` names a program. `sgt lint`
and `sgt check` run it beside Sergeant's lint, and what it finds is kept per file and held
to the baseline, under the plugin's name.

**Rust, a crate at a time.** A unit with a `Cargo.toml` is formatted by file and checked,
linted and tested as that crate, with the profile the crate asks for.

**One binary, zero config.** The formatter, linter and TypeScript checker are built in. A
package's kind comes from its layout, so packages carry no tsconfig, ESLint or bundler config.

**No escape hatches.** `@ts-ignore` and `eslint-disable` are errors. Existing problems go in a
baseline that can only shrink.

**Made for agents.** Every command speaks JSON, `sgt mcp` serves them all to any agent, and
`sgt worktree` gives each agent its own checkout over one shared cache.

**CI that skips what passed.** `sgt ci` shards by past timing, skips every test a shared cache
has already passed, and reports one status.

## How it works

Every result is stored under a hash of exactly the inputs it was made from, and those inputs
are read from your code. A saved parse is used only after the source bytes are hashed again
and match. A typecheck is kept under the installed declarations the checker read. The same
key gives the same answer on every machine. Ask for the reason behind any answer:

```console
$ sgt log
sgt test: exit 0 in 21 ms
changed since the command before: libraries/domain/src/price.ts
test: 1 ran in 11 ms, 1 reused
  libraries/domain/src/cart.test.ts  11 ms  reaches libraries/domain/src/price.ts
```

## Many worktrees, one cache

Agents in different worktrees share one cache, so one worktree can be handed a pass that
another made. That is safe because a key is not a name for a test: it is a hash of every
byte the test can read, the file, everything it imports, the lockfile, the toolchain and the
settings. Two worktrees with different edits in a test's closure get different keys and each
run their own. Two with the same bytes get the same key, and the answer is the one they
would have got by running it.

- **The same key at the same moment runs once.** The second worktree waits and replays the
  pass. A failure is never kept, so a worktree that waited on one runs the test itself.
- **Sealing is what makes a key complete.** On Linux a test runs in a root that holds only
  the files in its key, with no network, so it cannot read an input the key missed. A sealed
  pass has a key of its own, apart from an unsealed one.
- **Unsealed Bun tests** use captured source, package and fixture inputs. Tests that
  read files through supported APIs run in private views. Tests that access live host
  state require `--no-cache` or a matching cache policy. Only sealed CI runs write
  to a shared remote cache.

## A workspace

```sh
mkdir shop && cd shop
sgt new library domain                  # shared code
sgt new service api                     # a Bun service
sgt new web page                        # a React page
sgt add @types/bun --dev --to api
sgt check && sgt test && sgt dev page
```

Give it to an agent:

```json
{ "mcpServers": { "sergeant": { "command": "sgt", "args": ["mcp"] } } }
```

## Benchmarks

The tables are one native run. Each system runs the tasks it is configured with, on the same
sources, with tsrs 7.1.0-beta.tsrs1 for checks and Bun 1.4.4 for tests. Four CPUs were
available and each scheduler could use four threads. Every row is the median of three rounds,
measured 2026-11-19 on an AMD EPYC 9V74 (Linux 6.18.57), source snapshot `498dd6ce`.

On the 1,005-file half (25 units, 200 tests, the same three rounds and the same machine),
Sergeant had the lowest median of the build systems on all six check workloads, and Turborepo
on all five test workloads. Counting the direct tools, the lowest median was Sergeant's on
five rows, the direct tools' on three and Turborepo's on three. A cold check took 143 ms in
the direct tools and 227 ms in Sergeant. With nothing changed, a check took 28 ms in
Sergeant, 169 ms in the direct tools and 71 ms in Turborepo, and the tests took 737 ms,
166 ms and 111 ms.

A separate measurement, inside Sergeant, compares typechecks kept under a file's declarations
with typechecks kept under the whole file. Seven paired rounds, one CPU of an AMD EPYC 9V74
(Linux 6.18.57), 1,011 diagnostic roots, snapshot `b103c51`.

After a function-body edit, Sergeant checked 1 diagnostic root with verified declarations (median 67.2 ms) and 6 diagnostic roots with full-content keys (median 105.5 ms). Full-content time divided by declaration time was 1.56× (paired 95% CI 1.41–1.88). Paired timings favored full-content keys for cold runs (0.92×), warm runs (0.90×) and an added public export (0.88×).

The fixed-work timings, one identical worker through every system, wait on a runner that can
seal Sergeant's actions.

A six-system comparison of cached fixed-work timings is pending a single runner that can seal Sergeant's actions.

### Ten thousand files

The tables are the 10,050-file half of the run above (250 units, 2,000 tests). A shared edit
and a leaf edit each add an unused export. Before a row is timed, each configured system has
to catch a type error and a failing test. The daemon row sits outside both counts below.
On this half Sergeant had the lowest build-system median
on 9 of the 11 workloads in the second table: all six checks, and the cold, shared-edit and
fresh-checkout tests. Turborepo was faster on an unchanged test (196 ms, Sergeant 520 ms) and
on a leaf-file test edit (256 ms, Sergeant 431 ms). Counting the direct tools, Sergeant led
seven rows, the direct tools two and Turborepo two.

With no edits, Sergeant reused all 40,200 check results in 190 ms, versus 6.84 s for the direct pipeline with incremental TSRS. Sergeant reused results for all 2,000 test files in 520 ms, while direct Bun ran those files in 2.24 s. Times are medians.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 1.16 s | 40,200 of 40,200 | OXC, declarations, TSRS 995 ms | fewer than 5 pairs |
| `check`, nothing changed | 190 ms | 0 of 40,200 | OXC, declarations, incremental TSRS 6.84 s | fewer than 5 pairs |
| `check` after editing a shared file | 580 ms | 7,155 of 40,200 | OXC, declarations, incremental TSRS 8.42 s | fewer than 5 pairs |
| `check` after editing inside a function of a shared file | 221 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 6.99 s | fewer than 5 pairs |
| `check` after editing a leaf file | 214 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 6.41 s | fewer than 5 pairs |
| the same, daemon running | 203 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 7.07 s | fewer than 5 pairs |
| `check` in a fresh checkout, cache shared | 249 ms | 0 of 40,200 | — | — |
| `test`, cold | 2.54 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 2.54 s | fewer than 5 pairs |
| `test`, nothing changed | 520 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.24 s | fewer than 5 pairs |
| `test` in a fresh checkout, cache shared | 455 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 1.78 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 2.51 s | fewer than 5 pairs |
| `test` after editing a leaf file | 431 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 1.87 s | fewer than 5 pairs |

<sub>10,050 files in 250 units. Median elapsed times across 3 rounds (3 cold). Measured 2026-11-19 on AMD EPYC 9V74 80-Core Processor (4 available CPUs, Linux 6.18.57, job limit 4), source snapshot `498dd6ce795f935e8bcdd86903ada96238c4b230`. Check arms use tsrs 7.1.0-beta.tsrs1 and test arms use Bun 1.4.4 with isolation. Ratios divide each comparison time by Sergeant's time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds.</sub>

| Situation | Sergeant | Turborepo | Nx | Moon | Bazel |
| --- | ---: | ---: | ---: | ---: | ---: |
| `check`, cold | 1.16 s | 11.48 s<br><sub>fewer than 5 pairs</sub> | 30.97 s<br><sub>fewer than 5 pairs</sub> | 21.00 s<br><sub>fewer than 5 pairs</sub> | 24.46 s<br><sub>fewer than 5 pairs</sub> |
| `check`, nothing changed | 190 ms | 252 ms<br><sub>fewer than 5 pairs</sub> | 1.57 s<br><sub>fewer than 5 pairs</sub> | 8.19 s<br><sub>fewer than 5 pairs</sub> | 563 ms<br><sub>fewer than 5 pairs</sub> |
| `check` after editing a shared file | 580 ms | 12.85 s<br><sub>fewer than 5 pairs</sub> | 30.41 s<br><sub>fewer than 5 pairs</sub> | 23.58 s<br><sub>fewer than 5 pairs</sub> | 17.25 s<br><sub>fewer than 5 pairs</sub> |
| `check` after editing inside a function of a shared file | 221 ms | 10.40 s<br><sub>fewer than 5 pairs</sub> | 27.54 s<br><sub>fewer than 5 pairs</sub> | 20.65 s<br><sub>fewer than 5 pairs</sub> | 15.46 s<br><sub>fewer than 5 pairs</sub> |
| `check` after editing a leaf file | 214 ms | 330 ms<br><sub>fewer than 5 pairs</sub> | 1.98 s<br><sub>fewer than 5 pairs</sub> | 7.82 s<br><sub>fewer than 5 pairs</sub> | 639 ms<br><sub>fewer than 5 pairs</sub> |
| `check` in a fresh checkout, cache shared | 249 ms | 761 ms<br><sub>fewer than 5 pairs</sub> | — | — | 9.76 s<br><sub>fewer than 5 pairs</sub> |
| `test`, cold | 2.54 s | 3.42 s<br><sub>fewer than 5 pairs</sub> | 21.82 s<br><sub>fewer than 5 pairs</sub> | 15.04 s<br><sub>fewer than 5 pairs</sub> | 46.41 s<br><sub>fewer than 5 pairs</sub> |
| `test`, nothing changed | 520 ms | 196 ms<br><sub>fewer than 5 pairs</sub> | 1.85 s<br><sub>fewer than 5 pairs</sub> | 9.34 s<br><sub>fewer than 5 pairs</sub> | 705 ms<br><sub>fewer than 5 pairs</sub> |
| `test` in a fresh checkout, cache shared | 455 ms | 1.22 s<br><sub>fewer than 5 pairs</sub> | — | — | 23.05 s<br><sub>fewer than 5 pairs</sub> |
| `test` after editing a shared file | 1.78 s | 3.25 s<br><sub>fewer than 5 pairs</sub> | 21.45 s<br><sub>fewer than 5 pairs</sub> | 15.70 s<br><sub>fewer than 5 pairs</sub> | 14.33 s<br><sub>fewer than 5 pairs</sub> |
| `test` after editing a leaf file | 431 ms | 256 ms<br><sub>fewer than 5 pairs</sub> | 1.76 s<br><sub>fewer than 5 pairs</sub> | 8.31 s<br><sub>fewer than 5 pairs</sub> | 887 ms<br><sub>fewer than 5 pairs</sub> |

<sub>10,050 files in 250 units. Median elapsed times across 3 rounds (3 cold). Measured 2026-11-19 on AMD EPYC 9V74 80-Core Processor (4 available CPUs, Linux 6.18.57, job limit 4), source snapshot `498dd6ce795f935e8bcdd86903ada96238c4b230`. Build systems measured include Turborepo 2.11.11, Nx 24.0.6, Moon 2.6.5 and Bazel 9.3.2. Package checks use tsrs 7.1.0-beta.tsrs1 and isolated tests use Bun 1.4.4. Ratios divide each comparison time by Sergeant's time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds. A dash marks an unmeasured arm.</sub>

## What it supports

| | |
| --- | --- |
| **TypeScript** | Libraries, Bun services and React pages. A check or a test is cached per file. |
| **Luau** | `sgt build` turns `src/main.luau` into one file of Lua 5.1. A World of Warcraft addon, a `.toc` at the unit's root, is built into the directory the game is given. |
| **Rust** | A unit with a `Cargo.toml` is formatted by file and checked, linted and tested as that crate, with the profile the crate asks for. |
| **Linux** | Prebuilt, static binaries for x86-64 and arm64. Sealed runs are on Linux. |
| **Windows** | A prebuilt `sgt.exe` for x86-64, installed with `install.ps1`. |
| **macOS** | No published binary yet. |

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | sh
```

This fetches the archive for the machine it runs on, checks it against its published
sha256, and puts `sgt` in `~/.local/bin`. It needs no token. Sergeant also expects
[Bun](https://bun.sh), [pnpm](https://pnpm.io) and [Node](https://nodejs.org) on the path,
and `sgt doctor` says what is missing.

On Windows, in PowerShell:

```powershell
irm https://github.com/Braden1996/sergeant-releases/releases/latest/download/install.ps1 | iex
```

This puts `sgt.exe` in `%LOCALAPPDATA%\sergeant\bin`, after the same sha256 check, and
prints the line that adds that folder to your path. `SGT_VERSION` works the same way.

| Variable | What it does |
| --- | --- |
| `SGT_VERSION` | The release to install, as its tag: `v0.1.0`. Left out, the latest. |
| `SGT_INSTALL` | The directory `sgt` goes in. Left out, `~/.local/bin`. |
| `SGT_FROM` | An address that holds the archives in place of GitHub: a mirror or a bucket. |

In CI or a container, pin the version:

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | SGT_VERSION=v0.1.0 sh
```

---

This repository holds releases only; Sergeant's source is not public yet. It builds on
[oxc](https://oxc.rs), the TypeScript checker,
[StyLua](https://github.com/JohnnyMorganz/StyLua), [selene](https://github.com/Kampfkarren/selene),
[Lune](https://github.com/lune-org/lune), [Bun](https://bun.sh), [Vitest](https://vitest.dev),
[Playwright](https://playwright.dev), [Rsbuild](https://rsbuild.dev) and [pnpm](https://pnpm.io),
and on ideas from [Bazel](https://bazel.build) and [Buck2](https://buck2.build). Diagrams in
[`assets/`](assets/README.md) are rendered from HTML.
