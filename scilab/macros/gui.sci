// Native desktop front end. All calculations remain callable without a GUI.
// Entry point: ew_gui(). State: global ew_app (controls, settings and results).
// View callbacks use named functions; numeric edits are parsed without evstr.

function h = ew_gui_label(parent, text, position, fontSize)
    if argn(2) < 4 then fontSize = 10; end
    h = uicontrol(parent, "style", "text", "units", "normalized", ..
        "position", position, "string", text, "horizontalalignment", "left", ..
        "fontsize", fontSize, "backgroundcolor", [0.975 0.98 0.96], ..
        "foregroundcolor", [0.23 0.29 0.20]);
endfunction

function h = ew_gui_edit(parent, value, position, tag, hint)
    if argn(2) < 5 then hint = ""; end
    h = uicontrol(parent, "style", "edit", "units", "normalized", ..
        "position", position, "string", value, "horizontalalignment", "left", ..
        "fontsize", 11, "backgroundcolor", [1 1 0.99], ..
        "foregroundcolor", [0.23 0.29 0.20], "tag", tag, "tooltipstring", hint);
endfunction

function h = ew_gui_popup(parent, options, value, position, tag)
    h = uicontrol(parent, "style", "popupmenu", "units", "normalized", ..
        "position", position, "string", options, "value", value, ..
        "fontsize", 10, "backgroundcolor", [1 1 0.99], ..
        "foregroundcolor", [0.23 0.29 0.20], "tag", tag);
endfunction

function h = ew_gui_button(parent, label, callback, position)
    h = uicontrol(parent, "style", "pushbutton", "units", "normalized", ..
        "position", position, "string", label, "callback", callback, ..
        "fontsize", 10, "backgroundcolor", [0.91 0.94 0.87], ..
        "foregroundcolor", [0.23 0.29 0.20]);
endfunction

function value = ew_gui_number(control, description)
    text = strsubst(stripblanks(control.string), ",", ".");
    if size(text, "*") <> 1 then error(description + ": Ein einzelner Zahlenwert ist erforderlich."); end
    // Full-string validation also rejects trailing commands or expressions.
    pattern = "/^[-+]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][-+]?[0-9]+)?$/";
    if size(regexp(text, pattern), "*") == 0 then
        error(description + ": Bitte eine Zahl eingeben (keine Formel).");
    end
    value = strtod(text);
    if isnan(value) | isinf(value) then error(description + ": Der Wert muss endlich sein."); end
endfunction

function text = ew_gui_format(value, digits)
    if argn(2) < 2 then digits = 5; end
    if size(value, "*") <> 1 then text = "nicht definiert"; return; end
    if isnan(value) | isinf(value) then text = "nicht definiert"; return; end
    if abs(value) < 1d-11 then value = 0; end
    text = msprintf("%.*g", digits, value);
endfunction

