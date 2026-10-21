// Independent geometry checks for the educational voltage-addition sequence.
function ew_animation_assert(condition,label)
    global EW_ANIMATION_TEST_COUNT;
    EW_ANIMATION_TEST_COUNT=EW_ANIMATION_TEST_COUNT+1;
    if ~and(condition) then error("Zeigeranimation: "+label);end
endfunction

function ew_animation_close(actual,expected,label)
    ew_animation_assert(abs(actual-expected)<2d-10,label);
endfunction

function value=ew_animation_direct_voltage(w,ids,order)
    value=0;
    for n=1:length(w.coils)
        coil=w.coils(n);
        if ~or(ids==coil.id) then continue;end
        value=value+exp(%i*order*2*%pi*(coil.positiveSlot-1)/w.slots)-exp(%i*order*2*%pi*(coil.negativeSlot-1)/w.slots);
    end
endfunction

function count=ew_test_animation()
    global EW_ANIMATION_TEST_COUNT;
    EW_ANIMATION_TEST_COUNT=0;
    inputs=[12,1,1,6;36,2,1,0;12,5,2,1;9,4,2,1;120,50,2,1];
    for machine=1:size(inputs,1)
        input=inputs(machine,:);
        w=ew_compute_winding(input(1),input(2),input(3),input(4));
        d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
        cv=ew_compute_convergence(w,d.parameters,20);
        phaseIds=struct("A",emptystr(0,1),"B",emptystr(0,1),"C",emptystr(0,1));
        for n=1:length(w.coils),c=w.coils(n);ids=phaseIds(c.phase);ids($+1,1)=c.id;phaseIds(c.phase)=ids;end
        for phase=["A","B","C"]
            ids=phaseIds(phase);
            // Vary both the selected physical coil and the spatial order.
            orders=unique([w.polePairs,w.polePairs+1,w.slots]);
            for k=orders
                coilId=ids(1);if k<>w.polePairs then coilId=ids($);end
                learn=ew_compute_learning(w,d,coilId,phase,phase,k,20,cv);
                data=ew_compute_animation(learn);
                ew_animation_assert(data.valid,"Gültige Wicklung erhält Animationsschritte");
                ew_animation_assert(data.coilId==coilId & data.phase==phase & data.order==k,"Auswahl und Raumordnung bleiben aktuell");
                ew_animation_assert(data.frameCount==5+length(learn.groupContribution.members)+length(learn.phaseContribution.members),"Vollständige, endliche Summenkette ohne Wiederholungen");
                ew_animation_assert(data.frameCount==length(data.frames),"Indexbereich ist vollständig");
                plus=exp(%i*k*2*%pi*(learn.coil.positiveSlot-1)/w.slots);
                rawMinus=exp(%i*k*2*%pi*(learn.coil.negativeSlot-1)/w.slots);
                ew_animation_close(ew_learning_value(data.frames(1).result),plus,"Plusseite folgt tatsächlicher Nutlage");
                ew_animation_close(ew_learning_value(data.frames(2).result),rawMinus,"Minus-Rohzeiger zeigt zunächst nur geometrische Lage");
                ew_animation_close(ew_learning_value(data.frames(3).result),-rawMinus,"Polung kehrt Minuszeiger um, ohne Nutlage zu ändern");
                ew_animation_assert(data.frames(2).terms(1).isRaw & ~data.frames(2).terms(1).polarityApplied,"Rohzeiger wird explizit vom signierten Beitrag unterschieden");
                ew_animation_assert(data.frames(3).terms(1).polarityApplied & ~data.frames(3).terms(1).isRaw,"Umpolung ist ausdrücklich abgeschlossen");
                ew_animation_assert(~data.frames(4).showResult & data.frames(5).showResult,"Spitze-an-Fuß und resultierender Spulenzeiger sind getrennte Etappen");
                ew_animation_close(ew_learning_value(data.frames(4).result),plus-rawMinus,"Parallele Verschiebung erhält vorzeichenrichtige Spulensumme");
                ew_animation_close(ew_learning_value(data.frames(5).result),ew_animation_direct_voltage(w,coilId,k),"Spulensumme stimmt mit unabhängiger Leiterrekonstruktion überein");
                ew_animation_assert(data.frames(4).terms(1).slot==learn.coil.positiveSlot & data.frames(4).terms(1).layer==learn.coil.positiveLayer,"Plus-Leiter behält tatsächliche Nut und Lage");
                ew_animation_assert(data.frames(4).terms(2).slot==learn.coil.negativeSlot & data.frames(4).terms(2).layer==learn.coil.negativeLayer,"Minus-Leiter behält tatsächliche Nut und Lage");
                sawFirstPhase=%f;
                for frameIndex=1:data.frameCount
                    f=data.frames(frameIndex);
                    ew_animation_assert(f.index==frameIndex & f.quantity=="U","Jeder Schritt ist indiziert und als normierter Spannungszeiger bezeichnet");
                    ew_animation_assert(f.visibleCount>=1 & f.visibleCount<=length(f.terms),"Sichtbarer Teil bleibt innerhalb der tatsächlichen Beiträge");
                    ew_animation_assert(~isempty(f.formulaText) & ~isempty(f.substitutionText) & ~isempty(f.resultText),"Allgemeine Formel, eingesetzte Werte und Ergebnis vorhanden");
                    ew_animation_assert(~isempty(f.formulaLatex) & ~isempty(f.substitutionLatex) & ~isempty(f.resultLatex),"Drei gesetzte Formelschritte vorhanden");
                    ew_animation_assert(~isempty(strindex(f.formulaMathML,"<math ")) & ~isempty(strindex(f.substitutionMathML,"<math ")) & ~isempty(strindex(f.resultMathML,"<math ")),"MathML-Schritte sind lokal eingebettet");
                    ew_animation_assert(size(unique(f.includedCoilIds),"*")==size(f.includedCoilIds,"*"),"Keine reale Spule wird innerhalb eines Summenschritts doppelt gezählt");
                    running=0;
                    for termIndex=1:f.visibleCount
                        term=f.terms(termIndex);v=ew_learning_value(term.value);
                        ew_animation_assert(and(~isnan([term.value.real,term.value.imag,term.value.magnitude])),"Keine undefinierten Koordinaten bei Auslöschung");
                        running=running+v;
                        if term.kind<>"side" then
                            ew_animation_close(v,ew_animation_direct_voltage(w,term.coilIds,k),"Gezeigter Spulen-/Gruppenvektor stammt aus tatsächlichen signierten Leitern");
                        end
                    end
                    ew_animation_close(ew_learning_value(f.result),running,"Jeder Ergebniszeiger entspricht genau den sichtbaren Beiträgen");
                    ew_animation_close(ew_learning_value(f.previous)+ew_learning_value(f.added),running,"Numerische Einsetzung addiert vorherige Summe und neuen Beitrag");
                    if f.stage=="group" | f.stage=="phase" then
                        ew_animation_close(ew_learning_value(f.result),ew_animation_direct_voltage(w,f.includedCoilIds,k),"Zwischensumme entspricht ihren physikalischen Spulen");
                    end
                    if f.stage=="phase" & ~sawFirstPhase then
                        ew_animation_assert(f.terms(1).id==learn.groupId,"Ausgewählte Gruppe startet nachvollziehbar die Strangaddition");sawFirstPhase=%t;
                    end
                end
                last=data.frames($);
                direct=0;
                for n=1:length(w.slotLayers)
                    side=w.slotLayers(n);
                    if side.phase==phase then direct=direct+side.sign*exp(%i*k*2*%pi*(side.slot-1)/w.slots);end
                end
                ew_animation_close(ew_learning_value(last.result),direct,"Endergebnis entspricht vollständiger unabhängiger Nutlagensumme");
                ew_animation_close(ew_learning_value(data.phaseFourier),conj(direct)/(2*%i*k),"Explizite Fourier-Umrechnung hält +j und -j-Konvention auseinander");
                ew_animation_assert(last.stage=="phase" & size(last.includedCoilIds,"*")==size(ids,"*"),"Letzte Etappe enthält den vollständigen Strang");
                ew_animation_assert(size(unique(last.includedCoilIds),"*")==size(ids,"*"),"Keine Spule fehlt im vollständigen Strang oder wird doppelt verwendet");
                if k==w.slots then
                    ew_animation_close(ew_learning_value(last.result),0,"Ordnung Q löscht alle tatsächlichen Spulen aus");
                    ew_animation_assert(last.result.magnitude==0,"Nullresultierende erfindet weder Betrag noch Winkel");
                end
            end
        end
    end
    missing=ew_compute_animation(struct("valid",%f,"warnings","Testfall"));
    ew_animation_assert(~missing.valid & missing.frameCount==0,"Ungültige Lerndaten erzeugen keine erfundenen Schritte");
    missing=ew_compute_animation([]);
    ew_animation_assert(~missing.valid,"Fehlende Lerndaten werden verständlich diagnostiziert");
    // A high spatial order must still use the same origin and finite values.
    w=ew_compute_winding(9,4,2,1);d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
    learn=ew_compute_learning(w,d,"A2","A","B",1999,20);data=ew_compute_animation(learn);
    ew_animation_close(ew_learning_value(data.frames($).result),ew_animation_direct_voltage(w,data.frames($).includedCoilIds,1999),"Hohe Raumordnung behält gemeinsamen Bezug");
    // Inspect actual rendered MathML labels, not only nonempty strings.
    ew_animation_assert(~isempty(strindex(data.frames(1).resultMathML,"<mtext>+,k (roh)</mtext>")),"Nutseiten-MathML enthält genau ein Basissymbol U");
    ew_animation_assert(~isempty(strindex(data.frames(5).resultMathML,"<mtext>A2,k</mtext>")),"Spulen-MathML verwendet die tatsächliche Kennung als Index ohne zweites U");
    ew_animation_assert(~isempty(strindex(data.frames(6).formulaMathML,"<mtext>Gruppe,k</mtext>")),"Gruppenformel enthält den Gruppenindex ohne verdoppeltes Basissymbol");
    ew_animation_assert(~isempty(strindex(data.frames($).formulaMathML,"<mtext>A,k</mtext>")),"Strangformel enthält den Strangindex ohne verdoppeltes Basissymbol");
    ew_animation_assert(~isempty(strindex(data.frames(6).formulaText,"+ U_")),"Textformel addiert den Spannungszeiger statt einer bloßen Spulenkennung");
    ew_animation_assert(~isempty(strindex(data.frames(6).formulaLatex,"U_{c_n,k}")) & ~isempty(strindex(data.frames(6).formulaMathML,"<msub><mi>c</mi><mi>n</mi></msub>")),"Allgemeine Gruppenformel benennt die n-te Spule statt einer mathematisch missverständlichen Kennung");
    ew_animation_assert(~isempty(strindex(data.frames($).formulaLatex,"U_{g_n,k}")) & ~isempty(strindex(data.frames($).formulaMathML,"<msub><mi>g</mi><mi>n</mi></msub>")),"Allgemeine Strangformel benennt die n-te Gruppe statt einer Kennung mit Bindestrich");
    parsed=fromJSON(toJSON(data));
    ew_animation_assert(parsed.frameCount==data.frameCount & parsed.coilId=="A2","Animierte Herleitung ist als reelles JSON vollständig exportierbar");
    count=EW_ANIMATION_TEST_COUNT;
    mprintf("Zeigeranimation: %d Prüfungen; reale Nutseiten, vorzeichenrichtige Zwischensummen und Formelwerte.\n",count);
endfunction
