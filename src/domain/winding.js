/**
 * Three-phase winding construction using a fixed, natural 60° phase-belt model.
 * Unit slot EMFs are used throughout; no machine dimensions or current model.
 * All angles increase counter-clockwise, beginning at slot 1 on the real axis.
 */
const PHASES = ["A", "B", "C"];
const ZONES = [
  { phase: "A", sign: 1 },
  { phase: "C", sign: -1 },
  { phase: "B", sign: 1 },
  { phase: "A", sign: -1 },
  { phase: "C", sign: 1 },
  { phase: "B", sign: -1 },
];
const EPSILON = 1e-9;
const radians = (degrees) => (degrees * Math.PI) / 180;
const mod = (value, modulus) => ((value % modulus) + modulus) % modulus;
const gcd = (a, b) => (b === 0 ? a : gcd(b, a % b));
const angularDistance = (a, b) => Math.abs(mod(a - b + 180, 360) - 180);

export const examples = [
  {
    label: "Folienbeispiel · 12 Nuten / 2 Pole",
    slots: 12,
    polePairs: 1,
    layers: 1,
    coilSpan: 6,
  },
  {
    label: "Verteilte Wicklung · 36 Nuten / 4 Pole",
    slots: 36,
    polePairs: 2,
    layers: 1,
    coilSpan: "auto",
  },
  {
    label: "Bruchloch · 12 Nuten / 10 Pole",
    slots: 12,
    polePairs: 5,
    layers: 2,
    coilSpan: "auto",
  },
  {
    label: "Bruchloch · 9 Nuten / 8 Pole",
    slots: 9,
    polePairs: 4,
    layers: 2,
    coilSpan: "auto",
  },
];

function requireInteger(value, name, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new Error(
      `${name} muss eine ganze Zahl zwischen ${min} und ${max} sein.`,
    );
  }
}

function makeAssignments(slots, polePairs) {
  const alphaDeg = (360 * polePairs) / slots;
  // Put a belt boundary halfway between neighboring distinct star rays.
  // Half-open belts resolve exact boundary ties deterministically.
  const distinctRayStep = (360 * gcd(slots, polePairs)) / slots;
  const zoneOffsetDeg = -Math.min(distinctRayStep / 2, 30);
  const slotAssignments = Array.from({ length: slots }, (_, index) => {
    const angleDeg = mod(index * alphaDeg, 360);
    const belt =
      Math.floor((mod(angleDeg - zoneOffsetDeg, 360) + EPSILON) / 60) % 6;
    const { phase, sign } = ZONES[belt];
    return {
      slot: index + 1,
      angleDeg,
      x: Math.cos(radians(angleDeg)),
      y: Math.sin(radians(angleDeg)),
      phase,
      sign,
      zone: `${sign > 0 ? "+" : "−"}${phase}`,
      zoneIndex: belt,
    };
  });
  return { slotAssignments, alphaDeg, zoneOffsetDeg };
}

function phaseResults(slotLayers, harmonic = 1) {
  return PHASES.map((phase) => {
    const sides = slotLayers.filter((side) => side.phase === phase);
    const x = sides.reduce(
      (sum, side) =>
        sum + side.sign * Math.cos(radians(side.angleDeg * harmonic)),
      0,
    );
    const y = sides.reduce(
      (sum, side) =>
        sum + side.sign * Math.sin(radians(side.angleDeg * harmonic)),
      0,
    );
    const magnitude = Math.hypot(x, y);
    return {
      phase,
      x: Math.abs(x) < EPSILON ? 0 : x,
      y: Math.abs(y) < EPSILON ? 0 : y,
      magnitude,
      angleDeg:
        magnitude < EPSILON ? 0 : mod((Math.atan2(y, x) * 180) / Math.PI, 360),
      kw: sides.length ? magnitude / sides.length : 0,
      sideCount: sides.length,
      positiveSlots: sides
        .filter((side) => side.sign === 1)
        .map((side) => side.slot),
      negativeSlots: sides
        .filter((side) => side.sign === -1)
        .map((side) => side.slot),
    };
  });
}

function symmetry(phases) {
  const average = phases.reduce((sum, phase) => sum + phase.magnitude, 0) / 3;
  const imbalance =
    average < EPSILON
      ? 1
      : Math.max(
          ...phases.map((phase) => Math.abs(phase.magnitude - average)),
        ) / average;
  const phaseErrorDeg = Math.max(
    angularDistance(phases[1].angleDeg - phases[0].angleDeg, 120),
    angularDistance(phases[2].angleDeg - phases[0].angleDeg, 240),
  );
  return {
    balanced: average > EPSILON && imbalance < 1e-7 && phaseErrorDeg < 1e-6,
    imbalance,
    phaseErrorDeg,
  };
}

