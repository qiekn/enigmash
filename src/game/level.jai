// 关卡（静态数据）与游戏状态（动态数据），以及 .level 文本格式的读写。
// 格式说明见 docs/architecture.md「关卡文件格式」。

Pos :: struct { x, y: s32; }

operator == :: (a: Pos, b: Pos) -> bool { return a.x == b.x && a.y == b.y; }

Tunnel_End :: struct {
    pos        : Pos;
    start_open : bool;     // 初始是否已激活（原版 awarp = 激活，iwarp = 未激活）
    message    : string;   // 第一次抵达时弹出的消息 id，可为空
    style      : u8;       // 端点贴图：#char "a".."d" 对应原版 awarpa..awarpd
}

// ends[0] 连着 path[0]，ends[1] 连着 path[path.count-1]
Tunnel_Def :: struct {
    ends : [2] Tunnel_End;
    path : [..] Pos;
}

Message_Def :: struct {
    id   : string;
    text : string;
}

// 镜头正在隧道里飞
Travel :: struct {
    active  : bool;
    tunnel  : s32;
    forward : bool;    // true = 从 ends[0] 飞向 ends[1]
    step    : s32;     // 镜头当前所在的 path 下标
    wait    : u8;      // 0 = 无，1 = 原版 wait，2 = 原版 wait2
}

Game_State :: struct {
    cells  : [] Cell;
    travel : Travel;
    open   : u32;      // 第 (tunnel*2 + end) 位 = 该隧道端点已激活
}

Level :: struct {
    w, h     : s32;
    title    : string;
    author   : string;
    initial  : Game_State;
    letters  : [] u8;              // 装饰字母，0 = 无（纯静态，不参与逻辑）
    tunnels  : [..] Tunnel_Def;
    messages : [..] Message_Def;
    path     : string;
}

// ----------------------------------------------------------------------------: 状态工具

state_alloc :: (s: *Game_State, cell_count: int) {
    s.cells = NewArray(cell_count, Cell);
}

state_free :: (s: *Game_State) {
    array_free(s.cells);
    s.cells = .[];
}

state_copy :: (dst: *Game_State, src: Game_State) {
    if dst.cells.count != src.cells.count {
        array_free(dst.cells);
        dst.cells = NewArray(src.cells.count, Cell, initialized = false);
    }
    memcpy(dst.cells.data, src.cells.data, src.cells.count * size_of(Cell));
    dst.travel = src.travel;
    dst.open   = src.open;
}

state_equal :: (a: Game_State, b: Game_State) -> bool {
    if a.cells.count != b.cells.count  return false;
    if memcmp(a.cells.data, b.cells.data, a.cells.count * size_of(Cell)) != 0  return false;
    return a.travel == b.travel && a.open == b.open;
}

operator == :: (a: Travel, b: Travel) -> bool {
    return a.active == b.active && a.tunnel == b.tunnel && a.forward == b.forward && a.step == b.step && a.wait == b.wait;
}

level_free :: (l: *Level) {
    state_free(*l.initial);
    array_free(l.letters);
    for * l.tunnels  array_free(it.path);
    array_reset(*l.tunnels);
    array_reset(*l.messages);
}

find_message :: (l: *Level, id: string) -> string {
    for l.messages  if it.id == id  return it.text;
    return id;
}

tunnel_open_bit :: (tunnel: int, end: int) -> u32 { return cast(u32)1 << cast(u32)(tunnel*2 + end); }

initial_open_bits :: (l: *Level) -> u32 {
    bits: u32;
    for t, ti: l.tunnels  for e, ei: t.ends  if e.start_open  bits |= tunnel_open_bit(ti, ei);
    return bits;
}

// ----------------------------------------------------------------------------: 读

// 实体种类 -> 格子里的标记
Entity_Kind :: struct { name: string; obj: Obj; mark: Mark; }
ENTITY_KINDS :: Entity_Kind.[
    .{"checkpoint",        0, .CHECKPOINT},
    .{"camera_stick",      0, .CAMSTICK},
    .{"camera_shift_left", 0, .CAMSHIFTLEFT},
    .{"hint_reset",        0, .HINT_RESET},
    .{"branch_left",       0, .BRANCH_L},
    .{"branch_right",      0, .BRANCH_R},
    .{"branch_once",       0, .BRANCH_ONCE},
    .{"uhh",               0, .UHH},
    .{"bad_idea",          0, .BAD_IDEA},
    .{"oops",              .OOPS,     0},
    .{"candy_bowl",        .GREEDY,   0},
    .{"secret",            .SECRET,   0},
    .{"win_spawn",         .WINSPAWN, 0},
    .{"no_link_up",        .FIX1,     0},
    .{"no_link",           .FIX2,     0},
];

