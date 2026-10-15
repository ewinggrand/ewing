import test from "node:test";
import assert from "node:assert/strict";
import { computeWinding, examples } from "../src/domain/winding.js";

const near = (actual, expected, tolerance = 1e-10) => {
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    `${actual} ≠ ${expected}`,
  );
};
const modulo = (value, modulus) => ((value % modulus) + modulus) % modulus;

function verifyActualWinding(result) {
  assert.equal(result.valid, true);
  assert.equal(result.balanced, true);
  assert.equal(result.coils.length, (result.slots * result.layers) / 2);
  assert.equal(result.slotLayers.length, result.slots * result.layers);
  const sides = new Map(
    result.slotLayers.map((side) => [`${side.slot}:${side.layer}`, side]),
  );
  assert.equal(
    sides.size,
    result.slots * result.layers,
    "Every slot/layer occurs exactly once",
  );
  const used = new Set();
  for (const coil of result.coils) {
    assert.notEqual(coil.positiveSlot, coil.negativeSlot);
    const distance = modulo(
      coil.negativeSlot - coil.positiveSlot,
      result.slots,
    );
    assert.equal(Math.min(distance, result.slots - distance), coil.span);
    assert.equal(
      modulo(coil.positiveSlot - 1 + coil.direction * coil.span, result.slots) +
        1,
      coil.negativeSlot,
    );
    for (const [slot, layer, sign] of [
      [coil.positiveSlot, coil.positiveLayer, 1],
      [coil.negativeSlot, coil.negativeLayer, -1],
    ]) {
      const key = `${slot}:${layer}`;
      assert.ok(!used.has(key), `Coil side ${key} used twice`);
      used.add(key);
      const side = sides.get(key);
      assert.ok(side, `Missing side ${key}`);
      assert.equal(side.phase, coil.phase);
      assert.equal(side.sign, sign);
    }
  }
  assert.equal(used.size, sides.size, "No unused coil sides");
  const [a, b, c] = result.phases;
  near(a.magnitude, b.magnitude, 1e-8);
  near(a.magnitude, c.magnitude, 1e-8);
  near(modulo(b.angleDeg - a.angleDeg, 360), 120, 1e-8);
  near(modulo(c.angleDeg - a.angleDeg, 360), 240, 1e-8);
  for (const phase of result.phases) {
    const actualSides = result.slotLayers.filter(
      (side) => side.phase === phase.phase,
    );
    near(
      phase.x,
      actualSides.reduce(
        (sum, side) =>
          sum + side.sign * Math.cos((side.angleDeg * Math.PI) / 180),
        0,
      ),
      1e-8,
    );
    near(
      phase.y,
      actualSides.reduce(
        (sum, side) =>
          sum + side.sign * Math.sin((side.angleDeg * Math.PI) / 180),
        0,
      ),
      1e-8,
    );
    near(phase.kw, phase.magnitude / actualSides.length);
    assert.equal(phase.positiveSlots.length, phase.negativeSlots.length);
    assert.ok(phase.kw > 0 && phase.kw <= 1 + 1e-10);
  }
  near(
    result.harmonics.find((harmonic) => harmonic.order === 1).factor,
    result.metrics.kw,
  );
}

test("PowerPoint reference: 12 slots, 1 pole pair, natural zones and full-pitch single layer", () => {
  const result = computeWinding({
    slots: 12,
    polePairs: 1,
    layers: 1,
    coilSpan: 6,
  });
  assert.deepEqual(
    result.slotAssignments.map((side) => side.zone),
    ["+A", "+A", "−C", "−C", "+B", "+B", "−A", "−A", "+C", "+C", "−B", "−B"],
  );
  near(result.q, 2);
  near(result.alphaDeg, 30);
  near(result.zoneOffsetDeg, -15);
  near(result.polePitch, 6);
  near(result.metrics.kw, Math.cos(Math.PI / 12));
  near(result.phases[0].angleDeg, 15);
  verifyActualWinding(result);
});

test("Single-layer automatic selection pairs every side and shortens equal-kw windings", () => {
  const result = computeWinding({ slots: 12, polePairs: 1 });
  assert.equal(result.coilSpan, 5);
  verifyActualWinding(result);
  const shorter = [1, 2, 3, 4].map((coilSpan) =>
    computeWinding({ slots: 12, polePairs: 1, coilSpan }),
  );
  assert.ok(
    shorter.every(
      (candidate) => !candidate.valid && candidate.coils.length === 0,
    ),
  );
  const reference = computeWinding({ slots: 12, polePairs: 1, coilSpan: 6 });
  near(result.metrics.kw, reference.metrics.kw);
});