function ew_gui()
    global ew_app;
    // A timer from a previous application instance must not change the new one.
    if typeof(ew_app)=="st" then
        if isfield(ew_app,"animationPlaying") then
            ew_gui_animation_pause();
            if isfield(ew_app.plotFigures,"animation") then
                try delete(ew_app.plotFigures.animation);catch ignored=%t;end
            end
        end
    end
    // Reopening replaces only this application window, never unrelated figures.
    if typeof(ew_app) == "st" then
        if isfield(ew_app, "figure") then
            try delete(ew_app.figure); catch ignored = %t; end
        end
    end
    windowSize = [1240 880];
    screen = get(0, "screensize_px");
    windowSize = [max(980, min(windowSize(1), screen(3) - 70)), ..
        max(650, min(windowSize(2), screen(4) - 90))];
    fig = figure("figure_name", "Wicklungsatelier - Scilab", ..
        "axes_size", windowSize, "menubar", "none", "toolbar", "none", ..
        "infobar_visible", "off", "dockable", "off", "visible", "off");
    fig.background = color(249, 250, 245);
    fig.tag = "wicklungsatelier-main";
    fig.figure_position = [35 35];
    c = struct();
    ew_gui_label(fig, "Wicklungsatelier", [0.02 0.943 0.93 0.043], 20);
    ew_gui_label(fig, "Dreiphasige Statorwicklung: Geometrie, Zeiger, Raumspektrum und Luftspaltinduktivität", [0.02 0.907 0.95 0.032], 11);

    ew_gui_label(fig, "WICKLUNG", [0.02 0.866 0.30 0.025], 12);
    ew_gui_label(fig, "Nutenzahl Q", [0.02 0.837 0.135 0.022]);
    ew_gui_label(fig, "Polpaarzahl p", [0.177 0.837 0.135 0.022]);
    c.slots = ew_gui_edit(fig, "12", [0.02 0.802 0.135 0.035], "ew-slots", "Ganze Zahl von 6 bis 120");
    c.polePairs = ew_gui_edit(fig, "1", [0.177 0.802 0.135 0.035], "ew-polepairs", "Ganze Zahl von 1 bis Q/2");
    ew_gui_label(fig, "Lagen", [0.02 0.773 0.135 0.022]);
    ew_gui_label(fig, "Spulenweite y", [0.177 0.773 0.135 0.022]);
    c.layers = ew_gui_popup(fig, ["Einschicht"; "Zweischicht"], 1, [0.02 0.738 0.135 0.035], "ew-layers");
    c.coilSpan = ew_gui_edit(fig, "0", [0.177 0.738 0.135 0.035], "ew-span", "0 = automatisch; sonst feste Weite in Nuten");
    ew_gui_label(fig, "y = 0: automatische Auswahl innerhalb der festen Zonung", [0.02 0.706 0.30 0.026], 9);

    ew_gui_label(fig, "SPEKTRUM UND ABWICKLUNG", [0.02 0.674 0.30 0.025], 12);
    ew_gui_label(fig, "Strang", [0.02 0.646 0.135 0.022]);
    ew_gui_label(fig, "Höchste Ordnung K", [0.177 0.646 0.135 0.022]);
    c.phase = ew_gui_popup(fig, ["A"; "B"; "C"], 1, [0.02 0.611 0.135 0.035], "ew-phase");
    c.maxOrder = ew_gui_popup(fig, ["20"; "40"; "60"; "120"], 4, [0.177 0.611 0.135 0.035], "ew-maxorder");
    ew_gui_label(fig, "Spektrumsquelle", [0.02 0.584 0.29 0.022]);
    c.source = ew_gui_popup(fig, ["Aktuelle Wicklung"; "Vollgeteilte Einzelspule"; "3/2-Wicklung"; "Gesehnte Gruppe"; "Q9/p4-Gruppe"], 1, [0.02 0.548 0.292 0.035], "ew-source");
    ew_gui_label(fig, "Normierung", [0.02 0.520 0.135 0.022]);
    ew_gui_label(fig, "Spektrumsanzeige", [0.177 0.520 0.135 0.022]);
    c.normalization = ew_gui_popup(fig, ["Strangsumme"; "Je Spule"], 1, [0.02 0.485 0.135 0.035], "ew-normalization");
    c.display = ew_gui_popup(fig, ["Realteil"; "Betrag"], 1, [0.177 0.485 0.135 0.035], "ew-display");
    c.polarity = uicontrol(fig, "style", "checkbox", "units", "normalized", ..
        "position", [0.02 0.455 0.29 0.025], "string", "Spektrum gemeinsam umpolen", ..
        "value", 0, "fontsize", 9, "backgroundcolor", [0.975 0.98 0.96]);
    ew_gui_label(fig, "Verschaltung", [0.02 0.426 0.135 0.022]);
    ew_gui_label(fig, "Abwicklung ab Nut", [0.177 0.426 0.135 0.022]);
    c.connectionMode = ew_gui_popup(fig, ["Serienstränge"; "Einzelspulen"], 1, [0.02 0.391 0.135 0.035], "ew-mode");
    c.startSlot = ew_gui_edit(fig, "0", [0.177 0.391 0.135 0.035], "ew-startslot", "0 = automatischer Umfangsschnitt");

    ew_gui_label(fig, "BEISPIELGEOMETRIE / EIGENE DATEN", [0.02 0.355 0.30 0.025], 11);
    ew_gui_label(fig, "Luftspaltdurchm. / mm", [0.02 0.326 0.135 0.022], 9);
    ew_gui_label(fig, "Eisenlänge / mm", [0.177 0.326 0.135 0.022], 9);
    c.diameterMm = ew_gui_edit(fig, "100", [0.02 0.291 0.135 0.035], "ew-diameter", "Mittlerer Luftspaltdurchmesser D = 2r");
    c.lengthMm = ew_gui_edit(fig, "100", [0.177 0.291 0.135 0.035], "ew-length");
    ew_gui_label(fig, "Luftspalt effektiv / mm", [0.02 0.262 0.135 0.022], 9);
    ew_gui_label(fig, "Windungen je Spule", [0.177 0.262 0.135 0.022], 9);
    c.gapMm = ew_gui_edit(fig, "1", [0.02 0.227 0.135 0.035], "ew-gap");
    c.turns = ew_gui_edit(fig, "10", [0.177 0.227 0.135 0.035], "ew-turns");
    ew_gui_label(fig, "Momentanströme iA / iB / iC in A", [0.02 0.198 0.29 0.022], 9);
    c.currentA = ew_gui_edit(fig, "1", [0.02 0.163 0.087 0.035], "ew-current-a");
    c.currentB = ew_gui_edit(fig, "0", [0.121 0.163 0.088 0.035], "ew-current-b");
    c.currentC = ew_gui_edit(fig, "0", [0.223 0.163 0.089 0.035], "ew-current-c");
    ew_gui_button(fig, "(1; 0; 0) A", "ew_gui_current_single();", [0.02 0.124 0.135 0.031]);
    ew_gui_button(fig, "(1; -0,5; -0,5) A", "ew_gui_current_balanced();", [0.177 0.124 0.135 0.031]);
    ew_gui_button(fig, "Berechnen / aktualisieren", "ew_gui_calculate();", [0.02 0.067 0.292 0.044]);

    ew_gui_label(fig, "VORLESUNGSBEISPIELE", [0.35 0.866 0.62 0.025], 12);
    c.preset = ew_gui_popup(fig, ["Q12 / p1 / Einschicht / y6"; "Q36 / p2 / Einschicht / automatisch"; "Q12 / p5 / Zweischicht / automatisch"; "Q9 / p4 / Zweischicht / y1"], 1, [0.35 0.816 0.47 0.042], "ew-preset");
    ew_gui_button(fig, "Beispiel laden", "ew_gui_apply_preset();", [0.835 0.816 0.145 0.042]);
    ew_gui_button(fig, "Analyse", "ew_gui_analyse();", [0.35 0.756 0.115 0.040]);
    ew_gui_button(fig, "Wickelschema", "ew_gui_winding();", [0.477 0.756 0.115 0.040]);
    ew_gui_button(fig, "Spektrum", "ew_gui_spectrum();", [0.604 0.756 0.115 0.040]);
    ew_gui_button(fig, "Induktivität", "ew_gui_inductance();", [0.731 0.756 0.115 0.040]);
    ew_gui_button(fig, "Herleitung", "ew_gui_derivation();", [0.858 0.756 0.122 0.040]);
    ew_gui_label(fig, "Wicklung: Strangfilter", [0.35 0.723 0.18 0.022], 9);
    ew_gui_label(fig, "Herleitung: Etappe", [0.55 0.723 0.18 0.022], 9);
    ew_gui_label(fig, "Faktoren: Raumordnung k", [0.75 0.723 0.23 0.022], 9);
    c.windingPhase = ew_gui_popup(fig, ["Alle Stränge"; "Nur A"; "Nur B"; "Nur C"], 1, [0.35 0.683 0.18 0.035], "ew-winding-phase");
    c.stage = ew_gui_popup(fig, ["1: Spulenachsen"; "2: Wicklungsfaktoren"; "3: Durchflutung / B"; "4: Flussverkettung"; "5: Induktivitäten"; "6: Ströme / Energie"], 1, [0.55 0.683 0.18 0.035], "ew-stage");
    c.selectedOrder = ew_gui_edit(fig, "1", [0.75 0.683 0.10 0.035], "ew-selected-order", "Mechanische Ordnung; Grundwelle k=p");
    c.coil = ew_gui_popup(fig, ["A1"], 1, [0.862 0.683 0.118 0.035], "ew-selected-coil");
    ew_gui_label(fig, "Interaktiver Lernpfad", [0.35 0.656 0.25 0.022], 9);
    ew_gui_label(fig, "Lernschritt", [0.604 0.656 0.18 0.022], 9);
    ew_gui_label(fig, "Quelle", [0.797 0.656 0.083 0.022], 9);
    ew_gui_label(fig, "K-Konv.", [0.892 0.656 0.088 0.022], 9);
    ew_gui_button(fig, "Lernpfad", "ew_gui_learning();", [0.35 0.617 0.115 0.035]);
    ew_gui_button(fig, "Konvergenz", "ew_gui_convergence();", [0.477 0.617 0.115 0.035]);
    c.learningStage = ew_gui_popup(fig, ["1: Spule"; "2: Gruppe"; "3: Strang"; "4: Induktivität"], 1, [0.604 0.617 0.18 0.035], "ew-learning-stage");
    c.sourcePhase = ew_gui_popup(fig, ["A"; "B"; "C"], 1, [0.797 0.617 0.083 0.035], "ew-source-phase");
    c.sourcePhase.tooltipstring = "Erregender Strang; der Strang links ist die Empfangswicklung";
    c.convergenceOrder = ew_gui_popup(fig, ["20"; "60"; "120"; "360"; "1200"], 3, [0.892 0.617 0.088 0.035], "ew-convergence-order");
    c.convergenceOrder.tooltipstring = "Unabhängige höchste Ordnung des Konvergenzdiagramms";
    c.animation = ew_gui_button(fig, "Zeigeranimation", "ew_gui_animation();", [0.35 0.561 0.18 0.035]);
    ew_gui_label(fig, "Schrittweise: Formel → eingesetzte Werte → Ergebnis", [0.545 0.561 0.435 0.030], 9);
    c.report = uicontrol(fig, "style", "edit", "units", "normalized", ..
        "position", [0.35 0.205 0.63 0.344], "string", "Berechnung wird vorbereitet ...", ..
        "min", 0, "max", 1000, "horizontalalignment", "left", "fontsize", 11, ..
        "fontname", "monospaced", "backgroundcolor", [1 1 0.99], ..
        "foregroundcolor", [0.23 0.29 0.20], "tag", "ew-report");
    ew_gui_label(fig, "Spule wählen oder im Diagramm anklicken: alle offenen Ansichten folgen derselben Auswahl.", [0.35 0.166 0.63 0.032], 9);
    c.exportCsv = ew_gui_button(fig, "Nutbelegung CSV", "ew_gui_save_csv();", [0.35 0.110 0.145 0.040]);
    ew_gui_button(fig, "Berechnung JSON", "ew_gui_save_json();", [0.511 0.110 0.145 0.040]);
    ew_gui_button(fig, "Diagramm SVG", "ew_gui_save_svg();", [0.672 0.110 0.145 0.040]);
    ew_gui_button(fig, "Herleitung HTML", "ew_gui_save_report();", [0.833 0.110 0.147 0.040]);
    ew_gui_label(fig, "Modell: gleiche Windungszahlen, ideal magnetisch leitendes Eisen, dünner gleichmäßiger Luftspalt.", [0.35 0.068 0.63 0.030], 9);
    c.status = ew_gui_label(fig, "Bereit.", [0.02 0.012 0.96 0.035], 10);
    callbacks = ["phase"; "coil"; "selectedOrder"; "stage"; "learningStage"; "sourcePhase"; "convergenceOrder"; "maxOrder"; "source"; "normalization"; "display"; "polarity"; "connectionMode"];
    for callbackIndex = 1:size(callbacks, "*")
        control = c(callbacks(callbackIndex));
        control.callback = "ew_gui_selection_changed();";
    end
    c.windingPhase.callback = "ew_gui_filter_changed();";
    c.startSlot.callback = "ew_gui_selection_changed();";
    ew_app = struct("figure", fig, "controls", c, "plotFigures", struct(), ..
        "lastFigure", [], "view", "analyse", "settings", struct(), ..
        "winding", struct(), "spectrum", struct(), "inductance", struct(), ..
        "selection", struct(), "learning", struct("valid", %f), "convergence", struct(), ..
        "eventBusy", %f, "windingComputations", 0, "inductanceComputations", 0, ..
        "animation", struct("valid",%f,"frames",list(),"frameCount",0), ..
        "animationFrame",1,"animationPlaying",%f,"animationGeneration",0, ..
        "animationTimer",[],"animationControls",struct(),"animationHighlight",%f);
    fig.visible = "on";
    show_window(fig);
    ew_gui_calculate(%f);
endfunction

