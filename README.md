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
when it cannot.

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
available and each scheduler could use four threads. Every row is the median of six rounds,
measured 2026-11-20 on a 4-CPU Intel Xeon at 2.10 GHz (Linux 6.18.44), at Sergeant 0.2.5,
source snapshot `5172cee`. Each ratio has a 95% interval.

On the 1,005-file half (25 units, 200 tests, the same six rounds and the same machine),
Sergeant had the lowest median of the build systems on all six check workloads, and Turborepo
on all five test workloads. Counting the direct tools, the lowest median was Sergeant's on
five rows, the direct tools' on three and Turborepo's on three. A cold check took 118 ms in
the direct tools and 163 ms in Sergeant. With nothing changed, a check took 29 ms in
Sergeant, 152 ms in the direct tools and 73 ms in Turborepo, and the tests took 101 ms,
273 ms and 75 ms.

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
on 9 of the 11 workloads in the second table: five of the six checks, and every test but the
cold one. Turborepo was faster on a cold test (2.40 s, Sergeant 3.04 s) and had a lower median
on an unchanged check (180 ms, Sergeant 184 ms), where the interval includes parity. Counting
the direct tools, Sergeant led eight rows, Turborepo two and the direct tools one, a cold check
(658 ms, Sergeant 890 ms).

With no edits, Sergeant reused all 40,200 check results in 184 ms, versus 8.86 s for the direct pipeline with incremental TSRS. Sergeant reused results for all 2,000 test files in 169 ms, while direct Bun ran those files in 2.96 s. Times are medians.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 890 ms | 40,200 of 40,200 | OXC, declarations, TSRS 658 ms | 0.73× [0.66, 0.80] |
| `check`, nothing changed | 184 ms | 0 of 40,200 | OXC, declarations, incremental TSRS 8.86 s | 46.33× [43.97, 50.98] |
| `check` after editing a shared file | 564 ms | 7,155 of 40,200 | OXC, declarations, incremental TSRS 9.72 s | 16.97× [14.49, 19.36] |
| `check` after editing inside a function of a shared file | 230 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 9.22 s | 38.28× [33.73, 42.60] |
| `check` after editing a leaf file | 253 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 9.36 s | 37.29× [31.30, 39.30] |
| the same, daemon running | 99 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 9.16 s | 89.52× [80.69, 107.04] |
| `check` in a fresh checkout, cache shared | 205 ms | 0 of 40,200 | — | — |
| `test`, cold | 3.04 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 2.95 s | 0.94× [0.79, 1.05], inconclusive |
| `test`, nothing changed | 169 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.96 s | 17.47× [16.18, 18.29] |
| `test` in a fresh checkout, cache shared | 216 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 2.12 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 3.08 s | 1.39× [1.17, 1.65] |
| `test` after editing a leaf file | 171 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.80 s | 16.41× [14.90, 18.23] |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-20 on Intel(R) Xeon(R) Processor @ 2.10GHz (4 available CPUs, Linux 6.18.44-fc-v726, job limit 4), source snapshot `5172ceee35b386a007ed2d443e90f93d0fe07d5f`. Check arms use tsrs 7.1.0-beta.tsrs1 and test arms use Bun 1.4.4 with isolation. Ratios divide each comparison time by Sergeant's time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds.</sub>

