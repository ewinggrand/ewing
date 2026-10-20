// Load the native Scilab functions without opening a window.
global EW_SCILAB_ROOT;
EW_SCILAB_ROOT = get_absolute_file_path("loader.sce");
exec(EW_SCILAB_ROOT + "macros/winding.sci", -1);
exec(EW_SCILAB_ROOT + "macros/spectrum.sci", -1);
exec(EW_SCILAB_ROOT + "macros/inductance.sci", -1);
exec(EW_SCILAB_ROOT + "macros/graphics.sci", -1);
exec(EW_SCILAB_ROOT + "macros/export.sci", -1);
exec(EW_SCILAB_ROOT + "macros/gui.sci", -1);
