import test from "node:test";
import assert from "node:assert/strict";
import { computeWinding } from "../src/domain/winding.js";
import {
  computeSpectrum,
  computeReferenceSpectrum,
  SPECTRUM_REFERENCES,
} from "../src/domain/spectrum.js";

function near(actual, expected, tolerance = 1e-10) {
  assert.ok(Math.abs(actual - expected) < tolerance, `${actual} ≠ ${expected}`);
}

// An isolated analytical coil is a finite signed-side distribution, not an
// assertion that this two-sided fixture is a complete three-phase machine.
const idealFullPitchCoil = {
  valid: true,
  slots: 4,
  polePairs: 1,
  slotLayers: [
    { slot: 4, layer: 1, phase: "A", sign: 1 }, // -pi/2
    { slot: 2, layer: 1, phase: "A", sign: -1 }, // +pi/2
  ],
};

test("Full-pitch signed-side Fourier coefficients equal sin(kπ/2)/k, including signs and 1/k", () => {
  const spectrum = computeSpectrum(idealFullPitchCoil, { maxOrder: 20 });
  assert.equal(spectrum.valid, true);
  assert.equal(spectrum.coilCountPhase, 1);
  near(spectrum.mechanicalReferenceRad, 0);
  for (const coefficient of spectrum.coefficients) {
    const expected =
      Math.sin((coefficient.order * Math.PI) / 2) / coefficient.order;
    near(coefficient.real, expected);
    near(coefficient.imag, 0);
    near(coefficient.amplitude, Math.abs(expected));
    near(coefficient.kw, coefficient.order % 2 ? 1 : 0);
  }
  near(spectrum.coefficients[2].real, -1 / 3);
  near(spectrum.coefficients[4].real, 1 / 5);
});

test("Winding fundamental amplitude carries coil count and inverse MECHANICAL order p", () => {
  for (const parameters of [
    { slots: 12, polePairs: 1, layers: 1, coilSpan: 6 },
    { slots: 36, polePairs: 2, layers: 1 },
    { slots: 12, polePairs: 5, layers: 2 },
    { slots: 9, polePairs: 4, layers: 2 },
  ]) {
    const winding = computeWinding(parameters);
    for (const phase of ["A", "B", "C"]) {
      const phaseWinding = winding.phases.find((item) => item.phase === phase);
      const perCoil = computeSpectrum(winding, {
        phase,
        normalization: "per-coil",
        maxOrder: 20,
      });
      const phaseSum = computeSpectrum(winding, {
        phase,
        normalization: "phase-sum",
        maxOrder: 20,
      });
      assert.equal(perCoil.valid, true);
      assert.equal(perCoil.fundamentalOrder, parameters.polePairs);
      near(
        perCoil.fundamental.amplitude * parameters.polePairs,
        phaseWinding.kw,
      );
      near(perCoil.fundamental.real, perCoil.fundamental.amplitude);
      near(perCoil.fundamental.imag, 0);
      near(perCoil.fundamental.relativeToFundamental, 1);
      for (let index = 0; index < perCoil.coefficients.length; index += 1) {
        const mean = perCoil.coefficients[index];
        const sum = phaseSum.coefficients[index];
        near(sum.real, mean.real * perCoil.coilCountPhase);
        near(sum.imag, mean.imag * perCoil.coilCountPhase);
        near(sum.amplitude, mean.amplitude * perCoil.coilCountPhase);
        near(mean.amplitude * mean.order, mean.kw);
        near((sum.amplitude * sum.order) / perCoil.coilCountPhase, sum.kw);
      }
    }
  }
});

