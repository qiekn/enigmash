editor_camera : Camera;

// 关卡编辑器：状态、工具、可撤销的编辑、区域计算、校验、试玩、画布标注。
// 面板（GetRect）在 editor_ui.jai。
//
// 编辑的是 Level.initial（关卡初始状态）。坐标：逻辑格 (x, row)，row 0 在最上；
// 画布是 y 朝上的世界坐标，换算见 world_to_grid / grid_to_world。

Editor_Tool :: enum s32 { BRUSH; EDGE; WORLD; ENTITY; TUNNEL; PICK; }
TOOL_NAMES :: string.["Brush (B)", "Edge (E)", "World (W)", "Entity (N)", "Tunnel (U)", "Pick (I)"];

Brush :: enum s32 { FLOOR; WALL; SUNK; THING; PLAYER; TOGGLE; TOGGLE_PRESSED; }
BRUSH_NAMES :: string.["1 Floor", "2 Wall", "3 Sunk (filled water)", "4 Thing", "5 Player start", "6 Toggle", "7 Toggle + thing (pressed)"];

WORLD_NAMES :: string.["0 None", "1 Green (push)", "2 Pink (gravity)", "3 Yellow (water)", "4 Gray (ice)", "5 Sand (snake)", "6 Cyan (legs)", "7 Void (ending)"];

Tunnel_Stage :: enum s32 { END0; PATH; END1; }

Edit_Change :: struct {
    index  : s32;
    before : Cell;
    after  : Cell;
    letter_before, letter_after : u8;
}

Edit_Step :: struct {
    changes : [..] Edit_Change;
    has_tunnels    : bool;           // 这一步改过隧道：前后各存一份完整拷贝
    tunnels_before : [..] Tunnel_Def;
    tunnels_after  : [..] Tunnel_Def;
}

Editor :: struct {
    level  : Level;
    loaded : bool;
    path   : string;       // 堆上
    dirty  : bool;

    tool          := Editor_Tool.BRUSH;
    brush         := Brush.WALL;
    world_value   : s32 = 1;
    world_hidden  := false;
    world_fill    := false;        // 世界工具：true = 点一下填整个区域；false = 逐格刷（按住 Shift 临时切到填充）
    world_auto_edges := true;      // 逐格刷时自动在不同世界之间加边界、相同世界之间去掉边界
    entity_index  : s32 = 0;       // ENTITY_KINDS 的下标；等于 ENTITY_KINDS.count 表示装饰字母
    entity_show_all := false;
    letter_text   : string;        // 堆上
    tunnel_index  : s32 = -1;
    tunnel_stage  := Tunnel_Stage.END0;

    schematic     := false;
    show_hidden   := false;
    show_edges    := false;
    show_entities := true;
    show_regions  := false;

    region_of     : [] s32;
    region_count  : s32;
    regions_dirty := true;

    undo : [..] Edit_Step;
    redo : [..] Edit_Step;
    stroke   : Edit_Step;
    stroking := false;
    stroke_erase := false;
    last_paint   : Pos = .{-1, -1};

    // 边界工具：从一个格点拖到另一个格点画一条直线（格点坐标 = 世界坐标，y 朝上）
    edge_dragging : bool;
    edge_erase    : bool;
    edge_start, edge_end : Pos;

    hover       : Pos;
    hover_valid : bool;
    hover_frac  : Vector2;         // 鼠标在格子里的位置 [0,1)，y 朝上
    hover_vertex       : Pos;      // 离鼠标最近的格点，夹在地图范围内
    hover_vertex_valid : bool;

    panning    : bool;
    last_mouse : Vector2;

    // 文本弹窗：编辑 level.messages 里 id 为 modal_id 的那条
    modal_open   : bool;
    modal_id     : string;         // 堆上
    modal_serial : s64;            // 每次打开换一个，让文本框用新状态（光标、内容）

    status   : string;             // 堆上
    problems : [..] string;        // 堆上
}

ed : Editor;

playtest_session : Session;
play_session     := *game;         // 游戏模式当前在玩的会话（正常游戏 / 编辑器试玩）
playtesting      := false;

// ----------------------------------------------------------------------------: 进出

enter_editor :: () {
    if !ed.loaded {
        if !editor_load_default()  editor_new_level(MAP_WIDTH, MAP_HEIGHT);
        if !ed.letter_text  ed.letter_text = copy_string("A");
    }
    program_mode = .EDITOR;
    menu_return_mode = .EDITOR;
    editor_camera.bounds.x = cast(float) ed.level.w;
    editor_camera.bounds.y = cast(float) ed.level.h;
    release_player_keys();
}

editor_set_status :: (fmt: string, args: ..Any) {
    free(ed.status);
    ed.status = sprint(fmt, ..args);
}

editor_load :: (path: string) -> bool {
    level, ok := load_level(path);
    if !ok {
        editor_set_status("Failed to load %", path);
        return false;
    }
    editor_take_level(level, path);
    return true;
}

// 默认关卡（散文件优先，否则资源包）；保存时写到 default_level_path()
editor_load_default :: () -> bool {
    level, ok := load_default_level();
    if !ok {
        editor_set_status("Failed to load the default level");
        return false;
    }
    editor_take_level(level, level.path);
    return true;
}

