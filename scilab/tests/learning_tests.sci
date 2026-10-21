// Independent reconstruction checks for linked selection and harmonic sums.
function ew_learning_assert(condition,label)
    global EW_LEARNING_TEST_COUNT;
    EW_LEARNING_TEST_COUNT=EW_LEARNING_TEST_COUNT+1;
    if ~and(condition) then error("Lernmodell: "+label); end
endfunction

function ew_learning_close(actual,expected,tolerance,label)
    ew_learning_assert(and(size(actual)==size(expected)),label+" / Dimensionen");
    if isempty(actual) then return; end
    ew_learning_assert(max(abs(actual-expected))<=tolerance,label);
endfunction

function value = ew_learning_direct_voltage(w,phase,order,ids)
    value=0;
    if argn(2)<4 then
        for index=1:length(w.slotLayers)
            side=w.slotLayers(index);
            if side.phase==phase then value=value+side.sign*exp(%i*order*2*%pi*(side.slot-1)/w.slots); end
        end
    else
        for index=1:length(w.coils)
            coil=w.coils(index);
            if or(ids==coil.id) then
                value=value+exp(%i*order*2*%pi*(coil.positiveSlot-1)/w.slots)-exp(%i*order*2*%pi*(coil.negativeSlot-1)/w.slots);
            end
        end
    end
endfunction

