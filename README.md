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

**Adopt any repository.** `sgt init` detects existing monorepo layouts (`package.json`
workspaces, workspace YAML, or existing directories) and writes an adoptable
`.sergeant/config.toml`. Tune rules workspace-wide under `[rules]`, override them per package in
`<unit>/sergeant.toml` or `package.json`, and let tests that touch host state degrade cleanly to
live uncached runs rather than blocking adoption.

**Your frameworks, your versions.** Dedicated integrations handle TypeScript, Bun, Luau, Rust,
Rsbuild, Electron, Vite, WXT, Cloudflare, Pulumi, Tauri and Astro using the packages and versions
pinned in your workspace.

**One binary, zero config.** The formatter, linter and TypeScript checker are built in. A
package's kind comes from its layout, so packages carry no tsconfig, ESLint or bundler config.

**No silent escape hatches.** `@ts-ignore` and `eslint-disable` are caught by default, existing
problems go in a baseline that can only shrink, and workspace or per-unit `[rules]` let teams
relax individual checks explicitly.

**Made for agents.** Every command speaks JSON, `sgt mcp` serves them all to any agent,
`sgt worktree` gives each agent its own checkout over one shared cache, and `sgt daemon status`
and `sgt daemon log` expose live work and bounded subprocess timeouts so nothing hangs silently.

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

Adopt an existing repository:

```sh
sgt init                                # detects workspace layout and writes .sergeant/config.toml
sgt check && sgt test
```

Or start a new one:

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
sources, with tsrs 7.1.0-beta.tsrs1 for checks and Bun 1.4.4 for tests. Two CPUs were
available and each scheduler could use two threads. Every row is the median of six rounds,
measured 2026-11-21 on two CPUs of an AMD EPYC 9V45 (Linux 7.0.0), at Sergeant 0.3.0,
source snapshot `176b920`. Each ratio has a 95% interval.

On the 1,005-file half (25 units, 200 tests, the same six rounds and the same machine),
Sergeant had the lowest median of the build systems on all six check workloads and on two of
the five test workloads, a test after a shared edit (293 ms, Turborepo 492 ms) and after a
leaf edit (88 ms, Turborepo 106 ms). Turborepo was lower on the other three: a cold test
(462 ms, Sergeant 551 ms), an unchanged one (70 ms, 85 ms) and a fresh checkout (75 ms,
102 ms). Counting the direct tools, the lowest median was Sergeant's on seven rows, the
direct tools' on two and Turborepo's on two. A cold check took 167 ms in the direct tools
and 155 ms in Sergeant, and that interval includes parity. A cold test took 129 ms in direct
Bun and 551 ms in Sergeant.

A separate measurement, inside Sergeant, compares typechecks kept under a file's declarations
with typechecks kept under the whole file. Seven paired rounds, one CPU of the same runner
(Linux 7.0.0), snapshot `176b920`.

After a function-body edit, Sergeant checked 1 diagnostic root with verified declarations (median 47.8 ms) and 6 diagnostic roots with full-content keys (median 72.4 ms). Full-content time divided by declaration time was 1.51× (paired 95% CI 1.48–1.57). The interval included 1 for cold runs (0.99×), warm runs (0.96×) and an added public export (0.99×).

The fixed-work timings, one identical worker through every system, wait on a runner that can
seal Sergeant's actions.

| State | Direct worker | Sergeant action | Nx task | Turbo task | Moon task | Bazel target |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold | 179 ms | 361 ms (2.02×, 1.99–2.06) | 1193 ms (6.58×, 6.52–7.10) | 259 ms (1.43×, 1.42–1.48) | 454 ms (2.53×, 2.40–2.61) | 5061 ms (28.49×, 27.88–29.55) |
| warm | 177 ms | 29 ms (0.16×, 0.15–0.18) | 965 ms (5.44×, 5.30–5.46) | 70 ms (0.39×, 0.39–0.41) | 253 ms (1.42×, 1.41–1.45) | 3908 ms (21.87×, 21.70–22.20) |
| edited | 181 ms | 370 ms (2.05×, 2.03–2.09) | 1187 ms (6.57×, 6.44–6.63) | 268 ms (1.48×, 1.45–1.49) | 457 ms (2.53×, 2.52–2.55) | 4275 ms (23.43×, 23.27–23.85) |

