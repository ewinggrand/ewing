/** Pure view model: electrical coil data is never changed by display rotation. */
const PHASES = ["A", "B", "C"];
const TERMINAL_NAMES = { A: "U", B: "V", C: "W" };
const mod = (value, period) => ((value % period) + period) % period;
const near = (a, b) => Math.abs(a - b) < 1e-7;
const point = (x, y) => ({ x, y });
const sideNode = (slot, layer) => `slot-${slot}-layer-${layer}`;

/** Clip unwrapped line segments at every periodic seam, preserving cut height. */
export function splitPeriodicPolyline(points, left, period) {
  const paths = [];
  for (let index = 1; index < points.length; index += 1) {
    const a = points[index - 1];
    const b = points[index];
    const cuts = [0, 1];
    if (!near(a.x, b.x)) {
      const min = Math.min(a.x, b.x);
      const max = Math.max(a.x, b.x);
      for (
        let cell = Math.floor((min - left) / period) + 1;
        left + cell * period < max - 1e-8;
        cell += 1
      ) {
        cuts.push((left + cell * period - a.x) / (b.x - a.x));
      }
    }
    cuts.sort((x, y) => x - y);
    for (let piece = 1; piece < cuts.length; piece += 1) {
      const t0 = cuts[piece - 1];
      const t1 = cuts[piece];
      const middleX = a.x + ((b.x - a.x) * (t0 + t1)) / 2;
      const cell = Math.floor((middleX - left + 1e-9) / period);
      const mapped = (t) =>
        point(a.x + (b.x - a.x) * t - cell * period, a.y + (b.y - a.y) * t);
      const first = mapped(t0);
      const last = mapped(t1);
      const previous = paths.at(-1);
      if (
        previous &&
        previous.cell === cell &&
        near(previous.points.at(-1).x, first.x) &&
        near(previous.points.at(-1).y, first.y)
      ) {
        previous.points.push(last);
      } else paths.push({ points: [first, last], cell });
    }
  }
  return paths.map(({ points: pathPoints }) => ({
    points: pathPoints,
    wrapped: paths.length > 1,
  }));
}

