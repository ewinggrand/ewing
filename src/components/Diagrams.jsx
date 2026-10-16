import React, { useEffect, useId, useMemo } from "react";
import { buildWindingLayout } from "../domain/windingLayout.js";

export const PHASE_COLORS = { A: "#c65736", B: "#31806d", C: "#5668c9" };
const INK = "#29372f";
const MUTED = "#758078";
const GRID = "#e1e6df";
const TOOTH = "#2998d0";
const ZONES = ["+A", "-C", "+B", "-A", "+C", "-B"];
const TAU = Math.PI / 180;
const mod = (n, d) => ((n % d) + d) % d;
const point = (x, y, radius, angle) => ({
  x: x + radius * Math.cos(angle * TAU),
  y: y - radius * Math.sin(angle * TAU),
});
const fmt = (n, digits = 3) =>
  Number.isFinite(n)
    ? n.toLocaleString("de-DE", { maximumFractionDigits: digits })
    : "–";
const phaseActive = (selected, phase) =>
  !selected || selected === "all" || selected === "Alle" || selected === phase;
const chosen = (selected, slot) => Number(selected) === Number(slot);
const getSlots = (result) => result.slotAssignments || [];
const getLayers = (result) =>
  result.slotLayers?.length
    ? result.slotLayers
    : getSlots(result).map((slot) => ({ ...slot, layer: 1 }));
const zoneLabel = (slot) => `${slot.sign > 0 ? "+" : "−"}${slot.phase}`;
const keyboard = (callback) => (event) => {
  if (event.key === "Enter" || event.key === " ") {
    event.preventDefault();
    callback?.();
  }
};

function useDiagramId(prefix) {
  return `${prefix}-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
}

function Arrows({ id, small = false }) {
  return (
    <defs>
      {Object.entries(PHASE_COLORS).map(([phase, color]) => (
        <marker
          key={phase}
          id={`${id}-${phase}`}
          markerWidth={small ? 5 : 7}
          markerHeight={small ? 5 : 7}
          refX={small ? 4 : 6}
          refY={small ? 2.5 : 3.5}
          orient="auto"
          markerUnits="strokeWidth"
        >
          <path
            d={small ? "M0,0 L5,2.5 L0,5 Z" : "M0,0 L7,3.5 L0,7 Z"}
            fill={color}
          />
        </marker>
      ))}
    </defs>
  );
}

function Grid({ cx, cy, radius }) {
  return (
    <g fill="none" stroke={GRID} strokeWidth="1">
      {[1 / 3, 2 / 3, 1].map((fraction) => (
        <circle
          key={fraction}
          cx={cx}
          cy={cy}
          r={radius * fraction}
          strokeDasharray={fraction === 1 ? undefined : "2 5"}
        />
      ))}
      <path
        d={`M${cx - radius - 10} ${cy}H${cx + radius + 10} M${cx} ${cy - radius - 10}V${cy + radius + 10}`}
      />
    </g>
  );
}

function annulus(cx, cy, inner, outer, start, end) {
  const a = point(cx, cy, outer, start);
  const b = point(cx, cy, outer, end);
  const c = point(cx, cy, inner, end);
  const d = point(cx, cy, inner, start);
  return `M${a.x} ${a.y}A${outer} ${outer} 0 0 0 ${b.x} ${b.y}L${c.x} ${c.y}A${inner} ${inner} 0 0 1 ${d.x} ${d.y}Z`;
}

export function SlotStar({ result, selectedSlot, onSelectSlot }) {
  const id = useDiagramId("slot");
  const assignments = getSlots(result);
  const cx = 200;
  const cy = 190;
  const radius = 121;
  const zoneOffset = result.zoneOffsetDeg ?? -15;
  const groups = [];
  for (const slot of assignments) {
    const angle = mod(slot.angleDeg, 360);
    const existing = groups.find(
      (group) => Math.abs(group.angle - angle) < 0.0001,
    );
    if (existing) existing.slots.push(slot);
    else groups.push({ angle, slots: [slot] });
  }
  const selected = assignments.find((slot) => chosen(selectedSlot, slot.slot));
  return (
    <div className="diagram-shell slot-star">
      <svg
        className="diagram-svg"
        viewBox="0 0 400 390"
        width="400"
        height="390"
        role="img"
        aria-labelledby={`${id}-title ${id}-desc`}
        style={{
          display: "block",
          width: "100%",
          height: "auto",
          fontFamily: "inherit",
        }}
      >
        <title id={`${id}-title`}>
          Nutenspannungsstern mit sechs Phasenzonen
        </title>
        <desc id={`${id}-desc`}>
          Elektrische Nutwinkel gegen den Uhrzeigersinn. Jeder Zeiger steht für
          eine Nut. Überlagerte Nutnummern teilen denselben elektrischen Winkel.
          Eine Nut kann per Klick oder mit Enter ausgewählt werden.
        </desc>
        <Arrows id={id} small />
        <Grid cx={cx} cy={cy} radius={radius} />
        <g>
          {ZONES.map((zone, index) => {
            const start = zoneOffset + index * 60;
            const label = point(cx, cy, 171, start + 30);
            const color = PHASE_COLORS[zone[1]];
            return (
              <g key={zone}>
                <path
                  d={annulus(cx, cy, 143, 156, start + 0.4, start + 59.6)}
                  fill={color}
                  fillOpacity={zone[0] === "+" ? 0.23 : 0.12}
                  stroke={color}
                  strokeOpacity="0.28"
                  strokeWidth="0.7"
                />
                <text
                  x={label.x}
                  y={label.y + 4}
                  textAnchor="middle"
                  fill={color}
                  fontSize="12"
                  fontWeight="650"
                >
                  {zone.replace("-", "−")}
                </text>
              </g>
            );
          })}
        </g>
        <text x="345" y={cy - 8} fill={MUTED} fontSize="10">
          Re
        </text>
        <text x={cx + 8} y="47" fill={MUTED} fontSize="10">
          Im
        </text>
        {groups.map((group, index) => {
          const groupSelected = group.slots.some((slot) =>
            chosen(selectedSlot, slot.slot),
          );
          const representative = groupSelected
            ? group.slots.find((slot) => chosen(selectedSlot, slot.slot))
            : group.slots[0];
          const end = point(cx, cy, radius - 1, group.angle);
          const label = point(cx, cy, 132, group.angle);
          const labelText =
            group.slots.length <= 3
              ? group.slots.map((slot) => slot.slot).join("·")
              : `${group.slots[0].slot}…`;
          return (
            <g key={index}>
              <line
                x1={cx}
                y1={cy}
                x2={end.x}
                y2={end.y}
                stroke={PHASE_COLORS[representative.phase]}
                strokeWidth={groupSelected ? 2.8 : 1.25}
                strokeOpacity={selected && !groupSelected ? 0.35 : 0.85}
                markerEnd={`url(#${id}-${representative.phase})`}
              />
              {(groups.length <= 48 ||
                index % Math.ceil(groups.length / 48) === 0 ||
                groupSelected) && (
                <text
                  x={label.x}
                  y={label.y + 3.5}
                  textAnchor="middle"
                  fontSize={groups.length > 36 ? 8 : 10.5}
                  fontWeight={groupSelected ? "750" : "500"}
                  fill={
                    groupSelected ? PHASE_COLORS[representative.phase] : INK
                  }
                >
                  {labelText}
                </text>
              )}
              {group.slots.map((slot, slotIndex) => {
                const target = point(
                  cx,
                  cy,
                  radius -
                    20 -
                    slotIndex *
                      Math.min(13, 73 / Math.max(1, group.slots.length - 1)),
                  group.angle,
                );
                return (
                  <g
                    key={slot.slot}
                    role="button"
                    tabIndex="0"
                    aria-label={`Nut ${slot.slot}, Zone ${zoneLabel(slot)}, elektrischer Winkel ${fmt(slot.angleDeg, 1)} Grad`}
                    aria-pressed={chosen(selectedSlot, slot.slot)}
                    onClick={() => onSelectSlot?.(slot.slot)}
                    onKeyDown={keyboard(() => onSelectSlot?.(slot.slot))}
                    style={{ cursor: "pointer", outlineOffset: 3 }}
                  >
                    <title>{`Nut ${slot.slot} · ${zoneLabel(slot)} · ${fmt(slot.angleDeg, 1)}°`}</title>
                    <circle
                      cx={target.x}
                      cy={target.y}
                      r="10"
                      fill="transparent"
                    />
                    <circle
                      cx={target.x}
                      cy={target.y}
                      r={chosen(selectedSlot, slot.slot) ? 4 : 2.4}
                      fill={PHASE_COLORS[slot.phase]}
                      stroke="white"
                      strokeWidth="1.3"
                    />
                  </g>
                );
              })}
            </g>
          );
        })}
        <circle
          cx={cx}
          cy={cy}
          r="3.5"
          fill={INK}
          stroke="white"
          strokeWidth="1.5"
        />
        <text x={cx} y="378" textAnchor="middle" fontSize="11" fill={MUTED}>
          {selected
            ? `Nut ${selected.slot} · ${zoneLabel(selected)} · ${fmt(selected.angleDeg, 1)}° elektrisch`
            : "Nut anklicken, um ihren Zeiger zu verfolgen"}
        </text>
      </svg>
    </div>
  );
}