function settings = ew_gui_read_settings()
    global ew_app;
    c = ew_app.controls;
    phases = ["A"; "B"; "C"];
    norms = ["phase-sum"; "per-coil"];
    displays = ["real"; "magnitude"];
    modes = ["series"; "individual"];
    references = ["actual"; "full-pitch"; "short-pitch"; "chorded-group"; "q9-group"];
    orders = [20; 40; 60; 120];
    filters = [""; "A"; "B"; "C"];
    settings = struct("slots", ew_gui_number(c.slots, "Nutenzahl Q"), ..
        "polePairs", ew_gui_number(c.polePairs, "Polpaarzahl p"), ..
        "layers", c.layers.value, "coilSpan", ew_gui_number(c.coilSpan, "Spulenweite y"), ..
        "phase", phases(c.phase.value), "maxOrder", orders(c.maxOrder.value), ..
        "normalization", norms(c.normalization.value), "display", displays(c.display.value), ..
        "source", references(c.source.value), "connectionMode", modes(c.connectionMode.value), ..
        "startSlot", ew_gui_number(c.startSlot, "Umfangsschnitt"), ..
        "windingPhase", filters(c.windingPhase.value), "stage", c.stage.value, ..
        "selectedOrder", ew_gui_number(c.selectedOrder, "Raumordnung k"), ..
        "polarity", 1 - 2 * c.polarity.value, "coilId", "", ..
        "learningStage", c.learningStage.value, "sourcePhase", phases(c.sourcePhase.value));
    convergenceOrders = [20; 60; 120; 360; 1200];
    settings.convergenceOrder = convergenceOrders(c.convergenceOrder.value);
    if settings.startSlot <> floor(settings.startSlot) | settings.startSlot < 0 | settings.startSlot > settings.slots then
        error("Der Umfangsschnitt muss 0 oder eine Nutnummer von 1 bis Q sein.");
    end
    settings.animationFrame=ew_app.animationFrame;
    settings.parameters = struct("radiusM", ew_gui_number(c.diameterMm, "Luftspaltdurchmesser") / 2000, ..
        "lengthM", ew_gui_number(c.lengthMm, "Eisenlänge") / 1000, ..
        "gapM", ew_gui_number(c.gapMm, "Wirksamer Luftspalt") / 1000, ..
        "turnsPerCoil", ew_gui_number(c.turns, "Windungszahl"), ..
        "currents", [ew_gui_number(c.currentA, "Strom iA"); ew_gui_number(c.currentB, "Strom iB"); ew_gui_number(c.currentC, "Strom iC")], ..
        "maxOrder", settings.maxOrder, "selectedOrder", settings.selectedOrder, "sampleCount", 361);
    options = c.coil.string;
    if size(options, "*") > 0 then settings.coilId = options(min(c.coil.value, size(options, "*"))); end
endfunction

function coefficient = ew_gui_reverse_coefficient(coefficient)
    fields = ["real"; "imag"; "rawReal"; "rawImag"; "signedRelativeToFundamental"];
    for index = 1:size(fields, "*")
        name = fields(index);
        if isfield(coefficient, name) then coefficient(name) = -coefficient(name); end
    end
    fields = ["phaseDeg"; "rawPhaseDeg"];
    for index = 1:size(fields, "*")
        name = fields(index);
        if isfield(coefficient, name) then coefficient(name) = ew_mod(coefficient(name) + 360, 360) - 180; end
    end
endfunction

function spectrum = ew_gui_spectrum_polarity(spectrum, polarity)
    spectrum.polarity = polarity;
    if polarity > 0 then return; end
    for index = 1:length(spectrum.coefficients)
        spectrum.coefficients(index) = ew_gui_reverse_coefficient(spectrum.coefficients(index));
    end
    if isfield(spectrum, "fundamental") then
        if typeof(spectrum.fundamental) == "st" then spectrum.fundamental = ew_gui_reverse_coefficient(spectrum.fundamental); end
    end
    if isfield(spectrum, "referenceCoefficient") then
        if typeof(spectrum.referenceCoefficient) == "st" then spectrum.referenceCoefficient = ew_gui_reverse_coefficient(spectrum.referenceCoefficient); end
    end
endfunction

// Cache only actual model inputs; changing a coil or view does not rerun the
// winding construction, field reconstruction or convergence summation.
function same = ew_gui_same_fields(previous, current, fields)
    same = %t;
    if typeof(previous) <> "st" then same = %f; return; end
    for k = 1:size(fields, "*")
        name = fields(k);
        if ~isfield(previous, name) then same = %f; return; end
        if ~isequal(previous(name), current(name)) then same = %f; return; end
    end
endfunction

function success = ew_gui_calculate(drawFigures)
    global ew_app;
    if argn(2) < 1 then drawFigures = %f; end
    success = %f;
    try
        settings = ew_gui_read_settings();
        previous = ew_app.settings;
        sameWinding = ew_gui_same_fields(previous, settings, ["slots"; "polePairs"; "layers"; "coilSpan"]);
        if sameWinding then
            winding = ew_app.winding;
        else
            winding = ew_compute_winding(settings.slots, settings.polePairs, settings.layers, settings.coilSpan);
            ew_app.windingComputations = ew_app.windingComputations + 1;
        end
        sameSpectrum = sameWinding & ew_gui_same_fields(previous, settings, ["source"; "maxOrder"; "phase"; "normalization"; "polarity"]);
        if sameSpectrum then
            spectrum = ew_app.spectrum;
        else
            if settings.source == "actual" then
                spectrum = ew_compute_spectrum(winding, settings.maxOrder, settings.phase, settings.normalization);
            else
                spectrum = ew_reference_spectrum(settings.source, settings.maxOrder);
            end
            spectrum = ew_gui_spectrum_polarity(spectrum, settings.polarity);
        end
        sameInductance = sameWinding & ew_gui_same_fields(previous, settings, "parameters");
        if sameInductance then
            inductance = ew_app.inductance;
        else
            try
                inductance = ew_compute_inductance(winding, settings.parameters);
            catch
                // Invalid magnetic dimensions never retain old L values, while
                // the actual physical coil selection remains available.
                inductance = struct("valid", %f, "parameters", settings.parameters, ..
                    "warnings", lasterror(), "matrixH", [], "harmonicMatrixH", [], ..
                    "fundamentalMatrixH", [], "fluxLinkagesWbTurns", [], "energyJ", [], ..
                    "coils", list(), "phases", list(), "groups", list(), ..
                    "segments", list(), "samples", list(), "harmonics", list());
            end
            ew_app.inductanceComputations = ew_app.inductanceComputations + 1;
        end
        coilNames = emptystr(0, 1);
        for index = 1:length(winding.coils)
            coil = winding.coils(index);
            if coil.phase == settings.phase then coilNames($ + 1, 1) = coil.id; end
        end
        if size(coilNames, "*") == 0 then coilNames = "Keine Spule"; end
        selected = find(coilNames == settings.coilId);
        if size(selected, "*") == 0 then selected = 1; else selected = selected(1); end
        ew_app.controls.coil.string = coilNames;
        ew_app.controls.coil.value = selected;
        settings.coilId = coilNames(selected);
        // A stale off-phase filter may not hide the centrally selected coil.
        if settings.windingPhase <> "" & settings.windingPhase <> settings.phase then
            settings.windingPhase = settings.phase;
            ew_app.controls.windingPhase.value = find(["A";"B";"C"] == settings.phase) + 1;
        end
        ew_app.selection = struct("coilId", settings.coilId, "phase", settings.phase, ..
            "selectedOrder", settings.selectedOrder, "order", settings.selectedOrder);
        learning = struct("valid", %f, "warnings", "Für den Lernpfad werden eine gültige Wicklung und Magnetgeometrie benötigt.");
        if winding.valid & inductance.valid & exists("ew_compute_learning") == 1 then
            learning = ew_compute_learning(winding, inductance, settings.coilId, settings.phase, ..
                settings.sourcePhase, settings.selectedOrder, settings.convergenceOrder, ew_app.convergence);
            if learning.valid then ew_app.convergence = learning.convergence; end
        else
            ew_app.convergence = struct();
        end
        ew_app.settings = settings;
        ew_app.winding = winding;
        ew_app.spectrum = spectrum;
        ew_app.inductance = inductance;
        ew_app.learning = learning;
        sameAnimation=sameWinding & ew_gui_same_fields(previous,settings,["coilId";"phase";"selectedOrder"]);
        if ~sameAnimation | ~learning.valid | ~ew_app.animation.valid then
            ew_gui_animation_pause();
            ew_app.animation=ew_compute_animation(learning);
            ew_app.animationFrame=1;settings.animationFrame=1;
            ew_app.settings.animationFrame=1;ew_app.animationHighlight=%f;
        end
        ew_gui_update_report();
        if winding.valid then
            ew_app.controls.status.string = msprintf("Q=%d, p=%d, y=%d | Auswahl %s | k=%d | offene Ansichten sind verknüpft.", ..
                winding.slots, winding.polePairs, winding.coilSpan, settings.coilId, settings.selectedOrder);
        else
            ew_app.controls.status.string = "Zonung berechnet; keine vollständige Wicklung im untersuchten Modell. Hinweise im Protokoll.";
        end
        if winding.valid & ~inductance.valid then
            ew_app.controls.status.string = ew_app.controls.status.string + " Induktivität: Geometrieparameter prüfen.";
        end
        linkedFields = ["phase";"coilId";"selectedOrder";"sourcePhase";"convergenceOrder"; ..
            "source";"maxOrder";"normalization";"polarity";"display";"connectionMode";"startSlot";"windingPhase"];
        linkedChanged = ~sameWinding | ~sameInductance | ~ew_gui_same_fields(previous,settings,linkedFields);
        if linkedChanged then
            ew_gui_refresh_views(drawFigures);
        else
            // Opening a view or changing a lesson stage does not repaint
            // unrelated windows whose selection and data are unchanged.
            if ~ew_gui_same_fields(previous,settings,"stage") then
                if isfield(ew_app.plotFigures,"herleitung") then
                    if ew_gui_figure_alive(ew_app.plotFigures.herleitung) then ew_gui_draw("herleitung",%f); end
                end
            end
            if ~ew_gui_same_fields(previous,settings,"learningStage") then
                if isfield(ew_app.plotFigures,"lernen") then
                    if ew_gui_figure_alive(ew_app.plotFigures.lernen) then ew_gui_draw("lernen",%f); end
                end
            end
            if drawFigures then ew_gui_draw(ew_app.view,%t); end
        end
        success = %t;
    catch
        message = lasterror();
        ew_app.controls.status.string = "Eingabe oder Berechnung prüfen: " + message;
        ew_app.controls.report.string = ["Berechnung nicht verfügbar"; ""; message; ""; "Bitte die Parameter prüfen und erneut berechnen."];
    end
