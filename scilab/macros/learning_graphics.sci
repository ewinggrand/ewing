// Native interactive learning plots. All vector sums retain the common
// mechanical origin; scaling below is only a common drawing scale.

function text=ew_lgfx_num(value)
    if isempty(value) then text="nicht definiert";return;end
    if isnan(value)|isinf(value) then text="nicht definiert";return;end
    if abs(value)<1d-12 then value=0;end
    text=strsubst(msprintf("%.6g",value),".",",");
endfunction

function vector=ew_lgfx_vector(parts)
    vector=[parts.real,parts.imag];
endfunction

function text=ew_lgfx_complex(parts)
    text=ew_lgfx_num(parts.real)+" + j("+ew_lgfx_num(parts.imag)+")";
endfunction

function ew_lgfx_axes(ax)
    ax.data_bounds=[-1.48,-1.80;1.48,1.47];
    ax.axes_visible=["off","off","off"];ax.isoview="on";
    ew_gfx_line([-1.24,0;1.24,0],color("grey"),0.8,2);
    ew_gfx_line([0,-1.20;0,1.20],color("grey"),0.8,2);
    labelColor=addcolor([0.42,0.48,0.39]);
    ew_gfx_text(1.22,-0.10,"Re",labelColor,2);
    ew_gfx_text(0.04,1.22,"Im",labelColor,2);
    circle=linspace(0,2*%pi,121);
    ew_gfx_line([cos(circle)',sin(circle)'],addcolor([0.88,0.90,0.85]),0.7,2);
    ax.user_data=struct("ewHits",list());
endfunction

function ew_lgfx_hit(ax,point,coilId,slot,layer)
    if coilId=="" then return;end
    if argn(2)<4 then slot=0;end
    if argn(2)<5 then layer=0;end
    tag=struct("ewHit","coil","coilId",coilId,"slot",slot,"layer",layer,"order",0,"x",point(1),"y",point(2));
    handle=gce();handle.user_data=tag;
    data=ax.user_data;
    data.ewHits($+1)=tag;
    ax.user_data=data;
endfunction

function ew_lgfx_vector_label(point,text,col,offset)
    if argn(2)<4 then offset=[0.04,0.04];end
    ew_gfx_text(point(1)+offset(1),point(2)+offset(2),text,col,2);
endfunction

function ew_lgfx_chain(ax,members,result,phase,selectedCoilId,tagCoils)
    vectors=zeros(length(members),2);chain=zeros(length(members)+1,2);
    for n=1:length(members)
        vectors(n,:)=ew_lgfx_vector(members(n).rawFourier);
        chain(n+1,:)=chain(n,:)+vectors(n,:);
    end
    total=ew_lgfx_vector(result.rawFourier);
    scale=max([sqrt(sum(chain.^2,2));norm(total);1d-12]);
    if scale<1d-10 then scale=1;end
    col=ew_gfx_phase_color(phase);pale=addcolor([0.72,0.77,0.69]);
    for n=1:length(members)
        item=members(n);selected=%f;
        if isfield(item,"isSelected") then selected=item.isSelected;end
        width=1.2;memberColor=pale;
        if selected then width=3.2;memberColor=col;end
        first=chain(n,:)/scale;last=chain(n+1,:)/scale;
        ew_gfx_arrow(first(1),first(2),last(1),last(2),memberColor,width);
        if tagCoils then
            ew_lgfx_hit(ax,last,item.id);
            ew_lgfx_hit(ax,(first+last)/2,item.id);
        end
        if length(members)<=10 | selected then
            ew_lgfx_vector_label(last,item.id,memberColor,[0.02,0.03]);
        end
    end
    endpoint=total/scale;
    ew_gfx_arrow(0,0,endpoint(1),endpoint(2),col,2.6);
    ew_lgfx_vector_label(endpoint,"Summe",col,[-0.10,-0.13]);
    ew_gfx_text(-1.40,-1.37,"Rohkoeffizient C = "+ew_lgfx_complex(result.rawFourier),col,2);
    ew_gfx_text(-1.40,-1.54,"Gemeinsamer Zeichenmaßstab: "+ew_lgfx_num(scale)+". Keine einzelne Zeigerdrehung.",color("black"),2);