load_level :: (path: string) -> Level, ok: bool {
    text, read_ok := read_entire_file(path);
    if !read_ok {
        log_error("Can't read level file '%'.", path);
        l: Level;
        return l, false;
    }
    defer free(text);
    l, ok := parse_level(text, path);
    return l, ok;
}

// 默认关卡的散文件路径：开发机上是仓库 data/levels/（编辑器改完不用重新打包就能玩），
// 否则是 exe 旁边的 data/levels/（发布版编辑器保存到这里，覆盖包里的那份）
default_level_path :: () -> string {
    dev := dev_level_path(DEFAULT_LEVEL_NAME);
    if dev  return dev;
    return tprint("data/levels/%", DEFAULT_LEVEL_NAME);
}

// 默认关卡：有散文件就读散文件，否则读资源包
load_default_level :: () -> Level, ok: bool {
    path := default_level_path();
    if file_exists(path) {
        l, ok := load_level(path);
        return l, ok;
    }

    name := tprint("levels/%", DEFAULT_LEVEL_NAME);
    text, ok := data_file_string(name);
    if !ok {
        l: Level;
        return l, false;
    }
    l, parsed := parse_level(text, name);
    if parsed {
        free(l.path);
        l.path = copy_string(path);
    }
    return l, parsed;
}

