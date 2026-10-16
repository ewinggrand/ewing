import React, { useEffect, useId, useMemo, useState } from "react";
import { computeInductance } from "../domain/inductance.js";
import MathFormula from "./MathFormula.jsx";
import "../inductance.css";

const PHASES = ["A", "B", "C"];
const COLORS = { A: "#c65736", B: "#31806d", C: "#5668c9" };
const TWO_PI = 2 * Math.PI;
const format = (value, digits = 4) => {
  if (!Number.isFinite(value)) return "–";
  if (Math.abs(value) < 1e-11) return "0";
  if (Math.abs(value) < 0.0001) return value.toExponential(2).replace(".", ",");
  return value.toLocaleString("de-DE", { maximumFractionDigits: digits });
};
const deg = (value) => Number.isFinite(value) ? `${format(value, 2)}°` : "nicht definiert";
const latexNumber = (value, digits = 5) => {
  if (!Number.isFinite(value)) return String.raw`\text{nicht definiert}`;
  if (Math.abs(value) < 1e-12) return "0";
  const parts = Number(value.toPrecision(digits)).toString().split("e");
  const mantissa = parts[0].replace(".", "{,}");
  return parts.length === 2 ? `${mantissa}\\cdot10^{${Number(parts[1])}}` : mantissa;
};
const complex = (value) => {
  if (!value) return "–";
  return `${format(value.real)} ${value.imag < -1e-11 ? "−" : "+"} j ${format(Math.abs(value.imag))}`;
};
const radiansToDegrees = (value) => value * 180 / Math.PI;

function Equation({ children, caption }) {
  return <div className="inductance-equation">
    <MathFormula>{children}</MathFormula>
    {caption && <div className="inductance-equation-caption">{caption}</div>}
  </div>;
}

function Stage({ number, title, subtitle, children, id }) {
  return <section className="inductance-card" id={id} data-inductance-stage={number}>
    <div className="inductance-card-heading">
      <span className="inductance-step-number">{String(number).padStart(2, "0")}</span>
      <div><h3>{title}</h3><p>{subtitle}</p></div>
    </div>
    {children}
  </section>;
}

function Field({ id, label, unit, value, onChange, min, max, step = "any", note }) {
  return <label className="inductance-field" htmlFor={id}>
    <span>{label}</span>
    <div className="inductance-input-wrap">
      <input id={id} type="number" inputMode="decimal" value={value} onChange={(event) => onChange(event.target.value)} min={min} max={max} step={step} />
      {unit && <span>{unit}</span>}
    </div>
    {note && <small>{note}</small>}
  </label>;
}

function Matrix({ matrix, title, kind, detail }) {
  if (!Array.isArray(matrix) || matrix.length !== 3) return null;
  return <div className="inductance-matrix" data-inductance-matrix={kind}>
    <h4>{title}<span>mH</span></h4>
    <table aria-label={`${title}, Werte in Millihenry`}>
      <thead><tr><th scope="col">L</th>{PHASES.map((phase) => <th key={phase} scope="col" style={{ color: COLORS[phase] }}>i{phase}</th>)}</tr></thead>
      <tbody>{matrix.map((row, a) => <tr key={PHASES[a]}>
        <th scope="row" style={{ color: COLORS[PHASES[a]] }}>Ψ{PHASES[a]}</th>
        {row.map((entry, b) => <td key={PHASES[b]} className={a === b ? "is-self" : undefined} data-inductance-entry={`${PHASES[a]}${PHASES[b]}`}>{format(entry * 1000, 6)}</td>)}
      </tr>)}</tbody>
    </table>
    {detail && <p className="inductance-footnote">{detail}</p>}
  </div>;
}

function AxisDiagram({ data, phase, coils, selectedCoil, onSelectCoil, id }) {
  const phaseData = data.phases.find((entry) => entry.phase === phase);
  const phaseAngle = phaseData?.axisRad === null ? null : phaseData?.axisRad * data.polePairs;
  const selectedId = selectedCoil?.id;
  const point = (angle, radius = 123) => ({ x: 210 + radius * Math.cos(angle), y: 180 - radius * Math.sin(angle) });
  const phaseEnd = phaseAngle === null ? null : point(phaseAngle, 143);
  return <svg className="diagram-svg inductance-axis-chart" viewBox="0 0 420 365" width="420" height="365" role="img" aria-labelledby={`${id}-axes-title ${id}-axes-desc`}
    data-export-title={`Spulen- und Strangmittelachsen ${phase}: Grundwelle`}
    data-export-subtitle={`Elektrisch gefaltete MMF-Achsen · α = pφ · p = ${data.polePairs} · ein gemeinsamer Raumursprung`}>
    <title id={`${id}-axes-title`}>MMF-Achsen des Strangs {phase}, elektrisch gefaltet</title>
    <desc id={`${id}-axes-desc`}>Alle orientierten Grundwellenachsen der Spulen und ihre Strangmittelachse. Die Darstellung faltet p mechanische Polpaarperioden auf einen elektrischen Kreis. Sie zeigt Feldachsen, keine Spannungszeiger.</desc>
    <rect width="420" height="365" fill="#fdfdfa" />
    <defs><marker id={`${id}-axis-tip`} markerWidth="7" markerHeight="7" refX="6" refY="3.5" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 0 L7 3.5 L0 7 Z" fill="context-stroke" /></marker></defs>
    <circle cx="210" cy="180" r="123" fill="#f6f7ef" stroke="#dce3d0" />
    <circle cx="210" cy="180" r="68" fill="none" stroke="#e3e8da" strokeDasharray="2 4" />
    {[0, 60, 120, 180, 240, 300].map((angle) => {
      const edge = point(angle * Math.PI / 180);
      const label = point(angle * Math.PI / 180, 141);
      return <g key={angle}><line x1="210" y1="180" x2={edge.x} y2={edge.y} stroke="#e0e6d6" /><text x={label.x} y={label.y + 3} textAnchor="middle" fontSize="9" fill="#929c85">{angle}°</text></g>;
    })}
    {coils.map((coil) => {
      if (!Number.isFinite(coil.axisRad)) return null;
      const selected = coil.id === selectedId;
      const end = point(coil.axisRad * data.polePairs, selected ? 123 : 112);
      const label = point(coil.axisRad * data.polePairs, 154);
      return <g key={coil.id} role="button" tabIndex={selected ? 0 : -1} aria-label={`${coil.id}, relative elektrische Achse ${deg(coil.relativeElectricalDeg)}`} onClick={() => onSelectCoil(coil.id)} onKeyDown={(event) => { if (["Enter", " "].includes(event.key)) { event.preventDefault(); onSelectCoil(coil.id); } }} data-inductance-coil-axis={coil.id}>
        <line x1="210" y1="180" x2={end.x} y2={end.y} stroke={COLORS[phase]} opacity={selected ? 1 : 0.3} strokeWidth={selected ? 2.5 : 1.2} markerEnd={`url(#${id}-axis-tip)`} />
        <circle cx={end.x} cy={end.y} r={selected ? 5 : 3.2} fill={COLORS[phase]} stroke="#fdfdfa" strokeWidth="1.5" />
        {selected && <text x={label.x} y={label.y + 4} textAnchor="middle" fontSize="11" fill={COLORS[phase]}>{coil.id}</text>}
      </g>;
    })}
    {phaseEnd && <line x1="210" y1="180" x2={phaseEnd.x} y2={phaseEnd.y} stroke="#354c35" strokeWidth="2" strokeDasharray="6 4" markerEnd={`url(#${id}-axis-tip)`} />}
    <circle cx="210" cy="180" r="3.5" fill="#fdfdfa" stroke="#839572" />
    <text x="210" y="18" textAnchor="middle" fontSize="10" fill="#7f8c70">Orientierte MMF-Grundwellenachsen · α = pφ</text>
    <line x1="70" x2="92" y1="338" y2="338" stroke={COLORS[phase]} strokeWidth="2" /><text x="99" y="342" fontSize="9" fill="#829071">Spulenachsen {phase}</text>
    <line x1="241" x2="263" y1="338" y2="338" stroke="#354c35" strokeWidth="2" strokeDasharray="5 3" /><text x="270" y="342" fontSize="9" fill="#829071">Strangmittelachse</text>
  </svg>;
}