1,005 diagnostic roots, 1 CPU(s), commit `176b92024c00`. Ratios give orchestrated time divided by direct time with paired 95% bootstrap intervals.

### Ten thousand files

The tables are the 10,050-file half of the run above (250 units, 2,000 tests). A shared edit
and a leaf edit each add an unused export. Before a row is timed, each configured system has
to catch a type error and a failing test. The daemon row sits outside both counts below.
On this half Sergeant had the lowest build-system median
on all 11 workloads in the second table. One interval includes parity: a test in a fresh
checkout (261 ms, Turborepo 571 ms). Counting the direct tools, Sergeant led eight rows and
the direct tools three: a cold check (929 ms, Sergeant 1.01 s, where the interval includes
parity), a cold test (1.25 s, Sergeant 3.43 s) and a test after a shared edit (1.64 s,
Sergeant 1.94 s).

With no edits, Sergeant reused all 40,201 check results in 126 ms, versus 6.54 s for the direct pipeline with incremental TSRS. Sergeant reused results for all 2,000 test files in 136 ms, while direct Bun ran those files in 1.26 s. Times are medians.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 1.01 s | 40,201 of 40,201 | OXC, declarations, TSRS 929 ms | 0.91× [0.86, 1.32], inconclusive |
| `check`, nothing changed | 126 ms | 0 of 40,201 | OXC, declarations, incremental TSRS 6.54 s | 51.24× [44.74, 60.49] |
| `check` after editing a shared file | 620 ms | 7,155 of 40,201 | OXC, declarations, incremental TSRS 6.95 s | 11.25× [10.51, 12.59] |
| `check` after editing inside a function of a shared file | 184 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 6.53 s | 36.14× [30.44, 38.78] |
| `check` after editing a leaf file | 179 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 6.47 s | 36.33× [33.98, 37.79] |
| the same, daemon running | 186 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 6.50 s | 35.01× [33.94, 36.22] |
| `check` in a fresh checkout, cache shared | 205 ms | 0 of 40,201 | — | — |
| `test`, cold | 3.43 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 1.25 s | 0.37× [0.35, 0.39] |
| `test`, nothing changed | 136 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 1.26 s | 9.38× [5.86, 9.78] |
| `test` in a fresh checkout, cache shared | 261 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 1.94 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 1.64 s | 0.73× [0.71, 0.94] |
| `test` after editing a leaf file | 146 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 1.45 s | 9.85× [8.61, 10.36] |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-21 on AMD EPYC 9V45 96-Core Processor (2 available CPUs, Linux 7.0.0-1017-azure, job limit 2), source snapshot `176b92024c00dafa7233d575af93b9f0983b6446`. Check arms use tsrs 7.1.0-beta.tsrs1 and test arms use Bun 1.4.4 with isolation. Ratios divide each comparison time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds.</sub>