function coilRecord(
  id,
  phase,
  positiveSlot,
  negativeSlot,
  span,
  slots,
  positiveLayer,
  negativeLayer,
) {
  return {
    id,
    phase,
    positiveSlot,
    negativeSlot,
    span,
    positiveLayer,
    negativeLayer,
    direction: mod(negativeSlot - positiveSlot, slots) === span ? 1 : -1,
  };
}

/** Find an actual perfect matching, not a greedy assignment of coil sides. */
function singleLayerCoils(assignments, span) {
  const slots = assignments.length;
  const coils = [];
  for (const phase of PHASES) {
    const positive = assignments.filter(
      (side) => side.phase === phase && side.sign === 1,
    );
    const negative = assignments.filter(
      (side) => side.phase === phase && side.sign === -1,
    );
    if (positive.length !== negative.length || positive.length === 0)
      return null;
    const negativeSlots = new Set(negative.map((side) => side.slot));
    const matched = new Map();
    const visit = (positiveSlot, visited) => {
      const neighbors = [
        ...new Set([
          mod(positiveSlot - 1 + span, slots) + 1,
          mod(positiveSlot - 1 - span, slots) + 1,
        ]),
      ].filter((slot) => negativeSlots.has(slot));
      for (const negativeSlot of neighbors) {
        if (visited.has(negativeSlot)) continue;
        visited.add(negativeSlot);
        if (
          !matched.has(negativeSlot) ||
          visit(matched.get(negativeSlot), visited)
        ) {
          matched.set(negativeSlot, positiveSlot);
          return true;
        }
      }
      return false;
    };
    for (const side of positive) {
      if (!visit(side.slot, new Set())) return null;
    }
    const ordered = [...matched.entries()].sort((a, b) => a[1] - b[1]);
    for (const [negativeSlot, positiveSlot] of ordered) {
      coils.push(
        coilRecord(
          `${phase}${coils.filter((coil) => coil.phase === phase).length + 1}`,
          phase,
          positiveSlot,
          negativeSlot,
          span,
          slots,
          1,
          1,
        ),
      );
    }
  }
  return coils;
}

function doubleLayerCandidate(assignments, span, alphaDeg) {
  const slots = assignments.length;
  const slotLayers = assignments.map((side) => ({ ...side, layer: 1 }));
  const coils = assignments.map((side) => {
    const secondSlot = mod(side.slot - 1 + span, slots) + 1;
    const secondSide = {
      slot: secondSlot,
      layer: 2,
      angleDeg: mod((secondSlot - 1) * alphaDeg, 360),
      phase: side.phase,
      sign: -side.sign,
      zone: `${side.sign > 0 ? "−" : "+"}${side.phase}`,
    };
    secondSide.x = Math.cos(radians(secondSide.angleDeg));
    secondSide.y = Math.sin(radians(secondSide.angleDeg));
    slotLayers.push(secondSide);
    return coilRecord(
      `${side.phase}${side.slot}`,
      side.phase,
      side.sign === 1 ? side.slot : secondSlot,
      side.sign === 1 ? secondSlot : side.slot,
      span,
      slots,
      side.sign === 1 ? 1 : 2,
      side.sign === 1 ? 2 : 1,
    );
  });
  slotLayers.sort((a, b) => a.slot - b.slot || a.layer - b.layer);
  return { coils, slotLayers };
}

/**
 * Build a reproducible winding within the documented fixed-zone model.
 * Valid means a balanced, non-zero fundamental and a complete side pairing.
 * Failure is a limitation of this construction, not a proof that no other
 * winding topology can exist for the requested slot/pole combination.
 */