// path 只用于报错和 Level.path（编辑器保存时写回这里）
parse_level :: (text: string, path: string) -> Level, ok: bool {
    l: Level;
    l.path = copy_string(path);

    lines := split(text, "\n",, temp);
    for * lines  it.* = trim_right(it.*, "\r");

    fail :: (line_index: int, fmt: string, args: ..Any) #expand {
        log_error("%:%: %", path, line_index + 1, tprint(fmt, ..args));
        `return `l, false;
    }

    li := 0;
    next_line :: () -> string, bool #expand {
        while li < lines.count {
            s := lines[li];
            li += 1;
            t := trim(s);
            if !t || t[0] == #char "#"  continue;
            return s, true;
        }
        return "", false;
    }

    header := next_line();
    if !begins_with(header, "enigmash-level 1")  fail(li - 1, "Not an enigmash level (bad header).");

    size_line := next_line();
    parts := split(trim(size_line), " ",, temp);
    if parts.count != 3 || parts[0] != "size"  fail(li - 1, "Expected 'size W H'.");
    l.w = cast(s32) string_to_int(parts[1]);
    l.h = cast(s32) string_to_int(parts[2]);
    if l.w <= 0 || l.h <= 0  fail(li - 1, "Bad level size.");

    n := l.w * l.h;
    state_alloc(*l.initial, n);
    l.letters = NewArray(n, u8);
    cells := l.initial.cells;

    idx :: (x: int, y: int) -> int #expand { return x * `l.h + y; }

    section := "";
    current_tunnel: *Tunnel_Def;

    while true {
        line, ok := next_line();
        if !ok break;
        t := trim(line);

        if t[0] == #char "[" {
            close := find_index_from_left(t, #char "]");
            if close < 0  fail(li - 1, "Bad section header.");
            section = slice(t, 1, close - 1);

            // 网格层：紧跟 h 行
            if section == "terrain" || section == "objects" || section == "fixtures" || section == "edges" || section == "world" || section == "hidden" {
                for y: 0..l.h-1 {
                    if li >= lines.count  fail(li, "Grid '%' ends early.", section);
                    row := lines[li];
                    li += 1;
                    if row.count < l.w  fail(li - 1, "Grid '%' row % is too short.", section, y);

                    for x: 0..l.w-1 {
                        c := row[x];
                        cell := *cells[idx(x, y)];
                        if section == {
                            case "terrain";
                                if c == #char "x"  cell.obj |= .WALL;
                                else if c == #char "~"  cell.obj |= .SUNK;
                            case "objects";
                                if c == #char "o"  cell.obj |= .THING;
                                else if c == #char "p"  cell.obj |= .PLAYER | .CAMERA;
                            case "fixtures";
                                if c == #char "t"  cell.obj |= .TOGGLE;
                                else if c == #char "T"  cell.obj |= .TOGGLE | .JUST_O;
                            case "edges";
                                if c == #char "|" || c == #char "+" {
                                    cell.obj |= .STOP_R;
                                    if x + 1 < l.w  cells[idx(x + 1, y)].obj |= .STOP_L;
                                }
                                if c == #char "_" || c == #char "+" {
                                    cell.obj |= .STOP_D;
                                    if y + 1 < l.h  cells[idx(x, y + 1)].obj |= .STOP_U;
                                }
                            case "world";
                                if c >= #char "1" && c <= #char "7"  cell.num = cast(World)(c - #char "0");
                            case "hidden";
                                if c >= #char "1" && c <= #char "7"  cell.hide = cast(World)(c - #char "0");
                        }
                    }
                }
                section = "";
                continue;
            }

            if begins_with(section, "tunnel") {
                current_tunnel = array_add(*l.tunnels);
            }
            continue;
        }

        if section == "meta" {
            key, value := split_key_value(t);
            if key == "title"   l.title  = copy_string(value);
            if key == "author"  l.author = copy_string(value);

        } else if section == "entities" {
            p := split(t, " ",, temp);
            if p.count < 3  fail(li - 1, "Bad entity line.");
            x := string_to_int(p[1]);
            y := string_to_int(p[2]);
            if x < 0 || y < 0 || x >= l.w || y >= l.h  fail(li - 1, "Entity out of bounds.");
            cell := *cells[idx(x, y)];

            if p[0] == "letter" {
                if p.count < 4 || !p[3]  fail(li - 1, "Letter entity needs a character.");
                l.letters[idx(x, y)] = p[3][0];
            } else {
                found := false;
                for ENTITY_KINDS  if it.name == p[0] {
                    cell.obj  |= it.obj;
                    cell.mark |= it.mark;
                    found = true;
                    break;
                }
                if !found  fail(li - 1, "Unknown entity '%'.", p[0]);
            }

        } else if begins_with(section, "tunnel") {
            if !current_tunnel  fail(li - 1, "Tunnel data outside of a tunnel section.");
            p := split(t, " ",, temp);
            if p[0] == "end0" || p[0] == "end1" {
                e := *current_tunnel.ends[ifx p[0] == "end0" then 0 else 1];
                if p.count < 4  fail(li - 1, "Bad tunnel end.");
                e.pos = .{cast(s32) string_to_int(p[1]), cast(s32) string_to_int(p[2])};
                e.start_open = p[3] == "active";
                e.style = #char "a";
                for 4..p.count-1 {
                    k, v := split_key_value_eq(p[it]);
                    if k == "message"  e.message = copy_string(v);
                    if k == "style" && v  e.style = v[0];
                }
            } else if p[0] == "path" {
                rest := trim(slice(t, 4, t.count - 4));
                for split(rest, "|",, temp) {
                    q := split(trim(it), " ",, temp);
                    if q.count != 2  fail(li - 1, "Bad tunnel path point.");
                    array_add(*current_tunnel.path, Pos.{cast(s32) string_to_int(q[0]), cast(s32) string_to_int(q[1])});
                }
            }

        } else if section == "messages" {
            key, value := split_key_value(t);
            m := array_add(*l.messages);
            m.id   = copy_string(key);
            m.text = unescape_newlines(value);
        }
    }

    // 校验：恰好一个玩家，隧道完整
    players := 0;
    for cells  if it.obj & .PLAYER  players += 1;
    if players != 1  log("WARNING: level '%' has % players (expected 1).", path, players);
    for l.tunnels  if it.path.count < 1  log("WARNING: level '%' has a tunnel without path.", path);

    l.initial.open = initial_open_bits(*l);
    return l, true;
}