function count = ew_test_learning()
    global EW_LEARNING_TEST_COUNT;
    EW_LEARNING_TEST_COUNT=0;
    inputs=[12,1,1,6;36,2,1,0;12,5,2,1;9,4,2,1;120,50,2,1];
    names=["A";"B";"C"];
    for machine=1:size(inputs,1)
        input=inputs(machine,:);
        w=ew_compute_winding(input(1),input(2),input(3),input(4));
        d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
        original=d.matrixH;
        cv=ew_compute_convergence(w,d.parameters,20);
        ew_learning_assert(cv.valid,"Konvergenz besitzt gültige Wicklung");
        ew_learning_close(cv.exactMatrixH,d.matrixH,2d-13,"Konvergenz verwendet das exakte Umfangsintegral");
        ew_learning_close(cv.finalMatrixH,d.harmonicMatrixH,2d-13,"Kumulierte Matrix entspricht unabhängigem Modell");
        ew_learning_assert(and(diff(cv.partialSelfH,1,1)>=-1d-14),"Selbstinduktivitäts-Summen wachsen monoton");
        for k=1:20
            ew_learning_close(cv.contributions(k),d.harmonics(k).contributionMatrixH,2d-13,"Ordnungsmatrix aus gemeinsamem Rohspektrum");
            ew_learning_assert(min(spec(cv.contributions(k)))>=-1d-13,"Jede Ordnungsmatrix ist positiv semidefinit");
        end
        for coilIndex=1:length(w.coils)
            // All actual coils are checked once at k=p. Extra orders below
            // exercise representative coils without redundant heavy work.
            coil=w.coils(coilIndex);a=ew_i_phase_index(coil.phase);
            b=modulo(a,3)+1;
            learn=ew_compute_learning(w,d,coil.id,coil.phase,names(b),w.polePairs,20,cv);
            ew_learning_assert(learn.valid & learn.convergenceCached,"Spule ist aktuell und benutzt magnetischen Cache");
            ew_learning_assert(learn.coil.id==coil.id & learn.coil.phase==coil.phase,"Zentrale Auswahl hält reale Spule/Strang");
            ew_learning_assert(learn.sides(1).slot==coil.positiveSlot & learn.sides(1).layer==coil.positiveLayer & learn.sides(1).sign==1,"Positive Nutseite ist tatsächlich vorhanden");
            ew_learning_assert(learn.sides(2).slot==coil.negativeSlot & learn.sides(2).layer==coil.negativeLayer & learn.sides(2).sign==-1,"Negative Nutseite ist tatsächlich vorhanden");
            pair=ew_learning_value(learn.sides(1).voltageFundamental)+ew_learning_value(learn.sides(2).voltageFundamental);
            expected=ew_learning_direct_voltage(w,coil.phase,w.polePairs,coil.id);
            ew_learning_close(pair,expected,2d-10,"Beide signierten Nutvektoren ergeben die Spulenspannung");
            ew_learning_close(ew_learning_value(learn.coilContribution.voltageHarmonic),expected,2d-10,"Spulenbeitrag entspricht den tatsächlichen Seiten");
            node=learn.groupContribution;
            expectedGroup=ew_learning_direct_voltage(w,coil.phase,w.polePairs,node.coilIds);
            ew_learning_close(ew_learning_value(node.voltageHarmonic),expectedGroup,2d-10,"Gruppe summiert die tatsächlich zugehörigen Spulen");
            sumGroup=0;
            for index=1:length(node.members),sumGroup=sumGroup+ew_learning_value(node.members(index).rawFourier);end
            ew_learning_close(sumGroup,ew_learning_value(node.rawFourier),2d-10,"Spulen -> Gruppe addiert komplex und vorzeichenrichtig");
            sumPhase=0;weighted=0;
            for index=1:length(learn.phaseContribution.members)
                group=learn.phaseContribution.members(index);
                sumPhase=sumPhase+ew_learning_value(group.rawFourier);
                weighted=weighted+ew_learning_value(group.phaseContribution);
            end
            ew_learning_close(sumPhase,ew_learning_value(learn.phaseContribution.rawFourier),2d-10,"Gruppen -> Strang addiert im gemeinsamen Raumbezug");
            ew_learning_close(weighted,ew_learning_value(learn.phaseContribution.factors.distributionFactor),2d-10,"Gewichtete Gruppenfaktoren rekonstruieren den Strangfaktor");
            voltage=ew_learning_direct_voltage(w,coil.phase,w.polePairs);
            ew_learning_close(ew_learning_value(learn.phaseContribution.voltageHarmonic),voltage,2d-10,"Strangspannung entspricht unabhängiger Nutvektorsumme");
            ew_learning_close(ew_learning_value(learn.phaseContribution.rawFourier),conj(voltage)/(2*%i*w.polePairs),2d-10,"Spannungs- und Fourier-Konvention bleiben getrennt");
            ew_learning_close(learn.harmonicMatrixH,d.fundamentalMatrixH,2d-13,"Grundwellen-Beitrag enthält alle Strang-Kreuzterme");
            ew_learning_close(learn.selectedContributionH,d.fundamentalMatrixH(a,b),2d-13,"Ausgewählter Erreger/Empfänger liest richtigen Matrixeintrag");
        end
        coil=w.coils(1);a=ew_i_phase_index(coil.phase);
        for order=unique([1,w.polePairs+1,w.slots,5*w.polePairs])
            learn=ew_compute_learning(w,d,coil.id,coil.phase,coil.phase,order,20,cv);
            ew_learning_assert(learn.valid,"Auch Nullordnungsbeiträge bleiben gültig");
            direct=ew_learning_direct_voltage(w,coil.phase,order);
            ew_learning_close(ew_learning_value(learn.phaseContribution.rawFourier),conj(direct)/(2*%i*order),2d-10,"Beliebige mechanische Harmonik aus tatsächlichen Nutseiten");
            ew_learning_assert(learn.selectedContributionH>=-1d-14,"Selbstinduktivitätsbeitrag jeder Ordnung ist nichtnegativ");
            ew_learning_assert(learn.selectedOrderOutsideConvergence==(order>20),"Außerhalb der Konvergenz liegende Ordnung wird markiert");
            ew_learning_assert(learn.coil.selected.order==order & learn.parameters.selectedOrder==order,"Kopierte Auswahlmetadaten gehören zur aktuellen Ordnung");
        end
        ew_learning_close(d.matrixH,original,0,"Auswahl und Lernschritte verändern das physikalische Rechenmodell nicht");
    end
    w=ew_compute_winding(9,4,2,1);
    d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
    cv=ew_compute_convergence(w,d.parameters,120);
    l=ew_compute_learning(w,d,"A2","A","B",4,120,cv);
    ew_learning_assert(l.selectedContributionH<0,"Gegeninduktivitätsbeitrag darf negativ sein");
    ew_learning_close(l.selectedPairFluxLinkageWbTurns,l.harmonicMatrixH(1,2)*d.parameters.currents(2),1d-15,"Ausgewähltes Quellpaar und zugehöriger Strom");
    ew_learning_close(l.receivingFluxLinkageWbTurns,l.harmonicMatrixH(1,:)*d.parameters.currents,1d-15,"Empfängerfluss enthält alle drei Quellströme");
    sumSquares=0;
    for index=1:length(d.coils)
        if d.coils(index).phase=="A" then sumSquares=sumSquares+abs(ew_i_coil_coefficient(d.coils(index),4))^2;end
    end
    ew_learning_assert(abs(d.fourierPrefactorH*sumSquares-l.harmonicMatrixH(1,1))>1d-5,"Einzelspulenquadrate ersetzen keine Strang-Kreuzterme");
    zero=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16,"currents",[0;0;0]));
    lzero=ew_compute_learning(w,zero,"A1","A","C",7,120,cv);
    ew_learning_assert(lzero.convergenceCached,"Ströme und Auswahl invalidieren keine Geometrie-Konvergenz");
    ew_learning_close(lzero.harmonicFluxLinkageWbTurns,zeros(3,1),0,"Strom null liefert Flussverkettung null ohne Division");
    ew_learning_close(lzero.convergence.parameters.currents,zeros(3,1),0,"Cache erhält frische Export-Metadaten");
    changed=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16,"turnsPerCoil",20));
    scaled=ew_compute_learning(w,changed,"A1","A","B",4,120,cv);
    ew_learning_assert(~scaled.convergenceCached,"Geänderte Windungszahl invalidiert den magnetischen Cache");
    ew_learning_close(scaled.convergence.finalMatrixH,4*cv.finalMatrixH,2d-13,"Konvergenz skaliert mit n²");
    moved=w;
    for index=1:length(moved.slotLayers)
        side=moved.slotLayers(index);side.slot=modulo(side.slot,moved.slots)+1;moved.slotLayers(index)=side;
    end
    for index=1:length(moved.coils)
        coil=moved.coils(index);coil.positiveSlot=modulo(coil.positiveSlot,moved.slots)+1;coil.negativeSlot=modulo(coil.negativeSlot,moved.slots)+1;moved.coils(index)=coil;
    end
    dm=ew_compute_inductance(moved,struct("maxOrder",20,"sampleCount",16));
    lm=ew_compute_learning(moved,dm,"A1","A","B",4,120,cv);
    ew_learning_assert(~lm.convergenceCached,"Tatsächliche Nutlage gehört zum Cache-Schlüssel");
    ew_learning_close(lm.convergence.finalMatrixH,cv.finalMatrixH,2d-13,"Gemeinsame Drehung ändert keine Induktivität");
    old=ew_compute_learning(moved,d,"A1","A","B",4,120,cv);
    ew_learning_assert(~old.valid,"Nicht zusammengehörige Wicklung/Induktivität werden erkannt");
    wzero=ew_compute_winding(12,5,2,1);dz=ew_compute_inductance(wzero,struct("maxOrder",20,"sampleCount",16));
    cz=ew_compute_convergence(wzero,dz.parameters,1200);
    ew_learning_assert(abs(cz.exactMatrixH(1,2))<1d-14 & and(~isnan(cz.relativeError)),"Verschwindende exakte Gegeninduktivität erzeugt keinen relativen Quotienten 0/0");
    ew_learning_assert(cz.relativeError($)<0.003,"Höhere Fourier-Ordnung nähert sich dem exakten Gram-Integral");
    invalid=ew_compute_winding(18,2,1,0);di=ew_compute_inductance(invalid);
    li=ew_compute_learning(invalid,di,"","A","B",2,20);
    ew_learning_assert(~li.valid,"Nicht realisierbare Wicklung erhält keine erfundenen Lernschritte");
    missing=ew_compute_learning(w,d,"A404","A","B",4,120,cv);
    mismatch=ew_compute_learning(w,d,"B3","A","B",4,120,cv);
    ew_learning_assert(~missing.valid & ~mismatch.valid,"Unbekannte oder strangfremde Spule wird diagnostiziert");
    parsed=fromJSON(toJSON(l));
    ew_learning_close(parsed.harmonicMatrixH,l.harmonicMatrixH,2d-15,"Lernmodell ist als reelles JSON exportierbar");
    ew_learning_assert(parsed.coilId=="A2" & parsed.sourcePhase=="B","JSON bewahrt die zentrale Auswahl");
    count=EW_LEARNING_TEST_COUNT;
    mprintf("Lernmodell: %d Prüfungen; verknüpfte Spulen, komplexe Gruppen und Fourier-Konvergenz.\n",count);
endfunction
