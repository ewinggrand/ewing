// Native plots and pure periodic drawing geometry. No JavaScript bridge.
// All winding directions and connections are taken from actual coil sides.

function ax = ew_gfx_prepare(plotTitle, ax)
    if argn(2) < 2 then ax = []; end
    if size(ax, "*") == 0 then
        fig = scf();
        fig.figure_name = "Wicklungsatelier - " + plotTitle;
        fig.figure_size = [900, 680];
        fig.background = color("white");
        clf(fig);
        ax = gca();
    else
        sca(ax);
        children = ax.children;
        if size(children, "*") > 0 then delete(children); end
    end
    sca(ax);
    ax.axes_reverse = ["off", "off", "off"];
    ax.axes_visible = ["off", "off", "off"];
    ax.box = "off";
    ax.background = color("white");
    ax.user_data = struct("ewHits",list(),"ewRole","");
    ax.font_size = 2;
    ax.title.text = plotTitle;
    ax.title.font_size = 3;
    ax.margins = [0.06, 0.04, 0.09, 0.08];
endfunction

function col = ew_gfx_phase_color(phase)
    select phase
    case "A" then rgb = [198, 87, 54];
    case "B" then rgb = [49, 128, 109];
    case "C" then rgb = [86, 104, 201];
    else rgb = [94, 104, 88];
    end
    col = addcolor(rgb / 255);
endfunction

function ew_gfx_line(points, col, lineWidth, lineStyle)
    if argn(2) < 3 then lineWidth = 1; end
    if argn(2) < 4 then lineStyle = 1; end
    if size(points, 1) < 2 then return; end
    xpoly(points(:, 1), points(:, 2), "lines", 0);
    entity = gce();
    entity.foreground = col;
    entity.thickness = lineWidth;
    entity.line_style = lineStyle;
endfunction

function ew_gfx_text(x, y, label, col, fontSize)
    if argn(2) < 4 then col = color("black"); end
    if argn(2) < 5 then fontSize = 2; end
    xstring(x, y, label);
    entity = gce();
    entity.font_foreground = col;
    entity.font_size = fontSize;
endfunction

function ew_gfx_polygon(points, col)
    if size(points, 1) < 3 then return; end
    xfpoly(points(:, 1), points(:, 2), col);
    entity=gce();
    entity.foreground=col;
    entity.background=col;
    entity.line_mode="off";
endfunction

function ew_gfx_arrow(x1, y1, x2, y2, col, lineWidth)
    if argn(2) < 6 then lineWidth = 1.5; end
    delta = [x2-x1, y2-y1];
    distance = norm(delta);
    if distance < 1d-12 then return; end
    unit = delta/distance;
    normal = [-unit(2), unit(1)];
    tip = [x2,y2];
    base = tip - unit*distance*0.12;
    halfWidth = distance*0.055;
    ew_gfx_line([x1,y1; x2,y2], col, lineWidth);
    ew_gfx_polygon([tip; base+normal*halfWidth; base-normal*halfWidth], col);
endfunction

function r = ew_gfx_mod(value, period)
    r = modulo(modulo(value, period)+period, period);
endfunction

// Linked selection belongs to the drawing layer. It never changes a coil,
// conductor sign, pairing, Fourier coefficient or canonical series chain.
function chosen = ew_gfx_selected_coil(w, selection)
    chosen = [];
    if typeof(selection) <> "st" then return; end
    id = "";
    if isfield(selection, "coilId") then id = selection.coilId; end
    if id == "" & isfield(selection, "selectedCoilId") then id = selection.selectedCoilId; end
    if id == "" & isfield(selection, "selectedCoil") then
        if typeof(selection.selectedCoil) == "st" then id = selection.selectedCoil.id; end
    end
    for index = 1:length(w.coils)
        coil = w.coils(index);
        if coil.id == id then chosen = coil; return; end
    end
endfunction

// A lesson may temporarily point to several actual coils. This drawing-only
// emphasis leaves the central selected coil and the canonical layout intact.
function ids = ew_gfx_active_coils(w, selection)
    ids = emptystr(0,1);
    if typeof(selection) <> "st" then return; end
    if isfield(selection,"activeCoilIds") then
        for k=1:length(w.coils)
            id=w.coils(k).id;
            if or(selection.activeCoilIds==id) then ids($+1,1)=id; end
        end
    else
        chosen=ew_gfx_selected_coil(w,selection);
        if typeof(chosen)=="st" then ids=chosen.id; end
    end
endfunction

function order = ew_gfx_selected_order(selection)
    order = [];
    if typeof(selection) <> "st" then return; end
    if isfield(selection, "selectedOrder") then order = selection.selectedOrder; end
    if isempty(order) & isfield(selection, "order") then order = selection.order; end
endfunction

function col = ew_gfx_link_color(phase, dimmed)
    if ~dimmed then col = ew_gfx_phase_color(phase); return; end
    select phase
    case "A" then rgb = [198,87,54];
    case "B" then rgb = [49,128,109];
    case "C" then rgb = [86,104,201];
    else rgb = [94,104,88];
    end
    col = addcolor(0.42*rgb/255 + 0.58*ones(1,3));
endfunction

function coilId = ew_gfx_side_coil(w, slot, layer)
    coilId = "";
    for index = 1:length(w.coils)
        coil = w.coils(index);
        if (coil.positiveSlot == slot & coil.positiveLayer == layer) | ..
           (coil.negativeSlot == slot & coil.negativeLayer == layer) then
            coilId = coil.id; return;
        end
    end
endfunction

function selected = ew_gfx_is_selected_side(chosen, slot, layer)
    selected = %f;
    if typeof(chosen) <> "st" then return; end
    selected = (chosen.positiveSlot == slot & chosen.positiveLayer == layer) | ..
        (chosen.negativeSlot == slot & chosen.negativeLayer == layer);
endfunction

function hits = ew_gfx_hit(hits, kind, coilId, x, y, slot, layer, order)
    if argn(2) < 6 then slot = 0; end
    if argn(2) < 7 then layer = 0; end
    if argn(2) < 8 then order = 0; end
    meta = struct("ewHit",kind,"coilId",coilId,"x",x,"y",y, ..
        "slot",slot,"layer",layer,"order",order);
    hits($+1) = meta;
    // Both native scene metadata and data-coordinate targets are provided.
    // The GUI can therefore resolve clicks without renderer-dependent boxes.
    try entity = gce(); entity.user_data = meta; catch ignored = %t; end
endfunction

function ew_gfx_set_hits(ax, hits, role)
    ax.user_data = struct("ewHits",hits,"ewRole",role);
endfunction

function node = ew_gfx_node(slot, layer)
    node = "slot-" + string(slot) + "-layer-" + string(layer);
endfunction

