// 游戏会话：在规则引擎之上实现原版的回合外壳
//   - 输入 tick、again 连锁（again 期间丢弃输入）
//   - 撤销（Z）、重开到检查点（R）、检查点
//   - 消息框、通关
//   - 持久化存档

TICK_MS :: 30;   // again tick 间隔。原版是每帧一个 tick（约 17ms）

Session :: struct {
    level          : Level;
    state          : Game_State;
    restart_target : Game_State;

    // 撤销栈：undo_top 是最近一次备份的完整拷贝，更早的备份用差分存
    undo_top    : Game_State;
    undo_count  : int;              // 备份个数（含 undo_top）
    undo_diffs  : [..] Undo_Diff;   // undo_diffs[k] 把第 k+2 个备份变回第 k+1 个

    againing    : bool;
    again_ms    : float;

    message     : string;           // 正在显示的消息文本，"" = 没有
    won         : bool;
    inputs_since_save : int;

    headless    : bool;             // 回放 / 测试：不放音效、不存档
    no_save     : bool;             // 编辑器试玩：不存档

    jumps       : int;              // 状态跳变计数（新游戏 / 读档 / 撤销 / 重开），渲染层据此跳过过渡动画
}

Undo_Cell :: struct { index: s32; cell: Cell; }
Undo_Diff :: struct {
    cells  : [] Undo_Cell;
    travel : Travel;
    open   : u32;
}

game : Session;

// ----------------------------------------------------------------------------: 开始

session_load_level :: (s: *Session, path: string) -> bool {
    level, ok := load_level(path);
    if !ok  return false;
    session_set_level(s, level);
    return true;
}

session_load_default_level :: (s: *Session) -> bool {
    level, ok := load_default_level();
    if !ok  return false;
    session_set_level(s, level);
    return true;
}

// 接管一个已经加载好的关卡（编辑器试玩也走这里）
session_set_level :: (s: *Session, level: Level) {
    session_clear(s);
    level_free(*s.level);
    s.level = level;
}

session_clear :: (s: *Session) {
    for s.undo_diffs  array_free(it.cells);
    array_reset(*s.undo_diffs);
    s.undo_count = 0;
    s.againing   = false;
    s.again_ms   = 0;
    s.message    = "";
    s.won        = false;
    s.jumps     += 1;
}

session_new_game :: (s: *Session, show_intro := true) {
    session_clear(s);
    state_copy(*s.state, s.level.initial);
    state_copy(*s.restart_target, s.level.initial);
    session_bind(s);

    if show_intro  s.message = find_message(*s.level, "intro");

    // 原版 run_rules_on_level_start：开局先跑一个没有输入的 tick
    run_start_tick(s);
}

session_bind :: (s: *Session) {
    sim_bind(*s.level, *s.state);
}

run_start_tick :: (s: *Session) {
    session_bind(s);
    res := run_tick(.NONE);
    handle_tick(s, res);
}

// ----------------------------------------------------------------------------: 输入

session_input :: (s: *Session, dir: Dir) {
    if s.won || s.message  return;
    if s.againing          return;   // 原版：again 期间的输入直接丢掉

    session_bind(s);
    res := run_tick(dir);
    if res.cancelled  return;

    if res.modified {
        push_undo(s, tick_backup);
        s.inputs_since_save += 1;
    }
    handle_tick(s, res);

    if !s.headless && !s.no_save && s.inputs_since_save >= 20 {
        session_save(s);
    }
}

session_update :: (s: *Session, dt_ms: float) {
    if !s.againing || s.message || s.won  return;

    s.again_ms += dt_ms;
    while s.againing && !s.message && s.again_ms >= TICK_MS {
        s.again_ms -= TICK_MS;
        again_step(s);
    }
    if !s.againing  s.again_ms = 0;
}

// 回放 / 测试用：把 again 一口气跑完
session_drain :: (s: *Session) {
    guard := 0;
    while s.againing {
        again_step(s);
        guard += 1;
        if guard > 10000 { log_error("again loop does not terminate"); s.againing = false; }
    }
}

again_step :: (s: *Session) {
    session_bind(s);
    res := run_tick(.NONE);
    // 原版先空跑一遍：这一 tick 什么都没改变（也没通关）就不算数，连带它的命令一起作废
    if !res.modified && !(res.commands & .WIN) {
        state_copy(*s.state, tick_backup);
        s.againing = false;
        return;
    }
    handle_tick(s, res);
}

