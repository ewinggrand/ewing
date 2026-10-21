// Native worked phasor additions. Only the drawing coordinates are scaled;
// every physical term retains the common mechanical origin and +j convention.

function value=ew_agfx_value(parts)
    value=parts.real+%i*parts.imag;
endfunction

function band=ew_agfx_band(stage)
    band=stage;
    if or(stage==["side","polarity","coil"]) then band="coil";end
endfunction

function scale=ew_agfx_scale(data,band)
    // One fixed scale throughout an addition. The change between coil, group
    // and phase is declared explicitly, so individual Nut phasors stay visible.
    scale=1;
    for n=1:length(data.frames)
        f=data.frames(n);
        if ew_agfx_band(f.stage)<>band then continue;end
        subtotal=0;
        for t=1:length(f.terms)
            value=ew_agfx_value(f.terms(t).value);
            scale=max([scale,abs(value)]);
            if f.drawMode=="chain" then
                subtotal=subtotal+value;
                scale=max([scale,abs(subtotal)]);
            end
        end
        scale=max([scale,abs(ew_agfx_value(f.result))]);
        if band=="coil" then scale=max([scale,abs(ew_agfx_value(f.rawMinus))]);end
    end
endfunction

function point=ew_agfx_point(value,scale)
    point=[0,0.80]+0.77*[real(value),imag(value)]/scale;
endfunction

function ew_agfx_label(point,label,col,offset)
    if argn(2)<4 then offset=[0.04,0.03];end
    ew_gfx_text(point(1)+offset(1),point(2)+offset(2),label,col,2);
endfunction

function ew_agfx_target(ax,point,term,order)
    meta=ax.user_data;
    for k=1:size(term.coilIds,"*")
        tag=struct("ewHit","coil","coilId",term.coilIds(k),"slot",term.slot, ..
            "layer",term.layer,"order",order,"x",point(1),"y",point(2));
        meta.ewHits($+1)=tag;
    end
    ax.user_data=meta;
endfunction

function ew_agfx_arrow(first,last,col,width)
    if norm(last-first)<1d-11 then
        xpoly(last(1),last(2),"marks");h=gce();h.mark_style=9;h.mark_size=4;
        h.mark_foreground=col;h.mark_background=col;
    else
        ew_gfx_arrow(first(1),first(2),last(1),last(2),col,width);
    end
endfunction

function ew_agfx_ghost(first,last,col)
    delta=last-first;distance=norm(delta);
    if distance<1d-11 then return;end
    ew_gfx_line([first;last],col,1.5,2);
    direction=delta/distance;normal=[-direction(2),direction(1)];
    base=last-direction*distance*0.12;
    ew_gfx_polygon([last;base+normal*distance*0.055;base-normal*distance*0.055],col);
endfunction

function text=ew_agfx_ids(ids)
    count=size(ids,"*");limit=min(6,count);
    text=strcat(ids(1:limit),", ");
    if count>limit then text=text+" +"+string(count-limit)+" weitere";end
endfunction

function ew_agfx_formula(x,y,latex,fallback,col)
    // Native JLaTeXMath, with a legible text fallback on older Scilab builds.
    try
        xstring(x,y,"$"+latex+"$");
        h=gce();h.font_size=4;h.font_foreground=col;
        box=xstringl(x,y,"$"+latex+"$",h.font_style,h.font_size);
        if box(3)>3.58 then
            h.font_size=3;
            box=xstringl(x,y,"$"+latex+"$",h.font_style,h.font_size);
            if box(3)>3.58 then h.font_size=2;end
        end
    catch
        xstring(x,y,fallback);h=gce();h.font_size=2;h.font_foreground=col;
    end
endfunction

