#import "Compiler";

build :: () {
    w := compiler_create_workspace("Jailor");
    if !w {
        write_string("The world is not ready!\n");
        return;
    }

    options := get_build_options(w);
    options.output_executable_name = "enigmash";
    set_build_options(options, w);

    add_build_file("./src/game.jai", w);
    set_build_options_dc(.{do_output=false});
}

#run build();