function FieldPlot({ data, id }) {
  const width = 900, height = 380, left = 62, right = 28;
  const plotWidth = width - left - right;
  const x = (radians) => left + radians / TWO_PI * plotWidth;
  const rows = [
    { key: "thetaAmpereTurns", harmonicKey: "harmonicThetaAmpereTurns", title: "Durchflutung Θ", unit: "A · Wdg", top: 35, bottom: 151, multiplier: 1 },
    { key: "bTesla", harmonicKey: "harmonicBTesla", title: "Luftspaltflussdichte B", unit: "mT", top: 223, bottom: 339, multiplier: 1000 },
  ];
  return <svg className="diagram-svg inductance-plot" viewBox={`0 0 ${width} ${height}`} width={width} height={height} role="img" aria-labelledby={`${id}-field-title ${id}-field-desc`}
    data-export-title="Stator-Durchflutung und Luftspaltflussdichte"
    data-export-subtitle={`K = ${data.parameters.maxOrder} · δeff = ${format(data.parameters.gapM * 1000)} mm · n = ${data.parameters.turnsPerCoil} Wdg/Spule · i(A,B,C) = (${PHASES.map((phase) => format(data.parameters.currents[phase])).join("; ")}) A`}>
    <title id={`${id}-field-title`}>Durchflutung und Luftspaltflussdichte am Statorumfang</title>
    <desc id={`${id}-field-desc`}>Stufenförmiger Verlauf aus den tatsächlich belegten Nuten, gemeinsam mit der endlichen Fourier-Näherung. Der Luftspalt ist gleichmäßig und das Eisen ideal leitend.</desc>
    <rect width={width} height={height} fill="#fdfdfa" />
    {rows.map((row) => {
      const values = [...data.segments.map((segment) => segment[row.key]), ...data.samples.map((sample) => sample[row.harmonicKey])].map((value) => Math.abs(value * row.multiplier));
      const bound = Math.max(...values, 0) * 1.12 || 1;
      const y = (value) => row.top + (bound - value * row.multiplier) / (2 * bound) * (row.bottom - row.top);
      const exactPath = data.segments.map((segment, index) => `${index ? "L" : "M"}${x(segment.startRad)},${y(segment[row.key])} L${x(segment.endRad)},${y(segment[row.key])}`).join(" ");
      const harmonicPath = data.samples.map((sample, index) => `${index ? "L" : "M"}${x(sample.angleRad)},${y(sample[row.harmonicKey])}`).join(" ");
      return <g key={row.key}>
        <text x={left} y={row.top - 15} fontSize="11" fill="#6f7f61">{row.title} [{row.unit}]</text>
        {[-1, 0, 1].map((tick) => <g key={tick}><line x1={left} x2={width - right} y1={y(tick * bound / row.multiplier)} y2={y(tick * bound / row.multiplier)} stroke={tick === 0 ? "#bdc8ae" : "#e6ebde"} strokeDasharray={tick ? "2 4" : undefined} /><text x={left - 10} y={y(tick * bound / row.multiplier) + 3} textAnchor="end" fontSize="9" fill="#929d85">{format(tick * bound, 3)}</text></g>)}
        {[0, 60, 120, 180, 240, 300, 360].map((tick) => <g key={tick}><line x1={x(tick * Math.PI / 180)} x2={x(tick * Math.PI / 180)} y1={row.top} y2={row.bottom} stroke="#e6ebde" strokeDasharray="2 4" /><text x={x(tick * Math.PI / 180)} y={row.bottom + 18} textAnchor="middle" fontSize="9" fill="#929d85">{tick}°</text></g>)}
        <path d={exactPath} fill="none" stroke="#b35f3b" strokeWidth="1.8" data-inductance-exact-field={row.key} />
        <path d={harmonicPath} fill="none" stroke="#53795e" strokeWidth="1.2" strokeDasharray="4 3" data-inductance-fourier-field={row.key} />
      </g>;
    })}
    <text x={width - right} y={height - 4} textAnchor="end" fontSize="9" fill="#929d85">mechanischer Winkel φ · Nut 1 bei 0°</text>
  </svg>;
}

