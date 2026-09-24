// 资源包：构建时 first.jai 把 data/ 打成 bin/data/enigmash.package（Simple_Package），
// 运行时整包读进内存，按「相对 data/ 的路径」取条目，例如 "fonts/OpenSans-Regular.ttf"。
//
// 关卡例外：开发机上（仓库里的 data/levels/ 还在）优先读 / 写仓库里的散文件，
// 这样编辑器保存后不用重新打包就能试玩；发布出去没有仓库时只读包里的那份。

PACKAGE_PATH :: "data/enigmash.package";

// 仓库 data/ 的绝对路径（编译期确定），只在开发机上存在
DEV_DATA_DIR :: #run -> string {
    #import "String";
    dir := path_strip_filename(#filepath);          // .../src/core/
    return join(dir, "../../data");
}

data_package : Load_Package;

// 包按 exe 所在目录找，和工作目录无关。
// set_cwd：游戏模式把工作目录切到 exe 旁边（save/ 等相对路径都以它为准）；
//          回放模式不切，命令行里的相对路径仍然相对调用者。
init_data_package :: (set_cwd := true) {
    exe_dir := path_strip_filename(get_path_of_running_executable());
    if set_cwd  set_working_directory(exe_dir);

    path := tprint("%/%", exe_dir, PACKAGE_PATH);
    if !init_from_file(*data_package, path) {
        log_error("Can't load the resource package '%'.", path);
        exit(1);
    }
}

// 取包里的一个条目；返回的内存属于包，程序结束前一直有效
data_file :: (name: string) -> [] u8, bool {
    found, entry := table_find(*data_package.lookup, name);
    if !found {
        log_error("Resource '%' is not in the package.", name);
        return .[], false;
    }
    return entry.data, true;
}

data_file_string :: (name: string) -> string, bool {
    bytes, ok := data_file(name);
    return xx bytes, ok;
}

// 关卡在开发机上的散文件路径（仓库 data/ 下）。没有仓库时返回 ""。
dev_level_path :: (name: string) -> string {
    dir := tprint("%/levels", DEV_DATA_DIR);
    if !file_exists(dir)  return "";
    return tprint("%/%", dir, name);
}

#scope_file

#import "Simple_Package";
#import "Hash_Table";
#import "System";