editor_take_level :: (level: Level, path: string) {
    path_copy := copy_string(path);      // path 可能指向 ed.level 里、马上要被释放的字符串
    level_free(*ed.level);
    ed.level  = level;
    ed.loaded = true;
    free(ed.path);
    ed.path  = path_copy;
    ed.dirty = false;
    editor_clear_history();
    ed.regions_dirty = true;
    ed.tunnel_index = cast(s32) ifx level.tunnels.count then 0 else -1;

    editor_camera.bounds.x = cast(float) level.w;
    editor_camera.bounds.y = cast(float) level.h;
    camera_fit_map(*editor_camera);

    editor_validate();
    editor_set_status("Loaded % (% x %)", ed.path, level.w, level.h);
}

editor_new_level :: (w: s32, h: s32) {
    level_free(*ed.level);
    l: Level;
    l.w = w;
    l.h = h;
    l.title  = "Untitled";
    l.author = "";
    state_alloc(*l.initial, w * h);
    l.letters = NewArray(w * h, u8);
    for * l.initial.cells  it.num = .ONE;
    // 玩家放中间
    l.initial.cells[(w / 2) * h + h / 2].obj |= .PLAYER | .CAMERA;
    for DEFAULT_MESSAGE_IDS {
        m := array_add(*l.messages);
        m.id = it;
        m.text = copy_string(it);
    }
    ed.level  = l;
    ed.loaded = true;
    ed.dirty  = true;
    editor_clear_history();
    ed.regions_dirty = true;
    ed.tunnel_index = -1;
    editor_camera.bounds.x = cast(float) w;
    editor_camera.bounds.y = cast(float) h;
    camera_fit_map(*editor_camera);
    editor_set_status("New % x % level", w, h);
}

DEFAULT_MESSAGE_IDS :: string.["intro", "hint_reset", "branch", "uhh", "oops", "bad_idea", "candy_bowl", "secret", "warp_thing"];

editor_save :: () {
    if !ed.path {
        editor_set_status("No file path");
        return;
    }
    make_directory_if_it_does_not_exist(path_strip_filename(ed.path), recursive = true);
    if save_level(*ed.level, ed.path) {
        ed.dirty = false;
        editor_validate();
        editor_set_status("Saved % (% problems)", ed.path, ed.problems.count);
    } else {
        editor_set_status("Failed to save %", ed.path);
    }
}

editor_clear_history :: () {
    for * ed.undo  free_step(it);
    for * ed.redo  free_step(it);
    array_reset(*ed.undo);
    array_reset(*ed.redo);
    free_step(*ed.stroke);
    ed.stroking = false;
}

free_step :: (s: *Edit_Step) {
    array_reset(*s.changes);
    free_tunnels(*s.tunnels_before);
    free_tunnels(*s.tunnels_after);
    s.has_tunnels = false;
}

free_tunnels :: (list: *[..] Tunnel_Def) {
    for * list.*  array_free(it.path);
    array_reset(list);
}

copy_tunnels :: (dst: *[..] Tunnel_Def, src: [..] Tunnel_Def) {
    free_tunnels(dst);
    for src {
        t := array_add(dst);
        t.ends = it.ends;
        for p: it.path  array_add(*t.path, p);
    }
}

// ----------------------------------------------------------------------------: 试玩

editor_playtest :: (from_cursor: bool) {
    l := level_clone(*ed.level);
    if from_cursor && ed.hover_valid {
        for * l.initial.cells  it.obj &= ~(.PLAYER | .CAMERA);
        i := ed.hover.x * l.h + ed.hover.y;
        l.initial.cells[i].obj |= .PLAYER | .CAMERA;
        l.initial.cells[i].obj &= ~.THING;
    }

    s := *playtest_session;
    s.no_save = true;
    session_set_level(s, l);
    session_new_game(s, show_intro = false);

    play_session = s;
    playtesting  = true;
    program_mode = .GAME;
    menu_return_mode = .GAME;
    game_camera.bounds.x = cast(float) l.w;
    game_camera.bounds.y = cast(float) l.h;
    update_game_camera_target();
    camera_reset(*game_camera);
}

editor_stop_playtest :: () {
    playtesting  = false;
    play_session = *game;
    enter_editor();
}

level_clone :: (src: *Level) -> Level {
    l: Level;
    l.w = src.w;
    l.h = src.h;
    l.title  = src.title;
    l.author = src.author;
    l.path   = src.path;
    state_copy(*l.initial, src.initial);
    l.letters = array_copy(src.letters);
    copy_tunnels(*l.tunnels, src.tunnels);
    for src.messages  array_add(*l.messages, .{copy_string(it.id), copy_string(it.text)});
    return l;
}

// ----------------------------------------------------------------------------: 可撤销的编辑

ed_index :: (p: Pos) -> s32 { return p.x * ed.level.h + p.y; }

ed_in_bounds :: (p: Pos) -> bool { return p.x >= 0 && p.y >= 0 && p.x < ed.level.w && p.y < ed.level.h; }