| Situation | Sergeant | Turborepo | Nx | Moon | Bazel |
| --- | ---: | ---: | ---: | ---: | ---: |
| `check`, cold | 890 ms | 8.64 s<br><sub>9.61× [8.86, 10.53]</sub> | 22.14 s<br><sub>24.94× [22.92, 26.15]</sub> | 16.80 s<br><sub>19.27× [17.55, 20.76]</sub> | 27.33 s<br><sub>30.55× [24.23, 33.44]</sub> |
| `check`, nothing changed | 184 ms | 180 ms<br><sub>0.93× [0.87, 1.15], inconclusive</sub> | 660 ms<br><sub>3.52× [3.34, 3.75]</sub> | 6.66 s<br><sub>34.83× [33.09, 38.40]</sub> | 378 ms<br><sub>1.93× [1.79, 3.20]</sub> |
| `check` after editing a shared file | 564 ms | 9.01 s<br><sub>16.17× [13.07, 18.78]</sub> | 22.10 s<br><sub>39.24× [32.50, 44.62]</sub> | 17.54 s<br><sub>31.58× [25.80, 34.25]</sub> | 18.05 s<br><sub>33.10× [25.77, 40.58]</sub> |
| `check` after editing inside a function of a shared file | 230 ms | 8.17 s<br><sub>36.09× [30.08, 38.55]</sub> | 21.33 s<br><sub>92.87× [73.97, 98.60]</sub> | 17.01 s<br><sub>72.40× [61.77, 77.31]</sub> | 19.73 s<br><sub>83.80× [68.61, 91.39]</sub> |
| `check` after editing a leaf file | 253 ms | 400 ms<br><sub>1.51× [1.33, 1.64]</sub> | 1.21 s<br><sub>4.76× [4.03, 5.25]</sub> | 6.90 s<br><sub>27.20× [23.36, 30.41]</sub> | 737 ms<br><sub>2.84× [1.99, 3.60]</sub> |
| `check` in a fresh checkout, cache shared | 205 ms | 534 ms<br><sub>2.76× [2.47, 2.98]</sub> | — | — | 9.30 s<br><sub>45.84× [43.39, 53.37]</sub> |
| `test`, cold | 3.04 s | 2.40 s<br><sub>0.74× [0.65, 0.81]</sub> | 16.56 s<br><sub>5.46× [4.52, 5.74]</sub> | 12.45 s<br><sub>4.04× [3.49, 4.21]</sub> | 70.14 s<br><sub>22.28× [10.67, 29.19]</sub> |
| `test`, nothing changed | 169 ms | 207 ms<br><sub>1.23× [1.12, 1.54]</sub> | 637 ms<br><sub>3.88× [3.13, 4.03]</sub> | 7.62 s<br><sub>43.94× [41.80, 48.40]</sub> | 556 ms<br><sub>3.24× [2.73, 4.55]</sub> |
| `test` in a fresh checkout, cache shared | 216 ms | 411 ms<br><sub>1.83× [1.71, 2.03]</sub> | — | — | 18.07 s<br><sub>83.82× [78.05, 113.69]</sub> |
| `test` after editing a shared file | 2.12 s | 2.33 s<br><sub>1.09× [0.91, 1.24], inconclusive</sub> | 16.15 s<br><sub>7.92× [5.98, 8.89]</sub> | 13.03 s<br><sub>6.08× [5.39, 7.12]</sub> | 10.28 s<br><sub>4.87× [4.62, 5.50]</sub> |
| `test` after editing a leaf file | 171 ms | 226 ms<br><sub>1.35× [1.06, 1.54]</sub> | 1.02 s<br><sub>5.93× [5.20, 7.18]</sub> | 7.41 s<br><sub>43.71× [36.65, 49.63]</sub> | 675 ms<br><sub>4.07× [3.18, 5.29]</sub> |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-20 on Intel(R) Xeon(R) Processor @ 2.10GHz (4 available CPUs, Linux 6.18.44-fc-v726, job limit 4), source snapshot `5172ceee35b386a007ed2d443e90f93d0fe07d5f`. Build systems measured include Turborepo 2.11.11, Nx 24.0.6, Moon 2.6.5 and Bazel 9.3.2. Package checks use tsrs 7.1.0-beta.tsrs1 and isolated tests use Bun 1.4.4. Ratios divide each comparison time by Sergeant's time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds. A dash marks an unmeasured arm.</sub>

## What it supports

| | |
| --- | --- |
| **TypeScript** | Libraries, Bun services and React pages. A check or a test is cached per file. |
| **Luau** | `sgt build` turns `src/main.luau` into one file of Lua 5.1. |
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
