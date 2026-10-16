/**
 * Linear, smooth-air-gap stator model in ONE shared mechanical coordinate.
 *
 * W_a(phi) has unit jumps at the actual signed coil sides and zero mean.
 * N_a = n_coil W_a, Theta = sum_a i_a N_a, B = mu0 Theta / delta.
 * L_ab = mu0*r*l/delta * integral_0^2pi N_a N_b dphi.
 *
 * The exact piecewise Gram integral is the primary result. With the spectrum's
 * unrotated C_a,k = D_a,k/(2 i k), W_a,k = C_a,k/pi, Parseval gives
 * L_ab^(K) = 4 mu0*r*l*n_coil^2/(pi*delta)
 *             * sum_k Re(C_a,k conj(C_b,k)).
 * Independent phase-origin rotations would destroy mutual inductances.
 * No iron reluctance, saturation, leakage, end turns or rotor are modeled.
 */
import { buildWindingLayout } from "./windingLayout.js";

export const MU0 = 4 * Math.PI * 1e-7;
const PHASES = ["A", "B", "C"];
const TWO_PI = 2 * Math.PI;
const EPSILON = 1e-11;
const mod = (value, period) => ((value % period) + period) % period;
const wrap = (angle) => mod(angle + Math.PI, TWO_PI) - Math.PI;
const degrees = (angle) => (angle * 180) / Math.PI;
const small = (value) => (Math.abs(value) < 1e-12 ? 0 : value);
const complex = (real = 0, imag = 0) => ({
  real: small(real),
  imag: small(imag),
  magnitude: small(Math.hypot(real, imag)),
});
const phaseObject = (makeValue) =>
  Object.fromEntries(PHASES.map((phase, index) => [phase, makeValue(phase, index)]));
const zeroMatrix = () => PHASES.map(() => PHASES.map(() => 0));
const multiply = (a, b) =>
  complex(a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real);
const rotation = (angle) => complex(Math.cos(angle), Math.sin(angle));
const scaleComplex = (value, scale) => complex(scale * value.real, scale * value.imag);

function requireNumber(value, name, { min = 0, max = 100, integer = false, strict = true } = {}) {
  if (
    !Number.isFinite(value) ||
    (strict ? value <= min : value < min) ||
    value > max ||
    (integer && !Number.isInteger(value))
  ) {
    throw new Error(`${name}: Bitte einen ${integer ? "ganzzahligen " : ""}Wert ${strict ? "größer als" : "ab"} ${min} und höchstens ${max} eingeben.`);
  }
}

function parametersFor(result, options) {
  const parameters = {
    radiusM: options.radiusM ?? 0.05,
    lengthM: options.lengthM ?? 0.1,
    gapM: options.gapM ?? 0.001,
    turnsPerCoil: options.turnsPerCoil ?? 10,
    currents: phaseObject((phase) => options.currents?.[phase] ?? (phase === "A" ? 1 : 0)),
    maxOrder: options.maxOrder ?? 120,
    selectedOrder: options.selectedOrder ?? result?.polePairs ?? 1,
    sampleCount: options.sampleCount ?? 361,
  };
  requireNumber(parameters.radiusM, "Luftspaltradius r / m");
  requireNumber(parameters.lengthM, "Aktive Länge l / m");
  requireNumber(parameters.gapM, "Wirksamer Luftspalt δ / m", { max: 1 });
  requireNumber(parameters.turnsPerCoil, "Windungszahl je Spule", { max: 1e6, integer: true });
  for (const phase of PHASES) {
    requireNumber(parameters.currents[phase], `Strom i${phase} / A`, { min: -1e6, max: 1e6, strict: false });
  }
  requireNumber(parameters.maxOrder, "Höchste Raumordnung K", { min: 1, max: 2000, integer: true, strict: false });
  requireNumber(parameters.selectedOrder, "Ausgewählte Raumordnung k", { min: 1, max: 2000, integer: true, strict: false });
  requireNumber(parameters.sampleCount, "Anzahl Kurvenstützpunkte", { min: 16, max: 1441, integer: true, strict: false });
  parameters.polePitchM = Number.isInteger(result?.polePairs) && result.polePairs > 0
    ? Math.PI * parameters.radiusM / result.polePairs
    : null;
  return parameters;
}

