// Draws each edge in window.EDGES as a curve from one element to another, then marks the
// page ready for render.mjs. An edge is [from id, to id, class, sides], where sides is
// "rl" (from's right to to's left, the default), "lr", "bt", "tb", or "ll" and "rr" for
// a loop out of one side and back.
async function draw() {
  await document.fonts.ready;
  const frame = document.getElementById("frame");
  const box = frame.getBoundingClientRect();
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("class", "edges");
  const point = (el, side) => {
    const r = el.getBoundingClientRect();
    const x = { l: r.left, r: r.right, t: (r.left + r.right) / 2, b: (r.left + r.right) / 2 }[side];
    const y = { l: (r.top + r.bottom) / 2, r: (r.top + r.bottom) / 2, t: r.top, b: r.bottom }[side];
    return [x - box.left, y - box.top];
  };
  for (const [from, to, cls = "", sides = "rl"] of window.EDGES || []) {
    const a = point(document.getElementById(from), sides[0]);
    const b = point(document.getElementById(to), sides[1]);
    if (sides === "ll" || sides === "rr") {
      const out = sides === "ll" ? -28 : 28;
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("d", `M${a} C${[a[0] + out, a[1]]} ${[b[0] + out, b[1]]} ${b}`);
      path.setAttribute("class", cls);
      svg.appendChild(path);
      continue;
    }
    const horizontal = sides === "rl" || sides === "lr";
    const bend = horizontal ? Math.max(24, Math.abs(b[0] - a[0]) / 2) : Math.max(16, Math.abs(b[1] - a[1]) / 2);
    const sign = sides === "lr" || sides === "tb" ? -1 : 1;
    const c1 = horizontal ? [a[0] + bend * sign, a[1]] : [a[0], a[1] + bend * sign];
    const c2 = horizontal ? [b[0] - bend * sign, b[1]] : [b[0], b[1] - bend * sign];
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", `M${a} C${c1} ${c2} ${b}`);
    path.setAttribute("class", cls);
    svg.appendChild(path);
  }
  frame.appendChild(svg);
  document.body.dataset.ready = "1";
}
draw();
