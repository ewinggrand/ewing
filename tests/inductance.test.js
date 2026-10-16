import test from "node:test";
import assert from "node:assert/strict";
import { computeWinding, examples } from "../src/domain/winding.js";
import { computeSpectrum } from "../src/domain/spectrum.js";
import { computeInductance, MU0 } from "../src/domain/inductance.js";

const PHASES = ["A", "B", "C"];
const TWO_PI = 2 * Math.PI;
const modulo = (value, period) => ((value % period) + period) % period;
const near = (actual, expected, tolerance = 1e-10) => {
  assert.ok(Math.abs(actual - expected) <= tolerance, `${actual} ≠ ${expected}`);
};
const reference = () => computeWinding({ slots: 12, polePairs: 1, layers: 1, coilSpan: 6 });

/** Three abstract test coils: A, B at +90°, C at +180° (not a machine design). */
function coilFixture(span = 6) {
  const coils = PHASES.map((phase, index) => ({
    id: `${phase}1`, phase, positiveSlot: 1 + 3 * index,
    negativeSlot: modulo(3 * index + span, 12) + 1,
    span, direction: 1, positiveLayer: phase === "C" ? 2 : 1,
    negativeLayer: phase === "C" ? 2 : 1,
  }));
  return {
    valid: true, slots: 12, polePairs: 1, polePitch: 6, layers: 2, coils,
    slotLayers: coils.flatMap((coil) => [
      { slot: coil.positiveSlot, layer: coil.positiveLayer, sign: 1, phase: coil.phase },
      { slot: coil.negativeSlot, layer: coil.negativeLayer, sign: -1, phase: coil.phase },
    ]),
  };
}

test("Full-pitch ideal coil matches the slide's infinite series and exact rectangular integral", () => {
  const data = computeInductance(coilFixture());
  assert.equal(data.valid, true);
  const { radiusM, lengthM, gapM, turnsPerCoil } = data.parameters;
  const expected = MU0 * radiusM * lengthM * turnsPerCoil ** 2 * Math.PI / (2 * gapM);
  near(data.matrixH[0][0], expected, 1e-16);
  near(data.matrixH[0][1], 0, 1e-16);
  near(data.matrixH[0][2], -expected, 1e-16);
  // Sum sin²(k*pi/2)/k² = pi²/8, with the slide's 4*tau_p/pi² prefactor.
  near(data.fourierPrefactorH * Math.PI ** 2 / 8, expected, 1e-16);
  const shortened = computeInductance(coilFixture(4));
  const beta = TWO_PI / 3;
  near(shortened.matrixH[0][0], MU0 * radiusM * lengthM * turnsPerCoil ** 2 / gapM * beta * (1 - beta / TWO_PI), 1e-16);
});

for (const fixture of [
  { title: "12 slots / p=1 / single y=6", input: { slots: 12, polePairs: 1, layers: 1, coilSpan: 6 }, diagonal: 5 / 3, mutual: -2 / 3 },
  { title: "9 slots / p=4 / double y=1", input: { slots: 9, polePairs: 4, layers: 2, coilSpan: 1 }, diagonal: 52 / 81, mutual: -2 / 81 },
  { title: "12 slots / p=5 / double y=1", input: { slots: 12, polePairs: 5, layers: 2, coilSpan: 1 }, diagonal: 2 / 3, mutual: 0 },
]) {
  test(`Independent piecewise Gram regression: ${fixture.title}`, () => {
    const data = computeInductance(computeWinding(fixture.input));
    const { radiusM, lengthM, gapM, turnsPerCoil } = data.parameters;
    const scale = MU0 * radiusM * lengthM * turnsPerCoil ** 2 * Math.PI / gapM;
    for (let a = 0; a < 3; a += 1) for (let b = 0; b < 3; b += 1) {
      near(data.matrixH[a][b] / scale, a === b ? fixture.diagonal : fixture.mutual);
    }
    // All-space harmonics do not generally obey M = -L/2.
    assert.ok(Math.abs(data.matrixH[0][1] + data.matrixH[0][0] / 2) > 1e-5);
    near(data.fundamentalMatrixH[0][1], -data.fundamentalMatrixH[0][0] / 2, 1e-14);
  });
}