function actualWindingError(result) {
  if (!result?.valid || !Array.isArray(result.coils) || !result.coils.length) {
    return "Ohne gültige vollständige Wicklung werden keine Induktivitäten berechnet.";
  }
  const { slots, polePairs, slotLayers, coils } = result;
  if (!Number.isInteger(slots) || slots < 2 || !Number.isInteger(polePairs) || polePairs < 1 || !Array.isArray(slotLayers)) {
    return "Mechanische Nutteilung, Polpaarzahl oder tatsächliche Spulenseiten fehlen.";
  }
  const sides = new Map();
  for (const side of slotLayers) {
    if (!PHASES.includes(side.phase) || ![1, -1].includes(side.sign) || !Number.isInteger(side.slot) || side.slot < 1 || side.slot > slots || ![1, 2].includes(side.layer ?? 1)) {
      return "Die tatsächlichen Spulenseiten sind unvollständig oder ungültig.";
    }
    const key = `${side.slot}:${side.layer ?? 1}`;
    if (sides.has(key)) return "Eine Nutlage ist mehreren Spulenseiten zugeordnet.";
    sides.set(key, side);
  }
  const used = new Set();
  const ids = new Set();
  for (const coil of coils) {
    const direction = coil.direction ?? (mod(coil.negativeSlot - coil.positiveSlot, slots) === coil.span ? 1 : -1);
    if (!PHASES.includes(coil.phase) || ids.has(coil.id) || !Number.isInteger(coil.span) || coil.span < 1 || coil.span >= slots || ![1, -1].includes(direction) || mod(coil.positiveSlot - 1 + direction * coil.span, slots) + 1 !== coil.negativeSlot) {
      return "Spulenweite, Wicklungssinn oder Spulenkennungen sind inkonsistent.";
    }
    ids.add(coil.id);
    for (const [slot, layer, sign] of [[coil.positiveSlot, coil.positiveLayer ?? 1, 1], [coil.negativeSlot, coil.negativeLayer ?? 1, -1]]) {
      const key = `${slot}:${layer}`;
      const side = sides.get(key);
      if (!side || used.has(key) || side.phase !== coil.phase || side.sign !== sign) {
        return "Spulen und vorzeichenbehaftete Nutlagen stimmen nicht überein.";
      }
      used.add(key);
    }
  }
  if (used.size !== sides.size || PHASES.some((phase) => !coils.some((coil) => coil.phase === phase))) {
    return "Für jeden Strang wird eine vollständige, geschlossene Spulenzuordnung benötigt.";
  }
  return null;
}

function rawCoefficient(sides, slots, order) {
  let real = 0;
  let imag = 0;
  for (const side of sides) {
    const angle = order * TWO_PI * (side.slot - 1) / slots;
    real -= side.sign * Math.sin(angle) / (2 * order);
    imag -= side.sign * Math.cos(angle) / (2 * order);
  }
  return complex(real, imag);
}

function axisOf(coefficient, polePairs) {
  return coefficient.magnitude < EPSILON
    ? null
    : mod(-Math.atan2(coefficient.imag, coefficient.real) / polePairs, TWO_PI / polePairs);
}

/** The sign in beta matters; a geometric midpoint alone has no terminal polarity. */
function geometryOf(coil, slots, polePairs) {
  const direction = coil.direction ?? (mod(coil.negativeSlot - coil.positiveSlot, slots) === coil.span ? 1 : -1);
  const positiveAngleRad = TWO_PI * (coil.positiveSlot - 1) / slots;
  const betaRad = TWO_PI * coil.span / slots;
  const signedSpanRad = direction * betaRad;
  const centerRad = mod(positiveAngleRad + signedSpanRad / 2, TWO_PI);
  return {
    ...coil,
    direction,
    positiveAngleRad,
    negativeAngleRad: TWO_PI * (coil.negativeSlot - 1) / slots,
    betaRad,
    signedSpanRad,
    betaElectricalRad: polePairs * betaRad,
    betaDeg: degrees(betaRad),
    betaElectricalDeg: degrees(polePairs * betaRad),
    centerRad,
    centerDeg: degrees(centerRad),
  };
}

function coilCoefficient(coil, order) {
  const amplitude = Math.sin(order * coil.signedSpanRad / 2) / order;
  return complex(amplitude * Math.cos(order * coil.centerRad), -amplitude * Math.sin(order * coil.centerRad));
}

function commonPitch(coils, order) {
  if (!coils.length || coils.some((coil) => Math.abs(coil.betaRad - coils[0].betaRad) > EPSILON)) return null;
  return small(Math.sin(order * coils[0].betaRad / 2));
}