function ax=ew_plot_animation(data,index,axesHandle)
    if argn(2)<2 then index=1;end
    if argn(2)<3 then axesHandle=[];end
    ax=ew_gfx_prepare("Zeigeraddition: Formel - Zahlen - Ergebnis",axesHandle);
    ax.parent.background=color("white");
    ax.data_bounds=[-2,-1.72;2,2.08];ax.isoview="on";
    ax.axes_visible=["off","off","off"];
    ax.margins=[0.045,0.025,0.055,0.035];
    if ~data.valid then
        ew_gfx_text(-1.8,0.8,"Die Zeigeraddition benötigt eine gültige Wicklung und Lernberechnung.",color("black"),2);
        return;
    end
    if size(index,"*")<>1 | ~isreal(index) then error("Animationsschritt muss eine ganze Zahl sein.");end
    if isnan(index)|isinf(index)|index<1|index>length(data.frames)|index<>floor(index) then
        error("Animationsschritt außerhalb des vorhandenen Lernpfads.");
    end
    f=data.frames(index);band=ew_agfx_band(f.stage);scale=ew_agfx_scale(data,band);
    col=ew_gfx_phase_color(data.phase);pale=addcolor([0.68,0.73,0.68]);
    grey=addcolor([0.43,0.46,0.43]);black=color("black");
    ax.title.text="Zeigeraddition · "+data.coilId+" · Strang "+data.phase+" · k="+string(data.order);
    ax.user_data=struct("ewRole","animation","ewHits",list(),"frameIndex",index, ..
        "activeCoilIds",f.activeCoilIds,"includedCoilIds",f.includedCoilIds, ..
        "scale",scale,"band",band,"quantity","normalized-voltage");
    ew_gfx_text(-1.83,1.87,"Schritt "+string(index)+" / "+string(length(data.frames))+": "+f.title,black,2.6);
    ew_gfx_text(-1.83,1.66,"Normierte Spannungszeiger U (dimensionslos); keine physikalischen Voltwerte.",grey,1.8);
    origin=ew_agfx_point(0,scale);
    ew_gfx_line([-0.94,0.80;0.94,0.80],addcolor([0.86,0.88,0.85]),0.7,2);
    ew_gfx_line([0,-0.05;0,1.65],addcolor([0.86,0.88,0.85]),0.7,2);
    ew_gfx_text(0.96,0.75,"Re",grey,1.8);ew_gfx_text(0.04,1.58,"Im",grey,1.8);
    theta=linspace(0,2*%pi,121);
    ew_gfx_line([0.77*cos(theta)',0.80+0.77*sin(theta)'],addcolor([0.91,0.92,0.89]),0.7,2);
    if band=="coil" & or(f.stage==["polarity","coil"]) then
        point=ew_agfx_point(ew_agfx_value(f.rawMinus),scale);
        ew_agfx_ghost(origin,point,grey);
        ew_agfx_label(point,"Minus-Seite ohne Vorzeichen",grey,[0.02,-0.10]);
    end
    subtotal=0;
    for n=1:f.visibleCount
        term=f.terms(n);value=ew_agfx_value(term.value);
        termColor=pale;width=1.6;
        if n==f.visibleCount then termColor=col;width=3;end
        if term.isRaw & term.sign<0 then termColor=grey;end
        if f.drawMode=="chain" then
            first=ew_agfx_point(subtotal,scale);subtotal=subtotal+value;
            last=ew_agfx_point(subtotal,scale);
        else
            first=origin;last=ew_agfx_point(value,scale);
        end
        ew_agfx_arrow(first,last,termColor,width);
        ew_agfx_target(ax,(first+last)/2,term,data.order);
        if n==f.visibleCount | f.visibleCount<=6 then
            label=term.id;
            if term.kind=="side" then label=label+" / L"+string(term.layer);end
            ew_agfx_label((first+last)/2,label,termColor,[0.035,0.035]);
        end
    end
    if f.showResult then
        last=ew_agfx_point(ew_agfx_value(f.result),scale);
        ew_agfx_arrow(origin,last,black,2.6);
        ew_agfx_label(last,"Summe U",black,[-0.12,-0.14]);
    end
    ew_gfx_text(-1.83,-0.08,"Aktueller Beitrag: "+ew_agfx_ids(f.activeCoilIds)+" | Einbezogen: "+string(size(f.includedCoilIds,"*"))+" Spulen",grey,1.7);
    ew_gfx_text(-1.83,-0.22,f.explanation,black,1.9);
    ew_gfx_text(-1.83,-0.44,"ALLGEMEIN",grey,1.7);
    ew_agfx_formula(-1.83,-0.65,f.formulaLatex,f.formulaText,black);
    ew_gfx_text(-1.83,-0.85,"WERTE EINSETZEN",grey,1.7);
    ew_agfx_formula(-1.83,-1.06,f.substitutionLatex,f.substitutionText,black);
    ew_gfx_text(-1.83,-1.25,"ERGEBNIS",grey,1.7);
    ew_agfx_formula(-1.83,-1.46,f.resultLatex,f.resultText,col);
    bandLabel="Spule";
    if band=="group" then bandLabel="Gruppe";end
    if band=="phase" then bandLabel="Strang";end
    ew_gfx_text(-1.83,-1.64,"Zeichenmaßstab "+bandLabel+": Kreisradius = "+ew_lgfx_num(scale)+"; innerhalb dieser Etappe fest.",grey,1.7);
endfunction
