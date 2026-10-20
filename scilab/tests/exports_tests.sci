// Integration checks for the actual native writers and bundled mathematics.
function count = ew_test_exports()
    global EW_TEST_ASSERTIONS;
    before = EW_TEST_ASSERTIONS;
    temporaryFile = tempname();
    directory = temporaryFile + "-exports";
    mkdir(directory);
    ew_test_assert(isdir(directory), "Temporärer Exportordner wurde angelegt");
    w = ew_compute_winding(9, 4, 2, 1);
    s = ew_compute_spectrum(w, 20, "A", "phase-sum");
    d = ew_compute_inductance(w, struct("maxOrder",20,"sampleCount",16));
    settings = struct("startSlot",3,"connectionMode","series","display","real");
    ew_export_csv(w, directory+"/winding.csv", settings);
    ew_export_spectrum_csv(s, directory+"/spectrum.csv");
    ew_export_inductance_csv(d, directory+"/inductance.csv");
    ew_export_json(w, s, d, directory+"/results.json", settings);
    ew_export_report(w, d, directory+"/derivation.html");
    parsed = fromJSON(strcat(mgetl(directory+"/results.json"), ""));
    ew_test_assert(parsed.winding.slots == 9, "JSON erhält die tatsächliche Nutenzahl");
    ew_test_assert(parsed.settings.startSlot == 3, "JSON erhält den eingestellten Schnitt");
    ew_test_assert(parsed.windingLayout.startSlot == 3, "JSON zeichnet tatsächlich den gewählten Schnitt");
    ew_test_close(parsed.inductance.matrixH, d.matrixH, 1d-15, "JSON erhält die vollständige Induktivitätsmatrix");
    ew_test_close(parsed.inductance.fluxLinkagesWbTurns, d.fluxLinkagesWbTurns, 1d-15, "JSON erhält Flussverkettung und Einheiten");
    csv = strcat(mgetl(directory+"/winding.csv"), ascii(10));
    ew_test_assert(size(strindex(csv,"U1;"),"*") == 1, "CSV enthält tatsächlichen U1-Anschluss");
    ew_test_assert(size(strindex(csv,"Umfangsschnitt;3"),"*") == 1, "CSV enthält den gewählten Schnitt");
    ew_test_assert(size(mgetl(directory+"/spectrum.csv"),"*") == 21, "Spektrums-CSV enthält alle 20 Ordnungen");
    html = strcat(mgetl(directory+"/derivation.html"),ascii(10));
    ew_test_assert(size(strindex(html,"<section "),"*") == 6, "HTML enthält alle sechs Etappen");
    ew_test_assert(size(strindex(html,"<math "),"*") == 21, "HTML enthält alle gesetzten MathML-Formeln");
    ew_test_assert(isempty(strindex(html,"<script")), "HTML-Bericht benötigt kein JavaScript oder CDN");
    ew_test_assert(size(strindex(html,"Exakte Luftspalt-Induktivitätsmatrix"),"*") == 1, "HTML enthält die tatsächliche Matrix");
    for name = ["winding.csv","spectrum.csv","inductance.csv","results.json","derivation.html"]
        mdelete(directory+"/"+name);
    end
    rmdir(directory);
    mdelete(temporaryFile);
    count = EW_TEST_ASSERTIONS-before;
endfunction
