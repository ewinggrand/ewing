// Native exports and six stages of typeset mathematics. The equation catalogue
// is packaged as LaTeX + already-rendered MathML: no network or JS at runtime.

function text = ew_html_escape(text)
    text = strsubst(string(text), "&", "&amp;");
    text = strsubst(text, "<", "&lt;");
    text = strsubst(text, ">", "&gt;");
    text = strsubst(text, ascii(34), "&quot;");
endfunction

function value = ew_number(value)
    if isempty(value) then value = "nicht definiert"; return; end
    if isnan(value) | isinf(value) then value = "nicht definiert"; return; end
    if abs(value) < 1d-12 then value = "0"; else value = msprintf("%.10g", value); end
endfunction

function text = ew_complex_text(value)
    text = ew_number(value.real) + " + j (" + ew_number(value.imag) + ")";
endfunction

function [latex, mathml] = ew_formula(key)
    global EW_SCILAB_ROOT EW_EQUATIONS;
    if isempty(EW_EQUATIONS) then
        if isempty(EW_SCILAB_ROOT) then error("Zuerst loader.sce ausführen."); end
        EW_EQUATIONS = mgetl(EW_SCILAB_ROOT + "resources/equations.tsv");
    end
    for lineIndex = 1:size(EW_EQUATIONS, "*")
        line = EW_EQUATIONS(lineIndex);
        positions = strindex(line, ascii(9));
        if size(positions, "*") < 2 then continue; end
        if part(line, 1:positions(1)-1) == key then
            latex = part(line, positions(1)+1:positions(2)-1);
            mathml = part(line, positions(2)+1:length(line));
            return;
        end
    end
    error("Formel fehlt im Offline-Katalog: " + key);
endfunction

function [heading, keys, explanation] = ew_stage(stage)
    select stage
    case 1 then
        heading = "Spulenmittelachsen relativ zur Strangmittelachse";
        keys = ["axes-pitch", "axes-oriented", "coil-difference"];
        explanation = "Die mechanische Spulenmitte liegt auf dem tatsächlichen Spulenbogen. Die orientierte Feldachse berücksichtigt zusätzlich die Polung. Bei p Polpaaren ist die Grundwellenachse nur modulo 2*pi/p eindeutig. Die elektrische Grafik faltet p mechanische Perioden übereinander. Feldachsen und Nutenspannungsresultanten unterscheiden sich um 90 Grad elektrisch.";
    case 2 then
        heading = "Spulenfaktor, Gruppenfaktor und Strangfaktor";
        keys = ["coil-factor", "group-factor", "phase-factor", "phase-spectrum"];
        explanation = "S ist der dimensionslose Spulenfaktor. Der zusätzliche Faktor 1/k entsteht durch die räumliche Integration. Gruppenfaktoren sind komplexe Mittelwerte; ihre gewichtete Addition enthält die relative Achslage. Ein Produkt gemittelter Beträge wäre im Allgemeinen falsch. Nc bezeichnet die Spulenzahl, N(phi) dagegen die Windungsfunktion. k ist mechanisch; die Nutzgrundwelle liegt bei k=p. Bei Bruchlochwicklungen muss nu=k/p nicht ganzzahlig sein.";
    case 3 then
        heading = "Durchflutung und Luftspaltflussdichte";
        keys = ["winding-function", "mmf-field"];
        explanation = "Jede Plus-Seite erzeugt einen Sprung +1, jede Minus-Seite einen Sprung -1. Der Mittelwert der Wicklungsfunktion wird über den gesamten Statorumfang abgezogen. Die Durchflutung folgt aus den gleichzeitig bestromten Strängen. Im gleichmäßigen dünnen Luftspalt ist B=mu0*Theta/delta. An Linienleitern sind Sprünge idealisiert; die endliche Fourier-Reihe zeigt dort Gibbs-Schwingungen.";
    case 4 then
        heading = "Flussverkettung und Integration des Spulenpaares";
        keys = ["pair-field", "pair-integral", "pair-xi", "pair-linkage", "stator-linkage"];
        explanation = "Die Empfangsspule integriert das erzeugte Feld über ihre Fläche. Symmetrische Integrationsgrenzen beseitigen den ungeraden Sinusanteil. Die Integration liefert den zweiten Faktor 1/nu und den Spulenfaktor des Empfängers. Die Folienformel gilt für eine Periode 2*tau_p mit lokaler Ordnung nu. Für die ganze Maschine sind p identische Perioden zu addieren, falls diese Periodizität vorliegt. Die App integriert unmittelbar den ganzen Umfang und setzt diese Periodizität bei Bruchlochwicklungen nicht voraus.";
    case 5 then
        heading = "Selbstinduktivität und Gegeninduktivität";
        keys = ["pair-inductance", "self-inductance", "gram-inductance", "fourier-inductance"];
        explanation = "Bei Selbstinduktivität sind Quelle und Empfänger dieselbe Wicklung; das Produkt wird zum Quadrat. Im Stator steht die Empfangswicklung in der Zeile und der erzeugende Strom in der Spalte. Alle komplexen Koeffizienten behalten denselben mechanischen Raumbezug. Das stückweise Integral ist innerhalb dieses Luftspaltmodells exakt, die Fourier-Summe eine endliche Näherung. L ist symmetrisch und positiv semidefinit. Negative Gegeninduktivitäten folgen aus Achsen und Anschlussrichtungen. M=-L/2 gilt nur für das symmetrische Grundwellensystem.";
    case 6 then
        heading = "Ströme einsetzen, Flussverkettung und Energie";
        keys = ["matrix-linkage", "differential", "energy"];
        explanation = "Die Flussverkettung enthält bereits die Windungszahl und alle gegenseitigen Beiträge. Psi_a/i_a ist deshalb nur bei alleiniger Bestromung dieses Strangs seine Selbstinduktivität. Bei Strom null wird nichts dividiert: Psi=L*i bleibt gültig. Im linearen ungesättigten Modell sind Sekanten- und differentielle Induktivität gleich. Ein nichtlineares Materialmodell wäre für Sättigung erforderlich.";
    else
        error("Die Etappe muss zwischen 1 und 6 liegen.");
    end