test("Raw coefficients retain a fixed Fourier convention and rephase by k·arg(Cp)/p", () => {
  const winding = computeWinding({ slots: 12, polePairs: 5, layers: 2 });
  const spectrum = computeSpectrum(winding, { maxOrder: 20 });
  near(spectrum.fundamental.rawReal, 0);
  near(spectrum.fundamental.rawImag, -0.7464101615137756);
  near(spectrum.mechanicalReferenceDeg, -18);
  for (const coefficient of spectrum.coefficients) {
    const rotation = coefficient.order * spectrum.mechanicalReferenceRad;
    near(
      coefficient.real,
      coefficient.rawReal * Math.cos(rotation) +
        coefficient.rawImag * Math.sin(rotation),
    );
    near(
      coefficient.imag,
      coefficient.rawImag * Math.cos(rotation) -
        coefficient.rawReal * Math.sin(rotation),
    );
    near(coefficient.amplitude, Math.hypot(coefficient.real, coefficient.imag));
  }
  assert.ok(
    Math.abs(spectrum.coefficients[0].imag) > 0.2,
    "A non-fundamental complex component must not be silently rotated onto the real axis",
  );
});

test("Mechanical subharmonics remain visible below p; electrical harmonic 1 is mechanical order p", () => {
  const winding = computeWinding({ slots: 12, polePairs: 5, layers: 2 });
  const spectrum = computeSpectrum(winding, { normalization: "per-coil" });
  near(spectrum.coefficients[0].kw, 0.0669872981077807);
  near(
    spectrum.coefficients[4].kw,
    winding.harmonics.find((item) => item.order === 1).factor,
  );
  assert.ok(spectrum.coefficients[0].amplitude > 0);
  assert.notEqual(spectrum.coefficients[0].kw, winding.harmonics[0].factor);
  const truncated = computeSpectrum(winding, { maxOrder: 2 });
  assert.equal(truncated.coefficients.length, 2);
  assert.equal(
    truncated.fundamental.order,
    5,
    "Fundamental remains explicit even outside the displayed order range",
  );
  const highPoleWinding = computeWinding({
    slots: 120,
    polePairs: 50,
    layers: 2,
  });
  const highPoleSpectrum = computeSpectrum(highPoleWinding, {
    maxOrder: 20,
    normalization: "per-coil",
  });
  assert.equal(highPoleSpectrum.valid, true);
  assert.equal(highPoleSpectrum.coefficients.length, 20);
  assert.equal(highPoleSpectrum.fundamental.order, 50);
  near(highPoleSpectrum.fundamental.amplitude * 50, highPoleWinding.metrics.kw);
});

test("Only actual layers count; the layer-2 pitch attenuation is not lost", () => {
  const full = computeSpectrum(
    computeWinding({ slots: 12, polePairs: 1, layers: 2, coilSpan: 6 }),
    { normalization: "per-coil" },
  );
  const shortened = computeSpectrum(
    computeWinding({ slots: 12, polePairs: 1, layers: 2, coilSpan: 5 }),
    { normalization: "per-coil" },
  );
  near(full.fundamental.real, Math.cos(Math.PI / 12));
  near(shortened.fundamental.real, Math.cos(Math.PI / 12) ** 2);
  assert.equal(shortened.coilCountPhase, 4);
});

test("Four analytical references preserve their literal signed formulas", () => {
  assert.equal(SPECTRUM_REFERENCES.length, 4);
  const evaluators = {
    "full-pitch": (k) => Math.sin((k * Math.PI) / 2) / k,
    "short-pitch": (k) => Math.sin((k * Math.PI) / 3) / k,
    "chorded-group": (k) =>
      (2 * Math.cos((k * Math.PI) / 2) * Math.sin((2 * Math.PI * k) / 9) -
        Math.sin((k * Math.PI) / 6)) /
      k,
    "q9-group": (k) =>
      (Math.sin((k * Math.PI) / 9) *
        (-1 + 2 * Math.cos((2 * Math.PI * k) / 9))) /
      k,
  };
  for (const reference of SPECTRUM_REFERENCES) {
    const spectrum = computeReferenceSpectrum(reference.id, { maxOrder: 120 });
    for (const coefficient of spectrum.coefficients) {
      near(coefficient.real, evaluators[reference.id](coefficient.order));
      near(coefficient.amplitude, Math.abs(coefficient.real));
      near(coefficient.imag, 0);
      assert.equal(
        coefficient.kw,
        null,
        "Formula amplitude is not an inferred machine winding factor",
      );
    }
  }
  const shortened = computeReferenceSpectrum("short-pitch");
  near(shortened.coefficients[0].real, Math.sqrt(3) / 2, 1e-12); // 3/2 is a label, not a multiplier.
  const chorded = computeReferenceSpectrum("chorded-group");
  near(chorded.coefficients[0].real, -0.5);
  near(chorded.coefficients[1].real, -1.4178204549044273);
  near(chorded.coefficients[5].real, 1 / Math.sqrt(12));
  assert.match(chorded.warnings.join(" "), /umgekehrten Strangpolung/);
});