// 改一格：记录进当前笔画
ed_set :: (i: s32, cell: Cell, letter: u8) {
    cells := ed.level.initial.cells;
    old := cells[i];
    old_letter := ed.level.letters[i];
    if memcmp(*old, *cell, size_of(Cell)) == 0 && old_letter == letter  return;

    found := false;
    for * ed.stroke.changes  if it.index == i {
        it.after = cell;
        it.letter_after = letter;
        found = true;
        break;
    }
    if !found  array_add(*ed.stroke.changes, .{i, old, cell, old_letter, letter});

    cells[i] = cell;
    ed.level.letters[i] = letter;
    ed.dirty = true;
}

ed_set_cell :: (i: s32, cell: Cell) { ed_set(i, cell, ed.level.letters[i]); }

begin_stroke :: () {
    free_step(*ed.stroke);
    ed.stroking = true;
    ed.last_paint = .{-1, -1};
}

// 隧道改动前调用：把改之前的隧道存进当前笔画
stroke_touch_tunnels :: () {
    if ed.stroke.has_tunnels  return;
    ed.stroke.has_tunnels = true;
    copy_tunnels(*ed.stroke.tunnels_before, ed.level.tunnels);
    ed.dirty = true;
}

end_stroke :: () {
    if !ed.stroking  return;
    ed.stroking = false;
    if ed.stroke.has_tunnels {
        copy_tunnels(*ed.stroke.tunnels_after, ed.level.tunnels);
        ed.level.initial.open = initial_open_bits(*ed.level);
    }
    if !ed.stroke.changes.count && !ed.stroke.has_tunnels  return;

    array_add(*ed.undo, ed.stroke);
    ed.stroke = .{};
    for * ed.redo  free_step(it);
    array_reset(*ed.redo);
    editor_validate();
}

editor_undo :: () {
    end_stroke();
    if !ed.undo.count  return;
    step := pop(*ed.undo);
    for < step.changes {
        ed.level.initial.cells[it.index] = it.before;
        ed.level.letters[it.index] = it.letter_before;
    }
    if step.has_tunnels {
        copy_tunnels(*ed.level.tunnels, step.tunnels_before);
        ed.level.initial.open = initial_open_bits(*ed.level);
    }
    array_add(*ed.redo, step);
    ed.dirty = true;
    ed.regions_dirty = true;
    clamp_tunnel_index();
    editor_validate();
    editor_set_status("Undo");
}

editor_redo :: () {
    end_stroke();
    if !ed.redo.count  return;
    step := pop(*ed.redo);
    for step.changes {
        ed.level.initial.cells[it.index] = it.after;
        ed.level.letters[it.index] = it.letter_after;
    }
    if step.has_tunnels {
        copy_tunnels(*ed.level.tunnels, step.tunnels_after);
        ed.level.initial.open = initial_open_bits(*ed.level);
    }
    array_add(*ed.undo, step);
    ed.dirty = true;
    ed.regions_dirty = true;
    clamp_tunnel_index();
    editor_validate();
    editor_set_status("Redo");
}

clamp_tunnel_index :: () {
    if ed.tunnel_index >= ed.level.tunnels.count  ed.tunnel_index = cast(s32) ed.level.tunnels.count - 1;
}

// ----------------------------------------------------------------------------: 工具

apply_tool_at :: (p: Pos, erase: bool) {
    if !ed_in_bounds(p)  return;

    if ed.tool == {
        case .BRUSH;   apply_brush(p, erase);
        case .ENTITY;  apply_entity(p, erase);
        case .EDGE;    // 边界按格点拖线，见 editor_handle_event / finish_edge_drag
        case .WORLD;
            if world_fill_mode() { if ed.last_paint != p  apply_world_fill(p, erase); }
            else                   apply_world_paint(p, erase);
        case .TUNNEL;  if ed.last_paint != p  apply_tunnel(p, erase);
        case .PICK;    apply_pick(p);
    }
    ed.last_paint = p;
}

world_fill_mode :: () -> bool {
    return ed.world_fill != ((input_button_states[Key_Code.SHIFT] & .DOWN) != 0);
}

apply_brush :: (p: Pos, erase: bool) {
    i := ed_index(p);
    c := ed.level.initial.cells[i];

    // 右键：不管当前笔刷是什么，把画笔能画的东西全擦掉（世界 / 边界 / 实体不动）
    if erase {
        c.obj &= ~(.WALL | .SUNK | .THING | .PLAYER | .CAMERA | .TOGGLE | .JUST_O);
        ed_set_cell(i, c);
        return;
    }

    if ed.brush == {
        case .FLOOR;
            c.obj &= ~(.WALL | .SUNK);
        case .WALL;
            c.obj |= .WALL; c.obj &= ~.SUNK;
        case .SUNK;
            c.obj |= .SUNK; c.obj &= ~.WALL;
        case .THING;
            c.obj |= .THING; c.obj &= ~(.PLAYER | .CAMERA);
        case .PLAYER;
            // 只能有一个玩家：先把别处的清掉
            cells := ed.level.initial.cells;
            for j: 0..cells.count-1 {
                if j != i && (cells[j].obj & (.PLAYER | .CAMERA)) {
                    o := cells[j];
                    o.obj &= ~(.PLAYER | .CAMERA);
                    ed_set_cell(cast(s32) j, o);
                }
            }
            c.obj |= .PLAYER | .CAMERA;
            c.obj &= ~.THING;
        case .TOGGLE;
            c.obj |= .TOGGLE; c.obj &= ~.JUST_O;
        case .TOGGLE_PRESSED;
            c.obj |= .TOGGLE | .JUST_O | .THING; c.obj &= ~(.PLAYER | .CAMERA);
    }
    ed_set_cell(i, c);
}