endfunction

function lines = ew_stage_values(w, d, stage, phase)
    names = ["A", "B", "C"];
    a = find(names == phase);
    if isempty(a) then error("Strang muss A, B oder C sein."); end
    p = d.parameters;
    pd = d.phases(a);
    select stage
    case 1 then
        lines = ["Strang " + phase + ": orientierte Grundwellenachse = " + ew_number(pd.axisDeg) + " Grad mechanisch."; ..
            "p = " + string(w.polePairs) + "; Serienwindungszahl = " + string(pd.turnsSeries) + " = " + string(pd.coilCount) + " Spulen * " + string(p.turnsPerCoil) + " Windungen."; ..
            "Geometrische Mitte und orientierte Feldachse sind getrennte Größen."];
    case 2 then
        f = pd.selected;
        lines = ["k = " + string(p.selectedOrder) + "; Spulenfaktor S = " + ew_number(f.pitchFactor); ..
            "Komplexer Strangfaktor H = " + ew_complex_text(f.distributionFactor); ..
            "Wicklungsfaktor kw = |S*H| = " + ew_number(f.windingFactor) + "."];
    case 3 then
        theta = 0;
        for j = 1:length(d.segments), theta = max(theta, abs(d.segments(j).thetaAmpereTurns)); end
        lines = ["max|Theta| = " + ew_number(theta) + " A*Windungen"; ..
            "max|B| = (4*pi*1e-7 / " + ew_number(p.gapM) + ") * " + ew_number(theta) + " = " + ew_number(4*%pi*1d-7*theta/p.gapM) + " T"; ..
            "Luftspalt delta_eff = " + ew_number(p.gapM*1000) + " mm; n = " + string(p.turnsPerCoil) + " Windungen je Spule."];
    case 4 then
        lines = ["r = " + ew_number(p.radiusM) + " m; aktive Eisenlänge = " + ew_number(p.lengthM) + " m"; ..
            "tau_p = pi*r/p = " + ew_number(p.polePitchM*1000) + " mm; Umfang = p * 2*tau_p."; ..
            "Lokale Ordnung nu und mechanische Ordnung k unterscheiden sich: k = p*nu."];
    case 5 then
        lines = ["Fourier-Vorfaktor = 4*mu0*r*lFe*n^2/(pi*delta) = " + ew_number(d.fourierPrefactorH) + " H"; ..
            "Exakt: L" + phase + phase + " = " + ew_number(d.matrixH(a,a)*1000) + " mH"; ..
            "Fourier bis K = " + string(p.maxOrder) + ": relative Matrixabweichung = " + ew_number(100*d.relativeTruncationError) + " Prozent."];
    case 6 then
        products = emptystr(1, 3);
        for b = 1:3, products(b) = "(" + ew_number(d.matrixH(a,b)*1000) + ")*(" + ew_number(p.currents(b)) + ")"; end
        lines = ["Psi_" + phase + " = " + strcat(products, " + ") + " = " + ew_number(d.fluxLinkagesWbTurns(a)*1000) + " mWb"; ..
            "i(A,B,C) = [" + ew_number(p.currents(1)) + "; " + ew_number(p.currents(2)) + "; " + ew_number(p.currents(3)) + "] A"; ..
            "Magnetische Energie = 0.5*i^T*L*i = " + ew_number(d.energyJ*1000) + " mJ."];
    end
