// Deterministic educational frames for normalized voltage phasors.
// Every displayed contribution keeps the same +j mechanical origin. These
// vectors are dimensionless; they are not voltages in physical volts.

function text = ew_a_number(value)
    if abs(value)<1d-12 then value=0; end
    text=msprintf("%.7g",value);
endfunction

function text = ew_a_complex_text(value)
    text=ew_a_number(real(value))+" + j*("+ew_a_number(imag(value))+")";
endfunction

function text = ew_a_complex_latex(value)
    text="\left("+ew_a_number(real(value))+"+j\left("+ew_a_number(imag(value))+"\right)\right)";
endfunction

function text = ew_a_math(body)
    text="<math xmlns=""http://www.w3.org/1998/Math/MathML"" display=""block""><mrow>"+body+"</mrow></math>";
endfunction

function text = ew_a_mnumber(value)
    text="<mn>"+ew_a_number(value)+"</mn>";
endfunction

function text = ew_a_mcomplex(value)
    text="<mrow><mo>(</mo>"+ew_a_mnumber(real(value))+"<mo>+</mo><mi>j</mi><mo>⋅</mo><mo>(</mo>"+ew_a_mnumber(imag(value))+"<mo>)</mo><mo>)</mo></mrow>";
endfunction

function text = ew_a_mlabel(label)
    // Callers may supply either a bare subscript or a human-readable U_ label.
    // The base symbol U is already represented by the outer MathML mi node.
    if length(label)>=2 then
        if part(label,1:2)=="U_" then label=part(label,3:length(label));end
    end
    text="<msub><mi>U</mi><mtext>"+label+"</mtext></msub>";
endfunction

function text = ew_a_mexp(order,slot,slots)
    text="<msup><mi>e</mi><mrow><mi>j</mi><mo>⋅</mo>"+ew_a_mnumber(order)+"<mo>⋅</mo><mfrac><mrow><mn>2</mn><mi>π</mi><mo>(</mo>"+ew_a_mnumber(slot)+"<mo>−</mo><mn>1</mn><mo>)</mo></mrow>"+ew_a_mnumber(slots)+"</mfrac></mrow></msup>";
endfunction

function term = ew_a_term(id,coilIds,kind,value)
    term=struct("id",id,"coilIds",matrix(coilIds,-1,1),"kind",kind, ..
        "value",ew_i_complex(value),"rawValue",ew_i_complex(value), ..
        "signedValue",ew_i_complex(value),"slot",0,"layer",0,"sign",0, ..
        "angleDeg",0,"mechanicalAngleDeg",0,"signedAngleDeg",0, ..
        "polarityApplied",%t,"isRaw",%f);
endfunction

function term = ew_a_side_term(side,id,coilId,order,isRaw)
    raw=exp(%i*order*side.mechanicalAngleRad); signed=side.sign*raw;
    value=signed; if isRaw then value=raw; end
    term=ew_a_term(id,coilId,"side",value);
    term.rawValue=ew_i_complex(raw); term.signedValue=ew_i_complex(signed);
    term.slot=side.slot; term.layer=side.layer; term.sign=side.sign;
    term.angleDeg=ew_i_mod(order*side.mechanicalAngleDeg,360);
    term.mechanicalAngleDeg=side.mechanicalAngleDeg;
    term.signedAngleDeg=ew_i_mod(term.angleDeg+90*(1-side.sign),360);
    term.isRaw=isRaw; term.polarityApplied=~isRaw;
endfunction

function ids = ew_a_ids(terms,count)
    ids=emptystr(0,1);
    for n=1:count
        for j=1:size(terms(n).coilIds,"*")
            id=terms(n).coilIds(j);
            if ~or(ids==id) then ids($+1,1)=id; end
        end
    end
endfunction

function frame = ew_a_frame(data,stage,title,explanation,mode,terms,count,showResult)
    value=0; previous=0;
    for n=1:count
        previous=value; value=value+ew_learning_value(terms(n).value);
    end
    frame=struct("index",0,"stage",stage,"title",title,"explanation",explanation, ..
        "drawMode",mode,"quantity","U","terms",terms,"visibleCount",count, ..
        "result",ew_i_complex(value),"previous",ew_i_complex(previous), ..
        "added",terms(count).value,"showResult",showResult, ..
        "activeCoilIds",terms(count).coilIds,"includedCoilIds",ew_a_ids(terms,count), ..
        "selectedCoilId",data.coilId,"coilId",data.coilId,"phase",data.phase,"order",data.order, ..
        "rawPlus",ew_i_complex(exp(%i*data.order*data.positiveSide.mechanicalAngleRad)), ..
        "rawMinus",ew_i_complex(exp(%i*data.order*data.negativeSide.mechanicalAngleRad)), ..
        "signedMinus",data.negativeSide.voltageHarmonic, ..
        "formulaLatex","","substitutionLatex","","resultLatex","", ..
        "formulaText","","substitutionText","","resultText","", ..
        "formulaMathML","","substitutionMathML","","resultMathML","");