apply_entity :: (p: Pos, erase: bool) {
    i := ed_index(p);
    c := ed.level.initial.cells[i];
    letter := ed.level.letters[i];

    if erase {
        // 右键：清掉这一格所有实体
        for ENTITY_KINDS { c.obj &= ~it.obj; c.mark &= ~it.mark; }
        letter = 0;
    } else if ed.entity_index >= ENTITY_KINDS.count {
        letter = ifx ed.letter_text then ed.letter_text[0] else 0;
    } else {
        k := ENTITY_KINDS[ed.entity_index];
        c.obj  |= k.obj;
        c.mark |= k.mark;
    }
    ed_set(i, c, letter);

    // 这一笔的第一格放的是带文本的实体：弹出文本框
    if !erase && ed.last_paint.x < 0 && ed.entity_index < ENTITY_KINDS.count {
        id := ENTITY_MESSAGE[ed.entity_index];
        if id  editor_open_message(id);
    }
}

// 实体触发的消息 id（和 ENTITY_KINDS 一一对应；空 = 不带文本）。同一种实体共用一条文本。
ENTITY_MESSAGE :: string.["", "", "", "hint_reset", "branch", "branch", "branch", "uhh", "bad_idea", "oops", "candy_bowl", "secret", "", "", ""];

// 实体面板默认只列这几种，其余的勾选 "All entities" 才显示
COMMON_ENTITIES :: s32.[0, 3, 11];   // checkpoint, hint_reset, secret

#run assert(ENTITY_MESSAGE.count == ENTITY_KINDS.count);

// 改一条边界：a 的右边（right）或下边（逻辑坐标，row 向下）
ed_set_edge :: (a: Pos, right: bool, on: bool) {
    b := a;
    if right  b.x += 1; else b.y += 1;
    if !ed_in_bounds(a) || !ed_in_bounds(b)  return;

    ia := ed_index(a);
    ib := ed_index(b);
    ca := ed.level.initial.cells[ia];
    cb := ed.level.initial.cells[ib];
    flag_a := ifx right then Obj.STOP_R else .STOP_D;
    flag_b := ifx right then Obj.STOP_L else .STOP_U;
    if on { ca.obj |= flag_a;  cb.obj |= flag_b; }
    else  { ca.obj &= ~flag_a; cb.obj &= ~flag_b; }
    ed_set_cell(ia, ca);
    ed_set_cell(ib, cb);
    ed.regions_dirty = true;
}

ed_has_edge :: (a: Pos, right: bool) -> bool {
    b := a;
    if right  b.x += 1; else b.y += 1;
    if !ed_in_bounds(a) || !ed_in_bounds(b)  return false;
    return (ed.level.initial.cells[ed_index(a)].obj & ifx right then Obj.STOP_R else .STOP_D) != 0;
}

// 单击（没拖动）：切换离鼠标最近的那条边；右键只删
toggle_nearest_edge :: (p: Pos, erase: bool) {
    f := ed.hover_frac;
    dl := f.x;  dr := 1 - f.x;  dd := f.y;  du := 1 - f.y;   // 世界坐标 y 朝上：du = 离上边
    best := min(min(dl, dr), min(dd, du));

    // 统一成「某格的右边 / 下边（逻辑坐标，row 向下）」
    a := p;
    right := true;
    if best == dl      { a.x -= 1; }
    else if best == dr { }
    else if best == du { a.y -= 1; right = false; }   // 上边 = 上一行的下边
    else               { right = false; }            // 下边

    ed_set_edge(a, right, !erase && !ed_has_edge(a, right));
}

// 格点 s 到 e 的一条横线或竖线（格点坐标 = 世界坐标，y 朝上），线上每一段都设成 on
apply_edge_line :: (s: Pos, e: Pos, on: bool) {
    l := *ed.level;
    if s.y == e.y {
        // 世界 y = vy 的横线：上面一格（row = h-1-vy）的下边
        row := l.h - 1 - s.y;
        for x: min(s.x, e.x)..max(s.x, e.x)-1  ed_set_edge(.{x, row}, false, on);
    } else {
        // 世界 x = vx 的竖线：左边一格的右边
        for wy: min(s.y, e.y)..max(s.y, e.y)-1  ed_set_edge(.{s.x - 1, l.h - 1 - wy}, true, on);
    }
}

finish_edge_drag :: () {
    ed.edge_dragging = false;
    begin_stroke();
    if ed.edge_start == ed.edge_end {
        if ed.hover_valid  toggle_nearest_edge(ed.hover, ed.edge_erase);
    } else {
        apply_edge_line(ed.edge_start, ed.edge_end, !ed.edge_erase);
    }
    end_stroke();
}

// 拖动中：终点吸附到起点所在的横线或竖线上
update_edge_drag :: () {
    if !ed.hover_vertex_valid  return;
    s := ed.edge_start;
    v := ed.hover_vertex;
    if abs(v.x - s.x) >= abs(v.y - s.y)  ed.edge_end = .{v.x, s.y};
    else                                 ed.edge_end = .{s.x, v.y};
}

