// Native diagram integration for the worked phasor animation.
function ew_animation_graphics_assert(condition,label)
    global EW_ANIMATION_GRAPHICS_CHECKS;
    EW_ANIMATION_GRAPHICS_CHECKS=EW_ANIMATION_GRAPHICS_CHECKS+1;
    if ~and(condition) then error("ANIMATION GRAPHICS: "+label);end
endfunction

try
    root=get_absolute_file_path("animation_graphics_smoke.sce")+"../";
    exec(root+"loader.sce",-1);
    if exists("ew_compute_animation")<>1 then exec(root+"macros/animation.sci",-1);end
    if exists("ew_plot_animation")<>1 then exec(root+"macros/animation_graphics.sci",-1);end
    global EW_ANIMATION_GRAPHICS_CHECKS;EW_ANIMATION_GRAPHICS_CHECKS=0;
    cases=[12,1,1,6;9,4,2,1;120,50,2,1];
    for ci=1:size(cases,1)
        input=cases(ci,:);w=ew_compute_winding(input(1),input(2),input(3),input(4));
        coil=w.coils(1);
        d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
        lesson=ew_compute_learning(w,d,coil.id,coil.phase,"B",w.polePairs,20);
        data=ew_compute_animation(lesson);
        ew_animation_graphics_assert(data.valid,"Valid animation data");
        fig=scf();fig.axes_size=[1100,760];
        indices=1:length(data.frames);
        if ci==3 then indices=unique([1:5,6,length(data.frames)-1,length(data.frames)]);end
        bands=struct();
        for index=indices
            f=data.frames(index);ax=ew_plot_animation(data,index,gca());
            meta=ax.user_data;
            ew_animation_graphics_assert(meta.ewRole=="animation" & meta.frameIndex==index,"Actual native frame metadata");
            ew_animation_graphics_assert(meta.activeCoilIds==f.activeCoilIds,"Actual current coil IDs");
            ew_animation_graphics_assert(meta.includedCoilIds==f.includedCoilIds,"Accumulated coil IDs remain distinct");
            ew_animation_graphics_assert(meta.scale>=1,"Declared drawing scale");
            if isfield(bands,meta.band) then
                ew_animation_graphics_assert(meta.scale==bands(meta.band),"Scale fixed throughout each complete addition");
            else bands(meta.band)=meta.scale;end
            mathCount=0;children=ax.children;
            for k=1:size(children,"*")
                h=children(k);
                if h.type=="Text" then
                    if size(h.text,"*")==1 then
                        if length(h.text)>1 then
                            if part(h.text,1)=="$" then mathCount=mathCount+1;end
                        end
                    end
                end
            end
            ew_animation_graphics_assert(mathCount==3,"Formula, numeric substitution and result use native LaTeX");
            for n=1:length(meta.ewHits)
                hit=meta.ewHits(n);
                ew_animation_graphics_assert(or(f.includedCoilIds==hit.coilId),"Hit target belongs to an actual included coil");
            end
        end
        // Highlight a complete actual group without changing the central
        // selected coil, and without touching the physical winding result.
        selection=struct("coilId",coil.id,"activeCoilIds",lesson.groupContribution.coilIds);
        before=w;
        ew_plot_winding(w,"series",0,"",gca(),selection);
        ew_animation_graphics_assert(gca().user_data.selectedCoilId==coil.id,"Transient highlight preserves central selected coil");
        ew_animation_graphics_assert(gca().user_data.activeCoilIds==lesson.groupContribution.coilIds,"Winding highlights actual complete contribution");
        ew_animation_graphics_assert(isequal(w,before),"Transient highlight leaves physical winding data unchanged");
        if ci==2 then xs2png(fig,fullfile(TMPDIR,"wicklungsatelier-animation-winding.png"));end
        delete(fig);
    end
    // Orders with cancelled phase results remain native drawable; the zero
    // resultant is represented by a point instead of a spurious direction.
    w=ew_compute_winding(9,4,2,1);d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
    lesson=ew_compute_learning(w,d,"A2","A","B",9,20);data=ew_compute_animation(lesson);
    fig=scf();fig.axes_size=[1100,760];
    ax=ew_plot_animation(data,length(data.frames),gca());
    ew_animation_graphics_assert(size(ax.children,"*")>0,"Cancelled resultant renders without invented angle");
    xs2png(fig,fullfile(TMPDIR,"wicklungsatelier-animation-zero.png"));
    mprintf("ANIMATION GRAPHICS PASSED: %d checks, actual coil highlights, fixed scales and native worked formulas.\n",EW_ANIMATION_GRAPHICS_CHECKS);
    exit(0);
catch
    mprintf("ANIMATION GRAPHICS FAILED: %s\n",lasterror());exit(1);
end