endfunction

function ew_gui_update_report()
    global ew_app;
    settings = ew_app.settings;
    if ew_app.view=="animation" then
        lines=ew_animation_report(ew_app.animation,ew_app.animationFrame);
    else
        lines = ew_gui_report(ew_app.winding, ew_app.spectrum, ew_app.inductance, settings, ew_app.view, ew_app.learning);
    end
    if ew_app.winding.valid then
        selected = ["GEMEINSAME AUSWAHL: " + settings.coilId + " / Strang " + settings.phase + ..
            " / mechanische Raumordnung k=" + string(settings.selectedOrder); ..
            "Quelle für L_ab,k: " + settings.sourcePhase + "; Empfang: " + settings.phase; ""];
        lines = [selected; lines];
    end
    ew_app.controls.report.string = lines;
    select ew_app.view
    case "spektrum" then ew_app.controls.exportCsv.string = "Spektrum CSV";
    case "induktivitaet" then ew_app.controls.exportCsv.string = "Induktivität CSV";
    case "lernen" then ew_app.controls.exportCsv.string = "Lernpfad CSV";
    case "konvergenz" then ew_app.controls.exportCsv.string = "Konvergenz CSV";
    case "animation" then ew_app.controls.exportCsv.string = "Animation CSV";
    else ew_app.controls.exportCsv.string = "Nutbelegung CSV";
    end
endfunction

function lines = ew_gui_report(w, s, ind, settings, view, learning)
    if argn(2) < 6 then learning = struct("valid", %f, "warnings", "Lerndaten nicht verfügbar."); end
    lines = ["WICKLUNGSATELIER / SCILAB"; ..
        msprintf("Q = %d Nuten    p = %d Polpaare    Lagen = %d", w.slots, w.polePairs, w.layers); ..
        msprintf("q = Q/(6p) = %.6g    elektrischer Nutwinkel = %.6g Grad", w.q, w.alphaDeg); ""];
    if ~w.valid then
        lines = [lines; "Keine vollständige Wicklung im festen 60-Grad-Zonenmodell."; w.warnings(:); ..
            "Die Kombination ist damit nicht allgemein physikalisch ausgeschlossen."; ""];
        if view == "spektrum" & s.valid then
            lines = [lines; "Die analytische Spektrumsreferenz ist davon unabhängig:"; s.formula; ""; ..
                " k          Re(Ck)          Im(Ck)           |Ck|"];
            for index = 1:length(s.coefficients)
                c = s.coefficients(index);
                lines($ + 1, 1) = msprintf("%3d    %13.7g    %13.7g    %13.7g", c.order, c.real, c.imag, c.amplitude);
            end
        end
        return;
    end
    lines = [lines; msprintf("Spulenweite y = %d    Spulen insgesamt = %d    kw1 = %.7f", w.coilSpan, length(w.coils), w.metrics.kw); ..
        "Spulenseiten liegen in den Nuten ZWISCHEN den blauen Zähnen."; ""];
    if view == "herleitung" then
        lines = [lines; ew_inductance_derivation(w, ind, settings.phase)]; return;
    end
    if view == "lernen" | view == "konvergenz" then
        lines = [lines; ew_gui_learning_report(learning, settings, view)]; return;
    end
    select view
    case "spektrum" then
        lines = [lines; "RAUMSPEKTRUM"; "Mechanische Ordnung k; elektrische Ordnung nu = k/p."; ..
            "Nutzgrundwelle der tatsächlichen Wicklung: k = p."; ..
            "Ck = Dk/(2 j k), Dk = Summe sign(s) exp(-j k phi_s)."; ..
            "Realteil und Betrag sind verschiedene Darstellungen."; ..
            "Globale Polung: " + string(settings.polarity); ""];
        if isfield(s, "normalizationText") then lines = [lines; s.normalizationText; ""]; end
        if isfield(s, "formula") then lines = [lines; s.formula; ""]; end
        if s.valid then
            lines = [lines; " k          Re(Ck)          Im(Ck)           |Ck|"];
            for index = 1:length(s.coefficients)
                c = s.coefficients(index);
                lines($ + 1, 1) = msprintf("%3d    %13.7g    %13.7g    %13.7g", c.order, c.real, c.imag, c.amplitude);
            end
        end
        if size(s.warnings, "*") > 0 then lines = [lines; ""; s.warnings(:)]; end
    case "induktivitaet" then
        lines = [lines; "LINEARE LUFTSPALT- / HAUPTINDUKTIVITÄT"; ..
            "r = " + ew_gui_format(ind.parameters.radiusM * 1000) + " mm; lFe = " + ew_gui_format(ind.parameters.lengthM * 1000) + " mm"; ..
            "delta_eff = " + ew_gui_format(ind.parameters.gapM * 1000) + " mm; n = " + string(ind.parameters.turnsPerCoil) + " Windungen je Spule"; ..
            "Q und p allein bestimmen keine Induktivität. Beispielwerte anpassen."; ""];
        if ind.valid then
            lines = [lines; "Exakte Luftspaltmatrix L in mH (Zeile: Empfang; Spalte: Quelle)"; "                     A                B                C"];
            names = ["A"; "B"; "C"];
            for a = 1:3
                lines($ + 1, 1) = msprintf("%s       %13.7g    %13.7g    %13.7g", names(a), ind.matrixH(a,1) * 1000, ind.matrixH(a,2) * 1000, ind.matrixH(a,3) * 1000);
            end
            lines = [lines; ""; msprintf("Fourier-Abweichung bis K=%d: %.5f %% (Frobeniusnorm)", settings.maxOrder, 100 * ind.relativeTruncationError); ..
                "Psi = L i: Flussverkettung in mWb, Windungszahl enthalten."];
            for a = 1:3
                lines($ + 1, 1) = msprintf("Psi_%s = %.8g mWb  bei i_%s = %.8g A", names(a), ind.fluxLinkagesWbTurns(a) * 1000, names(a), ind.parameters.currents(a));
            end
            lines = [lines; msprintf("Magnetische Energie = %.8g mJ", ind.energyJ * 1000); ""; ..
                "M = -L/2 gilt für die symmetrische Grundwelle, nicht allgemein für alle Raumharmonischen."; ..
                "Die Gegeninduktivitäten verwenden einen gemeinsamen mechanischen Winkelbezug."; ..
                "Kein Streufluss, keine Sättigung, keine Rotoranisotropie und keine Eisenreluktanz."];
        end
        if size(ind.warnings, "*") > 0 then lines = [lines; ""; ind.warnings(:)]; end
    case "wicklung" then
        lines = [lines; "WICKELSCHEMA / TATSÄCHLICHE SPULEN"; ..
            "Umfangsschnitt 0 = automatisch. Eine Drehung des Schnitts ändert keine Klemmen."; ..
            "Serienverschaltung: Minus einer Spule an Plus der nächsten Spule desselben Strangs."; ..
            "U1/U2: A; V1/V2: B; W1/W2: C. Keine Stern-/Dreieckbrücken."; ""; ..
            " Spule       Plus-Nut/Lage       Minus-Nut/Lage      Weite   Orientierung"];
        for index = 1:length(w.coils)
            coil = w.coils(index);
            lines($ + 1, 1) = msprintf(" %-8s         %3d / %d             %3d / %d           %3d      %+d", coil.id, coil.positiveSlot, coil.positiveLayer, coil.negativeSlot, coil.negativeLayer, coil.span, coil.direction);
        end
    else
        lines = [lines; "NUTENSPANNUNGSSTERN / ZONUNG / STRANGSPANNUNGSSTERN"; ..
            "Natürliche Zonenfolge: +A, -C, +B, -A, +C, -B."; ..
            "Die Strangspannung ist die vorzeichenrichtige Summe aller zugehörigen Nutspannungen."; ..
            "Sterne zeigen elektrische Winkel; das Spektrum zählt mechanische Umfangswellen."; ""];
        for index = 1:length(w.phases)
            phase = w.phases(index);
            lines($ + 1, 1) = msprintf("Strang %s: Summe = %.7g + j %.7g; Winkel = %.5f Grad; kw1 = %.7f", phase.phase, phase.x, phase.y, phase.angleDeg, phase.kw);
        end
        lines = [lines; ""; "Nutbelegung der ersten Lage:"];
        for index = 1:length(w.slotAssignments)
            slot = w.slotAssignments(index);
            lines($ + 1, 1) = msprintf("Nut %3d: %-3s    Winkel %.5f Grad", slot.slot, slot.zone, slot.angleDeg);
        end
        lines = [lines; ""; "Automatisch bedeutet: höchste Grundwellenwirkung im dokumentierten festen Zonenmodell;"; ..
            "bei gleichem Faktor kürzere Spulenweite. Kein allgemeines elektromagnetisches Optimum."];
    end
    if size(w.warnings, "*") > 0 then lines = [lines; ""; w.warnings(:)]; end