// 点一下：把这一格所在的整个区域（边界围起来的连通块）设成当前世界
apply_world_fill :: (p: Pos, erase: bool) {
    editor_update_regions();
    r := ed.region_of[ed_index(p)];
    v := ifx erase then World.NONE else cast(World) ed.world_value;
    cells := ed.level.initial.cells;
    for j: 0..cells.count-1 {
        if ed.region_of[j] != r  continue;
        c := cells[j];
        if ed.world_hidden  c.hide = v;
        else                c.num  = v;
        ed_set_cell(cast(s32) j, c);
    }
}

// 逐格刷世界；自动边界开着时，和四邻世界不同就加边界，相同就去掉
apply_world_paint :: (p: Pos, erase: bool) {
    i := ed_index(p);
    c := ed.level.initial.cells[i];
    v := ifx erase then World.NONE else cast(World) ed.world_value;
    if ed.world_hidden  c.hide = v;
    else                c.num  = v;
    ed_set_cell(i, c);
    ed.regions_dirty = true;
    if !ed.world_auto_edges  return;

    check :: (c: Cell, q: Pos, a: Pos, right: bool) {
        if !ed_in_bounds(q)  return;
        n := ed.level.initial.cells[ed_index(q)];
        ed_set_edge(a, right, n.num != c.num || n.hide != c.hide);
    }
    check(c, .{p.x + 1, p.y}, p, true);
    check(c, .{p.x - 1, p.y}, .{p.x - 1, p.y}, true);
    check(c, .{p.x, p.y + 1}, p, false);
    check(c, .{p.x, p.y - 1}, .{p.x, p.y - 1}, false);
}

apply_tunnel :: (p: Pos, erase: bool) {
    if ed.tunnel_index < 0 || ed.tunnel_index >= ed.level.tunnels.count {
        editor_set_status("Create a tunnel first (right panel)");
        return;
    }
    stroke_touch_tunnels();
    t := *ed.level.tunnels[ed.tunnel_index];
    if ed.tunnel_stage == {
        case .END0;  t.ends[0].pos = p;  ed.tunnel_stage = .PATH;   // 放完起点接着画路径
        case .END1;  t.ends[1].pos = p;
        case .PATH;
            if erase { if t.path.count  t.path.count -= 1; }
            else       array_add(*t.path, p);
    }
}

apply_pick :: (p: Pos) {
    c := ed.level.initial.cells[ed_index(p)];
    if      c.obj & .PLAYER  ed.brush = .PLAYER;
    else if (c.obj & .TOGGLE) && (c.obj & .JUST_O)  ed.brush = .TOGGLE_PRESSED;
    else if c.obj & .TOGGLE  ed.brush = .TOGGLE;
    else if c.obj & .THING   ed.brush = .THING;
    else if c.obj & .WALL    ed.brush = .WALL;
    else if c.obj & .SUNK    ed.brush = .SUNK;
    else                     ed.brush = .FLOOR;
    ed.world_value = cast(s32) c.num;
    ed.tool = .BRUSH;
    editor_set_status("Picked %", BRUSH_NAMES[ed.brush]);
}

// ----------------------------------------------------------------------------: 文本弹窗

// 打开文本弹窗编辑消息 id；关卡里还没有这条就先加一条空的
editor_open_message :: (id: string) {
    l := *ed.level;
    found := false;
    for l.messages  if it.id == id { found = true; break; }
    if !found {
        array_add(*l.messages, .{copy_string(id), copy_string("")});
        ed.dirty = true;
    }
    modify_string(*ed.modal_id, id);
    ed.modal_open = true;
    ed.modal_serial += 1;
}

editor_close_modal :: () {
    ed.modal_open = false;
    active_widget_deactivate_all();
}

editor_find_message :: (id: string) -> *Message_Def {
    for * ed.level.messages  if it.id == id  return it;
    return null;
}

modify_string :: (s: *string, v: string) {
    if s.* == v  return;
    old := s.*;
    s.* = copy_string(v);
    free(old);
}

// ----------------------------------------------------------------------------: 区域与校验

editor_update_regions :: () {
    if !ed.regions_dirty && ed.region_of.count == ed.level.initial.cells.count  return;
    ed.regions_dirty = false;

    l := *ed.level;
    n := l.w * l.h;
    if ed.region_of.count != n {
        array_free(ed.region_of);
        ed.region_of = NewArray(n, s32);
    }
    for * ed.region_of  it.* = -1;

    cells := l.initial.cells;
    stack: [..] s32;
    stack.allocator = temp;
    count: s32 = 0;

    for start: 0..n-1 {
        if ed.region_of[start] >= 0  continue;
        ed.region_of[start] = count;
        array_add(*stack, cast(s32) start);
        while stack.count {
            i := pop(*stack);
            x := i / l.h;
            y := i % l.h;
            c := cells[i];
            visit :: (j: s32) #expand {
                if ed.region_of[j] < 0 { ed.region_of[j] = `count; array_add(*`stack, j); }
            }
            if x + 1 < l.w && !(c.obj & .STOP_R) && !(cells[i + l.h].obj & .STOP_L)  visit(i + l.h);
            if x > 0       && !(c.obj & .STOP_L) && !(cells[i - l.h].obj & .STOP_R)  visit(i - l.h);
            if y + 1 < l.h && !(c.obj & .STOP_D) && !(cells[i + 1].obj & .STOP_U)    visit(i + 1);
            if y > 0       && !(c.obj & .STOP_U) && !(cells[i - 1].obj & .STOP_D)    visit(i - 1);
        }
        count += 1;
    }
    ed.region_count = count;
}

