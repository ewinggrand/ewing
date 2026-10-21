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
    settings = struct("startSlot",3,"connectionMode","series","display","real", ..
        "phase","A","sourcePhase","B","coilId","A2","selectedOrder",4,"convergenceOrder",20,"animationFrame",4);
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
    ew_test_assert(parsed.learning.valid & parsed.learning.coilId=="A2", "JSON erhält die verknüpfte Spulenauswahl");
    ew_test_assert(parsed.learning.sourcePhase=="B" & parsed.learning.order==4, "JSON erhält Quellenstrang und mechanische Raumordnung");
    ew_test_close(parsed.convergence.finalMatrixH, d.harmonicMatrixH, 1d-14, "JSON-Konvergenz stimmt mit bestehender Fourier-Matrix überein");
    ew_test_assert(parsed.version=="1.2", "JSON benennt native Edition 1.2");
    ew_test_assert(parsed.animation.valid & parsed.animation.coilId=="A2", "JSON enthält tatsächliche Zeigeranimation");
    ew_test_assert(parsed.animation.currentFrame==4, "JSON erhält den gewählten Animationsschritt");
    finalFrame=parsed.animation.frames(parsed.animation.frameCount);
    ew_test_close([finalFrame.result.real;finalFrame.result.imag], ..
        [parsed.learning.phaseContribution.voltageHarmonic.real;parsed.learning.phaseContribution.voltageHarmonic.imag], ..
        1d-13, "JSON-Animationsende ist die gemeinsame Strangspannungssumme");
    csv = strcat(mgetl(directory+"/winding.csv"), ascii(10));
    ew_test_assert(size(strindex(csv,"U1;"),"*") == 1, "CSV enthält tatsächlichen U1-Anschluss");
    ew_test_assert(size(strindex(csv,"Umfangsschnitt;3"),"*") == 1, "CSV enthält den gewählten Schnitt");
    ew_test_assert(size(mgetl(directory+"/spectrum.csv"),"*") == 21, "Spektrums-CSV enthält alle 20 Ordnungen");
    html = strcat(mgetl(directory+"/derivation.html"),ascii(10));
    ew_test_assert(size(strindex(html,"<section "),"*") == 6, "HTML enthält alle sechs Etappen");
        defaultAnimation=ew_compute_animation(ew_export_learning_context(w,d,struct()));
    ew_test_assert(size(strindex(html,"<math "),"*") == 30+3*defaultAnimation.frameCount, "HTML enthält Grundherleitung und alle gesetzten Rechenschritte der Animation");
    ew_test_assert(isempty(strindex(html,"<script")), "HTML-Bericht benötigt kein JavaScript oder CDN");
    ew_test_assert(size(strindex(html,"Exakte Luftspalt-Induktivitätsmatrix"),"*") == 1, "HTML enthält die tatsächliche Matrix");
    learning = ew_compute_learning(w,d,"A2","A","B",4,20);
    ew_export_report(w,d,directory+"/selected.html",learning,4);
    selectedHtml = strcat(mgetl(directory+"/selected.html"),ascii(10));
    ew_test_assert(size(strindex(selectedHtml,"data-learning-coil=""A2"""),"*")==1, "HTML markiert die ausgewählte tatsächliche Spule");
    ew_test_assert(size(strindex(selectedHtml,"data-animation-frame=""4"""),"*")==1, "HTML erhält den gewählten Animationsschritt");
    animation=ew_compute_animation(learning);
    ew_test_assert(size(strindex(selectedHtml,"<details id=""animation-"),"*")==animation.frameCount, "HTML enthält die vollständige aufklappbare Summenkette");
    ew_test_assert(size(strindex(selectedHtml,"<details id=""animation-4"" open>"),"*")==1, "HTML öffnet genau den ausgewählten Rechenschritt");
    ew_export_animation_csv(animation,directory+"/animation.csv");
    ew_test_assert(size(mgetl(directory+"/animation.csv"),"*")==animation.frameCount+2, "Animations-CSV enthält alle Rechenschritte");
    ew_test_error("ew_export_report(w,d,directory+''/invalid.html'',learning,0)", "Ungültigen Animationsschritt im Bericht abweisen");
    ew_export_learning_csv(learning,directory+"/learning.csv");
    ew_export_convergence_csv(learning.convergence,"A","B",directory+"/convergence.csv");
    ew_test_assert(size(mgetl(directory+"/convergence.csv"),"*")==22, "Konvergenz-CSV enthält alle 20 Teilmatrizen");
    ew_test_assert(size(strindex(strcat(mgetl(directory+"/learning.csv"),""),"Quellenstrang"),"*")>0, "Lern-CSV benennt Quellen- und Empfangsstrang");
    for name = ["winding.csv","spectrum.csv","inductance.csv","results.json","derivation.html","selected.html","learning.csv","convergence.csv","animation.csv"]
        mdelete(directory+"/"+name);
    end
    rmdir(directory);
    mdelete(temporaryFile);
    count = EW_TEST_ASSERTIONS-before;
endfunction
