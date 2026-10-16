import React, { useCallback, useMemo, useState } from "react";
import { computeWinding } from "./domain/winding.js";
import { buildWindingLayout } from "./domain/windingLayout.js";
import { computeSpectrum } from "./domain/spectrum.js";
import SpectrumPanel from "./components/SpectrumPanel.jsx";
import InductancePanel from "./components/InductancePanel.jsx";
import {
  SlotStar,
  PhaseStar,
  ZonePlan,
  WindingDiagram,
} from "./components/Diagrams.jsx";

const COLORS = { A: "#c65736", B: "#31806d", C: "#5668c9" };
const PRESETS = [
  {
    name: "Das Folienbeispiel",
    detail: "12 Nuten · 2 Pole · Einschicht",
    slots: 12,
    polePairs: 1,
    layers: 1,
    coilSpan: 6,
  },
  {
    name: "Verteilte Wicklung",
    detail: "36 Nuten · 4 Pole · Einschicht",
    slots: 36,
    polePairs: 2,
    layers: 1,
    coilSpan: "auto",
  },
  {
    name: "Bruchlochwicklung",
    detail: "12 Nuten · 10 Pole · Zweischicht",
    slots: 12,
    polePairs: 5,
    layers: 2,
    coilSpan: "auto",
  },
  {
    name: "9-Nuten-Wicklung",
    detail: "9 Nuten · 8 Pole · Zweischicht",
    slots: 9,
    polePairs: 4,
    layers: 2,
    coilSpan: "auto",
  },
];
const INITIAL = { slots: 12, polePairs: 1, layers: 1, coilSpan: "auto" };
const nf = (number, digits = 2) =>
  Number(number).toLocaleString("de-DE", {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits,
  });
const degree = (angle) => `${nf(((angle % 360) + 360) % 360, 1)}°`;

function Icon({ name, size = 20, ...props }) {
  const paths = {
    arrow: (
      <>
        <path d="M5 12h14M13 6l6 6-6 6" />
      </>
    ),
    download: (
      <>
        <path d="M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4" />
      </>
    ),
    chevron: <path d="m9 5 7 7-7 7" />,
    check: <path d="m5 12 4 4L19 6" />,
    spark: (
      <>
        <path d="m12 3 2.8 6.2L21 12l-6.2 2.8L12 21l-2.8-6.2L3 12l6.2-2.8Z" />
        <path d="m20 2 .6 1.4L22 4l-1.4.6L20 6l-.6-1.4L18 4l1.4-.6Z" />
      </>
    ),
    info: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 11v6m0-10v.1" />
      </>
    ),
    reset: (
      <>
        <path d="M4 10a8 8 0 1 1 1 7M4 4v6h6" />
      </>
    ),
    grid: (
      <>
        <path d="M3 3h7v7H3zm11 0h7v7h-7zM3 14h7v7H3zm11 0h7v7h-7z" />
      </>
    ),
    wave: <path d="M2 12c3-16 7 16 10 0s7 16 10 0" />,
    coil: (
      <>
        <path d="M4 18V7a3 3 0 0 1 6 0v10a3 3 0 0 0 6 0V7a3 3 0 0 1 6 0v11M2 18h4M20 18h4" />
      </>
    ),
  };
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      {paths[name] || paths.info}
    </svg>
  );
}