endfunction

function lines = ew_gui_learning_report(data, settings, view)
    if ~data.valid then
        lines = ["Lernpfad / Konvergenz nicht verfügbar."; data.warnings(:)]; return;
    end
    a = find(["A";"B";"C"] == settings.phase);
    b = find(["A";"B";"C"] == settings.sourcePhase);
    coil = data.coil;
    lines = ["INTERAKTIVER LERNPFAD: SPULE -> GRUPPE -> STRANG -> L_ab,k"; ..
        msprintf("Spule %s: Plus Nut %d / Lage %d, Minus Nut %d / Lage %d", ..
            coil.id, coil.positiveSlot, coil.positiveLayer, coil.negativeSlot, coil.negativeLayer); ..
        msprintf("Mechanische Ordnung k=%d; elektrische Ordnung nu=k/p=%.8g", data.order, data.electricalOrder); ..
        "Die Feld-/Spulenachsen gehören weiterhin zur Nutzgrundwelle k=p."; ""];
    if settings.source <> "actual" then
        lines = [lines; "Der Lernpfad verwendet die tatsächliche aktuelle Wicklung; die analytische Spektrumsreferenz ist davon unabhängig."; ""];
    end
    if view == "konvergenz" then
        conv = data.convergence;
        exact = conv.exactMatrixH(a,b);
        partial = conv.finalMatrixH(a,b);
        lines = [lines; "KONVERGENZ DER INDUKTIVITÄT"; ..
            "Zeile = Empfang " + settings.phase + ", Spalte = Quelle " + settings.sourcePhase; ..
            "Durchgezogen: endliche gemeinsame Fourier-Summe L_ab(K)."; ..
            "Referenz: stückweise exaktes Integral im linearen Luftspaltmodell."; ..
            "Ein einzelner Gegeninduktivitätsbeitrag darf negativ sein."; ..
            "Die Gesamtmatrix-Abweichung verwendet die Frobeniusnorm und teilt nicht durch ein möglicherweise verschwindendes L_ab."; ""; ..
            "Exakt L_"+settings.phase+settings.sourcePhase+" = "+ew_gui_format(exact*1000,10)+" mH"; ..
            "Bis K="+string(conv.maxOrder)+": "+ew_gui_format(partial*1000,10)+" mH"; ..
            "Matrixfehler = "+ew_gui_format(100*conv.relativeError($),8)+" Prozent"; ..
            "Beitrag der gewählten Ordnung k="+string(data.order)+": "+ew_gui_format(data.selectedContributionH*1000,10)+" mH"; ..
            "K-Konv. begrenzt nur dieses Diagramm; K des Spektrums und die exakte Matrix bleiben unabhängig."];
        return;
    end
    steps = ["1. SPULE: beide tatsächlichen Nutseiten vorzeichenrichtig addieren"; ..
        "2. GRUPPE: alle zugehörigen Spulen komplex addieren"; ..
        "3. STRANG: alle Gruppen im gemeinsamen mechanischen Bezug addieren"; ..
        "4. INDUKTIVITÄT: Empfangs- und Quellstrang derselben Ordnung kreuzen"];
    contributions = list(data.coilContribution, data.groupContribution, data.phaseContribution);
    labels = ["C_Spule,k"; "C_Gruppe,k"; "C_Strang,k"];
    for stage = 1:3
        marker = "";
        if stage == settings.learningStage then marker = "  <--- gewählter Lernschritt"; end
        entry = contributions(stage);
        value = entry.rawFourier;
        voltage = entry.voltageHarmonic;
        lines = [lines; steps(stage)+marker; ..
            labels(stage)+" = "+ew_gui_format(value.real,9)+" + j*("+ew_gui_format(value.imag,9)+")"; ..
            "Spannungssumme bei k: "+ew_gui_format(voltage.real,9)+" + j*("+ew_gui_format(voltage.imag,9)+")"; ..
            "Spulen: "+strcat(entry.coilIds,", "); ""];
    end
    lines = [lines; steps(4); ..
        "Delta L_ab,k = (4*mu0*r*lFe*n^2/(pi*delta)) * Re(C_a,k * conj(C_b,k))"; ..
        "Empfang "+settings.phase+", Quelle "+settings.sourcePhase+": "+ew_gui_format(data.selectedContributionH*1000,10)+" mH"; ..
        "Der Gesamtbeitrag eines Strangs enthält auch die Kreuzprodukte verschiedener Spulen."; ..
        "Spannungsvektoren benutzen exp(+j*k*phi); rohe Fourier-Koeffizienten exp(-j*k*phi)/(2*j*k)."; ..
        "Ein getrenntes Ausrichten jedes Strangs würde die Gegeninduktivität verfälschen."];
endfunction

function fig = ew_gui_plot_figure(view, title)
    global ew_app;
    fig = [];
    if isfield(ew_app.plotFigures, view) then
        try
            candidate = ew_app.plotFigures(view);
            scf(candidate); clf(candidate); fig = candidate;
        catch
            fig = [];
        end
    end
    if size(fig, "*") == 0 then
        fig = figure("figure_name", title, "axes_size", [1100 760], "dockable", "off");
    end
    fig.figure_name = title;
    fig.background = color(255, 255, 255);
    ew_app.plotFigures(view) = fig;
endfunction

function ew_gui_matrix_plot(ind, ax)
    sca(ax);
    ax.axes_visible = ["off" "off" "off"];
    ax.data_bounds = [0 0; 1 1];
    xstring(0.04, 0.90, "Luftspalt-Induktivitätsmatrix / mH");
    gce().font_size = 3;
    names = ["A"; "B"; "C"];
    for a = 1:3
        xstring(0.04, 0.72 - 0.17 * (a - 1), names(a));
        for b = 1:3
            xstring(0.14 + 0.27 * (b - 1), 0.72 - 0.17 * (a - 1), ew_gui_format(ind.matrixH(a, b) * 1000, 7));
        end
    end
    xstring(0.04, 0.18, "Zeilen: Empfang; Spalten: Quelle A, B, C");
    xstring(0.04, 0.07, "Psi = L i; Wmag = 1/2 i transponiert L i");