test("No motor pole-pair count is invented for a formula lacking machine data", () => {
  for (const id of ["full-pitch", "short-pitch", "chorded-group"]) {
    const spectrum = computeReferenceSpectrum(id);
    assert.equal(spectrum.fundamentalOrder, null);
    assert.equal(spectrum.polePairs, null);
    assert.equal(spectrum.fundamental, null);
    assert.equal(spectrum.referenceOrder, 1);
    assert.equal(spectrum.referenceCoefficient.order, 1);
    assert.ok(
      spectrum.coefficients.every(
        (coefficient) =>
          !coefficient.isFundamental &&
          coefficient.relativeToFundamental === null,
      ),
    );
  }
  const q9 = computeReferenceSpectrum("q9-group");
  assert.equal(q9.fundamentalOrder, 4);
  near(q9.fundamental.real, -0.7089102274522137);
});

test("Q9 p4 physical group matches the reference through one global polarity reversal", () => {
  const spectrum = computeSpectrum(
    computeWinding({ slots: 9, polePairs: 4, layers: 2 }),
    { maxOrder: 40 },
  );
  const reference = computeReferenceSpectrum("q9-group", { maxOrder: 40 });
  assert.equal(spectrum.coilCountPhase, 3);
  for (let index = 0; index < spectrum.coefficients.length; index += 1) {
    near(
      spectrum.coefficients[index].real,
      -reference.coefficients[index].real,
    );
    near(spectrum.coefficients[index].imag, 0);
  }
  near(spectrum.coefficients[0].real, -0.18198511713310114);
  near(spectrum.fundamental.real, 0.7089102274522137);
  near(
    spectrum.coefficients[4].amplitude / spectrum.fundamental.amplitude,
    4 / 5,
  );
});

test("Invalid windings and absent or incomplete sides do not produce a fabricated spectrum", () => {
  for (const winding of [
    undefined,
    { valid: false },
    computeWinding({ slots: 18, polePairs: 2, layers: 1 }),
    { valid: true, slots: 12, polePairs: 1, slotLayers: [] },
    {
      valid: true,
      slots: 12,
      polePairs: 1,
      slotLayers: [{ slot: 1, sign: 1, phase: "A" }],
    },
  ]) {
    const spectrum = computeSpectrum(winding);
    assert.equal(spectrum.valid, false);
    assert.deepEqual(spectrum.coefficients, []);
    assert.equal(spectrum.fundamental, null);
    assert.ok(spectrum.warnings.length > 0);
  }
});

test("Unusable options fail with German errors", () => {
  for (const maxOrder of [0, 121, 2.5, NaN, "20"]) {
    assert.throws(
      () => computeSpectrum(idealFullPitchCoil, { maxOrder }),
      /Raumordnungszahl/,
    );
    assert.throws(
      () => computeReferenceSpectrum("full-pitch", { maxOrder }),
      /Raumordnungszahl/,
    );
  }
  assert.throws(
    () => computeSpectrum(idealFullPitchCoil, { phase: "D" }),
    /Strang/,
  );
  assert.throws(
    () => computeSpectrum(idealFullPitchCoil, { normalization: "invented" }),
    /Normierung/,
  );
  assert.throws(() => computeReferenceSpectrum("invented"), /unbekannt/);
});