// Clip every individual segment at the periodic seam. The interpolated y
// coordinate is preserved even when a sloping head crosses away from its apex.
function paths = ew_split_periodic_polyline(points, left, period)
    paths = list();
    previousCell = %nan;
    for ii = 2:size(points, 1)
        a = points(ii-1,:); b = points(ii,:);
        cuts = [0;1];
        if abs(a(1)-b(1)) > 1d-9 then
            lowX = min(a(1),b(1)); highX = max(a(1),b(1));
            seamIndex = floor((lowX-left)/period)+1;
            while left+seamIndex*period < highX-1d-8
                cuts($+1,1) = (left+seamIndex*period-a(1))/(b(1)-a(1));
                seamIndex = seamIndex+1;
            end
        end
        cuts = gsort(cuts,"g","i");
        for jj = 2:size(cuts,"*")
            t0 = cuts(jj-1); t1 = cuts(jj);
            midpointX = a(1)+(b(1)-a(1))*(t0+t1)/2;
            cellIndex = floor((midpointX-left+1d-9)/period);
            first = a+(b-a)*t0-[cellIndex*period,0];
            last = a+(b-a)*t1-[cellIndex*period,0];
            join = %f;
            if length(paths)>0 then
                pp = paths($);
                join = cellIndex == previousCell & norm(pp.points($,:)-first)<1d-7;
            end
            if join then
                pp.points($+1,:) = last;
                paths($) = pp;
            else
                paths($+1) = struct("points",[first;last],"wrapped",%f);
            end
            previousCell = cellIndex;
        end
    end
    for ii = 1:length(paths)
        pp = paths(ii); pp.wrapped = length(paths)>1; paths(ii) = pp;
    end
endfunction

function x = ew_gfx_side_x(slot, layer, cut, count, pitch, lane, left)
    offset = 0;
    if lane<>0 then
        if layer==1 then offset=lane; else offset=-lane; end
    end
    x = left+ew_gfx_mod(ew_gfx_mod(slot-cut,count)*pitch+offset,count*pitch);
endfunction

function off = ew_gfx_layer_offset(layer,lane)
    off=0;
    if lane<>0 then
        if layer==1 then off=lane; else off=-lane; end
    end
endfunction

function measures = ew_gfx_measures_at(coils, cut, count, pitch, lane, left)
    measures = list(); centers=[]; ids=emptystr(0,1);
    period=count*pitch;
    for ii=1:length(coils)
        cc=coils(ii);
        px=ew_gfx_side_x(cc.positiveSlot,cc.positiveLayer,cut,count,pitch,lane,left);
        nx=px+cc.direction*cc.span*pitch+ew_gfx_layer_offset(cc.negativeLayer,lane)-ew_gfx_layer_offset(cc.positiveLayer,lane);
        center=left+ew_gfx_mod((px+nx)/2-left,period);
        measures($+1)=struct("coil",cc,"positiveX",px,"negativeUnwrappedX",nx,"centerX",center,"wrapped",nx<left-1d-7 | nx>left+period+1d-7);
        centers($+1)=center;
        ids($+1,1)=cc.id;
    end
    [dummy,order]=gsort(centers,"g","i");
    // Resolve coincident geometric centers with the same ID ordering used by
    // the browser version, rather than depending on the numeric sort stability.
    first=1;
    while first<=size(order,"*")
        last=first;
        while last<size(order,"*")
            if abs(centers(order(last+1))-centers(order(first)))>1d-8 then break; end
            last=last+1;
        end
        if last>first then
            [dummy,tieOrder]=gsort(ids(order(first:last)),"g","i");
            tied=order(first:last); order(first:last)=tied(tieOrder);
        end
        first=last+1;
    end
    sorted=list();
    for ii=1:size(order,"*") sorted($+1)=measures(order(ii)); end
    measures=sorted;
endfunction

function less = ew_gfx_score_less(a,b)
    less=%f;
    for ii=1:size(a,"*")
        if a(ii)<b(ii) then less=%t; return; end
        if a(ii)>b(ii) then return; end
    end
endfunction

function side = ew_gfx_find_side(sides,nodeId)
    side=[];
    for ii=1:length(sides)
        ss=sides(ii);
        if ss.nodeId==nodeId then side=ss; return; end
    end
    error("Eine Spulenseite fehlt im Wickelschema: "+nodeId);
endfunction

function cc = ew_gfx_find_coil(coils,id)
    cc=[];
    for ii=1:length(coils)
        ss=coils(ii);
        if ss.id==id then cc=ss; return; end
    end
    error("Eine Spule fehlt im Wickelschema: "+id);
endfunction