editor_validate :: () {
    for ed.problems  free(it);
    array_reset(*ed.problems);
    problem :: (fmt: string, args: ..Any) { array_add(*ed.problems, sprint(fmt, ..args)); }

    l := *ed.level;
    cells := l.initial.cells;

    players := 0;
    for cells  if it.obj & .PLAYER  players += 1;
    if players != 1  problem("% players (need exactly 1)", players);

    ed.regions_dirty = true;
    editor_update_regions();

    Region_Info :: struct { num, hide: World; mixed_num, mixed_hide, toggle, seen: bool; first: s32; }
    infos := NewArray(ed.region_count, Region_Info,, temp);
    for c, i: cells {
        r := *infos[ed.region_of[i]];
        if !r.seen { r.seen = true; r.num = c.num; r.hide = c.hide; r.first = cast(s32) i; }
        if c.num  != r.num   r.mixed_num  = true;
        if c.hide != r.hide  r.mixed_hide = true;
        if c.obj & .TOGGLE   r.toggle = true;
    }
    for infos {
        x := it.first / l.h;
        y := it.first % l.h;
        if it.mixed_num   problem("Region at %,% has mixed visible worlds", x, y);
        if it.mixed_hide  problem("Region at %,% has mixed hidden worlds", x, y);
        if it.num == .NONE  problem("Region at %,% has no world", x, y);
        if it.toggle && it.hide == .NONE  problem("Region at %,% has a toggle but no hidden world", x, y);
    }

    for t, ti: l.tunnels {
        if !t.path.count  problem("Tunnel % has no path", ti);
        for e: t.ends  if e.pos.x < 0 || e.pos.y < 0 || e.pos.x >= l.w || e.pos.y >= l.h  problem("Tunnel % end out of bounds", ti);
    }
}

// ----------------------------------------------------------------------------: 输入

editor_text_focused := false;   // 有文本框在输入时，快捷键让路（editor_ui 每帧更新）

editor_handle_event :: (event: Event) {
    if event.type == .MOUSE_WHEEL {
        if !mouse_over_panels()  handle_camera_wheel(*editor_camera, event, always_anchor_mouse = true);
        return;
    }
    if event.type != .KEYBOARD  return;

    key := event.key_code;
    pressed := event.key_pressed != 0;

    // 鼠标
    if key == .MOUSE_BUTTON_LEFT || key == .MOUSE_BUTTON_RIGHT || key == .MOUSE_BUTTON_MIDDLE {
        if pressed {
            if mouse_over_panels()  return;
            if key == .MOUSE_BUTTON_MIDDLE || (key == .MOUSE_BUTTON_LEFT && (input_button_states[Key_Code.SPACEBAR] & .DOWN)) {
                ed.panning = true;
                ed.last_mouse = mouse_position();
                return;
            }
            if ed.tool == .EDGE {
                if ed.hover_vertex_valid {
                    ed.edge_dragging = true;
                    ed.edge_erase = key == .MOUSE_BUTTON_RIGHT;
                    ed.edge_start = ed.hover_vertex;
                    ed.edge_end   = ed.hover_vertex;
                }
                return;
            }
            begin_stroke();
            ed.stroke_erase = key == .MOUSE_BUTTON_RIGHT;
            if ed.hover_valid  apply_tool_at(ed.hover, ed.stroke_erase);
        } else {
            if key == .MOUSE_BUTTON_MIDDLE || ed.panning { ed.panning = false; }
            if ed.edge_dragging && key != .MOUSE_BUTTON_MIDDLE  finish_edge_drag();
            end_stroke();
        }
        return;
    }

    if !pressed || editor_text_focused  return;

    ctrl  := event.ctrl_pressed;
    shift := event.shift_pressed;

    if ctrl {
        if key == {
            case #char "Z";  editor_undo();
            case #char "Y";  editor_redo();
            case #char "S";  editor_save();
            case #char "O";  if ed.path  editor_load(ed.path);
        }
        return;
    }

    if key == {
        case .F5;       editor_playtest(from_cursor = shift);
        case .TAB;      ed.schematic = !ed.schematic;
        case #char "H"; ed.show_hidden = !ed.show_hidden;
        case #char "G"; ed.show_regions = !ed.show_regions;
        case #char "F"; camera_fit_map(*editor_camera);
        case #char "B"; ed.tool = .BRUSH;
        case #char "E"; ed.tool = .EDGE;
        case #char "W"; ed.tool = .WORLD;
        case #char "N"; ed.tool = .ENTITY;
        case #char "U"; ed.tool = .TUNNEL;
        case #char "I"; ed.tool = .PICK;
    }

    // 数字键：画笔工具选画笔，世界工具选世界
    if key >= #char "0" && key <= #char "7" {
        n := cast(s32)(key - #char "0");
        if ed.tool == .WORLD  ed.world_value = n;
        if ed.tool == .BRUSH && n >= 1  ed.brush = cast(Brush)(n - 1);
    }
}