export function PhaseStar({ result, selectedPhase, onSelectPhase }) {
  const id = useDiagramId("phase");
  const phases = result.phases || [];
  const layers = getLayers(result);
  const cx = 200;
  const cy = 184;
  const sums = phases.map((phase) => {
    const terms = layers.filter((slot) => slot.phase === phase.phase);
    const chain = [{ x: 0, y: 0 }];
    for (const slot of terms) {
      const last = chain[chain.length - 1];
      chain.push({
        x: last.x + slot.sign * Math.cos(slot.angleDeg * TAU),
        y: last.y + slot.sign * Math.sin(slot.angleDeg * TAU),
        slot,
      });
    }
    return { ...phase, terms, chain };
  });
  const extent = Math.max(
    1,
    ...sums.flatMap((phase) => phase.chain.map((p) => Math.hypot(p.x, p.y))),
    ...phases.map((phase) => Math.hypot(phase.x, phase.y)),
  );
  const scale = 124 / extent;
  const xy = (p) => ({ x: cx + p.x * scale, y: cy - p.y * scale });
  return (
    <div className="diagram-shell phase-star">
      <svg
        className="diagram-svg"
        viewBox="0 0 400 390"
        width="400"
        height="390"
        role="img"
        aria-labelledby={`${id}-title ${id}-desc`}
        style={{
          display: "block",
          width: "100%",
          height: "auto",
          fontFamily: "inherit",
        }}
      >
        <title id={`${id}-title`}>
          Strangspannungsstern aus der vorzeichenrichtigen Vektorsumme
        </title>
        <desc id={`${id}-desc`}>
          Je Strang werden alle zugehörigen Nutenspannungsvektoren addiert.
          Negative Seiten gehen mit umgekehrtem Vorzeichen ein. Gestrichelte
          Teilzeiger zeigen die Addition; kräftige Pfeile zeigen die
          resultierenden Strangspannungen.
        </desc>
        <Arrows id={id} small />
        <Grid cx={cx} cy={cy} radius={124} />
        <text x="338" y={cy - 8} fill={MUTED} fontSize="10">
          Re
        </text>
        <text x={cx + 8} y="42" fill={MUTED} fontSize="10">
          Im
        </text>
        {sums.map((phase) => {
          const color = PHASE_COLORS[phase.phase];
          const active = phaseActive(selectedPhase, phase.phase);
          const end = xy(phase);
          const angle = Math.atan2(phase.y, phase.x) / TAU;
          const label = point(end.x, end.y, 21, angle);
          return (
            <g
              key={phase.phase}
              opacity={active ? 1 : 0.17}
              role="button"
              tabIndex="0"
              aria-label={`Strang ${phase.phase}, Wicklungsfaktor ${fmt(phase.kw)}`}
              aria-pressed={selectedPhase === phase.phase}
              onClick={() => onSelectPhase?.(phase.phase)}
              onKeyDown={keyboard(() => onSelectPhase?.(phase.phase))}
              style={{ cursor: "pointer" }}
            >
              <title>{`Strang ${phase.phase}: Σ sₙ · Eₙ, Betrag ${fmt(phase.magnitude)}, k_w = ${fmt(phase.kw)}`}</title>
              {phase.chain.slice(1).map((p, index) => {
                const a = xy(phase.chain[index]);
                const b = xy(p);
                return (
                  <line
                    key={`${p.slot.slot}-${p.slot.layer ?? 1}-${index}`}
                    x1={a.x}
                    y1={a.y}
                    x2={b.x}
                    y2={b.y}
                    stroke={color}
                    strokeOpacity="0.55"
                    strokeWidth="1.1"
                    strokeDasharray="2.5 2.5"
                    markerEnd={
                      phase.terms.length <= 32
                        ? `url(#${id}-${phase.phase})`
                        : undefined
                    }
                  />
                );
              })}
              <line
                x1={cx}
                y1={cy}
                x2={end.x}
                y2={end.y}
                stroke={color}
                strokeWidth="2.8"
                markerEnd={`url(#${id}-${phase.phase})`}
              />
              <line
                x1={cx}
                y1={cy}
                x2={end.x}
                y2={end.y}
                stroke="transparent"
                strokeWidth="22"
              />
              <text
                x={label.x}
                y={label.y + 5}
                fill={color}
                textAnchor="middle"
                fontSize="15"
                fontWeight="700"
              >
                {phase.phase}
              </text>
            </g>
          );
        })}
        <circle
          cx={cx}
          cy={cy}
          r="3.5"
          fill={INK}
          stroke="white"
          strokeWidth="1.5"
        />
        <g transform="translate(51 349)">
          <line
            x1="0"
            x2="23"
            y1="0"
            y2="0"
            stroke={MUTED}
            strokeWidth="1.5"
            strokeDasharray="3 3"
          />
          <text x="30" y="4" fill={MUTED} fontSize="10.5">
            Einzelbeiträge
          </text>
          <line
            x1="157"
            x2="180"
            y1="0"
            y2="0"
            stroke={INK}
            strokeWidth="2.5"
          />
          <text x="187" y="4" fill={MUTED} fontSize="10.5">
            Vektorsumme
          </text>
        </g>
        <text x="200" y="378" textAnchor="middle" fill={MUTED} fontSize="11">
          Eₛ = Σ sₙ · Eₙ · negative Zonen: sₙ = −1
        </text>
      </svg>
    </div>
  );
}