endfunction

function frame = ew_a_result(frame,label,latexLabel)
    value=ew_learning_value(frame.result);
    frame.resultText=label+" = "+ew_a_complex_text(value)+" (dimensionslos)";
    frame.resultLatex=latexLabel+"="+ew_a_complex_latex(value);
    frame.resultMathML=ew_a_math(ew_a_mlabel(label)+"<mo>=</mo>"+ew_a_mcomplex(value));
endfunction

function frame = ew_a_side_equations(frame,data,side,positive)
    label="−"; latexLabel="-";
    if positive then label="+";latexLabel="+";end
    frame.formulaText="U_"+label+",k (roh) = exp(j*k*2*pi*(s-1)/Q)";
    frame.formulaLatex="U_{"+latexLabel+",k}^{\mathrm{roh}}=e^{jk\frac{2\pi(s-1)}{Q}}";
    frame.formulaMathML=ew_a_math(ew_a_mlabel(label+",k (roh)")+"<mo>=</mo><msup><mi>e</mi><mrow><mi>j</mi><mi>k</mi><mfrac><mrow><mn>2</mn><mi>π</mi><mo>(</mo><mi>s</mi><mo>−</mo><mn>1</mn><mo>)</mo></mrow><mi>Q</mi></mfrac></mrow></msup>");
    frame.substitutionText="k="+string(data.order)+", s="+string(side.slot)+", Q="+string(data.slots)+": exp(j*"+string(data.order)+"*2*pi*("+string(side.slot)+"-1)/"+string(data.slots)+")";
    frame.substitutionLatex="U_{"+latexLabel+","+string(data.order)+"}^{\mathrm{roh}}=e^{j\cdot"+string(data.order)+"\cdot\frac{2\pi("+string(side.slot)+"-1)}{"+string(data.slots)+"}}";
    frame.substitutionMathML=ew_a_math(ew_a_mlabel(label+","+string(data.order)+" (roh)")+"<mo>=</mo>"+ew_a_mexp(data.order,side.slot,data.slots));
    frame=ew_a_result(frame,"U_"+label+",k (roh)","U_{"+latexLabel+",k}^{\mathrm{roh}}");
endfunction

function frame = ew_a_accumulation_equations(frame,label,latexLabel,memberLabel)
    n=frame.visibleCount; before=ew_learning_value(frame.previous); added=ew_learning_value(frame.added);
    memberSymbol="c";if frame.stage=="phase" then memberSymbol="g";end
    frame.formulaText=label+"(n) = "+label+"(n-1) + U_"+memberSymbol+"(n),k";
    frame.formulaLatex=latexLabel+"^{(n)}="+latexLabel+"^{(n-1)}+U_{"+memberSymbol+"_n,k}";
    frame.formulaMathML=ew_a_math("<msup>"+ew_a_mlabel(label)+"<mrow><mo>(</mo><mi>n</mi><mo>)</mo></mrow></msup><mo>=</mo><msup>"+ew_a_mlabel(label)+"<mrow><mo>(</mo><mi>n</mi><mo>−</mo><mn>1</mn><mo>)</mo></mrow></msup><mo>+</mo>"+"<msub><mi>U</mi><mrow><msub><mi>"+memberSymbol+"</mi><mi>n</mi></msub><mo>,</mo><mi>k</mi></mrow></msub>");
    frame.substitutionText=ew_a_complex_text(before)+" + ("+ew_a_complex_text(added)+")";
    frame.substitutionLatex=latexLabel+"^{("+string(n)+")}="+ew_a_complex_latex(before)+"+"+ew_a_complex_latex(added);
    frame.substitutionMathML=ew_a_math("<msup>"+ew_a_mlabel(label)+ew_a_mnumber(n)+"</msup><mo>=</mo>"+ew_a_mcomplex(before)+"<mo>+</mo>"+ew_a_mcomplex(added));
    frame=ew_a_result(frame,label+"("+string(n)+")",latexLabel+"^{("+string(n)+")}");
endfunction

