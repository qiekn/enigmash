// 规则引擎骨架：状态访问、按原版顺序遍历匹配、命令队列、移动结算、单个 tick。
//
// 规则本身在 rules_normal.jai / rules_late.jai，按原脚本的顺序逐条手写，
// 每条都注明原脚本行号（ps:行号）。这里复刻的是原版引擎的执行模型：
//
//   - 一条规则 = 一个组：反复执行直到不再改变任何东西（原版 applyRuleGroup）
//   - up/left 规则会被原版改写成反向的 down/right，匹配顺序随之改变（rewriteUpLeftRules）
//   - 竖直规则按 x 外层、y 内层遍历；水平规则按 y 外层、x 内层遍历（matchCellRow）
//   - 命令（again / 音效 / 消息 …）在规则「匹配」时就入队，不管有没有改变东西
//   - 移动在全部普通规则之后统一结算，按格子索引、按层顺序反复尝试（resolveMovements）

LOCAL_RADIUS :: 17;

// 当前正在模拟的关卡与状态
sim_level : *Level;
sim       : *Game_State;
SW, SH    : s32;          // 地图宽高

moves : [] Dir;           // 每格每个通道的移动方向，只在一个 tick 内有效

// 原版 local_radius：每个 tick 开始时以逻辑 CAMERA 为中心限制非 global 规则。
// 右/下边界不包含在内，与 PuzzleScript 的 [pos-radius, pos+radius) 一致。
// global 规则仍扫描全图；调试/性能对照时可关闭这个开关。
emulate_local_radius := true;
sim_ticks_run: u64;

rule_changed := false;    // 当前组这一轮有没有改变东西
D : Dir;                  // 当前规则方向，由 scan() 设置

Scope :: struct { x0, y0, x1, y1: s32; }
scope : Scope;

Cmd :: enum_flags u32 {
    AGAIN; CANCEL; WIN; CHECKPOINT; MESSAGE;
    SFX0; SFX1; SFX2; SFX3; SFX4; SFX5; SFX6; SFX7;
}
SFX_MASK :: Cmd.SFX0 | .SFX1 | .SFX2 | .SFX3 | .SFX4 | .SFX5 | .SFX6 | .SFX7;

cmd         : Cmd;
cmd_message : string;     // 消息 id，同一 tick 里只保留第一条（原版 queueCommands 去重）

queue :: inline (c: Cmd) { cmd |= c; }

queue_message :: (id: string) {
    if cmd & .MESSAGE  return;
    cmd |= .MESSAGE;
    cmd_message = id;
}

// ----------------------------------------------------------------------------: 访问

cell_index :: inline (x: s32, y: s32) -> s32 { return x * SH + y; }
cell_x     :: inline (i: s32) -> s32 { return i / SH; }
cell_y     :: inline (i: s32) -> s32 { return i % SH; }

has  :: inline (i: s32, o: Obj)  -> bool  { return (sim.cells[i].obj & o) == o; }
any  :: inline (i: s32, o: Obj)  -> bool  { return (sim.cells[i].obj & o) != 0; }
hasm :: inline (i: s32, m: Mark) -> bool  { return (sim.cells[i].mark & m) != 0; }
w    :: inline (i: s32) -> World { return sim.cells[i].num; }
hw   :: inline (i: s32) -> World { return sim.cells[i].hide; }
swp  :: inline (i: s32) -> u8    { return sim.cells[i].swap; }
tch  :: inline (i: s32) -> u8    { return sim.cells[i].touch; }

is_y  :: inline (i: s32) -> bool { return any(i, Y_OBJ); }
is_po :: inline (i: s32) -> bool { return any(i, PO); }

mv    :: inline (i: s32, ch: Channel) -> Dir  { return moves[i * CHANNEL_COUNT + cast(s32) ch]; }
still :: inline (i: s32, ch: Channel) -> bool { return mv(i, ch) == .NONE; }

// 不做越界检查：只在 scan() 给出的格子上用，pattern 保证落在地图内
nb :: inline (i: s32, d: Dir) -> s32 {
    dx, dy := dir_delta(d);
    return i + dx * SH + dy;
}

nb_checked :: (i: s32, d: Dir) -> s32, bool {
    dx, dy := dir_delta(d);
    x := cell_x(i) + dx;
    y := cell_y(i) + dy;
    if x < 0 || y < 0 || x >= SW || y >= SH  return -1, false;
    return cell_index(x, y), true;
}