mouse_position :: () -> Vector2 {
    mx, my, ok := get_mouse_pointer_position(the_window, true);
    return .{cast(float) mx, cast(float) my};
}

editor_update :: (dt: float) {
    // 视口：拖动平移
    m := mouse_position();
    if ed.panning {
        camera_drag(*editor_camera, m - ed.last_mouse);
        ed.last_mouse = m;
    }

    // 悬停格 / 格点
    ed.hover_valid = false;
    ed.hover_vertex_valid = false;
    if !mouse_over_panels() {
        l := *ed.level;
        w := screen_to_world(*editor_camera, m.x, m.y);
        wx := cast(int) floor(w.x);
        wy := cast(int) floor(w.y);
        g := world_to_grid(l, wx, wy);
        if ed_in_bounds(g) {
            ed.hover = g;
            ed.hover_valid = true;
            ed.hover_frac = .{w.x - wx, w.y - wy};
        }
        ed.hover_vertex = .{cast(s32) clamp(floor(w.x + 0.5), 0, cast(float) l.w), cast(s32) clamp(floor(w.y + 0.5), 0, cast(float) l.h)};
        ed.hover_vertex_valid = true;
    }

    if ed.edge_dragging  update_edge_drag();

    // 按住拖动连续画
    if ed.stroking && ed.hover_valid && ed.hover != ed.last_paint {
        if ed.tool == .BRUSH || ed.tool == .ENTITY || (ed.tool == .WORLD && !world_fill_mode())  apply_tool_at(ed.hover, ed.stroke_erase);
    }

    update_camera_controls(*editor_camera, dt, pan_with_arrows = !editor_text_focused);
}

// ----------------------------------------------------------------------------: 画布

editor_draw_canvas :: () {
    l := *ed.level;
    state := *l.initial;

    // H：预览隐藏世界（所有区域都翻过来的样子）
    preview: Game_State;
    if ed.show_hidden {
        state_copy(*preview, l.initial);
        for * preview.cells  if it.hide != .NONE { t := it.num; it.num = it.hide; it.hide = t; }
        state = *preview;
    }
    defer if ed.show_hidden  state_free(*preview);

    if ed.schematic  draw_schematic(l, state);
    else             draw_level(*editor_camera, l, state);

    if ed.show_regions  draw_region_overlay(l);
    if ed.show_edges || ed.tool == .EDGE || ed.tool == .WORLD  draw_edge_overlay(l, state);
    draw_tunnel_overlay(l);
    if ed.tool == .EDGE  draw_edge_tool();
    else if ed.hover_valid  draw_hover();
    flush_graphics();

    if ed.show_entities  draw_entity_labels(l);
}

visible_cells :: (l: *Level) -> x0: int, x1: int, wy0: int, wy1: int {
    vx0, vy0, vx1, vy1 := camera_visible_grid(*editor_camera);
    return max(vx0, 0), min(vx1, l.w - 1), max(vy0, 0), min(vy1, l.h - 1);
}

draw_schematic :: (l: *Level, state: *Game_State) {
    x0, x1, wy0, wy1 := visible_cells(l);
    for x: x0..x1  for wy: wy0..wy1 {
        row := l.h - 1 - wy;
        c := state.cells[x * l.h + row];
        col := WORLD_COLORS[cast(int) c.num];
        if c.obj & .WALL  col = .{col.x * 0.45, col.y * 0.45, col.z * 0.45, 1};
        draw_rect(*editor_camera, x, wy, col);
        if c.obj & .SUNK    draw_world_rect(*editor_camera, x + 0.3, wy + 0.3, x + 0.7, wy + 0.7, .{0.1, 0.2, 0.6, 1});
        if c.obj & .TOGGLE  draw_world_rect(*editor_camera, x + 0.2, wy + 0.2, x + 0.8, wy + 0.8, .{0.8, 0.1, 0.1, 1});
        if c.obj & .THING   draw_world_rect(*editor_camera, x + 0.3, wy + 0.3, x + 0.7, wy + 0.7, .{0.6, 0.35, 0.1, 1});
        if c.obj & .PLAYER  draw_world_rect(*editor_camera, x + 0.25, wy + 0.25, x + 0.75, wy + 0.75, .{0.95, 0.4, 0.9, 1});
    }
}

draw_region_overlay :: (l: *Level) {
    editor_update_regions();
    x0, x1, wy0, wy1 := visible_cells(l);
    for x: x0..x1  for wy: wy0..wy1 {
        r := ed.region_of[x * l.h + (l.h - 1 - wy)];
        h := cast(u32)(r * 2654435761);
        col := Vector4.{cast(float)((h >> 16) & 255) / 255, cast(float)((h >> 8) & 255) / 255, cast(float)(h & 255) / 255, 0.35};
        draw_rect(*editor_camera, x, wy, col);
    }
}