function data = ew_compute_animation(learning)
    data=struct("valid",%f,"warnings",emptystr(0,1),"frames",list(), ..
        "frameCount",0,"coilId","","phase","","order",0, ..
        "voltageConvention","U=sum sign*exp(+j*k*phi), dimensionslos; kein physischer Spannungswert in Volt.");
    if typeof(learning)<>"st" then data.warnings="Aktuelle Lerndaten fehlen.";return;end
    if ~isfield(learning,"valid") then data.warnings="Aktuelle Lerndaten fehlen.";return;end
    if ~learning.valid then
        data.warnings="Ohne gültige Lerndaten kann keine Zeigeraddition gezeigt werden.";
        if isfield(learning,"warnings") then data.warnings=[data.warnings;learning.warnings(:)];end
        return;
    end
    data.coilId=learning.coilId;data.phase=learning.phase;data.order=learning.order;
    data.slots=learning.slots;data.polePairs=learning.polePairs;
    data.positiveSide=learning.positiveSide;data.negativeSide=learning.negativeSide;
    data.groupId=learning.groupId;
    data.phaseVoltage=learning.phaseContribution.voltageHarmonic;
    data.phaseFourier=learning.phaseContribution.rawFourier;
    plusRaw=ew_a_side_term(learning.positiveSide,"+ Nut "+string(learning.positiveSide.slot),data.coilId,data.order,%t);
    minusRaw=ew_a_side_term(learning.negativeSide,"− Nut "+string(learning.negativeSide.slot)+" (roh)",data.coilId,data.order,%t);
    plus=ew_a_side_term(learning.positiveSide,"+ Nut "+string(learning.positiveSide.slot),data.coilId,data.order,%f);
    minus=ew_a_side_term(learning.negativeSide,"− Nut "+string(learning.negativeSide.slot),data.coilId,data.order,%f);
    f=ew_a_frame(data,"side","1 · Positive Nutseite", ..
        "Die mechanische Nutlage wird mit k multipliziert. Ihr Einheitszeiger erhält hier das Pluszeichen.","rays",list(plusRaw),1,%f);
    f=ew_a_side_equations(f,data,learning.positiveSide,%t);data.frames($+1)=f;
    f=ew_a_frame(data,"side","2 · Negative Nutseite zunächst ohne Polungszeichen", ..
        "Dieser graue Rohzeiger beschreibt nur die Nutlage. Er ist noch nicht der vorzeichenrichtige Beitrag der Rückseite.","rays",list(minusRaw),1,%f);
    f=ew_a_side_equations(f,data,learning.negativeSide,%f);data.frames($+1)=f;
    f=ew_a_frame(data,"polarity","3 · Minus-Seite umpolen", ..
        "Das Minuszeichen kehrt den Rohzeiger um 180 Grad um. Die physische Nut und Lage bleiben gleich.","rays",list(minus),1,%f);
    raw=ew_learning_value(minus.rawValue);
    f.formulaText="U_−,k = −U_−,k (roh)";
    f.formulaLatex="U_{-,k}=-U_{-,k}^{\mathrm{roh}}";
    f.formulaMathML=ew_a_math(ew_a_mlabel("−,k")+"<mo>=</mo><mo>−</mo>"+ew_a_mlabel("−,k (roh)"));
    f.substitutionText="U_−,k = −("+ew_a_complex_text(raw)+")";
    f.substitutionLatex="U_{-,k}=-"+ew_a_complex_latex(raw);
    f.substitutionMathML=ew_a_math(ew_a_mlabel("−,k")+"<mo>=</mo><mo>−</mo>"+ew_a_mcomplex(raw));
    f=ew_a_result(f,"U_−,k","U_{-,k}");data.frames($+1)=f;
    pair=list(plus,minus);
    for step=4:5
        title="4 · Spitze an Fuß: beide Nutseiten addieren";
        explanation="Der Minus-Beitrag wird parallel an die Spitze des Plus-Beitrags verschoben. Länge und Richtung ändern sich nicht.";
        if step==5 then
            title="5 · Resultierender Spulenzeiger "+data.coilId;
            explanation="Der Zeiger vom gemeinsamen Ursprung zum Endpunkt ist die Spulensumme. Es werden komplexe Zeiger addiert, keine Beträge.";
        end
        f=ew_a_frame(data,"coil",title,explanation,"chain",pair,2,step==5);
        f.formulaText="U_c,k = U_+,k + U_−,k = exp(j*k*phi_+) − exp(j*k*phi_−)";
        f.formulaLatex="U_{c,k}=U_{+,k}+U_{-,k}=e^{jk\varphi_+}-e^{jk\varphi_-}";
        f.formulaMathML=ew_a_math(ew_a_mlabel("c,k")+"<mo>=</mo>"+ew_a_mlabel("+,k")+"<mo>+</mo>"+ew_a_mlabel("−,k"));
        a=ew_learning_value(plus.value);b=ew_learning_value(minus.value);
        f.substitutionText=ew_a_complex_text(a)+" + ("+ew_a_complex_text(b)+")";
        f.substitutionLatex="U_{c,k}="+ew_a_complex_latex(a)+"+"+ew_a_complex_latex(b);
        f.substitutionMathML=ew_a_math(ew_a_mlabel("c,k")+"<mo>=</mo>"+ew_a_mcomplex(a)+"<mo>+</mo>"+ew_a_mcomplex(b));
        f=ew_a_result(f,"U_"+data.coilId+",k","U_{c,k}");data.frames($+1)=f;
    end
    group=learning.groupContribution;terms=list();
    for n=1:length(group.members)
        c=group.members(n);terms($+1)=ew_a_term(c.id,c.coilId,"coil",ew_learning_value(c.voltageHarmonic));
    end
    for n=1:length(terms)
        f=ew_a_frame(data,"group","Gruppe "+group.id+": Spule "+string(n)+" von "+string(length(terms)), ..
            "Die tatsächlichen Spulen dieser Gruppe werden im selben mechanischen Bezug nacheinander addiert. Aktuell: "+terms(n).id+".","chain",terms,n,%t);
        f=ew_a_accumulation_equations(f,"U_Gruppe,k","U_{g,k}",terms(n).id);
        data.frames($+1)=f;
    end
    terms=list();groups=learning.phaseContribution.members;
    // Begin with the group just derived, then add each remaining group once.
    order=1:length(groups);selected=[];
    for n=1:length(groups), if groups(n).id==group.id then selected=n;break;end;end
    if ~isempty(selected) then order=[selected,order(find(order<>selected))];end
    for n=order
        g=groups(n);terms($+1)=ew_a_term(g.id,g.coilIds,"group",ew_learning_value(g.voltageHarmonic));
    end
    for n=1:length(terms)
        f=ew_a_frame(data,"phase","Strang "+data.phase+": Gruppe "+string(n)+" von "+string(length(terms)), ..
            "Alle Gruppen des Strangs bleiben im gemeinsamen mechanischen Winkelbezug. Aktuell: "+terms(n).id+".","chain",terms,n,%t);
        f=ew_a_accumulation_equations(f,"U_"+data.phase+",k","U_{"+data.phase+",k}",terms(n).id);
        data.frames($+1)=f;
    end
    for n=1:length(data.frames),f=data.frames(n);f.index=n;data.frames(n)=f;end
    data.frameCount=length(data.frames);
    voltage=ew_learning_value(data.phaseVoltage);coefficient=ew_learning_value(data.phaseFourier);
    data.conversionFormulaText="C_a,k = conj(U_a,k)/(2*j*k)";
    data.conversionSubstitutionText="C_"+data.phase+","+string(data.order)+" = conj("+ew_a_complex_text(voltage)+")/(2*j*"+string(data.order)+")";
    data.conversionResultText="C_"+data.phase+","+string(data.order)+" = "+ew_a_complex_text(coefficient);
    data.conversionFormulaLatex="C_{a,k}=\frac{\overline{U_{a,k}}}{2jk}";
    data.conversionSubstitutionLatex="C_{"+data.phase+","+string(data.order)+"}=\frac{\overline{"+ew_a_complex_latex(voltage)+"}}{2j\cdot"+string(data.order)+"}";
    data.conversionResultLatex="C_{"+data.phase+","+string(data.order)+"}="+ew_a_complex_latex(coefficient);
    cLabel="<msub><mi>C</mi><mtext>"+data.phase+","+string(data.order)+"</mtext></msub>";
    data.conversionFormulaMathML=ew_a_math("<msub><mi>C</mi><mtext>a,k</mtext></msub><mo>=</mo><mfrac><mover>"+ew_a_mlabel("a,k")+"<mo>¯</mo></mover><mrow><mn>2</mn><mi>j</mi><mi>k</mi></mrow></mfrac>");
    data.conversionSubstitutionMathML=ew_a_math(cLabel+"<mo>=</mo><mfrac><mover>"+ew_a_mcomplex(voltage)+"<mo>¯</mo></mover><mrow><mn>2</mn><mi>j</mi><mo>⋅</mo>"+ew_a_mnumber(data.order)+"</mrow></mfrac>");
    data.conversionResultMathML=ew_a_math(cLabel+"<mo>=</mo>"+ew_a_mcomplex(coefficient));
    data.valid=%t;
endfunction
