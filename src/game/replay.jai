// 无窗口回放：给同一串按键，逐步输出规范化的格子状态，用来和原版引擎（tools/oracle）逐格比对。
//
//     enigmash.exe -replay keys.txt -dump out.txt [-local] [-level path/to.lvl]
//
// keys.txt：用逗号或空白分隔的 up/down/left/right/action/undo/restart
// -local：模拟原版 local_radius 17（和原版对照时要开）

run_replay :: (args: [] string) -> int {
    keys_path  := "";
    dump_path  := "";
    level_path := DEFAULT_LEVEL_PATH;

    i := 1;
    while i < args.count {
        a := args[i];
        if a == "-replay" && i + 1 < args.count { keys_path  = args[i+1]; i += 2; continue; }
        if a == "-dump"   && i + 1 < args.count { dump_path  = args[i+1]; i += 2; continue; }
        if a == "-level"  && i + 1 < args.count { level_path = args[i+1]; i += 2; continue; }
        if a == "-local"  { emulate_local_radius = true; i += 1; continue; }
        i += 1;
    }

    keys_text, ok := read_entire_file(keys_path);
    if !ok { log_error("Can't read '%'.", keys_path); return 1; }

    s := *game;
    s.headless = true;
    if !session_load_level(s, level_path)  return 1;
    session_new_game(s, show_intro = false);
    session_drain(s);

    b: String_Builder;
    dump_state(*b, s, 0);

    step := 0;
    for token: split(keys_text, cast(u8) #char ",",, temp) {
        for word: split(token, cast(u8) #char "\n",, temp) {
            k := trim(word);
            if !k  continue;

            s.message = "";   // 原版测试框架里消息不阻塞
            if k == {
                case "up";      session_input(s, .UP);
                case "down";    session_input(s, .DOWN);
                case "left";    session_input(s, .LEFT);
                case "right";   session_input(s, .RIGHT);
                case "action";  session_input(s, .ACTION);
                case "x";       session_input(s, .ACTION);
                case "undo";    session_undo(s);
                case "restart"; session_restart(s);
                case;
                    log_error("Unknown key '%'.", k);
                    return 1;
            }
            s.message = "";
            session_drain(s);

            step += 1;
            dump_state(*b, s, step);
        }
    }

    out := builder_to_string(*b);
    if dump_path {
        if !write_entire_file(dump_path, out) { log_error("Can't write '%'.", dump_path); return 1; }
    } else {
        write_string(out);
    }
    return 0;
}

// 每格一行：x,y: token token ...（token 按字母排序，和 tools/oracle/oracle.js 的 canonical() 一致）
dump_state :: (b: *String_Builder, s: *Session, step: int) {
    print_to_builder(b, "step %\n", step);
    l := *s.level;
    tokens: [..] string;
    tokens.allocator = temp;

    for y: 0..l.h-1  for x: 0..l.w-1 {
        c := s.state.cells[x * l.h + y];
        array_reset_keeping_memory(*tokens);

        if c.num   array_add(*tokens, tprint("w%", cast(int) c.num));
        if c.hide  array_add(*tokens, tprint("h%", cast(int) c.hide));
        if c.swap  array_add(*tokens, tprint("sw%", c.swap));

        OBJ_TOKENS :: struct { o: Obj; name: string; }.[
            .{.WALL, "wall"}, .{.THING, "thing"}, .{.PLAYER, "p"}, .{.CAMERA, "cam"}, .{.SUNK, "sunk"},
            .{.TOGGLE, "toggle"}, .{.JUST_P, "jp"}, .{.JUST_O, "jo"}, .{.SWAPPED, "swapped"},
            .{.M5U, "m5u"}, .{.M5D, "m5d"}, .{.M5L, "m5l"}, .{.M5R, "m5r"}, .{.TAIL, "tail"}, .{.EXIT, "exit"},
            .{.M4U, "m4u"}, .{.M4D, "m4d"}, .{.M4L, "m4l"}, .{.M4R, "m4r"},
            .{.M6U, "m6u"}, .{.M6D, "m6d"}, .{.M6L, "m6l"}, .{.M6R, "m6r"}, .{.LEGS, "legs"},
            .{.LU, "lu"}, .{.LD, "ld"}, .{.LL, "ll"}, .{.LR, "lr"}, .{.LINKED, "linked"},
            .{.WENT_L, "wentl"}, .{.WENT_R, "wentr"},
        ];
        for OBJ_TOKENS  if c.obj & it.o  array_add(*tokens, it.name);
        if c.mark & .CHECKPOINT  array_add(*tokens, "checkpoint");

        if !tokens.count  continue;
        quick_sort(tokens, compare_strings);
        print_to_builder(b, "%,%:", x, y);
        for tokens  print_to_builder(b, " %", it);
        append(b, "\n");
    }
}