endfunction

function ax=ew_plot_learning(data,stage,axesHandle)
    if argn(2)<2 then stage=1;end
    if argn(2)<3 then axesHandle=[];end
    if stage<1|stage>4|stage<>floor(stage) then error("Lernschritt muss 1 bis 4 sein.");end
    titles=["1 · Nutseiten der Spule addieren";"2 · Spulen zur Gruppe addieren";"3 · Gruppen zum Strang addieren";"4 · Beitrag einer Raumharmonischen zur Induktivität"];
    ax=ew_gfx_prepare(titles(stage),axesHandle);
    ew_lgfx_axes(ax);
    if ~data.valid then
        ew_gfx_text(-1.35,0.3,"Für diese Eingaben ist keine vollständige Lernansicht verfügbar.",color("black"),2);
        return;
    end
    phase=data.phase;col=ew_gfx_phase_color(phase);
    ax.title.text=titles(stage)+" · "+data.coilId+" · k="+string(data.order)+" (nu="+ew_lgfx_num(data.electricalOrder)+")";
    select stage
    case 1 then
        first=ew_lgfx_vector(data.sides(1).voltageHarmonic);
        second=ew_lgfx_vector(data.sides(2).voltageHarmonic);
        total=ew_lgfx_vector(data.coilContribution.voltageHarmonic);
        scale=max([norm(first),norm(second),norm(total),1]);
        first=first/scale;second=second/scale;endpoint=total/scale;
        original=-second;
        ew_gfx_line([0,0;original],addcolor([0.66,0.69,0.64]),1.3,2);
        ew_lgfx_vector_label(original,"Minus-Seite vor Umpolung",color("grey"),[0.02,-0.10]);
        ew_gfx_arrow(0,0,first(1),first(2),col,2.5);
        ew_lgfx_hit(ax,first,data.coilId,data.sides(1).slot,data.sides(1).layer);
        ew_lgfx_vector_label(first,"+ Nut "+string(data.sides(1).slot)+" / Lage "+string(data.sides(1).layer),col,[0.03,0.06]);
        ew_gfx_arrow(0,0,second(1),second(2),col,2.5);
        ew_lgfx_hit(ax,second,data.coilId,data.sides(2).slot,data.sides(2).layer);
        ew_lgfx_vector_label(second,"- Nut "+string(data.sides(2).slot)+" / Lage "+string(data.sides(2).layer),col,[0.03,-0.13]);
        ew_gfx_arrow(first(1),first(2),endpoint(1),endpoint(2),addcolor([0.35,0.48,0.35]),1.5);
        ew_gfx_arrow(0,0,endpoint(1),endpoint(2),color("black"),2.8);
        ew_lgfx_vector_label(endpoint,"Spulensumme U",color("black"),[-0.10,0.14]);
        ew_gfx_text(-1.40,-1.35,"U_c,k = "+ew_lgfx_complex(data.coilContribution.voltageHarmonic),col,2);
        ew_gfx_text(-1.40,-1.52,"Normierte Spannungszeiger: sign * exp(+j*k*phi). Minus-Seite um 180 Grad umgepolt.",color("black"),2);
        ew_gfx_text(-1.40,-1.69,"Zum Fourier-Koeffizienten: C_c,k = conj(U_c,k) / (2*j*k).",color("black"),2);
    case 2 then
        ew_lgfx_chain(ax,data.groupContribution.members,data.groupContribution,phase,data.coilId,%t);
        ew_gfx_text(-1.40,-1.70,"Gruppensumme aus tatsächlichen Spulen; hervorgehoben: "+data.coilId+". C enthält den Faktor 1/k.",color("black"),2);
    case 3 then
        ew_lgfx_chain(ax,data.phaseContribution.members,data.phaseContribution,phase,data.coilId,%f);
        ew_gfx_text(-1.40,-1.70,"Strangsumme aus Gruppen im gemeinsamen mechanischen Bezug; keine Addition von Beträgen.",color("black"),2);
    case 4 then
        receiving=data.phaseContribution.rawFourier;
        source=data.sourceContribution.rawFourier;
        r=ew_lgfx_vector(receiving);s=ew_lgfx_vector(source);
        scale=max([norm(r),norm(s),1d-12]);if scale<1d-10 then scale=1;end
        r=r/scale;s=s/scale;
        sourceCol=ew_gfx_phase_color(data.sourcePhase);
        ew_gfx_arrow(0,0,r(1),r(2),col,3.2);
        ew_lgfx_vector_label(r,"Empfang "+phase,col,[0.03,0.06]);
        ew_gfx_arrow(0,0,s(1),s(2),sourceCol,1.8);
        ew_lgfx_vector_label(s,"Quelle "+data.sourcePhase,sourceCol,[0.03,-0.14]);
        inner=receiving.real*source.real+receiving.imag*source.imag;
        ew_gfx_text(-1.40,-1.20,"C_"+phase+",k = "+ew_lgfx_complex(receiving)+"; C_"+data.sourcePhase+",k = "+ew_lgfx_complex(source),color("black"),2);
        ew_gfx_text(-1.40,-1.37,"P = "+ew_lgfx_num(data.fourierPrefactorH)+" H; Re(C_"+phase+",k * conj(C_"+data.sourcePhase+",k)) = "+ew_lgfx_num(inner),color("black"),2);
        ew_gfx_text(-1.40,-1.54,"L_"+phase+data.sourcePhase+",k = P * Re(C_"+phase+",k * conj(C_"+data.sourcePhase+",k)) = "+ew_lgfx_num(data.selectedContributionH*1000)+" mH",col,2);
        ew_gfx_text(-1.40,-1.71,"Gesamter exakter Eintrag: "+ew_lgfx_num(data.exactSelectedH*1000)+" mH. Einzelne Gegenbeiträge dürfen negativ sein.",color("black"),2);
    end
