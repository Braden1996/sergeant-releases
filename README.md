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

**Your linter, your version, your rules.** A workspace with `.oxlintrc.json` is linted by
its own rules. One that installs oxlint or ESLint has that program run, at the version its
lockfile pins, and Sergeant keeps what it finds per file so only changed files are asked
about again.

**Your formatting options.** A workspace with `.oxfmtrc.json` is formatted the way it
says: quotes, semicolons, widths, commas. The file is in the key of each result, so a
changed option formats again and an unchanged one costs nothing.

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
measured 2026-11-20 on a 4-CPU Intel Xeon at 2.10 GHz (Linux 6.18.44), at Sergeant 0.2.7,
source snapshot `24f6691`. Each ratio has a 95% interval.

On the 1,005-file half (25 units, 200 tests, the same six rounds and the same machine),
Sergeant had the lowest median of the build systems on all six check workloads, and Turborepo
on four of the five test workloads. On the fifth, a test after a leaf edit, Sergeant's median
was lower (101 ms, Turborepo 103 ms), but the interval includes parity. Counting the direct
tools, the lowest median was Sergeant's on six rows, the direct tools' on three and
Turborepo's on two. A cold check took 113 ms in the direct tools and 166 ms in Sergeant.
With nothing changed, a check took 27 ms in Sergeant, 146 ms in the direct tools and 61 ms
in Turborepo, and the tests took 91 ms, 272 ms and 62 ms.

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
on 8 of the 11 workloads in the second table: five of the six checks, and three of the five
tests. Turborepo was faster on a cold test (2.09 s, Sergeant 2.92 s). It also had a lower
median on an unchanged check (160 ms, Sergeant 176 ms) and on a test after a shared edit
(2.08 s, Sergeant 2.09 s), where both intervals include parity. Counting the direct tools,
Sergeant led seven rows, Turborepo three and the direct tools one, a cold check (678 ms,
Sergeant 901 ms).

With no edits, Sergeant reused all 40,200 check results in 176 ms, versus 8.46 s for the direct pipeline with incremental TSRS. Sergeant reused results for all 2,000 test files in 160 ms, while direct Bun ran those files in 2.68 s. Times are medians.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 901 ms | 40,200 of 40,200 | OXC, declarations, TSRS 678 ms | 0.70× [0.58, 0.81] |
| `check`, nothing changed | 176 ms | 0 of 40,200 | OXC, declarations, incremental TSRS 8.46 s | 48.43× [41.51, 54.08] |
| `check` after editing a shared file | 576 ms | 7,155 of 40,200 | OXC, declarations, incremental TSRS 9.02 s | 15.03× [14.03, 16.97] |
| `check` after editing inside a function of a shared file | 233 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 8.54 s | 36.01× [33.36, 41.41] |
| `check` after editing a leaf file | 233 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 8.72 s | 36.73× [34.97, 45.91] |
| the same, daemon running | 96 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 8.91 s | 90.22× [72.46, 104.80] |
| `check` in a fresh checkout, cache shared | 166 ms | 0 of 40,200 | — | — |
| `test`, cold | 2.92 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 2.69 s | 0.94× [0.64, 1.06], inconclusive |
| `test`, nothing changed | 160 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.68 s | 16.42× [14.75, 18.55] |
| `test` in a fresh checkout, cache shared | 189 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 2.09 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 2.83 s | 1.32× [1.17, 1.73] |
| `test` after editing a leaf file | 167 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.87 s | 17.51× [15.16, 18.20] |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-20 on Intel(R) Xeon(R) Processor @ 2.10GHz (4 available CPUs, Linux 6.18.44-fc-v726, job limit 4), source snapshot `24f66915e644840687c4f2bb0f453a3d332ce54c`. Check arms use tsrs 7.1.0-beta.tsrs1 and test arms use Bun 1.4.4 with isolation. Ratios divide each comparison time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds.</sub>