// A rotation changes only drawing coordinates. Canonical series chains and
// terminal nodes are selected once from the best automatic cut and stay fixed.
function layout = ew_build_winding_layout(w,mode,startSlot)
    if argn(2)<2 then mode="series"; end
    if argn(2)<3 then startSlot=0; end
    if and(mode<>["series","individual"]) then error("Verbindungsart: series oder individual."); end
    count=w.slots;
    if startSlot<>0 & (startSlot<1 | startSlot>count | startSlot<>floor(startSlot)) then error("Die Schnittnut muss zwischen 1 und Q liegen; 0 bedeutet automatisch."); end
    layout=struct("valid",%f,"width",640,"height",220,"startSlot",[],"canonicalStartSlot",[],"connectionMode",mode,"teeth",list(),"slots",list(),"coilPaths",list(),"orderedCoils",list(),"groups",list(),"connections",list(),"seriesConnections",list(),"terminals",list(),"topology",struct("nodes",list(),"edges",list(),"phaseChains",list()),"warnings","Ohne vollständige Wicklung wird kein Wickelschema gezeichnet.");
    if ~w.valid | length(w.coils)==0 | length(w.slotLayers)==0 then return; end
    if count<=24 then pitch=max(58,520/count); else pitch=max(36,520/count); end
    left=60; period=count*pitch; right=left+period;
    lane=0; if w.layers==2 then lane=min(6,pitch*0.12); end
    original=list();
    for ii=1:length(w.coils)
        cc=w.coils(ii);
        if ~isfield(cc,"positiveLayer") then cc.positiveLayer=1; end
        if ~isfield(cc,"negativeLayer") then cc.negativeLayer=1; end
        if ~isfield(cc,"direction") then
            cc.direction=-1;
            if ew_gfx_mod(cc.negativeSlot-cc.positiveSlot,count)==cc.span then cc.direction=1; end
        end
        original($+1)=cc;
    end
    bestScore=[%inf,%inf,%inf,%inf]; canonicalCut=1;
    phaseNames=["A","B","C"];
    for cutCandidate=1:count
        mm=ew_gfx_measures_at(original,cutCandidate,count,pitch,lane,left);
        wraps=0; runs=0; prior="";
        for ii=1:length(mm)
            item=mm(ii); wraps=wraps+bool2s(item.wrapped);
            if item.coil.phase<>prior then runs=runs+1; end
            prior=item.coil.phase;
        end
        firstItem=mm(1);
        phaseIndex=find(phaseNames==firstItem.coil.phase);
        score=[wraps,runs,phaseIndex(1),cutCandidate];
        if ew_gfx_score_less(score,bestScore) then bestScore=score; canonicalCut=cutCandidate; end
    end
    canonicalMeasures=ew_gfx_measures_at(original,canonicalCut,count,pitch,lane,left);
    canonicalIds=emptystr(0,1);
    for ii=1:length(canonicalMeasures) item=canonicalMeasures(ii); canonicalIds($+1,1)=item.coil.id; end
    cut=startSlot; if cut==0 then cut=canonicalCut; end
    measures=ew_gfx_measures_at(original,cut,count,pitch,lane,left);
    slope=0.65; maxHeadHeight=0;
    for ii=1:length(measures)
        item=measures(ii); maxHeadHeight=max(maxHeadHeight,abs(item.negativeUnwrappedX-item.positiveX)*slope/2);
    end
    bodyTop=70+maxHeadHeight;
    if count<=24 then bodyBottom=bodyTop+128; else bodyBottom=bodyTop+110; end
    sides=list(); nodes=list();
    for ii=1:length(w.slotLayers)
        ss=w.slotLayers(ii); ss.nodeId=ew_gfx_node(ss.slot,ss.layer);
        ss.x=ew_gfx_side_x(ss.slot,ss.layer,cut,count,pitch,lane,left);
        ss.yTop=bodyTop; ss.yBottom=bodyBottom;
        sides($+1)=ss;
        nodes($+1)=struct("id",ss.nodeId,"slot",ss.slot,"layer",ss.layer,"phase",ss.phase,"sign",ss.sign);
    end
    slots=list(); teeth=list();
    for ii=0:count
        slot=ew_gfx_mod(cut-1+ii,count)+1; sx=left+ii*pitch; these=list();
        for jj=1:length(sides)
            ss=sides(jj);
            if ss.slot==slot & abs(ss.x-sx)<pitch/3 then these($+1)=ss; end
        end
        slots($+1)=struct("slot",slot,"displayIndex",ii,"x",sx,"sides",these,"isSeam",ii==0 | ii==count);
    end
    for ii=0:count-1
        teeth($+1)=struct("index",ii,"toothNumber",ew_gfx_mod(cut-1+ii,count)+1,"x",left+(ii+0.5)*pitch-pitch*0.28,"y",bodyTop+8,"width",pitch*0.56,"height",bodyBottom-bodyTop-16);
    end
    coilPaths=list();
    for ii=1:length(measures)
        item=measures(ii); cc=item.coil; px=item.positiveX; nx=item.negativeUnwrappedX;
        mid=(px+nx)/2; headWidth=abs(nx-px); h=headWidth*slope/2; gap=min(8,headWidth*0.24);
        positiveIsLeft=px<nx;
        if positiveIsLeft then ppx=mid-gap/2; npx=mid+gap/2; else ppx=mid+gap/2; npx=mid-gap/2; end
        portY=bodyBottom+h-gap*slope/2;
        cc.positiveSide=ew_gfx_find_side(sides,ew_gfx_node(cc.positiveSlot,cc.positiveLayer));
        cc.negativeSide=ew_gfx_find_side(sides,ew_gfx_node(cc.negativeSlot,cc.negativeLayer));
        cc.centerX=item.centerX; cc.labelX=item.centerX; cc.wrapped=item.wrapped;
        cc.headHeight=h; cc.headSlope=slope;
        cc.positivePort=struct("x",left+ew_gfx_mod(ppx-left,period),"y",portY,"nodeId",cc.positiveSide.nodeId);
        cc.negativePort=struct("x",left+ew_gfx_mod(npx-left,period),"y",portY,"nodeId",cc.negativeSide.nodeId);
        cc.topPaths=ew_split_periodic_polyline([px,bodyTop;mid,bodyTop-h;nx,bodyTop],left,period);
        cc.bottomPaths=ew_split_periodic_polyline([px,bodyBottom;ppx,portY],left,period);
        more=ew_split_periodic_polyline([nx,bodyBottom;npx,portY],left,period);
        for jj=1:length(more) cc.bottomPaths($+1)=more(jj); end
        coilPaths($+1)=cc;
    end
    groups=list();
    for ii=1:length(coilPaths)
        cc=coilPaths(ii); newGroup=%t;
        if length(groups)>0 then gg=groups($); newGroup=gg.phase<>cc.phase; end
        if newGroup then gg=struct("id","group-"+string(length(groups)+1),"phase",cc.phase,"label",cc.phase,"coilIds",emptystr(0,1),"centers",[]); groups($+1)=gg; end
        gg=groups($); gg.coilIds($+1,1)=cc.id; gg.centers($+1)=cc.centerX;
        groups($)=gg; cc.groupId=gg.id; coilPaths(ii)=cc;
    end
    for ii=1:length(groups)
        gg=groups(ii); gg.centerX=mean(gg.centers);
        if ii==1 then gg.startX=left; else prev=groups(ii-1); gg.startX=(prev.centers($)+gg.centers(1))/2; end
        if ii==length(groups) then gg.endX=right; else following=groups(ii+1); gg.endX=(gg.centers($)+following.centers(1))/2; end
        groups(ii)=gg;
    end
    canonicalCoils=list();
    for ii=1:size(canonicalIds,"*") canonicalCoils($+1)=ew_gfx_find_coil(coilPaths,canonicalIds(ii)); end
    edges=list();
    for ii=1:length(canonicalCoils)
        cc=canonicalCoils(ii);
        edges($+1)=struct("id","coil-"+cc.id,"type","coil","phase",cc.phase,"from",cc.positiveSide.nodeId,"to",cc.negativeSide.nodeId,"coilId",cc.id);
    end
    orderedCoils=list(); connections=list(); terminals=list(); phaseChains=list(); routingLanes=list();
    terminalNames=["U","V","W"];
    for phaseIndex=1:3
        phase=phaseNames(phaseIndex); phaseCoils=list();
        for ii=1:length(canonicalCoils) cc=canonicalCoils(ii); if cc.phase==phase then phaseCoils($+1)=cc; end; end
        for ii=1:length(phaseCoils) orderedCoils($+1)=phaseCoils(ii); end
        chains=list();
        if mode=="series" then chains(1)=phaseCoils; else
            for ii=1:length(phaseCoils) chains($+1)=list(phaseCoils(ii)); end
        end
        for chainIndex=1:length(chains)
            chain=chains(chainIndex);
            if length(chain)==0 then continue; end
            chainConnections=list();
            for ii=1:length(chain)-1
                fromCoil=chain(ii); toCoil=chain(ii+1);
                a=fromCoil.negativePort; b=toCoil.positivePort;
                delta=ew_gfx_mod(b.x-a.x+period/2,period)-period/2; endX=a.x+delta;
                padding=max(6,pitch*0.12);
                clipped=ew_split_periodic_polyline([min(a.x,endX)-padding,0;max(a.x,endX)+padding,0],left,period);
                intervals=[];
                for jj=1:length(clipped) pp=clipped(jj); intervals($+1,:)=[min(pp.points(:,1)),max(pp.points(:,1))]; end
                routeLane=0;
                for jj=1:length(routingLanes)
                    occupied=routingLanes(jj); free=%t;
                    for ki=1:size(intervals,1)
                        for kj=1:size(occupied,1)
                            if ~(intervals(ki,2)<=occupied(kj,1) | intervals(ki,1)>=occupied(kj,2)) then free=%f; break; end
                        end
                        if ~free then break; end
                    end
                    if free then routeLane=jj; break; end
                end
                if routeLane==0 then
                    routeLane=length(routingLanes)+1; routingLanes(routeLane)=intervals;
                else
                    routingLanes(routeLane)=[routingLanes(routeLane);intervals];
                end
                routeY=bodyBottom+maxHeadHeight+18+(routeLane-1)*12;
                paths=ew_split_periodic_polyline([a.x,a.y;a.x,routeY;endX,routeY;endX,b.y],left,period);
                pts=[]; if length(paths)==1 then pp=paths(1); pts=pp.points; end
                groupId=""; if fromCoil.groupId==toCoil.groupId then groupId=fromCoil.groupId; end
                link=struct("id","link-"+fromCoil.id+"-"+toCoil.id,"phase",phase,"fromNode",fromCoil.negativeSide.nodeId,"toNode",toCoil.positiveSide.nodeId,"fromCoilId",fromCoil.id,"toCoilId",toCoil.id,"groupId",groupId,"paths",paths,"points",pts,"routeY",routeY,"routeLane",routeLane-1);
                connections($+1)=link; chainConnections($+1)=link;
                edges($+1)=struct("id",link.id,"type","connection","phase",phase,"from",link.fromNode,"to",link.toNode);
            end
            firstCoil=chain(1); lastCoil=chain($);
            chainId=phase+"-"+string(chainIndex); coilIds=emptystr(0,1); nodeIds=emptystr(0,1);
            terminalY=bodyBottom;
            for ii=1:length(chain)
                cc=chain(ii); coilIds($+1,1)=cc.id;
                nodeIds($+1,1)=cc.positiveSide.nodeId; nodeIds($+1,1)=cc.negativeSide.nodeId;
                terminalY=max(terminalY,cc.positivePort.y);
            end
            for ii=1:length(chainConnections) link=chainConnections(ii); terminalY=max(terminalY,link.routeY); end
            terminalY=terminalY+27;
            phaseChains($+1)=struct("id",chainId,"phase",phase,"coilIds",coilIds,"nodeIds",nodeIds,"startNodeId",firstCoil.positiveSide.nodeId,"endNodeId",lastCoil.negativeSide.nodeId);
            for terminalIndex=1:2
                if terminalIndex==1 then typ="start"; cc=firstCoil; ss=cc.positiveSide; port=cc.positivePort; else typ="end"; cc=lastCoil; ss=cc.negativeSide; port=cc.negativePort; end
                if mode=="series" then label=terminalNames(phaseIndex)+string(terminalIndex); else
                    if terminalIndex==1 then label=cc.id+"+"; else label=cc.id+"-"; end
                end
                pts=[port.x,port.y;port.x,terminalY]; paths=list(struct("points",pts,"wrapped",%f));
                terminals($+1)=struct("id",chainId+"-"+typ,"type",typ,"phase",phase,"label",label,"nodeId",ss.nodeId,"coilId",cc.id,"slot",ss.slot,"layer",ss.layer,"groupId",cc.groupId,"x",port.x,"y",terminalY,"paths",paths,"points",pts);
            end
        end
    end
    maxBottomY=bodyBottom+maxHeadHeight;
    for ii=1:length(connections) link=connections(ii); maxBottomY=max(maxBottomY,link.routeY); end
    for ii=1:length(terminals) term=terminals(ii); maxBottomY=max(maxBottomY,term.y+16); end
    geometry=struct("seamLeft",left,"seamRight",right,"period",period,"slotGap",pitch*0.44,"laneOffset",lane,"minHeadY",bodyTop-maxHeadHeight,"maxHeadY",bodyBottom+maxHeadHeight,"dimensionY",26,"slotLabelY",bodyTop-25,"toothLabelY",bodyBottom-15,"groupLabelY",maxBottomY+29,"annotationY",maxBottomY+52,"zoneLabelY",maxBottomY+29,"legendY",maxBottomY+77);
    boundaries=list();
    for ii=2:length(groups)
        gg=groups(ii); prev=groups(ii-1);
        boundaries($+1)=struct("x",gg.startX,"phaseLeft",prev.phase,"phaseRight",gg.phase);
    end
    layout=struct("valid",%t,"width",right+left,"height",geometry.legendY+36,"startSlot",cut,"canonicalStartSlot",canonicalCut,"connectionMode",mode,"slotPitch",pitch,"bodyTop",bodyTop,"bodyBottom",bodyBottom,"teeth",teeth,"slots",slots,"coilPaths",coilPaths,"orderedCoils",orderedCoils,"groups",groups,"connections",connections,"seriesConnections",connections,"terminals",terminals,"topology",struct("nodes",nodes,"edges",edges,"phaseChains",phaseChains),"geometry",geometry,"polePitchDimension",struct("x1",left,"x2",left+w.polePitch*pitch,"y",26,"label","tau_p = "+string(w.polePitch)),"zoneBoundaries",boundaries,"description","Leiter in den Nuten zwischen den blauen Zähnen; offene additive Serienstränge. Abwicklung ab Nut "+string(cut)+". L1 rechts, L2 links aufgefächert.","warnings",emptystr(0,1));