| Situation | Sergeant | Turborepo | Nx | Moon | Bazel |
| --- | ---: | ---: | ---: | ---: | ---: |
| `check`, cold | 1.01 s | 21.20 s<br><sub>20.80× [20.06, 21.44]</sub> | 50.45 s<br><sub>50.12× [46.76, 50.65]</sub> | 27.81 s<br><sub>27.65× [26.26, 27.96]</sub> | 33.66 s<br><sub>33.05× [32.43, 33.69]</sub> |
| `check`, nothing changed | 126 ms | 242 ms<br><sub>1.89× [1.64, 2.49]</sub> | 771 ms<br><sub>6.19× [5.25, 6.77]</sub> | 7.58 s<br><sub>59.68× [53.11, 61.60]</sub> | 339 ms<br><sub>2.65× [2.08, 4.10]</sub> |
| `check` after editing a shared file | 620 ms | 22.57 s<br><sub>36.77× [35.69, 41.90]</sub> | 52.99 s<br><sub>84.53× [82.44, 98.53]</sub> | 29.15 s<br><sub>46.61× [45.42, 52.61]</sub> | 26.12 s<br><sub>41.99× [41.28, 50.35]</sub> |
| `check` after editing inside a function of a shared file | 184 ms | 21.02 s<br><sub>119.80× [100.99, 127.76]</sub> | 51.13 s<br><sub>282.11× [241.51, 305.90]</sub> | 28.52 s<br><sub>156.16× [132.15, 171.61]</sub> | 25.07 s<br><sub>141.38× [119.55, 160.66]</sub> |
| `check` after editing a leaf file | 179 ms | 378 ms<br><sub>2.14× [2.10, 2.28]</sub> | 1.06 s<br><sub>6.01× [5.54, 6.16]</sub> | 8.02 s<br><sub>44.87× [42.39, 47.07]</sub> | 504 ms<br><sub>2.86× [2.56, 4.05]</sub> |
| `check` in a fresh checkout, cache shared | 205 ms | 510 ms<br><sub>2.49× [2.34, 2.75]</sub> | — | — | 9.26 s<br><sub>44.58× [43.67, 52.10]</sub> |
| `test`, cold | 3.43 s | 5.02 s<br><sub>1.46× [1.36, 1.50]</sub> | 34.68 s<br><sub>10.14× [9.45, 10.87]</sub> | 18.06 s<br><sub>5.23× [4.85, 5.81]</sub> | 48.43 s<br><sub>14.04× [13.61, 15.19]</sub> |
| `test`, nothing changed | 136 ms | 240 ms<br><sub>1.79× [1.42, 1.93]</sub> | 825 ms<br><sub>5.84× [4.12, 6.10]</sub> | 8.17 s<br><sub>58.32× [39.00, 61.01]</sub> | 545 ms<br><sub>3.86× [2.85, 4.52]</sub> |
| `test` in a fresh checkout, cache shared | 261 ms | 571 ms<br><sub>2.23× [0.89, 2.84], inconclusive</sub> | — | — | 48.15 s<br><sub>183.28× [77.79, 202.42]</sub> |
| `test` after editing a shared file | 1.94 s | 5.61 s<br><sub>2.93× [2.38, 2.96]</sub> | 36.99 s<br><sub>19.04× [14.95, 20.52]</sub> | 18.99 s<br><sub>9.84× [7.61, 10.58]</sub> | 23.29 s<br><sub>11.62× [9.59, 12.61]</sub> |
| `test` after editing a leaf file | 146 ms | 305 ms<br><sub>2.11× [1.81, 2.19]</sub> | 1.14 s<br><sub>7.36× [6.89, 8.23]</sub> | 9.50 s<br><sub>65.06× [56.20, 69.08]</sub> | 706 ms<br><sub>4.88× [4.23, 6.59]</sub> |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-21 on AMD EPYC 9V45 96-Core Processor (2 available CPUs, Linux 7.0.0-1017-azure, job limit 2), source snapshot `176b92024c00dafa7233d575af93b9f0983b6446`. Build systems measured include Turborepo 2.11.11, Nx 24.0.6, Moon 2.6.5 and Bazel 9.3.2. Package checks use tsrs 7.1.0-beta.tsrs1 and isolated tests use Bun 1.4.4. Ratios divide each comparison time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals. The inconclusive label uses the unrounded bounds. A dash marks an unmeasured arm.</sub>

### Windows

The same harness ran natively on Windows, on an AMD Ryzen 9 9950X3D, 16 cores and 32 threads, 94 GB of memory, Windows 11 Pro 25H2, at
`9ad3908`, with tsrs 7.1.0-beta.tsrs1, Bun 1.4.4 and the same six rounds. The harness
times Turborepo, Nx, Moon and Bazel only on Unix, so on Windows Sergeant is compared with
the direct tools alone. Every scheduler could use 32 threads, so these times do not compare
with the two-CPU Linux run above.