| Situation | Sergeant | Turborepo | Nx | Moon | Bazel |
| --- | ---: | ---: | ---: | ---: | ---: |
| `check`, cold | 901 ms | 8.36 s<br><sub>9.04× [7.53, 9.96]</sub> | 22.25 s<br><sub>24.41× [19.07, 26.70]</sub> | 16.98 s<br><sub>19.01× [14.04, 20.56]</sub> | 29.81 s<br><sub>33.03× [20.62, 39.18]</sub> |
| `check`, nothing changed | 176 ms | 160 ms<br><sub>0.93× [0.86, 1.02], inconclusive</sub> | 645 ms<br><sub>3.71× [3.18, 3.79]</sub> | 6.61 s<br><sub>37.94× [30.50, 41.32]</sub> | 411 ms<br><sub>2.37× [1.76, 2.94]</sub> |
| `check` after editing a shared file | 576 ms | 8.67 s<br><sub>14.92× [13.09, 16.98]</sub> | 20.82 s<br><sub>35.88× [33.81, 40.37]</sub> | 16.36 s<br><sub>28.08× [25.41, 32.17]</sub> | 16.87 s<br><sub>29.54× [24.95, 32.15]</sub> |
| `check` after editing inside a function of a shared file | 233 ms | 7.74 s<br><sub>33.86× [28.90, 41.36]</sub> | 20.29 s<br><sub>85.39× [77.09, 101.69]</sub> | 15.64 s<br><sub>68.94× [57.97, 79.14]</sub> | 17.53 s<br><sub>74.05× [59.60, 91.97]</sub> |
| `check` after editing a leaf file | 233 ms | 320 ms<br><sub>1.47× [1.33, 1.50]</sub> | 1.15 s<br><sub>4.92× [4.62, 5.31]</sub> | 6.25 s<br><sub>27.10× [24.59, 29.44]</sub> | 702 ms<br><sub>2.98× [2.45, 3.63]</sub> |
| `check` in a fresh checkout, cache shared | 166 ms | 483 ms<br><sub>2.76× [2.32, 3.29]</sub> | — | — | 8.78 s<br><sub>52.39× [48.63, 59.72]</sub> |
| `test`, cold | 2.92 s | 2.09 s<br><sub>0.71× [0.52, 0.78]</sub> | 15.17 s<br><sub>5.21× [3.77, 5.60]</sub> | 11.54 s<br><sub>3.85× [2.98, 4.19]</sub> | 81.31 s<br><sub>27.81× [9.44, 34.51]</sub> |
| `test`, nothing changed | 160 ms | 171 ms<br><sub>1.09× [0.95, 1.19], inconclusive</sub> | 610 ms<br><sub>3.69× [3.15, 4.12]</sub> | 6.71 s<br><sub>40.89× [38.34, 43.81]</sub> | 500 ms<br><sub>3.22× [2.35, 4.54]</sub> |
| `test` in a fresh checkout, cache shared | 189 ms | 395 ms<br><sub>2.07× [1.58, 2.35]</sub> | — | — | 16.44 s<br><sub>87.40× [82.11, 112.82]</sub> |
| `test` after editing a shared file | 2.09 s | 2.08 s<br><sub>0.97× [0.90, 1.22], inconclusive</sub> | 14.81 s<br><sub>7.20× [6.10, 9.12]</sub> | 12.88 s<br><sub>5.77× [5.19, 7.03]</sub> | 9.97 s<br><sub>4.65× [4.53, 5.74]</sub> |
| `test` after editing a leaf file | 167 ms | 210 ms<br><sub>1.26× [1.11, 1.42]</sub> | 1.01 s<br><sub>5.94× [5.39, 6.77]</sub> | 7.25 s<br><sub>44.49× [40.04, 46.19]</sub> | 685 ms<br><sub>4.27× [3.49, 6.37]</sub> |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-20 on Intel(R) Xeon(R) Processor @ 2.10GHz (4 available CPUs, Linux 6.18.44-fc-v726, job limit 4), source snapshot `24f66915e644840687c4f2bb0f453a3d332ce54c`. Build systems measured include Turborepo 2.11.11, Nx 24.0.6, Moon 2.6.5 and Bazel 9.3.2. Package checks use tsrs 7.1.0-beta.tsrs1 and isolated tests use Bun 1.4.4. Ratios divide each comparison time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds. A dash marks an unmeasured arm.</sub>

### Windows

The same harness ran natively on Windows, on an AMD Ryzen 9 9950X3D, 16 cores and 32 threads, 94 GB of memory, Windows 11 Pro 25H2, at Sergeant 0.2.8
(`8b174db`), with tsrs 7.1.0-beta.tsrs1, Bun 1.4.4 and the same six rounds. The harness
times Turborepo, Nx, Moon and Bazel only on Unix, so on Windows Sergeant is compared with
the direct tools alone. Every scheduler could use 32 threads, so these times do not compare
with the four-CPU Linux run above.

At 10,050 files Sergeant was faster than the direct tools on every warm and incremental
check, 7.4× to 26×, and on an unchanged test run and a leaf edit's tests, 3.6× and 4.0×. The
direct tools were faster on a cold check (968 ms, Sergeant 1.31 s), a cold test run (1.91 s,
Sergeant 6.92 s) and the tests after a shared edit (1.89 s, Sergeant 3.52 s). At 1,005 files
the direct tools were faster on every row but two: an unchanged check (Sergeant 102 ms,
direct 248 ms), and a function-body edit, where the interval includes parity.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 1.31 s | 40,200 of 40,200 | OXC, declarations, TSRS 968 ms | 0.74× [0.61, 0.83] |
| `check`, nothing changed | 231 ms | 0 of 40,200 | OXC, declarations, incremental TSRS 5.63 s | 24.68× [23.56, 28.85] |
| `check` after editing a shared file | 808 ms | 7,155 of 40,200 | OXC, declarations, incremental TSRS 5.90 s | 7.37× [6.55, 7.52] |
| `check` after editing inside a function of a shared file | 421 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 5.64 s | 13.38× [11.93, 13.72] |
| `check` after editing a leaf file | 430 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 5.57 s | 12.98× [12.00, 13.08] |
| the same, daemon running | 210 ms | 4 of 40,200 | OXC, declarations, incremental TSRS 5.55 s | 26.47× [24.86, 27.08] |
| `check` in a fresh checkout, cache shared | 243 ms | 0 of 40,200 | — | — |
| `test`, cold | 6.92 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 1.91 s | 0.27× [0.27, 0.29] |
| `test`, nothing changed | 494 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 1.78 s | 3.59× [3.46, 3.89] |
| `test` in a fresh checkout, cache shared | 539 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 3.52 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 1.89 s | 0.54× [0.39, 0.58] |
| `test` after editing a leaf file | 548 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 2.18 s | 3.95× [3.85, 4.05] |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-21 on an AMD Ryzen 9 9950X3D, 16 cores and 32 threads, 94 GB of memory, Windows 11 Pro 25H2 (32 available CPUs, job limit 32), source snapshot `8b174db65251193533cd67b406036d6690da4497`. Ratios divide the direct time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals.</sub>

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