endfunction

function ew_gfx_paths(paths,col,lineWidth,casing)
    if argn(2)<4 then casing=%f; end
    for ii=1:length(paths)
        pp=paths(ii);
        if casing then ew_gfx_line(pp.points,color("white"),lineWidth+3.2); end
        ew_gfx_line(pp.points,col,lineWidth);
    end
endfunction

function ax = ew_plot_winding(w,mode,startSlot,phaseFilter,ax,selection)
    if argn(2)<2 then mode="series"; end
    if argn(2)<3 then startSlot=0; end
    if argn(2)<4 then phaseFilter=""; end
    if argn(2)<5 then ax=[]; end
    if argn(2)<6 then selection=struct(); end
    ax=ew_gfx_prepare("Wickelschema - Leiter in Nuten zwischen den Zähnen",ax);
    chosen=ew_gfx_selected_coil(w,selection); hasChoice=typeof(chosen)=="st"; chosenId="";
    if hasChoice then chosenId=chosen.id; end
    activeIds=ew_gfx_active_coils(w,selection); hasHighlight=~isempty(activeIds);
    hits=list();
    layout=ew_build_winding_layout(w,mode,startSlot);
    if ~layout.valid then
        ax.data_bounds=[0,0;1,1]; ew_gfx_text(0.05,0.5,"Keine vollständige Wicklung: Bitte Eingaben prüfen."); return;
    end
    ax.axes_reverse=["off","on","off"];
    ax.data_bounds=[0,0;layout.width,layout.height];
    ax.isoview="off";
    gray=addcolor([0.66,0.69,0.64]); dark=addcolor([0.22,0.29,0.21]); blue=addcolor([0.02,0.62,0.98]);
    for ii=1:length(layout.teeth)
        tt=layout.teeth(ii); pts=[tt.x,tt.y;tt.x+tt.width,tt.y;tt.x+tt.width,tt.y+tt.height;tt.x,tt.y+tt.height];
        ew_gfx_polygon(pts,blue); ew_gfx_line([pts;pts(1,:)],dark,0.7);
        ew_gfx_text(tt.x+tt.width*0.25,layout.geometry.toothLabelY,"Z"+string(tt.toothNumber),color("white"),1);
    end
    for ii=1:length(layout.slots)
        ss=layout.slots(ii);
        ew_gfx_text(ss.x-layout.slotPitch*0.08,layout.geometry.slotLabelY,string(ss.slot),dark,1.5);
    end
    // Roofs, separated V-head halves, and real active sides. No closed
    // short-circuit polygon is used for an individual coil.
    for ii=1:length(layout.coilPaths)
        cc=layout.coilPaths(ii);
        selected=or(activeIds==cc.id);
        if phaseFilter<>"" & cc.phase<>phaseFilter & ~selected then continue; end
        col=ew_gfx_link_color(cc.phase,hasHighlight & ~selected); lineWidth=1.4;
        if selected then lineWidth=3.5; end
        ew_gfx_paths(cc.topPaths,col,lineWidth,%t);
        ew_gfx_paths(cc.bottomPaths,col,lineWidth,%t);
        for which=1:2
            if which==1 then ss=cc.positiveSide; sgn=1; else ss=cc.negativeSide; sgn=-1; end
            ew_gfx_line([ss.x,layout.bodyTop;ss.x,layout.bodyBottom],color("white"),5);
            ew_gfx_line([ss.x,layout.bodyTop;ss.x,layout.bodyBottom],col,lineWidth);
            midY=(layout.bodyTop+layout.bodyBottom)/2;
            // The 6.16-unit-wide solid tip fits even Q120's two-layer gap:
            // pitch36, lane4.32, halfgap7.92; 4.32+3.08 < 7.92.
            ew_gfx_arrow(ss.x,midY+sgn*28,ss.x,midY-sgn*28,col,lineWidth);
            if which==1 then slot=cc.positiveSlot; layer=cc.positiveLayer; else slot=cc.negativeSlot; layer=cc.negativeLayer; end
            hits=ew_gfx_hit(hits,"coil",cc.id,ss.x,midY,slot,layer);
            hits=ew_gfx_hit(hits,"coil",cc.id,ss.x,layout.bodyTop+16,slot,layer);
            if selected then
                symbol="+"; if sgn<0 then symbol="-"; end
                ew_gfx_text(ss.x-layout.slotPitch*0.04,layout.bodyTop+7,symbol,col,2);
            end
        end
        fontSize=1; if selected then fontSize=2.2; end
        ew_gfx_text(cc.labelX-layout.slotPitch*0.11,layout.bodyTop-8,cc.id,col,fontSize);
        hits=ew_gfx_hit(hits,"coil",cc.id,cc.labelX,layout.bodyTop-8);
    end
    for ii=1:length(layout.connections)
        link=layout.connections(ii);
        if phaseFilter<>"" & link.phase<>phaseFilter then continue; end
        ew_gfx_paths(link.paths,ew_gfx_link_color(link.phase,hasHighlight),1.3,%t);
    end
    for ii=1:length(layout.terminals)
        term=layout.terminals(ii);
        if phaseFilter<>"" & term.phase<>phaseFilter then continue; end
        col=ew_gfx_link_color(term.phase,hasHighlight & ~or(activeIds==term.coilId)); ew_gfx_paths(term.paths,col,1.6,%f);
        ew_gfx_text(term.x-layout.slotPitch*0.1,term.y+12,term.label,col,1.6);
    end
    for ii=1:length(layout.zoneBoundaries)
        bb=layout.zoneBoundaries(ii); ew_gfx_line([bb.x,layout.geometry.minHeadY-8;bb.x,layout.geometry.groupLabelY+9],gray,0.6,2);
    end
    dim=layout.polePitchDimension;
    ew_gfx_line([dim.x1,dim.y;dim.x2,dim.y],dark,1);
    ew_gfx_line([dim.x1,dim.y-5;dim.x1,dim.y+5],dark,1);
    ew_gfx_line([dim.x2,dim.y-5;dim.x2,dim.y+5],dark,1);
    ew_gfx_text((dim.x1+dim.x2)/2-layout.slotPitch*0.7,dim.y-9,"tau_p = Q/(2p) = "+msprintf("%.4g",w.polePitch)+" Nutteilungen",dark,1.5);
    ew_gfx_text(60,layout.geometry.annotationY,"Schnittnut "+string(layout.startSlot)+" | "+mode+" | L1 rechts, L2 links | Blau: Zähne; Weiß: Nuten",dark,1.5);
    legend="Plus-Seite: Pfeil aufwärts; Minus-Seite: abwärts. Stränge: A / B / C";
    if hasChoice then legend=chosen.id+": +Nut "+string(chosen.positiveSlot)+"/L"+string(chosen.positiveLayer)+"; -Nut "+string(chosen.negativeSlot)+"/L"+string(chosen.negativeLayer)+". Auswahl in allen Ansichten gekoppelt."; end
    if typeof(selection)=="st" then
        if isfield(selection,"activeCoilIds") then
            legend="Animationsschritt: "+strcat(activeIds,", ")+" hervorgehoben. Gewählte Ausgangsspule: "+chosenId+". Verschaltung unverändert.";
        end
    end
    ew_gfx_text(60,layout.geometry.legendY,legend,dark,1.5);
    ew_gfx_set_hits(ax,hits,"winding");
    metadata=ax.user_data;metadata.activeCoilIds=activeIds;metadata.selectedCoilId=chosenId;
    ax.user_data=metadata;
