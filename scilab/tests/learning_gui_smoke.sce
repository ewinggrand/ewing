// Native integration test for shared coil selection and the interactive lesson.
// Requires the full Scilab graphics/Java runtime and a display.
function ew_lgui_assert(condition, label)
    global EW_LEARNING_GUI_TESTS;
    EW_LEARNING_GUI_TESTS = EW_LEARNING_GUI_TESTS + 1;
    if ~and(condition) then error("LEARNING GUI: " + label); end
endfunction

function ew_lgui_same_selection(coilId)
    global ew_app;
    views = fieldnames(ew_app.plotFigures);
    for k = 1:size(views,"*")
        fig = ew_app.plotFigures(views(k));
        if ~ew_gui_figure_alive(fig) then continue; end
        ew_lgui_assert(fig.user_data.coilId == coilId, "Gemeinsame Auswahl in "+views(k));
        ew_lgui_assert(fig.user_data.selectedOrder == ew_app.settings.selectedOrder, "Gemeinsame Raumordnung in "+views(k));
    end
endfunction

try
    directory = get_absolute_file_path("learning_gui_smoke.sce");
    exec(directory+"../loader.sce",-1);
    global ew_app EW_LEARNING_GUI_TESTS;
    EW_LEARNING_GUI_TESTS = 0;
    ew_gui();
    ew_gui_preset(4);
    ew_lgui_assert(ew_app.learning.valid, "Lernmodell startet für Q9/p4");
    for view = ["analyse","wicklung","spektrum","induktivitaet","herleitung","lernen","konvergenz"]
        ew_lgui_assert(ew_gui_view(view), "Ansicht "+view);
    end
    windingCalls = ew_app.windingComputations;
    magneticCalls = ew_app.inductanceComputations;
    exact = ew_app.inductance.matrixH;
    ew_lgui_assert(ew_gui_select_coil("A2"), "Zentrale Spulenauswahl A2");
    ew_lgui_assert(ew_app.selection.coilId == "A2", "Zentrale Auswahl gespeichert");
    ew_lgui_assert(ew_app.learning.coil.id == "A2", "Lernpfad folgt Spule");
    ew_lgui_assert(ew_app.learning.convergenceCached, "Konvergenz bei Spulenauswahl wiederverwendet");
    ew_lgui_assert(ew_app.windingComputations == windingCalls, "Auswahl konstruiert Wicklung nicht erneut");
    ew_lgui_assert(ew_app.inductanceComputations == magneticCalls, "Auswahl integriert Luftspalt nicht erneut");
    ew_lgui_same_selection("A2");
    ew_app.controls.sourcePhase.value = 2;
    ew_lgui_assert(ew_gui_selection_changed(), "Erregenden Strang umschalten");
    ew_lgui_assert(ew_app.learning.sourcePhase == "B", "Quelle und Empfang getrennt");
    ew_lgui_assert(ew_app.learning.selectedContributionH < 0, "Vorzeichenbehafteter Gegeninduktivitätsbeitrag");
    axesBefore = zeros(3,1);
    for a=1:3, axesBefore(a)=ew_app.inductance.phases(a).axisRad; end
    ew_lgui_assert(ew_gui_select_order(8), "Einzelne Raumharmonische auswählen");
    ew_lgui_assert(ew_app.learning.order == 8, "Lernpfad benutzt gewählte Ordnung");
    ew_lgui_assert(ew_app.learning.convergenceCached, "K-Auswahl ändert keine Konvergenzdaten");
    for a=1:3
        ew_lgui_assert(abs(axesBefore(a)-ew_app.inductance.phases(a).axisRad)<1d-13, "Grundwellenachsen bleiben bei k-Auswahl fest");
    end
    ew_lgui_assert(max(abs(exact-ew_app.inductance.matrixH))<1d-13, "K-Auswahl verändert exakte Matrix nicht");
    ew_lgui_same_selection("A2");
    for stage=1:4
        ew_app.controls.learningStage.value=stage;
        ew_lgui_assert(ew_gui_view("lernen"), "Lernschritt "+string(stage));
        ew_lgui_assert(~isempty(grep(ew_app.controls.report.string,"C_Spule,k")), "Lernprotokoll erhält tatsächliche Lerndaten");
    end
    ew_app.controls.windingPhase.value=2;
    ew_lgui_assert(ew_gui_select_coil("B3"), "Spule aus anderem Strang auswählen");
    ew_lgui_assert(ew_app.settings.phase == "B", "Empfangsstrang folgt tatsächlicher Spule");
    ew_lgui_assert(ew_app.settings.sourcePhase == "B", "Quellstrang bleibt unabhängig erhalten");
    ew_lgui_assert(ew_app.settings.windingPhase == "B", "Alter Phasenfilter versteckt ausgewählte Spule nicht");
    ew_lgui_same_selection("B3");
    c=ew_app.learning.coil;
    beforeSides=[c.positiveSlot,c.positiveLayer,c.negativeSlot,c.negativeLayer];
    ew_app.controls.startSlot.string="7";
    ew_lgui_assert(ew_gui_selection_changed(), "Umfangsschnitt drehen");
    ew_lgui_assert(ew_app.selection.coilId=="B3", "Schnittdrehung erhält physische Spulenauswahl");
    c=ew_app.learning.coil;
    ew_lgui_assert([c.positiveSlot,c.positiveLayer,c.negativeSlot,c.negativeLayer]==beforeSides, "Schnittdrehung erhält Nutlagen und Polungen");
    // Exercise the real plot hit metadata and pixel-to-data event path.
    ew_app.controls.windingPhase.value=1;
    ew_lgui_assert(ew_gui_selection_changed(), "Alle Stränge für Diagrammklick sichtbar");
    ew_lgui_assert(ew_gui_view("wicklung"), "Wickelschema für Diagrammklick");
    fig=ew_app.plotFigures.wicklung;
    hitFound=%f;
    children=fig.children;
    for axisIndex=1:size(children,"*")
        ax=children(axisIndex);
        if ax.type<>"Axes" then continue; end
        metadata=ax.user_data;
        if typeof(metadata)<>"st" then continue; end
        if ~isfield(metadata,"ewHits") then continue; end
        for hitIndex=1:length(metadata.ewHits)
            hit=metadata.ewHits(hitIndex);
            if hit.ewHit=="coil" & hit.coilId=="A2" then
                sca(ax); hitFound=%t; break;
            end
        end
        if hitFound then break; end
    end
    ew_lgui_assert(hitFound, "Tatsächliche Spule besitzt Diagramm-Hit-Ziel");
    xs2png(fig,fullfile(TMPDIR,"wicklungsatelier-hit-test.png"));
    [px,py]=xchange(hit.x,hit.y,"f2i");
    ew_gui_graphic_event(fig.figure_id,double(px),double(py),0);
    ew_lgui_assert(ew_app.settings.coilId=="A2", "Diagrammklick wählt die tatsächliche Spule");
    ew_lgui_assert(ew_app.settings.phase=="A", "Diagrammklick synchronisiert den Empfangsstrang");
    ew_lgui_assert(ew_app.lastFigure==fig & ew_app.view=="wicklung", "SVG-Export folgt dem angeklickten Diagramm");
    // The native listener reports 3 for a short click, 0 for a held press.
    // Both must select the same physical slot/layer target.
    ew_lgui_assert(ew_gui_select_coil("B3"), "Auswahl vor nativem Kurzklick wechseln");
    ew_gui_graphic_event(fig.figure_id,double(px),double(py),3);
    ew_lgui_assert(ew_app.settings.coilId=="A2", "Nativer Kurzklick-Code wählt tatsächliche Spule");
    ew_lgui_assert(ew_app.settings.phase=="A", "Nativer Kurzklick synchronisiert den Strang");
    // Closing a linked view must not recreate it on the next selection.
    deleted=ew_app.plotFigures.analyse;
    delete(deleted);
    beforeWindows=size(winsid(),"*");
    ew_lgui_assert(ew_gui_select_coil("A1"), "Weitere Auswahl nach Schließen einer Ansicht");
    ew_lgui_assert(size(winsid(),"*")==beforeWindows, "Geschlossene Ansicht bleibt geschlossen");
    ew_lgui_assert(~ew_gui_figure_alive(deleted), "Gelöschter Fensterhandle wird übersprungen");
    // A native left release (-5), movement and other buttons never cycle
    // overlapped rays a second time.
    beforeSelection=ew_app.settings.coilId;
    for ignoredCode=[-5,-1,1,2,4,5,10,1003]
        ew_gui_graphic_event(ew_app.plotFigures.wicklung.figure_id,double(px),double(py),ignoredCode);
    end
    ew_lgui_assert(ew_app.settings.coilId==beforeSelection, "Loslassen ändert Auswahl nicht");
    ew_app.controls.gapMm.string="0";
    ew_lgui_assert(ew_gui_calculate(), "Unabhängige Wicklung bei ungültigem Luftspalt erhalten");
    ew_lgui_assert(ew_app.winding.valid & ~ew_app.inductance.valid, "Ungültige Magnetgeometrie isoliert");
    ew_lgui_assert(ew_app.selection.coilId==beforeSelection, "Physische Auswahl ohne gültiges L erhalten");
    ew_lgui_assert(~ew_app.learning.valid, "Keine veralteten Induktivitätslerndaten");
    ew_app.controls.gapMm.string="1";
    ew_lgui_assert(ew_gui_calculate(), "Magnetgeometrie wiederhergestellt");
    ew_lgui_assert(ew_app.learning.valid, "Lerndaten wieder verfügbar");
    ew_app.controls.convergenceOrder.value=1;
    ew_lgui_assert(ew_gui_select_order(50), "Ordnung oberhalb des Konvergenzbereichs");
    ew_lgui_assert(ew_app.learning.selectedOrderOutsideConvergence, "Außerhalb liegende ausgewählte Ordnung kenntlich");
    ew_lgui_assert(ew_app.convergence.maxOrder==20, "K-Konv. bleibt unabhängig");
    mprintf("LEARNING-GUI PASSED: %d Prüfungen, sieben verknüpfte Ansichten und vier Lernschritte.\n",EW_LEARNING_GUI_TESTS);
    exit(0);
catch
    mprintf("LEARNING-GUI FAILED: %s\n",lasterror());
    if typeof(ew_app)=="st" then
        if isfield(ew_app,"controls") then mprintf("Status: %s\n",ew_app.controls.status.string); end
    end
    exit(1);
end
