// Integration of deterministic frames, native controls, short timer callbacks
// and actual winding highlights. The Desktop event loop is verified separately
// with real mouse input; -nw deliberately drives ticks synchronously here.
function ew_agui_assert(condition,label)
    global EW_ANIMATION_GUI_TESTS;
    EW_ANIMATION_GUI_TESTS=EW_ANIMATION_GUI_TESTS+1;
    if ~and(condition) then error("ANIMATION GUI: "+label);end
endfunction

try
    directory=get_absolute_file_path("animation_gui_smoke.sce");
    exec(directory+"../loader.sce",-1);
    global ew_app EW_ANIMATION_GUI_TESTS;
    EW_ANIMATION_GUI_TESTS=0;
    ew_gui();ew_gui_preset(4);ew_gui_winding();ew_gui_animation();
    ew_agui_assert(ew_app.animation.valid,"Lernfolge verfügbar");
    ew_agui_assert(ew_app.animationFrame==1,"Start mit erster Nutseite");
    ew_agui_assert(ew_app.animation.frameCount==9,"Q9/p4 ergibt vollständige Folge");
    ew_agui_assert(ew_gui_figure_alive(ew_app.plotFigures.animation),"Eigene native Ansicht");
    screen=get(0,"screensize_px");
    position=matrix(ew_app.plotFigures.animation.figure_position,1,-1);
    window=matrix(ew_app.plotFigures.animation.figure_size,1,-1);
    ew_agui_assert(and(position>=0),"Animationsfenster beginnt im sichtbaren Bildschirm");
    ew_agui_assert(and(position+window<=screen(3:4)),"Native Steuerung passt vollständig auf den Bildschirm");
    ew_agui_assert(ew_app.animationControls.play.string=="Start","Start-Steuerung");
    ew_agui_assert(ew_app.controls.exportCsv.string=="Animation CSV","Ansicht exportiert Lernprotokoll");
    // Opening another result must not leave a manual animation control bound
    // to that result's report, CSV dispatch or SVG figure.
    ew_gui_winding();ew_gui_animation_step(1);
    ew_agui_assert(ew_app.view=="animation","Manueller Schritt aktiviert seine eigene Ansicht");
    ew_agui_assert(ew_app.lastFigure==ew_app.plotFigures.animation,"SVG folgt manuellem Animationsschritt");
    ew_agui_assert(ew_app.controls.exportCsv.string=="Animation CSV","CSV folgt manuellem Animationsschritt");
    ew_agui_assert(~isempty(grep(ew_app.controls.report.string,"WERTE EINSETZEN")),"Hauptprotokoll folgt manuellem Animationsschritt");
    ew_gui_winding();ew_gui_animation_toggle();
    ew_agui_assert(ew_app.view=="animation" & ew_app.lastFigure==ew_app.plotFigures.animation,"Start aktiviert Animationsbericht und SVG");
    ew_gui_winding();token=ew_app.animationGeneration;ew_gui_animation_tick(token);
    ew_agui_assert(ew_app.view=="wicklung","Automatischer Tick erhält vom Nutzer gewählte Ansicht");
    ew_agui_assert(ew_app.lastFigure==ew_app.plotFigures.wicklung & ew_app.controls.exportCsv.string=="Nutbelegung CSV","Automatischer Tick erhält SVG und CSV der aktiven Ansicht");
    ew_gui_animation_toggle();
    ew_agui_assert(~ew_app.animationPlaying & ew_app.view=="animation" & ew_app.lastFigure==ew_app.plotFigures.animation,"Pause aktiviert ihre eigene Ansicht");
    ew_gui_winding();ew_app.animationControls.speed.value=3;ew_gui_animation_speed_changed();
    ew_agui_assert(ew_app.view=="animation" & ew_app.lastFigure==ew_app.plotFigures.animation & ew_app.controls.exportCsv.string=="Animation CSV","Manueller Tempowechsel aktiviert Animationsansicht");
    ew_gui_animation_restart();
    windingCalls=ew_app.windingComputations;magneticCalls=ew_app.inductanceComputations;
    matrixBefore=ew_app.inductance.matrixH;coilId=ew_app.settings.coilId;
    for index=1:ew_app.animation.frameCount
        ew_agui_assert(ew_gui_animation_set_frame(index),"Schritt auswählen "+string(index));
        frame=ew_app.animation.frames(index);
        ew_agui_assert(ew_app.settings.coilId==coilId,"Zentrale Spule bleibt bei Schritt "+string(index));
        ew_agui_assert(ew_app.plotFigures.animation.user_data.animationFrame==index,"Sichtbarer Schritt");
        ew_agui_assert(ew_app.settings.animationFrame==index,"Exportierter Schritt");
        ax=ew_app.plotFigures.wicklung.children(1);
        ew_agui_assert(isequal(ax.user_data.activeCoilIds,frame.activeCoilIds),"Tatsächliche Spulen passend zum Summanden");
        ew_agui_assert(ax.user_data.selectedCoilId==coilId,"Aktive Markierung ändert Ausgangsspule nicht");
    end
    ew_agui_assert(ew_app.windingComputations==windingCalls,"Keine neue Wicklung beim Abspielen");
    ew_agui_assert(ew_app.inductanceComputations==magneticCalls,"Keine neue Luftspaltintegration");
    ew_agui_assert(max(abs(ew_app.inductance.matrixH-matrixBefore))<1d-14,"Physik bleibt unverändert");
    ew_agui_assert(~isempty(grep(ew_app.controls.report.string,"ALLGEMEINE FORMEL")),"Allgemeine Formel im Protokoll");
    ew_agui_assert(~isempty(grep(ew_app.controls.report.string,"WERTE EINSETZEN")),"Eingesetzte Werte im Protokoll");
    ew_agui_assert(~isempty(grep(ew_app.controls.report.string,"ERGEBNIS")),"Ergebnis im Protokoll");
    ew_gui_animation_set_frame(0);ew_agui_assert(ew_app.animationFrame==1,"Zurück am Anfang begrenzt");
    ew_gui_animation_step(1);ew_agui_assert(ew_app.animationFrame==2,"Einzelschritt weiter");
    ew_gui_animation_step(-1);ew_agui_assert(ew_app.animationFrame==1,"Einzelschritt zurück");
    ew_gui_animation_set_frame(2000);ew_agui_assert(ew_app.animationFrame==ew_app.animation.frameCount,"Ende begrenzt");
    ew_gui_animation_toggle();
    ew_agui_assert(ew_app.animationFrame==1,"Start am Ende beginnt neue Folge");
    ew_agui_assert(ew_app.animationPlaying,"Native Wiedergabe gestartet");
    ew_agui_assert(ew_app.animationTimer.isRunning(),"Einmal-Timer gestartet");
    token=ew_app.animationGeneration;
    ew_gui_animation_tick(token);
    ew_agui_assert(ew_app.animationFrame==2,"Ein Tick zeichnet genau einen Schritt");
    ew_app.animationControls.speed.value=3;ew_gui_animation_speed_changed();
    ew_agui_assert(ew_gui_animation_delay()==400,"Geschwindigkeit umschalten");
    ew_agui_assert(ew_app.animationTimer.getInitialDelay()==400,"Timer erhält neues Tempo");
    ew_gui_animation_pause();position=ew_app.animationFrame;
    ew_agui_assert(~ew_app.animationPlaying,"Pause beendet Wiedergabe");
    ew_agui_assert(~ew_app.animationTimer.isRunning(),"Pause stoppt nativen Timer");
    ew_gui_animation_tick(token);
    ew_agui_assert(ew_app.animationFrame==position,"Bereits wartender Tick nach Pause verworfen");
    ew_gui_animation_toggle();ew_gui_animation_step(1);
    ew_agui_assert(~ew_app.animationPlaying,"Manueller Schritt pausiert zuerst");
    ew_agui_assert(ew_app.animationFrame==position+1,"Manueller Schritt erhält exakte Reihenfolge");
    ew_gui_animation_restart();ew_agui_assert(ew_app.animationFrame==1,"Anfang stellt ersten Schritt her");
    ew_gui_animation_toggle();token=ew_app.animationGeneration;
    ew_agui_assert(ew_gui_select_coil("A2"),"Ausgangsspule während Wiedergabe ändern");
    ew_agui_assert(~ew_app.animationPlaying & ew_app.animationFrame==1,"Neue Auswahl pausiert und beginnt neu");
    ew_agui_assert(ew_app.animation.coilId=="A2","Lernfolge folgt tatsächlicher Auswahl");
    ew_gui_animation_tick(token);ew_agui_assert(ew_app.animationFrame==1,"Alter Tick nach Auswahl verworfen");
    ew_gui_animation_set_frame(7);ew_gui_animation_toggle();token=ew_app.animationGeneration;
    deleted=ew_app.plotFigures.animation;ew_gui_animation_close(deleted.figure_id);
    ew_agui_assert(~ew_gui_figure_alive(deleted),"Animationsfenster geschlossen");
    ew_agui_assert(~ew_app.animationPlaying,"Schließen stoppt Timer");
    ax=ew_app.plotFigures.wicklung.children(1);
    ew_agui_assert(isequal(ax.user_data.activeCoilIds,"A2"),"Schließen stellt zentrale Spulenmarkierung her");
    windowsBefore=size(winsid(),"*");ew_gui_animation_tick(token);
    ew_agui_assert(size(winsid(),"*")==windowsBefore,"Veralteter Tick öffnet geschlossenes Fenster nicht");
    ew_gui_animation();ew_agui_assert(ew_gui_figure_alive(ew_app.plotFigures.animation),"Ansicht erneut öffnen");
    ew_app.controls.gapMm.string="0";ew_gui_selection_changed();
    ew_agui_assert(~ew_app.animation.valid & ~ew_app.animationPlaying,"Ungültige Magnetgeometrie entfernt alte Lerndaten");
    ew_agui_assert(ew_app.animationControls.play.enable=="off","Keine Wiedergabe ungültiger Daten");
    ew_app.controls.gapMm.string="1";ew_gui_selection_changed();
    ew_agui_assert(ew_app.animation.valid & ew_app.animationFrame==1,"Gültige Geometrie stellt Lernfolge wieder her");
    ew_app.controls.slots.string="12+1";ew_gui_animation_toggle();
    ew_agui_assert(~ew_app.animationPlaying & ew_app.animationFrame==1,"Fehlerhafte noch nicht übernommene Eingabe startet keine alte Animation");
    ew_agui_assert(~isempty(grep(ew_app.controls.status.string,"Eingabe")),"Start erklärt ungültige Eingaben");
    ew_app.controls.slots.string="9";
    ew_gui_animation_toggle();token=ew_app.animationGeneration;oldFigure=ew_app.plotFigures.animation;
    ew_agui_assert(ew_app.animationPlaying,"Korrigierte Eingabe startet die Wiedergabe");
    ew_gui();
    ew_agui_assert(~ew_gui_figure_alive(oldFigure),"Neustart entfernt eigene alte Animationsansicht");
    ew_agui_assert(ew_app.animationGeneration>token,"Generationen bleiben über App-Neustart eindeutig");
    ew_gui_animation_tick(token);
    ew_agui_assert(ew_app.animationFrame==1 & ~ew_app.animationPlaying,"Alter App-Tick bleibt wirkungslos");
    mprintf("ANIMATION-GUI PASSED: %d Prüfungen, native Steuerung, Timer-Lebenszyklus und tatsächliche Spulenmarkierung.\n",EW_ANIMATION_GUI_TESTS);
    exit(0);
catch
    mprintf("ANIMATION-GUI FAILED: %s\n",lasterror());
    if typeof(ew_app)=="st" then
        if isfield(ew_app,"controls") then mprintf("Status: %s\n",ew_app.controls.status.string);end
    end
    exit(1);
end
