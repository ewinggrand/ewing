// Noninteractive example; also works with scilab-cli -nb -f demo.sce.
ew_demo_directory = get_absolute_file_path("demo.sce");
exec(ew_demo_directory + "loader.sce", -1);
w = ew_compute_winding(9, 4, 2, 1);
s = ew_compute_spectrum(w, 20, "A", "phase-sum");
d = ew_compute_inductance(w, struct("radiusM", 0.05, "lengthM", 0.1, ..
    "gapM", 0.001, "turnsPerCoil", 10, "currents", [1;0;0]));
mprintf("Q=%d, p=%d, q=%.6f, y=%d, kw1=%.8f\n", w.slots, w.polePairs, w.q, w.coilSpan, w.metrics.kw);
mprintf("Luftspaltinduktivitaeten / mH:\n");
disp(d.matrixH * 1000);
mprintf("Flussverkettung / mWb:\n");
disp(d.fluxLinkagesWbTurns * 1000);
mprintf("Die Geometrie und Windungszahl sind Beispielwerte.\n");
if getscilabmode() <> "NWNI" then
    scf(); ew_plot_winding(w, "series", 0, "", gca());
    scf(); ew_plot_spectrum(s, "real", "A", gca());
end