test("Shared raw Fourier coefficients converge to the exact Gram matrix and preserve PSD", () => {
  for (const example of examples) {
    const winding = computeWinding(example);
    const low = computeInductance(winding, { maxOrder: 20, sampleCount: 16 });
    const high = computeInductance(winding, { maxOrder: 1200, sampleCount: 16 });
    assert.deepEqual(high.matrixH, low.matrixH, "Changing K cannot change the exact primary result");
    assert.ok(high.relativeTruncationError < low.relativeTruncationError);
    assert.ok(high.relativeTruncationError < 0.003);
    for (const phase of PHASES) {
      const spectrum = computeSpectrum(winding, { phase, maxOrder: 20 });
      for (const coefficient of spectrum.coefficients) {
        near(low.harmonics[coefficient.order - 1].coefficients[phase].real, coefficient.rawReal);
        near(low.harmonics[coefficient.order - 1].coefficients[phase].imag, coefficient.rawImag);
      }
    }
    for (let trial = 0; trial < 20; trial += 1) {
      const vector = PHASES.map((_, a) => Math.sin((trial + 1) * (a + 1) * 1.7));
      const quadratic = (matrix) => vector.reduce((sum, current, a) => sum + current * vector.reduce((inner, other, b) => inner + matrix[a][b] * other, 0), 0);
      assert.ok(quadratic(high.matrixH) >= -1e-14);
      assert.ok(quadratic(high.harmonicMatrixH) >= -1e-14);
      assert.ok(quadratic(high.matrixH.map((row, a) => row.map((value, b) => value - high.harmonicMatrixH[a][b]))) >= -1e-14);
      for (let a = 0; a < 3; a += 1) for (let b = 0; b < 3; b += 1) assert.equal(high.matrixH[a][b], high.matrixH[b][a]);
    }
  }
});

test("MMF, field, linkages and energy follow the same zero-mean winding functions", () => {
  const currents = { A: 2, B: -0.5, C: 0.7 };
  const data = computeInductance(reference(), { currents });
  for (const phase of PHASES) {
    near(data.segments.reduce((sum, segment) => sum + segment.widthRad * segment.winding[phase], 0), 0);
    const fromIntegral = data.geometricFactor * data.segments.reduce((sum, segment) => sum + segment.widthRad * segment.turnFunction[phase] * segment.thetaAmpereTurns, 0);
    near(data.fluxLinkagesWbTurns[phase], fromIntegral, 1e-14);
  }
  const energyFromField = data.parameters.radiusM * data.parameters.lengthM * data.parameters.gapM / (2 * MU0) * data.segments.reduce((sum, segment) => sum + segment.widthRad * segment.bTesla ** 2, 0);
  near(data.energyJ, energyFromField, 1e-14);
  for (const sample of data.samples) near(sample.bTesla, MU0 / data.parameters.gapM * sample.thetaAmpereTurns);
  const zero = computeInductance(reference(), { currents: { A: 0, B: 0, C: 0 } });
  assert.deepEqual(zero.fluxLinkagesWbTurns, { A: 0, B: 0, C: 0 });
  assert.equal(zero.energyJ, 0);
  assert.deepEqual(zero.matrixH, data.matrixH);
  assert.ok(zero.samples.every((sample) => sample.thetaAmpereTurns === 0 && sample.harmonicBTesla === 0));
});

test("Exact segment integration reproduces the complex coefficients and jump-mean convention", () => {
  const data = computeInductance(computeWinding({ slots: 9, polePairs: 4, layers: 2, coilSpan: 1 }), { sampleCount: 181 });
  for (const { order, coefficients } of data.harmonics.slice(0, 20)) for (const phase of PHASES) {
    const real = data.segments.reduce((sum, s) => sum + s.winding[phase] * (Math.sin(order * s.endRad) - Math.sin(order * s.startRad)) / (2 * order), 0);
    const imag = data.segments.reduce((sum, s) => sum + s.winding[phase] * (Math.cos(order * s.endRad) - Math.cos(order * s.startRad)) / (2 * order), 0);
    near(coefficients[phase].real, real);
    near(coefficients[phase].imag, imag);
  }
  const first = data.samples[0];
  near(first.thetaAmpereTurns, (data.segments[0].thetaAmpereTurns + data.segments.at(-1).thetaAmpereTurns) / 2);
  near(data.samples.at(-1).thetaAmpereTurns, first.thetaAmpereTurns);
});

