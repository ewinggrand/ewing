import React, { useEffect, useId, useMemo, useState } from "react";
import {
  computeReferenceSpectrum,
  computeSpectrum,
  SPECTRUM_REFERENCES,
} from "../domain/spectrum.js";

const COLORS = { A: "#c65736", B: "#31806d", C: "#5668c9" };
const short = (value, digits = 4) => {
  if (!Number.isFinite(value)) return "–";
  if (value === 0 || Math.abs(value) < 1e-11) return "0";
  if (Math.abs(value) < 0.0001) return value.toExponential(2).replace(".", ",");
  return value.toLocaleString("de-DE", { maximumFractionDigits: digits });
};
const degree = (value) =>
  Number.isFinite(value) ? `${short(value, 2)}°` : "–";
const selectedValue = (coefficient, display) =>
  display === "magnitude" ? coefficient.amplitude : coefficient.real;
const normalizePhase = (angle) => ((((angle + 180) % 360) + 360) % 360) - 180;

const STYLES = `
.spectrum-panel{--sp-accent:#c65736;--sp-ink:#344132;--sp-muted:#7b8475;--sp-line:#e2e5db;--sp-paper:#fdfdfa;color:var(--sp-ink)}
.spectrum-panel *{box-sizing:border-box}.spectrum-panel button,.spectrum-panel select{font:inherit}.spectrum-panel button{cursor:pointer}
.spectrum-source-section{margin-bottom:20px}.spectrum-label{display:block;font-size:9px;letter-spacing:1.35px;text-transform:uppercase;font-weight:650;color:var(--sp-muted);margin-bottom:10px}
.spectrum-sources{display:grid;grid-template-columns:repeat(auto-fit,minmax(132px,1fr));gap:8px}.spectrum-source{position:relative;text-align:left;border:1px solid var(--sp-line);border-radius:6px;background:#fafaf5;padding:12px 12px 13px;min-height:77px;color:var(--sp-ink);transition:background .15s,border-color .15s}
.spectrum-source:hover{background:#f0f2e9}.spectrum-source.is-active{background:#f2ece1;border-color:#c9ad8d;box-shadow:inset 0 2px 0 #b3653d}.spectrum-source small{font-size:7px;letter-spacing:1.3px;color:#959b8e;display:block;margin-bottom:7px}.spectrum-source.is-active small{color:#a36640}.spectrum-source strong{font-size:10px;font-weight:550;line-height:1.4;display:block}
.spectrum-controls{display:grid;grid-template-columns:minmax(100px,.8fr) minmax(160px,1.35fr) minmax(95px,.7fr) minmax(158px,1.1fr);gap:16px;padding:20px;margin-bottom:18px;border:1px solid var(--sp-line);border-radius:8px;background:var(--sp-paper)}
.spectrum-control{min-width:0}.spectrum-control>label,.spectrum-control>span{display:block;font-size:9px;font-weight:550;margin-bottom:9px;color:#727d69}.spectrum-control select{width:100%;height:36px;border:1px solid #dfe4d7;border-radius:4px;background:#fcfdf8;color:#47543c;padding:0 9px;font-size:10px}.spectrum-control select:disabled{opacity:.5;cursor:default}
.spectrum-segmented{display:flex;border:1px solid #dfe4d7;border-radius:4px;background:#f3f5ec;padding:3px;gap:3px;height:36px}.spectrum-segmented button{flex:1;min-width:0;background:transparent;border:0;border-radius:2px;font-size:10px;color:#8a927e;padding:0 5px}.spectrum-segmented button.is-active{color:var(--sp-ink);background:#fffefa;box-shadow:0 1px 3px #26382012}.spectrum-segmented button:disabled{opacity:.4;cursor:default}
.spectrum-control-footer{grid-column:1/-1;display:flex;justify-content:space-between;align-items:center;gap:12px;padding-top:1px}.spectrum-polarity{display:flex;align-items:center;gap:8px;font-size:10px;color:#6d7863;cursor:pointer}.spectrum-polarity input{width:13px;height:13px;accent-color:#a85c36;margin:0}.spectrum-control-note{font-size:8px;color:#969d8e;text-align:right;line-height:1.6}
.spectrum-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-bottom:18px}.spectrum-metric{min-width:0;border:1px solid var(--sp-line);border-radius:7px;padding:17px 18px;background:var(--sp-paper)}.spectrum-metric>span{display:block;color:#7e8874;font-size:9px;margin-bottom:10px}.spectrum-metric strong{font-family:Georgia,serif;font-weight:400;font-size:29px;letter-spacing:-.8px;line-height:1;display:block}.spectrum-metric strong.spectrum-metric-small{font-family:inherit;font-size:15px;letter-spacing:-.2px;line-height:1.6}.spectrum-metric small{font-size:8px;line-height:1.65;display:block;color:#8e9782;margin-top:9px}.spectrum-metric-accent strong{color:var(--sp-accent)}
.spectrum-chart-panel{border:1px solid var(--sp-line);border-radius:8px;background:var(--sp-paper);overflow:hidden;margin-bottom:18px}.spectrum-heading{padding:21px 22px 12px;display:flex;justify-content:space-between;gap:16px;align-items:flex-start}.spectrum-heading h2{font-size:13px;font-weight:550;margin:0}.spectrum-heading p{color:#8b947f;font-size:9px;margin:7px 0 0;line-height:1.7}.spectrum-view-label{font-family:Georgia,serif;font-size:15px;color:var(--sp-accent);white-space:nowrap;border:1px solid #e6e7dd;border-radius:4px;padding:6px 10px}
.spectrum-model{margin:0 22px 5px;padding:13px 15px;border:1px solid #e6e7db;border-radius:5px;background:#f5f6ed}.spectrum-model-title{font-size:8px;letter-spacing:1px;color:#949a86;margin-bottom:7px;text-transform:uppercase}.spectrum-formula{font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:1.8;overflow-wrap:anywhere}.spectrum-model p{font-size:9px;line-height:1.85;color:#7d8871;margin:6px 0 0}.spectrum-model .spectrum-reference-note{padding-top:9px;margin-top:9px;border-top:1px solid #dedfcf;color:#946b43}.spectrum-polarity-note{display:inline-block;color:#a46842!important;font-weight:550}.spectrum-chart-wrap{padding:3px 7px 0}.spectrum-chart{display:block;width:100%;height:auto;font-family:inherit}.spectrum-chart [role=button]{cursor:pointer}.spectrum-chart [role=button]:focus-visible{outline:2px solid #bd673b;outline-offset:1px}
.spectrum-chart-footnote{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;padding:0 22px 16px;font-size:8px;line-height:1.7;color:#8b957e}.spectrum-key{display:flex;gap:13px;align-items:center}.spectrum-key>span{display:flex;align-items:center;gap:5px}.spectrum-key i{display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--sp-accent)}.spectrum-key i.spectrum-fundamental-key{background:#fff;border:1.5px solid var(--sp-accent);width:8px;height:8px}
.spectrum-selected{display:flex;gap:18px;align-items:center;padding:16px 22px;border-top:1px solid #e8eadf;background:#fafaf4}.spectrum-selected-title{min-width:111px}.spectrum-selected-title>strong{font-size:13px;font-weight:550;display:block}.spectrum-selected-title>span{font-size:8px;color:#8a947e;display:block;margin-top:6px}.spectrum-selected-values{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:17px;flex:1;min-width:0}.spectrum-selected-values span{display:block;font-size:8px;color:#8f9784;margin-bottom:6px}.spectrum-selected-values strong{font-size:11px;font-weight:550;white-space:nowrap}.spectrum-badge{display:inline-block;font-size:7px;color:#a0653d;background:#f3e8d7;border-radius:3px;padding:3px 5px;line-height:1;margin-left:6px;vertical-align:2px}
.spectrum-actions{display:flex;gap:10px;justify-content:space-between;align-items:center;margin-bottom:17px}.spectrum-action-button{border:1px solid #d9dece;border-radius:5px;background:#fafbf6;color:#6c785f;font-size:9px;padding:10px 12px;display:inline-flex;align-items:center;gap:7px}.spectrum-action-button:hover{background:#eef1e5}.spectrum-action-button:disabled{opacity:.45;cursor:default}.spectrum-download-status{font-size:8px;color:#8b957e;margin-left:auto}
.spectrum-table-panel{border:1px solid var(--sp-line);border-radius:7px;overflow:hidden;margin-bottom:18px;background:var(--sp-paper)}.spectrum-table-heading{padding:14px 18px;border-bottom:1px solid var(--sp-line);font-size:10px;color:#7e8873;display:flex;justify-content:space-between;gap:10px}.spectrum-table-scroll{overflow:auto;max-height:355px}.spectrum-table{width:100%;min-width:580px;border-collapse:collapse;font-size:10px;font-variant-numeric:tabular-nums}.spectrum-table th{position:sticky;top:0;z-index:1;background:#f3f5ec;color:#828c76;text-align:right;font-size:9px;font-weight:500;padding:11px 14px;border-bottom:1px solid var(--sp-line)}.spectrum-table td{padding:10px 14px;border-bottom:1px solid #edf0e6;text-align:right;color:#69755d}.spectrum-table th:first-child,.spectrum-table td:first-child{text-align:left}.spectrum-table tr.is-selected td{background:#f1ecdf;color:#574c38}.spectrum-table td button{font:inherit;color:inherit;background:transparent;border:0;padding:1px 2px;text-decoration:underline;text-decoration-color:#c4cbb9;text-underline-offset:3px}.spectrum-table .spectrum-fundamental-cell{font-weight:650;color:var(--sp-accent)}
.spectrum-explanation{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:22px;border:1px solid var(--sp-line);border-radius:8px;padding:21px;background:#f7f8f0}.spectrum-explanation h3{font-size:10px;font-weight:550;margin:0 0 10px}.spectrum-explanation p{font-size:9px;line-height:1.95;color:#7f8972;margin:0}.spectrum-explanation strong{font-weight:550;color:#647257}.spectrum-reference-detail{font-size:9px;line-height:1.9;color:#859078;grid-column:1/-1;border-top:1px solid #e2e6d8;padding-top:13px}.spectrum-reference-detail summary{cursor:pointer;font-size:9px;color:#7b876d}.spectrum-reference-detail p{padding-top:8px;overflow-wrap:anywhere}
.spectrum-invalid{padding:26px;border:1px dashed #cbbda2;background:#faf6ed;border-radius:8px;margin-bottom:18px}.spectrum-invalid h2{font-size:14px;font-weight:550;color:#9b6c43;margin-bottom:12px}.spectrum-invalid p{font-size:11px;line-height:1.9;color:#8d816b}.spectrum-outside{margin:12px 22px 2px;font-size:9px;color:#9a744b;line-height:1.8}.spectrum-outside button{background:transparent;border:0;font:inherit;color:#9a643d;text-decoration:underline;text-underline-offset:3px;padding:0;margin-left:8px}.spectrum-warnings{margin:13px 0;padding:13px 17px;border:1px solid #e6d9bd;border-radius:5px;background:#fbf5e9;color:#8f754e;font-size:9px;line-height:1.9}.spectrum-warnings p{margin:0}
@media(max-width:1100px){.spectrum-controls{grid-template-columns:1fr 1fr;gap:16px}.spectrum-explanation{grid-template-columns:1fr;gap:18px}.spectrum-explanation>div+div{padding-top:15px;border-top:1px solid #e3e7d9}.spectrum-selected{align-items:flex-start;gap:12px}.spectrum-selected-values{gap:12px}}
@media(max-width:640px){.spectrum-sources{grid-template-columns:repeat(2,minmax(0,1fr));gap:6px}.spectrum-source:first-child{grid-column:1/-1;min-height:63px}.spectrum-source{min-height:73px;padding:11px}.spectrum-controls{padding:15px;gap:15px 11px}.spectrum-control-footer{align-items:flex-start;flex-direction:column;gap:10px}.spectrum-control-note{text-align:left;font-size:8px}.spectrum-polarity{font-size:9px}.spectrum-metrics{gap:7px}.spectrum-metric{padding:13px 11px}.spectrum-metric>span{font-size:7px;line-height:1.7;min-height:24px;margin-bottom:8px}.spectrum-metric strong{font-size:24px}.spectrum-metric strong.spectrum-metric-small{font-size:11px}.spectrum-metric small{font-size:7px}.spectrum-heading{padding:18px 15px 12px;gap:10px}.spectrum-heading h2{font-size:12px}.spectrum-heading p{font-size:8px}.spectrum-view-label{font-size:12px;padding:6px}.spectrum-model{margin:0 14px 4px;padding:11px}.spectrum-formula{font-size:13px}.spectrum-model p{font-size:8px}.spectrum-chart-wrap{padding:5px 1px 0;overflow-x:auto}.spectrum-chart{min-width:500px}.spectrum-chart-footnote{padding:0 15px 13px;font-size:7px}.spectrum-selected{flex-direction:column;padding:15px}.spectrum-selected-title{width:100%;display:flex;justify-content:space-between;align-items:center}.spectrum-selected-title>span{margin-top:0;font-size:8px}.spectrum-selected-values{width:100%;gap:9px}.spectrum-selected-values span{font-size:7px}.spectrum-selected-values strong{font-size:10px}.spectrum-actions{flex-wrap:wrap;gap:9px}.spectrum-action-button{font-size:8px;padding:9px 10px}.spectrum-download-status{width:100%;margin:0}.spectrum-explanation{padding:18px}.spectrum-outside{margin:12px 15px 0;font-size:8px}.spectrum-table-heading{font-size:8px}}
`;

