// The numbers the benchmark chart draws. Copied from the benchmark run named in `source`,
// never typed from memory: update them from a newer run, not by hand.
window.BENCHMARKS = {
  source: "Braden1996/sergeant benchmarks/results.json, 2026-11-16, commit 14224ab: 10,050 files in 250 units, medians on 2 cores of an AMD EPYC 7763, TypeScript 7.0.2",
  other: "tsc --incremental",
  rows: [
    { label: "Check after editing a leaf file", sgt: 0.296, other: 3.01 },
    { label: "Check, nothing changed", sgt: 0.174, other: 2.23 },
    { label: "Check after editing a shared file", sgt: 1.38, other: 3.93 },
  ],
};