endfunction
// Native Scilab plots. The coefficients and geometry come from the numerical
// models; no plot changes conductor signs or independently rotates phases.

function label = ew_gfx_number(value, digits)
    if argn(2) < 2 then digits = 3; end
    if abs(value) < 1d-10 then value = 0; end
    label = strsubst(msprintf("%.*f", digits, value), ".", ",");
endfunction

function ax = ew_plot_slot_star(w, axesHandle, selection)
    if argn(2) < 2 then axesHandle = []; end
    if argn(2) < 3 then selection = struct(); end
    chosen = ew_gfx_selected_coil(w,selection); hasChoice = typeof(chosen)=="st"; hits=list();
    ax = ew_gfx_prepare("Nutenspannungsstern - elektrische Winkel", axesHandle);
    ax.data_bounds = [-1.45, -1.45; 1.45, 1.45];
    if hasChoice then ax.data_bounds = [-1.45,-1.72;1.45,1.45]; end
    ax.isoview = "on";
    ax.axes_visible = ["off", "off", "off"];
    if length(w.slotAssignments) == 0 then
        ew_gfx_text(-1, 0, "Keine Nutzuordnung verfuegbar", color("black"), 2);
        return;
    end
    pale = [0.97 0.87 0.82; 0.84 0.93 0.88; 0.85 0.89 0.98];
    phaseNames = ["A", "B", "C"];
    zonePhases = ["A", "C", "B", "A", "C", "B"];
    zoneNames = ["+A", "-C", "+B", "-A", "+C", "-B"];
    for zone = 1:6
        angles = (w.zoneOffsetDeg + (zone - 1)*60 + linspace(0,60,25)) * %pi/180;
        piIndex = find(phaseNames == zonePhases(zone));
        wedge = [0, 0; cos(angles)', sin(angles)'; 0, 0];
        ew_gfx_polygon(wedge, addcolor(pale(piIndex,:)));
        angle = (w.zoneOffsetDeg + (zone - 1)*60 + 30)*%pi/180;
        ew_gfx_text(1.17*cos(angle)-0.055, 1.17*sin(angle), zoneNames(zone), ew_gfx_phase_color(zonePhases(zone)), 3);
    end
    angles = linspace(0,2*%pi,181);
    ew_gfx_line([cos(angles)',sin(angles)'], color("grey"), 1);
    ew_gfx_line([-1.25,0;1.25,0],color("grey"),1,2);
    ew_gfx_line([0,-1.25;0,1.25],color("grey"),1,2);
    allAngles = zeros(1,length(w.slotAssignments));
    for n = 1:length(w.slotAssignments)
        side = w.slotAssignments(n);
        allAngles(n) = side.angleDeg;
    end
    visited = zeros(1,length(w.slotAssignments));
    for n = 1:length(w.slotAssignments)
        if visited(n) == 1 then continue; end
        indices = find(abs(allAngles - allAngles(n)) < 1d-7);
        visited(indices) = 1;
        side = w.slotAssignments(n);
        angle = side.angleDeg * %pi/180;
        ew_gfx_arrow(0,0,0.96*cos(angle),0.96*sin(angle),ew_gfx_link_color(side.phase,hasChoice),1.3);
        numbers = emptystr(size(indices,"*"),1);
        for j = 1:size(indices,"*")
            member = w.slotAssignments(indices(j)); numbers(j)=string(member.slot);
        end
        if size(numbers,"*") > 5 then
            label = strcat(numbers(1:3),",") + ".." + numbers($);
        else
            label = strcat(numbers,",");
        end
        ew_gfx_text(1.03*cos(angle)-0.035,1.03*sin(angle),label,color("black"),2);
    end
    // All actual layers remain selectable, even when several electrical rays
    // coincide. The GUI cycles equally close targets instead of inventing one.
    for n=1:length(w.coils)
        coil=w.coils(n);
        for which=1:2
            if which==1 then slot=coil.positiveSlot;layer=coil.positiveLayer; else slot=coil.negativeSlot;layer=coil.negativeLayer;end
            angle=2*%pi*w.polePairs*(slot-1)/w.slots;
            hits=ew_gfx_hit(hits,"coil",coil.id,0.96*cos(angle),0.96*sin(angle),slot,layer);
        end
    end
    if hasChoice then
        col=ew_gfx_phase_color(chosen.phase);
        plus=2*%pi*w.polePairs*(chosen.positiveSlot-1)/w.slots;
        minus=2*%pi*w.polePairs*(chosen.negativeSlot-1)/w.slots;
        rawMinusColor=addcolor([0.38,0.43,0.36]);
        ew_gfx_line([0,0;cos(minus),sin(minus)],rawMinusColor,2,2);
        ew_gfx_arrow(0,0,cos(plus),sin(plus),col,3.4);
        hits=ew_gfx_hit(hits,"coil",chosen.id,cos(plus),sin(plus),chosen.positiveSlot,chosen.positiveLayer);
        ew_gfx_arrow(0,0,-0.83*cos(minus),-0.83*sin(minus),col,3.4);
        hits=ew_gfx_hit(hits,"coil",chosen.id,-0.83*cos(minus),-0.83*sin(minus),chosen.negativeSlot,chosen.negativeLayer);
        ew_gfx_text(1.10*cos(plus)-0.05,1.10*sin(plus)+0.09,"+N"+string(chosen.positiveSlot)+"/L"+string(chosen.positiveLayer),col,2);
        ew_gfx_text(-0.87*cos(minus)-0.05,-0.87*sin(minus)-0.14,"-N"+string(chosen.negativeSlot)+"/L"+string(chosen.negativeLayer),col,2);
        ew_gfx_text(-1.40,-1.43,chosen.id+": volle Pfeile = vorzeichenrichtige Seitenbeitraege",col,1.5);
        ew_gfx_text(-1.40,-1.61,"Grau gestrichelt: rohe Minus-Nutspannung vor der Umkehr um 180 Grad.",rawMinusColor,1.4);
    else
        ew_gfx_text(-1.4,-1.4,msprintf("Q = %d, p = %d, q = %.5g",w.slots,w.polePairs,w.q),color("black"),2);
    end
    ew_gfx_set_hits(ax,hits,"slot-star");