export default function InductancePanel({ result, onDataChange }) {
  const id = useId().replaceAll(":", "");
  const [form, setForm] = useState({ diameterMm: "100", lengthMm: "100", gapMm: "1", turns: "10", iA: "1", iB: "0", iC: "0", maxOrder: "120" });
  const [phase, setPhase] = useState("A");
  const [selectedCoilId, setSelectedCoilId] = useState(null);
  const [selectedOrder, setSelectedOrder] = useState(result?.polePairs || 1);
  const [valuesEdited, setValuesEdited] = useState(false);
  useEffect(() => setSelectedOrder(result?.polePairs || 1), [result?.polePairs]);
  const setValue = (field, value) => { setForm((current) => ({ ...current, [field]: value })); setValuesEdited(true); };
  const parameters = useMemo(() => ({
    radiusM: Number(form.diameterMm) / 2000,
    lengthM: Number(form.lengthMm) / 1000,
    gapM: Number(form.gapMm) / 1000,
    turnsPerCoil: Number(form.turns),
    currents: { A: Number(form.iA), B: Number(form.iB), C: Number(form.iC) },
    maxOrder: Number(form.maxOrder), selectedOrder: Number(selectedOrder), sampleCount: 721,
  }), [form, selectedOrder]);
  const data = useMemo(() => {
    try { return computeInductance(result, parameters); }
    catch (error) { return { valid: false, warnings: [error.message], parameters }; }
  }, [result, parameters]);
  useEffect(() => { onDataChange?.(data); }, [data, onDataChange]);
  const phaseData = data.phases?.find((entry) => entry.phase === phase);
  const coils = data.coils?.filter((coil) => coil.phase === phase) || [];
  const selectedCoil = coils.find((coil) => coil.id === selectedCoilId) || coils[0];
  const groups = data.groups?.filter((group) => group.phase === phase) || [];
  const phaseIndex = PHASES.indexOf(phase);
  const setCurrents = (currents) => setForm((current) => ({ ...current, iA: String(currents[0]), iB: String(currents[1]), iC: String(currents[2]) }));
  const stageId = (stage) => `${id}-inductance-${stage}`;
  const peakTheta = data.valid ? Math.max(0, ...data.segments.map((segment) => Math.abs(segment.thetaAmpereTurns))) : 0;
  const peakB = data.valid ? Math.max(0, ...data.segments.map((segment) => Math.abs(segment.bTesla))) : 0;
  return <div className="inductance-panel" data-inductance-valid={data.valid ? "true" : "false"}>
    <div className="inductance-intro">
      <h2>Von der Spulenlage zur Induktivität</h2>
      <p>Wir betrachten die Statorwicklung im gemeinsamen mechanischen Koordinatensystem. Aus jeder tatsächlichen Spulenseite entstehen die Wicklungsfunktion, die Durchflutung und schließlich die gegenseitige Flussverkettung aller drei Stränge.</p>
      <div className="inductance-assumption">Lineares Luftspaltmodell: gleichmäßiger wirksamer Luftspalt δ<sub>eff</sub>, ideal magnetisch leitendes Eisen (μ<sub>Fe</sub> → ∞), alle Spulen eines Strangs in Reihe. Nut-, Stirn- und sonstige Streuinduktivitäten sowie Sättigung sind nicht enthalten.</div>
    </div>

    <section className="inductance-card" aria-labelledby={`${id}-parameters-title`}>
      <span className="inductance-example-badge">{valuesEdited ? "Einstellbare Modellparameter · Werte bitte an der Maschine prüfen" : "Beispielwerte – durch eigene Maschinendaten ersetzen"}</span>
      <h3 id={`${id}-parameters-title`}>Geometrie, Windungszahl und Erregung</h3>
      <p>Q und p allein bestimmen noch keine Induktivität. Hier ergänzen wir die magnetisch wirksamen Abmessungen; jede Wicklung verwendet n Windungen pro Spule.</p>
      <div className="inductance-inputs" style={{ marginTop: 18 }}>
        <Field id="inductance-diameter" label="Mittlerer Luftspaltdurchmesser D" unit="mm" value={form.diameterMm} onChange={(value) => setValue("diameterMm", value)} min="0.001" note="Mittlerer Luftspaltradius r = D / 2" />
        <Field id="inductance-length" label="Aktive Eisenlänge ℓFe" unit="mm" value={form.lengthMm} onChange={(value) => setValue("lengthMm", value)} min="0.001" />
        <Field id="inductance-gap" label="Wirksamer Luftspalt δeff" unit="mm" value={form.gapMm} onChange={(value) => setValue("gapMm", value)} min="0.0001" note="Gleichmäßiger Ersatzluftspalt; keine automatische Carter-Korrektur" />
        <Field id="inductance-turns" label="Windungen je Spule n" unit="Wdg" value={form.turns} onChange={(value) => setValue("turns", value)} min="1" step="1" note="Gleiche Windungszahl in jeder tatsächlichen Spule" />
        <label className="inductance-field" htmlFor="inductance-max-order"><span>Fourier-Näherung bis Raumordnung K</span><select id="inductance-max-order" className="inductance-select" value={form.maxOrder} onChange={(event) => setValue("maxOrder", event.target.value)}>{[20, 40, 60, 120].map((order) => <option key={order} value={order}>K = {order}</option>)}</select><small>Die exakte Matrix ist unabhängig von K.</small></label>
        <Field id="inductance-order" label="Raumordnung k für die Faktoren" value={selectedOrder} onChange={setSelectedOrder} min="1" max="120" step="1" note={`Mechanische Grundwelle k = p = ${result?.polePairs || "–"}; ν = k/p`} />
      </div>
      <div className="inductance-current-inputs">{PHASES.map((entry) => <Field key={entry} id={`inductance-current-${entry}`} label={`Momentanstrom i${entry}`} unit="A" value={form[`i${entry}`]} onChange={(value) => setValue(`i${entry}`, value)} />)}</div>
      <div className="inductance-preset-buttons"><button onClick={() => setCurrents([1, 0, 0])}>Nur A: (1; 0; 0) A</button><button onClick={() => setCurrents([1, -0.5, -0.5])}>Symmetrischer Augenblick: (1; −0,5; −0,5) A</button><button onClick={() => setCurrents([0, 0, 0])}>Alle Ströme null</button></div>
    </section>

    {!data.valid ? <div className="inductance-invalid" role="status"><h3>Für diese Eingaben ist keine Induktivität verfügbar</h3>{(data.warnings || ["Bitte ein gültiges Wickelschema und positive Maschinenabmessungen wählen."]).map((warning) => <p key={warning}>{warning}</p>)}</div> : <>
      <div className="inductance-metrics">
        <div className="inductance-metric"><span>Selbstinduktivität L{phase}{phase}</span><strong>{format(data.matrixH[phaseIndex][phaseIndex] * 1000, 4)} <small>mH</small></strong><small>Gesamte Luftspalt-Hauptinduktivität im linearen Modell</small></div>
        <div className="inductance-metric"><span>Flussverkettung Ψ{phase}</span><strong>{format(data.fluxLinkagesWbTurns[phase] * 1000, 4)} <small>mWb</small></strong><small>Windungszahl bereits enthalten · bei den eingestellten Strömen</small></div>
        <div className="inductance-metric"><span>Magnetische Energie Wmag</span><strong>{format(data.energyJ * 1000, 4)} <small>mJ</small></strong><small>Wmag = ½ iᵀLi ≥ 0 · alle drei Stränge gemeinsam</small></div>
      </div>
      {data.warnings?.length > 0 && <div className="inductance-step-note" role="status">{data.warnings.map((warning) => <p key={warning}>{warning}</p>)}</div>}
      <nav className="inductance-navigation" aria-label="Etappen der Induktivitätsherleitung">{["Achsen", "Faktoren", "Durchflutung", "Flussverkettung", "Induktivitäten", "Ströme & Energie"].map((title, index) => <a key={title} href={`#${stageId(index + 1)}`}>{index + 1}. {title}</a>)}</nav>

      <Stage number={1} id={stageId(1)} title="Wie stehen die Spulenmittelachsen zur Strangmittelachse?" subtitle="Mechanische Geometrie und orientierte Grundwellenachse sind zwei verschiedene Größen.">
        <p>Die Nutlagen sind mechanisch fest: φ<sub>s</sub> = 2π(s − 1)/Q. Für jede Spule benutzen wir die tatsächliche Plus- und Minus-Seite, die Spulenweite β und ihre Orientierung ε = ±1. Die geometrische Mitte γ liegt zwischen den beiden Seiten auf dem gewählten Spulenbogen.</p>
        <Equation caption="γc: geometrische Spulenmitte; β: positive mechanische Spulenweite; εc: Orientierung von der Plus- zur Minus-Seite. Winkel bei Bedarf über 360° fortsetzen.">{String.raw`\beta=\frac{2\pi y}{Q},\qquad \varphi_{c,-}=\varphi_{c,+}+\varepsilon_c\beta,\qquad \gamma_c=\frac{\varphi_{c,+}+\varphi_{c,-}}{2}`}</Equation>
        <Equation caption="Die orientierte MMF-Achse α ist aus dem ungedrehten Fourier-Koeffizienten der Grundwelle bestimmt. Bei p Polpaaren ist sie nur modulo 2π/p eindeutig. Eine umgepolte Spule hat dieselbe geometrische Mitte, aber eine um 180° elektrisch gedrehte MMF-Achse.">{String.raw`\alpha_c=-\frac{\arg C_{c,p}}{p},\qquad \alpha_a=-\frac{\arg C_{a,p}}{p},\qquad \Delta\alpha_{c,\mathrm{el}}=\operatorname{wrap}_{[-\pi,\pi)}\!\left[p(\alpha_c-\alpha_a)\right]`}</Equation>
        <div className="inductance-controls">
          <label className="inductance-field" htmlFor="inductance-phase"><span>Strang betrachten</span><select id="inductance-phase" className="inductance-select" value={phase} onChange={(event) => { setPhase(event.target.value); setSelectedCoilId(null); }}>{PHASES.map((entry) => <option key={entry} value={entry}>Strang {entry}</option>)}</select></label>
          <label className="inductance-field" htmlFor="inductance-coil"><span>Spule hervorheben</span><select id="inductance-coil" className="inductance-select" value={selectedCoil?.id || ""} onChange={(event) => setSelectedCoilId(event.target.value)}>{coils.map((coil) => <option key={coil.id} value={coil.id}>{coil.id} · Nut {coil.positiveSlot} → {coil.negativeSlot}</option>)}</select></label>
          <div className="inductance-field"><span>Serienwindungszahl des Strangs</span><div className="inductance-axis-values" style={{ padding: "5px 12px" }}>{phaseData.turnsSeries} Wdg = {phaseData.coilCount} Spulen × {format(parameters.turnsPerCoil)} Wdg</div></div>
        </div>
        <div className="inductance-axis-grid">
          <AxisDiagram data={data} phase={phase} coils={coils} selectedCoil={selectedCoil} onSelectCoil={setSelectedCoilId} id={id} />
          <div className="inductance-axis-values"><h4>{selectedCoil?.id}: Geometrie und Achsen</h4><dl>
            <dt>Plus- / Minus-Seite</dt><dd>{selectedCoil?.positiveSlot} / {selectedCoil?.negativeSlot}</dd>
            <dt>Spulenweite β mechanisch</dt><dd>{deg(radiansToDegrees(selectedCoil?.betaRad))}</dd>
            <dt>Spulenweite pβ elektrisch</dt><dd>{deg(selectedCoil?.betaElectricalDeg)}</dd>
            <dt>Geometrische Mitte γ</dt><dd>{deg(selectedCoil?.centerDeg)}</dd>
            <dt>Orientierung ε</dt><dd>{selectedCoil?.direction > 0 ? "+1" : "−1"}</dd>
            <dt>MMF-Achse αc mechanisch</dt><dd>{deg(selectedCoil?.axisDeg)}</dd>
            <dt>Strangmittelachse α{phase}</dt><dd>{deg(phaseData.axisDeg)}</dd>
            <dt>Relative Lage Δαc,el</dt><dd style={{ color: COLORS[phase] }}>{deg(selectedCoil?.relativeElectricalDeg)}</dd>
            <dt>Entsprechender mechanischer Abstand</dt><dd>{deg(selectedCoil?.relativeMechanicalDeg)}</dd>
          </dl></div>
        </div>
        <p className="inductance-step-note">Die Kreisgrafik zeigt α = pφ und faltet deshalb alle Polpaarperioden übereinander. Eine gemeinsame mechanische Drehung ist für alle Stränge erlaubt; ein getrenntes Ausrichten jedes Strangs würde seine Gegeninduktivitäten verfälschen. Die MMF-Achsen unterscheiden sich außerdem um 90° elektrisch von den zugehörigen Nutenspannungsresultanten.</p>
      </Stage>

      <Stage number={2} id={stageId(2)} title="Spulenfaktor → Gruppenfaktor → Strangfaktor" subtitle={`Aktuelle mechanische Raumordnung k = ${parameters.selectedOrder}; elektrische Ordnung ν = k/p = ${format(parameters.selectedOrder / data.polePairs)}.`}>
        <p>Die beiden Seiten einer Spule liefern zuerst eine komplexe Differenz. Damit lässt sich die Wirkung der Spulenweite von der räumlichen Verteilung und der Polung trennen.</p>
        <Equation>{String.raw`D_{c,k}=e^{-\mathrm{j}k\varphi_{c,+}}-e^{-\mathrm{j}k\varphi_{c,-}}=2\mathrm{j}\,\varepsilon_c\sin\!\left(\frac{k\beta}{2}\right)e^{-\mathrm{j}k\gamma_c}`}</Equation>
        <Equation caption="Der dimensionslose Spulenfaktor ist Sₖ. Erst die räumliche Integration erzeugt den zusätzlichen Faktor 1/k des Spektrums ξₖ. Beide Größen sind deshalb getrennt zu betrachten.">{String.raw`S_k=\sin\!\left(\frac{k\beta}{2}\right),\qquad \xi_k=\frac{S_k}{k},\qquad C_{c,k}=\varepsilon_c\,\xi_k\,e^{-\mathrm{j}k\gamma_c}`}</Equation>
        <Equation caption="Eine Gruppe g ist eine zusammengehörige Spulenmenge der Serienfolge. Nc,g zählt ihre Spulen, Nc,a die Spulen des gesamten Strangs. Der interne, normierte Gruppenfaktor ist eine komplexe Vektorsumme; αg dient als Gruppenbezugsachse.">{String.raw`G_{g,k}=\frac{1}{N_{c,g}}\sum_{c\in g}\varepsilon_c\,e^{-\mathrm{j}k(\gamma_c-\alpha_g)}`}</Equation>
        <Equation caption="Die Gruppen werden mit ihrer jeweiligen Spulenzahl gewichtet und relativ zur Strangmittelachse addiert. H ist der geometrische Strangfaktor; kw ist der Betrag des gesamten Wicklungsfaktors. Für die allgemeine Wicklung darf man keine gemittelten Beträge miteinander multiplizieren.">{String.raw`H_{a,k}=\sum_{g\in a}\frac{N_{c,g}}{N_{c,a}}\,G_{g,k}\,e^{-\mathrm{j}k(\alpha_g-\alpha_a)},\qquad k_{w,a,k}=\left|S_kH_{a,k}\right|`}</Equation>
        <Equation>{String.raw`C_{a,k}=\frac{N_{c,a}}{k}\,S_kH_{a,k}\,e^{-\mathrm{j}k\alpha_a}`}</Equation>
        <div className="inductance-solution">
          <div><span>Spulenfaktor S{parameters.selectedOrder}</span><strong>{format(phaseData.selected.pitchFactor, 6)}</strong></div>
          <div><span>|Strangfaktor H{phase},{parameters.selectedOrder}|</span><strong>{format(phaseData.selected.distributionFactor.magnitude, 6)}</strong></div>
          <div><span>Wicklungsfaktor kw,{parameters.selectedOrder}</span><strong>{format(phaseData.selected.windingFactor, 6)}</strong></div>
        </div>
        <p className="inductance-footnote">Komplexer Strangfaktor: <span className="inductance-complex">{complex(phaseData.selected.distributionFactor)}</span>. Der vorzeichenbehaftete Sₖ und die komplexen Gruppenbeiträge bleiben in allen Summen erhalten. Alle Spulen des aktuellen Schemas besitzen dieselbe Spulenweite β.</p>
        <div className="inductance-table-wrap"><table className="inductance-table" aria-label={`Spulenachsen und Faktoren von Strang ${phase}`}>
          <thead><tr><th>Spule</th><th>γc mech.</th><th>εc</th><th>Δαc,el</th><th>S{kLabel(parameters.selectedOrder)}</th><th>Gruppe</th></tr></thead>
          <tbody>{coils.map((coil) => <tr key={coil.id} className={coil.id === selectedCoil?.id ? "is-selected" : undefined}><td><button onClick={() => setSelectedCoilId(coil.id)}>{coil.id}</button></td><td>{deg(coil.centerDeg)}</td><td>{coil.direction > 0 ? "+1" : "−1"}</td><td>{deg(coil.relativeElectricalDeg)}</td><td>{format(coil.selected.pitchFactor, 6)}</td><td>{coil.groupId}</td></tr>)}</tbody>
        </table></div>
        <div className="inductance-group-detail"><h4>Gruppen des Strangs {phase}: komplexe Addition bei k = {parameters.selectedOrder}</h4>
          <div className="inductance-table-wrap"><table className="inductance-table" aria-label={`Gruppenfaktoren von Strang ${phase}`}>
            <thead><tr><th>Gruppe / Spulen</th><th>Nc,g</th><th>αg mech.</th><th>Gg,k</th><th>Beitrag zu H{phase},k</th></tr></thead>
            <tbody>{groups.map((group) => <tr key={group.id}><td>{group.id}<br /><small>{group.coilIds.join(", ")}</small></td><td>{group.coilCount}</td><td>{deg(group.axisDeg)}</td><td className="inductance-complex">{complex(group.selected.distributionFactor)}</td><td className="inductance-complex">{complex(group.selected.phaseContribution)}</td></tr>)}</tbody>
          </table></div>
        </div>
        <p className="inductance-step-note">Nur wenn die Gruppen identische interne Faktoren besitzen, lässt sich ihr gemeinsamer Gruppenfaktor aus der Strangsumme herausziehen. Allgemein gilt die gewichtete komplexe Addition oben. Die orientierte Grundwellenachse darf bei höheren k die explizite Polung εc nicht ersetzen.</p>
      </Stage>

      <Stage number={3} id={stageId(3)} title="Aus der Wicklung entstehen Durchflutung und Luftspaltflussdichte" subtitle="Jede belegte Nut erzeugt einen Sprung der Wicklungsfunktion.">
        <p>Die dimensionslose Wicklungsfunktion w<sub>a</sub>(φ) springt an einer Plus-Seite um +1 und an einer Minus-Seite um −1. Wir entfernen ihren Mittelwert über den vollständigen Umfang; so ergibt sich im geschlossenen Luftspalt kein künstlicher Gleichfluss. Mit n Windungen je Spule ist N<sub>a</sub>(φ) = n · w<sub>a</sub>(φ).</p>
        <Equation caption="Cₐ,ₖ sind die gemeinsamen, ungedrehten mechanischen Fourier-Koeffizienten der Strangsumme. Der Faktor 2 berücksichtigt die positive und die negative Frequenz des reellen räumlichen Verlaufs.">{String.raw`w_a(\varphi)=\frac{2}{\pi}\sum_{k=1}^{\infty}\operatorname{Re}\!\left\{C_{a,k}e^{\mathrm{j}k\varphi}\right\},\qquad \int_0^{2\pi}w_a(\varphi)\,d\varphi=0`}</Equation>
        <Equation>{String.raw`\Theta(\varphi)=\sum_{a\in\{A,B,C\}}N_a(\varphi)i_a,\qquad B(\varphi)=\frac{\mu_0}{\delta_{\mathrm{eff}}}\,\Theta(\varphi),\qquad \mu_0=4\pi\cdot10^{-7}\,\frac{\mathrm{H}}{\mathrm{m}}`}</Equation>
        <Equation caption="Eingesetzte SI-Werte: Luftspalt in Metern, Durchflutung in Amperewindungen. Die Durchflutung folgt aus allen eingestellten Strömen; die Flussdichte ist im gleichmäßigen Luftspalt dazu proportional.">{String.raw`\max|\Theta|=${latexNumber(peakTheta)}\,\mathrm{A\,Wdg},\qquad \max|B|=\left(\frac{4\pi\cdot10^{-7}}{${latexNumber(parameters.gapM)}}\,${latexNumber(peakTheta)}\right)\mathrm T=${latexNumber(peakB * 1000)}\,\mathrm{mT}`}</Equation>
        <FieldPlot data={data} id={id} />
        <div className="inductance-plot-legend"><span><i />Exakt: stückweise konstante Wicklungsfunktion</span><span><i className="is-fourier" />Fourier-Näherung bis K = {parameters.maxOrder}</span></div>
        <p className="inductance-footnote">An idealisierten Linienleitern springt das Feld. Das Überschwingen der endlichen Fourier-Summe nahe diesen Sprüngen ist der Gibbs-Effekt; die exakte Hauptinduktivität wird deshalb direkt aus den Nutintervallen integriert.</p>
      </Stage>

      <Stage number={4} id={stageId(4)} title="Flussverkettung: Empfangswicklung × erzeugtes Feld" subtitle="Zuerst das Spulenpaar der Folien, anschließend die vollständige Statorwicklung.">
        <p>Bei einer einzelnen Empfangsspule S integriert man die Luftspaltflussdichte über ihre aufgespannte Fläche und multipliziert mit der Windungszahl n<sub>S</sub>. Bei axial konstanter Flussdichte ist dA = ℓ<sub>Fe</sub> dx. Die Verschiebung x<sub>R</sub> beschreibt hier den Abstand zweier Spulenachsen; die App berechnet darunter die Kopplung der drei feststehenden Statorstränge.</p>
        <Equation>{String.raw`\Psi_{SR}(x_R)=n_S\ell_{\mathrm{Fe}}\int_{-w_S/2}^{w_S/2} B_R(x-x_R)\,dx`}</Equation>
        <details className="inductance-details" open><summary>Die Integration des Folienmodells in drei Schritten</summary>
          <p>Hier bezeichnet ν die ganzzahlige Raumordnung der lokalen Periode 2τ<sub>p</sub>. Wird diese Spulenverteilung p-mal über den Umfang wiederholt, gilt für die mechanische Ordnung k = pν. Die anschließende allgemeine Statorrechnung verwendet wieder k.</p>
          <h4>1. Das Feld der sendenden Spule einsetzen</h4>
          <Equation>{String.raw`B_R(x-x_R)=\frac{\mu_0}{\delta}\frac{2n_Ri_R}{\pi}\sum_{\nu=1}^{\infty}\frac{1}{\nu}\sin\!\left(\frac{\nu\pi w_R}{2\tau_p}\right)\cos\!\left(\frac{\nu\pi(x-x_R)}{\tau_p}\right)`}</Equation>
          <h4>2. Die Kosinusfunktion über die Spulenweite integrieren</h4>
          <Equation>{String.raw`\int_{-w_S/2}^{w_S/2}\cos\!\left(\frac{\nu\pi(x-x_R)}{\tau_p}\right)dx=\frac{2\tau_p}{\nu\pi}\sin\!\left(\frac{\nu\pi w_S}{2\tau_p}\right)\cos\!\left(\frac{\nu\pi x_R}{\tau_p}\right)`}</Equation>
          <p>Die symmetrischen Integrationsgrenzen beseitigen den ungeraden Sinusanteil. Das Integral liefert den zweiten Faktor 1/ν und den Spulenfaktor der Empfangsspule.</p>
          <h4>3. Beide Spulenfaktoren zusammenfassen</h4>
          <Equation>{String.raw`\xi_{S,\nu}=\frac{1}{\nu}\sin\!\left(\frac{\nu\pi w_S}{2\tau_p}\right),\qquad \xi_{R,\nu}=\frac{1}{\nu}\sin\!\left(\frac{\nu\pi w_R}{2\tau_p}\right)`}</Equation>
          <Equation>{String.raw`\Psi_{SR}(x_R)=\frac{\mu_0}{\delta}\frac{4\tau_p}{\pi^2}\ell_{\mathrm{Fe}}n_Sn_Ri_R\sum_{\nu=1}^{\infty}\xi_{S,\nu}\xi_{R,\nu}\cos\!\left(\frac{\nu\pi x_R}{\tau_p}\right)`}</Equation>
          <p>Bei alleiniger Erregung R teilen wir durch i<sub>R</sub>. Für die Selbstinduktivität wählen wir dieselbe Spule als Sender und Empfänger, setzen x<sub>R</sub> = 0 und n<sub>R</sub> = n<sub>S</sub>:</p>
          <Equation>{String.raw`L_{SR}(x_R)=\frac{\Psi_{SR}}{i_R}=\frac{\mu_0}{\delta}\frac{4\tau_p}{\pi^2}\ell_{\mathrm{Fe}}n_Sn_R\sum_{\nu=1}^{\infty}\xi_{S,\nu}\xi_{R,\nu}\cos\!\left(\frac{\nu\pi x_R}{\tau_p}\right)`}</Equation>
          <Equation>{String.raw`L_{SS}=\frac{\mu_0}{\delta}\frac{4\tau_p}{\pi^2}\ell_{\mathrm{Fe}}n_S^2\sum_{\nu=1}^{\infty}\xi_{S,\nu}^{\,2}`}</Equation>
          <p>Der Kosinus zeigt unmittelbar den Einfluss der relativen Spulenachsen. Bei gleichen Spulen und x<sub>R</sub> = 0 werden die Produkte zu ξ<sub>S,ν</sub>²: Das ist der Selbstinduktivitätsfall. Die beiden Spulenindizes dürfen dabei nicht vertauscht werden.</p>
        </details>
        <h4 style={{ marginTop: 22 }}>Übergang zum vollständigen Statorumfang</h4>
        <p>Für die reale Nutbelegung überlagern wir die Empfangswirkung aller Spulen durch N<sub>a</sub>(φ). Mit x = rφ und dA = rℓ<sub>Fe</sub>dφ folgt:</p>
        <Equation>{String.raw`\Psi_a=\ell_{\mathrm{Fe}}r\int_0^{2\pi}N_a(\varphi)B(\varphi)\,d\varphi=\frac{\mu_0\ell_{\mathrm{Fe}}r}{\delta_{\mathrm{eff}}}\int_0^{2\pi}N_a(\varphi)\sum_bN_b(\varphi)i_b\,d\varphi`}</Equation>
        <Equation caption="Die tatsächliche Polteilung ergibt sich aus der Geometrie. Das Spulenpaar der Folie bezieht sich auf eine Periode 2τp. Beim Übergang zur ganzen Maschine müssen alle p Perioden berücksichtigt werden; die mechanischen Koeffizienten der App enthalten bereits sämtliche Spulenseiten.">{String.raw`\tau_p=\frac{\pi r}{p}=${latexNumber(data.parameters.polePitchM * 1000)}\,\mathrm{mm},\qquad 2\pi r=p\cdot2\tau_p`}</Equation>
      </Stage>

      <Stage number={5} id={stageId(5)} title="Selbst- und Gegeninduktivitäten als gemeinsame Matrix" subtitle="Die Empfangswicklung steht in der Zeile, der erzeugende Strom in der Spalte.">
        <p>Wir ziehen die Ströme aus dem Integral und lesen ihre Proportionalitätsfaktoren ab. Ein Diagonaleintrag beschreibt die Selbstinduktivität; ein Eintrag außerhalb der Diagonale beschreibt die Gegen- oder Koppelinduktivität zweier Stränge.</p>
        <Equation>{String.raw`\Psi_a=\sum_b L_{ab}i_b,\qquad L_{ab}=\frac{\mu_0\ell_{\mathrm{Fe}}r}{\delta_{\mathrm{eff}}}\int_0^{2\pi}N_a(\varphi)N_b(\varphi)\,d\varphi`}</Equation>
        <Equation caption="Exakte Auswertung: Auf jedem Nutintervall j sind die Wicklungsfunktionen konstant. Die Multiplikation und die gewichtete Summe ersetzen ein numerisches Raster. Die Windungszahl n wird genau zweimal berücksichtigt.">{String.raw`L_{ab}=\frac{\mu_0\ell_{\mathrm{Fe}}r\,n^2}{\delta_{\mathrm{eff}}}\sum_j w_{a,j}w_{b,j}\,\Delta\varphi_j`}</Equation>
        <Matrix matrix={data.matrixH} title="Exakte Luftspalt-Induktivitätsmatrix L" kind="exact" detail="Positive Diagonale = Selbstinduktivitäten. Gegeninduktivitäten dürfen negativ sein; das Vorzeichen folgt aus den räumlichen Achsen und den gewählten Strangpolungen." />
        <h4 style={{ marginTop: 22 }}>Dieselbe Matrix aus dem Spektrum</h4>
        <p>Die Orthogonalität der Raumharmonischen lässt nur Produkte gleicher Ordnung stehen. Für die reellen Wicklungsfunktionen ergibt sich aus der positiven und negativen Frequenz zusammen der Faktor 4/π.</p>
        <Equation>{String.raw`\int_0^{2\pi}w_a w_b\,d\varphi=\frac{4}{\pi}\sum_{k=1}^{\infty}\operatorname{Re}\!\left(C_{a,k}\overline{C_{b,k}}\right)`}</Equation>
        <Equation>{String.raw`L_{ab}=\frac{4\mu_0\ell_{\mathrm{Fe}}r\,n^2}{\pi\delta_{\mathrm{eff}}}\sum_{k=1}^{\infty}\operatorname{Re}\!\left(C_{a,k}\overline{C_{b,k}}\right),\qquad L_{aa}=\frac{4\mu_0\ell_{\mathrm{Fe}}r\,n^2}{\pi\delta_{\mathrm{eff}}}\sum_{k=1}^{\infty}|C_{a,k}|^2`}</Equation>
        <Equation caption="Der gemeinsame geometrische Vorfaktor multipliziert die ungedrehten Spektralprodukte. Für Selbstinduktivitäten stehen Betragsquadrate, für Gegeninduktivitäten das reale komplexe Kreuzprodukt.">{String.raw`\frac{4\mu_0\ell_{\mathrm{Fe}}r\,n^2}{\pi\delta_{\mathrm{eff}}}=\frac{4(4\pi\cdot10^{-7})\,${latexNumber(parameters.lengthM)}\,${latexNumber(parameters.radiusM)}\,${latexNumber(parameters.turnsPerCoil)}^2}{\pi\,${latexNumber(parameters.gapM)}}=${latexNumber(4 * 4e-7 * parameters.lengthM * parameters.radiusM * parameters.turnsPerCoil ** 2 / parameters.gapM)}\,\mathrm{H}`}</Equation>
        <div className="inductance-matrix-comparison">
          <Matrix matrix={data.fundamentalMatrixH} title={`Nur Grundwelle k = p = ${data.polePairs}`} kind="fundamental" detail="Bei einem ideal symmetrischen Grundwellensystem mit 120° Achsabstand gilt M1 = −L1/2. Für die gesamte Wicklung muss man die höheren Raumharmonischen mitnehmen." />
          <Matrix matrix={data.harmonicMatrixH} title={`Fourier-Summe bis K = ${parameters.maxOrder}`} kind="harmonic" detail={`Relative Abweichung zur exakten Matrix: ${format(data.relativeTruncationError * 100, 4)} % (Frobeniusnorm). Liegt p oberhalb K, ist die Grundwelle in dieser endlichen Summe noch nicht enthalten.`} />
        </div>
        <p className="inductance-step-note">Weil beide Wicklungen im selben Integral stehen, gilt L<sub>ab</sub> = L<sub>ba</sub>. Die Luftspaltmatrix ist eine Gram-Matrix und damit positiv semidefinit. Ein negativer Koppeleintrag widerspricht daher keiner positiven magnetischen Energie.</p>
      </Stage>

      <Stage number={6} id={stageId(6)} title="Ströme einsetzen: Flussverkettung und magnetische Energie" subtitle="Die Induktivitätsmatrix hängt im linearen Modell von der Wicklung und Geometrie ab, nicht von der Stromhöhe.">
        <Equation>{String.raw`\begin{bmatrix}\Psi_A\\\Psi_B\\\Psi_C\end{bmatrix}=\begin{bmatrix}L_{AA}&L_{AB}&L_{AC}\\L_{BA}&L_{BB}&L_{BC}\\L_{CA}&L_{CB}&L_{CC}\end{bmatrix}\begin{bmatrix}i_A\\i_B\\i_C\end{bmatrix},\qquad \boldsymbol i=\begin{bmatrix}${latexNumber(parameters.currents.A)}\\${latexNumber(parameters.currents.B)}\\${latexNumber(parameters.currents.C)}\end{bmatrix}\,\mathrm A`}</Equation>
        <Equation>{String.raw`\Psi_${phase}=L_{${phase}A}i_A+L_{${phase}B}i_B+L_{${phase}C}i_C=\left(${data.matrixH[phaseIndex].map((entry, index) => `${latexNumber(entry * 1000)}\\cdot(${latexNumber(parameters.currents[PHASES[index]])})`).join("+")}\right)\,\mathrm{mH\,A}=${latexNumber(data.fluxLinkagesWbTurns[phase] * 1000)}\,\mathrm{mWb}`}</Equation>
        <div className="inductance-solution">{PHASES.map((entry) => <div key={entry}><span style={{ color: COLORS[entry] }}>Flussverkettung Ψ{entry}</span><strong data-inductance-linkage={entry}>{format(data.fluxLinkagesWbTurns[entry] * 1000, 6)} mWb</strong></div>)}</div>
        <p>Die Windungszahl ist in der Flussverkettung bereits enthalten (Wb · Windungen, bei dimensionslos gezählten Windungen kurz Wb). Für gleichzeitig bestromte Stränge ist Ψ<sub>a</sub>/i<sub>a</sub> im Allgemeinen keine Selbstinduktivität, weil die anderen Ströme ebenfalls Fluss verketten.</p>
        <Equation caption="Im hier verwendeten linearen Modell sind Sekanten- und differentielle Induktivität gleich. Die einfache Quotientenform für die Selbstinduktivität gilt bei alleiniger Erregung dieses Strangs und ohne einen zusätzlichen Permanentmagnetfluss.">{String.raw`L_{ab}=\frac{\partial\Psi_a}{\partial i_b},\qquad L_{aa}=\left.\frac{\Psi_a}{i_a}\right|_{i_{b\ne a}=0},\qquad W_{\mathrm{mag}}=\frac12\boldsymbol i^{\mathsf T}\mathbf L\boldsymbol i`}</Equation>
        <Equation>{String.raw`W_{\mathrm{mag}}=\frac{\mu_0\ell_{\mathrm{Fe}}r}{2\delta_{\mathrm{eff}}}\int_0^{2\pi}\Theta^2(\varphi)\,d\varphi=${latexNumber(data.energyJ * 1000)}\,\mathrm{mJ}\ge0`}</Equation>
        <details className="inductance-details"><summary>Was diese Rechnung beschreibt und welche Daten für ein vollständiges Maschinenmodell fehlen</summary>
          <p>Berechnet wird die Luftspalt-Hauptinduktivität der tatsächlichen Statorwicklung bei gleichmäßiger Luftspaltpermeanz. Die Spulenachsen und alle Gegeninduktivitäten bleiben im gemeinsamen Statorbezug. Eine Rotorwicklung, Rotorlage, magnetische Salienz, Streufluss, endliche Eisenpermeabilität und Sättigung sind hier nicht modelliert.</p>
          <p>Die Eingabe δ<sub>eff</sub> darf einen bereits bestimmten wirksamen Ersatzluftspalt enthalten. Die App berechnet keine Carter-Zahl aus fehlenden Nutabmessungen. Für einen Messwertvergleich muss insbesondere die Streuinduktivität ergänzt werden.</p>
          <p>Bei Sättigung ist Ψ(i) nicht linear: Die Sekanteninduktivität Ψ/i und die differentielle Induktivität dΨ/di beschreiben dann verschiedene Eigenschaften. Eine belastbare nichtlineare Rechnung benötigt Materialkennlinien und weitere Geometrie.</p>
        </details>
      </Stage>
    </>}
  </div>;
}

function kLabel(order) { return <sub>{order}</sub>; }