split_key_value :: (s: string) -> string, string {
    i := find_index_from_left(s, #char "=");
    if i < 0  return trim(s), "";
    return trim(slice(s, 0, i)), trim(slice(s, i + 1, s.count - i - 1));
}

split_key_value_eq :: (s: string) -> string, string {
    i := find_index_from_left(s, #char "=");
    if i < 0  return s, "";
    return slice(s, 0, i), slice(s, i + 1, s.count - i - 1);
}

unescape_newlines :: (s: string) -> string {
    b: String_Builder;
    i := 0;
    while i < s.count {
        if s[i] == #char "\\" && i + 1 < s.count && s[i+1] == #char "n" {
            append(*b, #char "\n");
            i += 2;
            continue;
        }
        append(*b, s[i]);
        i += 1;
    }
    return builder_to_string(*b);
}

escape_newlines :: (s: string) -> string {
    b: String_Builder;
    for 0..s.count-1 {
        if s[it] == #char "\n"  append(*b, "\\n");
        else append(*b, s[it]);
    }
    return builder_to_string(*b,, temp);
}

// ----------------------------------------------------------------------------: 写

save_level :: (l: *Level, path: string) -> bool {
    b: String_Builder;
    p :: (fmt: string, args: ..Any) #expand { print_to_builder(*`b, fmt, ..args); }

    cells := l.initial.cells;
    idx :: (x: int, y: int) -> int #expand { return x * `l.h + y; }

    p("enigmash-level 1\n");
    p("size % %\n\n", l.w, l.h);
    p("[meta]\n");
    p("title  = %\n", l.title);
    p("author = %\n\n", l.author);

    // 每层一个 (Cell) -> u8。不用 $Code：Code 实参会在调用处先做类型检查，那里没有 c
    grid :: (title: string, comment: string, cell_char: (c: Cell) -> u8) #expand {
        p("[%]   # %\n", title, comment);
        for y: 0..`l.h-1 {
            for x: 0..`l.w-1 {
                append(*`b, cell_char(`cells[idx(x, y)]));
            }
            append(*`b, "\n");
        }
        append(*`b, "\n");
    }

    grid("terrain",  ". floor   x wall   ~ sunk", c =>
        ifx c.obj & .WALL then cast(u8) #char "x" else ifx c.obj & .SUNK then cast(u8) #char "~" else cast(u8) #char ".");
    grid("objects",  ". none   o thing   p player", c =>
        ifx c.obj & .PLAYER then cast(u8) #char "p" else ifx c.obj & .THING then cast(u8) #char "o" else cast(u8) #char ".");
    grid("fixtures", ". none   t toggle   T toggle (already pressed)", c =>
        ifx (c.obj & .TOGGLE) && (c.obj & .JUST_O) then cast(u8) #char "T" else ifx c.obj & .TOGGLE then cast(u8) #char "t" else cast(u8) #char ".");
    grid("edges",    ". none   | right   _ bottom   + both", edge_char);
    grid("world",    ". none   1-6   7 void", c =>
        ifx c.num  then cast(u8)(#char "0" + cast(u8) c.num)  else cast(u8) #char ".");
    grid("hidden",   ". none   1-6   7 void", c =>
        ifx c.hide then cast(u8)(#char "0" + cast(u8) c.hide) else cast(u8) #char ".");

    p("[entities]\n");
    for y: 0..l.h-1  for x: 0..l.w-1 {
        i := idx(x, y);
        c := cells[i];
        for ENTITY_KINDS {
            if (it.obj && (c.obj & it.obj)) || (it.mark && (c.mark & it.mark))  p("% % %\n", it.name, x, y);
        }
        if l.letters[i]  p("letter % % %\n", x, y, string.{1, *l.letters[i]});
    }
    p("\n");

    for t, ti: l.tunnels {
        p("[tunnel %]\n", ti);
        for e, ei: t.ends {
            p("end% % % %", ei, e.pos.x, e.pos.y, ifx e.start_open "active" else "inactive");
            if e.style    p(" style=%", string.{1, *e.style});
            if e.message  p(" message=%", e.message);
            p("\n");
        }
        p("path");
        for t.path  p("% % %", ifx it_index "  |" else "", it.x, it.y);
        p("\n\n");
    }

    p("[messages]\n");
    for l.messages  p("% = %\n", it.id, escape_newlines(it.text));

    s := builder_to_string(*b);
    defer free(s);
    return write_entire_file(path, s);
}

edge_char :: (c: Cell) -> u8 {
    r := (c.obj & .STOP_R) != 0;
    d := (c.obj & .STOP_D) != 0;
    if r && d return #char "+";
    if r      return #char "|";
    if d      return #char "_";
    return #char ".";
}

// 开发机优先使用可编辑的散文件关卡。
dev_level_path :: (name: string) -> string {
    dir := tprint("%/levels", DEV_DATA_DIR);
    if !file_exists(dir)  return "";
    return tprint("%/%", dir, name);
}