endfunction

function ax = ew_plot_phase_star(w, axesHandle, selection)
    if argn(2) < 2 then axesHandle = []; end
    if argn(2) < 3 then selection=struct(); end
    chosen=ew_gfx_selected_coil(w,selection); hasChoice=typeof(chosen)=="st"; hits=list();
    ax = ew_gfx_prepare("Strangspannungsstern - Addition der tatsaechlichen Nutseiten",axesHandle);
    ax.data_bounds = [-1.4,-1.4;1.4,1.4]; ax.isoview="on";
    if hasChoice then ax.data_bounds=[-1.4,-1.62;1.4,1.4]; end
    ax.axes_visible=["off","off","off"];
    if ~w.valid then
        ew_gfx_text(-1.2,0,"Keine vollstaendige Wicklung: Strangstern nicht verfuegbar",color("black"),2);
        return;
    end
    count = 1;
    for index=1:length(w.phases)
        item=w.phases(index); count=max(count,item.sideCount);
    end
    circle=linspace(0,2*%pi,181);
    ew_gfx_line([cos(circle)',sin(circle)'],color("grey"),1,2);
    ew_gfx_line([-1.18,0;1.18,0],color("grey"),1);
    ew_gfx_line([0,-1.18;0,1.18],color("grey"),1);
    for index=1:length(w.phases)
        phase=w.phases(index); phaseColor=ew_gfx_link_color(phase.phase,hasChoice);
        chain=[0,0]; current=[0,0];
        for n=1:length(w.slotLayers)
            side=w.slotLayers(n);
            if side.phase <> phase.phase then continue; end
            angle=side.angleDeg*%pi/180;
            previous=current;
            current=current+side.sign*[cos(angle),sin(angle)]/count;
            chain($+1,:)=current;
            coilId=ew_gfx_side_coil(w,side.slot,side.layer);
            middle=(previous+current)/2;
            hits=ew_gfx_hit(hits,"coil",coilId,middle(1),middle(2),side.slot,side.layer);
            hits=ew_gfx_hit(hits,"coil",coilId,current(1),current(2),side.slot,side.layer);
        end
        ew_gfx_line(chain,phaseColor,1,2);
        endpoint=[phase.x,phase.y]/count;
        ew_gfx_arrow(0,0,endpoint(1),endpoint(2),phaseColor,3);
        angle=atan(endpoint(2),endpoint(1));
        ew_gfx_text(1.13*cos(angle)-0.08,1.13*sin(angle),phase.phase+" : kw = "+ew_gfx_number(phase.kw,5),phaseColor,2);
    end
    if hasChoice then
        col=ew_gfx_phase_color(chosen.phase); current=[0,0]; selectedSidePoints=list();
        for n=1:length(w.slotLayers)
            side=w.slotLayers(n);
            if side.phase<>chosen.phase then continue; end
            angle=side.angleDeg*%pi/180;
            next=current+side.sign*[cos(angle),sin(angle)]/count;
            if ew_gfx_is_selected_side(chosen,side.slot,side.layer) then
                selectedSidePoints($+1)=struct("start",current,"finish",next,"side",side);
            end
            current=next;
        end
        for n=1:length(selectedSidePoints)
            segment=selectedSidePoints(n); side=segment.side;
            ew_gfx_arrow(segment.start(1),segment.start(2),segment.finish(1),segment.finish(2),col,3.2);
            middle=(segment.start+segment.finish)/2;
            hits=ew_gfx_hit(hits,"coil",chosen.id,middle(1),middle(2),side.slot,side.layer);
        end
        plus=2*%pi*w.polePairs*(chosen.positiveSlot-1)/w.slots;
        minus=2*%pi*w.polePairs*(chosen.negativeSlot-1)/w.slots;
        selectedVector=[cos(plus)-cos(minus),sin(plus)-sin(minus)]/count;
        ew_gfx_arrow(0,0,selectedVector(1),selectedVector(2),col,4);
        hits=ew_gfx_hit(hits,"coil",chosen.id,selectedVector(1),selectedVector(2),chosen.positiveSlot,chosen.positiveLayer);
        ew_gfx_text(selectedVector(1)+0.04,selectedVector(2)-0.10,chosen.id+": Spulenbeitrag",col,2);
        ew_gfx_text(-1.35,-1.35,"Kräftig: gewählte Spule und ihre beiden Schritte in der Strangaddition.",col,1.5);
        ew_gfx_text(-1.35,-1.53,"Alle Vektoren durch maximale Strang-Seitenzahl normiert; Grundwelle k=p.",color("black"),1.5);
    else
        ew_gfx_text(-1.35,-1.35,"Gestrichelt: Vektoraddition; Pfeile: normierte Strangresultanten",color("black"),2);
    end
    ew_gfx_set_hits(ax,hits,"phase-star");
