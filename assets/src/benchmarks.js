// The numbers the benchmark chart draws. Copied from the benchmark run named in `source`,
// never typed from memory: update them from a newer run, not by hand.
window.BENCHMARKS = {
  source: "Braden1996/sergeant benchmarks/results.json, 2026-11-17, commit 78e4e10: 10,050 files in 250 units, medians on 4 cores of an Intel Xeon @ 2.30GHz, tsrs 7.1.0-beta.tsrs1",
  other: "the same tools, run plainly",
  rows: [
    { label: "Check after editing a leaf file", sgt: 0.2048, other: 0.6289 },
    { label: "Check, nothing changed", sgt: 0.1535, other: 0.5727 },
    { label: "Check after editing a shared file", sgt: 0.5508, other: 1.0549 },
  ],
};