endfunction

function ax = ew_plot_derivation(w, d, stage, phase, ax)
    if argn(2) < 3 then stage = 1; end
    if argn(2) < 4 then phase = "A"; end
    if argn(2) < 5 then ax = []; end
    [heading, keys, explanation] = ew_stage(stage);
    ax = ew_gfx_prepare("Etappe " + string(stage) + ": " + heading, ax);
    ax.data_bounds = [0, 0; 1, 1];
    if ~d.valid then xstring(0.04, 0.7, "Ohne vollständige Wicklung keine Induktivitätsherleitung."); return; end
    step = min(0.16, 0.72/size(keys, "*"));
    for k = 1:size(keys, "*")
        [latex, unused] = ew_formula(keys(k));
        try
            xstring(0.02, 0.90-(k-1)*step, "$" + latex + "$");
            formulaHandle = gce();
            formulaHandle.font_size = 5;
        catch
            // Scilab versions differ in supported JLaTeXMath commands. The
            // offline HTML report always contains the complete native MathML.
            xstring(0.02, 0.90-(k-1)*step, latex);
            gce().font_size = 2;
        end
    end
    lines = ew_stage_values(w, d, stage, phase);
    xstring(0.02, 0.10, lines);
    gce().font_size = 2;
    ax.x_label.text = "Die vollständige Erklärung und Zahlen-Tabellen stehen im Offline-HTML-Bericht.";
endfunction

function ew_export_csv(w, path, settings)
    if argn(2) < 3 then settings = struct("startSlot", 0, "connectionMode", "series"); end
    rows = ["Wicklungsatelier Scilab;Version;1.1"; ..
        "Q;p;Schichten;y;q;kw1"; ..
        strcat([string(w.slots),string(w.polePairs),string(w.layers),ew_number(w.coilSpan),ew_number(w.q),ew_number(w.metrics.kw)], ";"); ..
        ""; "Nut;Lage;Strang;Vorzeichen;Elektrischer Winkel Grad"];
    for k = 1:length(w.slotLayers)
        s = w.slotLayers(k);
        rows($+1) = strcat([string(s.slot),string(s.layer),s.phase,string(s.sign),ew_number(s.angleDeg)], ";");
    end
    rows = [rows; ""; "Spule;Strang;Positive Nut;Negative Nut;Weite;Positive Lage;Negative Lage;Orientierung"];
    for k = 1:length(w.coils)
        c = w.coils(k);
        rows($+1) = strcat([c.id,c.phase,string(c.positiveSlot),string(c.negativeSlot),string(c.span),string(c.positiveLayer),string(c.negativeLayer),string(c.direction)], ";");
    end
    if w.valid then
        layout = ew_build_winding_layout(w, settings.connectionMode, settings.startSlot);
        rows = [rows; ""; "Umfangsschnitt;"+string(layout.startSlot); "Verschaltung;"+settings.connectionMode];
        rows = [rows; ""; "Serienverbindung;Strang;Von Spule;Zu Spule;Von Knoten;Zu Knoten"];
        for k = 1:length(layout.connections)
            c = layout.connections(k);
            rows($+1) = strcat(["Link",c.phase,c.fromCoilId,c.toCoilId,c.fromNode,c.toNode], ";");
        end
        rows = [rows; ""; "Klemme;Strang;Spule;Nut;Lage;Knoten"];
        for k = 1:length(layout.terminals)
            t = layout.terminals(k);
            rows($+1) = strcat([t.label,t.phase,t.coilId,string(t.slot),string(t.layer),t.nodeId], ";");
        end
    end
    mputl(rows, path);
