import test from "node:test";
import assert from "node:assert/strict";
import { computeWinding } from "../src/domain/winding.js";
import { computeSpectrum } from "../src/domain/spectrum.js";
import {
  buildWindingLayout,
  splitPeriodicPolyline,
} from "../src/domain/windingLayout.js";
const near = (a, b, tolerance = 1e-8) =>
  assert.ok(Math.abs(a - b) < tolerance, `${a} ≠ ${b}`);

function verifySeriesGraph(layout, winding) {
  const nodes = new Map(layout.topology.nodes.map((node) => [node.id, node]));
  assert.equal(nodes.size, winding.slots * winding.layers);
  const incoming = new Map();
  const outgoing = new Map();
  for (const edge of layout.topology.edges) {
    assert.equal(nodes.get(edge.from).phase, edge.phase);
    assert.equal(nodes.get(edge.to).phase, edge.phase);
    assert.notEqual(edge.from, edge.to);
    assert.ok(!outgoing.has(edge.from), "No branch or short circuit");
    assert.ok(!incoming.has(edge.to), "No branch or short circuit");
    outgoing.set(edge.from, edge);
    incoming.set(edge.to, edge);
    if (edge.type === "coil") {
      assert.equal(nodes.get(edge.from).sign, 1);
      assert.equal(nodes.get(edge.to).sign, -1);
    } else {
      assert.equal(nodes.get(edge.from).sign, -1);
      assert.equal(nodes.get(edge.to).sign, 1);
    }
  }
  const visited = new Set();
  for (const chain of layout.topology.phaseChains) {
    assert.ok(!incoming.has(chain.startNodeId));
    assert.ok(!outgoing.has(chain.endNodeId));
    let nodeId = chain.startNodeId;
    let coilCount = 0;
    while (nodeId) {
      assert.ok(!visited.has(nodeId), "No cycle and no shared side");
      visited.add(nodeId);
      const edge = outgoing.get(nodeId);
      if (edge?.type === "coil") coilCount += 1;
      if (!edge) {
        assert.equal(nodeId, chain.endNodeId);
        break;
      }
      nodeId = edge.to;
    }
    assert.equal(coilCount, chain.coilIds.length);
  }
  assert.equal(
    visited.size,
    nodes.size,
    "All coil sides belong to an open additive chain",
  );
  assert.equal(layout.terminals.length, layout.topology.phaseChains.length * 2);
}

function verifyGeometry(layout, winding) {
  const shownSides = layout.slots.flatMap((slot) => slot.sides);
  assert.equal(shownSides.length, winding.slotLayers.length);
  assert.equal(
    new Set(shownSides.map((side) => side.nodeId)).size,
    shownSides.length,
  );
  for (const slot of layout.slots) {
    for (const side of slot.sides) {
      assert.equal(side.slot, slot.slot);
      assert.ok(Math.abs(side.x - slot.x) < layout.geometry.slotGap / 2);
      assert.ok(
        layout.teeth.every(
          (tooth) => side.x <= tooth.x || side.x >= tooth.x + tooth.width,
        ),
        "Conductors lie between teeth, never inside blue iron",
      );
      assert.ok(
        winding.slotLayers.some(
          (original) =>
            original.slot === side.slot &&
            original.layer === side.layer &&
            original.phase === side.phase &&
            original.sign === side.sign,
        ),
      );
    }
  }
  for (const coil of layout.coilPaths) {
    assert.notEqual(
      coil.positivePort.x,
      coil.negativePort.x,
      "Bottom coil heads remain open",
    );
    for (const path of [...coil.topPaths, ...coil.bottomPaths]) {
      for (const p of path.points)
        assert.ok(
          p.x >= layout.geometry.seamLeft - 1e-8 &&
            p.x <= layout.geometry.seamRight + 1e-8,
        );
      for (let index = 1; index < path.points.length; index += 1) {
        const a = path.points[index - 1];
        const b = path.points[index];
        near(Math.abs((b.y - a.y) / (b.x - a.x)), coil.headSlope);
      }
    }
  }
  const horizontal = layout.connections.flatMap((connection) =>
    connection.paths.flatMap((path) =>
      path.points.slice(1).flatMap((b, index) => {
        const a = path.points[index];
        return Math.abs(a.y - b.y) < 1e-8 && Math.abs(a.x - b.x) > 1e-8
          ? [
              {
                id: connection.id,
                y: a.y,
                min: Math.min(a.x, b.x),
                max: Math.max(a.x, b.x),
              },
            ]
          : [];
      }),
    ),
  );
  for (let i = 0; i < horizontal.length; i += 1)
    for (let j = i + 1; j < horizontal.length; j += 1) {
      const a = horizontal[i];
      const b = horizontal[j];
      if (a.id === b.id || Math.abs(a.y - b.y) > 1e-8) continue;
      assert.ok(
        Math.min(a.max, b.max) - Math.max(a.min, b.min) <= 1e-8,
        "Different electrical links cannot share a collinear conductor segment",
      );
    }
}