function factorsOf(coils, order, referenceAxisRad) {
  const reference = referenceAxisRad ?? 0;
  let distributionReal = 0;
  let distributionImag = 0;
  let rawReal = 0;
  let rawImag = 0;
  for (const coil of coils) {
    const angle = order * (coil.centerRad - reference);
    distributionReal += coil.direction * Math.cos(angle);
    distributionImag -= coil.direction * Math.sin(angle);
    const coefficient = coilCoefficient(coil, order);
    rawReal += coefficient.real;
    rawImag += coefficient.imag;
  }
  const pitchFactor = commonPitch(coils, order);
  const raw = complex(rawReal, rawImag);
  return {
    order,
    pitchFactor,
    distributionFactor: pitchFactor === null ? null : complex(distributionReal / coils.length, distributionImag / coils.length),
    rawCoefficient: raw,
    windingFactor: order * raw.magnitude / coils.length,
    referenceAxisRad: referenceAxisRad,
  };
}

function exactSegments(result, parameters) {
  const jumps = Array.from({ length: result.slots }, () => phaseObject(() => 0));
  for (const side of result.slotLayers) jumps[side.slot - 1][side.phase] += side.sign;
  const running = phaseObject(() => 0);
  const widthRad = TWO_PI / result.slots;
  const values = jumps.map((jump, index) => {
    for (const phase of PHASES) running[phase] += jump[phase];
    return { startRad: index * widthRad, endRad: (index + 1) * widthRad, widthRad, winding: { ...running } };
  });
  const mean = phaseObject((phase) => values.reduce((sum, segment) => sum + segment.winding[phase], 0) / result.slots);
  return values.map((segment) => {
    const winding = phaseObject((phase) => small(segment.winding[phase] - mean[phase]));
    const turnFunction = phaseObject((phase) => parameters.turnsPerCoil * winding[phase]);
    const thetaAmpereTurns = PHASES.reduce((sum, phase) => sum + parameters.currents[phase] * turnFunction[phase], 0);
    return { ...segment, winding, turnFunction, thetaAmpereTurns, bTesla: MU0 * thetaAmpereTurns / parameters.gapM };
  });
}

function exactMatrix(segments, geometricFactor) {
  const matrix = zeroMatrix();
  for (let a = 0; a < PHASES.length; a += 1) {
    for (let b = a; b < PHASES.length; b += 1) {
      const value = geometricFactor * segments.reduce((sum, segment) => sum + segment.widthRad * segment.turnFunction[PHASES[a]] * segment.turnFunction[PHASES[b]], 0);
      matrix[a][b] = value;
      matrix[b][a] = value;
    }
  }
  return matrix;
}

function matrixFromCoefficients(coefficients, prefactor) {
  const matrix = zeroMatrix();
  for (let a = 0; a < PHASES.length; a += 1) {
    for (let b = a; b < PHASES.length; b += 1) {
      const ca = coefficients[PHASES[a]];
      const cb = coefficients[PHASES[b]];
      const value = prefactor * (ca.real * cb.real + ca.imag * cb.imag);
      matrix[a][b] = value;
      matrix[b][a] = value;
    }
  }
  return matrix;
}

/**
 * All lengths are SI meters, matrix values H, currents A and linkages Wb turns.
 * Mechanical order k is NOT electrical harmonic nu; the useful fundamental is k=p.
 * Equal turns per coil and additive series connection of each phase are assumed.
 * maxOrder controls only the Fourier approximation, never the exact result.
 */