function Plot({
  data,
  coefficients,
  display,
  selectedOrder,
  onSelectOrder,
  color,
  title,
  subtitle,
  formula,
  id,
}) {
  const width = 960;
  const height = 342;
  const left = 62;
  const right = 27;
  const top = 27;
  const bottom = 277;
  const plotWidth = width - left - right;
  const signed = display === "real";
  const values = coefficients.map((coefficient) =>
    selectedValue(coefficient, display),
  );
  const maximum = Math.max(0, ...values);
  const minimum = signed ? Math.min(0, ...values) : 0;
  const niceBound = (value) => {
    if (value < 1e-11) return 0;
    const padded = value * 1.08;
    const unit = 10 ** Math.floor(Math.log10(padded));
    return (
      ([1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10].find(
        (factor) => factor * unit >= padded,
      ) || 10) * unit
    );
  };
  const upper = niceBound(maximum) || (minimum > -1e-11 ? 1 : 0);
  const lower = signed ? niceBound(-minimum) : 0;
  const y = (value) =>
    signed
      ? top + ((upper - value) / (upper + lower)) * (bottom - top)
      : bottom - (value / upper) * (bottom - top);
  const baseline = y(0);
  const x = (order) => left + ((order - 0.5) / data.maxOrder) * plotWidth;
  const ticks = signed
    ? [
        ...(lower > 0 ? [-lower, -lower / 2] : []),
        0,
        ...(upper > 0 ? [upper / 2, upper] : []),
      ]
    : [0, upper / 4, upper / 2, (upper * 3) / 4, upper];
  const step = data.maxOrder <= 20 ? 1 : data.maxOrder <= 40 ? 5 : 10;
  const keyboard = (event, order) => {
    let next = order;
    if (event.key === "ArrowRight" || event.key === "ArrowUp")
      next = Math.min(data.maxOrder, order + 1);
    else if (event.key === "ArrowLeft" || event.key === "ArrowDown")
      next = Math.max(1, order - 1);
    else if (event.key === "Home") next = 1;
    else if (event.key === "End") next = data.maxOrder;
    else if (!["Enter", " "].includes(event.key)) return;
    event.preventDefault();
    onSelectOrder(next);
    event.currentTarget.ownerSVGElement
      ?.querySelector(`[data-spectrum-order="${next}"]`)
      ?.focus();
  };
  return (
    <svg
      className="diagram-svg spectrum-chart"
      viewBox={`0 0 ${width} ${height}`}
      width={width}
      height={height}
      role="img"
      aria-labelledby={`${id}-title ${id}-desc`}
      data-export-title={title}
      data-export-subtitle={subtitle}
    >
      <title
        id={`${id}-title`}
      >{`${title}: ${signed ? "vorzeichenbehafteter Realteil Re(Cₖ)" : "Betrag |Cₖ|"} für mechanische Ordnungen 1 bis ${data.maxOrder}`}</title>
      <desc id={`${id}-desc`}>
        Linien des räumlichen Fourier-Spektrums. Die senkrechte Achse zeigt
        dimensionslose Koeffizienten, die waagerechte Achse die mechanische
        Raumordnung k. Ordnungen per Klick wählen; mit Pfeiltasten, Pos1 und
        Ende wechseln. Der Realteil hängt von der festen Bezugsphase und der
        Strangpolung ab.
      </desc>
      <rect width={width} height={height} fill="#fdfdfa" />
      {ticks.map((tick) => (
        <g key={tick}>
          <line
            x1={left}
            x2={width - right}
            y1={y(tick)}
            y2={y(tick)}
            stroke={tick === 0 ? "#aeb8a3" : "#e5e9dd"}
            strokeWidth={tick === 0 ? 1.2 : 0.7}
            strokeDasharray={tick === 0 ? undefined : "2 5"}
          />
          <text
            x={left - 12}
            y={y(tick) + 3.7}
            fill="#8c967e"
            fontSize="10"
            textAnchor="end"
          >
            {short(tick, 4)}
          </text>
        </g>
      ))}
      <text x={left} y="14" fill="#8a947c" fontSize="10">
        {signed ? "Re(Cₖ)" : "|Cₖ|"}
      </text>
      <text
        x={width - right}
        y="14"
        fill="#7e8872"
        fontFamily="Georgia, 'Times New Roman', serif"
        fontSize="11"
        textAnchor="end"
      >
        {formula}
      </text>
      {coefficients.map((coefficient) => {
        const value = selectedValue(coefficient, display);
        const selected = coefficient.order === selectedOrder;
        const targetX = x(coefficient.order);
        const targetY = y(value);
        const isZero = Math.abs(value) < 1e-11;
        const aria = `Ordnung ${coefficient.order}${coefficient.isFundamental ? ", Grundwelle" : ""}: Realteil ${short(coefficient.real)}, Imaginärteil ${short(coefficient.imag)}, Betrag ${short(coefficient.amplitude)}, Phase ${degree(coefficient.phaseDeg)}`;
        return (
          <g
            key={coefficient.order}
            role="button"
            tabIndex={selected ? 0 : -1}
            aria-label={aria}
            aria-pressed={selected}
            data-spectrum-order={coefficient.order}
            onClick={() => onSelectOrder(coefficient.order)}
            onKeyDown={(event) => keyboard(event, coefficient.order)}
          >
            <title>{`${aria}${coefficient.kw === null ? "" : `, Wicklungsfaktor ${short(coefficient.kw)}`}`}</title>
            {selected && (
              <rect
                x={targetX - plotWidth / data.maxOrder / 2 + 1}
                y={top - 5}
                width={Math.max(4, plotWidth / data.maxOrder - 2)}
                height={bottom - top + 10}
                fill="#eae2d4"
                opacity="0.52"
                rx="2"
              />
            )}
            <rect
              x={targetX - plotWidth / data.maxOrder / 2}
              y={top - 5}
              width={plotWidth / data.maxOrder}
              height={bottom - top + 10}
              fill="transparent"
            />
            {coefficient.isFundamental && (
              <line
                x1={targetX}
                x2={targetX}
                y1={top - 2}
                y2={bottom + 5}
                stroke={color}
                strokeOpacity="0.2"
                strokeDasharray="3 4"
              />
            )}
            {!isZero && (
              <line
                x1={targetX}
                x2={targetX}
                y1={baseline}
                y2={targetY}
                stroke={color}
                strokeWidth={selected ? 2.8 : data.maxOrder > 60 ? 1.5 : 2}
                strokeOpacity={value < 0 ? 0.68 : 0.9}
              />
            )}
            <circle
              cx={targetX}
              cy={targetY}
              r={
                selected
                  ? 4.5
                  : coefficient.isFundamental
                    ? 4
                    : isZero
                      ? 1.8
                      : 2.8
              }
              fill={coefficient.isFundamental ? "#fdfdfa" : color}
              stroke={coefficient.isFundamental || selected ? color : "none"}
              strokeWidth={coefficient.isFundamental ? 1.8 : 1}
              opacity={isZero && !selected ? 0.42 : 1}
            />
          </g>
        );
      })}
      {coefficients
        .filter(
          (coefficient) =>
            coefficient.order === 1 ||
            coefficient.order % step === 0 ||
            coefficient.order === data.maxOrder,
        )
        .map((coefficient) => (
          <text
            key={coefficient.order}
            x={x(coefficient.order)}
            y={bottom + 23}
            textAnchor="middle"
            fill={coefficient.order === selectedOrder ? color : "#8e977f"}
            fontSize={data.maxOrder <= 20 ? 10.5 : 10}
            fontWeight={coefficient.order === selectedOrder ? "700" : "400"}
          >
            {coefficient.order}
          </text>
        ))}
      <text
        x={(left + width - right) / 2}
        y="328"
        fill="#88937a"
        fontSize="10.5"
        textAnchor="middle"
      >
        Mechanische Raumordnung k
      </text>
    </svg>
  );
}