endfunction

function [x,y]=ew_lgfx_convergence_row(orders,values,exact,selectedOrder,top,bottom,label,col)
    x=0.08+0.87*orders/max(orders);
    low=min([0;values(:);exact]);high=max([0;values(:);exact]);
    span=max(high-low,1d-12);low=low-0.08*span;high=high+0.12*span;
    y=bottom+(values-low)/(high-low)*(top-bottom);
    exactY=bottom+(exact-low)/(high-low)*(top-bottom);
    for tick=[0,0.5,1]
        yy=bottom+tick*(top-bottom);value=low+tick*(high-low);
        ew_gfx_line([0.08,yy;0.95,yy],addcolor([0.86,0.89,0.82]),0.7,2);
        ew_gfx_text(-0.08,yy-0.009,ew_lgfx_num(value*1000),addcolor([0.42,0.48,0.39]),1.8);
    end
    ew_gfx_line([0.08,exactY;0.95,exactY],color("black"),1.3,2);
    ew_gfx_line([x(:),y(:)],col,2.0);
    ew_gfx_text(0.08,top+0.025,label+" [mH]",col,2.5);
    ew_gfx_text(0.62,top+0.025,"Exakt: "+ew_lgfx_num(exact*1000),color("black"),2);
    if selectedOrder<=max(orders) then
        pos=find(orders==selectedOrder);
        if size(pos,"*")>0 then
            xp=x(pos(1));yp=y(pos(1));
            ew_gfx_line([xp,bottom;xp,top],addcolor([0.78,0.58,0.28]),1.1,2);
            xpoly(xp,yp,"marks");marker=gce();marker.mark_style=9;marker.mark_size=5;marker.mark_foreground=col;marker.mark_background=col;
        end
    end
    for tick=unique([1,round(max(orders)/2),max(orders)])
        xp=0.08+0.87*tick/max(orders);
        ew_gfx_text(xp-0.012,bottom-0.032,string(tick),addcolor([0.42,0.48,0.39]),1.8);
    end
endfunction