function saveFile(name, content, type) {
  const url = URL.createObjectURL(new Blob([content], { type }));
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function exportCsv(result, layout) {
  const rows = [
    [
      "Nut",
      "Lage",
      "Strang",
      "Vorzeichen",
      "Zone",
      "Elektrischer Winkel (Grad)",
    ],
  ];
  for (const slot of result.slotLayers ||
    result.slotAssignments.map((s) => ({ ...s, layer: 1 }))) {
    rows.push([
      slot.slot,
      slot.layer,
      slot.phase,
      slot.sign,
      slot.zone,
      Number(slot.angleDeg).toFixed(6),
    ]);
  }
  rows.push(
    [],
    [
      "Spule",
      "Strang",
      "Plus-Nut",
      "Minus-Nut",
      "Plus-Lage",
      "Minus-Lage",
      "Spulenweite",
    ],
  );
  (layout.orderedCoils || result.coils).forEach((c) =>
    rows.push([
      c.id,
      c.phase,
      c.positiveSlot,
      c.negativeSlot,
      c.positiveLayer,
      c.negativeLayer,
      c.span,
    ]),
  );
  rows.push(
    [],
    ["Abwicklung beginnt in Nut", layout.startSlot],
    [],
    ["Strang", "Serienfolge"],
  );
  (layout.topology?.phaseChains || []).forEach((chain) => {
    const start = layout.terminals.find(
      (terminal) => terminal.phase === chain.phase && terminal.type === "start",
    );
    const end = layout.terminals.find(
      (terminal) => terminal.phase === chain.phase && terminal.type === "end",
    );
    rows.push([
      chain.phase,
      [start?.label, ...chain.coilIds, end?.label].filter(Boolean).join(" → "),
    ]);
  });
  rows.push(
    [],
    [
      "Strang",
      "Von Spule (Minus)",
      "Nach Spule (Plus)",
      "Von-Knoten",
      "Nach-Knoten",
    ],
  );
  (layout.seriesConnections || []).forEach((connection) =>
    rows.push([
      connection.phase,
      connection.fromCoilId,
      connection.toCoilId,
      connection.fromNode,
      connection.toNode,
    ]),
  );
  rows.push([], ["Klemme", "Strang", "Spule", "Nut", "Lage", "Knoten"]);
  (layout.terminals || []).forEach((terminal) =>
    rows.push([
      terminal.label,
      terminal.phase,
      terminal.coilId,
      terminal.slot,
      terminal.layer,
      terminal.nodeId,
    ]),
  );
  saveFile(
    `wicklung-Q${result.slots}-p${result.polePairs}.csv`,
    "\uFEFF" + rows.map((r) => r.join(";")).join("\r\n"),
    "text/csv;charset=utf-8",
  );
}

function exportDiagram(result, onStatus) {
  const svgs = Array.from(
    document.querySelectorAll("[data-export-diagrams] svg.diagram-svg"),
  ).filter((svg) => !svg.closest("[hidden]"));
  if (!svgs.length) {
    onStatus("Bitte zuerst eine Ansicht mit Diagrammen öffnen.");
    return;
  }
  let y = 80;
  const content = svgs
    .map((svg) => {
      let label = "";
      if (svgs.length > 1 && svg.dataset.exportTitle) {
        label = `<text x="35" y="${y + 12}" fill="#344132" font-size="15" font-family="sans-serif">${escapeXml(svg.dataset.exportTitle)}</text>`;
        y += 28;
        if (svg.dataset.exportSubtitle) {
          label += `<text x="35" y="${y + 4}" fill="#66736c" font-size="11" font-family="sans-serif">${escapeXml(svg.dataset.exportSubtitle)}</text>`;
          y += 22;
        }
      }
      const node = svg.cloneNode(true);
      node.setAttribute("style", "font-family: sans-serif");
      const box = svg.viewBox.baseVal;
      const h =
        box.width && box.height
          ? Math.min(420, (1120 * box.height) / box.width)
          : 300;
      node.setAttribute("x", "35");
      node.setAttribute("y", String(y));
      node.setAttribute("width", "1130");
      node.setAttribute("height", String(h));
      y += h + 40;
      return label + new XMLSerializer().serializeToString(node);
    })
    .join("");
  function escapeXml(value) {
    return String(value).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&apos;",
        })[c],
    );
  }
  const heading =
    svgs.length === 1 && svgs[0].dataset.exportTitle
      ? `Wicklungsatelier · ${svgs[0].dataset.exportTitle}`
      : `Wicklungsatelier · Q=${result.slots}, p=${result.polePairs}, ${result.layers} Lage(n), y=${result.coilSpan}`;
  const caption =
    svgs.length === 1 && svgs[0].dataset.exportSubtitle
      ? svgs[0].dataset.exportSubtitle
      : `Idealisierter dreiphasiger Wicklungsentwurf · kw1=${Number(result.metrics.kw).toFixed(5)}`;
  const documentSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="${y + 30}" viewBox="0 0 1200 ${y + 30}"><rect width="100%" height="100%" fill="#fff"/><text x="35" y="38" fill="#24312b" font-size="22" font-family="sans-serif">${escapeXml(heading)}</text><text x="35" y="61" fill="#66736c" font-size="13" font-family="sans-serif">${escapeXml(caption)}</text>${content}</svg>`;
  saveFile(
    `wicklungsdiagramme-Q${result.slots}-p${result.polePairs}.svg`,
    documentSvg,
    "image/svg+xml",
  );
  onStatus("Die sichtbaren Diagramme wurden als SVG exportiert.");
}

function StepTitle({ number, title, subtitle, children }) {
  return (
    <div className="card-heading">
      <div className="card-title-group">
        <span className="step-number">{number}</span>
        <div>
          <h2>{title}</h2>
          {subtitle && <p>{subtitle}</p>}
        </div>
      </div>
      {children}
    </div>
  );
}

function PhaseLegend({ selected, onSelect, compact = false }) {
  return (
    <div
      className={`phase-legend ${compact ? "compact" : ""}`}
      aria-label="Strangfilter"
    >
      <button
        className={selected === null ? "active" : ""}
        onClick={() => onSelect(null)}
        aria-pressed={selected === null}
      >
        Alle
      </button>
      {["A", "B", "C"].map((phase) => (
        <button
          key={phase}
          style={{ "--phase-color": COLORS[phase] }}
          className={selected === phase ? "active" : ""}
          aria-pressed={selected === phase}
          onClick={() => onSelect(selected === phase ? null : phase)}
        >
          <i />
          {compact ? phase : `Strang ${phase}`}
        </button>
      ))}
    </div>
  );
}

function SlotDetail({ result, selectedSlot, setSelectedSlot }) {
  const slot = result.slotAssignments.find((s) => s.slot === selectedSlot);
  return (
    <div className="slot-detail">
      <div>
        <span className="detail-label">
          {slot ? "Ausgewählte Nut" : "Den Stern erkunden"}
        </span>
        <strong>
          {slot ? (
            <>
              Nut {slot.slot}
              <span
                className="zone-tag"
                style={{
                  color: COLORS[slot.phase],
                  background: `${COLORS[slot.phase]}12`,
                }}
              >
                {slot.zone}
              </span>
            </>
          ) : (
            "Eine Nut anklicken"
          )}
        </strong>
      </div>
      {slot ? (
        <>
          <div>
            <span className="detail-label">Elektrischer Winkel</span>
            <strong>{degree(slot.angleDeg)}</strong>
          </div>
          <button
            className="text-button"
            onClick={() => setSelectedSlot(null)}
            aria-label="Nutauswahl zurücksetzen"
          >
            Zurücksetzen
          </button>
        </>
      ) : (
        <span className="detail-hint">
          Die Auswahl verbindet Stern,
          <br />
          Zonenplan und Wickelschema.
        </span>
      )}
    </div>
  );
}

function Method({ result }) {
  const alpha = nf(result.alphaDeg, 2);
  return (
    <div className="method-layout">
      <article className="panel method-card">
        <StepTitle
          number="01"
          title="Nutenspannungsstern"
          subtitle="Von der mechanischen zur elektrischen Lage"
        />
        <p>
          Jede Nut erhält einen Einheitsvektor. Die Polpaarzahl vervielfacht den
          mechanischen Winkel zum elektrischen Winkel.
        </p>
        <div className="formula">
          α<sub>el</sub> = 360° · p / Q = <b>{alpha}°</b>
        </div>
        <p>
          Für Nut n gilt θ<sub>n</sub> = (n − 1) · α<sub>el</sub>. Mehrere
          Nutvektoren können deshalb dieselbe elektrische Richtung haben.
        </p>
      </article>
      <article className="panel method-card">
        <StepTitle
          number="02"
          title="Zonung"
          subtitle="Sechs Zonen für drei Stränge"
        />
        <p>
          Der Spannungsstern wird in sechs 60°-Zonen aufgeteilt. Die natürliche
          Zonenfolge lautet:
        </p>
        <div className="zone-sequence">
          {["+A", "−C", "+B", "−A", "+C", "−B"].map((v) => (
            <span
              key={v}
              style={{ color: COLORS[v[1]], background: `${COLORS[v[1]]}12` }}
            >
              {v}
            </span>
          ))}
        </div>
        <div className="formula">
          q = Q / (2 · p · 3) = <b>{nf(result.q, 3)}</b>
        </div>
        <p>
          Q ist die Nutenzahl, q die Lochzahl. Eine nicht ganzzahlige Lochzahl
          kennzeichnet eine Bruchlochwicklung.
        </p>
      </article>
      <article className="panel method-card">
        <StepTitle
          number="03"
          title="Strangspannungsstern"
          subtitle="Vorzeichenrichtig vektoriell addieren"
        />
        <p>
          Die Nutvektoren der positiven Zone werden addiert. Die Vektoren der
          negativen Zone werden wegen der umgekehrten Leiterorientierung um 180°
          gedreht und anschließend addiert.
        </p>
        <div className="formula">
          U<sub>A</sub> ∝ ∑ s<sub>n</sub> · e<sup>jθₙ</sup>
        </div>
        <p>
          Der Grundwellen-Wicklungsfaktor k<sub>w1</sub> ist der Betrag dieser
          Summe, geteilt durch die Zahl der aktiven Spulenseiten des Strangs.
          Bei Zweischicht werden beide Lagen berücksichtigt.
        </p>
      </article>
      <article className="panel method-card">
        <StepTitle
          number="04"
          title="Spulen bilden"
          subtitle="Leiter in den Nuten, Eisen in den Zähnen"
        />
        <p>
          In einer Einschichtwicklung belegt jede Spulenseite genau eine Nut. In
          einer Zweischichtwicklung liegen je zwei Spulenseiten in verschiedenen
          Lagen einer Nut.
        </p>
        <div className="formula">
          τ<sub>p</sub> = Q / (2 · p) = <b>{nf(result.polePitch, 2)} Nuten</b>
        </div>
        <p>
          Jede gezeichnete Spule verbindet eine positive mit einer negativen
          Seite desselben Strangs. Die blauen Flächen sind die Zähne; Leiter
          liegen in den weißen Zwischenräumen.
        </p>
      </article>
      <article className="panel method-card method-wide">
        <div className="method-note-icon">
          <Icon name="spark" size={25} />
        </div>
        <div>
          <h2>Was bedeutet hier „optimal“?</h2>
          <p>
            Die automatische Auswahl vergleicht realisierbare Spulenweiten
            innerhalb der festen 60°-Zonung. Symmetrische Stränge und ein hoher
            Grundwellen-Wicklungsfaktor haben Vorrang; bei gleichem Faktor
            gewinnt die kürzere Weite.
          </p>
          <div className="method-scope">
            <b>Untersuchter Bereich</b>
            <p>{result.method.candidateScope}</p>
            <p>{result.method.selection}</p>
          </div>
          <p>{result.method.note}</p>
          <p className="muted">
            {result.method.limitation} Eine vollständige Maschinenauslegung
            erfordert zusätzlich Nutgeometrie, Windungszahl, Drahtquerschnitt,
            Verschaltung und thermische Randbedingungen.
          </p>
        </div>
      </article>
    </div>
  );
}

export default function App() {
  const [form, setForm] = useState(INITIAL);
  const [result, setResult] = useState(() => computeWinding(INITIAL));
  const [error, setError] = useState("");
  const [activeTab, setActiveTab] = useState("analyse");
  const [selectedSlot, setSelectedSlot] = useState(null);
  const [selectedPhase, setSelectedPhase] = useState(null);
  const [connectionMode, setConnectionMode] = useState("series");
  const [windingStartSlot, setWindingStartSlot] = useState("auto");
  const windingLayout = useMemo(
    () =>
      buildWindingLayout(result, {
        startSlot: windingStartSlot,
        connectionMode: "series",
      }),
    [result, windingStartSlot],
  );
  const [spectrumExport, setSpectrumExport] = useState(null);
  const handleSpectrumChange = useCallback(
    (data) => {
      setSpectrumExport({ winding: result, data });
    },
    [result],
  );
  const [inductanceExport, setInductanceExport] = useState(null);
  const handleInductanceChange = useCallback(
    (data) => {
      setInductanceExport({ winding: result, data });
    },
    [result],
  );
  const [status, setStatus] = useState("");
  const [exportOpen, setExportOpen] = useState(false);
  const changed =
    ["slots", "polePairs", "layers"].some(
      (key) => Number(form[key]) !== Number(result[key]),
    ) || String(form.coilSpan) !== String(result.requestedCoilSpan);

  function calculate(next = form) {
    try {
      const answer = computeWinding({
        slots: Number(next.slots),
        polePairs: Number(next.polePairs),
        layers: Number(next.layers),
        coilSpan: next.coilSpan === "auto" ? "auto" : Number(next.coilSpan),
      });
      setResult(answer);
      setWindingStartSlot("auto");
      setError("");
      setSelectedSlot(null);
      setSelectedPhase(null);
      setStatus(
        answer.valid
          ? "Wicklung neu berechnet."
          : "Zonung berechnet. Bitte Hinweise zur Realisierbarkeit beachten.",
      );
    } catch (err) {
      setError(err.message);
      setStatus("");
    }
  }

  function preset(p) {
    const next = {
      slots: p.slots,
      polePairs: p.polePairs,
      layers: p.layers,
      coilSpan: p.coilSpan,
    };
    setForm(next);
    calculate(next);
  }

  return (
    <>
      <header className="site-header">
        <a className="brand" href="#" aria-label="Wicklungsatelier Start">
          <span className="brand-mark">
            <Icon name="coil" size={25} />
          </span>
          <span>
            Wicklungs<span className="brand-light">atelier</span>
            <small>ELEKTRISCHE MASCHINEN · INTERAKTIV</small>
          </span>
        </a>
        <div className="header-right">
          <span className="workspace-label">
            <i />
            Entwurfsraum
          </span>
          <button
            className="quiet-button"
            onClick={() => {
              setActiveTab("methode");
              document
                .getElementById("workspace")
                ?.scrollIntoView({ behavior: "smooth", block: "start" });
            }}
          >
            <Icon name="info" size={17} />
            So funktioniert’s
          </button>
        </div>
      </header>

      <main className="page-shell">
        <section className="hero">
          <div>
            <div className="eyebrow">
              <span />
              WICKLUNGEN SICHTBAR MACHEN
            </div>
            <h1>
              Von der Nut<span className="serif-italic"> zur Wicklung.</span>
            </h1>
            <p>
              Maschine definieren. Spannungssterne verstehen.
              <br className="mobile-break" /> Einen nachvollziehbaren
              Wicklungsentwurf entwickeln.
            </p>
          </div>
          <div className="hero-stamp">
            <svg viewBox="0 0 112 86" aria-hidden="true">
              <g fill="none" strokeWidth="1.5">
                {[0, 1, 2].map((i) => (
                  <g
                    key={i}
                    stroke={Object.values(COLORS)[i]}
                    transform={`translate(${i * 17} 0)`}
                  >
                    <path d="M14 62V26L38 13l24 13v36L38 74Z" />
                    <path d="M14 26 38 39l24-13M38 39v35" opacity=".45" />
                  </g>
                ))}
              </g>
            </svg>
            <span>
              Drei Stränge.
              <br />
              Ein klares Schema.
            </span>
          </div>
        </section>

        <div className="workspace" id="workspace">
          <aside className="sidebar">
            <section className="panel config-panel">
              <div className="config-title">
                <span className="tiny-icon">
                  <Icon name="grid" size={18} />
                </span>
                <h2>Maschine definieren</h2>
                <span className="subtle-index">01</span>
              </div>
              <form
                onSubmit={(event) => {
                  event.preventDefault();
                  calculate();
                }}
              >
                <div className="field-row">
                  <label htmlFor="slots">
                    Nutenzahl <span>Q</span>
                  </label>
                  <div className="number-control">
                    <input
                      id="slots"
                      name="slots"
                      type="number"
                      min="6"
                      max="120"
                      step="1"
                      required
                      value={form.slots}
                      onChange={(e) =>
                        setForm({ ...form, slots: e.target.value })
                      }
                    />
                    <span>Nuten</span>
                  </div>
                  <small>Gesamtzahl der Nuten im Stator</small>
                </div>
                <div className="field-row">
                  <label htmlFor="polePairs">
                    Polpaarzahl <span>p</span>
                  </label>
                  <div className="number-control">
                    <input
                      id="polePairs"
                      name="polePairs"
                      type="number"
                      min="1"
                      max="60"
                      step="1"
                      required
                      value={form.polePairs}
                      onChange={(e) =>
                        setForm({ ...form, polePairs: e.target.value })
                      }
                    />
                    <span>{Number(form.polePairs) * 2 || "–"} Pole</span>
                  </div>
                </div>
                <div className="field-row">
                  <label>Wicklungsart</label>
                  <div
                    className="segmented"
                    role="group"
                    aria-label="Wicklungsart"
                  >
                    {[1, 2].map((layer) => (
                      <button
                        key={layer}
                        type="button"
                        className={
                          Number(form.layers) === layer ? "selected" : ""
                        }
                        aria-pressed={Number(form.layers) === layer}
                        onClick={() => setForm({ ...form, layers: layer })}
                      >
                        {layer === 1 ? "Einschicht" : "Zweischicht"}
                      </button>
                    ))}
                  </div>
                </div>
                <div className="field-row">
                  <label htmlFor="coilSpan">
                    Spulenweite <span>y</span>
                  </label>
                  <select
                    id="coilSpan"
                    value={form.coilSpan}
                    onChange={(e) =>
                      setForm({ ...form, coilSpan: e.target.value })
                    }
                  >
                    <option value="auto">Automatisch auswählen</option>
                    {Array.from(
                      {
                        length: Math.min(
                          60,
                          Math.max(1, Math.floor(Number(form.slots) / 2)),
                        ),
                      },
                      (_, i) => (
                        <option key={i + 1} value={i + 1}>
                          {i + 1} {i === 0 ? "Nut" : "Nuten"}
                          {i + 1 ===
                          Number(form.slots) / (2 * Number(form.polePairs))
                            ? " · volle Polteilung"
                            : ""}
                        </option>
                      ),
                    )}
                  </select>
                </div>
                <div className="machine-note">
                  <Icon name="wave" size={19} />
                  <span>3 Stränge · symmetrisches Drehstromsystem</span>
                </div>
                <button type="submit" className="primary-button">
                  <span>Wicklung berechnen</span>
                  <Icon name="arrow" size={19} />
                </button>
                {error && (
                  <div role="alert" className="form-error">
                    {error}
                  </div>
                )}
                {changed && !error && (
                  <p className="pending-note">
                    Parameter geändert · neu berechnen
                  </p>
                )}
              </form>
            </section>

            <section className="examples-panel">
              <div className="section-kicker">MIT EINEM BEISPIEL STARTEN</div>
              {PRESETS.map((p) => (
                <button
                  key={p.name}
                  className={`example-button ${result.slots === p.slots && result.polePairs === p.polePairs && result.layers === p.layers && (p.coilSpan === "auto" || result.coilSpan === p.coilSpan) ? "is-current" : ""}`}
                  onClick={() => preset(p)}
                >
                  <span className="example-orbit">
                    <svg viewBox="0 0 30 30" aria-hidden="true">
                      <circle
                        cx="15"
                        cy="15"
                        r="10"
                        fill="none"
                        stroke="currentColor"
                        opacity=".3"
                      />
                      {Array.from({ length: 6 }, (_, i) => (
                        <path
                          key={i}
                          d="M15 15V5"
                          stroke="currentColor"
                          transform={`rotate(${i * 60} 15 15)`}
                        />
                      ))}
                      <circle cx="15" cy="15" r="2" fill="currentColor" />
                    </svg>
                  </span>
                  <span>
                    <strong>{p.name}</strong>
                    <small>{p.detail}</small>
                  </span>
                  <Icon name="chevron" size={15} />
                </button>
              ))}
            </section>
            <div className="sidebar-note">
              <Icon name="info" size={17} />
              <p>
                Von den Vorlesungsfolien zum interaktiven Modell. Sterne:
                <b> elektrische Winkel</b>. Spektrum: mechanische Raumordnung.
              </p>
            </div>
          </aside>

          <section className="results-area" aria-label="Berechnungsergebnisse">
            <div className="results-toolbar">
              <div className="tabs" role="tablist" aria-label="Ergebnisansicht">
                {[
                  { id: "analyse", label: "Analyse" },
                  { id: "wicklung", label: "Wickelschema" },
                  { id: "spektrum", label: "Spektrum" },
                  { id: "induktivitaet", label: "Induktivität" },
                  { id: "methode", label: "Berechnungsweg" },
                ].map((tab) => (
                  <button
                    id={`tab-${tab.id}`}
                    role="tab"
                    aria-selected={activeTab === tab.id}
                    aria-controls="result-view"
                    key={tab.id}
                    className={activeTab === tab.id ? "active" : ""}
                    onClick={() => setActiveTab(tab.id)}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>
              <div className="export-control">
                <button
                  className="export-button"
                  aria-expanded={exportOpen}
                  onClick={() => setExportOpen(!exportOpen)}
                >
                  <Icon name="download" size={17} />
                  <span>Exportieren</span>
                  <span className="down-caret">⌄</span>
                </button>
                {exportOpen && (
                  <>
                    <button
                      className="menu-dismiss"
                      aria-label="Exportmenü schließen"
                      onClick={() => setExportOpen(false)}
                    />
                    <div className="export-menu">
                      <button
                        onClick={() => {
                          exportCsv(result, windingLayout);
                          setExportOpen(false);
                          setStatus(
                            "Nutbelegung und Spulenliste als CSV exportiert.",
                          );
                        }}
                      >
                        Nutbelegung & Spulen · CSV
                      </button>
                      <button
                        onClick={() => {
                          exportDiagram(result, setStatus);
                          setExportOpen(false);
                        }}
                      >
                        Sichtbare Diagramme · SVG
                      </button>
                      <button
                        onClick={() => {
                          saveFile(
                            `wicklung-Q${result.slots}-p${result.polePairs}.json`,
                            JSON.stringify(
                              {
                                ...result,
                                windingLayout: {
                                  ...windingLayout,
                                  displayMode: connectionMode,
                                  automaticStart: windingStartSlot === "auto",
                                },
                                spectrum:
                                  spectrumExport?.winding === result
                                    ? spectrumExport.data
                                    : computeSpectrum(result),
                                inductance:
                                  inductanceExport?.winding === result
                                    ? inductanceExport.data
                                    : null,
                              },
                              null,
                              2,
                            ),
                            "application/json",
                          );
                          setExportOpen(false);
                          setStatus("Berechnung als JSON exportiert.");
                        }}
                      >
                        Gesamte Berechnung · JSON
                      </button>
                    </div>
                  </>
                )}
              </div>
            </div>

            <div className="calculation-heading">
              <div>
                <h2>
                  Dein Wicklungsentwurf
                  <span
                    className={`state-tag ${result.valid ? "" : "warning"}`}
                  >
                    <i />
                    {result.valid ? "Realisierbar im Modell" : "Zonung prüfen"}
                  </span>
                </h2>
                <p>
                  Q = {result.slots}
                  <span>·</span>p = {result.polePairs}
                  <span>·</span>
                  {result.layers === 1
                    ? "Einschichtwicklung"
                    : "Zweischichtwicklung"}
                  <span>·</span>3 Stränge
                </p>
              </div>
              <span className="calculation-symbol">Q / 2p</span>
            </div>

            <div className="metrics-grid">
              <div className="metric">
                <span>
                  Lochzahl <i>q</i>
                </span>
                <strong>
                  {nf(result.q, Number.isInteger(result.q) ? 0 : 3)}
                  <small>
                    {Number.isInteger(result.q) ? "Ganzloch" : "Bruchloch"}
                  </small>
                </strong>
              </div>
              <div className="metric">
                <span>
                  Wicklungsfaktor{" "}
                  <i>
                    k<sub>w1</sub>
                  </i>
                </span>
                <strong>
                  {result.valid ? nf(result.metrics.kw, 4) : "—"}
                  <small>Grundwelle</small>
                </strong>
              </div>
              <div className="metric">
                <span>
                  Nutwinkel{" "}
                  <i>
                    α<sub>el</sub>
                  </i>
                </span>
                <strong>
                  {nf(result.alphaDeg, 1)}
                  <em>°</em>
                  <small>elektrisch</small>
                </strong>
              </div>
              <div className="metric">
                <span>
                  Spulenweite <i>y</i>
                </span>
                <strong>
                  {result.valid ? result.coilSpan : "—"}
                  <small>
                    {result.valid
                      ? `${result.metrics.coilCount} Spulen`
                      : "keine Paarung"}
                  </small>
                </strong>
              </div>
            </div>

            <div className="selection-summary">
              <Icon
                name={result.requestedCoilSpan === "auto" ? "spark" : "info"}
                size={13}
              />
              <span>
                {result.requestedCoilSpan === "auto"
                  ? `Automatik · ${result.metrics.candidateCount} Weiten geprüft · ${result.method.candidateScope.split(";")[0]}`
                  : `Manuelle Spulenweite y = ${result.coilSpan} · vollständige Paarung und Symmetrie geprüft`}
              </span>
              <button onClick={() => setActiveTab("methode")}>
                Kriterien
                <Icon name="arrow" size={12} />
              </button>
            </div>
            {!!result.warnings?.length && (
              <div className={`result-notice ${result.valid ? "" : "invalid"}`}>
                <Icon name="info" size={19} />
                <div>
                  {result.warnings.map((warning, i) => (
                    <p key={i}>
                      {typeof warning === "string" ? warning : warning.message}
                    </p>
                  ))}
                </div>
              </div>
            )}

            <div
              id="result-view"
              role="tabpanel"
              aria-labelledby={`tab-${activeTab}`}
              data-export-diagrams
            >
              {activeTab === "analyse" && (
                <>
                  <div className="star-grid">
                    <article className="panel star-card">
                      <StepTitle
                        number="01"
                        title="Nutenspannungsstern"
                        subtitle="Jede Nut ein Vektor. Jede Farbe ein Strang."
                      >
                        <span className="card-meta">
                          α = {nf(result.alphaDeg, 0)}°
                        </span>
                      </StepTitle>
                      <SlotStar
                        result={result}
                        selectedSlot={selectedSlot}
                        onSelectSlot={setSelectedSlot}
                      />
                      <SlotDetail
                        result={result}
                        selectedSlot={selectedSlot}
                        setSelectedSlot={setSelectedSlot}
                      />
                    </article>
                    <article className="panel star-card">
                      <StepTitle
                        number="03"
                        title="Strangspannungsstern"
                        subtitle="Die vorzeichenrichtige Summe je Strang."
                      />
                      <PhaseStar
                        result={result}
                        selectedPhase={selectedPhase}
                        onSelectPhase={setSelectedPhase}
                      />
                      <div className="phase-summary">
                        {result.phases.map((phase) => (
                          <button
                            key={phase.phase}
                            onClick={() =>
                              setSelectedPhase(
                                selectedPhase === phase.phase
                                  ? null
                                  : phase.phase,
                              )
                            }
                            aria-pressed={selectedPhase === phase.phase}
                            className={
                              selectedPhase === phase.phase ? "chosen" : ""
                            }
                          >
                            <span style={{ color: COLORS[phase.phase] }}>
                              <i style={{ background: COLORS[phase.phase] }} />
                              {phase.phase}
                            </span>
                            <strong>{nf(phase.kw, 4)}</strong>
                            <small>{degree(phase.angleDeg)}</small>
                          </button>
                        ))}
                      </div>
                    </article>
                  </div>
                  <article className="panel zone-card">
                    <StepTitle
                      number="02"
                      title="Zonenplan"
                      subtitle={
                        result.layers === 1
                          ? "Spulenseiten nach Strang und Orientierung zugeordnet."
                          : "Belegung beider Lagen aus den tatsächlichen Spulenseiten."
                      }
                    >
                      <PhaseLegend
                        selected={selectedPhase}
                        onSelect={setSelectedPhase}
                        compact
                      />
                    </StepTitle>
                    <ZonePlan
                      result={result}
                      selectedSlot={selectedSlot}
                      onSelectSlot={setSelectedSlot}
                      selectedPhase={selectedPhase}
                    />
                    <div className="card-footnote">
                      <span>Natürliche Zonenfolge</span>
                      <b>
                        +A<span>→</span>−C<span>→</span>+B<span>→</span>−A
                        <span>→</span>+C<span>→</span>−B
                      </b>
                      <span>60° je Zone</span>
                    </div>
                  </article>
                  <article className="panel winding-card">
                    <StepTitle
                      number="04"
                      title="Wickelschema"
                      subtitle="Abwicklung des Stators · Spulengruppen und Stranganschlüsse"
                    >
                      <button
                        className="text-button"
                        onClick={() => setActiveTab("wicklung")}
                      >
                        Im Detail ansehen
                        <Icon name="arrow" size={16} />
                      </button>
                    </StepTitle>
                    <WindingDiagram
                      result={result}
                      connectionMode={connectionMode}
                      startSlot={windingStartSlot}
                      selectedPhase={selectedPhase}
                      selectedSlot={selectedSlot}
                      onSelectSlot={setSelectedSlot}
                    />
                    <div className="winding-caption">
                      <div>
                        <span className="tooth-swatch" />
                        Zahn
                        <span className="slot-swatch" />
                        Nut mit Spulenseite
                      </div>
                      <span>
                        y = {result.coilSpan} ·{" "}
                        {result.layers === 1 ? "eine Lage" : "zwei Lagen"} ·
                        Schnitt in Nut {windingLayout.startSlot ?? "—"}
                      </span>
                    </div>
                  </article>
                </>
              )}
              {activeTab === "wicklung" && (
                <>
                  <article className="panel winding-card detail-winding">
                    <StepTitle
                      number="04"
                      title="Wickelschema im Detail"
                      subtitle="Die farbigen Leiter verlaufen zwischen den blauen Zähnen."
                    >
                      <PhaseLegend
                        selected={selectedPhase}
                        onSelect={setSelectedPhase}
                      />
                    </StepTitle>
                    <div className="connection-toolbar">
                      <div
                        className="connection-switch"
                        role="group"
                        aria-label="Verschaltungsansicht"
                      >
                        <button
                          className={
                            connectionMode === "series" ? "active" : ""
                          }
                          aria-pressed={connectionMode === "series"}
                          onClick={() => setConnectionMode("series")}
                        >
                          Serienverschaltung
                        </button>
                        <button
                          className={
                            connectionMode === "individual" ? "active" : ""
                          }
                          aria-pressed={connectionMode === "individual"}
                          onClick={() => setConnectionMode("individual")}
                        >
                          Einzelne Spulen
                        </button>
                      </div>
                      <span>
                        {connectionMode === "series"
                          ? windingLayout.valid
                            ? "3 Stränge · 6 Klemmen"
                            : "Keine gültige Verschaltung"
                          : "Spulen unabhängig betrachten"}
                      </span>
                    </div>
                    <div className="winding-cut-controls">
                      <label htmlFor="winding-start-slot">
                        Abwicklung beginnen bei
                      </label>
                      <select
                        id="winding-start-slot"
                        value={windingStartSlot}
                        disabled={!windingLayout.valid}
                        onChange={(event) =>
                          setWindingStartSlot(
                            event.target.value === "auto"
                              ? "auto"
                              : Number(event.target.value),
                          )
                        }
                      >
                        <option value="auto">
                          {windingLayout.valid
                            ? `Automatisch · Nut ${windingLayout.startSlot}`
                            : "Kein gültiges Wickelschema"}
                        </option>
                        {Array.from({ length: result.slots }, (_, index) => (
                          <option key={index + 1} value={index + 1}>
                            Nut {index + 1}
                          </option>
                        ))}
                      </select>
                      <span>
                        Nut am Anfang und Ende ist dieselbe Nut am
                        Umfangsschnitt.
                      </span>
                    </div>
                    <WindingDiagram
                      result={result}
                      connectionMode={connectionMode}
                      startSlot={windingStartSlot}
                      selectedPhase={selectedPhase}
                      selectedSlot={selectedSlot}
                      onSelectSlot={setSelectedSlot}
                    />
                    <div className="winding-caption">
                      <div>
                        <span className="tooth-swatch" />
                        Zahn
                        <span className="slot-swatch" />
                        Nut mit Spulenseite
                      </div>
                      <span>
                        {connectionMode === "series"
                          ? "Additive Reihenschaltung · Kreuzungen ohne Punkt sind nicht verbunden"
                          : "Einzelne Spulen · Umfang periodisch"}
                      </span>
                    </div>
                    {connectionMode === "series" && (
                      <p className="panel-note">
                        A → U1/U2 · B → V1/V2 · C → W1/W2. Alle Spulen eines
                        Strangs sind gleichsinnig in geometrischer Gruppenfolge
                        verbunden. Die Pfeile beziehen sich auf diese
                        Anschlussrichtung. Vertauschte Stranganschlüsse kehren
                        sämtliche Pfeile um. Stern- oder Dreieckbrücken sind
                        nicht vorgegeben.
                      </p>
                    )}
                  </article>
                  {windingLayout.valid && (
                    <article className="panel winding-chains-panel">
                      <StepTitle
                        number="05"
                        title="Strangverbindungen"
                        subtitle="Jede Zeile ist ein durchgehender Serienpfad mit zwei offenen Klemmen."
                      />
                      <div className="winding-chain-list">
                        {(windingLayout.topology?.phaseChains || [])
                          .filter(
                            (chain) =>
                              !selectedPhase || chain.phase === selectedPhase,
                          )
                          .map((chain) => {
                            const start = windingLayout.terminals.find(
                              (terminal) =>
                                terminal.phase === chain.phase &&
                                terminal.type === "start",
                            );
                            const end = windingLayout.terminals.find(
                              (terminal) =>
                                terminal.phase === chain.phase &&
                                terminal.type === "end",
                            );
                            return (
                              <div
                                key={chain.phase}
                                className="winding-chain"
                                style={{ "--phase-color": COLORS[chain.phase] }}
                              >
                                <b>{chain.phase}</b>
                                <span>
                                  {start?.label} → {chain.coilIds.join(" → ")} →{" "}
                                  {end?.label}
                                </span>
                              </div>
                            );
                          })}
                      </div>
                    </article>
                  )}
                  <article className="panel">
                    <StepTitle
                      number="05"
                      title="Spulen & Nutbelegung"
                      subtitle="Spulen in der gezeichneten Serienfolge · Plus/Minus bezeichnet die elektrische Orientierung."
                    >
                      <span className="card-meta">
                        {result.coils.length} Spulen
                      </span>
                    </StepTitle>
                    <div className="table-scroll">
                      <table>
                        <thead>
                          <tr>
                            <th>Spule</th>
                            <th>Strang</th>
                            <th>Plus-Seite</th>
                            <th>Minus-Seite</th>
                            <th>Spulenweite</th>
                          </tr>
                        </thead>
                        <tbody>
                          {(windingLayout.orderedCoils || result.coils)
                            .filter(
                              (c) =>
                                !selectedPhase || c.phase === selectedPhase,
                            )
                            .map((c) => (
                              <tr
                                key={c.id}
                                onClick={() => setSelectedSlot(c.positiveSlot)}
                              >
                                <td>{c.id}</td>
                                <td>
                                  <span
                                    className="table-phase"
                                    style={{
                                      color: COLORS[c.phase],
                                      background: `${COLORS[c.phase]}12`,
                                    }}
                                  >
                                    {c.phase}
                                  </span>
                                </td>
                                <td>
                                  Nut {c.positiveSlot}
                                  {result.layers === 2 && (
                                    <small> · Lage {c.positiveLayer}</small>
                                  )}
                                </td>
                                <td>
                                  Nut {c.negativeSlot}
                                  {result.layers === 2 && (
                                    <small> · Lage {c.negativeLayer}</small>
                                  )}
                                </td>
                                <td>y = {c.span}</td>
                              </tr>
                            ))}
                        </tbody>
                      </table>
                      {!result.coils.length && (
                        <p className="empty-message">
                          Für diese Kombination gibt es im gewählten Modell
                          keine gültige Spulenpaarung. Die Hinweise oberhalb
                          erklären den Grund.
                        </p>
                      )}
                    </div>
                  </article>
                  <article className="panel harmonic-panel">
                    <StepTitle
                      number="06"
                      title="Wicklungsfaktoren der Raumharmonischen"
                      subtitle="Normierte geometrische Vektorsummen · kein Spektrum einer konkreten Maschine"
                    />
                    <div className="harmonic-bars">
                      {result.harmonics.map((h) => (
                        <div className="harmonic-item" key={h.order}>
                          <span>ν = {h.order}</span>
                          <div>
                            <i
                              style={{
                                width: `${Math.min(100, Math.max(0, h.factor * 100))}%`,
                              }}
                            />
                          </div>
                          <strong>{nf(h.factor, 4)}</strong>
                        </div>
                      ))}
                    </div>
                    <p className="panel-note">
                      Ein großer Grundwellenfaktor ist erwünscht. Die Wirkung
                      höherer Raumharmonischer hängt auch von Erregung,
                      Verschaltung und Maschinengeometrie ab. Diese Faktoren
                      enthalten noch keinen 1/k-Faktor.
                      <button
                        className="spectrum-link"
                        onClick={() => setActiveTab("spektrum")}
                      >
                        Zum Fourier-Spektrum <Icon name="arrow" size={14} />
                      </button>
                    </p>
                  </article>
                </>
              )}
              {activeTab === "spektrum" && (
                <SpectrumPanel
                  result={result}
                  onDataChange={handleSpectrumChange}
                />
              )}
              <div hidden={activeTab !== "induktivitaet"}>
                <InductancePanel
                  result={result}
                  onDataChange={handleInductanceChange}
                />
              </div>
              {activeTab === "methode" && (
                <>
                  <Method result={result} />
                  <article className="panel spectrum-method-note">
                    <StepTitle
                      number="05"
                      title="Vom Wicklungsfaktor zum Raumspektrum"
                      subtitle="Fourier-Koeffizienten der idealisierten Wicklungsfunktion"
                    />
                    <div>
                      <p>
                        Für die mechanische Nutlage φₙ = 2π(n − 1)/Q wird zuerst
                        Dₖ = Σ sₙ · exp(−j k φₙ) berechnet. Der
                        Fourier-Koeffizient lautet Cₖ = Dₖ/(2 j k). Für eine
                        mittlere Spule wird zusätzlich durch die Spulenzahl des
                        Strangs geteilt.
                      </p>
                      <p>
                        Die Grundwelle liegt bei k = p. Ihr Betrag ist Nₛ · k
                        <sub>w1</sub>/p für die Strangsumme und k<sub>w1</sub>/p
                        je Spule. Ein einziger fester mechanischer Bezugswinkel
                        richtet die Grundwelle positiv reell aus; dieselbe
                        Winkelverschiebung gilt für alle Ordnungen. Re(Cₖ) kann
                        negativ sein, |Cₖ| ist immer nichtnegativ.
                      </p>
                      <p>
                        Die Darstellung beschreibt die räumliche
                        Wicklungsfunktion mit idealisierten Linienleitern.
                        Magnetische Flussdichten, Stromharmonische und
                        Feld-Drehrichtungen folgen daraus ohne Erregungs- und
                        Maschinenmodell noch nicht.
                      </p>
                      <button
                        className="spectrum-link"
                        onClick={() => setActiveTab("spektrum")}
                      >
                        Spektrum öffnen <Icon name="arrow" size={14} />
                      </button>
                    </div>
                  </article>
                </>
              )}
            </div>
            <div className="results-bottom">
              <span>
                <i
                  className={
                    result.balanced ? "balanced-dot" : "unbalanced-dot"
                  }
                />
                {result.balanced
                  ? "Strangresultanten symmetrisch"
                  : "Strangresultanten nicht symmetrisch"}
              </span>
              <span>Idealisierter Entwurf · gleiche Nutspannungen</span>
            </div>
            <div className="sr-only" role="status" aria-live="polite">
              {status}
            </div>
            {status && (
              <div className="status-message" key={status}>
                <Icon name="check" size={15} />
                {status}
              </div>
            )}
          </section>
        </div>
        <footer className="site-footer">
          <span>
            Wicklungsatelier<span className="footer-divider">/</span>Verstehen.
            Berechnen. Entwickeln.
          </span>
          <span>Dreiphasige Statorwicklungen · Entwurfsmodell v0.4</span>
        </footer>
      </main>
    </>
  );
}
