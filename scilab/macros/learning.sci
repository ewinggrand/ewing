// Linked selection and harmonic learning model. All physical coupling uses
// unrotated Fourier coefficients in ONE shared mechanical coordinate.
// Voltage phasors E_k=sum s*exp(+i*k*phi) are kept separate from
// C_k=conj(E_k)/(2*i*k). No phase-specific plot rotation enters L_ab.

function value = ew_learning_value(parts)
    value = parts.real + %i * parts.imag;
endfunction

function signature = ew_learning_signature(w, parameters)
    signature = msprintf("Q%.17g/p%.17g/L%.17g/r%.17g/l%.17g/d%.17g/n%.17g", ..
        w.slots, w.polePairs, w.layers, parameters.radiusM, parameters.lengthM, ..
        parameters.gapM, parameters.turnsPerCoil);
    for index = 1:length(w.slotLayers)
        side = w.slotLayers(index);
        signature = signature + msprintf("|%d:%d:%s:%d",side.slot,side.layer,side.phase,side.sign);
    end
endfunction

function data = ew_compute_convergence(w, options, maxOrder)
    if argn(2) < 2 then options = struct(); end
    if argn(2) < 3 then maxOrder = 120; end
    ew_i_require(maxOrder,"Höchste Konvergenzordnung",1,2000,%t,%t);
    parameters = ew_inductance_parameters(w, options);
    parameters.maxOrder = maxOrder;
    data = struct("valid",%f,"maxOrder",maxOrder,"parameters",parameters, ..
        "orders",[],"partialSelfH",[],"partialMutualH",[],"relativeError",[], ..
        "relativeErrorK",[],"partialMatricesH",list(),"contributions",list(), ..
        "exactMatrixH",[],"matrixH",[],"finalMatrixH",[],"coefficients",[], ..
        "phaseOrder",["A";"B";"C"],"mutualPairs",["AB";"AC";"BC"], ..
        "signature","","warnings",emptystr(0,1));
    message = ew_i_winding_error(w);
    if message <> "" then data.warnings=message; return; end
    Q = w.slots; count = length(w.slotLayers);
    jumps = zeros(Q,3); weights = zeros(3,count); angles=zeros(count,1);
    for index = 1:count
        side=w.slotLayers(index); a=ew_i_phase_index(side.phase);
        jumps(side.slot,a)=jumps(side.slot,a)+side.sign;
        weights(a,index)=side.sign;
        angles(index)=2*%pi*(side.slot-1)/Q;
    end
    unitWinding=cumsum(jumps,1);
    unitWinding=unitWinding-ones(Q,1)*mean(unitWinding,1);
    geometric=4*%pi*1d-7*parameters.radiusM*parameters.lengthM/parameters.gapM;
    exact=geometric*parameters.turnsPerCoil^2*(2*%pi/Q)*(unitWinding'*unitWinding);
    prefactor=4*geometric*parameters.turnsPerCoil^2/%pi;
    // Vectorisation avoids constructing full field samples for every order.
    orders=1:maxOrder;
    coefficients=(weights*exp(-%i*angles*orders))./(ones(3,1)*(2*%i*orders));
    data.orders=orders'; data.partialSelfH=zeros(maxOrder,3);
    data.partialMutualH=zeros(maxOrder,3); data.relativeError=zeros(maxOrder,1);
    data.coefficients=zeros(maxOrder,6);
    cumulative=zeros(3,3); denominator=norm(exact,"fro");
    for k=1:maxOrder
        values=coefficients(:,k);
        delta=prefactor*real(values*values');
        cumulative=cumulative+delta;
        data.contributions($+1)=delta;
        data.partialMatricesH($+1)=cumulative;
        data.partialSelfH(k,:)=[cumulative(1,1),cumulative(2,2),cumulative(3,3)];
        data.partialMutualH(k,:)=[cumulative(1,2),cumulative(1,3),cumulative(2,3)];
        if denominator>0 then data.relativeError(k)=norm(exact-cumulative,"fro")/denominator; end
        data.coefficients(k,:)=[real(values(1)),imag(values(1)),real(values(2)),imag(values(2)),real(values(3)),imag(values(3))];
    end
    data.relativeErrorK=data.relativeError;
    data.exactMatrixH=exact; data.matrixH=exact; data.finalMatrixH=cumulative;
    data.fourierPrefactorH=prefactor;
    data.signature=ew_learning_signature(w,parameters);
    data.valid=%t;
    data.description="Stückweise exaktes Gram-Integral und kumulierte gemeinsame Fourier-Produkte. K beeinflusst nur die Näherung.";
endfunction

function node = ew_learning_node(members, order, p, referenceAxis, id, selectedId)
    raw=0; fundamental=0; ids=emptystr(0,1); pieces=list();
    for index=1:length(members)
        coil=members(index); coefficient=ew_i_coil_coefficient(coil,order);
        cp=ew_i_coil_coefficient(coil,p);
        raw=raw+coefficient; fundamental=fundamental+cp;
        ids($+1)=coil.id;
        pieces($+1)=struct("id",coil.id,"coilId",coil.id,"phase",coil.phase, ..
            "isSelected",coil.id==selectedId,"rawFourier",ew_i_complex(coefficient), ..
            "rawCoefficient",ew_i_complex(coefficient), ..
            "voltageFundamental",ew_i_complex(conj(2*%i*p*cp)), ..
            "voltageHarmonic",ew_i_complex(conj(2*%i*order*coefficient)));
    end
    node=struct("id",id,"phase",members(1).phase,"coilIds",ids, ..
        "coilCount",length(members),"members",pieces, ..
        "rawFourier",ew_i_complex(raw),"rawCoefficient",ew_i_complex(raw), ..
        "voltageFundamental",ew_i_complex(conj(2*%i*p*fundamental)), ..
        "voltageHarmonic",ew_i_complex(conj(2*%i*order*raw)), ..
        "factors",ew_i_factors(members,order,referenceAxis));
endfunction

function members = ew_learning_members(geometry, ids)
    members=list();
    for index=1:length(geometry)
        if or(ids==geometry(index).id) then members($+1)=geometry(index); end
    end
endfunction

function [node, groups] = ew_learning_phase_node(d, phase, order, selectedId)
    a=ew_i_phase_index(phase); members=list(); groups=list();
    for index=1:length(d.coils)
        if d.coils(index).phase==phase then members($+1)=d.coils(index); end
    end
    phaseAxis=d.phases(a).axisRad;
    node=ew_learning_node(members,order,d.polePairs,phaseAxis,phase,selectedId);
    for index=1:length(d.groups)
        group=d.groups(index);
        if group.phase<>phase then continue; end
        gm=ew_learning_members(d.coils,group.coilIds);
        gn=ew_learning_node(gm,order,d.polePairs,group.axisRad,group.id,selectedId);
        gn.axisRad=group.axisRad; gn.axisDeg=group.axisDeg;
        gn.weight=length(gm)/length(members);
        ga=group.axisRad; pa=phaseAxis;
        if isnan(ga) then ga=0; end
        if isnan(pa) then pa=0; end
        gn.phaseContribution=ew_i_complex(gn.weight*ew_learning_value(gn.factors.distributionFactor)*exp(-%i*order*(ga-pa)));
        gn.isSelected=or(gn.coilIds==selectedId);
        groups($+1)=gn;
    end
    node.members=groups;
endfunction

function data = ew_compute_learning(w,d,coilId,phase,sourcePhase,order,maxConvergenceOrder,cachedConvergence)
    if argn(2)<3 then coilId=""; end
    if argn(2)<4 then phase="A"; end
    if argn(2)<5 then sourcePhase=phase; end
    if argn(2)<6 then order=w.polePairs; end
    if argn(2)<7 then maxConvergenceOrder=120; end
    if argn(2)<8 then cachedConvergence=[]; end
    a=ew_i_phase_index(phase); b=ew_i_phase_index(sourcePhase);
    ew_i_require(order,"Ausgewählte mechanische Raumordnung",1,2000,%t,%t);
    ew_i_require(maxConvergenceOrder,"Höchste Konvergenzordnung",1,2000,%t,%t);
    if type(coilId)<>10 | size(coilId,"*")<>1 then error("Eine einzelne Spulenkennung angeben."); end
    data=struct("valid",%f,"phase",phase,"sourcePhase",sourcePhase,"order",order, ..
        "selectedOrder",order,"electricalOrder",order/w.polePairs,"coilId",coilId, ..
        "selectedCoilId",coilId,"sides",list(),"groups",list(),"warnings",emptystr(0,1), ..
        "convergenceCached",%f);
    message=ew_i_winding_error(w);
    if message<>"" then data.warnings=message; return; end
    if ~isfield(d,"valid") then data.warnings="Passende Induktivitätsberechnung fehlt."; return; end
    if ~d.valid then
        data.warnings="Ohne gültige Maschinenparameter werden keine Induktivitäts-Lernschritte berechnet.";
        return;
    end
    if d.slots<>w.slots | d.polePairs<>w.polePairs | length(d.coils)<>length(w.coils) then
        data.warnings="Wicklung und Induktivitätsberechnung gehören nicht zum selben Entwurf."; return;
    end
    compareFields=["id","phase","positiveSlot","negativeSlot","positiveLayer","negativeLayer","span","direction"];
    for index=1:length(w.coils)
        for fieldIndex=1:size(compareFields,"*")
            field=compareFields(fieldIndex);
            if w.coils(index)(field)<>d.coils(index)(field) then
                data.warnings="Wicklung und Induktivitätsberechnung besitzen unterschiedliche Spulenseiten."; return;
            end
        end
    end
    selected=0;
    for index=1:length(d.coils)
        coil=d.coils(index);
        if coilId=="" & coil.phase==phase then selected=index; break; end
        if coil.id==coilId then selected=index; break; end
    end
    if selected==0 then data.warnings="Die ausgewählte Spule gehört nicht zur aktuellen Wicklung."; return; end
    coil=d.coils(selected);
    if coil.phase<>phase then data.warnings="Spule und ausgewählter Empfangsstrang müssen übereinstimmen."; return; end
    coil.selected=ew_i_factors(list(coil),order,d.phases(a).axisRad);
    data.coilId=coil.id; data.selectedCoilId=coil.id;
    data.coil=coil; data.selectedCoil=coil;
    data.slots=w.slots; data.polePairs=w.polePairs;
    data.parameters=d.parameters; data.parameters.selectedOrder=order;
    data.phaseIndex=a; data.sourceIndex=b;
    data.selectedOrderOutsideConvergence=order>maxConvergenceOrder;
    slots=[coil.positiveSlot,coil.negativeSlot]; layers=[coil.positiveLayer,coil.negativeLayer];
    for sideIndex=1:2
        sign=3-2*sideIndex; angle=2*%pi*(slots(sideIndex)-1)/w.slots;
        vfund=sign*exp(%i*w.polePairs*angle); vharm=sign*exp(%i*order*angle);
        fourier=sign*exp(-%i*order*angle)/(2*%i*order);
        data.sides($+1)=struct("slot",slots(sideIndex),"layer",layers(sideIndex), ..
            "sign",sign,"phase",phase,"mechanicalAngleRad",angle, ..
            "mechanicalAngleDeg",angle*180/%pi, ..
            "electricalAngleDeg",ew_i_mod(w.polePairs*angle*180/%pi,360), ..
            "harmonicAngleDeg",ew_i_mod(order*angle*180/%pi,360), ..
            "signedElectricalAngleDeg",ew_i_mod(w.polePairs*angle*180/%pi+90*(1-sign),360), ..
            "signedHarmonicAngleDeg",ew_i_mod(order*angle*180/%pi+90*(1-sign),360), ..
            "voltageFundamental",ew_i_complex(vfund),"voltageHarmonic",ew_i_complex(vharm), ..
            "fourierContribution",ew_i_complex(fourier));
    end
    data.positiveSide=data.sides(1); data.negativeSide=data.sides(2);
    data.coilContribution=ew_learning_node(list(coil),order,w.polePairs,d.phases(a).axisRad,coil.id,coil.id);
    [data.phaseContribution,data.groups]=ew_learning_phase_node(d,phase,order,coil.id);
    [data.sourceContribution,unused]=ew_learning_phase_node(d,sourcePhase,order,coil.id);
    groupIndex=0;
    for index=1:length(data.groups)
        if or(data.groups(index).coilIds==coil.id) then groupIndex=index; break; end
    end
    if groupIndex==0 then data.warnings="Die physikalische Spulengruppe fehlt."; return; end
    data.groupContribution=data.groups(groupIndex);
    data.group=data.groupContribution; data.groupId=data.group.id;
    coefficients=ew_i_raw_coefficient(w,order);
    data.coefficients=struct("A",ew_i_complex(coefficients(1)),"B",ew_i_complex(coefficients(2)),"C",ew_i_complex(coefficients(3)));
    data.fourierPrefactorH=d.fourierPrefactorH;
    data.harmonicMatrixH=d.fourierPrefactorH*real(coefficients*coefficients');
    data.selectedContributionH=data.harmonicMatrixH(a,b);
    data.exactSelectedH=d.matrixH(a,b);
    data.harmonicFluxLinkageWbTurns=data.harmonicMatrixH*d.parameters.currents;
    data.selectedFluxLinkageWbTurns=data.selectedContributionH*d.parameters.currents(b);
    data.selectedPairFluxLinkageWbTurns=data.selectedFluxLinkageWbTurns;
    data.receivingFluxLinkageWbTurns=data.harmonicFluxLinkageWbTurns(a);
    signature=ew_learning_signature(w,d.parameters);
    useCache=%f;
    if typeof(cachedConvergence)=="st" then
        if isfield(cachedConvergence,"valid") & isfield(cachedConvergence,"signature") & isfield(cachedConvergence,"maxOrder") then
            useCache=cachedConvergence.valid & cachedConvergence.signature==signature & cachedConvergence.maxOrder==maxConvergenceOrder;
        end
    end
    if useCache then data.convergence=cachedConvergence; data.convergenceCached=%t;
    else data.convergence=ew_compute_convergence(w,d.parameters,maxConvergenceOrder); end
    // Currents and selections do not change the cached magnetic matrices, but
    // exported metadata must describe the current controls rather than old UI.
    data.convergence.parameters=data.parameters;
    data.convergence.parameters.maxOrder=maxConvergenceOrder;
    data.voltageConvention="E_k=sum s*exp(+j*k*phi); C_k=conj(E_k)/(2*j*k). Die Grundwellen-Spannungszeiger verwenden k=p.";
    data.couplingConvention="L_ab,k=P*Re(C_a,k*conj(C_b,k)); alle Stränge behalten den gemeinsamen mechanischen Raumursprung. Einzelspulenquadrate ersetzen keine Strang-Kreuzprodukte.";
    data.valid=%t;
endfunction
