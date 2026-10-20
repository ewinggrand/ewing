// In Scilab: execute this file through File > Execute.
ew_start_directory = get_absolute_file_path("start.sce");
exec(ew_start_directory + "loader.sce", -1);
clear ew_start_directory;
ew_gui();