handle_tick :: (s: *Session, res: Tick_Result) {
    c := res.commands;

    if !s.headless  play_tick_sounds(c);

    if c & .MESSAGE {
        s.message = find_message(*s.level, res.message);
    }

    if c & .WIN {
        s.won = true;
        s.againing = false;
        if !s.headless && !s.no_save  session_delete_save();
        return;
    }

    if c & .CHECKPOINT {
        state_copy(*s.restart_target, s.state);
        if !s.headless && !s.no_save  session_save(s);
    }

    s.againing = (c & .AGAIN) && res.modified;
}

play_tick_sounds :: (c: Cmd) {
    if c & .SFX0  play_sound(*push_box);
    if c & .SFX1  play_sound(*push_box);    // 原版世界 2 跳 / 爬的音效没有素材，按审阅决定用推箱子音效代替
    if c & .SFX2  play_sound(*rock_drop);
    if c & .SFX3  play_sound(*push_rock);
    if c & .SFX4  play_sound(*push_ball);   // 原版 SFX4 与 SFX5 是同一个种子
    if c & .SFX5  play_sound(*push_ball);
    if c & .SFX6  play_sound(*snake_move);
    if c & .SFX7  play_sound(*world_mutation);
}

session_dismiss_message :: (s: *Session) {
    s.message = "";
}

// ----------------------------------------------------------------------------: 撤销 / 重开

push_undo :: (s: *Session, backup: Game_State) {
    if s.undo_count > 0 {
        // 记下「从新备份回到旧备份」需要恢复的格子
        diff: Undo_Diff;
        diff.travel = s.undo_top.travel;
        diff.open   = s.undo_top.open;
        changed: [..] Undo_Cell;
        for i: 0..backup.cells.count-1 {
            if memcmp(*backup.cells[i], *s.undo_top.cells[i], size_of(Cell)) != 0 {
                array_add(*changed, .{cast(s32) i, s.undo_top.cells[i]});
            }
        }
        diff.cells = changed;
        array_add(*s.undo_diffs, diff);
    }
    state_copy(*s.undo_top, backup);
    s.undo_count += 1;
}

pop_undo :: (s: *Session) {
    if s.undo_count == 0  return;
    s.undo_count -= 1;
    if s.undo_count == 0  return;

    diff := pop(*s.undo_diffs);
    for diff.cells  s.undo_top.cells[it.index] = it.cell;
    s.undo_top.travel = diff.travel;
    s.undo_top.open   = diff.open;
    array_free(diff.cells);
}

session_undo :: (s: *Session) {
    if s.message  return;
    // 原版 DoUndo(false, true)：先丢掉和当前状态一模一样的备份
    while s.undo_count > 0 && state_equal(s.undo_top, s.state)  pop_undo(s);
    if s.undo_count == 0  return;

    state_copy(*s.state, s.undo_top);
    pop_undo(s);
    s.againing = false;
    s.won = false;
    s.jumps += 1;
}

session_restart :: (s: *Session) {
    if s.message  return;
    push_undo(s, s.state);
    state_copy(*s.state, s.restart_target);
    s.againing = false;
    s.won = false;
    s.jumps += 1;
    run_start_tick(s);
}

// ----------------------------------------------------------------------------: 查询

session_camera_cell :: (s: *Session) -> Pos, bool {
    for c, i: s.state.cells {
        if c.obj & .CAMERA  return .{cast(s32)(i / s.level.h), cast(s32)(i % s.level.h)}, true;
    }
    return .{}, false;
}

session_player_cell :: (s: *Session) -> Pos, bool {
    for c, i: s.state.cells {
        if c.obj & .PLAYER  return .{cast(s32)(i / s.level.h), cast(s32)(i % s.level.h)}, true;
    }
    return .{}, false;
}

// ----------------------------------------------------------------------------: 存档

// 多存档：每个战役一个文件 save/campaign_<id>.dat（相对 exe 所在目录，init_data_package 把工作目录切到那里）
LEGACY_SAVE_PATH :: #run tprint("%/save.dat", SAVE_DIR);
SAVE_MAGIC :: "ENGS";

current_campaign := 1;

campaign_save_path :: (id: int) -> string /* Temporary_Storage */ {
    return tprint("%/campaign_%.dat", SAVE_DIR, id);
}

