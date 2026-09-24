// late 规则（移动结算之后执行），按原脚本顺序逐条翻译。
// 原版 late 段里大量是装饰规则（给每格摆美术对象），那些改在渲染时现算，这里只保留有逻辑作用的，
// 以及几条通过「同层对象」间接影响���辑的装饰规则（见 ps:2317-2318、ps:2340-2344）。

rules_late :: () {
    l := sim_level;

    // ps:1778  late [o warp] -> message ...don't... (press Z to undo)
    for t, ti: l.tunnels  for e, ei: t.ends {
        if !(sim.open & tunnel_open_bit(ti, ei))  continue;
        i := cell_index(e.pos.x, e.pos.y);
        if in_scope(i) && has(i, .THING)  queue_message("warp_thing");
    }

    // ---------------------------------------------------------------- 世界 6：箱子连接

    // ps:1869  global late up [6 o no linked no fixmypuzzle no fixmypuzzle2| thing no linked no fixmypuzzle2] -> [6 o ulink| thing]
    for pass: stable() for scan(.UP, 2, global = true) {
        c1 := nb(it, D);
        if w(it) == .SIX && has(it, .THING) && !any(it, .LINKED | .FIX1 | .FIX2) && has(c1, .THING) && !any(c1, .LINKED | .FIX2)  add(it, .LU);
    }
    // ps:1870  global late down [6 o no linked no fixmypuzzle2 | thing no linked no fixmypuzzle no fixmypuzzle2] -> [6 o dlink | thing]
    for pass: stable() for scan(.DOWN, 2, global = true) {
        c1 := nb(it, D);
        if w(it) == .SIX && has(it, .THING) && !any(it, .LINKED | .FIX2) && has(c1, .THING) && !any(c1, .LINKED | .FIX1 | .FIX2)  add(it, .LD);
    }
    // ps:1871  global late left  [6 o no linked no fixmypuzzle2| thing no linked no fixmypuzzle2] -> [6 o llink | thing]
    // ps:1872  global late right [6 o no linked no fixmypuzzle2| thing no linked no fixmypuzzle2] -> [6 o rlink | thing]
    for d: Dir.[.LEFT, .RIGHT] {
        for pass: stable() for scan(d, 2, global = true) {
            c1 := nb(it, D);
            if w(it) == .SIX && has(it, .THING) && !any(it, .LINKED | .FIX2) && has(c1, .THING) && !any(c1, .LINKED | .FIX2)  add(it, link_of(D));
        }
    }
    // ps:1873  global late [6 o no swap no swapped] -> [6 o linked]
    for pass: stable() for scan(.DOWN, 1, global = true)  if w(it) == .SIX && has(it, .THING) && swp(it) == 0 && !has(it, .SWAPPED)  add(it, .LINKED);

    // ps:1911-1914  late up [ o ulink | no 6 no 3] -> [ o | ]   邻居离开世界 6/3 就断开
    for d: DIRS4 {
        link := link_of(d);
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .THING | link) && w(c1) != .SIX && w(c1) != .THREE  del(it, link);
        }
    }

    // ps:1935  late [legs no 6] -> []
    for pass: stable() for scan(.DOWN)  if has(it, .LEGS) && w(it) != .SIX  del(it, .LEGS);
    // ps:1936  late [link no 6] -> []
    for pass: stable() for scan(.DOWN)  if any(it, LINKS) && w(it) != .SIX  del(it, LINKS);

    // ---------------------------------------------------------------- 世界 5：蛇身

    // ps:1950-1953  late up [umark5 no o no p 5|o 5] -> [umark5 finishedeating 5|5]  + left + right + down
    //               身体整体往头的方向挪一格
    for pass: stable() for d: Dir.[.UP, .LEFT, .RIGHT, .DOWN] for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, m5_of(D)) && !any(it, .THING | .PLAYER) && w(it) == .FIVE && has(c1, .THING) && w(c1) == .FIVE {
            add(it, .FINISHED);
            del(c1, .THING);
        }
    }
    // ps:1954  late [finishedeating] -> [o]
    for pass: stable() for scan(.DOWN)  if has(it, .FINISHED) { del(it, .FINISHED); add(it, .THING); }
    // ps:1956  late [exitmark no o] -> []
    for pass: stable() for scan(.DOWN)  if has(it, .EXIT) && !has(it, .THING)  del(it, .EXIT);

    // ps:1958-1961  late up [p 5][umark5 no o no p 5| no 5] -> [p 5][umark5 o 5|]  + down + left + right
    //               锚定蛇：尾端指向世界 5 以外时，在尾端补一节
    if exists((i: s32) -> bool { return has(i, .PLAYER) && w(i) == .FIVE; })  anchored_growth();
    // ps:1963-1966  同上，不要求玩家在世界 5
    anchored_growth();

    // ps:1968-1971  late down [tailmark no o | umark5] -> [|tailmark]  …   尾巴跟上
    TAIL_RULES :: Dir.[.DOWN, .UP, .RIGHT, .LEFT];
    for d: TAIL_RULES {
        for pass: stable() for scan(d, 2) {
            c1 := nb(it, D);
            if has(it, .TAIL) && !has(it, .THING) && has(c1, m5_of(opposite(D))) {
                del(it, .TAIL);
                add(c1, .TAIL);
            }
        }
    }

    // ps:1979  late [mark5 5 no p no o] -> [5]
    for pass: stable() for scan(.DOWN)  if any(it, MARK5) && w(it) == .FIVE && !any(it, .PLAYER | .THING)  del(it, MARK5 & sim.cells[it].obj);

    // ---------------------------------------------------------------- 开关

    // ps:1990  late [t justswappedp no 5 no p] -> [t]
    for pass: stable() for scan(.DOWN)  if has(it, .TOGGLE | .JUST_P) && w(it) != .FIVE && !has(it, .PLAYER)  del(it, .JUST_P);
    // ps:1991  late [t justswappedo no 5 no fivehide no o] -> [t]
    for pass: stable() for scan(.DOWN)  if has(it, .TOGGLE | .JUST_O) && w(it) != .FIVE && hw(it) != .FIVE && !has(it, .THING)  del(it, .JUST_O);
    // ps:1992  late [t justswappedp 5 no o no p] -> [t 5]
    for pass: stable() for scan(.DOWN)  if has(it, .TOGGLE | .JUST_P) && w(it) == .FIVE && !any(it, .THING | .PLAYER)  del(it, .JUST_P);

    // ps:1994  late [p] -> [p noswap]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER)  add(it, .NOSWAP);
    // ps:1995  late [noswap][justswappedp t 5] -> [][justswappedp t 5]
    if exists((i: s32) -> bool { return has(i, .JUST_P | .TOGGLE) && w(i) == .FIVE; }) {
        for pass: stable() for scan(.DOWN)  if has(it, .NOSWAP)  del(it, .NOSWAP);
    }
    // ps:1996  late [noswap][justswappedo t 5] -> [][justswappedo t 5]
    if exists((i: s32) -> bool { return has(i, .JUST_O | .TOGGLE) && w(i) == .FIVE; }) {
        for pass: stable() for scan(.DOWN)  if has(it, .NOSWAP)  del(it, .NOSWAP);
    }
    // ps:1997  late [noswap][mark5 no 5] -> [noswap][]   翻出世界 5 后清掉蛇标记，身体变回普通箱子
    if exists((i: s32) -> bool { return has(i, .NOSWAP); }) {
        for pass: stable() for scan(.DOWN)  if any(it, MARK5) && w(it) != .FIVE  del(it, MARK5 & sim.cells[it].obj);
    }
    // ps:1998  late [noswap]-> []
    for pass: stable() for scan(.DOWN)  if has(it, .NOSWAP)  del(it, .NOSWAP);

    // ps:2002  late [p t no justswappedp no 5 no fivehide] -> [p t swap1 justswappedp] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .TOGGLE) && !has(it, .JUST_P) && w(it) != .FIVE && hw(it) != .FIVE {
        trigger_toggle(it, .JUST_P);
    }
    // ps:2003  late [o t no justswappedo no swap no swapped no 5 no fivehide] -> [o t swap1 justswappedo] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .THING | .TOGGLE) && !has(it, .JUST_O) && swp(it) == 0 && !has(it, .SWAPPED) && w(it) != .FIVE && hw(it) != .FIVE {
        trigger_toggle(it, .JUST_O);
    }
    // ps:2004  late [o t swap justswappedo no swapped][swap justswappedp no swapped] -> [o t][swap justswappedp]
    //          玩家和箱子同时触发时，只算玩家那一次
    if exists((i: s32) -> bool { return swp(i) > 0 && has(i, .JUST_P) && !has(i, .SWAPPED); }) {
        for pass: stable() for scan(.DOWN)  if has(it, .THING | .TOGGLE | .JUST_O) && swp(it) > 0 && !has(it, .SWAPPED) {
            set_swap(it, 0);
            del(it, .JUST_O);
        }
    }
    // ps:2006  late [p t no justswappedp 5] -> [p t swap1 justswappedp 5] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .TOGGLE) && !has(it, .JUST_P) && w(it) == .FIVE  trigger_toggle(it, .JUST_P);
    // ps:2007  late [o t no mark5 no justswappedo 5] -> [o t swap1 justswappedo 5] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .THING | .TOGGLE) && !any(it, MARK5) && !has(it, .JUST_O) && w(it) == .FIVE  trigger_toggle(it, .JUST_O);
    // ps:2008  late [o t mark5 no justswappedp 5] -> [o t swap1 mark5 justswappedp 5] again SFX7   蛇身压开关也算玩家
    for pass: stable() for scan(.DOWN)  if has(it, .THING | .TOGGLE) && any(it, MARK5) && !has(it, .JUST_P) && w(it) == .FIVE  trigger_toggle(it, .JUST_P);
    // ps:2009  late [p t no justswappedp fivehide] -> [p t swap1 justswappedp fivehide] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .TOGGLE) && !has(it, .JUST_P) && hw(it) == .FIVE  trigger_toggle(it, .JUST_P);
    // ps:2010  late [o t no justswappedp no justswappedo fivehide] -> [o t swap1 justswappedp fivehide] again SFX7
    for pass: stable() for scan(.DOWN)  if has(it, .THING | .TOGGLE) && !any(it, .JUST_P | .JUST_O) && hw(it) == .FIVE  trigger_toggle(it, .JUST_P);

    // ps:2197  late [p legs] -> [p]
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .LEGS)  del(it, .LEGS);

    // ps:2211  late [p messag] -> [p] message Oh dang, I made a secret...
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER | .SECRET) { del(it, .SECRET); queue_message("secret"); }

    // ---------------------------------------------------------------- 重力 / 沉没

    // ps:2219  late down [p 2 | no o no x] -> [p 2 |] again
    for scan(.DOWN, 2)  if has(it, .PLAYER) && w(it) == .TWO && !any(nb(it, D), .THING | .WALL)  queue(.AGAIN);
    // ps:2220  late down [o 2 no x |no p no o no x] -> [o 2 |] again
    for scan(.DOWN, 2)  if has(it, .THING) && w(it) == .TWO && !has(it, .WALL) && !any(nb(it, D), .PLAYER | .THING | .WALL)  queue(.AGAIN);

    // ps:2223  late [supported] -> []
    for pass: stable() for scan(.DOWN)  if tch(it) == TOUCH_SUPPORTED  set_touch(it, 0);
    // ps:2224  late [o no x 3] -> [o supported 3]
    for pass: stable() for scan(.DOWN)  if has(it, .THING) && !has(it, .WALL) && w(it) == .THREE  set_touch(it, TOUCH_SUPPORTED);
    // ps:2225  late [o supported 3|o 3] -> [o supported 3 | o supported 3]   筏子只要有一块在岸上就整组托住
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, .THING) && tch(it) == TOUCH_SUPPORTED && w(it) == .THREE && has(c1, .THING) && w(c1) == .THREE  set_touch(c1, TOUCH_SUPPORTED);
    }
    // ps:2226  late right [o x 3 no supported no swap|no swap] -> [sunk 3 no swap|] SFX4
    for pass: stable() for scan(.RIGHT, 2) {
        c1 := nb(it, D);
        if has(it, .THING | .WALL) && w(it) == .THREE && tch(it) != TOUCH_SUPPORTED && swp(it) == 0 && swp(c1) == 0 {
            del(it, .THING | .WALL);
            add(it, .SUNK);
            queue(.SFX4);
        }
    }

    // ps:2230-2233  late up [umark6 p | no x no legs] -> again   世界 6 还在下落
    for d: DIRS4 {
        for scan(d, 2)  if has(it, m6_of(D) | .PLAYER) && !any(nb(it, D), .WALL | .LEGS)  queue(.AGAIN);
    }

    // ---------------------------------------------------------------- 有逻辑副作用的装饰规则

    // ps:2317  late [efive no o] -> []     ps:2318  late [efive no mark5] -> []
    for pass: stable() for scan(.DOWN)  if any(it, EFIVE) && !has(it, .THING)  del(it, EFIVE & sim.cells[it].obj);
    for pass: stable() for scan(.DOWN)  if any(it, EFIVE) && !any(it, MARK5)   del(it, EFIVE & sim.cells[it].obj);

    // ps:2340-2344  世界 5 的玩家贴图（playerfive）和 reallybadidea 同层，蛇头经过会把那个提示抹掉
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && w(it) == .FIVE && hasm(it, .BAD_IDEA)  delm(it, .BAD_IDEA);

    // ---------------------------------------------------------------- 虚空

    // ps:2402  late [t seven] -> [seven]
    for pass: stable() for scan(.DOWN)  if has(it, .TOGGLE) && w(it) == .SEVEN  del(it, .TOGGLE);
    // ps:2403  late [o seven] -> [seven]
    for pass: stable() for scan(.DOWN)  if has(it, .THING) && w(it) == .SEVEN  del(it, .THING);
    // ps:2405  late [seven no x] -> [seven x sevenwall]
    for pass: stable() for scan(.DOWN)  if w(it) == .SEVEN && !has(it, .WALL) { add(it, .WALL); add(it, .SEVENWALL); }

    // ---------------------------------------------------------------- 检查点、消息

    // ps:2407  late [p checkpoin] -> [p] checkpoint
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && hasm(it, .CHECKPOINT) { delm(it, .CHECKPOINT); queue(.CHECKPOINT); }
    // ps:2414  late [p checkpointmessage] -> [p] message BTW, If you press R to reset...
    for pass: stable() for scan(.DOWN)  if has(it, .PLAYER) && hasm(it, .HINT_RESET) { delm(it, .HINT_RESET); queue_message("hint_reset"); }
    // ps:2422  late [o reallybadidea] -> message Er... that seems like a bad idea
    for scan(.DOWN)  if has(it, .THING) && hasm(it, .BAD_IDEA)  queue_message("bad_idea");

    // ---------------------------------------------------------------- 镜头

    // ps:2429  late [camera no camerastick no camerashift no p][p] -> [][camera p]
    for pass: stable() {
        p := first_cell((i: s32) -> bool { return has(i, .PLAYER); });
        if p < 0  break;
        for scan(.DOWN)  if has(it, .CAMERA) && !hasm(it, .CAMSTICK) && !any(it, .CAMSHIFT | .PLAYER) {
            del(it, .CAMERA);
            add(p, .CAMERA);
        }
    }
    // ps:2430  late left [camerashiftleft camera no camerashift] -> [camerashiftleft camera camerashift]
    for pass: stable() for scan(.LEFT)  if hasm(it, .CAMSHIFTLEFT) && has(it, .CAMERA) && !has(it, .CAMSHIFT)  add(it, .CAMSHIFT);
    // ps:2431  late left [camerashiftleft camera camerashift|] -> [|camera camerashift]   镜头再往左领先一格
    for pass: stable() for scan(.LEFT, 2) {
        c1 := nb(it, D);
        if hasm(it, .CAMSHIFTLEFT) && has(it, .CAMERA | .CAMSHIFT) {
            delm(it, .CAMSHIFTLEFT);
            del(it, .CAMERA | .CAMSHIFT);
            add(c1, .CAMERA);
            add(c1, .CAMSHIFT);
        }
    }
}

// late up [umark5 no o no p 5| no 5] -> [umark5 o 5|]  + down + left + right
anchored_growth :: () {
    for pass: stable() for d: DIRS4 for scan(d, 2) {
        c1 := nb(it, D);
        if has(it, m5_of(D)) && !any(it, .THING | .PLAYER) && w(it) == .FIVE && w(c1) != .FIVE  add(it, .THING);
    }
}

// [.. t ..] -> [.. t swap1 justswappedX ..] again SFX7
trigger_toggle :: (i: s32, latch: Obj) {
    set_swap(i, 1);
    add(i, latch);
    queue(.AGAIN);
    queue(.SFX7);
}

in_scope :: (i: s32) -> bool {
    if !emulate_local_radius  return true;
    x := cell_x(i);
    y := cell_y(i);
    return x >= scope.x0 && x < scope.x1 && y >= scope.y0 && y < scope.y1;
}