At 10,050 files Sergeant was faster than the direct tools on every warm and incremental
check, 7.9× to 28×, and on an unchanged test run and a leaf edit's tests, 5.6× and 2.5×. The
direct tools were faster on a cold check (564 ms, Sergeant 1.09 s), a cold test run (2.39 s,
Sergeant 9.83 s) and the tests after a shared edit (2.05 s, Sergeant 5.24 s). At 1,005 files
Sergeant was faster on an unchanged check (81 ms, direct 169 ms, 2.09×), and the direct tools
were faster on the remaining rows.

| Situation | Sergeant | Work redone | Direct tool and time | Direct / Sergeant |
| --- | ---: | ---: | --- | ---: |
| `check`, cold | 1.09 s | 40,201 of 40,201 | OXC, declarations, TSRS 564 ms | 0.53× [0.48, 0.58] |
| `check`, nothing changed | 633 ms | 0 of 40,201 | OXC, declarations, incremental TSRS 11.81 s | 18.40× [9.30, 22.28] |
| `check` after editing a shared file | 1.67 s | 7,155 of 40,201 | OXC, declarations, incremental TSRS 13.44 s | 7.94× [6.58, 9.74] |
| `check` after editing inside a function of a shared file | 777 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 12.11 s | 16.17× [14.25, 18.32] |
| `check` after editing a leaf file | 531 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 7.37 s | 13.83× [13.30, 14.30] |
| the same, daemon running | 447 ms | 4 of 40,201 | OXC, declarations, incremental TSRS 13.50 s | 27.85× [18.70, 39.42] |
| `check` in a fresh checkout, cache shared | 546 ms | 0 of 40,201 | — | — |
| `test`, cold | 9.83 s | 2,000 of 2,000 | `bun test --isolate` (all 2,000) 2.39 s | 0.26× [0.20, 0.33] |
| `test`, nothing changed | 713 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 3.99 s | 5.59× [4.54, 7.95] |
| `test` in a fresh checkout, cache shared | 734 ms | 0 of 2,000 | — | — |
| `test` after editing a shared file | 5.24 s | 685 of 2,000 | `bun test --isolate` (all 2,000) 2.05 s | 0.40× [0.37, 0.43] |
| `test` after editing a leaf file | 751 ms | 0 of 2,000 | `bun test --isolate` (all 2,000) 1.83 s | 2.45× [2.26, 2.52] |

<sub>10,050 files in 250 units. Median elapsed times across 6 rounds (6 cold). Measured 2026-11-21 on an AMD Ryzen 9 9950X3D, 16 cores and 32 threads, 94 GB of memory, Windows 11 Pro 25H2 (32 available CPUs, job limit 32), source snapshot `9ad3908c7be1cbc2b05af826d261c379aa093030`. Ratios divide the direct time by Sergeant’s time in the same round and take the median on a log scale. Above 1× means Sergeant took less time. Brackets show 95% bootstrap intervals.</sub>

## What it supports

| | |
| --- | --- |
| **TypeScript** | Libraries, Bun services, React/Rsbuild pages, Vite, Astro, Electron, WXT, Cloudflare, Pulumi and Tauri. A check or a test is cached per file. |
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
| `SGT_VERSION` | The release to install, as its tag: `v0.4.0`. Left out, the latest. |
| `SGT_INSTALL` | The directory `sgt` goes in. Left out, `~/.local/bin`. |
| `SGT_FROM` | An address that holds the archives in place of GitHub: a mirror or a bucket. |

In CI or a container, pin the version:

```sh
curl -fsSL https://raw.githubusercontent.com/Braden1996/sergeant-releases/main/install.sh | SGT_VERSION=v0.4.0 sh
```

---

This repository holds releases only; Sergeant's source is not public yet. It builds on
[oxc](https://oxc.rs), the TypeScript checker,
[StyLua](https://github.com/JohnnyMorganz/StyLua), [selene](https://github.com/Kampfkarren/selene),
[Lune](https://github.com/lune-org/lune), [Bun](https://bun.sh), [Vitest](https://vitest.dev),
[Playwright](https://playwright.dev), [Rsbuild](https://rsbuild.dev) and [pnpm](https://pnpm.io),
and on ideas from [Bazel](https://bazel.build) and [Buck2](https://buck2.build). Diagrams in
[`assets/`](assets/README.md) are rendered from HTML.