// ----------------------------------------------------------------------------: 修改（都会记录 rule_changed）

set_mv :: (i: s32, ch: Channel, d: Dir) {
    p := *moves[i * CHANNEL_COUNT + cast(s32) ch];
    if p.* != d { p.* = d; rule_changed = true; }
}

// 加对象：先清掉同层的其他对象（原版 objectsClear |= layerMask）
add :: (i: s32, o: Obj) {
    c := *sim.cells[i];
    n := (c.obj & ~layer_of(o)) | o;
    if n != c.obj { c.obj = n; rule_changed = true; }
}

add_moving :: (i: s32, o: Obj, d: Dir) {
    add(i, o);
    ch := channel_of(o);
    set_mv(i, ch, d);
}

// 删对象：整层清空，并清掉这一层的移动（原版「LHS 用到、RHS 没用到的层」）
del :: (i: s32, o: Obj) {
    c := *sim.cells[i];
    remaining := o;
    while remaining {
        r := cast(u64) remaining;
        bit := cast(Obj)(r & (~r + 1));   // 最低位
        remaining &= ~bit;
        layer := layer_of(bit);
        if c.obj & layer {
            c.obj &= ~layer;
            rule_changed = true;
        }
        ch, is_channel := channel_of(bit);
        if is_channel  set_mv(i, ch, .NONE);
    }
}

delm :: (i: s32, m: Mark) {
    c := *sim.cells[i];
    layer := m;
    if m & MESSAGE_MARKS  layer |= MESSAGE_MARKS;
    if c.mark & layer { c.mark &= ~layer; rule_changed = true; }
}

set_num :: (i: s32, v: World) {
    c := *sim.cells[i];
    if c.num != v { c.num = v; rule_changed = true; }
}

set_hide :: (i: s32, v: World) {
    c := *sim.cells[i];
    if c.hide != v { c.hide = v; rule_changed = true; }
}

set_swap :: (i: s32, v: u8) {
    c := *sim.cells[i];
    if c.swap != v { c.swap = v; rule_changed = true; }
}

set_touch :: (i: s32, v: u8) {
    c := *sim.cells[i];
    if c.touch != v { c.touch = v; rule_changed = true; }
}

// ----------------------------------------------------------------------------: 遍历

scope_bounds :: (global: bool) -> x0: s32, y0: s32, x1: s32, y1: s32 {
    if global || !emulate_local_radius  return 0, 0, SW, SH;
    return scope.x0, scope.y0, scope.x1, scope.y1;
}

// for scan(d, len) { ... }：按原版顺序枚举长度为 len、方向为 d 的 pattern，it = 第一个格子
Scan :: struct { d: Dir; len: s32; global: bool; }
scan :: (d: Dir, len: s32 = 1, global := false) -> Scan { return .{d, len, global}; }

for_expansion :: (s: Scan, body: Code, flags: For_Flags) #expand {
    D = s.d;
    x0, y0, x1, y1 := scope_bounds(s.global);
    L := s.len;

    // up/left 被原版改写成反向的 down/right：遍历的锚点是 pattern 最上 / 最左的格子，
    // 而 pattern 的第一个格子在锚点下方 / 右方 L-1 格
    back: s32 = 0;
    if s.d == .UP    back = L - 1;
    if s.d == .LEFT  back = (L - 1) * SH;

    // body 只插一次（插两次会在调用处重复声明 `it）。竖向扫描：外层 x 内层 y；横向：外层 y 内层 x
    vertical := is_vertical(s.d);
    if vertical  y1 -= L - 1;
    else         x1 -= L - 1;
    outer0, outer1 := ifx vertical then x0 else y0, ifx vertical then x1 else y1;
    inner0, inner1 := ifx vertical then y0 else x0, ifx vertical then y1 else x1;

    `it: s32;
    `it_index := 0;
    for a: outer0..outer1-1 {
        for b: inner0..inner1-1 {
            x := ifx vertical then a else b;
            y := ifx vertical then b else a;
            it = cast(s32)(x * SH + y) + back;
            #insert body;
        }
    }
}

// for stable() { ... }：反复执行直到这一轮没有任何改变（一个规则组 / startloop..endloop）
Stable :: struct { unused: u8; }
stable :: () -> Stable { return .{}; }

for_expansion :: (s: Stable, body: Code, flags: For_Flags) #expand {
    outer_changed := rule_changed;
    any_changed   := false;
    for iteration: 1..200 {
        rule_changed = false;
        `it := iteration;
        `it_index := 0;
        #insert body;
        if !rule_changed  break;
        any_changed = true;
    }
    rule_changed = outer_changed || any_changed;
}

