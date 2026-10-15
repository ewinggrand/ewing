import React, { useId } from "react";

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
}) {
  const id = useDiagramId("winding");
  const assignments = getSlots(result);
  const coils = result.coils || [];
  const layerCount = Math.max(1, result.layers || 1);
  const step = result.slots <= 24 ? 47 : 35;
  const left = 43;
  const width = Math.max(680, left * 2 + (result.slots - 1) * step);
  const actualStep = (width - 36) / Math.max(1, result.slots);
  const firstSlotX = 18 + actualStep / 2;
  const slotGap = layerCount === 2 ? 17 : 14;
  const yTop = 112;
  const yBottom = 237;
  const isSeries = connectionMode === "series";
  const xSlot = (slot, layer = 1) =>
    firstSlotX +
    (slot - 1) * actualStep +
    (layerCount === 2 ? (layer === 2 ? 3.8 : -3.8) : 0);
  const seamLeft = 18;
  const seamRight = width - 18;
  const showCoilLabels = coils.length <= 24;
  const edgeMarks = [];
  const connections = [];
  const terminals = [];
  for (const [phase, letter] of [
    ["A", "U"],
    ["B", "V"],
    ["C", "W"],
  ]) {
    const orderedCoils = coils.filter((coil) => coil.phase === phase);
    orderedCoils
      .slice(0, -1)
      .forEach((coil, index) =>
        connections.push({ phase, from: coil, to: orderedCoils[index + 1] }),
      );
    if (orderedCoils.length) {
      terminals.push({
        phase,
        label: `${letter}1`,
        coil: orderedCoils[0],
        slot: orderedCoils[0].positiveSlot,
        layer: orderedCoils[0].positiveLayer || 1,
      });
      const last = orderedCoils[orderedCoils.length - 1];
      terminals.push({
        phase,
        label: `${letter}2`,
        coil: last,
        slot: last.negativeSlot,
        layer: last.negativeLayer || 1,
      });
    }
  }
  const connectionBase = yBottom + 24;
  const connectionSpacing = connections.length > 48 ? 7 : 9;
  const terminalRouteBase =
    connectionBase +
    Math.max(0, connections.length - 1) * connectionSpacing +
    20;
  const terminalY = terminalRouteBase + terminals.length * 9 + 20;
  const height = isSeries ? terminalY + 94 : 365;
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
        style={{
          display: "block",
          width: "100%",
          minWidth: width,
          height: "auto",
          maxHeight: isSeries ? "none" : undefined,
          fontFamily: "inherit",
        }}
      >
        <title
          id={`${id}-title`}
        >{`Abgewickeltes Wickelschema mit ${result.slots} Nuten und ${coils.length} Spulen${isSeries ? ", je Strang additiv in Reihe verbunden" : ""}`}</title>
        <desc id={`${id}-desc`}>
          {isSeries
            ? "Die blauen Rechtecke sind Zähne. Leiter liegen in den weißen Nuten zwischen den Zähnen. Die Spulen jedes Strangs werden additiv in der Reihenfolge der Spulenliste verbunden: vom positiven Leiter durch den oberen Wickelkopf zum negativen Leiter, dann unten zum positiven Leiter der nächsten Spule. Jede untere Verbindung hat eine eigene Höhe. Kreuzungen ohne Verbindungspunkt sind elektrisch getrennt. U1 und U2, V1 und V2 sowie W1 und W2 sind die offenen Stranganschlüsse. Es werden keine Stern- oder Dreieckbrücken und keine Fertigungs- oder Wickelkopfoptimierung vorgegeben. Randmarkierungen kennzeichnen den Umlauf über das Ende der Abwicklung."
            : "Die blauen Rechtecke sind Zähne. Leiter liegen in den weißen Nuten zwischen den Zähnen. Jede gezeichnete Schleife ist eine eigene Spule. Randübertritte sind als geteilte Spulen mit Fortsetzungsmarkierungen dargestellt. Eine elektrische Serienverbindung zwischen Spulen wird nicht vorgegeben."}
        </desc>
        <Arrows id={id} small />
        <text x="15" y="18" fill={MUTED} fontSize="10.5">
          NUT
        </text>
        {assignments.map((slot) => (
          <text
            key={slot.slot}
            x={xSlot(slot.slot, 0) + (layerCount === 2 ? 3.8 : 0)}
            y="18"
            textAnchor="middle"
            fill={chosen(selectedSlot, slot.slot) ? INK : MUTED}
            fontSize="11"
            fontWeight={chosen(selectedSlot, slot.slot) ? "750" : "500"}
          >
            {slot.slot}
          </text>
        ))}
        <path
          d={`M${seamLeft} 91V259 M${seamRight} 91V259`}
          stroke="#c5cfc6"
          strokeWidth="1"
          strokeDasharray="4 4"
          fill="none"
        />
        {Array.from({ length: result.slots + 1 }, (_, index) => {
          const x = firstSlotX + (index - 1) * actualStep + slotGap / 2;
          return (
            <rect
              key={index}
              x={Math.max(6, x)}
              y={yTop}
              width={Math.max(
                0,
                Math.min(width - 6, x + actualStep - slotGap) - Math.max(6, x),
              )}
              height={yBottom - yTop}
              rx="1.5"
              fill={TOOTH}
              fillOpacity="0.89"
              stroke="#187db1"
              strokeWidth="0.7"
            />
          );
        })}
        {coils.map((coil, index) => {
          const color = PHASE_COLORS[coil.phase];
          const active = phaseActive(selectedPhase, coil.phase);
          const selected =
            chosen(selectedSlot, coil.positiveSlot) ||
            chosen(selectedSlot, coil.negativeSlot);
          const xp = xSlot(coil.positiveSlot, coil.positiveLayer || 1);
          const xn = xSlot(coil.negativeSlot, coil.negativeLayer || 1);
          const offset = 22 + (index % 5) * 8;
          const yt = yTop - 13 - offset;
          const yb = yBottom + 13 + offset;
          const forwardDistance = mod(
            coil.negativeSlot - coil.positiveSlot,
            result.slots,
          );
          const intendedSpan = mod(
            Math.abs(coil.span ?? forwardDistance),
            result.slots,
          );
          const goesForward = coil.direction
            ? coil.direction > 0
            : forwardDistance === intendedSpan;
          const wraps = goesForward ? xn < xp : xp < xn;
          const top = [];
          const bottom = [];
          let labelX;
          if (wraps) {
            const exit = goesForward ? seamRight : seamLeft;
            const entry = goesForward ? seamLeft : seamRight;
            top.push(`M${xp} ${yTop} L${xp} ${yTop - 5} L${exit} ${yt}`);
            top.push(`M${entry} ${yt} L${xn} ${yTop - 5} L${xn} ${yTop}`);
            bottom.push(
              `M${xp} ${yBottom} L${xp} ${yBottom + 5} L${exit} ${yb}`,
            );
            bottom.push(
              `M${entry} ${yb} L${xn} ${yBottom + 5} L${xn} ${yBottom}`,
            );
            labelX = (xp + exit) / 2;
            edgeMarks.push({
              key: coil.id ?? index,
              color,
              y: yt,
              active,
              selected,
            });
          } else {
            labelX = (xp + xn) / 2;
            top.push(
              `M${xp} ${yTop} L${xp} ${yTop - 5} L${labelX} ${yt} L${xn} ${yTop - 5} L${xn} ${yTop}`,
            );
            bottom.push(
              `M${xp} ${yBottom} L${xp} ${yBottom + 5} L${labelX} ${yb} L${xn} ${yBottom + 5} L${xn} ${yBottom}`,
            );
          }
          return (
            <g
              key={coil.id ?? index}
              opacity={
                active ? (selectedSlot && !selected ? 0.43 : 0.92) : 0.12
              }
              fill="none"
              stroke={color}
              strokeWidth={selected ? 2.8 : 1.6}
              strokeLinejoin="round"
              strokeLinecap="round"
            >
              <title>{`Spule ${coil.id ?? index + 1}: Strang ${coil.phase}, Nut ${coil.positiveSlot} (positiv, Lage ${coil.positiveLayer || 1}) ↔ Nut ${coil.negativeSlot} (negativ, Lage ${coil.negativeLayer || 1}), Weite ${coil.span}`}</title>
              {top.map((path, i) => (
                <path key={`t${i}`} d={path} />
              ))}
              {!isSeries &&
                bottom.map((path, i) => <path key={`b${i}`} d={path} />)}
              <path d={`M${xp} ${yTop}V${yBottom} M${xn} ${yTop}V${yBottom}`} />
              <path
                d={`M${xp} 184V162 M${xn} 162V184`}
                markerEnd={`url(#${id}-${coil.phase})`}
                strokeWidth={selected ? 2.2 : 1.5}
              />
              {showCoilLabels && (
                <text
                  x={labelX}
                  y={yt - 5}
                  textAnchor="middle"
                  stroke="none"
                  fill={color}
                  fontSize="9"
                  fontWeight="600"
                >
                  {coil.id ?? `${coil.phase}${index + 1}`}
                </text>
              )}
            </g>
          );
        })}
        {edgeMarks.map((mark) => (
          <g
            key={mark.key}
            opacity={mark.active ? 0.75 : 0.12}
            stroke={mark.color}
            strokeWidth="1.5"
            fill="none"
          >
            <path
              d={`M${seamLeft + 4} ${mark.y - 3}l-4 3 4 3 M${seamRight - 4} ${mark.y - 3}l4 3 -4 3`}
            />
          </g>
        ))}
        {isSeries &&
          connections.map(({ phase, from, to }, index) => {
            const xp = xSlot(from.negativeSlot, from.negativeLayer || 1);
            const xn = xSlot(to.positiveSlot, to.positiveLayer || 1);
            const y = connectionBase + index * connectionSpacing;
            const active = phaseActive(selectedPhase, phase);
            const selected = [
              from.positiveSlot,
              from.negativeSlot,
              to.positiveSlot,
              to.negativeSlot,
            ].some((slot) => chosen(selectedSlot, slot));
            return (
              <g
                key={`series-${from.id}-${to.id}`}
                opacity={
                  active ? (selectedSlot && !selected ? 0.43 : 0.92) : 0.12
                }
              >
                <title>{`Strang ${phase}: negatives Ende der Spule ${from.id} in Nut ${from.negativeSlot}, Lage ${from.negativeLayer || 1}, zum positiven Anfang der Spule ${to.id} in Nut ${to.positiveSlot}, Lage ${to.positiveLayer || 1}. Kreuzungen ohne Punkt sind keine Verbindung.`}</title>
                <path
                  d={`M${xp} ${yBottom}V${y}H${xn}V${yBottom}`}
                  fill="none"
                  stroke={PHASE_COLORS[phase]}
                  strokeWidth={selected ? 2.3 : 1.5}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </g>
            );
          })}
        {isSeries &&
          terminals.map((terminal, index) => {
            const xp = xSlot(terminal.slot, terminal.layer);
            const anchor =
              left +
              (index * (width - 2 * left)) / Math.max(1, terminals.length - 1);
            const routeY = terminalRouteBase + index * 9;
            const active = phaseActive(selectedPhase, terminal.phase);
            const selected = chosen(selectedSlot, terminal.slot);
            const color = PHASE_COLORS[terminal.phase];
            return (
              <g
                key={terminal.label}
                opacity={active ? (selectedSlot && !selected ? 0.55 : 1) : 0.15}
                fill="none"
                stroke={color}
                strokeWidth={selected ? 2.4 : 1.7}
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <title>{`${terminal.label}: ${terminal.label.endsWith("1") ? "positiver Anfang der ersten" : "negatives Ende der letzten"} Spule ${terminal.coil.id}, Nut ${terminal.slot}, Lage ${terminal.layer}. Offener Anschluss des Strangs ${terminal.phase}.`}</title>
                <path
                  d={`M${xp} ${yBottom}V${routeY}H${anchor}V${terminalY - 4}`}
                />
                <circle cx={anchor} cy={terminalY} r="4" fill="white" />
                <text
                  x={anchor}
                  y={terminalY + 20}
                  textAnchor="middle"
                  fontSize="12"
                  fontWeight="700"
                  fill={color}
                  stroke="none"
                >
                  {terminal.label}
                </text>
              </g>
            );
          })}
        {assignments.map((slot) => {
          const x = firstSlotX + (slot.slot - 1) * actualStep;
          const selected = chosen(selectedSlot, slot.slot);
          return (
            <g
              key={slot.slot}
              role="button"
              tabIndex="0"
              aria-label={`Nut ${slot.slot} im Wickelschema auswählen, Zone ${zoneLabel(slot)}`}
              aria-pressed={selected}
              onClick={() => onSelectSlot?.(slot.slot)}
              onKeyDown={keyboard(() => onSelectSlot?.(slot.slot))}
              style={{ cursor: "pointer" }}
            >
              <title>{`Nut ${slot.slot}: weißer Zwischenraum zwischen zwei blauen Zähnen`}</title>
              <rect
                x={x - slotGap / 2}
                y={yTop - 2}
                width={slotGap}
                height={yBottom - yTop + 4}
                fill="transparent"
                stroke={selected ? INK : "transparent"}
                strokeWidth="1.3"
                strokeDasharray="3 3"
                rx="2"
              />
            </g>
          );
        })}
        <g
          transform={`translate(${width / 2 - 196} ${isSeries ? terminalY + 49 : 344})`}
          fontSize="10.5"
          fill={MUTED}
        >
          <rect x="0" y="-8" width="12" height="11" fill={TOOTH} rx="1" />
          <text x="18" y="1">
            Zahn
          </text>
          <rect
            x="73"
            y="-8"
            width="12"
            height="11"
            fill="white"
            stroke="#b9c6bd"
          />
          <path d="M79 -7V2" stroke={PHASE_COLORS.A} strokeWidth="1.5" />
          <text x="91" y="1">
            Nut mit Leiter
          </text>
          <path d="M203 -5h18m-3 -3 3 3 -3 3" stroke={MUTED} fill="none" />
          <text x="229" y="1">
            Fortsetzung am Rand
          </text>
        </g>
        {isSeries && (
          <g textAnchor="middle" fill={MUTED} fontSize="10">
            <text x={width / 2} y={height - 23}>
              Additive Reihenschaltung in Spulenreihenfolge · Kreuzungen ohne
              Punkt sind getrennt
            </text>
            <text x={width / 2} y={height - 8}>
              Offene Stranganschlüsse · keine Stern-/Dreieckbrücken ·
              Wickelköpfe schematisch
            </text>
          </g>
        )}
      </svg>
    </div>
  );
}
