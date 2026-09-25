OUTPUT_EXECUTABLE_NAME :: "enigmash";
OUTPUT_DIRECTORY       :: "bin";

DATA_SOURCE_DIRECTORY  :: "data";                 // 仓库里的资源
PACKAGE_PATH           :: "bin/data/enigmash.package";
SAVE_DIRECTORY         :: "bin/save";

// 不进资源包的文件（相对 data/）：原版关卡只给转换脚本和对照测试用
PACKAGE_EXCLUDE :: string.["levels/level.data"];

// 输出：
//   bin/enigmash.exe
//   bin/data/enigmash.package    data/ 下的全部资源（Simple_Package）
//   bin/save/                    存档
//
// `jai first.jai - release` 优化版本
#run {
    w := compiler_create_workspace("Jail");
    if !w {
        write_string("The world is not ready for jai!\n");
        return;
    }

    options := get_build_options(w);

    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
    options.output_path = OUTPUT_DIRECTORY;
    for dir: string.[OUTPUT_DIRECTORY, SAVE_DIRECTORY, path_strip_filename(PACKAGE_PATH)] {
        if !make_directory_if_it_does_not_exist(dir, recursive = true) {
            log(tprint("Could not create output directory %.", dir));
            return;
        }
    }

    release := false;
    for get_build_options().compile_time_command_line if it == "release"  release = true;
    if release set_optimization(*options, .OPTIMIZED);

    set_build_options(options, w);

    add_build_file("src/main.jai", w);

    if !write_data_package()  return;

    set_build_options_dc(.{do_output=false});
}

// 把 data/ 打成一个包；条目名 = 相对 data/ 的路径，例如 "fonts/OpenSans-Regular.ttf"
write_data_package :: () -> bool {
    package: Create_Package;
    defer deinit(*package);
    init(*package);

    files := file_list(DATA_SOURCE_DIRECTORY, recursive = true);
    count := 0;
    for path: files {
        name := path;
        advance(*name, DATA_SOURCE_DIRECTORY.count + 1);    // 去掉 "data/"
        skip := false;
        for PACKAGE_EXCLUDE  if name == it  skip = true;
        if skip  continue;

        data, ok := read_entire_file(path);
        if !ok {
            log_error("Can't read %.", path);
            return false;
        }
        add(*package, name, xx data);
        count += 1;
    }

    if !write(*package, PACKAGE_PATH) {
        log_error("Can't write %.", PACKAGE_PATH);
        return false;
    }
    print("Packed % files into %.\n", count, PACKAGE_PATH);
    return true;
}

#import "Compiler";
#import "Basic";
#import "File";
#import "File_Utilities";
#import "String";
#import "Simple_Package";