endfunction

function ew_export_spectrum_csv(s, path)
    rows = ["k;Realteil;Imaginaerteil;Betrag;Raw Realteil;Raw Imaginaerteil"];
    for k = 1:length(s.coefficients)
        c = s.coefficients(k);
        rows($+1) = strcat([string(c.order),ew_number(c.real),ew_number(c.imag),ew_number(c.amplitude),ew_number(c.rawReal),ew_number(c.rawImag)], ";");
    end
    mputl(rows, path);
endfunction

function ew_export_inductance_csv(d, path)
    if ~d.valid then error("Keine gültige Induktivität vorhanden."); end
    rows = ["Luftspaltmatrix / H;iA;iB;iC"];
    names = ["A","B","C"];
    for a = 1:3
        rows($+1) = strcat(["Psi"+names(a),ew_number(d.matrixH(a,1)),ew_number(d.matrixH(a,2)),ew_number(d.matrixH(a,3))], ";");
    end
    rows = [rows; ""; "Strang;Strom / A;Flussverkettung / Wb"];
    for a = 1:3, rows($+1) = strcat([names(a),ew_number(d.parameters.currents(a)),ew_number(d.fluxLinkagesWbTurns(a))], ";"); end
    rows = [rows; ""; "Energie / J;"+ew_number(d.energyJ)];
    mputl(rows, path);
endfunction

function learning = ew_export_learning_context(w, d, settings)
    learning = struct("valid", %f, "warnings", "Keine vollständige Induktivitätsberechnung vorhanden.");
    if ~w.valid | ~d.valid then return; end
    phase = "A"; sourcePhase = "A"; coilId = "";
    order = d.parameters.selectedOrder; limit = d.parameters.maxOrder;
    if isfield(settings,"phase") then phase = settings.phase; end
    if isfield(settings,"sourcePhase") then sourcePhase = settings.sourcePhase; end
    if isfield(settings,"coilId") then coilId = settings.coilId; end
    if isfield(settings,"selectedOrder") then order = settings.selectedOrder; end
    if isfield(settings,"convergenceOrder") then limit = settings.convergenceOrder; end
    learning = ew_compute_learning(w,d,coilId,phase,sourcePhase,order,limit);
endfunction

function ew_export_json(w, s, d, path, settings, learning)
    if argn(2) < 5 then settings = struct("startSlot", 0, "connectionMode", "series"); end
    if argn(2) < 6 then learning = ew_export_learning_context(w,d,settings); end
    payload = struct("edition", "Scilab", "version", "1.1", "winding", w, "spectrum", s, "inductance", d);
    payload.settings = settings;
    payload.learning = learning;
    if learning.valid then payload.convergence = learning.convergence; end
    if w.valid then payload.windingLayout = ew_build_winding_layout(w, settings.connectionMode, settings.startSlot); end
    mputl(toJSON(payload), path);
endfunction

function ew_export_svg(fig, path)
    if isempty(fig) then error("Zuerst ein Diagramm öffnen."); end
    xs2svg(fig, path);
endfunction

function html = ew_html_matrix(matrix, label)
    names = ["A","B","C"];
    html = "<h3>"+ew_html_escape(label)+" / mH</h3><div class=""scroll""><table><tr><th>Empfang / Erregung</th><th>A</th><th>B</th><th>C</th></tr>";
    for a = 1:3
        html = html + "<tr><th>"+names(a)+"</th>";
        for b = 1:3, html = html + "<td>"+ew_number(matrix(a,b)*1000)+"</td>"; end
        html = html + "</tr>";
    end
    html = html + "</table></div>";
endfunction