export function computeInductance(result, options = {}) {
  const parameters = parametersFor(result, options);
  const base = {
    valid: false,
    slots: result?.slots ?? null,
    polePairs: result?.polePairs ?? null,
    layers: result?.layers ?? null,
    parameters,
    phaseOrder: [...PHASES],
    matrixH: [],
    harmonicMatrixH: [],
    fundamentalMatrixH: [],
    fluxLinkagesWbTurns: null,
    energyJ: null,
    phases: [],
    coils: [],
    groups: [],
    segments: [],
    samples: [],
    harmonics: [],
    relativeTruncationError: null,
    warnings: [],
  };
  const windingError = actualWindingError(result);
  if (windingError) return { ...base, warnings: [windingError] };
  const warnings = [];
  if (parameters.gapM / parameters.radiusM > 0.05) warnings.push("Der Luftspalt ist gegenüber dem Radius groß. Die dünne, zylindrische Luftspaltnäherung wird ungenauer.");
  const { polePairs } = result;
  const { turnsPerCoil, maxOrder, selectedOrder, radiusM, lengthM, gapM, currents } = parameters;
  const geometricFactor = MU0 * radiusM * lengthM / gapM;
  const fourierPrefactorH = 4 * geometricFactor * turnsPerCoil ** 2 / Math.PI;
  const phaseSides = phaseObject((phase) => result.slotLayers.filter((side) => side.phase === phase));
  const cache = new Map();
  const coefficientsAt = (order) => {
    if (!cache.has(order)) cache.set(order, phaseObject((phase) => rawCoefficient(phaseSides[phase], result.slots, order)));
    return cache.get(order);
  };
  const fundamentalCoefficients = coefficientsAt(polePairs);
  const phaseAxes = phaseObject((phase) => axisOf(fundamentalCoefficients[phase], polePairs));
  const geometry = result.coils.map((coil) => geometryOf(coil, result.slots, polePairs));
  const geometryById = new Map(geometry.map((coil) => [coil.id, coil]));
  const phaseGeometry = phaseObject((phase) => geometry.filter((coil) => coil.phase === phase));
  const phases = PHASES.map((phase) => ({
    phase,
    coilCount: phaseGeometry[phase].length,
    turnsSeries: turnsPerCoil * phaseGeometry[phase].length,
    axisRad: phaseAxes[phase],
    axisDeg: phaseAxes[phase] === null ? null : degrees(phaseAxes[phase]),
    selected: factorsOf(phaseGeometry[phase], selectedOrder, phaseAxes[phase]),
    fundamental: factorsOf(phaseGeometry[phase], polePairs, phaseAxes[phase]),
  }));
  // A display seam may split ONE physical cyclic group into two fragments.
  // Rejoin those fragments for physical group factors, without changing layout.
  const groupDefinitions = buildWindingLayout(result).groups.map((group) => ({
    ...group,
    coilIds: [...group.coilIds],
    sourceGroupIds: [group.id],
  }));
  if (groupDefinitions.length > 1 && groupDefinitions[0].phase === groupDefinitions.at(-1).phase) {
    const last = groupDefinitions.pop();
    groupDefinitions[0].coilIds = [...last.coilIds, ...groupDefinitions[0].coilIds];
    groupDefinitions[0].sourceGroupIds = [...last.sourceGroupIds, ...groupDefinitions[0].sourceGroupIds];
  }
  const groups = groupDefinitions.map((group) => {
    const members = group.coilIds.map((id) => geometryById.get(id));
    const fundamentalRaw = factorsOf(members, polePairs, 0).rawCoefficient;
    const axisRad = axisOf(fundamentalRaw, polePairs);
    const weight = members.length / phaseGeometry[group.phase].length;
    const withContribution = (order) => {
      const factor = factorsOf(members, order, axisRad);
      const relativePhase = -order * ((axisRad ?? 0) - (phaseAxes[group.phase] ?? 0));
      return {
        ...factor,
        weight,
        phaseContribution: factor.distributionFactor === null ? null : scaleComplex(multiply(factor.distributionFactor, rotation(relativePhase)), weight),
      };
    };
    return { id: group.id, phase: group.phase, coilIds: [...group.coilIds], sourceGroupIds: group.sourceGroupIds, coilCount: members.length, axisRad, axisDeg: axisRad === null ? null : degrees(axisRad), selected: withContribution(selectedOrder), fundamental: withContribution(polePairs) };
  });
  const groupForCoil = new Map(groups.flatMap((group) => group.coilIds.map((id) => [id, group.id])));
  const coils = geometry.map((coil) => {
    const axisRad = axisOf(coilCoefficient(coil, polePairs), polePairs);
    const phaseAxisRad = phaseAxes[coil.phase];
    const relativeElectricalRad = axisRad === null || phaseAxisRad === null ? null : wrap(polePairs * (axisRad - phaseAxisRad));
    const relativeMechanicalRad = relativeElectricalRad === null ? null : relativeElectricalRad / polePairs;
    return {
      ...coil,
      axisRad,
      axisDeg: axisRad === null ? null : degrees(axisRad),
      phaseAxisRad,
      phaseAxisDeg: phaseAxisRad === null ? null : degrees(phaseAxisRad),
      relativeElectricalRad,
      relativeElectricalDeg: relativeElectricalRad === null ? null : degrees(relativeElectricalRad),
      relativeMechanicalRad,
      relativeMechanicalDeg: relativeMechanicalRad === null ? null : degrees(relativeMechanicalRad),
      groupId: groupForCoil.get(coil.id),
      selected: factorsOf([coil], selectedOrder, phaseAxisRad),
      fundamental: factorsOf([coil], polePairs, phaseAxisRad),
    };
  });
  if (phases.some((phase) => phase.axisRad === null)) warnings.push("Mindestens eine Stranggrundwelle verschwindet; ihre Mittelachse ist nicht definiert. Die Induktivitätsberechnung bleibt gültig.");
  if (coils.some((coil) => coil.axisRad === null)) warnings.push("Mindestens eine Spule besitzt bei k = p keine Grundwelle und daher keine orientierte Grundwellenachse.");
  const segments = exactSegments(result, parameters);
  const matrixH = exactMatrix(segments, geometricFactor);
  const harmonicMatrixH = zeroMatrix();
  const harmonics = Array.from({ length: maxOrder }, (_, index) => {
    const order = index + 1;
    const coefficients = coefficientsAt(order);
    const contributionMatrixH = matrixFromCoefficients(coefficients, fourierPrefactorH);
    for (let a = 0; a < 3; a += 1) for (let b = 0; b < 3; b += 1) harmonicMatrixH[a][b] += contributionMatrixH[a][b];
    return { order, coefficients, contributionMatrixH, isFundamental: order === polePairs };
  });
  const fundamentalMatrixH = matrixFromCoefficients(fundamentalCoefficients, fourierPrefactorH);
  const fluxLinkagesWbTurns = phaseObject((phase, a) => PHASES.reduce((sum, source, b) => sum + matrixH[a][b] * currents[source], 0));
  const energyJ = PHASES.reduce((sum, phase) => sum + currents[phase] * fluxLinkagesWbTurns[phase] / 2, 0);
  let exactNormSquared = 0;
  let errorNormSquared = 0;
  for (let a = 0; a < 3; a += 1) for (let b = 0; b < 3; b += 1) {
    exactNormSquared += matrixH[a][b] ** 2;
    errorNormSquared += (matrixH[a][b] - harmonicMatrixH[a][b]) ** 2;
  }
  const relativeTruncationError = exactNormSquared > 0 ? Math.sqrt(errorNormSquared / exactNormSquared) : 0;
  const samples = Array.from({ length: parameters.sampleCount }, (_, index) => {
    const angleRad = TWO_PI * index / (parameters.sampleCount - 1);
    const position = angleRad / TWO_PI * result.slots;
    const after = segments[Math.floor(position + 1e-10) % result.slots];
    const onSlot = Math.abs(position - Math.round(position)) < 1e-9;
    // A Fourier series takes the mean of the two one-sided values at a jump.
    const before = segments[mod(Math.round(position) - 1, result.slots)];
    const thetaAmpereTurns = onSlot ? (after.thetaAmpereTurns + before.thetaAmpereTurns) / 2 : after.thetaAmpereTurns;
    let harmonicThetaAmpereTurns = 0;
    for (const harmonic of harmonics) {
      const cos = Math.cos(harmonic.order * angleRad);
      const sin = Math.sin(harmonic.order * angleRad);
      for (const phase of PHASES) {
        const coefficient = harmonic.coefficients[phase];
        harmonicThetaAmpereTurns += 2 * turnsPerCoil * currents[phase] / Math.PI * (coefficient.real * cos - coefficient.imag * sin);
      }
    }
    return { angleRad, angleDeg: degrees(angleRad), thetaAmpereTurns, bTesla: MU0 * thetaAmpereTurns / gapM, harmonicThetaAmpereTurns, harmonicBTesla: MU0 * harmonicThetaAmpereTurns / gapM };
  });
  return {
    ...base,
    valid: true,
    matrixH,
    harmonicMatrixH,
    fundamentalMatrixH,
    fluxLinkagesWbTurns,
    energyJ,
    phases,
    coils,
    groups,
    segments,
    samples,
    harmonics,
    relativeTruncationError,
    geometricFactor,
    fourierPrefactorH,
    warnings,
    model: {
      coordinate: "Gemeinsamer mechanischer Winkel φ = 2π(Nut−1)/Q; Nutzgrundwelle k = p.",
      assumptions: "Linearer Magnetkreis, μFe → ∞, gleichmäßiger dünner Luftspalt, gleiche Windungszahl je Spule, additive Strangreihenschaltung.",
      excluded: "Nut-, Stirn- und sonstige Streuung, Sättigung, endliche Eisenpermeabilität und Rotoranisotropie.",
      exact: "Stückweise exaktes Gram-Integral der mittelwertfreien Wicklungsfunktionen über den ganzen Statorumfang.",
    },
  };
}