export function computeWinding({
  slots,
  polePairs,
  layers = 1,
  coilSpan = "auto",
} = {}) {
  requireInteger(slots, "Die Nutenzahl Q", 6, 120);
  requireInteger(polePairs, "Die Polpaarzahl p", 1, Math.floor(slots / 2));
  requireInteger(layers, "Die Schichtzahl", 1, 2);
  if (coilSpan !== "auto")
    requireInteger(coilSpan, "Die Spulenweite y", 1, Math.floor(slots / 2));

  const { slotAssignments, alphaDeg, zoneOffsetDeg } = makeAssignments(
    slots,
    polePairs,
  );
  const polePitch = slots / (2 * polePairs);
  const maxAutoSpan = Math.min(Math.ceil(polePitch), Math.floor(slots / 2));
  const spans =
    coilSpan === "auto"
      ? Array.from({ length: maxAutoSpan }, (_, index) => index + 1)
      : [coilSpan];
  const baseLayers = slotAssignments.map((side) => ({ ...side, layer: 1 }));
  const candidates = spans.map((span) => {
    const constructed =
      layers === 1
        ? {
            coils: singleLayerCoils(slotAssignments, span),
            slotLayers: baseLayers,
          }
        : doubleLayerCandidate(slotAssignments, span, alphaDeg);
    const phases = phaseResults(constructed.slotLayers);
    const state = symmetry(phases);
    const kw = phases.reduce((sum, phase) => sum + phase.kw, 0) / 3;
    return {
      span,
      ...constructed,
      phases,
      ...state,
      kw,
      valid:
        !!constructed.coils && constructed.coils.length > 0 && state.balanced,
    };
  });
  const viable = candidates.filter((candidate) => candidate.valid);
  // Roundoff must not make a numerically equal winding win against a shorter one.
  viable.sort((a, b) =>
    Math.abs(b.kw - a.kw) > EPSILON ? b.kw - a.kw : a.span - b.span,
  );
  const selected = viable[0] || candidates[0];
  const warnings = [];
  if (!selected.valid) {
    if (layers === 1 && slots % 2 !== 0) {
      warnings.push(
        "Eine Einschichtwicklung benötigt eine gerade Nutenzahl: Jede Spule belegt zwei verschiedene Nuten.",
      );
    }
    if (!selected.balanced) {
      warnings.push(
        "Die feste 60°-Zonung ergibt keine symmetrischen, von null verschiedenen Strangspannungen mit 120° Versatz.",
      );
    }
    if (layers === 1 && !selected.coils) {
      warnings.push(
        coilSpan === "auto"
          ? `Innerhalb der geprüften Weiten 1 bis ${maxAutoSpan} lassen sich die Seiten dieser Zonung nicht vollständig zu gleichweiten Spulen paaren.`
          : `Bei Spulenweite ${coilSpan} lassen sich die Seiten dieser Zonung nicht vollständig zu Spulen paaren.`,
      );
    }
    warnings.push(
      "Für diese Eingabe wird in diesem Zonenmodell kein gültiges Wickelschema ausgegeben. Andere Zonungen oder Wicklungstopologien sind damit nicht ausgeschlossen.",
    );
  }
  const harmonics = [1, 3, 5, 7, 11, 13].map((order) => ({
    order,
    factor:
      phaseResults(selected.slotLayers, order).reduce(
        (sum, phase) => sum + phase.kw,
        0,
      ) / 3,
  }));
  return {
    slots,
    polePairs,
    layers,
    q: slots / (6 * polePairs),
    alphaDeg,
    polePitch,
    coilSpan: selected.span,
    requestedCoilSpan: coilSpan,
    zoneOffsetDeg,
    slotAssignments,
    slotLayers: selected.slotLayers,
    coils: selected.valid ? selected.coils : [],
    phases: selected.phases,
    harmonics,
    balanced: selected.balanced,
    valid: selected.valid,
    warnings,
    metrics: {
      kw: selected.kw,
      imbalance: selected.imbalance,
      phaseErrorDeg: selected.phaseErrorDeg,
      coilCount: selected.valid ? selected.coils.length : 0,
      candidateCount: candidates.length,
      validCandidateCount: viable.length,
    },
    method: {
      name: "Natürliche 60°-Zonung",
      description:
        "Nutenspannungsstern → feste 60°-Zonen → vorzeichenrichtige Summe aller tatsächlichen Spulenseiten → vollständige Spulenpaarung.",
      selection:
        coilSpan === "auto"
          ? "Symmetrische realisierbare Kandidaten: höchster Grundwellen-Wicklungsfaktor, bei Gleichstand kürzeste Spulenweite."
          : "Manuell vorgegebene Spulenweite; vollständige Paarung und Strangsymmetrie werden geprüft.",
      candidateScope:
        coilSpan === "auto"
          ? `Gleichweite Spulen mit y = 1 bis ${maxAutoSpan} (aufgerundete Polteilung); feste Zonung, drei Stränge.`
          : `Gleichweite Spulen mit y = ${coilSpan}; feste Zonung, drei Stränge.`,
      note:
        layers === 1
          ? "Bei fester Einschicht-Zonung bleibt der Strangstern für alle vollständigen Paarungen gleich. Die Automatik verkürzt daher unter den gültigen Paarungen die Weite."
          : "Die zweite Lage wird um y Nuten versetzt und mit umgekehrtem Vorzeichen gebildet. Der Strangstern summiert beide Lagen.",
      limitation:
        "Optimierung nur innerhalb dieses Modells; Kupferbedarf, Wickelkopfkreuzungen, Oberwellen, Verluste und Fertigbarkeit werden nicht gemeinsam optimiert.",
    },
  };
}