function ew_export_report(w, d, path, learning)
    if ~w.valid | ~d.valid then error("Für den Bericht ist eine vollständige gültige Wicklung nötig."); end
    if argn(2) < 4 then learning = ew_export_learning_context(w,d,struct()); end
    html = ["<!doctype html><html lang=""de""><head><meta charset=""utf-8""><meta name=""viewport"" content=""width=device-width,initial-scale=1""><title>Wicklungsatelier – mathematische Herleitung</title>"; ..
        "<style>body{font:16px/1.8 system-ui,sans-serif;color:#344132;background:#f5f6ed;margin:0}main{max-width:1080px;margin:32px auto;padding:0 20px}section{background:#fffefa;border:1px solid #dce1d1;border-radius:8px;padding:24px;margin:22px 0}h1,h2,h3{line-height:1.4}h1{font-size:28px}h2{font-size:22px}h3{font-size:17px}table{border-collapse:collapse;width:100%;font-size:14px}th,td{padding:9px;border:1px solid #e1e6d7;text-align:right}th:first-child,td:first-child{text-align:left}.formula{overflow-x:auto;padding:15px;background:#f3f5eb;border-radius:6px;margin:16px 0;font-size:18px}.values{background:#faf3e8;padding:16px;overflow-wrap:anywhere}.scroll{overflow:auto}pre{white-space:pre-wrap}nav a{margin-right:16px;color:#a95736}small{color:#748268}@media print{body{background:white}section{break-inside:avoid}nav{display:none}main{margin:0;max-width:none}}</style></head><body><main>"; ..
        "<h1>Wicklungsatelier für Scilab: mathematische Herleitung</h1>"; ..
        "<p>Q="+string(w.slots)+", p="+string(w.polePairs)+", Schichten="+string(w.layers)+", y="+string(w.coilSpan)+", q="+ew_number(w.q)+". Berechnet aus den tatsächlichen vorzeichenbehafteten Nutlagen und Serienverbindungen.</p>"; ..
        "<p><strong>Modell:</strong> linearer Magnetkreis, ideal magnetisch leitendes Eisen, gleichmäßiger dünner Luftspalt. Luftspalt-/Hauptinduktivität ohne Nut- und Wickelkopfstreuung, Sättigung, endliche Eisenpermeabilität und Rotorsalienz.</p>"; ..
        "<p>r="+ew_number(d.parameters.radiusM*1000)+" mm, lFe="+ew_number(d.parameters.lengthM*1000)+" mm, delta_eff="+ew_number(d.parameters.gapM*1000)+" mm, n="+string(d.parameters.turnsPerCoil)+" Windungen je Spule. Abmessungen und Windungszahl müssen zur eigenen Maschine passen; die Voreinstellungen sind Beispielwerte.</p>"; ..
        "<nav>" ];
    for stage = 1:6, html($+1) = "<a href=""#stage"+string(stage)+""">Etappe "+string(stage)+"</a>"; end
    html($+1) = "</nav>";
    for stage = 1:6
        [heading, keys, explanation] = ew_stage(stage);
        html($+1) = "<section id=""stage"+string(stage)+"""><h2>"+string(stage)+". "+ew_html_escape(heading)+"</h2><p>"+ew_html_escape(explanation)+"</p>";
        for k = 1:size(keys, "*")
            [latex, mathml] = ew_formula(keys(k));
            html($+1) = "<div class=""formula"">"+mathml+"</div>";
        end
        for a = 1:3
            names = ["A","B","C"];
            values = ew_stage_values(w, d, stage, names(a));
            html($+1) = "<div class=""values""><strong>Strang "+names(a)+"</strong><p>"+strcat(ew_html_escape(values), "<br>")+"</p></div>";
            if stage <> 1 & stage <> 2 & stage <> 6 then break; end
        end
        if stage == 1 then
            html($+1) = "<div class=""scroll""><table><tr><th>Spule</th><th>Geometrische Mitte / Grad</th><th>MMF-Achse / Grad mech.</th><th>Relativ zum Strang / Grad el.</th><th>Orientierung</th></tr>";
            for k = 1:length(d.coils)
                c = d.coils(k);
                html($+1) = "<tr><td>"+c.id+"</td><td>"+ew_number(c.centerDeg)+"</td><td>"+ew_number(c.axisDeg)+"</td><td>"+ew_number(c.relativeElectricalDeg)+"</td><td>"+string(c.direction)+"</td></tr>";
            end
            html($+1) = "</table></div>";
        end
        if stage == 2 then
            html($+1) = "<div class=""scroll""><table><tr><th>Gruppe</th><th>Spulen</th><th>Gruppenfaktor G</th><th>Gewichteter Strangbeitrag</th></tr>";
            for k = 1:length(d.groups)
                g = d.groups(k);
                html($+1) = "<tr><td>"+g.id+"</td><td>"+strcat(g.coilIds, ", ")+"</td><td>"+ew_complex_text(g.selected.distributionFactor)+"</td><td>"+ew_complex_text(g.selected.phaseContribution)+"</td></tr>";
            end
            html($+1) = "</table></div>";
        end
        if stage == 5 then
            html($+1) = ew_html_matrix(d.matrixH, "Exakte Luftspalt-Induktivitätsmatrix");
            html($+1) = ew_html_matrix(d.fundamentalMatrixH, "Nur Nutzgrundwelle k=p");
            html($+1) = ew_html_matrix(d.harmonicMatrixH, "Fourier-Summe bis K="+string(d.parameters.maxOrder));
        end
        if learning.valid then html = [html; ew_learning_html_stage(w,d,learning,stage)]; end
        html($+1) = "</section>";
    end
    html = [html; "<p><small>Scilab-Edition 1.1 · Formeln als natives MathML · vollständig offline lesbar. Zum PDF-Ausdruck die Druckfunktion des Browsers verwenden.</small></p></main></body></html>"];
    mputl(html, path);