endfunction

function ew_gui_draw(view, bringToFront)
    global ew_app;
    if argn(2) < 1 then view = ew_app.view; end
    if argn(2) < 2 then bringToFront = %t; end
    if view=="animation" then ew_gui_animation_draw(bringToFront);return;end
    w = ew_app.winding; s = ew_app.spectrum; ind = ew_app.inductance;
    settings = ew_app.settings;
    titles = struct("analyse", "Nutenspannungsstern - Strangstern - Zonung", ..
        "wicklung", "Wickelschema: gemeinsame Spulenauswahl", ..
        "spektrum", "Räumliches Wicklungsspektrum", ..
        "induktivitaet", "Luftspaltinduktivitäten, Spulenachsen und Feldverlauf", ..
        "herleitung", "Mathematische Herleitung der Induktivität", ..
        "lernen", "Interaktiver Lernpfad: Spule - Gruppe - Strang - Induktivität", ..
        "konvergenz", "Konvergenz der Induktivität gegen das exakte Integral");
    fig = ew_gui_plot_figure(view, titles(view));
    selection = ew_app.selection;
    if view=="wicklung" & ew_app.animationHighlight & ew_app.animation.valid then
        frame=ew_app.animation.frames(ew_app.animationFrame);
        selection.activeCoilIds=frame.activeCoilIds;
    end
    select view
    case "analyse" then
        subplot(2, 2, 1); ax1 = gca();
        subplot(2, 2, 2); ax2 = gca();
        subplot(2, 1, 2); ax3 = gca();
        ew_plot_slot_star(w, ax1, selection); ew_plot_phase_star(w, ax2, selection); ew_plot_zone_plan(w, ax3, selection);
    case "wicklung" then
        ew_plot_winding(w, settings.connectionMode, settings.startSlot, settings.windingPhase, gca(), selection);
    case "spektrum" then
        if settings.source == "actual" then
            ew_plot_spectrum(s, settings.display, settings.phase, gca(), selection);
        else
            ew_plot_spectrum(s, settings.display, settings.phase, gca());
        end
    case "induktivitaet" then
        if ind.valid then
            subplot(2, 2, 1); ax1 = gca();
            subplot(2, 2, 2); ax2 = gca();
            subplot(2, 1, 2); ax3 = gca();
            ew_plot_axes(ind, settings.phase, settings.coilId, ax1);
            ew_gui_matrix_plot(ind, ax2);
            ew_plot_field(ind, ax3);
        else
            xstring(0.1, 0.5, "Ohne gültige Magnetgeometrie keine Induktivitätsdiagramme.");
        end
    case "herleitung" then
        ew_plot_derivation(w, ind, settings.stage, settings.phase, gca());
    case "lernen" then
        if ew_app.learning.valid then
            ew_plot_learning(ew_app.learning, settings.learningStage, gca());
        else
            xstring(0.05, 0.6, ew_app.learning.warnings(:));
        end
    case "konvergenz" then
        if ew_app.learning.valid then
            ew_plot_convergence(ew_app.convergence, settings.phase, settings.sourcePhase, settings.selectedOrder, gca());
        else
            xstring(0.05, 0.6, ew_app.learning.warnings(:));
        end
    end
    fig.user_data = struct("ewView", view, "selection", selection, ..
        "coilId", settings.coilId, "selectedOrder", settings.selectedOrder);
    fig.event_handler = "ew_gui_graphic_event";
    fig.event_handler_enable = "on";
    drawnow();
    if bringToFront then
        ew_app.lastFigure = fig;
        show_window(fig);
    end
endfunction

function alive = ew_gui_figure_alive(fig)
    alive = %f;
    try alive = fig.type == "Figure"; catch alive = %f; end
endfunction

function ew_gui_refresh_views(drawCurrent)
    global ew_app;
    if argn(2) < 1 then drawCurrent = %f; end
    views = fieldnames(ew_app.plotFigures);
    for k = 1:size(views, "*")
        view = views(k);
        if drawCurrent & view == ew_app.view then continue; end
        fig = ew_app.plotFigures(view);
        if ~ew_gui_figure_alive(fig) then continue; end
        ew_gui_draw(view, %f);
    end
    if drawCurrent then ew_gui_draw(ew_app.view, %t); end
endfunction

function success = ew_gui_view(view)
    global ew_app;
    allowed = ["analyse"; "wicklung"; "spektrum"; "induktivitaet"; "herleitung"; "lernen"; "konvergenz";"animation"];
    if size(find(allowed == view), "*") == 0 then error("Unbekannte Ergebnisansicht."); end
    ew_app.view = view;
    success = ew_gui_calculate(%t);
endfunction
function ew_gui_analyse(), ew_gui_view("analyse"); endfunction
function ew_gui_winding(), ew_gui_view("wicklung"); endfunction
function ew_gui_spectrum(), ew_gui_view("spektrum"); endfunction
function ew_gui_inductance(), ew_gui_view("induktivitaet"); endfunction
function ew_gui_derivation(), ew_gui_view("herleitung"); endfunction
function ew_gui_learning(), ew_gui_view("lernen"); endfunction
function ew_gui_convergence(), ew_gui_view("konvergenz"); endfunction
function ew_gui_animation()
    ew_gui_view("animation");ew_gui_animation_sync_winding();
endfunction

// Both native controls and diagram hit targets use this single selection path.
function success = ew_gui_selection_changed()
    global ew_app;
    ew_gui_animation_pause();
    success = ew_gui_calculate(%f);
endfunction

function success = ew_gui_filter_changed()
    global ew_app;
    if ew_app.controls.windingPhase.value > 1 then
        ew_app.controls.phase.value = ew_app.controls.windingPhase.value - 1;
    end
    success = ew_gui_selection_changed();
endfunction

function success = ew_gui_select_coil(coilId)
    global ew_app;
    success = %f;
    names = ["A";"B";"C"];
    chosen = [];
    for k = 1:length(ew_app.winding.coils)
        coil = ew_app.winding.coils(k);
        if coil.id == coilId then chosen = coil; break; end
    end
    if isempty(chosen) then return; end
    ew_app.controls.phase.value = find(names == chosen.phase);
    coilNames = emptystr(0,1);
    for k = 1:length(ew_app.winding.coils)
        coil = ew_app.winding.coils(k);
        if coil.phase == chosen.phase then coilNames($+1,1) = coil.id; end
    end
    ew_app.controls.coil.string = coilNames;
    ew_app.controls.coil.value = find(coilNames == coilId);
    if ew_app.controls.windingPhase.value > 1 then
        ew_app.controls.windingPhase.value = find(names == chosen.phase) + 1;
    end
    success = ew_gui_selection_changed();
endfunction

function success = ew_gui_select_order(order)
    global ew_app;
    success = %f;
    if ~isreal(order) | size(order,"*") <> 1 then return; end
    if order < 1 | order > 2000 | order <> floor(order) then return; end
    ew_app.controls.selectedOrder.string = string(order);
    success = ew_gui_selection_changed();
endfunction

// Scilab's native listener emits 3 for a short left click, or 0 when the
// button remains pressed beyond its click-delay window. These are alternative
// notifications for one gesture; the release (-5) and motion (-1) are ignored.
function ew_gui_graphic_event(win, x, y, ibut)
    global ew_app;
    if ibut <> 0 & ibut <> 3 then return; end
    if typeof(ew_app) <> "st" then return; end
    if ew_app.eventBusy then return; end
    ew_app.eventBusy = %t;
    try
        fig = scf(win);
        bestDistance = %inf;
        candidates = list();
        axes = fig.children;
        for k = 1:size(axes,"*")
            ax = axes(k);
            if ax.type <> "Axes" then continue; end
            metadata = ax.user_data;
            if typeof(metadata) <> "st" then continue; end
            if ~isfield(metadata,"ewHits") then continue; end
            sca(ax);
            for j = 1:length(metadata.ewHits)
                hit = metadata.ewHits(j);
                [px, py] = xchange(hit.x, hit.y, "f2i");
                distance = sqrt((double(px)-x)^2+(double(py)-y)^2);
                if distance > 22 then continue; end
                if distance < bestDistance - 2 then
                    bestDistance = distance;
                    candidates = list(hit);
                elseif abs(distance-bestDistance) <= 2 then
                    candidates($+1) = hit;
                end
            end
        end
        if length(candidates) > 0 then
            if typeof(fig.user_data) == "st" then
                if isfield(fig.user_data,"ewView") then ew_app.view = fig.user_data.ewView; end
            end
            hit = candidates(1);
            if hit.ewHit == "order" then
                ew_gui_select_order(hit.order);
            else
                ids = emptystr(0,1);
                for j = 1:length(candidates)
                    candidate = candidates(j);
                    if candidate.ewHit <> "coil" then continue; end
                    if isempty(find(ids == candidate.coilId)) then ids($+1,1) = candidate.coilId; end
                end
                if ~isempty(ids) then
                    current = find(ids == ew_app.settings.coilId);
                    if isempty(current) then next = 1; else next = modulo(current(1),size(ids,"*"))+1; end
                    ew_gui_select_coil(ids(next));
                end
            end
        end
        ew_app.lastFigure = fig;
        show_window(fig);
    catch
        ew_app.controls.status.string = "Diagrammauswahl nicht verfügbar: " + lasterror();
    end
    ew_app.eventBusy = %f;