test("Q9/p4 two-layer tooth coils: contiguous A/B/C groups, real slot numbers and 18 unique sides", () => {
  const winding = computeWinding({ slots: 9, polePairs: 4, layers: 2 });
  const beforeWinding = JSON.stringify(winding);
  const beforeSpectrum = JSON.stringify(computeSpectrum(winding));
  const layout = buildWindingLayout(winding);
  assert.equal(layout.startSlot, 9);
  assert.deepEqual(
    layout.slots.map((slot) => slot.slot),
    [9, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  );
  assert.deepEqual(
    layout.coilPaths.map((coil) => coil.id),
    ["A9", "A1", "A2", "B3", "B4", "B5", "C6", "C7", "C8"],
  );
  assert.deepEqual(
    layout.coilPaths.map((coil) => coil.direction),
    [-1, 1, -1, -1, 1, -1, -1, 1, -1],
  );
  assert.deepEqual(
    layout.groups.map((group) => group.phase),
    ["A", "B", "C"],
  );
  assert.equal(layout.teeth.length, 9);
  assert.deepEqual(
    layout.slots[0].sides.map((side) => side.layer),
    [1],
  );
  assert.deepEqual(
    layout.slots.at(-1).sides.map((side) => side.layer),
    [2],
  );
  assert.ok(
    layout.coilPaths.every(
      (coil) =>
        !coil.wrapped &&
        coil.topPaths.length === 1 &&
        coil.bottomPaths.length === 2,
    ),
  );
  assert.deepEqual(
    layout.terminals.map((terminal) => [
      terminal.label,
      terminal.slot,
      terminal.layer,
    ]),
    [
      ["U1", 1, 2],
      ["U2", 2, 1],
      ["V1", 4, 2],
      ["V2", 5, 1],
      ["W1", 7, 2],
      ["W2", 8, 1],
    ],
  );
  assert.equal(layout.connections.length, 6);
  assert.deepEqual(
    layout.connections.map((connection) => connection.routeLane),
    [0, 1, 0, 1, 0, 1],
  );
  for (const connection of layout.connections) {
    assert.ok(connection.groupId);
    const group = layout.groups.find((item) => item.id === connection.groupId);
    for (const path of connection.paths)
      for (const p of path.points)
        assert.ok(
          p.x >= group.startX && p.x <= group.endX,
          "Local group connection, no global terminal rail",
        );
  }
  verifySeriesGraph(layout, winding);
  verifyGeometry(layout, winding);
  assert.equal(JSON.stringify(winding), beforeWinding);
  assert.equal(JSON.stringify(computeSpectrum(winding)), beforeSpectrum);
  assert.doesNotThrow(() => JSON.stringify(layout));
});

test("Changing the display cut preserves canonical series chains, terminal nodes and edge order", () => {
  const winding = computeWinding({ slots: 9, polePairs: 4, layers: 2 });
  const canonical = buildWindingLayout(winding);
  const terminals = (layout) =>
    layout.terminals.map(({ label, nodeId, coilId, slot, layer }) => ({
      label,
      nodeId,
      coilId,
      slot,
      layer,
    }));
  for (let startSlot = 1; startSlot <= 9; startSlot += 1) {
    const layout = buildWindingLayout(winding, { startSlot });
    assert.equal(layout.startSlot, startSlot);
    assert.equal(layout.canonicalStartSlot, 9);
    assert.deepEqual(layout.topology, canonical.topology);
    assert.deepEqual(terminals(layout), terminals(canonical));
    assert.deepEqual(
      layout.orderedCoils.map((coil) => coil.id),
      canonical.orderedCoils.map((coil) => coil.id),
    );
    verifySeriesGraph(layout, winding);
    verifyGeometry(layout, winding);
  }
});

test("Periodic clipping uses true intersection heights, including diagonal non-midpoint cuts", () => {
  const paths = splitPeriodicPolyline(
    [
      { x: 90, y: 10 },
      { x: 130, y: 50 },
    ],
    0,
    100,
  );
  assert.deepEqual(
    paths.map((path) => path.points),
    [
      [
        { x: 90, y: 10 },
        { x: 100, y: 20 },
      ],
      [
        { x: 0, y: 20 },
        { x: 30, y: 50 },
      ],
    ],
  );
  const reverse = splitPeriodicPolyline(
    [
      { x: 20, y: 10 },
      { x: -20, y: 50 },
    ],
    0,
    100,
  );
  near(reverse[0].points.at(-1).y, 30);
  near(reverse[1].points[0].y, 30);
  near(reverse[0].points.at(-1).x, 0);
  near(reverse[1].points[0].x, 100);
});

test("Distributed layouts use constant head slope, correct wraps, one chain per phase and all layers", () => {
  for (const parameters of [
    { slots: 12, polePairs: 1, layers: 1, coilSpan: 6 },
    { slots: 12, polePairs: 1, layers: 2, coilSpan: 5 },
    { slots: 36, polePairs: 2, layers: 1 },
    { slots: 12, polePairs: 5, layers: 2 },
    { slots: 120, polePairs: 50, layers: 2 },
  ]) {
    const winding = computeWinding(parameters);
    for (const startSlot of ["auto", 1, winding.slots]) {
      const layout = buildWindingLayout(winding, { startSlot });
      assert.equal(layout.valid, true);
      assert.equal(layout.topology.phaseChains.length, 3);
      assert.equal(layout.terminals.length, 6);
      assert.equal(layout.connections.length, winding.coils.length - 3);
      verifySeriesGraph(layout, winding);
      verifyGeometry(layout, winding);
      for (const connection of layout.connections) {
        const from = layout.coilPaths.find(
          (coil) => coil.id === connection.fromCoilId,
        );
        const to = layout.coilPaths.find(
          (coil) => coil.id === connection.toCoilId,
        );
        assert.equal(connection.fromNode, from.negativeSide.nodeId);
        assert.equal(connection.toNode, to.positiveSide.nodeId);
      }
    }
  }
});

test("Individual coils have two open terminals each and no inter-coil connection", () => {
  const winding = computeWinding({ slots: 9, polePairs: 4, layers: 2 });
  const layout = buildWindingLayout(winding, {
    connectionMode: "individual",
    startSlot: 1,
  });
  assert.equal(layout.startSlot, 1);
  assert.equal(layout.connections.length, 0);
  assert.equal(layout.terminals.length, 18);
  assert.equal(layout.topology.phaseChains.length, 9);
  verifySeriesGraph(layout, winding);
  verifyGeometry(layout, winding);
});

test("Invalid inputs never fabricate diagram conductors", () => {
  const invalid = buildWindingLayout(
    computeWinding({ slots: 18, polePairs: 2, layers: 1 }),
  );
  assert.equal(invalid.valid, false);
  assert.deepEqual(invalid.coilPaths, []);
  assert.deepEqual(invalid.topology.edges, []);
  assert.throws(
    () =>
      buildWindingLayout(computeWinding({ slots: 12, polePairs: 1 }), {
        startSlot: 13,
      }),
    /Schnittnut/,
  );
  assert.throws(
    () => buildWindingLayout(undefined, { connectionMode: "closed" }),
    /Verbindungsart/,
  );
});