endfunction

function ax = ew_plot_zone_plan(w, axesHandle, selection)
    if argn(2)<2 then axesHandle=[]; end
    if argn(2)<3 then selection=struct(); end
    chosen=ew_gfx_selected_coil(w,selection); hasChoice=typeof(chosen)=="st"; hits=list();
    ax=ew_gfx_prepare("Zonenplan - Spulenseiten in den Nuten zwischen blauen Zaehnen",axesHandle);
    ax.data_bounds=[0.2,-0.4;w.slots+1.8,3.6];
    ax.isoview="off"; ax.axes_visible=["off","off","off"];
    blue=addcolor([0,0.58,0.95]);
    for n=1:w.slots
        ew_gfx_polygon([n+0.2,0.55;n+0.8,0.55;n+0.8,2.15;n+0.2,2.15],blue);
        side=w.slotAssignments(n);
        ew_gfx_polygon([n-0.18,2.65;n+0.18,2.65;n+0.18,3.05;n-0.18,3.05],ew_gfx_phase_color(side.phase));
        ew_gfx_text(n-0.15,3.15,side.zone,color("black"),2);
        ew_gfx_text(n-0.11,0.1,string(n),color("black"),2);
    end
    ew_gfx_text(w.slots+0.88,0.1,"1",color("black"),2);
    for n=1:length(w.slotLayers)
        side=w.slotLayers(n);
        lane=0;
        if w.layers==2 then lane=0.08*(3-2*side.layer); end
        xpos=side.slot+lane;
        selected=ew_gfx_is_selected_side(chosen,side.slot,side.layer);
        if side.sign>0 then ya=0.72; yb=1.94; else ya=1.94; yb=0.72; end
        col=ew_gfx_link_color(side.phase,hasChoice & ~selected); width=1.5;
        if selected then width=3.5;
            ew_gfx_polygon([xpos-0.055,0.57;xpos+0.055,0.57;xpos+0.055,2.13;xpos-0.055,2.13],addcolor([1,0.95,0.84]));
        end
        ew_gfx_arrow(xpos,ya,xpos,yb,col,width);
        coilId=ew_gfx_side_coil(w,side.slot,side.layer);
        hits=ew_gfx_hit(hits,"coil",coilId,xpos,(ya+yb)/2,side.slot,side.layer);
        if selected then ew_gfx_text(xpos-0.12,2.25,chosen.id+"/L"+string(side.layer),col,1.5); end
    end
    legend="Nuten: 1..Q, periodische Randnut 1; L1 rechts / L2 links aufgefaechert";
    if hasChoice then legend=chosen.id+": +Nut "+string(chosen.positiveSlot)+"/L"+string(chosen.positiveLayer)+" und -Nut "+string(chosen.negativeSlot)+"/L"+string(chosen.negativeLayer)+" hervorgehoben. Seiten anklicken: Spule wählen."; end
    ew_gfx_text(0.5,-0.25,legend,color("black"),2);
    ew_gfx_set_hits(ax,hits,"zone-plan");
endfunction

function ax=ew_plot_spectrum(spectrum,displayMode,phase,axesHandle,selection)
    if argn(2)<2 then displayMode="real"; end
    if argn(2)<3 then phase="A"; end
    if argn(2)<4 then axesHandle=[]; end
    if argn(2)<5 then selection=struct(); end
    chosenOrder=ew_gfx_selected_order(selection); hits=list();
    plotTitle="Raumspektrum - Strang "+phase;
    if isfield(spectrum,"title") then plotTitle="Raumspektrum - "+spectrum.title;end
    ax=ew_gfx_prepare(plotTitle,axesHandle);
    if ~spectrum.valid then
        ax.data_bounds=[0,0;1,1];
        ew_gfx_text(0.03,0.5,"Kein gueltiges Spektrum verfuegbar",color("black"),2); return;
    end
    orders=zeros(1,length(spectrum.coefficients)); values=orders;
    for n=1:length(spectrum.coefficients)
        item=spectrum.coefficients(n); orders(n)=item.order;
        if displayMode=="magnitude" then values(n)=item.amplitude; else values(n)=item.real; end
    end
    upper=max([values,0]); lower=min([values,0]);
    spread=max(upper-lower,0.01);
    ax.data_bounds=[0,lower-0.12*spread;max(orders)+1,upper+0.2*spread];
    ax.isoview="off"; ax.axes_visible=["on","on","off"];
    ax.x_label.text="Mechanische Raumordnung k";
    if displayMode=="magnitude" then ax.y_label.text="Betrag |C_k|"; else ax.y_label.text="Reeller Anteil Re(C_k)"; end
    ax.box="off";
    ew_gfx_line([0,0;max(orders)+1,0],color("grey"),1);
    phaseColor=ew_gfx_phase_color(phase);
    for n=1:size(orders,"*")
        width=1.6;
        if size(spectrum.fundamentalOrder,"*")>0 then
            if orders(n)==spectrum.fundamentalOrder then width=3; end
        end
        selected=%f;
        if ~isempty(chosenOrder) then selected=orders(n)==chosenOrder; end
        col=ew_gfx_link_color(phase,~isempty(chosenOrder) & ~selected);
        if selected then width=4; end
        ew_gfx_line([orders(n),0;orders(n),values(n)],col,width);
        hits=ew_gfx_hit(hits,"order","",orders(n),values(n)/2,0,0,orders(n));
        hits=ew_gfx_hit(hits,"order","",orders(n),values(n),0,0,orders(n));
    end
    if size(spectrum.fundamentalOrder,"*")>0 then
        label="Nutzgrundwelle k = p = "+string(spectrum.fundamentalOrder);
        if spectrum.fundamentalOrder>max(orders) then label=label+" (ausserhalb des Plotbereichs)";end
    else
        label="Analytische Referenz ohne festgelegte Polpaarzahl";
    end
    if ~isempty(chosenOrder) then
        label=label+"; gewählt k="+string(chosenOrder);
        if chosenOrder>max(orders) then label=label+" ausserhalb des Plotbereichs"; end
    end
    ew_gfx_text(0.3,upper+0.13*spread,label,color("black"),2);
    ew_gfx_set_hits(ax,hits,"spectrum");