test("Coil middle axes, signs and complex weighted group factors recover every phase coefficient", () => {
  for (const example of examples) for (const selectedOrder of [1, 2, 4, 5, 12, 17]) {
    const winding = computeWinding(example);
    const data = computeInductance(winding, { selectedOrder, maxOrder: 20, sampleCount: 16 });
    for (const coil of data.coils) {
      const direct = computeSpectrum({ ...winding, slotLayers: winding.slotLayers.filter((side) => (side.slot === coil.positiveSlot && side.layer === coil.positiveLayer) || (side.slot === coil.negativeSlot && side.layer === coil.negativeLayer)) }, { phase: coil.phase, maxOrder: selectedOrder });
      near(coil.selected.rawCoefficient.real, direct.coefficients.at(-1).rawReal);
      near(coil.selected.rawCoefficient.imag, direct.coefficients.at(-1).rawImag);
      near(Math.sin(winding.polePairs * coil.axisRad) * coil.fundamental.rawCoefficient.real + Math.cos(winding.polePairs * coil.axisRad) * coil.fundamental.rawCoefficient.imag, 0);
      assert.ok(Math.abs(coil.relativeElectricalDeg) <= 180 + 1e-9);
    }
    for (const phase of data.phases) {
      near(phase.fundamental.windingFactor, winding.phases.find((p) => p.phase === phase.phase).kw);
      const groups = data.groups.filter((group) => group.phase === phase.phase);
      const sumReal = groups.reduce((sum, group) => sum + group.selected.phaseContribution.real, 0);
      const sumImag = groups.reduce((sum, group) => sum + group.selected.phaseContribution.imag, 0);
      near(sumReal, phase.selected.distributionFactor.real);
      near(sumImag, phase.selected.distributionFactor.imag);
      const amplitude = phase.coilCount / selectedOrder * phase.selected.pitchFactor;
      const angle = -selectedOrder * phase.axisRad;
      const real = amplitude * (sumReal * Math.cos(angle) - sumImag * Math.sin(angle));
      const imag = amplitude * (sumReal * Math.sin(angle) + sumImag * Math.cos(angle));
      near(real, phase.selected.rawCoefficient.real);
      near(imag, phase.selected.rawCoefficient.imag);
      near(Math.abs(phase.selected.pitchFactor) * phase.selected.distributionFactor.magnitude, phase.selected.windingFactor);
    }
  }
});

test("A common mechanical rotation changes axes but leaves inductances invariant", () => {
  const winding = computeWinding({ slots: 9, polePairs: 4, layers: 2, coilSpan: 1 });
  const shift = 2;
  const rotateSlot = (slot) => modulo(slot - 1 + shift, winding.slots) + 1;
  const rotated = {
    ...winding,
    coils: winding.coils.map((coil) => ({ ...coil, positiveSlot: rotateSlot(coil.positiveSlot), negativeSlot: rotateSlot(coil.negativeSlot) })),
    slotLayers: winding.slotLayers.map((side) => ({ ...side, slot: rotateSlot(side.slot) })),
  };
  const a = computeInductance(winding);
  const b = computeInductance(rotated);
  for (let row = 0; row < 3; row += 1) for (let col = 0; col < 3; col += 1) {
    near(a.matrixH[row][col], b.matrixH[row][col], 1e-15);
    near(a.harmonicMatrixH[row][col], b.harmonicMatrixH[row][col], 1e-15);
  }
  for (const phase of a.phases) {
    const rotatedPhase = b.phases.find((p) => p.phase === phase.phase);
    near(Math.sin(winding.polePairs * (rotatedPhase.axisRad - phase.axisRad - shift * TWO_PI / winding.slots)), 0);
  }
});

test("A periodic display seam cannot split a physical coil group for factor calculation", () => {
  const winding = computeWinding({ slots: 36, polePairs: 2, layers: 1 });
  const data = computeInductance(winding, { sampleCount: 16 });
  for (const phase of PHASES) {
    const groups = data.groups.filter((group) => group.phase === phase);
    assert.equal(groups.length, 2);
    assert.deepEqual(groups.map((group) => group.coilCount), [3, 3]);
  }
  assert.ok(data.groups.some((group) => group.sourceGroupIds.length === 2));
  assert.equal(new Set(data.groups.flatMap((group) => group.coilIds)).size, winding.coils.length);
});

test("Dimensional scaling, independent fundamental order, and invalid parameters", () => {
  const winding = reference();
  const base = computeInductance(winding);
  const scaled = computeInductance(winding, { turnsPerCoil: 20, lengthM: 0.2, gapM: 0.002 });
  near(scaled.matrixH[0][0], 4 * base.matrixH[0][0], 1e-15);
  const highPole = computeWinding({ slots: 120, polePairs: 50, layers: 2, coilSpan: 1 });
  const high = computeInductance(highPole, { maxOrder: 20, selectedOrder: 80, sampleCount: 16 });
  assert.equal(high.valid, true);
  assert.equal(high.harmonics.length, 20);
  assert.equal(high.phases[0].fundamental.order, 50);
  assert.equal(high.phases[0].selected.order, 80);
  assert.ok(high.fundamentalMatrixH[0][0] > 0);
  for (const options of [{ gapM: 0 }, { radiusM: NaN }, { lengthM: Infinity }, { turnsPerCoil: 1.5 }, { currents: { A: NaN } }, { maxOrder: 0 }, { selectedOrder: 2001 }, { sampleCount: 2 }]) {
    assert.throws(() => computeInductance(winding, options), Error);
  }
  const invalid = computeInductance({ valid: false });
  assert.equal(invalid.valid, false);
  assert.deepEqual(invalid.matrixH, []);
  assert.equal(invalid.fluxLinkagesWbTurns, null);
  const inconsistent = structuredClone(winding);
  inconsistent.coils[0].negativeSlot = inconsistent.coils[0].positiveSlot;
  assert.equal(computeInductance(inconsistent).valid, false);
});
