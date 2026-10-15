/**
 * Spatial Fourier spectrum of the actual, signed coil sides.
 *
 * Mechanical angle: phi_s = 2*pi*(slot_s - 1)/Q. Layer 1 and layer 2 occupy
 * the same mechanical slot angle. Slot-voltage electrical angles are NOT used.
 * Standard Fourier convention: D_k = sum_s sign_s * exp(-i*k*phi_s).
 * For a winding function with W' = sum_s sign_s*delta(phi-phi_s), its complex
 * coefficient is W_k = D_k/(2*pi*i*k). The dimensionless plotted coefficient
 * is C_k = pi*W_k = D_k/(2*i*k), optionally divided by the phase's coil count.
 * The real winding function is reconstructed from both conjugate coefficients.
 * Thus a full-pitch reference coil (+ at -pi/2, - at +pi/2) has
 * C_k = sin(k*pi/2)/k. No absolute-value-only or per-order sign correction.
 */
const TWO_PI = 2 * Math.PI;
const EPSILON = 1e-11;
const PHASES = ["A", "B", "C"];
const normalizeSmall = (value) => (Math.abs(value) < EPSILON ? 0 : value);
const toDegrees = (radians) => (radians * 180) / Math.PI;

function validateMaxOrder(maxOrder) {
  if (!Number.isInteger(maxOrder) || maxOrder < 1 || maxOrder > 120) {
    throw new Error(
      "Die höchste Raumordnungszahl muss eine ganze Zahl zwischen 1 und 120 sein.",
    );
  }
}

function withRelative(coefficient, fundamentalAmplitude) {
  return {
    ...coefficient,
    relativeToFundamental:
      fundamentalAmplitude > EPSILON
        ? coefficient.amplitude / fundamentalAmplitude
        : null,
    signedRelativeToFundamental:
      fundamentalAmplitude > EPSILON
        ? coefficient.real / fundamentalAmplitude
        : null,
  };
}

function coefficientFromParts(
  order,
  rawReal,
  rawImag,
  referenceRad,
  kw,
  fundamentalOrder,
) {
  const angle = order * referenceRad;
  const real = normalizeSmall(
    rawReal * Math.cos(angle) + rawImag * Math.sin(angle),
  );
  const imag = normalizeSmall(
    rawImag * Math.cos(angle) - rawReal * Math.sin(angle),
  );
  const amplitude = normalizeSmall(Math.hypot(rawReal, rawImag));
  return {
    order,
    real,
    imag,
    amplitude,
    phaseDeg: amplitude === 0 ? 0 : toDegrees(Math.atan2(imag, real)),
    rawReal: normalizeSmall(rawReal),
    rawImag: normalizeSmall(rawImag),
    rawPhaseDeg: amplitude === 0 ? 0 : toDegrees(Math.atan2(rawImag, rawReal)),
    kw: kw === null ? null : normalizeSmall(kw),
    isFundamental: order === fundamentalOrder,
  };
}

/**
 * The default is a sum over the phase's coils, matching a group spectrum.
 * Per-coil normalization divides all orders by ONE common coil count.
 * One fixed origin rotation makes C_p positive real; it rotates order k by
 * -k*arg(C_p)/p. It never rotates individual orders independently.
 */