export function buildWindingLayout(
  result,
  { startSlot = "auto", connectionMode = "series" } = {},
) {
  if (!["series", "individual"].includes(connectionMode))
    throw new Error("Die Verbindungsart muss „series“ oder „individual“ sein.");
  const count = result?.slots;
  if (
    startSlot !== "auto" &&
    (!Number.isInteger(startSlot) ||
      !Number.isInteger(count) ||
      startSlot < 1 ||
      startSlot > count)
  ) {
    throw new Error(
      `Die Schnittnut muss zwischen 1 und ${count ?? "Q"} liegen.`,
    );
  }
  if (!result?.valid || !result.coils?.length || !result.slotLayers?.length) {
    return {
      valid: false,
      width: 640,
      height: 220,
      startSlot: null,
      canonicalStartSlot: null,
      connectionMode,
      teeth: [],
      slots: [],
      coilPaths: [],
      orderedCoils: [],
      groups: [],
      connections: [],
      seriesConnections: [],
      terminals: [],
      topology: { nodes: [], edges: [], phaseChains: [] },
      warnings: [
        "Ohne gültige vollständige Wicklung wird kein Wickelschema gezeichnet.",
      ],
    };
  }
  const pitch = Math.max(count <= 24 ? 58 : 36, 520 / count);
  const left = 60;
  const period = count * pitch;
  const right = left + period;
  const lane = result.layers === 2 ? Math.min(6, pitch * 0.12) : 0;
  const offset = (layer) =>
    result.layers === 2 ? (layer === 1 ? lane : -lane) : 0;
  const xFor = (slot, layer, cut) =>
    left + mod(mod(slot - cut, count) * pitch + offset(layer), period);
  const originalCoils = result.coils.map((coil) => ({
    ...coil,
    positiveLayer: coil.positiveLayer ?? 1,
    negativeLayer: coil.negativeLayer ?? 1,
    direction:
      coil.direction ??
      (mod(coil.negativeSlot - coil.positiveSlot, count) === coil.span
        ? 1
        : -1),
  }));
  const measuresAt = (cut) =>
    originalCoils
      .map((coil) => {
        const positiveX = xFor(coil.positiveSlot, coil.positiveLayer, cut);
        const negativeUnwrappedX =
          positiveX +
          coil.direction * coil.span * pitch +
          offset(coil.negativeLayer) -
          offset(coil.positiveLayer);
        return {
          coil,
          positiveX,
          negativeUnwrappedX,
          centerX:
            left + mod((positiveX + negativeUnwrappedX) / 2 - left, period),
          wrapped:
            negativeUnwrappedX < left - 1e-7 ||
            negativeUnwrappedX > right + 1e-7,
        };
      })
      .sort(
        (a, b) => a.centerX - b.centerX || a.coil.id.localeCompare(b.coil.id),
      );
  const scoreAt = (cut) => {
    const measures = measuresAt(cut);
    const runs = measures.reduce(
      (sum, item, index) =>
        sum +
        (index === 0 || item.coil.phase !== measures[index - 1].coil.phase
          ? 1
          : 0),
      0,
    );
    return [
      measures.filter((item) => item.wrapped).length,
      runs,
      PHASES.indexOf(measures[0].coil.phase),
      cut,
    ];
  };
  const compare = (a, b) => {
    for (let i = 0; i < a.length; i += 1) if (a[i] !== b[i]) return a[i] - b[i];
    return 0;
  };
  const canonicalCut = Array.from(
    { length: count },
    (_, index) => index + 1,
  ).sort((a, b) => compare(scoreAt(a), scoreAt(b)))[0];
  const canonicalIds = measuresAt(canonicalCut).map((item) => item.coil.id);
  const cut = startSlot === "auto" ? canonicalCut : startSlot;
  const measures = measuresAt(cut);
  const slope = 0.65;
  const maxHeadHeight = Math.max(
    ...measures.map(
      (item) =>
        (Math.abs(item.negativeUnwrappedX - item.positiveX) * slope) / 2,
    ),
  );
  const bodyTop = 70 + maxHeadHeight;
  const bodyBottom = bodyTop + (count <= 24 ? 128 : 110);
  const sides = result.slotLayers.map((side) => ({
    ...side,
    nodeId: sideNode(side.slot, side.layer),
    x: xFor(side.slot, side.layer, cut),
    yTop: bodyTop,
    yBottom: bodyBottom,
  }));
  const sideMap = new Map(sides.map((side) => [side.nodeId, side]));
  const slots = Array.from({ length: count + 1 }, (_, displayIndex) => {
    const slot = mod(cut - 1 + displayIndex, count) + 1;
    const x = left + displayIndex * pitch;
    return {
      slot,
      displayIndex,
      x,
      sides: sides.filter(
        (side) => side.slot === slot && Math.abs(side.x - x) < pitch / 3,
      ),
      isSeam: displayIndex === 0 || displayIndex === count,
    };
  });
  const teeth = Array.from({ length: count }, (_, index) => ({
    index,
    toothNumber: mod(cut - 1 + index, count) + 1,
    x: left + (index + 0.5) * pitch - pitch * 0.28,
    y: bodyTop + 8,
    width: pitch * 0.56,
    height: bodyBottom - bodyTop - 16,
  }));
  const coilPaths = measures.map(
    ({ coil, positiveX, negativeUnwrappedX, centerX, wrapped }) => {
      const mid = (positiveX + negativeUnwrappedX) / 2;
      const width = Math.abs(negativeUnwrappedX - positiveX);
      const h = (width * slope) / 2;
      const gap = Math.min(8, width * 0.24);
      const positiveIsLeft = positiveX < negativeUnwrappedX;
      const positivePortX = mid + (positiveIsLeft ? -gap / 2 : gap / 2);
      const negativePortX = mid + (positiveIsLeft ? gap / 2 : -gap / 2);
      const portY = bodyBottom + h - (gap * slope) / 2;
      const mappedPort = (x, nodeId) => ({
        x: left + mod(x - left, period),
        y: portY,
        nodeId,
      });
      const positiveSide = sideMap.get(
        sideNode(coil.positiveSlot, coil.positiveLayer),
      );
      const negativeSide = sideMap.get(
        sideNode(coil.negativeSlot, coil.negativeLayer),
      );
      return {
        ...coil,
        positiveSide,
        negativeSide,
        centerX,
        labelX: centerX,
        wrapped,
        headHeight: h,
        headSlope: slope,
        positivePort: mappedPort(positivePortX, positiveSide.nodeId),
        negativePort: mappedPort(negativePortX, negativeSide.nodeId),
        topPaths: splitPeriodicPolyline(
          [
            point(positiveX, bodyTop),
            point(mid, bodyTop - h),
            point(negativeUnwrappedX, bodyTop),
          ],
          left,
          period,
        ),
        bottomPaths: [
          ...splitPeriodicPolyline(
            [point(positiveX, bodyBottom), point(positivePortX, portY)],
            left,
            period,
          ),
          ...splitPeriodicPolyline(
            [
              point(negativeUnwrappedX, bodyBottom),
              point(negativePortX, portY),
            ],
            left,
            period,
          ),
        ],
      };
    },
  );
  const groups = [];
  for (const coil of coilPaths) {
    let group = groups.at(-1);
    if (!group || group.phase !== coil.phase) {
      group = {
        id: `group-${groups.length + 1}`,
        phase: coil.phase,
        label: coil.phase,
        coilIds: [],
        centers: [],
      };
      groups.push(group);
    }
    group.coilIds.push(coil.id);
    group.centers.push(coil.centerX);
    coil.groupId = group.id;
  }
  groups.forEach((group, index) => {
    group.centerX =
      group.centers.reduce((sum, x) => sum + x, 0) / group.centers.length;
    group.startX =
      index === 0
        ? left
        : (groups[index - 1].centers.at(-1) + group.centers[0]) / 2;
    group.endX =
      index === groups.length - 1
        ? right
        : (group.centers.at(-1) + groups[index + 1].centers[0]) / 2;
  });
  groups.forEach((group) => {
    delete group.centers;
  });
  const connections = [];
  // Reuse compact local routing lanes only where their periodic x-intervals
  // are disjoint. Padding separates neighboring bridges in a tooth group.
  const routingLanes = [];
  const terminals = [];
  const coilMap = new Map(coilPaths.map((coil) => [coil.id, coil]));
  const canonicalCoils = canonicalIds.map((id) => coilMap.get(id));
  const edges = canonicalCoils.map((coil) => ({
    id: `coil-${coil.id}`,
    type: "coil",
    phase: coil.phase,
    from: coil.positiveSide.nodeId,
    to: coil.negativeSide.nodeId,
    coilId: coil.id,
  }));
  const phaseChains = [];
  const orderedCoils = [];
  for (const phase of PHASES) {
    const phaseCoils = canonicalCoils.filter((coil) => coil.phase === phase);
    orderedCoils.push(...phaseCoils);
    const chains =
      connectionMode === "series"
        ? [phaseCoils]
        : phaseCoils.map((coil) => [coil]);
    for (const chain of chains) {
      if (!chain.length) continue;
      const chainConnections = [];
      for (let index = 0; index < chain.length - 1; index += 1) {
        const from = chain[index];
        const to = chain[index + 1];
        const a = from.negativePort;
        const b = to.positivePort;
        const delta = mod(b.x - a.x + period / 2, period) - period / 2;
        const endX = a.x + delta;
        const padding = Math.max(6, pitch * 0.12);
        const intervals = splitPeriodicPolyline(
          [
            point(Math.min(a.x, endX) - padding, 0),
            point(Math.max(a.x, endX) + padding, 0),
          ],
          left,
          period,
        ).map((path) => [
          Math.min(...path.points.map((p) => p.x)),
          Math.max(...path.points.map((p) => p.x)),
        ]);
        let routeLane = routingLanes.findIndex((occupied) =>
          intervals.every(([min, max]) =>
            occupied.every(([aMin, aMax]) => max <= aMin || min >= aMax),
          ),
        );
        if (routeLane < 0) {
          routeLane = routingLanes.length;
          routingLanes.push([]);
        }
        routingLanes[routeLane].push(...intervals);
        const routeY = bodyBottom + maxHeadHeight + 18 + routeLane * 12;
        const paths = splitPeriodicPolyline(
          [
            point(a.x, a.y),
            point(a.x, routeY),
            point(endX, routeY),
            point(endX, b.y),
          ],
          left,
          period,
        );
        const connection = {
          id: `link-${from.id}-${to.id}`,
          phase,
          fromNode: from.negativeSide.nodeId,
          toNode: to.positiveSide.nodeId,
          fromCoilId: from.id,
          toCoilId: to.id,
          groupId: from.groupId === to.groupId ? from.groupId : null,
          paths,
          points: paths.length === 1 ? paths[0].points : [],
          routeY,
          routeLane,
        };
        connections.push(connection);
        chainConnections.push(connection);
        edges.push({
          id: connection.id,
          type: "connection",
          phase,
          from: connection.fromNode,
          to: connection.toNode,
        });
      }
      const chainId = `${phase}-${phaseChains.filter((item) => item.phase === phase).length + 1}`;
      const first = chain[0];
      const last = chain.at(-1);
      phaseChains.push({
        id: chainId,
        phase,
        coilIds: chain.map((coil) => coil.id),
        nodeIds: chain.flatMap((coil) => [
          coil.positiveSide.nodeId,
          coil.negativeSide.nodeId,
        ]),
        startNodeId: first.positiveSide.nodeId,
        endNodeId: last.negativeSide.nodeId,
      });
      const terminalY =
        Math.max(
          ...chain.map((coil) => coil.positivePort.y),
          ...chainConnections.map((link) => link.routeY),
        ) + 27;
      for (const [type, coil, side, port, suffix] of [
        ["start", first, first.positiveSide, first.positivePort, "1"],
        ["end", last, last.negativeSide, last.negativePort, "2"],
      ]) {
        const paths = [
          {
            points: [point(port.x, port.y), point(port.x, terminalY)],
            wrapped: false,
          },
        ];
        terminals.push({
          id: `${chainId}-${type}`,
          type,
          phase,
          label:
            connectionMode === "series"
              ? `${TERMINAL_NAMES[phase]}${suffix}`
              : `${coil.id}${type === "start" ? "+" : "−"}`,
          nodeId: side.nodeId,
          coilId: coil.id,
          slot: side.slot,
          layer: side.layer,
          groupId: coil.groupId,
          x: port.x,
          y: terminalY,
          paths,
          points: paths[0].points,
        });
      }
    }
  }
  const maxBottomY = Math.max(
    bodyBottom + maxHeadHeight,
    ...connections.map((link) => link.routeY),
    ...terminals.map((terminal) => terminal.y + 16),
  );
  const geometry = {
    seamLeft: left,
    seamRight: right,
    period,
    slotGap: pitch * 0.44,
    laneOffset: lane,
    layerOffsets: { 1: offset(1), 2: offset(2) },
    minHeadY: bodyTop - maxHeadHeight,
    maxHeadY: bodyBottom + maxHeadHeight,
    dimensionY: 26,
    slotLabelY: bodyTop - 25,
    toothLabelY: bodyBottom - 15,
    groupLabelY: maxBottomY + 29,
    annotationY: maxBottomY + 52,
    zoneLabelY: maxBottomY + 29,
    legendY: maxBottomY + 77,
  };
  return {
    valid: true,
    width: right + left,
    height: geometry.legendY + 36,
    startSlot: cut,
    canonicalStartSlot: canonicalCut,
    connectionMode,
    slotPitch: pitch,
    bodyTop,
    bodyBottom,
    teeth,
    slots,
    coilPaths,
    orderedCoils,
    groups,
    connections,
    seriesConnections: connections,
    terminals,
    topology: {
      nodes: sides.map((side) => ({
        id: side.nodeId,
        slot: side.slot,
        layer: side.layer,
        phase: side.phase,
        sign: side.sign,
      })),
      edges,
      phaseChains,
    },
    geometry,
    polePitchDimension: {
      x1: left,
      x2: left + result.polePitch * pitch,
      y: geometry.dimensionY,
      label: `τₚ = ${result.polePitch}`,
    },
    zoneBoundaries: groups
      .slice(1)
      .map((group, index) => ({
        x: group.startX,
        phaseLeft: groups[index].phase,
        phaseRight: group.phase,
      })),
    description: `Zyklisch abgewickelt ab Nut ${cut}; Leiter in den Nuten zwischen den Zähnen. ${connectionMode === "series" ? "Jeder Strang bildet eine additive offene Reihenschaltung." : "Jede Spule hat zwei offene Einzelanschlüsse."} Lagen sind zur Lesbarkeit seitlich aufgefächert: L1 rechts, L2 links.`,
    warnings: [],
  };
}