export function ZonePlan({
  result,
  selectedSlot,
  onSelectSlot,
  selectedPhase,
}) {
  const id = useDiagramId("zones");
  const assignments = getSlots(result);
  const layers = getLayers(result);
  const layerCount = Math.max(1, result.layers || 1);
  const step = result.slots <= 24 ? 42 : 31;
  const left = 52;
  const width = Math.max(640, left * 2 + result.slots * step);
  const extra = (width - left * 2 - result.slots * step) / 2;
  const xSlot = (slot) => left + extra + (slot - 0.5) * step;
  const rowHeight = 35;
  const toothY = 43 + layerCount * rowHeight;
  const height = toothY + 80;
  return (
    <div className="diagram-shell zone-plan" style={{ overflowX: "auto" }}>
      <svg
        className="diagram-svg"
        viewBox={`0 0 ${width} ${height}`}
        width={width}
        height={height}
        role="img"
        aria-labelledby={`${id}-title ${id}-desc`}
        style={{
          display: "block",
          width: "100%",
          minWidth: width,
          height: "auto",
          fontFamily: "inherit",
        }}
      >
        <title id={`${id}-title`}>
          Zonenplan: Zuordnung aller Nuten zu Strang und Vorzeichen
        </title>
        <desc id={`${id}-desc`}>
          Jede Spalte entspricht einer Nut. Das Vorzeichen bezeichnet die
          Leiterorientierung. Bei zwei Schichten wird jede tatsächliche
          Spulenseite in einer eigenen Zeile dargestellt.
        </desc>
        {Array.from({ length: layerCount }, (_, index) => (
          <text
            key={index}
            x="14"
            y={52 + index * rowHeight}
            fontSize="10"
            fill={MUTED}
          >
            L{index + 1}
          </text>
        ))}
        {assignments.map((slot) => {
          const x = xSlot(slot.slot);
          const selected = chosen(selectedSlot, slot.slot);
          return (
            <g
              key={slot.slot}
              role="button"
              tabIndex="0"
              aria-label={`Nut ${slot.slot}, ${layers
                .filter((side) => side.slot === slot.slot)
                .map((side) => `Lage ${side.layer}: ${zoneLabel(side)}`)
                .join(", ")}`}
              aria-pressed={selected}
              onClick={() => onSelectSlot?.(slot.slot)}
              onKeyDown={keyboard(() => onSelectSlot?.(slot.slot))}
              style={{ cursor: "pointer" }}
            >
              <title>{`Nut ${slot.slot} · ${fmt(slot.angleDeg, 1)}° elektrisch`}</title>
              <text
                x={x}
                y="20"
                textAnchor="middle"
                fill={selected ? INK : MUTED}
                fontWeight={selected ? "750" : "500"}
                fontSize="11"
              >
                {slot.slot}
              </text>
              {Array.from({ length: layerCount }, (_, index) => {
                const side = layers.find(
                  (item) => item.slot === slot.slot && item.layer === index + 1,
                );
                const color = side ? PHASE_COLORS[side.phase] : MUTED;
                return (
                  <g
                    key={index}
                    opacity={phaseActive(selectedPhase, side?.phase) ? 1 : 0.2}
                  >
                    <rect
                      x={x - step / 2 + 1}
                      y={30 + index * rowHeight}
                      width={step - 2}
                      height={rowHeight - 3}
                      rx="3"
                      fill={color}
                      fillOpacity={selected ? 0.24 : 0.1}
                      stroke={selected ? color : "none"}
                      strokeWidth="1.5"
                    />
                    <text
                      x={x}
                      y={51 + index * rowHeight}
                      textAnchor="middle"
                      fill={color}
                      fontSize="12"
                      fontWeight="650"
                    >
                      {side ? zoneLabel(side) : "–"}
                    </text>
                  </g>
                );
              })}
              <rect
                x={x - 4}
                y={toothY}
                width="8"
                height="24"
                fill="white"
                stroke={selected ? INK : "#d2dcd5"}
                strokeWidth={selected ? 1.6 : 0.8}
              />
            </g>
          );
        })}
        {Array.from({ length: result.slots + 1 }, (_, index) => (
          <rect
            key={index}
            x={xSlot(index + 1) - step + 5}
            y={toothY}
            width={step - 10}
            height="24"
            fill={TOOTH}
            fillOpacity="0.88"
            rx="1"
          />
        ))}
        <g
          transform={`translate(${width / 2 - 100} ${height - 16})`}
          fontSize="10.5"
          fill={MUTED}
        >
          <rect x="0" y="-8" width="11" height="11" fill={TOOTH} rx="1" />
          <text x="17" y="1">
            Zahn
          </text>
          <rect
            x="84"
            y="-8"
            width="8"
            height="11"
            fill="white"
            stroke="#b9c6bd"
          />
          <text x="99" y="1">
            Nut / Spulenseite
          </text>
        </g>
      </svg>
    </div>
  );
}