export function computeSpectrum(
  result,
  { maxOrder = 20, phase = "A", normalization = "phase-sum" } = {},
) {
  validateMaxOrder(maxOrder);
  if (!PHASES.includes(phase))
    throw new Error("Der Strang muss A, B oder C sein.");
  if (!["phase-sum", "per-coil"].includes(normalization)) {
    throw new Error("Die Normierung muss „phase-sum“ oder „per-coil“ sein.");
  }
  const polePairs = result?.polePairs ?? null;
  const normalizationText =
    normalization === "phase-sum"
      ? "Strangsumme: Cₖ = Dₖ / (2 i k). Alle tatsächlichen Spulenseiten dieses Strangs werden addiert."
      : "Pro Spule: Cₖ = Dₖ / (2 i k N). N ist die Spulenzahl dieses Strangs.";
  const base = {
    valid: false,
    phase,
    polePairs,
    maxOrder,
    fundamentalOrder: polePairs,
    coilCountPhase: 0,
    normalization,
    normalizationText,
    mechanicalReferenceRad: null,
    mechanicalReferenceDeg: null,
    coefficients: [],
    fundamental: null,
    convention:
      "Dₖ = Σ sⱼ exp(−i k φⱼ), φⱼ = 2π(Nutⱼ−1)/Q; Cₖ wird mit exp(−i k φ₀), φ₀ = arg(Cₚ)/p, auf einen festen Phasenursprung bezogen.",
    warnings: [],
  };
  if (!result?.valid) {
    return {
      ...base,
      warnings: ["Ohne gültiges Wickelschema wird kein Spektrum berechnet."],
    };
  }
  if (
    !Number.isInteger(result.slots) ||
    result.slots < 1 ||
    !Number.isInteger(polePairs) ||
    polePairs < 1 ||
    !Array.isArray(result.slotLayers)
  ) {
    return {
      ...base,
      warnings: [
        "Die tatsächlichen Spulenseiten und die mechanische Nutteilung fehlen.",
      ],
    };
  }
  const sides = result.slotLayers.filter((side) => side.phase === phase);
  const positiveSides = sides.filter((side) => side.sign === 1).length;
  const negativeSides = sides.filter((side) => side.sign === -1).length;
  if (
    positiveSides === 0 ||
    positiveSides !== negativeSides ||
    sides.some(
      (side) =>
        !Number.isInteger(side.slot) ||
        side.slot < 1 ||
        side.slot > result.slots ||
        ![1, -1].includes(side.sign),
    )
  ) {
    return {
      ...base,
      warnings: [
        "Der Strang besitzt keine vollständigen, vorzeichenrichtig zugeordneten Spulenseiten.",
      ],
    };
  }
  const coilCountPhase = positiveSides;
  const scale = normalization === "per-coil" ? coilCountPhase : 1;
  const rawCoefficient = (order) => {
    let dReal = 0;
    let dImag = 0;
    for (const side of sides) {
      const angle = (TWO_PI * (side.slot - 1) * order) / result.slots;
      dReal += side.sign * Math.cos(angle);
      dImag -= side.sign * Math.sin(angle);
    }
    const denominator = 2 * order * scale;
    return {
      rawReal: dImag / denominator,
      rawImag: -dReal / denominator,
      kw: Math.hypot(dReal, dImag) / sides.length,
    };
  };
  const rawFundamental = rawCoefficient(polePairs);
  const fundamentalAmplitude = Math.hypot(
    rawFundamental.rawReal,
    rawFundamental.rawImag,
  );
  if (fundamentalAmplitude < EPSILON) {
    return {
      ...base,
      coilCountPhase,
      warnings: [
        "Die Grundwelle des ausgewählten Strangs ist null; ein Grundwellen-Phasenursprung ist nicht definiert.",
      ],
    };
  }
  const mechanicalReferenceRad =
    Math.atan2(rawFundamental.rawImag, rawFundamental.rawReal) / polePairs;
  const makeCoefficient = (order) => {
    const raw = rawCoefficient(order);
    return withRelative(
      coefficientFromParts(
        order,
        raw.rawReal,
        raw.rawImag,
        mechanicalReferenceRad,
        raw.kw,
        polePairs,
      ),
      fundamentalAmplitude,
    );
  };
  return {
    ...base,
    valid: true,
    coilCountPhase,
    mechanicalReferenceRad,
    mechanicalReferenceDeg: toDegrees(mechanicalReferenceRad),
    coefficients: Array.from({ length: maxOrder }, (_, index) =>
      makeCoefficient(index + 1),
    ),
    fundamental: makeCoefficient(polePairs),
  };
}