// 多行规则 [A][B] 里「另一行存在匹配」的判断
exists :: (pred: (i: s32) -> bool, global := false) -> bool {
    for scan(.DOWN, 1, global)  if pred(it)  return true;
    return false;
}

first_cell :: (pred: (i: s32) -> bool, global := false) -> s32 {
    for scan(.DOWN, 1, global)  if pred(it)  return it;
    return -1;
}

// ----------------------------------------------------------------------------: 世界 4 的墙（原版是装饰对象，这里现算）

// wallfour：世界 4 里与世界 4 空地相邻的墙（玩家可以走上去）
is_wallfour :: (i: s32) -> bool {
    if !has(i, .WALL) || w(i) != .FOUR  return false;
    for d: DIRS4 {
        j, ok := nb_checked(i, d);
        if ok && !has(j, .WALL) && w(j) == .FOUR  return true;
    }
    return false;
}

is_wallfour2 :: (i: s32) -> bool {
    return has(i, .WALL) && w(i) == .FOUR && !is_wallfour(i);
}

// ----------------------------------------------------------------------------: 移动结算

resolve_movements :: () {
    n := sim.cells.count;
    moved := true;
    while moved {
        moved = false;
        for i: 0..n-1 {
            base := i * CHANNEL_COUNT;
            for ch: 0..CHANNEL_COUNT-1 {
                d := moves[base + ch];
                if d == .NONE  continue;
                if try_move(cast(s32) i, cast(Channel) ch, d) {
                    moves[base + ch] = .NONE;
                    moved = true;
                }
            }
        }
    }
    // 没能移动的就算了
    memset(moves.data, 0, moves.count * size_of(Dir));
}

try_move :: (i: s32, ch: Channel, d: Dir) -> bool {
    if d == .ACTION  return true;    // 原版：action 原地「移动」，总是成功

    t, ok := nb_checked(i, d);
    if !ok  return false;

    mask := CHANNEL_MASK[ch];
    if sim.cells[t].obj & mask  return false;

    moving := sim.cells[i].obj & mask;
    sim.cells[i].obj &= ~moving;
    sim.cells[t].obj |= moving;
    return true;
}

// ----------------------------------------------------------------------------: tick

Tick_Result :: struct {
    modified  : bool;
    cancelled : bool;
    commands  : Cmd;
    message   : string;
}

tick_backup : Game_State;

sim_bind :: (l: *Level, s: *Game_State) {
    sim_level = l;
    sim       = s;
    SW = l.w;
    SH = l.h;
    n := l.w * l.h * CHANNEL_COUNT;
    if moves.count != n {
        array_free(moves);
        moves = NewArray(n, Dir);
    }
}

compute_scope :: () {
    scope = .{};
    cam := -1;
    for i: 0..sim.cells.count-1  if sim.cells[i].obj & .CAMERA { cam = i; break; }
    if cam < 0  return;     // 原版没有镜头时 playerPositions 为空，非 global 规则全部不匹配

    px := cell_x(xx cam);
    py := cell_y(xx cam);
    scope.x0 = xx max(0, px - LOCAL_RADIUS);
    scope.x1 = xx min(SW, px + LOCAL_RADIUS);
    scope.y0 = xx max(0, py - LOCAL_RADIUS);
    scope.y1 = xx min(SH, py + LOCAL_RADIUS);
}

// 原版 processInput 的一次：input = NONE 表示没有输入的 tick（again / 关卡开始）
run_tick :: (input: Dir) -> Tick_Result {
    sim_ticks_run += 1;
    state_copy(*tick_backup, sim.*);

    compute_scope();
    memset(moves.data, 0, moves.count * size_of(Dir));

    if input != .NONE {
        for i: 0..sim.cells.count-1 {
            if sim.cells[i].obj & .CAMERA  moves[i * CHANNEL_COUNT + cast(int) Channel.CAMERA] = input;
        }
    }

    cmd = 0;
    cmd_message = "";

    rules_normal();
    resolve_movements();
    rules_late();

    r: Tick_Result;
    if cmd & .CANCEL {
        state_copy(sim, tick_backup);
        r.cancelled = true;
        return r;
    }

    r.modified = !state_equal(sim.*, tick_backup);
    r.commands = cmd;
    r.message  = cmd_message;
    return r;
}