// 现有的战役编号，升序（Temporary_Storage）
list_campaigns :: () -> [] int {
    ids: [..] int;
    ids.allocator = temp;
    files := file_list(SAVE_DIR,, temp);
    for files {
        name := path_filename(it);
        if !begins_with(name, "campaign_") || !ends_with(name, ".dat")  continue;
        digits := slice(name, 9, name.count - 9 - 4);
        id, ok, rest := string_to_int(digits);
        if ok && !rest && id > 0  array_add(*ids, id);
    }
    quick_sort(ids, (a, b) => a - b);
    return ids;
}

// 最近写过的战役；没有存档返回 0。旧版单存档 save.dat 顺手迁成 1 号战役
latest_campaign :: () -> int {
    if file_exists(LEGACY_SAVE_PATH) && !file_exists(campaign_save_path(1)) {
        file_move(LEGACY_SAVE_PATH, campaign_save_path(1));
    }
    best := 0;
    best_time: Apollo_Time;
    for list_campaigns() {
        t, _, ok := file_modtime_and_size(campaign_save_path(it));
        if !ok  continue;
        if !best || t > best_time { best = it; best_time = t; }
    }
    return best;
}

next_campaign_id :: () -> int {
    ids := list_campaigns();
    if !ids  return 1;
    return ids[ids.count-1] + 1;
}
SAVE_VERSION :: 1;

session_save :: (s: *Session) {
    s.inputs_since_save = 0;
    if s.won  return;

    b: String_Builder;
    append(*b, SAVE_MAGIC);
    put :: (b: *String_Builder, value: $T) { append(b, cast(*u8) *value, size_of(T)); }
    put(*b, cast(u32) SAVE_VERSION);
    put(*b, level_hash(*s.level));
    put(*b, s.level.w);
    put(*b, s.level.h);
    for st: Game_State.[s.state, s.restart_target] {
        append(*b, cast(*u8) st.cells.data, st.cells.count * size_of(Cell));
        put(*b, st.travel);
        put(*b, st.open);
    }

    make_directory_if_it_does_not_exist(SAVE_DIR);
    data := builder_to_string(*b);
    defer free(data);
    path := campaign_save_path(current_campaign);
    if !write_entire_file(path, data)  log_error("Failed to write %.", path);
}

// 返回 false：没有存档，或存档对应的关卡已经改过
session_load_save :: (s: *Session) -> bool {
    data, ok := read_entire_file(campaign_save_path(current_campaign), log_errors = false);
    if !ok  return false;
    defer free(data);

    cursor := data;
    take :: (size: int) -> *u8, bool #expand {
        if cursor.count < size  return null, false;
        p := cursor.data;
        advance(*cursor, size);
        return p, true;
    }
    get :: ($T: Type) -> T, bool #expand {
        p, ok := take(size_of(T));
        zero: T;
        if !ok  return zero, false;
        return (cast(*T) p).*, true;
    }

    magic, m_ok := take(4);
    if !m_ok || memcmp(magic, SAVE_MAGIC.data, 4) != 0  return false;
    version := get(u32);
    hash    := get(u64);
    w       := get(s32);
    h       := get(s32);
    if version != SAVE_VERSION || hash != level_hash(*s.level) || w != s.level.w || h != s.level.h {
        log("Save file is for a different level version, ignoring it.");
        return false;
    }

    session_clear(s);
    for st: (*Game_State).[*s.state, *s.restart_target] {
        state_copy(st, s.level.initial);
        p, cells_ok := take(st.cells.count * size_of(Cell));
        if !cells_ok  return false;
        memcpy(st.cells.data, p, st.cells.count * size_of(Cell));
        travel, t_ok := get(Travel);
        open,   o_ok := get(u32);
        if !t_ok || !o_ok  return false;
        st.travel = travel;
        st.open   = open;
    }
    session_bind(s);
    return true;
}

session_has_save :: () -> bool {
    return file_exists(campaign_save_path(current_campaign));
}

session_delete_save :: () {
    path := campaign_save_path(current_campaign);
    if file_exists(path)  file_delete(path);
}

// 关卡初始状态的指纹：关卡被编辑过，旧存档就作废
level_hash :: (l: *Level) -> u64 {
    h: u64 = 14695981039346656037;
    mix :: (h: *u64, p: *u8, n: int) {
        for 0..n-1 { h.* ^= p[it]; h.* *= 1099511628211; }
    }
    mix(*h, cast(*u8) l.initial.cells.data, l.initial.cells.count * size_of(Cell));
    for l.tunnels  mix(*h, cast(*u8) it.path.data, it.path.count * size_of(Pos));
    return h;
}