endfunction

function ax=ew_plot_axes(data,phase,coilId,axesHandle)
    if argn(2)<2 then phase="A"; end
    if argn(2)<3 then coilId=""; end
    if argn(2)<4 then axesHandle=[]; end
    ax=ew_gfx_prepare("Spulen- und Strangmittelachsen: orientierte MMF-Grundwelle",axesHandle);
    hits=list();
    ax.data_bounds=[-1.5,-1.62;1.5,1.5]; ax.isoview="on";
    ax.axes_visible=["off","off","off"];
    if ~data.valid then
        ew_gfx_text(-1.3,0,"Keine Induktivitaetsdaten verfuegbar",color("black"),2); return;
    end
    circle=linspace(0,2*%pi,181);
    ew_gfx_line([cos(circle)',sin(circle)'],color("grey"),1);
    for angleDeg=[0,60,120,180,240,300]
        angle=angleDeg*%pi/180;
        ew_gfx_line([0,0;cos(angle),sin(angle)],color("grey"),1,2);
        ew_gfx_text(1.12*cos(angle)-0.07,1.12*sin(angle),string(angleDeg)+"°",color("grey"),2);
    end
    chosen=[]; first=%t;
    phaseColor=ew_gfx_phase_color(phase);
    for n=1:length(data.coils)
        coil=data.coils(n);
        if coil.phase<>phase | size(coil.axisRad,"*")==0 then continue; end
        if isnan(coil.axisRad) | isinf(coil.axisRad) then continue;end
        selected=(coil.id==coilId);
        if coilId=="" & first then selected=%t; end
        first=%f;
        angle=coil.axisRad*data.polePairs; width=1;
        if selected then width=3; chosen=coil; end
        col=ew_gfx_link_color(phase,coilId<>"" & ~selected);
        ew_gfx_arrow(0,0,cos(angle),sin(angle),col,width);
        hits=ew_gfx_hit(hits,"coil",coil.id,cos(angle),sin(angle),coil.positiveSlot,coil.positiveLayer);
        if selected then ew_gfx_text(1.28*cos(angle)-0.05,1.28*sin(angle),coil.id,phaseColor,3); end
    end
    for n=1:length(data.phases)
        item=data.phases(n);
        if item.phase==phase & size(item.axisRad,"*")>0 then
            if isnan(item.axisRad) | isinf(item.axisRad) then continue;end
            angle=item.axisRad*data.polePairs;
            ew_gfx_line([0,0;1.18*cos(angle),1.18*sin(angle)],color("black"),2,2);
        end
    end
    if typeof(chosen)=="st" then
        ew_gfx_text(-1.42,-1.38,chosen.id+": geometrische Mitte = "+ew_gfx_number(chosen.centerDeg,2)+"°; relative elektrische Achse = "+ew_gfx_number(chosen.relativeElectricalDeg,2)+"°",phaseColor,2);
    end
    ew_gfx_text(-1.42,-1.55,"Elektrisch gefaltet: alpha = p*phi. Gestrichelt: gemeinsame Strangmittelachse.",color("black"),2);
    ew_gfx_set_hits(ax,hits,"axes");
endfunction

function ax=ew_plot_field(data,axesHandle)
    if argn(2)<2 then axesHandle=[]; end
    ax=ew_gfx_prepare("Durchflutung und Luftspaltflussdichte am Statorumfang",axesHandle);
    ax.data_bounds=[-40,-0.15;382,3.2]; ax.isoview="off";
    ax.axes_visible=["off","off","off"];
    if ~data.valid then
        ew_gfx_text(0,1.5,"Keine Felddaten verfuegbar",color("black"),2); return;
    end
    exactColor=ew_gfx_phase_color("A"); fourierColor=ew_gfx_phase_color("B");
    exactTheta=zeros(1,length(data.segments)); exactB=exactTheta;
    for n=1:length(data.segments)
        segment=data.segments(n); exactTheta(n)=segment.thetaAmpereTurns; exactB(n)=segment.bTesla*1000;
    end
    harmonicTheta=zeros(1,length(data.samples)); harmonicB=harmonicTheta; sampleDeg=harmonicTheta;
    for n=1:length(data.samples)
        sample=data.samples(n); sampleDeg(n)=sample.angleDeg;
        harmonicTheta(n)=sample.harmonicThetaAmpereTurns; harmonicB(n)=sample.harmonicBTesla*1000;
    end
    for row=1:2
        if row==1 then
            exact=exactTheta; harmonic=harmonicTheta; base=2.3; label="Durchflutung Theta [A Wdg]";
        else
            exact=exactB; harmonic=harmonicB; base=0.8; label="Luftspaltflussdichte B [mT]";
        end
        bound=max(abs([exact,harmonic]))*1.1;
        if bound<1d-12 then bound=1; end
        for tick=[-1,0,1]
            ypos=base+0.5*tick;
            ew_gfx_line([0,ypos;360,ypos],color("grey"),1,2);
            ew_gfx_text(-37,ypos,ew_gfx_number(tick*bound,2),color("grey"),2);
        end
        for tick=[0,60,120,180,240,300,360]
            ew_gfx_line([tick,base-0.5;tick,base+0.5],color("grey"),1,2);
            ew_gfx_text(tick-5,base-0.67,string(tick)+"°",color("grey"),2);
        end
        exactPath=zeros(2*length(data.segments),2);
        for n=1:length(data.segments)
            segment=data.segments(n); ypos=base+0.5*exact(n)/bound;
            exactPath(2*n-1,:)=[segment.startRad*180/%pi,ypos];
            exactPath(2*n,:)=[segment.endRad*180/%pi,ypos];
        end
        ew_gfx_line(exactPath,exactColor,2);
        ew_gfx_line([sampleDeg', (base+0.5*harmonic/bound)'],fourierColor,1,2);
        ew_gfx_text(0,base+0.63,label,color("black"),3);
    end
    ew_gfx_text(0,3.08,"Rot: exakte Stufenfunktion; gruen gestrichelt: Fourier bis K = "+string(data.parameters.maxOrder),color("black"),2);
    currents=data.parameters.currents;
    ew_gfx_text(0,-0.12,"delta_eff = "+ew_gfx_number(data.parameters.gapM*1000,3)+" mm; n = "+string(data.parameters.turnsPerCoil)+" Wdg/Spule; i(A,B,C) = ("+ew_gfx_number(currents(1),3)+"; "+ew_gfx_number(currents(2),3)+"; "+ew_gfx_number(currents(3),3)+") A",color("black"),2);
endfunction