function applyPolarity(coefficient, polarity) {
  if (!coefficient) return null;
  return {
    ...coefficient,
    real: coefficient.real === 0 ? 0 : coefficient.real * polarity,
    imag: coefficient.imag === 0 ? 0 : coefficient.imag * polarity,
    phaseDeg:
      coefficient.amplitude === 0
        ? 0
        : normalizePhase(coefficient.phaseDeg + (polarity === -1 ? 180 : 0)),
    signedRelativeToFundamental:
      coefficient.signedRelativeToFundamental === null
        ? null
        : coefficient.signedRelativeToFundamental * polarity,
  };
}

function downloadSpectrum(data, result) {
  const csvCell = (value) => `"${String(value ?? "").replaceAll('"', '""')}"`;
  const rows = [
    ["# Modell", data.title],
    ["# Quelle", data.sourceId],
    [
      "# Q",
      data.sourceId === "winding"
        ? result?.slots
        : "Aus Referenzformel nicht festgelegt",
    ],
    ["# p", data.polePairs ?? "Nicht festgelegt"],
    [
      "# Strang",
      data.sourceId === "winding" ? data.phase : "Analytische Referenz",
    ],
    ["# Normierung", data.normalizationText],
    ["# Fester mechanischer Phasenbezug [Grad]", data.mechanicalReferenceDeg],
    [
      "# Polung",
      data.polarity === -1
        ? "-1: alle dargestellten Koeffizienten global umgekehrt"
        : "+1: Formel-/Modellpolung",
    ],
    [
      "# Darstellung",
      data.display === "real"
        ? "Re(C_k), vorzeichenbehafteter Realteil"
        : "|C_k|, Betrag",
    ],
    [
      "# Formel",
      data.formula ||
        "D_k = Summe s_j exp(-ik phi_j); C_k = D_k/(2ikN), N=1 bei Strangsumme",
    ],
    ["# Referenzhinweis", data.referenceNote || ""],
    ["k", "real", "imag", "amplitude", "phaseDeg", "kw"],
    ...data.displayCoefficients.map((coefficient) => [
      coefficient.order,
      coefficient.real,
      coefficient.imag,
      coefficient.amplitude,
      coefficient.phaseDeg,
      coefficient.kw,
    ]),
  ];
  const blob = new Blob(
    ["\uFEFF" + rows.map((row) => row.map(csvCell).join(";")).join("\r\n")],
    { type: "text/csv;charset=utf-8;" },
  );
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `spektrum-${data.sourceId}${data.sourceId === "winding" ? `-Q${result.slots}-p${result.polePairs}-${data.phase}` : ""}-k${data.maxOrder}.csv`;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function SpectrumPanel({ result, onDataChange }) {
  const [sourceId, setSourceId] = useState("winding");
  const [phase, setPhase] = useState("A");
  const [normalization, setNormalization] = useState("phase-sum");
  const [maxOrder, setMaxOrder] = useState(20);
  const [display, setDisplay] = useState("real");
  const [reversed, setReversed] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(
    result?.polePairs <= 20 ? result.polePairs : 1,
  );
  const [tableOpen, setTableOpen] = useState(false);
  const [downloadStatus, setDownloadStatus] = useState("");
  const id = `spectrum-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
  const live = sourceId === "winding";
  const reference = SPECTRUM_REFERENCES.find((item) => item.id === sourceId);
  const title = live
    ? "Aktuelles Wicklungsmodell"
    : reference?.title || "Analytische Referenz";
  const color = live ? COLORS[phase] : COLORS.A;
  const polarity = reversed ? -1 : 1;
  const liveResult = live ? result : null;
  const spectrum = useMemo(
    () =>
      live
        ? computeSpectrum(liveResult, { maxOrder, phase, normalization })
        : computeReferenceSpectrum(sourceId, { maxOrder }),
    [live, liveResult, sourceId, maxOrder, phase, normalization],
  );
  const coefficients = useMemo(
    () =>
      spectrum.coefficients.map((coefficient) =>
        applyPolarity(coefficient, polarity),
      ),
    [spectrum, polarity],
  );
  const data = useMemo(
    () => ({
      ...spectrum,
      title,
      sourceId,
      display,
      polarity,
      displayOptions: {
        display,
        polarity,
        maxOrder,
        phase: spectrum.phase,
        normalization: spectrum.normalization,
      },
      displayCoefficients: coefficients,
      displayFundamental: applyPolarity(spectrum.fundamental, polarity),
    }),
    [spectrum, title, sourceId, display, polarity, maxOrder, coefficients],
  );
  useEffect(() => {
    onDataChange?.(data);
  }, [data, onDataChange]);
  useEffect(() => {
    setSelectedOrder(
      spectrum.fundamentalOrder && spectrum.fundamentalOrder <= maxOrder
        ? spectrum.fundamentalOrder
        : 1,
    );
    setDownloadStatus("");
  }, [
    sourceId,
    phase,
    liveResult?.slots,
    liveResult?.polePairs,
    liveResult?.layers,
    liveResult?.coilSpan,
  ]);
  useEffect(() => {
    setSelectedOrder((order) => (order <= maxOrder ? order : 1));
  }, [maxOrder]);
  const selected =
    coefficients.find((coefficient) => coefficient.order === selectedOrder) ||
    coefficients[0];
  const hasFundamental =
    Number.isInteger(spectrum.fundamentalOrder) &&
    spectrum.fundamentalOrder > 0;
  const fundamentalVisible =
    hasFundamental && spectrum.fundamentalOrder <= maxOrder;
  const largestSide = coefficients
    .filter((coefficient) => coefficient.order !== spectrum.fundamentalOrder)
    .reduce(
      (largest, coefficient) =>
        !largest || coefficient.amplitude > largest.amplitude + 1e-11
          ? coefficient
          : largest,
      null,
    );
  const referenceOrder = spectrum.referenceOrder || 1;
  const amplitude =
    spectrum.fundamental?.amplitude ??
    spectrum.referenceCoefficient?.amplitude ??
    coefficients[0]?.amplitude;
  const modelFormula = live
    ? `Cₖ = Dₖ / (2 i k${normalization === "per-coil" ? " N" : ""})  ·  Dₖ = Σ sⱼ exp(−i k φⱼ)`
    : reference?.formula;
  const subtitle = `${live ? `Strang ${phase} · ${normalization === "phase-sum" ? "Strangsumme" : "pro Spule"} · fester Bezug φ₀ = ${degree(spectrum.mechanicalReferenceDeg)}` : "Analytische Referenz · Formelamplituden"} · ${display === "real" ? "Re(Cₖ)" : "|Cₖ|"} · Polung ${reversed ? "−1" : "+1"} · k ≤ ${maxOrder}`;
  const warnings = spectrum.warnings.filter(
    (warning) => warning !== spectrum.referenceNote,
  );

  return (
    <div className="spectrum-panel" style={{ "--sp-accent": color }}>
      <style>{STYLES}</style>
      <div className="spectrum-source-section">
        <span className="spectrum-label">Spektrum untersuchen</span>
        <div
          className="spectrum-sources"
          aria-label="Datenquelle für das Spektrum"
        >
          <button
            type="button"
            className={`spectrum-source${live ? " is-active" : ""}`}
            aria-pressed={live}
            onClick={() => setSourceId("winding")}
          >
            <small>LIVE · AUS NUTBELEGUNG</small>
            <strong>Aktuelle Wicklung</strong>
          </button>
          {SPECTRUM_REFERENCES.map((item, index) => (
            <button
              type="button"
              key={item.id}
              className={`spectrum-source${sourceId === item.id ? " is-active" : ""}`}
              aria-pressed={sourceId === item.id}
              onClick={() => setSourceId(item.id)}
            >
              <small>FOLIENREFERENZ 0{index + 1}</small>
              <strong>{item.title}</strong>
            </button>
          ))}
        </div>
      </div>

      <div className="spectrum-controls">
        <div className="spectrum-control">
          <span id={`${id}-phase-label`}>Strang</span>
          <div
            className="spectrum-segmented"
            role="group"
            aria-labelledby={`${id}-phase-label`}
          >
            {["A", "B", "C"].map((item) => (
              <button
                type="button"
                key={item}
                disabled={!live}
                aria-pressed={live && phase === item}
                className={phase === item && live ? "is-active" : ""}
                style={
                  live && phase === item ? { color: COLORS[item] } : undefined
                }
                onClick={() => setPhase(item)}
              >
                {item}
              </button>
            ))}
          </div>
        </div>
        <div className="spectrum-control">
          <label htmlFor={`${id}-normalization`}>Amplitudenbezug</label>
          <select
            id={`${id}-normalization`}
            value={live ? normalization : "formula"}
            disabled={!live}
            onChange={(event) => setNormalization(event.target.value)}
          >
            {live ? (
              <>
                <option value="phase-sum">Strangsumme</option>
                <option value="per-coil">Pro Spule</option>
              </>
            ) : (
              <option value="formula">Unveränderte Formel</option>
            )}
          </select>
        </div>
        <div className="spectrum-control">
          <label htmlFor={`${id}-max-order`}>Höchste Ordnung</label>
          <select
            id={`${id}-max-order`}
            value={maxOrder}
            onChange={(event) => setMaxOrder(Number(event.target.value))}
          >
            {[20, 40, 60, 120].map((order) => (
              <option key={order} value={order}>
                k ≤ {order}
              </option>
            ))}
          </select>
        </div>
        <div className="spectrum-control">
          <span id={`${id}-view-label`}>Darstellung</span>
          <div
            className="spectrum-segmented"
            role="group"
            aria-labelledby={`${id}-view-label`}
          >
            <button
              type="button"
              className={display === "real" ? "is-active" : ""}
              aria-pressed={display === "real"}
              onClick={() => setDisplay("real")}
            >
              Realteil ±
            </button>
            <button
              type="button"
              className={display === "magnitude" ? "is-active" : ""}
              aria-pressed={display === "magnitude"}
              onClick={() => setDisplay("magnitude")}
            >
              Betrag
            </button>
          </div>
        </div>
        <div className="spectrum-control-footer">
          <label className="spectrum-polarity">
            <input
              type="checkbox"
              checked={reversed}
              onChange={(event) => setReversed(event.target.checked)}
            />
            Polung umkehren · alle Koeffizienten × −1
          </label>
          <span className="spectrum-control-note">
            {live
              ? `${spectrum.coilCountPhase} Spulen in Strang ${phase} · mechanische Raumordnungen`
              : "Analytische Formeln unabhängig vom aktuellen Wickelschema"}
          </span>
        </div>
      </div>

      {!spectrum.valid ? (
        <div className="spectrum-invalid" role="status">
          <h2>Für dieses Modell liegt kein gültiges Spektrum vor.</h2>
          {spectrum.warnings.map((warning) => (
            <p key={warning}>{warning}</p>
          ))}
          <p>
            Eine gültige Wicklung berechnen oder eine der Folienreferenzen
            auswählen.
          </p>
        </div>
      ) : (
        <>
          <div className="spectrum-metrics">
            <div className="spectrum-metric">
              <span>
                {live
                  ? "Nutzgrundwelle"
                  : hasFundamental
                    ? "Grundwellenbezug der Referenz"
                    : "Bezugsordnung der Formel"}
              </span>
              <strong>{`k = ${hasFundamental ? spectrum.fundamentalOrder : referenceOrder}`}</strong>
              <small>
                {live
                  ? `k = p = ${spectrum.polePairs} · elektrisch ν = 1`
                  : hasFundamental
                    ? "k = 4 gemäß Referenzannahme"
                    : "p und Nutzgrundwelle nicht festgelegt"}
              </small>
            </div>
            <div className="spectrum-metric spectrum-metric-accent">
              <span>
                {hasFundamental
                  ? live
                    ? "Grundwellenbetrag |Cₚ|"
                    : "Referenz-Grundwellenbetrag |Cₖ|"
                  : `Betrag bei Bezugsordnung k = ${referenceOrder}`}
              </span>
              <strong>{short(amplitude)}</strong>
              <small>
                {live
                  ? normalization === "per-coil"
                    ? "pro Spule · einschließlich 1/p-Faktor"
                    : `Summe über ${spectrum.coilCountPhase} Spulen`
                  : "Formelamplitude · dimensionslos"}
              </small>
            </div>
            <div className="spectrum-metric">
              <span>
                {hasFundamental
                  ? "Größte weitere Raumordnung"
                  : "Größter dargestellter Koeffizient"}
              </span>
              <strong>{largestSide ? `k = ${largestSide.order}` : "–"}</strong>
              <small>
                {largestSide
                  ? `|Cₖ| = ${short(largestSide.amplitude)} · im Bereich k ≤ ${maxOrder}`
                  : `im Bereich k ≤ ${maxOrder}`}
              </small>
            </div>
          </div>

          <section
            className="spectrum-chart-panel"
            aria-labelledby={`${id}-chart-heading`}
          >
            <div className="spectrum-heading">
              <div>
                <h2 id={`${id}-chart-heading`}>Räumliches Linienspektrum</h2>
                <p>
                  {live
                    ? `Q = ${result.slots} · p = ${result.polePairs} · Strang ${phase}`
                    : reference?.title}{" "}
                  ·{" "}
                  {display === "real"
                    ? "vorzeichenbehafteter Realteil"
                    : "Betrag der komplexen Koeffizienten"}
                </p>
              </div>
              <span className="spectrum-view-label">
                {display === "real" ? "Re(Cₖ)" : "|Cₖ|"}
              </span>
            </div>
            <div className="spectrum-model">
              <div className="spectrum-model-title">
                {live
                  ? "Berechnung aus allen tatsächlichen Spulenseiten"
                  : "Angegebene Formel der Folienreferenz"}
              </div>
              <div className="spectrum-formula">{modelFormula}</div>
              <p>
                {live
                  ? `${spectrum.normalizationText} Mechanische Nutlage φⱼ = 2π (Nutⱼ − 1) / Q.`
                  : reference?.description}
              </p>
              {reference?.referenceNote && (
                <p className="spectrum-reference-note">
                  {reference.referenceNote}
                </p>
              )}
              {reversed && (
                <p className="spectrum-polarity-note">
                  Darstellung mit umgekehrter Polung: Die gesamte Formel wird
                  mit −1 multipliziert.
                </p>
              )}
            </div>
            {hasFundamental && !fundamentalVisible && (
              <p className="spectrum-outside">
                Die Grundwelle k = {spectrum.fundamentalOrder} liegt außerhalb
                des angezeigten Bereichs k ≤ {maxOrder}. Ihr Betrag wird dennoch
                separat berechnet.
                <button
                  type="button"
                  onClick={() => {
                    setMaxOrder(
                      [20, 40, 60, 120].find(
                        (order) => order >= spectrum.fundamentalOrder,
                      ) || 120,
                    );
                    setSelectedOrder(spectrum.fundamentalOrder);
                  }}
                >
                  Bereich erweitern
                </button>
              </p>
            )}
            <div className="spectrum-chart-wrap">
              <Plot
                data={spectrum}
                coefficients={coefficients}
                display={display}
                selectedOrder={selected?.order}
                onSelectOrder={setSelectedOrder}
                color={color}
                title={`${title}${live ? ` · Q${result.slots}/p${result.polePairs}` : ""}`}
                subtitle={subtitle}
                formula={modelFormula}
                id={id}
              />
            </div>
            <div className="spectrum-chart-footnote">
              <div className="spectrum-key">
                <span>
                  <i />
                  Koeffizient
                </span>
                {fundamentalVisible && (
                  <span>
                    <i className="spectrum-fundamental-key" />
                    Grundwelle k = {spectrum.fundamentalOrder}
                  </span>
                )}
              </div>
              <span>Linie auswählen · Pfeiltasten wechseln die Ordnung</span>
            </div>
            {selected && (
              <div className="spectrum-selected" aria-live="polite">
                <div className="spectrum-selected-title">
                  <strong>
                    Ordnung k = {selected.order}
                    {selected.isFundamental && (
                      <span className="spectrum-badge">GRUNDWELLE</span>
                    )}
                  </strong>
                  <span>
                    {live
                      ? `elektrisch ν = ${short(selected.order / spectrum.polePairs, 3)}`
                      : "analytischer Fourierkoeffizient"}
                  </span>
                </div>
                <div className="spectrum-selected-values">
                  <div>
                    <span>Realteil Re(Cₖ)</span>
                    <strong>{short(selected.real, 5)}</strong>
                  </div>
                  <div>
                    <span>Imaginärteil Im(Cₖ)</span>
                    <strong>{short(selected.imag, 5)}</strong>
                  </div>
                  <div>
                    <span>Betrag |Cₖ|</span>
                    <strong>{short(selected.amplitude, 5)}</strong>
                  </div>
                  <div>
                    <span>Raumphase arg(Cₖ)</span>
                    <strong>{degree(selected.phaseDeg)}</strong>
                  </div>
                </div>
              </div>
            )}
          </section>

          <div className="spectrum-actions">
            <button
              className="spectrum-action-button"
              type="button"
              aria-expanded={tableOpen}
              aria-controls={`${id}-table`}
              onClick={() => setTableOpen(!tableOpen)}
            >
              <span aria-hidden="true">{tableOpen ? "−" : "+"}</span>
              {tableOpen
                ? "Koeffiziententabelle schließen"
                : `Alle ${maxOrder} Koeffizienten anzeigen`}
            </button>
            <span className="spectrum-download-status" role="status">
              {downloadStatus}
            </span>
            <button
              className="spectrum-action-button"
              type="button"
              onClick={() => {
                downloadSpectrum(data, result);
                setDownloadStatus(
                  "Spektrum mit Bezugsdaten als CSV exportiert.",
                );
              }}
            >
              <svg
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                aria-hidden="true"
              >
                <path d="M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4" />
              </svg>
              Spektrum als CSV
            </button>
          </div>
          {tableOpen && (
            <div className="spectrum-table-panel" id={`${id}-table`}>
              <div className="spectrum-table-heading">
                <span>
                  Komplexe Koeffizienten ·{" "}
                  {reversed ? "umgekehrte Polung" : "Modell-/Formelpolung"}
                </span>
                <span>{maxOrder} mechanische Ordnungen</span>
              </div>
              <div className="spectrum-table-scroll">
                <table className="spectrum-table">
                  <thead>
                    <tr>
                      <th scope="col">k</th>
                      <th scope="col">Re(Cₖ)</th>
                      <th scope="col">Im(Cₖ)</th>
                      <th scope="col">|Cₖ|</th>
                      <th scope="col">arg(Cₖ)</th>
                      <th scope="col">k_w(k)</th>
                    </tr>
                  </thead>
                  <tbody>
                    {coefficients.map((coefficient) => (
                      <tr
                        key={coefficient.order}
                        className={
                          selected?.order === coefficient.order
                            ? "is-selected"
                            : ""
                        }
                      >
                        <td
                          className={
                            coefficient.isFundamental
                              ? "spectrum-fundamental-cell"
                              : ""
                          }
                        >
                          <button
                            type="button"
                            aria-label={`Ordnung ${coefficient.order} im Spektrum auswählen`}
                            aria-pressed={selected?.order === coefficient.order}
                            onClick={() => setSelectedOrder(coefficient.order)}
                          >
                            {coefficient.order}
                            {coefficient.isFundamental ? " *" : ""}
                          </button>
                        </td>
                        <td>{short(coefficient.real, 6)}</td>
                        <td>{short(coefficient.imag, 6)}</td>
                        <td>{short(coefficient.amplitude, 6)}</td>
                        <td>{degree(coefficient.phaseDeg)}</td>
                        <td>
                          {coefficient.kw === null
                            ? "–"
                            : short(coefficient.kw, 5)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </>
      )}

      {warnings.length > 0 && spectrum.valid && (
        <div className="spectrum-warnings" role="status">
          {warnings.map((warning) => (
            <p key={warning}>{warning}</p>
          ))}
        </div>
      )}
      <div className="spectrum-explanation">
        <div>
          <h3>Mechanische statt elektrische Ordnung</h3>
          <p>
            k zählt räumliche Wellen über einen vollständigen mechanischen
            Umfang. Beim Wicklungsmodell liegt die Nutzgrundwelle bei{" "}
            <strong>k = p</strong>; die elektrische Ordnung ist ν = k/p.
            Nutenspannungssterne verwenden dagegen elektrische Winkel.
            Referenzformeln legen eine Polpaarzahl nur dort fest, wo sie
            ausdrücklich angegeben ist.
          </p>
        </div>
        <div>
          <h3>Der Faktor 1/k bleibt erhalten</h3>
          <p>
            Die Integration der vorzeichenbehafteten Spulenseiten erzeugt den
            Faktor 1/k im Fourierkoeffizienten. Bei Normierung pro Spule gilt{" "}
            <strong>|Cₖ| = k_w(k)/k</strong>. Das Linienspektrum zeigt deshalb
            andere Höhen als das reine Wicklungsfaktor-Diagramm. Die größte
            weitere Ordnung bezieht sich auf den aktuell gewählten Bereich.
          </p>
        </div>
        <div>
          <h3>Bezug, Vorzeichen und Betrag</h3>
          <p>
            {live && spectrum.valid
              ? `Ein fester mechanischer Bezug von φ₀ = ${degree(spectrum.mechanicalReferenceDeg)} richtet die Grundwelle aus. `
              : "Die Referenzformeln werden ohne automatische Bezugsdrehung ausgewertet. "}
            Der Realteil hängt von diesem Bezug und der Polung ab; der{" "}
            <strong>Betrag bleibt unverändert</strong>. Ein negativer Realteil
            bezeichnet eine Projektion, keine negative Raumordnung oder
            Drehrichtung.
          </p>
        </div>
        {spectrum.valid && (
          <details className="spectrum-reference-detail">
            <summary>Mathematische Konvention und Export</summary>
            <p>
              {spectrum.convention} {spectrum.normalizationText} Die Checkbox
              kehrt alle dargestellten Real- und Imaginärteile gemeinsam um. Im
              CSV stehen die dargestellten Koeffizienten; der JSON-Export
              enthält zusätzlich die ursprünglichen Modellkoeffizienten und die
              gewählten Darstellungsoptionen.
            </p>
          </details>
        )}
      </div>
    </div>
  );
}

export default SpectrumPanel;