test("Double-layer sums both actual layers and reproduces pitch factors", () => {
  const full = computeWinding({
    slots: 12,
    polePairs: 1,
    layers: 2,
    coilSpan: 6,
  });
  const short = computeWinding({
    slots: 12,
    polePairs: 1,
    layers: 2,
    coilSpan: 5,
  });
  near(full.metrics.kw, Math.cos(Math.PI / 12));
  near(short.metrics.kw, Math.cos(Math.PI / 12) ** 2);
  assert.equal(full.phases[0].sideCount, 8);
  for (const result of [full, short]) {
    verifyActualWinding(result);
    for (const coil of result.coils)
      assert.notEqual(coil.positiveLayer, coil.negativeLayer);
  }
  // The sehned coil also rotates the resultant; keeping only the upper layer
  // would incorrectly leave the phase A angle at 15°.
  near(short.phases[0].angleDeg, 0);
});

test("Fractional-slot fixtures have known fundamental winding factors", () => {
  for (const [parameters, expectedFactor] of [
    [{ slots: 12, polePairs: 5, layers: 1 }, Math.cos(Math.PI / 12)],
    [{ slots: 12, polePairs: 5, layers: 2 }, 0.9330127018922193],
    [{ slots: 9, polePairs: 4, layers: 2 }, 0.9452136366029515],
    [{ slots: 36, polePairs: 2, layers: 1 }, 0.9597950805239389],
  ]) {
    const result = computeWinding(parameters);
    near(result.metrics.kw, expectedFactor);
    verifyActualWinding(result);
  }
});

test("A symmetric voltage star alone does not prove single-layer pairability", () => {
  const unpairable = computeWinding({ slots: 18, polePairs: 2, layers: 1 });
  assert.equal(unpairable.balanced, true);
  assert.equal(unpairable.valid, false);
  assert.deepEqual(unpairable.coils, []);
  assert.match(unpairable.warnings.join(" "), /Andere Zonungen/);
  assert.equal(
    computeWinding({ slots: 18, polePairs: 2, layers: 2 }).valid,
    true,
  );
});

test("Unsupported zones, odd single layer, and a zero-pitch-factor result never invent coils", () => {
  for (const parameters of [
    { slots: 9, polePairs: 4, layers: 1 },
    { slots: 12, polePairs: 3, layers: 1 },
    { slots: 12, polePairs: 3, layers: 2 },
    { slots: 6, polePairs: 2, layers: 1 },
    { slots: 12, polePairs: 2, layers: 2, coilSpan: 6 },
  ]) {
    const result = computeWinding(parameters);
    assert.equal(result.valid, false, JSON.stringify(parameters));
    assert.deepEqual(result.coils, []);
    assert.equal(result.metrics.coilCount, 0);
    assert.ok(result.warnings.length > 0);
  }
});

test("Bad values fail with a readable input error", () => {
  for (const parameters of [
    {},
    { slots: 5, polePairs: 1 },
    { slots: 121, polePairs: 1 },
    { slots: 12.5, polePairs: 1 },
    { slots: "12", polePairs: 1 },
    { slots: 12, polePairs: 0 },
    { slots: 12, polePairs: 7 },
    { slots: 12, polePairs: 1, layers: 3 },
    { slots: 12, polePairs: 1, coilSpan: 0 },
    { slots: 12, polePairs: 1, coilSpan: 7 },
    { slots: 12, polePairs: NaN },
  ])
    assert.throws(() => computeWinding(parameters), /muss eine ganze Zahl/);
});

test("Every provided example constructs a complete winding", () => {
  for (const example of examples) verifyActualWinding(computeWinding(example));
});

test("Representative range: complete side use, balanced phase stars and scoped automatic maximum", () => {
  for (const slots of [
    6, 9, 12, 15, 18, 21, 24, 27, 30, 36, 48, 60, 72, 96, 120,
  ]) {
    for (const polePairs of [
      ...new Set([1, 2, 3, 4, 5, Math.floor(slots / 2)]),
    ].filter((p) => p <= slots / 2)) {
      for (const layers of [1, 2]) {
        const result = computeWinding({ slots, polePairs, layers });
        if (!result.valid) {
          assert.deepEqual(result.coils, []);
          continue;
        }
        verifyActualWinding(result);
        for (
          let coilSpan = 1;
          coilSpan <=
          Math.min(Math.ceil(result.polePitch), Math.floor(slots / 2));
          coilSpan += 1
        ) {
          const candidate = computeWinding({
            slots,
            polePairs,
            layers,
            coilSpan,
          });
          if (!candidate.valid) continue;
          assert.ok(result.metrics.kw >= candidate.metrics.kw - 1e-9);
          if (Math.abs(result.metrics.kw - candidate.metrics.kw) < 1e-9)
            assert.ok(result.coilSpan <= coilSpan);
        }
      }
    }
  }
});