export function WindingDiagram({
  result,
  selectedPhase,
  selectedSlot,
  onSelectSlot,
  connectionMode = "individual",
  startSlot = "auto",
  onLayoutChange,
}) {
  const id = useDiagramId("winding");
  const layout = useMemo(() => {
    try {
      return buildWindingLayout(result, { connectionMode, startSlot });
    } catch (error) {
      return { valid: false, warnings: [error.message] };
    }
  }, [result, connectionMode, startSlot]);
  useEffect(() => {
    onLayoutChange?.(layout);
  }, [layout, onLayoutChange]);
  const geometry = layout.geometry || {};
  const width = layout.width || 740;
  const height = Math.max(layout.height || 380, (geometry.legendY || 330) + 46);
  const bodyTop = layout.bodyTop ?? geometry.bodyTop ?? 120;
  const bodyBottom = layout.bodyBottom ?? geometry.bodyBottom ?? 240;
  const slots = layout.slots || [];
  const coilPaths = layout.coilPaths || [];
  const groups = layout.groups || [];
  const connections = layout.connections || [];
  const terminals = layout.terminals || [];
  const pitch = layout.slotPitch || geometry.slotPitch || 58;
  const seamLeft = geometry.seamLeft ?? slots[0]?.x ?? 60;
  const seamRight =
    geometry.seamRight ?? slots[slots.length - 1]?.x ?? width - 60;
  const slotGap = geometry.slotGap || 18;
  const layerCount = result?.layers || 1;
  const isSeries = connectionMode === "series";
  const dimensionY = geometry.dimensionY ?? 27;
  const zoneY = geometry.upperZoneLabelY ?? 48;
  const legendY = geometry.legendY ?? height - 43;
  const groupLabelY = geometry.groupLabelY ?? legendY - 32;
  const slotLabelY = geometry.slotLabelY ?? bodyTop - 13;
  const sideList = slots.flatMap((slot) =>
    (slot.sides || []).map((side) => ({
      ...side,
      slot: side.slot ?? slot.slot,
    })),
  );
  const sideByNode = new Map(sideList.map((side) => [side.nodeId, side]));
  const pathPoints = (path) => path?.points || [];
  const pointsAttribute = (points) =>
    points.map((p) => `${p.x ?? p[0]},${p.y ?? p[1]}`).join(" ");
  const casingPoints = (path) => {
    const trimStart = (points) => {
      let remaining = 4;
      while (points.length > 1 && remaining > 0) {
        const a = points[0];
        const b = points[1];
        const distance = Math.hypot(b.x - a.x, b.y - a.y);
        if (distance <= remaining) {
          remaining -= distance;
          points.shift();
        } else {
          points[0] = {
            x: a.x + ((b.x - a.x) * remaining) / distance,
            y: a.y + ((b.y - a.y) * remaining) / distance,
          };
          remaining = 0;
        }
      }
      return points;
    };
    const points = pathPoints(path).map((p) => ({
      x: p.x ?? p[0],
      y: p.y ?? p[1],
    }));
    return trimStart(trimStart(points).reverse()).reverse();
  };
  const allPaths = (element) =>
    element.paths?.length
      ? element.paths
      : element.points?.length
        ? [{ points: element.points }]
        : [];
  const elementOpacity = (phase, touched = true) =>
    phaseActive(selectedPhase, phase)
      ? selectedSlot && !touched
        ? 0.34
        : 0.96
      : 0.12;
  const touches = (...sides) =>
    sides.some((side) => side && chosen(selectedSlot, side.slot));
  const zoneRuns = [];
  for (const slot of slots) {
    const assignment = result?.slotAssignments?.find(
      (side) => side.slot === slot.slot,
    );
    if (!assignment) continue;
    const x1 = Math.max(seamLeft, slot.x - pitch / 2);
    const x2 = Math.min(seamRight, slot.x + pitch / 2);
    if (x2 <= x1) continue;
    const zone = zoneLabel(assignment);
    const previous = zoneRuns[zoneRuns.length - 1];
    if (previous && previous.zone === zone && Math.abs(previous.x2 - x1) < 0.1)
      previous.x2 = x2;
    else zoneRuns.push({ zone, phase: assignment.phase, x1, x2 });
  }
  const dimensions = layout.polePitchDimension || geometry.polePitchDimension;
  const polePitchWidth = (result?.polePitch || 1) * pitch;
  const dimensionX1 = dimensions?.x1 ?? seamLeft;
  const dimensionX2 =
    dimensions?.x2 ?? Math.min(seamRight, dimensionX1 + polePitchWidth);
  const polePitchY = dimensions?.y ?? dimensionY;
  const header = `Wickelschema · Q${result?.slots}/p${result?.polePairs} · ${isSeries ? "Strangverschaltung" : "Einzelspulen"}`;
  const subtitle = `Schnitt in Nut ${layout.startSlot ?? startSlot} · Polteilung τp = ${fmt(result?.polePitch, 3)} Nuten · ${layerCount} Lage${layerCount === 1 ? "" : "n"}`;
  const seamMarks = [];
  for (const coil of coilPaths) {
    for (const path of [
      ...(coil.topPaths || []),
      ...(coil.bottomPaths || []),
    ]) {
      const points = pathPoints(path);
      if (!points.length) continue;
      for (const p of [points[0], points[points.length - 1]]) {
        const x = p.x ?? p[0];
        const y = p.y ?? p[1];
        if (Math.abs(x - seamLeft) < 0.2 || Math.abs(x - seamRight) < 0.2)
          seamMarks.push({ x, y, phase: coil.phase, coil: coil.id });
      }
    }
  }
  for (const connection of connections) {
    for (const path of allPaths(connection)) {
      const points = pathPoints(path);
      if (!points.length) continue;
      for (const p of [points[0], points[points.length - 1]]) {
        const x = p.x ?? p[0];
        const y = p.y ?? p[1];
        if (Math.abs(x - seamLeft) < 0.2 || Math.abs(x - seamRight) < 0.2)
          seamMarks.push({
            x,
            y,
            phase: connection.phase,
            coil: `${connection.fromCoilId} → ${connection.toCoilId}`,
            kind: "series",
          });
      }
    }
  }
  if (layout.valid === false || !slots.length)
    return (
      <div
        className="diagram-shell winding-diagram"
        role="status"
        style={{ padding: 24, fontSize: 12, lineHeight: 1.8, color: MUTED }}
      >
        {(layout.warnings?.length
          ? layout.warnings
          : ["Für dieses Modell liegt kein vollständiges Wickelschema vor."]
        ).map((warning) => (
          <p key={warning}>{warning}</p>
        ))}
      </div>
    );
  return (
    <div
      className={`diagram-shell winding-diagram${isSeries ? " winding-series" : ""}`}
      style={{ overflowX: "auto" }}
    >
      <svg
        className="diagram-svg"
        viewBox={`0 0 ${width} ${height}`}
        width={width}
        height={height}
        role="img"
        aria-labelledby={`${id}-title ${id}-desc`}
        data-export-title={header}
        data-export-subtitle={subtitle}
        data-winding-start-slot={layout.startSlot}
        data-winding-mode={connectionMode}
        style={{
          display: "block",
          width: "100%",
          minWidth: width,
          height: "auto",
          maxHeight: "none",
          fontFamily: "inherit",
        }}
      >
        <title id={`${id}-title`}>{`${header}. ${subtitle}`}</title>
        <desc
          id={`${id}-desc`}
        >{`Abwicklung des Stators mit blauen rechteckigen Zähnen und weißen Nuten dazwischen. Die Leiter liegen ausschließlich in den Nuten. Gleiche Spulenweiten besitzen gleiche Wickelkopfsteigungen. Der Schnitt in Nut ${layout.startSlot} wird an beiden Rändern gezeigt; seine elektrischen Leiterseiten werden insgesamt genau einmal dargestellt. ${isSeries ? "Jeder Strang bildet einen unverzweigten Leiterweg zwischen zwei offenen Stranganschlüssen. Die unteren V-Köpfe sind an den Spulenenden geöffnet und über die gezeichneten Gruppenverbindungen additiv in Reihe geschaltet. Kreuzungen ohne Verbindungspunkt sind getrennt." : "Die einzelnen Spulen besitzen offene Anschlussenden im unteren Wickelkopf. Eine geschlossene kurzgeschlossene Einzelwindung wird nicht gezeichnet."} Die Polteilung und die Zonen der ersten Lage sind markiert. Bei zwei Lagen ist die seitliche Auffächerung nur eine schematische Trennung der Leiter.`}</desc>
        <defs>
          {Object.entries(PHASE_COLORS).map(([phase, color]) => (
            <marker
              key={phase}
              id={`${id}-${phase}`}
              markerWidth="4.5"
              markerHeight="4.5"
              refX="4"
              refY="2.25"
              orient="auto"
              markerUnits="userSpaceOnUse"
            >
              <path d="M0 0L4.5 2.25L0 4.5Z" fill={color} />
            </marker>
          ))}
          <marker
            id={`${id}-dimension`}
            markerWidth="7"
            markerHeight="7"
            refX="6"
            refY="3.5"
            orient="auto-start-reverse"
            markerUnits="userSpaceOnUse"
          >
            <path d="M0 0L7 3.5L0 7Z" fill={INK} />
          </marker>
          <clipPath id={`${id}-clip`}>
            <rect
              x={seamLeft - 8}
              y="0"
              width={seamRight - seamLeft + 16}
              height={height}
            />
          </clipPath>
        </defs>
        <g fill="none" stroke={INK} strokeWidth="1">
          <line
            x1={dimensionX1 + 2}
            y1={polePitchY}
            x2={dimensionX2 - 2}
            y2={polePitchY}
            markerStart={`url(#${id}-dimension)`}
            markerEnd={`url(#${id}-dimension)`}
          />
          <path
            d={`M${dimensionX1} ${polePitchY - 7}v17 M${dimensionX2} ${polePitchY - 7}v17`}
            stroke="#adb7a4"
            strokeDasharray="3 3"
          />
        </g>
        <text
          x={(dimensionX1 + dimensionX2) / 2}
          y={polePitchY - 9}
          fill={INK}
          fontFamily="Georgia, serif"
          fontStyle="italic"
          fontSize="13"
          textAnchor="middle"
        >{`τₚ = ${fmt(result?.polePitch, 3)} Nuten`}</text>
        <text
          x={seamRight}
          y={polePitchY + 2}
          textAnchor="end"
          fill={MUTED}
          fontSize="9"
        >{`Schnitt: Nut ${layout.startSlot}${startSlot === "auto" ? " · automatisch" : ""}`}</text>
        <text x="12" y={zoneY + 3} fill={MUTED} fontSize="7.5">
          ZONE L1
        </text>
        <g>
          {zoneRuns.map((run, index) => (
            <g
              key={`zone-${index}`}
              opacity={phaseActive(selectedPhase, run.phase) ? 1 : 0.22}
            >
              <rect
                x={run.x1 + 0.5}
                y={zoneY - 10}
                width={Math.max(0, run.x2 - run.x1 - 1)}
                height="20"
                rx="2"
                fill={PHASE_COLORS[run.phase]}
                fillOpacity="0.08"
              />
              <text
                x={(run.x1 + run.x2) / 2}
                y={zoneY + 3}
                textAnchor="middle"
                fill={PHASE_COLORS[run.phase]}
                fontWeight="600"
                fontSize="10"
              >
                {run.zone}
              </text>
            </g>
          ))}
        </g>
        <g
          stroke="#acb7a4"
          strokeWidth="0.8"
          strokeDasharray="4 5"
          opacity="0.6"
        >
          {[
            ...new Set([
              seamLeft,
              ...zoneRuns.slice(1).map((run) => run.x1),
              seamRight,
            ]),
          ].map((x) => (
            <line key={x} x1={x} x2={x} y1={zoneY + 13} y2={bodyBottom + 8} />
          ))}
        </g>
        {(layout.teeth || []).map((tooth, index) => {
          const previousSlot = slots
            .filter((slot) => slot.x <= tooth.x + tooth.width / 2)
            .at(-1);
          const toothNumber =
            tooth.toothNumber ?? previousSlot?.slot ?? index + 1;
          return (
            <g key={tooth.index ?? index}>
              <rect
                data-winding-tooth={toothNumber}
                x={tooth.x}
                y={tooth.y ?? bodyTop}
                width={tooth.width}
                height={tooth.height ?? bodyBottom - bodyTop}
                rx="0.5"
                fill={TOOTH}
                fillOpacity="0.93"
                stroke="#1680b7"
                strokeWidth="0.9"
              />
              <text
                x={tooth.x + tooth.width / 2}
                y={geometry.toothLabelY ?? (bodyTop + bodyBottom) / 2 + 3}
                textAnchor="middle"
                fill="#eaf8ff"
                fontSize={pitch < 40 ? "8" : "9"}
                fontWeight="600"
              >{`Z${toothNumber}`}</text>
            </g>
          );
        })}
        <g>
          {coilPaths.map((coil, index) => {
            const positive = coil.positiveSide;
            const negative = coil.negativeSide;
            const selected = touches(positive, negative);
            const color = PHASE_COLORS[coil.phase];
            const paths = [
              ...(coil.topPaths || []),
              ...(coil.bottomPaths || []),
            ];
            const labelY =
              coil.labelY ??
              Math.min(
                ...(coil.topPaths || []).flatMap((path) =>
                  pathPoints(path).map((point) => point.y ?? point[1]),
                ),
              ) - 6;
            return (
              <g
                key={coil.id ?? index}
                data-winding-coil={coil.id}
                opacity={elementOpacity(coil.phase, selected)}
                stroke={color}
                fill="none"
                strokeWidth={selected ? 2.7 : 1.8}
                strokeLinejoin="round"
                strokeLinecap="round"
              >
                <title>{`Spule ${coil.id}: Strang ${coil.phase}, positiv Nut ${positive?.slot} Lage ${positive?.layer}, negativ Nut ${negative?.slot} Lage ${negative?.layer}, Spulenweite ${coil.span} Nuten. Offene Anschlussenden im unteren Wickelkopf.`}</title>
                {paths.map((path, pathIndex) => (
                  <polyline
                    key={`casing-${pathIndex}`}
                    points={pointsAttribute(casingPoints(path))}
                    stroke="#fffef9"
                    strokeWidth="5.4"
                    aria-hidden="true"
                  />
                ))}
                {paths.map((path, pathIndex) => (
                  <polyline
                    key={pathIndex}
                    points={pointsAttribute(pathPoints(path))}
                  />
                ))}
                {coilPaths.length <= 36 && Number.isFinite(labelY) && (
                  <text
                    x={coil.labelX ?? (positive.x + negative.x) / 2}
                    y={labelY}
                    textAnchor="middle"
                    fill={color}
                    stroke="none"
                    fontWeight="600"
                    fontSize="8.5"
                  >
                    {coil.id}
                  </text>
                )}
              </g>
            );
          })}
          {sideList.map((side, index) => {
            const color = PHASE_COLORS[side.phase];
            const selected = chosen(selectedSlot, side.slot);
            const top = side.yTop ?? bodyTop;
            const bottom = side.yBottom ?? bodyBottom;
            const middle = (top + bottom) / 2;
            return (
              <g
                key={side.nodeId ?? `${side.slot}-${side.layer}-${index}`}
                data-winding-side={side.nodeId ?? `${side.slot}-${side.layer}`}
                opacity={elementOpacity(side.phase, selected)}
                stroke={color}
                fill="none"
                strokeLinecap="round"
              >
                <title>{`Nut ${side.slot}, Lage ${side.layer}, ${zoneLabel(side)}: ${side.sign > 0 ? "positive Seite, Pfeil nach oben" : "negative Seite, Pfeil nach unten"}`}</title>
                <line
                  x1={side.x}
                  x2={side.x}
                  y1={top + 4}
                  y2={bottom - 4}
                  stroke="#fffef9"
                  strokeWidth="5.4"
                  aria-hidden="true"
                />
                <line
                  x1={side.x}
                  x2={side.x}
                  y1={top}
                  y2={bottom}
                  strokeWidth={selected ? 2.7 : 1.8}
                />
                <line
                  x1={side.x}
                  x2={side.x}
                  y1={middle + (side.sign > 0 ? 12 : -12)}
                  y2={middle + (side.sign > 0 ? -12 : 12)}
                  strokeWidth="1.5"
                  markerEnd={`url(#${id}-${side.phase})`}
                />
              </g>
            );
          })}
          {connections.map((connection, index) => {
            const selected = touches(
              sideByNode.get(connection.fromNode),
              sideByNode.get(connection.toNode),
            );
            return (
              <g
                key={connection.id ?? index}
                data-winding-link={connection.id}
                opacity={elementOpacity(connection.phase, selected)}
                stroke={PHASE_COLORS[connection.phase]}
                strokeWidth={selected ? 2.5 : 1.8}
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <title>{`Strang ${connection.phase}: additive Serienverbindung ${connection.fromCoilId} → ${connection.toCoilId}, ${connection.fromNode} → ${connection.toNode}. Kreuzungen ohne Punkt sind getrennt.`}</title>
                {allPaths(connection).map((path, pathIndex) => (
                  <polyline
                    key={`casing-${pathIndex}`}
                    points={pointsAttribute(casingPoints(path))}
                    stroke="#fffef9"
                    strokeWidth="5.4"
                    aria-hidden="true"
                  />
                ))}
                {allPaths(connection).map((path, pathIndex) => (
                  <polyline
                    key={pathIndex}
                    points={pointsAttribute(pathPoints(path))}
                  />
                ))}
              </g>
            );
          })}
          {terminals.map((terminal, index) => {
            const color = PHASE_COLORS[terminal.phase];
            const side = sideByNode.get(terminal.nodeId);
            const terminalLabel = terminal.label ?? terminal.id;
            const partner =
              !isSeries &&
              terminals.find(
                (candidate) =>
                  candidate.coilId === terminal.coilId &&
                  candidate.id !== terminal.id,
              );
            const labelOnLeft = partner && terminal.x < partner.x;
            const labelX =
              terminal.labelX ??
              (partner ? terminal.x + (labelOnLeft ? -5 : 5) : terminal.x);
            const labelAnchor =
              terminal.textAnchor ??
              (partner ? (labelOnLeft ? "end" : "start") : "middle");
            return (
              <g
                key={terminal.id ?? index}
                data-winding-terminal={terminalLabel}
                opacity={elementOpacity(terminal.phase, touches(side))}
                stroke={color}
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
                fill="none"
              >
                <title>{`${terminalLabel}: offener ${terminal.type === "start" ? "Anfang" : "Endanschluss"} des Strangs ${terminal.phase}${side ? `, Nut ${side.slot}, Lage ${side.layer}` : ""}`}</title>
                {allPaths(terminal).map((path, pathIndex) => (
                  <polyline
                    key={`casing-${pathIndex}`}
                    points={pointsAttribute(casingPoints(path))}
                    stroke="#fffef9"
                    strokeWidth="5.4"
                    aria-hidden="true"
                  />
                ))}
                {allPaths(terminal).map((path, pathIndex) => (
                  <polyline
                    key={pathIndex}
                    points={pointsAttribute(pathPoints(path))}
                  />
                ))}
                <circle
                  cx={terminal.x}
                  cy={terminal.y}
                  r="3.2"
                  fill="#fffef9"
                />
                <text
                  x={labelX}
                  y={terminal.labelY ?? terminal.y + 16}
                  textAnchor={labelAnchor}
                  fill={color}
                  stroke="none"
                  fontSize={isSeries ? "11" : "9"}
                  fontWeight="650"
                >
                  {terminalLabel}
                </text>
              </g>
            );
          })}
        </g>
        {seamMarks.map((mark, index) => (
          <g
            key={`seam-${index}`}
            opacity={phaseActive(selectedPhase, mark.phase) ? 0.9 : 0.15}
            stroke={PHASE_COLORS[mark.phase]}
            strokeWidth="1"
            fill="none"
          >
            <title>{`${mark.kind === "series" ? "Serienverbindung" : "Spule"} ${mark.coil}: Fortsetzung über den Abwicklungsschnitt auf gleicher Höhe`}</title>
            <path
              d={`M${mark.x - 3} ${mark.y - 4}l5 8 M${mark.x + 1} ${mark.y - 4}l5 8`}
            />
          </g>
        ))}
        <text x="12" y={slotLabelY} fill={MUTED} fontSize="8.5">
          NUT
        </text>
        {slots.map((slot, index) => {
          const selected = chosen(selectedSlot, slot.slot);
          const isEdge = index === 0 || index === slots.length - 1;
          return (
            <g
              key={`${slot.slot}-${index}`}
              role="button"
              tabIndex="0"
              aria-label={`Nut ${slot.slot}${isEdge ? ", am Abwicklungsschnitt" : ""}, ${(slot.sides || []).map((side) => `Lage ${side.layer}, ${zoneLabel(side)}`).join("; ")}`}
              aria-pressed={selected}
              onClick={() => onSelectSlot?.(slot.slot)}
              onKeyDown={keyboard(() => onSelectSlot?.(slot.slot))}
              style={{ cursor: "pointer" }}
            >
              <title>{`Nut ${slot.slot}${isEdge ? ": geteilte Schnittnut, elektrisch nur einmal vorhanden" : ": weißer Spalt zwischen den blauen Zähnen"}`}</title>
              <rect
                x={slot.x - slotGap / 2 - 1}
                y={bodyTop - 3}
                width={slotGap + 2}
                height={bodyBottom - bodyTop + 6}
                fill="transparent"
                stroke={selected ? INK : "transparent"}
                strokeWidth="1"
                strokeDasharray="3 3"
                rx="1"
              />
              <text
                x={slot.x}
                y={slotLabelY}
                textAnchor="middle"
                fill={selected ? INK : MUTED}
                fontSize="10"
                fontWeight={selected ? "750" : "500"}
                paintOrder="stroke"
                stroke="#fffef9"
                strokeWidth="3"
              >
                {slot.slot}
              </text>
            </g>
          );
        })}
        {groups.map((group, index) => {
          const samePhaseGroups = groups.filter(
            (candidate) => candidate.phase === group.phase,
          );
          const groupIndex =
            samePhaseGroups.findIndex(
              (candidate) => candidate.id === group.id,
            ) + 1;
          const label =
            group.label && group.label !== group.phase
              ? group.label
              : samePhaseGroups.length > 1
                ? `${group.phase}${groupIndex}`
                : `Strang ${group.phase}`;
          return (
            <g
              key={group.id ?? index}
              opacity={phaseActive(selectedPhase, group.phase) ? 1 : 0.2}
            >
              <text
                x={group.centerX ?? (group.startX + group.endX) / 2}
                y={group.labelY ?? groupLabelY}
                textAnchor="middle"
                fill={PHASE_COLORS[group.phase]}
                fontSize={groups.length > 18 ? "9" : "11"}
                fontWeight="650"
              >
                {label}
              </text>
            </g>
          );
        })}
        <g
          transform={`translate(${Math.max(24, width / 2 - (layerCount === 2 ? 266 : 194))} ${legendY})`}
          fontSize="9.5"
          fill={MUTED}
        >
          <rect x="0" y="-8" width="11" height="11" fill={TOOTH} />
          <text x="17" y="1">
            Zahn Zₙ
          </text>
          <rect
            x="89"
            y="-8"
            width="11"
            height="11"
            fill="white"
            stroke="#c4cec0"
          />
          <path d="M94.5 -7V2" stroke={PHASE_COLORS.A} strokeWidth="1.4" />
          <text x="106" y="1">
            Nut mit Leiter
          </text>
          <path d="M218 -8l5 9m0 -9 5 9" stroke={MUTED} fill="none" />
          <text x="237" y="1">
            Fortsetzung
          </text>
          {layerCount === 2 && (
            <text x="334" y="1">
              L2 links · L1 rechts*
            </text>
          )}
        </g>
        <text
          x={width / 2}
          y={legendY + 21}
          textAnchor="middle"
          fill={MUTED}
          fontSize="9"
        >
          {layerCount === 2
            ? "*Seitliche Auffächerung zur Lesbarkeit; beide Lagen gehören zur selben Nut."
            : "Zₙ bezeichnet den Zahn nach Nut n im zunehmenden Nutumlauf."}
        </text>
        <text
          x={width / 2}
          y={legendY + 36}
          textAnchor="middle"
          fill={MUTED}
          fontSize="8.5"
        >
          {isSeries
            ? "Offene Stranganschlüsse · Kreuzungen ohne Punkt getrennt · schematische Gruppenverbindung"
            : "Offene Einzelspulen · Spulenenden am unteren V-Kopf · keine vorgegebene Strangverschaltung"}
        </text>
      </svg>
    </div>
  );
}
