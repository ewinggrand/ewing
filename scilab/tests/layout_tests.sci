// Geometry and topology regression tests. Helpers are defined by run_tests.sce.
// Loading this file only defines a test function and opens no graphics windows.
function cases = ew_test_layout()
    fixtures=ew_test_layout_fixtures();
    cases=length(fixtures);
    for fixtureIndex=1:cases
        expected=fixtures(fixtureIndex); inputs=expected.input;
        label="Layout "+string(fixtureIndex)+" Q"+string(inputs(1))+"/p"+string(inputs(2))+" "+expected.mode;
        w=ew_compute_winding(inputs(1),inputs(2),inputs(3),inputs(4));
        layout=ew_build_winding_layout(w,expected.mode,expected.cut);
        ew_test_assert(layout.valid,label+": Realisierbar");
        ew_test_close([layout.width,layout.height,layout.startSlot,layout.canonicalStartSlot,layout.bodyTop,layout.bodyBottom],expected.geometry,1d-7,label+": Geometrie und kanonischer Schnitt");
        ew_test_assert(length(layout.teeth)==w.slots,label+": Genau Q blaue Zaehne");
        ew_test_assert(length(layout.slots)==w.slots+1,label+": Q+1 Nutachsen mit periodischer Randnut");
        ew_test_assert(length(layout.coilPaths)==size(expected.positions,1),label+": Spulenzahl");
        actualPositions=zeros(length(layout.coilPaths),7);
        sideNodes=emptystr(0,1);
        for ii=1:length(layout.coilPaths)
            coil=layout.coilPaths(ii);
            ew_test_assert(coil.id==expected.coilIds(ii),label+": Unveraenderte Spulenkennungen");
            actualPositions(ii,:)=[coil.centerX,coil.positiveSide.x,coil.negativeSide.x,coil.positivePort.x,coil.positivePort.y,coil.negativePort.x,coil.negativePort.y];
            sideNodes($+1,1)=coil.positiveSide.nodeId; sideNodes($+1,1)=coil.negativeSide.nodeId;
            ew_test_assert(abs(coil.positivePort.x-coil.negativePort.x)>1d-6,label+": Zwei getrennte offene Spulenenden");
            both=list(coil.topPaths,coil.bottomPaths);
            for kind=1:2
                paths=both(kind);
                for ppIndex=1:length(paths)
                    pp=paths(ppIndex);
                    ew_test_assert(and(pp.points(:,1)>=layout.geometry.seamLeft-1d-7 & pp.points(:,1)<=layout.geometry.seamRight+1d-7),label+": Koepfe am realen Umfangsschnitt geclippt");
                    for pointIndex=2:size(pp.points,1)
                        dx=abs(pp.points(pointIndex,1)-pp.points(pointIndex-1,1));
                        dy=abs(pp.points(pointIndex,2)-pp.points(pointIndex-1,2));
                        if dx>1d-7 then ew_test_close(dy/dx,0.65,1d-7,label+": Gemeinsame Kopfsteigung aus realer Spulenweite");end
                    end
                end
            end
        end
        ew_test_close(actualPositions,expected.positions,1d-7,label+": Jede Seite und jeder offene Port gegen Browserreferenz");
        ew_test_assert(size(unique(sideNodes),"*")==length(w.slotLayers),label+": Jede aktive Nutlage genau einmal");
        ew_test_assert(length(layout.terminals)==size(expected.terminalPositions,1),label+": Klemmenzahl");
        actualTerminals=zeros(length(layout.terminals),2);
        for ii=1:length(layout.terminals)
            terminal=layout.terminals(ii); actualTerminals(ii,:)=[terminal.x,terminal.y];
            ew_test_assert(terminal.nodeId==expected.terminalNodes(ii),label+": Identische Klemmenknoten bei jeder Schnittdrehung");
            ew_test_assert(terminal.label==expected.terminalLabels(ii),label+": Offene Strang-/Spulenklemmen");
        end
        ew_test_close(actualTerminals,expected.terminalPositions,1d-7,label+": Lokale Anschlussfuehrung");
        ew_test_assert(length(layout.connections)==size(expected.routes,1),label+": Serienbrueckenanzahl");
        if length(layout.connections)>0 then
            actualRoutes=zeros(length(layout.connections),3);
            for ii=1:length(layout.connections)
                bridge=layout.connections(ii); actualRoutes(ii,:)=[bridge.routeY,bridge.routeLane,length(bridge.paths)];
                fromCoil=ew_gfx_find_coil(layout.coilPaths,bridge.fromCoilId);
                toCoil=ew_gfx_find_coil(layout.coilPaths,bridge.toCoilId);
                ew_test_assert(bridge.fromNode==fromCoil.negativeSide.nodeId & bridge.toNode==toCoil.positiveSide.nodeId,label+": Additiv Minus an Plus desselben Strangs");
                ew_test_assert(fromCoil.phase==toCoil.phase,label+": Keine fremden Straenge zusammengeschaltet");
            end
            ew_test_close(actualRoutes,expected.routes,1d-7,label+": Lokale kreuzungsgetrennte Routing-Ebenen");
        end
        if expected.mode=="series" then
            ew_test_assert(length(layout.topology.phaseChains)==3,label+": Genau drei offene Serienstraenge");
            ew_test_assert(length(layout.connections)==length(w.coils)-3,label+": Zusammenhaengende offene Reihenschaltung");
        else
            ew_test_assert(length(layout.connections)==0,label+": Einzelspulen bleiben offen und unverbunden");
        end
    end

    // Analytic clipping fixture: the seam intersects a sloping segment at a
    // non-midpoint height. Endpoint wrapping alone cannot satisfy this test.
    paths=ew_split_periodic_polyline([95,10;115,50],0,100);
    ew_test_assert(length(paths)==2,"Zwei getrennte periodische Linienabschnitte");
    first=paths(1); last=paths(2);
    ew_test_close(first.points,[95,10;100,20],1d-12,"Exakte erste Schnitthoehe");
    ew_test_close(last.points,[0,20;15,50],1d-12,"Exakte fortgesetzte Schnitthoehe");

    w=ew_compute_winding(9,4,2,1);
    canonical=ew_build_winding_layout(w,"series",0);
    ew_test_assert(canonical.startSlot==9,"Neun Zahnspulen beginnen automatisch in Nut 9");
    chainA=canonical.topology.phaseChains(1);
    ew_test_assert(and(chainA.coilIds==["A9";"A1";"A2"]),"Q9: additive Serienfolge A9/A1/A2");
    for cut=1:9
        rotated=ew_build_winding_layout(w,"series",cut);
        for phase=1:3
            original=canonical.topology.phaseChains(phase); displayed=rotated.topology.phaseChains(phase);
            ew_test_assert(and(original.coilIds==displayed.coilIds),"Schnittdrehung erhaelt kanonische Serienfolge");
            ew_test_assert(original.startNodeId==displayed.startNodeId & original.endNodeId==displayed.endNodeId,"Schnittdrehung erhaelt die Strangpolung");
        end
    end
    invalid=ew_compute_winding(18,2,1,0);
    missing=ew_build_winding_layout(invalid,"series",0);
    ew_test_assert(~missing.valid & length(missing.coilPaths)==0 & length(missing.terminals)==0,"Ungueltige Zonung erfindet keine gezeichneten Leiter");
    ew_test_error("ew_build_winding_layout(w,''series'',10)","Ungueltige Schnittnut abweisen");
    ew_test_error("ew_build_winding_layout(w,''parallel'',0)","Nicht implementierte Parallelzweige abweisen");
    mprintf("PASS: %d native Layoutreferenzen und periodische Topologieinvarianten.\n",cases);
endfunction