endfunction

function ew_gui_preset(index)
    global ew_app;
    values = [12 1 1 6; 36 2 1 0; 12 5 2 0; 9 4 2 1];
    if index < 1 | index > 4 | index <> floor(index) then error("Unbekanntes Wicklungsbeispiel."); end
    c = ew_app.controls;
    c.slots.string = string(values(index, 1));
    c.polePairs.string = string(values(index, 2));
    c.layers.value = values(index, 3);
    c.coilSpan.string = string(values(index, 4));
    c.selectedOrder.string = string(values(index, 2));
    c.startSlot.string = "0";
    c.preset.value = index;
    ew_gui_calculate(%f);
endfunction

function ew_gui_apply_preset()
    global ew_app;
    ew_gui_preset(ew_app.controls.preset.value);
endfunction

function ew_gui_current_single()
    global ew_app;
    ew_app.controls.currentA.string = "1";
    ew_app.controls.currentB.string = "0";
    ew_app.controls.currentC.string = "0";
    ew_gui_calculate(%f);
endfunction

function ew_gui_current_balanced()
    global ew_app;
    ew_app.controls.currentA.string = "1";
    ew_app.controls.currentB.string = "-0.5";
    ew_app.controls.currentC.string = "-0.5";
    ew_gui_calculate(%f);
endfunction

function path = ew_gui_choose_file(extension, suggested)
    path = "";
    [name, directory] = uiputfile(["*." + extension, extension + "-Datei"], suggested, "Wicklungsatelier: Export speichern");
    if typeof(name) <> "string" then return; end
    if size(name, "*") == 0 then return; end
    if name == "" then return; end
    path = fullfile(directory, name);
    if convstr(fileext(path), "l") <> "." + extension then path = path + "." + extension; end
endfunction

function ew_gui_save(kind)
    global ew_app;
    ew_gui_animation_pause();
    try
        drawFigures = kind == "svg";
        if ~ew_gui_calculate(drawFigures) then return; end
        w = ew_app.winding;
        stem = msprintf("wicklung-Q%d-p%d", w.slots, w.polePairs);
        extension = kind;
        if kind == "csv" then
            if ew_app.view == "spektrum" then stem = stem + "-spektrum"; end
            if ew_app.view == "induktivitaet" then stem = stem + "-induktivitaet"; end
            if ew_app.view == "lernen" then stem = stem + "-lernpfad"; end
            if ew_app.view == "konvergenz" then stem = stem + "-konvergenz"; end
            if ew_app.view == "animation" then stem = stem + "-animation"; end
        end
        if kind == "report" then extension = "html"; stem = stem + "-herleitung"; end
        path = ew_gui_choose_file(extension, stem + "." + extension);
        if path == "" then return; end
        select kind
        case "csv" then
            select ew_app.view
            case "spektrum" then ew_export_spectrum_csv(ew_app.spectrum, path);
            case "induktivitaet" then ew_export_inductance_csv(ew_app.inductance, path);
            case "lernen" then ew_export_learning_csv(ew_app.learning, path);
            case "konvergenz" then ew_export_convergence_csv(ew_app.convergence, ew_app.settings.phase, ew_app.settings.sourcePhase, path);
            case "animation" then ew_export_animation_csv(ew_app.animation,path);
            else ew_export_csv(w, path, ew_app.settings);
            end
        case "json" then ew_export_json(w, ew_app.spectrum, ew_app.inductance, path, ew_app.settings, ew_app.learning);
        case "svg" then ew_export_svg(ew_app.lastFigure, path);
        case "report" then ew_export_report(w, ew_app.inductance, path, ew_app.learning,ew_app.animationFrame);
        else error("Unbekanntes Exportformat.");
        end
        ew_app.controls.status.string = "Export gespeichert: " + path;
    catch
        ew_app.controls.status.string = "Export nicht verfügbar: " + lasterror();
    end
endfunction
function ew_gui_save_csv(), ew_gui_save("csv"); endfunction
function ew_gui_save_json(), ew_gui_save("json"); endfunction
function ew_gui_save_svg(), ew_gui_save("svg"); endfunction
function ew_gui_save_report(), ew_gui_save("report"); endfunction

// A one-shot native Swing timer queues one Scilab frame at a time. No drawing
// loop blocks the Desktop interpreter: Pause, edits and window closing remain
// ordinary short callbacks. Scilab Desktop includes Java/JIMS already.
function epoch=ew_gui_animation_epoch()
    global EW_ANIMATION_EPOCH;
    if isempty(EW_ANIMATION_EPOCH) then EW_ANIMATION_EPOCH=0;end
    EW_ANIMATION_EPOCH=EW_ANIMATION_EPOCH+1;epoch=EW_ANIMATION_EPOCH;
endfunction

function ew_gui_animation_pause()
    global ew_app;
    if typeof(ew_app)<>"st" then return;end
    if ~isfield(ew_app,"animationPlaying") then return;end
    ew_app.animationPlaying=%f;
    ew_app.animationGeneration=ew_gui_animation_epoch();
    if isfield(ew_app,"animationTimer") then
        if ~isempty(ew_app.animationTimer) then
            try ew_app.animationTimer.stop();catch ignored=%t;end
        end
    end
    if isfield(ew_app,"animationControls") then
        if isfield(ew_app.animationControls,"play") then
            try ew_app.animationControls.play.string="Start";catch ignored=%t;end
        end
    end
endfunction

function delay=ew_gui_animation_delay()
    global ew_app;
    speeds=[1800,900,400];index=2;
    try index=ew_app.animationControls.speed.value;catch ignored=%t;end
    delay=speeds(min(3,max(1,index)));
endfunction

function ew_gui_animation_draw(bringToFront)
    global ew_app;
    if argn(2)<1 then bringToFront=%t;end
    generation=ew_app.animationGeneration;
    fig=[];
    if isfield(ew_app.plotFigures,"animation") then
        if ew_gui_figure_alive(ew_app.plotFigures.animation) then fig=ew_app.plotFigures.animation;end
    end
    if isempty(fig) then
        screen=get(0,"screensize_px");
        windowSize=[min(1120,screen(3)-60),min(850,screen(4)-70)];
        windowPosition=[min(200,max(0,screen(3)-windowSize(1)-20)), ..
            min(120,max(0,screen(4)-windowSize(2)-30))];
        fig=figure("figure_name","Zeigeranimation: Formel - Zahlen - Ergebnis", ..
            "axes_size",windowSize,"menubar","none","toolbar","none", ..
            "infobar_visible","off","dockable","off","visible","off");
        fig.figure_position=windowPosition;fig.background=color(255,255,255);
        fig.tag="wicklungsatelier-animation";
        fig.closerequestfcn="ew_gui_animation_close("+string(fig.figure_id)+");";
        ew_app.plotFigures.animation=fig;
        controls=struct();
        controls.previous=ew_gui_button(fig,"Zurück","ew_gui_animation_step(-1);",[0.02,0.018,0.105,0.041]);
        controls.play=ew_gui_button(fig,"Start","ew_gui_animation_toggle();",[0.139,0.018,0.105,0.041]);
        controls.next=ew_gui_button(fig,"Weiter","ew_gui_animation_step(1);",[0.258,0.018,0.105,0.041]);
        controls.restart=ew_gui_button(fig,"Anfang","ew_gui_animation_restart();",[0.377,0.018,0.105,0.041]);
        ew_gui_label(fig,"Tempo",[0.503,0.029,0.06,0.024],9);
        controls.speed=ew_gui_popup(fig,["Langsam";"Normal";"Schnell"],2,[0.563,0.018,0.12,0.041],"ew-animation-speed");
        controls.speed.callback="ew_gui_animation_speed_changed();";
        controls.progress=ew_gui_label(fig,"",[0.705,0.019,0.275,0.04],10);
        ew_app.animationControls=controls;
        fig.visible="on";
    end
    scf(fig);
    // Keep buttons alive, including their focus, while replacing only the plot.
    children=fig.children;
    for n=1:size(children,"*")
        if children(n).type=="Axes" then delete(children(n));end
    end
    ax=newaxes();ax.axes_bounds=[0,0,1,0.91];
    ew_plot_animation(ew_app.animation,ew_app.animationFrame,ax);
    // Native drawing may dispatch a close/Pause callback. Its newer state wins.
    if generation<>ew_app.animationGeneration then return;end
    if ~ew_gui_figure_alive(fig) then return;end
    if ew_app.animation.valid then
        ew_app.animationHighlight=%t;
        ew_app.animationControls.progress.string=msprintf("Schritt %d / %d",ew_app.animationFrame,ew_app.animation.frameCount);
        enabled="on";
    else
        ew_app.animationHighlight=%f;
        ew_app.animationControls.progress.string="Keine gültige Lernfolge";enabled="off";
    end
    for name=["previous","play","next","restart"]
        control=ew_app.animationControls(name);control.enable=enabled;
    end
    if ew_app.animationPlaying then ew_app.animationControls.play.string="Pause";else ew_app.animationControls.play.string="Start";end
    fig.user_data=struct("ewView","animation","coilId",ew_app.settings.coilId, ..
        "selectedOrder",ew_app.settings.selectedOrder,"animationFrame",ew_app.animationFrame, ..
        "selection",ew_app.selection);
    fig.event_handler="ew_gui_graphic_event";fig.event_handler_enable="on";
    drawnow();
    if bringToFront then ew_app.lastFigure=fig;show_window(fig);end
