# README assets

The banner and diagrams in the README are rendered from the pages in `src/`, so they draw
the same anywhere GitHub shows them and can be changed by editing HTML, not pixels.

```sh
cd assets
pnpm install --frozen-lockfile
pnpm exec playwright install chromium   # once, or set CHROMIUM to a Chromium you have
pnpm build                              # every image; `pnpm build agents` for one
```

Each page is rendered twice, for a light and a dark GitHub, as `<name>.png` and
`<name>-dark.png`, at twice its size. A page whose `<body>` has `data-variants="single"`
is rendered once. Fonts come from `node_modules`, pinned by `pnpm-lock.yaml`.

| Source | What it draws |
| --- | --- |
| `src/banner.html` | The banner. |
| `src/granularity.html` | Package-level against file-level reruns for one edit. |
| `src/how-it-works.html` | Edit, trace, key, then reuse or run sealed. |
| `src/agents.html` | Many worktrees sharing one machine, with the measured result. |
| `src/benchmarks.html` | The benchmark chart. Its numbers are in `src/benchmarks.js`. |
| `src/theme.css`, `src/diagram.js` | Colours, fonts, and the edges between boxes. |