draw_edge_overlay :: (l: *Level, state: *Game_State) {
    x0, x1, wy0, wy1 := visible_cells(l);
    ts := camera_tile_px(*editor_camera);
    t := max(2.0, ts / 8) / ts;   // 线宽（格为单位）
    col := Vector4.{1, 0.85, 0.2, 0.9};
    for x: x0..x1  for wy: wy0..wy1 {
        row := l.h - 1 - wy;
        c := state.cells[x * l.h + row];
        if c.obj & .STOP_R  draw_world_rect(*editor_camera, x + 1 - t, cast(float) wy, x + 1 + t, wy + 1.0, col);
        if c.obj & .STOP_D  draw_world_rect(*editor_camera, cast(float) x, wy - t, x + 1.0, wy + t, col);
    }
    // 地图边框
    edge := Vector4.{1, 1, 1, 0.5};
    draw_world_rect(*editor_camera, -t, -t, l.w + t, t, edge);
    draw_world_rect(*editor_camera, -t, l.h - t, l.w + t, l.h + t, edge);
    draw_world_rect(*editor_camera, -t, -t, t, l.h + t, edge);
    draw_world_rect(*editor_camera, l.w - t, -t, l.w + t, l.h + t, edge);
}

draw_tunnel_overlay :: (l: *Level) {
    for t, ti: l.tunnels {
        selected := ti == ed.tunnel_index;
        a := ifx selected then 0.95 else 0.5;
        for e, ei: t.ends {
            w := grid_to_world(l, e.pos);
            col := ifx ei == 0 then Vector4.{1, 0.5, 0.1, a} else Vector4.{1, 0.2, 0.6, a};
            draw_world_rect(*editor_camera, w.x + 0.1, w.y + 0.1, w.x + 0.9, w.y + 0.9, col);
        }
        for p: t.path {
            w := grid_to_world(l, p);
            draw_world_rect(*editor_camera, w.x + 0.35, w.y + 0.35, w.x + 0.65, w.y + 0.65, .{0.2, 0.9, 1, a});
        }
    }
}

draw_hover :: () {
    w := grid_to_world(*ed.level, ed.hover);
    draw_cell_outline(*editor_camera, cast(int) w.x, cast(int) w.y, .{1, 1, 1, 0.9});

    // 世界工具的填充模式：高亮整个区域
    if ed.tool == .WORLD && world_fill_mode() {
        editor_update_regions();
        l := *ed.level;
        r := ed.region_of[ed_index(ed.hover)];
        x0, x1, wy0, wy1 := visible_cells(l);
        for x: x0..x1  for wy: wy0..wy1 {
            if ed.region_of[x * l.h + (l.h - 1 - wy)] == r  draw_rect(*editor_camera, x, wy, .{1, 1, 1, 0.18});
        }
    }
}

// 边界工具：格点光标 + 正在拖的线（绿 = 加，红 = 删）
draw_edge_tool :: () {
    ts := camera_tile_px(*editor_camera);
    t := max(3.0, ts / 6) / ts;   // 线宽的一半（格为单位）

    if ed.edge_dragging {
        s := ed.edge_start;
        e := ed.edge_end;
        col := ifx ed.edge_erase then Vector4.{1, 0.25, 0.25, 0.9} else Vector4.{0.3, 1, 0.4, 0.9};
        draw_world_rect(*editor_camera, min(s.x, e.x) - t, min(s.y, e.y) - t, max(s.x, e.x) + t, max(s.y, e.y) + t, col);
    }
    if ed.hover_vertex_valid {
        v := ed.hover_vertex;
        r := t * 1.8;
        draw_world_rect(*editor_camera, v.x - r, v.y - r, v.x + r, v.y + r, .{1, 1, 1, 0.95});
    }
}

// 实体用字符标在格子上（格子太小时不画）
ENTITY_GLYPHS :: string.["*", "Z", "'", ":", "<", ">", "\\", ";", ",", "?", "_", "\"", "W", "0", "-"];

draw_entity_labels :: (l: *Level) {
    ts := camera_tile_px(*editor_camera);
    if ts < 12  return;
    font := ifx ts >= 28 then editor_font else small_font;
    if !font  return;

    x0, x1, wy0, wy1 := visible_cells(l);
    for x: x0..x1  for wy: wy0..wy1 {
        row := l.h - 1 - wy;
        i := x * l.h + row;
        c := l.initial.cells[i];

        glyphs: [4] string;
        n := 0;
        for k, ki: ENTITY_KINDS {
            if n >= glyphs.count  break;
            if (k.obj && (c.obj & k.obj)) || (k.mark && (c.mark & k.mark)) { glyphs[n] = ENTITY_GLYPHS[ki]; n += 1; }
        }
        letter := l.letters[i];
        if letter && n < glyphs.count { glyphs[n] = string.{1, *l.letters[i]}; n += 1; }
        if !n  continue;

        text := glyphs[0];
        for 1..n-1  text = tprint("%1%2", text, glyphs[it]);
        p := world_to_screen(*editor_camera, cast(float) x, cast(float) wy);
        tw := prepare_text(font, text);
        draw_screen_rect(p.x + 1, p.y + ts - font.character_height - 2, p.x + tw + 4, p.y + ts - 1, .{0, 0, 0, 0.6});
        draw_prepared_text(font, xx (p.x + 2), xx (p.y + ts - font.character_height - 1), .{1, 1, 0.4, 1});
    }
}

draw_editor_frame :: () {
    clear_background(GAME_CLEAR_COLOR);

    x, y, width, height := get_dimensions(the_window, true);
    ui_per_frame_update(the_window, width, height, seconds_since_init());

    editor_draw_canvas();
    flush_graphics();

    editor_draw_panels();
    draw_popups();
}