endfunction

function rows = ew_learning_formula_rows(keys)
    rows = emptystr(0,1);
    for k = 1:size(keys,"*")
        [unused, mathml] = ew_formula(keys(k));
        rows($+1) = "<div class=""formula"">"+mathml+"</div>";
    end
endfunction

function rows = ew_learning_html_stage(w,d,learning,stage)
    rows = emptystr(0,1);
    names = ["A","B","C"];
    a = find(names == learning.phase); b = find(names == learning.sourcePhase);
    select stage
    case 1 then
        c = learning.coil;
        rows = ["<h3>Verknüpfte Auswahl: Spule "+ew_html_escape(c.id)+"</h3>"; ..
            "<div class=""values"" data-learning-coil="""+ew_html_escape(c.id)+""">Empfangsstrang "+learning.phase+", Quellenstrang "+learning.sourcePhase+", mechanische Raumordnung k="+string(learning.order)+". Dieselbe Spule wird im Wickelschema, den Spannungssternen und der Achsenansicht hervorgehoben.</div>"; ..
            "<p>Die tatsächlichen Seiten behalten ihre Nut und Lage. Spannungszeiger verwenden +j im Exponenten; die ungedrehten Fourier-Koeffizienten verwenden −j. Die Konjugation und die Division durch 2jk sind notwendig.</p>"; ..
            ew_learning_formula_rows("learning-voltage"); ..
            "<div class=""scroll""><table><tr><th>Seite</th><th>Nut</th><th>Lage</th><th>Vorzeichenbehafteter Spannungszeiger bei k</th></tr>" ];
        slots = [c.positiveSlot,c.negativeSlot]; layers = [c.positiveLayer,c.negativeLayer]; signs = [1,-1]; labels = ["Plus","Minus"];
        for j = 1:2
            value = signs(j)*exp(%i*learning.order*2*%pi*(slots(j)-1)/w.slots);
            rows($+1) = "<tr><td>"+labels(j)+"</td><td>"+string(slots(j))+"</td><td>"+string(layers(j))+"</td><td>"+ew_complex_text(ew_i_complex(value))+"</td></tr>";
        end
        rows($+1) = "</table></div>";
    case 2 then
        rows = ["<h3>Nachvollziehbare Summenkette bei k="+string(learning.order)+"</h3>"; ..
            ew_learning_formula_rows("learning-chain"); ..
            "<p>Die ausgewählte Spule gehört zu einer tatsächlichen Spulengruppe. Die Tabelle stellt deren Beiträge und den vollständigen Empfangsstrang im gemeinsamen mechanischen Bezug gegenüber. Einheiten: normierte Spannungszeiger und dimensionslose Fourier-Koeffizienten.</p>"; ..
            "<div class=""scroll""><table><tr><th>Summe</th><th>Spulen</th><th>Spannungszeiger U bei k</th><th>Raw-Fourier C bei k</th></tr>" ];
        nodes = list(learning.coilContribution,learning.groupContribution,learning.phaseContribution);
        labels = ["Ausgewählte Spule","Ihre Gruppe","Vollständiger Strang "+learning.phase];
        for j = 1:3
            node = nodes(j);
            rows($+1) = "<tr><td>"+labels(j)+"</td><td>"+ew_html_escape(strcat(node.coilIds,", "))+"</td><td>"+ew_complex_text(node.voltageHarmonic)+"</td><td>"+ew_complex_text(node.rawFourier)+"</td></tr>";
        end
        rows($+1) = "</table></div>";
    case 5 then
        rows = ["<h3>Beitrag einer einzelnen Raumharmonischen</h3>"; ..
            ew_learning_formula_rows(["learning-inductance","learning-cross-terms"]); ..
            "<p>Der Induktivitätsbeitrag verwendet die vollständigen Strangsummen, einschließlich der Kreuzterme zwischen den Spulen. Die Auswahl einer einzelnen Spule verändert weder die physikalische Verschaltung noch die gesamte Induktivität.</p>"; ..
            "<div class=""values"">ΔL_"+learning.phase+learning.sourcePhase+",k = "+ew_number(learning.selectedContributionH*1000)+" mH bei k="+string(learning.order)+". Exaktes L_"+learning.phase+learning.sourcePhase+" = "+ew_number(learning.exactSelectedH*1000)+" mH.</div>"; ..
            ew_learning_formula_rows("learning-convergence"); ..
            "<p>Die Selbstinduktivität nähert sich durch nichtnegative Eigenbeiträge dem exakten Integral. Gegeninduktivitäten können oszillieren und ihr Vorzeichen wechseln. Die angegebene relative Abweichung bezieht sich auf die vollständige Matrix; auch bei exakt verschwindender Gegeninduktivität bleibt sie definiert.</p>"; ..
            ew_learning_html_convergence(learning.convergence,learning.phase,learning.sourcePhase,learning.order) ];
    case 6 then
        pairFlux = learning.selectedContributionH*d.parameters.currents(b);
        rows = ["<h3>Flussverkettung der ausgewählten Raumharmonischen</h3>"; ..
            ew_learning_formula_rows("learning-flux"); ..
            "<p>Aus der Quelle "+learning.sourcePhase+" allein: ΔL_"+learning.phase+learning.sourcePhase+",k · i_"+learning.sourcePhase+" = "+ew_number(pairFlux*1000)+" mWb. Mit allen drei eingestellten Strangströmen zusammen: Ψ_"+learning.phase+",k = "+ew_number(learning.harmonicFluxLinkageWbTurns(a)*1000)+" mWb.</p>" ];
    end
endfunction

function rows = ew_learning_html_convergence(conv,phase,sourcePhase,selectedOrder)
    names = ["A","B","C"]; a = find(names==phase); b = find(names==sourcePhase);
    count = size(conv.orders,"*");
    values = zeros(count,1);
    for j = 1:count, matrix = conv.partialMatricesH(j); values(j) = matrix(a,b)*1000; end
    exact = conv.exactMatrixH(a,b)*1000;
    low = min([values;exact]); high = max([values;exact]);
    spread = high-low;
    if spread < 1d-15 then spread = max([abs(exact)*0.1;1d-6]); end
    low = low-0.08*spread; high = high+0.08*spread;
    points = emptystr(1,count);
    for j = 1:count
        px = 70+800*(j-1)/max(1,count-1); py = 260-220*(values(j)-low)/(high-low);
        points(j) = msprintf("%.4f,%.4f",px,py);
    end
    yExact = 260-220*(exact-low)/(high-low);
    rows = ["<div class=""scroll""><svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 920 320"" role=""img"" aria-label=""Konvergenz L_"+phase+sourcePhase+""" style=""width:100%;min-width:500px;background:#f8f9f1""><text x=""70"" y=""20"" font-size=""15"" fill=""#344132"">L_"+phase+sourcePhase+" in mH: Fourier-Summe und exaktes Integral</text>"; ..
        msprintf("<line x1=""70"" x2=""870"" y1=""%.4f"" y2=""%.4f"" stroke=""#31806d"" stroke-dasharray=""7 4""/>",yExact,yExact); ..
        "<polyline fill=""none"" stroke=""#c65736"" stroke-width=""2"" points="""+strcat(points," ")+"""/><path d=""M70 35 V260 H870"" fill=""none"" stroke=""#7b8970""/>"; ..
        "<text x=""64"" y=""44"" text-anchor=""end"" font-size=""11"">"+msprintf("%.4g",high)+"</text><text x=""64"" y=""263"" text-anchor=""end"" font-size=""11"">"+msprintf("%.4g",low)+"</text>"; ..
        "<text x=""70"" y=""283"" font-size=""12"">K=1</text><text x=""800"" y=""283"" font-size=""12"">K="+string(count)+"</text><text x=""70"" y=""307"" font-size=""12"">Grün gestrichelt: exakt "+ew_number(exact)+" mH; rot: L(K)</text></svg></div>" ];
    if selectedOrder > count then rows($+1) = "<p>Die ausgewählte Ordnung k="+string(selectedOrder)+" liegt außerhalb des Konvergenzbereichs K≤"+string(count)+". Ihr Einzelbeitrag wird trotzdem gesondert berechnet.</p>"; end
    orders = unique([1,min(count,20),min(count,60),min(count,120),min(count,360),count]);
    rows($+1) = "<div class=""scroll""><table><tr><th>K</th><th>L_"+phase+sourcePhase+"(K) / mH</th><th>Matrixabweichung / %</th></tr>";
    for k = orders
        rows($+1) = "<tr><td>"+string(k)+"</td><td>"+ew_number(values(k))+"</td><td>"+ew_number(conv.relativeError(k)*100)+"</td></tr>";
    end
    rows($+1) = "</table></div>";
endfunction

function text = ew_learning_csv_number(value)
    if isnan(value) | isinf(value) then text = "nicht definiert"; else text = msprintf("%.16g",value); end
endfunction

function ew_export_learning_csv(learning,path)
    if ~learning.valid then error("Keine gültige Lernansicht vorhanden."); end
    rows = ["Wicklungsatelier Scilab;Version;1.1"; ..
        "Spule;Empfangsstrang;Quellenstrang;Raumordnung k"; ..
        strcat([learning.coilId,learning.phase,learning.sourcePhase,string(learning.order)],";"); ..
        ""; "Summe;Spulenzahl;U Real;U Imaginaer;C Raw Real;C Raw Imaginaer"];
    nodes = list(learning.coilContribution,learning.groupContribution,learning.phaseContribution,learning.sourceContribution);
    labels = ["Spule","Gruppe","Empfangsstrang","Quellenstrang"];
    for j = 1:4
        n = nodes(j);
        rows($+1) = strcat([labels(j),string(n.coilCount),ew_learning_csv_number(n.voltageHarmonic.real),ew_learning_csv_number(n.voltageHarmonic.imag),ew_learning_csv_number(n.rawFourier.real),ew_learning_csv_number(n.rawFourier.imag)],";");
    end
    names = ["A","B","C"]; phaseIndex = find(names==learning.phase);
    rows = [rows; ""; "Harmonischer Induktivitaetsbeitrag / H;"+ew_learning_csv_number(learning.selectedContributionH); ..
        "Exakter gesamter Matrixeintrag / H;"+ew_learning_csv_number(learning.exactSelectedH); ..
        "Harmonische Flussverkettung gewaehlte Quelle / Wb;"+ew_learning_csv_number(learning.selectedFluxLinkageWbTurns); ..
        "Harmonische Flussverkettung alle Stroeme / Wb;"+ew_learning_csv_number(learning.harmonicFluxLinkageWbTurns(phaseIndex))];
    mputl(rows,path);
endfunction

function ew_export_convergence_csv(conv,phase,sourcePhase,path)
    if ~conv.valid then error("Keine gültige Konvergenzberechnung vorhanden."); end
    names = ["A","B","C"]; a = find(names==phase); b = find(names==sourcePhase);
    if isempty(a) | isempty(b) then error("Stränge müssen A, B oder C sein."); end
    rows = ["Wicklungsatelier Scilab;Konvergenz;Empfang;"+phase+";Quelle;"+sourcePhase; ..
        "K;L(K) / H;Exakter Matrixeintrag / H;Relative Matrixabweichung;Delta L dieser Ordnung / H"];
    for k = 1:size(conv.orders,"*")
        matrix = conv.partialMatricesH(k); contribution = conv.contributions(k);
        rows($+1) = strcat([string(k),ew_learning_csv_number(matrix(a,b)),ew_learning_csv_number(conv.exactMatrixH(a,b)),ew_learning_csv_number(conv.relativeError(k)),ew_learning_csv_number(contribution(a,b))],";");
    end
    mputl(rows,path);
endfunction
