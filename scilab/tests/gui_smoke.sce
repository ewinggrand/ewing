// Optional native desktop regression. Requires Scilab with graphics and Java,
// plus a display (on Linux, xvfb-run may supply one). This script exits with a
// nonzero status if any calculation, callback, plot or export fails.

function ew_gui_test(condition, label)
    global EW_GUI_TEST_COUNT;
    EW_GUI_TEST_COUNT = EW_GUI_TEST_COUNT + 1;
    if ~and(condition) then error("GUI-ASSERTION: " + label); end
endfunction

function ew_gui_test_view(view)
    global ew_app;
    okay = ew_gui_view(view);
    if ~okay then error("Ansicht " + view + ": " + ew_app.controls.status.string); end
    ew_gui_test(okay, "Native Ansicht " + view);
endfunction

try
    directory = get_absolute_file_path("gui_smoke.sce");
    exec(directory + "../loader.sce", -1);
    global EW_GUI_TEST_COUNT ew_app;
    EW_GUI_TEST_COUNT = 0;
    ew_gui();
    ew_gui_test(ew_app.winding.valid, "Startberechnung ist gültig");
    ew_gui_test(size(ew_app.figure.children, "*") >= 25, "Native Eingabefelder und Schaltflächen erstellt");

    expectedQ = [12 36 12 9];
    expectedP = [1 2 5 4];
    for preset = 1:4
        ew_gui_preset(preset);
        ew_gui_test(ew_app.winding.valid, "Beispiel " + string(preset));
        ew_gui_test(ew_app.winding.slots == expectedQ(preset), "Nutenzahl aus Bedienelement");
        ew_gui_test(ew_app.winding.polePairs == expectedP(preset), "Polpaarzahl aus Bedienelement");
        ew_gui_test(ew_app.inductance.valid, "Induktivität des Beispiels");
    end

    ew_gui_test_view("analyse");
    ew_gui_test_view("wicklung");
    ew_gui_test_view("spektrum");
    ew_gui_test_view("induktivitaet");
    for stage = 1:6
        ew_app.controls.stage.value = stage;
        ew_gui_test_view("herleitung");
        ew_gui_test(size(ew_app.lastFigure.children, "*") > 0, "Gesetzte Formeln in Etappe " + string(stage));
    end

    // Full-string parsing rejects executable expressions instead of evaluating.
    ew_app.controls.slots.string = "12;exit()";
    ew_gui_test(~ew_gui_calculate(), "Keine Auswertung von Eingabetext als Scilab-Code");
    ew_app.controls.slots.string = "9";
    ew_gui_test(ew_gui_calculate(), "Erholung nach ungültiger Eingabe");
    ew_app.controls.turns.string = "20";
    ew_gui_test(ew_gui_calculate(), "Neue Windungszahl übernommen");
    ew_gui_test(abs(ew_app.inductance.matrixH(1,1) - 0.00506883386525083) < 1d-12, "Quadratische Skalierung mit der Windungszahl");
    ew_gui_current_balanced();
    ew_gui_test(ew_app.settings.parameters.currents == [1; -0.5; -0.5], "Symmetrischer Strom-Augenblick");
    ew_app.controls.gapMm.string = "0";
    ew_gui_test_view("analyse");
    ew_gui_test(~ew_app.inductance.valid, "Unzulässiger Luftspalt erzeugt keine alten Induktivitätswerte");
    ew_app.controls.gapMm.string = "0,5";
    ew_gui_test(ew_gui_calculate(), "Dezimalkomma wird akzeptiert");
    ew_gui_test(ew_app.inductance.parameters.gapM == 0.0005, "Luftspalt in SI umgerechnet");
    ew_app.controls.gapMm.string = "1";

    // A common display polarity changes signed coefficients, not magnitudes.
    ew_app.controls.polarity.value = 1;
    ew_app.controls.source.value = 2;
    ew_gui_test_view("spektrum");
    ew_gui_test(abs(ew_app.spectrum.coefficients(1).real + 1) < 1d-12, "Gemeinsame Referenzpolung");
    ew_gui_test(ew_app.spectrum.coefficients(1).phaseDeg == -180, "Phasenlage nach Umpolung");
    ew_app.controls.slots.string = "18";
    ew_app.controls.polePairs.string = "2";
    ew_app.controls.layers.value = 1;
    ew_app.controls.coilSpan.string = "0";
    ew_gui_test_view("spektrum");
    ew_gui_test(~ew_app.winding.valid & ew_app.spectrum.valid, "Analytische Referenz unabhängig von ungültiger Wicklung");

    ew_gui_preset(4);
    ew_app.controls.source.value = 1;
    ew_app.controls.polarity.value = 0;
    ew_app.controls.startSlot.string = "7";
    ew_app.controls.connectionMode.value = 2;
    ew_gui_test_view("wicklung");
    ew_gui_test(ew_app.settings.startSlot == 7 & ew_app.settings.connectionMode == "individual", "Manueller Umfangsschnitt und Einzelspulenmodus");

    output = fullfile(TMPDIR, "wicklungsatelier-gui-smoke");
    if ~isdir(output) then mkdir(output); end
    csvPath = fullfile(output, "wicklung.csv");
    jsonPath = fullfile(output, "berechnung.json");
    svgPath = fullfile(output, "wicklung.svg");
    reportPath = fullfile(output, "herleitung.html");
    spectrumPath = fullfile(output, "spektrum.csv");
    inductancePath = fullfile(output, "induktivitaet.csv");
    ew_export_csv(ew_app.winding, csvPath, ew_app.settings);
    ew_export_json(ew_app.winding, ew_app.spectrum, ew_app.inductance, jsonPath, ew_app.settings);
    ew_export_svg(ew_app.lastFigure, svgPath);
    ew_export_report(ew_app.winding, ew_app.inductance, reportPath);
    ew_export_spectrum_csv(ew_app.spectrum, spectrumPath);
    ew_export_inductance_csv(ew_app.inductance, inductancePath);
    exports = [csvPath; jsonPath; svgPath; reportPath; spectrumPath; inductancePath];
    for index = 1:size(exports, "*")
        ew_gui_test(isfile(exports(index)), "Exportdatei vorhanden");
        ew_gui_test(size(mgetl(exports(index)), "*") > 0, "Exportdatei ist nicht leer");
    end
    ew_gui_test(size(grep(mgetl(svgPath), "<svg"), "*") > 0, "SVG enthält ein Diagramm");
    ew_gui_test(size(grep(mgetl(reportPath), "<math"), "*") > 0, "Offline-Bericht enthält gesetztes MathML");
    mprintf("GUI-SMOKE PASSED: %d Prüfungen, fünf Ansichten und sechs Herleitungsetappen.\n", EW_GUI_TEST_COUNT);
    mprintf("Temporäre Exportdateien: %s\n", output);
    exit(0);
catch
    mprintf("GUI-SMOKE FAILED: %s\n", lasterror());
    if typeof(ew_app) == "st" then
        if isfield(ew_app, "controls") then mprintf("Status: %s\n", ew_app.controls.status.string); end
    end
    exit(1);
end
