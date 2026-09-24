#import "Compiler";

build :: () {
    w := compiler_create_workspace("Jailor");
    if !w {
        write_string("The world is not ready!\n");
        return;
    }

    options := get_build_options(w);
    options.output_executable_name = "enigmash";
    // 默认开优化（保留调试信息）；`jai first.jai - debug` 出未优化版本
    args := get_build_options().compile_time_command_line;
    debug := false;
    for args  if it == "debug"  debug = true;
    if !debug  set_optimization(*options, .OPTIMIZED);
    set_build_options(options, w);

    add_build_file("./src/main.jai", w);
    set_build_options_dc(.{do_output=false});
}

#run build();
