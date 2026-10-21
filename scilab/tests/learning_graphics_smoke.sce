// Native graphics/selection integration, run in a separate desktop Scilab
// process: scilab -nw -nb -f tests/learning_graphics_smoke.sce.
function ew_linked_graphics_assert(condition, label)
    global EW_LINKED_GRAPHICS_ASSERTIONS;
    EW_LINKED_GRAPHICS_ASSERTIONS = EW_LINKED_GRAPHICS_ASSERTIONS + 1;
    if ~and(condition) then error("LINKED GRAPHICS: " + label); end
endfunction

function ew_linked_graphics_selected(ax, coil)
    targets=ax.user_data.ewHits; plus=%f; minus=%f;
    for index=1:length(targets)
        hit=targets(index);
        ew_linked_graphics_assert(isfield(hit,"ewHit") & isfield(hit,"x") & isfield(hit,"y"),"Full hit metadata");
        if hit.ewHit<>"coil" | hit.coilId<>coil.id then continue;end
        if hit.slot==coil.positiveSlot & hit.layer==coil.positiveLayer then plus=%t;end
        if hit.slot==coil.negativeSlot & hit.layer==coil.negativeLayer then minus=%t;end
    end
    ew_linked_graphics_assert(plus & minus,"Selected actual positive/negative slot and layer remain selectable");
endfunction

try
    root=get_absolute_file_path("learning_graphics_smoke.sce")+"../";
    exec(root+"loader.sce",-1);
    global EW_LINKED_GRAPHICS_ASSERTIONS;EW_LINKED_GRAPHICS_ASSERTIONS=0;
    cases=[12,1,1,6;9,4,2,1;120,50,2,1];
    for caseIndex=1:size(cases,1)
        input=cases(caseIndex,:);
        w=ew_compute_winding(input(1),input(2),input(3),input(4));
        d=ew_compute_inductance(w,struct("maxOrder",20,"sampleCount",16));
        coil=w.coils(1);selection=struct("coilId",coil.id,"phase",coil.phase,"selectedOrder",w.polePairs);
        fig=scf();fig.axes_size=[1100,760];
        ew_plot_winding(w,"series",0,"",gca(),selection);ew_linked_graphics_selected(gca(),coil);
        ew_plot_slot_star(w,gca(),selection);ew_linked_graphics_selected(gca(),coil);
        ew_plot_phase_star(w,gca(),selection);ew_linked_graphics_selected(gca(),coil);
        ew_plot_zone_plan(w,gca(),selection);ew_linked_graphics_selected(gca(),coil);
        s=ew_compute_spectrum(w,20,coil.phase,"phase-sum");
        ew_plot_spectrum(s,"real",coil.phase,gca(),selection);
        ew_linked_graphics_assert(length(gca().user_data.ewHits)==40,"Two clickable targets for each actual spectrum line");
        data=ew_compute_learning(w,d,coil.id,coil.phase,"B",w.polePairs,20);
        for stage=1:4
            ew_plot_learning(data,stage,gca());
            ew_linked_graphics_assert(size(gca().children,"*")>0,"Native harmonic learning stage renders");
        end
        ew_plot_convergence(data.convergence,coil.phase,"B",w.polePairs,gca());
        targets=gca().user_data.ewHits;
        ew_linked_graphics_assert(length(targets)==60,"All three convergence curves are clickable");
        for index=1:length(targets)
            hit=targets(index);
            ew_linked_graphics_assert(hit.ewHit=="order" & hit.order>=1 & hit.order<=20,"Convergence click maps to actual truncation order");
        end
        delete(fig);
    end
    // Invalid drawings must discard prior hit targets when an axes is reused.
    fig=scf();w=ew_compute_winding(9,4,2,1);
    ew_plot_winding(w,"series",0,"",gca(),struct("coilId","A2"));
    bad=ew_compute_winding(18,2,1,0);
    ew_plot_winding(bad,"series",0,"",gca());
    ew_linked_graphics_assert(length(gca().user_data.ewHits)==0,"No stale conductor targets after invalid recalculation");
    mprintf("LINKED GRAPHICS PASSED: %d checks, three winding geometries, four learning stages and all convergence curves.\n",EW_LINKED_GRAPHICS_ASSERTIONS);
    exit(0);
catch
    mprintf("LINKED GRAPHICS FAILED: %s\n",lasterror());exit(1);
end