endfunction

function ew_gui_animation_sync_winding()
    global ew_app;
    if isfield(ew_app.plotFigures,"wicklung") then
        if ew_gui_figure_alive(ew_app.plotFigures.wicklung) then ew_gui_draw("wicklung",%f);end
    end
endfunction

// A direct control action selects its own result view and export target.
// Automatic ticks only refresh data and never change the user's active view.
function ew_gui_animation_activate()
    global ew_app;
    ew_app.view="animation";
    if isfield(ew_app.plotFigures,"animation") then
        if ew_gui_figure_alive(ew_app.plotFigures.animation) then
            ew_app.lastFigure=ew_app.plotFigures.animation;
        end
    end
    ew_gui_update_report();
endfunction

function success=ew_gui_animation_set_frame(index,stopFirst,generation)
    global ew_app;
    if argn(2)<2 then stopFirst=%t;end
    success=%f;
    if stopFirst then
        ew_gui_animation_pause();ew_gui_animation_activate();
    end
    if argn(2)<3 then generation=ew_app.animationGeneration;end
    if generation<>ew_app.animationGeneration then return;end
    if ~ew_app.animation.valid then return;end
    if size(index,"*")<>1 | ~isreal(index) then return;end
    if isnan(index)|isinf(index) then return;end
    index=max(1,min(ew_app.animation.frameCount,floor(index)));
    ew_app.animationFrame=index;ew_app.settings.animationFrame=index;
    ew_gui_animation_draw(%f);
    if generation<>ew_app.animationGeneration then return;end
    if stopFirst then ew_gui_animation_activate();end
    ew_gui_animation_sync_winding();
    if generation<>ew_app.animationGeneration then return;end
    if ew_app.view=="animation" then ew_gui_update_report();end
    success=%t;
endfunction

function ew_gui_animation_step(delta)
    global ew_app;
    ew_gui_animation_set_frame(ew_app.animationFrame+delta);
endfunction

function ew_gui_animation_restart()
    ew_gui_animation_set_frame(1);
endfunction

function ew_gui_animation_toggle()
    global ew_app;
    ew_gui_animation_activate();
    if ew_app.animationPlaying then ew_gui_animation_pause();return;end
    // Apply pending edits before starting; failed inputs must not animate a
    // previous valid machine. Unchanged inputs reuse the existing model cache.
    if ~ew_gui_calculate(%f) then return;end
    if ~ew_app.animation.valid then return;end
    if ~isfield(ew_app.plotFigures,"animation") then ew_gui_animation();end
    if ~ew_gui_figure_alive(ew_app.plotFigures.animation) then ew_gui_animation();end
    if ew_app.animationFrame>=ew_app.animation.frameCount then ew_gui_animation_set_frame(1);end
    ew_app.animationPlaying=%t;
    ew_app.animationGeneration=ew_gui_animation_epoch();
    ew_app.animationControls.play.string="Pause";
    try
        jimport org.scilab.modules.gui.events.callback.ScilabCallBack;
        command=msprintf("ew_gui_animation_tick(%.0f);",ew_app.animationGeneration);
        listener=ScilabCallBack.create(command);
        ew_app.animationTimer=jnewInstance("javax.swing.Timer",int32(ew_gui_animation_delay()),listener);
        ew_app.animationTimer.setRepeats(%f);
        ew_app.animationTimer.start();
    catch
        ew_gui_animation_pause();
        ew_app.controls.status.string="Automatische Wiedergabe nicht verfügbar: "+lasterror()+" Einzelschritte bleiben bedienbar.";
    end
endfunction

function ew_gui_animation_tick(generation)
    global ew_app;
    if typeof(ew_app)<>"st" then return;end
    if ~isfield(ew_app,"animationGeneration") then return;end
    if generation<>ew_app.animationGeneration | ~ew_app.animationPlaying then return;end
    if ~ew_gui_figure_alive(ew_app.figure) then ew_gui_animation_pause();return;end
    if ~isfield(ew_app.plotFigures,"animation") then ew_gui_animation_pause();return;end
    if ~ew_gui_figure_alive(ew_app.plotFigures.animation) then
        ew_gui_animation_pause();ew_app.animationHighlight=%f;ew_gui_animation_sync_winding();return;
    end
    if ~ew_app.animation.valid then ew_gui_animation_pause();return;end
    if ew_app.animationFrame>=ew_app.animation.frameCount then ew_gui_animation_pause();return;end
    try
        ew_gui_animation_set_frame(ew_app.animationFrame+1,%f,generation);
        if generation<>ew_app.animationGeneration | ~ew_app.animationPlaying then return;end
        if ew_app.animationFrame>=ew_app.animation.frameCount then
            ew_gui_animation_pause();
        elseif ~isempty(ew_app.animationTimer) then
            ew_app.animationTimer.setInitialDelay(int32(ew_gui_animation_delay()));
            ew_app.animationTimer.restart();
        end
    catch
        message=lasterror();
        // Closing, pausing or replacing the app can invalidate a handle while
        // its previous frame is drawing. Never change the newer app state.
        if typeof(ew_app)<>"st" then return;end
        if ~isfield(ew_app,"animationGeneration") then return;end
        if generation<>ew_app.animationGeneration then return;end
        if ~ew_gui_figure_alive(ew_app.plotFigures.animation) then
            ew_gui_animation_pause();ew_app.animationHighlight=%f;
            ew_gui_animation_sync_winding();return;
        end
        ew_gui_animation_pause();
        try ew_app.controls.status.string="Animation angehalten: "+message;catch ignored=%t;end
    end
endfunction

function ew_gui_animation_speed_changed()
    global ew_app;
    ew_gui_animation_activate();
    if ew_app.animationPlaying & ~isempty(ew_app.animationTimer) then
        ew_app.animationTimer.setInitialDelay(int32(ew_gui_animation_delay()));
        ew_app.animationTimer.restart();
    end
endfunction

function ew_gui_animation_close(figureId)
    global ew_app;
    current=%f;
    if typeof(ew_app)=="st" then
        if isfield(ew_app,"plotFigures") then
            if isfield(ew_app.plotFigures,"animation") then
                if ew_gui_figure_alive(ew_app.plotFigures.animation) then
                    current=ew_app.plotFigures.animation.figure_id==figureId;
                end
            end
        end
    end
    if current then
        ew_gui_animation_pause();ew_app.animationHighlight=%f;
        delete(ew_app.plotFigures.animation);ew_app.animationControls=struct();
        ew_gui_animation_sync_winding();
    else
        if ~isempty(find(winsid()==figureId)) then
            try delete(scf(figureId));catch ignored=%t;end
        end
    end
endfunction