function ax=ew_plot_convergence(data,phase,sourcePhase,selectedOrder,axesHandle)
    if argn(2)<2 then phase="A";end
    if argn(2)<3 then sourcePhase="B";end
    if argn(2)<4 then selectedOrder=1;end
    if argn(2)<5 then axesHandle=[];end
    ax=ew_gfx_prepare("Konvergenz: endliche Fourier-Summe gegen exaktes Wicklungsintegral",axesHandle);
    ax.data_bounds=[-0.11,-0.14;1.02,1.12];ax.isoview="off";
    ax.axes_visible=["off","off","off"];
    if ~data.valid then
        ew_gfx_text(0.02,0.5,"Ohne gültige Wicklung keine Konvergenzkurve.",color("black"),2);return;
    end
    phases=["A","B","C"];a=find(phases==phase);b=find(phases==sourcePhase);
    if isempty(a)|isempty(b) then error("Stränge müssen A, B oder C sein.");end
    K=data.maxOrder;orders=data.orders(:);
    self=data.partialSelfH(:,a);chosen=zeros(K,1);
    for n=1:K, matrix=data.partialMatricesH(n);chosen(n)=matrix(a,b);end
    [selfX,selfY]=ew_lgfx_convergence_row(orders,self,data.exactMatrixH(a,a),selectedOrder,0.97,0.77,"Selbstinduktivität L"+phase+phase,ew_gfx_phase_color(phase));
    [chosenX,chosenY]=ew_lgfx_convergence_row(orders,chosen,data.exactMatrixH(a,b),selectedOrder,0.62,0.42,"Gewählter Eintrag L"+phase+sourcePhase,ew_gfx_phase_color(sourcePhase));
    errors=max(data.relativeError(:),1d-14)*100;
    logErrors=log10(errors);lowest=floor(min(logErrors));highest=ceil(max(logErrors));
    if highest<=lowest then highest=lowest+1;end
    x=0.08+0.87*orders/K;y=0.08+(logErrors-lowest)/(highest-lowest)*0.20;
    tickStep=max(1,ceil((highest-lowest)/4));
    for exponent=lowest:tickStep:highest
        yy=0.08+(exponent-lowest)/(highest-lowest)*0.20;
        ew_gfx_line([0.08,yy;0.95,yy],addcolor([0.86,0.89,0.82]),0.7,2);
        ew_gfx_text(-0.08,yy-0.009,"10^"+string(exponent),addcolor([0.42,0.48,0.39]),1.8);
    end
    ew_gfx_line([x,y],addcolor([0.42,0.48,0.35]),2);
    ew_gfx_text(0.08,0.305,"Relativer Matrixfehler [%], logarithmisch",color("black"),2.3);
    ew_gfx_text(0.08,0.015,"Abbruchordnung K (mechanische Raumordnung)",addcolor([0.42,0.48,0.39]),2);
    if selectedOrder<=K then
        xp=0.08+0.87*selectedOrder/K;
        ew_gfx_line([xp,0.08;xp,0.28],addcolor([0.78,0.58,0.28]),1,2);
    end
    ax.user_data=struct("ewHits",list());
    metadata=ax.user_data;
    for n=1:K
        metadata.ewHits($+1)=struct("x",selfX(n),"y",selfY(n),"order",n,"ewHit","order","coilId","","slot",0,"layer",0);
        metadata.ewHits($+1)=struct("x",chosenX(n),"y",chosenY(n),"order",n,"ewHit","order","coilId","","slot",0,"layer",0);
        metadata.ewHits($+1)=struct("x",x(n),"y",y(n),"order",n,"ewHit","order","coilId","","slot",0,"layer",0);
    end
    ax.user_data=metadata;
    ew_gfx_text(0.08,-0.055,"K_max = "+string(K)+"; Matrixfehler am Ende: "+ew_lgfx_num(data.relativeError($)*100)+" %",color("black"),2);
    if selectedOrder>K then
        note="Gewählte Ordnung k="+string(selectedOrder)+" liegt außerhalb der dargestellten Summe.";
    else
        note="Markierung: Summe bis zur gewählten Ordnung k="+string(selectedOrder)+". Gestrichelt: exakter Eintrag.";
    end
    ew_gfx_text(0.08,-0.108,note,color("black"),1.8);
endfunction