const REFERENCE_DEFINITIONS = [
  {
    id: "full-pitch",
    title: "Vollgeteilte Einzelspule",
    formula: "ξₖ = sin(kπ/2) / k",
    description:
      "Rechteckige Wicklungsfunktion einer Spule mit 180° Weite im Formelwinkel; gerade Ordnungen verschwinden, ungerade behalten ihr Fourier-Vorzeichen. Eine Polpaarzahl ist nicht vorgegeben.",
    fundamentalOrder: null,
    referenceOrder: 1,
    coilCountPhase: 1,
    evaluate: (k) => Math.sin((k * Math.PI) / 2) / k,
  },
  {
    id: "short-pitch",
    title: "3/2-Wicklung",
    formula: "ξₖ = sin(kπ/3) / k",
    description:
      "Analytische Vergleichskurve mit 120° Spulenweite. „3/2“ ist die Bezeichnung der Wicklung und kein zusätzlicher Amplitudenfaktor.",
    fundamentalOrder: null,
    referenceOrder: 1,
    evaluate: (k) => Math.sin((k * Math.PI) / 3) / k,
  },
  {
    id: "chorded-group",
    title: "Gesehnte Spulengruppe",
    formula: "ξₖ = [2 cos(kπ/2) sin(2πk/9) − sin(kπ/6)] / k",
    description:
      "Überlagerung der angegebenen Gruppenbeiträge; die Vorzeichen sind Teil der räumlichen Fourierkoeffizienten.",
    fundamentalOrder: null,
    referenceOrder: 1,
    coilCountPhase: 3,
    referenceNote:
      "Der beschriebene Folienplot entspricht der umgekehrten Strangpolung: Alle Koeffizienten besitzen gegenüber dieser Formel gemeinsam das entgegengesetzte Vorzeichen. Die Formel wird hier unverändert ausgewertet.",
    evaluate: (k) =>
      (2 * Math.cos((k * Math.PI) / 2) * Math.sin((2 * Math.PI * k) / 9) -
        Math.sin((k * Math.PI) / 6)) /
      k,
  },
  {
    id: "q9-group",
    title: "9-Nuten-Spulengruppe",
    formula: "ξₖ = sin(kπ/9) [−1 + 2 cos(2πk/9)] / k",
    description:
      "Gruppenabstand 2π/9 (mechanischer Nutabstand). Der Gruppenfaktor ist Re{−1 + exp(−i2πk/9) + exp(+i2πk/9)}. Die angenommene Nutzgrundwelle besitzt die mechanische Ordnung k = 4.",
    fundamentalOrder: 4,
    referenceOrder: 4,
    coilCountPhase: 3,
    referenceNote:
      "Bei k = 2 bis 5 sind die Formelwerte negativ; die Folienbalken zeigen hier positive Beträge. Bei k = 1 ist die Formel positiv. Die unklare Bildlesart π/9 im Gruppenexponenten wird hier als Nutabstand 2π/9 interpretiert, weil nur dieser die angegebenen Beträge reproduziert. Keine einzelnen Koeffizienten werden im Vorzeichen angepasst.",
    evaluate: (k) =>
      (Math.sin((k * Math.PI) / 9) *
        (-1 + 2 * Math.cos((2 * Math.PI * k) / 9))) /
      k,
  },
];

/** Formula metadata for the UI; evaluators stay private. */
export const SPECTRUM_REFERENCES = REFERENCE_DEFINITIONS.map(
  ({ evaluate, ...metadata }) => metadata,
);

/** No hidden rephasing, amplitude fitting or per-order sign flips of references. */
export function computeReferenceSpectrum(id, { maxOrder = 20 } = {}) {
  validateMaxOrder(maxOrder);
  const reference = REFERENCE_DEFINITIONS.find((item) => item.id === id);
  if (!reference)
    throw new Error("Die analytische Spektrumsreferenz ist unbekannt.");
  const fundamentalAmplitude =
    reference.fundamentalOrder === null
      ? 0
      : Math.abs(reference.evaluate(reference.fundamentalOrder));
  const makeCoefficient = (order) =>
    withRelative(
      coefficientFromParts(
        order,
        reference.evaluate(order),
        0,
        0,
        null,
        reference.fundamentalOrder,
      ),
      fundamentalAmplitude,
    );
  const { evaluate, ...metadata } = reference;
  return {
    ...metadata,
    valid: true,
    phase: "A",
    polePairs: reference.fundamentalOrder,
    maxOrder,
    coilCountPhase: reference.coilCountPhase ?? null,
    normalization: "formula",
    normalizationText:
      "Unveränderte Amplituden der angegebenen Formel; keine automatische Strang- oder Spulennormierung.",
    mechanicalReferenceRad: 0,
    mechanicalReferenceDeg: 0,
    coefficients: Array.from({ length: maxOrder }, (_, index) =>
      makeCoefficient(index + 1),
    ),
    fundamental:
      reference.fundamentalOrder === null
        ? null
        : makeCoefficient(reference.fundamentalOrder),
    referenceCoefficient: makeCoefficient(reference.referenceOrder),
    convention:
      "Reelle, vorzeichenbehaftete Koeffizienten der angegebenen analytischen Formel; keine nachträgliche Grundwellenrotation.",
    warnings: reference.referenceNote ? [reference.referenceNote] : [],
  };
}
